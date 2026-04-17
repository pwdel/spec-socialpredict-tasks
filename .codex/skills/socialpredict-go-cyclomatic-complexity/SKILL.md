---
name: socialpredict-go-cyclomatic-complexity
description: Run `gocyclo` against SocialPredict Go code and summarize cyclomatic-complexity hotspots. Use when a user asks to check cyclomatic complexity, review complexity regressions, identify hard-to-maintain functions, or compare complexity before and after a backend refactor.
---

# SocialPredict Go Cyclomatic Complexity

## Workflow

1. Confirm the target repo and scope. Default to `../socialpredict/backend` when working from this control workspace.
2. Read `references/gocyclo-guidance.md` for thresholds, output format, and reporting rules.
3. Run `scripts/run_gocyclo.sh [repo-dir] [over-threshold] [targets...]`.
4. Report the exact command, threshold, and highest-complexity functions with file references.
5. Separate production hotspots from test-only noise when that distinction matters.
6. If `gocyclo` is missing, stop and report the install command instead of inventing another metric.

## Defaults

- Default repo dir: `../socialpredict`
- Default `gocyclo -over` threshold: `4`
- Default target list: `.`

The default threshold reports functions at complexity 5 or higher via `gocyclo --over 4 .`.

Raise the threshold when the user wants a shorter actionable list:

- `4`: broad hotspot scan
- `8`: likely-maintenance-risk functions
- `10`: only the most complex functions

## Output Requirements

- State the exact command that was run.
- State whether the run covered all of `backend/` or a narrower target.
- Highlight the top production-code hotspots first when test files dominate the output.
- Keep recommendations focused on decomposition or boundary cleanup; do not propose broad rewrites unless the user asks.
- If the command could not run because `gocyclo` is not installed, say that explicitly and include the install hint from the script output.

## Resources

- `references/gocyclo-guidance.md`: thresholds, output interpretation, and reporting guidance.
- `scripts/run_gocyclo.sh`: wrapper that runs `gocyclo` against the SocialPredict backend.
