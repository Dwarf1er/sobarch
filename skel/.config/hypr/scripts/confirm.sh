#!/bin/bash
# Sourced by menu scripts that gate a destructive action, never run
# directly: a shared Yes/No confirmation step using the same fuzzel
# picker every other menu already uses. "No" is listed first since
# fuzzel highlights the first entry by default, so a stray Enter never
# confirms a destructive action by accident.

confirm() {
    [ "$(printf '%s\n' 'No' 'Yes' | fuzzel --dmenu --prompt "${1:-Are you sure? }")" = "Yes" ]
}
