+++
title = "Theming"
description = "Switching color schemes across the whole desktop at once."
weight = 30
template = "docs/page.html"

[extra]
lead = "Every themed app reads from one shared color scheme, applied and reloaded together through tinty."
toc = true
+++

Sobarch themes the desktop through
[tinty](https://github.com/tinted-theming/tinty), using the
[base16](https://github.com/tinted-theming/home)/base24 color scheme
ecosystem. The default scheme is OneDark, but any base16, base24, or
tinted8 scheme installed by tinty can be applied.

Themed apps: Hyprland, waybar, mako, fuzzel, hyprlock, qt6ct,
[starship](../../shell-editor/terminal-and-shell/), fastfetch, the
desktop wallpaper, and [kitty's](../../shell-editor/terminal-and-shell/)
terminal colors.

## Switching schemes

Open the theme picker from **Super → Sobarch**, or run
`~/.config/hypr/scripts/themes-menu.sh` directly. It lists every scheme
tinty knows about, tagging non-base16 systems for clarity
(`(24-color)`, `(8-color)`), and applies whichever one you pick.

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/theming-picker-menu.webp" width="1366" height="768" alt="The theme picker, listing available base16/base24/tinted8 color schemes">
</figure>

Applying a scheme writes each app's color file and reloads that app:
`hyprctl reload` for Hyprland, `makoctl reload` for mako, a full
restart for waybar (it has no live file-watcher for its own config),
and so on. This reload behavior is wired per-app in tinty's own config.
The picker itself doesn't need to know about it; it only calls
`tinty apply`.

## Adding a scheme

`tinty install` fetches new schemes and runs automatically on login, so
newly available schemes show up in the picker without any manual step.
Browse the [tinted gallery](https://tinted-theming.github.io/tinted-gallery/)
for the full list of available schemes.

## The same desktop, four schemes

Terminal, waybar, and wallpaper all recolor together, whatever scheme
is active:

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/theming-onedark.webp" width="1366" height="768" alt="The desktop themed with OneDark, the default scheme">
  <figcaption class="figure-caption">OneDark, the default</figcaption>
</figure>

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/theming-catppuccin-mocha.webp" width="1366" height="768" alt="The desktop themed with Catppuccin Mocha">
  <figcaption class="figure-caption">Catppuccin Mocha</figcaption>
</figure>

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/theming-catppuccin-latte.webp" width="1366" height="768" alt="The desktop themed with Catppuccin Latte">
  <figcaption class="figure-caption">Catppuccin Latte</figcaption>
</figure>

<figure class="figure">
  <img class="img-fluid rounded shadow-sm" src="/images/desktop/theming-github-dark.webp" width="1366" height="768" alt="The desktop themed with GitHub Dark">
  <figcaption class="figure-caption">GitHub Dark</figcaption>
</figure>
