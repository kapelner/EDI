# The "Lock-and-Key" Metaphor for the Design/Inference Pairing

> **Depends on:** none. Pure documentation/naming; touches no code, no public
> API, no tests. Not gated by any other plan and gates nothing downstream.

Date: 2026-09-08 (started as a "lego system" framing; narrowed, refined,
and had lego dropped entirely same day, user decisions — see "History"
below, this file was `lego_metaphor.md` until that point; further refined
same day with the warding/shear-line/scoping additions below, user
decisions)

> **Release placement (2026-09-08, user decision): v1.1.0.**
> `../future_release_plans/release_v1_1_0.md → TODO-19`. Recorded in
> `_master.md`'s Phase 3 (Documentation) as item 4.

## The metaphor

A `Design` is the **lock**: built once, its capability profile (response
type, blocking, censoring axes, randomization scheme) fixes at construction
— like a lock already installed in the wall. An `Inference` class is the
**key**: a fixed tooth pattern (its declared required capabilities,
`supports(capability)` / `capabilities()`,
`R/EDI/R/design_abstract.R:599`, `R/EDI/R/inference_all_abstract.R:175`)
that either turns a given lock or doesn't. The relationship is asymmetric
(an `Inference` object is constructed *from* an already-built `Design` and
checks compatibility against it, never the reverse) and gated by an
explicit compatibility check that fails fast rather than silently producing
a partial or wrong fit.

**Which side is which is settled by usage, not by an arbitrary label:**
`InferenceSuite$run_all_inference()` takes *one* fixed `Design` and tries
*every* eligible `Inference` class against it, keeping whichever ones fit —
literally "one lock, many candidate keys tried in sequence." Nobody fixes
one `Inference` object first and then shops for a compatible `Design`. So:
**Design = lock, Inference = key.**

### Two gates, not one: warding, then bitting

Real locks actually check compatibility in two stages, and so does `EDI` —
this isn't decoration, it's a confirmed architectural fact:

- **Warding (the keyway shape).** Before any tooth-by-tooth check, a real
  lock's keyway only physically admits blades of a broadly compatible
  profile. `Design$applicable_inference_class_names()`
  (`design_abstract.R:602-625`) documents exactly this: a cheap, coarse
  compatibility predicate over *normalized metadata* (response type,
  KK-matching capability, blocking, both censoring axes) —
  `is_inference_class_compatible_with_design_metadata()` — that runs before
  any candidate object is even constructed. This is the warding: it rules
  out wrong-shaped keys wholesale, with no per-tooth check yet.
- **Bitting (the pins).** Only once a key's blade shape passes the warding
  does its actual cut — the specific declared/required capabilities,
  checked via `capabilities()`/`supports()` — get compared pin-by-pin
  against what the lock exposes.

### The shear line: all-or-nothing, not partial credit

A pin-tumbler lock's plug turns only once *every* pin simultaneously
reaches the shear line — one wrong pin height and nothing turns, no partial
credit for getting most of them right. `get_effective_capabilities()`
(`inference_class_registry.R:1437`) computes a class's full capability set
from its registered components, and construction fails if *any* required
capability is missing from what the design exposes — not a majority, not a
best-effort partial fit. The shear line names that all-or-nothing moment.

### Not everything on either side is a tooth or a pin

Both a `Design` and an `Inference` class are internally built from many
parts, but only the subset each side *declares* is checked by the other
side. The real-world terms for "the rest" already exist:

- **The key's bow** — the handle you grip, never touched by the lock.
  Maps to internal `Inference`-side metadata like `likelihood_tier`, which
  picks which internal likelihood-based component a class is built from
  (confirmed: `get_effective_capabilities()` derives capabilities purely
  from registered components' `provides_capabilities` plus explicit
  `metadata$capabilities`/`excluded_capabilities` — `likelihood_tier` never
  enters that computation; it's used elsewhere for registry bookkeeping,
  not for cutting teeth).
- **The lock's housing** — the casing holding the pin chamber and springs,
  essential to the mechanism but not what determines whether a *specific*
  key fits. Maps to internal `Design`-side machinery (RNG/seed handling,
  tuning parameters, allocation internals) that a paired `Inference` class
  never inspects.

An author composing a new `Design` or `Inference` class is free to build it
out of whatever internal parts they like (bow/housing); only the
capabilities they explicitly declare enter the pairing contract with the
other side (teeth/pins, gated by warding then bitting, judged at the shear
line).

### Scope of the metaphor: eligibility, not analysis

**Turning the lock means the pairing is legal — it does not mean "here is
the one correct answer."** Once a key turns (construction succeeds), what
happens next — `compute_estimate()`, `compute_asymp_confidence_interval()`,
`compute_rand_two_sided_pval()` — is outside the metaphor entirely. Several
different keys can legitimately turn the same lock (several different
`Inference` classes can be legally applicable to one `Design`), and each
then does its own independent work once inside, the way different
investigators walking into the same room with different instruments
produce different measurements of one physical scene — not because the
room changed, but because asymptotic Wald, likelihood-ratio, bootstrap, and
randomization tests are genuinely different procedures with different
assumptions, not different readings of one true number.
`InferenceSuite$run_all_inference()` is the concrete proof this is a
feature, not a bug: it deliberately tries every key that turns the lock and
reports all their differing results side by side (plus a combined-evidence
summary), rather than treating any single "opening" as canonical. Any
placement of this metaphor (README, vignette) that implies otherwise is
wrong and should be corrected before it ships.

## History: how this metaphor was built

This plan started from a different question: `coin` (Conditional Inference
Procedures, on CRAN) describes itself as a "lego system" (Hothorn, Hornik,
van de Wiel & Zeileis, *"A Lego System for Conditional Inference"*, *The
American Statistician*, 2006 — cited verbatim in `EDI` already, at
`R/package_tests/testthat_bulk/helper-coin-cross-validation.R:4`), and the
question was whether that self-description also fit `EDI`. Every revision
below came from direct user pushback, not from a unilateral rewrite:

1. **"Two brick families" (rejected):** Design and Inference snap together
   the same way `coin`'s test-statistic/distribution pieces do. Rejected —
   lego bricks are symmetric and freely interchangeable; the Design/
   Inference relationship is asymmetric and gated by a compatibility check
   that can fail. Lock-and-key, not lego.
2. **Lego-for-components + lock-and-key-for-pairing:** kept "lego" for the
   internal composition inside a single class, reserved "lock-and-key" for
   the Design↔Inference pairing. Settled Design = lock / Inference = key
   via `run_all_inference()`'s one-lock-many-keys pattern; found the
   `likelihood_tier` example of an internal component that's real but never
   checked.
3. **Lego dropped entirely:** once the pairing is properly lock-and-key,
   there wasn't a clean second place left where "lego" earned its keep as a
   package self-description — one metaphor, not two, and the internal-
   composition fact is described in plain language instead (still in
   TODO-4's vignette copy, just unnamed).
4. **Named the non-tooth/non-pin parts:** "bow" (key) and "housing" (lock)
   — real locksmith terms, not invented ones, replacing vaguer "internal
   structure" language.
5. **Added warding and the shear line:** confirmed two real, distinct gates
   in the code (`applicable_inference_class_names()`'s coarse metadata
   predicate vs. `capabilities()`'s fine-grained check) and the all-or-
   nothing nature of the capability check, both previously unstated.
6. **Scoped "turning the lock" to eligibility only:** user asked, correctly,
   how different keys turning one lock could produce different "openings"
   if opening meant "the inference result." Resolution: it doesn't — the
   metaphor stops at construction succeeding; what a valid `Inference`
   class then computes is separate, and differs legitimately across
   classes the same way different investigators measure one scene
   differently.
7. **Dropped the missing-optional-package case:** an earlier draft
   considered mapping `unavailable_inference_classes_due_to_missing_packages()`
   (a class that's shape-compatible but whose optional R package isn't
   installed) to "a key that's the right cut but not yet in your keyring."
   **User decision: drop this from the analogy** — not used anywhere in
   this plan's shipped copy.

## Scope: everywhere (2026-09-08, user decision)

The lock-and-key metaphor goes on every documentation surface listed below,
including `DESCRIPTION`, with one standing caution: `EDI` has a CRAN
submission imminent as of 2026-08-30 (`project_cran_status` memory), and
CRAN reviewers do push back on promotional language in `Title`/
`Description` specifically. TODO-6 below keeps the `DESCRIPTION` wording
plain and factual — the metaphor cashed out as a description of the
architecture, not an ad slogan. Every other surface (README, vignette,
pkgdown, package-level help page, CITATION) has no such constraint.

## TODO

- [x] **TODO-1 (decision):** scope is every surface below, including
  `DESCRIPTION` (2026-09-08, user decision). Release placement decided
  2026-09-08 (user decision): **v1.1.0** — `release_v1_1_0.md → TODO-19`.
  Metaphor settled 2026-09-08 (user decisions, after multiple rounds of
  pushback — see History): lock-and-key only, Design = lock, Inference =
  key; "lego" dropped entirely; bow/housing name the non-tooth/non-pin
  parts; warding + shear line name the two-gate, all-or-nothing check;
  "turning the lock" is scoped to eligibility only, never to the analysis
  result; the missing-optional-package case is excluded from the analogy.

- [ ] **TODO-2 — `README.md`.** Add 1-2 sentences to the **Highlights** list
  (`README.md:29-31`, the "Designs and inference that match" bullet) or
  immediately after it. Top-level only — skip warding/shear-line/bow/
  housing detail here, that's the vignette's job (TODO-4). Example shape
  (adapt wording, don't paste verbatim):
  > **Lock-and-key pairing.** A `Design` is the lock — its randomization
  > scheme and response type fix which capabilities it offers. An
  > `Inference` class is the key — it only turns designs whose capabilities
  > match what it declares it needs, checked at construction time, never a
  > silent partial fit.

- [ ] **TODO-3 — pkgdown site.** `R/EDI/_pkgdown.yml`'s `home: description`
  block (the meta description search engines and AI retrieval show, per the
  comment above it citing `improve_discoverability.md`) stays keyword-first
  per that comment's own reasoning — don't compress it by trading a task
  keyword for the metaphor. Instead add the phrase as a **second, short
  tagline** elsewhere on the pkgdown home (e.g. a `home: sidebar` links
  block or a line in the site's index content), so the site carries both
  the keyword-dense meta description and the human-facing framing.

- [ ] **TODO-4 — `R/EDI/vignettes/extending-edi.Rmd`.** Highest-value
  placement, and the one that carries the full metaphor — the page is
  about extension authors implementing new Design/Inference classes,
  exactly where every piece of this (warding vs. bitting, the shear line,
  bow/housing, and the eligibility-only scope) matters. Add one framing
  passage at the top of the "How EDI classes are built" section
  (`extending-edi.Rmd:28-34`), before the existing "Both the `Inference*`
  and `Design*` hierarchies are shallow and component-based" sentence,
  covering:
  1. Design = lock, Inference = key, settled by `run_all_inference()`'s
     one-lock-many-keys pattern.
  2. Two gates: warding (coarse metadata compatibility, checked with no
     object constructed) then bitting (the fine capability check).
  3. The shear line: every declared capability must align simultaneously;
     no partial credit.
  4. Bow/housing: internal parts (e.g. `likelihood_tier`) that are real but
     never inspected by the other side — only declared capabilities enter
     the contract.
  5. Scope: turning the lock means the pairing is legal, not that there's
     one correct answer — different valid `Inference` classes do
     independent work once inside, which is why `run_all_inference()`
     reports multiple differing results by design, not as a caveat.
  Write it as connected prose, not a bulleted metaphor glossary — this is
  the one placement where the full picture belongs, but it should still
  read as one coherent passage an extension author would actually want to
  read.

- [ ] **TODO-5 — `R/EDI/R/EDI.R` package-level `@name EDI` roxygen block**
  (`EDI.R:1-8`), which renders as the `?EDI` / `library(help = "EDI")`
  overview page. Add one sentence naming the lock-and-key framing
  (top-level only, same scope as TODO-2) — this is prose documentation, not
  a metadata field, so it carries none of `DESCRIPTION`'s CRAN-style
  constraint. Keep it consistent with the README/vignette wording so the
  two don't drift. **Parse-check only after editing**
  (`parse("R/EDI/R/EDI.R")` or an equivalent syntax check) — do not run
  `roxygenize()`/`devtools::document()` as part of this batch; that's a
  separate, deliberate step per `feedback_no_interim_roxygenize` memory,
  run once after all doc TODOs in this plan are done, not per-file.

- [ ] **TODO-6 — `R/EDI/DESCRIPTION` `Description:` field.** Append one
  plain, factual clause to the existing paragraph (not a replacement),
  naming the capability check only — e.g. append something like: "Design
  and inference objects are paired by an explicit capability check, so an
  inference procedure is only usable with designs whose randomization
  scheme and response type actually support it." Read as a factual
  architecture statement, not a slogan. If a CRAN reviewer flags it on
  submission, drop this clause first (lowest cost of the six placements to
  revert) rather than treat the rejection as blocking the other five.

- [ ] **TODO-7 — `CITATION.cff` / `R/EDI/inst/CITATION`.** Optional, lowest
  priority: check whether either file has a free-text abstract/description
  field where a one-clause mention fits without disrupting the citation
  metadata format each tool (GitHub's citation UI, `citation("EDI")`)
  expects. Skip if there's no natural slot — don't force it into a field
  that's supposed to be pure bibliographic metadata.

- [ ] **TODO-8 — `future_release_plans` placement.** Recorded (this
  session): `release_v1_1_0.md → TODO-19` (Implementation TODOs list) and
  `_master.md`'s Phase 3 (Documentation), item 4. No further action needed
  here — this TODO exists so the plan's own checklist reflects that the
  release-bookkeeping half of the work is already done, distinct from the
  TODO-2..7 prose edits which are not.

## Verification

Since this plan touches only prose (`.md`, `.Rmd`, `.yml`), verification is
read-through, not `R CMD check`:

1. `Rscript -e 'knitr::knit("R/EDI/vignettes/extending-edi.Rmd", quiet = TRUE)'`
   after TODO-4 (or `rmarkdown::render` if `knitr::knit` alone doesn't catch
   an Rmd syntax error) — confirms the added passage doesn't break the
   vignette's knit. This is a docs-only knit check, not a package build/
   install, so it does not fall under the `R CMD INSTALL`/`load_all`
   restriction in `CLAUDE.md`.
2. Read `README.md`'s rendered Markdown preview (or just re-read the diff)
   to confirm the new Highlights bullet doesn't push the bullet list past a
   reasonable length or duplicate the existing "Designs and inference that
   match" bullet's content.
3. Re-verify the `likelihood_tier` claim still holds before TODO-4 ships (it
   could move if an unrelated plan touches it first): confirm
   `get_effective_capabilities()` in `inference_class_registry.R` still
   derives capabilities purely from components'
   `provides_capabilities`/`metadata$capabilities`/`excluded_capabilities`,
   with no reference to `likelihood_tier`.
4. Re-verify the warding claim: confirm
   `Design$applicable_inference_class_names()`
   (`R/EDI/R/design_abstract.R:602-625`) still documents a metadata-only
   predicate that constructs no candidate object, separate from
   `capabilities()`/`supports()`.
5. After TODO-5 (`EDI.R`) and TODO-6 (`DESCRIPTION`): `parse("R/EDI/R/EDI.R")`
   and a plain read-through of the edited `DESCRIPTION` paragraph for grammar
   — no `roxygenize()`, no `R CMD INSTALL`/`load_all()`, no package rebuild
   of any kind for this plan (none of its edits require one; see `CLAUDE.md`).
6. Grep-sweep once all TODOs are checked:
   `grep -rin "lego\|lock-and-key\|lock and key" README.md R/EDI/DESCRIPTION
   R/EDI/R/EDI.R R/EDI/vignettes/extending-edi.Rmd R/EDI/_pkgdown.yml` —
   the "lego" branch should come back **empty** everywhere; "Design" should
   always read as the lock and "Inference" always as the key; nothing
   duplicated within a single file.
7. Read TODO-4's finished passage once more against the "Scope of the
   metaphor" section above and confirm it does not, even by implication,
   suggest that a successful pairing produces a single canonical result —
   this was flagged directly by the user and is the easiest part of the
   metaphor to accidentally overstate.
