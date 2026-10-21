# Fix: `InferenceSurvivalRestrictedMeanDiff` Computes Restricted Mean Survival Time to a Different Truncation Horizon τ Per Arm

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-23`. Found 2026-09-24, surfaced by the new
> `low_coverage` audit check's two-sided exact-binomial test (H0:
> coverage = 0.95) — near-universal, severe undercoverage (0.53-0.65,
> should be 0.95) across almost every CI-construction method family this
> class supports; root-caused same day.

## The bug, confirmed by direct code reading at three sites

Restricted Mean Survival Time (RMST) integrates the Kaplan-Meier curve
from 0 to a truncation horizon τ. The RMST literature (Royston & Parmar
2013, and this class's own cited reference) is explicit that τ **must be
common across the two arms being compared** — otherwise the difference of
two RMSTs integrated to different horizons is not a coherent, comparable
estimand. This class computes τ **independently per arm**, as that arm's
own maximum observed/censored time, at three sites that all share the
same shape:

- R level: `weighted_survival_stat_for_group()`
  (`R/EDI/R/inference_survival_rmst.R:239`) — `tau = max(y)`, called
  separately per arm by `weighted_survival_stat_diff()` (`:257`/`:260`).
- C++ point-estimate level (the actual production path,
  `get_survival_stat_diff`): `fast_survival_stats.cpp:158` and `:290` —
  `restricted_mean += survival_probs.back() * (subjects.back().time -
  unique_times.back())`, where `subjects` is that call's own per-group
  vector, sorted, so `subjects.back().time` is that arm's own max time.
- C++ SE level: `fast_survival_stats.cpp:400`,
  `get_restricted_mean_se_for_group()` — `double tau =
  subjects.back().time;`, the identical per-arm-local pattern, feeding
  `get_restricted_mean_se_diff()` (`:455`, calling the per-group SE
  function once per arm at `:487`/`:489`).

At this harness's 15% censoring rate (`comprehensive_tests.R:798` — a
moderate, unremarkable rate, not an edge case), the two arms routinely
realize different max follow-up times, so this fires broadly rather than
in a rare corner case — exactly matching the observed near-universal (not
occasional) undercoverage.

## Two distinct downstream consequences, both plausible contributors

1. **Estimand bias.** The point estimate is a difference of two RMSTs
   integrated to *different* horizons — not an unbiased estimate of any
   single well-defined quantity tied to `beta_T`.
2. **Structurally under-estimated SE.** τ varies draw-to-draw (a
   different bootstrap resample realizes a different max time, so a
   different τ), an extra source of sampling variability the classical
   Greenwood-based SE formula — which assumes a *fixed* τ — never
   accounts for. This alone would produce the observed undercoverage
   signature regardless of the bias question.

This also explains the exact pattern observed: consistent, severe
undercoverage across `wald` (0.535), `asymp` (0.569), `subsampling`
(0.562), every `bayesian_bootstrap`/`bootstrap` flavor (0.565-0.601),
`m_out_of_n_bootstrap` (0.591), and `jackknife_wald` (0.645) — all of
which reuse the same core `get_survival_stat_diff`/
`get_restricted_mean_se_diff` machinery — while `rand_bootstrap`-family
variants (0.857-0.937) and `rand(custom)` (0.971) are comparatively
spared, since they route through a structurally different resampling
mechanism (`compute_fast_rand_bootstrap_distr`,
`inference_survival_rmst.R:204-218`, not traced in detail here but
evidently not sharing the per-arm-τ code path).

## Full per-`function_run` coverage breakdown (n ≥ 30, historical CSV)

| `function_run` | n | coverage |
|---|---:|---:|
| `compute_wald_confidence_interval` | 1448 | 0.535 |
| `compute_asymp_confidence_interval` | 1586 | 0.569 |
| `compute_subsampling_confidence_interval` | 906 | 0.562 |
| `compute_bayesian_bootstrap_confidence_interval_bca` | 1232 | 0.565 |
| `compute_bayesian_bootstrap_confidence_interval_wald` | 1556 | 0.568 |
| `compute_bayesian_bootstrap_confidence_interval` | 738 | 0.572 |
| `compute_bayesian_bootstrap_confidence_interval_basic` | 738 | 0.574 |
| `compute_bootstrap_confidence_interval` | 738 | 0.572 |
| `compute_bootstrap_confidence_interval_bca` | ~900 | ~0.58 |
| `compute_bootstrap_confidence_interval_basic` | ~900 | ~0.58 |
| `compute_m_out_of_n_bootstrap_confidence_interval` | 906 | 0.591 |
| `compute_bootstrap_confidence_interval_studentized` | 173 | 0.601 |
| `compute_jackknife_wald_confidence_interval` | 1567 | 0.645 |
| `compute_rand_bootstrap_confidence_interval*` (several variants) | — | 0.857-0.937 |
| `compute_rand_two_sided_pval(custom)` (CI-adjacent, for reference) | — | 0.971 |

This class has no `model_formula` concept (`formula` column is `NA`
throughout — confirmed). `coverage_truth` is 100% populated, ruling out a
missing-truth-target explanation for the pattern.

## Implemented fix (2026-10-08; compiled-kernel validation pending)

Compute a single shared τ once per estimation call — the standard
convention is the **minimum** of the two arms' max observed/censored time
(the horizon both arms can actually support) — and pass it into both
arms' KM-integration and SE computation instead of each independently
deriving its own from `subjects.back().time`. This touches exactly three
sites: `weighted_survival_stat_for_group()`
(`inference_survival_rmst.R:239`) and the two C++ functions
(`fast_survival_stats.cpp:158`/`:290` for the point estimate, `:400` for
the SE). Not a "pick a more robust estimator" design decision — this is a
concrete, scoped code fix, not an inherent statistical limitation of RMST.
The implementation applies the convention consistently to the R
weighted-bootstrap path, the R and portable/Python point-estimate kernels,
the Greenwood SE-difference kernel, and both serial and parallel
randomization-bootstrap kernels. The exported single-group point and SE
helpers retain their own-maximum horizon because there is no second arm in
those APIs.

## TODOs

- [x] TODO-1: Confirm the mechanism with a direct reproduction via
  `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, top-level `CLAUDE.md`).
  Construct a minimal two-arm fixture where the arms' realized max times
  differ by a known amount, print each arm's independently-derived τ, and
  confirm they differ as predicted. This investigation traced the code but
  did not run it — this is the concrete next step before treating the
  root cause as fully closed. **Done 2026-10-08:** on the exact fixture
  `y=c(1,4,2,3,10)`, `dead=c(1,0,1,0,0)`,
  `w=c(0,0,1,1,1)`, the installed pre-fix kernel returned `4.8333333`,
  exactly the independently truncated-arm reference, while the common
  `tau=4` reference is `0.8333333`.
- [x] TODO-2: Implement the shared-τ fix at the three identified sites
  (`weighted_survival_stat_for_group()`,
  `fast_survival_stats.cpp:158`/`:290`, `fast_survival_stats.cpp:400`).
  Since the point estimate itself changes (not just its SE), this is a
  **documented default change** requiring a numerical-equivalence
  discipline different from most of this session's other fixes — a class
  whose two arms happen to share max follow-up time (rare but possible)
  should show no change; every other case will show a genuinely different
  point estimate, by design (the old value was not a well-defined
  estimand). Note this explicitly in the fix's commit message and any
  migration-golden test updates. **Done 2026-10-08:** the audit also found
  the same defect in the portable/Python and randomization-bootstrap paths,
  so all RMST-difference paths now use the same horizon. The shared
  integration helper also correctly returns `tau` for an all-censored
  single group, rather than the previous zero area.
- [ ] TODO-3: Validate the native changes in `fast_survival_stats.cpp`
  against an artifact built from the exact source revision. Local compile,
  build, or install requires explicit permission under the current repo
  instructions; any authorized compile must use `EDI_UNITY=0`. The existing
  bulk correctness workflow is the no-local-compile route for exact-HEAD
  native build/runtime evidence. **Pending:** repository instructions in the
  current session explicitly prohibit compiling,
  building, or installing. **Updated 2026-10-14:** after the user's
  reinstall, the installed package still reports version 1.0.3, but the
  C++-backed shared-horizon/Greenwood/randomization regression file passed
  all 17 assertions, and the separate 52-assertion `survfit` group/difference
  reference passed. No compile command was run by Codex; the explicit
  compile-permission rule remains in force, so current native validation is
  not claimed as complete.
  **Same-HEAD CI native validation 2026-10-16:** current checkout HEAD
  `430c19bcdb0702d998c79f9058c449449034134c` passed R bulk run `38808821543`.
  Its isolated build job installed that commit and all five correctness
  shards succeeded. The correctness manifest includes the shared-horizon,
  native RMST/complete-randomization, Greenwood `survfit`, weighted/fallback,
  and general-censoring tests. Thus the changed C++ code was compiled and
  exercised at current HEAD in CI; no local or targeted compile was run.
  This confirms native compile/runtime behavior at the same HEAD in CI, but
  does not validate a later checkout HEAD; TODO-3 remains open until exact-HEAD
  native CI evidence is available (or explicitly authorized local validation
  is completed).
  **Current-HEAD provenance recheck 2026-10-17:** checkout HEAD is
  `3f71c2c996050fc0367fdce2e287b9e90b6e6891`; the latest remote run list
  contains no run for this SHA. The latest successful `test-bulk-non-cran` build/shard
  run remains `38808821543` at `430c19bcdb0702d998c79f9058c449449034134c`.
  The current diff from that SHA has no changes to
  `fast_survival_stats.cpp`, `inference_survival_rmst.R`, or
  `test-rmst-weighted-shared-truncation-horizon-reference.R`, so the target
  source/test content is unchanged, but this is source-identical ancestor
  evidence, not exact-current-SHA validation. The most recent scheduled
  coverage run (`39009933731`) is also at `430c19bc` and is not native-gate
  evidence for the new SHA. A no-local-compile route is available: run the
  existing bulk correctness workflow on the current commit, whose build job
  compiles/installs that commit in an isolated library and whose five shards
  execute the native tests; until that exact-SHA run exists, TODO-3 remains
  open. **Supplemental installed-package runtime check 2026-10-17:** the
  focused `test-rmst-weighted-shared-truncation-horizon-reference.R` run
  against installed EDI 1.0.3 passed 4 assertions with zero failures or
  warnings (`TMPDIR=/tmp Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-rmst-weighted-shared-truncation-horizon-reference.R", package="EDI")'`).
  This is useful runtime evidence for the installed library only; it is not
  an exact-current-HEAD build/CI result and does not close TODO-3.
  **Current-HEAD provenance recheck 2026-10-18:** checkout HEAD is
  `66379c40b7c417ba024a5edbe79a1f1a8b344222`; `gh run list --commit
  66379c40b7c417ba024a5edbe79a1f1a8b344222` returns no runs. The latest
  successful scheduled coverage run `39009933731` is at
  `430c19bcdb0702d998c79f9058c449449034134c`, and its correctness jobs were
  skipped, so it is not native validation. The latest successful bulk
  correctness run remains `38808821543` at that same older SHA. The target
  RMST source and focused shared-horizon test are unchanged between that SHA
  and current HEAD (a path-limited diff for `fast_survival_stats.cpp`,
  `inference_survival_rmst.R`, and the focused shared-horizon test is empty),
  but this ancestry/source-identity does not equal an exact-SHA native run.
  TODO-3 therefore remains open; run the current commit through the existing
  bulk correctness workflow for exact-SHA CI evidence. A local targeted
  compile is an alternative only with explicit permission and `EDI_UNITY=0`.
  **Current-source R-layer check 2026-10-18:** ran
  `test-rmst-weighted-shared-truncation-horizon-reference.R` after
  `pkgload::load_all("R/EDI", compile = FALSE)` at checkout HEAD
  `efdc1b4ebe07c6dc3aadba713b5f5fe0722fdfe1`; all 4 assertions passed,
  with no failures, warnings, or skips. The source-loaded session's EDI DLL
  MD5 (`dd43c5d0e11708aea17ba82b900f66d1`) matches the installed EDI 1.0.3
  DLL at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`.
  This fixture validates the R weighted-helper path against `survfit`, not the
  changed native RMST kernels; it does not close TODO-3 or provide current-
  HEAD native provenance.
  **Post-HEAD installed-native recheck, 2026-10-20:** the C++-backed
  `test-rmst-se-mean-diff-kernel-and-complete-randomization-draw-kernels-reference.R`
  passed 17 assertions against installed EDI 1.0.3 with 0 failures, warnings,
  or skips. The installed `EDI.so` SHA-256 is
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`, with
  embedded build timestamp `2026-10-19 23:31:50 IDT` and mtime
  `23:47:15 IDT`, after checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9` (`21:03:16 IDT`). The changed
  native source, R helper, and test file are clean at HEAD. This is focused
  post-HEAD installed-library runtime evidence using the user's reported
  reinstall; the package embeds no Git SHA, so it does not prove artifact
  source identity at the exact-revision level required by TODO-3. Exact-HEAD
  CI evidence or an explicitly authorized targeted compile/runtime remains
  required. No build/install or output snapshot was performed here.
  **Checkout-R source overlay, 2026-10-20:** reran the same 17-assertion
  kernel/randomization-draw test after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. It passed with
  0 failures, warnings, or skips; `load_all()` reported EDI 1.0.3 and loaded
  `/tmp/RtmptXXmxm/pkgload254ec505/EDI.so`. The reused installed library
  binary at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`
  has SHA-256 `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`
  (mtime `2026-10-19 23:47:15 +0300`). The relevant R helper, native source,
  and test are clean at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`.
  This confirms checkout-R behavior with the reused installed native DLL, not
  an exact-source native build; the DLL embeds no Git SHA. It does not address
  coverage calibration or comprehensive-row regeneration. No compile/install
  or canonical output write occurred.
  **Installed R-helper edge recheck, 2026-10-20:** the focused shared-horizon
  test now also covers an all-censored control arm. Against installed EDI
  1.0.3, `test-rmst-weighted-shared-truncation-horizon-reference.R` passed all
  8 expectations (0 failures, warnings, or skips). The independent
  `survival::survfit` reference confirms the all-censored arm contributes
  exactly the shared `tau`, and the R weighted-difference helper matches the
  two-arm contrast. Installed `EDI.so` SHA-256 is
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  (mtime `2026-10-20 09:38:02 +0300`); checkout HEAD is
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This test exercises the R helper,
  not the changed native kernels, and the package embeds no Git SHA, so it is
  not exact-source native provenance. A read-only `cmp` found the installed
  DLL byte-identical to the ignored checkout artifact `R/EDI/src/EDI.so`
  (both SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`,
  `cmp` exit 0). This confirms binary equality to that local artifact but not
  which tracked source revision produced it; the ignored `.so` has no
  embedded build manifest/Git SHA. Thus the exact-source/native validation
  gate is still open. No build/install or canonical output write occurred;
  TODO-3/5/7 remain open.
  **Latest installed-native recheck, 2026-10-20:** after the user's later
  reinstall, `library(EDI)` resolved to EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI` under R-devel
  `r90668`; its loaded `EDI.so` SHA-256 is
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  (mtime `2026-10-20 10:40:08 +0300`). The focused installed-package command
  `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-rmst-se-mean-diff-kernel-and-complete-randomization-draw-kernels-reference.R", reporter="summary")'`
  passed all 17 expectations with no failures, warnings, or skips. The tracked
  native source, R helper, and regression test remain clean at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This is a current installed-DLL
  runtime check; neither the package nor the binary embeds a Git SHA tying
  this artifact to those exact sources. It therefore adds runtime evidence
  but does not close TODO-3's exact-source/native provenance gate, TODO-5's
  calibration, or TODO-7's regeneration. No build/install or canonical write.
- [x] TODO-4: Decide the exact shared-τ convention (minimum of both arms'
  max time is the standard literature default; confirm this is what's
  wanted here, or whether a pre-specified fixed horizon parameter should
  be exposed instead — check whether the class already has a `tau`/
  horizon argument that's simply unused, or whether one needs to be
  added). **Done 2026-10-08:** no existing horizon parameter exists; use
  the standard minimum arm-level maximum. Adding a user horizon is a
  separate API enhancement and is not needed to correct the default.
**Acceptance criteria (owner decision 2026-10-21, TODO-5 calibration):**
- **Denominator:** accept on the **all-attempts** denominator. Every attempted
  replicate counts; an invalid, non-finite or missing interval counts as
  noncoverage (the BCa diagnostic is 33/35 = 94% finite-only but 33/120 = 27.5%
  all-attempts, the gap being almost entirely invalid intervals). The generic
  `SimulationFrameworkReport` finite-only rate (invalid excluded) is not
  acceptance evidence for this item.
- **Invalid fraction:** report the invalid count per method family and cap it
  separately: a family fails if more than 5% of attempts yield an invalid
  interval (5% cap confirmed by the owner 2026-10-21: keep 5%, conventional and strict).
- **Precision / replicates:** target a 95% binomial half-width of about 2
  points at coverage 0.95, i.e. at least 457 attempted replicates per method
  family (120 replicates gives only about +/-4 points). A family passes when
  its exact binomial interval for all-attempts coverage contains 0.95.

- [ ] TODO-5: Re-run the historical-CSV-style coverage check (or a fresh
  simulation at this harness's censoring rate) across every affected
  method family and confirm coverage returns to nominal ~95%.
  **Bounded installed-package diagnostic 2026-10-16 (not closure):** against
  EDI 1.0.3, seed 23001, 120 replications, n=100/arm, B=199 for each
  bootstrap interval; exponential event rates were 0.4 (control) and 0.3
  (treatment), with administrative follow-up maxima forced to 4 and 10, so
  the shared horizon was exactly τ=4 in every sample and the analytic RMST
  contrast was 0.334094. Mean censoring was 13.2%. Wald coverage was 115/120
  (0.958; exact 95% binomial interval 0.905–0.986), nonparametric percentile
  bootstrap 112/120 (0.933; 0.873–0.971), and Bayesian-bootstrap percentile
  113/120 (0.942; 0.884–0.976). This small diagnostic exercises the changed
  estimand and spans asymptotic, ordinary-bootstrap, and weighted-bootstrap
  intervals, but its intervals are wide and it does not cover every affected
  method family; the full TODO-5 calibration remains open. The exact binomial
  intervals reflect outer-replication uncertainty only, not inner-bootstrap
  Monte Carlo error at B=199. It ran only against the installed package and
  does not validate the checkout's C++ changes. One administratively
  censored sentinel per arm fixed each sample's observed maximum; this is a
  bounded stress design, not a fully iid coverage calibration.
  **Expanded installed-package diagnostic, 2026-10-16 (still not closure):**
  the broader matrix used seed 23002, 120 reps, n=100/arm, B=99, rates
  0.4/0.3, maxima 4/10 (τ=4, truth 0.334094; mean censoring 13.5%). Exact
  95% binomial intervals for valid CIs were: asymp/Wald 113/120 each
  (0.942; 0.884–0.976); ordinary bootstrap percentile 114/120 (0.950;
  0.894–0.981), basic 110/120 (0.917; 0.852–0.959), BCa 33/35 valid
  (0.943; 0.808–0.993; 85/120 invalid), studentized 115/120 (0.958;
  0.905–0.986); Bayesian-bootstrap percentile 115/120 (0.958; 0.905–0.986),
  basic 112/120 (0.933; 0.873–0.971), BCa 34/36 valid (0.944; 0.813–0.993;
  84/120 invalid), Wald 114/120 (0.950; 0.894–0.981); subsampling-basic
  111/120 (0.925; 0.862–0.965); m-out-of-n-basic 111/120 (0.925;
  0.862–0.965); jackknife-Wald 113/120 (0.942; 0.884–0.976); and
  randomization-bootstrap 100/120 (0.833; 0.754–0.895). BCa coverage is
  conditional on the few finite intervals; counting invalid intervals as
  noncoverage gives 33/120 and 34/120, respectively.

  A second pattern/seed used seed 23003, 120 reps, n=100/arm, B=199,
  maxima 3/8 (τ=3, truth 0.231087; mean censoring 20.4%). Wald covered
  117/120 (0.975; exact 95% interval 0.929–0.995), ordinary-bootstrap
  percentile 116/120 (0.967; 0.917–0.991), Bayesian-bootstrap percentile
  119/120 (0.992; 0.954–1.000), and subsampling-basic 116/120 (0.967;
  0.917–0.991); all had 120 finite intervals. This second run was narrowed
  to four representatives after the full matrix's randomization-bootstrap
  path made the second-pattern run exceed the bounded runtime. These intervals
  reflect outer-replication uncertainty only, with additional inner-bootstrap
  Monte Carlo error (especially B=99) unaccounted for. Results are mixed—most
  non-randomization methods are compatible with 95% at this resolution, while
  the randomization-bootstrap interval undercovers and both BCa variants have
  substantial invalid rates—so the complete historical-CSV calibration and
  post-install regeneration remain required. All runs used installed EDI
  1.0.3, not the checkout's compiled C++. Both patterns used one forced
  administrative censor per arm to make their maxima deterministic, so these
  remain stress diagnostics rather than iid coverage evidence.
  **Coverage-accounting audit, 2026-10-20:** the stored expanded-diagnostic
  summary explicitly distinguishes the finite-only BCa rates (33/35 and
  34/36) from the all-replication rates after treating invalid intervals as
  noncoverage (33/120 and 34/120). However, the generic
  `SimulationFrameworkReport` contract is different: its finite-calibration
  regression uses five CI rows, reports `n_cov=3`, and computes 2/3 coverage
  and the exact binomial test with denominator 3, excluding two non-finite
  intervals. The RMST shared-horizon, Wald, and fallback tests are fixture
  correctness tests, not empirical interval-coverage classifiers. A targeted
  `/tmp` filename audit found no retained per-rep RMST calibration output or
  driver to independently verify the stored 120-rep tabulation. Therefore the
  generic report must not be used as TODO-5 acceptance without a separate
  all-replication invalid-interval count; the full calibration remains open.
  **Synthetic output-contract regression, 2026-10-20:** broadened the
  existing `test-simulation-report-finite-calibration-reference.R` fixture
  to retain and enumerate five attempted CI reps, two invalid intervals,
  and two covered reps. Its independent raw-row calculation distinguishes
  finite-only coverage (2/3) from all-attempts coverage (2/5 when invalid
  intervals count as noncoverage); it also pins the report's `n_cov=3` and
  finite-only binomial denominator of three. The focused test passed against
  installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI` via
  `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-simulation-report-finite-calibration-reference.R", reporter="summary")'`;
  no simulation or fit was run. This makes the generic
  report boundary explicit but supplies no RMST per-rep output, calibration
  result, or owner-selected replication/tolerance criterion; TODO-5 remains
  open.
  **Checkout-R source-overlay recheck, 2026-10-20:** with no concurrent
  R/Rscript workload, ran the same focused test after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; it passed with
  no failures. Runtime was R Under development (2026-10-13 r90668), EDI 1.0.3,
  checkout namespace `/home/kapelner/workspace/EDI/R/EDI`; the loaded temporary
  DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This confirms the current checkout R report path still uses finite-only CI
  rows on the synthetic fixture; it does not implement or validate
  all-attempts coverage for RMST calibration, and supplies no historical
  calibration rows. No build/install, simulation, or canonical output write.
  **One-key empirical-calibration pilot preflight, 2026-10-20 (not run):**
  selected the exact first source-manifest key
  `rep=1, beta_T=0, diamonds, survival, Bernoulli, design_formula=~1,
  InferenceSurvivalRestrictedMeanDiff [design_formula=~1],
  compute_wald_confidence_interval`. The non-R runbook is
  `/tmp/edi-todo23-rmst-pilot-preflight-20261020.md`. Current harness
  selectors can constrain response/design/class/dataset/beta/rep/test-family,
  but not formula; thus its bounded `wald` run would retain the target plus
  companion `~.` attempts. The runbook keeps all returned/error/skipped and
  invalid-interval rows, redirects the CSV/provenance/temp files to a fresh
  `/tmp` directory, and caps the future run at 180s. It is one diagnostic
  attempt, not empirical calibration or acceptance evidence; the full
  120-rep multi-method study and owner-approved precision/acceptance rule
  remain open. No R process, fit, or output file was created.
- [x] TODO-6: Add a permanent regression test constructing a fixture with
  deliberately mismatched arm-level max follow-up times, asserting the
  point estimate and SE are computed against one shared τ, not two
  different ones. **Done 2026-10-08:** point estimate, SE, weighted
  bootstrap, randomization-bootstrap, and Python portable-kernel references
  now assert the common-horizon contract. The source-loaded weighted tests
  pass (4 expectations); the shared-horizon Greenwood formula was also
  checked against `survival::survfit` on 100 deterministic random fixtures.
- [ ] TODO-7: Regenerate the affected `comprehensive_tests` CSV rows for
  this class's coverage-affected methods once fixed and installed (only
  after install, not before, same caution as the sibling plans this
  session produced).

  **Read-only artifact check 2026-10-16:** canonical
  `R/package_tests/comprehensive_tests_results_nc_1_survival.csv` has 50,670
  `InferenceSurvivalRestrictedMeanDiff` text matches, size 372,209,537 bytes,
  and mtime 2026-09-27 (before the 2026-10-08 source fix). The TODO-56 resume
  copy has the same size and match count but is not a post-fix regeneration
  receipt. No current provenance ties any canonical RMST result rows to the
  fixed installed package. Keep TODO-7 open; regenerate/reconcile only after
  TODO-56 releases the shared artifacts.

  **Source-derived operation-roster preflight, 2026-10-20 (scratch only):**
  `/tmp/edi-todo23-source-attempt-operation-manifest.csv` lists 18 current
  full-route survival CI `function_run` candidates; the comparison is in
  `/tmp/edi-todo23-source-attempt-comparison.csv` and
  `/tmp/edi-todo23-source-attempt-comparison.txt`. Thirteen names match
  explicitly listed historical CI labels. The remaining candidates include
  four rand-bootstrap-t CI variants grouped under the plan's wildcard and a
  current Bayesian-bootstrap studentized candidate not individually named in
  the historical roster. The documented target is 16 historical keys, but
  the wildcard does not identify the exact BRT membership; do not infer which
  candidates belong to that target. The maintainer must provide or approve
  the exact historical `function_run` roster before an exact-key anti-join.
  This is an operation-level source manifest only, not a full dataset/design/
  replicate key inventory, result validation, or post-fix artifact receipt.
  TODO-7 remains open.

  **Expanded full-grid source preflight, 2026-10-20 (scratch only):**
  `/tmp/edi-todo23-source-attempt-full-key-manifest.csv` expands the 18
  current operation candidates over the runner's current default source grid:
  9 survival datasets, `beta_T` 0 and 0.5, default `Nrep=40`, seven tested
  designs, and the `~1`/`~.` design-formula paths. This yields 10,080 case
  dimensions and 181,440 unique candidate full keys, including the formula
  suffix in `inference_class`. The generator and dimension/count report are
  `/tmp/edi-todo23-full-key-manifest.R` and
  `/tmp/edi-todo23-source-attempt-full-key-summary.txt`. A 16-operation roster
  on this same grid would conditionally yield 161,280 keys (20,160 fewer),
  but that is not a historical target: `Nrep=40` is only the current runner
  default, and the exact historical 16 function names and run dimensions are
  unresolved. No key-level anti-join or canonical CSV access/write was done;
  keep historical reconciliation and TODO-7 open until the exact historical
  roster and grid are supplied or approved.

  **Attempt-lifecycle overlap regression, 2026-10-21:** broadened the
  standalone TODO-23 pure-R reconciliation fixture with a key whose event
  sequence is `started, started, terminal`. The expected hand-counted state
  is one retry attempt, one unclosed/overlapping start, and one terminal/result
  pair; balanced terminal/result counts must not erase the overlap anomaly.
  The focused test
  `test-todo23-attempt-reconciliation-reference.R` passed all 38 expectations
  (`Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-todo23-attempt-reconciliation-reference.R", reporter = "summary")'`).
  This extends the existing test file and exercises an otherwise unasserted
  lifecycle branch; the bulk manifest already registers the test. The
  reconciliation helper is pure R and this test is not a fit or coverage
  calibration. It does not choose the historical 16-vs-18 operation/grid
  target or establish a provenance-pinned post-fix result artifact; TODO-7
  remains open. No canonical result was read or written.

**Pure-R reconciliation recheck, 2026-10-21:** reran the standalone
`test-todo23-attempt-reconciliation-reference.R` file with
`timeout 120s Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-todo23-attempt-reconciliation-reference.R")'`;
it exited 0 with 50 passes, 0 failures, warnings, or skips. The test sources
`R/package_tests/validate_todo23_attempt_reconciliation.R` directly and its
fixtures exercise missing/extra/duplicate full keys, completed retries,
unclosed/overlapping starts, orphan terminals, status/count mismatches, and
invalid event sequence IDs. Test SHA-256 is
`682fb06990de0ab8f1203470d6638d8fb1d2c5b202c24a3c2797f8fa354dc7e2`; validator
SHA-256 is
`8529ed5ff430755d7ea0457052864e544ff796a27bbc81c999163ad55171e03d`.
This is synthetic reconciliation-mechanics evidence only: no historical RMST
artifact was read, no fit/calibration ran, and no canonical result was
modified. The historical operation/grid choice, provenance-pinned current
artifact, coverage calibration, and stale-row reconciliation remain open.

**Retained-artifact provenance follow-up, 2026-10-21:** the bounded inventory
found only the existing source candidates and the one-replicate scratch pilot;
it adds no authenticated historical/current-source result cohort. The
18-operation candidate file
`/tmp/edi-todo23-source-attempt-operation-manifest.csv` has SHA-256
`0096afb20a18676b0e879aee122d931529fb542730fc447400d779d84104ba10`; its
comparison files are
`/tmp/edi-todo23-source-attempt-comparison.csv` (SHA-256
`35f771c6d354cbd20fb4362d80f3f02bd879639b26d9347b81e39a208cd0bcd7`) and
`.txt` (SHA-256
`86a6860c7508fac8e461a551de01928a8a211826f2702a389f510c3ed4389d5a`). The
18-operation full-grid candidate
`/tmp/edi-todo23-source-attempt-full-key-manifest.csv` contains 181,440 keys
(SHA-256 `99871ef30ab3ebd065edb527d5e9424d5dc08de6aeb4351d8dd8192b155b4a5b`);
its generator and summary are `/tmp/edi-todo23-full-key-manifest.R` and
`/tmp/edi-todo23-source-attempt-full-key-summary.txt`. This is current-source
candidate scope only: its 9 datasets, beta `{0, 0.5}`, default 40 reps, seven
designs, and two formula labels do not establish the historical grid. The
16-operation/161,280-key count remains conditional, not an accepted roster.

The only empirical scratch output is
`/tmp/edi-todo23-rmst-pilot.0alSnq/comprehensive_tests_results_nc_1_survival_filtered_design-Bernoulli_class-InferenceSurvivalRestrictedMeanDiff_dataset-diamonds_beta-0_rep-1_family-wald.csv`
(four result rows; SHA-256
`7ae942b4e7073ce6b390ab27feb5285b7d0920d31ca443645e85eb99ef2e7c32`). It is
one `diamonds`/survival/Bernoulli/beta-0 replicate across `~1` and `~.` with
Wald p-value and CI rows, not a calibration cohort. Its `run.log` (SHA-256
`b68f7a92810821c9fb41fa7e04cfe9f74308c1a4b3eba2b354ce678bd7e89864`) reports
EDI 1.0.3 and completion; the CSV records checkout commit
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`. No matching attempt-event receipt
or provenance sidecar exists; neither artifact binds the installed R package
path/payload or loaded DLL hash. The canonical
`R/package_tests/comprehensive_tests_results_nc_1_survival.csv` is the
372,209,537-byte, 2026-09-27 pre-fix mixed artifact (18 recorded commits,
without a run sidecar); this pass used only its recorded metadata and did not
read or merge its payload. Exact reconciliation remains blocked on maintainer
approval of the 16 low-coverage operations versus all 18 current/raw-present
operations, an authoritative historical grid/attempt-status roster, and a
fresh isolated post-fix run with package/R/DLL provenance and attempt receipt.
No canonical artifact was read or changed; TODO-5 calibration and TODO-7
post-fix full-run reconciliation remain open.

**Pure-R validator contract recheck, 2026-10-21:** with no R/Rscript process
active beforehand and no compile/install, reran
`test-todo14-attempt-result-provenance-reference.R` (12 expectations) and
`test-todo23-attempt-reconciliation-reference.R` (50 expectations); both
completed cleanly. These synthetic tests exercise the generic receipt/result
provenance contract and TODO-23 exact-key/event-lifecycle reconciliation
mechanics. They do not attest a retained RMST run, resolve its 16-vs-18
operation/grid choice, validate current native provenance, or supply empirical
calibration evidence. The post-fix run and full reconciliation remain open.

**Artifact-independent source audit 2026-10-14:** exhaustive Graft searches
for `get_survival_stat_diff` and `get_restricted_mean_se_diff` found no
additional production callsites beyond RMST and the separate median-only
KM-difference path. The native RMST point-estimate branch takes the minimum
of the two observed arm maxima only when `requested_stat` is
`"restricted_mean"`; the native SE-difference path takes the same minimum
unconditionally. This narrows the remaining code-path risk, but cannot
substitute for TODO-3's targeted compile/runtime validation, TODO-5's
coverage calibration, or TODO-7's post-install regeneration.

## `InferenceSurvivalDepCensTransformRegr` — separate, narrower, unconfirmed finding

Surfaced by the same audit sweep, this class shows a narrow, isolated
undercoverage symptom — only
`compute_bayesian_bootstrap_confidence_interval_basic` (0.55 at n=202,
0.74 at n=124), while every other method family (`wald`, `asymp`,
`score`, `gradient`, `param_bootstrap`, `lik_ratio*`,
`rand_bootstrap*`) is near-nominal (0.91-1.00), including the plain and
`wald`-variant Bayesian-bootstrap CIs for the *same* class. Not the same
shape as the RMST finding above (narrow vs. broad), and not yet
root-caused: no `compute_bayesian_bootstrap_confidence_interval_basic`
override exists in `inference_survival_dep_cens_transform.R` (confirmed by
grep), so it resolves to shared Bayesian-bootstrap mixin machinery not yet
traced. The class's own file already documents a *different*,
previously-fixed crash bug in the sibling `compute_bootstrap_confidence_interval_basic`/
`_bca` methods ("never-implemented `_basic`/`_bca` name variants always
threw `attempt to apply non-function`," `:179-191`) — worth checking
whether the Bayesian-bootstrap `_basic` variant has an analogous, still-
unfixed dispatch gap; that's the concrete next step, not yet done.

**Cross-validation, 2026-09-24**: a fresh full-package audit run
surfaced 4 findings for this class (not yet the full picture, more
`function_run`s than the single `_basic` one above): `compute_bayesian_bootstrap_confidence_interval_wald`
OVER-coverage (1.000 at n=124, 0.995 at n=202), plain
`compute_bayesian_bootstrap_confidence_interval` UNDER-coverage (0.832 at
n=202 — this may be the same signal as the `_basic` finding above,
different variant), and `compute_rand_bootstrap_confidence_interval_smoothed`
OVER-coverage (1.000 at n=137). The mix of both directions (over AND
under, across different Bayesian-bootstrap CI-formula variants for the
SAME underlying estimate) argues against a single simple explanation and
for something variant-specific in how each CI formula reads the shared
bootstrap distribution — consistent with, but not proof of, the
suspected `_basic`-style dispatch-gap hypothesis above. Not further
investigated this pass; the RMST fix (TODO-1..7 above) is unrelated to
this class (`DepCensTransformRegr` doesn't use RMST) and should proceed
independently.

- [x] TODO-8 (2026-09-24, done — refuted as originally framed): Traced the
  dispatch. `compute_bayesian_bootstrap_confidence_interval()`
  (`inference_all_abstract_bayesian_bootstrap.R:404-489`) is a **single
  shared method** dispatching internally on a `type=` parameter
  (`"percentile"`/`"basic"`/`"wald"`/`"studentized"`/`"bca"`), not a set
  of separately-named `_basic`/`_wald`/etc. methods — unlike the plain
  (non-Bayesian) bootstrap family, where `_basic`/`_bca` really were
  distinct, previously-unimplemented method names. So there is no
  analogous "missing method" dispatch gap to find here; the `_basic`
  suffix in `comprehensive_tests.R`'s `function_run` naming is the
  harness's own convention for `type="basic"`, not a real second method.
  The `"basic"` type falls through to the generic
  `ci_from_boot_distribution()` (`inference_all_abstract_non_param_boot.R:1700-1705`)
  → `bootstrap_ci_from_distribution()` — **the same shared `"basic"`
  CI-formula helper already confirmed defective for HL-ties-at-zero data
  in `simple_wilcox_hl_degenerate_pval_boundary.md`'s `TODO-1`**. This
  class has no HL-tie mechanism (it's a survival transform-regression
  estimator, not a rank-based one), so that specific tie-driven defect
  doesn't directly transfer — but it raises the real possibility that
  `bootstrap_ci_from_distribution()`'s `"basic"` formula has a broader,
  non-tie-specific defect that both classes are independently exposing.
  Not confirmed either way for this class.
- [x] TODO-9 (2026-09-24, done — refuted): read
  `bootstrap_ci_from_distribution()` (`helper_bootstrap_ci.R:5-22`) in
  full. **No code-level defect** — the `"basic"` branch
  (`2 * est - stats::quantile(boot_distr, probs = c(1 - alpha/2,
  alpha/2), type = 8)`) matches the textbook basic/reflection-bootstrap
  formula exactly: quantile probs are ordered `(1-alpha/2, alpha/2)`
  (high then low), so `2*est` minus each, in that order, yields
  `(lower, upper)` correctly. No swapped order, no off-by-one, `type = 8`
  (a defensible, commonly-recommended quantile type) is used
  consistently. Does **not** explain the Wilcox/MeanDiffPooledVar
  findings — this rules out a shared-formula bug as their common cause;
  those remain explained by their own already-confirmed, independent
  mechanisms (`TODO-1`/`TODO-2` in `simple_wilcox_hl_degenerate_pval_boundary.md`).
  **Correction to this file's own "Cross-validation" note above**: the
  plain, unsuffixed `compute_bayesian_bootstrap_confidence_interval`
  function_run does **not** call `type="basic"` — traced its dispatch
  (`inference_all_abstract_bayesian_bootstrap.R:404-489`,
  `type = tolower(type %||% "percentile")`) and its harness call site
  (`comprehensive_tests.R:2698`, no `type=` argument passed) — it
  defaults to `type="percentile"`, a *different* CI-formula branch
  entirely (raw `quantile(boot_distr, probs=c(alpha/2, 1-alpha/2))`, no
  reflection). So the fresh audit's 0.832-under-coverage finding for the
  plain function_run is on the **percentile** method, not `"basic"` —
  update any downstream reasoning accordingly; only the harness's
  explicit `_basic`-suffixed `function_run` (`bayes_ci_type="basic"` at
  `comprehensive_tests.R:2700-2701`, a separate historical-baseline entry
  at 0.55/0.74 coverage, not re-confirmed this pass) actually exercises
  the `"basic"` branch.
  **Static source/estimand audit (2026-10-18; narrows the prior
  hypothesis):** dispatch and formulas do not show a missing-method or
  interval-order defect. The original point estimate is the treatment
  log-time ratio from the joint bivariate log-normal dependent-censoring
  likelihood, while `compute_estimate_with_bootstrap_weights()` explicitly
  uses `weighted_cox_bootstrap_surrogate_fit()` as an approximation to the
  weighted joint likelihood. The shared Bayesian-bootstrap CI then combines
  that surrogate draw distribution with the original joint-likelihood
  estimate (for `"basic"`; `"percentile"` uses the raw surrogate quantiles).
  This intentional estimator mismatch is a concrete alternative to the
  earlier unmeasured-skew explanation; neither it nor skew has been shown to
  cause the observed coverage. The old
  `/tmp/edi-v105-r6-benchmark.eQ0PpT/R/package_tests/comprehensive_tests_results_nc_1_survival.csv`
  full survival CSV is not validating evidence for the historical finding: its
  relevant `compute_bayesian_bootstrap_confidence_interval_basic` row is one
  replicate (`rep=1`), marked `numeric_instability`, under commit
  `5d8246300ea034bed7f4591d7f2258a7215436eb`, rather than the retained
  per-seed coverage/bootstrap draws needed to reproduce the 0.55/0.74 rates.
  Do not close this as accepted behavior or add a numerical regression based
  on that summary alone. A useful next investigation needs the original
  response/design/DGP and seed-level estimates plus the corresponding
  weighted-Cox bootstrap draws and usable-fit counts; comparing those with a
  full weighted joint-likelihood reference would separate surrogate error
  from bootstrap-shape effects. No statistical threshold is set here, and
  no calibration run or source behavior change was made.

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only for R-layer checks, and
only a targeted compile of touched `.cpp` files (never a full build) once
the C++ fix (TODO-2/3) is implemented. Unlike most of this session's other
fixes, TODO-2 is an intentional, documented default change to the point
estimate for classes whose arms have mismatched follow-up — this is
restoring a well-defined estimand, not introducing a new opt-in switch,
but it is NOT expected to be bit-for-bit-preserving the way this
session's other fixes were, and that distinction should be called out
explicitly wherever this fix is described.
