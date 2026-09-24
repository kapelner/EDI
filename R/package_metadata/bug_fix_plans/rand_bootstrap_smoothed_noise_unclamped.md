# Fix: `smoothed` Randomization-Bootstrap p-Value Adds Unclamped Continuous Noise to Binary/Ordinal Responses — Shared Machinery, ~85 Cells Wildly Miscalibrated

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-18`. Found 2026-09-23, surfaced by the new
> `pval_miscalibration` audit check — a `_smoothed` function-run variant
> appeared across 85 distinct (class, response_type) cells with wildly
> inconsistent miscalibration direction/severity (not a single consistent
> bias), which is itself the tell that this is shared machinery breaking
> differently depending on what data shape it's fed, not 85 independent
> per-class bugs. Root-caused same day. **Confirmed not yet tracked**:
> `ordinal_cumulative_link_null_refit_multistart.md:127-131` explicitly
> flags this exact `function_run` for `InferencePropOddsRegr` as "a
> separate, unexamined finding, out of scope for this plan."

## The bug, traced to a single shared function

`add_rand_bootstrap_smooth_noise()`
(`R/EDI/R/inference_all_abstract_rand_bootstrap.R:613-618`) is genuinely
shared machinery — one function, called from three sites in the abstract
base class (`:753`, `:928`, `:1060`), used identically by every class's
`type="smoothed"` randomization-bootstrap p-value variant. No class
overrides it (confirmed by grep).

```r
add_rand_bootstrap_smooth_noise = function(y, noise, response_type){
    y_noisy = as.numeric(y) + as.numeric(noise)
    if (identical(response_type, "count")) {
        return(pmax(0L, as.integer(round(y_noisy))))
    }
    y_noisy
}
```

The smoothing bandwidth is `bw = sd(private$y, na.rm = TRUE) / sqrt(n)`
(`:526-527`, `zero-one/proportion-unaware` — the marginal SD of the raw
coded response) and this Gaussian noise is added directly to the response
before refitting on each draw (`:753` et al. call
`add_rand_bootstrap_smooth_noise` with this per-draw `rnorm(n, 0, bw)`
noise). The function has an explicit special case for
`response_type == "count"` (rounds and floors at 0 — the code comment
above it, dated 2026-09-15, explains this was added because "a slightly
negative noisy count became a large negative integer after a nonzero-delta
shift, every Poisson/GLMM refit on that draw failed"). **There is no
equivalent handling for `"incidence"` (binary 0/1) or `"ordinal"`
(integer category codes)** — the comment literally says "Every other
response type keeps the raw additive noise." Continuous Gaussian noise
gets added straight onto 0/1 or 1/2/3/4-coded responses with no clamping,
producing invalid values like `y=0.3` or `y=4.7` fed into a refit that
expects binary/ordinal data.

**This directly explains the observed pattern**: downstream behavior on
malformed fractional-binary or fractional-ordinal input reasonably varies
wildly by each class's specific fitting internals (how it handles a
non-0/1 "binary" value, or a non-integer "ordinal" value, is undefined
behavior nobody designed for) — exactly matching what the audit found:
- `InferenceContinKKRobustRegrOneLik`: reject-rate 0.495 at a true null
  (should be ~0.05) — 10x inflated.
- `InferenceIncidKKCondLogitOneLik`: reject-rate 0.325 — 6.5x inflated.
- `InferenceOrdinalGCompMeanDiff`: reject-rate 0.000 — never rejects.
- The remaining ~80 cells span the full range between these extremes.

Note `InferenceContinKKRobustRegrOneLik` is `continuous` response type,
which is NOT one of the two flagged-as-missing cases (`incidence`/
`ordinal`) — continuous responses aren't bounded/discrete-coded the way
binary/ordinal are, so raw additive noise shouldn't be categorically wrong
for them the way it is for incidence/ordinal. This suggests the bug's
blast radius may be wider than just "binary/ordinal get corrupted inputs"
— TODO-2 below covers checking whether the bandwidth formula itself
(`sd(y)/sqrt(n)`) is appropriate across every response type/link scale, not
just whether integer/binary rounding is missing.

This bug is specific to classes that route through this R-level dispatch
— per the same code comment, "The C++ batch kernels (mean difference,
Wilcoxon, survival) apply `noise_mat` themselves; none of them fits an
integer-support likelihood, so they are unaffected" — so the affected-class
list is bounded to whichever classes use the generic R-level BRT smoothed
path, not every class with a `smoothed` variant. TODO-1 confirms the exact
boundary.

## Scope

Confirmed shared/generic (one function, three call sites, no per-class
override) — this is a systemic fix, not a per-class patch list, matching
the "single source of truth" pattern this session's other fixes have
favored. Not yet independently reproduced via a repeated-trial calibration
check (the investigating fork's time budget didn't cover it) — TODO-1
covers this.

## Proposed fix — not yet decided, two directions

**Option A — response-type-aware clamping, mirroring the `count` case.**
Add `incidence`/`ordinal` (and check `proportion`, which is also
bounded/non-continuous in spirit even though stored as a real number in
[0,1]) branches to `add_rand_bootstrap_smooth_noise()`: for `incidence`,
clamp/round to `{0,1}` (or reject noise draws that would flip the value,
depending on what's statistically appropriate for a smoothed *binary*
resampling distribution — needs thought, since rounding continuous noise
back to a binary value may defeat the entire point of "smoothing"); for
`ordinal`, round to the nearest valid integer level and clamp to the
observed category range.

**Option B — don't smooth binary/ordinal/proportion responses at all**,
i.e. `type="smoothed"` silently falls back to `type="percentile"` (or
errors/warns) for response types where continuous additive noise isn't a
coherent operation on the response scale. Simpler and safer, but removes a
feature (the whole point of `smoothed` is reducing null-distribution
discreteness, which matters MORE for exactly these low-cardinality
response types, so Option B trades away the feature where it would help
most).

Recommend investigating Option A's statistical validity first (does
clamped/rounded noise still deliver the discreteness-reduction benefit
`smoothed` exists for?) before falling back to Option B.

## TODOs

- [ ] TODO-1: Confirm the exact boundary of affected classes — which
  concrete classes route through `add_rand_bootstrap_smooth_noise()`
  (R-level dispatch) vs. the C++ batch kernels (mean difference, Wilcoxon,
  survival — believed unaffected per the existing code comment, confirm
  this holds for `type="smoothed"` specifically, not just the general BRT
  path). Cross-reference against the ~85 flagged cells from the audit to
  build the exact list.
- [ ] TODO-2: Investigate whether the bandwidth formula
  (`bw = sd(private$y) / sqrt(n)`, `:526-527`) is itself appropriate across
  every affected response type/link scale, not just whether rounding is
  missing — `InferenceContinKKRobustRegrOneLik` (continuous, reject=0.495)
  doesn't fit the "unclamped discrete noise" explanation cleanly and needs
  its own look.
- [ ] TODO-3: Reproduce directly via `pkgload::load_all(".", compile = FALSE)`
  only (never `R CMD INSTALL`/`R CMD build`/`pkgbuild::compile_dll()`/
  `load_all(compile = TRUE)` or unspecified `compile=` — hard project rule,
  top-level `CLAUDE.md`). Pick 2-3 of the worst-offending classes, run a
  repeated-trial true-null calibration check on `type="smoothed"`, and
  confirm the wild miscalibration reproduces. Compare against the plain
  (non-smoothed) variant on the same draws to isolate the smoothing step
  specifically.
- [ ] TODO-4: Decide Option A vs. B (per response type, possibly a mix —
  e.g. Option A for `incidence`/`ordinal`, investigate `proportion`
  separately, Option B only if A proves statistically unsound for a given
  type) and implement.
- [ ] TODO-5: Verify the fix doesn't change `smoothed` results for
  response types that were already correctly handled (`count`, and
  whichever of `continuous`/`survival` turn out fine) — bit-for-bit or
  within floating-point tolerance for those.
- [ ] TODO-6: Re-run true-null calibration checks across all affected
  classes/response-types and confirm rejection rates return to nominal
  ~5%.
- [ ] TODO-7: Add a permanent regression test analogous to this session's
  other new coverage: construct a minimal true-null fixture per affected
  response type, run `type="smoothed"` repeatedly, and assert calibration
  stays within a reasonable band of nominal — this general shape
  (response-type-dependent noise validity) isn't caught by the existing
  non-degeneracy test either.
- [ ] TODO-8: Regenerate the affected `comprehensive_tests` CSV rows for
  the confirmed affected classes' `smoothed` variant once fixed and
  installed (only after install, not before, same caution as the sibling
  plans this session produced).

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build.
Response types NOT affected by whatever gap is found must produce
unchanged (bit-for-bit or floating-point-tolerance) results after the fix.
