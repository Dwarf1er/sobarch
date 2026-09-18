+++
title = "sobarch"

[extra]
tagline = "Simple software, simply installed."
lead = "A Hyprland desktop on Arch Linux: installer, versioned configuration, and package tooling in one repo. As close to upstream Arch as possible, no custom package repository, as few dependencies as possible."
install_command = "curl -fsSL https://raw.githubusercontent.com/Dwarf1er/sobarch/master/bootstrap.sh | bash"
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
+++
