# Investigation: Six Classes With Historical Audit Flags — Ruled Out From The Stale-`cached_design_matrix` Bug

> **Depends on:** none. (Global ordering: see `_master.md`.) Slated for
> `release_v1_0_5.md → TODO-52`. Surfaced 2026-09-24 as a byproduct of
> `bootstrap_worker_stale_design_matrix.md`'s (TODO-28) cross-class sweep —
> each class below was checked specifically against that bug's mechanism,
> confirmed NOT to share it, and then left as an unexplained aside with no
> TODO number or plan file, same pattern as `investigate_count_family_unexplained_miscalibration_cluster.md`
> (TODO-50, renumbered from TODO-31 for a numbering collision — see
> that file's TODO-50 entry). **This is an open investigation, not a
> confirmed bug.**

## The six historical flag groups

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

**Local artifact availability recheck (read-only), 2026-10-18:** this
workspace also contains the ignored, row-level comprehensive output files
`comprehensive_tests_results_nc_1_proportion.csv` (81 MB, Oct 9),
`..._continuous.csv` (644 MB, Oct 9), `..._incidence.csv` (502 MB, Oct 9),
`..._count.csv` (315 MB, Sep 27), and `..._ordinal.csv` (398 MB, Oct 9).
Unlike the tracked audit baseline, their rows retain `rep`, `beta_T`, dataset,
response type, design, inference-class label (including the model/design
formula tags), function run, `github_commit_id`, timestamp, and harness
settings such as `r`, `pval_epsilon`, censoring rate, and noise SD. A sample
row in the proportion file, for example, records commit
`95e5203765fde92b5d501c0e93139603c2a95bf1` and its 2026-09-24 run context.
This means some of TODO-52's historical cell metadata can be recovered from
these local files; the earlier wording that the audit summary is the only
retained representation was too broad. These files are ignored local
artifacts, not tracked or release-provenance artifacts, and they do not store
the generated outcomes/assignments or RNG state. They can identify/filter
the old cells and their recorded commit/settings, but cannot provide an exact
deterministic replay. Do not use them as post-fix evidence or edit them; keep
the replacement-study/calibration gate open.

**Additional historical lead from the isolated comprehensive audit (2026-10-16;
not a new TODO and not a current-defect claim):** the Oct 16 audit of the
retained proportion results also flags `InferencePropBetaRegr`'s generic
`compute_lik_ratio_two_sided_pval`, separate from the older
`compute_lik_ratio_bootstrap_two_sided_pval` row above. The model-formula
`~.` group rejects 45/316 null rows (0.142); the legacy rows without an
explicit model formula reject 29/316 (0.092). The `~1` group rejects 10/316
(0.032) and was not flagged. As a method-family comparison, the corresponding
likelihood-ratio-bootstrap rate is 43/339 (0.127), while asymptotic/Wald is
15/339 (0.044); this is evidence to investigate the LR family, not enough to
assign a cause. These raw rows all carry commit
`903ced0404921b7f4a6b5a8b1f7d0a6702466a31` and timestamps from 2026-09-25
through 2026-09-27, so they are internally same-commit historical evidence,
not a mixture of commits. They predate the 2026-10-11 source change in
`inference_proportion_beta.R` that corrected the warm-start coefficient
vector passed by the likelihood-test null-fit closure. Consequently, current
reproducibility is unproven; the historical rows must not be called a live
defect or used to justify a source change without a post-fix calibration
check. This remains within TODO-52's existing unexplained-finding scope.

**Bounded installed-harness pilot setup check (2026-10-16):** the first
scratch-only diagnostic invocation selected `response=incidence`,
`design=FixedBinaryMatch`, `InferencePropBetaRegr`, `dataset=cars`,
`beta_T=0.5`, one replicate, and the generic likelihood-ratio family. It was
not a valid calibration cell: `InferencePropBetaRegr` is a proportion model,
and the harness explicitly skipped FixedBinaryMatch with
`no covariates provided to run the binary matching algorithm`. The process
exited 0 but executed zero cells/replicates and wrote no CSV; its unique
`/tmp/edi-todo52-pilot-lr-20261016/` output directory is empty. Installed
context was R-devel r90668 and EDI 1.0.3 from
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. No canonical output
was touched. This is only a setup/skip check, not post-fix calibration
evidence.

The corrected one-replicate pilot matrix, held until the active TODO-56 run is
terminal, is response `proportion`, dataset `airquality`, `beta_T=0.3`, and
`InferencePropBetaRegr`, with separate `Bernoulli` and `FixedBinaryMatch`
design invocations (the harness accepts one design filter per invocation).
Run the generic `lik_ratio`, LR parametric-bootstrap (`parametric_bootstrap`),
and `wald` families as separate calls; the class wrapper covers both `~1` and `~.`
formula paths. Keep each result in a distinct scratch directory, record
successful denominators and session metadata, and do not scale to 100
replicates until pilot timing supports it. Use the checkout runner
`R/package_tests/comprehensive_tests.R` with argument tuple
`1 1 proportion <design> InferencePropBetaRegr airquality 0.3 NA <family> narrow fork=FALSE`;
the family argument is exactly `lik_ratio`, `parametric_bootstrap`, or
`wald`, and run
each tuple independently for each of the two designs (six pilot invocations
total). The runner normally hard-wires its CSV under `R/package_tests/`, so
do not launch the raw command directly: evaluate the parsed runner in-memory
with `script_path` fixed to the checkout script and `results_file` overridden
to `<scratch-root>/<design>/<family>/results.csv`. This preserves the harness
logic without editing the runner or touching canonical results. The
`fork=FALSE` argument is already part of the harness's supported CLI and
keeps this narrow pilot in one process. Note that `r=151` is a separate
runner constant: the LR parametric-bootstrap call uses `B=151` for each
formula path even when outer `Nrep=1`, so time the first such cell before
proceeding with the other parametric-bootstrap pilot calls or expanding to
100 outer replicates. The ordinary nonparametric `bootstrap` family is not
the historical LR-bootstrap method under investigation.

**Runner-isolation warning (2026-10-16):** the in-memory instruction above
must not be implemented as one unrestricted `eval(parse(file=...))`. The
runner begins with `rm(list=ls())`, selects its script path from process
arguments/current directory, may enter watchdog setup, and later assigns
`results_file` unconditionally to the canonical `R/package_tests/` path
(lines 926-931) before the write path. A future pilot must use an isolated
evaluation/copy strategy that preserves the checkout `repo_root`, avoids
watchdog relaunch/`quit()` behavior, and intercepts or replaces the output
path after runner initialization but before any result loop/write. Verify
the resolved output path is under that invocation's unique scratch directory
before starting each call. No corrected pilot has run yet; the six-cell
matrix remains held until TODO-56 is confirmed terminal.

**Hold reconciliation (2026-10-16):** one Bernoulli/`lik_ratio` invocation
was briefly started after a process poll returned no R workers, then
interrupted with SIGINT when the TODO-56 owner reported that its worker was
still live. It exited 130 before any result CSV was created; its scratch
directory is empty. No other valid pilot invocation was started. Keep the
full matrix held until the TODO-56 owner confirms a clean terminal result and
log.

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

No `R CMD INSTALL`/rebuild of `R/EDI` without explicit user permission in
the current conversation. Do not use `pkgload::load_all()` as a workaround:
project policy treats loading and verification commands that may compile as
requiring that same permission.
