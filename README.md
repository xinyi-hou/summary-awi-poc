# summary-awi-poc-private

Private proof-of-concept repository for validating whether a minimal `summary.yml` workflow is susceptible to:

- attacker-influenced issue summarization
- shell injection when LLM output is inlined unsafely into `gh issue comment --body`

## What this repo does

The workflow in `.github/workflows/summary.yml`:

1. triggers automatically on `issues.opened`
2. sends raw issue title/body to `actions/ai-inference`
3. posts the model output back to the issue with `gh issue comment`

The repository is currently configured with the intentionally unsafe form:

```yaml
gh issue comment $ISSUE_NUMBER --body '${{ steps.inference.outputs.response }}'
```

That form is useful for validating shell breakout when model output contains a single quote.

The PoC issue body in `poc/issue-body.md` asks the model to include a unique marker:

`AWI_POC_MARKER_9E1B`

If that marker appears in the workflow-generated issue comment, the workflow has been influenced by attacker-controlled issue content.

## Files

- `.github/workflows/summary.yml`: test workflow using inline single-quoted model output
- `poc/issue-body.md`: issue body used to validate attacker-influenced comments
- `poc/shell-injection-issue-body.md`: issue body used to validate shell breakout
- `scripts/run_poc.sh`: creates a test issue, waits for the workflow run, and checks the resulting comments for the marker
- `scripts/run_shell_injection_poc.sh`: creates a shell-injection test issue, waits for the run, and checks logs for an execution marker

## Notes

- This repo is intended for controlled validation in a private repository you own.
- The workflow uses `actions/ai-inference`, so the account/repository must have access to GitHub Models.
- The result may vary by model behavior and model-side content filtering.
