# Randomization warm-start chaining: timing on slow-converging classes (2026-11-21)

Owner request 2026-11-21, follow-up to v1.0.6-TODO-25 (owner ruling 2026-11-19: randomization replicates never
chain warm starts; every permutation starts from the full-data fit). That ruling's speed evidence was Poisson,
NegBin and PropOdds only. This study measures the slow / non-concave classes. No package code was changed.

## Verdict

Chaining is not materially faster for any class measured. The largest gains, after 5 to 9 interleaved repeats, are
1.10x to 1.12x, and they save under 0.1 s per 400 replicates. Identical-output classes show 0.88x to 1.17x from
noise alone on this (loaded) machine. Nothing reaches the 1.3x threshold, so no owner decision is raised and the
blanket ruling stands. The fork path at 2 cores was not timed, since nothing sped up at 1 core.

## Method

- Variant code: the pre-TODO-61 `compute_randomization_distr_via_reused_worker_states` loop from
  `git show 3395b6c3^:R/EDI/R/inference_all_abstract_rand.R`. Its gate was replaced with an option switch, so
  base-only and chained runs execute the same function and differ only in the chaining block. With the switch off
  the function is identical to the current loop (checked with `diff`). The function was injected into each
  object's private environment in the R session only (`pkgload::load_all(compile = FALSE)`). A third variant
  ("chain, keep Fisher") also kept the full-data Fisher warm start, which the old chaining dropped. It made no
  difference, so it is not tabulated.
- Data: n = 150, `~ x1 + x2`, a pair random effect (sd 0.6) and treatment effect 0.4. KK classes use
  `DesignFixedBinaryMatch` with 75 pairs. Stereotype, partial PO and ZOIB use `DesignFixedBernoulli`. Survival is
  Weibull with about 15% right-censoring.
- Timing: `compute_rand_two_sided_pval(r, permutations = <fixed>)` on a fresh object each run (estimate fitted
  outside the timer), `num_cores = 1`, `OMP_NUM_THREADS = 1`, one discarded warm-up, and variants interleaved
  ABC/CBA. The table gives medians. Iteration counts are not exposed uniformly by the backends, so time per
  replicate is the proxy.
- Correctness: max |base - chained| over the null statistics, the NA counts, and, for up to 15 replicates that
  differ by more than 1e-4, a fresh `compute_estimate()` on the permuted design as reference ("closer to fresh"
  columns). The fresh-fit reference is not valid for CondLogitGLMM (see finding 2).
- Total compute about 45 min, on 1 core.

## Results

| Class | n | r | reps | base-only s | chained s | speedup | max stat diff | reps differing > 1e-4 (> 1e-2) | NA base / chained | closer to fresh: base / chained |
|---|---|---|---|---|---|---|---|---|---|---|
| InferenceIncidKKCondLogitGLMMOneLik | 150 | 400 | 9 | 0.52 | 0.46 | 1.12 | 1.2e-8 | 0 | **43 / 7** | n/a (see finding 2) |
| InferencePropKKGLMM | 150 | 400 | 9 | 1.09 | 0.99 | 1.10 | 1.3e-2 | 330 (14) | 0 / 4 | 2 / 13 |
| InferenceCountKKGLMM | 150 | 400 | 5 | 11.49 | 10.93 | 1.05 | 4.2e-9 | 0 | 0 / 0 | – |
| InferenceOrdinalKKGLMM | 150 | 400 | 3 | 19.02 | 18.96 | 1.00 | 4.8e-9 | 0 | 0 / 0 | – |
| InferenceOrdinalKKCLMM | 150 | 400 | 3 | 18.43 | 18.90 | 0.98 | 0 | 0 | 0 / 0 | – |
| InferenceOrdinalKKCLMMProbit | 150 | 400 | 3 | 22.73 | 22.63 | 1.00 | 0 | 0 | 0 / 0 | – |
| InferenceOrdinalStereotypeLogitRegr | 150 | 150 | 2 | 7.78 | 7.83 | 0.99 | 0 | 0 | 1 / 1 | – |
| InferenceSurvivalGLMMWeibullFrailtyNormalOneLik | 150 | 400 | 3 | 0.98 | 0.84 | 1.17 | 0 | 0 | 0 / 0 | – |
| InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik | 150 | 400 | 3 | 1.43 | 1.34 | 1.07 | 0 | 0 | 0 / 0 | – |
| InferenceOrdinalPartialProportionalOddsRegr | 150 | 400 | 3 | 0.49 | 0.46 | 1.06 | 5.3e-3 | 212 (0) | 0 / 0 | 7 / 8 |
| InferencePropZeroOneInflatedBetaRegr | 150 | 400 | 3 | 0.79 | 0.90 | 0.88 | 5.6e-4 | 68 (0) | 0 / 0 | 3 / 12 |
| InferenceContinKKGLMM | 150 | 400 | 3 | 0.15 | 0.17 | 0.92 | 0 | 0 | 0 / 0 | – |
| InferenceCountKKCondPoissonOneLik | 150 | 400 | 3 | 0.21 | 0.22 | 0.95 | 0 | 0 | 0 / 0 | – |

The first-pass 3-repeat run showed 1.32x for CondLogitGLMM and 1.33x for PropKKGLMM. The first-pass times ranged
from 1.2 s to 2.1 s, and with 9 repeats both fell to about 1.1x. The p-values were equal across variants except
for CondLogitGLMM (0.112 base-only vs 0.102 chained, because different replicates are NA) and PropKKGLMM (0.0050 vs
0.0051).

Why the classes were chosen: every registry class with `likelihood_concave = FALSE`, or a mixed / frailty model
with an iterative fit (KK GLMMs for each response type, the CLMM family, both Weibull frailty OneLik classes,
stereotype logit), plus three non-KK iterative fits with many parameters (partial PO, ZOIB, KK conditional Poisson).
The IVWC variants were skipped because each has a OneLik twin. The slowest per replicate are the CLMMs and
OrdinalKKGLMM (about 50 ms) and stereotype logit (about 50 ms). Seven classes give bit-identical distributions
under chaining: either their rand-path fit does not take the carried warm start, or it reaches the same iterate
from any start. For those seven, chaining cannot change the speed.

## Side findings (independent of chaining)

1. **CondLogitGLMM: replicates go NA depending on the start.** With the full-data warm start (the current rule),
   43 of 400 replicates are NA. Chained, 7 are NA. With warm starts disabled, 0 of 60 are NA (base-only 5 of 60 on
   the same draws). The NA replicates are dropped (`na.rm = TRUE`), so the p-value moves (0.112 vs 0.102). The
   cleanest case: on the mirrored assignment `1 - w` the worker returns NA, while a fresh fit gives exactly -0.6247
   (the observed value is 0.6247). The full-data start is the mirror image of that optimum. This is the "explain
   why the NA count changes" question that v1.0.6-TODO-7 left open; TODO-61's base-only rule makes it more
   frequent here than the old chaining did. NA with no warning is the v1.0.6-TODO-67 pattern.
2. **CondLogitGLMM: the rand-worker statistic is not the fresh-fit estimate on permuted data.** Cold-start worker
   replicates match base-start ones to 9e-9, and on the original assignment the worker gives the observed estimate
   exactly. But against `compute_estimate()` on a design with the permuted `w` (same y, X, m), 58 of 60 replicates
   differ by more than 1e-3 (max 0.44, correlation 0.90, sd 0.39 vs 0.43). For CountKKGLMM the same check matches
   to 3e-9. Possible causes: worker state or a preserved cache key that is not refreshed per draw (compare the
   2026-09-22 stale-worker-cache bug), or a deliberately different worker estimator. Not diagnosed; it needs its
   own TODO.
3. **PropKKGLMM fits depend on the start at the 1e-3 to 1e-2 level.** On the original data the worker
   (base start) gives 0.39643 against the observed 0.39727. Chained replicates sit further from fresh fits than
   base-only ones (13 of 15). This is consistent with v1.0.7-TODO-8 (L-BFGS reports `converged = TRUE` with
   gradient norm 0.22). ZOIB (5.6e-4) and partial PO (5.3e-3) show smaller start dependence of the same kind.

Scripts (scratch, not kept): `/tmp/claude-1000/chainstudy/{harness.R,override.R,study.R}`.
