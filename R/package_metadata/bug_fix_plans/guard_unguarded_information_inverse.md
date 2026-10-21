# Guard the Unguarded Information-Matrix Inverses (NegBin, ZINB, ZAP, Beta)

> **Release:** v1.0.5 (`../future_release_plans/release_v1_0_5.md → TODO-4`,
> moved 2026-09-23 from `release_v1_1_0.md → TODO-17q`, bug-fix/feature
> split; 2026-08-30, user decision). Correctness / hardening, not performance:
> five `with_var` kernels invert the free-parameter information matrix with a
> bare `.inverse()` and no invertibility check, while their siblings (Cox,
> ordinal, ZOIB) check `FullPivLU::isInvertible()` and return a `NaN`
> covariance otherwise. No Phase 0 dependency. **Bit-for-bit on every fit
> whose information matrix is invertible** (see "Equivalence"); only the
> singular case changes, from garbage to `NaN`.

Date: 2026-08-30

## The finding

`fast_negbin_regression_with_var_cpp` (`src/fast_negbin_regression.cpp:485`):

```cpp
Eigen::MatrixXd H_free = subset_matrix(res.XtWX, information_spec.free_idx, information_spec.free_idx);
Eigen::MatrixXd cov_free = H_free.inverse();
Eigen::MatrixXd vcov = expand_free_covariance(X.cols() + 1, information_spec, cov_free, true);
```

Its own roxygen (`:411-418`) says so: "inverted via a plain matrix inverse …
A rank-deficient or near-singular design … will therefore produce
numerically unstable or `NaN` variances rather than a graceful fallback."
Known, documented — and inconsistent with the rest of `src/`. The same bare
pattern appears at:

| site | kernel |
| --- | --- |
| `fast_negbin_regression.cpp:485` | `fast_negbin_regression_with_var_cpp` |
| `fast_zinb.cpp:457` | ZINB `with_var` |
| `fast_zero_augmented_poisson.cpp:340` | ZAP `with_var` (first variant) |
| `fast_zero_augmented_poisson.cpp:566` | ZAP `with_var` (second variant) |
| `fast_beta_regression.cpp:643` | `fast_beta_regression_with_var_cpp` (roxygen `:576` carries the same caveat) |

The guarded siblings — the pattern to adopt — are
`fast_coxph_regression.cpp:391-399` (and `:498`),
`fast_ordinal_regression.cpp:236-244` (and `:559`), and
`fast_zero_one_inflated_beta.cpp:618-627`, which additionally checks
`observed_information.allFinite()` before factoring.

**Why it matters.** On an exactly singular `H_free`, Eigen's `.inverse()`
divides by a zero pivot and the result is `Inf`/`NaN` — noisy but at least
visibly wrong. On a *near*-singular `H_free` (a covariate almost collinear
with the intercept, a dispersion parameter at the Poisson boundary that
`negbin_information_spec` did not catch, a beta-regression `phi` diverging)
it returns a **finite** matrix of enormous, meaningless entries, and the R
side then reports a finite, wildly wrong standard error with no warning.
The R consumers (`inference_count_negbin.R:458`, `:507`) do
`res$vcov %||% solve(hess)` — `%||%` treats a non-`NULL` matrix as valid, so
neither `NaN` nor garbage triggers the fallback; a `NaN` at least propagates
to `NA` in `ssq_b_2` and the SE, which is what the Cox precedent produces
and what `harden = TRUE` paths expect.

## The fix

One shared helper in `_helper_functions_core.h`, next to
`expand_free_covariance()` (`:595`):

```cpp
// Invert the free-parameter information block; NaN-filled on singular input.
// Uses .inverse() for the value (bit-for-bit with the pre-existing behaviour
// on invertible input) and FullPivLU only for the invertibility decision.
inline Eigen::MatrixXd invert_free_information(const Eigen::MatrixXd& H_free) {
    const int k = H_free.rows();
    if (k == 0) return Eigen::MatrixXd(0, 0);
    if (!H_free.allFinite()) return Eigen::MatrixXd::Constant(k, k, NaN);
    Eigen::FullPivLU<Eigen::MatrixXd> lu(H_free);
    if (!lu.isInvertible()) return Eigen::MatrixXd::Constant(k, k, NaN);
    return H_free.inverse();
}
```

and each of the five sites becomes
`Eigen::MatrixXd cov_free = invert_free_information(H_free);`. The
`expand_free_covariance(…, cov_free, true)` call after it already handles
a `NaN` block (it copies entries; fixed parameters get the usual fill).

`FullPivLU::isInvertible()` uses Eigen's default threshold
(`ε · max(rows, cols)` relative to the largest pivot), the same one the Cox
and ordinal sites rely on today, so the five kernels become consistent with
those rather than introducing a new tolerance. The extra factorisation is
one O(p³) at p ≤ 20 per *observed-data* fit (the `with_var` kernels are not
the bootstrap-replicate hot path, which uses `estimate_only`), i.e.
negligible.

## Equivalence

- **Invertible `H_free` (every existing passing fixture):** the returned
  `vcov` is computed by the identical `H_free.inverse()` call as before —
  **bit-for-bit**. This is why the helper does *not* return
  `lu.inverse()` (full-pivot LU differs from `.inverse()`'s partial-pivot
  LU at the ulp and would move every SE in the package by ~1e-16, which
  the v1.1.0 additive constraint forbids without a documented reason).
- **Singular / non-finite `H_free`:** was `Inf`/`NaN`/garbage, becomes an
  all-`NaN` block → `NA` SE on the R side. Documented default change; the
  roxygen caveats at `fast_negbin_regression.cpp:411-418` and
  `fast_beta_regression.cpp:576` are rewritten to describe the guard.

## Items

- [x] **TODO-1: Helper.** `invert_free_information()` in
  `_helper_functions_core.h` (Rcpp-free, `EDI_CORE_ONLY`-compatible; use
  `std::numeric_limits<double>::quiet_NaN()`, not `NA_REAL`, since the
  header is shared with the Python core).
- [x] **TODO-2: Apply at the five sites.** Source edits were complete and
  the user's 2026-10-14 EDI reinstall has now supplied the native rebuild:
  `test-information-inverse-guard.R` exercises the rebuilt kernels and
  observes the new `information_invertible` results. No compile/install was
  run by Codex. Optionally refactor the four already-
  guarded sites to call the same helper **only if** they currently use
  `lu.inverse()` and the maintainer accepts the ulp-level change there;
  otherwise leave them (recommended for 1.1.0: leave them; note it as a
  1.2.0 tidy-up).
- [x] **TODO-3: Tests.** `test-information-inverse-guard.R` and the linked
  information-matrix reference tests passed on 2026-10-14 against the user's
  reinstalled package: 30 guard assertions, 48 extraction/fallback
  assertions, and 4 solve-cascade assertions; no compile/install was run by
  Codex. The end-to-end NegBin regression injects the duplicated candidate
  column through the private design-matrix cache and checks typed
  `model_standard_error_unavailable` plus NA CI. Two focused files passed
  against the installed native library: `test-information-inverse-edge-cases.R`
  (11 assertions: Poisson-boundary-excluded `k = 0` information block,
  non-finite information after an overflowing warm start, and a finite-input
  fixture whose Fisher-information matrix contains a literal `Inf`) and
  `test-information-inverse-inference-typed-guards.R` (30 assertions with the
  checkout's R class source-overlaid on installed EDI v1.0.3; typed SE/CI
  coverage for Beta, ZIP, Hurdle-Poisson, and ZINB). The native
  duplicate-column kernel cases also cover NegBin, Beta, ZAP, and ZINB.
  **Resolved 2026-10-14:** added a finite-input NegBin fixture with
  `X = cbind(1, rep(1e200, 80))` and moderate warm-start coefficients. The
  installed kernel reports a literal `Inf` in the information matrix,
  `information_invertible = FALSE`, and an all-`NaN` covariance; the edge-case
  test now asserts each condition and passes 11 assertions against installed
  EDI v1.0.3. The before/after bit-identical sweep remains the only open
  requirement under this checklist item. The Poisson
  boundary and `k = 0` requirements are now exercised through the public
  NegBin kernel API; the latter reports `information_invertible = TRUE` and
  the expected all-NA fixed/boundary covariance fill.
  **Installed-native focused recheck, 2026-10-20:** against installed EDI
  1.0.3 at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, with
  `EDI.so` at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`
  (SHA-256 `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`),
  `test-compute-variance-from-information-matrix-cpp-to-solve-fallback-cascade-reference.R`
  passed 4 assertions, `test-information-matrix-extraction-order-and-variance-fallbacks-reference.R`
  passed 48, `test-information-inverse-guard.R` passed 33, and
  `test-information-inverse-edge-cases.R` passed 11 (96 total; no failures,
  warnings, or skips). These confirm the available installed binary's guard,
  extraction/fallback, and edge behavior; they do not replace the open
  provenance-pinned current-head before/after identity sweep. No build or
  install was run.
  **Independent affected-kernel reference checks, 2026-10-20:** against the
  same installed EDI 1.0.3 DLL, the Beta-regression `with_var` reference test
  passed 18 assertions, and the zero-augmented Poisson kernel/reference test
  passed 20 assertions with three upstream `pscl` deprecated-`.Names`
  warnings. These provide independent kernel/reference evidence for Beta and
  zero-augmented paths; they do not provide a pre-fix comparator or establish
  bit-identical output across every `with_var` fixture.
  **Fresh user-managed rebuild/reinstall guard recheck, 2026-10-20:**
  `test-information-inverse-guard.R` passed 33 assertions,
  `test-information-inverse-edge-cases.R` passed 11, the Beta `with_var`
  reference passed 18, and the zero-augmented Poisson kernel/reference passed
  20 (82 assertions total; 0 failures, 3 upstream `pscl` deprecation
  warnings) against installed EDI 1.0.3. Its `EDI.so` SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  byte-identical to checkout `R/EDI/src/EDI.so`; install `Built` time was
  `2026-10-20 07:40:04 UTC`. This validates the freshly installed guard and
  affected-kernel behavior only. No build/install was performed by the agent.
  **Recovered pre-guard artifact and focused identity probe, 2026-10-20:** a
  scratch snapshot of the parent of guard commit `288e6643` was loaded with
  `compile=FALSE` and an Oct-8 09:58 pre-guard candidate DLL (SHA-256
  `89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`). On
  identical seeded, well-conditioned `n=100` inputs, all common native result
  fields were `identical()` between that EDI 1.0.2 artifact and the installed
  EDI 1.0.3 DLL (SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`)
  for NegBin, Beta, zero-augmented Poisson, Hurdle Poisson, and ZINB. On the
  matched duplicated-column NegBin fixture, the candidate pre-guard DLL
  produced non-finite covariance entries including `+/-Inf`; the current DLL
  reported `information_invertible = FALSE` and all-`NaN` covariance. Probe
  script and RDS outputs are under `/tmp/edi-v105-todo4-preguard.Ocl0Mg/`.
  This verifies one invertible fixture per kernel branch plus the singular
  behavior; it does not establish identity across every `with_var` fixture.
  The full-fixture before/after `identical()` requirement remains open.
  **Expanded seeded identity matrix, 2026-10-20:** using the same pre-guard
  EDI 1.0.2 snapshot/candidate DLL (SHA-256
  `89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`) and
  installed EDI 1.0.3 DLL (SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`), a
  generated matrix covered 3 sample sizes (`n=50,100,200`) × 5 fixed seeds ×
  NegBin, Beta, zero-augmented Poisson, Hurdle Poisson, and ZINB (75 fits).
  Every current fit reported `information_invertible = TRUE`, and every common
  native result field was bit-identical before/after (75/75); the current-only
  `information_invertible` field was excluded from parity. Driver and RDS
  outputs are in `/tmp/edi-v105-todo4-preguard.Ocl0Mg/` (old SHA-256
  `51838dcdc92ef9cd87cd4fe87848ddeb32d1e2853409791811077a0aac29b711`, new
  SHA-256 `babe3f294b2043961ccf5cad43e06dbf9a07a8f14c5d39a25f5abd77308fee49`).
  This is broader generated-fit evidence, not yet an exhaustive comparison
  over every existing `with_var` fixture; TODO-3 remains open.
  **Existing-fixture native-call capture, 2026-10-20:** instrumented 15
  affected-kernel R test files under both artifacts (51 pre-guard and 57
  current calls). Of the 41 identical-argument pairs, all 30 current
  invertible fits had bit-identical common result fields. Eleven pairs were
  non-invertible: eight differed only in `vcov` (current all-NaN; five legacy
  results contained non-finite entries), and three were identical. Ten legacy
  and 16 current calls were unmatched because their arguments differed, so
  those are not parity evidence. Both runs used identical current checkout R
  sources loaded with compilation disabled, swapping only the pre-guard versus
  current native DLL. Captures and driver are in
  `/tmp/edi-v105-todo4-preguard.Ocl0Mg/` (old capture SHA-256
  `c7a680376498287063e8983559ac42990c28ce787a874ea9605729e4fb8a1868`, new
  `d296b7d4b8832fd4e1da5af3475c05862dfb8a032381ec140f272a9b83eb79fd`).
  TODO-3 remains open until the unmatched calls and all remaining existing
  `with_var` fixtures have a provenance-pinned same-input comparison.

**Current-checkout R/current-user-native focused guard recheck, 2026-10-21:**
after confirming `ps -C R -C Rscript` was empty and `/tmp` had 16 GiB free,
ran `test-information-inverse-guard.R` and
`test-information-inverse-edge-cases.R` after
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. They passed 33
and 11 expectations respectively (44 total; no failures reported). The
loaded namespace was `/home/kapelner/workspace/EDI/R/EDI`, EDI 1.0.3; the
temporary DLL `/tmp/Rtmp82cqLV/pkgload24f4a25e7/EDI.so` had MD5
`bfea6f47ab8b27618d5d8633e9021f91` and SHA-256
`0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`,
matching both checkout `R/EDI/src/EDI.so` and the installed library's
`EDI.so`. This exercises checkout R definitions over the latest user-built
native artifact without compiling. It rechecks guard, zero-dimensional and
non-finite/literal-Inf behavior, but does not close the remaining provenance-
pinned before/after identity inventory for every successful `with_var`
fixture/caller, Python parity, or Bartlett per-replicate diagnostics. TODO-4
remains open; no canonical outputs were written.
  **Installed-package focused guard recheck, 2026-10-21:**
  `timeout 180s Rscript -e 'library(EDI); ...; testthat::test_file("R/EDI/tests/testthat/test-information-inverse-guard.R", reporter = "summary")'`
  passed 33 expectations (0 failures, warnings, or skips) against installed
  EDI 1.0.3 from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Loaded `EDI.so`
  SHA-256 was
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`
  (MD5 `bfea6f47ab8b27618d5d8633e9021f91`). This confirms only the tested
  installed artifact; it does not prove installed R-source/build identity or
  close the provenance-pinned same-input `with_var` inventory, Python parity,
  or Bartlett replicate-diagnostic gates. No build/install or canonical
  output occurred.
- [x] **TODO-4: Roxygen.** Replace the "will produce numerically unstable or
  NaN variances" caveats at `fast_negbin_regression.cpp:411-418` and
  `fast_beta_regression.cpp:576` with a sentence describing the guard
  (`NaN` covariance when the free information block is singular; check
  `is.finite(vcov)`); add the same sentence to the ZINB/ZAP `with_var`
  docs. Per `fix_documentation.md` conventions, `parse()`-check only, no
  interim `roxygenize` (memory `feedback_no_interim_roxygenize`).
- [x] **TODO-5: Audit sweep.** `grep -n "\.inverse()" src/*.cpp src/*.h`
  today lists the five sites above plus: `atkinson_assign.cpp:49` and
  `generate_permutations.cpp:107` (both `lu.inverse()` after a
  `FullPivLU` — check they test `isInvertible()` first; if not, they are
  design-side sites for the same guard), and `fast_gamma_functions.h:98`
  (an elementwise array reciprocal, not a matrix inverse — fine). Record
  the disposition of each in this file.
- [x] **TODO-6: Confirm and standardize the rejection reason names.** Before
  implementing TODO-2, list, for each of the five classes
  (`InferenceCountNegBin`, `InferenceCountZeroInflatedNegBin`,
  `InferenceCountZeroInflatedPoisson`/`Hurdle*` via the zero-augmented
  abstract, `InferencePropBetaRegr`), the `cache_nonestimable_se()` reason its
  R wrapper would use when the helper reports a non-invertible block, and
  confirm it follows the existing `<class-prefix>_standard_error_unavailable`
  convention (default `standard_error_unavailable`; Beta uses
  `model_standard_error_unavailable`). Record the chosen string per class
  here, make the helper return an invertible/not status alongside the `NaN`
  inverse, and have TODO-3's tests assert the reason string, not just `NA`.
  See "Diagnostics coordination" below for the reasoning.
  **Checked 2026-09-24 (R wrappers as they stand):** no consistent
  "singular information" reason exists for these five classes today.
  `InferenceCountHurdleNegBin`/`Poisson` (`inference_count_hurdle.R:135`) and
  `InferencePropBetaRegr` (`inference_proportion_beta.R:169`) already use
  `model_standard_error_unavailable`; `InferenceCountNegBin` sets only
  `negbin_jackknife_not_supported`; the zero-augmented abstract sets only the
  estimate-stage `zero_augmented_poisson_design_unusable`
  (`inference_count_zero_augmented_poisson_abstract.R:133`), and its SE path
  (line 334) calls `compute_standard_error_from_information_matrix()` without a
  wrapper-level reason; `inference_count_zero_inflated.R` sets none. So the
  earlier "`<prefix>_standard_error_unavailable`" wording overstated the
  convention. **Recommendation:** use `model_standard_error_unavailable` for
  all five (two of them already do), via the shared
  `cache_nonestimable_se()`, rather than five class-specific strings; TODO-6 is
  complete when that is decided and recorded per class here.

## Diagnostics coordination (2026-09-24, user decision)

A rejected (singular) information block must be reported through the
existing typed `cache_nonestimable_estimate()`/`cache_nonestimable_se()`
reason strings (the existing `<class-prefix>_standard_error_unavailable`
convention; see the convention paragraph below), not a new ad-hoc flag. This is what lets the
v1.1.0 `SolverDiagnostics` component
(`../new_feature_plans/optimizer_diagnostics_report.md → TODO-3`) and the
public diagnostics API's `information_condition_number` /
ill-conditioned-information warnings
(`../new_feature_plans/public_diagnostics_api_spec.md`) absorb these
rejections later without migrating them. TODO-2 and TODO-3 above must
include this: the tests assert the reason string, not just `NA`. The
diagnostics chain itself is out of scope here.

**Reason-name convention, checked 2026-09-24 (supersedes the earlier
`information_singular` suggestion, which matches nothing in the code):**
- The C++ kernels that already guard (Cox, ordinal, ZOIB, stereotype) signal
  a singular information block only by returning a `NaN` covariance; none
  sets a reason in C++. The reason is assigned R-side.
- R-side reasons are `cache_nonestimable_se(reason)` strings
  (`inference_all_abstract.R:815`, default `"standard_error_unavailable"`),
  named `<class-prefix>_standard_error_unavailable` where a class sets one
  (`ppor_`, `kk_clmm_`, `cmh_`, `strat_cox_`, `extended_robins_`; the Beta
  class uses `model_standard_error_unavailable`, `inference_proportion_beta.R:169`).
  No shared "singular information" reason exists anywhere today.
- Therefore TODO-2 should not invent a new global taxonomy: when the helper
  returns `NaN`, the R wrapper for each of the five classes caches SE
  nonestimability with `<prefix>_standard_error_unavailable` (default
  string if the class has no prefix convention). Any finer
  "singular vs. other" distinction is the v1.1.0 `SolverDiagnostics`
  taxonomy's job, which reads the `NaN` + the new `invert_free_information()`
  status; so the helper should also expose a status flag (invertible /
  not) alongside the inverse, not just `NaN`.

## Explicitly out of scope

- A rank-aware pseudo-inverse (what `fast_adjacent_category_logit_with_var_cpp`
  does, per the negbin roxygen). That changes *values* on rank-deficient
  designs rather than flagging them; the package's hardening philosophy
  (`fit_with_hardened_qr_column_dropping`) is to drop columns on the R side
  and treat a singular free block in C++ as non-estimable. Keep it that way.
- Surfacing `min_eigenvalue_information` (already returned by negbin) as a
  near-singularity warning on the R side — worth doing, separate plan.

## Implementation record (2026-10-08)

- `invert_free_information()` now lives beside `expand_free_covariance()` in
  `_helper_functions_core.h`. It treats the zero-dimensional all-fixed block as
  invertible, rejects non-square/non-finite input, uses
  `FullPivLU::isInvertible()` only for the decision, and retains the original
  `.inverse()` calculation for accepted matrices. Its `bool&` result is exposed
  as `information_invertible` by each migrated kernel.
- The five former bare sites now use the helper: NegBin, portable ZINB,
  portable ZAP, R-facing ZAP, and Beta. The R-facing ZINB wrapper had meanwhile
  moved to `covariance_from_information()`; it now uses the same helper as an
  accept/reject gate while preserving that wrapper's existing covariance value
  on accepted fits. This closes the class-level singular-information behavior
  without changing invertible fits on that evolved path.
- The full `.inverse()` sweep leaves the helper's intentional accepted-input
  `.inverse()`; two Cox, two ordinal, and one ZOIB covariance sites already
  gated by `FullPivLU::isInvertible()`; `atkinson_assign.cpp` and
  `generate_permutations.cpp`, also already gated by that check; and
  `fast_gamma_functions.h`'s elementwise array reciprocal. All guarded sites
  remain unchanged to preserve their existing numerical paths.
- All affected R inference families use
  `model_standard_error_unavailable`: NegBin and Beta through
  `InferenceAsympLikStdModCache`; ZINB, ZIP, and hurdle-Poisson through their
  concrete `compute_estimate()` guards. Kernel status is retained on the R
  model objects for later diagnostics.
- `test-information-inverse-guard.R` statically verifies the helper, all five
  migrations, the audit dispositions, and the typed rejection strings. Its
  native duplicate-column cases cover NegBin, Beta, ZAP, and ZINB; the user's
  installed native library was exercised in the 2026-10-14 focused runs above.
  The focused inference-guard tests additionally exercise typed SE
  nonestimability through Beta, ZIP, Hurdle-Poisson, and ZINB classes. The
  ZINB regression uses an exact duplicate conditional covariate and confirms
  the finite point estimate is retained while the SE is typed as unavailable;
  its public CI preserves the bootstrap fallback warning and NA endpoints.
  The typed-guard file passed 30 assertions with the checkout's R class
  source-overlaid on installed EDI v1.0.3 (installed native kernels; no
  compile/install). A plain installed-namespace run cannot exercise the new
  ZINB R override until the maintainer's independent reinstall. Python
  duplicate-column coverage was added for
  the portable ZINB and both ZAP variants. Source-loaded validation with
  `compile = FALSE` passed 18 assertions; the rebuilt-native block skipped as
  designed. R/Python parse checks and `git diff --check` passed. Per the repo's
  compilation rule, native compilation and rebuilt-kernel execution remain for
  the maintainer's next independent build. Full closure still needs the
  before/after `identical()` sweep for all `with_var` fixtures. The separate
  literal-Inf fixture described above passes against the installed binary;
  that binary reports a Sep 20 native build, so it does not verify this
  checkout's native changes.

**Compile-free acceptance audit 2026-10-16:** the existing cross-family
`with_var` reference test compares `ssq_b_j` and covariance to
`solve(fisher_information)` and GLM values with numerical tolerances (up to
`1e-3`); it is an independent accuracy check, not a before/after identity
comparison. The guard regression also source-checks that accepted inputs still
execute `information.inverse()`, but that does not establish bit-for-bit output
parity for the five migrated kernels. The installed native binary noted above
predates the source migration. Therefore no available compile-free fixture
closes the remaining parity gate. The smallest valid next step remains a
provenance-stamped same-input comparison of each affected `with_var` result
before and after the source change, asserting `identical()` for
accepted/invertible fixtures; do not substitute the tolerant Fisher/GLM
reference assertions or alter the acceptance criterion.

**Current-head CI execution evidence 2026-10-16:** HEAD
`430c19bcdb0702d998c79f9058c449449034134c` passed the R coverage workflow
([run 38808821546](https://github.com/kapelner/EDI/actions/runs/38808821546));
the same-commit coverage manifest assigns all three files below to the
coverage tier, and the run completed all shards and merge successfully:

- `R/EDI/tests/testthat/test-information-inverse-guard.R` — five-site source
  assertion and native duplicate-column guard fixtures;
- `R/EDI/tests/testthat/test-information-inverse-edge-cases.R`;
- `R/EDI/tests/testthat/test-information-inverse-inference-typed-guards.R` —
  typed R-side SE/CI rejection behavior.

The same SHA's successful Python coverage job ([run 38808821508](https://github.com/kapelner/EDI/actions/runs/38808821508))
also ran the portable duplicate-column cases in
`python/tests/test_fast_zinb.py` and
`python/tests/test_fast_zero_augmented_poisson.py` (including the two
zero-augmented variants). This establishes execution of the checked-in
guard/typed regressions at that commit; it does **not** close the separate
before/after `identical()` parity sweep above. The worktree's later dirty
warm-start dimension checks in `R/EDI/src/fast_negbin_regression.cpp` and
`R/EDI/src/fast_zinb.cpp` are not in this CI commit and are excluded from this
evidence. No change to the parity acceptance criterion or TODO status follows
from these CI runs.

**Parity-artifact audit 2026-10-16:** no tracked pre-guard baseline or stored
before/after `identical()` values were found for the duplicate-column SE/CI
fixtures. Those fixtures record only post-guard outcomes; the successful
post-guard CI runs above establish execution, not a before/after comparison.
The required accepted/invertible `with_var` parity gate therefore remains
open.

**TODO-3 fixture-union replay, 2026-10-20 (not exhaustive):** the earlier
parity-artifact audits are superseded by a provenance-pinned replay using the
recovered pre-guard DLL
(SHA-256 `89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`)
and current installed/check-out DLL (SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`). Both
artifacts were loaded under identical current checkout R sources with
`pkgload::load_all(..., compile = FALSE)`. Twenty affected-kernel R test files
produced 638 pre-guard and 644 current calls; their union yielded 567 unique
exact argument fixtures, each replayed against both DLLs with zero call
errors. All 436 currently invertible fits had bit-identical common native
result fields. Of 131 singular/non-invertible fits, 72 changed only `vcov` to
all-NaN (18 legacy covariances contained non-finite values); all other common
fields were identical, and the remaining 59 cases were wholly identical.
The current source-loaded test run passed 1,229 assertions (0 failures,
16 upstream warnings, 2 skips); the pre-guard run's seven failures were the
expected typed-rejection assertions for singular information. Manifest and
before/after outputs are in `/tmp/edi-v105-todo4-preguard.Ocl0Mg/` (manifest
SHA-256 `84c3ff1c657f5a9cbb99f8ae6211d0bf3a4b34df0b17dd9113f324906a99a9c0`,
old outputs `8d0b665b929d1100517a31e2ed74e6cb27c0e6b45a2d7622eafbb76e7e17f811`,
current outputs `fea3a768182d559cd2a9646a34e6150134ea592d31249fd1cefcebb5f432dfe5`).
This covers the captured fixture union, but not every existing `with_var`
fixture by itself: the 20-file capture omitted the pre-existing
`R/EDI/tests/testthat/test-zinb-operator-workspace.R` variance-path fixture.
The omitted fixture was replayed separately as recorded below. No build or
install was performed.

**Omitted-fixture follow-up, 2026-10-20:** the omitted test file's
deterministic variance-path case uses `make_zinb_workspace_data(seed =
11001L, n = 180L)`, obtains a warm-start fit with `estimate_only = TRUE`,
then calls `fast_zinb_cpp(..., warm_start_params = fit0$params, maxit = 150L,
..., estimate_only = FALSE)`. Its seven assertions cover repeatability,
convergence, finite score, Hessian symmetry, and finite covariance diagonal.
`testthat::test_file("R/EDI/tests/testthat/test-zinb-operator-workspace.R",
reporter = "summary")` passed all 7 expectations against installed EDI 1.0.3
at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded `EDI.so`
was `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`,
SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
(matching checkout `R/EDI/src/EDI.so`). This is current-artifact test
evidence. Its provenance-pinned pre/post replay is recorded next. The two
package copies were made from the same current
checkout source at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; their R-source
trees were identical (SHA-256 of the sorted `.R`-file hash manifest
`1adba6bbd477f63760d4d0ee7e1d2b9d805149829fe7aad9edc1e1e0f8046635`) and the
test file SHA-256 was `d59d48461b5ff78d91a05f9bf24414d60dbc319743da4ee109ec1e272ce5528e`.
Only `src/EDI.so` differed: pre-guard `89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`
versus current `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
With `pkgload::load_all(..., compile = FALSE)`, the test passed all 7
expectations under each DLL. The estimate-only warm-start parameter vectors
were bit-identical, and every common field in the subsequent
`estimate_only = FALSE` result was `identical()`, including score, information,
Hessian, coefficients, and `vcov`; the current-only `information_invertible`
field was not part of the common-field comparison. The separate outputs are
preserved under `/tmp/edi-todo4-zinb-replay.EZqzty/` (`pre-guard-result.rds`
SHA-256 `60afd6971a83230ebb815d9a025f9f91b2bddf50c9f355d83c834465f50f3186`,
`current-result.rds` SHA-256
`694c9f55c43eaf5887372f084c64582e67b1bb3b47616c58ca69af2133174c81`). This
closes the specifically identified omitted-fixture replay gap. The original
20-file capture remains a 567-fixture artifact and was not edited; describe
the combined evidence as that capture plus this separately replayed fixture,
not as a 21-file capture. No build or install was performed.

**Capture-manifest/inventory audit, 2026-10-20 (exhaustiveness still open):**
the saved `fixture-union-manifest.rds` (SHA-256
`84c3ff1c657f5a9cbb99f8ae6211d0bf3a4b34df0b17dd9113f324906a99a9c0`)
contains exactly the unique argument signatures in the old/new raw captures;
the per-kernel old/new union and manifest sets match exactly, and the manifest
has no duplicate signatures. It correctly coalesced repeated raw calls:

| Kernel | Old calls / unique | Current calls / unique | Union unique = manifest |
|---|---:|---:|---:|
| NegBin | 24 / 17 | 25 / 18 | 19 |
| Beta | 6 / 6 | 7 / 7 | 7 |
| Zero-augmented Poisson | 426 / 355 | 429 / 358 | 360 |
| ZINB | 182 / 173 | 183 / 175 | 181 |
| Total | 638 | 644 | 567 |

The inclusion logic is a hand-maintained `files <- c(...)` list in
`/tmp/edi-v105-todo4-preguard.Ocl0Mg/capture_existing_fixtures.R` (SHA-256
`593cc5d4c524bdc9e5be04f641dedd3b89f01aed85f6e5e111d8c581d72e430c`), not a
source-derived test inventory. A literal-call audit found two additional
successful ZINB variance-path fixtures absent from that list and without
pre-guard result records:

- `R/EDI/tests/testthat/test-zinb-poisson-boundary-score-length.R` fits the
  seed-1, `n = 30` Poisson-boundary case with `fixed_idx = 2L`,
  `fixed_values = 0`, and `estimate_only = FALSE`.
- `R/package_tests/testthat_bulk/test-zinb-kernel-warm-start-params-wrong-length-guard-reference.R`
  includes a successful correctly-sized warm start (`seed = 37`, `n = 150`,
  `warm_start_params = c(0.5, 0.3, -1, 0, log(3))`); its default is the full
  variance path.

The operator-workspace positive fixture above now has its separate
pre/post replay, but neither of these two successful fixtures is represented
in the saved old/new captures or the earlier standalone replay RDS files.
Other direct mentions in `test-kernel-warm-start-length-contracts.R` and
`test-mixed-kernel-warm-start-shape-guards-reference.R` exercise malformed
warm-start/Fisher-information rejection or diagnostic returns, not a
successful information-inversion result. This static audit does not establish
coverage of every indirect R6/class-level path that may reach these native
wrappers.

**Two additional ZINB fixture replays, 2026-10-20:** both tests were run
separately against two isolated package copies using
`pkgload::load_all(..., compile = FALSE)` and only their preserved native
DLLs; no compile/install was performed. The copies used identical current
checkout R sources at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`
(sorted `.R`-file manifest SHA-256
`1adba6bbd477f63760d4d0ee7e1d2b9d805149829fe7aad9edc1e1e0f8046635`), while
the recovered pre-guard DLL was SHA-256
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and the
current DLL was SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
`test-zinb-poisson-boundary-score-length.R` (source SHA-256
`716b3e660775bdbf211422ff2deca600f2ab5f46e8db6b79e6cef7b62dbaa6ac`) passed
15 assertions under each DLL. Across the direct boundary fit and the
class-mediated score-test path, it produced four successful
`fast_zinb_cpp` calls; exact-argument matching found all four counterparts.
For calls 1–2, every common result field was
`identical()`. For calls 3–4, every common field except `vcov` was
`identical()`; the pre-guard covariance included large finite entries and
NaNs, while the current covariance was all NaN. The current output added
`information_invertible`; in calls 3–4 it omitted the pre-guard-only
`covariance_type` field. `test-zinb-kernel-warm-start-params-wrong-length-guard-reference.R`
(source SHA-256
`64ee525860b27c94b8e48b9fb0cdea06a3dcb76110fe5a56fae3273eb126a2b0`) passed
7 assertions under each DLL; its successful correctly-sized full-variance
warm-start call had every common result field `identical()` (the current-only
`information_invertible` field was excluded). Captured outputs are preserved
under `/tmp/edi-todo4-zinb-twofixtures.OPBGoG/`; pre-guard RDS SHA-256
`656f215d5bcc44713dd6746aadcbe05e90b74619c121a4781c59c781c7b771fa`, current
RDS SHA-256
`7e96934d2e52eadb74a62804ac581e21fe8ba0272cc17e02c13cb254086fbfb9`.
These standalone replays close those two identified fixture replay gaps, but
do not change the original 20-file/567-fixture capture or establish that all
successful direct and indirect callers have been inventoried. The exhaustive
gate remains: derive that complete inventory and replay any newly uncovered
fixtures against both pinned DLLs under identical current R sources, then
reconcile common fields. No source or capture script was changed.

**Caller-inventory and omitted-fixture follow-up, 2026-10-20:** a fresh
source-derived call-graph audit started from every indexed
`invert_free_information` occurrence and followed the R wrapper/class callers.
The helper has six native call sites in the checkout: Beta and NegBin
`with_var`, portable ZAP and ZINB internal paths, and the R-facing ZAP and
ZINB paths. The four R-facing wrappers are the scope of the pinned R DLL
captures; the separate portable Python-core paths are not represented by an R
package DLL replay. R callers map to `InferencePropBetaRegr` and
`InferenceCountNegBin`, plus the shared
`ZeroAugmentedCountLikelihoodSource` (`generate_mod`, likelihood-spec null
fits, and null simulations); Beta also reaches the same kernel through the
KK21 and stepwise-KK21 weight helpers. `estimate_only = TRUE` routes are not
successful information-inversion fixtures.

**Source-derived dispatch classification, 2026-10-21 (read-only):** the six
call sites divide into four R-facing paths and two portable Python-core paths:
`fast_beta_regression_with_var_cpp` and `fast_neg_bin_with_var_cpp`;
`fast_zero_augmented_poisson_cpp` (shared by ZIP and hurdle-Poisson) and
`fast_zinb_cpp`; and Python's `fast_zap_with_var_internal` /
`fast_zinb_with_var_internal`, respectively. The Python bindings expose both
internal paths only through their `*_with_var` APIs, with no estimate-only
flag. The R ZAP and ZINB wrappers return from their `estimate_only = TRUE`
branches before the guard; malformed input or fit failures that exit before
information construction are error-only, not inversion fixtures. The separate
NegBin estimate-only and weighted kernels do not use this helper. A nuance is
that `fast_neg_bin_with_var_cpp(estimate_only = TRUE)` still reaches the helper
after its internal fit supplies a zero information block, so it is not a
successful positive-information parity fixture; Beta's separate
`fast_beta_regression_cpp` is its estimate-only route. The `compute_std_errs`
formal on the Beta `with_var` wrapper does not bypass its guarded inverse.

The test/replay map remains incomplete: the hand-maintained 20-file manifest
contains 638 pre-guard / 644 current calls and 567 unique exact fixtures;
later exact-input replays supplement it without making it source-exhaustive.
The two previously omitted successful ZINB fixtures have separate paired
replay records, but complete successful-call reconciliation for all four
R-facing paths is still open. Python's duplicate-column guard tests cover the
two portable paths' singular behavior, but no paired positive-fit
pre/post-guard replay is recorded for either binding. Selected Bartlett
initial fits and bounded resampling examples are recorded; full Bartlett
coverage and per-replicate diagnostic reconciliation remain open. This note
does not close TODO-4 or change its acceptance criterion.

**Captured-call reconciliation, 2026-10-21 (read-only; TODO-4 remains open):**
the full retained raw capture contains 638 pre-guard and 644 current
successful R-facing wrapper calls. Every captured argument list is represented
in the 567-input union fixture manifest, and both the pre-guard and current
replay manifests contain those same inputs:

| R-facing kernel | Pre-guard calls | Current calls | Union/replay inputs |
|---|---:|---:|---:|
| Negative Binomial | 24 | 25 | 19 |
| Beta regression | 6 | 7 | 7 |
| Zero-augmented Poisson (ZIP / hurdle-Poisson) | 426 | 429 | 360 |
| ZINB | 182 | 183 | 181 |
| Total | 638 | 644 | 567 |

Some independently rerun test files generate different random arguments, so
their raw pre-guard and current calls are not necessarily direct same-argument
pairs. The union capture includes both sides' observed inputs, however, and
each of those inputs is replayed against both DLLs. This establishes manifest
input pairing, not equality of numerical outputs; result-field reconciliation
remains a separate gate.

Remaining inventory gaps are: two test files in the literal-call audit have no
successful target-wrapper capture
(`test-information-matrix-extraction-order-and-variance-fallbacks-reference.R`
and `test-hurdle-negbin-poisson-boundary-rescue-acceptance-reference.R`); the
test-derived manifest is not an exhaustive inventory of indirect production,
benchmark, and profiler configurations; neither portable Python positive-fit
path has a paired pre/post replay; and full Bartlett per-replicate
fit/status/information diagnostics remain unreconciled. These gaps do not
invalidate the 567-input pairing, but prevent treating it as an exhaustive
successful-call inventory or closing TODO-4.

**Remaining successful caller groups and bounded next replay, 2026-10-21
(static source/artifact audit):** direct and public class-level test/replay
evidence covers many of the successful paths recorded elsewhere in this
plan, but the retained raw capture is not a source-call-site-complete
inventory. The following full-variance benchmark/profiler configurations are
concrete successful-call candidates whose exact inputs are not captured as
their own call records. The two test files named above are not additional
successful wrapper fixtures: one checks the separate information-matrix
extraction helper, while the other has only a commentary/reference hit for
the NegBin wrapper and no successful target call in the retained capture.

| Family | Successful R-facing caller path | Remaining production configuration |
|---|---|---|
| Beta | `InferencePropBetaRegr` / `fast_beta_regression_with_var`; the KK21 and stepwise-KK21 weight helpers also reach this wrapper. Existing direct, class, asymptotic, and selected bootstrap replays are recorded above. | `make_edi_wald_bm` in `R/benchmark/benchmark_model_fits.R` and `R/benchmark/benchmark_wald_tests.R`, plus the full-variance `get_kernel` entry in `R/profile/edi_kernel_profiler.R`. |
| NegBin | `InferenceCountNegBin` (`inference_count_negbin.R`, full-variance calls at the compute-estimate and likelihood-refit routes), and `fast_negbin_regression_with_var`. Existing direct/class and selected bootstrap/Bartlett replays are recorded above. | The same two `make_edi_wald_bm` callers and the full-variance profiler entry; the separate weighted and estimate-only benchmark kernels are outside the inverse guard. |
| ZIP / hurdle-Poisson | `ZeroAugmentedCountLikelihoodSource`: public estimate entry and full-variance likelihood/null-refit routes (`get_likelihood_test_spec`, `generate_mod`, and `simulate_under_lik_null`). The randomization-estimate method defaults to `estimate_only = TRUE` and is not an inversion fixture unless explicitly requested otherwise. Existing ZIP and hurdle class replays are recorded above. | The two Wald-benchmark callers and profiler's full-variance entries, separately for `is_hurdle = FALSE` and `TRUE`. The `make_edi_bm` estimate-only variants return before inversion. |
| ZINB | `ZeroAugmentedCountLikelihoodSource`: public estimate entry and full-variance likelihood/null-refit routes; the randomization-estimate method likewise defaults to `estimate_only = TRUE`. Existing ZINB class/direct and selected bootstrap/Bartlett replays are recorded above. | The two Wald-benchmark callers and profiler's full-variance entry. The `make_edi_bm` estimate-only variant returns before inversion. |

The bounded next comparison is a non-timed replay of the five full-variance
branches in `R/benchmark/benchmark_model_fits.R::make_edi_wald_bm`, using one
already-generated benchmark `d` object pinned once as exact `X_bm`, `y_bm`,
and response/design inputs: Beta, NegBin, ZIP, hurdle-Poisson, and ZINB. Capture
the exact arguments and native return for each call, then replay those same
arguments under the preserved pre-guard/current DLL pair with identical
current R sources. Do not invoke benchmark timing loops or regenerate canonical
rows. This directly checks the production benchmark call shapes without
confounding RNG history; it does not substitute for the remaining Python
positive-path parity or full Bartlett per-replicate diagnostics. Before
execution, confirm the benchmark fixture builder can provide one deterministic
`d` without running its timing harness; if not, preserve a single explicit
`d` and its transformed inputs as the replay fixture.
The ZAP/ZINB `generate_mod` and `simulate_under_lik_null` call sites are
exercised by selected class-level bootstrap replays, but their generated
per-replicate low-level calls are not yet a source-call-site-complete capture.

All package copies used for the following caller-inventory replays carried
the same current checkout R-source manifest SHA-256
`f35da9b53aefd38c29ea9d53cc2e4137fc6ea9e83a29ec266eff2b6c62044f7c`, with
only the preserved pre-guard DLL
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` versus
the current DLL
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` varying.

Comparing the indexed direct-call test-file hits and those indirect class
routes against the hand-maintained 20-file manifest identified additional
positive-path test containers. Beyond the already separately replayed ZINB
files, this follow-up replayed seven focused direct/helper/KK21 files
(`test-negbin-gemv-gradient.R`,
`test-fast-glm-direct-helper-reference.R`,
`test-argument-permutations.R`, and four KK21 weight-selection references),
three Beta-class files (`test-proportion-classes-estimates-and-intervals-match-betareg-quasibinomial-and-gcomp-references.R`,
`test-beta-regr-marginal-estimand-delta-method.R`, and
`test-beta-regr-marginal-estimand-fit-point-and-se-unavailable-branches-reference.R`),
and `test-negbin-jackknife-and-likelihood-spec-reference.R`. All 11 files
passed their 132 total assertions under each preserved DLL. Wrappers captured
26 successful calls (10 Beta and 3 NegBin helper/direct calls, 7 Beta-class
calls, and 6 NegBin-class calls). The current DLL was replayed on the exact
pre-guard argument objects; common fields were identical for all six NegBin
class calls and 16 of the first 20 calls. Four Beta degenerate/nonfinite
covariance outputs differed only in `vcov` and, for two calls, `std_errs`:
pre-guard outputs retained Inf/NaN mixtures while the guarded result was
all-NaN. The new `information_invertible` field is current-only and excluded
from common-field comparison. Nominal same-seed Beta/NegBin class reruns did
not always produce identical design matrices/outcomes, so those were not used
as parity pairs; exact captured pre-guard arguments were used instead.

**Next class-candidate replay, 2026-10-20:** Trail located the
`InferencePropBetaRegr` test in
`R/EDI/tests/testthat/test-mle-km-summary-table.R` (the file's other mock,
ordinal, survival, and zero/one-inflated tests do not call this Beta kernel).
The entire focused test file passed under both isolated copies loaded with
`pkgload::load_all(..., compile = FALSE)`, capturing one successful
`fast_beta_regression_with_var_cpp` call per DLL. Current source manifest SHA-256
was `f35da9b53aefd38c29ea9d53cc2e4137fc6ea9e83a29ec266eff2b6c62044f7c`; the
pre-guard/current DLL SHA-256 values were respectively
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. The
captured arguments were `identical()` and all 11 common result fields were
`identical()`; current-only `information_invertible` was excluded. Test source
SHA-256 is `af4cf56aa7160519fb11c0657ce90ae1bb39c2faed1d8cf12397fe8db1fb3a78`;
capture RDS SHA-256 values (pre-guard/current) are
`610d217928290087a5166fa8a2a56ef3ebdfc84f4c5a54bc0c21cf6254feee65` and
`1b871a53c5366ac8e8c0c607e6ab21f15de2eb8bb0951ec516bfdd1ed4b9d186`.
This adds one exact-input parity pair, without changing the original manifest.

**Focused asymptotic class replay, 2026-10-20:** the next source candidate,
`R/package_tests/testthat_bulk/test-asymp-inference-paths.R`, was reduced to
its two relevant `test_that` blocks (`NegBin Asymp paths` and `Beta Asymp
paths`) plus their shared path helper; unrelated model fits in that file were
not run. Each block passed 20 expectations under both DLLs. Each captured one
successful `with_var` call. The pre-guard Beta and NegBin argument objects
were separately replayed by the same seeded test blocks, and each exact
argument list matched the current-DLL counterpart; all 11 common result
fields were `identical()` for both families, excluding the current-only
`information_invertible`. Test source SHA-256 is
`a642d54fe74553468d8a34c7985d4b0866d6236853c849c1fc7e89be15d1692a`.
Captured RDS SHA-256 values are pre-guard Beta
`7d176f51be7f751718904704c861f88cfd2fda58ce434f6aa25380ce3f93b3f7`,
pre-guard NegBin
`8385888bddaa625d20cd14e78986ad542bf281147588c6062476e6209dc5478c`, and
current Beta+NegBin
`a6b4dfc0f256bc48c36968ca7d8db33660dab88bd54229b0d4ed2337831b094e`.
The exact selected test blocks, not the broad full file, are the evidence
scope. This adds two exact-input parity pairs without changing the manifest.

**Candidate path classification, 2026-10-20:** the Beta mention in
`R/EDI/tests/testthat/test-permutations.R` is a randomized-refit state
invariance test, not a successful information-inversion fixture. Its
`compute_treatment_estimate_during_randomization_inference()` route uses
`fast_beta_regression_cpp(..., compute_std_errs = FALSE)` (source
`R/EDI/R/inference_proportion_beta.R`, around lines 438-459); it does not call
the guarded `fast_beta_regression_with_var_cpp`. No preguard replay is needed
for that test's stated path, and it is removed from the unisolated positive
class-fixture queue.

**Focused design-inference candidate, 2026-10-20:** the single Beta block in
`R/package_tests/testthat_bulk/test-design-inference.R` (“Inference works for
proportion”) calls `compute_estimate()` and reaches one successful
`fast_beta_regression_with_var_cpp` inversion. Only that block was evaluated
under each preserved DLL; it passed one expectation per DLL. The current-DLL
replay used the exact pre-guard arguments and all 11 common result fields were
`identical()` (current-only `information_invertible` excluded). Test source
SHA-256 is `5f5b072aad417f153976dea316b705db8693a90338740ac8ecbf0c2708395bd1`;
capture RDS hashes (pre-guard/current) are
`5497c6a47c00a7d524ffcc8e2505bd2e6d4e81ea5faa0533f2e4e0814b490b16` and
`9574bbf15798b67987b527a2de7f8e3e8ab52af392566da94c3125082787d97a`.
Unrelated test blocks in that file were not run.

**Bounded Bartlett smoke-fixture initial-fit replay, 2026-10-20:** the Bartlett
smoke helper runs `compute_estimate()` before its `B = 21` parametric null
simulation; the latter was deliberately not run. The source-defined NegBin
fixture's initial fit was captured separately under each DLL and exact-input
replayed through the current DLL; arguments were identical and all 11 common
fields matched. For the same reason, the source-defined ZINB and shared
zero-augmented Poisson fixtures were each constructed with their test helper
and only their initial full-variance `compute_estimate()` was run under the
pre-guard DLL; the current DLL was then run directly on those exact captured
arguments. These finite-fit captures produced one `fast_zinb_cpp` call and
two `fast_zero_augmented_poisson_cpp` calls. For each, arguments were
identical and all 15 common result fields matched (the current-only
`information_invertible` field was excluded). The source-defined fixture
helpers and class settings match the Bartlett smoke file; the full test
blocks, Bartlett p-value/CI, and repeated null-refit work remain unrun. Source
SHA-256 is `e71f837eeb947137b52fa9b6d1869dcd386bbd40becbb025aa28176cde8a29cb`;
RDS SHA-256 values are NegBin pre/current
`eb2486e29b52125043bd1254c2d09be9ce8a0b24b17f32d10140079e59126b3b` /
`e91b0ee10d8c75f20e2abe5019c7773d1590fb86998ceee3435ac0e8d208f801`, ZINB +
zero-augmented pre-guard `fc39ed83d79e08b60af4cca2ea207a6f2e23f33c14d630fca3b177f9065b1b53`,
and current replay `1db9708c09146d290e716cfe35d7928ba8bb91341bdbaec026926a4f963a3897`.
Artifacts are under `/tmp/edi-todo4-caller-audit.F3SnnC/`. This bounded
initial-fit evidence does not count as the smoke test's resampling acceptance.

**Bounded Bartlett NegBin null-refit smoke, 2026-10-20:** ran only the
source-defined `InferenceCountNegBin` p-value call from the Bartlett smoke
fixture (`make_bartlett_smoke_negbin_design(seed = 41002L, n = 100L)`,
`model_formula = ~x1`, `num_cores = 1L`, `set_seed(51002L)`,
`delta = 0`, `B = 21L`) once under each preserved DLL. Both separate
`Rscript` processes used `pkgload::load_all(..., compile = FALSE,
recompile = FALSE)` against the corresponding preserved source tree and had a
hard 90-second timeout; both exited 0 before the bound. R was 4.7.0. The
initial estimate was `0.47105703080541689` under both DLLs, and the public
Bartlett p-value was `0.018854003198690451` under both (`identical()` for each
scalar). This is source-loaded R plus preserved-native evidence, not an
installed-package result. The pre-guard/current source-tree DLL hashes are
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`;
the preserved R-source tree manifest is
`f35da9b53aefd38c29ea9d53cc2e4137fc6ea9e83a29ec266eff2b6c62044f7c`.
Logs and RDS outputs are `pre-guard-bartlett-negbin-B21.{log,rds}` and
`current-bartlett-negbin-B21.{log,rds}` under
`/tmp/edi-todo4-caller-audit.F3SnnC/`; the RDS SHA-256 values are
`235b91cb9dde9aee77ff27af6c70e25a182665ea4a6a9e95474c84a3dc74a77a` and
`71a785fe8be5008ee6be9699cbe4d1223e50149100cc77e420db9043b9fb6140`.
This bounded check records the initial estimate and the public p-value only;
it does not retain or compare each private simulated/refit result, execute the
smoke helper's confidence-interval call, or close the full Bartlett/matrix
acceptance gate.

These files and their calls are additional evidence, not additions to or a
rewrite of the 20-file/567-fixture manifest. Remaining broader fixture paths
not fully isolated/reconciled include the Bartlett null-refit portion of
`R/package_tests/testthat_bulk/test-bartlett-lr-approx-smoke-families.R` and
the all-class matrix in `R/package_tests/testthat_bulk/test-parametric-bootstrap-lr-all-capable-classes.R`.
The latter's test matrix runs B=2 parametric-bootstrap smoke paths for every
capable class (including NegBin/Beta/zero-augmented families); the broad
matrix was not run. The full Bartlett file remains unrun; selected bounded
B=21 p-value-only replay exists for `InferenceCountNegBin`, and p-value plus
CI replays now exist for `InferenceCountZeroInflatedNegBin` and
`InferenceCountZeroInflatedPoisson` fixtures below. Other Bartlett classes
and per-replicate internal diagnostic reconciliation remain outstanding.

**Residual helper-hit classification, 2026-10-20:** the NegBin block in
`R/EDI/tests/testthat/test-smart-start-warm-paths.R` reaches one successful
full-variance kernel call from its source-seeded gradient-path fixture
(`set.seed(505)`, `n = 80`); the isolated block passed four expectations under
the pre-guard DLL. Its one captured input was replayed through the current
DLL with identical arguments and all 11 common result fields identical
(current-only `information_invertible` excluded). Source SHA-256 is
`86c6a94297baf131e3a388ebfb80ee0964f8e9f2f821a3d856b3dffca9eadb2c`;
pre-guard/current RDS hashes are
`c677907e87d519c0a616e8fd9d69dde9777853e65b1b6957a75e76886138be93` and
`07319730775ce139b96b4fdafc8a73df6b84116665347f1f7afd4471094f40cb`.
Only this NegBin block, not the other families in the test file, was evaluated.

`R/EDI/tests/testthat/test-negbin-weighted.R` is not a successful fixture for
this guard: its direct call and class bootstrap-weighted refit call
`fast_neg_bin_weighted_cpp`, not `fast_neg_bin_with_var_cpp`; the weighted
point-estimate path does not call `invert_free_information()`. It was therefore
classified statically and not replayed.

Other literal/helper hits such as warm-start error guards and weighted
point-estimate paths still need distinction from successful guarded-kernel
calls; a symbol hit alone is insufficient. Thus the exhaustive *fixture*
inventory and full before/after replay gate remain open. All new package-copy,
capture, and comparison artifacts are under
`/tmp/edi-todo4-caller-audit.F3SnnC/`; no checkout source or canonical capture
was changed.

**All-capable parametric-bootstrap matrix candidate inventory, 2026-10-20:**
the test file's declared cases were statically compared with the six native
`invert_free_information()` sites. The R-facing positive candidates are
`InferencePropBetaRegr` → `fast_beta_regression_with_var_cpp`,
`InferenceCountNegBin` → `fast_neg_bin_with_var_cpp`,
`InferenceCountHurdlePoisson` and `InferenceCountZeroInflatedPoisson` →
`fast_zero_augmented_poisson_cpp`, and
`InferenceCountZeroInflatedNegBin` → `fast_zinb_cpp`. The other two sites,
`fast_zap_with_var_internal` and `fast_zinb_with_var_internal`, are portable
Python-core helpers with Python binding callers, not R wrappers; they are not
reachable from this R package test. One initial `compute_estimate()` fit was
then run for each of the five positive class candidates using that test file's
fixture builders and per-class seeds (definitions parsed without executing
the test blocks). Traces confirmed one Beta hit, one NegBin hit, two ZAP hits
(one per class), and one ZINB hit; all five estimates were finite. This used
installed EDI 1.0.3 at
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, with loaded DLL
SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`;
the candidate test source SHA-256 was
`b78a8900e92d716f5a2d5d2c76d0e6ee19b4fae11363a33a825a81b70add46b3`.
This is bounded installed-artifact evidence that those initial fits reach the
guarded R-facing sites, not a parametric-bootstrap null-refit replay,
pre/post-guard identity comparison, or run of the test's B=2 matrix. The two
Python-only sites and remaining test-matrix classes have no successful-hit
evidence from this exercise; the broader fixture and provenance gates remain
open. No build/install or canonical output was performed.

**Bounded B=2 all-capable LR replay, 2026-10-20:** ran only the five
R-reachable positive candidates from the same test file in five isolated
`Rscript` processes. Each loaded checkout R source with
`pkgload::load_all("R/EDI", compile = FALSE)` and used the already-installed
EDI 1.0.3 native DLL; each process had a hard 90-second timeout and exited 0.
For each class, the test's parametric-bootstrap LR call used `B = 2`,
`min_number_usable_samples = 1`, and `max_attempts_per_replicate = 3`; each
reported `n_success = 2`. The wrapper traces recorded Beta 2 hits, NegBin 2,
hurdle-Poisson 10, zero-inflated Poisson 10, and zero-inflated NegBin 10.
Returned p-values were respectively `2/3`, `2/3`, `2/3`, `2/3`, and `2/3`.
Elapsed times were 0.47, 0.56, 0.90, 0.93, and 1.42 seconds. The installed
DLL at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`
had SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`;
the loaded `pkgload` copies were reported under per-process `/tmp/Rtmp*/`
directories. The checkout was at HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and the test source SHA-256 was
`b78a8900e92d716f5a2d5d2c76d0e6ee19b4fae11363a33a825a81b70add46b3`.
This confirms bounded wrapper reachability and successful two-replicate
execution against that installed artifact; it is not before/after parity,
current-checkout native validation, or closure of the full fixture matrix.
No build/install or canonical output was performed.

**Paired pre-guard/current B=2 replay of the five R-reachable candidates,
2026-10-20:** replayed the same five cases from the test above in ten separate
`Rscript` processes (pre-guard and current DLL for each), each with a hard
90-second timeout. Both preserved package snapshots have identical `R/`
trees, and the same checked-out fixture source was used in every process;
the sorted `.R`-file manifest hash recorded above is
`1adba6bbd477f63760d4d0ee7e1d2b9d805149829fe7aad9edc1e1e0f8046635`. Each
loaded the selected existing DLL using `pkgload::load_all(...,
compile = FALSE, recompile = FALSE)`. The pre-guard DLL SHA-256 was
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`; the
current DLL SHA-256 was
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
R was `R Under development (unstable) (2026-10-13 r90668)`; both package
snapshot DESCRIPTION files identify version 1.0.3. The checked-out test
source SHA-256 is
`b78a8900e92d716f5a2d5d2c76d0e6ee19b4fae11363a33a825a81b70add46b3`.

For each case the fixture builder and seeds exactly follow the checked-in
test (`design_seed = 20260817 + case_index`, `bootstrap_seed = 20260917 +
case_index`; B=2, minimum usable=1, maximum attempts=3). All ten processes
exited 0. Pre-guard/current values were `identical()` for the point estimate,
observed LR statistic, both simulated LR statistics, p-value, replicate
statuses, complete LR diagnostics (including reason counts/results), CI
support flag, CI return, and final CI diagnostics. Every class had two
successful and zero failed/skipped LR replicates; every p-value was 2/3.
The exact estimates, observed LR, and two replicate LR values were:

| Class | Estimate | Observed LR | Bootstrap LR values | LR-bootstrap CI |
| --- | ---: | ---: | --- | --- |
| `InferencePropBetaRegr` | 0.51085030682947929 | 16.149823229900917 | 0.50617734481062371, 0.53008586114717104 | supported; `NA, NA` |
| `InferenceCountNegBin` | 0.50151406090391826 | 4.5037179727437433 | 0.44382206476677766, 1.96891431012363682 | supported; `NA, NA` |
| `InferenceCountHurdlePoisson` | 0.35715101203954952 | 2.7909054182966315 | 0.84727991692082583, 1.04389242011495753 | unsupported |
| `InferenceCountZeroInflatedPoisson` | -0.15517957076941039 | 0.52506986827938817 | 0.18135214342643735, -1.30067405869365871 | unsupported |
| `InferenceCountZeroInflatedNegBin` | 0.18404649899991099 | 0.4856958489765475 | 3.156742617180441357, 0.044073028255979807 | unsupported |

For the two supported CI methods, the same B=2 LR-inversion request returned
`NA` bounds under both DLLs; the three zero-augmented/hurdle classes report
that LR-bootstrap confidence intervals are unsupported. The B=2 CI result is
therefore a parity observation, not a useful finite interval. Per-process RDS
captures and the driver (SHA-256
`e3ada5711b96e0447c8b3ceca4748a711bd59ba3a1a904a94fe96b7d3c18aff5`) are in
`/tmp/edi-todo4-paired-b2/`. This closes paired runtime parity only for these
five bounded fixtures; it does not exercise the singular-information guard,
cover the remaining test classes/fixtures, or close TODO-4's exhaustive
before/after matrix. No build/install or canonical output was performed.

**Paired pre-guard/current B=21 Beta-regression replay, 2026-10-20:** as a
bounded follow-up to the B=2 matrix, replayed only the checked-in
`InferencePropBetaRegr` fixture with `B = 21`, minimum usable=1, and maximum
attempts=3, preserving the fixture's design/bootstrap seeds (20260844 and
20260944). Each side ran in a separate process with a hard 90-second timeout;
both exited 0 in about 9 seconds. Both loaded the same checkout R sources
(`pkgload::load_all(..., compile = FALSE, recompile = FALSE)`); the preserved
snapshot `R/` trees are byte-identical. The pre-guard DLL SHA-256 is
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`; the
current DLL SHA-256 is
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`, matching
`R/EDI/src/EDI.so`. Both snapshot DESCRIPTION files identify EDI 1.0.3; R was
`R Under development (unstable) (2026-10-13 r90668)`. The checkout was at
HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and the checked-out fixture
SHA-256 was
`b78a8900e92d716f5a2d5d2c76d0e6ee19b4fae11363a33a825a81b70add46b3`.

The full captured result fields were `identical()` across DLLs: point
estimate, observed LR (`16.149823229900917`), all 21 replicate LR values and
statuses, full diagnostics, p-value (`1/11`), CI support, CI return, and final
CI diagnostics. Each run had 21 successes and zero failures; the supported
LR-bootstrap CI call returned `NA, NA` on both sides. RDS captures are in
`/tmp/edi-todo4-paired-b21/` (pre-guard SHA-256
`a65fb4d5bf2193d49a6390d5cbeb0924f9313d88c8300c523f7184f223c587c5`, current
`2c8f2a88ec272a293e2048d932548b9db2a155ab29428794e62ebb1c145052d1`); the
scratch driver SHA-256 is
`7004bfb79a2b383c69b7b5b303a49da45cd54e4517fd541d3b0732611176f1f1`.
This establishes same-input B=21 parity for this one nonsingular Beta fixture,
not singular-guard behavior or exhaustive TODO-4 parity across remaining
fixtures/classes. No build/install or canonical output was performed.

**Paired pre-guard/current B=21 hurdle-Poisson replay, 2026-10-20:** replayed
only `InferenceCountHurdlePoisson` from the same all-capable test fixture,
using case index 6, design/bootstrap seeds 20260823/20260923, B=21, minimum
usable=1, and maximum attempts=3. Separate processes loaded the same
byte-identical snapshot R trees with compilation disabled and each exited 0
under a 90-second cap (about 7.5 seconds). Provenance matches the preceding
Beta replay: pre-guard DLL SHA-256
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`, current
DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`, R
`R Under development (unstable) (2026-10-13 r90668)`, snapshot DESCRIPTION
version 1.0.3, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and
fixture SHA-256
`b78a8900e92d716f5a2d5d2c76d0e6ee19b4fae11363a33a825a81b70add46b3`.

All captured fields were `identical()` across DLLs: estimate
(`0.35715101203954952`), observed LR (`2.7909054182966315`), all 21 replicate
LR values/statuses, complete diagnostics, p-value (`1/11`), and CI support and
return fields. Each run had 21 successes and zero failures; this class does
not support LR-bootstrap confidence intervals. Captures are in
`/tmp/edi-todo4-paired-b21/` (pre-guard RDS SHA-256
`894670e4bb423652eb9a195c5673c036a432108fee01986724b1893cef275f83`, current
`9001e0fdb0dbf39efaff4b40e176a1259ed5cb3484570c62c58fb31195e5d03c`). This
adds same-input B=21 parity for one hurdle-Poisson fixture only; singular-guard
behavior and the remaining TODO-4 fixture/class matrix remain open. No
build/install or canonical output was performed.

**Paired pre-guard/current B=21 zero-inflated NegBin replay, 2026-10-20:**
replayed only `InferenceCountZeroInflatedNegBin` from the same all-capable test
fixture, using case index 12, design/bootstrap seeds 20260829/20260929, B=21,
minimum usable=1, and maximum attempts=3. Separate processes loaded the same
byte-identical snapshot R trees with compilation disabled and each exited 0
under a 90-second cap (about 8 seconds). Provenance matches the preceding
paired replays: pre-guard DLL SHA-256
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`, current
DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`, R
`R Under development (unstable) (2026-10-13 r90668)`, snapshot DESCRIPTION
version 1.0.3, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and
fixture SHA-256
`b78a8900e92d716f5a2d5d2c76d0e6ee19b4fae11363a33a825a81b70add46b3`.

All captured fields were `identical()` across DLLs: estimate
(`0.18404649899991099`), observed LR (`0.4856958489765475`), all 21 replicate
LR values/statuses, complete diagnostics, p-value (`6/11`), and CI support and
return fields. Each run had 21 successes and zero failures; this class does
not support LR-bootstrap confidence intervals. Captures are in
`/tmp/edi-todo4-paired-b21/` (pre-guard RDS SHA-256
`97b9f14ec2eb00cb24326f196a4d877a29d7868ccdeb88ceee3bdc1182f344f0`, current
`3860a15dae55e1f143148e90ff92ee7e83c656534a478a24ac279b7e4b908459`). This
adds same-input B=21 parity for one zero-inflated NegBin fixture only;
singular-guard behavior and the remaining TODO-4 fixture/class matrix remain
open. No build/install or canonical output was performed.

**Paired pre-guard/current B=21 zero-inflated Poisson replay, 2026-10-20:**
replayed only `InferenceCountZeroInflatedPoisson` from the same all-capable
test fixture, using case index 13, design/bootstrap seeds 20260830/20260930,
B=21, minimum usable=1, and maximum attempts=3. Separate processes loaded the
same byte-identical snapshot R trees with compilation disabled and each exited
0 under a 90-second cap (about 7.5 seconds). Provenance matches the preceding
paired replays: pre-guard DLL SHA-256
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`, current
DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`, R
`R Under development (unstable) (2026-10-13 r90668)`, snapshot DESCRIPTION
version 1.0.3, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and
fixture SHA-256
`b78a8900e92d716f5a2d5d2c76d0e6ee19b4fae11363a33a825a81b70add46b3`.

All captured fields were `identical()` across DLLs: estimate
(`-0.15517957076941039`), observed LR (`0.52506986827938817`), all 21
replicate LR values/statuses, complete diagnostics, p-value (`9/22`), and CI
support and return fields. Each run had 21 successes and zero failures; this
class does not support LR-bootstrap confidence intervals. Captures are in
`/tmp/edi-todo4-paired-b21/` (pre-guard RDS SHA-256
`f9c1dc672d491c777d42862e2c7c65ae26b6f62eaa67d1f6008cf14581a3d0d8`, current
`ad2e11cb4743e75b0a7aa88f54ff1ca35ce4ba5fa9a1b9c2524db5c85a29cfb0`). This
adds same-input B=21 parity for one zero-inflated Poisson fixture only;
singular-guard behavior and the remaining TODO-4 fixture/class matrix remain
open. No build/install or canonical output was performed.

**Paired pre-guard/current B=21 NegBin replay, 2026-10-20:** replayed only
`InferenceCountNegBin` from the same all-capable test fixture, using case
index 10, design/bootstrap seeds 20260827/20260927, B=21, minimum usable=1,
and maximum attempts=3. Separate processes loaded the same byte-identical
snapshot R trees with compilation disabled and exited 0 under a 90-second
cap (about 8 and 9 seconds). Provenance matches the preceding paired replays:
pre-guard DLL SHA-256
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`, current
DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`, R
`R Under development (unstable) (2026-10-13 r90668)`, snapshot DESCRIPTION
version 1.0.3, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and
fixture SHA-256
`b78a8900e92d716f5a2d5d2c76d0e6ee19b4fae11363a33a825a81b70add46b3`.

All captured fields were `identical()` across DLLs: estimate
(`0.50151406090391826`), observed LR (`4.5037179727437433`), all 21 replicate
LR values/statuses, complete diagnostics, p-value (`1/11`), CI support, CI
return, and final CI diagnostics. Each run had 21 successes and zero
failures. The supported LR-bootstrap CI call returned `NA, NA` under both
DLLs, so this is an interval parity observation, not a finite interval.
Captures are in `/tmp/edi-todo4-paired-b21/` (pre-guard RDS SHA-256
`fa07745fc30674ee86a3d4f40947bff18c789843b11570aa247625dd30ec6d2d`, current
`6edf9c6b4519bb80cab54679abab5bde0c2299225b2907b6782962d51c708a50`). This
adds same-input B=21 parity for one NegBin fixture only; singular-guard
behavior and the remaining TODO-4 fixture/class matrix remain open. No
build/install or canonical output was performed.

**Paired singular-information guard fixture, 2026-10-20:** replayed the exact
documented duplicated-column block from
`R/EDI/tests/testthat/test-information-inverse-guard.R` (seed `20261008`,
`n=100`, treatment alternating 0/1, `x ~ N(0,1)`, and the test's generated
NegBin/Beta/Poisson responses) under the preserved pre-guard and current DLLs.
The source file SHA-256 is
`7bbb7426b42a8e9e96497e02dc03b8db4366dcf9410d01ad90c20c72486f6b3c`. The
paired DLL SHA-256 values are pre-guard
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
current
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`; the
snapshot `R/` trees are byte-identical, both snapshot DESCRIPTION files report
EDI 1.0.3, R was `R Under development (unstable) (2026-10-13 r90668)`, and
checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. Before replay, a
separate source-ordered check executed the documented native calls and
confirmed they preserve `.Random.seed` and leave the generated Beta/Poisson
response vectors identical to the source sequence under both DLLs.

Each kernel was invoked in its own fresh `Rscript` process with a 60-second
timeout. All eight paired processes exited 0 and returned normally; none
errored or crashed. For all four kernels, every common result field except
`vcov` was `identical()` across DLLs. The pre-guard result has no
`information_invertible` field; each current result reports `FALSE`. The
covariance change was:

| Kernel | Pre-guard covariance (finite / NaN / Inf) | Current covariance |
| --- | ---: | --- |
| NegBin | 0 / 19 / 6 | 25/25 NaN |
| Beta | 0 / 19 / 6 | 25/25 NaN |
| Zero-augmented Poisson | 0 / 30 / 6 | 36/36 NaN |
| Zero-inflated NegBin | 25 / 24 / 0 | 49/49 NaN |

The scalar fit outputs and information/Hessian diagnostics were bit-identical;
the change is confined to covariance and the current invertibility flag. RDS
captures are under `/tmp/edi-todo4-paired-b21/`:

| Kernel | Pre-guard RDS SHA-256 | Current RDS SHA-256 |
| --- | --- | --- |
| NegBin | `bd8081c5195c0b1c12b9c9e1450b68f11ceaa5114e18a55f95e15f3b310c13c7` | `784f9eccc5f0f413e19c08a7933c6ce8c1b2000d499d20cd4cefa52ee51e8e76` |
| Beta | `d7c6107fa081ae7294dada636cd23084d1cc00b604e722b10d168995bc2ee1e7` | `0d496bf3da964f4052747761078ab1368beb61f2ff33c41ad1677cb774f990e5` |
| Zero-augmented Poisson | `1753eeae5755c4841484c51c5f3e1adc73cf4c0441a88ef67f207501a4bc191c` | `ea96ed3b7c2fc02f6f7d4c0dedcbbedfe96934481cccbdddd5406d5bcafc6ca1` |
| Zero-inflated NegBin | `35796ddb9ec5a0b65fbaeead1c23229376129b25c0de41497d9c6cee44f4c49c` | `c19fed203503f165ed881c7bdf4648d9716708a62006c5d10537838742459cbb` |

The replay/RNG-check driver scripts are `/tmp/edi-todo4-singular-*.R`
(replay-driver SHA-256
`86f40b0479a2fc7eb5a5cb22515baa1412dfabc255f1860af0db89b4fa899201`,
RNG-check driver SHA-256
`842ad36f6db31e2bc5cf91dcd28f0aa41ef5244304377e34578d5fda7fb26a79`). This
confirms the documented singular fixture's pre/post behavior for these four
R-facing kernels; it does not close TODO-4's remaining full fixture/class
identity matrix. No build/install or canonical output was performed.

**Paired Bartlett ZIP B=21 fixture, 2026-10-20:** extended the selected
Bartlett smoke replay to the source-defined
`InferenceCountZeroInflatedPoisson` stratum from
`test-bartlett-lr-approx-smoke-families.R`. This uses the shared
`make_bartlett_smoke_zero_augmented_poisson_design(seed = 41006L, n = 80L)`,
`model_formula = ~x1`, `use_rcpp = TRUE`, one core, bootstrap seed `51007L`,
`B=21`, and CI `alpha=0.25`. Separate fresh p-value and CI processes ran under
each preserved DLL; all four exited 0 under 90 seconds. Both loaded the
byte-identical snapshot R trees with compilation disabled. The pre-guard and
current DLL SHA-256 values were
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`; both
snapshot DESCRIPTION files report EDI 1.0.3. R was
`R Under development (unstable) (2026-10-13 r90668)`, checkout HEAD was
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and test source SHA-256 was
`e71f837eeb947137b52fa9b6d1869dcd386bbd40becbb025aa28176cde8a29cb`.

The estimate (`-0.3659973380055454`), Bartlett p-value
(`0.41687729705400045`), and finite CI
`[-0.51434723298758689, -0.01299297465940378]` were `identical()` across DLLs.
The public `get_last_param_bootstrap_diagnostics()` returned `NULL` for both
calls, so per-replicate fit/status parity is not established. Pre-guard/current
p-value RDS SHA-256s are
`50710ff4db6ef0ea58c16857e80ed6ad03cb94deb8508043b49285ce50eb0e51` /
`0c54940e7841e0a335f2b783acb23476cac7c575112319f633ef6689be2c5f02`; CI RDS
SHA-256s are
`762565719488f2c5544eec31b74b3932962512cdba8b2c8c6c7e7e7ece15c803` /
`a3e6eabe37e1139ca8af1b480572d4870907e0a072de350a34ef48000ffbffb3`. Captures
and driver (SHA-256
`d317074a4f827deb4f8cd50d8d8522632c08622f314cf8074b1483471ad73cbb`) are in
`/tmp/edi-todo4-paired-b21/` and `/tmp/edi-todo4-bartlett-zap-replay.R`.
This adds one bounded Bartlett ZIP public-output pair only; other Bartlett
classes and full per-replicate diagnostic reconciliation remain open. No
build/install or canonical output was performed.

**Paired Bartlett ZINB B=21 fixture, 2026-10-20:** to cover a distinct
parameter/design stratum from the all-capable fixed-design matrix, replayed
the source-defined `InferenceCountZeroInflatedNegBin` Bartlett smoke fixture
from `test-bartlett-lr-approx-smoke-families.R`: design seed `41005`, `n=110`,
`model_formula = ~x1`, `use_rcpp = TRUE`, one core, bootstrap seed `51006`,
`B=21`, and CI `alpha=0.25`. Separate fresh p-value and CI processes ran for
each preserved DLL, each under a 90-second timeout and each exiting 0. Both
loaded the byte-identical snapshot R trees with compilation disabled. The
pre-guard/current DLL SHA-256 values were
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`; both
snapshot DESCRIPTION files report EDI 1.0.3. R was
`R Under development (unstable) (2026-10-13 r90668)`, checkout HEAD was
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and test source SHA-256 was
`e71f837eeb947137b52fa9b6d1869dcd386bbd40becbb025aa28176cde8a29cb`.

The exact initial estimate (`-0.14696937848088917`), Bartlett p-value
(`0.55906582938402849`), and finite interval
`[-0.52159109734822984, 0.07077257601023698]` were `identical()` across DLLs.
The public `get_last_param_bootstrap_diagnostics()` returned `NULL` for both
Bartlett calls, so this comparison does not establish per-replicate fit/status
parity. Pre-guard/current p-value RDS SHA-256s are
`a5ef9ec17c7b3c3527394f654883990e69b2e3b374f68e566fb521c2942d554c` /
`85107543bc63ab92bb7aa9387d696d348816ac20e72c2ffe34758a4c6fe2d92c`; CI RDS
SHA-256s are
`4768ba0f9c27e83230e1cd683f0ff30c0ec2a7eb2b8f51b296b74514aa8aaea8` /
`44cff7b159a953e4ce2ad8d1abfae2d64121f2d8aa52955cb1573fc8bd2c605a`. The
captures and driver (`7a116d321bdb4614f1d81a254a0292956c676bd1bac6f0707ed2dbd39c50211c`)
are under `/tmp/edi-todo4-paired-b21/` and `/tmp/edi-todo4-bartlett-zinb-replay.R`.
This closes one bounded Bartlett ZINB public-output pair only; it does not
close the full Bartlett class matrix or TODO-4's complete direct/indirect
fixture inventory. No build/install or canonical output was performed.

**Paired Bartlett Hurdle-Poisson B=21 fixture, 2026-10-20:** replayed the
source-defined `InferenceCountHurdlePoisson` stratum from
`test-bartlett-lr-approx-smoke-families.R`, using
`make_bartlett_smoke_zero_augmented_poisson_design(seed = 41006L, n = 80L)`,
`model_formula = ~x1`, `use_rcpp = TRUE`, one core, bootstrap seed `51007L`,
`B=21`, and CI `alpha=0.25`. This is the sibling Hurdle class on the shared
zero-augmented Poisson response fixture, distinct from the ZIP replay above.
Four separate fresh `Rscript` processes (p-value and CI under each DLL) all
exited 0 under the 90-second per-process limit. Both source snapshots' `R/`
trees were byte-identical; compilation/recompilation was disabled. The
pre-guard/current DLL SHA-256 values were
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`; both
snapshots identify EDI 1.0.3. R was
`R Under development (unstable) (2026-10-13 r90668)`, checkout HEAD was
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and test source SHA-256 was
`e71f837eeb947137b52fa9b6d1869dcd386bbd40becbb025aa28176cde8a29cb`.

The initial estimate (`-0.35696406911634965`), Bartlett p-value
(`0.097518202397671339`), and finite CI
`[-0.66210311056794668, -0.10485643024113409]` were identical across DLLs.
`get_last_param_bootstrap_diagnostics()` returned `NULL` for both operations
under both DLLs, so this establishes public-output parity only, not
per-replicate fit/status parity. Pre-guard/current p-value RDS SHA-256s are
`11e3e640b5668c17fa630642d1905e4753ae5cb346d591b14bf552c81b4c2c36` /
`5924862fc0aa7b21217ff73f609f29a0c8e5432eff08940b8a95b883c427fef6`; CI RDS
SHA-256s are
`45734014cb8049389ee31f0230e40554dd17803d4fc4a60f30d682e2a59beb2a` /
`f1e5f3792dc3a33f25f42a38b5dfb9768818981579bba06a989b11d8cf2a415d`. The
replay driver is `/tmp/edi-todo4-bartlett-zap-replay.R` (SHA-256
`d317074a4f827deb4f8cd50d8d8522632c08622f314cf8074b1483471ad73cbb`); logs
and RDS files are under `/tmp/edi-todo4-paired-b21/`. The expected
`pkgload::load_all()` warning that no installed `EDI` package was found was
emitted; calls used the explicitly loaded snapshot source and DLL. This adds
one bounded Bartlett Hurdle-Poisson public-output pair only. Other Bartlett
classes and the full per-replicate diagnostic reconciliation remain open; no
build/install or canonical output was performed.

**Paired Beta real-data `with_var` fixture, 2026-10-20:** added a distinct
successful R-facing Beta kernel fixture from
`R/EDI/tests/testthat/test-rcpp-fitting-real-data.R` (the
`betareg::ReadingSkills` block), not another parametric-bootstrap stratum.
The test's exact call is `fast_beta_regression_with_var_cpp(X_data, y)` with
`y = ReadingSkills$accuracy` and
`X_data = model.matrix(accuracy ~ dyslexia + iq, data = ReadingSkills)`;
the fixture has `n=44`, `p=3`. Separate fresh processes source-loaded each
preserved snapshot with `compile=FALSE` and `recompile=FALSE`, then captured
the native result and independent `betareg::betareg` reference. Both exited 0
under a 90-second timeout. The design and response were `identical()` across
snapshots, and all 11 common native result fields were `identical()`; the
guarded DLL additionally returns `information_invertible`. Reapplying the
existing test's independent coefficient (`tolerance=1e-4`) and precision
(`tolerance=1e-3`) assertions to both captures passed four expectations.

The C++ coefficients were
`1.44535082306025853, -0.96592882389069523, 0.12415111143541324`, versus
`betareg`'s
`1.44529192685319230, -0.96592364795243879, 0.12425644711883500`; C++
precision was `10.379897249237548`, versus `10.380110452789152`. The fixture
source SHA-256 is
`0cc65d3e4478dce05ba375f52b00f1b866b926b5257914e098472b6ba3f87f0d`. The
pre-guard/current DLL hashes are
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`; both
snapshot DESCRIPTION files identify EDI 1.0.3, both `R/` trees are
byte-identical, and checkout HEAD is
`4f7a6e4ca82829e880c15a76699701a95e5e83b9` (R 4.7.0-devel,
`2026-10-13 r90668`). RDS captures are
`/tmp/edi-todo4-paired-b21/beta-readingskills-pre-guard.rds` (SHA-256
`64888b4936660239020f17c8edf11aacc87d80022f5eb0c8559d888ab3d7f405`) and
`beta-readingskills-current.rds` (`6f96934548c00670b440493aa4e1258f92ca1b393ce5cc4d93bef6f9d9fac5b2`);
the driver is `/tmp/edi-todo4-beta-readingskills.R` (SHA-256
`debbd5dc216e8dd48d52ed7290f051a24f33c4d32b8a84b6476cfe73892b02e5`). The
`pkgload` warning that no installed EDI package was found was expected; the
explicit source snapshot and DLL were loaded. This direct-fit fixture has no
bootstrap replicate diagnostics to compare and does not replace TODO-4's
remaining class/fixture matrix. No build/install or canonical output was
performed.

**Paired NegBin canonical-GLM fixture, 2026-10-20:** replayed the exact
Negative Binomial block from
`R/EDI/tests/testthat/test-fast_glm_outputs.R` under the preserved pre-guard
and current DLLs. The fixture uses `set.seed(123)`, `n=200`, two Gaussian
covariates plus intercept, true coefficients `(1, 0.5, -0.5)`, `theta=2`, and
`MASS::rnegbin`; it exercises `fast_neg_bin_with_var_cpp` and checks against
`MASS::glm.nb`. Each source-loaded process disabled compilation and
recompilation, had a 90-second timeout, exited 0, and passed both existing
independent-reference assertions. The input design/response and all 11 common
native result fields were identical; the current DLL additionally returns
`information_invertible`. This is a new direct-kernel n=200 fixture, distinct
from the earlier class/Bartlett and Beta ReadingSkills runs.

Native coefficients were
`0.98329066694172973, 0.54290256676333581, -0.47287343191649389`, versus
`MASS` coefficients
`0.98327490557526087, 0.54287565916016201, -0.47297060819978520`; theta was
`2.245648562896629` versus `2.2456925369405401`; the treatment SE was
`0.069237108257947502` versus `0.069304311430646595`. The test source SHA-256
is `37354f31f9ca3ada93536239501c2eaf04f0108924461d25321fa00c78b36dcc`; the
pre-guard/current DLL hashes remain
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` (EDI
1.0.3 snapshots, identical `R/` trees; checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, R 4.7.0-devel,
`2026-10-13 r90668`). The `pkgload` warning that no installed EDI package was
found was expected. Captures are
`/tmp/edi-todo4-paired-b21/negbin-fast-glm-outputs-pre-guard.rds` (SHA-256
`000db36658b02cc0d2039deb4c7e444a794152f441c3c4be3b0d0b3da3c7f54f`) and
`negbin-fast-glm-outputs-current.rds`
(`5163cc22f06a12c04250b30037eaee9da3c21369f6c81c20287090782f0da789`); the
driver `/tmp/edi-todo4-negbin-canonical-glm.R` has SHA-256
`932b5067570fca94e6d7fd420b43634c8b137fcc87d3b501004a60cdcbcc1223`. These
direct-fit results have no bootstrap replicate diagnostics to compare and do
not close the full TODO-4 fixture matrix. No build/install or canonical output
was performed.

**Paired Hurdle-Poisson real-data `with_var` fixture, 2026-10-20:** replayed
the exact `fast_zero_augmented_poisson_cpp(..., is_hurdle = TRUE)` block for
`glmmTMB::Salamanders` from
`R/EDI/tests/testthat/test-rcpp-fitting-real-data.R`. The conditional model is
`count ~ mined + spp`, zero-inflation model `~ mined`, with
`glmmTMB::truncated_poisson`; the 644-row fixture has 8 conditional and 2
zero-inflation columns. Separate fresh source-loaded processes under the
preserved pre-guard and current DLLs disabled compilation/recompilation,
exited 0 under 90 seconds, and passed all four existing independent-reference
assertions for conditional coefficients, zero-inflation coefficients, and
both covariance-diagonal blocks against `glmmTMB::glmmTMB` version 1.1.14.
The response and both design matrices were `identical()` between runs. All 15
common native fields (including fit/convergence diagnostics, score, observed
and Fisher information, Hessian, covariance, and coefficients) were
`identical()`; only the current-only `information_invertible` field has no
pre-guard counterpart.

The conditional coefficients were
`0.010544402605668477, 0.974712607143844223, -0.451246439472479777,
0.181452501244518866, -0.166301239536322587, 0.622935058668255492,
0.610373337838239105, 0.050518270446735666`; zero-inflation coefficients
were `1.6652287731704825, -2.1507478912054259`; all covariance diagonal
entries were finite. The test source SHA-256 is
`0cc65d3e4478dce05ba375f52b00f1b866b926b5257914e098472b6ba3f87f0d`; the
pre-guard/current DLL hashes remain
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. The
snapshots have byte-identical `R/` trees and both identify EDI 1.0.3; checkout
HEAD is `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, R 4.7.0-devel
(`2026-10-13 r90668`). RDS captures are
`/tmp/edi-todo4-paired-b21/hurdle-salamanders-pre-guard.rds` (SHA-256
`894eb6df06b8541d1481e447a2d0df46c2d4b1344198ba2c8ef3e4f86523bf92`) and
`hurdle-salamanders-current.rds`
(`67ff009659e3e9e4f9af94b77fe747b18b3072e051db38719b54031a78af646a`); the
driver `/tmp/edi-todo4-hurdle-salamanders.R` has SHA-256
`9fb4ca2c36d08cfe0ece142490e507fb33f2ee4c349e3017a3ec914d89e879de`. The
expected pkgload warning that no installed EDI package was found was emitted.
This is a direct-fit fixture with native fit diagnostics, not a bootstrap
replicate-diagnostics comparison; the remaining TODO-4 matrix is open. No
build/install or canonical output was performed.

**Paired ZINB real-data `with_var` fixture, 2026-10-20:** replayed the exact
`fast_zinb_cpp` block for `glmmTMB::Salamanders` in
`R/EDI/tests/testthat/test-rcpp-fitting-real-data.R` under the preserved
pre-guard and current DLLs. The fixture uses `count ~ mined + spp`,
`ziformula = ~ mined`, `nbinom2`, `n=644`, an 8-column conditional design,
and a 2-column zero-inflation design; its independent reference is
`glmmTMB::glmmTMB` (version 1.1.14). Both fresh source-loaded processes
disabled compilation/recompilation, exited 0 under 90 seconds, and passed the
four existing coefficient/precision/finite-vcov assertions. The response and
both design matrices were `identical()` across the two calls. All 15 common
native result fields—including fit status, score, information/Hessian,
covariance, boundary indicators, reduced-model flag, and coefficients—were
`identical()`; the current DLL has the additional `information_invertible`
field.

The conditional coefficients were
`-0.39799863588994039, 1.12949700497644900, -1.31874415201418005,
0.27842372298621954, -0.72212453140188404, 0.61866716837158375,
0.71491825496377304, 0.15579407669331533`; zero-inflation coefficients were
`0.48967992112813746, -3.06393355974730364`. The last parameter was
`0.2089035843169888` versus reference log-sigma `0.20897614441469267`, and
all covariance diagonal values were finite. The fixture source SHA-256 is
`0cc65d3e4478dce05ba375f52b00f1b866b926b5257914e098472b6ba3f87f0d`; DLL
hashes are the preserved pair
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` /
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. The
snapshot `R/` trees are identical and both DESCRIPTION files identify EDI
1.0.3; checkout HEAD is `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, R is
4.7.0-devel (`2026-10-13 r90668`). Captures are
`/tmp/edi-todo4-paired-b21/zinb-salamanders-pre-guard.rds` (SHA-256
`e411ac571ddc8b02fcbc034fca37426c9c0e7bbe78a606cef7341724bec6929f`) and
`zinb-salamanders-current.rds`
(`eaddc935434407a8d564dfe4d3d744bf09854ce447a9650e73e5c37818aa7557`); the
driver `/tmp/edi-todo4-zinb-salamanders.R` has SHA-256
`214bd850e5fa71f57b10e85129cbd4222fa8dcfa82eb4345f6749131077a8828`. The
expected pkgload warning that no installed EDI package was found was emitted.
This is one direct real-data fit pair, not a bootstrap replication or
per-replicate diagnostic comparison; the remaining TODO-4 matrix is open. No
build/install or canonical output was performed.

**Paired NegBin `MASS::quine` real-data `with_var` fixture, 2026-10-20:**
replayed the exact Negative Binomial block from
`R/EDI/tests/testthat/test-rcpp-fitting-real-data.R` under both preserved
DLLs. The fixture uses `y = quine$Days` and
`model.matrix(Days ~ Eth + Sex + Age, data = quine)` (`n=146`, `p=6`), with
`MASS::glm.nb` as the independent reference (MASS 7.3.66). Each fresh
source-loaded process disabled compilation/recompilation, exited 0 under 90
seconds, and passed all three existing coefficient, dispersion, and covariance
diagonal assertions. The input response/design and all 11 common native
result fields were `identical()`; the current DLL's extra field is
`information_invertible`.

The native coefficients were
`3.008748809616876851, -0.568250506365470032, 0.063282681133944516,
-0.364864859035399614, 0.178630819488851372, 0.255086120821000129`; theta
was `1.2481604148253713` and covariance was finite. Test-source SHA-256 is
`0cc65d3e4478dce05ba375f52b00f1b866b926b5257914e098472b6ba3f87f0d`; the
pre-guard/current DLLs are
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` and
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` (both
EDI 1.0.3 snapshots with byte-identical `R/` trees; checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, R 4.7.0-devel,
`2026-10-13 r90668`). Captures are
`/tmp/edi-todo4-paired-b21/negbin-quine-pre-guard.rds` (SHA-256
`c90e1bc39e2aa3c41e5db5ccf78e33f7b4aca2d2218d2b2ab1ea37116362a3cf`) and
`negbin-quine-current.rds`
(`077eb2dcf8a0d1a1161b509166177963d3679e29f9b564ca0d0450b7b03c6cbe`); the
driver `/tmp/edi-todo4-negbin-quine.R` has SHA-256
`2d2b0d6c0904b643e2d777f796f557e856ff42bcf0359b04c9861c107ff6e2bb`. The
expected pkgload warning that no installed EDI package was found was emitted.
This direct fit exposes kernel fit fields but no bootstrap replicate
diagnostics; the full TODO-4 fixture matrix remains open. No build/install or
canonical output was performed.

**Paired synthetic Hurdle-Poisson `with_var` fixture, 2026-10-20:** replayed
the exact seed-19 `fast_zero_augmented_poisson_cpp(..., is_hurdle=TRUE)` block
from `R/EDI/tests/testthat/test-rcpp-fitting-equivalence.R`. The fixture has
`n=300`, two Gaussian covariates, a log-mean `1 + 0.5*x1 - 0.3*x2`, and a
zero mechanism `plogis(-1 + x1)`; its independent reference is a
`glmmTMB::truncated_poisson` model with conditional and zero-inflation
predictors `~ x1 + x2` (glmmTMB 1.1.14). Separate fresh source-loaded runs
under the preserved DLLs disabled compilation/recompilation, exited 0 under
90 seconds, and each passed all four existing coefficient/covariance-block
assertions. Inputs were `identical()`, and all 15 common kernel output fields
(including convergence diagnostics, gradient/information/Hessian, covariance,
and coefficients) were `identical()`; the current-only field is
`information_invertible`.

Conditional coefficients were
`1.12028319713954572, 0.50201915705503153, -0.19230786060155100`, and
zero-inflation coefficients were
`-0.23745563974088693, 0.19513978281238015, 0.45565535135660618`; covariance
diagonals were finite. Test-source SHA-256 is
`67c82f992e7f14502f2720eb275dafcc3fd46e3f8da5ff9ad280fd08c2f313b7`; DLL
SHA-256 values are the preserved pair
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` /
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. The
snapshot `R/` trees are byte-identical, both DESCRIPTION files identify EDI
1.0.3, and checkout HEAD is `4f7a6e4ca82829e880c15a76699701a95e5e83b9` (R
4.7.0-devel, `2026-10-13 r90668`). RDS captures are
`/tmp/edi-todo4-paired-b21/hurdle-synthetic-pre-guard.rds` (SHA-256
`8bcb456efea4c3c9ca185db0c8ea26a9aee1a00c47107c8ac9662f5a33702857`) and
`hurdle-synthetic-current.rds`
(`96148b5bf5c40fecb30acd754b399a62b7f03e1527cd37ae28afcc1c93ff18e8`); the
driver `/tmp/edi-todo4-hurdle-glmm-synthetic.R` has SHA-256
`0ef04ece3bb737f1ac6cc2b7823f6450ba1e32e946245c5b21d7c39b9411d4dd`. The
expected pkgload warning that no installed EDI package was found was emitted.
This is a direct-fit fixture with native fit diagnostics, not a bootstrap
replicate-diagnostics comparison; the rest of TODO-4's paired matrix remains
open. No build/install or canonical output was performed.

**Paired synthetic ZIP `pscl` reference fixture, 2026-10-20:** replayed the
non-Hurdle (`is_hurdle = FALSE`) seed-4 block from
`R/package_tests/testthat_bulk/test-zero-augmented-poisson-kernels-score-hessian-fit-and-pscl-reference.R`.
The 200-row fixture uses a three-column count design and two-column zero
model; `pscl::zeroinfl` (pscl 1.5.9) is the independent reference. Each
fresh source-loaded process disabled compilation/recompilation, exited 0
under 90 seconds, and passed all six existing cold/warm parameter, likelihood,
and standard-error assertions. The warm call used the test's correctly shaped
`p0` start. Both input designs and response were `identical()` across the
preserved DLLs; all 15 common cold-fit fields and all 15 common warm-fit fields
were `identical()`, including convergence, score/gradient, information,
Hessian, covariance, and coefficients. The current-only field is
`information_invertible`.

Cold coefficients were
`0.344730400182303887, 0.256127659782282358, -0.079650294264682703,
-0.826501722592277055, 0.274260795849584738`; warm coefficients were
`0.344770440046867410, 0.256111616730347658, -0.079689480116055353,
-0.826481367234512043, 0.274227593980514106`; pscl's reference coefficients
were `0.344753082054194138, 0.256218426542875855, -0.079678134264005426,
-0.826686694110069342, 0.274371453235384866`. Test-source SHA-256 is
`fc08174ea1b89dc3722b446aebed6f23e27de2e60547e5f0ecfdedda4064eca7`; DLL
hashes remain
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` /
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` (EDI
1.0.3 snapshots with byte-identical `R/` trees; checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, R 4.7.0-devel,
`2026-10-13 r90668`). RDS captures are
`/tmp/edi-todo4-paired-b21/zip-pscl-pre-guard.rds` (SHA-256
`9223d830abe96a9a3beaeb5c90b55522d59fe5b347e87824a4f61003d0503e72`) and
`zip-pscl-current.rds`
(`1a0dc902df33b140e5db85134a8e0150c8378f8dca1b995a8940a8961e9dd525`); the
driver `/tmp/edi-todo4-zip-pscl-reference.R` has SHA-256
`12e4368329d127a3d1df8e59e7cbd515c812b39d060028b935ab16c41bd86d57`. The
expected pkgload warning and pscl `.Names` deprecation warning appeared under
both runs. This direct cold/warm fit pair has native fit diagnostics but no
bootstrap replicate diagnostics; TODO-4's remaining fixture matrix stays
open. No build/install or canonical output was performed.

**Paired synthetic ZINB `glmmTMB` fixture, 2026-10-20:** replayed the exact
seed-18 `fast_zinb_cpp` block from
`R/EDI/tests/testthat/test-rcpp-fitting-equivalence.R`. The fixture has
`n=300`, two Gaussian covariates, a log-mean `1 + 0.5*x1 - 0.3*x2`, and
zero-inflation probability `plogis(-1 + x1)`; the independent oracle is
`glmmTMB::glmmTMB` with `nbinom2` (glmmTMB 1.1.14), `y ~ x1 + x2`, and
`ziformula = ~x1 + x2`. Separate fresh source-loaded runs under the preserved
pre-guard and current DLLs disabled compilation/recompilation, exited 0 under
90 seconds, and passed all four existing parameter/precision/finite-vcov
assertions. The response and both designs were `identical()` across runs. All
15 common native fields—including convergence, score, observed information,
Hessian, covariance, boundary flags, reduced-model status, and coefficients—
were `identical()`; the current-only field is `information_invertible`.

Conditional coefficients were
`0.93788129693838873, 0.50220425401160362, -0.36785651960031857`,
zero-inflation coefficients were
`-0.98012425397677283, 1.77594980275169356, 0.24550023773391189`, and the
last parameter was `0.54492834427742232` versus reference log-sigma
`0.54496995942726723`; covariance diagonals were finite. Test-source SHA-256
is `67c82f992e7f14502f2720eb275dafcc3fd46e3f8da5ff9ad280fd08c2f313b7`; DLL
hashes are the preserved pair
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` /
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. The
snapshot `R/` trees are byte-identical, both DESCRIPTION files identify EDI
1.0.3, and checkout HEAD is `4f7a6e4ca82829e880c15a76699701a95e5e83b9` (R
4.7.0-devel, `2026-10-13 r90668`). RDS captures are
`/tmp/edi-todo4-paired-b21/zinb-synthetic-pre-guard.rds` (SHA-256
`a4b63fbbb870d84866b0aa5e0fceda5603822be0dda8739287874ee7f0896321`) and
`zinb-synthetic-current.rds`
(`e2957ffc5f14c9b4930a386d75ab6b7d14d6b535d6ed8f7f36aa56499daefa0d`); the
driver `/tmp/edi-todo4-zinb-synthetic-glmmtmb.R` has SHA-256
`1d94972f72c7bffb69b63217f307d0103184dfa939b1d1d417b086553fd2b169`. The
expected pkgload warning that no installed EDI package was found was emitted.
This is a direct-fit native-diagnostic comparison, not a bootstrap
replicate-diagnostics check; the rest of TODO-4's paired matrix remains open.
No build/install or canonical output was performed.

**Paired synthetic Beta `betareg` fixture, 2026-10-20:** replayed the exact
seed-6 `fast_beta_regression_with_var_cpp` block from
`R/EDI/tests/testthat/test-rcpp-fitting-equivalence.R`, a new fixture distinct
from the prior ReadingSkills and Bartlett cases. The 200-row response is
drawn from a Beta model with mean `plogis(X %*% c(0.5, -0.5))` and precision
15, clipped to `(1e-6, 1-1e-6)`; the oracle is `betareg::betareg(y ~ X)`
(betareg 3.2.6). Separate fresh source-loaded runs under the preserved
pre-guard and current DLLs disabled compilation/recompilation, exited 0 under
90 seconds, and each passed all three existing independent coefficient,
precision, and covariance-diagonal assertions. The exact response/design
were identical. All 11 common native fields—coefficients, precision,
likelihood, covariance/SE, convergence/iteration, gradient and information
diagnostics—were `identical()`; the current-only field is
`information_invertible`.

Native coefficients were
`0.039656131121006029, 0.493193970002103854, -0.533258641577553649`, versus
reference `0.039654124393980583, 0.493195187107743516, -0.533260648527198455`;
precision was `17.442775664241708` versus `17.442450662714528`, and the
covariance was finite. Test-source SHA-256 is
`67c82f992e7f14502f2720eb275dafcc3fd46e3f8da5ff9ad280fd08c2f313b7`; DLL
hashes remain
`89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` /
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. Both
snapshots identify EDI 1.0.3 and have byte-identical `R/` trees; checkout
HEAD is `4f7a6e4ca82829e880c15a76699701a95e5e83b9` (R 4.7.0-devel,
`2026-10-13 r90668`). Captures are
`/tmp/edi-todo4-paired-b21/beta-synthetic-pre-guard.rds` (SHA-256
`648b62e8d1fa15957a90807c532b3aa762fc3cddfff1307cce7afd1f30fbe019`) and
`beta-synthetic-current.rds`
(`c2e933e53d81d3a1b03b8d1d90b9e057f1fec6bd7d5fbee9aa8feda415e6bd90`); the
driver `/tmp/edi-todo4-beta-synthetic-betareg.R` has SHA-256
`3731943a77f69f90f4fd4baf1ec61c842751ef7121431026731620793ffe2d8e`. The
expected pkgload warning that no installed EDI package was found was emitted.
This direct fit has native fit diagnostics but no bootstrap replicate
diagnostics; TODO-4's remaining paired matrix is open. No build/install or
canonical output was performed.
