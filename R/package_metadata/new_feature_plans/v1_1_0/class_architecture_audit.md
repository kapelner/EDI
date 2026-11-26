# Class-Architecture Audit (weekly CI job)

> **Release:** v1.1.0-TODO-272 (`../../future_release_plans/release_v1_1_0.md`). Owner request 2026-11-26.
>
> **Related:**
> - `../v1_0_6/audit_jobs_framework.md`: the framework this audit plugs into (`audit.yml`, `audit_common.py`,
>   the `audit-notes` state branch, decisions and dismissals). Part 4's table gets a row for this audit.
> - `.github/workflows/audit-code-duplication.yml` + `.github/scripts/audits/code_duplication.py`: the closest
>   existing audit in shape (mechanical candidates, Sonnet verdicts, one issue, no PR). Copy its structure.
> - `R/EDI/tests/testthat/test-inference-class-wiring-completeness.R`, `test-design-abstract-hierarchy.R`,
>   `test-extracted-likelihood-mixin-public-contracts.R`, `test-design-component-registry.R`: the pre-push structural
>   tests. They catch **broken** wiring (a NULL component method, an unresolvable `private$x()` call). This audit
>   does not repeat them.
> - `R/EDI/R/contracts_mixins.R`: the Pattern-1 mixin host contracts, `EDI_MIXIN_ALLOWED_COLLISIONS` (line 89) and
>   `define_inference_class()` (line 3613), which stores `generator$edi_declaration` (metadata + components).
> - `R/EDI/R/design_class_factory.R`: `define_design_class()`.

## Goal

Every week, look over the R6 class architecture (inheritance, components, Pattern-1 mixins, overrides) and report
structure that works today but could be simpler, plus override patterns that have caused real bugs here. Report
only; edit nothing. Refactors of the hierarchy are owner decisions.

Not goals:
- Re-checking that wiring resolves (the pre-push tests own that).
- Code duplication in general (the code-duplication audit owns that; this audit only cross-references its
  verdicts for method bodies repeated across sibling classes).
- The Python class tree. A later phase may compare it with R; it is out of scope here.

## Why

Two bugs that cost real time had an architectural shape the existing tests could not see:

- **KK Wilcox randomization-bootstrap scale mismatch (2026-10-12).** A class overrode the randomization statistic
  but inherited `compute_bootstrap_worker_estimate`, so the bootstrap worker computed a different statistic (BRT
  p 0.02 against rand 0.31). Rule learned: a class that overrides one method of a coupled pair must override the
  other.
- **The 2026-09-19 wiring bugs** (Cox missing `ParametricLikelihoodBootstrap`, KK quantile classes missing the
  matched-pairs hooks) are now caught by the wiring test, but they show the class tree's composition grew faster
  than anyone could review by hand.

With 143 `define_inference_class` and 41 `define_design_class` calls, 97 classes inheriting `Inference` directly,
and a dozen intermediate abstracts, no one re-reads the whole tree. A weekly diff plus a ranked candidate list
makes changes to it visible.

## Design

Name `class-architecture`. Workflow `.github/workflows/audit-class-architecture.yml`, a thin caller of `audit.yml`
like `audit-code-duplication.yml`. Weekly, **Saturday 07:07 UTC** (`"7 7 * * 6"`, free as of 2026-11-26; Saturday
06:07 is the Rd audit). `workflow_dispatch` with `scope: auto | all | none`, as in code-duplication.

### Stage 1: export the class graph (R, no Claude)

New `.github/scripts/audits/class_architecture_export.R`. It **loads EDI and introspects the generators** rather
than parsing source, because `define_inference_class()` and `define_design_class()` assemble public/private lists
from components at definition time: static parsing would misattribute where an effective method comes from.

- Load: `pkgload::load_all("R/EDI", compile = FALSE)` over a cached `EDI.so`, keyed on a hash of `R/EDI/src`, so an
  R-only change costs no compile. On a cache miss, build once in CI with `EDI_UNITY=0`. CI only; never run this
  locally as a build step (project CLAUDE.md). `audit.yml` has an install step only for the finish stage
  (`finish_install_edi`); this audit needs a `prepare_load_edi` input (or equivalent) on the prepare stage.
- For every `R6ClassGenerator` in the namespace, write to `class_graph.json`:
  - class name, file:line of its definition, parent, depth from the root, children;
  - `edi_declaration$components` (after `resolve_component_dependencies()`), declared `overrides`, metadata;
  - Pattern-1 mixins spliced in (from the host contracts in `contracts_mixins.R`);
  - each public and private method: origin (`own`, `inherited:<ancestor>`, `component:<name>`, `mixin:<name>`),
    a hash of the normalized deparsed body, whether the body calls `super$`, and whether it is a bare `stop()`;
  - method count, active-binding count.
- Deterministic output (sorted keys and lists), so the week-over-week diff is meaningful.

### Stage 2: mechanical checks (Python, no Claude)

New `.github/scripts/audits/class_architecture.py` on top of `audit_common.py`. Each finding gets a stable id
`arch-<hex>` from (check, class names, method names), so it survives line moves.

| Check | What it flags |
|---|---|
| **Paired overrides** | A class overrides method A of a coupled pair but inherits B from an ancestor whose A differs. Pairs come from two sources: (1) the hand-kept pairs in `R/EDI/tests/testthat/class_architecture_paired_overrides.csv` (also run in pre-push by `test-class-architecture-paired-overrides.R`, DECISION-v1.1.0-TODO-272), seeded with the randomization statistic ↔ `compute_bootstrap_worker_estimate` pair and grown after each bug of this shape; an inherited coupled method that calls the statistic or a listed delegate helper passes; (2) mined pairs overridden together in ≥ 90% of the classes that override either, with the outliers flagged. Ranked first. |
| Pull-up candidates | The same method body hash in ≥ 2 sibling classes but not on their parent: a candidate to move into the parent or a component. Skip pairs the code-duplication audit already has a verdict for (`code-duplication/verdicts.json`). |
| Overrides that defeat the parent | A parent method that ≥ 90% of its children override (the parent's version is effectively dead), or children that override it with a bare `stop("not supported")` (a capability that belongs behind a `supports_*` hook instead). |
| No-op overrides | An override whose body only calls `super$<same>(...)` with the same arguments. |
| Thin abstracts | An abstract class with one child (collapse candidate) or none (dead). Chains deeper than a threshold (start at 5; tune in Phase 0). |
| Mixin and component hygiene | A Pattern-1 mixin used by only one host (inline it); one used by every child of one parent (promote it into the parent); `EDI_MIXIN_ALLOWED_COLLISIONS` entries that no longer collide; host-contract requirements no method calls; `private$` calls a mixin makes that its contract does not list. |
| Repeated component sets | The same resolved component set in ≥ k classes (start at 4): a candidate for a named bundle (like `define_incidence_likelihood_class()`) or an intermediate abstract. |
| Large classes | Method count above a threshold, with separate thresholds for the root classes (`Inference`, `Design`) and leaves. |
| Graph diff | Not a finding: classes added or removed, parent changes, depth changes and new overrides since the last run, for the job summary. |

Thresholds live in the rules file, not in code.

### Stage 3: Claude verdicts

Sonnet, batches of 8, at most 8 batches a run, highest-ranked first. Only findings with no verdict yet and not
dismissed; the rest wait for the next run. The agent has no shell, so the prepare stage hands it each finding with
the relevant class-graph excerpt and the method sources inlined (reuse `_edi_index.py` for which tests mention each
class). One verdict per finding:

- `intentional`: why the structure is right as it is (one sentence).
- `refactor`: target (parent, component or new abstract), the methods that move, every class affected, and the
  tests that would cover the move.
- `bug`: file:line evidence of a wrong result. As in the numerical-robustness audit, a bug counts only with a
  testthat test that fails on the branch; the finish stage runs it under `pkgload::load_all(compile = FALSE)` and
  keeps the finding only if the test fails. The test is reported, never committed.

Optional Phase 5: a rotating Opus pass, one subtree per run (survival, KK, ordinal, count, proportion, designs;
1/6 rotation via `_rotation.py`), given that subtree's graph and asked for at most 2 restructurings with the same
`refactor` fields.

### Output

- **One issue**, label `audit-class-architecture`, updated in place, closed when there is nothing open: findings
  by verdict, paired-override findings first, plus the graph diff.
- **Decisions**: `refactor` and `bug` verdicts become decisions with ids `class-architecture-d<hex>` on the pinned
  `audit-decisions` issue; the owner dismisses them in `R/package_metadata/audits/DISMISSED_DECISIONS.md`. A fixed
  finding stays there until re-run, cited or dismissed.
- **No PR**: nothing here is a mechanical edit.
- **State** on `audit-notes`: `class-architecture/graph.json` (last run's graph, for the diff),
  `class-architecture/verdicts.json`, `class-architecture/manifest.json`.
- **Skip**: when `scripts/significant_changes.py` finds no change in `R/EDI/R` since the last run and nothing is
  waiting for a verdict.
- **Secrets**: needs `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`; without one, stages 1 and 2 still run and
  every batch is reported NOT RUN.

### Files

- `.github/workflows/audit-class-architecture.yml`
- `.github/scripts/audits/class_architecture.py`, `.github/scripts/audits/class_architecture_export.R`
- `.github/prompts/audit_class_architecture.md`, `.github/prompts/audit_class_architecture.schema.json`
- `R/package_metadata/audits/class_architecture_rules.yml` (thresholds; the coupled pairs are in `R/EDI/tests/testthat/class_architecture_paired_overrides.csv`)
- `.github/scripts/test_audit_class_architecture.py` (unit tests of the checks on a small fixture graph)
- `audit.yml`: the prepare-stage EDI load input
- a row in `../v1_0_6/audit_jobs_framework.md` Part 4

## Phases

- [ ] **Phase 0: measure.** Write the exporter, run it once on `main`, and report: class count, depth
  distribution, and the raw count each check would flag at the starting thresholds. Owner picks thresholds before
  any Claude stage is wired. Also time the export with a warm `.so` cache (target: under 2 minutes).
- [ ] **Phase 1: mechanical audit.** Stage 2 checks, the issue, the
  graph diff, the skip rule, unit tests on a fixture graph. No Claude yet.
- [ ] **Phase 2: verdicts.** Stage 3 with Sonnet, the prompt and schema, decisions and dismissals.
- [ ] **Phase 3: bug confirmation.** The finish stage runs each `bug` verdict's test and drops it if the test
  passes.
- [ ] **Phase 4: first month review.** After four runs, the owner reviews the verdict mix; drop or retune any check
  whose findings are almost all `intentional`.
- [ ] **Phase 5 (optional): Opus subtree rotation.**

## Open questions for the owner

1. ~~Should the paired-override rules also run in pre-push?~~ Decided 2026-11-26 (owner): yes; see
   [DECISION-v1.1.0-TODO-272](../../future_release_plans/COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-272). Done:
   `R/EDI/tests/testthat/test-class-architecture-paired-overrides.R`. The hand-kept pairs therefore live in
   `R/EDI/tests/testthat/class_architecture_paired_overrides.csv` (not in `class_architecture_rules.yml`, which keeps
   the thresholds); the weekly audit reads that CSV and adds the mined pairs.
2. Thresholds (chain depth, repeated component-set size, large-class method counts): set after Phase 0.

## Done when

Phases 0-4 are ticked: the weekly job runs on `main`, posts one issue with verdicts, records decisions, and the
owner has reviewed one month of output and retuned or dropped the noisy checks.
