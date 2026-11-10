# Rerandomization Criterion Variants, Samplers, and the Grundy-Healy Diagnostic

> **Depends on:** `DesignFixedRerandomization` and the greedy-swap engine
> (shipped). Additive arguments and one diagnostic. **Release target:
> v2.0.0 (theoretical-design backlog, user decision 2026-08-27)**
> (`release_v2_0_0.md → TODO-5b-ii`; `_master.md` Phase 5Q).

Written 2026-08-27. Owning plan for
`missing_theoretical_design_classes_literature_audit.md` items **#6, #7,
#11–#18, #20, #43, #45**.

## A. Generalized quadratic-form criterion `w'Aw`

One `criterion =` argument on `DesignFixedRerandomization` (and as an
`objective` on the greedy/annealer engines) with named forms — nesting
six published designs (arXiv 2403.12815 unified framework):

| name | `A` | reference |
|---|---|---|
| `"mahalanobis"` (default, today) | `(X'X)⁻¹` | Morgan & Rubin 2012 |
| `"ridge"(lambda)` | `(X'X + λI)⁻¹` | Branson & Shao 2021 |
| `"pca"(q)` | Mahalanobis on top-`q` PC scores | Zhang, Yin, Rubin 2023 |
| `"bayes"(prior_precision)` | posterior-expected-loss form | Liu, Han, Rubin, Deng *JASA* 2025 — reuses EDI's D_B/A_B `prior_precision` |
| `"kernel"(k)` | Gram matrix (MMD²) | Kallus 2018; arXiv 1901.08984 |
| `"energy"` | energy-distance form | Székely-Rizzo |
| user matrix | any PSD `A` | — |

plus **tiers** (`tiers = list(c("x1","x2"), c("x3"))`, Morgan & Rubin
2015 — sequential orthogonalized thresholds), **p-value acceptance**
(`accept = "pvalue", alpha =`; Zhao & Ding 2024), and **min–max |t| with
an explicit retained-set size `K`** (Johansson-Schultzberg-Rubin 2021;
Nordin-Schultzberg 2022 — makes the entropy-vs-FRT-power tradeoff a
parameter; today's top-quantile option is this without per-covariate `t`
or a power-targeted `K`).

## B. Samplers of the acceptance region

- `sampler = "pair_switch"`: Zhu & Liu (*Biometrics* 2023) — greedy pair
  switches *until* the threshold is crossed, then stop; samples the MR
  acceptance region 3–23× faster with MR theory intact. EDI has both
  halves (greedy swap; rerandomization loop) but not the hybrid.
- `sampler = "mcmc"`: Metropolis over assignments targeting the uniform
  law on the acceptance set (BRAIN, arXiv 2312.17230) for tiny `p_a`.
Both make randomization tests under tight thresholds practical.

## C. Grundy-Healy concurrence diagnostic and Hadamard randomization

- `Design$concurrence_diagnostic(r = )`: over `r` design draws, report
  `max_{i,j} |P(w_i = w_j) − c|` — Grundy & Healy (1950) / Bailey (1983)
  second-order balance. Group-valid restrictions (permuted blocks,
  Hadamard) give ≈ 0 ⇒ model-based OLS/ANOVA SEs exactly unbiased;
  X-dependent restrictions (rerandomization, greedy) do not ⇒ explains
  why they need LDR asymptotics or replay tests. Cheap; available on
  every design class.
- `DesignFixedHadamard` (Bailey & Nelson 2003): trend-robust restricted
  permuted blocks that remain group-valid. Small.

## D. Inference-side checks (small)

Verify/implement the Li-Ding-Rubin (2018) truncated-Gaussian-mixture CI
for rerandomized designs and the Li & Ding (2020) rerandomization + Lin
adjustment variance; ensure the studentized FRT is the default for
weak-null validity (Wu & Ding 2021; Zhao & Ding 2024).

## Tests

Each criterion at the `mahalanobis` default is a golden no-op; ridge at
λ→0 ≡ Mahalanobis; kernel with linear kernel ≡ Mahalanobis up to scaling;
pair-switch sampler's acceptance-region samples match rejection-sampling
moments; Hadamard concurrence ≈ 0 vs rerandomization ≠ 0; LDR CI
coverage simulation.

## TODOs

- [ ] TODO-1: `criterion =` quadratic-form family + tiers on
  `DesignFixedRerandomization`; same objectives on greedy/annealer.
- [ ] TODO-2: p-value acceptance; min–max |t| with retained-set size `K`.
- [ ] TODO-3: `sampler = "pair_switch"` and `"mcmc"`.
- [ ] TODO-4: concurrence diagnostic on `Design`; `DesignFixedHadamard`.
- [ ] TODO-5: inference-side LDR CI / Li-Ding variance / studentized FRT
  default check.
- [ ] TODO-6: docs — note c-optimality ≡ Mahalanobis, BCMS 2020 ≡
  rerandomization.
