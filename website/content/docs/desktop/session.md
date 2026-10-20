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
- `fcitx5` for [input methods](../input-methods/) and the polkit agent
  (`hyprpolkitagent`).
- `gsettings` values for the GTK theme (`adw-gtk3`), dark color scheme,
  and Papirus-Dark icons (see [Appearance and Apps](../appearance-and-apps/)).
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

The screen also locks before the system suspends (from the Power menu,
the lid, or anywhere else), so it is already locked when you resume, and
the display is switched back on after the wake-up.

The lock screen shows the time and date, the sobarch mark, your username,
and a password field. Its colors follow the active
[theme](../theming/), and the field changes color on a wrong password.
Fingerprint unlock is enabled in the lock screen's config: on a machine
with a fingerprint reader and `fprintd`, a finger can be used instead of
typing the password; otherwise `hyprlock` just uses the password. The
installer sets this up for T2 Macs (see [T2 Macs](../../installer/t2-mac/)).

## Local overrides

Hyprland reads two optional files that sobarch never ships or overwrites,
so they're the safe place for machine-specific settings:

- `~/.config/hypr/local.lua` for monitor layout and workspace pinning.
  Without it, every monitor uses its preferred mode, placed automatically.
- `~/.config/hypr/nvidia.lua`, written on installs where an NVIDIA GPU was
  detected, holding the environment variables that GPU needs.

Touchpads use natural scrolling and the mouse uses a flat acceleration
profile; focus follows the mouse. Windows have 5 px gaps, 10 px rounded
corners, and no blur or shadows. Animations are off except a short
fade-out on menus and other overlays, which hides the gap between one
menu level closing and the next opening.
When a monitor is plugged in or removed, the [wallpaper](../wallpaper/)
is re-applied.
