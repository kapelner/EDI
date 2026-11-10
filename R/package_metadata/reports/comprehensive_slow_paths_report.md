# `EDI_COMPREHENSIVE_SLOW_PATHS`: Granularity Report

> **Depends on:** none. Written 2026-09-06 in the course of
> `randomization_ci_construction_audit.md`'s path_audits registry-mirroring
> work, answering the question "is the slow-path registry refined by design
> and formula, or only by class and method?"

## The direct answer

**No design- or formula-level refinement exists anywhere in the registry.**
Every entry — both the ~29 plain category lists (`rand`, `rand_ci`,
`bootstrap`, `bbt_pval`, `jack`, `pboot_ci`, `brt_ci_all`, …) and the
finer-grained `exact_operations` list — is scoped to **(response_type +)
class name + method**, and nothing finer. This is deliberate and
documented in the file's own header:

> `@format` … every other element contains **formula-, dataset-, and
> design-independent** concrete inference-class names for the named
> slow-path family.

and, at the one place a maintainer considered going finer and explicitly
declined to:

> \[the 7 non-KK ordinal classes\] recompute the Bartlett-approx correction
> factor … at every delta candidate the CI root-finder tries … **Exact
> entries intentionally collapse across design and formula.**

So the granularity ladder has exactly two rungs, not three:

| tier | scope | example |
|---|---|---|
| **category lists** (`bootstrap`, `rand_ci`, `jack`, …) | class name only — applies to every design, every formula, every response-type instance of that class (response_type isn't even part of the key) | `rand_ci = c("InferenceSurvivalWeibullRegr", …)` — this class's plain randomization CI is slow, full stop |
| **`exact_operations`** | `response_type‖ClassName‖method` triple — the finest key the registry has | `"count‖InferenceCountHurdleNegBin‖compute_rand_two_sided_pval(delta=0.5)"` — this class's `delta=0.5` p-value specifically, for the count response type |

Neither tier carries a design family (Bernoulli, iBCRD, KK14, SPBR, …) or a
model formula (`~1`, `~.`, `~.*w`) as part of its key. A class that is slow
under one design/formula combination is treated as slow under all of them.

## Why this is a real, chosen simplification, not an oversight

Two pieces of evidence make clear this was thought about and rejected, not
just never attempted:

1. **The explicit comment above.** The registry could have keyed
   `exact_operations` on `response_type‖Class‖design‖formula‖method` — the
   information is available at the call site — and the maintainer's note
   says entries "intentionally collapse" it away instead.
2. **The validation function enforces the two-tier shape.**
   `validate_comprehensive_slow_path_rules()` (same file) parses every
   `exact_operations` key with `strsplit(..., "||")` and requires **exactly
   three parts** (`response_type`, a `^Inference[A-Za-z0-9]+$` class name,
   and a non-empty method string) — a fourth or fifth part would fail
   validation outright. The schema itself refuses a design- or
   formula-scoped key.

## The practical consequence

A "too slow" entry is a statement about the **worst case** the comprehensive
suite has actually hit for that class/method — usually the most expensive
design/formula combination the suite happens to sweep (e.g. a KK design
with covariates, which is typically the slowest cell for a KK-family class).
Once added, the exclusion applies uniformly, including to combinations that
would have been fast (e.g. the same class under a plain Bernoulli design
with no covariates). This is a one-directional conservatism: the registry
can make the comprehensive suite skip a combination that would have
finished quickly, but it can never under-skip a combination that's actually
slow, because the class/method-level exclusion is a superset of every
design/formula cell for that class.

This is the same trade EDI makes elsewhere for the sake of a small,
auditable registry: `validate_comprehensive_slow_path_rules()` also forbids
naming abstract classes and requires every listed name to resolve in the
live class registry, keeping the whole file mechanically checkable rather
than a free-form list that could silently rot.

## What actually varies *is* tracked, just under a different mechanism

The comprehensive suite does have per-design/per-formula timing data — it's
just not what drives skip decisions. The raw `comprehensive_tests_results_*.csv`
files (the ones `path_audits_nonestimability_defaults.csv` is built from)
carry a `design` column and an `inference_class` label that embeds the
model formula (e.g. `"InferenceSurvivalCoxPHRegr (model_formula=~.)
[design_formula=~.]"`), alongside `duration_time_sec` per row — i.e.
wall-clock time **per** `(class, design, formula, method)` combination is
recorded. That data feeds reporting (the estimability-rate bands
`path_audits.html` colors cells with) and ad hoc investigation, not skip
decisions — `EDI_COMPREHENSIVE_SLOW_PATHS` is the only thing that gates
what the suite attempts, and it stays at the coarser class/method grain by
design. (`comprehensive_suite_runtime_tiers.csv`, despite the name, is a
different thing entirely — a policy table of timeout/scheduler tiers, not
per-run timing data.)

## One nuance found while building path_audits' live derivation of this registry

`bartlett_pval`'s class list does not distinguish *which* Bartlett variant
(approximate vs. exact) a member class actually has — its own comment says
the bucket "gates both 'approx' and 'exact'" even though, at the time of
writing, none of the 7 non-KK ordinal classes in it support the exact
variant at all. This is consistent with the "class/method, not finer" rule
above (the variant isn't part of the key), but it means a naive automated
consumer of this category — such as an early draft of path_audits'
registry-mirroring code — can misapply the exact-variant method names to a
class that never had that method available, turning a correct "not
implemented" into an incorrect "slow." Fixed in path_audits by filtering
the derived Bartlett method names against each row's own
`pboot`/`bartlett_exact` applicability flags before merging — see
`path_audits_source.R`'s `derive_slow_methods()` overlay step. Anyone else
consuming this registry programmatically for the `bartlett_pval` category
specifically should apply the same filter.
