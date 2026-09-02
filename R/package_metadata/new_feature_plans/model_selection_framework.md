# `ModelSelection`: Comparative Fit over the Model × Formula Grid, with an Honest Exit

> **Depends on:** `InferenceSuite`'s shipped plumbing (registry discovery,
> per-class failure isolation, `num_cores`, `formulas`, screen/HTML
> reporting) — reused, not duplicated. Consumes
> `model_diagnostics_framework.md`'s typed check results as assumption
> gates in its selection table (split from a briefly-combined plan,
> 2026-09-02, user decision: that sibling is the **absolute** half of
> model criticism, this is the **relative** half). Shares the
> `Design`-level splitting/fold machinery with
> `sample_splitting_model_selection.md` (v2.0.0,
> `release_v2_0_0.md → TODO-6e`) — the two plans should land their common
> substrate once (see TODO-3). Complementary to the whole
> model-selection-honesty family (`_master.md` 5AB–5AG); this plan is the
> **choose** step those plans' **test** steps assume, plus one new
> test-step mechanism of its own (the selection-inclusive randomization
> test, §5). **Release target: v2.0.0** (`release_v2_0_0.md → TODO-6h`),
> same release and same architectural reason as its sibling 5AE: real
> `Design`-level fold/split support, thorniest for sequential
> matching-on-the-fly designs. (Global ordering: see `_master.md` 5AI.)

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
formula grid — `~ 1` (unadjusted), `~ .` (additive adjustment), `~ . * w`
(treatment-covariate interactions, Lin-style), spline expansions, and
flexible/nonparametric outcome models — and report comparative
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
   significance. Criteria are outcome-model fit only, computed
   **treatment-blinded** where feasible — `w` omitted from the fit, or
   included with its coefficient masked from every output — mirroring
   the principle that adjustment models are chosen for prognostic value,
   not effect size. Blinding mode (`blind = c("omit_w", "mask_w",
   "none")`, shared implementation with the sibling plan) and its
   default are a Phase 0 decision (TODO-1); `"none"` should exist for
   the pre-specification workflow (§6) but never be the silent default.
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
       formulas = list(~ 1, ~ ., ~ . * w),   # + spline/flexible entries
       classes  = NULL,                       # default: all applicable
       blind    = "omit_w")
res = ms$run_all_selection(cv_folds = 10, num_cores = 4,
                           screen = TRUE, html = FALSE)
# res$selection_table: one row per (class x formula) cell — criteria,
#                      assumption-gate flags (from ModelDiagnostics),
#                      typed statuses
# res$plots: criterion profiles, calibration overlays
```

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
anyway. Flexible/nonparametric outcome-model entries coordinate with
`causal_forest_inference.md` (v2.0.0) rather than growing a second ML
integration; the rank-based inference classes already serve as the
model-free comparators within the catalog itself.

## 4. What this is *not*

Not a combined-evidence summary (5AB/5AC/5AD do that), not a splitting
workflow (5AE), not a conditional-coverage correction (5AF), not an
adaptive-validity framework (5AG), and not assumption checking (the
sibling plan). It is the comparative half of the model-criticism layer
those plans assume exists, with the honesty machinery attached at the
exit.

## 5. The selection-inclusive randomization test, and honest post-selection inference generally

The distinctive payoff, and the piece no sibling plan covers.
*(Ratified 2026-09-02, user decision, after working the mechanics in
conversation: pipeline composition, hard-gate default, mandatory
fallback, blinding commutation, and the battery-tranche execution-path
split below are decided, not open.)*

**The pipeline as a statistic.** A randomization test is valid under the
sharp null for **any** statistic — provided the identical procedure is
applied to every redrawn assignment. So wrap the entire criticism
pipeline as the test statistic:

```
T(w):  1. fit every (class x formula) cell in the grid
       2. run each cell's declared assumption battery
       3. QUALIFY: drop cells failing their gates       <- ModelDiagnostics
       4. RANK: tier-valid criteria over the survivors  <- ModelSelection
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

**The blinding-commutation result (the free lunch).** If selection is
fully treatment-blinded — criteria *and* gates computed from `(X, y)`
only — then under the sharp null (`y` invariant to `w`) every redraw
selects the *same* winner, so the selection-inclusive test **collapses
to the plain randomization test of the blindly-selected model**: exactly
valid, zero extra compute. The §2 blinding rule doesn't just prevent
effect-seeking; it *purchases* post-selection validity outright. For CI
inversion under the shift null `delta`, run blinded selection once per
`delta` on the de-treated responses `y - delta * w_obs` (a fixed vector
given `delta`), then invert the plain test per `delta` — cost is
(#deltas × one selection) + (#deltas × B single-model fits), not
(#deltas × B × whole-grid). Caveat to document: the test and interval
are valid, but the selected model's raw point estimate still carries
winner's-curse bias — report the inversion-centered interval as the
headline number.

**The battery-tranche split decides the execution path.** Covariate-side
checks (covariate PH, overdispersion, proportionality of covariate
effects, calibration of the `w`-omitted outcome model) are blindable;
treatment-side checks (the treatment coefficient's own PH, adequacy of
`~ . * w` interaction cells) inherently see `w` and are not. Each
declared check carries a `blindable` tag (sibling plan's contract); a
pipeline gated only on the blinded tranche keeps the free-lunch path,
and any gate from the unblinded tranche forces the full per-replicate
re-run. The dispatch is mechanical, not the user's job (below).

**Provenance, and inference that refuses to be naive.**
`ModelSelection$run_all_selection()` returns a provenance object: the
winner, the candidate universe, blinding mode, gate thresholds, pinned
seeds, and the pipeline as a replayable closure exposing
`as_randomization_statistic()`. Post-selection inference is then
constructed *from the provenance*:

```r
psi = InferencePostSelection$new(des_obj, selection = sel,
        method = c("auto", "rand_selection_inclusive",
                   "rand_conditional", "split", "simultaneous"))
```

`method = "auto"` inspects the provenance and picks the cheapest valid
path (blinded tranche only → plain randomization test of the winner;
otherwise → full selection-inclusive re-run). Because inference received
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

Remaining costs stated honestly: the unblinded path is pipeline-cost ×
replicates (mitigated by warm starts, the parallel layers, effort
tiers, and the existing sequential-MC early stopping); the BRT variant
inherits the open asymptotic-validity question recorded in
`inference_all_abstract_rand_bootstrap.R`. Whether this section ships
inside this plan or splits into its own
(`selection_inclusive_randomization_test.md`) remains a TODO-1
decision; its validity argument should also be recorded in
`InferenceRandBootstrap`'s roxygen neighborhood where the package's
other validity arguments live.

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

## 7. Architectural cost — why v2.0.0

Same class of cost as 5AE, plus its own: (i) `Design`-level fold/split
support shared with sample splitting — a post-hoc row filter can break a
matching-on-the-fly design's own within-fold structure, so folds need
design cooperation, not subsetting; (ii) a genuinely new public workflow
object with a large criteria surface rolled out per tier across the
registry; (iii) treatment-blinding infrastructure that must provably
keep `w` out of the criteria path; (iv) the selection-inclusive
randomization wrapper touching the hot resampling loops. None of this is
an additive v1.x patch over `results_table`.

## Tests

- Tier gating: a `quasi`-tier cell exposes QIC and never AIC; cross-tier
  AIC comparison is a typed refusal.
- Fold integrity: under a KK design, no fold separates a matched pair;
  under cluster designs, no fold splits a cluster.
- Gate wiring: a cell flagged by the sibling plan's battery carries its
  gate flag in the selection table, with TODO-1(e) semantics (hard gate
  vs. flag) honored.
- Blinding: with `blind = "omit_w"`, every criterion is invariant to
  permuting `w`; with `"mask_w"`, no output object contains the
  treatment coefficient.
- Selection-inclusive randomization test: simulated Type-I error at
  nominal level under the sharp null with aggressive diagnostics-gated
  selection over a wide grid (the whole point — verify the level
  survives selection); reproducibility across `num_cores`.
- Failure isolation: one pathological (class × formula) cell yields a
  typed status, never an aborted panel.

## TODOs

- [ ] TODO-1: **Decision gate (ask the user, no code).** (a) Standalone
  object vs. a verb on `InferenceSuite`; (b) `blind` default (`"omit_w"`
  proposed, shared with the sibling) and whether `"none"` requires an
  explicit acknowledgment argument; (c) ratify §3's tier-gated criteria
  table; (d) default formula grid; (e) ~~assumption-gate semantics (hard
  gate vs. flag)~~ **decided (2026-09-02, user): hard gate is the
  default, penalty-flag ranking is the offered option; gates are
  pre-specified constants in the sibling's typed check contract; the
  candidate universe must include an assumption-light
  (`likelihood_tier = "none"`) fallback class so the qualified set is
  non-empty by construction — see §5**; (f) does §5 split into its own
  plan file; (g) confirm v2.0.0 slating against 5AE's timeline since
  they share substrate.
- [ ] TODO-2: **Comparative-criteria layer**, tier-gated and
  registry-driven: log-lik/AIC/BIC extraction where
  `likelihood_tier = "full"`, QIC for `"quasi"`, partial-likelihood AIC
  + C-index for `"partial"`, scoring rules for all tiers; per-cell typed
  statuses; gate wiring per TODO-1(e).
- [ ] TODO-3: **Design-respecting fold machinery** over
  `resolve_resampling_unit()` units — built once, shared with
  `sample_splitting_model_selection.md → TODO-2` (coordinate; whichever
  plan lands first owns the substrate, the other consumes it).
- [ ] TODO-4: **Formula-grid engine** with rank/collinearity guardrails
  and typed `rank_deficient` downgrades; spline entries; flexible-model
  entries deferred to `causal_forest_inference.md` coordination. (The
  sibling plan consumes this engine; if its pilots ship first per its
  TODO-1(e), it carries a minimal local grid until this lands.)
- [ ] TODO-5: **Blinding modes** with the §Tests invariance guarantees
  (shared implementation with the sibling plan).
- [ ] TODO-6: **Reporting**: selection table, criterion-profile and
  calibration plots, HTML report, and the §2 rule-2 handoff footer.
- [ ] TODO-7: **Selection-inclusive randomization statistic**: pipeline
  wrapper over the custom-randomization-statistic machinery, BRT
  variant, CI-inversion support, warm-start/parallel wiring, level
  simulations.
- [ ] TODO-8: **Documentation**: vignette with the pre-specification
  workflow as the front door, the §2 "one unsupported workflow"
  statement, roxygen, and a JSS-manuscript sentence when shipped (the
  paper's `InferenceSuite` section is the natural attachment point).

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
