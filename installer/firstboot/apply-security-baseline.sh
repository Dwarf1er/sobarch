#!/usr/bin/env bash
# Applies the security baseline: a default-deny nftables firewall,
# root login locked unconditionally, and SSH disabled unless the TUI's
# SSH screen (installer/tui/screens/ssh.py) enabled it.
#
# Run once by sobarch-firstboot-security.service (ConditionPathExists
# on MARKER below, same pattern as the other first-boot units): a
# failure here leaves MARKER unwritten, so it retries on the next boot
# instead of being silently skipped.

set -euo pipefail

MARKER="/var/lib/sobarch/security-baseline-applied"
SSH_FLAG="/etc/sobarch/ssh-enabled"

# Best-effort desktop notification into the logged-in user's session:
# this runs as root with no controlling terminal, so a failure is
# otherwise invisible until someone thinks to check journalctl. A
# no-op if no graphical session is active yet (e.g. a network blip
# right after boot before anyone's logged in) or notify-send isn't
# installed.
#
# notify_user prints the notification's id (via -p) so a caller can
# pass it back in as replace_id to update that same notification in
# place, rather than piling up a new transient one per step.
notify_user() {
    local urgency="$1" title="$2" body="$3" replace_id="${4:-0}"
    command -v notify-send >/dev/null 2>&1 || { echo 0; return 0; }
    local session_user
    session_user="$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3; exit}')"
    [[ -n "$session_user" ]] || { echo 0; return 0; }
    local uid
    uid="$(id -u "$session_user" 2>/dev/null)" || { echo 0; return 0; }
    runuser -u "$session_user" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
        notify-send -p -r "$replace_id" -u "$urgency" "$title" "$body" 2>/dev/null || echo 0
}
trap 'rc=$?; [[ $rc -eq 0 ]] || notify_user critical "sobarch: security baseline failed" \
    "Check: journalctl -u sobarch-firstboot-security.service"; exit $rc' EXIT

mkdir -p "$(dirname "$MARKER")"
id=$(notify_user normal "sobarch: security baseline" "Applying the security baseline...")

# Absent (e.g. a hand-run archinstall config outside the TUI) defaults
# to disabled, matching SSH's own "off unless explicit" default.
ssh_enabled="false"
if [[ -f "$SSH_FLAG" ]]; then
    ssh_enabled="$(<"$SSH_FLAG")"
fi

# Root login is locked unconditionally, independent of SSH's state or
# how the base system was installed: `passwd -l`
# prepends "!" to the shadow entry, disabling password auth outright.
# Harmless to repeat if already locked.
echo "sobarch-firstboot: locking the root account..."
id=$(notify_user normal "sobarch: security baseline" "Locking the root account..." "$id")
passwd -l root

# Base ruleset from Arch's own "Simple & Safe" nftables example:
# default-drop inbound, always allow loopback and established/related
# traffic, explicit exceptions only for required packages. LocalSend
# (packages/aur/localsend-bin, not yet vendored) is a required
# package, so its port
# is opened unconditionally rather than gated on whether it happens to
# be installed yet. SSH's exception is appended only when enabled.
echo "sobarch-firstboot: installing the nftables baseline ruleset..."
id=$(notify_user normal "sobarch: security baseline" "Installing the firewall ruleset..." "$id")

ssh_rule=""
if [[ "$ssh_enabled" == "true" ]]; then
    ssh_rule='
        # SSH (sobarch-firstboot: enabled via the TUI'"'"'s SSH screen)
        tcp dport 22 accept'
fi

cat > /etc/nftables.conf <<EOF
#!/usr/sbin/nft -f
# Managed by sobarch-firstboot-security.service; re-run
# apply-security-baseline.sh (or edit directly, this file is not
# reconciled like configs/skel) to change it.

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        iif "lo" accept
        ct state established,related accept
        ct state invalid drop

        icmp type echo-request accept
        icmpv6 type { echo-request, nd-neighbor-solicit, nd-neighbor-advert, nd-router-advert } accept

        # LocalSend
        tcp dport 53317 accept
        udp dport 53317 accept
${ssh_rule}
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

systemctl enable --now nftables.service

if [[ "$ssh_enabled" == "true" ]]; then
    echo "sobarch-firstboot: SSH enabled, installing openssh..."
    id=$(notify_user normal "sobarch: security baseline" "Installing and enabling SSH..." "$id")
    pacman -S --needed --noconfirm openssh

    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/10-sobarch-no-root-login.conf <<'EOF'
# Root login is locked at the account level regardless (passwd -l
# root), but this is the belt-and-suspenders SSH-specific guarantee:
# it must not depend on SSH's own state.
PermitRootLogin no
EOF

    systemctl enable --now sshd.service
else
    # Defensive even though Arch doesn't auto-enable sshd: matches
    # the same policy exactly, and is a no-op if openssh isn't installed or
    # sshd was never enabled.
    systemctl disable --now sshd.service 2>/dev/null || true
fi

touch "$MARKER"
echo "sobarch-firstboot: security baseline applied."
notify_user normal "sobarch: security baseline" "Security baseline applied." "$id" >/dev/null
