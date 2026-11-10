# Response-Adaptive Randomization (Two-Arm and K-Arm) and Inference After Adaptive Assignment

> **Depends on:** `sequential_inference.md` (shares the response-
> dependent-replay problem and the interim-look ledger). For the `K`-arm
> generalization (sections marked "K-arm generalization" below): the
> multi-arm track, specifically `multi_arm_designs.md → TODO-1c` (the
> `K`/`prob_T_vec` base-class machinery) and `→ TODO-2` (`arm_treated`/
> `arm_control` selection on `Inference$initialize()`). **Release target:
> v2.0.0** (`release_v2_0_0.md → TODO-2c`) — the designs are small, but
> valid inference after adaptive assignment is a new inference contract.
>
> **Amended 2026-09-10 (user decision): a new "Visualization" section (the
> allocation-proportion-over-time trajectory plot) is added, targeted at
> `release_v3_0_0.md`.** The rest of this file's scope — the designs and
> inference work below — is unchanged, still v2.0.0. The visualization
> renders state the designs already accrue, not new statistical content,
> which is why it targets a later release than the designs themselves.
>
> **Amended 2026-09-16 (user decision): scope widened from two-arm-only to
> include a `K`-arm generalization**, fulfilling theoretical-audit item
> **#48** (`missing_theoretical_design_classes_literature_audit.md`, Part
> 2H, previously catalogued but unranked: *"Multi-arm Atkinson (2002),
> multi-arm ARM/PSR, K-arm online balancing walk, K-arm bandits /
> controlled FLGI ... **missing** ... rides multi-arm track"*). Folded into
> this file rather than a separate plan — an earlier draft of this decision
> did write a standalone `bandit_designs.md`, but the `K`-arm case reuses
> this file's design and inference architecture essentially unmodified
> (see "K-arm generalization" throughout) rather than introducing a new
> one, so a second file would have split one coherent design family across
> two documents for no architectural reason. Prompted by a targeted
> literature sweep on bandit/Thompson-sampling allocation
> (`package_metadata/reports/real_world_experiment_properties_audit.md
> §4.5, §8.10`).

Written 2026-08-27; `K`-arm generalization added 2026-09-16. Owning plan
for `missing_design_classes_literature_audit.md` item **#5** (Part 4B),
`missing_theoretical_design_classes_literature_audit.md` Part 2D (items
**#32–#37**) and Part 2H item **#48**.

## Why and what it is not

KK21 uses responses only to reweight the matching distance and never
shifts the allocation probability; EDI has no design that skews `P(w = 1)`
toward the better-performing arm. RAR is rare in medicine (65 planned
trials 1985–2023, 83% Bayesian, 88% with burn-in, 51% capped; FDA 2019
permits) and in economics (~a dozen: Kasy & Sautmann 2021, Caria et al.
2024), common as a tech product feature (Optimizely / Adobe / VWO
bandits). Its value here is completeness of the sequential family and the
research interest in inference after adaptivity.

**Why support it despite the rarity.** A 2026-09-16 literature sweep
sharpens this: bandit/Thompson-sampling allocation is real and effective
at production scale — Microsoft's Decision Service reported 25–30%
click-through improvements and an 18% revenue lift (Agarwal, Bird,
Cozowicz et al., "A Multiworld Testing Decision Service," arXiv:1606.03966);
the foundational contextual-bandit paper reported a 12.5% click lift over
a context-free baseline on 33M+ Yahoo events (Li, Chu, Langford &
Schapire, *WWW* 2010, arXiv:1003.0146) — but a qualitative minority
practice industry-wide: "companies rarely boast about using multi-armed
bandit models... everything is either a t-test or linear regression" (Au,
*Counting Stuff*, 2024), and no source found anywhere, including vendors
(Optimizely, VWO) with every commercial incentive to publish a flattering
adoption number, gives one. Crucially, none of those vendor platforms
publish a rigorous post-allocation causal-inference story — they optimize
reward during the run, not a valid treatment-effect estimate afterward.
The `AdaptiveWeighting` component below (already planned, pre-dating this
amendment) is exactly the harder, more valuable half of the problem
vendors skip; this remains this file's real differentiator, not the
allocation rule itself.

**Why K-arm, not just two-arm.** The classic bandit literature this
evidence draws on — Yahoo's article-recommendation problem, Microsoft's
Decision Service — is inherently `K`-armed (many articles/variants), not
two-armed. This file's original scope covered the minority of real bandit
deployments. The sections below marked "K-arm generalization" extend the
same designs, and — more importantly — the same inference architecture,
to `K > 2` without introducing new inference code; see Inference below.

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

**K-arm generalization.** `DesignSeqOneByOneThompson` generalizes in
place, not via a new class name — mirroring how `multi_arm_designs.md
§3a/§3b` generalize every other design in place rather than forking
`K`-arm sibling classes. Instead of a scalar `P(w=1)`, maintain a
`prob_T_vec` (length `K`, riding `multi_arm_designs.md §3c`'s base-class
machinery) updated from `K` arm-specific posterior response models;
Thall-Wathen tempering and Kasy-Sautmann exploration sampling both have
direct `K`-arm forms — neither rule is intrinsically two-arm, the two-arm
framing above is a special case. `burn_in =`/`cap =` generalize to a
floor/ceiling per arm. Kernel shape follows `DesignSeqOneByOneAtkinson`'s
`atkinson_assign_weight_cpp` precedent (`design_seq_one_by_one_atkinson.R:51-57`
— takes assignment history directly, returns a decision); a `K`-arm
Thompson kernel takes the `K`-arm posterior draws and returns
`prob_T_vec` or a drawn label, needing a new `_cpp` kernel per
`multi_arm_designs.md §3b`'s budgeting convention — this is not purely an
R-level change. **New K-arm-specific diagnostic — control-arm
starvation**: with more arms competing, a naive rule can drop the control
arm's share toward zero well before a two-arm extremity check would catch
it (Villar, Bowden & Wason, *Stat. Sci.* 2015 — theoretical-audit item
#36 — "severe power loss unless control protected"); add an explicit
per-arm floor, not only a global extremity check. **Second-wave K-arm
rules**: UCB/Gittins/controlled FLGI (Villar, Bowden & Wason 2015, item
#36); multi-arm Atkinson (2002) and `K`-arm ARM/PSR (the remainder of
theoretical-audit item #48), a natural pairing with CARA above once both
land.

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

**K-arm generalization.** `K`-arm bandit inference is not `K` independent
two-arm inferences run naively — it inherits exactly the invalidity
above, per `missing_theoretical_design_classes_literature_audit.md`
§2G's validity table ("Thompson / bandits": naive permutation invalid;
design-replay FRT valid; unadjusted Wald invalid, biased & non-normal;
needs AW-AIPW/batched OLS), which also names two `K`-arm-relevant validity
papers this file didn't previously cite — **Nie, Tian, Taylor & Zou
(2018)** and **Shin, Ramdas & Rinaldo (2019)** — worth folding into
`AdaptiveWeighting`'s documentation alongside Hadad et al. and
Zhang-Janson-Murphy. **No new inference architecture is needed**:
selecting any two of the `K` arms for a specific contrast reuses
`multi_arm_designs.md §4`'s `arm_treated`/`arm_control` mechanism on
`Inference$initialize()` — requiring no changes to any concrete
`Inference*` class — and the selected slice reuses the replay test and
`AdaptiveWeighting` component exactly as built above. This buys two
things: the two-arm inference code never becomes "K-arm-aware," and the
multiplicity caveat `multi_arm_designs.md §4` already documents (shared
subjects across pairwise contrasts inflate familywise error) applies here
without new analysis — `MultiArmInference` (`multi_arm_designs.md`'s
Phase 3a) is the eventual home for a corrected "best-arm vs. control" or
"all-pairs" summary; document, don't solve, here. **Open framing question,
not yet resolved**: much of the applied bandit literature (including both
production examples cited above) optimizes for cumulative reward or
best-arm identification, not a clean estimate of one specific contrast —
which is what every existing `Inference*` class targets. Document this
tension explicitly rather than picking a resolution silently: a user
running a `K`-arm bandit for regret minimization and one running it for a
defensible post-hoc treatment effect want different summaries from the
same allocation history.

## Tests

Allocation proportions converge to the target (`ρ(θ)`) for DBCD/ERADE;
ERADE variance ≈ lower bound; Thompson regret curves; replay-test size at
nominal level; AW-AIPW coverage vs sample-mean under-coverage in
simulation; RPW pathology at `q_A + q_B ≥ 3/2`.

**K-arm generalization.** Allocation shares behave sensibly under both
tempering rules (no fixed target exists for pure Thompson, but shares
should not degenerate before burn-in/cap diagnostics fire); the new
control-arm-starvation check fires under a deliberately adversarial K-arm
simulation where one arm's early responses are misleadingly poor; AW-AIPW
coverage vs. naive-sample-mean under-coverage in K-arm simulation; replay-
test size at nominal level for an `arm_treated`/`arm_control` pair
selected out of a K-arm history; regret curves for Thompson vs.
UCB/Gittins once the second wave lands.

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
on the same time axis rather than a separate report. **K-arm
generalization**: one line per arm rather than two — the plot's design
already generalizes for free, since it was never structurally two-arm
(`N_k(t)/t` is already indexed by arm `k`); the K-arm control-arm-
starvation diagnostic renders as an additional annotation the same way.

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
  whether replay may see responses (contract change). **[Amended
  2026-09-16, user decision]: pursue, and pursue the `K`-arm
  generalization too, for v2.0.0 — see TODO-7..10.**
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
- [ ] TODO-7 (added 2026-09-16): **K-arm `DesignSeqOneByOneThompson`
  generalization** — `prob_T_vec` state, K-arm Thall-Wathen tempering and
  Kasy-Sautmann exploration sampling, new `_cpp` kernel, and the new
  control-arm-starvation diagnostic. **Blocked on `multi_arm_designs.md →
  TODO-1c`** (the shared `K`/`prob_T_vec` base-class machinery) landing
  first.
- [ ] TODO-8 (added 2026-09-16): **K-arm inference wiring** — confirm
  K-arm bandit designs compose with `multi_arm_designs.md → TODO-2`'s
  `arm_treated`/`arm_control` selection and TODO-4's `AdaptiveWeighting`
  component with zero new `Inference*` code; add Nie et al. (2018) /
  Shin-Ramdas-Rinaldo (2019) to that component's validity documentation.
  Document, don't solve, the multiplicity and best-arm-identification
  framing questions above.
- [ ] TODO-9 (added 2026-09-16): **UCB / Gittins / controlled FLGI second
  wave** (Villar, Bowden & Wason 2015); ship the control-protection
  caveat as an enforced diagnostic, not documentation alone.
- [ ] TODO-10 (added 2026-09-16): **Multi-arm Atkinson (2002) / K-arm
  ARM/PSR** as a further wave, paired with TODO-5's CARA second wave once
  both land. Lowest priority in this file.
