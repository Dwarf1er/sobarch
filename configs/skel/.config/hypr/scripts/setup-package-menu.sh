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
# after the display text, comma-separated fallback list, tried in
# order until one resolves). This is used for two things at once, both
# emergent from the fallback chain rather than any bespoke styling
# fuzzel's dmenu mode has no support for at all (only global colors, no
# per-row dimming/markup):
#   - an already-installed package's own real icon exists on disk and
#     wins the lookup, so it renders in full; one not yet installed
#     falls through to a plain generic icon, which reads as visually
#     muted in practice without this script tracking install state
#     for display purposes at all (pacman -Q is only consulted for the
#     install action itself, further down).
#   - a vendored AUR/custom package that isn't installed yet falls
#     through past its own (not-yet-existing) icon to sobarch's own
#     mark, distinguishing "this is vetted and built by sobarch" from
#     an official-repo package's plain package-x-generic fallback,
#     without a text tag like "(AUR)" cluttering the row.
set -euo pipefail

DATA_FILE="/usr/share/sobarch/profiles.txt"
AUR_SYNC="/usr/local/lib/sobarch/aur-sync.sh"
SOBARCH_ICON="/usr/share/sobarch/sobarch.svg"

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

mapfile -t names < <(printf '%s\n' "${!pkg_is_aur[@]}" | sort)

choice=$(
    for name in "${names[@]}"; do
        if [[ "${pkg_is_aur[$name]}" == 1 ]]; then
            icons="$name,$SOBARCH_ICON,package-x-generic"
        else
            icons="$name,package-x-generic"
        fi
        printf '%s\0icon\x1f%s\n' "$name" "$icons"
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
