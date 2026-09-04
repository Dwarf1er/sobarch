------------------
---- MONITORS ----
------------------

-- Generic fallback: matches any monitor not covered by a machine-specific rule below.
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- Machine-specific monitor layout and workspace pinning. Not tracked by the dotfiles/distro defaults; safe to be absent.
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/local.lua")

-- NVIDIA-specific env vars, deployed only on machines where hardware
-- detection found an NVIDIA GPU (see installer/archinstall/nvidia.lua).
-- Safe to be absent on AMD/Intel-only systems.
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/nvidia.lua")

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local fileManager = "pcmanfm"
local menu = "fuzzel"
local browser = "librewolf"
local screenshot = "hyprshot"
local lockScreen = "hyprlock"
local colorPicker = "hyprpicker"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("waybar & mako & hypridle & hyprpaper & udiskie")
	hl.exec_cmd("fcitx5")
	hl.exec_cmd("xdg-user-dirs-update")
end)

hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3"')
hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
hl.exec_cmd('gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"')

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 5,

		border_size = 2,

		col = {
			active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},

		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,

		active_opacity = 1.0,
		inactive_opacity = 1.0,

		shadow = {
			enabled = false,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},

		blur = {
			enabled = false,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = false,
	},
})

hl.config({
	dwindle = {
		preserve_split = true,
	},
})

hl.config({
	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		follow_mouse = 1,

		sensitivity = 0,
		accel_profile = "flat",

		touchpad = {
			natural_scroll = true,
		},
	},
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd(lockScreen))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(colorPicker .. " | wl-copy"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/audio-menu.sh"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/network-menu.sh"))
hl.bind(
	mainMod .. " + SHIFT + B",
	hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/bluetooth-menu.sh")
)
hl.bind(
	mainMod .. " + SUPER_L",
	hl.dsp.exec_cmd("bash -c \"if ! hyprctl activewindow | grep -q 'fullscreen: [1-9][0-9]*'; then " .. menu .. '; fi"')
)

hl.bind("PRINT", hl.dsp.exec_cmd(screenshot .. " -m output --clipboard-only"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " -m region --clipboard-only"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd('grim -g "$(slurp)" - | tesseract - - | wl-copy'))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd('grim -g "$(slurp)" - | zbarimg --raw - | wl-copy'))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("makoctl mode -t do-not-disturb"))

-- Move focus (vim-style)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

-- Move windows (vim-style)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- Switch workspaces and move windows
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

hl.window_rule({
	name = "float-network-manager",
	match = { title = ".*Network Manager.*" },
	float = true,
})

hl.layer_rule({
	name = "no-anim-fuzzel",
	match = { namespace = "^(fuzzel)$" },
	no_anim = true,
})
