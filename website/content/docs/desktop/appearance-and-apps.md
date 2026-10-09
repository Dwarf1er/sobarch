+++
title = "Appearance & Apps"
description = "How Qt, GTK, the file manager, and desktop portals are set up to look and behave consistently."
weight = 110
template = "docs/page.html"

[extra]
lead = "Qt and GTK apps get one dark look, files open in a lightweight manager, and screen sharing works through the Hyprland portal."
toc = true
+++

## Qt and GTK

- **Qt apps** use the Fusion style through qt6ct, with a palette that
  follows your [color scheme](../theming/) and the Papirus-Dark icon
  theme. To change fonts or the style, run `qt6ct`; the palette file
  itself is regenerated whenever you switch schemes.
- **GTK apps** use `adw-gtk3` in its dark variant with Papirus-Dark
  icons. These are fixed, not tied to the color scheme.

Both are applied at login, so they need no setup from you.

## Default applications

`Super+T` opens kitty, `Super+E` the file manager, and `Super+B` the
browser (LibreWolf). To change which app opens a given file type, use
**Super, Sobarch, Default Apps**: pick a MIME type (common ones such as
PDFs, images, video, and web links are listed first), then pick from the
installed apps that handle it.

## File manager

`Super+E` opens PCManFM. It's set up with kitty as its terminal, trash
enabled, confirmation before deleting, thumbnails on, and a places pane
with Home, Desktop, Trash, Applications, and unmounted drives.
`udiskie` runs in the session so removable drives mount automatically
and appear there.

## Desktop portals

`xdg-desktop-portal` is configured to prefer the Hyprland backend
(`xdg-desktop-portal-hyprland`), with the GTK backend also installed.
That's what lets browsers and other apps share or record the screen
under Wayland. Nothing needs configuring.

## Privilege prompts

Graphical apps that need administrator rights, and the pkexec prompts
sobarch uses itself (see [The sobarch Command](../sobarch-command/)),
are handled by `hyprpolkitagent`, started with the session.
