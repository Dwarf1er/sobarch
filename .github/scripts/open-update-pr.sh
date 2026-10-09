#!/usr/bin/env bash
# Commits PATH on a fresh branch and opens a pull request for it, for
# the update jobs in .github/workflows/aur.yml. Skips (created=false)
# if a PR for BRANCH is already open.
#
#   open-update-pr.sh BRANCH TITLE DESCRIPTION PATH [CHECK_NAME...]
#
# Each CHECK_NAME is a log at $RUNNER_TEMP/<name>.log whose tail is
# attached to the PR body. Needs GH_TOKEN, and the workspace marked
# safe.directory for git.

set -euo pipefail

branch="$1" title="$2" desc="$3" path="$4"
shift 4
checks=("$@")

if [[ -n "$(gh pr list --state open --head "$branch" --json number --jq '.[0].number')" ]]; then
    echo "PR for $branch already open, skipping"
    echo "created=false" >> "$GITHUB_OUTPUT"
    exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git checkout -B "$branch"
git add "$path"
git commit -m "$title"
# Force: this branch name is entirely derived from the package+version
# by the caller, so it's owned by this automation alone -- a stale ref
# left by an earlier run that pushed but failed before/at `gh pr create`
# (no open PR, so the guard above didn't catch it) must never block this
# run from reaching the same state.
git push --force origin "$branch"

{
    echo "$desc"
    echo
    echo "Requires human review before merge (no auto-merge configured); check the diff for anything beyond the version bump before approving. Check results for this package are below (a stale \`.SRCINFO\` would have failed the run before this PR opened)."
    for check in "${checks[@]}"; do
        echo
        echo "<details><summary>$check</summary>"
        echo
        echo '```'
        # PR bodies cap at 65536 chars
        tail -c 25000 "$RUNNER_TEMP/$check.log"
        echo '```'
        echo "</details>"
    done
    echo
    echo "[Workflow run]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)"
} > pr-body.txt
gh pr create --title "$title" --head "$branch" --base master --body-file pr-body.txt

echo "branch=$branch" >> "$GITHUB_OUTPUT"
echo "created=true" >> "$GITHUB_OUTPUT"
