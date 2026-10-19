#!/usr/bin/env bash
# Applies the security baseline: default-deny nftables firewall, locked root
# account, and SSH only if enabled in the TUI. MARKER stays unwritten on
# failure so the next boot retries.

set -euo pipefail

MARKER="/var/lib/sobarch/security-baseline-applied"
SSH_FLAG="/etc/sobarch/ssh-enabled"

# md-shield_lock
GLYPH=$'\U000F099D'
source /usr/local/lib/sobarch/notify-user.sh

id=0
trap 'rc=$?; [[ $rc -eq 0 ]] || notify_user critical "sobarch: security baseline failed" \
    "Check: journalctl -u sobarch-firstboot-security.service" "$id"; exit $rc' EXIT

mkdir -p "$(dirname "$MARKER")"
id=$(notify_user normal "sobarch: security baseline" "Applying the security baseline...")

# Absent defaults to disabled.
ssh_enabled="false"
if [[ -f "$SSH_FLAG" ]]; then
    ssh_enabled="$(<"$SSH_FLAG")"
fi

echo "sobarch-firstboot: locking the root account..."
id=$(notify_user normal "sobarch: security baseline" "Locking the root account..." "$id")
passwd -l root

# ly's PAM files still reference pam_gnome_keyring.so, which isn't installed,
# so the keyring never unlocks at login and Secret Service clients (e.g.
# Chromium) hang on an unlock prompt.
echo "sobarch-firstboot: wiring oo7 into ly's PAM stack..."
id=$(notify_user normal "sobarch: security baseline" "Wiring oo7 into the login PAM stack..." "$id")

for pam_file in /etc/pam.d/ly /etc/pam.d/ly-autologin; do
    sed -i 's/pam_gnome_keyring\.so/pam_oo7.so/g' "$pam_file"
done

# pam_oo7 forks oo7-daemon itself if it isn't running, then gives up before
# its socket exists, discarding the password. Start it at login instead.
# --global because no user session exists yet at first boot.
echo "sobarch-firstboot: enabling oo7-daemon.service so it's already running by login..."
id=$(notify_user normal "sobarch: security baseline" "Enabling the oo7 keyring daemon..." "$id")
systemctl --global enable oo7-daemon.service

# systemd already grants power actions to active sessions, but a session
# started without full display-manager integration may not resolve as active
# to polkit. Wheel members can sudo anyway, so this crosses no new boundary.
echo "sobarch-firstboot: installing the polkit power rule..."
id=$(notify_user normal "sobarch: security baseline" "Installing the polkit power rule..." "$id")

mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/46-sobarch-power.rules <<'EOF'
// Managed by apply-security-baseline.sh; not reconciled like skel.
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
         action.id == "org.freedesktop.login1.reboot" ||
         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
         action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.suspend-multiple-sessions") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# Based on the ArchWiki "Simple & Safe" nftables example. The LocalSend port
# is always open since it's a required package.
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
# reconciled like skel) to change it.

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
# Root is also locked with passwd -l; this keeps SSH from ever allowing it.
PermitRootLogin no
EOF

    systemctl enable --now sshd.service
else
    # Defensive; a no-op if sshd was never installed or enabled.
    systemctl disable --now sshd.service 2>/dev/null || true
fi

touch "$MARKER"
echo "sobarch-firstboot: security baseline applied."
notify_user critical "sobarch: security baseline" "Security baseline applied." "$id" >/dev/null
