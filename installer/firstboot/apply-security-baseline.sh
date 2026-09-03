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

mkdir -p "$(dirname "$MARKER")"

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
passwd -l root

# Base ruleset from Arch's own "Simple & Safe" nftables example:
# default-drop inbound, always allow loopback and established/related
# traffic, explicit exceptions only for required packages. LocalSend
# (packages/aur/localsend-bin, not yet vendored) is a required
# package, so its port
# is opened unconditionally rather than gated on whether it happens to
# be installed yet. SSH's exception is appended only when enabled.
echo "sobarch-firstboot: installing the nftables baseline ruleset..."

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
