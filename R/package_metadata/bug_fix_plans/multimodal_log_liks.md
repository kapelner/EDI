# Fix: Stereotype-Logit Likelihood Is Multimodal — `compute_estimate()` Can Return a Non-Global Optimum

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-8` (moved 2026-09-23 from
> `release_v1_1_0.md → TODO-30`, bug-fix/feature split).
> **Related (v1.0.5):** `glmm_variance_component_sigma_collapse.md` — the targeted, observed-wrong-answer subset for the random-intercept kernels (`log sigma` boundary collapse); coordinate start values with this plan. (`release_v1_0_5.md → TODO-31`.)

Found 2026-09-21, following up on the `comprehensive_tests` results-CSV audit
(`audit_comprehensive_results.R`) finding that fixed
`InferenceOrdinalStereotypeLogitRegr`'s delta-constrained null refit
(`get_likelihood_test_spec()` / `simulate_under_lik_null()` in
`inference_ordinal_stereotype_logit.R`), landed 2026-09-21
(`inference_ordinal_stereotype_logit.R`, regression test in
`test-stereotype-logit-null-refit-pd-gate.R`). That fix closed the
zero-width-CI bug (the refit stalling far from the true constrained optimum,
inflating the LR statistic at the point estimate to below `alpha`, collapsing
`compute_lik_ratio_bootstrap_confidence_interval()` to `c(est, est)`). See
memory `project_stereotype_multimodal_likelihood_20260921`.

## The residual problem

Post-fix measurement (400 simulated null datasets, one continuous covariate,
`w` balanced 0/1) still shows anti-conservative behavior at small `n`:

| n | Fits | Type-I (`compute_lik_ratio_two_sided_pval`) | CI coverage | Zero-width CIs | Fits where the null refit didn't reach the full-fit likelihood |
|---|---|---|---|---|---|
| 100 | 386 | 6.5% | 0.933 | 0 | 0 |
| 50 (3 response categories) | 169 | 13% | 0.923 | 0 | 5 (3%) |

The 5 residual cases at `n = 50` are not a refit-stalling problem (the
2026-09-21 multi-start fix already tried the refit from many starts and
confirmed the reported gap is real, not a local-search failure of the
*refit*). The problem is upstream, in `compute_estimate()` itself: the
stereotype likelihood is multimodal, and the **unconstrained** fit that
`compute_estimate()` reports can land at a local, non-global optimum.

Example (`r = 183`, `n = 50`, seed `1183`): `compute_estimate()` reports
`beta_T = 0.057` with `neg_loglik = 42.22`. A jittered restart from that same
fit reaches `neg_loglik = 40.05` at `beta_T = 1.248` — a strictly better
(lower) likelihood at a very different treatment effect. Because
`get_likelihood_test_spec()`'s `full_fit` stores whatever `generate_mod()`
returned as the point estimate, the LR statistic at `delta = beta_T_hat` is
computed against the *worse* optimum's likelihood, comes out positive (not
~0 as it should at the MLE), and pushes `compute_lik_ratio_two_sided_pval()`
below `alpha` more often than the nominal rate — this is the residual 13%
Type-I at `n = 50`.

This also means: **the point estimate itself can be wrong** (not just the
test/CI built on top of it) — `compute_estimate()`'s contract is "the MLE",
and in ~3% of small-`n` fits observed here it silently isn't.

## Root cause

`generate_mod()` (`inference_ordinal_stereotype_logit.R`) calls
`fast_stereotype_logit_cpp()` / `fast_stereotype_logit_with_var_cpp()` with a
**single** warm start (the class's own warm-start cache, or a cold start with
no prior fit). Newton/L-BFGS-type optimizers on this likelihood converge to
whichever local optimum is nearest the start; nothing in the current fit path
compares candidate optima or restarts from a spread of starting points. The
model's non-regularity near `beta_T = 0` (documented in
`stereotype_fit_is_usable()`'s comments — the category-score/loading
parameters `phi_k` are not identified there) is exactly the region small-`n`
null-adjacent data lands in, which is presumably why multimodality shows up
disproportionately at small `n` / few categories rather than uniformly.

## Proposed fix

Multi-start `compute_estimate()`'s own fit (`generate_mod()`), not just the
constrained null refit (already multi-started as of 2026-09-21). Candidate
starts, in the same spirit as `../new_feature_plans/cold_starts.md` / `../new_feature_plans/multistart_nonconcave_likelihoods.md`
(the package's existing smart-cold-start and multistart infrastructure for
nonconcave kernels — reuse rather than reinvent):

1. The existing smart cold start / warm-start cache (current behavior,
   kept as the primary/cheapest candidate).
2. A small number of deterministic perturbations of the smart start (e.g.
   jittered `gamma`/loading coordinates, since those are the non-identified
   directions near `beta_T = 0`).
3. A reproducible random layer (seeded off the fit's own data, not global
   RNG state) for a few additional starts, matching
   `../new_feature_plans/multistart_nonconcave_likelihoods.md`'s pattern if that plan has already
   established one by the time this is implemented.

Keep whichever converged fit has the lowest `neg_loglik`. Cache its
`fisher_information`/`params` as the warm start exactly as today.

## Why this needs review before shipping (not done inline with the CI fix)

- **Changes reported estimates**, not just p-values/CIs, in ~3% of small-`n`
  fits observed so far (true rate over the full comprehensive-test grid
  unmeasured). This is a behavior change to `compute_estimate()`'s output,
  unlike the 2026-09-21 fix, which only touched an internal refit that never
  fed a public return value directly.
- **Migration/reference-parity risk**: `test-ordinal-kk-clmm-migration-golden`
  and similar golden-value tests, plus `test-reference-parity.R`
  (`R/EDI/tests/testthat/`, part of the structural pre-push gates — see
  memory `project_prepush_structural_and_results_gates_20260919`), may pin
  exact `InferenceOrdinalStereotypeLogitRegr` estimates that would move.
  Every such golden needs to be re-derived (not just re-recorded) with a
  documented justification (the new estimate is provably the better
  optimum), same standard as any other estimate-changing fix in this
  package.
- **Cost**: multi-start multiplies the per-fit cost of a class already
  tiered `"heavy"` (`get_complexity_tier()`); needs a benchmark before/after
  (same table format as `../new_feature_plans/cold_starts.md`) to size the impact on
  `comprehensive_tests.R`'s stereotype-logit runtime, which is already
  flagged as slow (`comprehensive_tests.R`'s per-class timing notes near the
  `InferenceOrdinalStereotypeLogitRegr||~.` jackknife-exclude entry).
- **Scope check**: confirm no other stereotype-logit entry point
  (`compute_estimate_with_bootstrap_weights()`'s weighted surrogate,
  `compute_treatment_estimate_during_randomization_inference()`) shares the
  same single-start fit path and needs the identical treatment, or
  deliberately differs and that's documented.

## TODOs

- [x] TODO-1: Confirm scope — grep every call site in
  `inference_ordinal_stereotype_logit.R` that invokes
  `fast_stereotype_logit_cpp()` / `fast_stereotype_logit_with_var_cpp()` with
  a single start (`generate_mod()`,
  `compute_treatment_estimate_during_randomization_inference()`,
  `compute_estimate_with_bootstrap_weights()`'s surrogate) and decide, per
  call site, whether multi-start applies (the randomization-inference and
  bootstrap-weights paths run many times per replicate — a naive multi-start
  there may be too slow; may need a cheaper heuristic, e.g. only multi-start
  when the single-start fit's `beta_T` is near 0). **Closed 2026-10-08:**
  only `generate_mod()` receives the multi-start search. The reusable
  randomization worker remains a one-start warm refit, and the weighted
  bootstrap path remains its documented ordinal-logistic surrogate (with
  Bayesian bootstrap disabled for this class), so repeated resampling draws
  do not pay the multi-start cost or silently change estimators.
- [x] TODO-2: Design the multi-start candidate set for `generate_mod()`
  (deterministic perturbations + seeded random layer, per "Proposed fix"
  above); align with `../new_feature_plans/multistart_nonconcave_likelihoods.md`'s scheme if it
  exists by implementation time, otherwise write this class's own and note
  the divergence there for future reconciliation. **Closed 2026-10-08:**
  the primary fit is screened against four deterministic loading-direction
  perturbations (plus alternating directions when `K > 3`) and two local,
  data-hashed pseudo-random starts. The local generator neither reads nor
  changes R's global RNG state.
- [x] TODO-3: Implement, keeping the lowest-`neg_loglik` converged fit;
  preserve existing warm-start caching semantics. **Closed 2026-10-08:**
  `.stereotype_full_data_multistart()` screens with estimate-only fits,
  recomputes variance only for the selected improvement, and hands the
  selected parameters and Fisher information back to the existing cache.
  The deterministic `n = 50`, `K = 3` regression improves negative
  log-likelihood from 51.09410 to 49.85571 and remains usable for inference.
- [ ] TODO-4: Re-run the 400-null-dataset measurement (both `n=100` and
  `n=50, K=3` configurations from this plan's table) post-fix; confirm the
  `n=50` non-global-optimum count drops to ~0 and Type-I/coverage improve
  accordingly. Extend to a few more `(n, K)` combinations to characterize
  where multimodality bites hardest. **Installed-package diagnostic
  2026-10-14 (not release-current validation):** the prescribed 400 seeds
  (1001--1400) were run for both configurations against installed EDI v1.0.3
  without rebuilding. At `n=100, K=5`, 224/400 estimates/LR p-values were
  finite; 19/224 rejected (8.48%), and 212/224 finite CIs covered zero
  (94.64%; zero-width 0). The fit's selected NLL improved in 3/400 cases.
  At `n=50, K=3`, 177/400 estimates/LR p-values were finite; 6/177 rejected
  (3.39%), and the script's non-missing interval-comparison coverage was
  168/172 (97.67%); 170 CI endpoint pairs were finite, of which 168 covered
  zero (98.82%; zero-width 0). The selected NLL improved in 48/400 cases.
  Thus the nominal 400 is the simulation count, not the usable inference
  denominator. In each grid, missing estimates and LR p-values coincide
  (176 and 223, respectively) and report `model_fit_unavailable`; sampled
  failures (seed 1003 at n=100 and seed 1001 at n=50) had converged full
  fits but failed the Fisher-information conditioning gate. Their reciprocal
  conditions were 1.29e-9 and 1.82e-11, below the source threshold
  `sqrt(.Machine$double.eps)` (~1.49e-8); both pass when that gate is waived.
  The n=50 run also had seven additional incomplete CI endpoint pairs.
  These results do not reconcile with the earlier n=100 table's 386 usable
  fits and cannot establish release-current calibration: the installed EDI
  reports version 1.0.3 and a native build timestamp of 2026-09-20, while the
  checkout's R layer is newer. Preserve this run as a diagnostic only; TODO-4
  remains open pending reconciliation of the usable-fit discrepancy and
  validation against a matching/current native build. Results:
  `/tmp/edi-todo8-400-null-installed-20261014T142934Z/`.
  **Artifact-only reconciliation, 2026-10-15:** a second 400-seed run after
  the user's reinstall is preserved at
  `/tmp/edi-todo8-400-null-reinstall-20261014T173835Z/`. Its `n100k5.csv`
  and `n50k3.csv` are byte-identical to the earlier installed-package run
  (SHA256 respectively `e07fb6839cbacb3e0bfa40da1f6a5614d9823206caf12ad273c4169ee0ddd051`
  and `5992e43b803016c970e0bbd2a92cf541872f062e153fad0b853d0bfdf147eff4`),
  even though `run_metadata.txt` records the native build timestamp changing
  from 2026-09-20 to 2026-10-14. Both runs therefore agree exactly on the
  observed 224/400 usable n=100 cases and 177/400 usable n=50 cases; the
  reinstall alone did not reproduce the historical table's 386/400 and
  169/400 denominators. The only other seed-level output located,
  `/tmp/edi_todo8_n100k5.csv` (2026-10-09; SHA256
  `7d4a64a0dc74dff0540130146e12d1a7f1943ba72362219e25a88b6a428566f9`),
  has 64/400 finite n=100 estimates/LR p-values. These 64 seeds are all
  finite in the later 224-case run; there are no old-only finite seeds and
  160 later-only finite seeds. That Oct 9 file has no paired n=50 output and
  is not the missing Sep 21 seed-level baseline. The original 386/400 and
  169/400 table still has no located per-seed CSV or run metadata, so neither
  denominator nor the historical fit-usability decisions can be reconciled
  from available artifacts. TODO-4 remains open; no regeneration or
  compilation was performed.
  **Artifact-schema follow-up, 2026-10-16:** reinspection of every located
  artifact found no missing status/reason field that explains the denominator
  gap. The Oct 9 `n100k5` file has 400 rows and only the estimate, LR p-value,
  CI endpoints, NLLs, and improvement columns; its generator uses
  `pkgload::load_all('R/EDI', compile=FALSE)` and has no run metadata. The two
  Oct 14 study scripts differ only in output-directory setup and metadata
  collection/formatting; their computation is otherwise identical, and their
  400-row CSVs are byte-identical despite the changed installed native mtime.
  This confirms deterministic repeatability of the later 224/177 counts but
  does not identify why the earlier table reported 386/169. The next decisive
  check is recovery of the Sep 21 per-seed CSV plus its generator/runtime
  metadata and exact usable-fit predicate. If those artifacts no longer exist,
  an explicitly approved current-native rerun must record per-stage errors,
  fit-usability decisions, and Fisher-information conditioning per seed; it
  can establish current behavior but cannot retrospectively explain the
  missing historical denominator. TODO-4 remains open, and no simulation was
  launched for this audit.
  **Fresh artifact inventory 2026-10-16:** a path search across `/tmp` and
  workspace `.scratch` found no additional TODO-8 artifacts beyond the Oct 9
  `n100k5` CSV and the two Oct 14 study directories already listed above;
  specifically, the original Sep 21 per-seed outputs and run metadata are
  absent. Thus the historical 386/400 and 169/400 usable denominators are
  irrecoverable from retained artifacts; this does not resolve their cause.
  **Hash verification 2026-10-18:** a read-only SHA-256 check of the four
  `n100k5.csv`/`n50k3.csv` files in the two Oct 14 directories reproduced the
  two hashes above exactly (`e07fb683…ddd051` for n=100 and
  `5992e43b…7eff4` for n=50). The recheck confirms byte identity, not source or
  native-build provenance; TODO-4 remains blocked on historical-denominator
  reconciliation or an explicitly approved current-native rerun. No files in
  either result directory were modified.
  **Paired-seed data-integrity recheck, 2026-10-20 (read-only):** reparsed
  the hash-verified CSVs above and confirmed that both configurations contain
  the same 400 unique seed IDs (1001--1400), with no duplicate or missing
  seeds. On that aligned seed set, 104 seeds have finite estimate/LR-p-value
  pairs in both configurations, 120 only at `n=100`, 73 only at `n=50`, and
  103 in neither. This documents the current per-configuration fit-usability
  pattern without treating the different-`n` datasets as paired observations
  or explaining the missing historical 386/400 and 169/400 denominators. The
  CSV hashes remain `e07fb683…ddd051` (`n=100`) and
  `5992e43b…7eff4` (`n=50`); provenance and the historical-data gap remain
  unchanged, so TODO-4 is still blocked. No result files were modified.
- [x] TODO-5: Audit and, where estimates move, re-derive (not just
  re-record) every golden/reference value touching
  `InferenceOrdinalStereotypeLogitRegr` in
  `test-ordinal-kk-clmm-migration-golden` (if applicable — confirm this is
  the CLMM class, not stereotype, before assuming it's in scope),
  `test-reference-parity.R`, `test-simple-estimator-migration-baseline`, and
  any `testthat_bulk/` stereotype-logit reference tests; document each
  change with the before/after `neg_loglik` showing the new value is the
  genuine improvement. **Closed 2026-10-08:** no existing golden required a
  value change. The full-likelihood migration baseline, randomization-estimate
  reference, and stereotype profile/randomization reference all pass against
  the source-loaded package. The new regression records the before/after
  likelihood for the one fixture intentionally changed by the fix.
- [x] TODO-6: Benchmark per-fit cost before/after (table format per
  `../new_feature_plans/cold_starts.md`); if the slowdown is material, gate multi-start behind a
  cheap pre-check (e.g. only trigger extra starts when `|beta_T_hat|` is
  small, since that's the observed non-identified/multimodal region) rather
  than always running the full candidate set. **Closed 2026-10-08:** a
  10-repetition source-loaded benchmark on the deterministic fixture measured
  0.006 seconds for the old full fit and 0.035 seconds for the complete
  multi-start selection (5.83x). The affected fixture's primary treatment
  coefficient is about 0.85, so the proposed near-zero-coefficient gate would
  miss the reproduced failure. The search therefore remains restricted by
  call site (one full-data fit) rather than by an unsafe coefficient gate;
  repeated randomization/bootstrap refits retain their one-start paths.
  **Installed-package focused recheck, 2026-10-20:**
  `test-stereotype-logit-full-fit-multistart.R` passed all 17 expectations
  with `testthat::test_file()` against installed EDI 1.0.3. R was
  `R-devel r90668`; package metadata reports Built `2026-10-20 06:33:10
  UTC`, and the loaded DLL was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`
  (SHA-256 `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`,
  MD5 `a75519a9256c0b3121398032314291d4`). Checkout HEAD was
  `4f7a6e4ca828`; the test was not source-loaded, so this is installed-package
  evidence and does not establish that the installed R implementation matches
  current checkout source or validate a current-checkout/native build. No
  compilation or installation occurred; TODO-4, TODO-7, and TODO-8 remain
  open.
  **Checkout-source focused recheck, 2026-10-20:**
  `pkgload::load_all("R/EDI", compile = FALSE, recompile = FALSE)` followed
  by `testthat::test_file("R/EDI/tests/testthat/test-stereotype-logit-full-fit-multistart.R",
  package = "EDI")` passed all 17 expectations (0 failures, warnings, or
  skips). R was R-devel `r90668`; package version was 1.0.3 and the loaded
  namespace was `/home/kapelner/workspace/EDI/R/EDI`. The loaded temporary
  `EDI.so` SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  matching checkout `R/EDI/src/EDI.so`. This validates the checkout R-layer
  full-fit multistart regression against that existing native DLL, not the
  missing post-fix 400-null calibration or class-wide comprehensive CSV
  regeneration/reconciliation. No compilation or installation occurred;
  TODO-4, TODO-7, and TODO-8 remain open. Captured output is
  `/tmp/todo8-stereotype-multistart-source-20261020.log`.
- [ ] TODO-7: Update `inference_ordinal_stereotype_logit.R`'s class-level
  roxygen (rewritten 2026-09-21 with the post-refit-fix Type-I/coverage
  numbers) with the post-multi-start numbers from TODO-4, and regenerate
  `man/InferenceOrdinalStereotypeLogitRegr.Rd`
  (`fix_documentation.md`'s batch process — do not roxygenize ad hoc mid
  other work, see memory `feedback_no_interim_roxygenize`).
  **Read-only gate check 2026-10-18:** both the roxygen source and checked-in
  Rd still report the prior post-refit/pre-multistart calibration (n=100:
  ~6.5% Type-I error and 0.93 coverage; n=50: ~13% and 169 converged fits).
  Because TODO-4 has not produced release-current post-multistart numbers,
  these values cannot yet be replaced safely. Update the source and generated
  Rd together only after TODO-4 is valid; follow the batch documentation
  process rather than roxygenizing ad hoc.
- [ ] TODO-8: Regenerate the `comprehensive_tests` CSV rows for this class
  (all `function_run`s, not just the lik-ratio-bootstrap slice already
  regenerated 2026-09-21) once the fix lands and is installed, then re-run
  `audit_comprehensive_results.R --write-baseline` to drop any
  now-stale `InferenceOrdinalStereotypeLogitRegr` baseline entries.

  **Isolated-output integration audit (2026-10-18):** the comprehensive
  runner's `EDI_COMPREHENSIVE_RESULTS_DIR` override redirects its computed
  result filename into an existing scratch directory and preserves the
  canonical default when unset. For a future class-filtered regeneration,
  use a new `/tmp` directory and retain every `function_run` for
  `InferenceOrdinalStereotypeLogitRegr`; record the installed package and
  loaded-DLL provenance with the shard. This produces a filtered filename,
  not the unfiltered
  `comprehensive_tests_results_nc_1_ordinal.csv` that
  `audit_comprehensive_results.R` scans. The audit now honors the same
  `EDI_COMPREHENSIVE_RESULTS_DIR` override: it routes response-level input
  filenames, baseline, and stamp into that existing scratch directory, while
  retaining script-relative canonical defaults when unset. Do not mistake a
  filtered shard alone for a full-suite audit: the audit needs complete
  response-level inputs. Before reconciliation, stage a scratch-only copy of
  the relevant complete ordinal results, replace only exact keys from the
  complete post-fix class shard, and run the audit with the override pointing
  at that scratch directory. For a `--write-baseline` pass, also stage every
  other complete response-level input CSV covered by the existing baseline:
  the audit treats missing response files as absent findings, so an ordinal-
  only scratch set could incorrectly prune unrelated baseline entries.
  The audit now refuses `--write-baseline` when any expected response-level
  file is missing or empty; this guard cannot prove that a present CSV is
  complete, which still requires provenance/content verification.
  Review every absent/new finding before any baseline update;
  `--write-baseline` must remain confined to scratch until separately
  authorized. Keep canonical CSVs and baseline untouched absent separate
  authorization.
  The focused output-directory-override reference test passed 7 assertions
  with 0 failures and 0 warnings (2026-10-18); this validates path routing
  only, not a full audit or post-fix regeneration.
  The current post-fix calibration and provenance gates (TODO-4/7) still
  precede this regeneration, and no run or audit was performed for this
  integration check.

  **Installed null-refit-selection regression, 2026-10-20:**
  `test-ordinal-stereotype-logit-lik-test-null-refit-multistart-reference.R`
  passed all 5 assertions (0 failures/warnings/skips; exit 0) against installed
  EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Loaded
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` had MD5
  `8b3ca30492d7b1c790deeebe94b201ad` and SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`;
  checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This fixture
  mocks the two constrained-null starts and verifies selection of the lower
  `neg_loglik`, the first-start winner, single-start nonconvergence fallback,
  and both-start failure. It is a focused null-refit contract only: it does
  not regenerate class-wide comprehensive rows, measure Type-I error/coverage,
  reconcile the historical usable-fit denominators, or establish that the
  installed R layer matches checkout source. TODO-8 remains gated on the full
  result inventory and TODO-4/7's valid post-fix calibration/documentation.

  **Retained-artifact inventory, 2026-10-21 (read-only):** the previously
  named `/tmp/edi-todo8-400-null-reinstall-20261014T173835Z/`,
  `/tmp/edi-todo8-400-null-installed-20261014T142934Z/`, and
  `/tmp/edi_todo8_n100k5.csv` are no longer present; only the 1,249-byte
  `/tmp/todo8-stereotype-multistart-source-20261020.log` remains from the
  TODO-8-named files checked. Four ignored, filtered class CSVs survive under
  `R/package_tests/` (line counts include headers): beta-0 parametric
  bootstrap 556 lines, SHA-256
  `46479a28cf5acf36f52b6365cec75a9766be4d0f080ce80eb07d8392b42db6ff`;
  bootstrap 133 lines, `362c25a221608db8030cda91330fda2315dc8e6c1c61363b97eca27f2a7bb7be`;
  jackknife 508 lines, `9fdd6ffb04c2a72a9659c44deec521b2dae5b6f5c395afe1cf9e52e9ccc56cca`;
  and rand 163 lines, `298511ebeb8200d997f5f24d003b403032cac2c7ea7b6cc9bc20876d753de011`.
  Their recorded mtimes are Sep 8 (three slices) and Sep 21 (the beta-0
  parametric-bootstrap slice), all before the Oct 8 ordinary full-fit
  multi-start implementation; none is a complete all-`function_run` class
  shard or has a current source/DLL provenance receipt. The two documented
  Oct 14 study cohorts (400 rows each at n=100 and n=50) are also absent now;
  they were null-calibration diagnostics, not comprehensive-runner output.
  These surviving files therefore provide neither an exact current-source
  reconciliation nor a complete expected-key roster. Keep TODO-8 open behind
  TODO-4/7; after those gates, produce an installed, provenance-stamped
  all-`function_run` class shard and reconcile it in an isolated complete
  ordinal audit input set. Do not update canonical CSVs/baseline from these
  stale partial files.

  **Ordinal artifact parity recheck, 2026-10-21 (read-only):** the bounded
  inventory also finds `comprehensive_tests_results_nc_1_ordinal.csv.pre_stereotype_merge.bak`
  (437,321,222 bytes; mtime 2026-09-21) and two Bernoulli/diamonds filtered
  class outputs (rand-custom, mtime 2026-09-23; and rand, also mtime
  2026-09-23). All precede the 2026-10-08 ordinary-fit multi-start change;
  the large backup is a pre-change snapshot, while the two filtered files are
  narrow dataset/family slices. None can validate the post-fix optimum
  selection, post-fix calibration, or full class result-key inventory. No
  newly retained artifact closes TODO-8 without the TODO-4/7 calibration and
  provenance gates; canonical CSV/baseline changes remain unauthorized.

- [ ] TODO-9 (added 2026-09-24, found via a dedicated cross-class
  investigation fork re-auditing the ordinal cluster — **flag
  prominently, low-medium confidence, thin sample**): possible **post-fix
  coverage regression** from the already-shipped 2026-09-21 multi-start
  fix this file describes. Coverage on several families dropped after
  the fix: `wald`/`asymp` 0.973→0.762, `score` 0.955→0.762, `gradient`
  0.922→0.667, `lik_ratio` 0.686→0.524 (already bad pre-fix, worse
  after). Confirmed NOT explained by stale audit data (the comparison is
  against post-fix rows specifically). Post-fix sample is thin (n=21 per
  the fork's count) — needs a larger post-fix regeneration run before
  concluding this is real rather than sampling noise. If confirmed real,
  this would mean the multi-start fix (keeping the lowest-`neg_loglik`
  converged fit, per TODO-3) changed which local optimum gets selected in
  a way that's *worse* for CI coverage on the affected families, even
  while presumably improving point-estimate bias/Type-I error (the
  original target of the fix) — plausible if the SE/CI machinery for
  these families implicitly assumed the old (buggy) single-start fit's
  behavior somewhere downstream. Not investigated further; needs its own
  look once TODO-4's larger post-fix measurement run exists. **Read-only
  matrix preflight 2026-10-18:** the retained `study.R` runner records the
  point estimate, raw LR p-value, and LR-bootstrap CI per seed; its summary
  has no Wald/asymptotic, score, or gradient result columns. Therefore simply
  repeating that runner cannot test the four family-specific coverage changes
  above. The later authorized calibration must add those family outputs and
  retain separate finite-result denominators per method; otherwise TODO-9's
  coverage lead remains unanswered even if TODO-4's aggregate calibration
  completes. No simulation was run for this preflight.

## Standing constraints

Same as `release_v1_1_0.md`'s standing constraints: additive by default
except where this plan explicitly documents an estimate-changing default
(TODO-3's fit change is exactly such a documented default change, same
category as `release_v1_1_0.md`'s TODO-11 class-deletion exception). No
`R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn (see
top-level `CLAUDE.md`); verify any C++-adjacent change (none expected here —
this is R-layer multi-start orchestration around existing kernels, not a new
kernel) via targeted compile only, never a full build.
