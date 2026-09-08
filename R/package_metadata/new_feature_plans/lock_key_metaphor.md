# The "Lock-and-Key" Metaphor for the Design/Inference Pairing

> **Depends on:** none. Pure documentation/naming; touches no code, no public
> API, no tests. Not gated by any other plan and gates nothing downstream.

Date: 2026-09-08 (started as a "lego system" framing; went through several
rounds of narrowing and refinement same day, all user decisions — see
"History" below; this file was `lego_metaphor.md` until the "lego" half was
dropped entirely)

> **Release placement (2026-09-08, user decision): v1.1.0.**
> `../future_release_plans/release_v1_1_0.md → TODO-19`. Recorded in
> `_master.md`'s Phase 3 (Documentation) as item 4.

## The metaphor: a key-operated measuring instrument

A `Design` is the **base of a measuring instrument**: built once, holding
the real thing being measured (the actual randomized experiment — response
data, randomization scheme, blocking structure) — like a meter's mechanism
already wired to what it measures. An `Inference` class is the **key**: it
has to physically fit the instrument (its declared required capabilities —
`supports(capability)` / `capabilities()`, `R/EDI/R/design_abstract.R:599`,
`R/EDI/R/inference_all_abstract.R:175` — are its cut teeth, checked against
the instrument's pins), and *turning it does two things at once*, not one:

1. **Gates.** The key either fits or it doesn't — checked at construction
   (`InferenceContinOLS$new(des)`), fails fast, no silent partial fit.
2. **Configures.** A fitting key doesn't just unlock access to something you
   then go measure separately — inserting it *assembles the machine*. The
   `design` is wired into the `Inference` object as its data source, and the
   resulting object *is* the instrument; calling `compute_estimate()`
   afterward is that assembled machine actually running. Which key you
   insert determines which computation path the fused machine reports
   through — asymptotic Wald, likelihood-ratio, bootstrap, randomization
   are different circuits through the same underlying instrument, not
   different tools brought in afterward.

This is a real, common device category, not an invented one: a **keyed
selector-switch meter** — a single instrument where a key is inserted and
turned to select which register or measurement channel it reports (a
multi-tariff meter is the everyday example: one meter, one key, and the
reading it produces depends on which key/position was used, because each
key completes a different circuit path through the same physical
mechanism, not because the meter is unreliable).

This single mechanism explains something the earlier "lock you walk through
into a room" version of this metaphor couldn't: **why different valid keys
report different, equally legitimate numbers from the same design.** They
aren't different investigators separately measuring one fixed room after
the door opens (that required a second, bolted-on metaphor). They're
different circuits through one assembled instrument — the same mechanism
that gates compatibility also determines what gets computed, because
gating and configuring are the same act of the key turning, not two
sequential acts.

### Two gates, not one: warding, then bitting

Real locks check compatibility in two stages, confirmed in the code:

- **Warding (the keyway shape).** `Design$applicable_inference_class_names()`
  (`design_abstract.R:602-625`) is a cheap, coarse compatibility predicate
  over *normalized metadata* (response type, KK-matching capability,
  blocking, both censoring axes) —
  `is_inference_class_compatible_with_design_metadata()` — that runs before
  any candidate object is even constructed. This rules out wrong-shaped
  keys wholesale, with no per-tooth check yet — the keyway only physically
  admits blades of a broadly compatible profile.
- **Bitting (the pins).** Only once a key's blade shape passes the warding
  does its actual cut — the specific declared/required capabilities,
  checked via `capabilities()`/`supports()` — get compared pin-by-pin
  against what the instrument exposes.

### The shear line: all-or-nothing, not partial credit

A pin-tumbler lock's plug turns only once *every* pin simultaneously
reaches the shear line — one wrong pin height and nothing turns, no partial
credit. `get_effective_capabilities()` (`inference_class_registry.R:1437`)
computes a class's full capability set from its registered components, and
construction fails if *any* required capability is missing from what the
design exposes.

### Not everything on either side is a tooth or a pin

Both a `Design` and an `Inference` class are internally built from many
parts, but only the subset each side *declares* is checked, or wired into
the assembled machine's circuit. The real-world terms for "the rest"
already exist:

- **The key's bow** — the handle you grip, never part of the circuit.
  Maps to internal `Inference`-side metadata like `likelihood_tier`, which
  picks which internal likelihood-based component a class is built from
  (confirmed: `get_effective_capabilities()` derives capabilities purely
  from registered components' `provides_capabilities` plus explicit
  `metadata$capabilities`/`excluded_capabilities` — `likelihood_tier` never
  enters that computation; it's used elsewhere for registry bookkeeping,
  not for cutting teeth or wiring the circuit).
- **The instrument's housing** — the casing holding the pin chamber and
  springs, essential to the mechanism but not itself part of any specific
  key's circuit. Maps to internal `Design`-side machinery (RNG/seed
  handling, tuning parameters, allocation internals) that a paired
  `Inference` class never inspects or wires into.

An author composing a new `Design` or `Inference` class is free to build it
out of whatever internal parts they like (bow/housing); only the
capabilities they explicitly declare enter the pairing contract and the
resulting computation (teeth/pins, gated by warding then bitting, judged at
the shear line, wired into the assembled machine).

## Which side is the lock, and which is the key

Settled by three independent facts, not an arbitrary label:

1. **The discovery API lives on `Design`, not `Inference`.**
   `design$applicable_inference_class_names()` exists; there is no reverse
   method on `Inference` ("which designs am I compatible with") — confirmed
   by grep, no such method exists anywhere in the inference hierarchy. You
   ask a *lock* which keys fit it (a locksmith reads the lock's pins to cut
   or select a matching key); you don't normally ask a key which locks it
   opens. The object being queried is the fixed one: `Design`.
2. **Usage asymmetry.** A `Design` is expensive and fixed — real subjects,
   real randomization already run, can't be redone — like a lock bolted to
   a door. An `Inference` class is cheap and interchangeable — you can try
   a dozen against one dataset for free, like keys on a keyring.
   `InferenceSuite$run_all_inference()` takes *one* fixed `Design` and
   tries *every* eligible `Inference` class against it, keeping whichever
   fit — "one lock, many candidate keys tried in sequence," the far more
   common real-world image than the reverse (one key tried in every door on
   the street, which reads as a burglar, not a locksmith).
3. **A real, considered counter-argument, and why it doesn't win.**
   `Inference$new(design)` passes the design *into* the inference
   constructor, which could read as "the key (design) is inserted into the
   lock (inference)." This doesn't actually favor the reverse assignment
   once the metaphor is the assembled instrument (above), not a static
   lock: `Inference$new(design)` isn't "insert key into complete lock," it
   is **assembly** — the design is wired into the inference object as the
   instrument's data source, and the resulting object is the machine. The
   key/lock roles (facts 1 and 2) are about which side gates and which side
   is checked against, not about which R6 constructor argument order was
   used, which is ordinary R6 idiom (the "analysis" object is always
   constructed by feeding it the "data" object) rather than a semantic
   signal.

**Design = lock (the instrument's base), Inference = key.**

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
   the Design↔Inference pairing.
3. **Lego dropped entirely:** once the pairing is properly lock-and-key,
   there wasn't a clean second place left where "lego" earned its keep as a
   package self-description.
4. **Named the non-tooth/non-pin parts:** "bow" (key) and "housing" (lock)
   — real locksmith terms, replacing vaguer "internal structure" language.
5. **Added warding and the shear line:** confirmed two real, distinct gates
   in the code and the all-or-nothing nature of the capability check.
6. **First attempt at "different keys, different results":** user asked
   how different keys turning one lock could produce different "openings"
   if opening meant "the inference result." First resolution: scope
   "turning the lock" to eligibility only, and describe the actual
   computation with a second metaphor (different investigators measuring
   one room with different instruments).
7. **Dropped the missing-optional-package case:** an earlier draft
   considered `unavailable_inference_classes_due_to_missing_packages()` as
   "a key that's the right cut but not on your keyring yet." **User
   decision: dropped**, not used anywhere in this plan's shipped copy.
8. **Searched for a real device, not an invented one:** user asked whether
   any real device works like "a key in a lock on a measuring device, where
   the device measures different things based on the key." Found the real
   category: keyed selector-switch meters / multi-tariff meters (e.g. a
   taxi meter, an Economy 7 electricity meter, or an off-the-shelf
   key-operated am-meter selector switch) — one instrument, one key, and
   the register reported depends on which key/position was used.
9. **Final resolution — the assembled-instrument framing (this file):**
   user pointed out that in the actual package, `Design` is *injected into*
   `Inference`, and the two together *operate the machine* — not "unlock,
   then separately go measure." This replaces step 6's bolted-on
   investigator metaphor entirely: turning the key both gates (the
   capability check) and configures (which circuit/computation the
   assembled machine runs), which is the same mechanism as the keyed
   selector-switch meter found in step 8, now grounded in the actual
   `Inference$new(design)` assembly step rather than a separate image.

## Scope: everywhere (2026-09-08, user decision)

The lock-and-key metaphor goes on every documentation surface listed below,
including `DESCRIPTION`, with one standing caution: `EDI` has a CRAN
submission imminent as of 2026-08-30 (`project_cran_status` memory), and
CRAN reviewers do push back on promotional language in `Title`/
`Description` specifically. TODO-6 below keeps the `DESCRIPTION` wording
plain and factual. Every other surface (README, vignette, pkgdown,
package-level help page, CITATION) has no such constraint.

## TODO

- [x] **TODO-1 (decision):** scope is every surface below, including
  `DESCRIPTION` (2026-09-08, user decision). Release placement decided
  2026-09-08 (user decision): **v1.1.0** — `release_v1_1_0.md → TODO-19`.
  Metaphor settled 2026-09-08 (user decisions, after nine rounds of
  pushback — see History): **Design = lock/instrument base, Inference =
  key**; "lego" dropped entirely; bow/housing name the non-tooth/non-pin
  parts; warding + shear line name the two-gate, all-or-nothing check;
  turning the key both gates *and* configures — the assembled-instrument
  framing, not "unlock a door, then separately investigate a room"; the
  missing-optional-package case is excluded.

- [ ] **TODO-2 — `README.md`.** Add 1-2 sentences to the **Highlights** list
  (`README.md:29-31`, the "Designs and inference that match" bullet) or
  immediately after it. Top-level only — skip warding/shear-line/bow/
  housing detail here, that's the vignette's job (TODO-4). Example shape
  (adapt wording, don't paste verbatim):
  > **A key-operated instrument.** A `Design` is the base of a measuring
  > instrument — its randomization scheme and response type fix which
  > capabilities it offers. An `Inference` class is the key: it only fits
  > designs whose capabilities match what it declares it needs, and once it
  > turns, it configures which computation the assembled instrument runs —
  > asymptotic, likelihood-based, bootstrap, and randomization procedures
  > are different circuits through the same underlying design, not
  > different guesses at one hidden number.

- [ ] **TODO-3 — pkgdown site.** `R/EDI/_pkgdown.yml`'s `home: description`
  block (the meta description search engines and AI retrieval show, per the
  comment above it citing `improve_discoverability.md`) stays keyword-first
  per that comment's own reasoning — don't compress it by trading a task
  keyword for the metaphor. Instead add the phrase as a **second, short
  tagline** elsewhere on the pkgdown home (e.g. a `home: sidebar` links
  block or a line in the site's index content).

- [ ] **TODO-4 — `R/EDI/vignettes/extending-edi.Rmd`.** Highest-value
  placement, and the one that carries the full metaphor — the page is
  about extension authors implementing new Design/Inference classes,
  exactly where every piece of this matters. Add one framing passage at the
  top of the "How EDI classes are built" section (`extending-edi.Rmd:
  28-34`), before the existing "Both the `Inference*` and `Design*`
  hierarchies are shallow and component-based" sentence, covering:
  1. Design = the base of a measuring instrument, Inference = the key,
     settled by the discovery-API asymmetry and `run_all_inference()`'s
     one-instrument-many-keys pattern.
  2. Two gates: warding (coarse metadata compatibility, checked with no
     object constructed) then bitting (the fine capability check), judged
     at the shear line (all declared capabilities must align
     simultaneously, no partial credit).
  3. Turning the key does two things at once: it gates (construction fails
     fast if it doesn't fit) and it configures — `Inference$new(design)`
     assembles the machine, and which key was used determines which
     computation (`compute_estimate()`, `compute_asymp_confidence_interval()`,
     `compute_rand_two_sided_pval()`, …) the assembled instrument runs.
  4. Bow/housing: internal parts (e.g. `likelihood_tier`) that are real but
     never inspected or wired into the circuit — only declared capabilities
     enter the contract.
  5. Why different valid keys report different numbers from the same
     design: they're different circuits through one instrument (the same
     mechanism that gates compatibility also configures computation), not
     different tools brought in afterward to inspect one fixed room. This
     is why `run_all_inference()` deliberately reports several differing,
     independently valid results rather than a single "correct" number.
  Write it as connected prose, not a bulleted metaphor glossary — this is
  the one placement where the full picture belongs, but it should read as
  one coherent passage an extension author would actually want to read.

- [ ] **TODO-5 — `R/EDI/R/EDI.R` package-level `@name EDI` roxygen block**
  (`EDI.R:1-8`), which renders as the `?EDI` / `library(help = "EDI")`
  overview page. Add one sentence naming the key-operated-instrument framing
  (top-level only, same scope as TODO-2) — this is prose documentation, not
  a metadata field, so it carries none of `DESCRIPTION`'s CRAN-style
  constraint. Keep it consistent with the README/vignette wording. **Parse-
  check only after editing** (`parse("R/EDI/R/EDI.R")` or an equivalent
  syntax check) — do not run `roxygenize()`/`devtools::document()` as part
  of this batch; that's a separate, deliberate step per
  `feedback_no_interim_roxygenize` memory, run once after all doc TODOs in
  this plan are done, not per-file.

- [ ] **TODO-6 — `R/EDI/DESCRIPTION` `Description:` field.** Append one
  plain, factual clause to the existing paragraph (not a replacement),
  naming the capability check only — e.g. append something like: "Design
  and inference objects are paired by an explicit capability check, so an
  inference procedure is only usable with designs whose randomization
  scheme and response type actually support it." Read as a factual
  architecture statement, not a slogan; skip the "assembled instrument"/
  circuit language here entirely, it's more than this field needs. If a
  CRAN reviewer flags it on submission, drop this clause first (lowest cost
  of the six placements to revert) rather than treat the rejection as
  blocking the other five.

- [ ] **TODO-7 — `CITATION.cff` / `R/EDI/inst/CITATION`.** Optional, lowest
  priority: check whether either file has a free-text abstract/description
  field where a one-clause mention fits without disrupting the citation
  metadata format each tool (GitHub's citation UI, `citation("EDI")`)
  expects. Skip if there's no natural slot.

- [ ] **TODO-8 — `future_release_plans` placement.** Recorded (this
  session): `release_v1_1_0.md → TODO-19` (Implementation TODOs list) and
  `_master.md`'s Phase 3 (Documentation), item 4. No further action needed
  here.

## Verification

Since this plan touches only prose (`.md`, `.Rmd`, `.yml`), verification is
read-through, not `R CMD check`:

1. `Rscript -e 'knitr::knit("R/EDI/vignettes/extending-edi.Rmd", quiet = TRUE)'`
   after TODO-4 (or `rmarkdown::render` if `knitr::knit` alone doesn't catch
   an Rmd syntax error) — no package build/install, does not fall under the
   `R CMD INSTALL`/`load_all` restriction in `CLAUDE.md`.
2. Read `README.md`'s rendered Markdown preview (or just re-read the diff)
   to confirm the new Highlights bullet doesn't push the bullet list past a
   reasonable length or duplicate the existing "Designs and inference that
   match" bullet's content.
3. Re-verify the `likelihood_tier` claim still holds before TODO-4 ships:
   confirm `get_effective_capabilities()` in `inference_class_registry.R`
   still derives capabilities purely from components'
   `provides_capabilities`/`metadata$capabilities`/`excluded_capabilities`,
   with no reference to `likelihood_tier`.
4. Re-verify the warding claim: confirm
   `Design$applicable_inference_class_names()`
   (`R/EDI/R/design_abstract.R:602-625`) still documents a metadata-only
   predicate that constructs no candidate object, separate from
   `capabilities()`/`supports()`. Re-confirm no reverse discovery method
   exists on `Inference` (`grep -rn "applicable_design\|legal_designs\|compatible_designs" R/EDI/R/inference_*.R` should return nothing).
5. After TODO-5 (`EDI.R`) and TODO-6 (`DESCRIPTION`): `parse("R/EDI/R/EDI.R")`
   and a plain read-through of the edited `DESCRIPTION` paragraph for
   grammar — no `roxygenize()`, no `R CMD INSTALL`/`load_all()`, no package
   rebuild of any kind for this plan.
6. Grep-sweep once all TODOs are checked:
   `grep -rin "lego\|lock-and-key\|lock and key" README.md R/EDI/DESCRIPTION
   R/EDI/R/EDI.R R/EDI/vignettes/extending-edi.Rmd R/EDI/_pkgdown.yml` —
   the "lego" branch should come back **empty** everywhere; "Design" should
   always read as the lock/instrument and "Inference" always as the key.
7. Read TODO-4's finished passage against the "different valid keys report
   different numbers" explanation above and confirm it grounds that fact in
   the assembled-instrument mechanism (different circuits, same machine),
   not in a separate bolted-on image (investigators, cameras) — that
   fallback was explicitly replaced, not layered on top of.
