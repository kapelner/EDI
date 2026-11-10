# Rate-derived calibration gate

> **Release:** v1.0.5 TODO-200 (`future_release_plans/release_v1_0_5.md`).
> **Depends on:** TODO-192 (regime registry, current step-schedule gate),
> TODO-193 (convergence-rate registry and resolver
> `inference_convergence_expectation()`), TODO-199
> (`calibration_convergence_slopes.md`: `convergence_calibration_study.R`,
> `summary/convergence_summary.csv`, the power-law fit and verdicts).
> **Owner decision 2026-11-10:** implement all seven points below as proposed,
> with the cap at 0.10 reached at n_eff = 50, the rate check gated, and the
> analysis run from `main` with both commits recorded.

Status: IMPLEMENTED 2026-11-10 (not yet run in GitHub Actions).

## The gate

1. **Finite-sample procedures** (registry regime `finite_sample`: exact,
   rand): size level 0.05, coverage level 0.95, at every n.
2. **Asymptotic procedures with a known order** a > 0 (any basis except
   `unknown`): size level `min(CAP, 0.05 + c_a * n_eff^-a)`, coverage level
   `1 - that`, where `CAP = 0.10` and `c_a` is chosen so the level reaches the
   cap exactly at `N_CAP = 50`: `c_a = (CAP - 0.05) * N_CAP^a`. Both constants
   are single named values in `calibration_study_stats.R`. n_eff is the cell's
   nominal effective n from the registry rule (same computation TODO-199 uses;
   reuse it, do not duplicate it; rules that need data the stats lack fall back
   to n, flagged). This replaces TODO-192's step schedule
   (`CAL_GATE_ASYMPTOTIC_SCHEDULE`): remove it, and update its test.
3. **Rate check, gated.** From TODO-199's power-law fit: a cell fails when its
   verdict is `slower` (the whole CI for a below the expected order) AND its
   error at the largest n is significant at the gate's family level. Same
   two-stage logic as size / coverage: it enters the BH screen, and a flagged
   cell's confirmation replicates must reproduce the significant large-n
   excess. Applies to size and coverage errors, not bias.
4. **Unknown-rate cells** (`basis = "unknown"` or order NA): the cap at every
   n below the campaign's largest n; at the largest n, the regular level
   (a = 1). A failure there says, in the table, "rate unknown: open a TODO to
   establish it".
5. **O(1) design-mismatch cells** (expected order 0): gate one-sided only, the
   anticonservative side (size above 0.05 / coverage below 0.95 at the cap
   rule with a = 1); conservative results are reported as "conservative
   (expected: model SE ignores the design)", never failed.
6. **Bias**: reported, not gated. Add a flag `bias_sd_large_n` when |bias|/SD
   > 0.1 at the campaign's largest n (null and non-null), shown in the bias
   tables and README; not part of `gate_failures.txt`.
7. **Unchanged:** two-stage screen + confirmation (BH q < 0.05, 5,000
   confirmation replicates, 0.01 / flagged), accepted rows override a cell's
   level and must cite a TODO, campaigns go red only at completion.

Every summary table shows, per cell: regime, n_eff (rule and value), expected
order and basis, the level tested against, and which rule set it (finite,
rate, cap, unknown, mismatch, accepted). The campaign README's About text
explains the rule in a few sentences, including the honest resolution limit:
5,000 confirmation replicates detect an excess of about 0.006 at the largest n,
so "nominal" there means no worse than about 0.06.

## Workflow: analysis from `main`, both commits recorded

`.github/workflows/calibration-study.yml` publish job: keep the campaign's
pinned commit for the EDI build and simulation (plan, build, shards
unchanged), but check out the analysis scripts (`R/package_tests/calibration/`
and the registry file `R/EDI/R/inference_procedure_regime.R`) from the
workflow run's own commit (`github.sha`, i.e. `main` at dispatch). Record both
in the campaign README and `campaign.env` / summary: "simulated at <pinned
sha>, analysed at <analysis sha>". Run actionlint
(`/snap/actionlint/current/bin/actionlint`). This lets the running campaign
(`2026-11-09-8c32d060`) be gated by these rules at completion.

## Workflow: analysis as its own check job before `publish` (owner, 2026-11-10)

The gate and the convergence post-processing (TODO-199's
`convergence_calibration_study.R`) run in a dedicated job between `shards`
and `publish` (e.g. `analyze`: `needs: [plan, shards]`), not inside `publish`.
It merges the wave's stats, runs `analyze_calibration_study.R` (gate),
`convergence_calibration_study.R` (slopes + rate check), the design comparison
at completion, and renders figures / README, and hands the outputs to
`publish` as an artifact. Its result is the campaign's check status: it fails
(red) only when a completed campaign has confirmed failures, exactly as the
gate step does today. `publish` then only pushes the artifact to
`calibration-results` and dispatches the next wave; it runs whatever the
`analyze` result (`if: always() && needs.analyze.result != 'cancelled'` or
equivalent), so failing results are still published. Move the existing
analysis steps out of `publish` rather than duplicating them; keep step
order and outputs identical otherwise. If TODO-199 already added its step to
`publish`, move it into `analyze`.

**Failure contract (owner, 2026-11-10).** The only statistically meaningful
red X is the `analyze` job's last step, named `Gate verdict`, which fails
only when a completed campaign has confirmed failures (it emits a
`::error title=Calibration gate::` annotation naming the count and the
summary link). Every other failure — plan, build, any shard, publish, or an
earlier `analyze` step (script error, missing file) — means a bug in the
check itself, never a calibration result. Make that true and visible:

* Audit every job for paths where a statistical outcome could fail a step
  (e.g. a replicate whose fit errors must be recorded as a row status, not
  stop a shard; a cell with no finite results must not crash the analysis)
  and fix any you find.
* Earlier `analyze` steps and the other jobs, on failure, emit a
  `::error title=Calibration CI bug::` annotation (an `if: failure()` step per
  job) so a red X from them is never mistaken for a gate result.
* The README / summary says which of the two a red campaign is.

## Tests

* Level function: finite-sample 0.05 at all n; a = 1 gives 0.10 at n_eff <= 50,
  0.075 at 100, 0.0625 at 200, 0.0525 at 1000; a = 0.5 gives 0.10 at 50 and
  `0.05 + 0.05 * sqrt(50/n)` beyond; unknown gives the cap below the largest n
  and the a = 1 level at it; mismatch is one-sided.
* End-to-end on a synthetic stats directory (as `test-calibration-gate-regime-levels.R`
  does): a regular cell at 0.07 for n = 50 passes, at 0.07 for n = 1000 fails;
  rand at 0.07 fails at n = 50; a cell converging at n^-1/2 when 1 is expected
  with a significant excess at 1000 fails the rate check; a conservative
  mismatch cell passes; an accepted row overrides; bias flag set when
  |bias|/SD > 0.1 at the largest n.
* Re-gate the published wave tables of `2026-11-09-8c32d060` (results-branch
  clone at `/tmp/claude-1000/resbr2/`; re-clone if stale) and record the
  failing-cell count and classes in Done (n = 50 only so far, so the rate check
  and unknown rule are inactive; say so).

## Constraints

* No package build; the gate scripts run without EDI. Do not edit
  `inference_procedure_regime.R` (report a needed field instead).
* Test file names carry no TODO number; cite "v1.0.5 TODO-200" in a top
  comment. Update `calibration_gates.md` and `release_v1_2_0.md` TODO-36 notes
  with one line each.

## Done

Implemented 2026-11-10, with TODO-201 (README split) and the overview-label fix. No package build; `inference_procedure_regime.R` untouched (no field needed).

**Gate.** `calibration_study_stats.R`: `CAL_GATE_CAP` (0.10), `CAL_GATE_N_CAP` (50), `cal_gate_size_level()`, `cal_gate_regime()` (stops on an unregistered label), `cal_gate_levels(regime, order, basis, n_eff, at_largest_n)` returning level and rule (finite, rate, cap, unknown, mismatch); `CAL_GATE_ASYMPTOTIC_SCHEDULE` removed. `convergence_calibration_study.R` gained `conv_expectations()` (registry expectation and nominal n_eff per row; the gate and the convergence study share it, no duplicate), a per-cell `tryCatch` (a failed fit is `undetermined`), and no longer swallows script errors. `analyze_calibration_study.R`: per-cell n_eff, order, basis, rule and level columns (calibration / power summaries), rate check, `note` (unknown rate, conservative mismatch), `bias_sd_large_n` in both bias tables and the markdown, `--convergence`. Rate check as implemented: a cell whose verdict for a metric is `slower`, at its largest n, on the anticonservative side, not accepted, is tested at the nominal 0.05 / 0.95 (rule `rate_check`); it is an ordinary row of the BH screen and its confirmation replicates are judged against the same nominal level (the planner needed no change). "Campaign's largest n" = largest n_nominal among null cells for null tables, among power cells for power tables (and per estimand table for the bias flag).

**Workflow** (`calibration-study.yml`, actionlint clean): `plan -> build -> shards -> analyze -> publish`. `analyze` (needs plan, shards; `always()` and plan ok and wave != 0) checks out the run's own commit (analysis scripts, registry) and the pinned commit under `pinned/` (planner, merge: they must match the shards), merges the wave, uploads `study-rows`, then convergence + analyze + plan (re-plan, COMPLETE), design comparison at completion, convergence, analyze / plot / README, stages `campaigns/<id>` plus the top README into the `study-results` artifact, sets output `ready=true`, then `Flag a bug in the check` (`if: failure()`) and last `Gate verdict` (`if: success() && COMPLETE`). `campaign.env` gets `ANALYSIS_SHA=` (SHA= stays the simulation commit); README master and job summary say "simulated at X, analysed at Y". `publish` (needs plan, analyze) runs when `!cancelled()`, analyze result is success or failure, and `analyze.outputs.ready == 'true'`: it clones the branch, overlays the artifact, force-pushes, dispatches the next wave unless complete. So a red gate still publishes; an analyze crash before the handoff does not (nothing merged for that wave: partial summaries would be inconsistent with the stats, and the next wave would plan from stale confirm_cells). Recovery: re-run failed jobs on the same run (shard artifacts live 3 days; the re-run reuses the same github.sha, so a script fix needs the shard artifacts downloaded and merged by hand).

**Audit (statistical outcome that could fail a step), fixed unless noted:** (1) `analyze_calibration_study.R` crashed when no cell had enough results (zero-column `gate` table in `fkey`) and when only power cells / no null cells exist (`data.frame` with a zero-row `s`); (2) it crashed on absent `tests.csv.gz` (`cal_stats_prepare(NULL)`) and on absent `est.csv.gz`; (3) convergence swallowed all errors into exit 0 (hiding bugs) while one fit error per cell could throw (`uniroot`): now per-cell `undetermined`, real errors fail the step; (4) re-plan step divided by `reps_total` (guarded). Not changed (not my files): `run_calibration_study.R` counts a replicate that fails outside the per-fit tryCatch as done, so a deterministic data-generation bug yields a green shard with no rows (candidate: exit non-zero when every replicate failed); a shard killed by the 75-minute timeout cannot run its annotation step. Annotations: `Calibration CI bug` step in plan, build, each shard, analyze, publish; `Calibration gate` only in `Gate verdict`.

**Tests.** `test-calibration-gate-regime-levels.R` rewritten (12 tests, 72 expectations: level function incl. 0.10 / 0.075 / 0.0625 / 0.0525, a = 0.5, unknown and mismatch; end-to-end: regular cell 0.07 passes at 50 and fails at 1000, rand 0.07 fails at 50, unknown cell, one-sided mismatch with the conservative note, accepted override, the rate check on a synthetic n^-1/2 cell with convergence run first and the control cell, bias flag, edge cases without testable cells / with a zero-result cell / without stats). `test-calibration-convergence-slopes.R`: 8 tests, 69 expectations (70 with `EDI_CAL_PUBLISHED_STATS_DIR`), 0 failed. `test-calibration-readme-pages.R`: 4 tests, 159 expectations (below).

**Re-gate of 2026-11-09-8c32d060** (fresh clone of `calibration-results`, wave 8, n = 50 only plus pair-switching 52; analyze + convergence into scratch, not final): old strict gate 1,792 failing cells; new gate 242 failing cells (233 at n = 50, 9 at 52) in 16 classes: CountZeroInflatedNegBin 109, CountZeroInflatedPoisson 49, CountHurdlePoisson 39, OrdinalCauchitRegr 26, IncidExtendedRobins 4, IncidKKCondLogitGLMMOneLik 2, IncidLogBinomial 2, OrdinalGCompMeanDiff 2, OrdinalKKGEE 2, and one each ContinLin (Bernoulli@0.2, n_eff 10), IncidBinomialIdentityRiskDiff, IncidKKCondLogitOneLik, SurvivalGLMMWeibullFrailtyLoggammaOneLik, OrdinalContRatioRegr, OrdinalKKGLMM, OrdinalPartialProportionalOddsRegr. By rule: 132 unknown, 73 cap, 37 finite (all `rand`). Rate check and the unknown rule's large-n branch are inactive (one sample size; every verdict undetermined / not applicable); 112 design-mismatch cells reported conservative; `bias_sd_large_n` set on 48 of 2,432 null-bias cells; 415 tests flagged at the screen (provisional).

**TODO-201 (README split).** `render_calibration_study_readme.R` writes `README.md` (title, status, simulated / analysed commits, summary counts, which-red note, contents table, short Data / About) plus flat sub-pages next to it so `summary/` and `figures/` links stay valid: `failing-<rt>.md` x6 (display order continuous, incidence, count, proportion, survival, ordinal), `flags.md`, `null-bias.md`, `nonnull.md`, `designs.md`, `convergence.md`, `figures-<rt>.md` x6 (the plot fragment regrouped by response type, null and non-null), `data.md`, `about.md`. Each starts and ends with `[<- Campaign <id> summary](README.md)`. Pages are built from the analysis markdown (split at `###`; the failing table split by response type), `confirmation_summary.csv`, `design_comparison.csv`, `convergence_summary.md` and `figures.md` (kept, as the plot fragment). Rendered against the published campaign: master 54 lines (was 917); failing pages 12 / 21 / 208 / 10 / 12 / 44 lines; all 63 link / back-link expectations pass (`EDI_CAL_PUBLISHED_CAMPAIGN_DIR`). The top-level index still links each campaign's master.

**Overview labels.** `plot_calibration_study.R`: `save_both()` re-themes after the figure is built and wiped `theme(axis.text.x = ...)`; the null and non-null overview grids and the convergence verdict grids now use `scale_x_discrete(guide = guide_axis(angle = 45))` (convergence grid was 90) with extra figure height. Rendered the published campaign's figures into scratch: `overview-continuous.png` and `overview-count-dark.png` are readable.

**Deviations / notes.** The master's Summary keeps the analysis's count paragraphs; the Levels paragraph moved to About. `figures.md` stays in the campaign directory as the plot fragment. The rate check substitutes the nominal level for the cell's level at its largest n rather than adding a separate row, which is what makes screen and confirmation reuse the existing machinery; "significant at the gate's family level" is therefore the usual BH-then-0.01/m test against nominal.
