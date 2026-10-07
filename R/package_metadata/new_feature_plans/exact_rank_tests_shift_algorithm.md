# Exact Small-Sample Rank Tests via the Streitberg–Röhmel Shift Algorithm

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-41`;
> 2026-10-07, user decision). Additive: a new C++ kernel plus a new `type`
> value on the existing randomization p-value / CI entry points; default
> path unchanged until the decision-gated TODO-6. No Phase 0 dependency.
>
> **Depends on:** `exact_randomization_nulls_closed_form.md → TODO-2`
> (`→ TODO-40`, the exact-null hook). This plan supplies the general
> integer-score PMF that hook calls for rank statistics; the hypergeometric
> in that plan is the 0/1-score special case and serves as a cross-check of
> this kernel.

Date: 2026-10-07. Grew out of the `coin` comparison in the 2026-10-07
benchmark investigation. `coin` and `exactRankTests` are GPL-2 only and EDI
is GPL-3, so the algorithm is reimplemented from the papers; no code is
copied.

## The finding

`InferenceAllSimpleWilcox` has no exact small-sample inference:

- `compute_asymp_two_sided_pval()` calls `stats::wilcox.test(yT, yC - delta,
  exact = FALSE)` (`inference_all_simple_wilcox.R:80`) and
  `compute_asymp_confidence_interval()` calls `wilcox.test(..., conf.int =
  TRUE, exact = FALSE)` (`:106`): the normal approximation with continuity
  correction, at any `n`.
- Its randomization p-value is Monte Carlo over permutations
  (`compute_fast_randomization_distr()` → `compute_wilcox_hl_distr_parallel_cpp`,
  midranks computed in `fast_wilcox_parallel.cpp:42,94`), so at `n = 20` a
  p-value that has a finite exact value is estimated with error `~1/√r`.
- `stats::wilcox.test(exact = TRUE)` is not a fix: it refuses ties and is
  only used below `n = 50`.

`coin` returns exact p-values for any integer-scored linear rank statistic,
with ties, via Streitberg and Röhmel's shift algorithm (`distribution =
exact(algorithm = "shift")`).

## The algorithm

For a two-sample statistic `T = Σ_{i ∈ treated} a_i` with non-negative
integer scores `a_i` and fixed `n_T`, let `N(k, s)` be the number of
`k`-subsets with score sum `s`. Processing subjects one at a time,
`N(k, s) ← N(k, s) + N(k − 1, s − a_i)` (a shift of the previous array by
`a_i`, hence the name). After all `n` subjects, `P(T = s) = N(n_T, s) /
C(n, n_T)`. Cost `O(n · n_T · S)` time and `O(n_T · S)` memory with
`S = Σ a_i`.

- **Ties:** use `2 × midrank`, which is an integer; `S = n(n + 1)`.
- **Size:** `n = 100, n_T = 50`: about `5 × 10^7` cell updates
  (milliseconds in C++); `n = 200`: about `8 × 10^8` (a few hundred ms).
  Rule: exact when `n_T · S ≤ 10^8`, otherwise fall back to Monte Carlo.
- **Overflow:** `C(n, n_T)` exceeds double range near `n = 1030`; keep the
  array as probabilities (divide by the running count) or use long double
  with per-step renormalization. Irrelevant under the size rule but must be
  asserted.
- **Blocks:** per-block PMFs convolved (exact stratified rank-sum, the van
  Elteren family).
- **Matched pairs (signed rank):** a subset-sum DP over the `|d_i|` ranks,
  `O(k · S)`; `stats::psignrank` has no tie handling.
- **General `k`-sample:** the shift algorithm is two-sample; van de Wiel's
  split-up algorithm (2001) covers `k` samples and is out of scope here.

## Proposal

One C++ kernel, `exact_linear_rank_pmf_cpp(scores_int, n_T)` returning the
support and PMF (new `src/exact_rank_shift.cpp`, added to a unity-build
group per the standing conventions), consumed through the exact-null hook
of `→ TODO-40` for `InferenceAllSimpleWilcox`, the stratified Wilcoxon on
blocking designs, and the signed-rank statistic on matched designs. The
same kernel with 0/1 scores reproduces `→ TODO-40`'s hypergeometric.

**Equivalence contract.** Tie-free fixtures: p-value identical to
`stats::wilcox.test(exact = TRUE)` to 1e-12 (two-sided ordering: doubled
smaller tail, matching `compute_two_sided_randomization_pval_from_t0s()`,
and `wilcox.test`'s own convention where they coincide). Tied fixtures:
agree with the Monte Carlo path at `r = 10^5` within its band. The
0/1-score case equals `dhyper`. `coin` may be used in a test as an
independent oracle (a Suggests-only test dependency), never as source.

## TODOs

- [ ] TODO-1: **Kernel.** `exact_linear_rank_pmf_cpp(scores_int, n_T)`
  with the size rule and overflow guard above; returns support and PMF.
  Unit tests: tiny cases by brute-force enumeration (`n ≤ 12`), the
  hypergeometric special case, a tied fixture against `coin` as oracle.

  **References (roxygen-ready in the house `@references` style; rotate into
  the kernel's and `InferenceAllSimpleWilcox`'s docs when implemented; use
  `\enc{Röhmel}{Roehmel}` if `R CMD check` objects to the non-ASCII name):**

  ```
  #' @references Streitberg, B., and Röhmel, J. (1986). "Exact distributions for
  #'   permutation and rank tests: An introduction to some recently published
  #'   algorithms." \emph{Statistical Software Newsletter}, 12(1), 10-17, for the
  #'   shift algorithm that computes the exact null distribution of an
  #'   integer-scored linear rank statistic by a dynamic program over subjects.
  #'   Streitberg, B., and Röhmel, J. (1987). "Exakte Verteilungen für Rang- und
  #'   Randomisierungstests im allgemeinen c-Stichprobenproblem." \emph{EDV in
  #'   Medizin und Biologie}, 18(1), 12-19, for the extension to tied scores and
  #'   the general c-sample problem. See also Hothorn, T., Hornik, K., van de
  #'   Wiel, M. A., and Zeileis, A. (2006). "A Lego system for conditional
  #'   inference." \emph{The American Statistician}, 60(3), 257-263,
  #'   \doi{10.1198/000313006X118430}, for the same algorithm as implemented in
  #'   \pkg{coin} (GPL-2; used here only as a test oracle, no code reused).
  ```


- [ ] TODO-2: **Rank-sum p-value.** Implement `InferenceAllSimpleWilcox`'s
  entry in `→ TODO-40`'s registry as `exact_pmf` on fixed-sample designs
  when the size rule holds: midranks × 2, `T` = treated rank sum,
  doubled-tail p-value. `compute_rand_two_sided_pval(type = "exact_null")`
  then returns it without permutations.

- [ ] TODO-3: **Exact Hodges–Lehmann CI.** For the shift model, invert the
  exact distribution: tie-free, the interval endpoints are order statistics
  of the pairwise differences at the exact quantiles of `U` (as
  `wilcox.test(exact = TRUE, conf.int = TRUE)` does); with ties, the ranks
  change with `δ`, so recompute the PMF at each candidate `δ` inside the
  existing CI search (`compute_rand_confidence_interval()`), which is still
  cheap under the size rule. Exposed as `compute_rand_confidence_interval(type
  = "exact_null")`.

- [ ] TODO-4: **Blocks and pairs.** Convolution over blocks for
  `DesignFixedBlocking`; signed-rank subset-sum for matched designs
  (`InferenceAllKKWilcoxIVWC`'s matched component is the natural first
  consumer; check its statistic before wiring).

- [ ] TODO-5: **Benchmark rows.** `type = "exact_null"` Wilcoxon rows at
  `n ∈ {20, 50, 100}` against `wilcox.test(exact = TRUE)` and
  `coin::wilcox_test(distribution = exact())` in the procedure table.

- [ ] TODO-6 *(decision-gated, user decision)*: **Default for small `n`.**
  Make the exact p-value and CI the default for `InferenceAllSimpleWilcox`
  when the size rule holds, replacing both the Monte Carlo randomization
  path and the `exact = FALSE` asymptotic calls. Changes default results
  (Monte Carlo estimate → exact limit; normal approximation → exact):
  document in `NEWS.md`, the roxygen and the vignette; regenerate the
  affected `comprehensive_tests` baseline rows. If declined, `"exact_null"`
  stays opt-in and this item closes.

## Out of scope

- `k`-sample exact distributions (split-up algorithm); multi-arm designs.
- Non-integer scores (van der Waerden, ridit) without rounding; a rounded
  variant is a later extension.
- Any change to the asymptotic path's formulas.

## References

House `@references` style (issue numbers included so the block above pastes
into roxygen unchanged):

- Streitberg, B., and Röhmel, J. (1986). "Exact distributions for permutation
  and rank tests: An introduction to some recently published algorithms."
  *Statistical Software Newsletter*, 12(1), 10-17.
- Streitberg, B., and Röhmel, J. (1987). "Exakte Verteilungen für Rang- und
  Randomisierungstests im allgemeinen c-Stichprobenproblem." *EDV in Medizin
  und Biologie*, 18(1), 12-19.
- van de Wiel, M. A. (2001). "The split-up algorithm: a fast symbolic method
  for computing p-values of distribution-free statistics." *Computational
  Statistics*, 16(4), 519-538 (k-sample case; out of scope here).
- Hothorn, T., Hornik, K., van de Wiel, M. A., and Zeileis, A. (2006). "A Lego
  system for conditional inference." *The American Statistician*, 60(3),
  257-263, doi:10.1198/000313006X118430 (the `coin` implementation; idea only,
  no code reused).
- Hothorn, T., and Hornik, K. (2002). "Exact nonparametric inference in R."
  *COMPSTAT 2002 Proceedings in Computational Statistics*, Physica-Verlag
  (the `exactRankTests` package; idea only, no code reused).
