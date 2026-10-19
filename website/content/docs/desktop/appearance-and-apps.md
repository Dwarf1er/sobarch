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
**Super, Sobarch, Default Apps**. The top rows are groups (Web browser,
Images, Video, Audio, Text files, Archives): pick one, then an app, and
that app becomes the default for every type in the group it can open,
with each app listed by how many of the group's types it covers. A group
shows the app all its types agree on, or `mixed`. Below the groups are
common file types by name (PDF documents, JPEG images, web links, ...),
then every other type, each showing the app it opens in now; pick one to
change just that type.

Out of the box, images open in imv, audio and video in mpv, web links,
HTML and PDFs in LibreWolf, folders in PCManFM, and archives in
xarchiver. These come from `/etc/xdg/mimeapps.list`, which anything you
choose in Default Apps overrides. Text files have no shipped default,
since Neovim needs a terminal that `xdg-open` doesn't open for it.

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
