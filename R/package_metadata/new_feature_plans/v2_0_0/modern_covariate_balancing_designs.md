# Modern Covariate-Balancing Designs

> **Depends on:** shipped design hierarchy; `sexp_removal_rcppeigen_conversion_spec.md`
> kernel conventions; `DesignFixedOptimal`'s existing MILP solver plumbing
> (ompr/ROI/glpk, already `Suggests`), reused by the online-MIO item added
> 2026-09-10 rather than adding a new solver dependency. New algorithms,
> additive classes. **Release target:
> v2.0.0 (theoretical-design backlog, user decision 2026-08-27)**
> (`release_v2_0_0.md → TODO-5b-iv`; `_master.md` Phase 5S).

Written 2026-08-27. Owning plan for
`missing_theoretical_design_classes_literature_audit.md` items **#1, #21,
#22** (its Tier-1 recommendations 1–3). **Amended 2026-09-10 (user
decision):** item **#30** (Bertsimas-Korolko-Weinstein online MIO) added —
same "online covariate-adaptive design" family as #21/#22, genuinely
missed by the 2026-08-27 sweep rather than deliberately excluded.

## Why

These are the modern theoretical benchmarks for covariate balance that
EDI — the home of the KAK-2019 / BRT / KK lineage — should implement and
compare against:

- **Gram-Schmidt Walk** (Harshaw, Sävje, Spielman & Zhang, *JASA* 2024):
  a random ±1 assignment from a discrepancy walk on the augmented matrix
  `[√φ I ; √(1−φ) X/ξ]`, with a finite-sample worst-case MSE bound *and*
  a covariance bound, and an explicit balance–robustness dial `φ ∈ (0,1]`
  (`φ = 1` ⇒ Bernoulli). Official software `GSWDesign.jl` (Julia); no CRAN
  package known.
- **Online balancing walk** (Arbour, Dimmery, Mai & Rao, *ICML* 2022):
  the online GSW — `P(z_{n+1} = 1) = ½ − ⟨w_n, x_{n+1}⟩/(2c)` on the running
  covariate-difference vector; `‖w_n‖_∞ = O(√log(nd))`; worst-case MSE
  within a log factor of offline GSW; linear time; any `prob_T`.
- **ARM / PSR** (Qin, Li, Ma & Hu; arXiv 1611.02802; ARM in *Statistica
  Sinica* 2024 to the best of my knowledge): a one-by-one (ARM) or
  pairwise (PSR) coin choosing the arm that lowers the running Mahalanobis
  distance with probability `q`; **`M_n = O_p(1)`** — bounded covariate
  imbalance, provably better than Pocock-Simon on continuous covariates,
  and the efficiency of rerandomization with `p_a → 0`. The direct
  theoretical rival of KK14.
- **Online MIO covariate-adaptive optimization** (Bertsimas, Korolko &
  Weinstein, *Oper. Res.* 2019): rather than a closed-form coin
  probability, solve a small mixed-integer program at each arrival that
  minimizes moment discrepancy, optionally over a lookahead window of
  near-future arrivals when their covariates are known or estimable in
  advance, subject to an explicit randomization constraint bounding how
  close the implied assignment probability may get to 0/1 (the same role
  ARM/PSR's `q` plays for replay-test validity); comes with finite-sample
  imbalance bounds rather than only asymptotic ones. Heavier per-arrival
  compute than a coin, traded for tighter finite-sample guarantees and
  lookahead when it's available.

## Proposal

- `DesignFixedGramSchmidtWalk(phi =)` — C++ implementation of the
  Bansal-Dadush-Garg-Lovett walk (O(n²p)); `draw_ws_raw(r)` re-runs the
  walk (valid randomization replay); exposes `get_covariance_bound()`;
  ships the paper's conservative variance estimator and ridge-adjusted
  estimator as an inference-side component (`InferenceContinGSWRidge`,
  optional).
- `DesignSeqOneByOneBalancingWalk(c =, prob_T =)` — the online coin;
  K-arm variant rides the multi-arm track.
- `DesignSeqOneByOneARM(q =)` and `DesignSeqOneByOnePSR(q =)` (pairwise
  arrivals — the first many-by-many-adjacent sequential class with block
  size 2; implement on the one-by-one framework by buffering one
  subject).
- `DesignSeqOneByOneOnlineMIO(lookahead =, randomization_constraint =)` —
  same one-by-one sequential framework; each arrival's step solves a small
  MIP over the discrete assignment choice (and the lookahead buffer, when
  `lookahead > 0`) minimizing moment discrepancy, reusing
  `DesignFixedOptimal`'s existing MILP solver plumbing rather than a new
  solver dependency; `randomization_constraint` bounds assignment
  probabilities away from 0/1 for replay-test validity, the same role `q`
  plays for ARM/PSR above.
- Inference: all three are replay-valid; ARM/PSR's adjusted tests
  (Ma-Qin-Li-Hu) via the existing covariate-adjusted Wald paths;
  document that the naive t-test is conservative.

## Research hooks

GSW vs. KAK-2019 vs. harmonized designs (same objective family, different
randomness guarantees — sub-Gaussian covariance bound vs. near-maximal
entropy) and ARM/PSR vs. KK14 (coin vs. matching) have no published
comparisons; both are natural EDI simulation-framework studies.

## Tests

GSW at `φ = 1` ≡ Bernoulli (golden); covariance bound holds empirically
over draws; balance vs `GSWDesign.jl` output on fixed seeds is not
bit-comparable (different RNG) — compare moments; balancing walk
`‖w_n‖_∞` growth ≈ `√log n`; ARM `M_n` bounded vs Pocock-Simon growing;
replay-test size at nominal level for all three; online-MIO's realized
finite-sample moment-discrepancy bound holds empirically across draws,
and its assignment-probability floor/ceiling from `randomization_constraint`
is respected exactly.

## TODOs

- [ ] TODO-1: GSW C++ kernel + `DesignFixedGramSchmidtWalk`; covariance
  bound accessor; tests.
- [ ] TODO-2: `DesignSeqOneByOneBalancingWalk`.
- [ ] TODO-3: `DesignSeqOneByOneARM` / `PSR`.
- [ ] TODO-4 (optional): GSW ridge-adjusted estimator component.
- [ ] TODO-5: registry entries, roxygen with full citations, simulation
  study scripts for the two research hooks.
- [ ] TODO-6: `DesignSeqOneByOneOnlineMIO` — per-arrival MIP formulation
  reusing `DesignFixedOptimal`'s solver plumbing, lookahead buffering,
  randomization-constraint enforcement; tests above.
