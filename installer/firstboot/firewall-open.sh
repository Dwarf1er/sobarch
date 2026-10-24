#!/usr/bin/env bash
# Opens or closes a named firewall exception: a rule file in /etc/nftables.d
# (included by the baseline ruleset, so it survives reboots) plus the live
# rule. Added live rather than reloading, which would wipe Docker's rules.
#
#   firewall-open.sh open|close NAME
#   firewall-open.sh sync NAME PACKAGE   # open if PACKAGE is installed, else close

set -euo pipefail

DIR="${NFT_DROPIN_DIR:-/etc/nftables.d}"

rules_for() {
    case "$1" in
        sunshine)
            echo 'tcp dport { 47984, 47989, 48010 } accept'
            echo 'udp dport { 47998, 47999, 48000, 48010 } accept'
            ;;
        wireguard) echo 'udp dport 51820 accept' ;;
        *) echo "firewall-open: unknown exception '$1'" >&2; return 1 ;;
    esac
}

live() { systemctl -q is-active nftables.service && nft list chain inet filter input >/dev/null 2>&1; }

open_rules() {
    local name="$1" file="$DIR/$1.nft" rule
    rules_for "$name" >/dev/null
    mkdir -p "$DIR"
    rules_for "$name" | sed "s/\$/ comment \"sobarch-$name\"/" >"$file"
    live || return 0
    nft list chain inet filter input | grep -q "sobarch-$name" && return 0
    while read -r rule; do
        nft add rule inet filter input $rule
    done <"$file"
}

close_rules() {
    local name="$1" handle
    rm -f "$DIR/$name.nft"
    live || return 0
    for handle in $(nft -a list chain inet filter input | sed -n "/sobarch-$name/s/.*handle //p"); do
        nft delete rule inet filter input handle "$handle"
    done
}

case "${1:-}" in
    open) open_rules "$2" ;;
    close) close_rules "$2" ;;
    sync)
        if pacman -Q "$3" >/dev/null 2>&1; then
            open_rules "$2"
        else
            close_rules "$2"
        fi
        ;;
    *) echo "usage: firewall-open.sh open|close NAME | sync NAME PACKAGE" >&2; exit 2 ;;
esac
