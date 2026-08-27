# Classical Sequential-Design Completions

> **Depends on:** the `DesignSeqOneByOne` framework (shipped). Additive
> classes and arguments only. Interacts with the greedy-merge plan's
> general-`prob_T` work and with
> `unequal_allocation_matching_greedy_minimization.md` (ARP rules matter
> once sequential coins accept unequal ratios). **Release target: v1.3.0 (design theory)**
> (`release_v1_3_0.md → TODO-1`; `_master.md` Phase 5P).

Written 2026-08-27. Owning plan for
`missing_design_classes_literature_audit.md` items **#6, #7** and
`missing_theoretical_design_classes_literature_audit.md` items **#23, #24,
#25, #26, #27**.

## Items

### A. Allocation-tolerance rules — `DesignSeqOneByOneTolerance(rule =, tolerance =)`

Big stick (Soares & Wu 1983), Chen's biased coin with imbalance tolerance
(1999), Berger's maximal procedure (2003 — uniform over all sequences
whose running imbalance never exceeds `b`; lattice-path counts), Zhao &
Weng block urn (2011), Ehrenfest urn (Chen 2000), adjustable biased coin
ABCD (Baldi Antognini & Giovagnoli 2004). All give `|D_n| ≤ b` a.s. with
exact replay distributions. Rare in practice (2 of 330 top-journal
trials) but completes the classical toolbox and `randomizeR` covers them.

### B. Smith's generalized biased coin (1984) — `DesignSeqOneByOneSmith(rho =)`

`P(A) = N_0^ρ / (N_0^ρ + N_1^ρ)`; `Var(D_n/√n) = 1/(1+2ρ)`; the parametric
bridge from CRD (ρ=0) through Wei to permuted blocks (ρ→∞). Trivial.

### C. Hu & Hu (2012) unified imbalance family on Pocock-Simon

Add `weights_overall`, `weights_stratum` to `DesignSeqOneByOnePocockSimon`
so the coin acts on `ω_o D_n + Σ ω_m D_n(margin) + ω_s D_n(stratum)`; with
`ω_s > 0` all three imbalances are `O_p(1)` (the design the Ma-Hu-Zhang /
Bugni-Canay-Shaikh inference theory is written for). Default weights
reproduce today's behaviour.

### D. Allocation-ratio-preserving (ARP) coins (Kuznetsova & Tymofyeyev 2011/12)

For `prob_T ≠ 0.5`, biased coins and minimization drift each unit's
unconditional `P(w_i = 1)` away from the target, which biases replay
tests. Brick-tunnel / wide-brick-tunnel randomization and the ARP variant
of Pocock-Simon keep it exact. Ship together with the first sequential
class that accepts an unequal target ratio.

### E. Fixed-sample permuted blocks with random block sizes — `DesignFixedPermutedBlocks`

Pregenerate the `DesignSeqOneByOneRandomBlockSize` rule for known `n`
(the list an IWRS stores). `DesignFixedBlocking` does complete
randomization within each stratum (one big block), not size-4/6 blocks.
Convenience + documentation gap; small.

### F. Continuous-covariate minimization (optional)

Baldi Antognini & Zagoraiou (2011) D-optimal covariate biased coin; Ma &
Hu (2013) kernel-density minimization; Ciolino-style standardized-mean
minimization. Atkinson already handles continuous covariates via `D_A`;
include only if cheap after A–D.

## Tests

Each rule vs `randomizeR` reference implementations (exact allocation
distributions at small `n` by enumeration); replay-test validity checks;
Smith at ρ=0 ≡ Bernoulli golden; Pocock-Simon default weights golden
no-op; ARP: unconditional `P(w_i = 1)` equals target at every position
over many draws.

## TODOs

- [ ] TODO-1: A — tolerance-rule class with `rule =` switch.
- [ ] TODO-2: B — Smith's coin.
- [ ] TODO-3: C — Hu & Hu weights on Pocock-Simon (golden no-op default).
- [ ] TODO-4: D — ARP coins (sequenced with unequal-`prob_T` on sequential
  classes).
- [ ] TODO-5: E — `DesignFixedPermutedBlocks`.
- [ ] TODO-6 (optional): F — continuous-covariate minimization.
- [ ] TODO-7: registry `randomization_family` entries, roxygen, replay-test
  fixtures.
