#!/usr/bin/env bash
# Posts a log file as a comment on the PR for the current ref, if any.
# Used by checks.yml; a no-op when there is no PR (e.g. a manual
# dispatch on master). Needs GH_TOKEN and TITLE in the environment.

set -uo pipefail

log="${1:?usage: comment-check-results.sh LOGFILE}"
git config --global --add safe.directory "$GITHUB_WORKSPACE"

if [[ "${GITHUB_EVENT_NAME}" == pull_request ]]; then
    pr="$(cut -d/ -f3 <<<"$GITHUB_REF")"  # refs/pull/N/merge
else
    pr="$(gh pr list --state open --head "$GITHUB_REF_NAME" --json number --jq '.[0].number')"
fi
[[ -n "${pr:-}" ]] || { echo "no PR for ${GITHUB_REF_NAME}, skipping comment"; exit 0; }

body="$(mktemp)"
{
    echo "### $TITLE"
    echo
    echo '```'
    # GitHub caps comments at 65536 chars
    tail -c 60000 "$log"
    echo '```'
    echo
    echo "[Workflow run]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)"
} > "$body"
gh pr comment "$pr" --repo "$GITHUB_REPOSITORY" --body-file "$body"
