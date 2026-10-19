#!/bin/bash
# Shared fuzzel menu helpers, sourced by every menu script.
#
#   MENU_TITLE="sobarch: thing"   # notification title
#   MENU_ICON="thing.svg"         # notification icon
#   menu_reset
#   menu_add ID LABEL [ICON] [STATE]
#   menu_show PROMPT [MESG] [SELECT_ID] || break
#   case "$MENU_ID" in ...; esac  # MENU_KEY: 0 = Enter, N = custom-N
#
# Submenus run as child processes via menu_sub, so Escape returns to the
# parent; menu_done closes every level.

source "$HOME/.config/hypr/scripts/confirm.sh"
source "$HOME/.config/hypr/scripts/notify-progress.sh"

ICONS="$HOME/.config/sobarch/icons"
MENU_SCRIPTS="$HOME/.config/hypr/scripts"

# menu_done's exit status; menu_sub propagates it up the stack.
MENU_DONE=100

# Same width at every level so the window doesn't jump between menus.
MENU_MIN_WIDTH=40

menu_reset() {
    MENU_IDS=()
    MENU_LABELS=()
    MENU_ICONS=()
    MENU_STATES=()
}

# ICON: a file under $ICONS, an absolute path, or an icon-theme name;
# comma-separated for fallbacks. STATE is a second, right-aligned column.
menu_add() {
    _menu_icon "${3:-}"
    MENU_IDS+=("$1")
    MENU_LABELS+=("$2")
    MENU_ICONS+=("$_MENU_ICON")
    MENU_STATES+=("${4:-}")
}

# Sets $_MENU_ICON instead of printing, to avoid a subshell per row.
_menu_icon() {
    local part out=() IFS=,
    for part in $1; do
        [ -n "$part" ] || continue
        case "$part" in
            */*) out+=("$part") ;;
            *.svg|*.png) out+=("$ICONS/$part") ;;
            *) out+=("$part") ;;
        esac
    done
    _MENU_ICON="${out[*]}"
}

# Per-row-count line heights so short menus fill the same window as an
# 8-row one (fuzzel.ini: lines=8, line-height=22).
_menu_line_height() {
    case "$1" in
        1|2|3) echo 40 ;;
        4) echo 32 ;;
        5) echo 27 ;;
        6) echo 23 ;;
        7) echo 20 ;;
        *) echo 22 ;;
    esac
}

# Returns 1 on Escape or an empty list. MESG renders above the prompt.
# Optional overrides: MENU_LINE_HEIGHT, MENU_PLACEHOLDER.
# --minimal-lines avoids fuzzel drawing stray icons in unused rows, but
# breaks --select-index on long lists, so it's only used when n <= 10.
menu_show() {
    local prompt="$1" mesg="${2:-}" select="${3:-}"
    local n=${#MENU_IDS[@]} i out rc=0 col=0 state_w=0 width
    MENU_ID=""
    MENU_KEY=0
    ((n > 0)) || return 1

    for i in "${!MENU_IDS[@]}"; do
        if [ -n "${MENU_STATES[$i]}" ]; then
            ((${#MENU_LABELS[$i]} > col)) && col=${#MENU_LABELS[$i]}
            ((${#MENU_STATES[$i]} > state_w)) && state_w=${#MENU_STATES[$i]}
        fi
    done
# Width is in characters; padding and the icon take about $chrome of them.
    local line_height="${MENU_LINE_HEIGHT:-$(_menu_line_height "$n")}"
    local chrome=$((6 + (line_height > 22 ? (line_height - 22 + 8) / 9 : 0)))
    width=$MENU_MIN_WIDTH
    ((state_w > 0 && col + 3 + state_w + chrome > width)) && width=$((col + 3 + state_w + chrome))
    ((width > 72)) && width=72
    local avail=$((width - chrome))
# Message lines use --line-height too, so cap it for multi-line headers.
    if [ -z "${MENU_LINE_HEIGHT:-}" ] && ((line_height > 28)) &&
        { [[ "$mesg" == *$'\n'* ]] || ((${#mesg} > avail)); }; then
        line_height=28
    fi
# Truncate labels here; fuzzel truncates the row end and would cut the state.
    local max_label=$((avail - state_w - 3))
    ((max_label < 8)) && max_label=8

    local lines=$((n < 10 ? n : 10))
    local args=(--dmenu --index --only-match --width "$width"
        --prompt "$prompt  " --placeholder "${MENU_PLACEHOLDER:-Search}"
        --lines "$lines" --line-height "$line_height")
    ((n > 10)) && args+=(--counter) || args+=(--minimal-lines)
    [ -n "$mesg" ] && args+=(--mesg "$mesg")
    if [ -n "$select" ]; then
        for i in "${!MENU_IDS[@]}"; do
            if [ "${MENU_IDS[$i]}" = "$select" ]; then
                args+=(--select-index "$i")
                break
            fi
        done
    fi

# Rows go to a file before fuzzel starts: it applies --select-index only
# at end of input, and a variable can't hold the NUL in icon markers.
    local rows
    rows=$(mktemp)
    for i in "${!MENU_IDS[@]}"; do
        local text="${MENU_LABELS[$i]}" pad
        if [ -n "${MENU_STATES[$i]}" ]; then
            ((${#text} > max_label)) && text="${text:0:max_label-1}…"
            # printf %-*s pads by bytes and would misalign multibyte "·".
            printf -v pad '%*s' "$((avail - ${#text} - ${#MENU_STATES[$i]}))" ''
            text="$text$pad${MENU_STATES[$i]}"
        fi
        if [ -n "${MENU_ICONS[$i]}" ]; then
            printf '%s\0icon\x1f%s\n' "$text" "${MENU_ICONS[$i]}"
        else
            printf '%s\n' "$text"
        fi
    done >"$rows"
    out=$(fuzzel "${args[@]}" <"$rows") || rc=$?
    rm -f "$rows"

# custom-1..custom-19 exit 10..28; any other non-zero exit is a cancel.
    if ((rc >= 10 && rc <= 28)); then
        MENU_KEY=$((rc - 9))
    elif ((rc != 0)); then
        return 1
    fi
    [[ "$out" =~ ^[0-9]+$ ]] && ((out < n)) || return 1
    MENU_ID="${MENU_IDS[$out]}"
}

# menu_input PROMPT [MESG] [password]: free-text prompt. Returns 1 on Escape.
menu_input() {
    local args=(--dmenu --minimal-lines --lines 0 --width "$MENU_MIN_WIDTH"
        --prompt "$1  " --placeholder "${MENU_PLACEHOLDER:-}")
    [ -n "${2:-}" ] && args+=(--mesg "$2")
    [ "${3:-}" = password ] && args+=(--password)
    local out
    out=$(fuzzel "${args[@]}" </dev/null) || return 1
    [ -n "$out" ] || return 1
    printf '%s\n' "$out"
}

menu_sub() {
    bash "$MENU_SCRIPTS/$1" "${@:2}"
    (($? == MENU_DONE)) && exit "$MENU_DONE"
    return 0
}

menu_done() { exit "$MENU_DONE"; }

menu_notify() {
    _menu_icon "${MENU_ICON:-}"
    notify-send -u "${2:-normal}" -i "$_MENU_ICON" "$MENU_TITLE" "$1"
}

# Captures through a temp file because a hook's `waybar &` would inherit a
# $(...) pipe and keep it open.
_menu_capture() {
    local tmp rc
    tmp=$(mktemp)
    "$@" >"$tmp" 2>&1
    rc=$?
    cat "$tmp"
    rm -f "$tmp"
    return "$rc"
}

# Notifies with the command's output only if it exits non-zero.
menu_run() {
    local out
    out=$(_menu_capture "$@") && return 0
    menu_notify "${out:-$* failed.}" critical
    return 1
}

# menu_progress BODY DONE_BODY CMD...: menu_run with a persistent progress toast.
menu_progress() {
    local body="$1" done_body="$2" icon id out
    shift 2
    _menu_icon "${MENU_ICON:-}"
    icon=$_MENU_ICON
    id=$(notify_progress normal "$MENU_TITLE" "$body" 0 persist "$icon")
    if out=$(_menu_capture "$@"); then
        notify_progress normal "$MENU_TITLE" "$done_body" "$id" "" "$icon" >/dev/null
    else
        notify_progress critical "$MENU_TITLE" "${out:-$* failed.}" "$id" "" "$icon" >/dev/null
        return 1
    fi
}
