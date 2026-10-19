#!/bin/bash
# Default applications: groups (one app for every type in a group), then
# common types by name, then every other mimetype. Defaults are resolved
# in one awk pass in xdg-mime's lookup order instead of one xdg-mime call per row.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: default app"
MENU_ICON="apps.svg"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_dirs=("${XDG_DATA_HOME:-$HOME/.local/share}")
IFS=: read -ra extra <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
data_dirs+=("${extra[@]}")
IFS=: read -ra config_dirs <<<"${XDG_CONFIG_DIRS:-/etc/xdg}"
app_dirs=()
for d in "${data_dirs[@]}"; do app_dirs+=("${d%/}/applications"); done

# ID<\037>NAME<\037>;MIMETYPES;<\037>ICON per app. NoDisplay apps are kept
# since real handlers set it; Hidden=true is skipped. User entries win.
# Loop per dir: a glob suffix on an array expansion only hits the last element.
desktop_files=$(for dir in "${app_dirs[@]}"; do
    [ -d "$dir" ] && printf '%s\n' "$dir"/*.desktop
done)
desktop_index=$(xargs -r -d '\n' awk '
    function flush() { if (id != "" && !hidden && name != "" && !seen[id]++) print id "\037" name "\037;" mimes ";\037" icon }
    FNR == 1 { flush(); id = FILENAME; sub(/.*\//, "", id); name = mimes = icon = ""; hidden = 0; in_entry = 0 }
    /^\[/ { in_entry = ($0 == "[Desktop Entry]") }
    in_entry && /^Hidden=true/ { hidden = 1 }
    in_entry && /^Name=/ && name == "" { name = substr($0, 6) }
    in_entry && /^MimeType=/ { mimes = substr($0, 10); sub(/;$/, "", mimes) }
    in_entry && /^Icon=/ && icon == "" { icon = substr($0, 6) }
    END { flush() }' <<<"$desktop_files")

declare -A name_of icon_of
while IFS=$'\037' read -r id name _ icon; do
    name_of["$id"]="$name"
    icon_of["$id"]="$icon"
done <<<"$desktop_index"

# Skip wildcard types like "image/*": xdg-mime misreads them as regexes.
all_types=$(awk -F'\037' '{ n = split($3, t, ";"); for (i = 1; i <= n; i++) if (t[i] != "" && t[i] !~ /\*/) print t[i] }' \
    <<<"$desktop_index" | sort -u)
declare -A is_type
while IFS= read -r mt; do [ -n "$mt" ] && is_type["$mt"]=1; done <<<"$all_types"

# MIMETYPE<\037>DESKTOP-ID in xdg-mime's order: mimeapps.list files
# (desktop-prefixed first), then defaults.list/mimeinfo.cache.
resolve_defaults() {
    local files=() d prefix desktop="${XDG_CURRENT_DESKTOP%%:*}"
    for d in "$config_home" "${config_dirs[@]}" "${app_dirs[@]}"; do
        for prefix in "${desktop:+${desktop,,}-}" ""; do
            [ -f "$d/${prefix}mimeapps.list" ] && files+=("$d/${prefix}mimeapps.list")
        done
    done
    for d in "${app_dirs[@]}"; do
        for prefix in defaults.list mimeinfo.cache; do
            [ -f "$d/$prefix" ] && files+=("$d/$prefix")
        done
    done
    ((${#files[@]})) || return
    awk -v installed="$(sed 's#.*/##' <<<"$desktop_files" | tr '\n' ';')" '
        BEGIN { n = split(installed, ids, ";"); for (i = 1; i <= n; i++) inst[ids[i]] = 1 }
        FNR == 1 { list = (FILENAME ~ /mimeapps\.list$/); section = "" }
        /^\[/ { section = $0; next }
        {
            eq = index($0, "="); if (!eq) next
            key = substr($0, 1, eq - 1); n = split(substr($0, eq + 1), apps, ";")
            if (list) {
                if (section != "[Default Applications]" || (key in res)) next
                for (i = 1; i <= n; i++) if (apps[i] in inst) { res[key] = apps[i]; break }
            } else if (!(key in cache) && apps[1] != "") cache[key] = apps[1]
        }
        END {
            for (k in cache) if (!(k in res)) res[k] = cache[k]
            for (k in res) print k "\037" res[k]
        }' "${files[@]}"
}

declare -A default_of
load_defaults() {
    local mt id
    default_of=()
    while IFS=$'\037' read -r mt id; do default_of["$mt"]="$id"; done < <(resolve_defaults)
}

# GROUP-ID|Label|icon|members: members are exact types, or a "major/*"
# wildcard with "-type" exclusions. text/html belongs to the browser, so
# a text editor picked for "Text files" doesn't take it over.
groups="web|Web browser|world.svg|x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml
images|Images|photo.svg|image/*
video|Video|movie.svg|video/*
audio|Audio|music.svg|audio/*
text|Text files|file-text.svg|text/* -text/html
archives|Archives|file-zip.svg|application/zip application/x-7z-compressed application/x-tar application/gzip application/x-gzip application/x-bzip application/x-bzip2 application/x-bzip-compressed-tar application/x-compressed-tar application/x-xz application/x-xz-compressed-tar application/x-zstd application/zstd application/x-zstd-compressed-tar application/vnd.rar application/x-rar application/x-rar-compressed application/x-lzip application/x-lzma"

declare -A group_label group_icon group_types
group_order=()
while IFS='|' read -r gid label icon members; do
    group_order+=("$gid")
    group_label["$gid"]="$label"
    group_icon["$gid"]="$icon"
    group_types["$gid"]=$(awk -v members="$members" '
        BEGIN { n = split(members, m, " ") }
        {
            keep = 0
            for (i = 1; i <= n; i++) {
                if (m[i] ~ /^-/) { if ($0 == substr(m[i], 2)) { keep = 0; break } }
                else if (m[i] ~ /\/\*$/) { if (index($0, substr(m[i], 1, length(m[i]) - 1)) == 1) keep = 1 }
                else if ($0 == m[i]) keep = 1
            }
            if (keep) print
        }' <<<"$all_types")
done <<<"$groups"

# Shown after the groups, if some installed app declares them.
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

declare -A label_of
while IFS='|' read -r mt label; do label_of["$mt"]="$label"; done <<<"$common"

# Sets $_ICON instead of printing, to avoid a subshell per row.
icon_for() {
    case "$1" in
        text/*) _ICON=file-text.svg ;;
        application/pdf) _ICON=file-type-pdf.svg ;;
        image/*) _ICON=photo.svg ;;
        video/*) _ICON=movie.svg ;;
        audio/*) _ICON=music.svg ;;
        application/zip|application/x-7z-compressed|application/x-tar|application/gzip|application/x-bzip*|application/x-rar*|application/x-xz)
            _ICON=file-zip.svg ;;
        application/json) _ICON=json.svg ;;
        inode/directory) _ICON=folder.svg ;;
        x-scheme-handler/*) _ICON=world.svg ;;
        application/msword|*wordprocessingml*) _ICON=file-type-doc.svg ;;
        application/vnd.ms-excel|*spreadsheetml*) _ICON=file-type-xls.svg ;;
        application/vnd.ms-powerpoint|*presentationml*) _ICON=file-type-ppt.svg ;;
        *) _ICON=file.svg ;;
    esac
}

# The one app every type in the group agrees on, or "mixed".
group_state() {
    local mt app="" first=1
    while IFS= read -r mt; do
        [ -n "$mt" ] && [ -n "${default_of[$mt]:-}" ] || continue
        if ((first)); then
            app="${default_of[$mt]}" first=0
        elif [ "${default_of[$mt]}" != "$app" ]; then
            echo "mixed"
            return
        fi
    done <<<"${group_types[$1]}"
    [ -n "$app" ] && echo "${name_of[$app]:-$app}"
}

# Apps declaring any of the group's types, most coverage first. Picking
# one sets it only for the types it declares.
group_menu() {
    local gid="$1" total id name n covered current
    total=$(grep -c . <<<"${group_types[$gid]}")
    current=$(group_state "$gid")
    menu_reset
    while IFS=$'\037' read -r n id name; do
        menu_add "$id" "$name" "${icon_of[$id]},apps.svg" \
            "$([ "$current" = "$name" ] && echo "default · ")$n of $total"
    done < <(awk -F'\037' -v types="${group_types[$gid]}" '
        BEGIN { n = split(types, t, "\n") }
        { c = 0; for (i = 1; i <= n; i++) if (index($3, ";" t[i] ";")) c++; if (c) print c "\037" $1 "\037" $2 }' \
        <<<"$desktop_index" | sort -t $'\037' -k1,1nr -k3,3f)
    MENU_PLACEHOLDER="Search apps" menu_show "open with" \
        "${group_label[$gid]} · $total types" || return
    id="$MENU_ID"
    mapfile -t covered < <(awk -F'\037' -v id="$id" -v types="${group_types[$gid]}" '
        BEGIN { n = split(types, t, "\n") }
        $1 == id { for (i = 1; i <= n; i++) if (index($3, ";" t[i] ";")) print t[i] }' <<<"$desktop_index")
    ((${#covered[@]})) || return
    menu_run xdg-mime default "$id" "${covered[@]}" &&
        menu_notify "${name_of[$id]} is now the default for ${#covered[@]} of ${group_label[$gid]}'s $total types. Single types below can still be set on their own."
}

type_menu() {
    local mt="$1" label="$2" current="${default_of[$1]:-}" id name icon
    menu_reset
    while IFS=$'\037' read -r id name icon; do
        menu_add "$id" "$name" "$icon,apps.svg" "$([ "$id" = "$current" ] && echo default)"
    done < <(awk -F'\037' -v mt=";$mt;" 'index($3, mt) { print $1 "\037" $2 "\037" $4 }' <<<"$desktop_index" |
        sort -f -t $'\037' -k2)
    MENU_PLACEHOLDER="Search apps" menu_show "open with" "$label" "$current" || return
    [ "$MENU_ID" = "$current" ] && return
    menu_run xdg-mime default "$MENU_ID" "$mt"
}

MENU_PLACEHOLDER="Search file types"
selected=""
while :; do
    load_defaults
    declare -A shown=()
    menu_reset
    for gid in "${group_order[@]}"; do
        [ -n "${group_types[$gid]}" ] &&
            menu_add "group:$gid" "${group_label[$gid]}" "${group_icon[$gid]}" "$(group_state "$gid")"
    done
    while IFS='|' read -r mt _; do
        [ -n "${is_type[$mt]:-}" ] || continue
        icon_for "$mt"
        id="${default_of[$mt]:-}"
        menu_add "$mt" "${label_of[$mt]}" "$_ICON" "${id:+${name_of[$id]:-$id}}"
        shown["$mt"]=1
    done <<<"$common"
    while IFS= read -r mt; do
        [ -n "$mt" ] && [ -z "${shown[$mt]:-}" ] || continue
        icon_for "$mt"
        id="${default_of[$mt]:-}"
        menu_add "$mt" "$mt" "$_ICON" "${id:+${name_of[$id]:-$id}}"
    done <<<"$all_types"
    unset shown

    MENU_PLACEHOLDER="Search file types" menu_show "default apps" "" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        group:*) group_menu "${MENU_ID#group:}" ;;
        *) type_menu "$MENU_ID" "${label_of[$MENU_ID]:-$MENU_ID}" ;;
    esac
done
