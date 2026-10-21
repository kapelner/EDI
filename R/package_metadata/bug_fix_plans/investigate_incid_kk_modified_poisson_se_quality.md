# Fix: `InferenceIncidKKModifiedPoisson` Exposed Invalid Working-Likelihood Tests

> **Resolved in source 2026-10-09.** A faithful 200-replicate Pima/
> `DesignSeqOneByOneKK21stepwise` replay refuted the proposed sandwich-SE
> defect: empirical SD was 0.1932, mean robust SE was 0.1987 (ratio 1.029),
> and coverage of the MC truth 0.086 was 0.955. The real defect was the API
> exposing score, gradient, likelihood-ratio, Bartlett, and parametric
> Poisson-bootstrap inference for a modified-Poisson estimator whose valid
> uncertainty is the cluster-robust sandwich. The class and registry now
> advertise Wald inference only and classify the estimator as likelihood
> tier `none`. Focused source-loaded regression suites pass; installed
> comprehensive CSV regeneration remains a release-validation step.

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-19`. Added 2026-09-23, same audit-triage wave as
> TODO-17/TODO-18. **Resolution 2026-10-09 (supersedes the historical
> investigation narrative below):** a faithful 200-replicate Pima/KK21stepwise
> replay found calibrated robust sandwich uncertainty (empirical SD 0.1932,
> mean SE 0.1987, ratio 1.029; MC-truth coverage 0.955), refuting the proposed
> SE defect. The concrete source defect was instead API capability: this
> modified-Poisson estimator exposed score, gradient, likelihood-ratio,
> Bartlett, and parametric-bootstrap inference from its Poisson working
> likelihood despite valid uncertainty being robust Wald only. The class and
> registry now expose Wald inference only with `likelihood_tier = "none"`;
> focused source-loaded validation is complete. Only installed comprehensive
> CSV regeneration/re-audit remains, so the linked release checkbox stays
> open. Historical sections below document how that resolution was reached;
> they no longer describe the current work state.

## The finding that started this

Historical `comprehensive_tests` CSV rows flagged `bad_type1_error` for
`InferenceIncidKKModifiedPoisson` at `model_formula=~1`: reject-rate **0.000**
across MULTIPLE unrelated test-statistic families simultaneously (Wald,
score, gradient, likelihood-ratio, Bartlett all zero-reject at the same
cell). Zero-across-every-family is the interesting/unusual part — a bug in
one test statistic's formula wouldn't do that; something shared by all of
them (most plausibly the variance estimate they all consume) would.

## Hypothesis 1 (original) — REFUTED

**Claim**: a structurally non-estimable/degenerate cell, similar in shape to
`InferenceAllSimpleWilcox`'s TODO-17 finding (see
`simple_wilcox_hl_degenerate_pval_boundary.md`).

**Refuted directly**: `compute_estimate()` for the exact flagged cell
(n=172, beta_T=0) shows 146 distinct values ranging -0.37 to 0.52, only
4.65% exactly 0 — a normally-varying point estimate, not a degenerate one.
Not TODO-17's failure mode.

## Hypothesis 2 — over-estimated SE — REFUTED (checked 2026-09-23)

**Claim**: Wald CI width for the flagged cell had median 0.82 (half-width
≈0.41) while the point estimate's own empirical IQR was only (-0.11, 0.12) —
roughly 4x wider than the estimate's actual spread. If every test family
consumes the same over-estimated variance, all would under-reject together,
which matches the "all five families zero-reject" observation.

**Checked against the empirical SD 2026-09-23 (refuted as originally
stated, medium confidence — approximate fixture, not an exact harness
replay)**: 40 true-null reps on a hand-built fixture approximating the
flagged cell (`model_formula=~1`, `DesignSeqOneByOneKK21stepwise`, n=148):
empirical SD of `beta_hat_T` = 0.221, mean implied SE from the asymptotic CI
= 0.272 — a 1.23× ratio, mildly conservative, nowhere near the ~4× estimated
from the historical CSV's IQR-vs-CI-width comparison. Wald reject rate =
2.5% (1/40) — mildly conservative vs. nominal 5%, not the dramatic "0.000
across every test family" the original finding reported. The dramatic
pattern did not reproduce.

Two live possibilities, neither resolved:
1. The hand-built fixture isn't a faithful enough replay of
   `comprehensive_tests.R`'s exact data-generating process (baseline
   probability, per-subject noise).
2. The original historical-CSV comparison (IQR vs. CI width) pooled rows
   across conditions in a way that wasn't a clean apples-to-apples
   comparison — the same pooling risk flagged elsewhere in this session's
   own audit-tooling work.

## Broadened context 2026-09-23 — cross-class SE-quality lead (separately motivated, not cross-confirmed)

A second, independent investigation (into `type="studentized"`/
`"symmetric-percentile-t"` randomization-bootstrap p-values, which also
showed wildly class-dependent miscalibration direction/severity across
`InferenceOrdinalGCompMeanDiff`, `InferenceIncidKKCondLogitGLMMOneLik`,
`InferenceIncidKKGEE`, `InferenceContinQuantileRegr` — same triage wave)
traced the shared dispatch/pivot code
(`compute_rand_bootstrap_two_sided_pval()`,
`inference_all_abstract_rand_bootstrap.R:471-505`, pivot formula at
`:1026-1038`) and found it **correct** — the observed and every null-draw
pivot read the identical `cached_values$s_beta_hat_T` field, no cross-
estimator mismatch, no shared-code bug. That's evidence FOR a per-class
SE-estimator-quality explanation (as opposed to a single shared bug)
*for the studentized-pivot pattern*, since a class whose asymptotic/plug-in
`s_beta_hat_T` is a poor finite-sample approximation would degrade every
test family that consumes it (Wald/score/gradient/LR/Bartlett AND the
studentized-bootstrap pivot) simultaneously through that one shared field —
over-estimated SE → conservative/under-reject, under-estimated SE →
anti-conservative/over-reject, both directions genuinely observed across
the four classes checked there.

**Tension, explicitly noted**: that "broadened" reasoning partly leaned on
this investigation's original ~4× SE-overestimation number for
`InferenceIncidKKModifiedPoisson`, which the direct empirical-SD check above
did NOT confirm (found 1.23×, not ~4×). The studentized-BRT-pivot code trace
is still valid on its own (the shared dispatch/pivot code is clean), so
"per-class SE-estimator quality, not shared-code bug" remains the
best-supported explanation for the studentized-pivot miscalibration
specifically — but it should no longer be read as cross-confirmed by this
investigation's own original finding, since that finding didn't hold up.
Treat the two threads (studentized-pivot class-dependence;
`InferenceIncidKKModifiedPoisson`'s Wald-family zero-rejection) as
**separately-motivated, not mutually reinforcing**, until at least one is
confirmed with a faithful harness replay.

## Round 3 (2026-09-24) — a faithful harness replay, plus a NEW corroborating signal from the coverage audit

**A faithful reproduction was built this time** (pima dataset via the
harness's own `MASS::Pima.tr2` loading, `DesignSeqOneByOneKK21stepwise`,
n=148, `apply_treatment_effect_and_noise()`'s exact mechanism
`p_t = plogis(qlogis(p_base) + bt + eps)`, `SD_NOISE=0.1` — matching
`comprehensive_tests.R`'s actual DGP, not a hand-approximation this time),
40 reps at `beta_T=0.5` via `pkgload`-loaded, already-installed EDI (no
compile):

- `compute_score_two_sided_pval()` reject rate: **0/40 (0%)** — matches
  the historical finding exactly.
- Coverage against the MC-derived truth (0.086, confirmed the correct
  log-risk-ratio-scale target, not raw `beta_T=0.5`): **40/40 (100%)** —
  also matches exactly.
- Empirical SD of `beta_hat_T`: **0.210**. Mean reported SE (from
  `compute_score_confidence_interval()`): **0.279**. Ratio: **1.33×** —
  real but modest, not "grossly" inflated, and within the range plausibly
  explained by ordinary sampling noise in an SD estimate from only 40 reps
  (SE of the SD estimate itself ≈ 0.024 at this n — a faithful DGP finally
  reproduced the *symptom* but the *magnitude* of SE inflation remains
  genuinely ambiguous at this rep count).

**Revised interpretation**: the 0%-power/100%-coverage symptom is now
confirmed real and reproducible with a faithful fixture (this alone closes
possibility 1 from Round 2's open list — the earlier non-reproduction WAS
a fixture-fidelity problem, not evidence the effect isn't real). But the
magnitude question is still open: the MC truth (0.086) is small relative
to this design's actual achievable precision (SD ≈ 0.21-0.28) at n=148 —
effect size ≈ 0.086/0.25 ≈ 0.34 SD-units. A MODEST (1.2-1.4×), not
catastrophic, SE overestimate combined with this small a true effect can
land at exactly this symptom without any single dramatic bug — this may be
a genuinely underpowered benchmark scenario for this class/design/n
combination at least as much as a code defect. 40 reps cannot distinguish
"true 1.33×" from "sampling noise around 1.0×" with confidence.

**NEW, independent corroborating evidence from the coverage audit
(2026-09-24, different check entirely)**: the same class shows exactly
100% CI coverage across SEVEN-PLUS unrelated method families
(`compute_score_confidence_interval`, `compute_lik_ratio_confidence_interval`,
`compute_gradient_confidence_interval`, `compute_m_out_of_n_bootstrap_confidence_interval`
×2 formulas, `compute_subsampling_confidence_interval` ×2,
`compute_lik_ratio_bootstrap_confidence_interval` ×2) in the historical
CSV — this is the SAME symptom (over-wide CI / chronic non-rejection),
found completely independently via the two-sided exact-binomial coverage
test rather than the original Type-I-error framing. Two different checks,
built independently, both landing on the same class with the same
"everything is too wide" signature is meaningfully stronger evidence the
symptom is real than either check alone — even though, per Round 3's own
reproduction, the *magnitude* still isn't pinned down precisely.

## Resolution checklist (updated 2026-10-09)

- [x] Re-run Round 3's faithful fixture with ≥200 reps (not 40) to get a
  statistically meaningful empirical-SD-vs-SE ratio — this is now the
  single highest-value next step, since fixture fidelity is no longer the
  blocker, only rep count is.
- [x] If ≥200 reps confirms a ratio meaningfully >1 (not just noise around
  1.0), THEN proceed to `build_design_matrix()`/
  `reduce_design_matrix_preserving_treatment()` (not yet read by any round
  of this investigation) as the next candidate location for a code-level
  cause — Round 2 cleared the sandwich formula, cluster ID assignment, and
  coverage-truth target, but never checked the design-matrix-building path
  upstream of those. **Not triggered: ratio was 1.029.**
- [x] If ≥200 reps confirms the ratio is genuinely ~1.0-1.3× (modest), this
  may not be a "bug" in the defect sense at all — write up as a documented
  known-limitation (small effect size relative to this design's achievable
  precision at n=148), not a fix plan, and close this investigation as
  resolved-not-a-defect.
- [x] Reproduce using `comprehensive_tests.R`'s actual DGP call path (not a
  hand-built approximation) for the exact flagged cell
  (`InferenceIncidKKModifiedPoisson`, `model_formula=~1`), with enough true-
  null reps (≥200) to get a stable empirical-SD-vs-implied-SE ratio.
- [x] Alternatively, re-pull the original historical finding fresh from a
  larger CSV sample and check whether the ~4× IQR-vs-CI-width gap was an
  artifact of pooling rows across conditions (the specific risk flagged
  above) before concluding anything about SE quality for this class.
  **Superseded by the faithful 200-replicate replay, which directly refuted
  the pooled IQR interpretation.**
- [x] If a real SE-quality problem is confirmed for this class specifically,
  identify which variance-estimator code path it uses
  (`InferenceIncidKKModifiedPoisson`'s own `shared()`/variance computation)
  and check whether it's a per-class formula bug or a genuine finite-sample
  asymptotic-approximation weakness (the latter might not have a "fix" in
  the bug sense — could end up documented as a known limitation instead,
  same caveat as TODO-20's BRT-tie lead). **The audited path was the class's
  cluster-sandwich fit and it was calibrated; the fix instead removes invalid
  working-likelihood inference families.**
- [x] Independently, if picked up: extend the four-class studentized-pivot
  cross-class check (`InferenceOrdinalGCompMeanDiff`,
  `InferenceIncidKKCondLogitGLMMOneLik`, `InferenceIncidKKGEE`,
  `InferenceContinQuantileRegr`) with an empirical-SD-vs-implied-SE ratio
  measurement per class, the same way this investigation did for
  `InferenceIncidKKModifiedPoisson`, to actually test the "per-class
  SE-estimator quality" hypothesis on classes it wasn't refuted on yet.
  **Out of scope: this is a separate multi-class investigation and is not a
  subtask of the refuted modified-Poisson SE hypothesis.**
- [x] Only once at least one of the above confirms a concrete, fixable
  mechanism should this file be replaced/upgraded to a normal `# Fix:` plan
  with its own `## TODOs` fix checklist. **The concrete API/capability defect
  is fixed and captured by this resolution checklist.**

## Validation

- [x] Focused sandwich/Wald contract regression: 13 assertions.
- [x] Parametric-bootstrap capability census: 257 assertions, one existing
  quarantined-class skip.
- [x] Full-likelihood migration/registry baseline: 742 assertions.
- [ ] Regenerate and re-audit the installed comprehensive CSV after the next
  authorized package rebuild; obsolete score/gradient/LR/Bartlett rows for
  this class must disappear.

### Source-loaded harden-retry and manifest check (2026-10-20)

`test-kk-modified-poisson-likelihood-spec-harden-retry-and-guards-reference.R`
passed all 25 assertions after `pkgload::load_all("R/EDI", compile = FALSE)`.
The test deliberately makes the first covariate-adjusted fit return `NULL`,
then verifies that harden mode retries with the two-column treatment-only
matrix and matches an independent Poisson GLM estimate; without hardening, it
verifies there is no retry and the result is nonestimable. This demonstrates
the R-source branch behavior with the existing native ABI; it is not a line-
coverage measurement and does not change the canonical registry percentage.
Loaded native DLL SHA-256 was
`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224` (matching
the installed EDI 1.0.3 DLL). The test is listed in both correctness and
coverage runtime inventories; check-only shard planning passed for correctness
(1,158 files, 5 shards) and coverage (1,410 files, 101 shards). The standalone
coverage-registry regression checks also passed. No coverage report was
generated, and no canonical coverage row or result CSV was modified.

### Fresh migration-golden recheck (2026-10-20)

`test-incid-kk-modified-poisson-migration-golden.R` passed all 35 assertions
with `pkgload::load_all("R/EDI", compile = FALSE)` against the user's freshly
rebuilt native DLL (SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`). This
revalidates the current checkout R migration/capability contract; it does not
regenerate or reconcile the comprehensive incidence CSV. The result-family
audit remains open, and no canonical CSV was modified.

### Additional installed migration-golden check

The updated `test-incid-kk-modified-poisson-migration-golden.R`, including the
explicit `likelihood_tier == "none"` metadata assertion, passed 36
expectations against installed EDI 1.0.3 after sourcing the checkout's pure-R
fixture helper. This is mixed-provenance test evidence, not a source-loaded or
rebuilt-checkout validation. The exact invocation and loaded DLL hash were not
captured. No build/install or canonical result write occurred.

### Installed-results artifact preflight (2026-10-18)

A filename-only search found no class-filtered
`comprehensive_tests_results*InferenceIncidKKModifiedPoisson*` shard. The
available canonical `comprehensive_tests_results_nc_1_incidence.csv` is
525,863,531 bytes (mtime 2026-10-09) and its header includes
`function_run`, `rep`, `beta_T`, `dataset`, `response_type`, `design`,
`inference_class`, `method_family`, `run_row_id`, and `status`. No full-file
scan, row count, or rewrite was performed. Once a provenance-pinned package
containing the fix is installed, regenerate the class's complete supported
incidence matrix; reconcile rows by those experiment/method identifiers,
remove only this class's obsolete score/gradient/LR/Bartlett/parametric-
bootstrap rows, and verify the Wald rows remain. Preserve the canonical file
until that generation and key-level audit are authorized and complete.

**Additional isolated-artifact inventory, 2026-10-20:** a narrower
one-replicate diagnostic was found at
`/tmp/edi-v105-todo19-scratch/package_tests/comprehensive_tests_results_nc_1_incidence_filtered_design-KK21stepwise_class-InferenceIncidKKModifiedPoisson_dataset-pima_beta-0_rep-1_family-wald.csv`
(mtime 2026-10-16 05:03, SHA-256
`c44b0987fa353e3e3ba635b2af8a98e19010b2bc8178249d1f4940ab0bfa269d`). It has
eight unique `id`s, all `status=ok`, and exactly four
`(model_formula, design_formula)` combinations times two Wald functions
(p-value and CI). Its `github_commit_id` is `NA`; it is explicitly filtered
to the Wald family and one Pima/KK21stepwise/replicate/beta-zero fixture, so
it cannot establish that obsolete likelihood-family rows disappear from the
complete canonical incidence matrix or provide package/DLL provenance. This
refines the earlier filename-only preflight: a small filtered Wald diagnostic
exists, but the required post-fix complete class matrix and row-key audit are
still absent. No full-file scan or canonical result modification was made.

### Exact-key subset reconciliation and migration recheck (2026-10-20)

The installed-package migration golden passed 35 assertions with
`Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-incid-kk-modified-poisson-migration-golden.R", package = "EDI")'`
against EDI 1.0.3; the loaded native DLL SHA-256 was
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
No build/install or canonical write occurred.

Read-only reconciliation of the two isolated pilot artifacts in
`/tmp/edi-v105-todo19-current-DgbXhW/` found 64/64 unique `id` keys and
`status=ok`, spanning four class/formula labels. No score, gradient,
likelihood-ratio, Bartlett, or parametric-bootstrap function rows appeared.
The eight `method_family=wald` rows in the 64-row all-family artifact have
the same eight keys and inference results as the co-located 8-row Wald-only
artifact. The co-located Wald-only CSV SHA-256 is
`49345f6d1777a41417805c9a55498cb1cd40c72cc2954f5ee6a3408da59b09ec`.
The older, separately located Wald-only artifact described above is the
`todo19-scratch` file with SHA-256
`c44b0987fa353e3e3ba635b2af8a98e19010b2bc8178249d1f4940ab0bfa269d`; it is
not the co-located DgbXhW artifact. Their run telemetry and commit-provenance
fields differ. The all-family artifact records checkout commit
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, but neither it nor the co-located
Wald-only CSV records an EDI DLL hash, so this pilot does not establish native
binary provenance. The all-family CSV SHA-256 is
`42308b5901487f4e3e842c8153fad697762b9503a279a3b54d7c51e6ab6bb3c2`.
This closes only the exact-key subset check for the one-replicate Pima /
KK21stepwise / beta-zero pilot, not the full supported-incidence matrix or
the complete absence audit under normal (non-narrow) execution. Full
provenance-pinned installed regeneration and canonical key reconciliation
remain open.

### Bootstrap-support regression after the user's reinstall (2026-10-20)

The focused capability/migration checks were rerun in both package modes:

- Installed EDI 1.0.3: `test-incid-kk-modified-poisson-migration-golden.R`
  passed 35 expectations; `test-parametric-bootstrap-lr-all-capable-classes.R`
  passed 257, with the existing Weibull frailty loggamma quarantine skip.
- Checkout R overlay: the same two files passed 35 and 257 expectations,
  respectively, with that same single quarantine skip, after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`.

Both runs loaded the same native library bytes: installed path
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` and
checkout-overlay path under `/tmp/RtmpWlx0He/pkgload3568541e9/EDI.so` had
MD5 `8b3ca30492d7b1c790deeebe94b201ad` and SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
The capability census confirms the advertised bootstrap-capable class set
has working smoke cases; the migration golden checks the modified-Poisson
class's post-migration contract. This confirms the latest installed R layer
and the current checkout R overlay for these focused support contracts. It
does not regenerate or reconcile comprehensive rows. The sole release gate
remains a provenance-pinned complete supported-incidence matrix and
key-level audit; no canonical CSV was changed.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`). Any reproduction work
must state explicitly whether it used the real `comprehensive_tests.R` DGP
or an approximation — the approximation-vs-real distinction already caused
one non-reproduction in this investigation and must not be glossed over
again.

### Candidate-count and next-slice audit (2026-10-21)

Read-only inspection reconfirmed that the retained `/tmp/edi-v105-todo19-current-DgbXhW/`
all-family pilot has 64 unique IDs, `status=ok` on all rows, and 16 distinct
`function_run` values for each of its four model/design-formula labels. Its
eight Wald rows match the co-located Wald-only pilot's key set. The CSV has
64/64 nonmissing `github_commit_id` values, but neither pilot CSV has a
schema-v2 provenance sidecar or records package version/DLL SHA-256. The
all-family CSV SHA-256 remains
`42308b5901487f4e3e842c8153fad697762b9503a279a3b54d7c51e6ab6bb3c2`.

The `430,080` figure is a conditional candidate count, not a retained
430,080-row manifest: 26,880 current-source class/formula labels (12 datasets
× 2 beta values × 40 reps × 7 designs × 2 model formulas × 2 design formulas)
times the 16 operations observed in the single Pima/KK21stepwise/beta-zero
pilot. That one-cell operation roster is not evidence that every operation is
eligible on every grid cell. A minimal next authentic slice would be a fresh,
isolated, normal-mode (not `narrow`) run for that same one-cell selector using
a provenance-pinned post-fix package and the current runner, retaining the
schema-v2 sidecar and reconciling all formula-specific keys/statuses. Such a
slice could check normal-mode unsupported-row absence for that cell only; it
would not close the full-grid requirement. Current `/tmp` availability is
363 MiB against the prior 318 MiB output estimate, leaving too little headroom
for a safe full run plus sidecar/log/temp files. No run, canonical-row access,
or canonical write was performed in this audit.
