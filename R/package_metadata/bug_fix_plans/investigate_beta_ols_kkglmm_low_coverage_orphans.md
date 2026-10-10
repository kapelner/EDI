# Investigation: Six Classes With Confirmed-Real `low_coverage`/Unexplained Flags — Ruled Out From The Stale-`cached_design_matrix` Bug

> **Depends on:** none. (Global ordering: see `_master.md`.) Slated for
> `release_v1_0_5.md → TODO-52`. Surfaced 2026-09-24 as a byproduct of
> `bootstrap_worker_stale_design_matrix.md`'s (TODO-28) cross-class sweep —
> each class below was checked specifically against that bug's mechanism,
> confirmed NOT to share it, and then left as an unexplained aside with no
> TODO number or plan file, same pattern as `investigate_count_family_unexplained_miscalibration_cluster.md`
> (TODO-50, renumbered from TODO-31 for a numbering collision — see
> that file's TODO-50 entry). **This is an open investigation, not a
> confirmed bug.**

## The six findings

All six were checked only against one specific candidate mechanism (the
reused bootstrap worker's stale `cached_design_matrix`,
`bootstrap_worker_stale_design_matrix.md`) and confirmed not to share it.
None has been root-caused on its own terms.

1. **`InferencePropBetaRegr`** — custom uncached `build_design_matrix()`
   (`inference_proportion_beta.R:657-660`), confirmed to never touch the
   broken cache. Real `low_coverage` flag, cause unidentified.
2. **`InferencePropZeroOneInflatedBetaRegr`** — uses
   `build_component_matrix()`, a different two-component builder, not
   `create_design_matrix()` at all. Real flag, cause unidentified, not
   traced further.
3. **`InferenceContinKKOLSOneLik`** and
4. **`InferenceContinKKRobustRegrOneLik`** — build `X_comb` directly from
   `KKstats$X_matched_diffs`/`X_reservoir`, cached via
   `reduce_design_matrix_once(..., cache_key=...)`
   (`inference_continuous_KK_ols_one_lik.R:459-506`,
   `inference_continuous_KK_robust_regr_one_lik.R:104-113`) — that cache
   lives in `private$cached_values[[cache_key]]`, correctly wiped by the
   bootstrap loader and self-validating on `ncol(X)`. Looks correctly
   designed on this specific point; their `low_coverage` flags are real
   and unexplained.
5. **`InferencePropKKGLMM`** and
6. **`InferenceIncidKKCondLogitGLMMIVWC`**/**`InferenceIncidKKCondLogitGLMMOneLik`**
   (grouped — all three inherit `InferenceAbstractKKCondLogitGLMM`) —
   `compute_estimate_with_bootstrap_weights()`
   (`inference_incidence_KK_cond_logit_glmm_abstract.R:80-99`) does call
   `private$create_design_matrix()` (the broken cache), but
   `supports_reusable_bootstrap_worker()` is never overridden in this
   hierarchy, so it inherits the base `FALSE` — every draw gets a fresh
   `duplicate()`d worker, immune to the staleness. Their `low_coverage`
   findings are real and unexplained by that bug.

## Lower-priority, not yet even confirmed as real findings

The 7-class "KKGLMM"/"KKCLMM" cluster (`InferenceContinKKGLMM`,
`InferenceCountKKGLMM`, `InferenceOrdinalKKGLMM`, `InferenceOrdinalKKCLMM`
+ its 3 link-function subclasses) was also ruled out from the stale-
design-matrix bug (same fresh-`duplicate()`-per-draw immunity as items 5/6
above) — but unlike items 1-6, it's not yet confirmed whether this cluster
actually shows real audit-flagged `low_coverage`/`biased_estimate` findings
at all. Check that first before investing in root-causing it. (Note:
`InferenceCountKKGLMM` specifically is *also* named in
`investigate_count_family_unexplained_miscalibration_cluster.md`/TODO-50 as
part of a separate count-family cluster — if this class does have a real
finding, coordinate with that file rather than duplicating the
investigation.)

## Historical-audit reconciliation (2026-10-09)

The retained historical source is
`R/package_tests/comprehensive_results_audit_baseline.csv` (mtime
2026-09-24). Its rows replace the earlier shorthand description of this
file: it records `pval_miscalibration`, `low_coverage`, `low_power`, and
`biased_estimate` separately, and calls statistically significant *over*
coverage `low_coverage` for historical compatibility. The exact grouped row
counts are:

| Class | Historical flags (number of rows) | Shared shape conclusion |
| --- | --- | --- |
| `InferencePropBetaRegr` | `pval_miscalibration` (3) | Two custom-randomization rows are byte-for-byte the same 37-null-draw result as ZOIB; its remaining likelihood-ratio-bootstrap row is unique. |
| `InferencePropZeroOneInflatedBetaRegr` | `pval_miscalibration` (2) | Only the same two custom-randomization 37-null-draw rows; no coverage row remains in this baseline. |
| `InferenceContinKKOLSOneLik` | `low_coverage` (10), `pval_miscalibration` (6) | Primarily undercoverage in Bayesian/bootstrap/studentized, parametric-bootstrap, and subsampling intervals. |
| `InferenceContinKKRobustRegrOneLik` | `low_coverage` (14), `pval_miscalibration` (15) | Stronger, mostly undercoverage in the same Bayesian-bootstrap/studentized/subsampling family, but also broad p-value flags. |
| `InferencePropKKGLMM` | `biased_estimate` (3), `low_coverage` (11), `pval_miscalibration` (10) | A different mixture: many asymptotic/likelihood/score intervals have 1.000 *over*coverage while the `~1` jackknife interval is 0.779. |
| `InferenceIncidKKCondLogitGLMMOneLik` | `pval_miscalibration` (13) | P-value-only pattern across bootstrap, likelihood-ratio, randomization, score, and asymptotic families; the audit has no IVWC row. |

Consequently, the only direct cross-class duplicate is the custom
randomization result shared by the two proportion classes. It cannot by
itself establish a shared estimator defect; the remaining four groups have
incompatible response types and error families. The historical CSV is an
audit summary, not a reproducible raw-result fixture, so any causal claim
requires a new, documented targeted study rather than retrospective source
edits.

The lower-priority KKGLMM/KKCLMM check is also affirmative and must remain
in scope. The same baseline has flagged rows for `InferenceContinKKGLMM`
(3 low-coverage, 2 low-power, 11 p-value), `InferenceCountKKGLMM` (11
low-coverage, 27 p-value), `InferenceOrdinalKKCLMM` (2 low-coverage, 3
p-value), `InferenceOrdinalKKCLMMCloglog` (4 biased-estimate, 12
low-coverage, 22 p-value), and `InferenceOrdinalKKCLMMProbit` (3
biased-estimate, 7 low-coverage, 1 low-power, 4 p-value). There are no
rows for `InferenceOrdinalKKGLMM` in this retained baseline. These
heterogeneous findings are not evidence for a common stale-worker cause,
and `InferenceCountKKGLMM` remains coordinated with TODO-50/TODO-31.

## Next steps

- [x] For each of the 6 confirmed-real-finding classes above, pull the
  exact historical `comprehensive_tests` CSV rows (which method families,
  what magnitude/direction) and look for a shared shape across any subset
  of them. The reconciliation above found no common mechanism; the two
  proportion-class custom-randomization duplicates are only a lead.
- [x] Check whether the 7-class KKGLMM/KKCLMM cluster actually has any real
  audit-flagged findings before investigating it further. It does, so it
  remains in scope rather than being dropped.
- [ ] Only once a concrete mechanism is confirmed for at least one class
  should this file be split into (or upgraded to) proper `# Fix:` plan
  file(s) with their own fix checklists.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`).
