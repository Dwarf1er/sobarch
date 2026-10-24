#!/usr/bin/env bash
# Root helper behind the VPN menu's server half: a single WireGuard
# interface (wg0) on a private 10.8.0.0/24, one peer per device. Run through
# pkexec.
#
#   wireguard-server.sh init HOST        create the server for public address HOST
#   wireguard-server.sh add NAME         add a device, print its client config
#   wireguard-server.sh remove NAME      remove a device
#   wireguard-server.sh list             "NAME<TAB>ADDRESS" per device
#   wireguard-server.sh status           on | off | none
#
# The menu reads wireguard-endpoint and wireguard-devices under /etc/sobarch.
#   wireguard-server.sh on | off         start or stop the server
#   wireguard-server.sh endpoint [HOST]  show or change the public address
#   wireguard-server.sh teardown         delete the server and close the port

set -euo pipefail
umask 077

WG_DIR="${WG_DIR:-/etc/wireguard}"
# World-readable, no secrets: lets the VPN menu show state without pkexec.
STATE_DIR="${STATE_DIR:-/etc/sobarch}"
IFACE="wg0"
CONF="$WG_DIR/$IFACE.conf"
ENDPOINT_FILE="$STATE_DIR/wireguard-endpoint"
DEVICES_FILE="$STATE_DIR/wireguard-devices"
SUBNET="10.8.0"
PORT="51820"
FIREWALL="$(dirname "$(readlink -f "$0")")/firewall-open.sh"

die() { echo "$*" >&2; exit 1; }

need_server() { [[ -f "$CONF" ]] || die "No WireGuard server is set up."; }

# Applies peer changes to a running interface without dropping connections.
reload_live() {
    wg show "$IFACE" >/dev/null 2>&1 || return 0
    wg syncconf "$IFACE" <(wg-quick strip "$CONF")
}

normalize_endpoint() {
    local host="$1"
    [[ "$host" =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || die "Enter a hostname or IPv4 address."
    [[ "$host" == *:* ]] || host="$host:$PORT"
    echo "$host"
}

server_public_key() { sed -n 's/^PrivateKey = //p' "$CONF" | wg pubkey; }

next_address() {
    local last
    last=$(sed -n "s|^AllowedIPs = $SUBNET\.\([0-9]*\)/32|\1|p" "$CONF" | sort -n | tail -n1)
    echo "$((${last:-1} + 1))"
}

write_state() {
    mkdir -p "$STATE_DIR"
    (umask 022; cmd_list >"$DEVICES_FILE.new" && mv "$DEVICES_FILE.new" "$DEVICES_FILE")
}

cmd_init() {
    [[ -f "$CONF" ]] && die "A WireGuard server already exists."
    local endpoint
    endpoint=$(normalize_endpoint "${1:?public address required}")
    mkdir -p "$WG_DIR"
    chmod 700 "$WG_DIR"
    cat >"$CONF" <<EOF
[Interface]
Address = $SUBNET.1/24
ListenPort = $PORT
PrivateKey = $(wg genkey)
EOF
    mkdir -p "$STATE_DIR"
    (umask 022; echo "$endpoint" >"$ENDPOINT_FILE")
    write_state
    "$FIREWALL" open wireguard
    systemctl enable --now "wg-quick@$IFACE.service"
}

cmd_add() {
    need_server
    local name="${1:?device name required}" key pub psk n
    [[ "$name" =~ ^[a-z0-9-]{1,15}$ ]] || die "Use 1-15 lowercase letters, digits or dashes."
    grep -qxF "# sobarch-peer: $name" "$CONF" && die "A device named '$name' already exists."
    n=$(next_address)
    ((n <= 254)) || die "No free addresses left."
    key=$(wg genkey)
    pub=$(wg pubkey <<<"$key")
    psk=$(wg genpsk)
    cat >>"$CONF" <<EOF

# sobarch-peer: $name
[Peer]
PublicKey = $pub
PresharedKey = $psk
AllowedIPs = $SUBNET.$n/32
EOF
    write_state
    reload_live
    cat <<EOF
[Interface]
PrivateKey = $key
Address = $SUBNET.$n/32

[Peer]
PublicKey = $(server_public_key)
PresharedKey = $psk
Endpoint = $(<"$ENDPOINT_FILE")
AllowedIPs = $SUBNET.1/32
PersistentKeepalive = 25
EOF
}

cmd_remove() {
    need_server
    local name="${1:?device name required}" tmp
    grep -qxF "# sobarch-peer: $name" "$CONF" || die "No device named '$name'."
    tmp=$(mktemp "$WG_DIR/.wg0.XXXXXX")
    awk -v marker="# sobarch-peer: $name" 'BEGIN { RS = ""; ORS = "\n\n" } index($0, marker) != 1' "$CONF" >"$tmp"
    mv "$tmp" "$CONF"
    write_state
    reload_live
}

cmd_list() {
    [[ -f "$CONF" ]] || return 0
    awk -v subnet="$SUBNET" '
        /^# sobarch-peer: / { name = substr($0, 17) }
        /^AllowedIPs = / && name != "" { sub(/^AllowedIPs = /, ""); sub(/\/32$/, ""); print name "\t" $0; name = "" }
    ' "$CONF"
}

cmd_status() {
    if [[ ! -f "$DEVICES_FILE" ]]; then
        echo none
    elif systemctl -q is-active "wg-quick@$IFACE.service"; then
        echo on
    else
        echo off
    fi
}

cmd_endpoint() {
    need_server
    if [[ -n "${1:-}" ]]; then
        local endpoint
        endpoint=$(normalize_endpoint "$1")
        (umask 022; echo "$endpoint" >"$ENDPOINT_FILE")
    else
        cat "$ENDPOINT_FILE"
    fi
}

cmd_teardown() {
    systemctl disable --now "wg-quick@$IFACE.service" 2>/dev/null || true
    "$FIREWALL" close wireguard
    rm -f "$CONF" "$ENDPOINT_FILE" "$DEVICES_FILE"
}

case "${1:-}" in
    init) cmd_init "${2:-}" ;;
    add) cmd_add "${2:-}" ;;
    remove) cmd_remove "${2:-}" ;;
    list) cmd_list ;;
    status) cmd_status ;;
    on) need_server; systemctl enable --now "wg-quick@$IFACE.service" ;;
    off) need_server; systemctl disable --now "wg-quick@$IFACE.service" ;;
    endpoint) cmd_endpoint "${2:-}" ;;
    teardown) cmd_teardown ;;
    *) die "usage: wireguard-server.sh init|add|remove|list|status|on|off|endpoint|teardown" ;;
esac
