# Calibration campaigns in class-major order, with per-class convergence pages

> **Release:** v1.0.6 TODO-21 (`future_release_plans/release_v1_0_6.md`; moved 2026-11-12 from v1.0.5 TODO-203, the
> number the code comments cite).
> **Builds on:** TODO-199 (`calibration_convergence_slopes.md`), TODO-200
> (`calibration_rate_derived_gate.md`), TODO-201 (split README).
> **Consumer:** the published calibration study (`R/package_tests/calibration/`,
> `.github/workflows/calibration-study.yml`, branch `calibration-results`).

Status: DONE 2026-11-10 (implemented; owner decisions below; see Done).

## Why

The planner orders work by n first (`plan_calibration_study.R` ~L196-198:
n, effect, design, response type). So a campaign runs every class at n = 50
null, then every n = 50 power cell, before any n = 200 null cell. The rate
check, the convergence slopes and the large-n gate all need n = 200 and
n = 1000 null cells, so no cell has a final verdict until most of the
campaign has run, and the figures show only n = 50 for weeks (campaign
`2026-11-09-8c32d060` after 13 waves: 18% of replicates, n = 50 only).

## Owner decisions (2026-11-10)

1. **Order:** null effect before non-null. Within an effect: response type;
   within it: inference class; within a class: design, then all n
   (50, 200, 1000), then the class's confirmation replicates (5,000) if any
   of its cells is flagged. A class is finished (all designs, all n,
   confirmation) before the next class starts, so verdicts become final class
   by class.
2. **Unit of work = one class with all its procedures.** Procedures (wald,
   score, LR, boot, rand, ...) share one fit on the same data, so they are
   never split. A shard is (response type, design, n, effect, class) plus a
   replicate range, run with the runner's existing `--only <class>`.
3. **Multiple-testing control over the whole campaign:**
   * Screen: Benjamini-Hochberg over *every* test the full campaign plan
     contains (m known from the plan, not from what has run so far). Tests not
     yet run enter as p = 1. BH is monotone in the p-values, so an interim
     flag is never withdrawn later (later tests can only add flags); only
     "not flagged" is provisional. State this property in the README and test it.
   * Confirmation: a flagged cell fails if its fresh replicates alone reject at
     0.01 / m_total (the total number of tests in the plan, fixed in advance),
     not 0.01 / (current number of flags), so a confirmed failure is final when
     it is made. (Owner adopted the recommended option (a); with 5,000
     replicates this still detects a size of about 0.065.) Keep the rate check
     and design-mismatch rules of TODO-200 unchanged otherwise.
   * Because confirmation of a class needs only that class's flags (which are
     permanent), it can run right after the class's screen.
4. **Asymptotic analysis per class** as soon as the class has all its n:
   `convergence_calibration_study.R` already works per cell; it runs every
   publish and a class's rows lose `provisional` once the class is complete.
5. **Figures:** one page per class (about 88 per campaign), each with one
   figure: facets procedure (rows) x metric (columns: size or coverage error,
   bias), x = n_eff, y = |error| on log-log axes, the registry's expected
   slope as a reference line, the verdict in the facet label or as text,
   effects (null, power20/50/80) as colours (same validated status/categorical
   palette as the existing figures; light and dark versions like every other
   figure). The class page also carries its cells' table (size / coverage /
   bias by design x n x procedure, gate verdict). The summary figures (overview
   grids, dot plots, convergence verdict grids) stay as they are, separately.
   The master README's contents table links a "Classes" index page listing
   each class with its status (complete / in progress / not started) and worst
   verdict.
6. **Restart:** once this is pushed, the running campaign
   `2026-11-09-8c32d060` is cancelled and a new campaign is dispatched (the
   owner does this; agents do not dispatch or cancel workflow runs). No ledger
   compatibility with the old all-classes shards is needed.

## Step 0: measure before building (report the numbers in the Done section)

Splitting by class means each class regenerates the data and re-runs the
design for every replicate (identical results: `cal_study_seed(response_type,
n, rep)` sets the seed; `cal_study_run_design`). For cheap designs this is
free; Fixed:GreedyPairSwitching, Fixed:Rerandomization, Fixed:OptimalBlocks,
Fixed:Optimal / GreedyDOptimal and the Seq KK designs may not be. Measure, on
the installed EDI, the time of data generation + design per replicate at
n = 50 / 200 / 1000 for every design, against the per-class fit time
(`R/package_tests/calibration/*costs*` or a fresh timing). If the repeated
design cost would add more than about 10% to the campaign's total, add a
cache: the runner stores each (response type, design, n, rep) assignment
(e.g. a compact `w` vector, gzip) and later class shards of the same unit
reuse it if present; otherwise skip the cache and say why.

## Implementation pointers

* `plan_calibration_study.R`: units gain a `class` key; sort as decision 1;
  the existing groups (`rest`, slow-class groups, `confirm:<only>`) become per
  class; the time-boxed wave filling keeps working (many classes' units run in
  parallel within a wave; the order decides which come first). Emit the plan's
  total test count m_total (per campaign, in `campaign.env` or a plan file) so
  analysis can use it.
* `run_calibration_study.R`: already takes `--only`; check shard.csv /
  ledger keys include the class so re-planning finds missing reps per class.
* `analyze_calibration_study.R` / `calibration_study_stats.R`: BH with
  m_total (unrun tests as p = 1); confirmation at 0.01 / m_total; class
  completeness status.
* `convergence_calibration_study.R`: `provisional` per class, not per
  campaign.
* `plot_calibration_study.R`: per-class figure (decision 5).
* `render_calibration_study_readme.R`: per-class pages + Classes index;
  keep the back-links at top and bottom (TODO-201) and the blank-line squeeze.
* `.github/workflows/calibration-study.yml`: only if the matrix / ledger
  needs it; actionlint clean. Failure contract of TODO-200 unchanged (only
  `Gate verdict` fails for a statistical reason).
* Docs: the About page and `calibration_gates.md` describe the order, the
  campaign-wide BH, the monotonicity property and the confirmation level.

## Tests (testthat_bulk; names without TODO numbers)

* Planner order: a synthetic plan sorts null before power, then response type,
  class, design, n; confirmation of a class directly after its screen.
* BH with unrun tests as p = 1: flags at any interim state are a subset of the
  final flags (property test over random p-value sequences).
* Confirmation threshold uses m_total and does not change as flags are added.
* Per-class page and figure rendered from a synthetic three-n campaign; every
  link resolves; back-links present; no double blank lines.
* Existing calibration tests still pass (`test-calibration-*`).

## Constraints

No package rebuild; R only; `load_all(compile = FALSE)` only if needed; use
the installed EDI for timing. Do not dispatch or cancel workflow runs, do not
push, do not commit. Scratch files in `$TMPDIR`. Never touch `.trail/`.

## Done

Implemented 2026-11-10. No package build or compile; the installed EDI (v1.0.4) was used only for the Step 0 timing. Not committed, not pushed, no workflow run touched.

**Step 0 (installed EDI, 3 replicates per design and n, continuous / survival / ordinal; local WSL machine, not a GitHub runner).** Data generation + design per replicate: fixed designs 0.002-0.07 s at every n except pair-switching (0.30 s at n = 50, 0.02 at 200, 0.47 at 1000), BinaryMatch (0.38 s at 1000), Optimal (0.07 s at 1000); sequential designs 0.03-0.2 s at n = 50, 0.1-0.7 s at 200, 0.5-0.8 s at 1000 (Bernoulli, iBCRD, Efron, Pocock-Simon, Urn) and 2.8-4.0 s at 1000 for Atkinson, RandomBlockSize, SPBR, KK14, KK21, KK21stepwise. The per-class fit time comes from the published campaign's per-class `fit_secs` at n = 50 (roster: median class 0.43 s per replicate, 90th percentile 1.9 s) scaled to n by `calibration_study_costs.csv`, with the slow classes at their own measured cost. Campaign total about 9,650 core-hours of fits. Repeating the design for every class (one class per shard, 13,599 shards): +722 core-hours = **7.5%** of the campaign (3.3% at n = 50, 6.6% at 200, 9.7% at 1000; at n = 1000 the three slow sequential designs would spend 159 h of design against 170 h of fits). With shards that pack neighbouring cheap classes of a cell (about 3,050 class groups): **2.7%**. **Cache decision: none** (below the 10% rule). Caveat: the roster's fit costs at n = 200 / 1000 are extrapolated from the n = 50 per-class costs, and the totals have not been confirmed on a runner; if the first waves show the design share above 10% at n = 1000, a cache of each (response type, design, n, rep) `w` vector is the follow-up.

**Files.**
* New: `calibration_study_plan_common.R` (plan units, class-major order, `cal_bh_q`, unit and class progress, constants moved out of the planner), `calibration_study_roster.csv` + `build_calibration_study_roster.R` (88 classes, 1,517 response type x design x class rows from the published campaign; the planner runs without EDI so the class list is committed), `calibration_study_synthetic_fixture.R` (synthetic three-n campaign), `testthat_bulk/test-calibration-class-major-order.R`.
* `plan_calibration_study.R` rewritten: units keyed by class, sort effect / response type (display order) / class / design / n; ledger and dead-shard accounting per class (a shard's `only` is its class list); a block's confirmation planned right after the block (no longer only when screening is over); `--plan-out` / `--plan-only` write `plan.csv` and `m_total` (88,362 tests, 13,599 units for the full plan); cost estimate = roster x cost-table scaling x correction from finished shards.
* `analyze_calibration_study.R`: reads `plan.csv` (`--plan`, default beside `stats/`): BH with `m_total` (`cal_bh_q`), a test enters when its unit's screening replicates are complete (all of them when `--final`), the plan's largest n for the unknown-rate rule and the bias flag, the rate check only on a cell whose every planned n is complete (so its level cannot change later), confirmation at 0.01 / max(m_total, tests) decided once the planned confirmation replicates are in, `class_status.csv` (status per effect group, flags, verdict). Without a plan the old behaviour is unchanged.
* `convergence_calibration_study.R`: `provisional` per class and effect group from the plan.
* `plot_calibration_study.R --class-figures`: `class-<Class>.png` / `-dark.png`.
* `render_calibration_study_readme.R`: `classes.md` index, `class-<Class>.md` pages (figure, convergence verdicts, null and power cell tables), master table row and class counts, About text (order, campaign-wide BH, monotonicity, confirmation level).
* `.github/workflows/calibration-study.yml`: the re-plan step writes `plan.csv` first (pinned planner), the plot step passes `--class-figures`. actionlint reports only the three shellcheck style warnings that HEAD already has (SC2129 line 88, SC2046 twice on the `$([ ... ] && echo --final)` lines).
* `calibration_gates.md`: one bullet.

**Deviations / decisions to check.**
1. **Shards pack neighbouring cheap classes of one cell** (`--pack-minutes`, default = the 25-minute target; `--pack-minutes 0` gives strictly one class per shard). A shard of one class per (design, n, effect) would be 13,600 jobs with minutes of setup each (about 7,000 even packed, which is what the compute needs). A class is still the ledger / unit / verdict unit, replicates are attributed per class, and a class that has lost a shard runs alone. The class-major order is therefore "a few neighbouring classes at a time" rather than strictly one.
2. Effect is the first sort key, so the confirmation of a class is per block (effect, class): after its null units, again after its power20 units, and so on.
3. A test's p-value enters the family only when its unit has all planned screening replicates (otherwise a partial p could withdraw a flag); an abandoned unit enters at `--final`. The planned m_total counts every roster row (size and coverage under the null, coverage at power effects), an upper bound (classes with no true value at a power effect have no test).
4. Class figure columns are size error, coverage error and bias (three), not two.
5. The `Classes` status is per effect group (null / power effects) because the null phase of every class finishes long before any power unit.

**Tests.** New `test-calibration-class-major-order.R`: 7 tests, 2,876 expectations, 0 failures (plan order, real roster rules, planner confirmation placement and packing, BH monotonicity property over 200 random sequences, m_total and confirmation level, class status and per-class provisional, per-class pages and figures with links, back-links and blank-line checks). Existing: `test-calibration-gate-regime-levels.R` 12 tests / 72 expectations, `test-calibration-convergence-slopes.R` 8 / 69 (1 skipped without `EDI_CAL_PUBLISHED_STATS_DIR`), `test-calibration-readme-pages.R` 4 / 208 with `EDI_CAL_PUBLISHED_CAMPAIGN_DIR` set; all 0 failures. Looked at the rendered per-class PNGs (light and dark): panel titles carry procedure, metric and verdict, no overlapping labels.

**Before restarting the campaign.** Push this commit; cancel campaign `2026-11-09-8c32d060` and dispatch a new one (the old ledger is not compatible). The roster must be regenerated (`build_calibration_study_roster.R --stats-dir <a campaign's stats>`) whenever a class, design or procedure is added; nothing checks drift automatically (a class missing from the roster would never run). Judge the first waves' design share and the shard count (about 7,000) against GitHub runner time.

## Amendment A (owner, 2026-11-10): roster generated per campaign, not committed

The committed `calibration_study_roster.csv` is built by hand from a *previous*
campaign's statistics (`build_calibration_study_roster.R --stats-dir`), so a
class added since the last campaign can never enter it, and nothing checks it.
Replace it:

1. **Workflow.** `plan` (no EDI) keeps deciding whether a campaign starts and
   pins the sha, but no longer computes the shard matrix. A new job `roster`
   (needs `plan`, `build`; restores the cached EDI install like `shards` does)
   computes the matrix and exposes it as the output `shards` reads.
   `shards` needs `roster`. `analyze` / `publish` dependencies adjusted so
   the failure contract (TODO-200) holds: only `Gate verdict` fails for a
   statistical reason; a failing `roster` job is a "Calibration CI bug".
2. **First wave of a campaign** (no `roster.csv` in the campaign folder on
   `calibration-results`): `roster` loads the EDI built at the pinned sha and
   enumerates, per (response type, design label incl. `@prob_T`), the classes
   via `cal_study_classes()` (the runner's own function) and each class's
   formulas x procedures (the same enumeration the runner uses to make its rows,
   without fitting) to get `n_size` / `n_cov`. It writes `roster.csv` into the
   campaign folder (published with the campaign like `campaign.env`).
3. **Later waves** read the campaign's `roster.csv`; the class list is frozen
   for the campaign and matches the simulated code.
4. **Costs** (`secs_n50`, used only for packing): from the previous published
   campaign's statistics where the class existed, else a conservative default;
   the planner's existing correction from `shard.csv` timings takes over after
   the first wave. Document the default.
5. **Remove** the committed `calibration_study_roster.csv` and the hand-run
   path; `build_calibration_study_roster.R` becomes the roster job's script
   (or is folded into it). `m_total` comes from the campaign's roster.
6. **Tests:** roster enumeration from the installed package matches the classes
   the runner actually runs for a sample of (response type, design, n) (no
   fitting needed); the planner reads a campaign roster and refuses to plan
   without one; the workflow's job graph (actionlint clean) has
   `plan -> build -> roster -> shards -> analyze -> publish`.

### Amendment A: Done

Implemented 2026-11-10 (uncommitted, nothing pushed, no workflow run touched, no package build; the installed EDI v1.0.4 was used).

**What changed.**
* `calibration_study_roster.csv` (untracked, never committed) deleted. `build_calibration_study_roster.R` is now the `roster` job's script: it loads EDI, and per (response type, design label incl. `@prob_T`) takes the classes from `cal_study_classes()` (the runner's function) and each class's rows from the new `cal_task_list()` in `calibration_fast_tier_common.R`, which `cal_run_tasks()` itself now calls (so the enumeration cannot drift from what is fitted; no fitting). `cal_study_common.R` gained `cal_study_throwaway_design()` (the body `cal_study_classes()` used). Options `--out`, `--response-types`, `--designs`, `--n` (class set read at n = 50), `--prev-stats-dir`.
* Planner: `--roster FILE` is required (no default); `cal_plan_read_roster()` refuses a missing, unnamed, empty or column-short roster. `m_total` is therefore the campaign roster's.
* Workflow: `plan` only starts/continues the campaign and pins the sha (no matrix, no `wave` output). `build` runs for every run (the `wave != 0` gate moved). New `roster` job (needs plan, build; restores the cached install with `fail-on-cache-miss`, like `shards`): reuses `campaigns/<C>/roster.csv` from the results branch if present, else builds it (costs from the latest other campaign directory with `stats/tests.csv.gz`), then plans the wave and outputs `matrix` / `wave`; uploads `study-roster`. `shards` needs `[plan, roster]` and is skipped at `wave == 0`; `analyze` needs `[plan, roster, shards]` and requires `roster.result == 'success'`; it downloads `study-roster`, copies it to `campaigns/<C>/roster.csv` (published like `campaign.env`) and passes `--roster "$d/roster.csv"` to both planner calls. `publish` needs `[plan, roster, analyze]` with the same roster condition. A failing `roster` job annotates "Calibration CI bug"; `Gate verdict` is still the analyze job's last step.

**Cost default.** `secs_n50` is, for a (response type, design, class) present in the previous published campaign's null screening rows, its summed fit_secs / reps at the smallest n; otherwise `CAL_ROSTER_DEFAULT_SECS_N50 = 2` s, about the 90th percentile of the classes in campaign 2026-11-09-8c32d060 (median 0.43 s). Conservative on purpose: an over-estimate only makes the packed shards smaller, an under-estimate makes them hit the time box; the planner's correction from `shard.csv` timings takes over after the first wave.

**Validation against the old roster.** Enumerating all 6 response types x 22 designs from the installed package takes 12 s and gives 1,533 rows, 88 classes: the 1,517 rows of the hand-built roster with identical `n_size` / `n_cov`, plus 16 rows it lacked (all `DesignSeqOneByOneKK21stepwise`, the old campaign had not reached them), which is the drift this amendment removes.

**Tests** (`test-calibration-class-major-order.R`, now 11 tests, 3,113 expectations, 0 failures, 0 skipped with EDI installed): no committed roster and the planner refuses to plan without one (no flag, missing file, wrong columns); the roster built from the installed package plans 88+ classes with the slow-class rules; enumeration equals `cal_study_classes()` and `cal_task_list()` (one class at a time, like `--only`) for 5 (response type, design) samples at n = 50 / 200; costs from the previous campaign else the default (synthetic and, when `EDI_CAL_PUBLISHED_CAMPAIGN_DIR` is set, the real one); the workflow's job graph and conditions. Other `test-calibration-*`: gate-regime-levels 12 / 72, convergence-slopes 8 / 69 (1 skipped without `EDI_CAL_PUBLISHED_STATS_DIR`), readme-pages 4 / 208; 0 failures. actionlint: only the three pre-existing shellcheck warnings (SC2129, SC2046 x2).

**Deviations / notes.** (1) The class set is read once per (response type, design) at n = 50 and assumed equal at 200 / 1000 (tested on samples, not enforced). (2) `CAL_PLAN_DESIGNS` in the planner is still a hand-synced list of the runner's designs; a new design still needs it extended (a test now checks the two lists are equal). (3) The roster is built for the campaign's `RESPONSE_TYPES` / `DESIGNS`, so a partial campaign has a partial roster. (4) The test file sources the study's common script into the global environment (it `source()`s the fast-tier common there), as the runner does.


## Amendment B (owner, 2026-11-10): design list discovered from the package

`CAL_STUDY_DESIGNS` (calibration_study_common.R) and its copy `CAL_PLAN_DESIGNS`
(calibration_study_plan_common.R) are hand-kept, so a new design is silently
left out of the study. Discover it instead:

1. **Discovery** (roster job, EDI loaded): every exported, concrete `Design*`
   R6 generator of the installed EDI, minus an explicit exclusion list with a
   reason per entry: `DesignFixedCluster`, `DesignFixedBlockedCluster`
   (need cluster ids the study's data do not have), `DesignFixedFactorial`
   (more than one treatment factor). Abstract bases / non-generators are
   filtered by inspection, not by name. Plus the unequal-allocation variant
   labels kept as now (`DesignFixedBernoulli@prob_T=0.2` only; widening it is
   a separate owner decision).
2. **Construction extras** (`cal_study_design_extras()`) stay a map for
   designs that need them (strata, `equal_block_sizes`); a discovered design
   with no entry is built with defaults. If it cannot be built and assigned on
   the study's data in a one-replicate smoke check, the roster job fails with a
   "Calibration CI bug" annotation naming the design and saying to add extras
   or an exclusion: loud, never silent.
3. **One source:** the campaign's `roster.csv` carries the design labels; the
   planner and analysis take designs from the roster, so `CAL_PLAN_DESIGNS`
   is removed. The runner validates `--design` against the discovered list
   (or the roster) instead of a hard-coded vector. The design sort order is
   Fixed before Seq, then a preferred order for the known designs with any new
   design appended alphabetically (documented).
4. **Tests:** discovery on the installed EDI returns exactly the current 22
   labels; a fake extra exported design (simulated by injecting a name into the
   discovery input) is included and, if unconstructible, fails loudly; the
   planner has no hard-coded design list left.

## Amendment C (owner, 2026-11-10): prob_T = 0.2 on every capable design

Every discovered design whose unequal-allocation capability is TRUE
(the package registry behind `design_supports_unequal_allocation()`,
`R/EDI/R/design_abstract.R`; TODO-183) also runs as `<Design>@prob_T=0.2`,
discovered the same way (no hand list). Designs without the capability run at
0.5 only. Check that every consumer handles any `<Design>@prob_T=0.2` label
generically, not just Bernoulli's: data generation / construction
(`cal_plan_entry`, `cal_study_run_design`), the convergence registry's design
keying and n_eff (`n_min_arm`) in `R/EDI/R/inference_procedure_regime.R` /
`inference_convergence_expectation()`, the gate, the README / figure labels
(` @0.2`), and design comparison. Report how many design labels and roster
rows the campaign gains and the estimated extra cost.

### Amendment B: Done

Implemented 2026-11-10 (uncommitted; no build, no compile, no workflow run touched; installed EDI v1.0.4 used).

**What changed.**
* `calibration_study_common.R`: `CAL_STUDY_DESIGNS` removed. `cal_study_design_names()` = every exported `Design*` name that resolves to an `R6ClassGenerator` and is not flagged by the package's own `is_design_class_abstract()` (inspection, not names), minus `CAL_STUDY_EXCLUDED_DESIGNS`; `cal_study_designs()` adds the Amendment C labels and sorts; `cal_study_smoke_check_designs()` builds and assigns every label once on the study's data (continuous, n = 50) and stops with "Calibration CI bug: cannot build and assign ... Add cal_study_design_extras() for the design or an entry in CAL_STUDY_EXCLUDED_DESIGNS"; `cal_study_design_extras()` stays the construction map (defaults for a design without an entry). Checked on the installed EDI: all 24 exported `Design*` names are concrete R6 generators (the abstract `Design`, `DesignFixed`, `DesignSeqOneByOne` are not exported), so nothing abstract slips through; the abstract filter is there for future exports.
* **Exclusion list** (named vector, reason per entry): `DesignFixedCluster`, `DesignFixedBlockedCluster` (need cluster ids, which the study's data do not have), `DesignFixedFactorial` (more than one treatment factor). A test checks that each is still exported (a stale entry fails).
* **Ordering:** `CAL_STUDY_DESIGN_ORDER` (the old list's order; sorting only, never membership) and `cal_study_design_rank()`: Fixed before Seq, known designs in that order, a new design after the known ones of its family, alphabetically; the `@prob_T` variants share their base's rank.
* **One source:** the roster (`build_calibration_study_roster.R`) takes its designs from `cal_study_designs()` (`--designs` validated against it), runs the smoke check first, and carries a new column `design_rank` (required by `cal_plan_read_roster()`). `CAL_PLAN_DESIGNS` is gone: the planner's `--designs all` = the roster's designs, `--designs X` must be in the roster, and the run order and the confirmation order use `design_rank`. The runner validates `--design` against `cal_study_designs()`. `render_procedure_trust_tables.R` and `test-inference-convergence-rate-registry.R` use `cal_study_designs()`.
* Workflow: unchanged (the roster job already annotates "Calibration CI bug" on any failure, and the smoke check's message names the design).

**Deviations / notes.** (1) `CAL_PLAN_MATCHED_DESIGNS` (which designs get the matched-pair class set / slow-class rules) is still a hand-kept list in `calibration_study_plan_common.R`; it classifies, it does not decide membership, and a new matched design would default to "iid" cost rules. (2) `CAL_STUDY_DESIGN_ORDER` is hand-kept but sort-only. (3) `calibrate_study_truths.R` still keys its allocations by the two Bernoulli labels: the truths are class-level at an allocation and are looked up by `prob_T`, so every `@prob_T=0.2` design reuses them (checked by reading `cal_study_estimand_true`, not by a new truth run).

### Amendment C: Done

Implemented 2026-11-10 (uncommitted, nothing compiled).

**What changed.**
* Discovery: `cal_study_designs()` adds `<Design>@prob_T=0.2` (`CAL_STUDY_UNEQUAL_PROB_T`) for every kept design whose registry capability `supports_unequal_allocation` is TRUE. `cal_study_supports_unequal()` calls the package's `design_supports_unequal_allocation()` with the class name (owner's registry fix); because the installed v1.0.4 and any build from an older sha answer TRUE for any string, a shim falls back to a direct registry read when the package function says TRUE for `DesignSeqOneByOneEfron` (remove once the fix is released).
* Result on the installed EDI: 21 base designs + 12 capable designs = **33 labels (11 added)**. Capable (TRUE): FixedBernoulli, FixediBCRD, FixedBlocking, FixedGreedy, FixedGreedyDOptimal, FixedOptimal, FixedOptimalBlocks, FixedRerandomization, SeqOneByOneBernoulli, SeqOneByOneiBCRD, SeqOneByOneRandomBlockSize, SeqOneByOneSPBR. Not given a label: FixedBinaryMatch, FixedMatchingGreedyPairSwitching, SeqOneByOneAtkinson, Efron, KK14, KK21, KK21stepwise, PocockSimon, Urn.
* **Construction (real finding):** `DesignSeqOneByOneRandomBlockSize` (default block sizes 4, 6, 8) and `DesignSeqOneByOneSPBR` (block size 4) refuse prob_T = 0.2 (a block must hold a whole number of treated subjects). `cal_study_design_extras(design, prob_T)` now takes the allocation and gives them blocks that are multiples of the smallest whole block (5): RandomBlockSize 5, 10, 15; SPBR 5. At prob_T = 0.5 nothing changes. All 33 labels pass the smoke check.
* **Consumers checked:** data generation / construction (`cal_plan_entry`, `cal_study_run_design`, `cal_study_effective_n`) are label-generic; analysis, gate, planner keys, README / figure labels (` @0.2`, `cdesign`, `short_design`, `design_label`), design comparison (`design_label` from `prob_T`) all derive the label from `design` + `prob_T`, no design name; estimand truths are looked up by `prob_T`. **Two package R files needed a change (R only, no compile):** (a) `R/EDI/R/inference_procedure_regime.R`: the unequal-allocation entry was keyed `DesignFixedBernoulli@prob_T=0.2` only, so every other design resolved `n_eff = n`; it is now keyed `"@prob_T"`, which `inference_convergence_expectation()` matches against any label with a `@prob_T=` suffix (still the design layer, asymptotic procedures only, still beaten by a more specific entry), which also closes the "other prob_T, e.g. 0.3" gap noted in `inference_validity_user_visibility.md`; (b) `R/EDI/R/inference_validity_n_eff.R`: `edi_inference_validity_design_label()` appended the `@prob_T` suffix for Bernoulli only, now for any design with prob_T != 0.5; (c) `R/EDI/R/inference_small_sample_doc.R`: `rd_ss_design_text()` renders the generic key as "any design with unequal allocation". **The man pages are not regenerated** (the class Rd "Design-specific differences" items change wording; owner runs the doc build).
* **Cost (roster built from the installed EDI with the published campaign's costs):** 33 labels; roster 2,220 rows (was 1,533: +687); 19,920 units (the 11 new labels add 6,183), m_total 129,978 tests (the 11 new labels add 40,572); estimated +3,560 core-hours on top of about 10,160 (**+35%**, 13,730 total) by the planner's own cost model; the unequal-allocation labels are cheap designs mostly, but each carries the full class set (88 classes).

**Tests** (`test-calibration-class-major-order.R`, now 15 tests, 3,213 expectations, 0 failures, 0 skipped; with EDI installed): discovery returns exactly the 21 + 12 labels and no label for Efron / KK21 / the other refusers (registry read by name, instance check for each capable design at 0.2); a fake extra design (injected export) is included with its 0.2 label, ordered after the known ones of its family, non-generators / abstract / excluded names filtered, an unconstructible one fails loudly naming the design and the remedy; no `CAL_PLAN_DESIGNS` / `CAL_STUDY_DESIGNS` in any study script and the planner plans a roster design it has never heard of, refuses a design not in the roster and a roster without `design_rank`; roster rows carry `design_rank`; every capable label resolves `n_min_arm` in the working-tree registry (also Bernoulli at 0.3, not the balanced label, not `rand`). Others unchanged: gate-regime-levels 12 / 72, convergence-slopes 8 / 69 (1 skipped without `EDI_CAL_PUBLISHED_STATS_DIR`), readme-pages 4 / 208 (with `EDI_CAL_PUBLISHED_CAMPAIGN_DIR`); 0 failures. actionlint not run: the workflow is unchanged.


## Amendment D (owner, 2026-11-11): matched designs from the package — DONE 2026-11-11

`CAL_PLAN_MATCHED_DESIGNS` (hand-kept: BinaryMatch, KK14, KK21, KK21stepwise) is gone. The roster job records,
per design, `matched = des$is_a_kk_matching_capable()`: the predicate the package's own class discovery
(`inference_suite.R`, `requires_kk` vs `is_kk`) uses to give a design the KK (matched-pair) class set. The
roster's `matched` column is required and logical; `cal_plan_read_roster()` and `cal_plan_units()` register the
matched designs, `plan.csv` carries them on as `family`, and `analyze_calibration_study.R` registers them from
there; `cal_plan_family()` stops with "matched designs unknown" rather than guess. The slow-class replicate rules
(`CAL_PLAN_SLOW_CLASSES`, an owner decision about cost, not a design list) are unchanged. Tests in
`test-calibration-class-major-order.R` (16 tests, 3,222 expectations, 0 failed): on the installed EDI the
matched designs are exactly the four above and exactly the designs whose class set has KK classes, the plan's
`family` agrees with the roster, no design names remain in the planner, and a missing / non-logical `matched`
column is refused. The other three `test-calibration-*` files still pass (12 / 8 (1 skipped) / 4 tests).

## Amendment E (measured costs, folded leftovers)

Observed on campaign 2026-11-11-9d2edc5c, wave 1: shards finished in 2-8 min (about 1.5 min of that is runner setup) while the
n = 1000 shards hit the 25-minute deadline, and their leftovers became tiny resume shards in wave 2 (48-240 replicates, 1-3 min).
Two causes: the packing used the roster's (previous campaign / 2 s default) class costs, and the only correction from this
campaign's shards (`cfac`, a shard-level median ratio) was clamped to [0.2, 20] and used only the ledger's whole-shard time.

Done 2026-11-11 (uncommitted), in `plan_calibration_study.R` only (`plan.csv`, the matrix JSON, `run_calibration_study.R`
arguments and the ledger / planned.csv formats are untouched; `plan.csv` from `--plan-only` is byte-identical to the
campaign's on the results branch):

* **Measured costs.** Per-class timing already exists: `stats/tests.csv.gz` has `fit_secs` and `reps` per (cell, class, formula,
  procedure) row, the same definition the roster's `secs_n50` uses. A class's cost is the sum over its rows of `fit_secs / reps`,
  pooled over effects and stages, by (response type, design label, n, class); nothing is apportioned from shard times. `reps`
  counts replicates actually completed, so a shard that hit its deadline contributes what it did (a lower bound: replicates
  still running at the deadline are not in it; the next wave refines it). A class needs `--min-measured-reps` (default 20).
  Runner setup is not included (the shard's elapsed time starts after it). Fallback chain, reported with `--verbose`:
  `measured_design` (same class, response type, design, n) -> `measured_n` (same class, response type, n on other designs;
  median, same matched / iid family preferred) -> `measured_class` (same class and response type at the nearest other n, same
  design if measured there, scaled by `calibration_study_costs.csv`) -> `roster` (secs_n50 scaled to n as before, times the
  median of measured / roster over this campaign's measured units of the same response type and n, else the response type, else
  1, clamped [0.02, 20]; replaces `cfac`).
* **Pack overhead.** What a pack shares (data, design, assignment) is not in the class costs: per ledger shard,
  `secs_per_rep` minus the sum of its classes' measured costs, median per (response type, design, n), else (design, n), else
  (response type, n), else n, else 0; charged once per pack and included in the shard's `secs_per_rep`. (On wave 1, 0.3-1.5 s per
  replicate; the old whole-shard ratio varied 1.0-3.2.)
* **Fold.** One shard carries one (response type, design, n, effect) and one replicate set, and a class may not repeat a replicate
  it has done (the statistics add up), so only classes whose missing set contains the shard's replicates can share it. Leftovers
  of different cells or different designs / n therefore cannot be combined. In a cell, a bin predicted under
  `--min-shard-minutes` (default `--target-minutes` / 3; 0 = off) takes in further classes of the cell, in priority order, whose
  missing set contains the bin's replicates (fresh classes, or classes with larger leftovers), while the pack budget
  (`--pack-minutes` x cores) allows, until it reaches the minimum. The guests' other replicates are planned as usual. A unit that
  has lost a shard stays alone (neither host nor guest); `--pack-minutes 0` disables folding. A folded shard has its host's
  priority, so order stays class-major (null before power, response type, class) apart from a guest's first replicates moving
  forward with its host. Chunking of long units is now into equal-size chunks (same count as before), so no tiny tail chunk.
* Tests: new `test-calibration-measured-costs-and-folded-leftovers.R` (6 tests, 42 expectations, 0 failed): measured overrides
  roster and overhead; fallback chain and `--min-measured-reps`; deadline-hit shard uses replicates done; fold; dead units alone;
  priority order and unchanged plan.csv. `test-calibration-class-major-order.R` 3,222 / 0 failed; gate-regime-levels 72,
  convergence-slopes 68 (1 skipped), readme-pages 120 (1 skipped), 0 failures.
* Dry run on the real campaign folder (ledger = wave 1 only; wave 2 not yet merged), wave size 64: old planner 9 of 64 shards
  predicted under 8.3 min (8 under 5), new 5 (3 under 5); whole remaining plan 10,164 -> 10,416 shards, shards under 8.3 min
  1,106 -> 223, under 5 min 560 -> 17. Predicted-minute quartiles of the whole plan: old 15.2 / 22.5 / 24.9, new 16.5 / 21.7 / 23.6.
  The old planner's estimates for the resumed n = 1000 cells were 20-100x too low (0.2-0.4 s per replicate against 5-31 measured; the shard-level correction floor of 0.2 was the cause).
  Costs for response types not yet run still come from the roster (uncorrected, no measurements).
* The workflow now takes `plan_calibration_study.R` from the run's current commit (owner, 2026-11-11), so this planner takes
  over the running campaign on its next wave; it reads only the campaign's existing roster.csv, ledger.csv, planned.csv and
  stats/tests.csv.gz.
