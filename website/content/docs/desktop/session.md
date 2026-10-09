+++
title = "Session & Lock Screen"
description = "What starts with your session, when the screen locks, and what the lock screen shows."
weight = 120
template = "docs/page.html"

[extra]
lead = "A small, predictable set of background programs, and an idle timer that locks the screen and turns the display off."
toc = true
+++

## What starts at login

Hyprland starts these for you each time:

- `waybar` (the [status bar](../status-bar/)), `mako` (the
  [notifications](../notifications/)), `hyprpaper` (the
  [wallpaper](../wallpaper/)), `hypridle`, and `udiskie`.
- `fcitx5` for [input methods](../input-methods/) and the polkit agent.
- `xdg-user-dirs-update`, which creates folders such as Documents and
  Downloads if they don't exist.
- The [snapshot boot check](../notifications/), which does nothing
  unless you booted a snapshot.
- tinty: on a first login it downloads the color schemes (this needs a
  network, and is retried at the next login if it fails), then it
  re-applies your last scheme.

## Idle and lock

After five minutes without input the screen locks with `hyprlock` and the
display turns off; any input turns it back on. Lock manually with
`Super+Ctrl+L` or from the Power menu.

The lock screen shows the time and date, the sobarch mark, your username,
and a password field. Its colors follow the active
[theme](../theming/), and the field changes color on a wrong password.

## Local overrides

Hyprland reads two optional files that sobarch never ships or overwrites,
so they're the safe place for machine-specific settings:

- `~/.config/hypr/local.lua` for monitor layout and workspace pinning.
  Without it, every monitor uses its preferred mode, placed automatically.
- `~/.config/hypr/nvidia.lua`, written on installs where an NVIDIA GPU was
  detected, holding the environment variables that GPU needs.

Touchpads use natural scrolling and the mouse uses a flat acceleration
profile; focus follows the mouse. Windows have 5 px gaps, 10 px rounded
corners, and no animations, blur, or shadows.
