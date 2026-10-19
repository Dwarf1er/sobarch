#!/usr/bin/env bash
# Run once per clone to enable the tracked .githooks/.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
echo "git hooks installed (core.hooksPath -> .githooks)"
