# Closed-Form Randomization Nulls: Exact PMFs and Exact Conditional Moments Where They Exist

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-40`;
> 2026-10-07, user decision). Additive: new `type` values on the existing
> randomization p-value / CI entry points, default path unchanged until the
> decision-gated TODO-7. No new response type, no new estimator. No Phase 0
> dependency.
>
> **Interaction:** the classes this plan serves (statistics linear in `y`)
> are exactly the tier-1 classes of
> `randomization_ci_affine_shift_reuse.md` (`release_v1_0_5.md → TODO-2`);
> TODO-5 below gives that plan a closed-form bracket for its CI search.
> `exact_rank_tests_shift_algorithm.md` (`→ TODO-41`) depends on this plan's
> TODO-2 hook and supplies the general integer-score PMF; the hypergeometric
> here is its 0/1-score special case, which is a cross-check, not a
> duplication.

Date: 2026-10-07. Grew out of the `coin` comparison in the 2026-10-07
benchmark investigation (`R/benchmark/benchmark_model_fits.R`, procedure
table). `coin`/`libcoin` are GPL-2 only and EDI is GPL-3, so nothing here
copies code; the ideas are from Strasser & Weber (1999) and the
hypergeometric/binomial identities below, reimplemented.

## The finding

`coin` treats every test as a linear statistic `T = Σ_i g(w_i) h(y_i)` and
knows its exact conditional expectation and covariance under the
permutation law in closed form (Strasser & Weber 1999). Its default
p-value needs no permutations at all, and for several (design, outcome)
pairs the whole null distribution is available in closed form.

EDI draws `r` permutations for all of these. Measured on the installed
1.0.2 at n = 1000, r = 1000: the mean-difference randomization p-value
spends 14 ms generating permutations and 0.7 ms consuming them, for a
distribution it could write down.

**What is closed-form, by design and outcome (statistic `T` = treated-arm
sum `Σ_i w_i y_i`, which drives the mean difference, the risk difference
and every other statistic monotone in it):**

| Design (randomization law) | Binary `y` | General `y` |
|---|---|---|
| `DesignFixediBCRD` (fixed `n_T`, exchangeable) | treated-case count `A ~ Hypergeometric(n, n_1, n_T)`: exact PMF | exact mean and finite-population variance of `T` (sampling without replacement) |
| `DesignFixedBlocking` (fixed `n_T,b` per block) | `A = Σ_b A_b`, independent hypergeometrics: exact PMF by convolution | moments add over blocks |
| Matched pairs (`DesignFixedBinaryMatch` and the KK designs, within-pair flips) | discordant-pair count `~ Binomial(k, 1/2)` (this is what `zhang_exact_binom_pval_cpp` already does at `delta_0 = 0`) | exact moments from per-pair differences |
| `DesignFixedBernoulli` (`n_T` random) | `A ~ Binomial(n_1, p_T)` and `n_T − A ~ Binomial(n_0, p_T)` independent: exact 2-D enumeration, `O(n_1 · n_0)` | moments in closed form (independent Bernoullis) |

**What EDI already has, and its gap.** For incidence responses,
`compute_rand_two_sided_pval()` (`inference_all_abstract_rand_ci.R`)
dispatches to the exact Zhang combined test whenever
`should_use_zhang_incidence_randomization()`
(`inference_all_abstract_rand.R:354`) is true: incidence response **and**
(Bernoulli design **or** a match structure), no custom statistic. The
Zhang test is Fisher's conditional test on the reservoir table
(`fisher_noncentral_two_sided_pval`, `zhang_exact_speedups.cpp`) combined
with the exact binomial on discordant pairs. Two gaps:

1. **It refuses the designs where the hypergeometric is the unconditional
   randomization law.** On `DesignFixediBCRD` and `DesignFixedBlocking`,
   `n_T` is fixed *by the design*, so conditioning on the table margins
   adds nothing and Fisher's hypergeometric *is* the randomization
   distribution. Those designs fall through to Monte Carlo. (On a Bernoulli
   design the conditional Fisher test is valid but is a different test from
   the unconditional randomization test; both are legitimate, and the plan
   keeps Zhang as is.)
2. **Its two-sided ordering differs from EDI's randomization ordering.**
   `fisher_noncentral_two_sided_pval` sums the probabilities of tables at
   most as likely as the observed one ("minlike"). The Monte Carlo path
   uses `compute_two_sided_randomization_pval_from_t0s()`
   (`inference_all_abstract_rand.R:633`): twice the smaller tail,
   `min(1, 2·min(P(T ≥ t), P(T ≤ t)))`, floored at `2/r`. A closed-form
   replacement for the Monte Carlo path must use the doubled-tail ordering
   on the exact PMF so that it is the `r → ∞` limit of today's answer.

## Proposal

Add an **exact-null hook** to the randomization layer and implement it for
the (class, design) pairs in the table. Keep Monte Carlo as the default in
v1.1.0; expose the closed forms as new `type` values; gate the default
switch on a user decision (TODO-7), because it changes default p-values
(from a Monte Carlo estimate to its limit, so never bit-for-bit).

**Equivalence contract.** For every fixture where a closed form applies:
`|p_exact − p_MC(r = 10^5)|` within the Monte Carlo band
(`compute_two_sided_randomization_pval_band()`); the exact PMF matches
`dhyper`/`dbinom` identities to 1e-12; Type I error in simulation at or
below nominal (discrete, hence conservative). Closed-form moments match the
sample moments of a `r = 10^6` draw to Monte Carlo error.

## TODOs

- [ ] TODO-1: **Registry of closed forms.** A table (in
  `contracts_mixins.R`'s style, or a new `contracts_exact_nulls.R`) mapping
  (inference class, design family, response type, `delta == 0`,
  `transform_responses == "none"`, no covariates kept, no custom statistic)
  to one of: `exact_pmf`, `exact_moments`, `none`. Start with
  `InferenceAllSimpleAverageDiff`, `InferenceAllSimpleMeanDiffPooledVar`,
  `InferenceIncidRiskDiff` (only when `best_X_colnames` is empty: with
  covariates kept, `compute_treatment_estimate_during_randomization_inference()`
  runs `fast_ols_cpp` and the statistic is no longer a function of `A`),
  and `InferenceAllSimpleWilcox` (moments here; PMF via `→ TODO-41`).
  Design families via the existing predicates
  (`is_fixed_sample_size()`, `is_bernoulli_design()`,
  `is_blocking_design()`, `has_match_structure`).

- [ ] TODO-2: **The hook.** In `compute_rand_two_sided_pval()` (the
  `InferenceRandCI` version, next to the Zhang dispatch), before
  `generate_permutations()`: if the registry says `exact_pmf` and `type`
  is `"exact_null"` (or the default has been switched by TODO-7), compute
  the doubled-tail p-value from the PMF and return it, with `r` ignored
  and the sequential-MC machinery untouched. If the registry says
  `exact_moments` and `type` is `"asymptotic_null"`, return the normal
  approximation from the exact moments (coin's default). Unknown `type`
  values error as today. The hook must coexist with the Zhang dispatch:
  Zhang keeps precedence on Bernoulli/matched incidence designs unless the
  caller asks for `"exact_null"` explicitly.

- [ ] TODO-3: **Hypergeometric PMF for fixed-`n_T` designs, binary `y`.**
  `A ~ Hypergeometric(n, n_1, n_T)` via `stats::dhyper` (no kernel needed
  at this size), doubled-tail two-sided p-value in the statistic's
  direction. Test against `fisher.test()`'s one-sided tails (which are the
  same hypergeometric tails) and against the Monte Carlo path at
  `r = 10^5`. Covers `DesignFixediBCRD` and every fixed-sample design that
  randomizes by exchangeable permutation.

- [ ] TODO-4: **Blocked and Bernoulli PMFs.** Blocking: convolve the
  per-block hypergeometrics (`O(Σ_b n_T,b · n_1,b)`); matched pairs:
  reuse `zhang_exact_binom_pval_cpp` at `delta_0 = 0` but with the
  doubled-tail ordering, or document why minlike is kept there; Bernoulli:
  enumerate `(A, n_T − A)` over the two independent binomials for the
  risk-difference statistic. A small C++ kernel in the
  `zhang_exact_speedups.cpp` unity group if the R loops are slow at
  n = 10^4.

- [ ] TODO-5: **Exact moments for linear statistics (Strasser & Weber
  1999).** `E[T]` and `Var[T]` under each randomization law in the table
  for `T = Σ w_i y_i` with general `y`; expose as the `"asymptotic_null"`
  p-value and as a bracket for the randomization CI search
  (`randomization_ci_affine_shift_reuse.md`: the normal-approximation
  interval around `T`'s moments brackets the exact step-function `p(δ)`,
  cutting its first bisection steps). Moments-only, so no default change.

- [ ] TODO-6: **Benchmark rows.** Add `type = "exact_null"` and
  `"asymptotic_null"` rows to the procedure table in
  `R/benchmark/benchmark_model_fits.R` against `coin::oneway_test(...,
  distribution = asymptotic())` and `fisher.test()`; expected EDI time is
  the R6 construction plus microseconds.

- [ ] TODO-7 *(decision-gated, user decision)*: **Default switch.** When
  the registry says `exact_pmf`, make it the default for
  `compute_rand_two_sided_pval()` on those (class, design) pairs. Changes
  default p-values from a Monte Carlo estimate to its exact limit:
  document in `NEWS.md`, the randomization vignette and each affected
  class's roxygen; regenerate the affected `comprehensive_tests` baseline
  rows. If declined, the `type` values stay opt-in and this item closes.

## Out of scope

- Statistics that are not functions of the treated-arm sum (covariate-
  adjusted estimators, likelihood-based statistics): Monte Carlo stays.
- `delta ≠ 0` with binary `y` (the shifted outcome is no longer binary,
  so no hypergeometric form; the moments path still applies).
- Exact PMFs for general integer scores: `exact_rank_tests_shift_algorithm.md`.
- Multi-arm designs (`multi_arm_designs.md`): the multinomial analogue is
  a later extension.

## References

- Strasser, H. and Weber, C. (1999). On the asymptotic theory of
  permutation statistics. *Mathematical Methods of Statistics* 8, 220–250.
- Hothorn, T., Hornik, K., van de Wiel, M. A. and Zeileis, A. (2006). A
  Lego system for conditional inference. *The American Statistician* 60,
  257–263 (the `coin` design; cited for the idea, no code reused).
