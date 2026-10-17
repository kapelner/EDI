# Dead Randomization Fast Paths: a Kernel That Does Not Exist, Two Type Mismatches, and a Dispatcher That Hides Both

> **Depends on:** nothing. Touches `inference_count_poisson.R →
> compute_fast_randomization_distr()` (L816–822),
> `inference_all_simple_wilcox.R → compute_fast_randomization_distr()`
> (L287–298), `inference_all_KK_wilcox_ivwc.R`'s equivalent, the fast-path
> dispatcher in `inference_all_abstract_rand.R` (L60–66), and one new
> wiring test. `permutation_signature_once.md` (`release_v1_1_0.md →
> TODO-42`) shares TODO-2 (integer storage) with this plan: implement once.
> Otherwise independent of every item in `release_v1_0_5.md` and
> `release_v1_1_0.md`.
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-64`).

Written 2026-10-07. Found while scoping `permutation_signature_once.md`
against the installed CRAN EDI 1.0.2 (no rebuild): a script called each
class's `compute_fast_randomization_distr()` directly on the permutation
object the dispatcher itself produces. Filed on the model's initiative under
the standing instruction to add found bugs to v1.0.5; delete if unwanted.

## Findings (installed 1.0.2, `DesignFixediBCRD` n = 1000 unless noted)

**F1. `InferenceCountPoisson`'s fast path calls a kernel that does not
exist.** `inference_count_poisson.R:821` calls
`compute_poisson_distr_parallel_cpp(X_covars, y, w_mat, delta,
log_transform, threads)`. There is no such function anywhere in the
package: no definition in `src/`, no wrapper in `RcppExports.R`, no
Poisson distribution kernel under any name (`grep` of `src/` for
`poisson.*distr.*_cpp` is empty). The call has been dangling since the
initial commit (`ff079d54`, 2026-08-10). On the installed package it fails
with `could not find function "compute_poisson_distr_parallel_cpp"`. The
`ols_randomization_distr_cpp_wiring.md` plan (`release_v1_0_5.md →
TODO-3`) cites this very method as "the Poisson class shows the intended
wiring"; the template points at a kernel that was never written.

**F2. Two Wilcoxon fast paths hand a double matrix to an integer-mapped
kernel.** `generate_permutations()` stores `w_mat` as double
(`inference_all_abstract_rand.R:755`). `InferenceAllSimpleWilcox` passes
it to `compute_wilcox_hl_distr_parallel_cpp` and `InferenceAllKKWilcoxIVWC`
to `compute_matching_wilcox_distr_parallel_cpp`, both declared
`Eigen::Map<Eigen::MatrixXi>& w_mat`, which cannot map a `REALSXP`:
`Wrong R type for mapped matrix`. Measured: `InferenceAllSimpleWilcox`
`compute_rand_two_sided_pval(r = 1000)` 891 ms through the fallback versus
404 ms for its kernel on an integer matrix.

Tested and working (their kernels take `IntegerMatrix`, which Rcpp
coerces with a copy): `InferenceAllSimpleAverageDiff`, `InferenceContinLin`,
`InferenceContinRobustRegr`, `InferenceContinQuantileRegr`,
`InferenceAllKKMeanDiffIVWC`, `InferenceContinKKOLSIVWC`,
`InferenceContinKKOLSOneLik`. Not yet tested: `InferenceOrdinalRidit`,
`InferencePropQuantileRegr`, the KK robust and Bai classes
(`compute_bai_distr_parallel_cpp` is also `Map<MatrixXi>`, so Bai is
likely dead too), `InferenceCustomRand`.

**F3. The dispatcher swallows every fast-path error.**
`inference_all_abstract_rand.R:61–66` wraps the fast path in
`tryCatch(..., error = function(e) NULL)` and falls through to the
per-permutation R worker loop. Nothing logs, warns or tests this, so a
missing kernel and a type mismatch both look like a slow day. No test
exercises any class's fast path against the dispatcher's own permutation
object; the one-line static check that found F1 (every `*_cpp(` inside a
`compute_fast_randomization_distr` body must exist in `RcppExports.R`) did
not exist either.

## TODOs

- [x] TODO-1: **Complete the audit.** Run the direct-call check for every
  class that defines `compute_fast_randomization_distr()` (18 files) on a
  design each can be constructed on, plus the static `*_cpp(`-exists check,
  and record the table here. Installed package only.

  **Static source audit, 2026-10-11:** after the Poisson method was removed,
  there are 18 overrides: seven direct native calls, ten reusable-worker
  delegates, and `InferenceRandCustom`'s R `vapply`/optional user C++
  callback. Every direct symbol has an R wrapper and native registration in
  `RcppExports`: `InferenceAllSimpleAverageDiff`,
  `InferenceAllKKMeanDiffIVWC`, `InferenceAllSimpleWilcox`,
  `InferenceAllKKWilcoxIVWC`, the Bai base, `InferenceContinOLS`, and
  `InferenceOrdinalRidit`. `InferenceContinOLS` was added by the linked
  TODO-3 wiring work after the earlier count. The first, Ridit, and the two
  matching mean-difference/Bai paths supply integer matrices already; OLS and
  both Wilcoxon paths now coerce the numeric dispatcher matrix at the R/native
  boundary. The ten delegates are KK quantile, OLS IVWC/one-likelihood,
  robust IVWC/one-likelihood, Lin, continuous/proportion quantile, continuous
  robust, and KK conditional Poisson. Thus the static wrapper-existence check
  has no remaining dangling `*_cpp` reference. **Environment recheck
  2026-10-15:** `Rscript` now starts successfully and loads installed EDI
  1.0.3, so the earlier `libmkl_gf_lp64.so.2` startup failure is no longer a
  current blocker. Focused installed-package tests passed 93 assertions
  across KK mean-difference, simple Wilcoxon, KK Wilcoxon, and ordinal Ridit
  fast paths, plus 54 assertions in the broader parallel-kernel contract
  suite. **Installed-package coverage probe, 2026-10-14:**
  `Rscript scripts/todo64_installed_override_parity.R` directly called the
  remaining 12 override definitions (Bai's shared override was exercised via
  both KK14 and KK21 classes) on generated small fixtures and compared each
  result with the reused-worker path at `1e-10`. All 13 class cases returned
  the requested 4 draws (5 for RandCustom) and reported parity; 12 had finite
  draws. The `InferenceContinKKOLSIVWC` case returned four `NA`s on both
  paths, so that equality is vacuous; a separate randomized-covariate n=40
  fixture also returned all `NA`s despite a finite public point estimate.
  Several delegate overrides call the same reused-worker method directly, so
  those comparisons establish execution, not an independent native-kernel
  oracle. That probe alone did not close the all-18, generated-50
  worker-parity criterion; the checked-in run below closes that runtime audit.
  Current-checkout coercion verification still requires a rebuilt native
  package.

  **Checked-in direct-call table, installed EDI 1.0.3, 2026-10-16:**

  | Class case | Draws | Finite | Fast/worker |
  |---|---:|---:|---|
  | `InferenceAllSimpleAverageDiff` | 50 | 50 | equal, `1e-10` |
  | `InferenceAllKKMeanDiffIVWC` | 50 | 50 | equal, `1e-10` |
  | `InferenceAllSimpleWilcox` | 50 | 50 | equal, `1e-10` |
  | `InferenceAllKKWilcoxIVWC` | 50 | 50 | equal, `1e-10` |
  | `InferenceBaiAdjustedTKK14` | 50 | 50 | equal, `1e-10` |
  | `InferenceBaiAdjustedTKK21` | 50 | 50 | equal, `1e-10` |
  | `InferenceContinKKOLSIVWC` | 50 | 50 | equal, `1e-10` |
  | `InferenceContinKKOLSOneLik` | 50 | 50 | equal, `1e-10` |
  | `InferenceContinKKRobustRegrIVWC` | 50 | 50 | equal, `1e-10` |
  | `InferenceContinKKRobustRegrOneLik` | 50 | 50 | equal, `1e-10` |
  | `InferenceContinLin` | 50 | 50 | equal, `1e-10` |
  | `InferenceContinOLS` | 50 | 50 | equal, `1e-10` |
  | `InferenceContinQuantileRegr` | 50 | 50 | equal, `1e-10` |
  | `InferenceContinRobustRegr` | 50 | 50 | equal, `1e-10` |
  | `InferenceCountKKHurdlePoissonIVWC` | 50 | 50 | equal, `1e-10` |
  | `InferenceOrdinalRidit` | 50 | 50 | equal, `1e-10` |
  | `InferencePropQuantileRegr` | 50 | 50 | equal, `1e-10` |
  | `InferenceRandCustom` | 50 | 50 | equal, `1e-10` |

  Each case calls its inference object's dispatcher generator, then directly
  calls the fast method and reused-worker reference on the same permutation
  matrix. The non-vacuous KK OLS-IVWC row uses the deterministic n=20 KK14
  fixture (design/response seed 1; permutation seed 1).

- [x] TODO-2: **Integer `w_mat` for the `Map<MatrixXi>` kernels (F2).**
  Minimal v1.0.5 form: coerce at the two Wilcoxon call sites
  (`storage.mode(w_mat) = "integer"`; one copy per call, which the
  fallback was paying many times over). Permanent form: integer storage at
  generation, `permutation_signature_once.md → TODO-4`. Implement once.
  Bit-preserving: the kernel and the worker loop compute the same
  statistic; assert equality to 1e-10 on a fixed permutation set. **Source
  implementation 2026-10-09:** both Wilcoxon call sites now make their
  `w_mat` integer before invoking the mapped kernels; the KK path also
  normalizes a supplied `m_mat`. Runtime equivalence awaits a usable rebuilt
  native package.

- [x] TODO-3 *(choose one; the kernel option is the result-changing
  exception in the standing constraint)*: **Poisson (F1).**
  - (a) Delete the dead method so `InferenceCountPoisson` honestly takes
    the worker path (bit-preserving: that is what it does today), and
    correct the "intended wiring" paragraph in
    `ols_randomization_distr_cpp_wiring.md` to point at
    `inference_all_average_diff.R:193` instead. Recommended for v1.0.5.
  - (b) Write `compute_poisson_distr_parallel_cpp` (per-permutation IRLS
    for the treatment coefficient with `X` hoisted, OpenMP over columns,
    `log_transform` honored) and keep the method. Same estimator to
    floating point, tolerance 1e-10 against the worker path; move the
    item to the OLS wiring plan's triage list if deferred.

  **Decision/implementation 2026-10-09:** chose (a). The dangling private
  method was deleted, preserving the existing worker fallback rather than
  silently claiming a native fast path that has never existed. The OLS
  wiring-plan reference now names the valid average-difference template.

- [x] TODO-4: **Stop hiding fast-path failures (F3).** Under
  `should_run_asserts()`, rethrow the fast-path error instead of falling
  back (tests and `comprehensive_tests` then catch the next dead path).
  Outside asserts keep the fallback, but `warning()` once per class per
  session and record the reason in `cached_values` for
  `InferenceSuite` diagnostics. **Source implementation 2026-10-09:**
  assertion mode now rethrows; ordinary mode emits one per-instance warning
  and records the most recent error in `cached_values` before falling back.

- [x] TODO-5: **Wiring test.** `test-randomization-fast-path-wiring-reference.R` (or
  a block in `test-inference-class-wiring-completeness.R`): for every
  class with a fast path, construct on a small fixture, call
  `generate_permutations(50)`, then assert the fast path returns without
  error and equals the worker-loop distribution to 1e-10 on the same
  permutations. Also the static `*_cpp(`-exists check over
  `R/EDI/R/*.R`.

  **Source regression progress, 2026-10-10:** the existing Simple-Wilcoxon
  reference test already supplies a double `w_mat` and checks the per-column
  HL reference. The KK-Wilcoxon reference suite now does the same explicitly,
  comparing double-dispatcher and integer-kernel matrices to `1e-10`. The
  broader all-class generated-permutation/worker-parity test remained open
  at that date and is closed by the checked-in audit below. The compile-free installed-package probe
  in `scripts/todo64_installed_override_parity.R` supplies small-fixture
  evidence for the 12 previously uncovered override definitions, but it does
  not substitute for a checked-in all-class `generate_permutations(50)` test;
  its KK OLS-IVWC fixture is vacuous (all outputs `NA`; resolved by the
  seeded fixture described below).

  **Additional installed-package coverage, 2026-10-15:** a temporary
  compile-free probe (`Rscript /tmp/edi_todo64_missing6_probe.R`) exercised
  the six remaining override classes not in that 12-case script—
  `InferenceAllKKMeanDiffIVWC`, `InferenceAllSimpleWilcox`,
  `InferenceAllKKWilcoxIVWC`, `InferenceContinOLS`,
  `InferenceContinKKOLSOneLik`, and `InferenceOrdinalRidit`—with
  `generate_permutations(50)` on small n=40 fixtures. All six returned 50
  finite values, and each matched the reused-worker distribution at
  tolerance `1e-10`; the run completed against installed EDI 1.0.3 without
  compilation/build/install. This is additional runtime evidence, not the
  checked-in all-class wiring test; its `InferenceContinKKOLSIVWC` case was
  vacuous, and it did not address current-checkout native coercion. The
  non-vacuous fixture is covered by the follow-up below.

  **Checked-in wiring test, 2026-10-15:**
  `R/package_tests/testthat_bulk/test-randomization-fast-path-wiring-reference.R`
  now exercises all 18 concrete fast-path class cases (including both Bai
  variants and `InferenceRandCustom`) using each inference object's generated
  50-permutation object, and compares the fast distribution to the reused-
  worker result at `1e-10`. Focused command
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-randomization-fast-path-wiring-reference.R")'`
  passed against installed EDI 1.0.3. **Final fixture/acceptance follow-up,
  2026-10-16:** the checked-in test uses a deterministic n=20 KK14 design
  (design/response seed 1; permutation seed 1) for KK OLS-IVWC; all 50
  `InferenceContinKKOLSIVWC` results are finite and match the reused-worker
  output at `1e-10`. The file also checks the Simple-Wilcoxon R6 p-value
  against its fast-kernel distribution at n=r=1000: both are `0.002` (ratio
  1.0, 1000/1000 finite draws). Final focused run against installed EDI 1.0.3
  passed 79 assertions with 0 failures and 0 warnings, including the direct-
  wrapper source audit. The existing pre-push
  `test-inference-class-wiring-completeness.R`
  audit was broadened to reject missing callable Rcpp wrappers referenced by
  instantiated fast-randomization methods; its focused installed-package run
  passed 10 assertions with no failures. `InferenceCountPoisson` has no
  class-defined `compute_fast_randomization_distr` in installed EDI 1.0.3,
  matching TODO-3's delete-the-dead-method choice. The KK OLS-IVWC non-vacuous
  fixture gap and the checked-in wiring-test/pre-push structural gates are
  resolved. **Source-only Rcpp registration assertion, 2026-10-16:** the
  wiring test now parses each direct fast-path wrapper's `.Call` target and
  checks for its generated registration row in checkout `src/RcppExports.cpp`;
  the focused installed-package run passes 152 assertions. This catches
  source-level wrapper/registration drift but does not by itself validate a
  rebuilt current-head shared library; the installed-package rerun below
  supplies that runtime evidence.

  **Installed-package rerun, 2026-10-16:** after the user-reported rebuild,
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-randomization-fast-path-wiring-reference.R", package = "EDI")'`
  passed all 152 assertions against `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`
  (EDI 1.0.3; `edi_build_info_cpp()` timestamp `2026-10-16 18:00:39 IDT`).
  The installed-package
  `R/EDI/tests/testthat/test-inference-class-wiring-completeness.R` also passed
  all 10 assertions.
  The installed build timestamp is later than checkout HEAD
  `6a9b91c4231853de1a14ab935beb2349ca9a189a` (17:50:36 IDT), and the checkout
  had no source changes at test time. The package does not embed its source
  commit, so there is no exact build-SHA attestation. Given the user's report
  that they rebuilt this checkout and the post-HEAD build timestamp, this is
  accepted as current-head native coercion/symbol-mapping validation; release
  TODO-64 is closed, with the provenance caveat retained.

  **CI artifact/readiness audit, 2026-10-16:** the successful
  `test-bulk-non-cran` run `38808821543` is on HEAD
  `430c19bcdb0702d998c79f9058c449449034134c`. Its `build` job installed that
  commit into an isolated library, archived the installed library and compiled
  objects as artifact `edi-build`, and the correctness shards passed. The
  successful full `test-coverage` run `38808821546` and
  `test-coverage-R-advanced` run `38808821369` are also on that HEAD. These
  runs establish that CI built the committed native source, but do NOT close
  this targeted parity gate: neither the focused
  `R/package_tests/testthat_bulk/test-randomization-fast-path-wiring-reference.R`
  nor the expanded `test-inference-class-wiring-completeness.R` was present
  at commit `430c19bc` or executed by those runs. Both tests are tracked at
  current HEAD and passed in the post-HEAD installed-package rerun above;
  the old CI artifacts are not used as evidence for that rerun.
  Existing tracked IVWC combination tests and OLS-OneLik fast/worker parity
  tests are not a substitute for the non-vacuous `InferenceContinKKOLSIVWC`
  fast-path/worker fixture. `R-CMD-check` run `38808821525` on the same HEAD
  was still in progress at this audit; it likewise cannot include those
  untracked/local test edits.

  **Non-compiling artifact option (superseded):** an earlier audit proposed
  downloading and extracting artifact `edi-build` from run `38808821543` into
  `/tmp`. It was not used; the post-HEAD installed-package rerun above supplied
  native execution evidence without downloading or compiling locally.

  **Placement rationale:** this is a bulk-tier dispatch-parity test: the
  existing `test-inference-class-wiring-completeness.R` only checks structural
  promises and runs no inference, while
  `test-kk-ols-one-lik-fast-randomization-distr-reused-worker-reference.R`
  covers only the one-likelihood class with its independent refit reference.
  Neither is a suitable home for 18 classes × 50 permutation refits. The new
  test checks the TODO's fast-path/worker wiring contract; class-specific
  independent numerical references remain in their existing focused files.

## Acceptance

No class's fast path errors on the dispatcher's own permutation object;
`InferenceAllSimpleWilcox` R6 p-value within 1.1x of its kernel at
n = r = 1000; `InferenceCountPoisson` either has a working kernel or no
fast-path method; TODO-5 in the pre-push structural gates.
