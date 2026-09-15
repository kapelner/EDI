# Implement a `lintr` Policy — Codify the House Style, Then Gate It

> **Depends on:** none (pure repository hygiene; no runtime code changes).
> Written 2026-09-16, user decision, growing out of the CONTRIBUTING.md /
> pre-push-hook work: the question "should lintr run in the pre-push hook?"
> turned out to have no honest yes/no answer until the repo has a `.lintr`
> that describes the code as it actually is. *(maintenance)* — no
> user-visible effect. (Global ordering: see `_master.md`; release index:
> `release_v1_1_0.md → TODO-23`.)

## Motivation

EDI has **no `.lintr` file anywhere** (checked: repo root and `R/EDI/`),
and `lintr` is wired into neither `.githooks/pre-push` nor any
`.github/workflows/*` (checked 2026-09-16). It is installed on the
maintainer's machine (`lintr` 3.3.0.1), so the only missing piece is a
*policy*, not tooling.

The reason a policy has to come first, rather than just dropping
`lintr::lint_package()` into the hook, is that **EDI's house style is the
opposite of lintr's defaults**, measured over `R/EDI/R/*.R` on 2026-09-16:

| Convention | EDI as written | lintr default linter |
|---|---|---|
| assignment | **26,306** statement-level `=` assignments vs. **605** `<-` | `assignment_linter` flags every `=` |
| indentation | **71,133** tab-indented lines vs. **5,622** space-indented | `indentation_linter` assumes spaces |

Running lintr with defaults would flag essentially every line in the
package. The two ways to "make it pass" — turning the linters off, or
reformatting ~26k lines to `<-` and ~71k lines to spaces — are both wrong
as a first step: the former checks nothing, the latter is a repo-wide
rewrite that would obliterate `git blame` and conflict with every open
branch. The correct first step is to **write down the style EDI actually
uses** and make lintr enforce *that*, then decide, as a separate visible
decision, whether the ~600 `<-` and ~5.6k space-indented lines are drift
to be normalized or acceptable variance.

This also matters for the agent-contribution goal: an agent that reads
`CONTRIBUTING.md` and then writes idiomatic-tidyverse `<-` / two-space code
is doing the natural thing and currently gets no signal that it doesn't
match. A `.lintr` turns the house style from tribal knowledge into a
machine-checkable contract.

## Finding 1: the style is consistent enough to codify

The counts above are not "mixed style"; they are one dominant style with a
~2% and ~7% minority. Spot-checking the `<-` sites (not exhaustive) shows
they cluster in a few files rather than being sprinkled everywhere —
consistent with individual files written or pasted in from elsewhere, not
with a deliberate per-context rule. That makes a single repo-wide `.lintr`
viable; a per-directory or per-file exception scheme is not needed.

Other observed conventions that a `.lintr` must not fight (so they must be
configured, not defaulted): R6 classes with long `public = list(...)` /
`private = list(...)` bodies (function-length and object-length linters
need generous limits or exclusion for those files); `checkmate` argument
asserts written one per line; very long roxygen `#'` lines (the
line-length linter must exclude comments or be set high — `fast_roxygenize`
and `R/EDI/tools/format_rd_width.py` already own Rd width, so lintr should
not double-police it).

## Finding 2: what lintr would genuinely add

Separate from style, lintr's *correctness* linters catch real bugs that
nothing else in the repo's gate does: `object_usage_linter` (undefined
variables, unused locals — the class of typo that only surfaces on a rare
branch), `equals_na_linter` (`x == NA`), `T_and_F_symbol_linter`,
`seq_linter` (`1:length(x)` on empty vectors), `vector_logic_linter`
(`&`/`|` where `&&`/`||` was meant), `undesirable_function_linter` (e.g.
`sapply` where the return shape matters). These are the payoff; the style
linters are the cost of admission.

## TODOs

### TODO-1 — Write `.lintr` codifying the actual style (Phase 0-style decision, then ~1 hour)

Decision to record first (user): **`=` and tabs are the house style.**
Then add `R/EDI/.lintr` (lintr reads it from the package root):

- `assignment_linter` **disabled**, or configured to allow `=`
  (`lintr::assignment_linter(operator = "=")` in lintr ≥ 3.1) — whichever
  the installed version supports; the intent is "flag `<-`", the inverse of
  the default.
- `indentation_linter(indent = 4L, hanging_indent_style = "tidy")` with
  tabs accepted, or disabled if the installed lintr cannot be told the
  indent unit is a tab — document which and why in the file.
- `line_length_linter` **excluding comments** (roxygen), set to 120.
- `object_length_linter` / `function_length` / `cyclocomp_linter`: set
  limits that the existing R6 class files pass, or exclude
  `R/EDI/R/design_*.R` and `inference_*.R` from those specific linters via
  `exclusions:`. The rule: **the initial `.lintr` must produce zero style
  findings on the current tree** — its job is to describe, not to reform.
- Keep every default *correctness* linter (Finding 2) **on**.

### TODO-2 — Baseline run and triage (~1–2 hours)

`lintr::lint_package("R/EDI")` under TODO-1's config. Expected outcome:
zero style findings by construction; some number of correctness findings.
Triage each correctness finding as (a) real bug → fix + regression test in
the same PR, (b) false positive → targeted `# nolint` with a reason, or
(c) a linter that is noisy for this codebase → disable it in `.lintr`
with a comment. Record the counts in this plan.

### TODO-3 — Decide the fate of the `<-` / space-indented minority (user decision)

Options, to be chosen explicitly rather than by default:
1. **Normalize now**, in one mechanical commit (`styler` cannot do this;
   it would need a targeted script), accepting the `git blame` cost — only
   attractive if done before many outside contributions exist.
2. **Freeze, don't fix**: `.lintr` excludes the specific files carrying
   the minority style; new code must match the house style; existing
   files migrate opportunistically when touched.
3. **Accept both**: disable the assignment and indentation linters
   entirely. Simplest, but then the style contract exists only in prose.

Recommendation: **option 2** — it enforces the rule going forward at zero
migration cost, and the exclusion list itself is a visible, shrinking
to-do.

### TODO-4 — Wire it in, in this order

1. `CONTRIBUTING.md` §3: one paragraph stating the house style and that
   `lintr::lint_package("R/EDI")` must be clean. Add
   `lintr::lint_package()` to §4's before-push list.
2. `.githooks/pre-push`: run lintr **content-gated** on changed `R/EDI/R/*.R`
   files only (mirror how `fast_roxygenize` is gated on roxygen edits), so
   it costs seconds, not a whole-package lint per push. Fail the push on
   any finding.
3. A new lightweight CI job (or a step in `test-coverage-R-advanced.yml`)
   running `lintr::lint_package()` with `lintr::sarif_output()` /
   GitHub annotations, so findings show inline on the PR. Path-filter on
   `R/EDI/R/**` and `R/EDI/.lintr`.
4. The devcontainer already installs `lintr` via
   `R/profile/install_perf_tools.sh`; add it to the Dockerfile's
   `install2.r` line so it is guaranteed, not incidental.

### TODO-5 — Python side (scope check only)

`python/` is small and already under `pytest`; `ruff` would be the analog.
Out of scope here — note only that if a Python linter is ever added, it
should follow the same "codify current style first" rule, and that
`black`/`ruff format` would be a formatting decision of the same kind as
TODO-3.

## Deferred (explicitly not in this plan)

- Any repo-wide reformat (TODO-3 option 1) — a separate decision with its
  own PR, if ever.
- `styler` integration — not needed if the answer to TODO-3 is option 2,
  and `styler` cannot produce EDI's `=`/tab style without a custom style
  guide anyway.
- Linting `R/package_tests/`, `R/benchmark/`, `R/profile/` — test/benchmark
  code has looser conventions on purpose; revisit only after `R/EDI/R` is
  clean and the rule set has settled.
