#!/usr/bin/env bash
# Installs a single optional package, individually, bypassing profile
# boundaries -- the same escape hatch Omarchy's own Install menu offers
# (pick one app, not a whole bundle), adapted to fuzzel/dmenu's flat-list
# shape instead of Omarchy's nested Quickshell/QML tree. Deliberately
# scoped to the same package set setup-profile-menu.sh used to draw
# from (every profile's packages, deduped), not a live search over all
# of Arch's official repos or arbitrary AUR: those packages are the ones
# this project has actually reviewed and vendored, and going further
# would turn this into a general-purpose package-manager frontend, which
# is not what sobarch is for (decision 3 already rejects arbitrary AUR
# installs for the same reason).
#
# Reads /usr/share/sobarch/profiles.txt, the same data file the old
# profile-bundle menu used (see git history for its format and
# regeneration note).
#
# Each row's leading glyph is a real icon, not a nerd-font character:
# fuzzel's dmenu mode speaks rofi's extended dmenu protocol (\0icon\x1f
# after the display text, comma-separated fallback list, tried in order
# until one resolves), which is enough for a real app icon (falling back
# to a plain generic one for anything the configured icon theme doesn't
# ship a match for), but not for indicating install state: fuzzel's
# dmenu mode has no per-row styling at all (only global colors, no
# dimming/markup), and an icon theme like Papirus ships icons for most
# popular apps as static theme files regardless of whether that
# package is actually installed, so icon presence/absence never
# tracked install state either (confirmed directly: every row rendered
# identically regardless of install status). Already-installed
# packages are filtered out of the list entirely instead, the one
# distinction fuzzel's flat dmenu list can actually make.
set -euo pipefail

DATA_FILE="/usr/share/sobarch/profiles.txt"
AUR_SYNC="/usr/local/lib/sobarch/aur-sync.sh"

if [[ ! -r "$DATA_FILE" ]]; then
    notify-send -u critical "sobarch: install package" "$DATA_FILE not found; is sobarch-skel installed?"
    exit 1
fi

declare -A pkg_is_aur
while IFS='|' read -r _ _ pkgs; do
    [[ -n "$pkgs" ]] || continue
    IFS=',' read -ra entries <<< "$pkgs"
    for entry in "${entries[@]}"; do
        if [[ "$entry" == *:aur ]]; then
            pkg_is_aur["${entry%:aur}"]=1
        else
            pkg_is_aur["$entry"]="${pkg_is_aur[$entry]:-0}"
        fi
    done
done < "$DATA_FILE"

mapfile -t names < <(
    for name in "${!pkg_is_aur[@]}"; do
        pacman -Q "$name" >/dev/null 2>&1 && continue
        printf '%s\n' "$name"
    done | sort
)

if ((${#names[@]} == 0)); then
    notify-send "sobarch: install package" "Every known package is already installed."
    exit 0
fi

choice=$(
    for name in "${names[@]}"; do
        printf '%s\0icon\x1f%s,package-x-generic\n' "$name" "$name"
    done | fuzzel --dmenu --prompt "install package: "
)
[[ -n "${choice:-}" && -n "${pkg_is_aur[$choice]:-}" ]] || exit 0

notify-send "sobarch: install package" "Installing $choice..."

if [[ "${pkg_is_aur[$choice]}" == 1 ]]; then
    result=0
    pkexec "$AUR_SYNC" "$choice" || result=$?
else
    result=0
    pkexec pacman -S --needed --noconfirm "$choice" || result=$?
fi

if ((result != 0)); then
    notify-send -u critical "sobarch: install package" \
        "$choice failed to install; check /var/log/sobarch/aur-sync.log and pacman's own log."
else
    notify-send "sobarch: install package" "$choice installed."
fi
