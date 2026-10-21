#!/usr/bin/env bash
# Sourced, not run. Maps /etc/sobarch/channel (stable|develop) to the git
# branch the update machinery fetches from.

SOBARCH_CHANNEL_FILE="/etc/sobarch/channel"

# Prints the branch for the current channel; anything unrecognised is stable.
sobarch_branch() {
    local channel=""
    [[ -r "$SOBARCH_CHANNEL_FILE" ]] && channel="$(tr -d '[:space:]' <"$SOBARCH_CHANNEL_FILE")"
    case "$channel" in
        develop) echo "develop" ;;
        *) echo "master" ;;
    esac
}
