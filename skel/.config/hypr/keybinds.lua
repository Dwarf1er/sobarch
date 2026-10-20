---------------------
---- KEYBINDINGS ----
---------------------

-- A "kb:" tag comment above a bind, as "<combo> | <description>", lists it in keybinds-menu.sh.
-- An optional "run:" line right after it holds the shell command Enter runs there; keep it in
-- step with the bind. Binds that act on the focused window have none.

local terminal = "kitty"
local fileManager = "pcmanfm"
local menu = "bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/main-menu.sh"
local browser = "librewolf"
local screenshot = "hyprshot"
local lockScreen = "hyprlock"
local colorPicker = "hyprpicker"

local mainMod = "SUPER"

-- kb: SUPER + T | Open terminal
-- run: kitty
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
-- kb: SUPER + C | Close focused window
hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- kb: SUPER + M | Exit Hyprland session
hl.bind(mainMod .. " + M", hl.dsp.exit())
-- kb: SUPER + E | Open file manager
-- run: pcmanfm
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
-- kb: SUPER + B | Open browser
-- run: librewolf
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
-- kb: SUPER + V | Toggle floating
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- kb: SUPER + F | Toggle fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
-- kb: SUPER + SHIFT + T | Toggle split direction
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.layout("togglesplit"))
-- kb: SUPER + CTRL + L | Lock screen
-- run: hyprlock
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd(lockScreen))
-- kb: SUPER + P | Pick color (copies to clipboard)
-- run: hyprpicker | wl-copy
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(colorPicker .. " | wl-copy"))
-- kb: SUPER + A | Open audio menu
-- run: bash $HOME/.config/hypr/scripts/audio-menu.sh
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/audio-menu.sh"))
-- kb: SUPER + N | Open network menu
-- run: bash $HOME/.config/hypr/scripts/network-menu.sh
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/network-menu.sh"))
-- kb: SUPER + SHIFT + B | Open bluetooth menu
-- run: bash $HOME/.config/hypr/scripts/bluetooth-menu.sh
hl.bind(
	mainMod .. " + SHIFT + B",
	hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/bluetooth-menu.sh")
)
-- kb: SUPER + SHIFT + F | Open firmware menu
-- run: bash $HOME/.config/hypr/scripts/fwupd-menu.sh
hl.bind(
	mainMod .. " + SHIFT + F",
	hl.dsp.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/fwupd-menu.sh")
)
-- kb: SUPER (tap) | Open main menu
-- run: bash $HOME/.config/hypr/scripts/main-menu.sh
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
-- run: hyprshot -m output --clipboard-only
hl.bind("PRINT", hl.dsp.exec_cmd(screenshot .. " -m output --clipboard-only"))
-- kb: SUPER + S | Screenshot: full output to file + clipboard, no focus grab
-- run: hyprshot -m output -m "$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name; exit}')"
hl.bind(
	mainMod .. " + S",
	hl.dsp.exec_cmd(
		screenshot
			.. [[ -m output -m "$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name; exit}')"]]
	)
)
-- kb: SUPER + SHIFT + S | Screenshot: region to clipboard
-- run: hyprshot -m region --clipboard-only
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " -m region --clipboard-only"))
-- kb: SUPER + O | OCR screen region to clipboard
-- run: grim -g "$(slurp)" - | tesseract - - | wl-copy
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd('grim -g "$(slurp)" - | tesseract - - | wl-copy'))
-- kb: SUPER + SHIFT + O | Scan QR/barcode in region to clipboard
-- run: grim -g "$(slurp)" - | zbarimg --raw - | wl-copy
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd('grim -g "$(slurp)" - | zbarimg --raw - | wl-copy'))
-- kb: SUPER + SHIFT + R | Screen recording: start (select region) / stop
-- run: $HOME/.config/hypr/scripts/record.sh toggle
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/record.sh toggle"))
-- kb: SUPER + D | Toggle do-not-disturb
-- run: makoctl mode -t do-not-disturb
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
-- run: $HOME/.config/hypr/scripts/osd.sh volume-up
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/osd.sh volume-up"),
	{ locked = true, repeating = true }
)
-- kb: Volume Down | Lower volume 5%
-- run: $HOME/.config/hypr/scripts/osd.sh volume-down
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/osd.sh volume-down"),
	{ locked = true, repeating = true }
)
-- kb: Mute | Toggle mute
-- run: $HOME/.config/hypr/scripts/osd.sh mute
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/osd.sh mute"),
	{ locked = true, repeating = true }
)
-- kb: Mic Mute | Toggle mic mute
-- run: $HOME/.config/hypr/scripts/osd.sh mic-mute
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/osd.sh mic-mute"),
	{ locked = true, repeating = true }
)
-- kb: Brightness Up | Raise brightness 10%
-- run: $HOME/.config/hypr/scripts/osd.sh brightness-up
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/osd.sh brightness-up"), { locked = true, repeating = true })
-- kb: Brightness Down | Lower brightness 10%
-- run: $HOME/.config/hypr/scripts/osd.sh brightness-down
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/osd.sh brightness-down"), { locked = true, repeating = true })

-- kb: Media Next | Next track
-- run: playerctl next
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
-- kb: Media Play/Pause | Play/pause
-- run: playerctl play-pause
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
-- kb: Media Previous | Previous track
-- run: playerctl previous
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Same actions on the Super layer, for keyboards without media keys.
local osd = os.getenv("HOME") .. "/.config/hypr/scripts/osd.sh "
local held = { locked = true, repeating = true }
-- kb: SUPER + = | Raise volume 5%
-- run: $HOME/.config/hypr/scripts/osd.sh volume-up
hl.bind(mainMod .. " + equal", hl.dsp.exec_cmd(osd .. "volume-up"), held)
-- kb: SUPER + - | Lower volume 5%
-- run: $HOME/.config/hypr/scripts/osd.sh volume-down
hl.bind(mainMod .. " + minus", hl.dsp.exec_cmd(osd .. "volume-down"), held)
-- kb: SUPER + SHIFT + - | Toggle mute
-- run: $HOME/.config/hypr/scripts/osd.sh mute
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.exec_cmd(osd .. "mute"), held)
-- Some QMK layers send "-" as the keypad key; same actions, no cheat sheet rows.
hl.bind(mainMod .. " + KP_Subtract", hl.dsp.exec_cmd(osd .. "volume-down"), held)
hl.bind(mainMod .. " + SHIFT + KP_Subtract", hl.dsp.exec_cmd(osd .. "mute"), held)
-- kb: SUPER + SHIFT + = | Toggle mic mute
-- run: $HOME/.config/hypr/scripts/osd.sh mic-mute
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.exec_cmd(osd .. "mic-mute"), held)
-- kb: SUPER + ] | Raise brightness 10%
-- run: $HOME/.config/hypr/scripts/osd.sh brightness-up
hl.bind(mainMod .. " + bracketright", hl.dsp.exec_cmd(osd .. "brightness-up"), held)
-- kb: SUPER + [ | Lower brightness 10%
-- run: $HOME/.config/hypr/scripts/osd.sh brightness-down
hl.bind(mainMod .. " + bracketleft", hl.dsp.exec_cmd(osd .. "brightness-down"), held)
-- kb: SUPER + ; | Play/pause
-- run: playerctl play-pause
hl.bind(mainMod .. " + semicolon", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
-- kb: SUPER + ' | Next track
-- run: playerctl next
hl.bind(mainMod .. " + apostrophe", hl.dsp.exec_cmd("playerctl next"), { locked = true })
-- kb: SUPER + , | Previous track
-- run: playerctl previous
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
