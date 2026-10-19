#!/bin/bash
# Firmware: every device fwupd knows a version for, with its update
# status in the header and a details view per device. Everything shown
# comes from fwupd's local metadata cache (fast, offline); only "Check
# for Updates" touches the network.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: firmware"
MENU_ICON="cpu.svg"

# NAME, VERSION, UPDATABLE, VENDOR, SUMMARY per device, \037-separated
# (not tabs: read collapses runs of whitespace IFS, so an empty vendor
# would shift every field after it),
# from get-devices' tree output (one "├─Name:" line per device, then
# indented "Key: value" lines). Devices without a version (monitors
# hanging off a GPU, mostly) are left out: nothing to show or update.
devices() {
    timeout 15 fwupdmgr get-devices --no-unreported-check 2>/dev/null | awk '
        function flush() {
            if (name != "" && version != "") print name "\037" version "\037" updatable "\037" vendor "\037" summary
            name = version = vendor = summary = ""; updatable = 0
        }
        /[├└]─.*:$/ { flush(); n = $0; sub(/^.*[├└]─/, "", n); sub(/:$/, "", n); name = n; next }
        /Current version:/ { v = $0; sub(/.*Current version: */, "", v); version = v }
        /Vendor:/ { v = $0; sub(/.*Vendor: */, "", v); sub(/ \(.*\)$/, "", v); vendor = v }
        /Summary:/ { v = $0; sub(/.*Summary: */, "", v); summary = v }
        /• Updatable$/ { updatable = 1 }
        END { flush() }'
}

# Monochrome set icons only, so these rows match every other menu
# rather than mixing in full-colour icon-theme ones.
device_icon() {
    case "$1" in
        *Processor*|*CPU*|*Radeon*|*GeForce*|*Graphics*|*GPU*) echo "cpu.svg" ;;
        TPM*) echo "lock.svg" ;;
        *) echo "devices.svg" ;;
    esac
}

# Read-only; Enter does nothing, Escape goes back.
device_details() {
    local name="$1" version="$2" updatable="$3" vendor="$4" summary="$5"
    menu_reset
    menu_add version "Version" "" "$version"
    [ -n "$vendor" ] && menu_add vendor "Vendor" "" "$vendor"
    [ -n "$summary" ] && menu_add summary "Summary" "" "$summary"
    menu_add updatable "Updatable" "" "$([ "$updatable" = 1 ] && echo yes || echo no)"
    while menu_show firmware "$name"; do :; done
}

selected=""
while :; do
    # get-updates: 0 = updates available, 2 = nothing to do.
    timeout 15 fwupdmgr get-updates --no-unreported-check >/dev/null 2>&1
    case $? in
        0) has_updates=1 mesg="Firmware updates available" ;;
        2) has_updates=0 mesg="Firmware is up to date" ;;
        *) has_updates=0 mesg="Couldn't read update status" ;;
    esac

    mapfile -t rows < <(devices)
    menu_reset
    menu_add check "Check for Updates" refresh.svg
    ((has_updates)) && menu_add install "Install Updates" download.svg "available"
    for i in "${!rows[@]}"; do
        IFS=$'\037' read -r name version _ <<<"${rows[$i]}"
        menu_add "dev$i" "$name" "$(device_icon "$name")" "$version"
    done

    menu_show firmware "$mesg" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        check)
            menu_progress "Checking for firmware updates..." "Firmware metadata refreshed." \
                fwupdmgr refresh --force
            ;;
        install)
            confirm "Install all available firmware updates? Some devices restart, or need a reboot to finish." Install &&
                menu_progress "Installing firmware updates..." "Firmware updates installed." fwupdmgr update -y
            ;;
        dev*)
            IFS=$'\037' read -r -a fields <<<"${rows[${MENU_ID#dev}]}"
            device_details "${fields[@]}"
            ;;
    esac
done
