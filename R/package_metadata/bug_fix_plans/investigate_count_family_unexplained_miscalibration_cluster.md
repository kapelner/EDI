# Investigation: Count-Family Classes With Confirmed-Real, Unexplained Miscalibration — Ruled Out From Every Known Mechanism So Far

> **Depends on:** none. (Global ordering: see `_master.md`.) Slated for
> `release_v1_0_5.md → TODO-31`. Surfaced 2026-09-24 as a byproduct of three
> other investigations (`guard_unguarded_information_inverse.md`/TODO-4,
> `bootstrap_worker_stale_design_matrix.md`/TODO-28-29) that each explicitly
> ruled these classes OUT from the mechanism they were chasing, leaving the
> underlying miscalibration itself un-investigated and un-homed. **This is
> an open investigation, not a confirmed bug** — do not treat "ruled out
> from mechanism X" as "root-caused"; none of the four classes below has a
> confirmed root cause yet.

## Why this file exists

Four count-family classes each show broad, real, audit-flagged
miscalibration across many method families simultaneously. Each was checked
against a specific candidate shared mechanism (the unguarded-information-
matrix-inverse bug, the stale-`cached_design_matrix` reused-worker bug) and
confirmed **not** to share it — but the underlying cause of each class's own
miscalibration was never chased further, because ruling out one hypothesis
was outside the scope of the investigation that found it. Without this file,
these four findings would exist only as asides inside TODO-4's and TODO-29's
prose, with no TODO number and no plan file — easy to lose track of.

## The four findings

### 1. `InferenceCountPoisson` — 16 families flagged, unidentified cause

Surfaced while checking whether `InferenceCountNegBin`'s unguarded-
information-inverse bug (`release_v1_0_5.md → TODO-4`) also explained this
class's audit flags. It does not: `InferenceCountPoisson` uses a different,
already well-guarded kernel, `compute_diagonal_inverse_entry()`
(`_helper_functions_core.h:222-245`, LDLT-first with a rank-revealing
`ColPivHouseholderQR` fallback, returns `NaN` not a wrong finite value on a
singular system) — exactly the pattern TODO-4 wants added elsewhere,
already present here. Confirmed NOT the same bug. Cause of the 16-family
miscalibration itself: **completely unidentified**, not investigated
further as of 2026-09-24.

### 2. `InferenceCountQuasiPoisson` — 9 families uniformity + 4 coverage, unidentified cause

Checked twice, ruled out from two different mechanisms:
- Ruled out from TODO-4's unguarded-information-inverse bug the same way as
  `InferenceCountPoisson` (independent implementation, not sharing the
  flagged kernels).
- Ruled out from TODO-28's stale-`cached_design_matrix` reused-worker bug
  (`bootstrap_worker_stale_design_matrix.md`): its `build_design_matrix()`
  (`inference_count_quasipoisson.R:244-252`) reads `private$w`/`private$X`
  directly on every call with **no caching at all** — genuinely immune to a
  stale-cache bug by construction.

Cause of the 9-family uniformity + 4-family coverage miscalibration:
**completely unidentified**, explicitly noted in `release_v1_0_5.md → TODO-29`
as "a fresh investigation, not covered by this TODO."

### 3. `InferenceCountKKGLMM` (part of the ruled-out "KKGLMM" cluster)

`InferenceContinKKGLMM`, `InferenceCountKKGLMM`, `InferenceOrdinalKKGLMM`
(compose the shared `KKGLMM` mixin, `inference_mixin_kk_glmm_shared.R`) plus
`InferencePropKKGLMM`, `InferenceIncidKKCondLogitGLMMIVWC`,
`InferenceIncidKKCondLogitGLMMOneLik` were all checked against TODO-28's
stale-design-matrix bug and ruled out: none of the 6 override
`supports_reusable_bootstrap_worker()`, so every draw gets a **fresh**
worker (`inf_template$duplicate(...)`) and `cached_design_matrix` cannot go
stale across draws for any of them (`release_v1_0_5.md → TODO-29`, "Also
explicitly ruled out, same day"). `InferenceCountKKGLMM` specifically was
originally flagged under TODO-4's broad-miscalibration sweep too, and
confirmed there to use "an independent implementation" not sharing that
bug's kernels either.

If `InferenceCountKKGLMM` (or any of its 5 KKGLMM-cluster siblings) shows
real audit-flagged miscalibration, per `release_v1_0_5.md`'s own note: "it
is a different, not-yet-investigated mechanism." **Not yet checked whether
it actually does** — that's the first next step below, before assuming this
class needs its own dedicated fix.

### 4. `InferenceCountKKHurdlePoissonOneLik` — separate file, unidentified cause

Flagged the same day as `InferenceCountPoisson`/`InferenceCountQuasiPoisson`
under TODO-4's sweep, confirmed to be "a separate file" (i.e. an independent
implementation, not sharing `InferenceCountNegBin`'s kernels) and "similarly
confirmed NOT to share this TODO's specific kernels — also broadly flagged,
also unexplained, also not part of this TODO." Never checked against
TODO-28's stale-design-matrix mechanism at all (unlike the other three
above) — that is an open, cheap first check.

## Tangential, much smaller item found alongside these (not itself part of the cluster)

While checking `InferenceCountPoisson`, `set_min_eigenvalue_if_suspect()`
(`_helper_functions_core.h:210-219`) was found to be entirely commented
out, so `min_eigenvalue_information` is never populated. This looked like
dead code, not a cause of the miscalibration above (there was no live
caller to rule in or out) — noted as "minor, unrelated cleanup, not
investigated further" in `release_v1_0_5.md → TODO-4`'s own text. Tracked
separately as `release_v1_0_5.md → TODO-32` (a one-line cleanup item, not
part of this investigation) — mentioned here only so a reader of this file
doesn't also lose track of it.

## Next steps (none done yet)

- [ ] Check whether `InferenceCountKKGLMM` (and the other 5 KKGLMM-cluster
  classes) actually show real audit-flagged miscalibration at all, or
  whether the "broadly flagged" framing in TODO-4's original note was
  loosely worded — if none of the 6 show a real, confirmed pattern, that
  narrows this file's scope by one class immediately.
- [ ] Check `InferenceCountKKHurdlePoissonOneLik` against TODO-28's
  stale-`cached_design_matrix` mechanism (the one check the other three
  classes already got but this one didn't) — cheap, do first.
- [ ] For each of `InferenceCountPoisson`/`InferenceCountQuasiPoisson`/
  `InferenceCountKKHurdlePoissonOneLik` (whichever remain unexplained after
  the above): pull the exact historical `comprehensive_tests` CSV rows,
  identify which specific method families are flagged and at what
  severity, and look for a shared shape (direction, magnitude,
  formula-dependence) the way `InferenceContinOLS`/`InferenceContinLin`/
  `InferenceIncidLogBinomial`/`InferenceSurvivalWeibullRegr`'s shared
  `~.`-specific pattern led to TODO-28's single-root-cause discovery — a
  cross-class comparison may again be higher-leverage than three separate
  per-class investigations, but don't assume that; these three classes have
  no confirmed shared code path the way those four did.
- [ ] Only once a concrete mechanism is confirmed for at least one class
  should this file be split into (or upgraded to) proper `# Fix:` plan
  file(s) with their own fix checklists.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`). Any reproduction
should prefer the real `comprehensive_tests.R` DGP/harness call path over a
hand-built approximation — several other investigations this session
(`investigate_incid_kk_modified_poisson_se_quality.md`,
`investigate_incid_kk_gee_bootstrap_family_inflation.md`) failed to
reproduce a real historical finding with a simplified fixture, so treat
that as the default risk to avoid here too.
