+++
title = "Menu System"
description = "What Super opens, and where each entry leads."
weight = 10
template = "docs/page.html"

[extra]
lead = "Bare Super opens one picker rather than a full application list, with real icons resolved through fuzzel's own icon protocol."
toc = true
+++

Pressing `Super` on its own opens a `fuzzel` picker:

| Entry | What it opens |
| --- | --- |
| **System** | Audio, network, and Bluetooth (also reachable directly via `Super+A`, `Super+N`, `Super+Shift+B`, and from waybar's own status module), plus firmware (`fwupdmgr`: check for updates, install updates, list devices; also reachable via `Super+Shift+F`). |
| **Sobarch** | **Update Config** / **Review Conflicts** (see [Updating Your Config](../updating-config/)), **Install** (see [Software Profiles](../../installer/software-profiles/)), **Themes** (see [Theming](../theming/)), **Wallpaper** (see [Wallpaper](../wallpaper/)), **Refresh Rescue ISO** (see [Rescue Media](../../installer/rescue-media/)), and **Docs**, which opens this site. |
| **Keybinds** | A read-only cheat sheet of every bind; see [Keybindings](../keybindings/). |
| **Power** | Lock, Logout, Suspend, Reboot, Shutdown; see the table below. |
| **Apps** | The regular application list, one level in. |

## Power

| Action | Command |
| --- | --- |
| Lock | `hyprlock` |
| Logout | `hyprctl dispatch 'hl.dsp.exit()'` |
| Suspend | `systemctl suspend` |
| Reboot | `systemctl reboot` |
| Shutdown | `systemctl poweroff` |

Each row's icon is a real icon, not a font glyph: fuzzel's dmenu mode
resolves icon names/paths the same way Rofi does, falling back to a
generic icon for anything the configured icon theme doesn't cover.
