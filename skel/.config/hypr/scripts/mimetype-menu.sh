#!/bin/bash

# Plain Unicode gear (U+2699) rather than a Nerd Font glyph: this repo's
# other menus mostly paste literal Nerd Font private-use characters, but
# main-menu.sh's own "Power" entry already falls back to a plain Unicode
# symbol, and there's no way to confirm a guessed private-use codepoint
# actually renders without the font in hand.
TITLE=$'⚙'"  sobarch: default app"

app_dirs=(/usr/share/applications "$HOME/.local/share/applications")

mimetype=$(grep -h '^MimeType=' "${app_dirs[@]}"/*.desktop 2>/dev/null \
    | cut -d= -f2- | tr ';' '\n' | awk 'NF' | sort -u \
    | fuzzel --dmenu --prompt "mimetype: ")
[ -n "$mimetype" ] || exit 0

# Tab-separated "Name\tdesktop-id" per candidate, same convention
# themes-menu.sh/bluetooth-menu.sh use to keep a pretty label in fuzzel
# while carrying the real identifier through untouched. The id has to
# be the desktop file's basename, not its path: `xdg-mime default`
# writes it verbatim into mimeapps.list, which every desktop-file
# lookup after that resolves by basename against the application dirs.
line=$(for dir in "${app_dirs[@]}"; do
    for file in "$dir"/*.desktop; do
        [ -f "$file" ] || continue
        awk -v mt="$mimetype" -v id="$(basename "$file")" '
            /^NoDisplay=true/ { skip = 1 }
            /^MimeType=/ {
                line = $0
                sub(/^MimeType=/, "", line)
                n = split(line, types, ";")
                for (i = 1; i <= n; i++) if (types[i] == mt) found = 1
            }
            /^Name=/ && !name {
                line = $0
                sub(/^Name=/, "", line)
                name = line
            }
            END { if (found && !skip && name) print name "\t" id }
        ' "$file"
    done
done | sort -f -u | fuzzel --dmenu --with-nth=1 --prompt "open with: ")
[ -n "$line" ] || exit 0

app_name="${line%%$'\t'*}"
app_id="${line##*$'\t'}"

if xdg-mime default "$app_id" "$mimetype"; then
    notify-send "$TITLE" "$mimetype now opens with $app_name."
else
    notify-send -u critical "$TITLE" "Failed to set $app_name as default for $mimetype."
fi
