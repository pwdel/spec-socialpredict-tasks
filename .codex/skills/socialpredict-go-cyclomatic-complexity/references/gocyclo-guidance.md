# gocyclo Guidance

## Command Pattern

Use the wrapper first:

```bash
./.codex/skills/socialpredict-go-cyclomatic-complexity/scripts/run_gocyclo.sh [repo-dir] [over-threshold] [targets...]
```

Default behavior from the control repo:

```bash
./.codex/skills/socialpredict-go-cyclomatic-complexity/scripts/run_gocyclo.sh
```

That resolves to:

```bash
cd ../socialpredict/backend
gocyclo -over 4 .
```

## Thresholds

- `4`: broad scan for functions at complexity 5 or higher.
- `8`: narrower list for likely maintenance hotspots.
- `10`: only the most complex functions.

## Output Format

`gocyclo` outputs one line per function:

```text
<complexity> <package> <function> <file>:<line>:<column>
```

When summarizing results:

1. Quote the threshold and scope used.
2. Lead with production-code hotspots before tests if the output is noisy.
3. Call out repeated patterns such as large handlers, mixed responsibilities, or inline orchestration logic.
4. Suggest targeted decomposition, not broad speculative rewrites.

## Installation

If `gocyclo` is not installed, report that explicitly and use this install hint:

```bash
go install github.com/fzipp/gocyclo/cmd/gocyclo@latest
```
