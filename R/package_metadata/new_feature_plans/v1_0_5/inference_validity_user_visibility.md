# Making procedure validity visible to EDI users

> **Release:** v1.0.5 TODO-194..198 (`future_release_plans/release_v1_0_5.md`).
> **Depends on:** TODO-192 (`inference_procedure_regime_registry.md`) and
> TODO-193 (`inference_convergence_rate_registry.md`): the single source of
> truth `R/EDI/R/inference_procedure_regime.R` and its resolver
> `inference_convergence_expectation(design, class, procedure)`. Nothing here
> keeps a second copy of a regime, rate or reference: every user-visible
> surface reads the registry.

Status: PLANNED 2026-11-10 (owner chose options 1, 2, 3, 4, 7 of the
2026-11-10 discussion, in that order; 5 and 6 not taken).

## 1. `run_all_inference()` columns (TODO-194)

Add columns to `run_all_inference()`'s result (see `inference_suite.R`; the row
label is the sentinel `label`): `regime`, `n_eff` (rule name and its value for
this design and data, e.g. `n_pairs = 25`), `size_order` (rendered, e.g.
"O(n_eff^-1)", "exact", "O(1)", "unknown") and `rate_basis`. Additive columns
only: existing columns, order and values unchanged. Computing `n_eff` needs the
design's realised data (pairs, arm sizes, events, nonzero counts); add one
small helper next to the resolver. Update the function's roxygen `@return`.
Tests: column presence and types, one matched design (n_pairs), one unequal
allocation (n_min_arm), one finite-sample row (exact / rand), existing
`run_all_inference` tests unchanged.

## 2. Help-page section, references (TODO-195)

* A roxygen `@eval` helper (e.g. `rd_small_sample_section(class_name)`) that
  renders a "Small-sample behaviour" `@section` for a class from the registry:
  one line per supported procedure with its regime, rate, effective n,
  regularity and reference key, plus any class-level note. Added to every
  concrete inference class's roxygen block. Existing hand-written "Small
  samples" paragraphs (e.g. `InferenceContinLin`) are reconciled: the registry
  is the source, the prose either moves into the registry's note or is checked
  against it (ContinLin's "up to about 10.5%" disagrees with the first
  campaign's 0.17; fix the prose with a citation of what was measured).
* Every rate cites a primary reference. References use `R/EDI/REFERENCES.md`
  citation keys; add any new works there (Hall 1992 for Edgeworth / bootstrap
  orders, Barndorff-Nielsen & Cox for Bartlett, Cox & Snell / Firth for MLE
  bias, Self & Liang 1987 for boundary / variance-component limits, Koenker
  for quantile-regression sparsity, Imbens & Rubin / Bai et al. for
  matched-pair designs, ...), following its format and family sections. A
  registry reference with no key in REFERENCES.md fails a test.
* Do not run roxygen (owner's pre-push regenerates Rd); verify the helper's
  output by calling it directly for a handful of classes.

## 3. Measured values from a complete campaign (TODO-196, GATED; moved 2026-11-12 to `release_v1_0_6.md → TODO-19`)

Do when a calibration campaign has completed (status `complete` on the
`calibration-results` branch; the first is `2026-11-09-8c32d060`, expected
around 2026-11-20). Ship a compact table in the package
(`inst/extdata/calibration_measured.csv` or sysdata) of measured size,
coverage, bias / SD and their Monte Carlo intervals per (design, class,
procedure, formula, n), with campaign id and EDI commit; a script to refresh
it from the results branch; a release-checklist line to refresh it; and show
it next to the expected rate in sections 1, 2 and 4 ("measured at n = 50 on
this design: 0.073 [0.058, 0.090], campaign 2026-11"). Stale if an estimator
changed after the campaign's commit: carry the commit so a reader can tell.

## 4. User-callable lookup (TODO-197)

An exported accessor, e.g. a public method on inference objects
`inf$get_procedure_validity(procedure = NULL)` (all supported procedures by
default) and a function form for a (design, class, procedure) triple without
data. Returns the resolved expectation, the realised `n_eff`, and (once TODO-196
lands) the measured values. Roxygen with an example. Exports require the
NAMESPACE, which roxygen regenerates at pre-push: add `@export` and also the
NAMESPACE line by hand so `load_all(compile = FALSE)` tests can see it, and
say so in the report.

## 5. Vignette (TODO-198)

A section in `R/EDI/vignettes/validation-evidence.Rmd` (or a new short
vignette if it fits better), "Which procedure can I trust at my sample size?":
the regime split, the rate orders and effective-n rules, the non-regular
classes and why, generated from the registry (code chunk that tabulates the
resolver output; the vignette is `eval = FALSE` by default, so render the
table statically or with a chunk that does run, matching the file's
conventions), and links to the published calibration results branch. Cite
REFERENCES.md keys.

## Shared constraints for every section

* R only; never `R CMD INSTALL` / build / `load_all()` without
  `compile = FALSE` (project CLAUDE.md). No roxygen run.
* Agents run in parallel on one checkout: touch only your section's files;
  `R/EDI/NEWS.md` and `release_v1_0_5.md` are shared, so edit only your own
  bullet / TODO line, with small targeted edits, re-reading right before.
* The registry file is owned by TODO-193; if a section needs a new registry
  field, add it there in a minimal, backwards-compatible way and say so.
* Test file names carry no TODO number; cite the TODO in a top comment.
* Leave each TODO's checkbox `- [ ]`; the main session ticks it after review.

## Done

(per section, fill in when complete)

### Section 1 (TODO-194), implemented 2026-11-10

* `R/EDI/R/inference_validity_n_eff.R` (new, in `Collate` right after `inference_procedure_regime.R`): `edi_inference_validity_counts(des_obj)` (realised counts for every `EDI_CONVERGENCE_N_EFF` rule; `NA` when a rule does not apply; never errors), `edi_inference_validity_n_eff(des_obj, rule)`, `edi_inference_validity_design_label(des_obj)` (class name, plus `@prob_T=<p>` for a `DesignFixedBernoulli` with `prob_T != 0.5`, the calibration study's key), `edi_inference_validity_render_order()` (Inf -> "exact", 0 -> "O(1)", NA -> "unknown", else "O(n_eff^-1)", "O(n_eff^-2/3)"), and `edi_inference_validity_columns(des_obj, class, procedure)`, the one call TODO-197 can reuse.
* `inference_suite.R`: `run_all_inference()` appends `regime`, `n_eff` ("n_pairs = 25"), `size_order`, `rate_basis` after `weight` (existing columns, order and values unchanged); a row whose `method` is `NA` or unregistered gets `NA` in all four. Roxygen `@return` updated. Registry file untouched.
* Count definitions (decisions): `n` = subjects with a response; `n_pairs` = matched pairs, `n_pairs_plus_reservoir` = pairs + singleton reservoir (from `get_matching_cluster_ids()`); `n_min_arm` = smaller arm among responders; `n_events` = observed events for survival, the rarer of 0/1 for incidence; `n_nonzero` = responses > 0; `n_strata` = distinct block ids; `n_clusters` = distinct values of the cluster column (read from the design's private `cluster_col`, no public accessor).
* Test: `R/package_tests/testthat_bulk/test-run-all-inference-validity-columns.R` (presence, types, additivity, vocabulary, matched design `n_pairs = 15`, unequal allocation `n_min_arm`, finite-sample rows exact, helper edge cases).
* Existing-test change: `testthat_bulk/helper-run-all-inference.R` hard-coded the exact `results_table` column names; it now expects the four new names appended after `weight` (the only change to an existing test).
* Known gap: the registry's unequal-allocation entry is keyed `DesignFixedBernoulli@prob_T=0.2` only, so a Bernoulli design with another unequal `prob_T` (e.g. 0.3) resolves to `n_eff = n`. Extending the registry key is TODO-193's file; not done here.

### Section 2 (TODO-195), implemented 2026-11-10

* `R/EDI/R/inference_small_sample_doc.R` (new; `Collate` right after `inference_procedure_regime.R`): `rd_small_sample_section(class_name)` returns roxygen lines (an `@section Small-sample behaviour:` with a `\tabular` of the class's capability-level procedures, then notes, then `@references` with full citations read from `REFERENCES.md`). Rows: regime, error order, effective n, regularity, basis, reference keys, resolved on `DesignFixediBCRD`; design-keyed registry entries that change `n_eff`, order or regularity are listed as "Design-specific differences" (unequal allocation, cluster designs, design mismatch). The point-estimate bias sentence comes from the asymptotic rows only. Rows with basis `assumed_default` or `unknown` get an explicit note ("the cited works establish it for the regular case only" / "no rate is known ... the cited works describe the non-standard limit"); regularity classes get one generic sentence each. Base R, no side effects; only runs while Rd is generated.
* `@eval rd_small_sample_section("<Class>")` inserted (one roxygen line, just before `@export`) in the blocks of the 88 public classes (the 14 legacy IVWC classes, `InferenceSuite`, `InferenceRandCustom` get none) across 76 `inference_*.R` files. No code changes.
* Registry (backwards compatible): new `reference_key` column in `EDI_CONVERGENCE_PROCEDURE_DEFAULTS` and new `bias_reference_key` (always `CoxSnell1968`), a `reference_key` argument and column in `edi_convergence_entry()`/overrides, the resolver returns `reference_key` and `bias_reference_key` beside `reference`/`bias_reference`, and `inference_convergence_validate()` checks key shape. Free-text `reference` is unchanged; synthetic tables without the columns still resolve (keys `NA`).
* `R/EDI/REFERENCES.md`: new section "Convergence rates and small-sample behaviour" with 24 entries, keys LehmannRomano2005, Hall1992, CoxSnell1968, ShaoTu1995, BarndorffNielsenCox1994, Terrell2002, Lemonte2016, Lawley1956, BarndorffNielsenHall1988, Beran1988, DiCiccioMartinStern2001, Rubin1981, Lo1987, SelfLiang1987, StramLee1994, Davies1977, HallSheather1988, Koenker1994, Huber1981, ImbensRubin2015, BaiRomanoShaikh2021, BugniCanayShaikh2018, MaHuZhang2015, LiDingRubin2018. Existing keys reused: Fisher1935, Neyman1923, Koenker2005, Kallus2018. Details written from memory (no web access): DOIs deliberately omitted on the new entries; the two to double-check are Koenker1994 (Prague symposium chapter, pages 349-359) and BaiRomanoShaikh2021 (JASA 117(540), 1726-1737, online 2021 / print 2022).
* Honesty choices: the vignette-agreed key `DiCiccioMartinStern2001` is a one-sided result, cited only as supporting `param_boot` next to Beran1988 and Hall1992; `rand_bootstrap` stays `assumed_default` (Hall1992 for the assumed order, Kallus2018 for the open validity question); unknown rows cite the non-standard-limit works (SelfLiang1987, StramLee1994, Davies1977, Huber1981), described as context, not as a rate.
* Prose reconciliation (first campaign `2026-11-09-8c32d060`, provisional screening replicates, n = 50, null cells): rewrote the "Small samples" paragraph of InferenceContinLin (was 10.5%; measured 17%, coverage 83%, treatment-only 6.4%), InferenceIncidWald (9% -> 10.2%), IncidRiskDiff (9.5% -> 11%), IncidGComp (10% -> 12.3% risk difference, 9.6% risk ratio), IncidBinomialIdentityRiskDiff (13.5% -> 14.4%; the claimed 88% likelihood-ratio coverage was not reproduced: LR/score/gradient 4.7-5.9%), OrdinalGCompMeanDiff (8.5% -> 10.2%), SurvivalLogRank (9.5% -> 7.1%), IncidLogBinomial (qualitative -> score 14%, others <= 7.5%), SurvivalDepCensTransformRegr (9% -> score up to 11%), OrdinalCauchitRegr (9.5%/12.5% -> score 17%, gradient/LR 13%), IncidKKCondLogitOneLik (9% -> gradient 14.5%, one cell) and the stereotype-logit score sentence (10.5% -> 10-12%). Each says the campaign measured n = 50 only and links the results branch; the old "close to nominal by n = 200" claim was dropped where it could not be verified. Left unchanged because within Monte Carlo error of the campaign (about 0.007) or no campaign cell exists yet: KKGLMM, KKRobustRegrOneLik, SurvivalWeibullRegr, KKWeibullMarginal, both Weibull-frailty classes, PropQuantileRegr.
* Tests: `testthat_bulk/test-inference-small-sample-section-references.R` (7 tests, 650 expectations under `load_all(compile = FALSE)`): registry keys resolve to REFERENCES.md and every rate-bearing entry has one; resolver returns the keys; the section renders for all 88 classes with only resolvable keys and a full citation per key; assumed-default / unknown / exact-only labelling; each public class has exactly one `@eval` line and no IVWC class has; ContinLin prose carries the measurement. Existing: convergence-rate registry 9 tests / 94 expectations, procedure-regime 6 / 14, calibration-gate 5 / 17, vignette tables 5 / 7 (its REFERENCES.md key check now passes), `check_references_sync.R` OK.
* Verified without running roxygen: the helper's output for all 88 classes was written into a scratch package under `$TMPDIR` and roxygenised there (`@eval` + `@section` + a merged `@references` with the class's own); 88 Rd files, `tools::checkRd` clean. The first real Rd regeneration (pre-push, which sources the package files rather than `load_all`) is the remaining check.

### Section 4 (TODO-197), implemented 2026-11-10

* `R/EDI/R/inference_validity_lookup.R` (new, in `Collate` right after `inference_validity_n_eff.R`): exported `get_inference_procedure_validity(design, inference_class, procedure = NULL)` (design = class name, `"Design...@prob_T=0.2"` label, or a `Design` object, which fills `n_eff`); internal `edi_procedure_validity_for_object()`, `_supported()`, `_build()`, `_check_procedure()` and the TODO-196 hook `edi_procedure_validity_measured()` (returns `NULL`; the only function to change when measured values land) with `EDI_PROCEDURE_VALIDITY_MEASURED_NOTE`.
* `R/EDI/R/inference_all_abstract.R`: public method `get_procedure_validity(procedure = NULL)` on the `Inference` root (next to `get_model_formula()`), so every class has it. It is not a capability method: it is not in `contracts_mixins.R`'s `public_methods_for_capability`, and no allowlist needed it. The only registry-style audit it trips is the frozen method-owner golden, handled as a reviewed delta (below).
* `R/EDI/NAMESPACE`: `export(get_inference_procedure_validity)` by hand (alphabetical, between the identity-binomial and `get_local_EDI_optimization` lines). `DESCRIPTION` Collate: one line. Roxygen not run.
* Return value: a list `expectation` (data.frame, one row per procedure: `design, class, procedure, supported, regime, size_order, size_order_label, bias_order, n_eff_rule, n_eff, regularity, basis, reference, bias_basis, bias_reference` and the four `*_layer` columns), `measured` (`NULL`), `measured_note`.
* Reuses TODO-194's `edi_inference_validity_counts()`, `_design_label()` and `_render_order()` (no second n_eff implementation). Default procedure set = `run_all_inference_class_applicable_methods()` over the sentinels (same rule as `run_all_inference()`); for a live object, `lik_ratio_bartlett_exact` is decided by that object. The function form is capability-level only unless given a `Design` object. An explicit `procedure` the class does not support still resolves, with `supported = FALSE`.
* Reviewed delta in `R/package_tests/inference_component_call_graph_helpers.R`: `get_procedure_validity@Inference` added to every class's public methods in the frozen baseline comparison (the golden CSV is not rewritten).
* Tests: `testthat_bulk/test-inference-procedure-validity-lookup.R` (6 tests, 49 expectations).

### Section 5 (TODO-198), implemented 2026-11-10

* New vignette `R/EDI/vignettes/procedure-trust.Rmd` (a new one, not a section of `validation-evidence.Rmd`: that file is an index of tests, this one is reader guidance). Added to `_pkgdown.yml` (Package Concepts) and `pkgdown/assets/llms.txt`.
* Tables: the vignette is `eval = FALSE` and must build on CRAN without the calibration scripts, so the tables are static text between `<!-- BEGIN/END GENERATED registry|counts -->` markers. `R/package_tests/render_procedure_trust_tables.R` renders them (`Rscript R/package_tests/render_procedure_trust_tables.R --write` from the repo root). `registry` (procedure table, effective-n rules, non-regular kinds, unknown-rate classes) needs base R only; `counts` (theory / literature / assumed default / unknown per regime, regularity shares) enumerates the applicable triples as the calibration planner does and needs `load_all(compile = FALSE)`.
* Sync test: `testthat_bulk/test-procedure-trust-vignette-tables.R` (registry block, counts block (skips without the package + calibration scripts), no IVWC, every citation key exists in REFERENCES.md, pkgdown listing).
* Citation keys: the script holds a procedure -> keys and regularity -> keys map (the registry's `reference` is free text). Keys already in REFERENCES.md: Fisher1935, Neyman1923, Koenker2005, Powell1991. Keys used but missing there (TODO-195 to add or rename; edit the maps in the script to match): LehmannRomano2005, Hall1992, CoxSnell1968, ShaoTu1995, BarndorffNielsenCox1994, Terrell2002, Lemonte2016, Lawley1956, BarndorffNielsenHall1988, Beran1988, DiCiccioMartinStern2001, Rubin1981, Lo1987, SelfLiang1987, StramLee1994, HallSheather1988, BaiRomanoShaikh2021, BugniCanayShaikh2018, LiDingRubin2018, Davies1977, Huber1981. The key test fails until they exist.
* No registry or REFERENCES.md edit. `get_procedure_validity()` is not referenced (not exported yet). Counts at the time of writing: 22 designs, 88 classes, 11,854 triples (theory 1,270, literature 78, assumed default 8,446, unknown 2,060).
