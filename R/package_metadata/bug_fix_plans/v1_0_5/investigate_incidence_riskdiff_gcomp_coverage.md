# Investigate: Incidence RiskDiff/GComp/Wald `low_coverage` Cluster (11 classes, 70 findings)

> Found 2026-09-24, from a dedicated cross-class investigation fork
> triaging `audit_comprehensive_results.R`'s `low_coverage`/`biased_estimate`
> findings for the incidence response type's RiskDiff/GComp/Wald family.
> Mixed confidence — see per-cluster verdicts below.

## Cluster 1 — mostly BENIGN (mild over-coverage), same shape as the already-closed RiskDiff/RiskRatio precedent

`InferenceIncidGCompRiskDiff`, `InferenceIncidGCompRiskRatio`,
`InferenceIncidKKGCompRiskRatio`, `InferenceIncidMiettinenNurminenRiskDiff`,
`InferenceIncidNewcombeRiskDiff` (partially — see Cluster 2),
`InferenceIncidModifiedPoisson`, `InferenceIncidKKGEE`,
`InferenceIncidKKCondLogitOneLik ~1 compute_jackknife_wald` (0.986): all
show mild OVER-coverage (0.965-1.000 vs. 0.95 target) across most
asymptotic and bootstrap-family methods — same shape as this session's
already-closed RiskDiff/RiskRatio `low_power` finding and the parallel
`InferenceIncidLogRegr`/`ProbitRegr` `low_coverage` cluster another fork
is checking. **Likely benign conservativeness, not independently
re-derived here** — deferring to whatever that parallel fork concludes
about the shared mechanism, since the numbers and shape match closely.

**GComp-family TODO-28 note**: `InferenceIncidGCompRiskDiff`/`RiskRatio`/
`KKGCompRiskRatio`'s findings here are mostly mild OVER-coverage, which
argues AGAINST TODO-28 (`cached_design_matrix` staleness) being the cause
— that bug scrambles data/weight correspondence and would be expected to
produce severe, not mild, miscalibration. Not independently verified via
call-graph read (time-boxed out of this pass) — if `release_v1_0_5.md`'s
TODO-28 note on these classes gets resolved elsewhere, cross-check against
this conclusion.

Two smaller `biased_estimate` findings, mild and plausibly benign:
`InferenceIncidGCompRiskRatio ~.`/`~1 compute_estimate` (+0.03/+0.03 mean
bias) and `InferenceIncidKKGCompRiskRatio ~. compute_jackknife_estimate`
(-0.02 mean bias, t-test p=0.08 NOT significant but Wilcoxon p=0.001 IS —
another instance of Wilcoxon catching a tail-driven signal the t-test
misses, same pattern as this session's earlier `InferenceIncidKKGCompRiskRatio`-style
findings). Not investigated further; small effect sizes.

## Cluster 2 — REAL, unexplained: severe under-coverage concentrated in `subsampling`/`m_out_of_n_bootstrap`

`InferenceIncidBinomialIdentityRiskDiff` (~1 and ~., 0.839-0.869
coverage, p as low as 7.97e-19), `InferenceIncidKKCondLogitOneLik ~1`
(0.757, n=107, p=1.45e-11 — the single worst finding in this whole
cluster), `InferenceIncidWald` (`compute_subsampling`, 0.922),
`InferenceIncidRiskDiff ~1` (`compute_subsampling`, 0.912),
`InferenceIncidNewcombeRiskDiff` (`compute_subsampling`, 0.913) all show
their worst under-coverage specifically on `compute_subsampling_confidence_interval`/
`compute_m_out_of_n_bootstrap_confidence_interval`.

**`TODO-28` checked and RULED OUT for `InferenceIncidBinomialIdentityRiskDiff`**:
its `build_design_matrix()` (`inference_incidence_binomial_identity.R:125-131`)
is a custom, uncached implementation reading `private$w`/`private$get_X()`
directly every call — never touches `create_design_matrix()`'s cache, so
immune to that specific bug, despite `supports_reusable_bootstrap_worker()`
returning `TRUE` (`:176-178`, confirmed it does reach the reused-worker
path). Not independently checked for the other 4 classes in this
sub-cluster, but the shared symptom pattern (all worst on the same two
`function_run`s) argues for a shared mechanism.

**Leading unconfirmed hypothesis**: `compute_subsampling_confidence_interval`/
`compute_m_out_of_n_bootstrap_confidence_interval` are a SHARED engine
(`inference_all_abstract_non_param_boot.R:217,337`, not class-specific —
confirmed these 5 classes don't override it, unlike the GComp family which
has its own override at `inference_incidence_gcomp.R:106,125` and shows
the benign pattern instead). Both take a `scaling = "sqrt_n"` parameter
controlling the pivot's scale correction for the subsample/m-out-of-n size
being smaller than `n` — a plausible place for a scaling-exponent bug that
would produce systematically-too-narrow CIs (severe undercoverage) for
whichever classes' asymptotic rate doesn't match the assumed `sqrt(n)`
default (e.g. boundary-constrained identity-link/logit estimators). **Not
verified** — the engine's actual scaling-application code
(`compute_subsampling_confidence_interval_impl`/
`compute_m_out_of_n_bootstrap_confidence_interval_impl`, private methods,
not yet read) needs a dedicated read to confirm or refute this.

Separately, `InferenceIncidWald compute_bayesian_bootstrap_confidence_interval_studentized`
shows severe under-coverage (0.874, n=1099, p=1.64e-22) — NOT in the
`subsampling`/`m_out_of_n` family, so likely a different, unrelated
mechanism; not investigated.

## Deprioritized (small counts, 1-2 findings each, not investigated)

`InferenceIncidKKGEE` (1 finding), `InferenceIncidMiettinenNurminenRiskDiff`
(2, already noted benign above).

## TODO-1/TODO-2 resolved 2026-09-24: scaling-exponent hypothesis REFUTED

Read the actual shared engine in full: `subsampling_centered_pivot()`
(`inference_ext_prw_subsampling.R:344-384`),
`m_out_of_n_bootstrap_centered_pivot()`
(`inference_ext_m_out_of_n_bootstrap.R:312-350`),
`resampling_ci_from_centered_distribution()`/`resampling_centered_pval()`/
`resampling_scaling_factor()` (`inference_ext_exchangeable_resampling_units.R:314-336`).

**The scaling formula is textbook-correct for both families, not a bug**:
- Subsampling: pivot = `fpc * sqrt(b) * (theta_hat_b - theta_hat_n)`,
  CI = `theta_hat_n -/+ quantile(pivot)/sqrt(n)` — exactly the standard
  Politis/Romano/Wolf construction (use `sqrt(b)`-scaled subsample
  replicates to estimate the quantiles of `sqrt(n)*(theta_hat_n - theta)`,
  then invert at the `sqrt(n)` scale).
- m-out-of-n bootstrap: same construction with `sqrt(m)` and no FPC
  (correct — with-replacement resampling needs no finite-population
  correction, unlike PRW subsampling's without-replacement draws).
- **The finite-population correction for subsampling
  (`fpc = 1/sqrt(max(1 - b/n_units, eps))`,
  `inference_ext_prw_subsampling.R:376-383`) is not naive** — its own
  comment cites a specific validating simulation (~9.75% vs. nominal 5%
  Type-I error without it, at `b/n ~ 0.4`) from 2026-09-07, i.e. this
  exact failure mode was already found and fixed once before. The
  algebra checks out by hand too: without-replacement sampling shrinks
  the subsample-pivot's variance by a factor of approximately `(1-b/n)`
  relative to the i.i.d. assumption the base `sqrt(b)` formula requires,
  and `1/sqrt(1-b/n)` is exactly the correction that restores it.

**Conclusion: this hypothesis is REFUTED.** The shared engine is not the
source of Cluster 2's severe under-coverage. Scope stays at the
originally-flagged 5 classes (not broadened), and each needs independent
root-causing — likely candidates worth checking instead: (a) the default
intermediate-size rule (`floor(n_units^0.7)`) may be too small relative
to `p_eff` for some of these classes, inflating finite-sample volatility
even though the formula itself is correct; (b) class-specific refit
convergence-failure asymmetry, the same shape already documented and
fixed for `InferenceIncidKKGEE`'s ~24% GEE-refit-failure case
(`inference_ext_m_out_of_n_bootstrap.R:328-338`) — worth checking whether
any of the 5 flagged classes (especially `InferenceIncidKKCondLogitOneLik`,
the worst offender at n=107) show a similar high-failure-rate pattern at
their resolved `b`/`m`.

- [x] TODO-1 (resolved 2026-09-24, follow-up fork): **REFUTED** for all 5
  Cluster-2 classes, on direct evidence, not inference. Checked the raw
  `comprehensive_tests_results_nc_1_incidence.csv` for NA CI bounds on
  every `compute_subsampling_confidence_interval`/
  `compute_m_out_of_n_bootstrap_confidence_interval` row for these 5
  classes: **0 of 5,986 rows in the cells that actually produced the
  audit's low_coverage findings have NA bounds** — meaning the shared
  engine's already-implemented `>=50%`-finite-fraction gate
  (`inference_ext_m_out_of_n_bootstrap.R:328-338`,
  `inference_ext_prw_subsampling.R:359-365`, both added 2026-09-06) never
  tripped for any of them. The `InferenceIncidKKGEE`-style silent-
  truncation mechanism is not occurring here — these classes are not
  losing replicates at a high rate; their pivots are built from
  (apparently) the full/near-full replicate set and still undercover.
  Root cause of the actual undercoverage remains genuinely open — this
  hypothesis is closed, not just deprioritized.

  **Side finding, not a bug, worth flagging separately**:
  `InferenceIncidKKCondLogitOneLik (model_formula=~.)` — a DIFFERENT
  cell from the one that appeared in the audit (which was
  `model_formula=~1`, n=107, 0% NA, coverage 0.757) — shows **89-93% NA
  CI bounds** (182 of 6,168 total rows across the whole cluster, all
  concentrated in this one `~.`/n=100 cell). This is the failure gate
  correctly tripping and returning honest `nonestimable` results, exactly
  as the 2026-09-06 fix intends — NOT a bug. It didn't appear in the
  audit's `low_coverage` findings because the effective non-NA sample
  size in that cell (~7-11 rows) falls below `COVERAGE_MIN_N=50`. Worth a
  light follow-up (separate from this plan): is
  `InferenceIncidKKCondLogitOneLik` under `~.` essentially non-functional
  at this harness's default `n`/covariate count (a capability-exclusion
  candidate, matched-pair conditional logit with many covariates is a
  known-hard regime), or is the resolved `m`/`b` just poorly sized for
  it specifically?

- [ ] TODO-2: Check whether the default `b`/`m` intermediate-size rule
  (`floor(n_units^0.7)`) is adequate relative to each class's effective
  parameter count, independent of the (now-refuted) scaling-formula
  hypothesis.
- [ ] TODO-3: Root-cause `InferenceIncidWald`'s separate
  `bayesian_bootstrap_confidence_interval_studentized` under-coverage
  (0.874) independently — different family, not yet looked at.
- [ ] TODO-4: Confirm TODO-28 ruled-out status for the other 4 Cluster-2
  classes (only `InferenceIncidBinomialIdentityRiskDiff` was checked).

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only.
