## Covered
- DesignFixedBernoulli (n = 90, unequal arms 37/53), 5 levels with level 5 empty in the treated arm, 3 covariates.
- Wald and LR CI/p for PO, AdjCat, Cloglog, Probit, Cauchit, ContRatio and Stereotype. Score, gradient and Bartlett-approx too for PO and the other links.
- PPO with `nonparallel` = empty / "base_pain" / c("age","female") / "treatment" (warns) / an unknown name (silently accepted, F2). Also `benchmark_asymp_two_sided_pval_breakdown()`.
- GComp mean-score diff (checked against clm + delta method), JT (asymptotic, exact, rand), Ridit (control/treatment/pooled reference, bogus reference rejected), and InferenceAllSimpleWilcox.
- Resampling: bootstrap (BCa default, percentile, basic), Bayesian bootstrap, jackknife, rand p (two-sided/less, delta), param bootstrap p/CI, LR bootstrap p/CI, subsampling CI.
- Options: alpha (0, 1, 1.5, -0.1), delta, set_testing_type, set_information_preference (affects score tests only, as documented), set_optimization_alg, smart_cold_start_default, and model_formula (~1, ~bp+I(age^2), ~bp*female).
- Response codings: 0-based and negative are rejected; gaps (1,2,4,5,6), shifted (11..15), double and ordered factor work; an unordered factor, character, non-integer or NA is rejected with a clear message. Also K = 2, a constant y (F8) and quasi-separation (F9).
- InferenceSuite with `inference_params` for PPO, and the combined-evidence CCT (F10, F11).

## Not reached
- KK-design ordinal classes: KKCLMM (logit/probit/cloglog/cauchit), KKGEE, KKGLMM, KKCondAdjCatLogitRegr, PairedSignTest.
- Blocking/cluster designs with ordinal outcomes, and sequential designs (cookbook's KK14 example).
- `InferenceSuite` `combined_evidence_weighting = "equal"/"custom"`, `formulas`, `html`/`plots` output.
- Missing covariates (`missingness_method`) with an ordinal outcome.
- The meaning of `delta` in randomization tests for ordinal coefficients, and `transform_responses`.
- Stereotype with several covariates; Bartlett exact on any ordinal class.
- How often the R6 estimate is under-converged (F5) at larger n, and whether `harden = FALSE` on AdjCat/ContRatio changes it.

## Workarounds
- `run_all_inference()` errors unless `screen = TRUE` or `html = TRUE`.
- `compute_param_bootstrap_pval()` has no default for `delta` (documented); pass `delta = 0`.
- Cloglog default BCa bootstrap returns NA with a boundary warning on this data; `type = "percentile"` works, as the message says.
- Sign conventions: the C++ backends `fast_ordinal_*_cpp` use P(Y<=k) = F(alpha_k + x'b), the opposite of the R6 classes and clm. The default lbfgs on the backend often hits `maxit = 100` with `converged = FALSE`; `optimization_alg = "newton_raphson"` converges to clm.
- Without `inf$set_seed()`, Bartlett-approx (Monte-Carlo) p-values differ between fresh objects; call `set_seed()` first.
- Rendering help pages with `tools::Rd2txt(tools::Rd_db("EDI")[["X.Rd"]])` into text files makes grepping docs fast.

## Confusing docs
- ?InferenceOrdinalPropOddsRegr / Cloglog / OrderedProbit / Cauchit have no `$new()` section; the inherited ?Inference constructor lists `harden` and `seed`, which they reject (F4).
- ?InferenceOrdinalPartialProportionalOddsRegr: `des_obj` is described as "A completed DesignSeqOneByOne object", but fixed designs work. The t(n-1) reference is not mentioned (F1).
- ?Inference `get_estimand()`: "conditional" just means "the class's default". InferenceOrdinalGCompMeanDiff (a marginal standardised estimand) reports "conditional", which is misleading.
- ?Inference `get_summary()`: says the full coefficient table is shown when available, but the ordinal regression classes show only the treatment row.
- ?InferenceOrdinalCloglogRegr and ?InferenceOrdinalStereotypeLogitRegr cite "EDI 1.0.5 null study" / "Since EDI 1.0.5", while the installed version is 1.0.4.
- `get_optimization_alg()` returns NULL until `set_optimization_alg()` is called. ?Inference says it returns the optimizer used.
- The JT exact p-value uses two-sided = 2·min(one-sided); coin's exact WMW uses |U - mu|. This convention isn't documented (F12).
