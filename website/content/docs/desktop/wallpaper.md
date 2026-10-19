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
connected monitor (see [Multiple monitors](#multiple-monitors) for how
it's sized to each one), and the picker stays open with your choice
marked `current`, so you can compare a few before pressing `Escape`.
Each entry shows a thumbnail, and names are shown in title case with
dashes and underscores turned into spaces and the file extension
dropped. The shipped wallpaper is
`sobarch-wallpaper.svg`, used until you pick something else.

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
first regardless of which app ends up displaying it. An SVG with
`id="sobarch-bg"` is rasterized once per monitor size, at that
monitor's exact resolution, rather than once and scaled.

## Multiple monitors

Monitors don't need to share a resolution or orientation. How each one
is filled depends on the wallpaper:

- **An SVG with `id="sobarch-bg"`** is rendered separately for each
  monitor size, rotated monitors included. The design is scaled so its
  shorter edge matches the monitor's shorter edge, then centered, with
  any leftover space filled in the background color. The artwork comes
  out the same size on a landscape and a portrait monitor of the same
  resolution, and never stretched.
- **Anything else** (a JPG, a PNG, or an SVG without `id="sobarch-bg"`)
  is scaled to cover each monitor and cropped to fit. An image made for
  a landscape screen gets enlarged and cut down the middle on a
  portrait one.

## Making your own SVG wallpaper

To get both recoloring and per-monitor fitting:

- Give one element `id="sobarch-bg"` and another `id="sobarch-accent"`,
  each with a plain `fill="#RRGGBB"` attribute (not a
  `style="fill:..."` one). Recoloring only touches those two elements.
- Make `sobarch-bg` a single solid shape covering the whole canvas.
  The space around the canvas on a differently shaped monitor is
  filled with that same color, so a gradient or texture there would
  show visible bars.
- Keep anything important within the **central ~55% of the canvas's
  long edge**. On a monitor narrower than the design, the canvas's
  sides are cropped off: a 16:9 design on a 9:16 portrait monitor
  shows only the middle 56% of its width, and on a 5:4 monitor the
  middle 70%. A monitor wider than the design loses nothing and just
  gets more background on the sides. The shipped wallpaper's mark sits
  within the middle ~38%, so it fits on any of these.

## When it re-applies

Nothing needs to be re-picked by hand: the current wallpaper is
re-applied automatically whenever you switch color schemes (so an SVG
wallpaper stays in sync with the rest of the desktop) and whenever the
set of connected monitors changes, in addition to running once
whenever you pick something new from the menu.
