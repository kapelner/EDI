# Inference convergence-rate registry (design x class x procedure)

> **Release:** v1.0.5 TODO-193 (`future_release_plans/release_v1_0_5.md`).
> **Depends on:** TODO-192, `inference_procedure_regime_registry.md` (done
> 2026-11-10): `R/EDI/R/inference_procedure_regime.R`.
> **Consumers:** the calibration study gate and figures (later; gating is
> deliberately out of scope here, owner 2026-11-10).

Status: IMPLEMENTED 2026-11-10 (awaiting owner review; gating deliberately not done).

## Why

TODO-192 says only whether a procedure is asymptotic or finite-sample. The
owner wants, for every **design x inference class x procedure**, an explicit
expectation of how fast that cell's size / coverage error and bias go to zero,
and in which sample size, from one single source of truth. Without it a slowly
converging cell cannot be told from a buggy one, and a tolerance schedule
(TODO-192's 0.10 / 0.075 / 0.05) has no principled basis.

Examples of why one rate per procedure is not enough:

* Regular parametric Wald / score / LR / gradient: two-sided size and coverage
  error O(n^-1) (Edgeworth); one-sided O(n^-1/2); bias of the MLE O(n^-1).
* Bartlett-corrected LR: O(n^-2) size error.
* Percentile / basic bootstrap: O(n^-1) two-sided; bootstrap-t / BCa better.
* Exact and randomization: zero error at every n (finite-sample).
* Matched and KK designs: the effective n is the number of pairs (and, for KK
  one-likelihood classes, pairs plus the reservoir). Unequal allocation: the
  smaller arm drives the constant (ContinLin HC2 Wald at prob_T = 0.2,
  n = 50: size 0.17 in the first campaign).
* Zero-inflated / hurdle count models: the nonzero (or zero) counts.
  Survival: the number of events. Incidence: the number of events / the
  rarer outcome.
* Non-regular cells: MLE on the parameter-space boundary (LogBinomial,
  identity-link risk difference), random-effect variance near zero (GLMM,
  CLMM, frailty), zero-inflation probability near 0, density-based standard
  errors (quantile regression Wald: slower than n^-1, bandwidth dependent),
  M-estimators with estimated scale. These may converge at n^-1/2 or have a
  non-standard limit.
* Designs change the randomization distribution (blocking, rerandomization,
  iBCRD, pair switching, sequential KK): a model-based Wald SE that ignores the
  design is conservative or anticonservative by a fixed amount that does not
  vanish with n. That is an O(1) error, not a rate, and must be recordable.

## Design

### One source of truth, resolved by composition

Extend `R/EDI/R/inference_procedure_regime.R` (same file, so the regime and the
rate never disagree; keep it base R only, since the calibration publish job
sources it without EDI installed). Enumerating ~24 x ~88 x 14 triples by hand
is neither maintainable nor honest, so the registry is **layered**, and a
single resolver composes the layers:

1. **Procedure defaults**: one entry per sentinel label (the 14 of TODO-192),
   the rate in a regular parametric model.
2. **Class overrides**: per inference class (by class name string), the fields
   that differ for that class, optionally per procedure (e.g. a class whose
   Wald uses a t reference and is exact under its model; a quantile-regression
   Wald with a density-based SE; a boundary-prone MLE).
3. **Design modifiers**: per design (by class name string), the effective-n
   rule and any O(1) design-mismatch flag for model-based SEs, optionally
   restricted to a class or procedure set.
4. **Triple overrides**: rare, for a specific (design, class, procedure) whose
   behavior the layers do not express. Each one carries its reason.

`inference_convergence_expectation(design, class, procedure)` returns one
record, vectorised over triples (a data.frame), with the layer that supplied
each field. Precedence: triple > class x design > class > design > procedure.

### Fields of a resolved expectation

| Field | Meaning |
|---|---|
| `regime` | from TODO-192 (`asymptotic` / `finite_sample`); never overridden here |
| `size_order` | a in "two-sided size / coverage error = O(n_eff^-a)"; `Inf` for finite-sample (no error); `0` for an O(1) error that does not vanish; `NA` = unknown |
| `bias_order` | b in "bias of the point estimate = O(n_eff^-b)"; `NA` = unknown; `Inf` for unbiased by construction (e.g. difference in means under randomization) |
| `n_eff` | the sample size the rate is in: one of `n`, `n_pairs`, `n_pairs_plus_reservoir`, `n_min_arm`, `n_events`, `n_nonzero`, `n_clusters`, `n_strata` (fixed vocabulary, validated) |
| `regularity` | `regular`, `boundary`, `variance_component`, `mixture`, `nonparametric_rate`, `design_mismatch`, `other` |
| `basis` | `theory`, `literature`, `empirical`, `assumed_default`, `unknown` |
| `reference` | short citation or note (paper, or file:line of the derivation, or "calibration campaign 2026-11-09-8c32d060") |

Unknowns are explicit (`NA` plus `basis = "unknown"`), never a silent default:
a triple that resolves only through the procedure default must report
`basis = "assumed_default"`, so it is visible which cells nobody has looked at.

### Applicability and completeness

The registry does not decide which triples exist. Applicability comes from the
package (which designs a class accepts, which procedures it supports:
`inference_class_registry.R` capabilities / `get_supported_testing_types()`,
and whatever the calibration planner `plan_calibration_study.R` uses to pair
classes with designs; reuse that, do not re-derive it). The requirement is:
every applicable triple resolves, and every class or design name in the
registry is a real concrete class (a stale name fails).

### Package tie-in

As for TODO-192, a load-time (or, if load-time is too expensive, a test-time)
check that every class and design named in the override layers exists, every
field value is in its vocabulary, and the procedure layer covers exactly the
sentinel labels. Internal (`@noRd`); no export; no user-visible change.

## Populating it

* Procedure layer: from theory (cite: Hall 1992 for Edgeworth / bootstrap
  orders; Barndorff-Nielsen & Cox for Bartlett; standard MLE bias O(1/n)).
* Class layer: read each class's implementation and roxygen (estimator, SE
  type, reference distribution, known boundary / variance-component issues,
  existing "Small samples" notes such as ContinLin's). Many classes need no
  override. Prefer `basis = "theory"` with a reference; mark `unknown` rather
  than guess.
* Design layer: effective n per design (pairs for matched / KK designs; the
  smaller arm for unequal-allocation designs; clusters for cluster designs),
  and whether model-based SEs ignore the design's restricted randomization.
* Empirical cross-check (report, do not tune the registry to it): the published
  wave tables of campaign `2026-11-09-8c32d060` (results-branch clone at
  `/tmp/claude-1000/resbr2/campaigns/2026-11-09-8c32d060/`; n = 50 only so
  far). List cells whose n = 50 excess is far outside what their expectation
  implies, as candidates for review, in this plan's Done section.

## Tests

* Every sentinel label has a procedure-layer entry; no extras.
* Every class / design name in the override layers is a concrete EDI class.
* Every field value is in its vocabulary; orders are numeric, >= 0, or `Inf` /
  `NA` as specified; `NA` orders carry `basis = "unknown"`.
* Completeness: for every applicable (design, class, procedure) triple (from
  the package's applicability source), the resolver returns exactly one record
  with no missing required field.
* Precedence: a synthetic layered table shows triple > class x design > class >
  design > procedure.
* The file still sources into an empty environment with base R only.

## Constraints

* R only; no C++; no `R CMD INSTALL`; `pkgload::load_all("R/EDI", compile =
  FALSE)` only (project CLAUDE.md). No roxygen run (pre-push regenerates Rd).
* Do not change the calibration gate or its levels (owner will decide gating
  after this). Reading the registry from the calibration scripts is not
  required yet.
* Test file names carry no TODO number; cite "v1.0.5 TODO-193" in a top
  comment.
* NEWS.md internal bullet under EDI 1.0.5.

## Done

Implemented 2026-11-10. No gate, `.github/`, calibration script, C++ or Rd change.

**What changed**

* `R/EDI/R/inference_procedure_regime.R` (appended after the TODO-192 table, still base R only and side-effect-free): vocabularies `EDI_CONVERGENCE_N_EFF` / `_REGULARITY` / `_BASIS` / `_LAYERS` (L91-101); procedure layer `EDI_CONVERGENCE_PROCEDURE_DEFAULTS` (L109, 14 rows, each with a citation); `edi_convergence_entry()` (L144, expands vector design / class / procedure arguments, `size_order = "unknown"` records an explicit unknown); override layers `EDI_CONVERGENCE_OVERRIDES` (L166; 573 rows after expansion: 36 design, 329 class, 208 class_design, 0 triple); `inference_convergence_validate()` (L289, pure internal-consistency check); `inference_convergence_expectation(design, class, procedure)` (L342, vectorised resolver).
* `R/EDI/R/inference_suite.R:357-361`: the existing TODO-192 load-time `local()` block also stops loading if `inference_convergence_validate()` reports a problem (vocabulary, procedure coverage, key shape, duplicates, NA-order-needs-unknown-basis, finite-sample orders). Class and design names are NOT checked at load (the R6 generators do not exist yet at collation); the test does it.
* `R/package_tests/testthat_bulk/test-inference-convergence-rate-registry.R` (new).
* `R/EDI/NEWS.md` (Internal bullet under 1.0.5), `release_v1_0_5.md` TODO-193 "Current state" (checkbox left `[ ]`).

**How a triple resolves.** Precedence triple > class_design > class > design > procedure; inside a layer an entry restricted to a procedure beats an unrestricted one, and an entry keyed by a design label (`DesignFixedBernoulli@prob_T=0.2`, the calibration study's label) beats the bare design class. Fields resolve independently (`size_order`, `bias_order`, `n_eff`, `regularity`), each reported with its `<field>_layer`. `basis`/`reference` describe the size order. A size order that comes only from the procedure layer is reported `assumed_default`, except exact and randomization (Inf by construction: `theory`). An NA order always comes with basis `unknown`.

**What is encoded (all with a citation or file:line)**

* Procedure layer: wald / jackknife / score / lik_ratio / gradient 1; both Bartlett LR and `param_boot` 2; `param_boot_direct` and `bootstrap` 1 (lower bound: the default BCa type is O(n^-2) in theory but falls back to percentile and many classes are pinned to it, `globals.R` `get_bootstrap_dispatch_policy`), `bayes_boot` 1, `rand_bootstrap` 1 (basis `assumed_default`: no derivation found), exact / rand Inf; bias 1 everywhere (regular MLE).
* Design layer: `DesignFixedBernoulli@prob_T=0.2` -> `n_min_arm` (asymptotic procedures); cluster designs -> `n_clusters`.
* Class layer, effective n: survival model classes `n_events`; hurdle classes `n_nonzero`; incidence classes `n_events`; `InferenceIncidCMH` `n_strata`; paired sign test `n_pairs`; all other KK / Bai classes `n_pairs_plus_reservoir`.
* Class layer, rates: difference-in-means classes unbiased (bias Inf, theory); quantile-regression Wald 2/3 (literature, Hall & Sheather 1988, extension to regression by analogy: flagged in the reference); explicit UNKNOWN for random-effect-variance classes (12), zero / one inflation mixtures (3), LogBinomial and identity-link risk difference (boundary), stereotype logit (Davies 1977), and robust regression with estimated scale (3).
* Class x design: the unadjusted two-sample classes (`InferenceAllSimpleAverageDiff`, `...MeanDiffPooledVar`) on covariate-balancing designs (blocking, matching, rerandomization, Pocock-Simon, SPBR, KK) for model-based procedures: size order 0, regularity `design_mismatch` (O(1) conservativeness, Bai-Romano-Shaikh 2021, Bugni-Canay-Shaikh 2018, Li-Ding-Rubin 2018).
* Triple layer: empty on purpose (no triple is known to differ from the layers); the mechanism is covered by the synthetic precedence test.

**Applicability (not a second table).** The test enumerates exactly what the calibration planner does: for each of `CAL_STUDY_DESIGNS` (22 labels) and each response type, `cal_study_classes()` (= `applicable_inference_class_names_for_design()` on a constructed design), then every sentinel procedure whose capability (`EDI_INFERENCE_SUITE_*_METHOD_PRIORITY`) is in `get_effective_capabilities(class)`. This is capability-level, so it can include a procedure (e.g. Bartlett) that a specific object later reports as unsupported through `get_supported_testing_types()`; extra triples only make the completeness check stricter.

**Counts** (22 design labels x 88 classes, 1,270 applicable design-class pairs):

* 11,854 triples resolve, none with a missing required field.
* Size order basis: theory 1,270 (all exact / rand), literature 78 (26 design-mismatch cells + 52 quantile-regression Wald cells), assumed_default 8,446, unknown 2,060, empirical 0. Bias basis: theory 1,490, assumed_default 10,364.
* By supplying layer (size): procedure 9,716, class 2,112, class_design 26, design 0 (the design-layer entry only sets `n_eff`).
* Regularity: regular 9,716, boundary 528, mixture 792, variance_component 368, other 372, nonparametric_rate 52, design_mismatch 26.
* n_eff: n 6,290; n_events 3,730; n_pairs_plus_reservoir 836; n_nonzero 624; n_min_arm 266; n_strata 84; n_pairs 24.
* The 2,060 unknown triples are 18 classes (ZI Poisson / NegBin, ZOIB, LogBinomial, IdentityRiskDiff 264 each; stereotype logit 242; ContinRobustRegr 110; 10 variance-component classes and `InferenceContinKKRobustRegrOneLik`, 20-48 each).
* `empirical` is unused: the only simulations are at n = 50, which cannot give an order. Documented small-sample excesses (`inference_continuous_lin.R:29`, ...) are cited only where they fix an effective-n rule or an unknown.

**Empirical cross-check** (report only; nothing was tuned). Source: `calibration_summary.csv` of `2026-11-09-8c32d060`, null cells at n_nominal 50 (2,946 rows, 2,898 with a size or coverage excess; excess = max(size - 0.05, 0.95 - coverage)). A cell is "far" when its excess exceeds 3 Monte-Carlo SE plus 3 * n_eff^-order (constant 1, crude; n_eff taken as n, n * min(p, 1-p) for the smaller arm, and n/2 for every pair / event / nonzero rule, the lenient end):

* 18 cells are far outside their expectation (13 where the expectation is finite-sample, 5 asymptotic):
  * `rand` on `InferenceCountZeroInflatedNegBin` (11 cells, size 0.076-0.097) and `InferenceCountZeroInflatedPoisson` (2 cells, up to 0.168): the expectation is exact (Inf). These are the 11 `rand` gate failures already known from TODO-192; a defect candidate, not a rate.
  * `score` on `InferenceOrdinalCauchitRegr`, `~.` (4 cells, size 0.131-0.151, coverage down to 0.852; expectation order 1 in n, assumed default): candidate for review (heavy-tailed link, likely a slow or defective cell).
  * `score` on `InferenceIncidKKCondLogitGLMMOneLik`, `~.`, DesignFixedBinaryMatch (size 0.286; expectation order 1 in pairs + reservoir, assumed default). The model is now a plain conditional logit (NEWS 1.0.5), so it was deliberately NOT recorded as variance-component; this cell says the default does not hold.
* 104 cells with an excess above 0.05 sit in classes whose expectation is `unknown`: ZI Poisson 44, ZI NegBin 41, stereotype logit 10, LogBinomial 8, identity risk difference 1. Consistent with the unknowns, and the strongest candidates for a real rate study.
* No cell of a class with a finite order is far above its expectation apart from the two classes above.
* Conservative direction is not examined: the design-mismatch cells (order 0) would show as coverage above nominal.

**Tests** (from the repo root; `pkgload::load_all("R/EDI", compile = FALSE)` first, then `testthat::test_file(..., reporter = "summary")`)

* `test-inference-convergence-rate-registry.R`: 9 tests, 94 expectations, 0 failed, 0 skipped (sources base-R-only; procedure layer = regime labels = sentinel labels; every class / design name is concrete; validator rejects each kind of malformed table; precedence on synthetic layers incl. row-order independence, label-vs-class and procedure-restricted entries; resolver spot checks; all 11,854 applicable triples resolve with complete fields, NA order iff basis unknown, regime iff Inf size, procedure-default cells flagged `assumed_default`; package copy equals the checkout).
* `test-inference-procedure-regime-registry.R`: 6 tests, 14 expectations pass. `test-calibration-gate-regime-levels.R`: 5 tests, 17 expectations pass. `test-inference-suite-run-all-inference-case-31.R`: 1 passes (sentinel completeness).

**Deviations from the plan**

* Extra resolved columns `bias_basis` / `bias_reference` and `<field>_layer`: with a single `basis`, a class that supplies only the bias would have overwritten the basis of the size order. `basis` / `reference` therefore describe the size order only.
* Design labels with a `@prob_T=` suffix are accepted by the resolver as a more specific key than the bare design class, because unequal allocation is a parameter of `DesignFixedBernoulli`, not a class.
* The layer an entry belongs to is stated by the author (`edi_convergence_entry(layer, ...)`), not inferred from which keys are `NA`, so procedure-restricted class x design entries stay in `class_design` rather than becoming `triple`.
* Finite-sample procedures may not carry a size override (validated), so `regime` is never overridden, as the plan requires.
* Legacy IVWC classes are named in the class layer (they are exported, concrete classes) but are absent from the completeness check, because the calibration study does not run them.
* Lattice effects for discrete outcomes (O(n^-1/2) pointwise Wald coverage error for binomial-type data) are not encoded; I was not sure enough to cite it. This is a candidate refinement of the incidence / count / ordinal Wald defaults.
