# Fix: `InferenceIncidModifiedPoisson`'s non-robust SE was severely over-conservative

> **Depends on:** nothing architectural. A pure R-side variance correction
> computed from quantities `fast_poisson_regression_with_var_cpp` already
> returns; no C++ change, no kernel change. **Status: CORE FIX IMPLEMENTED,
> 2026-10 (same session that found it); release follow-up open.**

Found 2026-10, via a `comprehensive_tests.R`-based investigation into why
incidence-response power looked unexpectedly low across every design, not a
user bug report. The class's own roxygen documentation already flagged this
as a known, intentional approximation (a "Caveat" paragraph naming Zou's
(2004) robust/sandwich correction as the thing this implementation did not
do), but nobody had measured how severe that approximation actually was.

## Symptom

Measured directly: incidence response, `Bernoulli` design,
`model_formula = ~.`, asymptotic Wald test (`compute_asymp_two_sided_pval`)
— **4 rejections out of 1,560 replicates at a true null, 0.26% empirical
Type-I error against a nominal 5%**, roughly 20x under nominal. Median
p-value 0.63 instead of the 0.5 a calibrated null should show. This showed
up identically in both the pooled historical `comprehensive_tests_*.csv`
corpus and a fresh live repro on current code, ruling out stale/pre-fix
data as the explanation.

## Root cause

The class fits Zou's (2004) "modified Poisson" working model: a Poisson
log-likelihood maximized on a genuinely binary (incidence) response, valid
as an estimating equation for the conditional mean regardless of the true
outcome distribution, but the Poisson working model assumes
\(\mathrm{Var}(Y_i) = \mu_i\), while the true response is Bernoulli with
\(\mathrm{Var}(Y_i) = p_i(1-p_i) \le \mu_i\). The implementation used the
ordinary model-based Poisson Fisher-information SE
(`fast_poisson_regression_with_var_cpp`'s `ssq_b_j`) directly, which
inherits that variance assumption and so **overstates** the true sampling
variance — an over-conservative, under-rejecting test. Zou's (2004)
original proposal exists specifically to correct this via a robust/sandwich
variance estimator, which this class never applied despite documenting the
gap.

## Fix (implemented and verified, 2026-10)

Computed the robust sandwich correction entirely in R, in
`private$apply_robust_sandwich_variance()`
(`R/EDI/R/inference_incidence_modified_poisson.R`), called from
`generate_mod()`'s variance-computing branch. Every input it needs is
already returned by the existing C++ fit with no kernel change: `mu`
(fitted values, for the raw residual `y - mu`) and `fisher_information`
(the unrestricted \(p \times p\) information matrix \(X'WX\), not yet
inverted — this call site never passes `fixed_idx`/`fixed_values`, so it
always spans every fitted coefficient). `bread = solve(fisher_information)`
is the naive covariance; `meat = X' \mathrm{diag}(\mathrm{resid}^2) X` is
the standard HC0 sandwich correction; robust \(\mathrm{Var}(b) = \mathrm{bread}
\cdot \mathrm{meat} \cdot \mathrm{bread}\). The helper overwrites
`ssq_b_j`/`ssq_b_2` on the fit object with the robust value before
returning, so the existing generic SE-caching layer
(`inference_all_abstract_asymp_lik_std_mod_cache.R`'s `shared()`, shared by
many other classes, left untouched) picks it up transparently. Falls back
to the already-computed naive `ssq_b_j`/`ssq_b_2` if the bread matrix can't
be inverted — this must never be the thing that turns an otherwise-estimable
fit into a crash.

Also declared the new private method in both places this codebase's
component-registry contract check requires it (a real integration bug hit
and fixed during implementation, not a design choice):
`inference_incidence_modified_poisson.R`'s class-level `overrides$private`
list, and `contracts_mixins.R`'s `provides_private_methods` manifest for
the `IncidenceModifiedPoissonLikelihood` component. Without both, the
component fails to load with "private method contract mismatch after load."

Rewrote the class's roxygen documentation (`initialize`,
`compute_asymp_confidence_interval`, `compute_asymp_two_sided_pval`, and the
class-level doc) to describe the corrected behavior and state plainly that
this is a **result-changing fix**: every standard error, confidence
interval, and p-value this class has ever returned differs from this
version's.

## Verification

- `pkgload::load_all(".", compile = FALSE)` only throughout — no install, no
  recompile, per this repo's standing rule against full `R/EDI` rebuilds.
- Confirmed the correction moves in the expected direction on an identical
  fit: naive SE 0.247, robust SE 0.178 (≈72% of the original) — smaller,
  not larger, consistent with the naive variance overstating the truth.
- Fresh 500-replicate null simulation with the fix in place: empirical
  Type-I error moved from the pre-fix 0.26% to **7.2%**; median p-value
  moved from 0.63 to **0.46**. Both now sit near nominal instead of nowhere
  near it.
- Existing dedicated test
  (`test-incidence-modified-poisson-bootstrap-fast-path.R`) still passes;
  it exercises the bootstrap-weighted estimate path only, which
  `compute_estimate_with_bootstrap_weights` already sets SE to `NA` on
  regardless, so this fix doesn't touch it.
- `test-incidence-modified-poisson-robust-sandwich.R` exercises the public
  fit, independently reconstructs the HC0 sandwich from the fitted mean and
  Fisher information, checks both stored variance aliases and the cached
  standard error, and proves the result differs from the naive variance.
- Deliberately **not** changed: `get_likelihood_test_spec()` and
  `simulate_under_lik_null()`, which back score/LR/gradient tests this
  class explicitly disables (`supports_likelihood_tests()` is hard
  `FALSE`, `get_supported_testing_types_impl()` returns `"wald"` only) —
  unreachable through the public API, out of scope for an asymptotic-SE fix.

## Not done this session

- `comprehensive_tests.R`'s historical result CSVs (and the
  `comprehensive_tests_size.csv`/`_power.csv`/etc. aggregates derived from
  them) were **not** regenerated. They still reflect the pre-fix behavior
  measured above; a fresh run is needed before this class's numbers in any
  published benchmark or coverage report can be trusted.
- No full `R CMD check` or full package test-suite run; those remain
  release-wide gates rather than subtasks of this fix.
- The release note, generated Rd synchronization, and direct deterministic
  sandwich regression were completed by the 2026-10-07 finished-item audit.
- Focused installed-package follow-up on 2026-10-14: the public-fit sandwich
  regression passed all 5 assertions. A 25-replicate Boston null Wald replay
  regenerated 100 p-value rows and 100 CI rows across the two model formulas
  and two design formulas: p-value rejection rates were 0.04, 0.08, 0.04,
  and 0.04; CI coverage was 0.92–0.96. This supports the corrected behavior
  but writes only a filtered CSV. It does not regenerate the canonical
  historical result CSVs or their derived aggregates, so TODO 6 remains open.

**External process-exit receipt gate, 2026-10-21:** the comprehensive runner's
schema-v2 RDS sidecar records command arguments, before/after package/source/
DLL identities, result-file identity, and optional attempt-manifest identity,
but it cannot record its own terminal process exit status. The sidecar is
written only on the normal completion path. The `fork=FALSE` watchdog obtains
the worker's `processx::get_exit_status()` and propagates it through the outer
R process's `quit(status=...)`, but its temporary watchdog directory is removed
on return and no durable success-exit receipt is retained by the runner.
Therefore a completed-looking CSV/heartbeat (or even a provenance sidecar)
alone does not prove exit 0. For the future isolated TODO-6 regeneration, retain
an external supervisor receipt in the same fresh `/tmp` run directory with the
exact command/arguments and relevant environment, parent/worker PIDs, UTC
start/end, terminal exit code, stdout/stderr log paths and SHA-256 hashes, and
paths plus SHA-256 hashes for the result CSV, schema-v2 provenance sidecar,
and attempt manifest. Accept the run only with a terminal exit code of 0,
complete/stable sidecar provenance, and a passing exact-key/status/value audit.
A killed/timed-out process or missing receipt is partial evidence and must not
be merged or used to replace canonical aggregates. This is a run-bundle
requirement, not a request to change the runner's in-process provenance schema;
no workload or result artifact was created for this note.

**External receipt wrapper contract, 2026-10-21:** the reusable
`R/package_tests/comprehensive_external_process_receipt.R` helper and
`R/package_tests/run_comprehensive_with_receipt.R` CLI write an atomic external
running marker and terminal receipt with command/arguments, PID, UTC bounds,
exit status, and stdout/stderr paths, byte counts, and SHA-256 hashes. The CLI
accepts `NAME=value` environment overrides; the helper converts these to the
named vector required by `processx` for child launch while preserving the
original `NAME=value` vector in receipt provenance. After diagnosing the
initial CLI failure (`processx` rejected the unnamed override vector), the
focused stub-child contract test passed 31 expectations with installed EDI
1.0.3 (exact command:
`Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-external-process-receipt-contracts.R", reporter="summary")'`). It exercised only the helper/CLI and a short stub child, not an EDI workload, build, or install. The receipt remains external to the runner's schema-v2 sidecar and has not yet been exercised on an authorized TODO-56 run. TODO-56 still requires a fresh isolated run bundle, terminal exit 0, complete sidecar provenance, and exact key/status/value audit.

**Read-only process/artifact recheck, 2026-10-21:** `ps -C R -C Rscript`
showed no live R/Rscript process, and `lsof +D` found no open handles in the
candidate tree or either retained `/tmp/edi-todo56-slice6*` directory. The
broad historical slice-6 run is terminal with exit 143; its runner log and
heartbeat end at 2026-10-18 11:09:00 and 11:09:25. The separate
`/tmp/edi-todo56-slice6-target.lnaz88/results/comprehensive_tests_results_nc_1_incidence_filtered_design-Bernoulli_class-InferenceIncidModifiedPoisson_family-rand.csv`
contains 152 all-`ok` rows, including the 16 canonical target IDs and 136
additional IDs, but no terminal receipt. It is retained evidence only and must
not be merged. `/tmp` currently has 16 GiB free; the exact 16 IDs/argv remain
owner-gated. Do not restart the broad run. A future bounded run requires the
confirmed 16-key scope, fresh `/tmp` output, external terminal receipt,
complete schema-v2 provenance, and exact key/status/value reconciliation.
No process was started or stopped and no result artifacts were changed in
this audit.

## Files changed

- `R/EDI/R/inference_incidence_modified_poisson.R`
- `R/EDI/R/contracts_mixins.R`

## TODOs

- [x] TODO-1: Diagnose and confirm the severity of the naive-SE
  miscalibration via live repro (not just historical pooled data).
- [x] TODO-2: Implement Zou's (2004) robust/sandwich correction in pure R,
  reusing existing C++ outputs, no kernel change.
- [x] TODO-3: Declare the new private method in both required manifests;
  confirm the component loads via `pkgload::load_all(compile = FALSE)`.
- [x] TODO-4: Verify the fix moves empirical Type-I error toward nominal via
  a fresh, independent null simulation (not the same data used to find the
  bug).
- [x] TODO-5: Update the class's roxygen documentation to describe the new
  behavior and flag the result-changing nature of the fix.
- [ ] TODO-6: Regenerate `comprehensive_tests.R`'s historical result CSVs
  (and the derived `comprehensive_tests_size.csv`/`_coverage.csv`/
  `_mse.csv`/`_power.csv` aggregates) so this class's numbers reflect the
  fix rather than the pre-fix behavior.
- [x] TODO-7: Record the result-changing correction in `R/EDI/NEWS.md`.
- [x] TODO-8: Synchronize both generated Rd files with the corrected roxygen
  text without running a package build.
- [x] TODO-9: Add a deterministic public-fit regression that independently
  recomputes the HC0 sandwich variance and proves it differs from the naive
  Fisher-information variance.
