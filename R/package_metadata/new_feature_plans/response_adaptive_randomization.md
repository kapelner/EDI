# Two-Arm Response-Adaptive Randomization and Inference After Adaptive Assignment

> **Depends on:** `sequential_inference.md` (shares the response-
> dependent-replay problem and the interim-look ledger); the multi-arm
> track for K-arm bandits. **Release target: v2.0.0** (`release_v2_0_0.md
> → TODO-2c`) — the designs are small, but valid inference after adaptive
> assignment is a new inference contract.
>
> **Amended 2026-09-10 (user decision): a new "Visualization" section (the
> allocation-proportion-over-time trajectory plot) is added, targeted at
> `release_v3_0_0.md`.** The rest of this file's scope — the designs and
> inference work below — is unchanged, still v2.0.0. The visualization
> renders state the designs already accrue, not new statistical content,
> which is why it targets a later release than the designs themselves.

Written 2026-08-27. Owning plan for
`missing_design_classes_literature_audit.md` item **#5** (Part 4B) and
`missing_theoretical_design_classes_literature_audit.md` Part 2D (items
**#32–#37**).

## Why and what it is not

KK21 uses responses only to reweight the matching distance and never
shifts the allocation probability; EDI has no design that skews `P(w = 1)`
toward the better-performing arm. RAR is rare in medicine (65 planned
trials 1985–2023, 83% Bayesian, 88% with burn-in, 51% capped; FDA 2019
permits) and in economics (~a dozen: Kasy & Sautmann 2021, Caria et al.
2024), common as a tech product feature (Optimizely / Adobe / VWO
bandits). Its value here is completeness of the sequential family and the
research interest in inference after adaptivity.

## Designs (all on the `DesignSeqOneByOne` framework)

- `DesignSeqOneByOneDBCD(target = c("neyman", "rsihr", custom), gamma =)`
  — doubly-adaptive biased coin (Eisele 1994; Hu & Zhang 2004) and
  **ERADE** (Hu, Zhang & He 2009), which attains the Hu-Rosenberger
  variance lower bound — the theoretically optimal RAR.
- `DesignSeqOneByOneThompson(burn_in =, cap =, temper = c("thall_wathen",
  "kasy_sautmann"))` — Bayesian adaptive randomization with Thall-Wathen
  tempering `c = n/2N` and Kasy-Sautmann exploration sampling (`p ∝
  p_k(1−p_k)`, policy-regret optimal).
- `DesignSeqOneByOneUrnRAR(rule = c("rpw", "drop_the_loser"))` — Wei-Durham
  RPW and Ivanova's drop-the-loser (variance-optimal urn).
- CARA (Zhang-Hu-Cheung-Chan 2007; Atkinson-Biswas skewed D_A) as a
  second wave on top of Atkinson.
- Diagnostics encoding the cautionary literature (Robertson et al. 2023;
  Proschan & Evans 2020): time-trend check, allocation-extremity warning,
  burn-in enforcement.

## Inference — the hard part

- Replay randomization test: re-run the rule under the sharp null with
  observed responses reassigned (Simon & Simon 2011) — valid, and fits
  `draw_ws_according_to_design()` if the design can see responses during
  replay (a contract change: today replay sees only covariates).
- Wald under DBCD/ERADE: valid with inflated variance (Hu & Zhang 2004);
  under Thompson the sample mean is biased and non-normal ⇒ implement
  **adaptively-weighted AIPW** (Hadad, Hirshberg, Zhan, Wager & Athey
  *PNAS* 2021) and **batched OLS** (Zhang, Janson & Murphy 2020) as a new
  `AdaptiveWeighting` inference component; anytime-valid confidence
  sequences from `randomization_ci_search_precision.md` /
  `sequential_inference.md` as the alternative.
- Bootstrap: the design-backed worker must replay the adaptive rule per
  resample; document which bootstrap contracts remain valid.

## Tests

Allocation proportions converge to the target (`ρ(θ)`) for DBCD/ERADE;
ERADE variance ≈ lower bound; Thompson regret curves; replay-test size at
nominal level; AW-AIPW coverage vs sample-mean under-coverage in
simulation; RPW pathology at `q_A + q_B ≥ 3/2`.

## Visualization: allocation-proportion-over-time trajectory (added 2026-09-10, user decision — v3.0.0)

The standard way RAR papers show a rule working (or failing): realized
allocation proportion per arm, `N_k(t)/t`, plotted against enrollment
order, one line per arm, for whichever rule was used. For target-seeking
rules (DBCD/ERADE), overlay the rule's own target `ρ(θ)` as a reference
line — the plot then directly shows convergence (or its absence) to the
theoretical target, exactly the diagnostic Hu & Zhang (2004) and Hu, Zhang
& He (2009) use to present DBCD/ERADE's variance-optimality empirically.
For Thompson/exploration-sampling, no fixed target exists — the plot
instead shows the trajectory drifting toward whichever arm currently looks
better, with the "Designs" section's already-planned diagnostics
(time-trend check, allocation-extremity warning) rendered as annotations
on the same time axis rather than a separate report.

**Data source**: the per-subject `w`/`t` history already accrued on
`Design`'s private state (`private$w`, growing one entry per
`add_one_subject_to_experiment_and_assign()` call — the same fields
`sequential_inference.md` §3 documents) — no new bookkeeping, purely a
rendering of state the design already tracks.

**Reporting layer**: same ggplot2/HTML/plotly convention as
`inference_suite_interactive_reporting.md` and `sequential_inference.md`
§10 — static default, optional `plotly::ggplotly()` wrap for
hover-to-inspect the exact arm/proportion/`t` at any point on the
trajectory.

## TODOs

- [ ] TODO-1: Decision — pursue at all; which rules in the first wave;
  whether replay may see responses (contract change).
- [ ] TODO-2: DBCD / ERADE class.
- [ ] TODO-3: Thompson / exploration-sampling class with burn-in and caps.
- [ ] TODO-4: Replay-test contract extension; `AdaptiveWeighting`
  inference component (AW-AIPW, batched OLS).
- [ ] TODO-5: urn RAR; CARA second wave; diagnostics; vignette.
- [ ] TODO-6 (added 2026-09-10, v3.0.0): **Visualization** —
  allocation-proportion-over-time trajectory plot, one line per arm,
  target-ratio reference line for DBCD/ERADE; renders `Design`'s existing
  per-subject `w`/`t` history, no new bookkeeping. Static `ggplot2`
  default, optional `plotly` wrap per
  `inference_suite_interactive_reporting.md`'s convention.
