#!/usr/bin/env bash
# Writes the redacted diagnostic report to $HOME for attaching to a bug report.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: diagnostic report"
MENU_ICON="stethoscope.svg"

out=$(sobarch doctor --write 2>&1) || { menu_notify "${out:-Report failed.}" critical; menu_done; }
menu_notify "$(tail -n 2 <<<"$out" | head -n 1)"
menu_done
