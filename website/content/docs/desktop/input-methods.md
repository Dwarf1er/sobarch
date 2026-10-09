+++
title = "Input Methods"
description = "Typing in English, Canadian French, and Korean with fcitx5, and switching between them."
weight = 90
template = "docs/page.html"

[extra]
lead = "fcitx5 starts with your session and ships configured for three layouts, with the active one shown in the status bar."
toc = true
+++

The [Input Method profile](../../installer/software-profiles/) installs
fcitx5 with its configuration tool, GTK support, and the Hangul engine.
Sobarch's default configuration starts it with the session and sets up
three input methods in one group:

| Method | Bar label |
| --- | --- |
| Canadian French keyboard (the default) | `FR` |
| US English keyboard | `EN` |
| Korean (Hangul, Dubeolsik layout) | the Hangul syllable 한 |

## Switching

| Key | Action |
| --- | --- |
| `Super+Space` | Toggle between the default keyboard and the input method you last used. Keep holding `Super` and press `Space` again to step through all three |
| `Shift+Super+Space` | Step through them in reverse |
| `Hangul` | Toggle input, same as `Super+Space` |
| `Hangul_Hanja` / `Hangul_Romaja` | Explicitly activate / deactivate the current method |
| `F9` (while typing Hangul) | Toggle Hanja conversion |

You can also click the indicator in the status bar to toggle. It refreshes
every second, so it follows a switch made with the keyboard.

Candidate lists page with `Up` and `Down` and move with `Tab` and
`Shift+Tab`. Input methods stay off in password fields.

## Customizing

Run `fcitx5-configtool` to add or reorder methods. Your configuration
lives in `~/.config/fcitx5/`, and is merged on updates like every other
dotfile (see [Updating Your System](../updating-system/)). The status bar
label only knows the three methods above, so one you add shows as `?`
with its name in the tooltip.
