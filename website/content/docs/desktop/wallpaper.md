+++
title = "Wallpaper"
description = "Picking a wallpaper, and how an SVG one recolors itself to match your theme."
weight = 40
template = "docs/page.html"

[extra]
lead = "Wallpapers live in the same per-user directory most desktops use, and an SVG one recolors itself to the active color scheme before it's ever applied."
toc = true
+++

Open the picker from **Super → Sobarch → Wallpaper**. It lists every
file in `~/.local/share/backgrounds/`, the per-user counterpart of the
`/usr/share/backgrounds` convention most distros ship their own
default wallpapers under. Picking one applies it immediately to every
connected monitor, scaled to cover.

## SVG wallpapers recolor automatically

A plain raster image (JPG, PNG) is applied as-is. An SVG one can opt
into recoloring by giving one element `id="sobarch-bg"` and another
`id="sobarch-accent"`, each with a plain `fill="#RRGGBB"` attribute.
Those two get rewritten to the active scheme's `base00`/`base0D`
before the file is ever shown, the same colors used across Hyprland,
waybar, and everything else [Theming](../theming/) covers. Sobarch's
own shipped wallpaper (the default until you pick something else)
follows this convention; drop your own SVG alongside it to get the
same treatment.

The recolored SVG is rasterized to PNG before being handed to
hyprpaper. hyprpaper's own raster scaling works correctly, but its SVG
decoding doesn't render fills right, so an SVG is always converted
first regardless of which app ends up displaying it.

## When it re-applies

Nothing needs to be re-picked by hand: the current wallpaper is
re-applied automatically whenever you switch color schemes (so an SVG
wallpaper stays in sync with the rest of the desktop) and whenever the
set of connected monitors changes, in addition to running once
whenever you pick something new from the menu.
