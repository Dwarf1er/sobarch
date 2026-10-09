+++
title = "Status Bar"
description = "What each waybar module shows and what clicking it does."
weight = 100
template = "docs/page.html"

[extra]
lead = "A floating bar at the top of every screen, colored by the active theme, with a few clickable modules that open the same menus as the shortcuts."
toc = true
+++

The bar is [waybar](https://github.com/Alexays/Waybar). Workspaces sit on
the left, the clock in the middle, and status modules on the right.

| Module | Shows | Click |
| --- | --- | --- |
| Workspaces | Your workspaces, with the active one highlighted | Switch to it |
| Clock | Day, date, and time. Hover for a calendar of the whole year, scroll to move through months | None |
| Input method | `EN`, `FR`, or `한` (see [Input Methods](../input-methods/)) | Toggle input method |
| Do not disturb | A bell icon, only while it's on | Toggle [do-not-disturb](../notifications/) |
| Network | Wi-Fi or Ethernet state; hover for the SSID and signal | Open the network menu |
| Bluetooth | Power state, and how many devices are connected | Open the Bluetooth menu |
| Volume | Output volume, shown muted when it is | Left click: audio menu. Right click: toggle mute. Scroll: volume up and down 5% |
| Battery | Charge percent, with warning and critical colors at 20% and 10% | None |

The menus are described in [Menu System](../menu-system/). Changing the
[theme](../theming/) restarts the bar so its colors update, including
the calendar colors in the tooltip.
