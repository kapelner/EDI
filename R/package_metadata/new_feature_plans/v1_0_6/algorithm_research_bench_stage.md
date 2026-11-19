# Algorithm research: a benchmark stage before the research PR

Status: **draft for the owner** (2026-11-17). Nothing here is built yet, and no release file has a
TODO for it.

Owner request (2026-11-17): the monthly algorithm research (`.github/workflows/algorithm-audit-drift.yml`,
runbook `../v1_0_5/algorithm_audit_runbook.md`) should benchmark its own findings after the
research agents finish and before the PR is opened, as the compiled-code audit does, so that only
findings that pass a benchmark reach the PR's main section. Reuse the compiled-code audit's
benchmark code (`.github/scripts/compiled_code_verify.py`, `compiled_code_bench.R`; plan
`audit_jobs_framework.md` Part 5) rather than copy it.

## What can be benchmarked (tagging pass, 2026-11-17)

A compiled-code proposal is a source patch, so its benchmark is "the same bench code on two builds".
A research finding is a literature claim ("use X instead of Y"), and most claims need new EDI code
before they can be timed. The 120 findings of run 43925959437 were tagged by hand by what a
benchmark would need:

| tag | meaning | findings | of them `investigate` |
|---|---|---|---|
| `pkg` | the candidate is an existing CRAN or base-R function, callable on EDI's inputs | 25 | 11 |
| `existing` | route an EDI path to a kernel or option EDI already has (both sides callable today) | 7 | 4 |
| `r_rewrite` | a small rewrite of an R-level EDI function that the bench code itself can define | 6 | 5 |
| `needs_code` | new C++ or an edit inside EDI is needed first (this is the TODO's own work) | 59 | 33 |
| `not_speed` | a correctness, accuracy, estimator or policy question, with no timing claim to test | 23 | 12 |

So **38 of 120 (32%) can be benchmarked without changing EDI**, including 20 of the 65
`investigate` findings (listed in the appendix). For the other 82 the bench stage does nothing,
and they go to triage unbenchmarked, as now.

## Design

1. **Agents write bench code; they do not run it.** The research agents stay read-only (no Bash).
   The research schema gains an optional `bench` object per finding: `kind`
   (`pkg` / `existing` / `r_rewrite`), `packages` (CRAN names), `setup` (fixed-seed data at EDI's
   sizes), `current` and `candidate` (each one call: EDI's path as it runs today, and the
   candidate), and the D2 tier for the comparison (`closed_form`, or `iterative` with the solver
   tolerance; `../v1_1_0/cross_platform_reproducibility.md` D2). A finding with no `bench`
   (needs_code / not_speed) is reported as now.
2. **New jobs between `research` and `research-pr`, with no Claude.** `bench-plan` collects the
   findings with bench code. `bench-build` installs EDI from the run's commit once
   (`EDI_UNITY=0`, the flags `audit-compiled-code.yml` uses) and the candidate packages from CRAN.
   A package that is not on CRAN, or whose license is not GPL-3-compatible, is not installed, and
   the finding is reported as not benchmarked, with the reason. `bench` is a matrix with one job
   per finding.
3. **Reuse, not copy.** Both sides run in the *same* EDI build, so A is `current` and B is
   `candidate`. That fits the existing helpers as they are: `run_once(lib, code, ...)` already
   takes the library and the bench file separately, and `compiled_code_bench.R`'s
   `bench_setup()` / `bench_run(d)` contract is unchanged. The driver writes two bench files that
   share the setup code. A new `.github/scripts/algorithm_audit_bench.py` imports
   `compiled_code_verify` and uses `abba_order`, `block_diffs`, `summarize`, `compare_results`
   and `run_once`. One small refactor in `compiled_code_verify.py`, agreed with the owner of
   `audit_jobs_framework.md`:
   - extract the measure loop of `cmd_bench` into
     `measure(runs={"A": (lib, code), "B": (lib, code)}, work, blocks, tol)`;
   - give `decide()` a `min_gain` argument, keeping `MIN_GAIN` as the default.

   `cmd_bench` then calls `measure` with two libraries and one file, and its tests stay as they
   are.
4. **Verdicts.** These come from `decide()` and the same ABBA timing (20 blocks, seeded 95%
   bootstrap interval):
   - **faster:** the results agree under the declared tier, and the interval's upper end clears
     `min_gain`;
   - **not faster:** the results agree, but the candidate is not clearly faster;
   - **faster, not equivalent:** the candidate is faster, but its results move beyond the tier.
     This is an estimator change, which goes to triage as one; it is not a reject;
   - **not benchmarked:** the bench code failed, timed out, or a package could not be installed.
5. **What reaches the PR.**
   - **Main findings section:** `faster` findings, the bench table in each finding, and findings
     with no bench code, which stay marked unverified.
   - **`<details>` blocks:**
     - `not faster`. Each also gets a `research_triage.csv` row: `reject`, `approved` (an
       automatic reject, owner 2026-11-19), with the numbers in the reason. Without that row, next month's agents re-report the finding,
       because they skip only what is recorded (the compiled-code audit likewise records a closed
       proposal as rejected).
     - `not benchmarked`, with the reason.
   - **`research_log.json`:** each finding records its bench verdict, so the next run's agents
     see it.

## Owner decisions

1. **`min_gain` for research findings.** Decided (owner, 2026-11-19): `faster` needs 5% at the
   95% interval's upper end (`MIN_GAIN = 0.05`); the report still shows every ratio. (The
   compiled-code audit uses 2%; 10% was proposed.)
2. **`not faster` is an automatic `reject`** (owner, 2026-11-19), recorded as approved, with the
   numbers. A later run reopens it only with new evidence, for example different sizes.
   Exception (owner, 2026-11-19): when the bench spec does not measure what the TODO is for, the
   owner can keep the finding. Kept so far: jackknife (v1.1.0-TODO-207) and Weibull AFT #1
   (v1.1.0-TODO-213), whose Phase 0 specs (run 44048167550) timed something else.
3. **The refactor of `compiled_code_verify.py`** (design 3), which is shared with the
   compiled-code audit.

## Phases

- **Phase 0, backfill (validates the bench stage before the schema change).** One agent writes
  `bench` code for the 20 benchmarkable `investigate` findings in the appendix, and the bench jobs
  run on it. Done when each of the 20 has a verdict, or a reason it could not be benchmarked, and
  the verdicts are written into `research_triage.csv` as proposed updates.
- **Phase 1:** the schema and prompt change, `algorithm_audit_bench.py`, the three jobs, and the
  report sections. Tests: a planted finding with bench code goes through plan → bench → report in
  each of the four verdicts. Done when a `changed` run with one planted problem produces a PR
  with the bench table.
- **Phase 2:** turn it on for the monthly run, and document it in the runbook (bench stage,
  `min_gain`, what "not benchmarked" means).

Stop condition: if Phase 0 gives fewer than 5 of the 20 a definite verdict (faster / not faster /
not equivalent), the agents' bench code is not good enough unaided. Stop there, and keep
benchmarking inside each TODO, as now.

## Appendix: the 20 benchmarkable `investigate` findings (run 43925959437)

`existing`: adjacent-cat-cr-logit-mle#43925959437.2, beta-regression-mle#43925959437.1,
binary-glm-mle#43925959437.1, cumulative-link-ordinal-mle#43925959437.2.

`r_rewrite`: cox-ph-fit#43925959437.1, design-matrix-preprocessing#43925959437.1,
grouping-and-level-coding#43925959437.1, jackknife-replicates#43925959437.1,
kaplan-meier-rmst#43925959437.1.

`pkg`: blocking-partition#43925959437.2, cox-ph-fit#43925959437.3,
interval-censored-npmle#43925959437.2, interval-censored-npmle#43925959437.3,
kk21-covariate-weights#43925959437.2, logrank-family-tests#43925959437.2,
missing-covariate-imputation#43925959437.1, robust-m-regression#43925959437.2,
weibull-aft-mle#43925959437.1, weibull-aft-mle#43925959437.2, zero-inflated-count-mle#43925959437.1.

The other 18 benchmarkable findings are 12 defers and 6 rejects. Several of them (HiGHS/scip vs
GLPK, fastcluster, fastglm_ordinal) are defers whose reason is "no benchmark yet", so a bench
verdict would settle them too.
