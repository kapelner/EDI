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

## Recommendation (not decided)

The path is plausibly cheap to properly enable — no new simulator needed,
just validation — but should not be flipped on without that validation,
especially with CRAN submission imminent (`project_cran_status`). Options:

1. **Validate and enable in v1.1.0.** Run a proper coverage/Type-I-error
   simulation (borrow the harness pattern
   `fix_multimodal_log_liks.md → TODO-5/6` already uses for a similar
   validate-before-shipping decision), then flip
   `supports_bartlett_likelihood_ratio_approx()` to `TRUE` on both Cox
   classes and delete the two explicit-FALSE overrides (letting the
   `ParametricLikelihoodBootstrap` delegating default take over, which is
   what would have happened automatically had this not been forced off).
2. **Defer.** Leave it off; it's not blocking anything today (the method is
   simply absent from `self$capabilities()`/`compute_lik_ratio_bartlett_approx_*`
   for Cox, not broken), and there is no user report asking for it.

## TODO

1. Design and run the coverage/Type-I-error simulation (option 1's
   prerequisite).
2. If it passes: flip both classes' override to `TRUE`, delete the two
   explicit-FALSE bodies and their justifying comments, update
   `path_audits_source.R`'s `bartlett_approx_override=FALSE` row for
   `InferenceSurvivalCoxPHRegr` (and the Strat-Cox equivalent) to match.
3. Add a permanent regression test asserting the validated coverage/Type-I
   rate, so a future change can't silently regress it back to unvalidated
   or broken.

Independent of every other 1.1.0 item; depends on nothing else in this
release.
