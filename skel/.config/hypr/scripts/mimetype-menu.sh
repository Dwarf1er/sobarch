#!/bin/bash
# Default applications: file types by name ("PDF documents", "Web
# links") with the app each one currently opens in, then every app able
# to handle the chosen type. Stays open after a change so the new default
# is visible in place.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: default app"
MENU_ICON="apps.svg"
MENU_PLACEHOLDER="Search file types"

app_dirs=("$HOME/.local/share/applications" /usr/share/applications)

# One pass over every desktop file: ID<\037>NAME<\037>;MIMETYPES;<\037>ICON per
# visible app (NoDisplay ones left out). ID is the file's basename, the
# form `xdg-mime default` writes verbatim into mimeapps.list. User
# entries come first and win over a system one with the same ID, the
# same precedence the XDG lookup itself uses. Looping per-dir rather
# than a single "${app_dirs[@]}"/*.desktop glob: a glob suffix on an
# array expansion only attaches to the last element.
desktop_index=$(for dir in "${app_dirs[@]}"; do
    [ -d "$dir" ] && printf '%s\n' "$dir"/*.desktop
done | xargs -r -d '\n' awk '
    FNR == 1 {
        if (id != "" && !hidden && name != "" && !seen[id]++) print id "\037" name "\037;" mimes ";\037" icon
        id = FILENAME; sub(/.*\//, "", id); name = mimes = icon = ""; hidden = 0; in_entry = 0
    }
    /^\[/ { in_entry = ($0 == "[Desktop Entry]") }
    in_entry && /^NoDisplay=true/ { hidden = 1 }
    in_entry && /^Name=/ && name == "" { name = substr($0, 6) }
    in_entry && /^MimeType=/ { mimes = substr($0, 10); sub(/;$/, "", mimes) }
    in_entry && /^Icon=/ && icon == "" { icon = substr($0, 6) }
    END { if (id != "" && !hidden && name != "" && !seen[id]++) print id "\037" name "\037;" mimes ";\037" icon }')

app_name() { awk -F'\037' -v id="$1" '$1 == id { print $2; exit }' <<<"$desktop_index"; }

# Shown first, in this order, under readable names, each only if some
# installed app actually declares it; everything else follows under its
# raw mimetype, alphabetically.
common="text/plain|Plain text
text/markdown|Markdown
text/html|HTML files
text/csv|CSV files
application/pdf|PDF documents
image/jpeg|JPEG images
image/png|PNG images
image/gif|GIF images
image/webp|WebP images
image/svg+xml|SVG images
audio/mpeg|MP3 audio
audio/flac|FLAC audio
audio/ogg|Ogg audio
video/mp4|MP4 video
video/x-matroska|MKV video
video/webm|WebM video
application/zip|ZIP archives
application/x-7z-compressed|7-Zip archives
application/json|JSON files
application/xml|XML files
inode/directory|Folders
x-scheme-handler/http|Web links (http)
x-scheme-handler/https|Web links (https)
application/epub+zip|EPUB books
application/vnd.openxmlformats-officedocument.wordprocessingml.document|Word documents
application/vnd.openxmlformats-officedocument.spreadsheetml.sheet|Spreadsheets
application/vnd.openxmlformats-officedocument.presentationml.presentation|Presentations"

icon_for() {
    case "$1" in
        text/*) echo file-text.svg ;;
        application/pdf) echo file-type-pdf.svg ;;
        image/*) echo photo.svg ;;
        video/*) echo movie.svg ;;
        audio/*) echo music.svg ;;
        application/zip|application/x-7z-compressed|application/x-tar|application/gzip|application/x-bzip*|application/x-rar*|application/x-xz)
            echo file-zip.svg ;;
        application/json) echo json.svg ;;
        inode/directory) echo folder.svg ;;
        x-scheme-handler/*) echo world.svg ;;
        application/msword|*wordprocessingml*) echo file-type-doc.svg ;;
        application/vnd.ms-excel|*spreadsheetml*) echo file-type-xls.svg ;;
        application/vnd.ms-powerpoint|*presentationml*) echo file-type-ppt.svg ;;
        *) echo file.svg ;;
    esac
}

all_types=$(awk -F'\037' '{ n = split($3, t, ";"); for (i = 1; i <= n; i++) if (t[i] != "") print t[i] }' \
    <<<"$desktop_index" | sort -u)

# The common types' current defaults, queried in parallel: xdg-mime is
# a shell script costing ~30ms a call, ~1s for the whole set serially.
current_defaults() {
    local dir mt i=0
    dir=$(mktemp -d)
    while IFS='|' read -r mt _; do
        grep -qxF "$mt" <<<"$all_types" || continue
        (xdg-mime query default "$mt" >"$dir/$i" 2>/dev/null) &
        i=$((i + 1))
    done <<<"$common"
    wait
    i=0
    while IFS='|' read -r mt _; do
        grep -qxF "$mt" <<<"$all_types" || continue
        printf '%s\037%s\n' "$mt" "$(cat "$dir/$i")"
        i=$((i + 1))
    done <<<"$common"
    rm -rf "$dir"
}

# Every app declaring MIMETYPE, the current default marked; returns once
# one is picked.
apps_menu() {
    local mt="$1" label="$2" current id name icon
    current=$(xdg-mime query default "$mt" 2>/dev/null)
    menu_reset
    while IFS=$'\037' read -r id name icon; do
        menu_add "$id" "$name" "$icon,apps.svg" "$([ "$id" = "$current" ] && echo default)"
    done < <(awk -F'\037' -v mt=";$1;" 'index($3, mt) { print $1 "\037" $2 "\037" $4 }' <<<"$desktop_index" | sort -f -t $'\037' -k2)
    MENU_PLACEHOLDER="Search apps" menu_show "open with" "$label" "$current" || return
    [ "$MENU_ID" = "$current" ] && return
    menu_run xdg-mime default "$MENU_ID" "$mt"
}

declare -A label_of
while IFS='|' read -r mt label; do label_of["$mt"]="$label"; done <<<"$common"

selected=""
while :; do
    declare -A shown=()
    menu_reset
    while IFS=$'\037' read -r mt id; do
        menu_add "$mt" "${label_of[$mt]}" "$(icon_for "$mt")" "$(app_name "$id")"
        shown["$mt"]=1
    done < <(current_defaults)
    while IFS= read -r mt; do
        [ -n "$mt" ] && [ -z "${shown[$mt]:-}" ] && menu_add "$mt" "$mt" "$(icon_for "$mt")"
    done <<<"$all_types"
    unset shown

    menu_show "default apps" "" "$selected" || break
    selected="$MENU_ID"
    apps_menu "$MENU_ID" "${label_of[$MENU_ID]:-$MENU_ID}"
done
