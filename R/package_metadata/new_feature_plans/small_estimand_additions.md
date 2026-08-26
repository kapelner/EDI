# Small Estimand Additions on Existing Response Types

> **Depends on:** nothing architectural; every item is a thin estimand
> wrapper over existing machinery via `define_inference_class()`.
> **Release target: v1.1.0** (`release_v1_1_0.md → TODO-17c`); each
> sub-item is independent and may ship separately.

Written 2026-08-27. Owning plan for
`missing_inference_classes_literature_audit.md` items **#6, #11, #17,
#18, #19, #20** (Part 4A/4B; batched as "each small" in its rank list).

## Items

### A. Standardized mean difference — `InferenceContinStandardizedMeanDiff` (#6)

Cohen's d / Hedges' g (small-sample-corrected) with noncentral-t or
bootstrap CI; cluster-adjusted g for cluster designs (Hedges 2007).
Required by WWC; the effect-size currency of psychology / education /
criminology meta-analysis. Estimate = g; SE from the standard
large-sample formula; randomization and bootstrap contracts via the
existing components. Response type: continuous.

### B. Win odds / probability of superiority — `InferenceAllWinOdds` / `InferenceAllProbSuperiority` (#11)

`P(Y_T > Y_C) + ½ P(Y_T = Y_C)` (Mann-Whitney parameter) and the win odds
`p/(1−p)` or win ratio `P(T>C)/P(C>T)`; Brunner-Munzel variance (valid
under unequal variances / shapes); pairwise-comparison rules for censored
survival (Pocock's win-ratio conventions). Generalizes the ordinal-only
`InferenceOrdinalJonckheereTerpstraTest` to all six response types; the
Wilcoxon classes report Hodges-Lehmann shift, not the probability. 68
win-ratio RCTs 2012–24, growing fast (cardiology); DOOR in ID trials. KK
variant via pair-wise comparison within pairs + reservoir IVWC (optional).

### C. Mantel-Haenszel stratified OR and RD — `InferenceIncidMantelHaenszelOR` / `RD` (#17)

True MH pooled OR (Robins-Breslow-Greenland variance) and RD (Sato /
Greenland-Robins variance) over the existing block structure. The
current `InferenceIncidCMH` is a legacy blocked mean-difference with a
randomization SE, not the MH estimator; document the distinction and
consider renaming the legacy class in 2.0.0.

### D. Non-inferiority / equivalence conveniences (#18)

`compute_noninferiority_pval(margin, direction)` and
`compute_equivalence_pval(bounds)` (TOST) on the base `Inference`
contract, derived from the existing `compute_*_two_sided_pval(delta)` and
CI methods; available for asymptotic, bootstrap and randomization paths.
Document the ITT-vs-per-protocol population caveat.

### E. Unconditional quantile treatment effect — `InferenceAllQuantileDiff` (#19)

`Q_τ(Y | w=1) − Q_τ(Y | w=0)` (Firpo 2007's marginal QTE — a different
estimand from the conditional quantile-regression coefficient EDI's QR
family reports); Harrell-Davis or RIF variance, bootstrap and
randomization CIs. Response types: continuous, count, proportion,
uncensored survival.

### F. Log-link QMLE for skewed non-negative continuous outcomes (#20)

Allow continuous non-negative `y` in the robust-Poisson (QMLE) path as
`InferenceContinLogLinkQMLE`, and add `InferenceContinGammaLogRegr`
(Gamma GLM, log link, sandwich SE). Rising fast in economics after Chen &
Roth 2024 (replacing `log(1+y)`); Gamma-log is the health-economics
standard for costs.

## Tests

A: parity vs `effectsize::hedges_g`; B: vs `rankFD`/`brunnermunzel` and
`WINS`; C: vs `mantelhaen.test` / `epitools`; D: algebraic identities vs
existing p-values/CIs; E: vs `quantreg::rq(y ~ w)` at `τ` (the marginal
QTE equals the coefficient in the no-covariate case); F: vs `glm(family =
quasipoisson)` / `Gamma(link = "log")` with `sandwich`.

## TODOs

- [ ] TODO-1: A — `InferenceContinStandardizedMeanDiff`.
- [ ] TODO-2: B — `InferenceAllWinOdds` / `ProbSuperiority` (all six types).
- [ ] TODO-3: C — `InferenceIncidMantelHaenszelOR` / `RD`; legacy-class doc.
- [ ] TODO-4: D — NI / equivalence methods on the base contract.
- [ ] TODO-5: E — `InferenceAllQuantileDiff`.
- [ ] TODO-6: F — `InferenceContinLogLinkQMLE`, `InferenceContinGammaLogRegr`.
- [ ] TODO-7: registry / fixture rows; `run_all_inference()` picks them up.
