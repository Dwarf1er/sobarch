#!/usr/bin/env bash
# Prints the names of packages/aur/ packages touched relative to
# origin/master, one per line. Prints nothing when none differ (e.g. a
# manual run on master), which callers treat as "check everything".
# Needs a checkout with enough history to see origin/master
# (fetch-depth: 0).

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
git diff --name-only origin/master...HEAD -- packages/aur \
    | cut -d/ -f3 | sort -u | while read -r name; do
        # Skip packages deleted by the diff
        [[ -d "packages/aur/$name" ]] && echo "$name"
    done
exit 0
