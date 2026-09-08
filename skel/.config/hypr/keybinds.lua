---------------------
---- KEYBINDINGS ----
---------------------

-- Split out of hyprland.lua so scripts/keybinds-menu.sh can grep just
-- this one file for the "kb:" tag prefix without also parsing colors/
-- monitor/window-rule config. Each tag sits directly above the bind
-- it documents, formatted as combo, a pipe, then a description.

local terminal = "kitty"
local fileManager = "pcmanfm"
local menu = "bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/main-menu.sh"
local browser = "librewolf"
local screenshot = "hyprshot"
local lockScreen = "hyprlock"
local colorPicker = "hyprpicker"

local mainMod = "SUPER"

-- kb: SUPER + T | Open terminal
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
-- kb: SUPER + C | Close focused window
hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- kb: SUPER + M | Exit Hyprland session
hl.bind(mainMod .. " + M", hl.dsp.exit())
-- kb: SUPER + E | Open file manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
-- kb: SUPER + B | Open browser
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
-- kb: SUPER + V | Toggle floating
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- kb: SUPER + F | Toggle fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
-- kb: SUPER + SHIFT + T | Toggle split direction
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.layout("togglesplit"))
-- kb: SUPER + CTRL + L | Lock screen
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd(lockScreen))
-- kb: SUPER + P | Pick color (copies to clipboard)
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(colorPicker .. " | wl-copy"))
-- kb: SUPER + A | Open audio menu
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/audio-menu.sh"))
-- kb: SUPER + N | Open network menu
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/network-menu.sh"))
-- kb: SUPER + SHIFT + B | Open bluetooth menu
hl.bind(
	mainMod .. " + SHIFT + B",
	hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/bluetooth-menu.sh")
)
-- kb: SUPER (tap) | Open main menu
hl.bind(
	mainMod .. " + SUPER_L",
	hl.dsp.exec_cmd("bash -c \"if ! hyprctl activewindow | grep -q 'fullscreen: [1-9][0-9]*'; then " .. menu .. '; fi"')
)
-- kb: SUPER + / | Show keybind cheat sheet
hl.bind(
	mainMod .. " + SLASH",
	hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/keybinds-menu.sh")
)

-- kb: Print Screen | Screenshot: full output to clipboard
hl.bind("PRINT", hl.dsp.exec_cmd(screenshot .. " -m output --clipboard-only"))
-- kb: SUPER + SHIFT + S | Screenshot: region to clipboard
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " -m region --clipboard-only"))
-- kb: SUPER + O | OCR screen region to clipboard
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd('grim -g "$(slurp)" - | tesseract - - | wl-copy'))
-- kb: SUPER + SHIFT + O | Scan QR/barcode in region to clipboard
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd('grim -g "$(slurp)" - | zbarimg --raw - | wl-copy'))
-- kb: SUPER + D | Toggle do-not-disturb
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("makoctl mode -t do-not-disturb"))

-- Move focus (vim-style)
-- kb: SUPER + H/J/K/L | Focus window left/down/up/right
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

-- Move windows (vim-style)
-- kb: SUPER + SHIFT + H/J/K/L | Move window left/down/up/right
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- Switch workspaces and move windows
-- kb: SUPER + 0-9 | Switch to workspace N
-- kb: SUPER + SHIFT + 0-9 | Move window to workspace N
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through workspaces
-- kb: SUPER + Scroll | Next/previous workspace
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mouse
-- kb: SUPER + Drag (LMB) | Move window
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- kb: SUPER + Drag (RMB) | Resize window
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys
-- kb: Volume Up | Raise volume 5%
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
-- kb: Volume Down | Lower volume 5%
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
-- kb: Mute | Toggle mute
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
-- kb: Mic Mute | Toggle mic mute
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
-- kb: Brightness Up | Raise brightness 10%
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
-- kb: Brightness Down | Lower brightness 10%
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- kb: Media Next | Next track
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
-- kb: Media Play/Pause | Play/pause
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
-- kb: Media Previous | Previous track
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
