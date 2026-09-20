+++
title = "Keybindings"
description = "Every window, workspace, and media shortcut, plus the on-screen cheat sheet."
weight = 20
template = "docs/page.html"

[extra]
lead = "Every real bind is tagged directly in the Hyprland config it's defined in, so the on-screen cheat sheet can't drift far from what's actually bound."
toc = true
+++

## General

| Keybind | Action |
| --- | --- |
| `Super+T` | Open terminal |
| `Super+C` | Close focused window |
| `Super+M` | Exit the Hyprland session |
| `Super+E` | Open file manager |
| `Super+B` | Open browser |
| `Super+V` | Toggle floating |
| `Super+F` | Toggle fullscreen |
| `Super+Shift+T` | Toggle split direction |
| `Super+Ctrl+L` | Lock screen |
| `Super+P` | Pick a color, copied to the clipboard |
| `Super+D` | Toggle do-not-disturb |

## Menus

| Keybind | Action |
| --- | --- |
| `Super` (tap) | Open the [main menu](../menu-system/) |
| `Super+A` | Open the audio menu |
| `Super+N` | Open the network menu |
| `Super+Shift+B` | Open the Bluetooth menu |
| `Super+Shift+F` | Open the firmware menu |
| `Super+/` | Show this cheat sheet |

## Windows and workspaces

| Keybind | Action |
| --- | --- |
| `Super+H`/`J`/`K`/`L` | Focus window left/down/up/right |
| `Super+Shift+H`/`J`/`K`/`L` | Move window left/down/up/right |
| `Super+0`-`9` | Switch to workspace N |
| `Super+Shift+0`-`9` | Move window to workspace N |
| `Super+Scroll` | Next/previous workspace |
| `Super+Drag` (left button) | Move window |
| `Super+Drag` (right button) | Resize window |

## Screenshots and capture

| Keybind | Action |
| --- | --- |
| `Print Screen` | Screenshot the full output to the clipboard |
| `Super+S` | Screenshot the full output to a file and the clipboard, without grabbing keyboard focus (region capture below does, since it shells out to `slurp`; this doesn't) |
| `Super+Shift+S` | Screenshot a region to the clipboard |
| `Super+O` | OCR a screen region to the clipboard |
| `Super+Shift+O` | Scan a QR code or barcode in a region to the clipboard |

## Media and volume

| Keybind | Action |
| --- | --- |
| `Volume Up`/`Volume Down` | Raise/lower volume 5% |
| `Mute` | Toggle mute |
| `Mic Mute` | Toggle mic mute |
| `Brightness Up`/`Brightness Down` | Raise/lower brightness 10% |
| `Media Next`/`Media Previous` | Skip track |
| `Media Play/Pause` | Play or pause |

## The cheat sheet

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/keybindings-cheatsheet.webp" width="1366" height="768" alt="The on-screen keybindings cheat sheet, opened with Super+/">
</figure>

`Super+/` opens a read-only fuzzel list built by grepping the
Hyprland config for `-- kb: <combo> | <description>` comments, one per
real bind, so the list can't list a bind that doesn't exist or omit
one that does. It has a short manual tail for fuzzel's own vim-style
navigation keys (`Ctrl+J`/`Ctrl+K` to move between entries,
`Ctrl+H`/`Ctrl+L` to move the cursor, `Ctrl+D`/`Ctrl+U` to page), since
those come from fuzzel's own config and have no Hyprland bind to tag.
