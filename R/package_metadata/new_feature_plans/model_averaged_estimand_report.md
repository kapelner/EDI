# Model-Averaged Point Estimate and CI Across `InferenceSuite`'s Applicable Models

> **Depends on:** the shipped marginal-estimand transform
> (`set_estimand("marginal_mean_diff"/"marginal_ratio")`,
> `marginal_estimand_report.md`, closed in the v1.0.0 line) for Stage 2's
> cross-estimand-group averaging; Stage 1 (within one estimand group) has no
> new dependency. Additive alongside the existing Cauchy combination test
> and `wilkinson_combined_pval.md`'s vote-count/order-statistic work — a
> different kind of summary, not a replacement for either. **Release target:
> v1.1.0** (`release_v1_1_0.md → TODO-17o`).

Written 2026-08-30.

## Why

`InferenceSuite`'s `combined_evidence$pval` (Cauchy combination test) and
the vote-count/Wilkinson work in `wilkinson_combined_pval.md` both answer a
yes/no question about the joint null ("does at least one / do most
applicable procedures detect a signal") — neither ever produces a number a
user would put in an abstract. `InferenceSuite`'s own roxygen ("Combined
Evidence interpretation caveat") explicitly warns *against* reading
`combined_evidence$pval` as if it estimated a single effect size, precisely
because it structurally can't.

Frequentist model averaging answers a different, complementary question:
"accounting for the fact that several legitimate models/procedures disagree
somewhat about the effect, what's the best single point estimate and CI?"
This is the natural next step once a user has looked at the CI-forest plot
(`plots$ci_forest`) and wants one number instead of eyeballing a dozen
intervals — the deliverable practitioners usually actually want to report.

## Mechanics

Given $K$ candidate models, each producing an estimate $\hat\theta_k$ of the
*same* target quantity on the *same* scale, with weights $w_k$ summing to 1
(Akaike weights $w_k \propto e^{-\Delta_k/2}$, $\Delta_k = \mathrm{AIC}_k -
\mathrm{AIC}_{\min}$, or inverse-variance weights):

- **Point estimate:** $\bar\theta = \sum_k w_k \hat\theta_k$.
- **Variance (Buckland, Burnham & Augustin 1997):**
  $\widehat{\mathrm{Var}}(\bar\theta) = \left[\sum_k w_k
  \sqrt{\widehat{\mathrm{Var}}(\hat\theta_k) + (\hat\theta_k -
  \bar\theta)^2}\right]^2$ — the naive $\sum_k w_k^2
  \widehat{\mathrm{Var}}(\hat\theta_k)$ ignores *model* uncertainty (the
  models disagreeing with each other) and understates the true variance; the
  $(\hat\theta_k - \bar\theta)^2$ term is a between-model heterogeneity
  variance, structurally the same role as DerSimonian & Laird (1986)'s
  between-study variance in a random-effects meta-analysis.
- **CI:** $\bar\theta \pm z_{1-\alpha/2}\sqrt{\widehat{\mathrm{Var}}(\bar\theta)}$
  (or a $t$-interval with an effective-df correction; Burnham & Anderson
  2002 treat the asymptotically-normal form as adequate in practice).

## The two levels this applies at

**Stage 1 — within one estimand group** (e.g. all "mean Δ" rows, all
"logodds cont ratio" rows): most rows in a group are the *same* fitted
model scored by different testing methods (bootstrap/score/Wald/jackknife
all share one MLE) — averaging across rows naively would double-count one
number under several names. The averaging unit here is the *distinct model
fit*, of which there is often exactly one per group (nothing to average) or
a small handful (e.g. genuinely different bootstrap point-estimate variants:
plain vs. Bayesian vs. parametric bootstrap can each produce a slightly
different $\hat\theta$). Everything is already on the same scale within a
group, so this stage needs no new machinery beyond the Buckland formula
itself.

**Stage 2 — across estimand groups** (cauchit link vs. cloglog vs. probit vs.
logodds proportional-odds — genuinely different model specifications for the
same outcome): a raw cauchit-link coefficient and a raw probit-link
coefficient are not the same quantity, so averaging them directly is
meaningless. This is why `InferenceSuite` treats these as separate estimand
groups today. Stage 2 requires first transforming every applicable class's
estimate onto the shared marginal-effect scale via the already-shipped
`set_estimand("marginal_mean_diff"/"marginal_ratio")` machinery, *then*
Akaike- or inverse-variance-weight-averaging the marginal estimates with the
Buckland variance formula above.

## Proposal (staged)

- **Stage 1:** add `compute_model_averaged_estimate()` (name TBD) operating
  within one estimand group's distinct model fits, returning
  `list(estimate, se, ci_a, ci_b, weights_used, weighting)`. Exposed on
  `InferenceSuite$run_all_inference()`'s return value as
  `model_averaged_estimate` (per estimand, alongside `combined_evidence`),
  reusing `results_table`'s existing per-row `estimate`/`se` fields; no
  refit needed since every candidate estimate is already computed.
- **Stage 2 (gated on a design decision):** wire the marginal-estimand
  transform in as a precondition — for classes not already fit under
  `set_estimand("marginal_*")`, either require the caller to have set it
  suite-wide, or have `InferenceSuite` re-fit only the across-group subset
  under the marginal estimand internally (more expensive: a second pass of
  fits). Needs a decision on which of those two costs is acceptable before
  implementation (Phase 0 gate).
- Both stages: weighting scheme mirrors `combined_evidence_weighting`'s
  existing `c("equal", "custom")` shape for consistency (`"custom"` needing
  the same named-weight-vector contract), plus `"akaike"` as a new option
  computed from each candidate's AIC (already available via each class's
  fitted log-likelihood + parameter count — no new C++ needed, this is an
  R-layer aggregation over existing per-class quantities).

## Tests

- Stage 1: golden test reproducing Buckland's variance formula by hand on a
  small fixed set of `(estimate, se)` pairs; degenerate case (one model in
  the group) reduces to that model's own `(estimate, se)` exactly.
- Stage 1: calibration check under the true null (`betaT = 0` in
  `SimulationFramework`) — the model-averaged CI's coverage should be at
  least nominal (Buckland's formula is known to be somewhat conservative,
  which is the right direction to err).
- Stage 2 (if built): parity that transforming a single class through
  `set_estimand("marginal_mean_diff")` and averaging over $K=1$ reproduces
  that class's own marginal estimate exactly.

## TODOs

- [ ] TODO-1: Implement Stage 1 (`compute_model_averaged_estimate()`,
  within-estimand-group only, `"equal"`/`"custom"`/`"akaike"` weighting) and
  wire it into `run_all_inference()`'s return value.
- [ ] TODO-2: Buckland-variance golden tests + null-calibration coverage
  check (`SimulationFramework`, `betaT = 0`).
- [ ] TODO-3: roxygen — explicitly distinguish `model_averaged_estimate`
  from `combined_evidence$pval` (a reportable effect estimate vs. a joint
  existence test), cross-referencing the existing "Combined Evidence
  interpretation caveat" section.
- [ ] TODO-4 (Phase 0 decision): pick Stage 2's cost tradeoff (require
  suite-wide `set_estimand("marginal_*")` upfront vs. an internal re-fit
  pass for the across-group subset).
- [ ] TODO-5 (if TODO-4 lands): implement Stage 2 (cross-estimand-group
  averaging on the marginal-estimand scale) and its parity test.

## References

Buckland, S. T., Burnham, K. P., and Augustin, N. H. (1997), "Model
selection: an integral part of inference," *Biometrics*, 53(2), 603-618 —
the model-averaged variance formula this plan uses.

Burnham, K. P., and Anderson, D. R. (2002), *Model Selection and
Multimodel Inference: A Practical Information-Theoretic Approach* (2nd ed.),
Springer — Akaike weights and the asymptotically-normal model-averaged CI.

DerSimonian, R., and Laird, N. (1986), "Meta-analysis in clinical trials,"
*Controlled Clinical Trials*, 7(3), 177-188 — the random-effects
between-study variance this plan's between-model term is structurally
analogous to.
