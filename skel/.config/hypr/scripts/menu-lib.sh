#!/bin/bash
# Sourced by menu scripts, never run directly: the plumbing every fuzzel
# menu used to rebuild by hand (row/icon formatting, window sizing,
# mapping a selection back to a stable id, custom-key dispatch, submenu
# navigation, failure/progress notifications), so a menu script only
# has to describe its rows and what each one does.
#
#   MENU_TITLE="sobarch: thing"   # notification title
#   MENU_ICON="thing.svg"         # notification icon
#   menu_reset
#   menu_add ID LABEL [ICON] [STATE]
#   menu_show PROMPT [MESG] [SELECT_ID] || break
#   case "$MENU_ID" in ...; esac  # MENU_KEY: 0 = Enter, N = custom-N
#
# Ids, not labels, are what a selection maps back to (fuzzel --index), so
# a label can carry live state without the caller's case statement
# having to match on it, and SELECT_ID keeps the cursor on the same row
# across loop iterations even after that row's label changed.
#
# Navigation is the process stack: a menu loops on menu_show and opens a
# submenu with menu_sub (a child process, never `exec`), so Escape in
# the submenu lands back in the loop that opened it. An action that
# should close every open level instead (launching an app, powering
# off, handing off to a long-running job) ends with menu_done.

source "$HOME/.config/hypr/scripts/confirm.sh"
source "$HOME/.config/hypr/scripts/notify-progress.sh"

ICONS="$HOME/.config/sobarch/icons"
MENU_SCRIPTS="$HOME/.config/hypr/scripts"

# menu_done's exit status; menu_sub propagates it up the stack.
MENU_DONE=100

# Every menu opens at the same width unless its rows need more, so
# moving between levels doesn't make the window jump around.
MENU_MIN_WIDTH=40

menu_reset() {
    MENU_IDS=()
    MENU_LABELS=()
    MENU_ICONS=()
    MENU_STATES=()
}

# ICON is a file under $ICONS ("power.svg"), an absolute path, or an
# icon-theme name ("audio-headset"); a comma-separated chain of those is
# a fallback list, tried in order (rofi's extended dmenu protocol, which
# fuzzel speaks). STATE renders as a second, aligned column: live state
# like "connected · 80%" or "active", and it's searchable like the label.
menu_add() {
    _menu_icon "${3:-}"
    MENU_IDS+=("$1")
    MENU_LABELS+=("$2")
    MENU_ICONS+=("$_MENU_ICON")
    MENU_STATES+=("${4:-}")
}

# Resolves into $_MENU_ICON rather than printing, so building a 500-row
# list (themes-menu.sh) doesn't fork a subshell per row.
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

# Up to 7 rows, these are the per-count --line-height values Phase 24
# tuned live against fuzzel.ini's global lines=8/line-height=22 box, so
# a short menu fills the same window an 8-row one does instead of
# leaving dead space below its last row. Longer lists grow to 10 rows
# at the default height, then scroll.
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

# Returns 1 on Escape (or an empty row list, without showing anything).
# MESG renders above the prompt (multi-line is fine): the place for live
# status and for the hint naming any custom keys a menu handles, since
# those aren't otherwise discoverable. Optional overrides, set by the
# caller: MENU_LINE_HEIGHT (thumbnail rows), MENU_PLACEHOLDER.
# --minimal-lines is on for any list that fits without scrolling: an
# icon-carrying row list shorter than --lines renders a duplicated,
# mispositioned icon in the empty leftover space (see wallpaper-menu.sh's
# own comment on that fuzzel bug). Longer lists have no leftover space,
# and leave it off: fuzzel 1.15 combined with --select-index past the
# first few hundred rows fails outright ("couldn't select entry at
# index 376", the theme list's current scheme, reproduced directly).
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
    # fuzzel's width is in characters of the whole window; its padding
    # and a default-height icon take about six of them, leaving $avail
    # for text. Icons scale with line height, so taller rows give up
    # roughly one more character per 9px. The state column is
    # right-aligned against that edge.
    local line_height="${MENU_LINE_HEIGHT:-$(_menu_line_height "$n")}"
    local chrome=$((6 + (line_height > 22 ? (line_height - 22 + 8) / 9 : 0)))
    width=$MENU_MIN_WIDTH
    ((state_w > 0 && col + 3 + state_w + chrome > width)) && width=$((col + 3 + state_w + chrome))
    ((width > 72)) && width=72
    local avail=$((width - chrome))
    # fuzzel spaces message lines by --line-height too, so a header that
    # wraps or runs to several lines gets its rows capped at 28px rather
    # than leaving 40px gaps between the header's own lines.
    if [ -z "${MENU_LINE_HEIGHT:-}" ] && ((line_height > 28)) &&
        { [[ "$mesg" == *$'\n'* ]] || ((${#mesg} > avail)); }; then
        line_height=28
    fi
    # Labels too long to leave room for the state column are cut with an
    # ellipsis here, since fuzzel's own truncation cuts from the end of
    # the whole row and would eat the state instead.
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

    # Written out to a file in full before fuzzel starts, rather than
    # piped in as it's generated: fuzzel draws as soon as rows start
    # arriving and only applies --select-index once input ends, so on a
    # long list (582 themes) the highlight visibly sat on the wrong row
    # for most of a second first. A file, not a variable, since a bash
    # variable can't hold the NUL byte in each icon marker.
    local rows
    rows=$(mktemp)
    for i in "${!MENU_IDS[@]}"; do
        local text="${MENU_LABELS[$i]}" pad
        if [ -n "${MENU_STATES[$i]}" ]; then
            ((${#text} > max_label)) && text="${text:0:max_label-1}…"
            # Padded by character count, not printf's %-*s, which counts
            # bytes and would misalign any label or state holding a "·".
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

    # fuzzel.ini(5): custom-1..custom-19 (Alt+1.. by default) print the
    # selection like Enter does, then exit 10..28. Any other non-zero
    # exit is a cancel.
    if ((rc >= 10 && rc <= 28)); then
        MENU_KEY=$((rc - 9))
    elif ((rc != 0)); then
        return 1
    fi
    [[ "$out" =~ ^[0-9]+$ ]] && ((out < n)) || return 1
    MENU_ID="${MENU_IDS[$out]}"
}

# menu_input PROMPT [MESG] [password]: a free-text prompt, no list.
# Prints what was typed; returns 1 on Escape, so a cancelled password
# prompt never runs the action with an empty one.
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

# Opens another menu script as a child; a menu_done anywhere below it
# closes this level too.
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

# Runs CMD..., output into a temp file, and prints that output. Through
# a file rather than $(...): a command that starts a long-lived process
# (tinty's waybar reload hook ends in a bare `waybar &`) hands it the
# capture as its stdout, and $(...) would then wait on that process's
# lifetime instead of the command's own.
_menu_capture() {
    local tmp rc
    tmp=$(mktemp)
    "$@" >"$tmp" 2>&1
    rc=$?
    cat "$tmp"
    rm -f "$tmp"
    return "$rc"
}

# Runs a command and, only if it exits non-zero, surfaces its combined
# output as a critical notification. One convention for every CLI: the
# exit status decides failure, never whether something was printed on
# stderr (the old per-script notify_on_fail copies disagreed on that).
menu_run() {
    local out
    out=$(_menu_capture "$@") && return 0
    menu_notify "${out:-$* failed.}" critical
    return 1
}

# menu_progress BODY DONE_BODY CMD...: menu_run for something slow. A
# persistent "in progress" toast, replaced in place by DONE_BODY, or by
# the command's own output on failure.
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
