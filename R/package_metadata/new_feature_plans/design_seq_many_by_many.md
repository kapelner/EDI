# New Design Family: Sequential Many-by-Many (`DesignSeqManyByMany`)

> **Depends on:** the v1.0.0 shallow design hierarchy
> (`../finished_features/fix_design_hierarchy.md` — every class below goes
> through `define_design_class()` and registers capability metadata) and the
> shipped sequential one-by-one family (`design_seq_one_by_one_abstract.R`),
> whose subject-ingestion machinery this family generalizes. Reuses
> `DesignFixedRerandomization`'s objective/acceptance machinery and the
> `atkinson_assign_weight_cpp()` kernel as shipped — no rewrite of either is
> in scope. **Release scope: v1.1.0** (user decision, 2026-08-17) — see
> `../future_release_plans/release_v1_1_0.md → TODO-15` and `_master.md`
> Phase 5F. Everything here is additive on the frozen 1.0.0 substrate.

Date: 2026-08-17

## Purpose

EDI currently has two timing families:

1. **Fixed** (`DesignFixed*`): all `n` subjects' covariates are known before
   any assignment is made; the allocation is drawn (or searched for) in one
   shot.
2. **Sequential one-by-one** (`DesignSeqOneByOne*`): subjects arrive singly;
   each is assigned on arrival via `add_one_subject_to_experiment_and_assign()`
   before the next arrives.

Real enrollment is very often in between: subjects arrive in **batches of
possibly varying sizes** — a week's accrual, a clinic day, a shipped cohort —
and the whole batch must be assigned at once, but future batches' covariates
are unknown. Neither existing family serves this: fixed designs need all of
`X` up front, and forcing a batch through a one-by-one design throws away the
within-batch covariate information that is already in hand when the batch's
first subject is assigned (each within-batch assignment could have conditioned
on all batchmates' covariates, not just the earlier ones').

This plan adds the third timing family: **`DesignSeqManyByMany`** — blocks
(batches) of subjects of possibly varying sizes are randomized one block after
another until all `n` subjects are assigned. It contains the two existing
families as limiting cases (every block of size 1 → one-by-one; a single
block of size `n` → fixed), which supplies free correctness checks
throughout.

Terminology note: this plan says **block** for a batch of simultaneously
arriving subjects (matching the user-facing class names), and **stratum**
for the covariate-defined groups in the permuted-block/blocking-structure
sense used by `BlockingStructure` components. Both senses genuinely appear
in this family (the `Blocking` member below stratifies within each arriving
block), so the roxygen for every class must draw this distinction
explicitly.

## Architecture

### The abstract class

`DesignSeqManyByMany` (new file `design_seq_one_by_one_abstract.R` sibling:
`design_seq_many_by_many_abstract.R`), inheriting `Design` directly — a
sibling of `DesignSeqOneByOne`, **not** a subclass of it (the one-by-one
contract "you can only add one subject at a time" is exactly what this family
relaxes; inheriting it would mean overriding its central assertion, which the
shallow-hierarchy rules forbid in spirit). Public API, mirroring the
one-by-one abstract's shape:

- `add_many_subjects(X_new, allow_new_cols = TRUE)` — ingest a block: a
  data frame of `n_b >= 1` rows. Reuses the one-by-one abstract's ingestion
  semantics **verbatim** (column reconciliation with NA-padding under
  `allow_new_cols`, data-type drift warnings, ordered-factor/Date rejection,
  the no-continuous-strata-in-sequential rule, imputation + model-matrix
  refresh once `t > p + 2`). That logic currently lives inline in
  `DesignSeqOneByOne$add_one_subject()`; extract it into a shared private
  helper on `Design` (or a shared utility) that both abstracts call, rather
  than copying ~100 lines — see TODO-2. Appends to `private$Xraw`, advances
  `private$t` by `n_b`, and records the block: `private$block_boundaries`
  (integer vector of cumulative block-end indices) so every subject's block
  id is recoverable.
- `add_many_subjects_to_experiment_and_assign(X_new)` — ingest + assign;
  returns the length-`n_b` vector of assignments `{0,1}`, stored into
  `private$w` at the block's positions.
- `assign_wts(n_b)` — abstract (`stop("Must be implemented by subclass.")`);
  returns the block's assignment vector given everything observed so far
  (all previous blocks' covariates and frozen assignments, plus the current
  block's covariates, already ingested).
- `print_current_block_assignment()` — the analogue of
  `print_current_subject_assignment()`.
- One-by-one convenience: `add_one_subject_to_experiment_and_assign(x_new)`
  delegates to the block path with `n_b = 1`, so a many-by-many design can be
  driven by existing one-subject-at-a-time calling code unchanged.

Private, mirroring the one-by-one abstract:

- `draw_ws_raw(r)` — the randomization-inference replay: re-draw the
  assignment law **block by block**, holding the realized covariate arrival
  sequence and block sizes fixed (blocks are the unit of conditioning: block
  `b`'s re-draw conditions on the re-drawn assignments of blocks `1..b-1`
  and the realized covariates of blocks `1..b`). Default implementation loops
  `assign_wts()` over the recorded `block_boundaries`, exactly as the
  one-by-one default loops `assign_wt()`; subclasses with vectorized kernels
  override it (Atkinson does today).
- Block-aware bootstrap: `draw_bootstrap_indices()` resampling subjects
  i.i.d. by default; whether a block-stratified bootstrap variant is wanted
  (resample within blocks, preserving block sizes) is TODO-1's second
  decision — blocks are an enrollment artifact, not strata, so i.i.d. is the
  expected answer, but record it.

### Concrete classes (the canonical set)

Ordered easiest-first; each contains its one-by-one sibling at block size 1.

1. **`DesignSeqManyByManyBernoulli`** — every subject in every block gets an
   i.i.d. `Bernoulli(prob_T)` coin. The degenerate baseline (block structure
   irrelevant); exists for the same reason `DesignSeqOneByOneBernoulli`
   does: the null model every other member is compared against, and the
   smoke-test class for the abstract's plumbing.

2. **`DesignSeqManyByManyCRD`** — complete randomization within each block:
   exactly `n_T,b = round(n_b * prob_T)` treated per block, in uniformly
   random order (the fixed-`DesignFixed` balanced draw applied per block).
   This is the many-by-many analogue of permuted-block randomization with
   the block sizes dictated by arrival rather than drawn — guarantees
   cumulative imbalance never exceeds one block's rounding. Validation rule
   from `DesignSeqOneByOneRandomBlockSize` applies per block: `n_b * prob_T`
   need not be integral (arrival sizes aren't chosen by us), so use
   `round()` and document the resulting ±1 imbalance rather than erroring.

3. **`DesignSeqManyByManyBlocking`** — the analogue of
   `DesignFixedBlocking` (added 2026-08-18, user request): within each
   arriving block, partition that block's subjects into covariate strata and
   run complete randomization **independently within each stratum × block
   cell** (`round(prob_T * cell_size)` treated per cell). Reuse the shared
   stratum-key machinery (`get_strata_keys()` / the `BlockingStructure`
   component) rather than reimplementing key construction — but under the
   sequential family's standing restriction: `strata_cols` must already be
   factors (the one-by-one abstract's no-continuous-strata rule applies
   verbatim, and for the same reason — quantile bins cannot be determined
   stably on-the-fly, so `preferred_num_bins_for_continuous_covariate` and
   the `B_target` greedy-cap contract from the fixed class do **not** carry
   over; document the narrowing explicitly). Small cells are the live design
   question: a stratum with 1 subject in this arriving block degenerates to
   a Bernoulli coin, so offer an optional **cross-block carry-over** mode —
   maintain a per-stratum permuted-block queue that persists across arriving
   blocks (exactly `DesignSeqOneByOneRandomBlockSize`'s
   `strata_states` mechanism, with the block size dictated by arrival
   rather than drawn), restoring within-stratum balance over time at the
   cost of a more complex replay. Default off (pure within-cell CRD) vs. on
   is TODO-1 decision (iv). Bootstrap: within-strata via the
   `SequentialStrataBootstrap` component, as the one-by-one blocked
   siblings do. This is the one member with `blocking_capable = TRUE` —
   both senses of "block" are in play here, so its roxygen carries the
   heaviest version of the family's terminology note.

4. **`DesignSeqManyByManyRerandomization`** — **the canonical many-by-many
   design** (Zhou, Ernst, Morgan, Hu & Hu, 2018, *PNAS* 115(37), "Sequential
   rerandomization"; the required rerandomization member). For block `b`,
   draw candidate within-block allocations from the base law (the CRD
   per-block draw above), and accept a candidate iff the **cumulative**
   covariate-imbalance objective `M(w_{1:b})` — computed over all subjects
   assigned so far, with blocks `1..b-1`'s assignments frozen at their
   realized values — falls in the acceptance region. Mirror
   `DesignFixedRerandomization`'s user API exactly: `objective ∈
   {"mahal_dist", "abs_sum_diff"}`, mutually exclusive `obj_val_cutoff` /
   `prop_acceptable` modes (per block: `prop_acceptable` draws
   `ceiling(1/prop_acceptable)` candidates for the block and keeps the
   best), same `S`-ridge fallback, same "couldn't find an acceptable draw
   within budget → error naming the count" semantics (no unbounded R
   `repeat` loop — learn from the fixed class's documented fallback hazard).
   Zhou et al. additionally schedule per-stage acceptance thresholds
   (tightening as `t` grows, since later blocks move the cumulative mean
   less); expose that as an optional user hook (`obj_val_cutoff` may be a
   function of `(b, t, n)`) but default to the constant-threshold behavior
   that matches the fixed class — TODO-1 records this as decided-by-default
   unless the user objects.

5. **`DesignSeqManyByManyAtkinson`** — **the required Atkinson-type member**:
   Atkinson's (1982) `D_A`-optimum biased coin generalized to blocks. Two
   candidate rules; TODO-1's first decision picks one (recommendation
   below):
   - **(a) Within-block sequential coin (recommended).** Assign the block's
     subjects one at a time *internally*, each via the shipped one-by-one
     rule — `atkinson_assign_weight_cpp()` on the cumulative
     `Z = [w, 1, X]` including the within-block assignments made so far —
     but (the improvement over just calling the one-by-one class `n_b`
     times) with the **entire block's covariates already ingested**, so the
     model matrix, imputation, and rank bookkeeping see all batchmates. At
     `n_b = 1` this reduces *exactly* to `DesignSeqOneByOneAtkinson`
     (regression test for free), it inherits the one-by-one class's
     early-trial/numerical-failure fallback to `Bernoulli(prob_T)`
     unchanged, and it reuses the shipped kernel with zero C++ work.
   - **(b) Block-level `D_A`-optimal biased draw.** Enumerate/search
     candidate block allocations `w_b`, and draw among them with
     probabilities proportional to Atkinson's directional-derivative
     weights of the resulting cumulative information matrix (the
     block-trials extension in the sequential-construction spirit of
     Atkinson's optimum-design work, e.g. Atkinson 1999, "Optimum
     biased-coin designs for sequential treatment allocation with
     covariates"; also Atkinson & Biswas 2014, *Randomised Response-Adaptive
     Designs in Clinical Trials*, Ch. 6–7). Statistically tighter for large
     `n_b`, but needs a new C++ kernel (candidate search + per-candidate
     determinant updates) and a new derivation to check.
   - Recommendation: ship **(a)** in this plan; record **(b)** as a named
     follow-up in this file, gated on demand, since (a)'s within-block
     sequential coin is the standard practical reading of "Atkinson for
     staggered cohorts" and its randomization-replay (`draw_ws_raw`) can
     reuse `generate_permutations_atkinson_cpp()`'s structure with the
     block-frozen conditioning added.

Explicit non-goals (record here so nobody scopes them in silently): a KK
matching-on-the-fly many-by-many (`KK14`/`KK21` batch variants — genuinely
open research, out of scope); Pocock–Simon batch minimization (canonical in
trials but its many-by-many form needs a within-batch processing-order
convention — a natural *second wave* member once the family ships, listed as
a follow-up, not a TODO); multi-arm variants (ride
`multi_arm_designs.md`'s machinery when that track lands, not before).

### What the inference side must know

No new inference classes. The design capability metadata must answer
correctly for the new family (registry wiring in TODO-3):
`sequential = TRUE`-style timing metadata (whatever key the registry settled
on for the one-by-one family — copy its registration, not its spirit),
`uses_covariates` per class (FALSE for Bernoulli/CRD, TRUE for
Blocking/Rerandomization/Atkinson), `blocking_capable = FALSE` for every
member **except** `DesignSeqManyByManyBlocking` (arrival blocks are not
blocking strata — see the terminology note; only the Blocking member's
covariate strata are), and randomization-CI support via
each class's `draw_ws_raw`. The `InferenceSuite$inspect()` discovery grid
(shipping in v1.0.0) is metadata-driven and should pick the new classes up
without changes — TODO-8 verifies that instead of assuming it.

## TODOs

- [ ] TODO-1: **Decision batch** (ask the user, no code): (i) Atkinson rule
  (a) within-block sequential coin vs. (b) block-level `D_A`-optimal draw —
  recommendation: (a), with (b) as a named follow-up; (ii) bootstrap:
  i.i.d.-over-subjects (recommended) vs. block-stratified;
  (iii) rerandomization threshold schedule: constant (recommended,
  matches `DesignFixedRerandomization`) vs. Zhou-et-al-style tightening
  exposed as a function-valued `obj_val_cutoff`; (iv) the Blocking
  member's cross-block per-stratum carry-over queues: off by default
  (pure within-cell CRD, recommended) vs. on. Record all four here.
- [ ] TODO-2: **Shared ingestion extraction**: lift
  `DesignSeqOneByOne$add_one_subject()`'s column-reconciliation/type-drift/
  imputation logic into a private multi-row-capable helper both abstracts
  call; `add_one_subject()` becomes the `n_b = 1` special case. Golden test
  first: the one-by-one family's ingestion behavior must be bit-identical
  before/after (this touches a frozen-1.0.0 code path — the extraction must
  be behavior-preserving, verified, not assumed).
- [ ] TODO-3: **Abstract class + registry wiring**: `DesignSeqManyByMany`
  via `define_design_class()` with the API above (including the
  `block_boundaries` record, the default block-replay `draw_ws_raw`, and
  the `n_b = 1` one-by-one convenience delegate); capability metadata
  registered per "What the inference side must know"; roxygen with the
  block-vs-blocking terminology note.
- [ ] TODO-4: **`DesignSeqManyByManyBernoulli` + `...CRD`**: the two
  covariate-free members, each with construction/assignment/replay tests,
  including the two limiting-case identities (all-size-1 blocks ≡ the
  one-by-one sibling's law; one size-`n` block ≡ the fixed sibling's law —
  seed-matched where the draw order allows, distributional otherwise).
- [ ] TODO-4b: **`DesignSeqManyByManyBlocking`**: per-arriving-block
  covariate stratification + within-cell complete randomization per the
  class description (factor-only `strata_cols`, shared `get_strata_keys()`
  reuse, `BlockingStructure` + `SequentialStrataBootstrap` components,
  carry-over queues per TODO-1(iv)). Tests: within-cell balance; stratum-key
  stability across arriving blocks; the singleton-cell degeneracy path; the
  one-block limiting case against `DesignFixedBlocking` (restricted to the
  factor-strata overlap of the two APIs); with carry-over on, the all-size-1
  limiting case against `DesignSeqOneByOneRandomBlockSize`'s per-stratum
  queue behavior.
- [ ] TODO-5: **`DesignSeqManyByManyRerandomization`**: per-block
  rejection/quantile acceptance on the cumulative objective, mirroring
  `DesignFixedRerandomization`'s API and error semantics; pure-R first, and
  only add a C++ kernel if profiling shows the per-block candidate loop
  matters at realistic `n_b` (if added, it follows the SEXP/RcppEigen
  conventions and the unity-build group membership rule). Tests: acceptance
  region actually truncates the law (accepted draws' `M` ≤ cutoff);
  cumulative-conditioning correctness (earlier blocks' realized `w` enter
  `M` but are never re-drawn within a block's acceptance loop); the
  one-block limiting case against `DesignFixedRerandomization`.
- [ ] TODO-6: **`DesignSeqManyByManyAtkinson`** per TODO-1(i)'s decision:
  under (a), within-block sequential application of
  `atkinson_assign_weight_cpp()` with full-block ingestion, the
  early-trial/failure Bernoulli fallback inherited unchanged, and a
  `draw_ws_raw` replay that conditions on block boundaries (extend or wrap
  `generate_permutations_atkinson_cpp()`; if the kernel grows a
  block-boundary argument, existing one-by-one callers pass the degenerate
  all-boundaries case and their outputs must be bit-identical). Regression
  test: `n_b ≡ 1` reproduces `DesignSeqOneByOneAtkinson` seed-for-seed.
- [ ] TODO-7: **Randomization/bootstrap inference pass**: run the standard
  design-class inference test battery (randomization CIs via `draw_ws_raw`,
  bootstrap per TODO-1(ii) — within-strata for the Blocking member) over
  all five classes × a covariate/response grid; confirm Fisherian tests keep nominal size under the block-truncated
  laws (the rerandomization class's acceptance region is the one that can
  silently break this — test it, don't argue it).
- [ ] TODO-8: **Discovery/`inspect()` verification**: confirm
  `InferenceSuite$inspect()` and the design-side discovery API enumerate
  the new classes correctly from metadata alone; fix metadata (not
  discovery) if they don't.
- [ ] TODO-9: **Docs + API bookkeeping**: full roxygen for all six classes
  (references: Atkinson 1982 `\doi{10.1093/biomet/69.1.61}`; Zhou, Ernst,
  Morgan, Hu & Hu 2018 `\doi{10.1073/pnas.1808191115}`; Morgan & Rubin 2012
  for the acceptance-region inference validity; for the Blocking member,
  Fisher 1935 / Cochran & Cox 1957 mirroring `DesignFixedBlocking`'s refs
  **plus** the sequential-stratification lineage — Zelen 1974
  `\doi{10.1016/0021-9681(74)90015-0}` (stratified randomization of
  sequentially arriving patients, the closest published ancestor of this
  member), Matts & Lachin 1988 `\doi{10.1016/0197-2456(88)90047-5}`
  (properties of permuted-block randomization within strata), and Kernan
  et al. 1999 `\doi{10.1016/S0895-4356(98)00138-3}` (review); no single
  paper publishes the per-arriving-batch form itself — it is a batch-wise
  composition of these, and the roxygen should say so rather than
  invent an attribution), examples in the house
  one-liner style, `NAMESPACE`/Rd via the standing roxygenize discipline
  (no interim roxygenize mid-batch), and the `package_tests` inventories
  (`public_api_inventory.csv`, `checkmate_argument_contracts.csv`) extended
  for the new public surface.
- [ ] TODO-10: **Follow-ups recorded, not implemented**: Atkinson rule (b)
  block-level `D_A`-optimal kernel; Pocock–Simon batch minimization
  (`DesignSeqManyByManyPocockSimon`); function-valued threshold schedules
  if TODO-1(iii) chose constant; multi-arm variants riding
  `multi_arm_designs.md`. Each stays a bullet here until someone asks.
