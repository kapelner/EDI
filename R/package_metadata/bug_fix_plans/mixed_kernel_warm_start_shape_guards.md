# Mixed-kernel warm-start shape guards

**Release target:** v1.0.5 TODO-38. This plan records the sibling sweep that
remained after the ZOIB heap-overflow fix. The shared test-comment audit is
historical input; this file is the implementation and validation record.

## Audit result

The ten sites named by the original static sweep reduce to these cases:

- `fast_zero_one_inflated_beta.cpp` already validates the parameter-vector
  length, Fisher-information dimensions, and row alignment.
- The count-only entry in `fast_hurdle_negbin.cpp` already calls
  `validate_truncated_negbin_inputs()` before assigning the supplied start.
- The full hurdle negative-binomial entry and seven other kernels had either a
  direct unchecked assignment or silently ignored a malformed start:
  Gaussian LMM, hurdle-Poisson GLMM, logistic GLMM, ordinal GLMM, Poisson GLMM,
  Weibull frailty, and zero-augmented Poisson.

The affected kernels now reject short, long, non-finite, and wrongly shaped
caller inputs before the optimizer or an Eigen expression can consume them.
The zero-augmented-Poisson R wrapper retains its established exception contract:
it returns a failed diagnostic result whose `exception_message` records the
shape error.

The unreferenced R helper `.fit_zero_one_inflated_beta()` also supplied a start
whose length only happened to fit a one-column auxiliary design. Its start,
parameter names, and numerical Hessian likelihood now use both full
`X_zero_one` coefficient blocks.

## TODOs

- [x] **TODO-1: Audit all ten listed sites.** Classify pre-existing guards and
  identify the eight kernel entry points needing a change.
- [x] **TODO-2: Guard the native inputs.** Validate `warm_start_params` length
  and finiteness and `warm_start_fisher_info` dimensions and finiteness before
  fitting.
- [x] **TODO-3: Repair the orphaned R helper.** Construct the full two-block
  inflation start and evaluate the matching covariate-dependent likelihood in
  its Hessian fallbacks.
- [x] **TODO-4: Add focused regression coverage.** The mixed-kernel test covers
  short and long parameter starts plus rectangular Fisher matrices at every
  affected export; the helper tests cover multi-column auxiliary designs and
  the generalized likelihood.

  **Finite-value regression extension (2026-10-20):** the existing mixed-kernel
  fixture now also checks NaN parameter starts and infinite Fisher entries for
  all seven sibling exports, plus the zero-augmented-Poisson wrapper's
  `exception_message` contract for both inputs. The test file passed 39
  assertions against installed EDI 1.0.3. This checks the test fixture and
  installed API behavior only; it does not validate the current checkout's
  native library. Current-head rebuilt-native, ASAN/UBSAN, and Valgrind gates
  remain open below.
- [ ] **TODO-5: Validate the rebuilt native artifact.** A matching EDI 1.0.3
  native install is now recorded in release TODO-63 (DLL SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`).
  The mixed-kernel warm-start shape-guard test passed 23 assertions against
  that install (recorded with TODO-63), and the ZOIB input-validation test
  passed 9 expectations on 2026-10-20. The affected kernel-equivalence tests
  remain to be run against the matching artifact.
  **Installed helper-reference recheck 2026-10-20:**
  `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-zoib-start-value-construction-reference.R")'`
  passed all 12 assertions against EDI 1.0.3. This exercises the public
  package's `.build_zoib_start()` helper contract and independent logistic-fit
  reference; it is not a fit/kernel-equivalence test and does not close the
  current-checkout native, sanitizer, Valgrind, or comprehensive-result gates.
  **Installed ZOIB-kernel reference recheck 2026-10-20:**
  `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-zoib-mixed-likelihood-reference.R")'`
  passed all 31 assertions with 0 failures, warnings, or skips against EDI
  1.0.3. The loaded DLL was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`, matching
  the native install recorded under TODO-63. This validates the installed
  ZOIB likelihood/reference path only; it does not validate the current
  checkout's native code or close the sibling-kernel, sanitizer, Valgrind, or
  comprehensive-result gates.
  **Checkout-R helper recheck 2026-10-20:** with
  `pkgload::load_all("R/EDI", compile=FALSE)`,
  `test-zoib-start-value-construction-reference.R` passed 12 assertions and
  `test-zoib-fit-vcov-hessian-fallback-rungs-reference.R` passed 11 (23 total;
  zero failures, warnings, or skips). These exercise checkout R helper behavior:
  multi-column auxiliary start construction and the mocked native fit/Hessian
  fallback ladder. They do not call the real ZOIB native optimizer. The
  available cached/installed `EDI.so` had SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`, but
  neither test relies on it for its assertions. This adds R-source evidence
  only; rebuilt-native validation, ASAN/UBSAN, Valgrind, and comprehensive-CSV
  reconciliation remain open.
  **Latest installed-artifact input-guard recheck, 2026-10-20:** against
  installed EDI 1.0.3, `test-mixed-kernel-warm-start-shape-guards-reference.R`
  passed 39 expectations and
  `R/EDI/tests/testthat/test-zoib-kernel-input-length-validation.R` passed 9
  (no failures, warnings, or skips). The installed `EDI.so` SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` is
  byte-identical to checkout `R/EDI/src/EDI.so`; no compilation or install was
  performed. This refreshes input-guard evidence for the available native
  artifact only. It does not run the affected-kernel equivalence suite or
  establish a source/build manifest. TODO-5 kernel-equivalence validation,
  TODO-6 ASAN/UBSAN and Valgrind, and comprehensive-CSV reconciliation remain
  open.
  **Additional valid-start reference case, 2026-10-20:** the focused
  `test-zero-augmented-poisson-kernels-score-hessian-fit-and-pscl-reference.R`
  now repeats both zero-inflated and hurdle Poisson fits with correctly shaped
  caller-supplied starts, checking convergence, coefficients, and log
  likelihood against `pscl::zeroinfl` / `pscl::hurdle`. The installed-package
  run passed 27 expectations with no failures (six existing `.Names`
  deprecation warnings). Installed EDI 1.0.3's DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` matched
  the checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This adds a valid-fit reference
  for the zero-augmented-Poisson sibling only; it does not close the remaining
  affected-kernel equivalence, sanitizer/Valgrind, or comprehensive-CSV gates.
  **Checkout-R Poisson-GLMM equivalence recheck 2026-10-20:** with
  `pkgload::load_all("R/EDI", compile=FALSE)`,
  `test-glmm-cpp-equivalence.R` passed all 14 expectations (0 failures,
  warnings, or skips). The file compares `fast_poisson_glmm_cpp` with
  `lme4::glmer` and checks a correctly shaped caller-supplied warm start; the
  same run also exercised its existing logistic and hurdle-Poisson cases.
  The loaded namespace path was the checkout `R/EDI`; the temporary loaded
  DLL copy had SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  matching the existing checkout `R/EDI/src/EDI.so`. No compilation or
  installation occurred. This is a focused reference pass using the
  available native artifact, not proof that it was built from current native
  source; other affected-kernel equivalence, memory-tool, and comprehensive-
  CSV reconciliation gates remain open.
  **TODO-5 provenance audit and additional references, 2026-10-20:** three
  prior sequential `pkgload::load_all("R/EDI", compile=FALSE)` test runs
  passed: `test-hurdle-negbin-kernel-pscl-agreement-and-variances-reference.R`
  (29 assertions, 0 failures; 11 existing `pscl` `.Names` deprecation
  warnings), `test-poisson-glmm-fit-quadrature-convergence-and-glmer-agreement-reference.R`
  (29 assertions, 0 failures/warnings/skips; `glmer` plus exact marginal-NLL
  reference), and
  `test-survival-kk-weibull-normal-frailty-class-matches-frailty-kernel-reference.R`
  (7 assertions, 0 failures/warnings/skips; class/kernel comparison plus
  `survreg` reference). These are checkout-R overlay results using the
  pre-existing native artifact; no compilation or install was performed.
  The test outputs identify EDI 1.0.3 but did not persist a per-run loaded-DLL
  sidecar.

  At this audit, HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and the
  affected C++ sources were clean in the worktree. Checkout
  `R/EDI/src/EDI.so` and installed
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` are both
  14,727,184 bytes with SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  The installed package reports EDI 1.0.3, `Built: R 4.7.0; x86_64-pc-linux-gnu;
  2026-10-20 07:40:04 UTC`, and the DLL mtimes are 10:40:08 +0300. The HEAD
  commit predates that build timestamp, as do the affected source-file mtimes.
  This is evidence that the two available binaries are identical and were
  timestamped after the current C++ sources; it is not a reproducible build
  manifest tying the DLL to this exact HEAD/toolchain/flags, nor per-test proof
  of which DLL path was loaded. TODO-5 therefore remains open for a recorded
  current-HEAD native build/source manifest and complete affected-kernel
  equivalence validation; the compile-free references do not close it.
  **TODO-5 artifact capture checklist (compile not performed):** when an
  authorized rebuild is available, keep one provenance record with (1) the
  checkout HEAD plus clean/dirty status and SHA-256 hashes of the affected
  native source files; (2) R/platform and compiler/toolchain identity, the
  exact build command and relevant flags (including `EDI_UNITY=0`); (3) the
  installed package version/path and `Built` metadata; (4) full paths and
  SHA-256 hashes for both the produced `EDI.so` and the DLL actually loaded by
  each focused test process; and (5) exact test commands and per-file
  pass/fail/warning summaries for the malformed-input and independent
  equivalence fixtures. Matching DLL hashes establish artifact identity, not
  source/build attestation by themselves. Do not mark TODO-5 complete until
  that record ties the tested binary to the authorized build and all required
  equivalence cases pass.
- **Source-derived comprehensive reconciliation targets (2026-10-20; no run):**
  `run_tests_for_response()` dispatches the affected production kernels through
  these concrete inference labels. For the four KK classes, the runner emits
  separate `model_formula=~1` and `model_formula=~.` labels; the non-KK count
  classes use the same two paths. The survival class is selected once per
  current design formula. These are class/response targets, not a claim that
  one output row corresponds to one kernel call:

  | Kernel | Response | Comprehensive inference class | Design/formula scope |
  |---|---|---|---|
  | `fast_gaussian_lmm_cpp` | continuous | `InferenceContinKKGLMM` | KK14, KK21, KK21stepwise, FixedBinaryMatch; `~1`, `~.` |
  | `fast_poisson_glmm_cpp` | count | `InferenceCountKKGLMM` | KK14, KK21, KK21stepwise, FixedBinaryMatch; `~1`, `~.` |
  | `fast_hurdle_poisson_glmm_cpp` | count | `InferenceCountKKHurdlePoissonOneLik` | KK14, KK21, KK21stepwise, FixedBinaryMatch; `~1`, `~.` |
  | `fast_ordinal_glmm_cpp` | ordinal | `InferenceOrdinalKKGLMM` | KK14, KK21, KK21stepwise, FixedBinaryMatch; `~1`, `~.` |
  | `fast_zero_augmented_poisson_cpp` | count | `InferenceCountZeroInflatedPoisson`, `InferenceCountHurdlePoisson` | non-KK designs; `~1`, `~.` |
  | `fast_hurdle_negbin_cpp` / `fast_hurdle_negbin_with_var_cpp` | count | `InferenceCountHurdleNegBin` | non-KK designs; `~1`, `~.` |
  | `fast_weibull_frailty_cpp` | survival | `InferenceSurvivalGLMMWeibullFrailtyNormalOneLik` | KK survival class selector; current design formula |

  `fast_logistic_glmm_cpp` has no direct production R inference caller in the
  current checkout (only its Rcpp wrapper, tests, and benchmark references),
  so it has no corresponding comprehensive inference-class row target.
  For each target class/formula, reconcile every runner-emitted `function_run`
  operation (including `compute_estimate` and applicable test/interval paths),
  retaining the CSV dimensions `dataset`, `response_type`, `design`,
  `inference_class`, `function_run`, `beta_T`, and replicate. The runner's
  `case_id` intentionally omits `beta_T` and replicate, so it is insufficient
  as the sole row key; use the runner's `id`, which includes both, for exact
  anti-joins. Operation rows vary by class capabilities and slow-path
  rules; a full pass must compare the emitted key set/statuses, not just the
  estimate operation. The existing runner supports response/class/test-family
  filters and `EDI_COMPREHENSIVE_RESULTS_DIR`, so a filtered scratch run can
  produce these rows without rebuilding. Such a run would exercise the
  installed EDI artifact only; current-source native provenance still requires
  the separately gated rebuild. No comprehensive run or canonical output was
  produced for this inventory.
- [ ] **TODO-6: Repeat memory-safety validation.** Exercise the exact
  cross-kernel input-guard regression under both CI memory tools, then
  regenerate and reconcile the installed comprehensive CSV. These checks
  inherently require rebuilt native code.

  **Execution/provenance gate (2026-10-20):** the workflow jobs are
  `R-CMD-check-sanitizers` (`R-devel (ASAN/UBSAN)`) and
  `R-CMD-check-valgrind` (`R-devel (valgrind)`) in
  `.github/workflows/R-CMD-check.yaml`. Each builds the checked-out `R/EDI`
  source and runs `RD CMD check`; neither currently invokes the extended
  regression
  `R/package_tests/testthat_bulk/test-mixed-kernel-warm-start-shape-guards-reference.R`.
  That file is outside the package's shipped `R/EDI/tests/testthat` tree, so a
  green job alone does not establish that this extended regression was
  exercised. Before
  treating either memory-tool subgate as passed, make this regression run
  against that job's instrumented package (for example, by wiring its cases
  into the shipped testthat suite or explicitly invoking the file against the
  exact instrumented check build); record the workflow run URL/ID, commit SHA,
  job name, and test summary. The current workflow prints `00install.out` and
  `tests/testthat.Rout(.fail)` on failure, but does not upload these files as
  artifacts; preserve the job logs or add artifact retention if row-level
  diagnosis requires them.

  The regression covers malformed `warm_start_params` and
  `warm_start_fisher_info` for `fast_gaussian_lmm_cpp`,
  `fast_hurdle_negbin_cpp`, `fast_hurdle_poisson_glmm_cpp`,
  `fast_logistic_glmm_cpp`, `fast_ordinal_glmm_cpp`,
  `fast_poisson_glmm_cpp`, and `fast_weibull_frailty_cpp`, plus the
  `fast_zero_augmented_poisson_cpp` wrapper's diagnostic contract. Keep this
  distinct from TODO-5's valid-fit/equivalence references. After both memory
  jobs pass with the focused cases confirmed in their test output, reconcile
  the post-fix comprehensive CSV against its source-strata/key manifest and
  record row dispositions and source/build provenance; a successful sanitizer
  or Valgrind job by itself does not close that data-reconciliation gate.
  **Shipped-suite overlap audit, 2026-10-20:** both workflow jobs run
  `RD CMD check`, which includes the shipped `R/EDI/tests/testthat` suite.
  `test-kernel-warm-start-length-contracts.R` supplies malformed Fisher
  matrices to the affected Gaussian-LMM, both hurdle-NB, hurdle-Poisson GLMM,
  logistic GLMM, ordinal GLMM, Poisson GLMM, Weibull-frailty, and
  zero-augmented-Poisson exports; it also checks malformed `warm_start_beta`
  for Gaussian-LMM, ordinal-GLMM, and Weibull-frailty. It does not supply
  malformed `warm_start_params` to the TODO-38 sibling entries: the file's
  parameter-vector cases instead cover ordinal CLMM and dependent-censoring
  kernels. Thus the CI suite has partial guard overlap, but a green memory job
  would not prove execution of the extended sibling parameter-length cases
  (or its NaN/Inf cases). This is workflow/test inventory, not evidence that a
  sanitizer or Valgrind job passed; TODO-6 remains open pending a run whose
  instrumented test output confirms the required cases.

  **Promoted fast-tier length guards, 2026-10-21:** broadened the existing
  CRAN-shipped `test-kernel-warm-start-length-contracts.R` with short- and
  long-`warm_start_params` cases for all seven sibling kernels and the
  zero-augmented-Poisson wrapper (16 added assertions). Its fresh-process
  installed-package run passed all 220 expectations against EDI 1.0.3; the
  installed and checkout DLLs both hash to
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  Because sanitizer and Valgrind workflows run the shipped testthat suite,
  these primary short/long length checks are now in their normal test path.
  The installed run above predates the follow-up non-finite cases below, and
  does not establish that either memory job ran or passed or authenticate
  current C++ sources to the installed DLL. TODO-5's native
  provenance/equivalence, TODO-6's actual instrumented workflow runs, and
  comprehensive-row reconciliation remain open.

  **Shipped-suite non-finite sibling starts, 2026-10-21:** extended the same
  fast-tier test with correctly sized `NaN` and `Inf` `warm_start_params` for
  each of the seven sibling kernels above (14 guard assertions). These calls
  are rejected at the finite-value input guard before optimization, so the
  sanitizer/Valgrind check jobs' shipped-suite path now includes malformed
  lengths and non-finite parameter starts for these seven exports. This is
  test-inventory evidence only; no R test or instrumented workflow was run at
  the time of this test change. A subsequent installed-artifact recheck is
  recorded below. The extended bulk test's zero-augmented-Poisson diagnostic
  case, non-finite Fisher-info cases, current-source native provenance, actual
  ASAN/UBSAN and Valgrind job results, and comprehensive-row reconciliation
  remain distinct/open gates.

  **Installed non-finite sibling-start recheck, 2026-10-21:** the shipped
  `test-kernel-warm-start-length-contracts.R` passed all 234 assertions in a
  fresh `Rscript` against installed EDI 1.0.3 (0 failures, warnings, or skips;
  exit 0), including the 14 correctly sized NaN/Inf start guards. The loaded
  installed `EDI.so` SHA-256 is
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`, byte-
  identical to checkout `R/EDI/src/EDI.so` (both 14,727,184 bytes). No build,
  compile, or install occurred. This confirms behavior in the currently
  installed artifact and its identity with the checkout's existing binary;
  it does not authenticate that binary to the tracked C++ sources or replace
  the actual ASAN/UBSAN, Valgrind, current-source provenance, equivalence, or
  comprehensive-row gates.

  **Installed valid-fit kernel-reference sweep, 2026-10-21:** seven focused
  reference files passed sequentially through `testthat::test_file()` after
  `library(EDI)`, with no failures: Gaussian LMM (17 assertions), hurdle
  negative-binomial versus `pscl` (29 assertions; 11 upstream `.Names`
  deprecation warnings), GLMM equivalence covering logistic, hurdle-Poisson,
  and Poisson (17), ordinal GLMM versus `clmm` (37), Poisson GLMM versus
  quadrature/`glmer` (29), Weibull frailty versus its class/`survreg` reference
  (7), and zero-augmented Poisson versus `pscl` (27 assertions; six upstream
  `.Names` deprecation warnings). The exact files were
  `test-gaussian-lmm-kernels-score-fisher-gls-and-fit-reference.R`,
  `test-hurdle-negbin-kernel-pscl-agreement-and-variances-reference.R`,
  `test-glmm-cpp-equivalence.R`,
  `test-ordinal-glmm-kernel-clmm-agreement-score-hessian-and-polish-reference.R`,
  `test-poisson-glmm-fit-quadrature-convergence-and-glmer-agreement-reference.R`,
  `test-survival-kk-weibull-normal-frailty-class-matches-frailty-kernel-reference.R`,
  and `test-zero-augmented-poisson-kernels-score-hessian-fit-and-pscl-reference.R`.
  The process reported installed EDI 1.0.3 and loaded
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  This extends valid-fit independent-reference coverage across the sibling
  kernel families; it does not establish exact current-checkout C++ provenance,
  exercise malformed starts under a memory tool, or reconcile comprehensive
  rows. TODO-5's current-head native/source manifest and TODO-6's ASAN/UBSAN,
  Valgrind, and comprehensive-row gates remain open.

  **Promoted non-finite Fisher and ZAP diagnostic guards, 2026-10-21:** the
  shipped `test-kernel-warm-start-length-contracts.R` now also checks correctly
  sized infinite Fisher matrices for all seven sibling kernels and the
  zero-augmented-Poisson wrapper, plus the wrapper's diagnostic messages for
  non-finite parameter and Fisher starts (9 assertions). The focused shipped
  test passed all 243 expectations against installed EDI 1.0.3; the loaded
  DLL was `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`,
  SHA-256 `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  This verifies the test and installed-artifact behavior only: no compilation,
  installation, ASAN/UBSAN, or project Valgrind CI job was run, and the hash
  does not establish that the installed native binary was built from the
  current checkout C++ sources. Current-source provenance and the two
  instrumented workflow results remain open.

  **Checkout-R/current-native valid-fit reference rerun, 2026-10-21:** the
  seven focused references above were rerun with
  `pkgload::load_all("R/EDI", compile=FALSE)` against the available native
  artifact. All passed: Gaussian LMM (17 assertions), hurdle NB/`pscl` (29;
  11 upstream `.Names` deprecation warnings), GLMM equivalence (17), ordinal
  GLMM/`clmm` (37), Poisson GLMM/`glmer` (29), Weibull frailty/`survreg` (7),
  and zero-augmented Poisson/`pscl` (27; six upstream `.Names` deprecation
  warnings), 163 assertions total. The loaded namespace was the checkout
  `/home/kapelner/workspace/EDI/R/EDI`; its temporary DLL SHA-256 was
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`, the
  latest user-built artifact also recorded for the installed guard recheck.
  No compilation, build, or install occurred. This adds independent valid-fit
  coverage using checkout R code and that native artifact; it is not a
  reproducible source/build manifest, a malformed-start memory-tool run, or
  comprehensive-row reconciliation. TODO-5 provenance/equivalence and TODO-6
  ASAN/UBSAN, Valgrind, and comprehensive-row gates remain open.

  **Native artifact/memory-job audit, 2026-10-21:** the latest successful
  `R-CMD-check` run visible in GitHub Actions is run `39110868823`, at commit
  `4d2531e97bc0636d3409003576a5766d15a308d0` (2026-10-18). Its R-devel
  ASAN/UBSAN job (`117626532715`) and R-devel Valgrind job (`117626532797`)
  both completed successfully and built the checked-out package. The eight
  affected C++ source files have identical Git contents between that commit
  and current HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; however, this
  run predates the 2026-10-21 additions to the shipped malformed-start test,
  so those jobs did not exercise the newly added sibling `warm_start_params`
  cases. Fresh memory-tool jobs whose test output confirms those cases remain
  required.

  The current installed and checkout `EDI.so` files are byte-identical
  (14,727,184 bytes; SHA-256
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`). The
  installed package reports EDI 1.0.3, built 2026-10-21 11:12:19 UTC. Current
  generated build metadata reports 2026-10-21 14:12:19 IDT on
  `LAPTOP-J2T9TGGB`, R-devel, g++/gnu++20, and `EDI_UNITY=1`; current Makevars
  lists `unity_01.o` through `unity_10.o`. These are non-attested user-build
  metadata and artifact identity only: neither the metadata nor matching DLL
  hashes bind the tested binary/object files to source hashes, and they do not
  substitute for a reproducible TODO-5 source/build manifest. Retained local
  TODO-38 Valgrind logs are not passing evidence: one is only an invocation
  banner without a test summary, while the direct-R attempt fails during
  startup loading `tools.so` (`undefined symbol: Rf_strchr_const`) before EDI
  tests execute; its zero-error Memcheck summary is therefore vacuous. TODO-5
  current-source provenance/equivalence and TODO-6 fresh ASAN/UBSAN, Valgrind,
  and comprehensive-row reconciliation remain open.

  **Malformed-start coverage versus retained memory jobs, 2026-10-21:** the
  current shipped test file
  `R/EDI/tests/testthat/test-kernel-warm-start-length-contracts.R` has SHA-256
  `c938ce677076ac16df6d9de6700922cc3a8e967c941d277b1ef51f319dfd866c`; it
  differs from current HEAD by 184 insertions and 8 deletions. The current
  additions cover short/long and correctly sized non-finite
  `warm_start_params` for the seven sibling kernels, plus the zero-augmented-
  Poisson wrapper diagnostics. The retained successful ASAN/UBSAN and
  Valgrind run `39110868823` used commit `4d2531e97bc0636d3409003576a5766d15a308d0`;
  its shipped-test SHA-256 is `18af939b192e9e008464f81b649ea2e97bf6f0aa2a7d212fa2ee145529db8aaa`,
  matching current HEAD but not the current worktree test file. Those jobs
  therefore do not cover the added malformed-start cases, even though their
  eight affected C++ files match through HEAD. The retained 243-expectation
  installed-package pass is not memory-instrumented, and its run record lacks
  the test-file hash needed to tie it to this exact worktree version. The two
  local TODO-38 Valgrind logs also remain unusable: the first has only the
  invocation banner and no test summary; the second fails loading `tools.so`
  with `undefined symbol: Rf_strchr_const` before the tests, making its zero-
  error Memcheck summary non-evidence. To close TODO-6, commit the test cases
  and obtain fresh ASAN/UBSAN and Valgrind jobs whose exact commit and test
  output confirm execution. Separately, TODO-5 still requires an attested
  current-source native build/object manifest (with `EDI_UNITY=0`); matching
  DLL hashes and the recorded `EDI_UNITY=1` metadata are insufficient. The
  comprehensive-row reconciliation remains a distinct open gate.
