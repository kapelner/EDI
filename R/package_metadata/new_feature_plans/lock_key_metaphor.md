# Explaining the Design–Inference Pairing

> **Depends on:** none. Documentation only; no changes to executable code,
> public APIs, or tests. Not gated by any other plan and gates nothing downstream.

Started: 2026-09-08. Revised: 2026-09-10 after reconsidering the lock-and-key
metaphor. The filename is retained so existing plan links continue to work.

> **Release placement (2026-09-08, user decision): v1.1.0.**
> `../future_release_plans/release_v1_1_0.md → TODO-19`. Recorded in
> `_master.md`'s Phase 3 (Documentation) as item 4.

## Primary explanation

Explain the relationship directly: **EDI pairs experimental designs with
compatible inference procedures.**

A `Design` object manages treatment assignment and records the experiment's
structure and observed responses. An `Inference` object uses that design
and its data to compute estimates, confidence intervals, or hypothesis
tests, according to the procedures it supports. For example,
`InferenceContinOLS$new(des)` constructs an analysis object using `des`.

The pairing has two distinct aspects. Compatibility checks establish
whether a procedure's implemented requirements are met. The inference
class, its configuration, and the method called determine the computation.
Some classes support several forms of inference; do not suggest that each
class corresponds to exactly one of Wald, likelihood-ratio, bootstrap, or
randomization inference.

Several compatible procedures can analyze the same experimental record.
They may estimate the same treatment effect using different estimators,
covariate adjustments, or uncertainty calculations. Some methods may
target different quantities, so comparisons also require attention to the
estimand. Explain differing results in these statistical terms.

**Software compatibility does not establish every statistical assumption.**
A successful pairing does not by itself guarantee an appropriate model,
accurate asymptotic approximations, or validity under the actual data
generating process. Describe results as valid under the relevant conditions,
without claiming that all compatible procedures are equally appropriate.

Suggested introductory copy:

> EDI pairs experimental designs with compatible inference procedures. A
> design object records treatment assignment, experimental structure, and
> observed outcomes; inference objects use that record to estimate effects
> and assess uncertainty. Several procedures can analyze the same experiment,
> each with its own requirements and assumptions.

## Optional analogy

If a visual comparison helps, use one brief sentence:

> Think of the design object as an instrument base and an inference procedure
> as an interchangeable analysis module: together they form a working
> analytical instrument.

Here, “analysis module” is descriptive prose for an inference procedure,
not a new API name or a synonym for the registered components used to build
an inference class. Use the actual `Design` and `Inference` names when
explaining the API.

Keep this analogy optional and local. It illustrates how an experimental
record can support several compatible analyses. It need not explain every
implementation detail or appear on every documentation surface.

“Like a key fitting a lock” remains an acceptable short comparison for
compatibility alone, if useful in context. It should not organize the
package documentation or explain why procedures compute different results.
Drop the extended locksmith vocabulary and the key-operated meter story.
Avoid replacing them with another detailed physical mechanism.

## What extension authors need to understand

The extension vignette should explain discovery, validation, and computation
using their actual software roles:

- `design$applicable_inference_class_names()` discovers candidate classes.
  Explain its metadata filtering through
  `is_inference_class_compatible_with_design_metadata()`, including the
  response and design characteristics checked by the current implementation.
- Construction and method-specific validation enforce the requirements of
  the chosen procedure. Explain where these checks occur from the current
  code; do not imply that every direct constructor call first runs discovery.
- `capabilities()` and `supports()` describe supported functionality.
  Distinguish capabilities a class provides from requirements it checks on
  its design. Do not treat the inference class's entire capability set as a
  list of required design capabilities.
- Constructing an inference object associates a procedure with the design.
  Calls such as `compute_estimate()` and supported confidence-interval or
  testing methods request particular computations.
- Internal components and metadata determine how classes are implemented.
  The pairing contract describes the interface between them; it does not
  imply that undeclared implementation details cannot affect computation.

Use `InferenceSuite$run_all_inference()` to illustrate several procedures
applied to one design, with its actual eligibility and execution behavior
verified before publication. Neither the discovery API's location nor the
constructor's argument order needs a physical analogy to justify it.

## Scope and writing guidance

Retain the planned documentation surfaces and v1.1.0 placement. The shared
message across those surfaces is design-aware inference and explicit
compatibility. Adjust the detail to each audience and avoid duplicating
existing explanations. A metaphor is not required in any placement.

Keep overview copy short and factual. Reserve interface details for the
extension vignette. Use the optional instrument sentence only where it
makes that explanation easier to understand. Keep `DESCRIPTION` and
citation metadata literal.

## TODO

- [x] **TODO-1 (decision):** revised 2026-09-10 at the user's request.
  Lead with the actual design–inference relationship; tone down the metaphor.
  Instrument base / analysis module is an optional illustration. The
  extended lock-and-key explanation is retired. Release placement remains
  **v1.1.0**, with the documentation surfaces below retained.

- [ ] **TODO-2 — `README.md`.** Refine the “Designs and inference that
  match” Highlights bullet or its immediate context. Use one or two direct
  sentences explaining that designs retain the experimental structure and
  inference procedures analyze compatible designs. Mention multiple analyses
  only if it adds information not already present. No metaphor heading is
  needed.

- [ ] **TODO-3 — pkgdown site.** Keep `R/EDI/_pkgdown.yml`'s
  `home: description` focused on task keywords, consistent with its existing
  discoverability guidance. Use the same factual pairing language in home
  content where useful. Do not require a second tagline or repeat content
  already supplied by the README.

- [ ] **TODO-4 — `R/EDI/vignettes/extending-edi.Rmd`.** Add or refine a
  short framing passage in “How EDI classes are built.” Explain the roles
  of `Design` and `Inference`, candidate discovery, checked requirements,
  and constructing and using an inference object. Distinguish the pairing
  interface from each class's internal composition. Verify the relevant
  source behavior before describing exact checks. Include a brief note
  that compatibility does not establish all statistical assumptions. The
  optional instrument analogy may appear once; no metaphor glossary is
  needed.

- [ ] **TODO-5 — `R/EDI/R/EDI.R` package-level `@name EDI` roxygen block.**
  Add or refine one sentence about pairing designs with compatible inference
  procedures, consistent with the README. Parse-check the file after editing.
  Keep documentation generation as a separate step after the documentation
  edits are complete; do not run `roxygenize()` or `devtools::document()` as
  part of this batch.

- [ ] **TODO-6 — `R/EDI/DESCRIPTION` `Description:` field.** Add a concise,
  factual clause if the existing description does not already cover pairing.
  Suggested wording, subject to source verification: “Inference procedures
  are matched to designs through explicit compatibility checks.” Avoid
  slogans, instrument language, and any implication that these checks alone
  guarantee statistical validity.

- [ ] **TODO-7 — `CITATION.cff` / `R/EDI/inst/CITATION`.** Optional, lowest
  priority: use a short factual pairing clause only if an existing free-text
  abstract or description provides a natural place. Preserve citation
  metadata structure and skip this item if there is no useful addition.

- [ ] **TODO-8 — `future_release_plans` placement.** The v1.1.0 placement
  was recorded on 2026-09-08 in `release_v1_1_0.md → TODO-19` and `_master.md`'s
  Phase 3, item 4. When implementing the documentation rollout, align any
  descriptions of this task with the revised framing. Preserve the release
  placement and existing links to this file.

## Verification

For this plan rewrite, review the Markdown and diff, and run
`git diff --check`. No execution, rendering, or compilation is needed.

When implementing the documentation TODOs:

1. Check API descriptions against the current source using the repo context
   graph. Start with `applicable_inference_class_names`,
   `is_inference_class_compatible_with_design_metadata`, `capabilities`,
   `supports`, and the constructor or method used in each example. Verify
   provided capabilities and required design features separately.
2. Read each passage in context for duplication, consistent terminology,
   and statistical qualifications. Explain differing results through methods,
   assumptions, and estimands. Avoid claims that a compatible procedure is
   automatically appropriate or that different procedures cannot estimate
   the same underlying effect.
3. Confirm the extended lock-and-key explanation has not been introduced
   into the target documentation. Any remaining analogy should be brief,
   optional, and unnecessary for understanding the actual API.
4. Parse-check `R/EDI/R/EDI.R` after its prose edits and review `DESCRIPTION`
   and citation metadata for formatting. Inspect Rmd chunks before considering
   rendering: rendering can execute code and is not automatically a read-only
   or compilation-free check. Any command that compiles, builds, rebuilds,
   or installs code requires explicit user permission under repo instructions.
5. Review the final diff and run `git diff --check`. A prose-only change does
   not need a package rebuild or test-suite run.

## History

The plan began on 2026-09-08 as a “lego system” comparison, then shifted to
lock-and-key to emphasize asymmetric compatibility. Subsequent revisions
added locksmith terminology and a key-operated measuring instrument to
account for different computations on the same design. The optional-package
availability analogy was dropped by user decision and remains out of scope.

On 2026-09-10, the user reopened the choice of metaphor and requested this
rewrite. The revised direction retains the useful idea of compatible
analytical components while giving the actual software and statistical
relationship priority. Earlier requirements to spread the full metaphor
across documentation are superseded by this plan.
