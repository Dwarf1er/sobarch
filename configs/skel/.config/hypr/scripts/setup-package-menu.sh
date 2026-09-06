#!/usr/bin/env bash
# Installs a single optional package, individually, bypassing profile
# boundaries -- the same escape hatch Omarchy's own Install menu offers
# (pick one app, not a whole bundle), adapted to fuzzel/dmenu's flat-list
# shape instead of Omarchy's nested Quickshell/QML tree. Deliberately
# scoped to the same package set setup-profile-menu.sh already draws
# from (every profile's packages, deduped), not a live search over all
# of Arch's official repos or arbitrary AUR: those packages are the ones
# this project has actually reviewed and vendored, and going further
# would turn this into a general-purpose package-manager frontend, which
# is not what sobarch is for (decision 3 already rejects arbitrary AUR
# installs for the same reason).
#
# Reads /usr/share/sobarch/profiles.txt, the same data file
# setup-profile-menu.sh uses (see that script's header for its format
# and regeneration note).

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

declare -A label_to_name
labels=()
for name in "${!pkg_is_aur[@]}"; do
    label="󰏖  $name"
    [[ "${pkg_is_aur[$name]}" == 1 ]] && label+=" (AUR)"
    pacman -Q "$name" >/dev/null 2>&1 && label+=" [installed]"
    labels+=("$label")
    label_to_name["$label"]="$name"
done

choice=$(printf '%s\n' "${labels[@]}" | sort | fuzzel --dmenu --prompt "install package: ")
[[ -n "${choice:-}" && -n "${label_to_name[$choice]:-}" ]] || exit 0
name="${label_to_name[$choice]}"

notify-send "sobarch: install package" "Installing $name..."

if [[ "${pkg_is_aur[$name]}" == 1 ]]; then
    result=0
    pkexec "$AUR_SYNC" "$name" || result=$?
else
    result=0
    pkexec pacman -S --needed --noconfirm "$name" || result=$?
fi

if ((result != 0)); then
    notify-send -u critical "sobarch: install package" \
        "$name failed to install; check /var/log/sobarch/aur-sync.log and pacman's own log."
else
    notify-send "sobarch: install package" "$name installed."
fi
