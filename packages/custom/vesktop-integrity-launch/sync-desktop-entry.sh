#!/usr/bin/env bash
# Run by vesktop-integrity-launch.hook (PostTransaction). Keeps a
# system-wide override of vesktop-bin's menu entry pointed at the
# launcher wrapper: /usr/local/share precedes /usr/share in the default
# XDG_DATA_DIRS, so a same-named .desktop file there wins, without
# touching (or conflicting with) the file vesktop-bin itself owns.
# Regenerated from the packaged entry on every vesktop-bin change so
# Name/Icon/MimeType never drift; removed again when either package
# goes away.

set -euo pipefail

SRC=/usr/share/applications/vesktop.desktop
DEST=/usr/local/share/applications/vesktop.desktop
LAUNCHER=/usr/bin/vesktop-integrity-launch

if [[ -x "$LAUNCHER" && -f "$SRC" ]]; then
    install -dm755 "$(dirname "$DEST")"
    # Rewrite only the binary token of Exec=, keeping trailing args
    # (%U): the launcher resolves the real vesktop itself.
    sed -E "s|^Exec=[^ ]+(.*)|Exec=$LAUNCHER\\1|" "$SRC" >"$DEST.tmp"
    chmod 644 "$DEST.tmp"
    mv "$DEST.tmp" "$DEST"
else
    rm -f "$DEST"
fi
