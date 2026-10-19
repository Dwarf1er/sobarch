#!/usr/bin/env bash
# Clears software rfkill blocks that some laptops carry into a fresh install,
# leaving WiFi "sw disabled". Ordered before NetworkManager.service.

set -euo pipefail

MARKER="/var/lib/sobarch/rfkill-unblocked"

mkdir -p "$(dirname "$MARKER")"

echo "sobarch-firstboot: unblocking any soft-blocked wireless radios..."
rfkill unblock all

touch "$MARKER"
