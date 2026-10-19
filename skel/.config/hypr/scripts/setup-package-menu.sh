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
# Each row carries the profile it comes from as its state, so the list
# reads as a small catalog ("steam ... Gaming"); installed packages are
# listed last and marked installed instead of being hidden, now that
# rows have a state column to say so (fuzzel itself has no per-row
# styling to dim them with). Each row's icon is the app's own icon-theme
# entry, falling back to a generic package icon.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

DATA_FILE="/usr/share/sobarch/profiles.txt"
MENU_TITLE="sobarch: install package"
MENU_ICON="download.svg"
MENU_PLACEHOLDER="Search apps"

if [[ ! -r "$DATA_FILE" ]]; then
    menu_notify "$DATA_FILE not found; is sobarch-skel installed?" critical
    exit 1
fi

# First profile listing a package names it; ":aur" marks a vendored AUR
# one, built through aur-sync rather than installed by pacman.
declare -A pkg_is_aur pkg_profile
while IFS='|' read -r _ profile pkgs; do
    [[ -n "$pkgs" ]] || continue
    IFS=',' read -ra entries <<<"$pkgs"
    for entry in "${entries[@]}"; do
        name="${entry%:aur}"
        [[ "$entry" == *:aur ]] && pkg_is_aur["$name"]=1 || pkg_is_aur["$name"]="${pkg_is_aur[$name]:-0}"
        pkg_profile["$name"]="${pkg_profile[$name]:-$profile}"
    done
done <"$DATA_FILE"

mapfile -t names < <(printf '%s\n' "${!pkg_is_aur[@]}" | sort)
# One pacman call for the whole set, not one per package.
mapfile -t installed < <(pacman -Qq "${names[@]}" 2>/dev/null)
declare -A is_installed
for name in "${installed[@]}"; do is_installed["$name"]=1; done

menu_reset
for pass in available installed; do
    for name in "${names[@]}"; do
        if [[ "$pass" == available && -z "${is_installed[$name]:-}" ]]; then
            menu_add "$name" "$name" "$name,package-x-generic" \
                "${pkg_profile[$name]}$([[ "${pkg_is_aur[$name]}" == 1 ]] && echo " · AUR")"
        elif [[ "$pass" == installed && -n "${is_installed[$name]:-}" ]]; then
            menu_add "$name" "$name" "$name,package-x-generic" "installed"
        fi
    done
done

menu_show install "${#installed[@]} of ${#names[@]} installed" || exit 0
choice="$MENU_ID"

if [[ -n "${is_installed[$choice]:-}" ]]; then
    menu_notify "$choice is already installed."
    exit 0
fi

# Hands off to the install and closes every open menu level: a from-source
# AUR build can take minutes, tracked by its own progress notification.
if [[ "${pkg_is_aur[$choice]}" == 1 ]]; then
    menu_progress "Installing $choice..." "$choice installed." sobarch aur-sync "$choice" ||
        menu_notify "Check /var/log/sobarch/aur-sync.log for the full build output." critical
else
    menu_progress "Installing $choice..." "$choice installed." pkexec pacman -S --needed --noconfirm "$choice"
fi
menu_done
