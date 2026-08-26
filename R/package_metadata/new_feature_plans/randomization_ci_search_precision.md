# Randomization-CI Search Precision: Anytime-Valid Confidence Sequences

> **Depends on:** none architecturally (touches only `InferenceRandCI`'s
> shared bisection machinery in `inference_all_abstract_rand_ci.R` /
> `inference_ext_sequential_mc_pval.R`); no relation to the hierarchy
> migration or design-side work. (Global ordering: see `_master.md` — not
> yet scheduled into a phase; needs a Phase-0-style "pursue now or defer"
> decision, since it changes default runtime behavior of every
> `InferenceRandCI` subclass's `compute_rand_confidence_interval()`.

## Symptom (2026-08-26)

Live `InferenceSuite$run_all_inference()` runs surfaced two related
observations in the same session:

1. **Very wide `rand` CIs, identical across unrelated classes.** Many
   different mean-difference-estimand classes (`Avg Δ`, `CMH`, `Extended
   Robins`, `G Comp Risk Δ`, `KK Newcombe Risk Δ`, `Wald`, ...) all reported
   the *exact same* `rand` CI, `[-4.33e-09, 2.51]`, despite having visibly
   different standard errors (0.06–0.12). The lower bound sitting at
   (numerically) zero and the upper bound landing on a value shared across
   every class is consistent with the search's documented conservative
   fallback (`compute_rand_confidence_interval()`'s own roxygen: "When the
   randomization p-value does not drop below alpha/2 anywhere within the
   search radius ... a conservative CI bound is returned at the search
   boundary") being hit almost everywhere, with the boundary itself
   dominated by the *shared* `max_radius_scale_mult * sd(y)` term rather
   than each class's own `se_guess`.
2. **A `rand` CI that excludes its own point estimate.** A Hodges-Lehmann
   shift class reported `est = 1.00` with `rand` CI `[-0.035, 0.460]` — an
   interval that does not contain the point estimate at all, even though
   the randomization null distribution this CI inverts is built from the
   *same* estimator (`approximate_randomization_distribution_beta_hat_T()`
   re-applies `compute_estimate()` to shifted responses under re-randomized
   assignments), so the two quantities are not independently defined and
   should not disagree this badly under correct search behavior.

Neither symptom reproduced on a first synthetic-data attempt with
`InferenceAllSimpleWilcox` (`est=1.158`, `rand CI = [0.267, 1.853]`, which
does contain the estimate, identically whether or not Monte Carlo early
stopping was enabled) — the failure is data/design-dependent, not universal,
which is itself consistent with a **multiplicity** problem: it shows up when
many bisection "looks" happen to compound unluckily, not on every run.

This is the same open issue diagnosed earlier in the same session (before
this report), from a *different* observed symptom ("CI's that do not cover
zero but have pval > 5%"): a CI that is either too narrow (falsely excludes
the null when the point-estimate test does not reject) or, as seen here, too
wide/off-center relative to what a converged bisection should produce.

## Root cause

`InferenceRandCI$compute_rand_confidence_interval()`
(`R/inference_all_abstract_rand_ci.R`) finds each CI bound by bisecting on
`delta` until the randomization p-value at `delta` crosses `alpha/2`. Each
p-value evaluation, when `r >= 200` (the default `mc_enable` threshold), is
itself a **sequential Monte Carlo estimate with early stopping**
(`InferenceExtSequentialMCPval$compute_two_sided_pval_with_sequential_mc()`,
`R/inference_ext_sequential_mc_pval.R`): it draws randomization replicates in
batches and stops as soon as a Clopper-Pearson-style confidence band for the
running p-value estimate excludes the target threshold at
`mc_conf_level` (default `0.99`) confidence.

That 99% confidence is **per look, not per search**. A single CI-bound search
can consult this early-stopped estimator many times:

- up to ~7 times in `expand_bound()` (bracket expansion),
- up to ~2×30 times in `compute_ci_by_inverting_the_randomization_test_iteratively()`'s
  NA-repair loop and its main bisection `repeat` loop,
- with two bounds per CI (lower, upper) and a shared `ci_pval_cache` that
  only dedupes *identical* deltas (rounded to `pval_cache_resolution`), not
  nearby ones.

So a single CI can rest on 30–60+ independent 99%-confidence looks. If each
look's true error rate is exactly 1%, the chance that **at least one** of 40
looks is wrong is `1 - 0.99^40 ≈ 33%` — not a tail case, a coin flip. And a
wrong look does not just produce a slightly-off final answer: because the
bisection uses each look's classification (`pval_m >= pval_th` or not) to
decide which half of the bracket to keep, one wrong look near the true
crossing point **discards the correct half of the bracket** and the search
converges confidently to the wrong location. This is exactly the shape of
both symptoms above: a boundary hit (the search convinced itself it would
never find significance) and an off-center bound (the search converged to a
crossing point that was never really there).

The `max_radius`/`expand_bound()` machinery amplifies this for symptom 1
specifically: when the *true* crossing point is genuinely outside the search
radius (low power, few unique permutations), the "conservative fallback" is
correct behavior by design — but when it's a **false negative** caused by
early-stopping noise at the boundary itself, the search has no way to tell
the two cases apart, and reports the same message either way.

## What shipped now (2026-08-26): final high-precision confirmation pass

`high_precision_confirm_and_refine_ci_bound()` (new private method,
`InferenceRandCI`, `inference_all_abstract_rand_ci.R`) is a **pragmatic
stopgap**, not the real fix:

- After the cheap (early-stopping-enabled) bisection converges to a bound —
  whether via the normal tolerance-convergence exit or the conservative-
  boundary exit — the search spends **one full-enumeration (`mc_enable =
  FALSE`, no early stopping) re-evaluation** of the p-value at both ends of
  the final bracket.
- If full precision agrees with the cheap conclusion (same side of
  `alpha/2`), the bound is returned as-is — no extra cost beyond those 2
  evaluations.
- If full precision **disagrees** (the cheap bracket's endpoints land on the
  same side once evaluated exactly, meaning the "crossing" the cheap search
  thought it found there was noise), the search either falls back to the
  verified non-significant end (conservative, matching the existing
  fallback philosophy) or, if the endpoints still straddle the threshold at
  full precision, runs a short (≤15-evaluation) full-precision re-bisection
  between them to correct the answer.
- Controlled by `ci_search_control$high_precision_confirm` (default `TRUE`);
  `compute_rand_confidence_interval()` always leaves it on.

**Why this is not sufficient on its own:** it only corrects noise that
survives to the *final* converged bound. It does nothing about the ~30-60
cheap looks that steered the bracket to get there — if an early wrong look
sends the bisection down entirely the wrong branch, the "final" bracket it
converges to may not even contain the true crossing point, and the
confirmation pass has nothing left to correct (both re-checked endpoints can
still agree with each other while both being wrong, if the search's whole
trajectory drifted off the true crossing early and never came back). It also
does not reduce the total number of noisy looks taken along the way, so it
does not improve runtime or give any formal guarantee about the final
answer's coverage — it only lowers the probability that the *specific* noise
event visible in the two symptoms above (a single bad look right at
convergence) survives into the returned number.

## The real fix: anytime-valid confidence sequences

The principled fix is to stop treating each look's Clopper-Pearson band as
independently correct at `mc_conf_level`, and instead use a **confidence
sequence (CS)**: a sequence of confidence sets `C_1, C_2, C_3, ...` (indexed
by the number of randomization draws so far) such that

```
P( true p-value ∈ C_n for ALL n simultaneously ) >= 1 - alpha_cs
```

A CS is valid to peek at **any** stopping time — including a stopping time
chosen adaptively by the bisection's own bracket logic — without any
multiplicity correction, because the simultaneous-coverage guarantee is
already baked into how the sequence is constructed (typically via a
nonnegative supermartingale / "betting" argument, or a law-of-the-iterated-
logarithm boundary). This is precisely the tool that makes "keep drawing
until you're confident, then stop and trust the current estimate" *safe* —
which is exactly what `sequential_mc_band_excludes_threshold()` is trying to
do today with a per-look band that was never designed for repeated peeking.

### Concretely, for this package

1. **Replace `compute_two_sided_randomization_pval_band()`'s per-look
   Clopper-Pearson band** (`inference_ext_sequential_mc_pval.R`) with a
   confidence sequence for a Bernoulli mean (the p-value is estimated as a
   proportion of randomization draws whose statistic is at least as extreme
   as observed). The standard modern choice is a **betting-based CS**
   (Waudby-Smith & Ramdas, *"Estimating means of bounded random variables by
   betting"*, 2020/2023) — tighter in practice than log-LIL-based CSs for
   the small-to-moderate sample sizes typical here (a few hundred to a few
   thousand randomization draws per look), and it degrades gracefully to a
   normal-approximation width as the draw count grows, so it should not
   regress the common (non-adversarial) case's stopping time much.
2. **One CS budget shared across a whole CI-bound search, not one per
   look.** Fix `alpha_cs` once per `compute_rand_confidence_interval()` call
   (e.g. `alpha_cs = 0.01`, replacing today's per-look `mc_conf_level =
   0.99`) and construct the CS so that *every* p-value evaluation made
   anywhere during that bound's search — bracket repair, expansion,
   bisection — draws from the *same* running sequence of confidence sets at
   the *same* nominal level, rather than each call getting its own
   independent 99%-confidence snapshot. This is the step that actually
   removes the multiplicity problem, as opposed to the shipped stopgap,
   which only re-checks the final answer.
3. **Delta-indexed reuse.** Because the bisection evaluates the p-value at
   many different `delta` values (not one fixed parameter being estimated),
   the CS machinery needs to be keyed per-delta — each `delta`'s running
   randomization draws build their own sequence. The existing
   `ci_pval_cache`/`reuse_key` machinery
   (`compute_randomization_ci_pval_cached()`,
   `build_randomization_distribution_cache_key()`) is close to the right
   shape for this already (it caches finished p-values per rounded delta);
   it would need to instead cache the **running CS state** (cumulative
   sufficient statistics for the betting martingale, not just a final
   p-value) so that a second look at a nearby `delta` — which happens
   constantly during bisection, since consecutive midpoints cluster near the
   true crossing — can resume rather than restart the sequence, or at least
   share the draw budget accounting.
4. **Stopping rule.** Replace
   `sequential_mc_band_excludes_threshold(t0s, t, threshold, conf_level)`
   with a CS-boundary check: stop drawing once the CS's current interval for
   the p-value excludes `threshold`, exactly as today, but now that "stop"
   decision is valid no matter when during the whole search it happens to
   fire — no per-look budget to divide up, no need for the confirmation pass
   in `high_precision_confirm_and_refine_ci_bound()` at all (it becomes
   provably redundant once the CS covers the whole search, and can be
   deleted rather than kept as permanent stopgap machinery).
5. **`max_expansions`/30-iteration bisection cap interaction.** With a CS,
   the number of "looks" no longer needs a hard cap for validity reasons
   (validity holds at every step), but the existing caps should stay as
   runtime/timeout guards — just decoupled from the confidence-budget
   reasoning, since that reasoning moves entirely into the CS itself.

### Simpler intermediate option (if the full CS redesign is deferred)

A much smaller change that still meaningfully helps, if the team wants
something before the full redesign: **Bonferroni-correct the existing
per-look Clopper-Pearson band** by a conservative fixed budget of looks.
Instead of `mc_conf_level = 0.99` per look, use
`1 - (1 - target_conf_level) / max_looks_estimate`, where
`max_looks_estimate` is a generous constant covering
`max_expansions + 2*30` (today's realistic look-count ceiling per bound).
This under-corrects for adaptive stopping in the same technical sense a
Bonferroni correction always does relative to a sequential test, but it is a
same-file, few-line change with no new statistical machinery, and it would
have caught both symptoms above (99.9%+ effective per-look confidence
instead of 99%). It should be treated as a bridge, not a destination — it
does not remove `high_precision_confirm_and_refine_ci_bound()`'s stopgap
role, and it makes every early-stopped p-value evaluation slower (wider
per-look confidence requires more draws before the band excludes the
threshold), trading some of the runtime win sequential MC was added for in
the first place.

## Implementation TODOs

1. **Decision (Phase-0-style):** pursue the full anytime-valid CS redesign
   now, ship the Bonferroni bridge only, or leave the 2026-08-26 high-
   precision-confirmation stopgap as the standing behavior. This changes
   default runtime behavior of every `InferenceRandCI` subclass and should
   be an explicit user decision, not an implementation-time default.
2. If pursuing the full redesign: implement a betting-CS helper (new file,
   e.g. `inference_ext_anytime_valid_cs.R`, mirroring
   `inference_ext_sequential_mc_pval.R`'s structure) with its own focused
   unit tests (coverage simulation: repeatedly draw from a known Bernoulli
   process, confirm the CS's simultaneous-coverage rate empirically matches
   `1 - alpha_cs` across many stopping times, the same kind of validation
   `inference_ext_sequential_mc_pval.R`'s existing tests likely already do
   for the current per-look band — audit and reuse that harness).
3. Wire the CS into `compute_two_sided_pval_with_sequential_mc()` and
   `sequential_mc_band_excludes_threshold()` behind a control flag first
   (e.g. `ci_search_control$mc_method = c("clopper_pearson_per_look",
   "anytime_valid_cs")`), default to the existing behavior, and only flip
   the default once a full `test-ci-rand.R` + `test-rand-ci-model-scale-
   classification.R` run plus a targeted coverage-simulation sweep (many
   synthetic datasets, checking empirical CI coverage against nominal
   `1 - alpha`) confirms no regression.
4. Once the CS path is the default and validated, delete
   `high_precision_confirm_and_refine_ci_bound()` and its
   `high_precision_confirm` control flag — redundant once the underlying
   search is itself valid at every look.
5. Re-run the two originally-reported scenarios (or close synthetic
   analogues — the exact datasets were not saved) to confirm the specific
   symptoms in this report no longer reproduce.
6. Update `compute_rand_confidence_interval()`'s roxygen (currently
   documents the per-look `mc_conf_level` Clopper-Pearson band) to describe
   the CS-based guarantee instead.

## Testing/verification plan

- Unit-level: CS coverage simulation (TODO-2 above) is the load-bearing new
  test — without it, "anytime-valid" is just an unverified claim about a new
  formula.
- Integration-level: extend `test-ci-rand.R` with a case that deliberately
  uses a low-power design/small effect (the shape that triggered symptom 1)
  and asserts the returned CI is not implausibly tied to a value shared
  across unrelated classes fit to the same response — the closest thing to
  a regression test for symptom 1 without the original dataset.
- No change expected to any *non*-randomization CI method (Wald, score,
  gradient, likelihood-ratio, bootstrap family) — this plan is scoped
  entirely to `InferenceRandCI`.
