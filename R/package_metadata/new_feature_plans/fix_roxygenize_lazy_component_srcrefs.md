# Fix: `roxygenize()` aborts on lazy-loaded inference mixin components

> **Depends on:** none (fix shipped). Its remaining `R CMD check` TODO should run after any large doc batch; re-verify at `fix_inference_hierarchy.md` Base Deletion (Rd-home note). (Global ordering: see `_master.md`.)

## Status

**Fixed.** `Rscript R/fast_roxygenize.R` previously aborted the entire package-wide
`roxygen2::roxygenize()` run with:

```
Error:
! R6 class <InferenceAllKKWilcoxIVWC> lacks source references.
```

This was not a defect specific to `InferenceAllKKWilcoxIVWC` — it was the first class
`roxygenize()` happened to process that tripped a systemic issue affecting a large
fraction of the `Inference*` class hierarchy (see Scope below).

The fallback approach described below (patch `fast_roxygenize.R`'s R6 method
extraction to drop lazy-component stub methods before roxygen2's srcref check) has
been implemented and verified: `fast_roxygenize.R` now runs to completion (exit code
0), regenerating all 330 `man/*.Rd` files with no fatal error, and `InferenceRandBootstrap.Rd`
(the component's real owning class) correctly retains the full documentation for the
methods that were previously crashing the build as undocumented stubs on composing
classes. The **primary approach** (copying a real srcref onto each stub) was
investigated and rejected: `combine_component_slot()` runs at class-definition time
(package load time), so resolving a real srcref there via `load_inference_component()`
would force every lazy component to eagerly load for every class that uses it on every
package load — defeating the entire purpose of lazy loading. The implemented fix
(described in "Fallback approach" below, now the primary/only fix) makes no runtime
behavior changes at all; it only touches the doc-generation tool.

Remaining known (pre-existing, unrelated) roxygen2 warnings after this fix — undocumented
methods and `@param`/method-signature mismatches on classes composed from bare-list
"mixin" `public = list(...)` objects (e.g. `inference_ordinal_adj_cat_logit.R`,
`inference_custom_extensions.R`) — are a separate, already-acknowledged limitation
(see the "KLUDGE" comment near the bottom of `fast_roxygenize.R`) and are not addressed
here.

## Root cause

1. `roxygen2:::extract_r6_methods()` calls `utils::getSrcref(m)` on every public method
   function `m` of every R6 class it documents, and calls `cli::cli_abort()`
   (terminating the whole `roxygenize()` run, not just that class) the moment any
   single method lacks a `srcref` attribute.

2. EDI's `Inference*` class hierarchy is composed from reusable "mixin components"
   via `define_inference_class()` (`R/mixin_contracts.R:2585`), which merges each
   component's `public`/`private` method lists (`assemble_public()`/
   `assemble_private()`) before calling `R6::R6Class()` itself.

3. Most components (39 of ~41 entries in `EDI_COMPONENT_SPECS`,
   `R/mixin_contracts.R:264`) are registered with `load_policy = "lazy"`. For a lazy
   component, `combine_component_slot()` does **not** splice in the component's real
   method functions; instead it calls `lazy_component_public_stub()` /
   `lazy_component_private_stub()` (`R/mixin_contracts.R:2000-2018`), which build a
   *placeholder* dispatch function per method name:

   ```r
   lazy_component_public_stub = function(component_name, method_name) {
       fn = function(...) NULL
       body(fn) = substitute({
           install_lazy_inference_component(self, private, class(self)[1L], .component_name)
           self[[.method_name]](...)
       }, list(.component_name = component_name, .method_name = method_name))
       attr(fn, "inference_lazy_component_stub") = component_name
       fn
   }
   ```

4. **`body(fn) <- substitute(...)` strips `fn`'s `srcref` attribute.** Verified
   directly:

   ```r
   > options(keep.source = TRUE)
   > fn = function(...) NULL
   > is.null(attr(fn, "srcref"))
   [1] FALSE
   > body(fn) = substitute({ x + 1 }, list())
   > is.null(attr(fn, "srcref"))
   [1] TRUE
   ```

   R silently drops `srcref` whenever a function's body is replaced (the old srcref
   text would no longer match the new body), and `function(...) NULL` never had a
   *useful* srcref to begin with even before replacement — it is a throwaway skeleton
   the stub generator reuses for every method name.

5. `InferenceAllKKWilcoxIVWC` (`R/inference_all_KK_wilcox_ivwc.R:408`) composes
   `components = c("RandomizationBootstrap", "Wald", "KKWilcoxIVWC")`.
   `RandomizationBootstrap` is `load_policy = "lazy"`
   (`R/mixin_contracts.R:373`), and several of its methods
   (e.g. `compute_rand_bootstrap_two_sided_pval`) are not in this class's
   `overrides$public`, so they end up in the final class as lazy stubs with no
   `srcref` — the first one `extract_r6_methods()` encounters when it processes this
   class aborts the whole run.

## Scope: this is not a one-class fix

- 39 of ~41 registered components in `EDI_COMPONENT_SPECS` use
  `load_policy = "lazy"`.
- 26 `define_inference_class(...)` call sites across 24 files compose classes from
  these components (`grep -rc "define_inference_class(" R/EDI/R/*.R`).
- Any such class that (a) includes at least one lazy component and (b) does not
  override *every one* of that component's provided methods will contain at least one
  srcref-less stub method, and will crash `roxygenize()` the moment it's processed.
  `InferenceAllKKWilcoxIVWC` is simply alphabetically/dependency-order first to be
  hit — fixing only that one class (e.g. by overriding every lazy method it
  inherits) would just move the crash to the next affected class.
- The fix must therefore live in the lazy-stub-generation mechanism itself
  (`lazy_component_public_stub()` / `lazy_component_private_stub()`), not in any
  individual class file.

## Proposed fix

**Primary approach — attach a real srcref to each stub, copied from the component's
actual (non-stub) method definition.**

Every lazy component's *real* implementation already exists somewhere with a proper
srcref — in the eagerly-defined class/component that "owns" it (e.g.
`RandomizationBootstrap`'s real `compute_rand_bootstrap_two_sided_pval` lives, with a
normal parsed-from-source function body, in whatever component/class actually
implements it — trace via `component$source_name` / `component$file` in
`EDI_COMPONENT_SPECS`). Rather than fabricating a synthetic srcref, look up that real
function object when building the stub and copy its `srcref` (and ideally its
`srcfile`) onto the stub function after `body(fn) <- substitute(...)`:

```r
lazy_component_public_stub = function(component_name, method_name, real_fn = NULL) {
    fn = function(...) NULL
    body(fn) = substitute({
        install_lazy_inference_component(self, private, class(self)[1L], .component_name)
        self[[.method_name]](...)
    }, list(.component_name = component_name, .method_name = method_name))
    if (!is.null(real_fn) && !is.null(attr(real_fn, "srcref"))) {
        attr(fn, "srcref") = attr(real_fn, "srcref")
    }
    attr(fn, "inference_lazy_component_stub") = component_name
    fn
}
```

`lazy_component_entries()` (`R/mixin_contracts.R:2020`) is the caller; it has access
to `component` and can resolve `real_fn` from wherever the component's real
(non-lazy-loaded) method list is registered — this needs a short investigation into
how `install_lazy_inference_component()` locates the real implementation at runtime,
so the same lookup can be reused at stub-construction time.

This makes roxygen2 attribute the stub method to the file/location where its *real*
implementation lives (e.g. `inference_all_abstract_rand_bootstrap.R`), which is
exactly correct: that is where the method's actual documented behavior is defined, and
`fast_roxygenize.R`'s existing `block_file`-matching logic
(`patched_extract_r6_methods()`, added for the unrelated-but-similar "mixin methods
sort into the wrong class" problem) should already do the right thing once a valid
srcref exists — filtering the stub out of `InferenceAllKKWilcoxIVWC`'s own method list
(since its file won't match `inference_all_KK_wilcox_ivwc.R`) and letting it surface,
correctly, as an inherited/shared method instead. This needs to be verified once the
srcref is attached, not assumed.

**Fallback approach — patch `fast_roxygenize.R` to tolerate srcref-less stubs.**

If copying a real srcref proves impractical (e.g. the real implementation is itself
assembled dynamically, or the mapping from component to "real" function isn't a clean
1:1 lookup), patch `fast_roxygenize.R`'s R6-doc-extraction pipeline instead — similar
in spirit to its existing `object_defaults.r6class` / `extract_r6_methods` monkey-patches:
detect `attr(m, "inference_lazy_component_stub")` and either (a) skip the srcref check
entirely for tagged stubs (dropping them from the documented method list, since they
carry no real documentation value of their own — the "real" method should already be
documented on whichever component/class truly owns it), or (b) synthesize a
placeholder `srcref` (via `srcref(srcfilecopy(...), ...)`) pointing at
`R/mixin_contracts.R`'s stub generator itself, tagged clearly so it's obviously not
the real implementation location. This is lower-risk (touches only the doc-generation
tool, not runtime package behavior) but produces less accurate provenance in the
generated docs, and doesn't fix the underlying srcref loss for any other tooling that
might introspect these classes (e.g. `sinew`, IDE tooltips, other Rd generators).

**Outcome:** the primary approach was rejected after investigation (it would force
eager loading of every lazy component at package-load time — see Status above). The
fallback approach was implemented instead, in `strip_lazy_component_stubs()` /
`patched_extract_r6_methods()` in `R/fast_roxygenize.R`: before calling roxygen2's own
`extract_r6_methods()`, it temporarily removes any public method tagged
`attr(fn, "inference_lazy_component_stub")` from the R6 generator's `public_methods`
(restored via `on.exit()` immediately after), so roxygen2 never sees — and never
srcref-checks — the stub. This is lower-risk than it first appeared: it touches only
the documentation tool, and the stub's real implementation is still fully documented
wherever the owning component/class actually defines it.

## Verification plan (completed)

1. **Done.** Implemented the fix in `R/fast_roxygenize.R` (not `R/mixin_contracts.R`
   — see Outcome above for why the fix moved to the doc-tooling layer).
2. **Done.** `Rscript R/fast_roxygenize.R` completes with exit code 0 and no
   `lacks source references` abort; it writes/updates 330 `man/*.Rd` files.
3. **Done.** Spot-checked `InferenceAllKKWilcoxIVWC.Rd` (correctly lists only its own
   literally-defined methods plus `clone()`; the lazy `RandomizationBootstrap`-provided
   methods it inherits, e.g. `compute_rand_bootstrap_two_sided_pval`, are absent from
   its own page but fully documented on `InferenceRandBootstrap.Rd`, their real owning
   class) and ran `tools::checkRd()` across all 61 changed `.Rd` files — zero
   severity ≥3 (error-level) issues; remaining issues are pre-existing severity -1
   style notes (non-ASCII em-dashes, already the repo's established convention).
   (Forward-looking note, 2026-08-13: this resolution leans on
   `InferenceRandBootstrap.Rd` as the lazy-component methods' documentation
   home. `fix_inference_hierarchy.md`'s Base Deletion removes the
   `InferenceRandBootstrap` generator — and the other algorithmic bases whose
   Rd pages currently host component-method docs — so each component's public
   methods will need a new declared owning page (component-level docs or a
   designated surviving class) at that point; re-run this plan's spot-checks
   when Base Deletion lands so the docs don't silently vanish.)
4. **Deferred.** `R CMD check` was not run as part of this fix (out of scope for the
   documentation-content TODOs this was blocking); recommended before the next
   release.
5. **Done.** Re-ran `fast_roxygenize.R` after the accumulated `fix_documentation.md`
   roxygen-source edits; it regenerated every previously hand-verified `.Rd` file (the
   ones hand-authored before the "stop hand-writing `.Rd` files" instruction took
   effect) and all content — titles, `\details`, `\references`, `\eqn`/`\deqn` math —
   came through intact (spot-checked `DesignFixedAOptimal.Rd`). Two stale `.Rd` files
   with no corresponding roxygen block in their source
   (`InferenceAbstractKKWilcoxBaseIVWC.Rd`, `InferenceCountCompositeLikelihood.Rd`)
   were deleted by roxygen2 as part of normal stale-file cleanup — unrelated to this
   fix and not a regression (these classes have no `@name`/`@title`/roxygen comment
   block in source at all).

## Remaining TODOs

- [ ] Run full `R CMD check` (deferred from the verification plan's item 4,
  where it was noted as "recommended before the next release" but never
  scheduled) — the fix itself was verified only via `fast_roxygenize.R`
  completing plus `tools::checkRd()` on the changed `.Rd` files, so a full
  check has still never been run over the regenerated documentation set.

## Relationship to `fix_documentation.md`

This is a hard prerequisite for *reliably* finishing `fix_documentation.md`: as long
as `roxygenize()` cannot run, every edit there is verified by hand-authoring/checking
`.Rd` files (error-prone, and already skipped entirely for most entries per an
explicit instruction to stop hand-writing `.Rd` files) rather than by the real
generator. It does not block making roxygen-source edits (those can continue), but it
does block confirming those edits actually produce correct `.Rd` output, and it
blocks documenting any `Inference*` class built via `define_inference_class()` with a
lazy component at all, since `roxygenize()` cannot even reach later classes once it
aborts on an earlier one.
