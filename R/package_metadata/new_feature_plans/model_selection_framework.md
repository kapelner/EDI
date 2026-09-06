# `ModelSelection`: Comparative Fit over the Model × Formula Grid, with an Honest Exit

> **Depends on:** `InferenceSuite`'s shipped plumbing (registry discovery,
> per-class failure isolation, `num_cores`, `formulas`, screen/HTML
> reporting) — reused, not duplicated. Consumes
> `model_diagnostics_framework.md`'s typed check results as assumption
> gates in its selection table (split from a briefly-combined plan,
> 2026-09-02, user decision: that sibling is the **absolute** half of
> model criticism, this is the **relative** half). **Does not share
> substrate with `sample_splitting_model_selection.md`** (v2.0.0,
> `release_v2_0_0.md → TODO-6e`) **— correction, 2026-09-06 (user
> question: "do we need this for ModelSelection?").** An earlier draft of
> this header claimed the two plans share `Design`-level splitting/fold
> machinery and should "land their common substrate once." That
> conflated two different requirements. This plan's CV folds only need to
> avoid leakage across already-linked units within a static,
> already-realized dataset — a weak requirement `resolve_resampling_unit()`
> already satisfies for every design family, fixed or sequential (see
> TODO-3). Sample splitting needs something structurally harder: a
> subject subset that is *itself* a valid realization of the design's own
> stochastic mechanism, since design-based inference then runs on that
> subset alone — that is what breaks under an arbitrary subset of a
> sequential design's arrivals, and it is a problem this plan never had.
> The two plans share no open problem; each solves its own, and neither
> is blocked on the other. Complementary to the whole
> model-selection-honesty family (`_master.md` 5AB–5AG); this plan is the
> **choose** step those plans' **test** steps assume, plus one new
> test-step mechanism of its own (the selection-inclusive randomization
> test, §5). **Release target — split into two phases (2026-09-05, user
> decision; the split's own reasoning narrowed 2026-09-06, user question
> about Phase B's actual difficulty — see §7 and TODO-3):**
>
> - **Phase A → v1.1.0** (`release_v1_1_0.md → TODO-17y`): the
>   `ModelSelection` workflow, tier-gated criteria, provenance, and the
>   selection-inclusive randomization test with CI
>   inversion — across **every design family EDI supports** (fixed:
>   completely randomized, blocked, stratified; matched-pair; cluster;
>   sequential matching-on-the-fly, including KK14/KK21) for the
>   continuous + incidence response types. **Finding that unlocked the
>   original 2026-09-05 move:** the selection-inclusive randomization test
>   needs *no* `Design`-level fold/split substrate at all. It needs only
>   the permutation engine's already-shipped user-statistic hook
>   (`set_custom_randomization_statistic_function()`,
>   `inference_all_abstract_rand.R:22`) and the registry — and every
>   design's redraw-of-`w` mechanism for the per-replicate re-run
>   already exists and is design-agnostic, since that is the package's
>   core, already-shipped randomization engine. **Second finding that
>   widened the move, 2026-09-06:** the one thing that *did* still need
>   design cooperation — CV folds for the comparative-criteria layer —
>   turns out to already exist too.
>   `resolve_resampling_unit()` (`inference_ext_exchangeable_resampling_units.R:15-33`)
>   dispatches on `is_matching_design()` / `is_cluster_design()` /
>   `is_blocking_design()`, **never** on whether treatment assignment was
>   fixed-upfront or sequential, and already returns `"matched_set"` for
>   KK-family sequential matching designs exactly as it returns `"pair"`
>   for a fixed matched-pair design — the same dispatch already serving
>   the bootstrap for both. There is no "arrival sequence" fold category
>   to build; no such category exists in that function (an earlier TODO-3
>   draft invoked one that isn't real). Phase A is additive (a new
>   workflow object; no default changes), so it meets the 1.x
>   release-line rule. The R Consortium ISC proposal
>   (`new_research_ideas/grants/RcISC/isc-proposal.qmd`; the earlier
>   `grant.tex` is now `grant_notes.tex`) has been re-scoped to this
>   widened Phase A — every design family, all six response types — and,
>   as of 2026-09-06, carries no blinding claims, matching §5.
> - **Phase B → v2.0.0** (`release_v2_0_0.md → TODO-6h`, narrowed
>   further, 2026-09-06): **only** the response types not reached in the
>   v1.1.0 pilot (count, proportion, survival, ordinal). The
>   design-family extension that used to be this phase's entire reason
>   for existing moved to Phase A above, because it was never a real
>   2.0.0-shaped cost (§7). Whether response-type coverage alone still
>   merits a 2.0.0 slot under this file's own release-line rule
>   ("genuinely new functionality requiring large refactoring"), or fits
>   v1.4.0's response-and-data-extensions theme better, is an open
>   question this correction surfaces but does not resolve — see TODO-9.
>
> (Global ordering: see `_master.md` 5AI.)

Written 2026-09-02 (user proposal: `ModelSelection(des_obj)` giving
"model selection diagnostics for the different offered models and
different formulas `~1`, `~.`, `~.*.`, non-parametrics").

Related:
[post_selection_inference_menu.md](../new_research_ideas/post_selection_inference_menu.md)
— the reference report comparing all six honest post-selection-inference
routes across this plan and its siblings (source material for the
eventual user vignette); §5 below owns the mechanics it summarizes.

## 1. Why

`InferenceSuite` reports what every applicable model *estimates* but not
which candidate *describes the data best*: no information-criterion
layer, no cross-validated predictive loss, no proper scoring rules. The
gap matters most where the package's own estimands lean on the outcome
model — the g-computation and marginal-estimand classes standardize over
a fitted outcome model, so its fit directly determines the estimate's
quality. The proposal: fit the response type's model catalog across a
formula grid — the default triple `~w` (unadjusted), `~w + .` (additive
adjustment), `~w * .` (treatment-covariate interactions, Lin-style —
TODO-1(d)), plus spline expansions and flexible/nonparametric outcome
models — and report comparative
fit-quality per (class × formula) cell, with the sibling plan's
assumption-check results attached as gates/flags (an
assumption-violating model should not win on AIC).

## 2. The central danger, and two non-negotiable design rules

Parked next to `InferenceSuite`'s p-value table, a comparative-fit panel
is a cherry-picking machine — the exact analytic-flexibility failure the
package's Madigan/Ryan/Schuemie framing exists to prevent, now with a
dashboard. Two rules are load-bearing design constraints, not
documentation afterthoughts:

1. **Selection criteria never see the treatment effect.** No criterion
   displays, sorts, or ranks by treatment-effect magnitude or
   significance. Criteria are outcome-model fit only — mirroring the
   principle that adjustment models are chosen for prognostic value, not
   effect size. `w` *is* in every fit (it is part of the data, and the
   reported model always includes it); what is forbidden is any ranking
   or display keyed to `w`'s coefficient or its p-value. ~~Blinding mode
   (`blind = c("omit_w", "mask_w", "none")`, shared implementation with
   the sibling plan) and its default are a Phase 0 decision (TODO-1);
   `"none"` should exist for the pre-specification workflow (§6) but
   never be the silent default.~~ **Dropped 2026-09-06 (user decision:
   "strip blinding … it's something that will never be implemented") —
   there are no blinding modes; see §5's removal note.**
2. **The output ends in a handoff, not a p-value.** The report's last
   section routes the user to the honest test-step options — the
   selection-inclusive randomization test (§5), sample splitting (5AE),
   selective inference (5AF), or the full-transparency suite summaries
   (CCT/Wilkinson/multiplicity) — and states plainly that reporting the
   selected model's naive p-value is the one unsupported workflow.

## 3. Mechanics

API sketch (shapes are TODO-1 decisions; this is the working target):

```r
ms = ModelSelection$new(des_obj,
       formulas = list(~ w, ~ w + ., ~ w * .), # default (TODO-1(d));
                                               # + spline/flexible entries
       classes  = NULL)                       # default: all applicable
res = ms$run_all_selection(cv_folds = 10, delta_threshold = 2, num_cores = 4,
                           screen = TRUE, html = FALSE)
# res$selection_table: one row per (class x formula) cell — criteria,
#                      assumption-gate flags (from ModelDiagnostics),
#                      typed statuses, and a Stage-1 `in_band` flag
# res$plots: criterion profiles, calibration overlays
```

`delta_threshold` is the Stage-1 supported-band width (§3's two-stage
aggregation), on each tier's own native-criterion scale; default `2`
(Burnham & Anderson 2002's "substantial support" convention).

**Criteria are gated by the likelihood-tier contract** — the tier
metadata prevents the classic invalid comparison structurally:

| Tier | Valid comparative criteria |
|---|---|
| `full` | log-likelihood, AIC, BIC; CV loss; proper scoring rules; calibration |
| `partial` (Cox) | partial-likelihood AIC; concordance (C-index); CV loss |
| `quasi` (GEE, quasi-*, robust) | QIC (Pan 2001), **no AIC/BIC**; CV loss; scoring rules |
| `none` (rank/exact) | CV loss and scoring rules only |

Cross-tier AIC comparison is refused, not warned about. Proper scoring
rules per response type: squared error (continuous), Brier and log score
(incidence), log score (count), C-index and integrated Brier (survival),
ranked probability score (ordinal).

**The two-stage aggregation algorithm — how one global winner comes out
of a table with three incomparable scales (2026-09-06, user-proposed,
ratified; Stage 1 widened to a Δ-criterion band the same day, user
decision, closing the correctness gap the single-winner version had).**
The table above says which criteria are *valid* per tier; it does not by
itself say how a single overall winner is chosen across tiers whose
native criteria (AIC, QIC, partial-AIC) live on different, non-comparable
scales. Resolved as two stages, run after `ModelDiagnostics`' QUALIFY
step has already dropped disqualified cells (§5's pipeline, step 3):

1. **Stage 1 — within-tier, native criterion, keep the Δ-band, no CV.**
   For each tier actually present among the qualified cells, rank its
   formulas by that tier's own criterion (AIC or BIC within `full`, QIC
   within `quasi`, partial-likelihood AIC or C-index within `partial`)
   and keep **every cell within `delta_threshold` of that tier's best**
   (default `delta_threshold = 2`, the Burnham & Anderson "substantial
   support" convention — Burnham & Anderson 2002, ch. 2), not only the
   single argmin. One fit per cell; no fold machinery is invoked at this
   stage at all. **Why the single-winner version (2026-09-06 morning
   draft) was wrong, not just conservative:** keeping only the argmin
   silently assumes the native criterion's within-tier ranking agrees
   with what CV would have picked; when a tier has near-ties under its
   own criterion, that assumption is exactly where it is weakest, and
   discarding the non-argmin near-ties before Stage 2 could permanently
   eliminate the true CV-optimal formula. Keeping the whole supported
   band is the standard hedge against that (Burnham & Anderson's
   multimodel-inference framing generally, not a bespoke fix). A class
   with no formula grid of its own (e.g. `SimpleAverageDiff`, or any
   `likelihood_tier = "none"` class) has nothing to rank internally and
   passes straight through as its own trivial one-cell "band" — Stage 1
   is opportunistic, not mandatory.
2. **Stage 2 — CV/scoring-rule only, only among Stage-1 survivors.** The
   union of every tier's surviving band (one or more cells per
   represented tier) is the *only* set CV-scored. The global winner is
   whichever survivor has the best CV loss / proper scoring rule. This
   is the sole place `cv_folds` refits are paid for — not once per grid
   cell, and it is invoked whenever Stage 1 leaves more than one
   survivor overall, whether that plurality comes from multiple tiers
   being represented, from within-tier near-ties, or both. **The
   narrower case that pays no fold cost:** when Stage 1 leaves exactly
   one survivor in total — a single tier represented, with one cell
   strictly outside every other cell's Δ-band — Stage 2 has nothing to
   bake off against and `cv_folds` is never invoked. This is common
   (a single well-separated formula search within one GLM family) but,
   unlike the single-winner design, is no longer *guaranteed* by "only
   one tier present": a single tier with two closely-competing formulas
   still reaches Stage 2.

This keeps CV's cost to a small, usually-small-constant number of
survivors rather than the whole `(classes × formulas)` grid, which
matters directly for §5's selection-inclusive path
(pipeline-cost × replicates — a `cv_folds`-per-cell design would
multiply that cost by `cv_folds` again), while no longer letting the
native criterion alone have the final say on a close within-tier call.
Consequences to test explicitly (see Tests below): (a) within-tier
AIC-based and CV-based rankings can disagree at small `n` — the classical
AIC ≈ leave-one-out-CV equivalence (Stone 1977) is asymptotic and is not
assumed to hold at the sample sizes this package targets, which is
exactly the risk the Δ-band hedges rather than eliminates (a true
CV-optimal formula more than `delta_threshold` outside its tier's best
can still be missed — the band reduces, not removes, the risk); (b) a
single-candidate tier (only one qualified cell) still goes through Stage
2 alone under its own scoring-rule number, not exempted from the
bake-off; (c) `delta_threshold` is applied on each tier's own native
scale (AIC units within `full`, QIC units within `quasi`, etc.) — it is
not a claim that 2 AIC-units and 2 QIC-units represent the same strength
of evidence, only that each tier uses its own literature's standard
band.

**Cross-validation respects the design's exchangeable unit.** Folds are
built over the same units the bootstrap resamples —
`resolve_resampling_unit()`: intact matched pairs, whole clusters,
clusters-within-strata — never raw rows under a matched/clustered
design. For sequential designs, folding breaks arrival structure; for
*outcome-model fit* purposes this is acceptable and documented, not
silently ignored (the fold unit is reported in the output).

**Formula-grid guardrails.** `~ . * w` explodes quickly at trial-scale
`n`: rank checks and `drop_linearly_dependent_cols()` run per cell, with
cells downgraded to a typed `rank_deficient` status rather than fit
anyway. Covariates are centered before interacting (Lin 2013) so `w`'s
coefficient in an interacted fit reads as the ATE at the covariate mean,
not an extrapolated corner. Flexible/nonparametric outcome-model entries coordinate with
`causal_forest_inference.md` (v2.0.0) rather than growing a second ML
integration; the rank-based inference classes already serve as the
model-free comparators within the catalog itself.

## 4. What this is *not*

Not a combined-evidence summary (5AB/5AC/5AD do that), not a splitting
workflow (5AE), not a conditional-coverage correction (5AF), not an
adaptive-validity framework (5AG), and not assumption checking (the
sibling plan). It is the comparative half of the model-criticism layer
those plans assume exists, with the honesty machinery attached at the
exit. **Also not a stacking/ensemble-weighting alternative to RANK's
discrete pick-one-winner step** — that generalization was worked through
and found valid (§5b), but is explicitly not part of this plan's
implementation; TODO-7 implements discrete selection only.

## 5. The selection-inclusive randomization test, and honest post-selection inference generally

The distinctive payoff, and the piece no sibling plan covers.
*(Ratified 2026-09-02, user decision, after working the mechanics in
conversation: pipeline composition, hard-gate default, mandatory
fallback below are decided, not open. Blinding commutation and the
battery-tranche split, ratified the same day, were **removed
2026-09-06** — see the note after the requirements list.)*

**The pipeline as a statistic.** A randomization test is valid under the
sharp null for **any** statistic — provided the identical procedure is
applied to every redrawn assignment. So wrap the entire criticism
pipeline as the test statistic:

```
T(w):  1. fit every (class x formula) cell in the grid
       2. run each cell's declared assumption battery
       3. QUALIFY: drop cells failing their gates       <- ModelDiagnostics
       4. RANK: tier-valid criteria over the survivors  <- ModelSelection
          (the two-stage algorithm, §3: within-tier native criterion,
          keeping every cell within `delta_threshold` of each tier's
          best, then a CV/scoring-rule bake-off over the union of those
          survivors — not CV over the whole grid, and not a single
          native-criterion argmin left unchecked)
       5. fit the winner, return its treatment estimate
```

and let `compute_rand_two_sided_pval()` / the BRT redraw `w` (or
resample-then-redraw) and re-run steps 1–5 per replicate, via the
existing custom-randomization-statistic machinery
(`inference_ext_custom_randomization_statistic.R`). Valid post-selection
p-values with no power sacrificed to a split and no conditioning
formula — selection costs compute, not validity.

**Requirements for `T(w)` to be a well-defined statistic (ratified):**

- *Gates are pre-specified constants.* Disqualification thresholds
  (e.g., "drop Cox if the Schoenfeld check rejects at 0.05") are part of
  the pipeline definition, declared in the sibling plan's typed check
  contract — never a judgment call. Any internal randomness (CV folds)
  is index-deterministic or seed-pinned so the pipeline is a pure
  function of `(X, y, w)`.
- *Hard gate is the default; penalty flags are the option.*
  Disqualify-then-rank (the composition above) is the default semantic.
  A soft variant — keep flagged models but penalize them in the ranking
  — is offered as an option: both are valid inside `T(w)`; the hard gate
  makes `T` discontinuous (lumpier null distribution, lower acceptance
  rates in the conditional variant below), the soft flag trades
  occasional selection of assumption-shaky models for a smoother, often
  more powerful statistic.
- *The qualified set must be non-empty by construction.* On some redraws
  every parametric candidate may fail its gates, and `T(w)` must still
  return a number. The structural answer: `likelihood_tier = "none"`
  classes (rank/exact) have essentially no parametric assumptions to
  violate and never disqualify — so the pipeline builder **requires** at
  least one assumption-light class in the candidate universe as the
  guaranteed fallback floor. A hard requirement, not a convention.

**~~The blinding-commutation result (the free lunch)~~ and ~~the
battery-tranche split~~ — removed 2026-09-06 (user decision: "strip
blinding from model_selection_framework.md as it's something that will
never be implemented").** Both paragraphs rested on ranking
`w`-stripped skeletons (`omit_w`), under which the winner was provably
identical across redraws and the test collapsed to a plain
randomization test of one model. The user's standing position
(2026-09-06, three separate corrections) is that `w` is part of the
data and therefore part of every fit and every diagnostic: the ranked
objects are `~w`, `~w + .`, `~w * .` *with* `w` inside them, so each
cell's criterion and its diagnostics legitimately move with every draw
and the winner may change from draw to draw. That is not a defect; it
is exactly the selection variability the test prices in. Consequences:
(i) there is no shortcut — every replicate re-runs steps 1–5 in full;
(ii) there is no `blindable` tag, no tranche split, no `blind =`
argument, and `method = "auto"` has no cheaper path to detect; (iii) CI
inversion under the shift null `delta` re-runs the full pipeline per
`delta` × replicate — the de-treat-once-per-`delta` trick no longer
applies, so the CI-search-driver plans
(`garthwaite_buckland_ci_search.md`, `brent_ci_inversion.md`) are what
keep the number of `delta` evaluations small; (iv) the cost is
pipeline × `R`, embarrassingly parallel over both replicates and cells,
dispatched over the persistent worker pool `set_num_cores(k)` already
stands up (fork cluster on Unix, `mirai` daemons on Windows or under
`force_mirai = TRUE`, native BLAS/OpenMP threads pinned to one per
worker — `globals.R:533-587`), with warm starts, shared design matrices
and the C++ fitters keeping each replicate cheap. The winner's-curse
caveat survives unchanged: the selected model's raw point estimate is
biased; report the inversion-centered interval as the headline number.
Downstream documents that still describe the removed result and need
the same strip: `model_diagnostics_framework.md` §2 (`blindable` tag),
`_master.md` 5AI, `release_v1_1_0.md` TODO-17y, `ROADMAP.md` v1.1.0,
`post_selection_inference_menu.md` §1–2, and
`selective_inference_post_selection.md`.

**Provenance, and inference that refuses to be naive.**
`ModelSelection$run_all_selection()` returns a provenance object: the
winner, the candidate universe, gate thresholds, pinned
seeds, and the pipeline as a replayable closure exposing
`as_randomization_statistic()`. Post-selection inference is then
constructed *from the provenance*:

```r
psi = InferencePostSelection$new(des_obj, selection = sel,
        method = c("auto", "rand_selection_inclusive",
                   "rand_conditional", "split", "simultaneous"))
```

`method = "auto"` resolves to the selection-inclusive re-run (there is
no cheaper exact path — see the removal note above); it exists so the
dispatch seam stays stable if one is ever added. Because inference received
the provenance, the §2 "one unsupported workflow" rule is enforced
mechanically: a naive asymptotic p-value on a selection-tainted winner
is a typed refusal, not a documentation caveat. The other methods route
to the honest alternatives: `"rand_conditional"` is the
rejection-sampled conditional randomization test (keep only redraws
selecting the same winner — the design-based implementation of selective
inference; see `selective_inference_post_selection.md`, which owns it);
`"split"` hands off to 5AE; `"simultaneous"` computes max-|t| bands
across the whole grid from one redraw set, valid for any selection at
the price of conservatism.

Remaining costs stated honestly: the test is pipeline-cost ×
replicates (embarrassingly parallel over `set_num_cores()`'s pool;
mitigated by warm starts, effort tiers, and the existing sequential-MC
early stopping); the BRT variant
inherits the open asymptotic-validity question recorded in
`inference_all_abstract_rand_bootstrap.R`. Whether this section ships
inside this plan or splits into its own
(`selection_inclusive_randomization_test.md`) remains a TODO-1
decision; its validity argument should also be recorded in
`InferenceRandBootstrap`'s roxygen neighborhood where the package's
other validity arguments live.

## 5b. Generalization: stacking/ensemble weighting instead of discrete
selection (worked through 2026-09-06, user question; validated but
**not implemented** — decided the same day, see TODO-1(i))

The question this section answers: if `ModelDiagnostics` still prunes
step 3 (QUALIFY), but step 4 (RANK) is replaced by CV-optimized
stacking/super-learner weighting over the survivors instead of picking
one winner, is wrapping *that* pipeline in the randomization test of §5
still exact under Fisher's sharp null? **Yes, unconditionally, for the
same reason as the discrete case** — the randomization test's exactness
depends only on `Y` being fixed under FSN and `T(Y, w)` being a
deterministic, always-defined function of it; it does not care whether
`T` picks one model or blends fifty. Concretely this needs the same two
structural guarantees §5's discrete version already requires and nothing
more: the pruning-then-weighting recipe is seed-pinned (any CV folds used
to fit the stacking weights are pure functions of `(X, Y, w)` given a
fixed seed), and the mandatory assumption-light fallback class (TODO-1(e))
still guarantees a non-empty survivor set to stack on every replicate.

That said, "exact" is not the same claim as "honest" in this family's
fuller sense, and two things do not come free merely by swapping the
RANK mechanism:

1. **What scalar is `T` now?** A single selected model's treatment
   coefficient is self-evidently a treatment-effect estimate; a stacked
   ensemble often is not, because some candidate learners (flexible/
   nonparametric members, e.g. anything from `causal_forest_inference.md`)
   have no literal coefficient on `w` at all. Two candidate definitions,
   neither automatic: (a) a CV-loss-weighted average of each surviving
   member's *own* coefficient, for members that have one — this is
   `model_averaged_estimand_report.md`'s existing machinery with
   CV-derived weights in place of AIC weights; or (b) a g-computation
   contrast (`mean[ŷ(x,1)] − mean[ŷ(x,0)]`) on the stacked predictor
   treated as a flexible outcome model — generalizes to any member type,
   and reuses the same pattern EDI's `*GComp*` inference classes already
   apply to single fitted models. (b) is the more general choice if this
   is ever built.
2. **Rule 1 bites harder on a weight-fitting objective, not softer.**
   §2 rule 1 ("selection criteria never see the treatment effect") was
   written against discrete choice, where a human or algorithm picks
   model A over B — an auditable, visible act. Continuous weighting is a
   *more* dangerous cherry-picking surface if the objective can reward
   `w`'s coefficient at all: an optimizer can assign weight 0.73 to the
   flattering combination and 0.27 to the rest, continuously and
   invisibly, with no discrete "which one did you pick" for a reader to
   question. The non-negotiable requirement is therefore that the
   stacking-weight loss is a pure outcome-prediction loss — never a loss
   that could reward a combination for a larger or more significant
   treatment coefficient. (An earlier version of this item also claimed
   §5's blinding-commutation collapse applied here; that result was
   removed 2026-09-06 along with §5's — the weights, like the discrete
   winner, are refit on every redraw.)

**Cost note.** A g-computation contrast on a stacked (necessarily
non-linear) predictor falls outside the affine-shift identity's scope —
`randomization_ci_affine_shift_reuse.md` explicitly excludes
g-computation on non-linear models from `t0_b(δ) = t0_b(0) + δ·(1−c_b)`.
So this generalization, if ever built, gets none of that plan's CI-search
speedup; every point on the CI search pays the full re-permutation cost.

**Winner's-curse note (plausible, not proven here).** A CV-optimized
stacked combination is a shrinkage-flavored estimate rather than a hard
argmin bet, so it plausibly carries a milder finite-sample selection bias
than the discrete winner's raw point estimate — this is consistent with
the general stacking/super-learner literature's appeal, but is not a
result this plan derives or verifies, and does not change the
recommendation to report the randomization-based (not naive) inference
either way.

**Disposition:** validated as a sound generalization, explicitly **not
implemented** — TODO-7 builds discrete pick-one-winner selection only.
Revisit as a future extension (most likely as a CV-weighted variant of
`model_averaged_estimand_report.md` rather than a new plan) only if a
concrete request for it materializes; nothing in TODO-7's design blocks
building it later, since RANK's discrete step and this generalization
are interchangeable at the same seam.

## 6. The no-validity-issues mode: pre-specification

Run on pilot/historical data, or on blinded interim data, this framework
is simply a principled way to *pre-specify* the analysis model — no
selection-effect correction needed because no unblinded outcome data
informed the choice. KK21 is in-house precedent that data-adaptive
choice is legitimate when the machinery accounts for it; here the
accounting is temporal (choose before unblinding) rather than
replay-based. The documentation should present this as the recommended
default workflow, with §5 as the rescue when selection did touch
unblinded data.

## 7. Architectural cost — revised again 2026-09-06: cost (i) was never
real for this plan

The original slating listed four costs: (i) `Design`-level fold/split
support shared with sample splitting — a post-hoc row filter can break a
matching-on-the-fly design's own within-fold structure, so folds need
design cooperation, not subsetting; (ii) a genuinely new public workflow
object with a large criteria surface rolled out per tier across the
registry; (iii) treatment-blinding infrastructure that must provably
keep `w` out of the criteria path (**dropped outright 2026-09-06** —
see §5's removal note; no longer a cost of any phase); (iv) the selection-inclusive
randomization wrapper touching the hot resampling loops.

The 2026-09-05 revision moved (ii)–(iv) to Phase A as additive
(new object, new argument, a client of an already-shipped hook) and kept
(i) in Phase B, reasoning that fold cooperation for matched/clustered/
sequential designs was the one genuinely 2.0.0-shaped cost remaining.
**That reasoning was itself wrong, corrected 2026-09-06 (user question):**
(i) conflated this plan's own CV-fold need — weak: avoid leakage across
already-linked units in a static, already-realized dataset — with sample
splitting's need — strong: a subject subset must itself be a valid
realization of the design's stochastic mechanism, since design-based
inference then runs on it in isolation. Only the second is genuinely hard
for sequential designs, and this plan never needed it. What it actually
needed, the first, `resolve_resampling_unit()` already provides
uniformly, because that function dispatches on matching/clustering/
blocking structure (`is_matching_design()` / `is_cluster_design()` /
`is_blocking_design()`), never on whether treatment assignment was
fixed-upfront or sequential — see the header for the exact dispatch. So
**every surviving original cost is additive and already-solved for every
design family**; there is no remaining structurally-2.0.0 cost on the
design-family axis of this plan. Phase A now takes (i), (ii) and (iv) across every
design family EDI supports. Phase B's only remaining content —
response-type coverage — was never one of these four costs to begin
with, and this section does not analyze its difficulty one way or the
other (see the header's open question and TODO-9).

## Tests

- Tier gating: a `quasi`-tier cell exposes QIC and never AIC; cross-tier
  AIC comparison is a typed refusal.
- Two-stage aggregation: (a) `cv_folds` refits are counted (spy on the
  fold-fitting call) and equal exactly the number of Stage-1 survivors
  (the union of every tier's `delta_threshold`-band), never the full
  `(classes × formulas)` grid size; (b) a grid with a clear, well-
  separated best formula in each of three tiers produces exactly one
  Stage-2 CV/scoring-rule comparison across exactly three survivors, one
  per tier; (c) a class with no formula grid (e.g. `SimpleAverageDiff`)
  enters Stage 2 directly as a one-cell band, with no Stage-1 ranking
  step logged for it; (d) a single-tier grid with one formula strictly
  outside `delta_threshold` of every competitor never invokes Stage 2's
  CV machinery at all — the sole Stage-1 survivor is the global winner,
  no fold cost paid; (e) **the widening's own correctness test:** a
  single-tier fixture engineered so two formulas are within
  `delta_threshold` of each other under the native criterion but have a
  known, different CV-optimal ordering — assert both formulas appear as
  Stage-1 survivors (neither silently dropped for being the non-argmin)
  and that Stage 2's CV comparison, not the native criterion, decides
  between them; (f) a fixture with a near-tie strictly outside
  `delta_threshold` confirms the non-argmin cell is correctly excluded
  from Stage 1 (the band is not vacuous — it has to actually filter
  something in the ordinary case, not just widen unconditionally).
- Fold integrity (all Phase A now, 2026-09-06 — no longer split by
  phase): under a matched-pair or KK-family sequential matching design,
  no fold separates a matched pair or matched set; under cluster designs,
  no fold splits a cluster; under a blocked/stratified design, folds are
  stratified by block; under a completely randomized design, folds are
  plain row subsets.
- Gate wiring: a cell flagged by the sibling plan's battery carries its
  gate flag in the selection table, with TODO-1(e) semantics (hard gate
  vs. flag) honored.
- Rule 1: no output object sorts or ranks cells by the treatment
  coefficient or its p-value — the selection table orders by criterion
  only, and no criterion column is a function of `w`'s coefficient.
- Selection-inclusive randomization test: simulated Type-I error at
  nominal level under the sharp null with aggressive diagnostics-gated
  selection over a wide grid (the whole point — verify the level
  survives selection); reproducibility across `num_cores`.
- Failure isolation: one pathological (class × formula) cell yields a
  typed status, never an aborted panel.

## TODOs

- [ ] TODO-1: **Decision gate (ask the user, no code).** (a) Standalone
  object vs. a verb on `InferenceSuite`; (b) ~~`blind` default (`"omit_w"`
  proposed, shared with the sibling) and whether `"none"` requires an
  explicit acknowledgment argument~~ **moot (2026-09-06, user): blinding
  is stripped from this plan and will never be implemented — see §5's
  removal note**; (c) ratify §3's tier-gated criteria
  table; (d) ~~default formula grid~~ **decided (2026-09-06, user
  question: "should formula ∈ {~1+w, ~.+w, ~.*w} be the default"):
  `w` is written explicitly in every candidate (`~1+w`, `~.+w`), not
  auto-appended to a `w`-free skeleton — uniform across the grid, and it
  leaves room for a genuinely `w`-free prognostic-only candidate as a
  distinct (if unusual) entry, which the auto-append convention couldn't
  express. **Default grid — revised the same day (2026-09-06, user
  decision, superseding the two-formula default recorded earlier that
  day): `list(~w, ~w + ., ~w * .)`**, i.e. unadjusted, additively
  adjusted, and the Lin-style interaction (covariates centered first per
  Lin 2013 so `w`'s coefficient in the interacted fit reads as the ATE at
  the covariate mean). ~~`~w`/`~w + .` were "blindable under `omit_w`"
  and `~w * .` was not (under `omit_w` it collapsed to `~w + .`), so an
  earlier same-day decision kept `~.*w` opt-in (`include_interactions =
  TRUE`) to keep the default on the free-lunch blinded path.~~ **The
  user overrode that on cost grounds ("who cares about affordability? …
  all embarrassingly parallelizable"), and then removed blinding from
  the plan altogether the same day — so the distinction that motivated
  the opt-in no longer exists: all three cells are ordinary grid entries
  fit on `(X, y, w)`, ranked afresh on every replicate, parallelized
  over `set_num_cores()`'s pool. There is no `include_interactions`
  argument. The ISC grant
  (`new_research_ideas/grants/RcISC/proposal/03-proposal.qmd`, worked
  ordinal example) carries the same three-formula default (16 regression
  classes × 3 = 48 cells + 3 rank-based = 51).**; (e) ~~assumption-gate semantics (hard
  gate vs. flag)~~ **decided (2026-09-02, user): hard gate is the
  default, penalty-flag ranking is the offered option; gates are
  pre-specified constants in the sibling's typed check contract; the
  candidate universe must include an assumption-light
  (`likelihood_tier = "none"`) fallback class so the qualified set is
  non-empty by construction — see §5**; (f) ~~does §5 split into its own
  plan file~~ **decided (2026-09-05, user): no — §5 stays here as the
  core of Phase A**; (g) ~~confirm v2.0.0 slating against 5AE's timeline
  since they share substrate~~ **decided (2026-09-05, user), then
  corrected (2026-09-06, user question): Phase A moves to v1.1.0
  (`TODO-17y`) because the selection-inclusive test needs no `Design`
  substrate at all, and — corrected 2026-09-06 — this plan's CV-fold need
  is not actually shared with `sample_splitting_model_selection.md`
  either; `resolve_resampling_unit()` already covers every design family
  on its own. Phase A therefore covers every design family, not just
  fixed ones; Phase B (TODO-9) narrows to response-type coverage only,
  no longer "coordinated with 5AE in 2.0.0"** — see the header and §7;
  (h) ~~how does one global winner come out of a table whose per-tier
  criteria (AIC/QIC/partial-AIC) are on non-comparable scales~~
  **decided (2026-09-06, user-proposed, ratified; widened same day, user
  decision): the two-stage aggregation algorithm in §3 — Stage 1 keeps
  every formula within a `delta_threshold` (default 2, Burnham & Anderson
  2002) of each represented tier's best under that tier's native
  criterion, no CV; Stage 2 runs the CV/scoring-rule bake-off over the
  union of Stage-1 survivors only — never CV over the whole grid, and
  never trusting a single native-criterion argmin to settle a close call
  on its own.**; (i) ~~should RANK use stacking/ensemble weighting over
  the survivors instead of discrete pick-one-winner selection~~
  **decided (2026-09-06, user): no — validated as a sound generalization
  (§5b: exact under FSN for the same structural reason as discrete
  selection, provided the weight-fitting objective never rewards the treatment effect and
  a scalar contrast definition is picked), but explicitly out of scope
  for this plan's implementation. TODO-7 builds discrete selection only.**
- [ ] TODO-2: **Comparative-criteria layer**, tier-gated and
  registry-driven: log-lik/AIC/BIC extraction where
  `likelihood_tier = "full"`, QIC for `"quasi"`, partial-likelihood AIC
  + C-index for `"partial"`, scoring rules for all tiers; per-cell typed
  statuses; gate wiring per TODO-1(e); **the two-stage aggregation
  (§3, TODO-1(h)) that turns this table into one global winner — Stage 1
  within-tier ranking with the `delta_threshold` band kept per tier,
  Stage 2 CV/scoring-rule bake-off restricted to the union of Stage-1
  survivors, never CV over the full grid. `delta_threshold` is a
  `run_all_selection()` argument, default `2`.**
- [ ] TODO-3: **Fold machinery** (unified across every design family,
  2026-09-06 — no longer split into a Phase A stub and a Phase B build;
  see the header and §7 for why). A seed-pinned fold-builder over
  `resolve_resampling_unit()`'s existing categories: `observation` under
  completely randomized, blocked, and stratified designs (plain row/
  stratum subsetting); `pair` or `matched_set` under fixed matched-pair
  and KK-family sequential matching-on-the-fly designs (intact pairs/sets
  per fold, never split); `cluster` under cluster designs (intact
  clusters per fold). No new `Design`-side API is needed — this consumes
  `resolve_resampling_unit()` exactly as it already exists
  (`inference_ext_exchangeable_resampling_units.R:15-33`) and already
  serves the bootstrap for every one of these design families, regardless
  of whether treatment assignment was fixed-upfront or sequential.
  ~~Earlier drafts (through 2026-09-05) split this into a Phase-A helper
  covering fixed designs only, typed-refusing any design whose
  `resolve_resampling_unit()` returned a matched pair, a cluster, or "an
  arrival sequence" (not a real category — the function's actual valid
  set is `observation`, `cluster`, `block`, `pair`, `matched_set`,
  nothing else), deferring everything else to a Phase B described as
  "shared with `sample_splitting_model_selection.md`." Both the refusal
  category and the shared-substrate claim were wrong — see the header's
  2026-09-06 correction.~~
- [ ] TODO-4: **Formula-grid engine** with rank/collinearity guardrails
  and typed `rank_deficient` downgrades; spline entries; flexible-model
  entries deferred to `causal_forest_inference.md` coordination. Default
  grid `list(~ w, ~ w + ., ~ w * .)` per TODO-1(d); the `~ w * .` cell
  (Lin-style, covariates centered first) is an ordinary grid entry;
  there is no `include_interactions` argument. (The
  sibling plan consumes this engine; if its pilots ship first per its
  TODO-1(e), it carries a minimal local grid until this lands.)
- ~~TODO-5: **Blinding modes** with the §Tests invariance guarantees
  (shared implementation with the sibling plan).~~ **Dropped 2026-09-06
  (user): never to be implemented — see §5's removal note. Number kept
  so cross-references elsewhere still resolve; the sibling plan's
  matching item needs the same strike.**
- [ ] TODO-6: **Reporting**: selection table, criterion-profile and
  calibration plots, HTML report, and the §2 rule-2 handoff footer.
- [ ] TODO-7 *(Phase A — the core deliverable)*: **Selection-inclusive
  randomization statistic**: pipeline wrapper over the
  custom-randomization-statistic machinery
  (`set_custom_randomization_statistic_function()`), the per-replicate
  full re-run of steps 1–5 dispatched over `set_num_cores()`'s
  persistent pool (fork on Unix, `mirai` on Windows — `globals.R:533`)
  across both replicates and cells, CI inversion by full re-run per δ
  (§5's removal note; pair with the CI-search-driver plans to keep the
  δ count small), the provenance-driven dispatch and the typed refusal
  of naive inference on a selection-tainted winner, warm-start and
  shared-design-matrix wiring so each replicate is cheap, and the
  level/coverage simulation study (naive inflation → exact size →
  interval coverage → power vs. a pre-specified model). Pilot scope:
  every design family EDI supports (fixed, matched-pair, cluster,
  sequential matching-on-the-fly — widened 2026-09-06 from the original
  fixed-designs-only scope, see the header), continuous + incidence,
  default grid `~ w`/`~ w + .`/`~ w * .` per TODO-1(d). The BRT
  variant and the simultaneous max-|t| bands are stretch items within
  this TODO. The rejection-sampled conditional variant is owned by
  `selective_inference_post_selection.md → TODO-7` and is unblocked by
  this item. **Discrete pick-one-winner only** — stacking/ensemble
  weighting over the survivors was worked through and validated as an
  equally-exact alternative (§5b) but is explicitly not part of this
  item's scope (TODO-1(i)).
- [ ] TODO-8: **Documentation**: vignette with the pre-specification
  workflow as the front door, the §2 "one unsupported workflow"
  statement, roxygen, and a JSS-manuscript sentence when shipped (the
  paper's `InferenceSuite` section is the natural attachment point).
  *(Phase A: the vignette and roxygen ship with the pilot; the JSS
  sentence when the manuscript next revises.)* **The two-stage
  aggregation algorithm's roxygen (whichever method documents Stage 1)
  must cite both (a) Stone (1977) for the AIC ≈ leave-one-out-CV
  equivalence backing the use of a native criterion at all, and (b)
  Burnham & Anderson (2002) for the ΔAIC/ΔQIC/Δ(partial-AIC) < 2
  supported-band convention `delta_threshold` implements — verify both
  against their primary sources first (currently tagged `NEEDS
  VERIFICATION` in this plan's References), and add both to
  `REFERENCES.md` alongside the existing Akaike/Schwarz/Pan entries this
  plan already cites** — do not let either citation ship as prose in
  this plan file only.
- [ ] TODO-9 *(narrowed 2026-09-06 — no longer "Design extensions";
  release TBD, see the header's open question)*: **Response-type
  coverage.** Roll out `ModelSelection` and the selection-inclusive
  randomization test to the response types not reached in the v1.1.0
  pilot (count, proportion, survival, ordinal): registry-driven per-tier
  criteria and per-type g-computation/scoring rules already exist
  elsewhere in the package for these types; this item wires
  `ModelSelection`'s grid/criteria/reporting layer to them, using the
  same TODO-3 fold machinery and TODO-7 randomization-test machinery
  every other design family already uses (nothing design-specific left
  to build for this item — design coverage moved to TODO-3/TODO-7 as
  part of Phase A). Whether that makes this a 1.4.0-shaped item (response
  extensions) rather than a 2.0.0-shaped one is unresolved — see the
  header.

## References

(Repo convention: entries marked `NEEDS VERIFICATION` were supplied from
general knowledge and must be checked against the primary source before
citation in roxygen/`REFERENCES.md`.)

- Akaike, H. (1974). "A new look at the statistical model
  identification." *IEEE Transactions on Automatic Control*, 19(6),
  716–723. `NEEDS VERIFICATION` (venue/pages).
- Schwarz, G. (1978). "Estimating the dimension of a model." *The Annals
  of Statistics*, 6(2), 461–464.
- Stone, M. (1974). "Cross-validatory choice and assessment of
  statistical predictions." *JRSS-B*, 36(2), 111–147. `NEEDS
  VERIFICATION` (pages).
- Stone, M. (1977). "An asymptotic equivalence of choice of model by
  cross-validation and Akaike's criterion." *JRSS-B*, 39(1), 44–47.
  `NEEDS VERIFICATION`. Distinct from Stone (1974) above — this is the
  specific result (AIC asymptotically equivalent to leave-one-out CV for
  nested, regular models) cited in §3's two-stage aggregation algorithm
  as the theoretical backing for Stage 1's use of AIC as a cheap proxy
  for within-tier CV ranking; the same section documents that the
  equivalence is asymptotic only and is not assumed to hold at this
  package's target sample sizes, and that no analogous equivalence is
  claimed (or known to this plan's authors) for BIC, QIC, or
  partial-likelihood AIC.
- Burnham, K. P., and Anderson, D. R. (2002). *Model Selection and
  Multimodel Inference: A Practical Information-Theoretic Approach*
  (2nd ed.). Springer-Verlag. `NEEDS VERIFICATION` (edition/pages). Source
  of the ΔAIC < 2 "substantial support" convention §3's two-stage
  aggregation algorithm uses (widened 2026-09-06, user decision) as the
  default `delta_threshold` for Stage 1's supported band — i.e. the
  standard multimodel-inference practice of retaining every model within
  a fixed distance of the best under an information criterion, rather
  than only the single argmin, before any further comparison. Applied
  here per-tier (AIC within `full`, QIC within `quasi`, partial-likelihood
  AIC within `partial`) — the source explicitly develops the convention
  for AIC; its extension to QIC and partial-likelihood AIC in this plan
  is this plan's own application of the same numeric rule of thumb to an
  analogous information-criterion-shaped quantity, not a claim that
  Burnham & Anderson themselves establish that extension.
- Pan, W. (2001). "Akaike's information criterion in generalized
  estimating equations." *Biometrics*, 57(1), 120–125. (QIC.)
- Gneiting, T., and Raftery, A. E. (2007). "Strictly proper scoring
  rules, prediction, and estimation." *JASA*, 102(477), 359–378.
- Harrell, F. E., Califf, R. M., Pryor, D. B., Lee, K. L., and Rosati,
  R. A. (1982). "Evaluating the yield of medical tests." *JAMA*,
  247(18), 2543–2546. (C-index.) `NEEDS VERIFICATION`.
- Lin, W. (2013) — interaction adjustment; already `[Lin2013]`-adjacent
  in the JSS bib; reuse that record.
- Madigan, D., Ryan, P. B., and Schuemie, M. (2013) — already
  `[MadiganRyanSchuemie2013]` in `REFERENCES.md`.
- Fisher, R. A. (1935) — already `[Fisher1935]`; sharp-null randomization
  validity for arbitrary statistics.
- Lehmann, E. L., and Romano, J. P. (2005). *Testing Statistical
  Hypotheses* (3rd ed.), Springer — randomization-test validity for any
  statistic (chapter/section to pin down). `NEEDS VERIFICATION`.
- Edgington, E., and Onghena, P. (2007). *Randomization Tests* (4th
  ed.), Chapman & Hall/CRC. `NEEDS VERIFICATION` (edition year).
- Kallus, N. (2018) — already `[Kallus2018]` in `REFERENCES.md` (BRT
  precursor; §5's BRT variant inherits its open asymptotic-validity
  question, per `inference_all_abstract_rand_bootstrap.R`).
