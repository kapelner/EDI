# `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` Optimizer Stability

> **Depends on:** nothing architectural. Two small, additive changes inside
> the existing Clayton-copula/loggamma-frailty C++ optimizer and its R
> fallback cascade; no public API change. **Release target: v1.0.5**
> (`release_v1_0_5.md → TODO-6`, moved 2026-09-23 from
> `release_v1_1_0.md → TODO-22`, bug-fix/feature split).

Written 2026-09-11, from a comprehensive-test-harness timing investigation
(not a user report). Owning plan for the bimodal-slowness finding
documented in `comprehensive_tests.R`'s BRT-sweep session history.

## Why

Production timing data (20 replicates, same design=KK21stepwise,
dataset=diamonds, `beta_T=0`, `design_formula=~1`) showed
`compute_lik_ratio_bartlett_approx_two_sided_pval()` on this class taking
0.5-1s for 18 of 20 replicates and 178.7s / 159.7s for exactly two (reps 1
and 13) — a ~200x outlier with everything about the scenario identical
except the specific data realization. A read-only investigation (this
session) traced the mechanism; it was not fixed.

## Root cause

`compute_lik_ratio_bartlett_approx_two_sided_pval` →
`InferenceExtBartlettApprox$get_bartlett_factor_approx`
(`inference_ext_bartlett_approx.R:53-94`) runs `B=99` Monte-Carlo null
replicates (`run_param_bootstrap_replicates`,
`inference_all_abstract_param_boot.R:582-696`), each calling
`simulate_under_lik_null` (`inference_survival_GLMM_weibull_frailty_
loggamma.R:840-920`), which does two `fast_clayton_weibull_aft_optim_cpp`
refits (full + null-constrained) per replicate.

Two compounding issues in that C++ optimizer
(`src/fast_survival_models_optim.cpp`):

1. **No bound on the dependence parameter.** The sibling normal-frailty
   optimizer (`fast_weibull_frailty_cpp`, `src/fast_weibull_frailty.cpp:
   319-323,426`) caps its analogous parameter at `max_abs_log_sigma=8.0`
   and uses a looser `eps_g=1e-6`/`maxit=300`. The Clayton/loggamma
   optimizer has no such cap — only `maxit=2000, reltol=1e-9`
   (`:743`) — and its objective merely *clips* `theta=exp(min(log_theta,
   10))` (`:69`) without constraining `log_theta` itself.
2. **Stale-gradient mismatch.** The gradient terms (`:111,121,135,148`)
   still multiply by the *unclipped* `theta` even where the objective used
   the clipped value. Once `log_theta > 10`, this leaves the optimizer
   seeing a persistent nonzero gradient on what is actually a flat
   objective surface, driving it toward the 2000-iteration cap instead of
   terminating.
3. **Cascading fallback only on this family's fit path.**
   `.fit_clayton_weibull_aft` (`helper_survival_fits.R:243-399`), when no
   warm start is cached (true for a fresh replicate object — the common
   case inside the B=99 loop), tries 3 C++ LBFGS starts, then 3 R
   `optim(BFGS)` starts, then 3 R `optim(Nelder-Mead, maxit=10000)` starts.
   The sibling normal-frailty fit (`.fit_weibull_frailty`, same file,
   line 503) is a thin direct pass-through with no cascade. When (1)+(2)
   above leave the C++ starts unconverged, this ladder's R-level
   Nelder-Mead tail is the expensive part.

Assessment (from the investigating agent): a real, data-dependent
numerical-cost bug, not an inherent fixed cost of the loggamma frailty
family — the two normal-frailty asymmetries (bound, gradient consistency)
are the most direct evidence this is fixable rather than structural.

## Proposal

- **TODO-1**: Add an explicit `log_theta` bound to
  `fast_clayton_weibull_aft_optim_cpp` (mirror `max_abs_log_sigma=8.0`'s
  role — same idea, different parameter name/scale; needs its own
  numerically-justified cap, not a blind copy of `8.0`).
- **TODO-2**: Fix the gradient/objective clipping mismatch (`:69` vs.
  `:111,121,135,148`) so both consistently use the clipped `theta` — this
  alone may resolve most of the thrashing even before TODO-1 lands.
- **TODO-3**: After TODO-1/2, re-run this session's production scenario
  (KK21stepwise/diamonds/`beta_T=0`/`~1`, ideally the exact reps 1 and 13
  seeds) to confirm the outlier is gone; if any residual slow tail remains,
  consider tightening `.fit_clayton_weibull_aft`'s fallback cascade (e.g.
  drop or shrink the Nelder-Mead tail's `maxit=10000`) as a second lever.
- **TODO-4**: Decide whether a bounded `log_theta` changes any existing
  golden-test point estimates for this class (expected: no, since a
  well-converged unclipped fit should already sit well inside any
  sane bound — but verify, not assume).

## Tests

- Golden-test parity for `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`
  before/after (point estimate, SE, Bartlett-approx p-value) on existing
  fixtures — must be bit-for-bit or within existing tolerance.
- Targeted timing regression: construct the reps-1/13-shaped scenario (or
  a synthetic data realization known to drive `log_theta` large) and
  assert `compute_lik_ratio_bartlett_approx_two_sided_pval()` completes
  well under the old 178.7s outlier, ideally in the same ~1s range as the
  other 18 reps.
- Sibling-class regression: `InferenceSurvivalGLMMWeibullFrailtyNormalOneLik`
  untouched by this change (different `.cpp` file) — no new test needed,
  just confirm nothing in the shared R dispatch layer moved.

## TODOs

- [x] TODO-1: Bound `log_theta` in `fast_clayton_weibull_aft_optim_cpp`
  (`src/fast_survival_models_optim.cpp`).
- [x] TODO-2: Fix the clipped-vs-unclipped `theta` mismatch between the
  objective (`:69`) and gradient (`:111,121,135,148`).
- [ ] TODO-3: Re-verify the original outlier scenario is resolved; consider
  narrowing `.fit_clayton_weibull_aft`'s fallback cascade if a residual
  slow tail remains. The user's reinstalled native library passes the direct
  upper-bound regression (unsafe start converges before 20 iterations) and
  the failed-fit branch test. **Filtered installed-package timing probe
  2026-10-14:** an isolated copy of `comprehensive_tests.R` was restricted to
  `~1` and run sequentially through rep 13 for the survival /
  KK21stepwise / diamonds / `beta_T=0` Bartlett case. The approx Bartlett
  p-value took 0.359s at rep 1 and 0.380s at rep 13 (p=0.837 and 0.735,
  both `status=ok`), versus the historical 178.7s and 159.7s. Generic
  Bartlett p-values took 10.169s and 0.448s; approx CIs took 4.979s and
  7.494s. This suggests the approx-pval slowdown is gone on these filtered
  draws, but does not reproduce the original production RNG stream: all
  other datasets/designs/classes were filtered out, and rep 13 is the
  thirteenth replicate of this isolated run. A separate two-formula run
  stalled for >5:24 in the generic Bartlett p-value for `~.` and was
  interrupted. Therefore the original outlier and multivariate-tail checks
  remain open; no fallback-cascade retuning is justified yet. The focused
  results are in
  `/tmp/edi-v105-todo6.kCbSHR/R/package_tests/comprehensive_tests_results_nc_1_survival_filtered_design-KK21stepwise_class-InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik_dataset-diamonds_beta-0_family-bartlett.csv`;
  its CSV records heartbeat path `/tmp/RtmpaeuB1H/comprehensive_tests_heartbeat_2.log`
  (R temporary-session path; console output was not separately redirected).
  **Artifact re-audit 2026-10-16:** the retained `/tmp/edi-v105-todo6.kCbSHR`
  tree contains only the filtered `~1` 13-replicate output, filtered two-
  formula rep-1 output, harness/helpers, and no original full-sweep sample
  or seed metadata. Thus the exact historical reps 1/13 cannot be recovered
  from retained artifacts; the prior `~.` stall remains unresolved, and no
  retry was launched.
  **Local raw-output metadata recheck 2026-10-18 (read-only):** the ignored
  `R/package_tests/comprehensive_tests_results_nc_1_survival.csv` (355 MB,
  last modified 2026-09-27) retains row-level run, duration, formula, commit,
  timestamp, and harness settings. It contains other historical
  `compute_lik_ratio_bartlett_approx_two_sided_pval` rows over 100s at
  `design_formula=~.` (rep 20: 213.060s, commit
  `c8d4786e8d56f9e53b4f9a5a38a263f2fdd4f903`; rep 30: 165.243s, commit
  `36368a0e00f9feb5cafb316ed2e161e8fbfac659`), as well as high-duration
  `compute_estimate` rows. These are pre-fix historical observations, not
  post-fix evidence and not the missing original reps 1/13 sample. The CSV
  does not record `.Random.seed`, assignments, or generated outcomes, so it
  cannot recover the exact RNG realization. The remaining acceptance is
  therefore still decision-gated. **Bounded execution proposal (not yet
  authorized):** use dataset `diamonds`, response `survival`, design
  `KK21stepwise`, class
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`, and `beta_T=0` for both
  formulas `~1` and `~.`. For an exact historical replay, target `~1` reps 1
  and 13 and the recorded `~.` rep 1 attempt only if their original per-case
  RNG state and full call context are recovered; the `~.` rep 1 attempt
  stalled in the generic Bartlett p-value, so it is not an observed
  approximate-p-value baseline. Otherwise, request approval for a deterministic
  replacement consisting of one explicitly seeded replicate per formula,
  labeled as replacement data (not historical reps 1/13). For every selected
  formula/replicate, record the point estimate, standard error, and
  `compute_lik_ratio_bartlett_approx_two_sided_pval()` result, including
  non-finite/error outcomes. Save the case-start `.Random.seed` and
  `RNGkind()`, plus R version, dataset/version or row-data hash, harness
  command and source commit, installed EDI version/library path, loaded native
  library path and hash/build provenance, start/end timestamps, per-call
  durations, stdout/stderr, process exit status, and timeout outcome. Run from
  an isolated harness copy with all outputs and logs under a fresh `/tmp`
  directory; apply a hard timeout whose numeric value is approved in advance.
  Before execution, the maintainer must approve the numeric runtime ceiling
  and explicit tolerances for estimate, SE, and Bartlett-p parity for each
  formula. The original replay and replacement are separate evidence paths;
  filtered rows, other historical rows, and a replacement seed cannot stand
  in for the missing historical RNG realization. Do not infer a runtime or
  parity threshold from existing probes.

**Fresh source/DLL provenance recheck 2026-10-18 (read-only):** checkout
`HEAD` is `efdc1b4ebe07c6dc3aadba713b5f5fe0722fdfe1`. The current
`R/EDI/src/fast_survival_models_optim.cpp` SHA-256 is
`c0ce193eaa4a40a511c55dcbce39026e2f35fab7df0a979fb70ee386b352475d`
(mtime 2026-10-18 05:59:22 +0300); its working-tree diff is limited to an
unrelated warm-start length guard in `fast_dep_cens_transform_optim_internal`,
not the Clayton optimizer. The loaded installed package is EDI 1.0.3 from
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; its `libs/EDI.so`
SHA-256 is `23033b395c5167d2e5cb88225084a5af63febe0483671498aaf0808d802a865e`
(MD5 `dd43c5d0e11708aea17ba82b900f66d1`, mtime 2026-10-18 03:57:33 +0300).
The DLL predates the current translation-unit mtime, and it has no recorded
source/build attestation tying it to this checkout. This is a provenance
limitation, not evidence that the Clayton fix is absent: the observed source
diff is outside the Clayton optimizer. No fit or test was run for this
recheck; TODO-56 remains active, the original per-case RNG/outcome context is
unavailable, and the numeric runtime ceiling plus per-formula estimate/SE/
Bartlett-p tolerances still require maintainer approval before the gated run.

- [x] TODO-4: Confirm no golden-test point-estimate drift from the new
  bound. `test-clayton-logtheta-optimizer-bound.R` passed against the
  reinstalled package on 2026-10-14, including the censored fixture's
  parameter vector, treatment estimate, variance, and log-likelihood.

## Implementation record (2026-10-08)

- The native likelihood now applies the same numerically justified upper
  boundary as the established R fallback (`log_theta <= 6`, corresponding to
  Clayton Kendall's tau above 0.995). The independence tail remains open;
  existing valid OneLik fixtures reach `log_theta < -12`, so copying the R
  fallback's lower rejection threshold into the native optimizer would have
  changed ordinary estimates.
- The chain derivative is exactly zero on the clipped part of the objective.
  Returned parameters are normalized to the boundary and the new
  `log_theta_at_upper_bound` diagnostic makes boundary fits explicit in both
  R and Python result dictionaries.
- Deterministic R and Python regressions start above the boundary with every
  other parameter fixed and require convergence before 20 iterations without
  hitting the iteration cap. This directly covers the mechanism behind the
  old 2,000-iteration outliers without adding a wall-clock assertion.
- **Filtered production-shaped timing probe, 2026-10-14:** against the
  already-installed package only, an isolated copy of the comprehensive
  harness was restricted to the `~1` formula and run sequentially through
  rep 13 with the survival/KK21stepwise/diamonds/`beta_T=0`/Bartlett filters.
  `compute_lik_ratio_bartlett_approx_two_sided_pval()` took 0.359s (rep 1)
  and 0.380s (rep 13), both finite and `status=ok`; the historical full-sweep
  rows were 178.7s and 159.7s. The filtered run does not preserve the full
  sweep's RNG consumption, so those rep labels do not prove exact-sample
  parity. A separate two-formula attempt stalled for over 5:24 in the generic
  Bartlett p-value on `~.` and was interrupted. Thus the targeted `~1`
  filtered sample shows no 200x tail, but TODO-3 remains open pending a
  reproducible original full-sweep sample and resolution/measurement of the
  `~.` path. The CSV is at
  `/tmp/edi-v105-todo6.kCbSHR/R/package_tests/comprehensive_tests_results_nc_1_survival_filtered_design-KK21stepwise_class-InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik_dataset-diamonds_beta-0_family-bartlett.csv`;
  its heartbeat path was `/tmp/RtmpaeuB1H/comprehensive_tests_heartbeat_2.log`
  (temporary R session path; stdout was not saved separately). No build or
  installation was performed for this timing check.
- An existing censored-data fit is pinned at its pre-change parameter vector,
  treatment estimate, treatment variance, and likelihood. The Python parity
  fixture independently pins an ordinary in-boundary parameter vector and
  likelihood. These fixtures exercise the unchanged interior surface; the
  Bartlett path uses the same full/null kernel and is covered mechanistically
  by the constrained-refit regression. On 2026-10-14, the user's reinstalled
  package passed the direct bound/golden regression; Codex did not compile or
  install.
