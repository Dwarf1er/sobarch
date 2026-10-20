#!/usr/bin/env bash
# Diagnostic report for bug reports; redacted before it is printed or written.
#
#   doctor.sh              print the report
#   doctor.sh --write      write it to ~/sobarch-doctor-<timestamp>.txt
#
# Runs as the user. Root-only sections are skipped unless sudo works
# without a prompt.

set -uo pipefail

write=false
for arg in "$@"; do
    case "$arg" in
        --write) write=true ;;
        *) echo "doctor.sh: unknown argument '$arg'" >&2; exit 2 ;;
    esac
done

section() { printf '\n== %s ==\n' "$1"; }

# Run a command, noting failure instead of aborting the report.
try() {
    "$@" 2>&1 || echo "(exit status $?: $*)"
}

# Probed once; the probe itself is logged by sudo, so it is filtered from
# the journal sections below.
can_sudo=false
((EUID == 0)) || ! sudo -n true 2>/dev/null || can_sudo=true

root_try() {
    if ((EUID == 0)); then
        try "$@"
    elif $can_sudo; then
        try sudo -n "$@"
    else
        echo "(skipped: needs root: $*)"
    fi
}

collect() {
    echo "sobarch doctor, $(date -u +%Y-%m-%dT%H:%M:%SZ)"

    section "Versions"
    try pacman -Q sobarch-skel sobarch-scripts sobarch-limine-snapshots
    echo "kernel: $(uname -r)"
    if command -v hyprctl >/dev/null; then
        hyprctl version 2>&1 | head -n 1
    else
        echo "hyprctl: not installed"
    fi
    pacman -Q hyprland linux linux-lts nvidia-open-dkms nvidia-580xx-dkms 2>/dev/null

    section "Hardware"
    for f in sys_vendor product_name bios_version; do
        printf '%s: %s\n' "$f" "$(cat "/sys/class/dmi/id/$f" 2>/dev/null)"
    done
    lscpu 2>/dev/null | grep -E '^(Model name|CPU\(s\))'
    grep -E '^(MemTotal|SwapTotal)' /proc/meminfo
    [[ -d /sys/firmware/efi ]] && echo "boot mode: UEFI" || echo "boot mode: BIOS"
    command -v lspci >/dev/null && lspci -nn | grep -Ei 'vga|3d|display|network|ethernet'
    try lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
    command -v hyprctl >/dev/null && hyprctl monitors 2>&1 | grep -E '^Monitor|@|scale' | grep -v availableModes

    section "Failed units (system)"
    try systemctl --failed --no-legend --plain
    section "Failed units (user)"
    try systemctl --user --failed --no-legend --plain

    section "First-boot units"
    for u in packages security skel git rfkill rescue; do
        printf 'sobarch-firstboot-%s: %s\n' "$u" \
            "$(systemctl is-active "sobarch-firstboot-$u.service" 2>&1)"
    done
    for m in /var/lib/sobarch/profile-packages-installed \
        /var/lib/sobarch/security-baseline-applied \
        /var/lib/sobarch/rfkill-unblocked \
        "$HOME/.local/state/sobarch/skel-version" \
        "$HOME/.local/state/sobarch/git-setup-done"; do
        [[ -e "$m" ]] && echo "present: $m" || echo "missing: $m"
    done
    echo "pending conflicts:"
    find "$HOME" -name '*.sobarch-new' -not -path "$HOME/.cache/*" 2>/dev/null | head -n 20

    section "Journal: errors this boot"
    journalctl -b -p err --no-pager -n 60 2>&1 | grep -v ' sudo\[' | tail -n 40
    section "Journal: sobarch units"
    try journalctl -b --no-pager -n 40 -u 'sobarch-*'
    section "Journal: sobarch user units"
    try journalctl --user -b --no-pager -n 20 -u 'sobarch-*'

    section "aur-sync log (tail)"
    tail -n 40 /var/log/sobarch/aur-sync.log 2>&1
    section "Last pacman transactions"
    grep -E '\] \[ALPM\] (upgraded|installed|removed)' /var/log/pacman.log 2>/dev/null | tail -n 15

    section "Snapshots"
    root_try snapper -c root list --columns number,type,date,description
    try findmnt -no SOURCE,FSTYPE,OPTIONS /
    root_try btrfs filesystem usage -T /

    section "Boot"
    conf=/boot/EFI/BOOT/limine.conf
    if [[ -r "$conf" ]]; then
        echo "limine.conf: $(grep -c '^ *//' "$conf") snapshot entries"
        grep -v '^ *//' "$conf" | grep -E '^(/|timeout|default_entry|term_)' | head -n 20
    else
        echo "limine.conf: not readable at $conf"
    fi

    section "Security"
    printf 'ssh-enabled: %s\n' "$(cat /etc/sobarch/ssh-enabled 2>/dev/null)"
    printf 'nftables: %s\n' "$(systemctl is-active nftables 2>&1)"
    printf 'root account: %s\n' "$(passwd -S root 2>/dev/null | awk '{print $2}')"
}

# Strip identifying values from stdin.
redact() {
    local host user
    host="$(uname -n)"
    user="$(id -un)"
    local -a args=(
        -E
        # MAC addresses
        -e 's/\b([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b/<mac>/g'
        # IPv4
        -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]+)?\b/<ip>/g'
        # IPv6: compressed (::) or full eight groups; never bare times like 22:44:01
        -e 's/\b([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}\b/<ip6>/g'
        -e 's/\b([0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{0,4}::([0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{0,4}\b/<ip6>/g'
        # Serial numbers and UUIDs
        -e 's/([Ss]erial[A-Za-z _#]*[:=] *)[^ ]+/\1<serial>/g'
        -e 's/\b[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\b/<uuid>/g'
    )
    [[ -n "$host" && "$host" != localhost ]] && args+=(-e "s/$(sed_escape "$host")/<hostname>/g")
    [[ "$user" != root ]] && args+=(-e "s/$(sed_escape "$user")/<user>/g")
    sed "${args[@]}"
}

sed_escape() { printf '%s' "$1" | sed -e 's/[][\.*^$/&+?(){}|-]/\\&/g'; }

report="$(collect 2>&1 | redact)"

if $write; then
    out="$HOME/sobarch-doctor-$(date +%Y%m%d-%H%M%S).txt"
    (umask 077; printf '%s\n' "$report" >"$out")
    echo "Wrote $out"
    echo "Review it, then attach it to your bug report."
else
    printf '%s\n' "$report"
fi
