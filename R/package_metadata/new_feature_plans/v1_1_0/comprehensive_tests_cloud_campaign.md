# Run `comprehensive_tests.R` in the Cloud After Each Calibration Campaign

> **Release:** v1.1.0 TODO-194 (`../../future_release_plans/release_v1_1_0.md`). Drafted 2026-11-13 at the owner's
> request; owner placed it in v1.1.0 the same day.
>
> **Depends on:** the calibration study workflow (`.github/workflows/calibration-study.yml`) and the per-case
> seeding of `comprehensive_tests.R` (2026-11-12, `comprehensive_case_seed()`).
>
> **Related:**
> - `R/package_tests/comprehensive_tests.R`, `comprehensive_tests_watchdog.R`, `comprehensive_results_path.R`,
>   `merge_comprehensive_slice_results.R`, `audit_comprehensive_results.R`.
> - `.github/workflows/test-coverage-R-advanced.yml` runs the comprehensive **suite** smoke tier
>   (`run_comprehensive_suite.R`). That is a different harness and is not changed here.

## Why

The calibration study simulates its data. `comprehensive_tests.R` is the only harness that runs every inference
class on real covariates (Boston, Cars93, diamonds, Pima and the packaged example, with a synthetic treatment
effect), and it runs only on the owner's machine:

- A full regeneration takes days of local compute. The ordinal file alone holds 567,005 rows and 222 CPU-hours
  of calls (50 reps, 2 effects, 5 datasets, 7 designs; measured 2026-11-13 from the local CSV). The six raw files
  total 2.6 GB. The other five response types were not measured for this plan.
- The raw files are gitignored, so nobody else can see or reproduce them, and release gates that read them
  (path audits, the results audit) depend on one machine.
- Regenerations happen at whatever commit is checked out, so results from different commits end up mixed.

## Goal

After a calibration campaign completes, the same commit is run through `comprehensive_tests.R` on GitHub's free
hosted runners, and the results are published next to the calibration results.

Not goals: making it a required check, running it on push or PR, adding it to the pre-push hook, or changing
what the harness tests.

## Design

### 1. Trigger: dispatched by the campaign's last wave

`calibration-study.yml`'s `publish` job already dispatches the next wave while the campaign is unfinished. When
`needs.analyze.outputs.complete == 'true'` it instead dispatches the new workflow:

```
gh workflow run comprehensive-study.yml -f campaign="$C" -f sha="<campaign sha>"
```

- Not `workflow_run`: every wave is its own run of `calibration-study.yml`, so `workflow_run` would fire once
  per wave.
- `comprehensive-study.yml` also takes `workflow_dispatch` by hand (blank campaign = start one at this commit),
  with inputs for reps, response types, datasets and designs, so a subset can be run alone.
- A calibration campaign that ends red still dispatches it. The two answer different questions.

### 2. Job graph: the calibration study's, reused

`plan -> build -> roster -> shards -> analyze -> publish`, in waves of at most 256 matrix jobs, each wave
dispatching the next until the ledger is empty.

- **build.** Same commit, so the EDI library cache (`calibration-study-edi-<ImageOS>-<sha>`) and the R runtime
  cache are usually still warm. Move the existing `build` job into a reusable workflow
  (`.github/workflows/_study-build.yml`, `workflow_call`) that both studies call, so the 90 lines are not copied.
  A cache miss rebuilds as today.
- **Concurrency.** Same group as the calibration study (`calibration-study`, `cancel-in-progress: false`), so
  the two never run together. `max-parallel: 16` and a 25-minute time box per shard, the same rule that keeps
  four slots free for push CI (owner ruling 2026-11-09, free hosted runners only).

### 3. Shard unit: one (response type, dataset, design, rep)

The runner already filters on all four (arguments 3, 4, 6 and 8), and since the per-case seeding a filtered
slice gives the same rows as the full loop.

- At 40 reps this is 6 x 5 x 7 x 40 = 8,400 units. From the ordinal file a unit averages about 7.6 CPU-minutes.
- A job runs four runner processes side by side (one per vCPU), each with `NUM_CORES = 1`, and each process
  takes a queue of units packed to the time box. `NUM_CORES` stays 1 so results do not depend on the runner's
  core count and file names stay `nc_1`.
- A planner script (`plan_comprehensive_study.R`) packs units into jobs using seconds per unit from the last
  published campaign (default 8 minutes for an unseen unit), the way `plan_calibration_study.R` does.
- Each process writes to its own `EDI_COMPREHENSIVE_RESULTS_DIR`; the watchdog (needs `processx`) stays on.

**New runner feature needed:** a soft deadline (`COMPREHENSIVE_DEADLINE_MINUTES`). The runner stops cleanly
between calls once the deadline has passed and exits with a distinct status. A unit that did not finish is
uploaded as a partial; the next wave restores those rows into the results directory and the runner's existing
resume cache skips what is done. Without this, a slow unit would either hold a slot past 25 minutes or be thrown
away.

### 4. Results

Published to the `calibration-results` branch under `comprehensive/<campaign>/` (one force-pushed commit, as now):

- `README.md`: per response type, the counts of ok / error / timeout / skipped rows, coverage and rejection
  tables by class, and the audit findings.
- The output of `audit_comprehensive_results.R` and of the path audits, run on the merged rows.
- `ledger.csv` (unit, status, seconds, run id) and `runs.txt`.
- **Raw rows, compressed.** One `csv.xz` per (response type, dataset). Measured 2026-11-13 on the first 100 MB
  of the local ordinal file: xz -6 gives 4.9 MB and zstd -19 gives 4.2 MB, about 20x. The 2.6 GB of local raw
  files would be about 130 MB, a few MB per file, so they fit in the branch. xz, to match the calibration study.
- **Logs, compressed.** One `log.xz` per shard process (runner output and watchdog records). Measured on the
  first 100 MB of the largest local log: 3.4 MB with xz -6, about 29x; the 1.2 GB of local logs would be about
  40 MB. Heartbeat logs are not kept.
- **Retention.** Campaigns sit side by side on the branch, so raw rows and logs are kept for the two newest
  campaigns only; older campaigns keep their README, audit output and ledger. Phase 0 confirms the sizes on all
  six response types.

A local script (`fetch_comprehensive_cloud_results.R`) downloads a campaign's raw rows into a directory. Merging
them into the local canonical files stays a manual, explicit step with `merge_comprehensive_slice_results.R`,
because results from different commits must not be mixed silently.

### 5. Gate

Never a required check. A finished campaign goes red only on findings in the results:

- a results-audit finding that is not in `comprehensive_results_audit_baseline.csv`;
- a path-audit failure;
- a unit whose estimates do not vary across reps (the symptom of the pre-2026-11-12 seeding bug).

Annotated "Comprehensive gate". Any other failure is annotated "Comprehensive CI bug", matching the calibration
study. Interim waves only publish.

## Budget

Rough, from the ordinal file only: if the other response types cost about the same per unit, 8,400 units are
about 1,100 CPU-hours on the owner's machine. Sixteen jobs of four processes is 64 processes, so about 17 hours
of wall time plus roughly 20 minutes of fixed cost per wave (3 to 4 waves), if hosted runners were as fast.
They are slower, so expect one to two days. The continuous and count files are far larger than ordinal's share
would suggest, so the real number may be several times higher. Phase 0 replaces this guess with a measurement.

Since the calibration study starts on the 1st of each month and itself runs for days, both must fit in a month.
If they do not, the levers are fewer reps (the cloud run could use 20), or running only the response types whose
classes changed since the last campaign.

## Phases

- [ ] **Phase 0: measure.** From the local raw files: CPU-hours per unit for all six response types, the tail
  (units over 25 minutes), and xz size per (response type, dataset). Check that `dependencies: "all"` in the
  build job installs what the datasets and watchdog need (`MASS`, `ggplot2`, `processx`, `data.table`). Run three
  units by hand on a hosted runner (`workflow_dispatch` with filters) to get the runner-to-local speed ratio.
  Confirm the compressed sizes and decide reps from the numbers.
- [ ] **Phase 1: runner deadline.** `COMPREHENSIVE_DEADLINE_MINUTES` in `comprehensive_tests.R`, with a
  reference test that a deadline-stopped run resumed to completion gives the same rows as an uninterrupted one.
- [ ] **Phase 2: planner and ledger.** `plan_comprehensive_study.R` (units, packing, wave selection) and the
  ledger format, with tests on a toy roster.
- [ ] **Phase 3: workflow.** `_study-build.yml` extracted; `comprehensive-study.yml` with the job graph above;
  first run restricted to one response type and one dataset.
- [ ] **Phase 4: analyze and publish.** Merge shard rows, run the results audit and path audits, write the
  README and ledger, publish, dispatch the next wave.
- [ ] **Phase 5: chain and gate.** The dispatch step in `calibration-study.yml`'s `publish` job, the gate
  verdict, `fetch_comprehensive_cloud_results.R`, and the release runbook wording for the path-audit gate (cloud
  or local, whichever completes first at the release commit).
- [ ] **Phase 6: first full campaign.** Compare its audit output with the local baseline and write down every
  difference before trusting the gate.

## Watch out

- Rows written before and after the 2026-11-12 per-case seeding come from different random streams. A cloud
  campaign is self-contained at one commit; never top it up from older local rows.
- The thread-count reproducibility bug (v1.0.5 TODO-95, v1.1.0 TODO-48) is why `NUM_CORES` is pinned to 1.
- Hosted runners differ from the owner's machine in BLAS and CPU. Timeouts (`COMPREHENSIVE_FUNCTION_TIMEOUT_SEC`,
  120 s) will trip on different calls, so timeout rows are reported but never gate.
- The harness's MC coverage truths for nonzero effects are cached per run; each shard would recompute them.
  Compute them once in `roster` and hand them to the shards, or the truth for one cell could differ between
  shards.
- The pre-push hook must not come to depend on this (it stays lean; contributors do not run the harness).

## Owner decisions (2026-11-13)

1. **Release:** v1.1.0 (TODO-194).
2. **Raw rows and logs:** compressed, on the results branch (see Results).
3. **Path-audit gate:** the cloud campaign and a local regeneration are both accepted. Whichever finishes first
   ungates. The set used must be complete and from the release commit; cloud and local rows are not combined to
   make one. Phase 5 updates the release runbook wording to say so.

## Reps and power

The harness's rejection rate at the nonzero effect is a power estimate, and its precision depends on how the rows
are pooled. 95% half-width at the worst case (power 50%):

| Rows pooled | Rows at 40 reps | Half-width | Reps for ±5 points |
|---|---|---|---|
| one cell (class, dataset, design) | 40 | ±15.5 | 385 |
| class and dataset, 7 designs pooled | 280 | ±5.9 | 55 |
| class, 5 datasets and 7 designs pooled | 1,400 | ±2.6 | 11 |

- Per-cell power to ±5 points needs about 385 reps, ten times the compute. That does not fit a monthly campaign
  on free runners, and the calibration study already does it on simulated data (500 reps, ±4.4 points).
- 50 reps gives about ±5 points per class and dataset with designs pooled. That is the recommended cloud setting;
  40 gives ±6.
- Comparing two classes needs fewer reps than the table says: a case's data and assignment are seeded from its
  key, so the classes see the same draws and the comparison is paired.
- Size at 5% is only usable pooled: one cell at 40 reps is ±6.8 points, a class over all datasets and designs is
  ±1.1.

Open: 40 or 50 reps (owner).
