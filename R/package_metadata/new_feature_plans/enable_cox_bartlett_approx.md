# Investigation: re-enabling the Bartlett-approx likelihood-ratio correction for Cox

Investigated 2026-09-22 at user request (a prior session's fix,
`inference_class_registry.R`/`inference_survival_coxph.R`/
`inference_survival_strat_cox.R`, forced
`supports_bartlett_likelihood_ratio_approx() = FALSE` explicitly on both
`InferenceSurvivalCoxPHRegr` and `InferenceSurvivalStratCoxPHRegr`, to stop
`ParametricLikelihoodBootstrap`'s delegating default from silently turning it
on when `ParametricLikelihoodBootstrap` was added to both classes' components
in that same fix). The forcing comment calls it "a previously-inert,
unvalidated Monte-Carlo Bartlett-correction code path this fix was never
meant to newly enable" — out of scope there, not investigated further until
now.

## What's actually there

The generic Monte-Carlo Bartlett-approx machinery
(`compute_lik_ratio_bartlett_approx_confidence_interval`/
`..._two_sided_pval`, `inference_all_abstract_asymp_lik.R`) estimates the
Bartlett correction factor by simulating `B` datasets under the
null-restricted fit and refitting, using exactly the same
`simulate_under_lik_null()` contract Cox already implements for real (not
stubbed) — a genuine Breslow-hazard-based simulator (`.breslow_hazard()` +
`.cox_simulate_from_breslow()`, `inference_survival_coxph.R`) that the
existing, already-shipped `compute_lik_ratio_bootstrap_confidence_interval()`
path already exercises in production. So enabling
`supports_bartlett_likelihood_ratio_approx()` for Cox does not require new
simulation code — it reuses machinery that is already live for a sibling
method.

## Investigation performed

Monkey-patched `supports_bartlett_likelihood_ratio_approx()` to `TRUE` on a
fresh `InferenceSurvivalCoxPHRegr` instance (no source change) and ran
`compute_lik_ratio_bartlett_approx_confidence_interval(B = 39)` /
`..._two_sided_pval(delta = 0, B = 39)` across 20 simulated Cox datasets
(`n = 80`, one covariate, a real treatment effect). Result: every one of the
20 replicates produced a finite CI, close in both width and location to the
Wald interval, and `p`-values that tracked the point estimate sensibly (near
0 for large estimates, near 1 for near-zero estimates). No crashes, no
degenerate output.

This is a mechanical smoke test, not a statistical validation: it does not
establish empirical coverage or Type-I error calibration, which needs a
proper repeated-sampling simulation (hundreds of reps at several `n`,
censoring rates, and effect sizes) — the same kind of validation
`fix_multimodal_log_liks.md`/`TODO-30` and the other audit-driven plans in
this release are held to before shipping a previously-off statistical
method.

## Coverage/Type-I simulation (2026-09-24) -- does not support enabling

Ran the proper validation the recommendation above called for:
`InferenceSurvivalCoxPHRegr`, `n = 100`, one covariate, ~25% censoring,
300 null reps (`beta_T = 0`, Type-I error) + 300 alternative reps
(`beta_T = 0.6`, CI coverage), `B = 49` Bartlett replicates per rep,
monkey-patched `supports_bartlett_likelihood_ratio_approx() = TRUE` (no
source change), Wald run alongside as the reference. Took 1.38 hours (each
of the 600 outer reps itself runs 49 Breslow-hazard-simulate-and-refit
sub-fits -- substantially more expensive than the earlier 20-rep smoke
test, which used no reference comparison and fewer reps).

Result: the Bartlett-approx correction does **not** clearly outperform
Wald, and on this run is mildly worse in both directions --

| | Bartlett-approx | Wald | nominal |
|---|---|---|---|
| Type-I error | 0.077 | 0.057 | 0.05 |
| CI coverage | 0.937 | 0.947 | 0.95 |
| median CI width | 0.945 | 0.970 | -- |

Both gaps are within ~1-2 simulation SEs of nominal at `n = 300` reps (SE
of a proportion near these values is ~0.013), so neither is a decisive
"broken," but there is no evidence of the improvement a Bartlett correction
is supposed to provide over the plain Wald asymptotic reference, and what
signal there is points the wrong way (mild over-rejection, mild
under-coverage) rather than toward it being a safe upgrade. It always ran
mechanically clean (0% NA rate on both real and alt draws, matching the
earlier smoke test), so this is a statistical-benefit finding, not a
robustness one.

**This was one scenario** (one `n`, one censoring rate, one effect size,
plain `InferenceSurvivalCoxPHRegr` only -- not `StratCoxPHRegr`). It does
not prove the method never helps anywhere, only that it did not help here,
and the cost of ruling that in/out more broadly is real (see below).

## Recommendation

Do not enable `supports_bartlett_likelihood_ratio_approx()` for either Cox
class. The validation this plan called for as the prerequisite for
enabling it came back unfavorable rather than favorable, so option 1 (from
the original writeup) is no longer supported by the evidence, and the
simpler resolution now is:

1. **Keep it off** (both explicit-FALSE overrides stay as-is) -- this is
   simply confirming the status quo with actual evidence instead of an
   unvalidated guess either way.
2. Optionally, if a future session wants to revisit this: re-run the same
   simulation at a couple more `(n, censoring, effect size)` combinations,
   and on `InferenceSurvivalStratCoxPHRegr` too, before concluding
   anything more general than "not shown to help on this one scenario."
   Given each such run costs over an hour at this `B`/rep count, this
   should be a deliberate, budgeted decision, not something to run
   speculatively.

## TODO

1. ~~Design and run the coverage/Type-I-error simulation~~ -- done
   2026-09-24, does not support enabling (see above).
2. No further action planned unless a future decision (item 2 above)
   reopens this.

Independent of every other 1.1.0 item; depends on nothing else in this
release.
