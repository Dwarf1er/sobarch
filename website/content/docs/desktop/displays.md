+++
title = "Displays"
description = "Resolution, refresh rate, scale, rotation, position, mirroring and enabling monitors from the System menu."
weight = 35
template = "docs/page.html"

[extra]
lead = "Arrange monitors from a menu instead of editing a Lua file. Every change is applied live and reverts by itself unless you confirm it."
toc = true
+++

Open **System, Displays**. Each connected monitor is a row showing its
current mode, scale and rotation; pick one for its settings.

| Setting | What it does |
| --- | --- |
| **Resolution & Refresh** | Every mode the monitor reports, deduplicated. |
| **Scale** | 1x, 1.25x, 1.5x, 1.75x or 2x. |
| **Rotation** | Normal, 90°, 180° or 270°. |
| **Position** | Right of, left of, above or below another monitor. When the two edges don't line up you're asked whether to align the top/left, center or bottom/right. The menu works out the pixel offsets. |
| **Mirror** | Show another monitor's picture, or stop mirroring. |
| **Disable / Enable** | Turn a monitor off or back on. The last active monitor can't be disabled. |

After each change the screen is reloaded and a **Keep these display
settings?** prompt appears. If you don't confirm within 15 seconds, for
example because the screen went blank, the previous settings are
restored.

## Where it's saved

Choices are written to `~/.config/hypr/monitors.lua`, regenerated from
the live layout after every change, so don't hand-edit it. Rules are
keyed by the monitor's description (make, model and serial) rather than
the port, so they follow a monitor across ports and docks, and rules
for monitors that aren't plugged in are kept for when they return.
Skel updates never touch the file.

Hyprland's built-in rule still applies to any monitor not listed, so a
newly connected monitor works with no setup.

**Reset to Automatic** (shown once the file exists) deletes it.

## Hand-written rules

`~/.config/hypr/local.lua` is loaded after `monitors.lua`, so monitor
rules there take precedence, and the menu warns you at the top while
`local.lua` defines any. Put workspace pinning and anything the menu
doesn't cover in `local.lua`.

## Limits

- Changing a monitor's size, scale or rotation doesn't move its
  neighbours, so layouts can overlap until you fix them with **Position**.
- Mirroring refers to the other monitor by its port name, which can
  change across reconnects.
- No Auto scale choice: use **Reset to Automatic** to go back to it.
