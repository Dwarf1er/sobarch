#!/usr/bin/env bash
# Lets Docker's bridge traffic through the baseline firewall's forward chain
# (policy drop), adds wheel members to the docker group and enables the
# socket. Idempotent; run by the docker install pacman hook and by
# apply-security-baseline.sh.

set -euo pipefail

CONF="/etc/nftables.conf"
FWD_ANCHOR='hook forward priority 0; policy drop;'

# Wheel members can already sudo, so docker's root-equivalent group crosses
# no new boundary. Effective at their next login.
IFS=, read -ra wheel_users < <(getent group wheel | cut -d: -f4)
for user in "${wheel_users[@]}"; do
    usermod -aG docker "$user"
done

systemctl enable docker.socket

[[ -f "$CONF" ]] || exit 0

if ! grep -q 'docker0' "$CONF"; then
    sed -i "/$FWD_ANCHOR/a\\
        ct state established,related accept\\
        iifname { \"docker0\", \"br-*\" } accept" "$CONF"
fi

# Add live too rather than reloading: the config's flush ruleset would wipe
# rules Docker has already loaded.
if systemctl -q is-active nftables.service &&
    ! nft list chain inet filter forward | grep -q 'docker0'; then
    nft add rule inet filter forward ct state established,related accept
    nft add rule inet filter forward iifname '{ "docker0", "br-*" }' accept
fi
