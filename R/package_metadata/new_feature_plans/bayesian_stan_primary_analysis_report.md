# Bayesian Parametric Primary Analysis via Stan

> **Depends on:** none structurally — additive and optional throughout, no
> existing contract changes. Shares its diagnostics-surfacing contract with
> `public_diagnostics_api_spec.md` (v1.1.0) once Phase 1 lands, and its
> Phase 5 reuses `sequential_inference.md`'s (v2.0.0) interim-look
> architecture rather than inventing a new one. (Global ordering: see
> `_master.md`.)

Generated: 2026-09-10

## Scope

This is a feasibility and design-space exploration, not an implementation
spec — same framing as `sequential_inference.md`. It asks: should EDI add a
genuinely parametric Bayesian primary-analysis family (real priors, a
declared likelihood, posterior probability statements, optionally Bayes
factors and hierarchical borrowing), backed by Stan, and if so, how would
it integrate without touching EDI's own C++ build or its CRAN posture?

Commissioned by
[`missing_inference_classes_literature_audit.md`](missing_inference_classes_literature_audit.md),
item 21 (Part 4C): "Bayesian parametric primary analysis... **partial** —
Bayesian bootstrap only... Large effort (Stan/JAGS or conjugate kernels).
Worth a scoping report; the Bayesian bootstrap already gives posterior-like
intervals."

## 1. What EDI already has, and what a resampling posterior cannot give

`InferenceAllAbstractBayesianBootstrap`
(`EDI/R/inference_all_abstract_bayesian_bootstrap.R`) already gives every
compatible class a posterior-*like* interval via Dirichlet-weighted
resampling, with no model or prior assumptions. `sequential_inference.md`
§8.2 already designs Bayesian interim monitoring on top of it. That
machinery is real, cheap, and correctly scoped as nonparametric — but it
structurally cannot produce:

- an **informative or weakly-informative prior** on the effect (there is no
  likelihood for a prior to combine with);
- a **posterior probability statement calibrated to a declared model**
  (`P(effect > 0 | data)` from the bootstrap is a resampling frequency, not
  a model-based posterior — the two coincide asymptotically under
  regularity conditions but are not the same object, and platform-trial /
  FDA-facing use expects the latter);
- a **Bayes factor** (undefined without two competing likelihoods); or
- **partial pooling / hierarchical borrowing** across sites, subgroups, or
  historical controls (needs a genuine multi-level model, not resampling
  of a single arm contrast).

These four gaps are exactly the four capabilities item 21 names, and they
are the reason this report exists rather than simply extending the
bootstrap. Demand is real but a minority use case — audit item 21 puts
Bayesian primary analysis at roughly 1% of phase III medicine trials
currently, rising with platform trials and the FDA's 2025 draft guidance on
Bayesian designs; common at tech vendors, occasional in psychology (JASP).
This motivates an **optional, clearly-secondary** family, not a change to
any default.

## 2. Integration depth: how Stan actually enters EDI

Two fundamentally different ways to depend on Stan:

**(a) External backend via `cmdstanr` (recommended).** Stan stays a fully
external, optional process. EDI ships (or generates once) `.stan` model
files; `cmdstanr` compiles each unique model file once via a separately
installed CmdStan toolchain, caches the compiled binary, and every
subsequent fit reuses it. Zero `LinkingTo` changes to `R/EDI`'s own
`DESCRIPTION`, zero coupling to `R/EDI`'s C++ sources, zero risk to its
compile time. `EDI/CLAUDE.md`'s standing rule against full rebuilds of
`R/EDI` is about `R/EDI`'s own `.cpp` tree; this backend never touches it.

**(b) Tight coupling via `rstan`/`StanHeaders`.** `LinkingTo: StanHeaders,
BH, RcppParallel`, generate C++ from Stan code and compile it in-process —
the `rstan`/`rstanarm`/`brms` model. This buys closer integration (e.g. a
Stan model could in principle call into EDI's own C++ likelihoods) at the
cost of adding heavy `LinkingTo` dependencies to `R/EDI` itself and
per-model runtime compilation, typically 30–90+ seconds for a first fit of
a new model. That is precisely the class of cost `EDI/CLAUDE.md` singles
out as intolerable for this repo, except it would recur per *model* rather
than per full package rebuild — arguably worse, since it would trigger on
ordinary user code paths, not just development.

**Recommendation: (a).** `cmdstanr` as an optional (`Suggests`) backend.
This also matches how EDI already handles other heavy optional
dependencies (see §4).

## 3. Model-authoring approach

Given (a), how does Stan model *code* get written?

1. **Hand-written, fixed `.stan` files, one per (response type ×
   canonical likelihood), shipped under `inst/stan/`** (recommended).
   Mirrors EDI's existing one-class-per-model-variant granularity (e.g.
   separate classes already exist per link function for incidence and
   ordinal). Auditable, and — critically — compile-cache-friendly:
   `cmdstanr` caches a compiled binary per exact Stan source text, so a
   small fixed library compiles once and every later fit (including inside
   `SimulationFramework` power studies, which may fit the same model
   thousands of times) is a fast reuse.
2. **Programmatic Stan code generation** (the `brms` model) — flexible,
   but every generated variant is new source text, which defeats the
   compile cache (near-certain recompilation on many calls) and adds a
   whole code-generation subsystem EDI would own and maintain. Against the
   "exact code paths, no magic" pattern the rest of the class hierarchy
   follows.
3. **Adapter around `brms` itself** — least new Stan code, but adds a
   dependency-of-a-dependency (`brms` pulls in its own rstan/cmdstanr
   choice, `bridgesampling`, `loo`) and cedes control of exact model
   parameterization, which EDI needs for its own design-aware weighting
   and estimand contracts (the same reason `causal_forest_inference.md`
   builds a thin adapter around `grf` rather than reimplementing forests,
   but does *not* delegate estimand bookkeeping to `grf`).

**Recommendation: (1).** A small, hand-written `.stan` library, expanded
one response type at a time as Phase 3 (§7) proceeds.

## 4. Architecture

- New sibling family alongside the existing hierarchy —
  `InferenceContinBayesStan`, `InferenceIncidenceBayesStanLogit`, etc. —
  registered the normal way via `define_inference_class()`
  (`EDI/R/contracts_mixins.R:3652`), with
  `metadata$required_packages = c("cmdstanr", "posterior")` (add
  `"bridgesampling"` only when the Bayes-factor output, §7 Phase 2, is
  requested). `populate_inference_class_registry()`
  (`EDI/R/inference_class_registry.R:2440`) and the registry's existing
  optional-dependency handling then gate availability exactly the way they
  already do for every other Suggests-only backend — no new mechanism
  needed here.
- A `BayesStanFit` component owns: assembling `standata` from the
  `Design`/response objects (reusing existing design-aware weighting
  rather than re-deriving it), invoking `cmdstanr::sample()` (full NUTS)
  or `$laplace()`/`$variational()` for cheap approximate-posterior paths
  (used in Phase 5, §7), and mapping draws back onto EDI's result
  contract.
- **Result contract stays complementary and separately labeled** from
  `BayesianBootstrap`, per the resolved design decision: a new
  `posterior_summary` shape (mean/median/credible interval,
  `P(effect > threshold)`, and an optional Bayes factor) that is never
  presented as a bootstrap CI. This is the same "many valid keys, not
  redundancy" pattern the `InferenceSuite` already uses for coexisting
  estimators of the same estimand.
- Diagnostics (R-hat, ESS, divergent transitions, treedepth saturation)
  surface through the same convergence-diagnostics contract
  `public_diagnostics_api_spec.md` is building for the optimizer paths —
  MCMC non-convergence is a different failure mode of the same "did this
  fit actually converge" question, not a new diagnostics concept.
- Default priors are weakly informative per response-type/likelihood
  (documented, not silently magic-number), user-overridable through a
  `priors = list(...)` argument on `Inference$new()`. Any class advertising
  a Bayes factor must document its prior's role in that number explicitly
  (Bayes factors are prior-sensitive in a way credible intervals mostly
  are not); a prior-sensitivity check is an implementation-phase test
  requirement, not optional polish.

## 4B. Visualization (added 2026-09-10, from this session's visualization brainstorm)

The original §4 architecture left the posterior only as numbers (mean/
median/credible interval, `P(effect > threshold)`, Bayes factor) plus
scalar convergence diagnostics (R-hat, ESS, divergences). Real value is
left on the table there — a posterior is far more informative shown than
tabulated, and this ecosystem already has a mature, purpose-built plotting
library: **`bayesplot`** (Stan's own companion package, already the de
facto standard for exactly this — `mcmc_dens()`, `mcmc_areas()`,
`mcmc_trace()`, `mcmc_hist()` all return plain `ggplot2` objects, so they
compose directly with `inference_suite_interactive_reporting.md`'s HTML/
`plotly` wrap rather than requiring a second plotting library).

- **Posterior density plot** — `bayesplot::mcmc_areas()`-style: one
  density per parameter (at minimum the treatment effect), the credible
  interval shaded within it. The Bayesian analogue of a histogram, but for
  a distribution EDI has draws for rather than raw data.
- **Trace plot** — `bayesplot::mcmc_trace()`: draws vs. iteration, one
  line per chain. The standard visual complement to the numeric R-hat/ESS
  diagnostics already scoped in §4 — a chain that "looks fine" on R-hat
  but visibly hasn't mixed is exactly the failure mode a trace plot catches
  and a scalar diagnostic can miss.
- **Prior-vs-posterior overlay** — the prior density and posterior density
  for the same parameter on one panel. Answers "how much did the data
  actually move this," which matters most for the Bayes-factor outputs
  (§4's own note that Bayes factors are prior-sensitive) — this plot is
  the visual version of that sensitivity statement, not a separate check.
- **Posterior forest plot** — point estimate (mean/median) + credible
  interval, one row per class/formula, in the *same visual language* as
  `InferenceSuite`'s existing frequentist CI forest plot
  (`run_all_inference_plot_ci_forest`) — a user should be able to place
  a Bayesian posterior interval next to a frequentist CI and immediately
  read both, not learn a second plot grammar. This is the closest thing to
  a "shared report" between this plan and `InferenceSuite`'s own, worth
  keeping in mind if/when the two are ever actually merged into one view.
- All of the above are `Suggests`-gated on `bayesplot` in addition to
  `cmdstanr`/`posterior` (§4) — absent, the numeric §4 output is
  unaffected, only the plots are skipped, same degrade-gracefully rule as
  everywhere else in this codebase.

## 5. Relationship to `causal_forest_inference.md`'s BART/BCF work

Both are "Bayesian," but they answer different questions with different
machinery and there is no overlap to reconcile:

- `causal_forest_inference.md` (already v2.0.0 scope) adds Bayesian
  **tree** models (BART/BCF) for **heterogeneous** treatment effects —
  a `tau(x)` surface — backed by the `BART`/`bcf` R packages, no Stan
  involved.
- This report is about a **scalar-effect** parametric posterior (the
  direct Bayesian analogue of EDI's existing point-estimate + CI classes),
  backed by Stan.

If both land, they should share vocabulary for posterior summaries
(credible intervals, ESS/R-hat-style diagnostics where applicable) so a
user sees one consistent "this is a posterior, here's how to read it"
convention — worth a shared helper, not a shared model family.

## 6. CRAN-compatibility risk (verified 2026-09-10)

`cmdstanr` is **not distributed on CRAN**; Stan's own install path is
`install.packages("cmdstanr", repos = "https://stan-dev.r-universe.dev")`,
and `cmdstanr::install_cmdstan()` then compiles a separate CmdStan
toolchain entirely outside R's package system. EDI is actively pursuing
CRAN submission (see `project_cran_status` context), so this needs explicit
handling, not discovery at submission time:

- `cmdstanr` must live in `Suggests`, gated by
  `requireNamespace("cmdstanr", quietly = TRUE)` /
  `cmdstanr::cmdstan_version()` (does CmdStan itself exist, not just the R
  package) — the same pattern already used for EDI's other optional
  Suggests backends. Every example, vignette chunk, and test touching this
  family must skip cleanly when absent, matching CI's existing
  no-Suggests leg (`_R_CHECK_SUGGESTS_ONLY_`, see `release.md`).
- A relevant precedent exists: `instantiate` (on CRAN) exists specifically
  to let R packages ship precompiled CmdStan models, and CRAN has already
  accepted that pattern. But `instantiate` precompiles models **at package
  install time, from source** — binary distributions (which is how most
  users get Windows/macOS builds from CRAN) skip compilation entirely,
  because CRAN's own binary-build servers don't have CmdStan. That
  approach only works for source installs. Since EDI ships CRAN binaries
  for Windows/macOS today, the right model here is **not** `instantiate`'s
  install-time precompilation but `cmdstanr`'s own ordinary compile-on-
  first-use-then-cache behavior, gated the same way any other optional
  compiled backend would be — the `.stan` library from §3 stays source,
  and the first call per machine pays the (one-time, cached) compile cost.
- Net effect: this is a real, solvable-but-nontrivial CRAN-compatibility
  item, not a blocker, but it is the first thing to re-verify at
  implementation time (`cmdstanr`'s CRAN status, and `instantiate`'s
  current approach) since both can change.

## 7. Phasing (design-space options, not commitments)

1. **MVP.** One or two response types (continuous, incidence), single
   covariate-adjusted treatment contrast, default weakly-informative
   priors (user-overridable), posterior estimate + credible interval +
   convergence diagnostics.
2. **Decision outputs.** `P(effect > 0)` / `P(effect > MCID)`, Bayes factor
   via bridge sampling — post-processing on Phase 1's fitted draws, not a
   new model family.
3. **Remaining response types** (proportion, count, survival, ordinal) —
   mechanical repetition of the Phase 1 pattern once it exists, one
   `.stan` file and one registered class per canonical likelihood.
4. **Hierarchical / borrowing models.** Genuinely new multi-level Stan
   structure (site/cluster partial pooling — echoes audit item 29's
   site-as-cluster framing for the frequentist case). Meaningfully bigger
   scope than Phases 1–3; own decision gate.
5. **Sequential / platform-trial monitoring.** Wire the Phase 1–4 posterior
   into `sequential_inference.md`'s existing repeated-look architecture
   (§8.2 there) as an alternative posterior source alongside the Bayesian
   bootstrap. **Flagged risk:** full NUTS at every interim look is
   expensive at the scale `SimulationFramework` operating-characteristic
   studies run at (many simulated trials × many looks each). Weigh a cheap
   approximate posterior (`cmdstanr`'s `$laplace()`/`$variational()`) for
   interim looks against full MCMC reserved for the final analysis before
   committing to this phase's design.

None of Phases 2–5 are prerequisites for each other in a strict sense
except as noted (2 needs 1's fitted draws; 5 needs 1–4's model family to
exist for whichever response types are being monitored); they can be
prioritized independently once Phase 1 exists.

## Implementation TODOs (decision gate only — no code)

- [ ] TODO-1: **Decision batch.** Pursue this at all? If yes: confirm
  `cmdstanr` as the backend (re-verify its CRAN/r-universe status and
  `instantiate`'s current approach first, per §6 — both can have changed);
  confirm the hand-written `.stan`-library authoring approach (§3);
  confirm response-type entry order for Phase 3 (§7).
- [ ] TODO-2: If yes, write the real implementation plan for Phase 1 (MVP)
  only — do not plan Phases 2–5 in detail until Phase 1's registry
  integration and result contract are proven out.
- [ ] TODO-3 (added 2026-09-10): **Visualization** per §4B — `bayesplot`-
  backed posterior density, trace, prior-vs-posterior overlay, and a
  posterior forest plot sharing `InferenceSuite`'s visual language;
  `Suggests`-gated, ships alongside Phase 1 rather than as a later
  afterthought since the plots are cheap once the draws already exist.

## 8. Non-goals

- Not a general-purpose probabilistic-programming interface exposed to end
  users — EDI ships fixed model families per response type/estimand
  (§3), not an arbitrary Stan-code editor.
- Not replacing `BayesianBootstrap` — the two stay complementary and
  separately labeled (§4), per the resolved design decision.
- Not the BART/BCF causal-forest work — that is
  `causal_forest_inference.md`, already v2.0.0 scope, a different family
  with a different backend (§5).
- Not implementing an MCMC sampler, autodiff engine, or optimizer of any
  kind — always delegates to Stan's own NUTS/ADVI/Laplace-approximation
  implementations via `cmdstanr`.
- Not committing to all six response types or all four capabilities
  (posterior CI, decision outputs, hierarchical models, sequential
  monitoring) in one release — phased per §7, each phase separately
  gate-able.
