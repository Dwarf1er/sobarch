#!/usr/bin/env bash
# Run by vesktop-integrity-launch.hook. Writes an override of vesktop.desktop
# in /usr/local/share, which wins over /usr/share in XDG_DATA_DIRS, with Exec
# pointed at the launcher. Removed when either package goes away.

set -euo pipefail

SRC=/usr/share/applications/vesktop.desktop
DEST=/usr/local/share/applications/vesktop.desktop
LAUNCHER=/usr/bin/vesktop-integrity-launch

if [[ -x "$LAUNCHER" && -f "$SRC" ]]; then
    install -dm755 "$(dirname "$DEST")"
    # Replace only the binary, keeping args like %U.
    sed -E "s|^Exec=[^ ]+(.*)|Exec=$LAUNCHER\\1|" "$SRC" >"$DEST.tmp"
    chmod 644 "$DEST.tmp"
    mv "$DEST.tmp" "$DEST"
else
    rm -f "$DEST"
fi
