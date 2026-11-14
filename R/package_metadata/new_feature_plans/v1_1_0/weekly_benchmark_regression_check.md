# Weekly Benchmark Regression Check on GitHub-Hosted Runners

> **Release:** v1.1.0 TODO-195 (`../../future_release_plans/release_v1_1_0.md`). Owner request 2026-11-13.
>
> **Implemented 2026-11-14 as a NIGHTLY job, not weekly** (owner ruling): `.github/workflows/nightly.yml`, jobs
> `bench-build` and `bench`, verdict `R/benchmark/benchmark_abba_verdict.R`, allowlist
> `R/benchmark/benchmark_regression_allowlist.csv`. Differences from the design below: the baseline is the newest
> release tag (`v*`) reachable from `main`, not the last benchmarked commit; the skip is "no functional R/C++ line
> changed since the previous nightly run"; no `--shard` yet. The utility section's six unexported `fast_*` kernels
> compile from the checkout's headers (`fast_math_utils_bench.cpp` includes `../EDI/src/*.h`), so both sides time
> the current code there and those rows can never flag. Phases 0 and 4 now run inside every nightly `bench` job (2026-11-14): each run's wall time goes to the step summary (Phase 0), and `R/benchmark/benchmark_canary_check.R` injects a 3x slowdown into one stable row of that night's real reports and requires the same comparison and verdict to flag it, else "Benchmark CI bug" (Phase 4, as a standing self-test instead of a one-off replay of an old commit).
>
> **Related:**
> - `R/benchmark/benchmark_model_fits.R` (about 90 minutes for all five sections: models, wald, utility,
>   procedures, designs; `--sections` runs a subset).
> - `R/benchmark/compare_benchmark_runs.R`: compares two benchmark reports and exits 1 on a regression
>   (`--ratio`, `--min-delta-ms`, `--normalize-host`, `--allow`). Reused as is.
> - `comprehensive_tests_cloud_campaign.md` (TODO-194), which shares the runner budget.

## Goal

Every week, check whether EDI got slower between the last benchmarked commit and the current `main`, and fail the
run only on a regression. Owner rules (2026-11-13):

- **No published results.** Nothing goes to a results branch, a release, a commit, the README or an uploaded
  artifact. The only output is the run's pass/fail status, its log and its step summary.
- **Fail only on a regression from one commit to another**, never on an absolute timing.
- **Skip when no functional R or C++ code changed** since the baseline commit.

Not goals: replacing the release benchmark regeneration (release gate G2 still regenerates the reports by hand),
the Python benchmark, or comparing against other packages.

## Design

### 1. Trigger and baseline

`.github/workflows/benchmark-weekly.yml`: `schedule` once a week (Sunday 05:00 UTC, away from the calibration
start on the 1st at 03:17), plus `workflow_dispatch` with optional `base` and `head` SHAs for a manual check.

- **head** = `main` at run time.
- **base** = the head SHA of the most recent run of this workflow that **succeeded** (benchmarked or skipped),
  from `gh run list --workflow benchmark-weekly.yml --branch main --status success --json headSha`. With no
  earlier success, the newest release tag (`v*`, today `v1.0.2`).
- Because a failed run does not move the baseline, a regression keeps failing every week until it is fixed or
  allowed (section 4). A skipped run does move it: nothing functional changed, so the timings are the same code.

### 2. Skip unless functional code changed

A `decide` job (no R) diffs base..head and benchmarks only if a **functional** line changed:

- Paths: `R/EDI/R/**/*.R`, `R/EDI/src/**/*.{cpp,h,hpp,c}`, `R/EDI/src/Makevars*`, `R/EDI/configure*`, and the
  `Imports`/`LinkingTo` fields of `R/EDI/DESCRIPTION`.
- A changed line counts only if it is not blank and not a comment once trimmed (`#`, including roxygen `#'`, in
  R; `//` and lines inside `/* ... */` in C/C++). Roxygen-only, comment-only and whitespace-only changes skip.
- The check is a small script, `.github/scripts/functional_code_changed.py` (git diff `-U0` over those paths),
  with a unit test on fixture diffs. Its output names the first few functional changes so a skip or a run is
  explainable from the log.
- When it skips, the run ends green with a one-line step summary ("no functional R/C++ change since <base>").

### 3. Build both commits, then time them alternately on the same runner

- `build` installs EDI at base and at head into two separate libraries (`R CMD INSTALL --strip`, `EDI_PORTABLE=1`,
  as the calibration study's build job), each cached by SHA, so next week's base is usually a cache hit.
  The comparator packages the benchmark loads (VGAM, ordinal, pscl, betareg, quantreg, ...) come from
  `setup-r-dependencies` once.
- `bench`: one job per section, `max-parallel: 3`. In each job the section runs four times, alternating
  libraries in the order **base, head, head, base** (ABBA), each in a fresh `Rscript` with `R_LIBS` pointing at
  one library. ABBA cancels a linear drift in runner speed over the job (thermal, noisy neighbours).
- Fixed `--cores 1` and pinned BLAS threads (`OPENBLAS_NUM_THREADS=1`), so the comparison does not depend on how
  many vCPUs the runner has.

### 4. Verdict

Per section, using `compare_benchmark_runs.R --normalize-host --ratio 1.25 --min-delta-ms 0.05`:

1. **Noise floor.** Compare base run 1 with base run 2, and head 1 with head 2. A row that "regresses" between
   two runs of the same code is noisy on this runner and is excluded this week, listed in the summary as
   "too noisy to judge".
2. **Regression.** Compare base 1 with head 1 and base 2 with head 2. A row fails only if it regresses in **both**
   comparisons and was not excluded in step 1.
3. **Allowed regressions.** `R/benchmark/benchmark_regression_allowlist.csv` (row regex, reason, date, until
   SHA or release) is passed as `--allow`. Each allowed row must name why the slowdown is accepted, as the path
   audit allowlist does.

The `verdict` job fails if any section has a regression that is not allowed, with an annotation
"Benchmark regression" per row (row, base ms, head ms, ratio). Any other failure (build, a crash in the
benchmark) is annotated "Benchmark CI bug", so the two cannot be confused. The step summary holds the table; no
artifact is uploaded.

### 5. Runner budget

- A full section set is about 90 minutes once; four runs is about 6 hours of compute, split over 5 jobs. Phase 0
  measures each section on a hosted runner. A section over about 60 minutes for four runs gets a `--shard i/k`
  option in `benchmark_model_fits.R` (rows split deterministically) so no job holds a slot for hours.
- Concurrency group `benchmark-weekly`, `cancel-in-progress: true` for a newer weekly run. At most 3 slots,
  which with calibration's 16 still leaves one for push CI; if that proves too tight, it joins the study sweeper
  (TODO-194) as a lower-priority entry.
- The utility section compiles `benchmark/fast_math_utils_bench.cpp` with `Rcpp::sourceCpp`; that is fine in the
  cloud (the CLAUDE.md compile limits are about the owner's machine).

## Phases

- [ ] **Phase 0: measure.** One `workflow_dispatch` run with base = head (same commit both sides): per-section
  time and how many rows the noise filter excludes. With identical code, the verdict must pass; if it does not,
  raise `--ratio` or the run counts before going further.
- [ ] **Phase 1: functional-change detector** (`functional_code_changed.py` and its test).
- [ ] **Phase 2: workflow** (`decide`, `build`, `bench`, `verdict`), with `--shard` added only if Phase 0 shows a
  section needs it.
- [ ] **Phase 3: allowlist** file and its `--allow` wiring.
- [ ] **Phase 4: validate.** A dispatch run with base = an older commit with a known speedup or slowdown (for
  example before and after a documented kernel change) must show it, in the right direction.

## Watch out

- `--normalize-host` divides by the median ratio of the comparator packages' times, which no EDI change affects.
  Base and head use the same comparator package versions in one run, so this is valid within the job.
- Never compare across runs or runner images: only the four runs inside one job are compared.
- Thread-count reproducibility (v1.0.5 TODO-95, v1.1.0 TODO-48) does not affect timing comparisons at a fixed
  `--cores 1`.
