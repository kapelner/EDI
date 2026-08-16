# DesignFixedOptimal: A Deterministic Single-Allocation Optimal Design

> **Depends on:** `fix_design_hierarchy.md` — specifically the completed
> `DesignFixedGreedyDOptimal` Stage 1 (this class reuses its
> `objective`/`interest`/`prior_precision` machinery verbatim for the
> closed-form objectives) and, from the Observational Design Migration
> section, **TODO-52** (split `supports_resampling()` into
> `supports("randomization_draw")`/`supports("resampling_replay")` — the
> mechanism this class's draw-`FALSE`/replay-`TRUE` capability profile
> requires) and **TODO-53** (wire `supports("randomization_draw")` and
> migrate `ObservationalDesign` off its throwing stub — the pattern this
> class reuses rather than reinventing). Both are prerequisites, confirmed
> unimplemented as of 2026-08-16 (verified against the code: `ObservationalDesign
> $draw_ws_raw` still throws `stop()`, and `Design$capabilities()` derives no
> `"randomization_draw"`/`"resampling_replay"` capability anywhere). **Does NOT depend
> on `fix_design_hierarchy.md`'s Stage-2 shared greedy-swap engine** (user
> correction, 2026-08-16, verified against the code: that engine does not
> exist yet — `DesignFixedGreedy`'s `greedy_design_search_cpp` and
> `DesignFixedGreedyDOptimal`'s `d_optimal_search_cpp`/`a_optimal_search_cpp`
> are today three independent kernel implementations sharing only common
> infrastructure includes, `RcppEigen.h`/`RNG.h`; the extraction is an open
> `[ ]` item in that plan's Follow-Ups, not yet started). Even once it exists,
> this class deliberately does not use it: see "Optimization backends" below
> for why an engine purpose-built to produce a randomization *distribution*
> is the wrong tool for a single-allocation optimizer. Optional-package
> precedent: `DesignFixedOptimalBlocks` already carries
> `ompr`/`ompr.roi`/`ROI.plugin.glpk` in Suggests.
> **Release-scoped:** in the v1.0.0 batch per `release_v1_0_0.md` (amendment
> 12, user decision 2026-08-16) — it adds public API surface (class, registry
> enum value, XPtr calling convention) that must freeze at 1.0.0.
> (Global ordering: see `_master.md`.)

Date: 2026-08-16

## Purpose

A fixed-sample-size design that computes **exactly one** allocation `w*` — the
minimizer of a chosen covariate-imbalance or information objective over all
allocations with `n_T = round(n * prob_T)` treated subjects — by **numerical
optimization**, rather than drawing from a restricted-randomization
distribution the way `DesignFixedGreedy`/`DesignFixedGreedyDOptimal` do.

The output contract is therefore the mirror image of every other fixed design:

- `assign_w_to_all_subjects()` runs the optimizer once and installs `w*`.
- There is **no usable randomization distribution conditional on the
  observed data**: given `X`, there is exactly one `w*` up to the mirror
  coin (see "Labeling and the mirror coin" under Class mechanics — with
  `mirror_coin = TRUE` the distribution is a 2-atom sign-flip pair
  `{w*, 1 - w*}`, vacuous for any two-sided randomization statistic), so
  permutation-style randomization tests and randomization CIs are
  impossible, declared via capability metadata
  (`supports("randomization_draw") = FALSE`), not a throwing stub, per
  `fix_design_hierarchy.md`'s Observational Design Migration pattern.
- **BRT (bootstrap-randomization) inference IS possible** (user correction,
  2026-08-16, replacing this plan's original blanket exclusion): each BRT
  replicate resamples the subjects, and the assignment mechanism — "optimize
  this dataset" — is *replayed on the resampled covariate matrix*, producing
  a different `w*_b` per replicate because `X*_b` differs. The reference
  distribution's stochasticity comes entirely from the bootstrap, with the
  deterministic mechanism applied faithfully to each resample — exactly what
  BRT means by "re-draw the assignment according to the design" when the
  design's draw is a deterministic function of the data. This is also the
  precise sense in which the class is *stronger* than `ObservationalDesign`
  (whose user-supplied `w` has no mechanism to replay on a resample):
  deterministic-but-replayable supports BRT; mechanism-free does not.
- Model-based inference (Wald/asymptotic, likelihood tests, nonparametric
  bootstrap, Bayesian bootstrap, jackknife — everything that resamples
  *subjects* or relies on a model rather than the assignment mechanism)
  remains valid and available, conditional on the usual model assumptions.
  This is the classical "optimal design + model-based analysis" stance; the
  class documentation must state the trade explicitly: you buy maximal
  balance/information for the realized sample at the price of all
  design-based (randomization) inference.

Naming note: the name `DesignFixedOptimal` was previously a candidate name for
the merged greedy class and was rejected in favor of
`DesignFixedGreedyDOptimal`; it is free, and fits here precisely because this
class actually *optimizes* (one answer) rather than greedily samples local
optima (a distribution of answers).

## Constructor API

Superset of `DesignFixedGreedyDOptimal`'s arguments (identical semantics where
shared) plus `DesignFixedGreedy`'s objectives plus the custom objective:

```r
DesignFixedOptimal$new(
  response_type,
  prob_T = 0.5,                    # n_T = round(n * prob_T), an equality
                                   #   constraint in every solver below
  objective = "D",                 # "D" | "A"           (from DesignFixedGreedyDOptimal)
                                   # "mahal_dist" | "abs_sum_diff"
                                   #                     (from DesignFixedGreedy)
                                   # "custom"            (new; see custom_objective)
  interest = "treatment",          # for objective = "D"/"A" only: "treatment" |
                                   #   "all" | one-sided formula | formula string |
                                   #   model-matrix column names (identical
                                   #   semantics, promotion rules, and
                                   #   interaction/design_formula constraint as
                                   #   DesignFixedGreedyDOptimal; contrast
                                   #   matrices arrive with that class's Stage 2)
  prior_precision = NULL,          # Bayesian D_B/A_B variants, identical to
                                   #   DesignFixedGreedyDOptimal (scalar tau
                                   #   penalizes covariates only; matrix R0 used
                                   #   verbatim)
  standardize_covariates = TRUE,   # honored when prior_precision is a scalar
                                   #   (and by "mahal_dist"/"abs_sum_diff",
                                   #   which standardize per DesignFixedGreedy's
                                   #   existing objective definitions)
  custom_objective = NULL,         # objective = "custom" only: an Rcpp::XPtr to
                                   #   a compiled C++ function ONLY -- no plain
                                   #   R function accepted (see below: an R
                                   #   closure is too slow inside the annealing
                                   #   loop, not merely inconvenient)
                                   #     double f(const Eigen::MatrixXd& X,
                                   #              const Eigen::VectorXd& w)
                                   #   (X = the design's model matrix, w = a
                                   #   candidate 0/1 allocation); see below
  solver = "auto",                 # "auto" | "ompr" | "annealing"; per-objective
                                   #   resolution table below
  solver_args = list(),            # e.g. list(time_limit_sec =, mip_gap =,
                                   #   roi_solver = "glpk",  # closed set:
                                   #     "glpk" (default) | "gurobi" | "cplex"
                                   #   linearization_max_n =,
                                   #   max_dinkelbach_iter =, n_chains =,
                                   #   max_iter =, initial_temp =,
                                   #   cooling_rate =)
  include_is_missing_as_a_new_feature = TRUE,
  n = NULL,
  verbose = FALSE,
  missingness_method = "impute",
  design_formula = ~ .,
  mirror_coin = TRUE,              # flip a fair (seeded) coin between w* and
                                   #   its mirror 1 - w* after every solve,
                                   #   whenever the mirror is a *verified*
                                   #   co-optimum -- only possible when
                                   #   prob_T = 0.5 (see "Labeling and the
                                   #   mirror coin" below); applies to
                                   #   assign_w_to_all_subjects(),
                                   #   draw_ws_according_to_design(r = 1),
                                   #   and each BRT replicate
  seed = NULL                      # consumed by the "annealing" solver and by
                                   #   the mirror coin (MILP solves via "ompr"
                                   #   are deterministic up to the seeded
                                   #   label flip)
)
```

All validation is **always-on** (never assert-gated), matching
`DesignFixedGreedyDOptimal`: `objective` from the closed set;
`interest`/`prior_precision` only meaningful for `"D"`/`"A"` (error otherwise);
`custom_objective` required iff `objective = "custom"` and must be an
externalptr; `solver` from the closed set.

### The custom objective

Follow the package's existing compiled-function-pointer precedent — the
`compiled_cpp_stat_fn` XPtr mechanism the custom-randomization-statistic
machinery already uses — rather than inventing a new calling convention:

- Typedef in a small public header (**landed as `EDI/src/user_compiled_fns.h`**,
  `EDI_CORE_ONLY`-clean — renamed from the originally planned
  `custom_objective.h` because it now carries the package-wide calling
  conventions for all user compiled C++, shared with the custom
  randomization statistic's XPtr form; see TODO-7's resolution):
  `typedef double (*edi_design_objective_fn)(const Eigen::MatrixXd& X, const Eigen::VectorXd& w);`
- Users produce the XPtr with `RcppXPtrUtils::cppXPtr()` (documented example
  in the class roxygen), or any mechanism yielding
  `Rcpp::XPtr<edi_design_objective_fn>`; a C++ **source string** is also
  accepted and compiled through the same `cppXPtr` mechanism (uniformity
  decision, 2026-08-17), with the source retained so parallel workers can
  recompile locally instead of dereferencing a dead serialized pointer.
- The optimizer treats it as a black box: **no gradient, no structure** — so
  it is only ever paired with the `"annealing"` solver (see table).
- **XPtr-only; no plain-R-function fallback (user decision, 2026-08-16,
  closing TODO-2).** `custom_objective` accepts a compiled `Rcpp::XPtr` and
  nothing else. Reasoning, to be stated explicitly in the shipped roxygen
  (not left implicit): the annealing solver evaluates the objective **once
  per candidate swap**, typically thousands of times per chain across
  `n_chains` chains, and again per BRT replicate (`B` times) if a custom
  objective is used under BRT. An R closure evaluated from the C++ annealing
  loop would mean an R-call round-trip on every one of those evaluations —
  orders of magnitude slower than the compiled XPtr path, and slow enough to
  make annealing impractical at realistic `n`/`n_chains`/iteration counts.
  Since `"custom"` is *always* solved by annealing (never `"ompr"` — no
  structure to linearize), there is no lower-frequency code path where an R
  closure would be merely inconvenient rather than actually prohibitive; the
  restriction is a hard performance requirement of this class's only
  execution path for `"custom"`, not a convenience trade-off to soften later.
  State this in `@param custom_objective`'s roxygen directly (see TODO-11).

## Optimization backends — what `ompr` can and cannot certify

`ompr` (+ `ompr.roi`/`ROI.plugin.glpk`, already Suggests via
`DesignFixedOptimalBlocks`) is a MILP modeling layer over GLPK. GLPK proves
**global** optimality for linear (and linearized) integer programs; it does
not handle quadratic objectives natively. The honest per-objective picture:

| `objective` | Structure in `w` | `"ompr"` solver | `"annealing"` solver |
|---|---|---|---|
| `"abs_sum_diff"` | linear (after standard abs-value linearization) | **exact global optimum**: minimize `sum_j t_j` s.t. `t_j >= ±(X_std'(2w-1))_j / n`, `sum w_i = n_T`, `w` binary. Pure MILP, GLPK-native. | available, not needed |
| `"mahal_dist"`, `"D"` (incl. Bayesian) | quadratic `w'Qw` (PSD `Q`: the Mahalanobis kernel, or `P`/`P_B`) | **exact** via **product linearization**: `y_ij = w_i w_j` with `y_ij >= w_i + w_j - 1`, `y_ij <= w_i`, `y_ij <= w_j`; objective `sum_i Q_ii w_i + 2 sum_{i<j} Q_ij y_ij`. Adds `n(n-1)/2` auxiliaries — practical only up to a benchmark-determined `linearization_max_n` (default TBD in TODO-5). | fallback above `linearization_max_n` |
| `"A"` (incl. Bayesian, subset) | fractional-quadratic `(w'Hw + 1)/(n_T - w'Pw)` | **exact** via **Dinkelbach's algorithm** (revised 2026-08-16, see below): each outer iteration is an ordinary product-linearized MILP subproblem in `Q = H + t_k P` (same technique as the row above, `H`/`H_S`/`H_B` substituted per `interest`/Bayesian setting), terminating in finitely many iterations since the finite feasible set admits only finitely many distinct ratio values. Same `linearization_max_n` cutoff per subproblem, plus `max_dinkelbach_iter`. | fallback once either cutoff is hit |
| `"custom"` | black box | not expressible | only option |

`solver = "auto"` resolves to: `"ompr"` for `"abs_sum_diff"` always, and for
`"mahal_dist"`/`"D"`/`"A"` while `n` stays within `linearization_max_n` (for
`"A"`, per Dinkelbach subproblem) and, for `"A"`, `max_dinkelbach_iter` is not
exhausted; `"annealing"` otherwise. `"custom"` always uses `"annealing"`.

**Design rule (stated explicitly, confirmed 2026-08-16): `"ompr"` strictly
dominates `"annealing"` wherever it is tractable** — a certified global
optimum beats an uncertified asymptotic-only one on the only axis that
matters — so `"auto"` never chooses `"annealing"` for the observed-data solve
in a region `"ompr"` can reach. `"annealing"` is the fallback for the
complementary region only (past the size/iteration cutoff, or `"custom"`'s
black box), never a head-to-head alternative within `"ompr"`'s reach. The one
deliberate exception is the BRT replicate path (see below), which defaults
to `"annealing"` even within `"ompr"`'s tractable region purely because of
the `B`-times cost multiplier, not because annealing wins on quality there.

### Exact `"A"`-optimality via Dinkelbach's algorithm (revised 2026-08-16)

An earlier draft of this table marked `"A"` as not MIP-expressible, reasoning
that Charnes-Cooper (the classical linearization for fractional *linear*
programs) does not extend to a fractional *quadratic* program. That is true
of Charnes-Cooper specifically, but a different technique applies: **Dinkelbach's
algorithm** (Dinkelbach, 1967; standard in fractional combinatorial
optimization since — see Radzik's survey for the discrete-domain theory) solves
`min_w g(w)/s(w)` by iterating a *parametric, non-fractional* subproblem
`F(t) = min_w [g(w) - t s(w)]` and updating `t_{k+1} = g(w_{k+1})/s(w_{k+1})`
until `F(t_k) ~= 0`. Substituting `g(w) = w'Hw + 1`, `s(w) = n_T - w'Pw`:

```
g(w) - t s(w) = w'(H + t P) w + (1 - t n_T)
```

Dropping the constant, each subproblem is `min_w w'(H + tP)w` subject to the
same `sum(w) = n_T` binary constraint — an ordinary (non-fractional) binary
quadratic program, identical in shape to the `"D"`/`"mahal_dist"` row and
solvable exactly by the same product-linearized MILP (the linearization trick
`y_ij = w_i w_j` is exact for binary `w` regardless of the matrix's
definiteness; `H + tP` is PSD throughout since `H`, `P` are both PSD and
`t = g(w)/s(w) >= 0` along the iteration, but this isn't even required for
correctness). Because the feasible set is finite, `t_k` takes only finitely
many distinct values, so **the outer loop provably terminates in finitely
many iterations** — a stronger guarantee than annealing's asymptotic-only
convergence, not a weaker one. The reduction only used `H`'s PSD-ness, so it
composes unchanged with the subset (`H_S`) and Bayesian (`H_B`) variants of
`"A"`.

Net effect: `"A"` (all variants) moves into `"ompr"`'s exact column,
narrowing `"annealing"`'s *necessary* role to `"custom"` (always) and any
objective past its size/iteration cutoff (fallback only). Termination in
finitely many iterations is not the same as *few* iterations — `solver_args$
max_dinkelbach_iter` bounds worst-case cost, with documented fallback
behavior (drop to `"annealing"` on the best `t_k` found, with the certificate
downgraded accordingly) if the cap is hit.

### The `"annealing"` solver is a dedicated formal method, not the greedy engine

**User correction, 2026-08-16:** an earlier draft of this plan proposed a
`"restarts"` solver that reused `fix_design_hierarchy.md`'s (not-yet-built)
shared greedy-swap engine, running many independent BCRD-started local
searches and keeping the best. That is the wrong tool for this class, for a
reason independent of whether the engine exists: that engine's search
accepts **only improving** swaps and halts at the **first** local optimum it
reaches, with no mechanism to escape it and no formal convergence guarantee
— it is purpose-built to generate a *distribution* of good-but-arbitrary
local optima for randomization inference (`DesignFixedGreedy`/
`DesignFixedGreedyDOptimal`'s actual job). This class needs the opposite: one
allocation, produced by a method with a defensible claim toward global
optimality.

**Necessary role, after the Dinkelbach revision above:** the `"custom"`
objective (always — no exploitable structure to linearize), and any of
`"D"`/`"mahal_dist"`/`"A"` once `n` (or, for `"A"`, `max_dinkelbach_iter`)
exceeds its exact-solve budget.

**Method: simulated annealing**, implemented as its own native C++ solver
(no dependency on the greedy engine, existing or future). Candidate moves are
single treated/control pairwise exchanges (the same neighborhood
*structure* the greedy engine uses, but not the same engine or acceptance
rule). At each step: a candidate move that improves the objective is always
accepted; a move that worsens the objective by `Δ` is accepted with
probability `exp(-Δ / T)` (the Metropolis criterion), where `T` decreases
according to `solver_args$cooling_rate` (e.g. geometric:
`T_{k+1} = alpha * T_k`). This is what makes it a *formal* method rather than
a heuristic dressed up with restarts: Hajek (1988) proves that simulated
annealing on a finite state space converges in probability to the global
optimum provided the temperature schedule decreases no faster than
`T_k = c / log(k)` for a problem-dependent constant `c`. A geometric schedule
is the standard practical relaxation of that guarantee — fast, but only
asymptotically justified, not literally convergent in finite time — so the
class documentation and `get_optimization_diagnostics()` must state which
regime `solver_args` selects, and `optimum_certificate` for this solver is
always `"annealing_converged"`, never `"global"`. `solver_args$n_chains`
(default modest, e.g. 4) runs independent annealing chains from independent
BCRD starts and keeps the best terminal state — a legitimate multi-start
refinement layered on top of a formal method, not a substitute for one (the
distinction from the rejected `"restarts"` design: here each *chain* has a
formal convergence property; there, no individual run did).

**Commercial ROI backends: supported, but scoped to exactly two, Gurobi and
CPLEX (user decision, 2026-08-16, resolving TODO-3; scope narrowed
2026-08-16: not "any ROI-registered solver," only these two — the two most
widely used commercial MILP/MIQP solvers, and the only ones worth the
documentation burden of a step-by-step guide for now).** Expose
`solver_args$roi_solver`, a **closed set** `c("glpk", "gurobi", "cplex")`
(default `"glpk"`) — validated against this set, not passed through to
`ROI::ROI_registered_solvers()` unchecked, so a typo or an unsupported
solver name fails fast with a clear message rather than an opaque `ompr`
error three layers down. Every `"ompr"`-path call (`"abs_sum_diff"`'s linear
MILP, `"mahal_dist"`/`"D"`'s linearized MILP, and each Dinkelbach subproblem
for `"A"`) passes it straight through:

```r
ompr.roi::with_ROI(solver = solver_args$roi_solver, verbose = FALSE)
```

**Why this benefits every `"ompr"`-solved row, not just the ones GLPK
can't reach:** Gurobi/CPLEX don't just extend which problems are
*expressible* — they extend which problems stay *practical*. GLPK's
branch-and-bound is single-threaded and has no commercial-grade
presolve/cutting-plane machinery; Gurobi/CPLEX are typically an order of
magnitude faster on the same MILP and solve in parallel, meaningfully
pushing out the benchmarked `linearization_max_n` and `max_dinkelbach_iter`
cutoffs before `"auto"` falls back to `"annealing"`.

**Wiring up Gurobi (must appear in the shipped roxygen as its own
step-by-step, not just this plan):**
1. Obtain a Gurobi license (a free academic license is available from
   Gurobi for non-commercial use) and install the Gurobi Optimizer itself.
   This sets up `GUROBI_HOME` and the license file
   (`gurobi.lic`, discoverable via the `GRB_LICENSE_FILE` environment
   variable or Gurobi's default search path) — entirely outside this
   package's control or dependency graph.
2. Install Gurobi's own R package. **Not available via CRAN** — it ships
   inside the Gurobi installation itself:
   `R CMD INSTALL "$GUROBI_HOME/R/gurobi_<version>_R_<Rmajor.minor>.tar.gz"`
   (exact filename/path depends on your Gurobi version and platform; see the
   `R/` subdirectory of your Gurobi install). This is the vendor interface
   `ROI.plugin.gurobi` wraps — required even though it's not what you call
   directly.
3. Install the ROI bridge package from CRAN:
   `install.packages("ROI.plugin.gurobi")`. This package **is** on CRAN (it
   only depends on `ROI` + the `gurobi` R package from step 2 being present
   at load time) and is the only new artifact this class's own dependency
   graph ever touches.
4. Verify: after `library(ROI.plugin.gurobi)`, `"gurobi" %in%
   ROI::ROI_registered_solvers()` should be `TRUE`.
5. Pass `solver_args = list(roi_solver = "gurobi")` to the constructor.

**Wiring up CPLEX (must appear in the shipped roxygen as its own
step-by-step, not just this plan):**
1. Obtain an IBM CPLEX license (a free academic license is available from
   IBM) and install IBM ILOG CPLEX Optimization Studio.
2. Install `Rcplex` (CRAN), CPLEX's R interface. Unlike `ROI.plugin.gurobi`,
   `Rcplex` is a **source package that compiles against your local CPLEX
   installation** — it needs to be pointed at your CPLEX SDK's include/lib
   directories at install time (typically via `configure.args` to
   `install.packages()`, naming your CPLEX version's
   `cplex/include`/`cplex/lib/<platform>` paths). The exact flag names and
   paths are CPLEX-version- and platform-specific — **follow `Rcplex`'s own
   `INSTALL`/README instructions for your installed CPLEX version rather
   than a fixed command copied from here**, since this changes across CPLEX
   releases and this plan should not assert a specific version's flags as if
   permanent.
3. Install the ROI bridge package from CRAN:
   `install.packages("ROI.plugin.cplex")` (depends on `Rcplex` from step 2
   being present and working).
4. Verify: after `library(ROI.plugin.cplex)`, `"cplex" %in%
   ROI::ROI_registered_solvers()` should be `TRUE`.
5. Pass `solver_args = list(roi_solver = "cplex")` to the constructor.

**Dependency-graph consequence:** `ROI.plugin.gurobi`/`ROI.plugin.cplex`
(and `Rcplex`) are **never added to `Suggests`** — they're free/CRAN-
available themselves, but declaring them would misrepresent the dependency
as something `install.packages("EDI", dependencies = TRUE)` could satisfy,
when the vendor package/license underneath cannot be. The lazy-check
pattern already used for `ompr`/`ompr.roi`/`ROI.plugin.glpk` extends
naturally: check `requireNamespace("ROI.plugin.gurobi"/"ROI.plugin.cplex")`
at solve time (not at package load or class-definition time) for whichever
`roi_solver` was requested, and error informatively — naming the missing
package and, if that's present but the solve still fails, noting the likely
cause is a missing vendor license/installation, not something this class
can diagnose further.

Scope is deliberately closed to these two for now — not because other ROI
plugins (CBC, SYMPHONY, ...) wouldn't work mechanically (the dispatch is
generic), but because Gurobi and CPLEX are the two most widely used
commercial solvers and the only ones worth a maintained step-by-step guide
at this point; extending the closed set is a small, low-risk addition later
if a real need for a third backend appears, not a reason to leave the set
open-ended now.

## Class mechanics

- `assign_w_to_all_subjects()`: runs the resolved solver once, installs `w*`,
  caches solver diagnostics (`objective_value`, `optimum_certificate`
  — `"global"` for `"ompr"`, `"annealing_converged"` for `"annealing"` —
  solver status/gap/time, and for `"annealing"` the realized `n_chains`,
  `max_iter`, and final temperature). A public accessor (e.g.
  `get_optimization_diagnostics()`) exposes them.
- `draw_ws_raw` is **absent as a randomization mechanism**: declared via
  capability metadata (`randomization_family` value below;
  `supports("randomization_draw") = FALSE`), following whatever final shape
  the Observational Design Migration lands (metadata query first, informative
  error preserved for unguarded callers). Whether
  `draw_ws_according_to_design(r = 1)` returns the single `w*` as a
  convenience or always errors is a gated decision (TODO-4) — returning
  `r > 1` copies of the same column is **forbidden** either way, since a
  constant matrix silently degenerates every randomization-inference
  consumer instead of stopping it.
- **Labeling and the mirror coin (user decision, 2026-08-16, replacing the
  earlier "labeling is solver-determined" note):** after every solve, if the
  mirror `1 - w*` is a **verified co-optimum**, flip a fair seeded coin
  between `w*` and `1 - w*` (`mirror_coin = TRUE`, the default). Applies
  uniformly to `assign_w_to_all_subjects()`, `draw_ws_according_to_design(
  r = 1)` (see TODO-4), and each BRT replicate's re-optimization.
  - **Verification, not taxonomy:** implement by evaluating the objective at
    `1 - w*` and flipping only on a tie within numerical tolerance — never by
    a hand-maintained per-objective symmetry table. The analytic picture,
    recorded here as documentation for the roxygen (not as code logic): at
    `prob_T = 0.5` the mirror is an exact co-optimum for `"mahal_dist"`,
    `"abs_sum_diff"`, `"D"` (via `P1 = 1`: `(1-w)'P(1-w) = w'Pw` at
    `n_T = n/2`), `"A"` with `interest = "treatment"` or a covariate-subset
    interest (`e1'S = 0` kills the intercept cross-terms in `H_S`), and the
    scalar-`tau` Bayesian variants (`R0 e1 = 0` preserves `P_B 1 = 1`). It is
    **not** a co-optimum for `"A"` with `interest = "all"` (the intercept is
    the control mean, so the labeling changes `var(a-hat)` — there the
    strictly better mirror wins deterministically and no coin is flipped,
    which the verification handles automatically), generally not for a
    matrix `R0` with a nonzero intercept row, not at `prob_T != 0.5` (the
    mirror changes `n_T` and is infeasible), and unknowable a priori for
    `"custom"` — all handled by the same evaluate-and-compare check. If the
    mirror evaluates *strictly better* than the solver's `w*`, that is a
    solver bug: assert/stop, don't silently adopt it.
  - **Why (rationale, condensed from the research doc
    `new_research_ideas/greedy_vs_optimal_design_brt_power.md`, "The Labeling
    Question" section):** a fixed solver-determined labeling makes the
    mean-difference estimator conditionally biased at the order of the
    unbalanced (nonlinear-residual) imbalance and leaves the BRT null with a
    labeling-determined sign asymmetry; no deterministic X-measurable
    tie-breaking rule can fix this, only exogenous randomness. The fair coin
    restores exact estimator unbiasedness and exact sign symmetry at zero
    cost to balance — it is the Harmonizing paper's mirror-pair construction.
  - **Capability fencing unchanged:** the coin induces at most a 2-atom
    sign-flip randomization distribution, which is vacuous for any two-sided
    randomization statistic (`|T(w*)| = |T(1 - w*)|`, p-value identically 1),
    so `supports("randomization_draw")` stays `FALSE` and the `r > 1` error
    stands.
  - `mirror_coin = FALSE` disables the flip (solver-determined labeling, the
    pre-decision behavior) — kept as an escape hatch and as the contrast arm
    the research doc's labeling study needs.

## Registry / capability integration (per the completed design hierarchy)

- Built via `define_design_class()`, `inherit = DesignFixed`,
  `direct_components = character()`, always-on validation, dynamically
  created private state — the same compatibility contract as
  `DesignFixedGreedyDOptimal`'s Stage 1.
- `randomization_family`: **new closed-enum value `"deterministic_optimal"`**
  (one value for the class, per the one-class-one-family rule; the
  objective/solver are object state). Update
  `EDI_DESIGN_ALLOWED_RANDOMIZATION_FAMILIES`,
  `EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME`, and the closed-enum tests.
- `seed_reproducible_draw = TRUE` (MILP path via `"ompr"` deterministic up to
  the seeded mirror coin; annealing path R-seeded, per-chain),
  `supports_batch_w_pregeneration = FALSE`,
  `required_packages = c("ompr", "ompr.roi", "ROI.plugin.glpk")` (needed only
  when the `"ompr"` solver is actually invoked — lazy check at solve time,
  like `DesignFixedOptimalBlocks`). **No new `Suggests` entry for the
  `"annealing"` solver** (question raised and settled 2026-08-16): it is a
  native C++ implementation (swap neighborhood + Metropolis acceptance +
  cooling schedule) using infrastructure the package already has
  (`edi_rng::RRng`/`RNG.h` for the seeded generator, RcppEigen for objective
  evaluation), matching every other local-search kernel in `EDI/src`. An
  R-package SA backend (`GenSA`, `optim(method = "SANN")`) was considered and
  rejected: it would call the objective from R once per candidate move,
  reintroducing exactly the per-candidate R-call bottleneck the
  `custom_objective` section above already rules out an R-closure fallback
  for, and it would be the only local-search kernel in the package not
  implemented natively.
- Inference fencing: randomization-test and randomization-CI capability
  checks exclude this family (via the capability read, not class-name
  checks), but — unlike `ObservationalDesign` — **BRT stays eligible**:
  the BRT draw path must route each replicate's assignment through a fresh
  optimization of the resampled worker design's covariates (the
  `generate_rand_bootstrap_draws()`/worker machinery calls the design's
  assignment mechanism per replicate; for this class that call *is*
  `assign_w_to_all_subjects()`-style optimization on `X*_b`). Wald/
  likelihood/nonparametric-bootstrap/Bayesian-bootstrap/jackknife paths
  remain eligible as before. Audit the same call-site list the Observational
  migration touches, keeping the BRT/permutation distinction explicit.
- **BRT cost and solver policy:** BRT pays one optimization per replicate
  (`B` solves). MILP-per-replicate can dominate runtime; default the BRT
  replicate path to the `"annealing"` solver with a reduced schedule
  (`solver_args$brt_max_iter` typically far fewer iterations than the
  observed-data solve, `solver_args$brt_n_chains = 1`) — the replicate
  assignments only need to be faithful applications of the mechanism, not
  individually re-verified to the same convergence standard as the observed
  `w*`. If the observed `w*` came from an exact `"ompr"` solve, document the
  resulting approximation gap, or allow `solver_args$brt_solver = "ompr"`
  for exact per-replicate solves at the user's expense.
- `SimulationFramework`: still usable — each Monte-Carlo replicate generates
  new covariates, so `w*` varies across replicates even though it is
  deterministic within one; the framework's valid-inference-types filter must
  pick up the missing randomization capability automatically via
  `.supports_inference_capability()`.

## Testing plan

1. **Exactness (MILP + Dinkelbach):** for small `n` (say `n <= 14`),
   brute-force all `choose(n, n_T)` allocations in R and assert the `"ompr"`
   solver returns the true global minimum for `"abs_sum_diff"`, `"mahal_dist"`/
   `"D"` (via linearization), and `"A"` (via Dinkelbach), each plain and
   Bayesian, and each `"A"` case's outer loop terminates within a small
   fixed iteration bound on these instances (report the observed count, not
   just pass/fail — a large count on tiny `n` would be a red flag worth
   investigating before trusting the reduction at scale).
2. **Annealing:** best-of-`n_chains` objective value `<=` the value of every
   individual chain; deterministic under `seed`; on the small brute-forceable
   instances from test 1, annealing finds the certified global optimum with
   high frequency across repeated trials (report and bound the miss rate, do
   not require zero misses — the method is asymptotic); `optimum_certificate`
   reported correctly for both solvers (`"global"` vs `"annealing_converged"`).
3. **Custom objective:** a test XPtr objective (e.g. re-implementing
   `abs_sum_diff` in C++) must reproduce the built-in objective's optimum;
   validation errors for `objective = "custom"` without an XPtr and vice
   versa.
4. **Quality baseline (not an equivalence claim):** annealing is a genuinely
   different algorithm from the greedy engine now, so there is no identity to
   test — instead assert annealing's objective value is no worse than the
   best of `n_chains` independent `DesignFixedGreedyDOptimal` greedy draws on
   the same data (a weak sanity floor: a formal method with restarts should
   not lose to blind greedy restarts on average across repeated trials). Run
   this specifically in annealing's now-narrower necessary zone (`"custom"`
   objectives, and `"D"`/`"mahal_dist"`/`"A"` forced past their exact-solve
   cutoffs) since that's the only regime where annealing is actually used by
   `"auto"`.
5. **Fencing:** randomization test/CI attempts fail with the informative
   capability error; Wald/bootstrap paths run; registry metadata assertions
   (family, seed flag, required packages).
6. **Solver fallback:** `"auto"` above `linearization_max_n` falls back to
   `"annealing"` with a message; `"ompr"` on `"A"`/`"custom"` errors
   informatively; missing Suggests packages error lazily at solve time only.
7. **BRT:** `compute_rand_bootstrap_two_sided_pval()` runs end-to-end;
   per-replicate `w*_b` genuinely varies across replicates **beyond mere
   mirroring** (with the mirror coin on, "not column-constant" is trivially
   satisfied by label flips alone — assert the columns are not all equal to
   a single `w*_b` *or its mirror*, i.e. variation modulo the sign flip);
   results deterministic under `seed`; replicate assignments verifiably come
   from re-optimizing the resampled covariates (spot-check one replicate:
   re-run the solver on that replicate's `X*_b` and match, modulo the coin).
8. **Mirror coin:** with `mirror_coin = TRUE` and a mirror-symmetric setting
   (`prob_T = 0.5`, e.g. `"mahal_dist"`), repeated seeded constructions
   return `w*` vs `1 - w*` at an empirical rate consistent with Bernoulli(1/2)
   and reproducibly under `seed`; the co-optimum verification actually gates
   the flip — for `"A"`/`interest = "all"` (not mirror-symmetric) the flip
   never fires and the returned labeling is the strictly better mirror;
   `mirror_coin = FALSE` returns the solver labeling deterministically; a
   mirror evaluating strictly better than the solver's `w*` triggers the
   solver-bug assertion.

## TODO Checklist

- [x] TODO-1: **Resolved (user decision, 2026-08-16): three classes.**
  `DesignFixedOptimal` stays a separate class from
  `DesignFixedGreedy`/`DesignFixedGreedyDOptimal`, not a `mode` flag on the
  latter. Rationale (see the plusses/minuses discussion this decision closed
  out): a `mode` flag would make `randomization_family`, `required_packages`,
  and the draw-shape contract instance-state-dependent, breaking the
  one-class-one-family invariant the completed design hierarchy is built on
  and reintroducing exactly the "capability flag and the state it gates can
  silently disagree" failure mode `fix_design_hierarchy.md` already
  documents as a bug class (Evidence of the Problem item 3).
- [x] TODO-1b: **Done (2026-08-16).** Extracted to `R/design_optimal_shared.R`
  (non-exported: `validate_optimal_design_objective_args()` with
  `allowed_objectives`/`objective_error_message` params,
  `resolve_optimal_interest_z0_columns()`, `build_optimal_design_P_H()`);
  `DesignFixedGreedyDOptimal`'s constructor validation and `draw_ws_raw` P/H
  construction rewired onto them and its private `resolve_interest_z0_columns`
  removed; `design_optimal_shared.R` added to `DESCRIPTION` Collate. Golden
  tests in `tests/testthat/test-design-optimal-shared-golden.R` pin every
  P/H construction variant (D, A/all, A/subset by names and formula, Bayesian
  scalar tau standardized/unstandardized, Bayesian matrix R0, Bayesian subset)
  bit-for-bit (`tolerance = 0`) against reference implementations, plus direct
  unit tests of both helpers; all pass post-rewire, as does the whole
  pre-existing `test-greedy-d-optimal-merged.R` suite. Original scope text
  follows for reference:
  Shared internal (non-exported) helper for the
  `objective`/`interest`/`prior_precision`/`standardize_covariates` argument
  definitions, validation, and `P`/`H`/`H_S`/`H_B` construction** (added
  2026-08-16, closing the one real cost of the three-class decision above:
  duplicated logic between `DesignFixedGreedyDOptimal` and
  `DesignFixedOptimal`). Scope, concrete because the source already exists to
  extract from: `DesignFixedGreedyDOptimal`'s shipped implementation
  (`R/design_fixed_greedy_d_optimal.R`) has `private$resolve_interest_z0_columns()`
  (interest -> `Z0` column-index resolution: `"treatment"`/`"all"`/formula/
  formula-string/column-names, identical promotion rules and
  interaction/`design_formula` constraint) plus inline QR-based `P`
  construction, ridge-regularized Bayesian `P_B` construction, and `H`/`H_S`/
  `H_B` construction from the resolved columns — all of this is exactly what
  `DesignFixedOptimal`'s `"D"`/`"A"` objectives need too, verbatim (its
  `"mahal_dist"`/`"abs_sum_diff"`/`"custom"` objectives don't touch `P`/`H`
  at all, so the helper's scope is precisely the `"D"`/`"A"` shared surface,
  not the whole class). Extract into a shared non-exported file (e.g.
  `R/design_optimal_shared.R`, sourced by both, collated before either in
  `DESCRIPTION`) exposing at minimum: an argument validator
  (`validate_optimal_design_objective_args(objective, interest,
  prior_precision, standardize_covariates, allowed_objectives)` — takes the
  caller's own closed `objective` set as a parameter, since the two classes'
  sets differ) and a matrix builder (`build_optimal_design_P_H(X, interest,
  prior_precision, standardize_covariates, need_H)`). Refactor
  `DesignFixedGreedyDOptimal` onto it (golden-tested: bit-identical `P`/`H`/
  allocations before/after) before or alongside implementing
  `DesignFixedOptimal`'s `"D"`/`"A"` path, not after — writing
  `DesignFixedOptimal` against a not-yet-extracted copy-paste would just
  create the duplication this item exists to avoid, then require a second
  pass to undo it.
- [x] TODO-2: **Resolved (user decision, 2026-08-16): XPtr-only, no plain-R-
  function fallback.** Reason: an R closure evaluated once per candidate swap
  inside the compiled annealing loop (thousands of times per chain, times
  `n_chains`, times `B` again under BRT) is orders of magnitude too slow to be
  a usable "convenience" option, not merely a slower one — so no fallback is
  offered at all. Document this reasoning directly in `@param
  custom_objective`'s roxygen (not just in this plan) — see TODO-11.
- [x] TODO-3: **Resolved (user decision, 2026-08-16): yes, support commercial
  ROI backends, scoped to exactly Gurobi and CPLEX (closed set, narrowed
  2026-08-16 — the two most widely used commercial solvers, not an
  open-ended "any ROI plugin" acceptor).** Implementation: `solver_args$
  roi_solver` validated against `c("glpk", "gurobi", "cplex")` (default
  `"glpk"`), passed through to every `ompr.roi::with_ROI(solver = ...)` call
  (see "Optimization backends" above for the full Gurobi and CPLEX
  step-by-step wiring guides, each of which must be reproduced verbatim in
  the shipped roxygen as its own subsection). No new `Suggests` entry — see
  "Appendix" below for the parallel finding and TODO for
  `DesignFixedOptimalBlocks`, which has the identical hardcoded-`"glpk"` gap.
- [x] TODO-4: **Resolved (forced by existing code, confirmed 2026-08-16;
  amended same day by the mirror-coin decision): `draw_ws_according_to_design(
  r = 1)` returns the mirror-coin draw** — `w*` or `1 - w*` by a fair seeded
  coin when the mirror is a verified co-optimum, only possible when
  `prob_T = 0.5` (at any other `prob_T` the mirror changes `n_T` and is
  infeasible; see "Labeling and the mirror coin" under Class mechanics), the
  single `w*` otherwise (no tie, or `mirror_coin = FALSE`). Verified
  `draw_ws_according_to_design()` is a genuine public `Design` method
  (`design_abstract.R:437`, documented, default `r = 1L`) — and, critically,
  the *existing* BRT worker machinery already calls it with a literal
  `r = 1L` per replicate (`inference_all_abstract_rand_bootstrap.R:561,566,
  609,775,904`: `des_obj$draw_ws_according_to_design(1L)[, 1L]`). Since
  `DesignFixedOptimal` must support BRT (see Purpose), and TODO-8b already
  routes BRT's per-replicate re-optimization through this exact call path,
  `r = 1` erroring is not a viable option — it would break BRT immediately or
  force a `DesignFixedOptimal`-specific bypass in shared inference code,
  exactly the class-identity special-casing this architecture eliminates.
  `r > 1` remains **forbidden** (errors), protected in practice by the
  `supports("randomization_draw") = FALSE` capability gate rejecting
  randomization-test/CI calls upstream, before `draw_ws_according_to_design`
  with `r > 1` is ever reached — the `r > 1` error in `draw_ws_raw` itself is
  defense-in-depth, not the primary fencing mechanism.
- [x] TODO-5: **Done (2026-08-16).** Implemented in
  `R/design_optimal_milp_solvers.R` (non-exported, in Collate):
  `milp_solve_l1(A, n_T, roi_solver)` (abs-value linearization, exact) and
  `milp_solve_quadratic(Q, n_T, roi_solver)` (product linearization
  `y_ij = w_i w_j`, exact for binary `w`, `y` continuous in `[0,1]`), plus
  `prepare_optimal_objective_matrices(X_raw, objective)` translating the
  greedy kernel's (`design_fixed_greedy.cpp`) `mahal_dist`/`abs_sum_diff`
  criteria into pure `w`-forms (column-centered `X` kills the cross terms:
  mahal `f = w'Qw` with `Q = 4 X S^-1 X'/n^2`; abs_sum `f = sum|A w|` with
  `A = (2/n) X_std'`), including the singular-covariance fallback to l1
  (guarded by `rcond(Sigma) < 1e-12` since R's `chol()` can numerically pass
  where Eigen's LLT fails). `roi_solver` threaded through every
  `ompr.roi::with_ROI()` call via `assert_optimal_roi_solver()` (closed set,
  fail-fast, lazy `requireNamespace` per backend with the vendor-license
  hint). **Benchmark (GLPK, mahal quadratic, p = 5): n = 15 -> 0.4s,
  n = 20 -> 3.5s, n = 25 -> 311s; default set at
  `EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N = 20L`** (sharp branch-and-bound
  cliff between 20 and 25). Exactness locked by brute-force enumeration over
  all `choose(n, n_T)` allocations in
  `tests/testthat/test-design-optimal-milp-solvers.R` (30 assertions, all
  passing), covering balanced and unbalanced `n_T`, `Q = P`, the Mahalanobis
  `Q`, and Bayesian `P_B`.
- [x] TODO-5b: **Done (2026-08-16).** `milp_solve_A_dinkelbach(P, H, n_T,
  roi_solver, max_dinkelbach_iter = 30L, tol = 1e-9)` in the same file:
  parametric subproblem `min w'(H + t_k P)w` via `milp_solve_quadratic`,
  ratio update, stop at `F(t_k) >= -tol`; returns
  `list(w, objective_value, iterations, converged, status)` — the
  fallback-to-annealing policy on `converged = FALSE` belongs to the class's
  solver dispatch (TODO-9), since the annealing solver (TODO-6) doesn't exist
  yet; this layer reports. Brute-force-verified against the true ratio
  minimum for interest `"all"`, subset `H_S`, and Bayesian `H_B`;
  finite-termination sanity asserted (`iterations <= 10` on the n = 10
  instances; observed convergence in a handful of outer iterations).
  Degenerate `s(w) <= 0` errors informatively.
- [x] TODO-6: **Done (2026-08-17).** Kernel:
  `src/design_optimal_annealing_search.cpp` (`annealing_design_search_cpp`),
  a dedicated native C++ SA optimizer with no greedy-engine dependency:
  treated/control swap neighborhood, Metropolis acceptance, geometric
  cooling, `n_chains` independent BCRD-started chains, incremental O(1)/O(p)
  move evaluation for all three objective kinds (`"quadratic"` `w'Qw`,
  `"l1"` `sum|Aw|`, `"ratio"` `(w'Hw+1)/(n_T - w'Pw)` with
  denominator-infeasibility rejection). Two deliberate refinements over the
  plan text: (1) seeding is **per chain**, not per thread (greedy's
  pattern), so a given `set.seed()` reproduces exactly under any OpenMP
  thread count; (2) each chain returns its best *visited* state (dominates
  the terminal state under any schedule), recomputed from scratch before the
  cross-chain argmin so incremental-update drift can never pick the wrong
  winner. R wrappers in `R/design_optimal_annealing.R` (in Collate):
  `annealing_solve_quadratic`/`_l1`/`_A_ratio` with always-on validation and
  auto-calibrated `initial_temp` (probe of random-swap |deltas|, R-RNG-seeded)
  when not supplied; certificate always `"annealing_converged"`.
  **Also landed here (pulled forward from TODO-9 at the user's request,
  2026-08-16): `optimal_solve_auto()`** — the "auto" solver-resolution
  policy as a solver-layer function: l1 always exact; quadratic/ratio exact
  within `linearization_max_n` (default the benchmarked
  `EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N = 20L`) with certificate
  `"global"`; annealing beyond it (with a message naming the cutoff and the
  commercial-backend escape hatch); Dinkelbach `max_dinkelbach_iter`
  exhaustion falls back to annealing keeping the better allocation with the
  certificate downgraded. TODO-9's class dispatch is now a thin consumer of
  this function. Tests (`test-design-optimal-annealing.R`, 34 assertions,
  all passing per testing-plan item 2): seed determinism,
  best-of-chains dominance + drift check, >= 80%-of-20-trials hit rate
  against the certified MILP optimum on brute-forceable instances (miss
  rate bounded, not zero), l1/ratio parity with the exact solvers,
  unbalanced `n_T`, argument validation, and the auto-dispatch switching
  behavior on both sides of the cutoff for quadratic and ratio.
- [x] TODO-7: **Done (2026-08-17), with scope widened by a user directive:
  the XPtr handling here and in the custom randomization statistic is now
  uniform via RcppXPtrUtils.** The header is `src/user_compiled_fns.h` (not
  the originally planned `custom_objective.h` — it now carries the
  package-wide calling conventions for ALL user compiled C++, EDI_CORE_ONLY-
  clean, Eigen-only): `edi_design_objective_fn(X, w)` plus
  `edi_rand_stat_fn(y, w)`/`edi_rand_stat_dead_fn(y, w, dead)`. Shared R
  half in `R/helper_user_compiled_fn.R` (in Collate):
  `normalize_user_cpp_fn()` accepts an `RcppXPtrUtils::cppXPtr()`
  externalptr OR a C++ source string (compiled via `cppXPtr`, source
  retained for worker recompilation), verifies recorded signatures with a
  whitespace/arg-name-insensitive check (deliberately not
  `RcppXPtrUtils::checkXPtr()`, which compares verbatim strings), and
  refuses plain R closures with the TODO-2 performance reason;
  `assert_custom_objective_xptr()` is the objective site's wrapper. Eval
  shims in `src/user_compiled_fn_shims.cpp` (`eval_custom_design_objective_cpp`,
  `eval_custom_rand_stat[_dead]_xptr_cpp`) are the single R-side deref
  points. Annealing integration: `annealing_design_search_cpp` gained the
  `"custom"` kind (M1 = the n x p model matrix X; flip-eval-restore
  candidate evaluation; **serial chains** — user code carries no
  thread-safety guarantee, so the OMP pragma is `if(parallel_ok)`-gated) and
  a `custom_objective` SEXP param; `annealing_solve_custom()` and
  `optimal_solve_auto(kind = "custom")` (always annealing, any n) wrap it.
  Stat-site uniformity: `set_custom_randomization_statistic_cpp()` now also
  accepts a `cppXPtr` externalptr (Eigen convention above), normalized at
  entry into the existing `compiled_cpp_stat_fn` slot as a thin closure over
  the shim — so all ~38 downstream consultation sites work unchanged; bare
  externalptrs without `cppXPtr`'s recorded signature are refused (arity is
  undeterminable); the legacy source-string/Rcpp-function forms are
  untouched. Tests (`test-design-optimal-custom-objective.R`, 21
  assertions, all passing): shim-vs-R-reference eval, closure refusal
  naming the performance reason, custom annealing reproducing the certified
  built-in `abs_sum_diff` optimum, seed determinism, source-string form,
  wrong-signature XPtr refusal, XPtr-vs-legacy-string stat p-value identity
  under a shared seed, bare-externalptr stat refusal, and auto-dispatch;
  annealing + legacy custom-stat baselines re-run green.

- [x] TODO-8: **Done (2026-08-17).** Registry side
  (`design_class_registry.R`): `"deterministic_optimal"` added to
  `EDI_DESIGN_ALLOWED_RANDOMIZATION_FAMILIES`;
  `DesignFixedOptimal = "deterministic_optimal"` staged in
  `EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME` (inert until TODO-9 — the
  registry scans the namespace, so a mapping with no live class is never
  read); `EDI_DESIGN_REQUIRED_PACKAGES_BY_NAME` lists
  `ompr`/`ompr.roi`/`ROI.plugin.glpk` only (commercial plugins deliberately
  absent per the never-Suggests rule); not in the batch-w-pregeneration set.
  Closed-enum tests appended to `test-design-class-registry.R` (incl. the
  one-class-one-family assertion for the new value); constants verified by
  standalone sourcing pending the next install. **Fencing audit finding: the
  inference side needs ZERO changes.** The Observational migration already
  made every call site capability-driven — `Inference` caches
  `des_obj$supports_randomization_draw()`/`supports_resampling_replay()`
  (`inference_all_abstract.R:87-88`) and gates via
  `assert_design_supports_randomization_draw` (rand test + rand CI:
  `inference_all_abstract_rand.R:97,313`, `_rand_ci.R:45,102,323,338`) vs.
  `assert_design_supports_resampling_replay` (BRT + BRT CI:
  `_rand_bootstrap.R:105,342`, `_rand_bootstrap_ci.R:81`) — exactly the
  draw-FALSE/replay-TRUE split this class needs. What remains is the
  class-level `supports_randomization_draw = function() FALSE` override
  (ObservationalDesign's pattern, `design_observational.R:85`; do NOT
  override `supports_resampling_replay`, whose base default is correct) —
  that lands with the class in TODO-9, as does the automatic registration
  via the namespace scan.
- [ ] TODO-8b: BRT wiring: route the BRT worker/draw path through
  per-replicate re-optimization of the resampled covariates
  (`generate_rand_bootstrap_draws()` and the reusable-worker machinery),
  implement `solver_args$brt_max_iter`/`brt_n_chains`/`brt_solver`, apply
  the mirror coin per replicate (each replicate's re-optimized `w*_b` gets
  its own independent seeded flip, per the Class-mechanics decision — the
  BRT must replay the *coin-inclusive* mechanism, not just the solve), and
  document the per-replicate cost.
- [ ] TODO-9: `assign_w_to_all_subjects()` solver dispatch, diagnostics
  cache, and `get_optimization_diagnostics()`; plus the mirror coin
  (`mirror_coin` constructor arg, post-solve co-optimum verification via
  objective evaluation at `1 - w*` with tolerance, seeded fair flip on a
  tie, strictly-better-mirror solver-bug assertion) applied at every solve
  site — observed-data solve, `draw_ws_according_to_design(r = 1)`, and the
  BRT replicate path (coordinate with TODO-8b). Diagnostics should record
  whether the mirror tied and which label the coin chose.
- [ ] TODO-10: Test suite per the Testing plan (brute-force exactness,
  annealing quality/convergence rate, custom XPtr, quality baseline vs.
  greedy restarts, fencing, fallback, BRT).
- [ ] TODO-11: Documentation: full roxygen (objective/argument mapping table
  in the same style as `DesignFixedGreedyDOptimal`'s D_M/D_s/D_A/D_B
  section, the model-based-inference-only trade-off stated prominently, an
  `RcppXPtrUtils::cppXPtr()` worked example), `Rscript fast_roxygenize.R`,
  and a `reproducibility.Rmd` note (MILP via `"ompr"` deterministic up to
  the seeded mirror coin; annealing R-seeded per chain; the mirror coin
  R-seeded), citing Hajek (1988) for the formal convergence property, and
  documenting `mirror_coin` — what the coin does, when it can fire
  (verified co-optimum only), and the unbiasedness/null-symmetry rationale
  with a pointer to the Harmonizing paper's mirror-pair construction. `@param custom_objective` specifically must state,
  not just imply, that only a compiled `Rcpp::XPtr` is accepted and *why*
  (an R closure evaluated per candidate swap inside the annealing loop is
  orders of magnitude too slow, per TODO-2's resolution) — this is a
  frequently-asked-"why can't I just pass a function" case, and the roxygen
  is the place that answer must live so it doesn't get re-litigated in
  issues/support requests later. `@param solver_args` must reproduce, as **two separate
  step-by-step subsections** ("Wiring up Gurobi" and "Wiring up CPLEX"),
  the full commercial-backend wiring guidance from "Optimization backends"
  above — not a merged/generic "commercial solvers" paragraph, since the
  two vendors' installation paths genuinely differ (Gurobi: CRAN-unavailable
  vendor R package installed from the Gurobi distribution, then
  `ROI.plugin.gurobi` from CRAN; CPLEX: `Rcplex` compiled from source against
  the local CPLEX SDK, then `ROI.plugin.cplex` from CRAN) — and why
  `ROI.plugin.gurobi`/`ROI.plugin.cplex`/`Rcplex` are never `Suggests`
  entries. Also document the closed `roi_solver` set explicitly
  (`"glpk"`/`"gurobi"`/`"cplex"` only) so a user doesn't assume an arbitrary
  ROI plugin name will work.

## Appendix: Commercial ROI Backends Also Benefit `DesignFixedOptimalBlocks`

Checked while resolving TODO-3, per the user's request: does the commercial-
backend wiring above also apply to the existing `DesignFixedOptimalBlocks`
class? **Yes — verified in the source, and it's the same gap, not a
different one.**

`DesignFixedOptimalBlocks`'s `method = "ompr"` (`design_fixed_optimal_blocks.R`,
`solve_optimal_blocks()`) builds a genuine exact MILP for block-partition
assignment — binary `x[i,k]` (subject `i` in block `k`) plus a
McCormick-linearized same-block indicator `z[i,j,k] <= x[i,k]`,
`z[i,j,k] <= x[j,k]`, `z[i,j,k] >= x[i,k] + x[j,k] - 1` (structurally the
same linearization technique as this plan's `"D"`/`"mahal_dist"` MILP,
independently arrived at in that file) — and solves it with:

```r
# design_fixed_optimal_blocks.R:292
result = ompr::solve_model(model, ompr.roi::with_ROI(solver = "glpk", verbose = FALSE))
```

**`solver` is hardcoded to `"glpk"`.** There is no argument on
`DesignFixedOptimalBlocks$new()` to change it — a user with a Gurobi/CPLEX
license and the right `ROI.plugin.*` installed currently has no way to use
it with this class at all, the feature doesn't exist to opt into.

This is the *same kind* of benefit as `DesignFixedOptimal`'s case, not the
"exactness" kind: `DesignFixedOptimalBlocks`'s own roxygen already documents
this MILP as "Globally optimal but scales as `O(n^2 B)` in variables and is
only practical for small `n`" — GLPK already gives a certified optimum here,
same as this plan's `"abs_sum_diff"`/`"D"`/`"mahal_dist"` rows; a commercial
solver would extend the practical `n`/`B` range before users must fall back
to `method = "greedy"`/`"K-way"`, exactly analogous to extending
`linearization_max_n`.

- [x] TODO-A1: **Done (2026-08-17).** Added `roi_solver` argument to
  `DesignFixedOptimalBlocks$new()` (closed set `"glpk"`/`"gurobi"`/`"cplex"`,
  default `"glpk"`, validated eagerly via `assertChoice(roi_solver,
  EDI_OPTIMAL_ROI_SOLVERS)` in the constructor's `method == "ompr"` branch;
  `EDI_OPTIMAL_ROI_SOLVERS` and `assert_optimal_roi_solver()` reused as-is
  from `helper_optimal_milp_solvers.R`, no new solver-registry logic).
  Stored as `private$roi_solver` and threaded into `solve_optimal_blocks()`'s
  `ompr.roi::with_ROI(solver = private$roi_solver, ...)` call in place of the
  hardcoded `"glpk"` string; the lazy `requireNamespace()`
  package/vendor-license check (`assert_optimal_roi_solver()`) runs at solve
  time inside `solve_optimal_blocks()` itself, mirroring
  `DesignFixedOptimal`'s TODO-5 pattern. `DesignFixedOptimalBlocks`'s roxygen
  updated with the same two Gurobi/CPLEX wiring subsections (verbatim
  content, `roi_solver = ...` direct-argument form instead of
  `solver_args$roi_solver`) plus a "Solver backend" paragraph carrying the
  same closed-set rationale and "never `Suggests`
  `ROI.plugin.gurobi`/`ROI.plugin.cplex`/`Rcplex`" rule. `.Rd` regeneration
  deferred to the next doc batch (interim roxygenize avoided per project
  convention); `parse()` on the changed file confirmed clean.
