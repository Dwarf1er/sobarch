#!/bin/bash

ICONS="$HOME/.config/sobarch/icons"

# apps: same icon setup-menu.sh's own "Default Apps" entry uses.
TITLE="sobarch: default app"

app_dirs=(/usr/share/applications "$HOME/.local/share/applications")

# Looping per-dir rather than a single "${app_dirs[@]}"/*.desktop glob:
# a glob suffix on an array expansion only attaches to the last element,
# silently dropping every earlier directory (passed to grep as a bare
# path, "Is a directory", swallowed by 2>/dev/null) and leaving the menu
# empty whenever the last dir doesn't happen to cover it.
all_mimetypes=$(for dir in "${app_dirs[@]}"; do
    grep -h '^MimeType=' "$dir"/*.desktop 2>/dev/null
done | cut -d= -f2- | tr ';' '\n' | awk 'NF' | sort -u)

# A flat alphabetical dump of every mimetype some installed app declares
# support for buries what a user is actually likely to want (PDF,
# images, video...) under obscure/legacy formats an app happens to
# register (application/clarisworks, application/iges, ...). This
# curated set, in this fixed order, is shown first -- only entries
# actually present above (an app is genuinely installed to handle them)
# make the cut -- with everything else following alphabetically after,
# same as before.
common_order="text/plain text/html text/markdown text/csv application/pdf
image/jpeg image/png image/gif image/svg+xml image/webp
audio/mpeg audio/flac audio/ogg video/mp4 video/x-matroska video/webm
application/zip application/x-7z-compressed application/json application/xml
inode/directory x-scheme-handler/http x-scheme-handler/https
application/epub+zip
application/vnd.openxmlformats-officedocument.wordprocessingml.document
application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
application/vnd.openxmlformats-officedocument.presentationml.presentation"

# Category icon slug (under $ICONS), by prefix/exact match; falls back
# to a generic file icon for anything not covered.
icon_for() {
    case "$1" in
        text/*) printf 'file-text' ;;
        application/pdf) printf 'file-type-pdf' ;;
        image/*) printf 'photo' ;;
        video/*) printf 'movie' ;;
        audio/*) printf 'music' ;;
        application/zip|application/x-7z-compressed|application/x-tar|application/gzip|application/x-bzip*|application/x-rar*|application/x-xz)
            printf 'file-zip' ;;
        application/json) printf 'json' ;;
        inode/directory) printf 'folder' ;;
        x-scheme-handler/*) printf 'world' ;;
        application/msword|*wordprocessingml*) printf 'file-type-doc' ;;
        application/vnd.ms-excel|*spreadsheetml*) printf 'file-type-xls' ;;
        application/vnd.ms-powerpoint|*presentationml*) printf 'file-type-ppt' ;;
        *) printf 'file' ;;
    esac
}

declare -A remaining
while IFS= read -r mt; do
    [ -n "$mt" ] && remaining["$mt"]=1
done <<<"$all_mimetypes"

# Decorated (icon-marker-carrying) lines are streamed straight into
# fuzzel below rather than built up in a bash variable first: a bash
# variable can't hold an embedded NUL byte, so accumulating them (as
# the old plain-glyph version of this script did) would silently
# truncate every line at its first icon marker -- same NUL-byte
# constraint themes-menu.sh's own comment documents.
line=$(
    {
        for mt in $common_order; do
            if [ -n "${remaining[$mt]:-}" ]; then
                printf '%s\t%s\0icon\x1f%s\n' "$mt" "$mt" "$ICONS/$(icon_for "$mt").svg"
                unset "remaining[$mt]"
            fi
        done
        rest=$(printf '%s\n' "${!remaining[@]}" | sort)
        while IFS= read -r mt; do
            [ -n "$mt" ] && printf '%s\t%s\0icon\x1f%s\n' "$mt" "$mt" "$ICONS/$(icon_for "$mt").svg"
        done <<<"$rest"
    } | fuzzel --dmenu --with-nth=1 --prompt "mimetype: "
)
[ -n "$line" ] || exit 0
mimetype="${line##*$'\t'}"

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
done | sort -f -u | fuzzel --dmenu --with-nth=1 --auto-select --prompt "open with: ")
[ -n "$line" ] || exit 0

app_name="${line%%$'\t'*}"
app_id="${line##*$'\t'}"

if xdg-mime default "$app_id" "$mimetype"; then
    notify-send -i "$ICONS/apps.svg" "$TITLE" "$mimetype now opens with $app_name."
else
    notify-send -u critical -i "$ICONS/apps.svg" "$TITLE" "Failed to set $app_name as default for $mimetype."
fi
