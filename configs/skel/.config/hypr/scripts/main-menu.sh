#!/bin/bash
# Bound to bare Super in place of a raw `fuzzel` call (hyprland.lua's
# `menu` variable). Fuzzel's own native app-launcher mode has no way to
# show a curated set of entries at the top level and fold everything
# else behind one of them (`hide-before-typing` in fuzzel.ini is a
# global on/off, not per-entry), so that folding has to happen here
# instead: this is a plain `--dmenu` picker, and "Apps" is just a
# second, separate `fuzzel` invocation, one level in.

choice=$(printf "%s\n" \
    "󰘮  System" \
    "󰢻  Setup" \
    "󰐦  Power" \
    "󰀻  Apps" \
    | fuzzel --dmenu --prompt "sobarch: ")

case "$choice" in
    "󰘮  System") exec bash "$HOME/.config/hypr/scripts/system-menu.sh" ;;
    "󰢻  Setup") exec bash "$HOME/.config/hypr/scripts/setup-menu.sh" ;;
    "󰐦  Power") exec wlogout ;;
    "󰀻  Apps") exec fuzzel ;;
esac
