#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
TITLE="${2:-AWI validation for summary.yml}"
BODY_FILE="${3:-poc/issue-body.md}"
WORKFLOW_FILE="${WORKFLOW_FILE:-summary.yml}"
MARKER="${MARKER:-AWI_POC_MARKER_9E1B}"

if [[ ! -f "$BODY_FILE" ]]; then
  echo "Body file not found: $BODY_FILE" >&2
  exit 1
fi

start_epoch="$(date +%s)"

echo "Creating issue in ${REPO} using ${BODY_FILE} ..."
issue_url="$(gh issue create --repo "$REPO" --title "$TITLE" --body-file "$BODY_FILE")"
issue_number="${issue_url##*/}"
echo "Created issue #${issue_number}: ${issue_url}"

echo "Waiting for workflow run from ${WORKFLOW_FILE} ..."
run_id=""
for _ in $(seq 1 36); do
  while IFS=$'\t' read -r candidate_id candidate_created; do
    [[ -z "${candidate_id}" ]] && continue
    created_epoch="$(date -d "$candidate_created" +%s)"
    if [[ "$created_epoch" -ge "$start_epoch" ]]; then
      run_id="$candidate_id"
      break
    fi
  done < <(gh run list \
    --repo "$REPO" \
    --workflow "$WORKFLOW_FILE" \
    --limit 10 \
    --json databaseId,event,createdAt \
    --jq '.[] | select(.event=="issues") | [.databaseId, .createdAt] | @tsv')

  [[ -n "$run_id" ]] && break
  sleep 5
done

if [[ -z "$run_id" ]]; then
  echo "Could not find a matching workflow run." >&2
  exit 1
fi

echo "Watching run ${run_id} ..."
gh run watch "$run_id" --repo "$REPO" --exit-status

echo "Fetching issue comments ..."
comments="$(gh api "repos/${REPO}/issues/${issue_number}/comments")"

if jq -e --arg marker "$MARKER" 'any(.[]; .body | contains($marker))' >/dev/null <<<"$comments"; then
  echo
  echo "PoC SUCCESS"
  echo "Found marker: ${MARKER}"
  exit 0
fi

echo
echo "PoC INCONCLUSIVE"
echo "Marker not found in issue comments."
echo "Inspect the issue manually: ${issue_url}"
exit 2
