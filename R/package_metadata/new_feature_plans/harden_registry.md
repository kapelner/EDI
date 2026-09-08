# Harden the Capability/Slow-Path Registries — Single Source of Truth

> **Depends on:** none. Written 2026-09-08, growing out of a
> `comprehensive_tests.R`/`path_audits.html` slow-path recheck session that
> ended up auditing how many independent, drift-prone "this class can't/
> shouldn't do X" fact-tables the package actually carries. (Global
> ordering: see `_master.md`; release index: `release_v1_1_0.md → TODO-20`.)

## Motivation

A session spent rechecking `EDI_COMPREHENSIVE_SLOW_PATHS` (trimming 23
`exact_operations` entries down to 12, adding formula-qualification) kept
running into the same shape of problem one level up: **there is more than
one place a class's "I can't/won't do X" fact can live**, and they don't
agree on how they're kept in sync. Two concrete instances were found and
are the subject of this plan:

1. **Two capability-exclusion registries in `inference_class_registry.R`**
   — `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES` (explicitly documented as
   migration debt: "Remove each entry when the class is migrated to
   shallow component composition") and `EDI_INFERENCE_EXCLUDED_CAPABILITIES`
   (explicitly documented as permanent/principled). The legacy one's three
   entries turn out to already be redundant with information the classes
   themselves already carry (see "Finding 1" below) — it should never have
   survived the 2026-08-24 migration that created the "real" registry, it
   just wasn't in the block that got extracted that day.
2. **`comprehensive_tests.R` has its own hardcoded, non-registry exclusion
   rules** — four class lists (`skip_bootstrap`, `skip_rand`,
   `skip_ci_rand`, `skip_ci_rand_custom` — lines 891, 1027, 1032, 1050)
   plus two single-class special-cases (`InferenceCountKKGLMM`'s
   jackknife exclusion, `InferenceIncidLogBinomial`'s always-on BRT
   opt-in — lines 1056, 976) — that predate `EDI_COMPREHENSIVE_SLOW_PATHS`
   entirely (present since the very first commit in this repo's history,
   `ff079d54`) and were never folded into it when it was created. They mix
   genuinely structural exclusions (bootstrap doesn't mathematically apply
   to an exact test) with genuine, never-migrated performance facts (one
   already carries real timing numbers in its own comment). See
   "Finding 2" below.
3. **Not everything under `path_audits_source.R`'s hand-typed `skip_*`
   audit flags is hardcoded, non-registry debt** — several of them
   (`skip_boot_ci`, `skip_bbt_ci`, `skip_rand_ci`, `skip_stud`,
   `skip_pboot_ci`, most of `skip_jack_slow`) already flow correctly
   through `EDI_COMPREHENSIVE_SLOW_PATHS`'s ~32 class-rule category
   buckets (82 class×rule entries total) via `is_slow_class_rule()` — the
   same normal mechanism the `exact_operations` recheck earlier this
   session already used successfully. Those aren't broken; they're just
   **unrechecked** — the original ask this session ("recheck every
   hand-typed slow path, report avg/80th/max duration, retain design and
   formula") got interrupted by finding (1) and (2) above before reaching
   them. See "Also still open" below.

This plan scopes and sequences all three, but only commits concrete TODOs
for (1) — it is fully audited and low-risk. (2) needs its own scoping pass
first (see "Deferred" below) before TODOs can be written without guessing.
(3) needs no new engineering at all — it's a matter of running the
already-built `COMPREHENSIVE_FORCE_SLOW_PATHS` recheck harness against the
remaining ~82 entries, the same way the 12 `exact_operations` entries were
already done.

## Finding 1: `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES` is fully
redundant, verified by direct audit

`EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES` (`inference_class_registry.R:21-25`)
currently reads:

```r
EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES = list(
	InferenceIncidKKCondLogitGLMMIVWC = "parametric_likelihood_bootstrap",
	InferenceIncidKKCondLogitGLMMOneLik = "parametric_likelihood_bootstrap",
	InferenceIncidModifiedPoisson = "parametric_likelihood_bootstrap"
)
```

`get_effective_capabilities(name)` (`inference_class_registry.R:1437-1451`)
computes a class's capabilities as `(component-provided capabilities ∪
metadata$capabilities) - metadata$excluded_capabilities`, and
`populate_inference_class_registry()` (`inference_class_registry.R:~2438-2441`)
builds `excluded_capabilities` by merging
`EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES[[name]]` and
`EDI_INFERENCE_EXCLUDED_CAPABILITIES[[name]]`. All three legacy entries are
the same capability, `parametric_likelihood_bootstrap` — granted
structurally because all three classes compose the `ParametricLikelihoodBootstrap`
component (`load_policy = "lazy"`, `contracts_mixins.R:920-960`).

**The exclusion is redundant with what the classes already say about
themselves**, confirmed by a read-only audit against the installed package
(no mutation, just `get_effective_components()`/generator introspection —
reproducible any time by re-running the snippet below):

```r
library(EDI)
ns = asNamespace("EDI")
registry = ns$inference_class_registry_as_list()
concrete = names(Filter(function(m) !isTRUE(m$abstract), registry))
composes = Filter(function(nm) {
  tryCatch("ParametricLikelihoodBootstrap" %in% ns$get_effective_components(nm), error = function(e) FALSE)
}, concrete)
# composes has 39 members.
```

For each of the 39, resolving `supports_lik_ratio_param_bootstrap()`
without instantiating (walk the generator's `get_inherit()` chain; if the
found method is a lazy-component install-stub — detectable via its
`"inference_lazy_component_stub"` attribute, set in
`contracts_mixins.R:3004/3014` — resolve the real definition instead via
`get_lazy_component_dispatch(component_name, class_name)`, which sources
the component's own file directly with no R6 instance required):

- **Exactly 3 classes have a resolvable mismatch** (component structurally
  grants the capability, the resolved guard is a safe, no-`self`/`private`
  `function() FALSE`): `InferenceIncidKKCondLogitGLMMIVWC`,
  `InferenceIncidKKCondLogitGLMMOneLik` (both via
  `ParametricLikelihoodBootstrap`'s own default,
  `inference_all_abstract_param_boot.R:1060`), and
  `InferenceIncidModifiedPoisson` (via its composed
  `IncidenceModifiedPoissonLikelihood` component's own default,
  `inference_incidence_modified_poisson.R:164-166`). These are exactly the
  three legacy entries — **nothing else needs an entry**.
- **7 classes have an instance-dependent guard**
  (`InferenceContinKKGLMM`, `InferenceCountHurdlePoisson`,
  `InferenceCountKKGLMM`, `InferenceCountZeroInflatedNegBin`,
  `InferenceCountZeroInflatedPoisson`, `InferenceOrdinalKKGLMM`,
  `InferenceSurvivalGLMMWeibullFrailtyNormalOneLik` — all
  `function() isTRUE(private$use_rcpp)`) and **cannot be resolved
  statically at all**, by anyone, ever — the answer genuinely depends on a
  constructor argument. Confirmed by hitting exactly this failure
  (`Error in fn() : object 'private' not found`) when an earlier draft of
  this fix's resolver tried to bare-invoke one during testing. These are
  correctly left alone (not excluded) today and this plan does not change
  that.

**Decision: static data, not a runtime resolver.** An earlier draft of
this fix built the walk-the-inheritance-chain/`get_lazy_component_dispatch`
resolver above as a *live*, package-load-time derivation (so the registry
would "self-heal" if a class's guard ever changed). That mechanism works
(the audit above IS that resolver, run read-only) but adds real runtime
risk for zero present benefit: it depends on locked-namespace/lazy-stub
mechanics that are fragile to get right (this session hit three distinct
failure modes — a stray top-level `populate_inference_class_registry()`
call firing during isolated testing, a lazy-stub bare-invoke crash, and an
instance-dependent-guard bare-invoke crash — before landing on the safe
version above), and the fact being encoded (a hardcoded `function() FALSE`
in source) is not going to change on its own. The cheaper, equally-correct
fix is to **read the fact once (done above) and write it down as plain
data**, exactly like `EDI_INFERENCE_EXCLUDED_CAPABILITIES` already does for
every other permanent exclusion — no object-querying at package-load time
at all. Drift is caught instead by a **test-only** use of the same
resolver logic (TODO-2), which only runs under `R CMD check`/`testthat`,
never at load time, so a bug in it fails a test loudly instead of breaking
every user's `library(EDI)`.

## Finding 2: `comprehensive_tests.R` has its own pre-registry hardcoded
exclusion rules (deferred, not this plan's TODOs)

Four `is_any_inference_class(c(...))`/`is_exact_inference_class(c(...))`
lists, plus two single-class special-cases, live directly in
`comprehensive_tests.R`, independent of `EDI_COMPREHENSIVE_SLOW_PATHS`:

- `skip_bootstrap` (line 891) — ~19 classes, backs `path_audits_source.R`'s
  hand-typed `skip_boot`/`skip_bbt` audit columns for those classes.
- `skip_rand` (line 1027) — ~9 classes (variable naming collision: this is
  a *different* thing from the registry-derived `skip_rand_slow`), backs
  `path_audits_source.R`'s `skip_rand`.
- `skip_ci_rand` (line 1032) — ~11 classes + a `response_type == "count"`
  catch-all + an `AllSimpleAverageDiff` special case, backs `skip_rci`.
- `skip_ci_rand_custom` (line 1050) — 2 classes, backs `skip_rpv`; its own
  comment already carries real, never-migrated timing data ("robust avg
  336.6s / max 1994.8s at n=6; Clayton avg 41.9s / max 1993.3s at n=53").
- `supports_jackknife = supports_jackknife && !is_any_inference_class(c("InferenceCountKKGLMM"))`
  (line 1056) — a single-class hardcoded jackknife exclusion, additional
  to (not instead of) the registry's `jack` category (which already
  covers `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` and
  `InferenceContinKKGLMM`); together these back `path_audits_source.R`'s
  `skip_jack_slow` for all three classes it lists.
- `run_brt_for_class = RUN_BRT || is_exact_inference_class(c("InferenceIncidLogBinomial"))`
  (line 976) — `InferenceIncidLogBinomial` always gets bootstrap-
  randomization (BRT) methods regardless of the `RUN_BRT` CLI flag;
  backs `path_audits_source.R`'s `run_brt` for that one class.

Confirmed via `git log --oneline -S` and reading the 2026-08-24
"slow paths now a constant" commit's diff (`9a91ce91`): these predate
`EDI_COMPREHENSIVE_SLOW_PATHS` (present since the repo's first commit,
`ff079d54`) and were sitting immediately adjacent to the exact local
variable that commit *did* extract into the registry — they weren't
excluded on purpose, they just weren't the block being touched that day.

**Why this isn't a TODO in this plan yet:** unlike Finding 1, these four
lists are not provably redundant without per-class review. Each list mixes
two kinds of fact that need different destinations:

- **Structural** (bootstrap/randomization mathematically doesn't apply —
  exact-only classes, a sign test, certain closed-form ordinal
  regressions) → belongs as a capability exclusion
  (`EDI_INFERENCE_EXCLUDED_CAPABILITIES`-style, or a new capability name if
  the relevant capability isn't modeled yet — e.g. there may be no
  `"bootstrap"` capability tag at all today, only method-level presence).
- **Genuine, unmigrated performance facts** (the `skip_ci_rand_custom`
  pair above) → belongs in `EDI_COMPREHENSIVE_SLOW_PATHS$exact_operations`,
  the same registry this session already spent significant effort
  rechecking and trimming.

Sorting ~30-40 class entries across these four lists and two special-cases
into the right one of those two buckets is real, class-by-class analytical
work (was it added because `bootstrap` errors on this class, or because it
merely wasn't tested?), not something to guess at in a TODO list. **This
needs its own dedicated scoping pass** (same posture
`betaregscale_duplication.md`'s Tier 3 items take for work that isn't
ready to commit to yet) before concrete TODOs can be written. Recommend
running that pass as a follow-up to this plan, not inside it.

## Also still open: rechecking the ~82 already-registry-backed
category-bucket entries (separate from Finding 2, no new engineering
needed)

Unlike Finding 2's hardcoded, off-registry rules, most of the
`path_audits_source.R` hand-typed `skip_*` audit flags **already** flow
through the normal, on-registry mechanism: `EDI_COMPREHENSIVE_SLOW_PATHS`
has ~32 class-rule category buckets (`bootstrap`, `rand_ci`, `boot_ci`,
`bbt_ci`, `jack`, `pboot_ci`, `boot_stud`, `bbt_pval_studentized`, `m_out_of_n`,
…, 82 class×rule entries total), each consulted by `comprehensive_tests.R`
via `is_slow_class_rule(<category>)` exactly the same way the (now-trimmed)
`exact_operations` list was. `skip_boot_ci`, `skip_bbt_ci`, `skip_rand_ci`,
`skip_stud`, `skip_pboot_ci`, and two of `skip_jack_slow`'s three classes
are all backed this way — nothing hardcoded, nothing to sort.

These were never confirmed broken. They're simply **unrechecked**: this
session's original request (before the registry-architecture detour) was
to recheck every hand-typed slow path the same way `exact_operations` was
— force-run each one 10x via `COMPREHENSIVE_FORCE_SLOW_PATHS=1`, filtered
by `RESPONSE_TYPE_FILTER`/`INFERENCE_CLASS_FILTER`/`TEST_FAMILY_FILTER`
the same way the 12 `exact_operations` entries were, report avg/80th-
percentile/max duration with design and formula retained, and trim any
category-bucket membership that turns out fast now. That work is larger in
scope (82 entries vs. 12) but needs **no new mechanism** — it's a
straightforward re-run of the harness and analysis script already built
and validated earlier this session (`R/package_tests/slow_path_recheck/`),
grouped by `(response_type, class, category)` the same way, at the same
10-min-per-job budget scale. Flagging this explicitly here so it doesn't
get lost behind Findings 1/2 again — it's the most direct continuation of
this session's original "are we collapsing too much" question.

## TODOs

### This plan's scope: eliminate `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES`

- [ ] TODO-1: In `R/EDI/R/inference_class_registry.R`, delete the
  `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES` list (lines 16-25) and its
  header comment, and fold its three entries into
  `EDI_INFERENCE_EXCLUDED_CAPABILITIES` (the "deliberate" list,
  currently starting at line ~27) as plain data — same shape as that
  list's existing entries, e.g.:
  ```r
  InferenceIncidKKCondLogitGLMMIVWC = "parametric_likelihood_bootstrap",
  InferenceIncidKKCondLogitGLMMOneLik = "parametric_likelihood_bootstrap",
  InferenceIncidModifiedPoisson = "parametric_likelihood_bootstrap",
  ```
  Add a short comment above them citing this plan and Finding 1's audit
  result (component-composed but the class's own guard already resolves
  to `FALSE`; not migration debt, a permanent fact). Update
  `populate_inference_class_registry()`'s `excluded_capabilities = unique(c(...))`
  line (currently reads
  `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES[[name]] %||% character(),
  EDI_INFERENCE_EXCLUDED_CAPABILITIES[[name]] %||% character()`) to drop
  the now-deleted list's term, leaving just
  `EDI_INFERENCE_EXCLUDED_CAPABILITIES[[name]] %||% character()`.

- [ ] TODO-2: In
  `R/package_tests/testthat_bulk/test-parametric-bootstrap-lr-all-capable-classes.R`,
  update the `"legacy runtime opt-outs do not advertise parametric
  likelihood bootstrap"` test (currently reads
  `legacy_opt_outs <- names(EDI:::EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES)`)
  to source the three class names from a literal vector instead (the
  registry it read no longer exists) while keeping the same
  `expect_false("parametric_likelihood_bootstrap" %in%
  EDI:::get_effective_capabilities(class_name), ...)` assertions per class
  — this test already IS the "does the registry say what the class says"
  check for these three, it just needs to stop depending on the deleted
  constant's names. `R/EDI/tests/testthat/test-incid-kk-gcomp-migration-golden.R`
  only mentions the constant in a comment (lines 36-39) — update the prose
  there, no code change needed.

- [ ] TODO-3: Add a genuinely new drift-detection test (new `test_that()`
  block, same file as TODO-2 or a new
  `test-parametric-bootstrap-registry-drift.R`) that — **at test time
  only, never at package load** — re-derives whether each of the three
  classes' `supports_lik_ratio_param_bootstrap()` still resolves to
  `FALSE` using the safe-invoke logic from Finding 1's audit snippet
  (walk `get_inherit()`, detect a lazy stub via the
  `"inference_lazy_component_stub"` attribute, resolve through
  `EDI:::get_lazy_component_dispatch()` when needed, skip — don't crash —
  if the resolved function references `self`/`private`/`super` via
  `all.vars(body(fn))`), and asserts the live answer still matches the
  now-static `EDI_INFERENCE_EXCLUDED_CAPABILITIES` entries from TODO-1.
  This is what catches the fact going stale if someone later changes one
  of these three classes' guard, without paying the runtime-resolver risk
  Finding 1 explains was rejected for production use. Guard the whole
  test with `skip_if_not_installed` / a `tryCatch` that skips (does not
  fail) if `EDI:::get_lazy_component_dispatch` isn't exported/found, so a
  future internal refactor of the lazy-component machinery doesn't break
  this test in a confusing way — it should degrade to "drift check
  skipped," not a red herring failure unrelated to the fact being tested.

- [ ] TODO-4: Verify: load the package (no rebuild — this is pure `.R`
  source, `library(EDI)` picks it up once installed by whatever the
  user's own build process is; per `CLAUDE.md` do not run
  `R CMD INSTALL`/`devtools::load_all(compile=TRUE)` etc. yourself) and
  confirm `EDI:::get_effective_capabilities("InferenceIncidKKCondLogitGLMMIVWC")`,
  `..."InferenceIncidKKCondLogitGLMMOneLik")`, and
  `..."InferenceIncidModifiedPoisson")` each still exclude
  `"parametric_likelihood_bootstrap"`, and that
  `EDI:::get_effective_capabilities("InferenceContinLin")` (a class that
  should keep the capability) is unaffected. Run both updated/added test
  files. Run the existing `"every concrete parametric-likelihood-bootstrap
  class has a finite smoke case"` test in the same file unmodified — it
  should still pass with no changes, since the `capable` set it computes
  is unchanged by this refactor (same 3 classes excluded, same mechanism
  underneath, just one registry instead of two).

## Deferred (needs its own scoping pass, not scoped here)

- Sorting `comprehensive_tests.R`'s `skip_bootstrap`/`skip_rand`/
  `skip_ci_rand`/`skip_ci_rand_custom` hardcoded lists and the
  `InferenceCountKKGLMM` jackknife / `InferenceIncidLogBinomial` BRT
  single-class special-cases (Finding 2) into
  `EDI_INFERENCE_EXCLUDED_CAPABILITIES` (structural members) vs.
  `EDI_COMPREHENSIVE_SLOW_PATHS` (performance members). Needs, per entry:
  read the member class's actual behavior when the relevant operation is
  attempted (does it error/not-apply, or does it just run slowly?) before
  it can be classified — not safe to infer from the list's name alone
  (`skip_bootstrap` already mixes both kinds, confirmed in the session
  that produced this plan).
- Rechecking the ~82 already-registry-backed category-bucket entries (see
  "Also still open" above) — larger in scope than Finding 2's sort, but
  mechanically identical to the `exact_operations` recheck already done
  this session; no architecture decision needed, just execution time.
- Whether `path_audits_source.R`'s hand-typed `skip_*` boolean columns
  (`skip_rand`, `skip_boot`, `skip_bbt`, `skip_rci`, `skip_jack_slow`,
  etc. — distinct from that file's already-live-derived `slow_methods`
  overlay, see its own header comment) should also be replaced by a live
  derivation once Finding 2's sort is done, so the audit table stops
  needing hand-maintenance keyed by eye against `comprehensive_tests.R`.
