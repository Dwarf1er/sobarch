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

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/menu-system-root.webp" width="1366" height="768" alt="The root Super menu, listing System, Sobarch, Keybinds, Power, and Apps">
</figure>

| Entry | What it opens |
| --- | --- |
| **System** | Audio, network, and Bluetooth (also reachable directly via `Super+A`, `Super+N`, `Super+Shift+B`, and from waybar's own status module), plus firmware (`fwupdmgr`: check for updates, install updates, list devices; also reachable via `Super+Shift+F`). |
| **Sobarch** | **Update System** / **Review Conflicts** (see [Updating Your System](../updating-system/)), **Install** (see [Software Profiles](../../installer/software-profiles/)), **Themes** (see [Theming](../theming/)), **Wallpaper** (see [Wallpaper](../wallpaper/)), **Default Apps** (pick a file type, then which installed app opens it), **Refresh Rescue ISO** (see [Rescue Media](../../installer/rescue-media/); only listed when rescue media was set up at install), and **Docs**, which opens this site. |
| **Keybinds** | A read-only cheat sheet of every bind; see [Keybindings](../keybindings/). |
| **Power** | Lock, Logout, Suspend, Reboot, Shutdown; see the table below. |
| **Apps** | The regular application list, one level in. |

Most of the Sobarch submenu's actions also exist as a `sobarch`
command for terminals and SSH; see [The sobarch Command](../sobarch-command/).

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/menu-system-sobarch.webp" width="1366" height="768" alt="The Sobarch submenu, listing Update System, Install, Themes, Wallpaper, Refresh Rescue ISO, and Docs">
</figure>

## System submenus

Each of these also has its own shortcut. Audio, Network, and Bluetooth
reopen after each action so you can chain several; Escape closes them.

| Menu | Entries |
| --- | --- |
| **Audio** (`Super+A`) | Toggle output mute, toggle mic mute, volume up/down 5%, switch output device, switch input device, per-app volume (mute, unmute, up, down). |
| **Network** (`Super+N`) | Wi-Fi networks (scan, pick, enter a password if the network is new), toggle Wi-Fi, disconnect, forget a saved network, copy your IP address, and share the current Wi-Fi as a QR code. |
| **Bluetooth** (`Super+Shift+B`) | Toggle power, scan and connect (pairs and trusts the device), paired devices (connect, disconnect, remove), disconnect. |
| **Firmware** (`Super+Shift+F`) | Check for updates, install updates, list devices, all through `fwupdmgr`. |

## Power

Logout, Suspend, Reboot, and Shutdown ask for confirmation first; Lock does not.

| Action | Command |
| --- | --- |
| Lock | `hyprlock` |
| Logout | `hyprctl dispatch exit` |
| Suspend | `systemctl suspend` |
| Reboot | `systemctl reboot` |
| Shutdown | `systemctl poweroff` |

Each row's icon is a real icon, not a font glyph: fuzzel's dmenu mode
resolves icon names/paths the same way Rofi does, falling back to a
generic icon for anything the configured icon theme doesn't cover.

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/menu-system-power.webp" width="1366" height="768" alt="The Power submenu, listing Lock, Logout, Suspend, Reboot, and Shutdown">
</figure>

What Lock shows, `hyprlock`, themed to match the active color scheme:

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/hyprlock.webp" width="1481" height="931" alt="The hyprlock screen, themed to match the active color scheme">
</figure>
