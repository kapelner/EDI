# E-Values / Safe Testing as an Adaptive-Robust Alternative to Combined Evidence

> **Depends on:** nothing existing architecturally, but is itself a
> substantial architectural shift — every `Inference` class would need to
> produce an e-value alongside its p-value, not a post-process over
> `results_table` the way `wilkinson_combined_pval.md`/
> `model_averaged_estimand_report.md`/`multiplicity_adjusted_results_table.md`
> (v1.x) are. Comparable in scope to `sample_splitting_model_selection.md`
> and `selective_inference_post_selection.md`'s broader-rollout stages.
> **Release target: v2.0.0** (`release_v2_0_0.md → TODO-6f`).

Written 2026-08-30.

## Why

Every combination method discussed so far in this line of plans —
`combined_evidence$pval` (CCT), `wilkinson_combined_pval.md`'s vote-count/
order-statistic work, `multiplicity_adjusted_results_table.md`'s Holm/BH
correction — is a p-value combiner. All of them require the candidate set
of tests to be **fixed before looking at the results**: CCT's closed-form
dependence-robust validity is a theorem about a specific, predetermined
weight vector over a specific, predetermined set of p-values. This was the
direct answer to an earlier question in this conversation ("isn't the
Cauchy combination sensitive to getting lucky with one model," "is CCT
gameable by adding more models") — the honest answer was: fixed weights
over a fixed, structurally-determined candidate set (`applicable_design_
classes`) protects against it *as currently used*, but nothing in CCT's own
machinery would remain valid if a user could adaptively decide, after
seeing some results, to fit and add more candidate models to the combination.

**E-values are a genuinely different validity framework built to survive
exactly that.** An e-value $E$ for a null hypothesis $H_0$ is a nonnegative
random variable with $\mathbb{E}_{H_0}[E] \le 1$ — Markov's inequality then
gives $P_{H_0}(E \ge 1/\alpha) \le \alpha$ for free, the same role a p-value
plays, but the *combination* rule is different and dramatically more
permissive: **e-values combine validly by simple averaging** (or
multiplication, in the sequential/testing-by-betting formulation), and — the
key property motivating this plan — **that validity is preserved under
adaptive stopping and under adaptively deciding, mid-stream, to include more
tests**, which p-value combination (CCT included) cannot claim (Vovk & Wang
2021; Grünwald, de Heide & Koolen 2024's "safe testing" / "anytime-valid
inference" framework). This is the most direct, structurally-guaranteed
answer to the earlier gaming question: not "the current fixed candidate set
happens to protect against it" but "the combination rule itself remains
valid even if the candidate set grows adaptively."

## What this would actually require

Unlike every v1.x plan in this family (thin wrappers/post-processes over an
already-computed `results_table`), this needs new output from **every**
`Inference` class, not a new aggregation step over existing output:

- Each class would need to produce an e-value for its own test, not just a
  p-value. For many parametric tests this is derivable from the likelihood
  ratio directly (a likelihood-ratio statistic is itself a valid e-value
  under fairly general conditions — this is not unrelated to the existing
  `likelihood_tier = "full"` machinery and `compute_lik_ratio_*` methods
  already in the registry, which may make some classes' e-values cheap to
  derive from what's already computed). For resampling-based procedures
  (bootstrap, randomization) an e-value analog needs a genuinely new
  construction (e.g. via a test martingale built from the resampling
  distribution), which is not a solved problem for every procedure family
  in the registry today.
- A combination layer (simple averaging, or a "GRO" — growth-rate-optimal —
  combination per Grünwald et al.) alongside, not replacing,
  `combined_evidence$pval`.
- New guidance on what "adaptively adding more models" would even mean in
  `InferenceSuite`'s architecture today — since `applicable_design_classes`
  is currently discovered structurally and fit once, "adaptive inclusion"
  is not a workflow the class currently supports at all; this plan would be
  the first place such a workflow could be introduced honestly.

## Proposal (staged)

- **Stage 0 (Phase 0 decision, research-heavy):** which classes' existing
  likelihood-ratio machinery already yields (or nearly yields) a valid
  e-value with no new derivation; triage the registry by
  `likelihood_tier`/capability metadata to find the cheapest starting
  subset, analogous to how `selective_inference_post_selection.md` picked
  `InferenceContinOLS` as its pilot.
- **Stage 1 (pilot):** derive and implement e-values for that cheapest
  subset (likely the `likelihood_tier = "full"` classes with an existing
  `compute_lik_ratio_two_sided_pval_impl()`); add
  `combined_evidence$e_value` (simple average across the pilot subset) as an
  opt-in alongside `combined_evidence$pval`; no adaptive-inclusion workflow
  yet — validate the machinery under the *existing* fixed-candidate-set
  regime first, where it should give a valid (if likely less powerful in
  the fixed-set case) alternative to CCT.
- **Stage 2 (gated on Stage 1, and on real user demand for the adaptive use
  case):** design and implement the actual adaptive-inclusion workflow this
  framework is meant to unlock — letting a user or an automated process add
  more candidate procedures to a running combined e-value after seeing
  interim results, without invalidating the combination. This is a new
  `InferenceSuite` interaction mode, not just new per-class math, and is the
  part of this plan that most resembles new architecture rather than an
  additive capability.
- **Stage 3 (gated further):** resampling-based e-value constructions
  (bootstrap/randomization procedures) for the classes that can't reach an
  e-value via a likelihood ratio.

## Tests

- Stage 1: calibration test under the true null (`betaT = 0` in
  `SimulationFramework`) confirming $\mathbb{E}[E] \le 1$ empirically and
  that the Markov-bound rejection rate at $1/\alpha$ stays at or below
  nominal — the e-value analog of the calibration checks already backing
  CCT's and (proposed) Wilkinson's use here.
- Stage 1: power comparison against `combined_evidence$pval` (CCT) on the
  same fixed candidate set, to document the expected power cost of the more
  permissive e-value framework when the adaptive-inclusion flexibility
  isn't actually being used.
- Stage 2 (if built): the core selling point needs its own dedicated test —
  simulate a user adaptively adding candidate procedures mid-stream based on
  interim e-values, confirm the running combined e-value's type-I error
  stays controlled under `betaT = 0` even under that adaptive rule, in
  contrast to a CCT-style combination run through the same adaptive
  protocol (which should visibly inflate, as a negative-control comparison).

## TODOs

- [ ] TODO-1: Phase 0 decision (research-heavy) — triage the registry by
  which classes' existing likelihood-ratio machinery yields a cheap e-value;
  pick the Stage 1 pilot subset.
- [ ] TODO-2: Derive and implement e-values for the pilot subset;
  `combined_evidence$e_value` (simple-average combination) as an opt-in
  alongside `combined_evidence$pval`, under the existing fixed-candidate-set
  regime (no adaptive workflow yet).
- [ ] TODO-3: Calibration test (`betaT = 0`, $\mathbb{E}[E]\le1$ and
  Markov-bound rejection rate) and power comparison against CCT on the same
  fixed set.
- [ ] TODO-4 (gated on TODO-3 and user demand): design and implement the
  adaptive-inclusion `InferenceSuite` workflow this framework is meant to
  unlock; the adaptive-calibration negative-control test above.
- [ ] TODO-5 (gated further): resampling-based e-value constructions for
  bootstrap/randomization procedures lacking a likelihood-ratio route.
- [ ] TODO-6: roxygen — distinguish `combined_evidence$e_value` from
  `combined_evidence$pval` (different validity framework, different
  guarantee under adaptive inclusion), cross-referencing this plan and the
  gaming discussion in `InferenceSuite`'s existing interpretation caveats.

## References

Vovk, V., and Wang, R. (2021), "E-values: calibration, combination, and
applications," *Annals of Statistics*, 49(3), 1736-1754 — the e-value
framework and its averaging-based combination rule.

Grünwald, P., de Heide, R., and Koolen, W. M. (2024), "Safe testing,"
*Journal of the Royal Statistical Society: Series B*, 86(5), 1091-1128 —
"safe testing" / anytime-valid inference under optional stopping and
adaptive test inclusion.

Ramdas, A., Grünwald, P., Vovk, V., and Shafer, G. (2023), "Game-theoretic
statistics and safe anytime-valid inference," *Statistical Science*, 38(4),
576-601 — accessible survey connecting e-values, test martingales, and
anytime-valid confidence sequences, useful background for Stage 3's
resampling-based e-value constructions.
