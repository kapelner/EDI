# Randomization CI for Incidence via Rigdon & Hudgens (2015)

> **Depends on:** none architecturally. Sibling/alternative to
> `incidence_randomization_cis.md` (that plan's TODO-17k, slated v1.1.0,
> commits to making the *existing* Zhang exact-combinatorics machinery
> estimand-aware -- this plan is a different, self-contained published
> construction, not a generalization of Zhang's). Touches
> `InferenceRandCI$compute_rand_confidence_interval()`'s incidence branch
> (`inference_all_abstract_rand_ci.R`) and needs a new kernel file (working
> name `inference_helpers_rigdon_hudgens.R`).
> **Release target: v2.0.0** (user decision, 2026-09-16).

Written 2026-09-16, following a `path_audits.html` NTS-cell audit that
surfaced randomization CI for every incidence class rendering "Not
Theoretically Supported" (white). It isn't -- it's disabled as an
emergency stopgap (`incidence_randomization_cis.md`, 2026-08-27) after a
real scale-mismatch bug, and a real published method exists that this
package has not implemented. Per user decision, the audit's `unsupported`
classification changes to `not_implemented` for these cells once this
plan exists and is scoped (see "Audit reclassification" below); ordinal's
randomization CI stays genuinely NTS (unaffected by this plan -- see
`inference_all_abstract_rand.R`'s ordinal exclusion, a different,
class-structural reason with no comparable published fix on the table).

## Why Rigdon & Hudgens, not (only) Zhang-estimand-aware

`incidence_randomization_cis.md` already frames the core difficulty: a
randomization CI for a binary outcome cannot reuse the package's generic
continuous-response machinery, which inverts a test at a *constant
additive shift* `delta` applied to every unit's response -- for a `{0,1}`
outcome that shift model doesn't make sense (you cannot add an arbitrary
real `delta` to a Bernoulli response and stay in `{0,1}`), and the
existing Zhang exact-combinatorics path that *does* handle binary outcomes
is hard-coded to the log-odds-ratio scale. That plan's Option 2 proposes
fixing this by deriving a per-estimand "exact shift model" (odds-ratio,
risk-ratio, risk-difference, each its own combinatorial kernel) grafted
onto the existing Zhang machinery.

Rigdon, J. and Hudgens, M.G. (2015), "Randomization inference for
treatment effects on a binary outcome," *Statistics in Medicine* 34(6),
924-935 ([PMC4459717](https://pmc.ncbi.nlm.nih.gov/articles/PMC4459717/)),
solves the risk-difference case directly and does not reuse or extend
Zhang's machinery at all -- it's a self-contained construction built
specifically for a `{0,1}` outcome and an additive estimand, requiring:

- **No superpopulation/random-sampling assumption** -- purely
  randomization-based (SUTVA/no-interference plus a known randomization
  mechanism), matching this package's own design-based inference
  philosophy elsewhere.
- **No constant-treatment-effect assumption.** Individual effects
  `delta_j = y_j(1) - y_j(0) in {-1, 0, 1}` are allowed to vary
  unit-to-unit -- the paper explicitly argues the alternative (assuming
  `delta_j` is the same for every unit) is "unlikely or implausible,
  particularly if the outcome is binary." This is a strictly weaker,
  more defensible assumption set than the additive-shift model the
  package's generic bisection already uses for continuous responses.
- **Exact, finite-sample coverage** (`>= 1 - alpha`, guaranteed
  conservative, not asymptotic) with a guaranteed CI width `<= 1`.

The estimand is `tau = sum(delta_j) / n` -- the average per-unit causal
effect on the `{0,1}` scale, i.e. exactly the population risk difference.
This maps directly onto EDI's `mean_difference`/risk-difference-tagged
incidence classes (per `incidence_randomization_cis.md`'s own class list:
`Avg Delta`, `CMH`, `Extended Robins`, `G Comp Risk Delta`, `KK G Comp Risk
Delta`, `KK Newcombe Risk Delta`, `Miettinen Risk Delta`, `Newcombe Risk
Delta`, `Risk Delta`, `Wald`) -- **not** the log-odds-ratio or risk-ratio
families, which would still need Option 2's separate per-estimand kernels
(or a different published method) on their own scales. This plan is
scoped to the risk-difference estimand family only; it does not claim to
close the other estimand families' gap.

## The two methods (both from the same paper)

**Method 1 -- attributable-effects prediction sets, Bonferroni-combined.**
Define the attributable effects among the treated and untreated,
`A1(Z, delta) = sum(Z_j * delta_j)` and `A0(Z, delta) = sum((1-Z_j) *
delta_j)`, with `A1 + A0 = n * tau` exactly. For each candidate value of
`A1` (there are only `m + 1` of them, `m` = number treated) and each
candidate value of `A0` (`n - m + 1` of them), a Fisher-exact-style
randomization p-value under the resulting sharp null is computable in
closed form from the observed `(Z_j, Y_j)` pairs, since under a sharp null
every unit's *other* potential outcome becomes known. Inverting each
one-dimensional family separately gives a `(1 - alpha/2)` prediction set
for `A1` and one for `A0`; Bonferroni-combining them (their paper's
Proposition 1) gives a valid `(1 - alpha)` confidence set for `tau` via
`{(L1+L0)/n, ..., (U1+U0)/n}`. **Only `n + 2` hypothesis evaluations
total** -- cheap, closed-form, no simulation. The paper reports the naive
un-adjusted combination under-covers (92% empirical at nominal 95% in
their example), so the Bonferroni step is load-bearing, not a
belt-and-suspenders extra.

**Method 2 -- full randomization-test inversion.** Invert the ordinary
two-sample mean-difference permutation test (`T = mean(Y | Z=1) - mean(Y |
Z=0)`) directly over the space of individual-effect vectors `delta`
compatible with each candidate `tau`, exploiting that units sharing the
same `(Z_j, Y_j)` pair produce identical test statistics to collapse the
search from `2^n` to `O(n^4)` hypotheses. Exact and (per the paper) tends
to be no wider than Method 1, but the authors themselves recommend it only
for `n <= 100` and note stratified designs blow up to `O(max(n_1, ...,
n_k)^{4k})` -- infeasible at EDI's typical comprehensive-test sample sizes
(multiple existing incidence audit rows run at `n` in the hundreds).

**Implementation target: Method 1 first.** `O(n)` cost makes it practical
at any `n` this package tests at; Method 2 is worth scoping as an
optional small-`n` refinement (tighter intervals, still exact) but is not
the default path. A faster fully-polynomial alternative building on this
same paper exists (Li, Ding & Mealli-style follow-up work, e.g. the 2016
*Statistics in Medicine* comment/response exchange and later exact-CI
papers) and is worth a literature re-check at implementation time in case
it supersedes Method 2 outright for the cases where exactness beyond
Method 1's conservativeness is wanted -- out of scope to pre-judge here.

## Proposal

- New kernel, e.g. `inference_helpers_rigdon_hudgens.R`: closed-form
  Method 1 (attributable-effects Bonferroni prediction sets) operating on
  `(Z, Y)` alone (design/response only, like `zhang_get_exact_stats()`),
  independent of which specific incidence class calls it.
- `InferenceRandCI$compute_rand_confidence_interval()`'s incidence branch:
  for classes tagged in the risk-difference estimand family (reuse or
  extend the existing `EDI_INFERENCE_ESTIMAND_TAGS` lookup that
  `incidence_randomization_cis.md`'s Option 1 already proposes as a gate),
  dispatch here instead of `zhang_ci_exact_combined()`. Non-risk-difference
  incidence estimands are unaffected by this plan and stay however
  `incidence_randomization_cis.md`'s own TODO-17k resolves them.
  Matched-pair designs need their own check against the paper's setup
  (written for a completely randomized two-arm mechanism) before reuse --
  do not assume the `d_plus`/`d_minus` matched-pair machinery in
  `zhang_get_exact_stats()` transfers unchanged.
- Remove the incidence `stop()` stopgap and restore `"rand"` in
  `run_all_inference_class_applicable_methods()`'s incidence branch for
  the now-covered risk-difference classes specifically (not blanket, since
  other estimand families remain unresolved pending
  `incidence_randomization_cis.md`).

## Audit reclassification (path_audits.html)

`path_audits_source.R`'s incidence rows currently have `rci_resp=""` for
every incidence class, which `cell_rand_c()`/`cell_brt_c()` render as
`unsupported` (NTS, white) -- correct for a hard-`stop()`ed path with no
implementation on the table, but no longer the right label now that a
concrete, scoped implementation plan exists. Once this plan is created
(this commit), the risk-difference-estimand incidence classes' rand-CI
cell should move from NTS to `not_implemented` (grey/NI) via
`unsupported_methods` -> `not_implemented_methods` (or, more precisely,
`rci_resp` gaining a distinct "known gap, not theoretical impossibility"
signal the cell functions can key off -- implementation detail for the
code-side TODO below). Ordinal's randomization CI is untouched: it is
excluded for a genuine class-structural reason unrelated to this paper's
scope, and stays NTS.

## Tests

- Method 1 validated by brute force at small `n` (enumerate all `2^n`
  potential-outcome-consistent `delta` vectors, confirm the closed-form
  prediction sets match direct enumeration) before trusting it at scale --
  same validation discipline the existing Zhang kernels presumably used.
- Empirical coverage simulation matching the paper's own reported
  (conservative) coverage behavior, not exact nominal-`alpha` coverage --
  don't write a test that wrongly expects exact-to-alpha coverage.
- Regression test asserting risk-difference-family incidence classes now
  return a real (non-`NA`, non-error) `rand` CI on a plain Bernoulli
  design, and that it is *not* on the log-odds-ratio scale (guards against
  reintroducing `incidence_randomization_cis.md`'s original bug).
- `path_audits.html`: confirm the NTS -> NI cell move for exactly the
  risk-difference-estimand incidence classes' rand-CI cells, and that
  ordinal's rand-CI cells are unchanged.

## Implementation TODOs

- [ ] TODO-1: Decide the exact estimand-tag gate (which
  `EDI_INFERENCE_ESTIMAND_TAGS` values route here) and confirm each
  candidate class's `compute_estimate()` really is `tau` as this paper
  defines it (a `{0,1}`-scale population average effect), not merely
  similarly named.
- [ ] TODO-2: Implement Method 1 (attributable-effects Bonferroni) as a
  design/response-only kernel; brute-force validation at small `n`.
- [ ] TODO-3: Wire into `compute_rand_confidence_interval()`'s incidence
  branch behind the TODO-1 gate; remove the `stop()` stopgap and restore
  `"rand"` in `run_all_inference_class_applicable_methods()` for the
  now-covered classes only.
- [ ] TODO-4: Matched-pair applicability check (paper assumes completely
  randomized two-arm; verify or explicitly exclude matched designs).
- [ ] TODO-5: `path_audits_source.R` cell reclassification (NTS -> NI) for
  the covered classes; verify ordinal is unaffected.
- [ ] TODO-6 (optional, not default path): Scope Method 2 (or a faster
  published successor found at implementation time) as a small-`n`
  tighter-interval option.
- [ ] TODO-7: Cross-reference from `release_v2_0_0.md`/`_master.md` (this
  commit) and from `incidence_randomization_cis.md` (note this plan as the
  chosen path for the risk-difference estimand family specifically, not a
  replacement for that plan's TODO-17k on the other estimand families).
