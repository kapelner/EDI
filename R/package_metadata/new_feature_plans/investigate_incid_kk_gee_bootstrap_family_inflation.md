# Investigation: `InferenceIncidKKGEE` Bootstrap-Family Type-I Inflation — Historical Finding Not Reproduced, Leading Hypothesis Refuted

> **Depends on:** none. (Global ordering: see `_master.md`.) Slated for
> `release_v1_0_5.md → TODO-21`. Added 2026-09-23, same audit-triage wave as
> TODO-17/18/19/20. Possibly related in kind (not mechanism) to
> `investigate_contin_quantile_regr_bootstrap_family_inflation.md`
> (TODO-20) — both are "asymptotic-SE-based methods whose variance
> estimator has known finite-sample fragility under resampling." **This is
> an open investigation, not a confirmed bug.** `release_v1_0_5.md`'s own
> TODO-21 entry explicitly says: "Do not write a plan file without first
> pulling the exact historical dataset/design/formula and confirming the
> inflation reproduces on it." That has NOT been done. This file exists to
> give the thread a durable home and record what's been ruled out so far —
> it is not a green light to start fixing anything, and the bottom line
> below is deliberately "genuinely unclear," not a diagnosis.

## The finding

Historical `comprehensive_tests` CSV rows show `InferenceIncidKKGEE` with
the same consistent-direction bootstrap-family inflation shape as TODO-20:
- `compute_bayesian_bootstrap_two_sided_pval_wald`: 0.314 vs. nominal 0.05.
- `compute_bayesian_bootstrap_two_sided_pval`: 0.306 vs. nominal 0.05.
- `compute_rand_bootstrap_two_sided_pval_symmetric-percentile-t`: 0.185 vs.
  nominal 0.05.

Originally-suspected cause: naive row-level bootstrap breaking GEE
matched-pair structure — resampling rows independently would ignore the
matched-pair clustering, understating true variance and inflating Type-I
error, a well-known failure mode for cluster-correlated data under a naive
bootstrap.

## Hypothesis (reservoir-singleton mishandling) — REFUTED 2026-09-23 by code trace AND direct reproduction, high confidence on the code being correct

**Claim**: `InferenceIncidKKGEE` uses matching-aware bootstrap machinery
(`bootstrap_sample_indices()` → design's `draw_bootstrap_indices()` →
`private$draw_matching_bootstrap_indices()` for matching-capable designs,
`design_matching_abstract.R:107-113`), shared across 4 `KKGEE`-family
classes (`InferenceCountPoissonKKGEE`, `InferenceIncidKKGEE`,
`InferenceOrdinalKKGEE`, `InferencePropKKGEE`,
`inference_class_registry.R:326-331`). Each cluster is either a matched
pair (2 members) or a reservoir singleton (1 member), per
`inference_incidence_KK_combined.R:6-7`. Pair-resampling logic that's
correct for 2-member clusters could plausibly mishandle 1-member ones
(e.g. resampling a "singleton pair" as if it always had 2 members, or
losing the cluster boundary entirely for singletons).

**Refuted**: read the full chain — `design_matching_abstract.R:55-114`
(separates reservoir-singleton indices from matched-pair row pairs, both
cached in `init_matching_bootstrap_structure()`) and
`bootstrap_match_indices.cpp:92-130` (`draw_matching_bootstrap_sample_cpp`,
the actual C++ resampler). This is textbook-correct cluster bootstrap:
reservoir singletons resampled i.i.d. with replacement, matched pairs
resampled as intact 2-member units with fresh relabeled pair IDs. No
mishandling of the singleton case found.

## Direct reproduction attempt — ALSO did not reproduce the historical inflation

A fresh true-null `InferenceIncidKKGEE` fixture (`DesignSeqOneByOneKK14`,
loaded via `pkgload`, no compilation) gave:
- `compute_bayesian_bootstrap_two_sided_pval(type="wald")` = **0.050**
  (n=100, B=200, 40 reps — exactly nominal).
- default variant = **0.025** (mildly conservative).
- A second, smaller check (n=60, B=100, 25 reps) gave **0/25 rejections** —
  consistent with nominal/conservative, not inflated.

Neither run is remotely close to the historical 0.306–0.314.

## Open question, not yet checked (the concrete next step)

The reproduction fixture used a single simple covariate and default
settings, while the flagged historical rows were at `model_formula=~1` AND
`~.` (both flagged, different rates) on whatever specific dataset the
harness used for this class — the **same shape as the already-CONFIRMED**
`InferenceContinLin` bug (`fix_contin_lin_param_bootstrap_bad_type1_error.md`
/ TODO-15's sibling finding), where `~1` vs `~.` on one specific real
dataset with near-collinear covariates was the actual trigger, not a
generic class property. The reproduction attempt above did not use that
exact dataset/design/formula combination — it built a fresh simplified
fixture instead, which is exactly the kind of substitution that already
failed to reproduce TODO-19's historical finding.

Also not checked: whether the other three `KKGEE`-family classes
(`InferenceCountPoissonKKGEE`, `InferenceOrdinalKKGEE`, `InferencePropKKGEE`)
show the same historical pattern — if they do, that argues for a shared
mechanism (weakening the "specific dataset/formula trigger" explanation);
if they don't, that strengthens it.

## Next steps (none done yet)

- [ ] Pull the *exact* historical dataset/design/`model_formula` combination
  from the flagged `comprehensive_tests` CSV rows (both the `~1` and `~.`
  rows) — not a fresh simplified fixture — and attempt reproduction with
  that exact combination.
- [ ] Check whether `InferenceCountPoissonKKGEE`, `InferenceOrdinalKKGEE`,
  `InferencePropKKGEE` show the same historical inflation pattern in the
  CSV, to determine whether this is class-specific or shared across the
  `KKGEE` family.
- [ ] If reproduced, check whether it's specifically a near-collinear-
  covariates-under-`~.`-formula trigger (matching `InferenceContinLin`'s
  confirmed mechanism) rather than a generic bootstrap-correctness bug,
  given the code trace above already ruled out the resampling machinery
  itself.
- [ ] If NOT reproduced even with the exact historical dataset/formula,
  treat this as likely resolved/noise (per the historical CSV possibly
  predating a fix, or reflecting a since-corrected upstream issue) and
  close TODO-21 without a code change, documenting that conclusion in
  `release_v1_0_5.md`.
- [ ] Only write a proper `# Fix:` plan if the above confirms a concrete,
  currently-broken mechanism.

## Bottom line

This may be resolved/noise, may need the exact triggering dataset to
reproduce, or may not be a real defect at all — genuinely unclear. Do not
write a fix plan or attempt a code change without first pulling the exact
historical dataset/design/formula and confirming the inflation reproduces
on it.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`).
