+++
title = "sobarch"

[extra]
tagline = "Arch's own principle, finally applied to the desktop."
lead = "A Hyprland desktop for Arch Linux: installer, versioned configuration, and package tooling in one repo. Every feature comes from the smallest tool that can deliver it, never from pulling in a foreign desktop environment's framework to get there."
install_command = "curl -fsSL http://installsobarch.antoinepoulin.com | bash"
docs_url = "/docs/"
repo_url = "https://github.com/Dwarf1er/sobarch"
philosophy = [
  "A modern desktop needs a secrets store, a polkit agent, network management, and a video editor, among other things. Sobarch picks whichever tool delivers each of those without dragging in a whole foreign desktop environment's framework: oo7 instead of KWallet, hyprpolkitagent instead of polkit-kde-agent, a NetworkManager-driven fuzzel menu instead of a GUI applet, Shotcut instead of Kdenlive. Same capability, a fraction of what's actually installed.",
  "One installer and one set of versioned configs make rebuilding a machine from scratch the normal way to make a change, not a last resort. Every app's config is generated from the same base16/base24 color scheme via tinty, so picking a new theme from the built-in menu recolors the terminal, bar, launcher, and editor together, not one app at a time.",
]

[[extra.menu.main]]
name = "Docs"
section = "docs"
url = "/docs/"
weight = 10

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
