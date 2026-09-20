#!/usr/bin/env bash
# One-time setup step for a fresh clone: points git at the tracked
# .githooks/ dir instead of the untracked, per-clone .git/hooks/, so
# .githooks/pre-commit actually runs. See docs/DECISIONS.md decision
# #16 for why this is a hook instead of a CI check.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
echo "git hooks installed (core.hooksPath -> .githooks)"
