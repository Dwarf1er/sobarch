#!/usr/bin/env bash
# Installs one optional package from the curated profile list
# (/usr/share/sobarch/profiles.txt), not arbitrary repo or AUR packages.

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
mapfile -t installed < <(pacman -Qq "${names[@]}" 2>/dev/null)
declare -A is_installed
for name in "${installed[@]}"; do is_installed["$name"]=1; done

menu_reset
for pass in available installed; do
    for name in "${names[@]}"; do
        base="${name%-bin}"
        base="${base%-git}"
        if [[ "$pass" == available && -z "${is_installed[$name]:-}" ]]; then
            menu_add "$name" "$name" "$name,$base,package.svg" \
                "${pkg_profile[$name]}$([[ "${pkg_is_aur[$name]}" == 1 ]] && echo " · AUR")"
        elif [[ "$pass" == installed && -n "${is_installed[$name]:-}" ]]; then
            menu_add "$name" "$name" "$name,$base,package.svg" "installed"
        fi
    done
done

menu_show install "${#installed[@]} of ${#names[@]} installed" || exit 0
choice="$MENU_ID"

if [[ -n "${is_installed[$choice]:-}" ]]; then
    menu_notify "$choice is already installed."
    exit 0
fi

# An AUR build can take minutes, so hand off and close every menu level.
if [[ "${pkg_is_aur[$choice]}" == 1 ]]; then
    menu_progress "Installing $choice..." "$choice installed." pkexec /usr/local/lib/sobarch/aur-sync.sh "$choice" ||
        menu_notify "Check /var/log/sobarch/aur-sync.log for the full build output." critical
else
    menu_progress "Installing $choice..." "$choice installed." pkexec pacman -S --needed --noconfirm "$choice"
fi
menu_done
