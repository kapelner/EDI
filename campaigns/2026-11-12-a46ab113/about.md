[← Campaign 2026-11-12-a46ab113 summary](README.md)

# About this study

Every month EDI re-runs a simulation study of its own inference procedures on GitHub Actions and publishes the
results here: Type I error (size), confidence-interval coverage and null bias for every inference class on every
design it applies to, and power under identical data on every design. Nothing is hand-picked: every cell of the
study is in the tables, failures included.

* **Data:** synthetic, n = 50, 200 and 1000 subjects, five covariates (three continuous, two binary factors) that
  explain about half the outcome variance, drawn from each response type's own model. Formulas `~ 1` (treatment
  only) and `~ .` (treatment + all covariates).
* **Order (v1.0.5 TODO-203):** a campaign runs class by class: the null effect first, then the power effects; within an
  effect by response type, then inference class; within a class by design, then n = 50, 200, 1000, then the class's
  confirmation replicates when any of its tests is flagged. A class is finished before the next starts (several fast
  classes of one cell share a shard and its data and design, so a few neighbouring classes run together), so verdicts
  become final class by class. All procedures of a class share one fit on the same data and are never split.
* **Null:** no treatment effect, 1,000 replicates per cell. Size and coverage are tested against a level that
  depends on the procedure's regime and on n (below), with exact one-sided binomial tests, in two stages. Screen: Benjamini-Hochberg q < 0.05 over every test the
  whole campaign plan contains (the number m is known in advance; a test that has not run counts as p = 1, and a test
  enters with its p-value once its cell's screening replicates are all in) flags a test (catching size of about 0.07 at 1,000
  replicates). BH is monotone in the p-values, so a flag is never withdrawn by later results: only "not flagged" is
  provisional while the campaign runs. Confirm: each flagged test is re-run
  on 5,000 fresh replicates (1,000 for the slow classes) and fails only if those alone reject, at 0.01 over m, the total number of tests in the plan
  (fixed in advance, so a confirmed failure is final when it is made; with 5,000 replicates this still detects a size of about 0.065);
  one with fewer than 500 confirmation results counts as failing. Null bias (mean
  estimate minus the null value) is reported and flagged, not gated: an honest estimator has O(1/n) null bias on
  ratio scales and under unequal allocation.
* **Levels (v1.0.5 TODO-200):** each procedure is either asymptotic (Wald, jackknife, score, likelihood ratio,
  gradient, Bartlett, the bootstraps, the randomization bootstrap) or finite-sample (exact, randomization); the registry is
  [`inference_procedure_regime.R`](https://github.com/kapelner/EDI/blob/main/R/EDI/R/inference_procedure_regime.R).
  Finite-sample procedures are held to size 5% and coverage 95% at every n. An asymptotic procedure with a known
  convergence order a (the registry's expected order of its size error, `inference_convergence_expectation()`) is
  held to size min(10%, 5% + c n_eff^-a) and coverage 1 minus that, with c chosen so the level reaches the 10% cap at
  an effective n of 50 (a = 1: 10% up to n_eff 50, 7.5% at 100, 6.25% at 200, 5.25% at 1,000). n_eff is the nominal
  effective sample size of the registry's rule (n, pairs, the smaller arm; counts the summary statistics do not carry
  fall back to n and are marked `proxy`). Procedures whose order is unknown are held to the cap at every n below the
  campaign's largest n and to the a = 1 level at it (a failure says "rate unknown: open a TODO to establish it").
  Cells with an expected O(1) error from a design mismatch (the model standard error ignores the design) fail only on the
  anticonservative side; conservative ones are reported. Rate check: a cell converging slower than its expected order
  (whole CI for the order below it) is held to the nominal level at its largest n. With 5,000 confirmation replicates
  an excess of about 0.006 is detectable at the largest n, so "nominal" there means no worse than about 0.06. Each table
  gives, per cell, the regime, n_eff, expected order and basis, the level tested and the rule that set it (finite, rate,
  cap, unknown, mismatch, rate check, accepted). Accepted cells use their own level.
* **Which red:** a campaign is red only when its `analyze` job's last step, `Gate verdict`, fails: a completed campaign
  with confirmed failing cells (annotation "Calibration gate"). A failure of any other step or job is a bug in the check
  itself (annotation "Calibration CI bug"), never a calibration result.
* **Power:** three effect sizes per response type, set to give 20 / 50 / 80% power to the Bernoulli-design
  baseline class at every n, 500 replicates per cell. Every design in a replicate sees the same subjects and
  outcomes, so power differences between designs are differences between designs. When a campaign completes,
  each design's power is compared with Bernoulli's by an exact McNemar test on the replicates they share
  (`design_comparison.csv`; unpaired where a design runs at another n). Reported, not gated.
* **Away from the null:** coverage at every power effect is tested like the null coverage (same two-stage
  gate), and bias is reported like the null bias, both against the true value of each class's own estimand:
  its estimate on eight samples of 20,000 from the same data generator (median; `calibrate_study_truths.R`). A
  marginal log odds ratio under `~1` is not the conditional beta_T, so each class gets its own value. Classes
  that apply only to matched designs have none (their estimand depends on the pairing), nor do cells where
  fewer than 75% of the large-sample fits were finite; both are reported as having no true value.
* **Slow classes:** the KK random-effects fits for count and ordinal responses on the matched designs
  (`InferenceCountKKGLMM` and the four `InferenceOrdinalKKCLMM*` links) take 4-40 minutes per replicate at
  n = 1000, so they get 500 null replicates at n = 1000 (1,000 below) and power at n = 50 only. Every table
  gives each cell's own replicate count.
* **Procedures:** Wald, score, likelihood ratio, gradient and exact tests and CIs, and the randomization test,
  monthly. Bootstrap, jackknife, Bartlett-corrected and randomization CIs run in slower tiers (see
  [the plan](https://github.com/kapelner/EDI/blob/main/R/package_metadata/future_release_plans/release_v1_2_0.md)).
* **Code:** [`R/package_tests/calibration/`](https://github.com/kapelner/EDI/tree/main/R/package_tests/calibration),
  run by `.github/workflows/calibration-study.yml`; each campaign is pinned to one EDI commit.

[← Campaign 2026-11-12-a46ab113 summary](README.md)
