+++
title = "sobarch"

[extra]
tagline = "Simple software, simply installed."
lead = "A Hyprland desktop on Arch Linux: installer, versioned configuration, and package tooling in one repo. As close to upstream Arch as possible, no custom package repository, as few dependencies as possible."
install_command = "curl -fsSL http://installsobarch.antoinepoulin.com | bash"
docs_url = "/docs/"
repo_url = "https://github.com/Dwarf1er/sobarch"

[[extra.menu.main]]
name = "Docs"
section = "docs"
url = "/docs/"
weight = 10

[[extra.pillars]]
title = "Minimal"
content = "No custom package repository, no bespoke daemons. What isn't upstream Arch or Hyprland is a plain dotfile or a script you can read top to bottom."

[[extra.pillars]]
title = "Reproducible"
content = "One installer, one set of versioned configs. Rebuilding a machine from scratch is the normal way to make a change, not a last resort."

[[extra.pillars]]
title = "Themeable at the root"
content = "Every app config is generated from the same base16/base24 color scheme via tinty, so switching a theme recolors the whole desktop at once, not one app at a time."

[[extra.included]]
title = "Desktop"
content = "Hyprland, Waybar, Mako, Fuzzel, Kitty, and ly, with hyprlock/hypridle/hyprpaper/hyprshot/hyprpicker for locking, idle handling, wallpapers, and screenshots. GPU driver selection, including NVIDIA generation detection, is automatic at install time."

[[extra.included]]
title = "Bootable snapshots"
content = "BTRFS root snapshots via Snapper show up as their own entries directly in the Limine boot menu, and a dedicated on-disk partition carries a spare Arch ISO so a rollback works even if the installed system won't boot."

[[extra.included]]
title = "Security baseline"
content = "A default-deny nftables firewall and a locked root account ship out of the box. SSH stays off unless enabled during install."

[[extra.included]]
title = "No terminal required"
content = "A Fuzzel-driven menu on the Super key covers pulling config updates, resolving merge conflicts, installing packages, switching themes and wallpapers, and refreshing the rescue ISO."

[[extra.profiles]]
name = "Developer"

[[extra.profiles]]
name = "Gaming"

[[extra.profiles]]
name = "Creative"

[[extra.profiles]]
name = "Maker / 3D Printing"

[[extra.profiles]]
name = "Virtualization"

[[extra.profiles]]
name = "Office"

[[extra.profiles]]
name = "Browsers & Chat"

[[extra.profiles]]
name = "System Tuning"

[[extra.profiles]]
name = "Input Method"
+++
