# Fix: `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` Randomization Distribution All-NA — `estimate_only` Pooling-Weight NA Propagation

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-14` (moved 2026-09-23 from
> `release_v1_1_0.md → TODO-36`, bug-fix/feature split). Found 2026-09-22, surfaced as a
> `KNOWN_BROKEN` entry in `stale_worker_cache_resampling.md`'s TODO-6
> regression test (the new KK-design fixture arm was the first thing to
> exercise `estimate_only = TRUE` on this class with both matched and
> reservoir components simultaneously usable); root-caused same day on user
> request. Unrelated mechanism to that plan or to
> `prop_gcomp_sample_usable_gating.md` — a plain arithmetic NA-
> propagation bug, not caching and not worker-state gating.

## The bug, confirmed by direct reproduction

`shared()` in `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:271-311`
(the `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` class — "IVWC" =
inverse-variance-weighted combination, literally naming the broken
mechanism) pools a matched-pair Clayton-copula estimate (`beta_m`) and a
reservoir Weibull-AFT estimate (`beta_r`) via inverse-variance weighting:

```r
# lines 296-300
if (m_ok && r_ok){
    w_star = ssq_r / (ssq_r + ssq_m)
    private$cached_values$beta_hat_T = w_star * beta_m + (1 - w_star) * beta_r
    if (estimate_only) return(invisible(NULL))
    ...
```

`ssq_m`/`ssq_r` come from `clayton_copula_for_matched_pairs()` and
`weibull_for_reservoir()` (lines 312-404), both of which — correctly, per
the `estimate_only` docstring ("skip variance component calculations") —
return `ssq = NA_real_` when `estimate_only = TRUE` (explicit at line 336:
`ssq_beta_T_matched = if (estimate_only) NA_real_ else fit$ssq`; the
reservoir fit's helper likewise returns `ssq = NA` under
`estimate_only = TRUE`). But the pooling-weight line above uses
`ssq_m`/`ssq_r` **unconditionally**, regardless of `estimate_only`. When
both components are usable (`m_ok && r_ok` — the common case, a design
with both matched pairs and a non-trivial reservoir), `w_star` becomes
`NA/NA = NA`, and `beta_hat_T = NA * beta_m + NA * beta_r = NA` — even
though `beta_m` and `beta_r` (the actual point estimates) are both
perfectly finite.

`estimate_only = TRUE` is exactly what every resampling draw uses for
speed (the reused-worker `rand` contract calls
`compute_estimate(estimate_only = TRUE)` via
`compute_bootstrap_worker_estimate_via_compute_treatment_estimate()`,
`inference_all_abstract_non_param_boot.R:1281-1288`). So this fires on
**every single draw, unconditionally** — not permutation-specific, not
data-dependent, not related to matching/frailty convergence. It also fires
on the very first "observed" call whenever a caller requests
`estimate_only = TRUE` directly.

**Direct reproduction** (golden fixture from
`R/package_tests/testthat_bulk/test-survival-glmm-weibull-frailty-loggamma-ivwc-migration-golden.R`'s
`clayton_golden_design(n=24, seed=20260817)`):
- `compute_estimate(estimate_only = FALSE)`: `-0.2163981` (works).
- `compute_estimate(estimate_only = TRUE)` on the same unpermuted data:
  `NA`, with `beta_T_matched = 0.0307` (finite),
  `ssq_beta_T_matched = NA`, `beta_T_reservoir = -1.022` (finite),
  `ssq_beta_T_reservoir = NA`.
- Full reused-worker `rand` draw traced step-by-step
  (`create_bootstrap_worker_state()` →
  `load_randomization_draw_into_worker()` →
  `compute_randomization_worker_estimate()`): `KKstats$m=4, nRT=9, nRC=7`
  (both components usable), `beta_T_matched = 0.297`,
  `beta_T_reservoir = 0.113` (both finite) → final `beta_hat_T = NA`,
  `is_nonestimable("estimate") = FALSE` (not gated there — confirms it's
  the pooling arithmetic, not a nonestimable-flag path).

## Scope: isolated to the IVWC variant

The sibling `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` (line 981)
does **not** have this bug — its `shared()` is a single joint-likelihood
fit with no matched/reservoir split and no `ssq_r`/`ssq_m`/`w_star`
pooling-weight computation at all. The bug is specific to the IVWC
variant's two-component combination logic. (No cross-class sweep beyond
this sibling check has been done — TODO-2 covers a broader grep for the
same `w_star`/inverse-variance-pooling shape elsewhere in the file/package,
in case another class shares it.)

## Proposed fix — already has a reference implementation in the same file

`shared()`'s pooling block needs to fall back to equal weighting
(`0.5 * beta_m + 0.5 * beta_r`) when `estimate_only = TRUE` (i.e. when
`ssq_m`/`ssq_r` are deliberately unavailable), exactly matching the pattern
already correct in a **different function in the same file**,
`compute_treatment_estimate_during_randomization_inference()`
(~lines 195-210), whose pooling logic already guards:

```r
if (!is.null(ssq_m_orig) && !is.null(ssq_r_orig) &&
    is.finite(ssq_m_orig) && is.finite(ssq_r_orig)) {
  # inverse-variance weight
} else {
  return(0.5 * beta_m + 0.5 * beta_r)
}
```

The fix is to bring `shared()`'s pooling block in line with this existing,
already-correct pattern — not to invent new logic.

## Status

Fixed 2026-09-23, exactly as proposed: `shared()`'s `w_star` computation
now falls back to `0.5` when `ssq_m`/`ssq_r` aren't both finite, matching
`compute_treatment_estimate_during_randomization_inference()`'s existing
guard. Verified on the plan's own golden fixture
(`clayton_golden_design(n=24, seed=20260817)`):
`estimate_only = FALSE` unchanged (`-0.2163981`, bit-for-bit);
`estimate_only = TRUE` now `-0.4956479` (finite, same sign as the `FALSE`
path, `beta_m`/`beta_r` unchanged at `0.0307`/`-1.022`); reused-worker
`rand` distribution now 99/99 finite (`sd = 0.391`, previously all-NA).
Removed from `RESAMPLING_NONDEGENERATE_KNOWN_BROKEN` in
`test-reused-worker-resampling-nondegenerate.R`; full suite re-run passes
(13/13). TODO-2's broader sweep is complete; TODO-7 (CSV regeneration)
remains open under release TODO-14.

## TODOs

- [x] TODO-1: Apply the fix — guard `shared()`'s `w_star` computation
  (`inference_survival_GLMM_weibull_frailty_loggamma.R:296-300`) the same
  way `compute_treatment_estimate_during_randomization_inference()` already
  does: equal-weight fallback (`0.5 * beta_m + 0.5 * beta_r`) when
  `ssq_m`/`ssq_r` aren't both finite (i.e. under `estimate_only = TRUE`).
  Verify via `pkgload::load_all(".", compile = FALSE)` only (never
  `R CMD INSTALL`/`R CMD build`/`pkgbuild::compile_dll()`/
  `load_all(compile = TRUE)` or unspecified `compile=` — hard project rule,
  see top-level `CLAUDE.md`).
- [x] TODO-2 (2026-09-23, completed): Grepped `R/EDI/R/*.R` for
  `w_star = ssq_r / (ssq_r + ssq_m)` and equivalent — found 10 more hits
  across `inference_continuous_KK_robust_regr_ivwc.R`,
  `inference_count_KK_cond_poisson.R` (×3, all three inside the one
  `CountKKHurdlePoissonIVWCSource` list feeding
  `InferenceCountKKHurdlePoissonIVWC` — not three separate classes),
  `inference_continuous_KK_ols_ivwc.R`, `inference_incidence_KK_cond_logit.R`,
  `inference_all_KK_wilcox_ivwc.R`,
  `inference_all_KK_quantile_regr_ivwc_abstract.R` (feeds two concrete
  leaves, `InferenceContinKKQuantileRegrIVWC`/`InferencePropKKQuantileRegrIVWC`),
  `inference_survival_KK_lwa_cox_ivwc_abstract.R`,
  `inference_survival_KK_strat_cox.R`,
  `inference_survival_KK_rank_regr_ivwc_abstract.R`, plus
  `inference_survival_GLMM_weibull_frailty_normal.R` (the *other* sibling,
  not just the checked `...OneLik` one — this one DOES pool via IVWC, but
  its `shared()` already has the correct `estimate_only` branch this class
  was missing). Direct behavioral check
  (`compute_estimate(estimate_only=TRUE)` vs. `FALSE` on a KK-matched
  fixture) on all 9 concrete classes reachable from this list
  (`InferenceContinKKRobustRegrOneLik`, `InferenceCountKKHurdlePoissonIVWC`,
  `InferenceContinKKOLSOneLik`, `InferenceIncidKKCondLogitOneLik`,
  `InferenceAllKKWilcoxIVWC`, `InferenceSurvivalKKLWACoxPHOneLik`,
  `InferenceSurvivalKKStratCoxPHOneLik`, `InferenceContinKKQuantileRegrIVWC`,
  `InferencePropKKQuantileRegrIVWC`) found **no NA-under-estimate_only
  case anywhere** — each either already guards `estimate_only` before
  computing `w_star`, or has its matched/reservoir helper substitute a
  finite placeholder `ssq` (e.g. `1.0`, or a placeholder `se = 1` in
  `InferenceCountKKHurdlePoissonIVWC`'s
  `compute_treatment_estimate_during_randomization_inference()` — checked
  directly since a hardcoded `se = FALSE` there looked suspicious on first
  read, but the placeholder is finite, not NA, so `m_ok` is never
  spuriously forced false; the ~0.09 point-estimate gap vs. the full path
  is the expected cost of a cruder placeholder-variance weighting, not a
  defect) under `estimate_only` instead of leaving it `NA`, avoiding the
  bug by a different mechanism than this class needed. **This bug is
  confirmed isolated to the one class already fixed** — the full sweep is
  now complete, no unchecked spots remain, and no further action is
  needed here.
- [x] TODO-3: Re-ran the golden fixture repro
  (`clayton_golden_design(n=24, seed=20260817)`):
  `estimate_only = TRUE` now `-0.4956479` — finite, same sign as the
  `FALSE` path's `-0.2163981`. Treated as passing per the plan's own
  "close enough" criterion (same sign; the two paths use genuinely
  different weights so exact numeric closeness was never the bar).
- [x] TODO-4: `estimate_only = FALSE` unchanged, confirmed bit-for-bit
  (`-0.2163981`, identical to the value already on record in this plan
  and in `release_v1_0_5.md → TODO-14` (was `release_v1_1_0.md →
  TODO-36`)).
- [x] TODO-5: Reused-worker `rand` distribution on the golden fixture now
  99/99 finite, `sd = 0.391` (previously all-NA).
- [x] TODO-6: `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` removed
  from `RESAMPLING_NONDEGENERATE_KNOWN_BROKEN`; full regression file
  re-run passes (13/13).
- [ ] TODO-7: Regenerate any `comprehensive_tests` CSV rows for this
  class's `rand`-family methods once fixed and installed (only after
  install, not before, same caution as the sibling plans). **Bounded
  harness-isolation pilot 2026-10-14:** ran the canonical harness from a
  minimal `/tmp` root (only `comprehensive_tests.R`, `_dataset_load.R`,
  its pruning helper, and the likelihood-smoke helper copied there), so its
  results path could not touch the workspace CSVs. First command filtered to
  one rep, survival, KK21, this class, `pte_example`, beta 0, rep 1, `rand`;
  second relaxed design/dataset filters while keeping one rep, survival,
  this class, beta 0, rep 1, `rand`. The runs exited 0 in 2.4s and 37.4s,
  respectively, but emitted no filtered result CSV/eligible rows, so these
  are isolation/setup timings only, not a benchmark of the class method.
  Logs are preserved at `/tmp/edi-todo14-pilot-W6SnZz/pilot.log` and
  `/tmp/edi-todo14-pilot-W6SnZz/pilot_all_designs.log`. The copied root is
  not a Git checkout, causing expected `rev-parse`/stale-row-pruner warnings;
  no workspace CSV changed. **Harness selection fixed and isolated rows
  validated 2026-10-16:** `comprehensive_tests.R` now explicitly includes
  this IVWC class in the KK-survival selector (IVWC remains excluded from
  the exhaustive namespace sweep). The focused regression
  `R/package_tests/testthat_bulk/test-comprehensive-survival-ivwc-rand-selection-reference.R`
  passed 7 expectations against installed EDI 1.0.3. One-core isolated
  `pte_example` runs for beta 0 and 0.5 each emitted the expected six rows
  (both formulas × p-value, delta=.5 p-value, and CI), all `status=ok`;
  direct public-API calls on the same in-memory data/object and restored
  pre-call RNG matched all 12 values exactly. Comparison records are in
  `/tmp/edi-todo14-api-compare.Nezg4w/direct_api_comparisons.csv` (combined
  beta run) and `/tmp/edi-todo14-api-compare.QKZpfy/direct_api_comparisons.csv`
  (beta 0.5 filtered run matching the original pilot RNG path). These are
  isolated validation outputs, not canonical results. TODO-7 remains open
  pending authorized regeneration/reconciliation of the canonical
  comprehensive-results CSV rows after install.

  **Expected-attempt manifest materialized (2026-10-20, no runner invocation):**
  independently expanded the source/plan dimensions for this target into
  `/tmp/edi-todo14-expected-attempts-20261020.csv`. It contains 8,640 unique
  `id`/natural-key rows for reps 1:40, beta 0/0.5, the nine named survival
  datasets, the two eligible KK designs, both formula labels, and the three
  `rand` operations. Key serialization follows `serialize_beta_T()` and
  `build_result_key()`; formula suffixes follow
  `current_design_formula_suffix()`. Manifest SHA-256 is
  `7f7af2c77b02458dfff4f1aab1b2fc55d9844cde5526a3f3aa4abeb6b4c925b0`; the
  source `comprehensive_tests.R` snapshot used for this audit is
  `0f4612616ec1362c6e8b100a1c2fec32c417f86b8c4bf8ce8c317f5eaa13b92a`.
  This is the expected runner-attempt inventory only: it does not show any
  attempt ran or succeeded, does not include run-assigned `run_row_id`, and
  does not validate installed package/native provenance. Compare a future
  candidate CSV against this inventory with exact two-way anti-joins; keep
  all canonical results untouched.

  **Independent grid/key reconciliation (2026-10-20, read-only):** compared
  the manifest against the current runner loop and key constructor without
  sourcing the runner or constructing a design. The source hash above matches
  the current `comprehensive_tests.R`; the current selectors define nine
  datasets with survival responses, `beta_T` values 0 and 0.5, reps 1:40,
  `TESTED_DESIGNS` intersected with KK designs as `KK21stepwise` and
  `FixedBinaryMatch`, both formula labels, and the three `rand` function names
  listed above. Independently rebuilding `id` with the current
  `serialize_beta_T()`/`build_result_key()` field order produced exactly
  8,640 keys: zero missing, zero extra, zero duplicates against the manifest.
  The focused static selector regression
  `test-comprehensive-survival-ivwc-rand-selection-reference.R` also passed
  7 assertions against installed EDI 1.0.3; it parses the harness and does not
  fit models. This confirms the intended attempt inventory and selector/key
  wiring only, not successful constructors, method execution, or output
  completeness.

  **Roster-scope clarification (2026-10-20):** the general
  `comprehensive_rand_ci_attempt_manifest()` helper models randomization-CI
  and randomization-bootstrap-CI eligibility; it does not enumerate the two
  ordinary `rand` p-value calls in this TODO-14 target. The 8,640-key
  inventory above therefore remains the independently source-derived
  three-operation roster (two p-values plus one CI), not output from that
  narrower helper. Do not replace or shrink it using the CI-only roster.

  **Outstanding exact-RNG β=.5 parity gate (2026-10-20):** the isolated
  six-row β=.5 harness output and the prior direct-API comparison are useful
  smoke evidence, but the retained comparison does not establish that the
  direct calls started from the exact RNG state after DGP/design setup. Do
  not treat it as satisfying exact replay parity. For one bounded
  `pte_example`, rep-1 replay, construct the DGP and design first, then save
  `.Random.seed` immediately before the first `rand` operation. On an
  equivalent fresh object, restore that state and make the same three calls
  in the original order for each formula (`~1` and `~.`): `rand` p-value,
  `rand` delta=.5 p-value, and `rand` CI. Compare the six raw, unrounded
  public-API result values against the corresponding harness values using
  exact equality; record the captured state/seed, call order, EDI version,
  resolved library, DLL path/hash, R version, and checkout SHA. Keep this
  isolated under `/tmp`. The β=.5 exact-RNG replay has not been run and
  remains open; this gate is separate from TODO-7's full 8,640-row
  regeneration/reconciliation and canonical-merge approval.

  **Manifest/artifact recheck (2026-10-20):** the prepared manifest remains
  present at `/tmp/edi-todo14-expected-attempts-20261020.csv` with SHA-256
  `7f7af2c77b02458dfff4f1aab1b2fc55d9844cde5526a3f3aa4abeb6b4c925b0`, and
  the current `R/package_tests/comprehensive_tests.R` still has the recorded
  source SHA-256 `0f4612616ec1362c6e8b100a1c2fec32c417f86b8c4bf8ce8c317f5eaa13b92a`.
  The focused synthetic candidate-validator test was rerun against the
  installed package and passed 27 expectations. The fixture now also
  duplicates a manifest natural key and verifies rejection through both the
  duplicate-manifest-ID and exact 1:40 replicate guards. An older
  `/tmp/edi-todo14-fullmerge.s72fR5/candidate_survival.csv` artifact exists
  (207,998,976 bytes, dated 2026-10-16), but it has no adjacent run-provenance
  record in that scratch directory and is not treated as the post-fix target
  candidate; no candidate rows were reconciled in this recheck. The expected
  inventory is therefore still not evidence of observed output completeness.

  **Replay prerequisite:** do not run the 8,640-fit invocation until the fixed
  package is installed and its source commit, R version, resolved library,
  package version, loaded DLL path/hash, and checkout SHA can all be captured
  before/after; confirm no competing heavy workload is active, obtain explicit
  authorization for the full fitting run, and use a fresh `/tmp` output
  directory with the prepared one-core invocation. Then require all expected
  IDs exactly once, no extra IDs, acceptable row statuses, finite/legitimate
  result and interval/coverage fields, and matching provenance before any
  separate canonical merge approval. A matching manifest alone does not waive
  these gates.

  **Isolated post-install invocation recipe (prepared only, 2026-10-19):**
  from the repository root, after the post-fix package is installed, run the
  existing harness with an explicit class selector and a fresh `/tmp` output
  directory. This leaves dataset, design, beta, and replicate filters unset,
  so it covers the full current target grid (40 reps, both beta values, both
  formulas, both eligible KK designs, nine survival datasets, three `rand`
  operations):

  ```sh
  outdir=$(mktemp -d /tmp/edi-todo14-ivwc-postfix.XXXXXX)
  EDI_COMPREHENSIVE_RESULTS_DIR="$outdir" Rscript R/package_tests/comprehensive_tests.R 40 1 survival NA InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC NA NA NA rand
  ```

  Before and after the run, record `git rev-parse HEAD`, `R.version.string`,
  `packageVersion("EDI")`, `.libPaths()`, `normalizePath(find.package("EDI"))`,
  and the installed platform DLL path and SHA-256. The CSV's
  `github_commit_id` alone identifies the checkout, not the loaded package or
  native library. The 8,640-key inventory is the expected runner-attempt set,
  not a promise of successful output; any absent or failed key remains a
  gate failure under the release checklist. This recipe is preparation only:
  it has not been run and does not authorize regeneration or canonical writes.

  **Candidate-validator QA (2026-10-20, synthetic inputs only):**
  `R/package_tests/testthat_bulk/test-todo14-candidate-validation-reference.R`
  passed 24 expectations. It exercises the read-only candidate reconciliation
  contract and file-hash checks, including two fail-open edges found during
  review: fractional `rep` values were truncated while IDs were serialized,
  and duplicate names in `expected_provenance` were silently resolved by
  `[[`. The validator now rejects non-positive/non-finite/non-integer
  replicate values in both manifest and candidate rows, and rejects duplicate
  field names in before/after/expected provenance snapshots. Synthetic input
  hashes remained unchanged. This is validator logic evidence only: it does
  not inspect a real candidate, prove a post-fix run occurred, establish
  loaded package/DLL provenance, or close TODO-7's post-install regeneration
  and reconciliation gate.

  **Bounded candidate slices (2026-10-20, source overlay only):** the
  source-derived manifest subset for `iris × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=1`
  contains six keys (both design formulas × the two rand p-value calls and
  rand CI). The `compile=FALSE` run emitted all six with unique IDs and
  `status=ok`; `validate_comprehensive_result_artifact()` confirmed six rows,
  exact key-set equality, and the matching provenance sidecar. Scratch output:
  `/tmp/edi-todo14-iris-kk21-beta05-rep1.oEHfZ8/`. CSV SHA-256
  `3f14a4d97b92c1e2fffc43b2d8fbb79f3aea099456f853bf8766c29adac49f99`,
  sidecar SHA-256
  `0b1c1b94fa9dd9f4f9ea2f0613bf3950c9a1cc87882c27989b6cc5246fd6c983`,
  and log SHA-256
  `f773b08b7cf7300a90f0d5c30f61f9713081f0ca63daddc927cf4f8ac6e183da`.
  Provenance records R 4.6 development r90668, EDI 1.0.3 from the checkout
  namespace, loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
  `660dae16378ce533bf1d7bb816b2e7933b989bff838e93907889ec0cbf024159`,
  and checkout-diff SHA-256
  `3bbe6bc89834cca14ac176265fbb0c5f378b4bf778e1492613ae6e91037e6dc0`.
  This is one bounded candidate only.

  The alternative `cars` and `diamonds` candidates were partial, not
  accepted: each hit its 180-second timeout (diamonds was also retried with
  a 300-second cap), persisting only the three `~1` rows of six expected
  keys. In the diamonds retry and cars run, the `~.` p-values appeared in the
  log but the `~.` CI was still in progress at timeout; neither partial
  candidate had a completion provenance sidecar. These timeout artifacts
  remain isolated under `/tmp/edi-todo14-diamonds-kk21-beta05-rep1.7Cn4Cu/`,
  `/tmp/edi-todo14-diamonds-kk21-beta05-rep1-retry.MVKL63/`, and
  `/tmp/edi-todo14-cars-kk21-beta05-rep1.qhVSAp/`. The 8,640-key full-grid
  regeneration, provenance reconciliation, and any canonical merge remain
  open.

  **Additional bounded candidate (airquality, 2026-10-20):** the
  source-roster subset `airquality × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=1`
  comprises six keys (both formulas × the two rand p-values and rand CI).
  Its `compile=FALSE` source-overlay run emitted all six, with six unique IDs
  and `status=ok`; `validate_comprehensive_result_artifact()` confirmed the
  exact expected-key set and matching sidecar. Scratch path:
  `/tmp/edi-todo14-airquality-kk21-beta05-rep1.e6NO3W/`; CSV SHA-256
  `bcca23507f183a46fecc8dd3f9a0babf01ac2cfb34174c2590739d121a73c3b4`,
  sidecar SHA-256
  `326ae151d21a0123cf229e061602f7c7bbef98ec0794ff4adf06434a493d6245`,
  log SHA-256
  `27eeb1a54312ca28630d60aa22bb8961308364c92d12dfe0f35973f40c11bd3a`.
  The sidecar records R 4.6 development r90668, EDI 1.0.3 from the checkout
  namespace, DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
  `660dae16378ce533bf1d7bb816b2e7933b989bff838e93989ec0cbf024159`,
  and checkout-diff SHA-256
  `5347c7f6f8fd7a307becbaf477810be5291d642180e9ad4ae15178f425e2f24d`.
  This remains one bounded candidate, not full-grid acceptance.

  **Schema-v2 provenance replay (2026-10-20):** reran the same
  `airquality × survival × KK21stepwise × InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC
  × beta_T=0.5 × rep=1` six-key slice with the package-payload fingerprint
  validator. It emitted all six unique expected keys (both formulas × two
  rand p-values and rand CI), all `status=ok`; exact-key validation passed
  and all deterministic result fields equal the prior airquality beta=.5
  candidate. Before/after runtime package-payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`;
  before/after loaded DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Scratch `/tmp/edi-todo14-airquality-beta05-schema2-R3kWt9/`; CSV SHA-256
  `4cea9b5e92649e00d88fe541622f4bf0afb1580918e3b8e4d0e8a2d650359849`,
  schema-v2 sidecar SHA-256
  `c6febf58435588200d3762e629b267e59b2698c33e7180c2b7b7ce84f4e01936`.
  This is repeated isolated source-overlay evidence only; the 8,640-key
  full-grid reconciliation and post-install/native gate remain open.

  **Additional schema-v2 bounded candidate (iris beta=0, 2026-10-20):**
  preflighted the prepared TODO-14 manifest and selected its exact
  `iris × survival × KK21stepwise × InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC
  × beta_T=0 × rep=1` subset (six unique keys, both formulas × three rand
  calls). A `compile=FALSE` run completed in under the 180-second cap and
  emitted all six, each `status=ok`, with no missing results; exact ID-set
  comparison and `validate_comprehensive_result_artifact()` passed. Sidecar
  schema is 2; before/after package-payload SHA-256 is
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`, and
  before/after loaded-DLL SHA-256 is
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Scratch `/tmp/edi-todo14-iris-beta0-schema2.jjnO9U/`; CSV SHA-256
  `7379bb8c1be4c0e72ce788fa8c2b6df9a20abfd8fdc66b6627f0aa4479282dc3`,
  sidecar SHA-256
  `5d7981bf4ef3c9e0096b41819c1bc98043b988b8602fb75138f46d759f0e5368`.
  This isolated source-overlay candidate does not close the 8,640-key
  reconciliation or post-install/native gate.

  **Additional schema-v2 bounded candidate (pte_example beta=0, 2026-10-20):**
  the source-derived manifest subset `pte_example × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0 × rep=1` has six
  unique keys (both formulas × three rand calls). With no active R workload,
  a serialized `compile=FALSE` run completed within the 180-second cap; all
  six exact IDs were emitted once, `status=ok`, with no missing results.
  `validate_comprehensive_result_artifact()` accepted the exact key set and
  matching schema-v2 sidecar. Before/after package-payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382` and
  before/after loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Scratch `/tmp/edi-todo14-pte-beta0-schema2.DX4ydF/`; CSV SHA-256
  `8e079102d56fce9091d9df94f72d74f79eb3ad673c38a06b02b29f344e632648`,
  sidecar SHA-256
  `c2ec4cd8be69b4d1e5cd97948bfaf725abdbd1720f5450c04530e65fcb91adaa`,
  log SHA-256 `ad125f5eadbf03727366e41368c72e675233fff022ce965fbbe537d26bdf3da8`.
  This isolated source-overlay candidate does not close the 8,640-key
  reconciliation or post-install/native gate.

  **Partial candidate, not accepted (airquality beta=0, 2026-10-20):** the
  source-roster subset `airquality × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0 × rep=1` has six
  expected keys. The serialized schema-v2 `compile=FALSE` run hit its
  180-second timeout: only the three `~1` rows persisted (`status=ok`); the
  log records both `~.` p-values, but the `~.` confidence-interval call was
  still running and no completion sidecar was written. The three absent keys
  remain expected; this is not validator-accepted evidence. Scratch
  `/tmp/edi-todo14-airquality-beta0-schema2.4EbTwx/`; partial CSV SHA-256
  `3b5e0610608510a0015c53bf9dd7373029aafa84a0afa52596a6a603f3e309af`, log
  SHA-256 `63090e9feb010be1adf3c01c417cb1835da2b1b557078c5d74f26c15651ed8bc`.
  Do not shrink the manifest or use these rows to close the 8,640-key gate.

  **Additional schema-v2 bounded candidate (pte_example beta=.5 rep=8,
  2026-10-20):** the source-derived subset has six exact IDs for
  `pte_example × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=8`
  (two formulas × three rand calls). With no competing R job, a serialized
  `compile=FALSE` run completed in 129 seconds under the 180-second cap.
  All six IDs were unique and matched the manifest exactly, all statuses
  were `ok`, no results were missing, and the schema-v2 artifact validator
  accepted the CSV and sidecar. Before/after package-payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`;
  before/after loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Scratch `/tmp/edi-todo14-pte-beta05-rep8-schema2.Kr4ClI/`; CSV SHA-256
  `aa3c98bf79599f8d23daed201ae290b07bf73bb576eaf58b3c4c9d842a54f3cc`,
  sidecar SHA-256
  `21acecd56bb658c7f266fc0e94d1c347c542e0cf970b639fd111805400198845`,
  log SHA-256 `554405268dbb536ff0730d8cb84ecd5fe1d6811c499336b01f9f40448d75a376`.
  This is a bounded source-overlay candidate only; the full 8,640-key
  reconciliation and post-install/native gate stay open.

  **Additional schema-v2 bounded candidate (iris beta=.5 rep=2,
  2026-10-20):** the prepared source manifest contains six exact IDs for
  `iris × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=2`.
  Following serialization preflight, a `compile=FALSE` run completed in
  about 120 seconds under the 180-second cap. All six IDs were unique and
  matched the manifest exactly, all rows had `status=ok`, no results were
  missing, and the schema-v2 artifact validator accepted the CSV and
  sidecar. Before/after package-payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`; the
  loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` both
  before and after. R was 4.6 development r90668, EDI 1.0.3 from the
  checkout namespace, HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`,
  runner SHA-256 `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`.
  Scratch `/tmp/edi-todo14-iris-beta05-rep2-schema2.bYgDXf/`; CSV SHA-256
  `932671e3b49f99606070794fefcbdb3e874396d6476ca2eb82f5efba9945e921`,
  sidecar SHA-256
  `bb63292b3f87c6c53ebf59d184ac060a2fd0470f1daa8d5dfffe207006397fd8`,
  log SHA-256 `0e9ab355029a0460838e43c19fc6ea60d1c01e0b5eb66cc76b63e57837dfc576`.
  This remains isolated source-overlay evidence; full-grid reconciliation
  and post-install/native acceptance remain open.

  **Additional schema-v2 bounded candidate (iris beta=.5 rep=3,
  2026-10-20):** the source-derived subset has exactly six IDs for
  `iris × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=3`.
  The serialized `compile=FALSE` run completed in about 113 seconds under
  the 180-second cap. All six IDs were unique and matched the manifest,
  all statuses were `ok`, no results were missing, and the schema-v2
  artifact validator accepted the CSV and sidecar. Before/after package-
  payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`; the
  loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` both
  before and after. R was 4.6 development r90668, EDI 1.0.3 from checkout
  namespace, HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
  `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`.
  Scratch `/tmp/edi-todo14-iris-beta05-rep3-schema2.2m3lEQ/`; CSV SHA-256
  `a61e2926ceba860574286b071b6bc4535a52d96d66be9375bd8b547a221407d8`,
  sidecar SHA-256
  `1be0de08f98844f045bf80025c296f6c63b8cf9558f74a2e98206315d774903d`,
  log SHA-256 `b83bc635f684eebec3abb7de251a65ab795b9facf3df1f8a8693b417bc05d7bc`.
  This isolated source-overlay candidate does not close the full 8,640-key
  reconciliation or post-install/native gate.

  **Additional schema-v2 bounded candidate (iris beta=.5 rep=4,
  2026-10-20):** the source-derived subset has six expected IDs for
  `iris × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=4`.
  The serialized `compile=FALSE` run completed in about 121 seconds under
  the 180-second cap. All six IDs were unique and matched the manifest;
  all statuses were `ok`, no results were missing, and the schema-v2
  artifact validator accepted the CSV and sidecar. Before/after package-
  payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`; the
  loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` both
  before and after. R was 4.6 development r90668, EDI 1.0.3 from checkout
  namespace, HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
  `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`.
  Scratch `/tmp/edi-todo14-iris-beta05-rep4-schema2.ammv1O/`; CSV SHA-256
  `199b1b3eb231f079de1dfb011e057d1acd393fd4238c3351b0db6f013dce5a11`,
  sidecar SHA-256
  `c41f76be66a018cd5919e3101e91ec42b02c4e746f585e55b35362749d768dcc`,
  log SHA-256 `c923b9a4f15bb77071f124620e3f52a3adf3c7b25cf080c90d88731de791720d`.
  This isolated source-overlay candidate does not close the full 8,640-key
  reconciliation or post-install/native gate.

  **Source-bound candidate generator and scope-guard test (2026-10-21):**
  added `todo14_source_candidate_manifest()` to
  `R/package_tests/validate_todo14_candidate.R`. It parses the checked-in
  `comprehensive_tests.R` and `_dataset_load.R` to bind the fixed 40-replicate
  default, beta axis `{0, 0.5}`, both target designs, both formula labels,
  target class selector, three `rand` operation labels, and nine survival
  dataset names before producing 8,640 unique serialized keys. Rows carry
  `candidate_status=candidate_only_requires_setup_and_runtime_eligibility`
  and `scope_source=checked_in_runner_defaults_without_cli_filters`.
  The focused synthetic test passed 71 expectations with
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-todo14-candidate-validation-reference.R", reporter="summary")'`.
  It checks the key axes against the fixed-scope grid and rejects a changed
  replicate count or formula source. The test did not invoke the runner,
  construct designs/models, or emit candidate rows; its assertions are
  pure-R source/validator contracts, not current package/native validation.
  Live object setup, `supports_randomization_test`, capability checks, and
  per-call runtime errors/skips cannot be inferred from these source literals.
  Exact emitted attempts still require the run's attempt-event output and
  before/after package/DLL provenance. TODO-7/full 8,640-key production
  reconciliation remains open; no canonical artifact was written or changed.

  **Timeout-result validator contract, 2026-10-21:** extended
  `test-todo14-attempt-result-provenance-reference.R` with a synthetic row
  matching the runner's timeout representation (`status=ok`,
  `skip_reason=timeout`, exact timeout message, missing numeric result) and a
  matching terminal event. The TODO-14 artifact validator rejects it, as
  required by the release gate that every target row be an actual usable
  result with no timeout/skip/error message. The focused test passed 12
  expectations against installed EDI 1.0.3, with no failures, warnings, or
  skips; it invokes no native code and performs no build/install. This is
  validator-contract evidence only; the full 8,640-key post-install artifact
  and its provenance/reconciliation gates remain open.

  **Filesystem-only artifact recount (2026-10-21):** the 8,640-key expected
  manifest at `/tmp/edi-todo14-expected-attempts-20261020.csv` remains
  unchanged (SHA-256
  `7f7af2c77b02458dfff4f1aab1b2fc55d9844cde5526a3f3aa4abeb6b4c925b0`). A
  read-only comparison of 34 direct-output candidate CSVs found 300 rows,
  192 distinct expected IDs, zero extras, and 8,448 missing IDs; all row
  natural-key fields matched the manifest. The rows claim checkout commit
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9` (the current HEAD during this
  recount), but this does not establish loaded package/DLL identity. Eight
  repeated IDs have conflicting `ok` interval payloads (iris, beta=.5,
  reps 2–5, both formulas), so the partial files are not a mergeable cohort.
  Sidecars exist beside 28/34 CSVs (29 sidecar files; one CSV has two); six
  CSVs lack one. This recount did not decode or newly validate any RDS
  receipt; see the release row's earlier sidecar-validator audit. No artifact
  was modified or merged. The authorized current-package 8,640-key run and
  exact result/provenance reconciliation remain open.

  **Conflict provenance attribution, 2026-10-21 (read-only):** the eight
  repeated confidence-interval keys are the two formula variants for iris,
  beta=.5, reps 2–5. Four isolated files invoked `Nrep=rep` with
  `REP_FILTER=rep`; their interval payloads repeat the rep-1 draw across
  nominal reps: `~1` [0.496, 0.709] and `~.` [0.380, 0.536], all covered.
  Receipts partition these outputs further: reps 2–4 share package-payload
  SHA `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`,
  DLL SHA `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  and runner SHA `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`;
  rep 5 instead records package payload `babd1c66da14e8108c1e9b115770c8ffb669956c9dc014f23203a5523479e898`,
  DLL `d44eed843a1541b33f81d35f27e051f145a66b894bc616f0e5afbee00578f7be`,
  and the same runner. Thus the identical repeated values are not one
  provenance cohort and are not independent-replicate evidence.

  The unfiltered `Nrep=5`, `REP_FILTER=NA` candidate at
  `/tmp/edi-todo14-iris-beta05-reps1to5-sequential-schema2.A0xNso/` contains
  30 rows and has CSV SHA
  `8cb3fee97dc81632ff2fe4effde085eca23a89980db3c05e11606057aca90cda`; its
  schema-v2 receipt binds the CSV and records package payload
  `24f16c8bcf92ee26a116a3f5217ea121c90a1dd2c1b7914cf30db6c2d5386927`, DLL
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`, and
  runner `77bfab7772580bc94f96e845fb20a89e7f9c7d7ae9014e42f0be50c93a71fbb9`.
  It yields distinct per-replicate values for the eight keys. The later
  one-shot and prefix/resume 12-key artifacts corroborate rep 2 exactly;
  their CSV SHAs are `f689ae95bb11db257acb2304b2b304753cd86841df8c8751bb67884abf3a34f7`
  and `5c74497a082dabb799919b8b05b1464a2f3e1cf39a548f114912ee6ae13d3d4a`,
  and their receipts share payload `58f809147f419372f9e82792e2ad6de097b3cbfede3371f9fac9d4ddd0283afd`,
  DLL `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  and runner `77bfab7772580bc94f96e845fb20a89e7f9c7d7ae9014e42f0be50c93a71fbb9`.
  The sequential artifact is internally consistent as one run, and the later
  pair corroborates only rep 2; differing payload hashes and limited scope
  mean none can be merged or accepted as a current full-grid cohort. No
  candidate file was changed; the 8,640-key provenance-matched run and
  reconciliation remain open.

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build. The
`estimate_only = FALSE` path must produce bit-for-bit identical results
before and after this fix (TODO-4 verifies this) — only the previously-NA
`estimate_only = TRUE` path should change.
