# Per-procedure validity regime (v1.0.5 TODO-192).
#
# Which regime a `run_all_inference()` sentinel label belongs to: "asymptotic"
# (valid as n grows; small-sample excess is expected behavior) or "finite_sample"
# (valid at every n by construction). The regime is a property of the procedure,
# not of the inference class. Consumed by the calibration gate
# (R/package_tests/calibration/), which holds finite-sample procedures to nominal
# at every n and asymptotic ones to an n-dependent tolerance.
#
# Self-contained on purpose: base R only, no R6, no package internals, no side
# effects beyond defining these objects. The calibration publish job runs without
# EDI installed and sys.source()s this file from the checkout.
# inference_suite.R checks at load time that this table and the sentinel tables
# list exactly the same labels.

#' @keywords internal
#' @noRd
EDI_INFERENCE_PROCEDURE_REGIMES = c("asymptotic", "finite_sample")

#' One entry per `run_all_inference()` sentinel label. Known per-cell exceptions
#' are deliberately not encoded: an `exact` procedure that falls back to a normal
#' approximation, or a randomization test that drops failed-fit draws, is still
#' `finite_sample`; when it misbehaves that is a defect or an accepted
#' calibration cell.
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_PROCEDURE_REGIME = c(
	# Exact test: valid at every n by construction.
	exact                     = "finite_sample",
	# Randomization test: exact under the sharp null by construction.
	rand                      = "finite_sample",
	# Normal approximation to the estimator's sampling distribution.
	wald                      = "asymptotic",
	# Jackknife variance fed to a Wald interval: still a normal approximation.
	jackknife                 = "asymptotic",
	# Score, likelihood-ratio and gradient tests: chi-square limits.
	score                     = "asymptotic",
	lik_ratio                 = "asymptotic",
	gradient                  = "asymptotic",
	# Bartlett correction: one order better, still asymptotic.
	lik_ratio_bartlett_approx = "asymptotic",
	lik_ratio_bartlett_exact  = "asymptotic",
	# Parametric bootstrap: calibrated under the fitted model, not the true one.
	param_boot                = "asymptotic",
	param_boot_direct         = "asymptotic",
	# Nonparametric and Bayesian bootstrap: valid as n grows only.
	bootstrap                 = "asymptotic",
	bayes_boot                = "asymptotic",
	# Resamples the data, so it does not inherit the randomization test's exactness.
	rand_bootstrap            = "asymptotic"
)

#' Regime of each procedure label: a character vector the length of `procedure`,
#' `NA_character_` for a label that is not registered.
#'
#' @keywords internal
#' @noRd
inference_procedure_regime = function(procedure) {
	unname(EDI_INFERENCE_PROCEDURE_REGIME[as.character(procedure)])
}

# ---------------------------------------------------------------------------
# Convergence-rate registry (v1.0.5 TODO-193).
#
# For every design x inference class x procedure triple: how fast the two-sided
# size / coverage error and the bias of the point estimate go to zero, and in
# which sample size. Same file as the regime above so the two cannot disagree.
# Still base R only and side-effect-free (sys.source()d by the calibration job).
#
# Layered, composed by inference_convergence_expectation(). Precedence, most
# specific first:
#     triple > class_design > class > design > procedure
# Within a layer an entry restricted to a procedure beats one that is not, and
# an entry keyed by a design *label* ("DesignFixedBernoulli@prob_T=0.2", the
# calibration study's label) beats one keyed by the bare design class. Fields
# resolve independently: an entry that sets only `n_eff` leaves the orders to
# the layers below it.
#
# Honesty rules: an order is `NA` only together with basis "unknown" (an
# explicit "nobody knows"); a triple whose size order comes only from the
# procedure layer reports basis "assumed_default" unless the procedure is
# exact by construction (class independent). Nothing here is tuned to
# simulation output: no entry has basis "empirical" because the only
# simulations so far are at a single n, which cannot give an order.
# ---------------------------------------------------------------------------

#' Vocabularies of the convergence registry.
#' @keywords internal
#' @noRd
EDI_CONVERGENCE_N_EFF = c(
	"n", "n_pairs", "n_pairs_plus_reservoir", "n_min_arm", "n_events",
	"n_nonzero", "n_clusters", "n_strata"
)
EDI_CONVERGENCE_REGULARITY = c(
	"regular", "boundary", "variance_component", "mixture",
	"nonparametric_rate", "design_mismatch", "other"
)
EDI_CONVERGENCE_BASIS = c("theory", "literature", "empirical", "assumed_default", "unknown")
# Layer name -> precedence rank (higher wins).
EDI_CONVERGENCE_LAYERS = c(procedure = 0L, design = 1L, class = 2L, class_design = 3L, triple = 4L)

#' Procedure layer: the rate in a regular parametric model, one row per
#' sentinel label. `class_independent` marks procedures whose size order is a
#' property of the procedure alone (exact by construction), so their basis is
#' not downgraded to "assumed_default".
#' @keywords internal
#' @noRd
EDI_CONVERGENCE_PROCEDURE_DEFAULTS = {
	# `reference_key`: comma-separated REFERENCES.md citation keys for the size order
	# (v1.0.5 TODO-195); `bias_reference_key` is the same for the bias order.
	r = function(procedure, size_order, bias_order, basis, reference, reference_key, class_independent = FALSE) {
		data.frame(procedure = procedure, size_order = size_order, bias_order = bias_order,
			n_eff = "n", regularity = "regular", basis = basis, reference = reference,
			reference_key = reference_key, bias_reference_key = "CoxSnell1968",
			class_independent = class_independent, stringsAsFactors = FALSE)
	}
	bias_ref = "MLE bias O(n^-1): Cox & Snell (1968)"
	rbind(
		r("exact", Inf, 1, "theory", "Exact by construction (finite-sample validity)", "LehmannRomano2005", TRUE),
		r("rand", Inf, 1, "theory", "Randomization test exact under the sharp null: Fisher (1935); Lehmann & Romano (2005) ch. 15", "Fisher1935, LehmannRomano2005", TRUE),
		r("wald", 1, 1, "theory", paste("Two-sided Edgeworth error O(n^-1): Hall (1992) The Bootstrap and Edgeworth Expansion, ch. 2;", bias_ref), "Hall1992"),
		r("jackknife", 1, 1, "literature", paste("Jackknife variance in a Wald interval, same order as Wald: Shao & Tu (1995) The Jackknife and Bootstrap, ch. 2;", bias_ref), "ShaoTu1995"),
		r("score", 1, 1, "theory", paste("Chi-square approximation error O(n^-1): Barndorff-Nielsen & Cox (1994) Inference and Asymptotics, ch. 6;", bias_ref), "BarndorffNielsenCox1994"),
		r("lik_ratio", 1, 1, "theory", paste("Chi-square approximation error O(n^-1): Barndorff-Nielsen & Cox (1994) ch. 6;", bias_ref), "BarndorffNielsenCox1994"),
		r("gradient", 1, 1, "literature", paste("Same first-order chi-square error as LR/score: Terrell (2002); Lemonte (2016) The Gradient Test;", bias_ref), "Terrell2002, Lemonte2016"),
		r("lik_ratio_bartlett_approx", 2, 1, "literature", paste("Bartlett-corrected LR error O(n^-2): Lawley (1956); Barndorff-Nielsen & Hall (1988). Factor is a Monte-Carlo estimate (inference_ext_bartlett_approx.R), whose noise is not a function of n;", bias_ref), "Lawley1956, BarndorffNielsenHall1988"),
		r("lik_ratio_bartlett_exact", 2, 1, "literature", paste("Bartlett-corrected LR error O(n^-2): Lawley (1956); Barndorff-Nielsen & Hall (1988);", bias_ref), "Lawley1956, BarndorffNielsenHall1988"),
		r("param_boot", 2, 1, "literature", paste("Parametric-bootstrap calibration of an asymptotically pivotal two-sided statistic: Beran (1988); DiCiccio, Martin & Stern (2001);", bias_ref), "Beran1988, DiCiccioMartinStern2001, Hall1992"),
		r("param_boot_direct", 1, 1, "literature", paste("Basic (reflected-quantile) interval, inference_ext_param_bootstrap_estimate.R; percentile-type two-sided error O(n^-1): Hall (1992) ch. 3;", bias_ref), "Hall1992"),
		r("bootstrap", 1, 1, "literature", paste("Equal-tailed percentile, BC, BCa and percentile-t intervals all have two-sided coverage error O(n^-1): Hall (1992) ch. 3. BCa (the default type, globals.R get_bootstrap_dispatch_policy) improves only the one-sided error, O(n^-1) vs O(n^-1/2); it falls back to percentile and several classes are pinned to percentile;", bias_ref), "Hall1992"),
		r("bayes_boot", 1, 1, "literature", paste("Bayesian-bootstrap percentile interval, same order as the percentile bootstrap: Rubin (1981); Lo (1987);", bias_ref), "Rubin1981, Lo1987"),
		r("rand_bootstrap", 1, 1, "assumed_default", paste("Resamples the data (TODO-192 regime note); no derivation of its order was found, bootstrap-type O(n^-1) assumed;", bias_ref), "Hall1992, Kallus2018")
	)
}

#' Procedures in the asymptotic regime (size order is a finite number there).
#' @keywords internal
#' @noRd
EDI_CONVERGENCE_ASYMPTOTIC_PROCEDURES = names(EDI_INFERENCE_PROCEDURE_REGIME)[EDI_INFERENCE_PROCEDURE_REGIME == "asymptotic"]

#' Builds override rows. Vector `design` / `class` / `procedure` arguments
#' expand to one row per combination (`NA` = any). `size_order = "unknown"` /
#' `bias_order = "unknown"` record an explicit unknown (order `NA`).
#' @keywords internal
#' @noRd
edi_convergence_entry = function(layer, design = NA_character_, class = NA_character_, procedure = NA_character_,
		size_order = NA, bias_order = NA, n_eff = NA_character_, regularity = NA_character_,
		basis = NA_character_, reference = NA_character_, reference_key = NA_character_) {
	grid = expand.grid(design = design, class = class, procedure = procedure, stringsAsFactors = FALSE)
	size_unknown = identical(size_order, "unknown")
	bias_unknown = identical(bias_order, "unknown")
	data.frame(
		layer = layer, grid,
		size_order = if (size_unknown) NA_real_ else as.numeric(size_order),
		size_unknown = size_unknown,
		bias_order = if (bias_unknown) NA_real_ else as.numeric(bias_order),
		bias_unknown = bias_unknown,
		n_eff = as.character(n_eff), regularity = as.character(regularity),
		basis = as.character(basis), reference = as.character(reference),
		reference_key = as.character(reference_key),
		stringsAsFactors = FALSE
	)
}

#' Override layers (design, class, class_design, triple). Every entry that sets
#' an order or a regularity carries a basis and a reference.
#' @keywords internal
#' @noRd
EDI_CONVERGENCE_OVERRIDES = local({
	e = edi_convergence_entry
	asy = EDI_CONVERGENCE_ASYMPTOTIC_PROCEDURES
	# Procedures whose variance is a model-based / iid formula that ignores the design.
	# (jackknife, bootstrap, bayes_boot, rand_bootstrap resample in design-aware units
	# in this package, resolve_jackknife_unit() / assert_design_supports_resampling(),
	# so they are not listed: they stay at the procedure default.)
	model_based = c("wald", "score", "lik_ratio", "gradient", "lik_ratio_bartlett_approx",
		"lik_ratio_bartlett_exact", "param_boot", "param_boot_direct")
	# Classes grouped by the property that drives the override.
	simple_unadjusted = c("InferenceAllSimpleAverageDiff", "InferenceAllSimpleMeanDiffPooledVar")
	survival_events = c("InferenceSurvivalCoxPHRegr", "InferenceSurvivalDepCensTransformRegr",
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC", "InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik",
		"InferenceSurvivalGLMMWeibullFrailtyNormalIVWC", "InferenceSurvivalGLMMWeibullFrailtyNormalOneLik",
		"InferenceSurvivalKKLWACoxPHIVWC", "InferenceSurvivalKKLWACoxPHOneLik",
		"InferenceSurvivalKKStratCoxPHIVWC", "InferenceSurvivalKKStratCoxPHOneLik",
		"InferenceSurvivalKKWeibullMarginal", "InferenceSurvivalLogRank",
		"InferenceSurvivalStratCoxPHRegr", "InferenceSurvivalWeibullRegr")
	hurdle_nonzero = c("InferenceCountHurdleNegBin", "InferenceCountHurdlePoisson",
		"InferenceCountKKHurdlePoissonIVWC", "InferenceCountKKHurdlePoissonOneLik")
	incid_events = c("InferenceIncidBinomialIdentityRiskDiff", "InferenceIncidExactBinomial",
		"InferenceIncidExactFisher", "InferenceIncidExactZhang", "InferenceIncidExtendedRobins",
		"InferenceIncidGCompRiskDiff", "InferenceIncidGCompRiskRatio", "InferenceIncidLogBinomial",
		"InferenceIncidLogRegr", "InferenceIncidMiettinenNurminenRiskDiff", "InferenceIncidModifiedPoisson",
		"InferenceIncidNewcombeRiskDiff", "InferenceIncidProbitRegr", "InferenceIncidRiskDiff",
		"InferenceIncidWald")
	kk_pairs_reservoir = c("InferenceAllKKMeanDiffIVWC", "InferenceAllKKWilcoxIVWC",
		"InferenceBaiAdjustedTKK14", "InferenceBaiAdjustedTKK21", "InferenceContinKKGLMM",
		"InferenceContinKKOLSIVWC", "InferenceContinKKOLSOneLik", "InferenceContinKKQuantileRegrIVWC",
		"InferenceContinKKQuantileRegrOneLik", "InferenceContinKKRobustRegrIVWC",
		"InferenceContinKKRobustRegrOneLik", "InferenceCountKKCondPoissonOneLik", "InferenceCountKKGLMM",
		"InferenceCountPoissonKKGEE", "InferenceIncidKKCondLogitGLMMIVWC", "InferenceIncidKKCondLogitGLMMOneLik",
		"InferenceIncidKKCondLogitIVWC", "InferenceIncidKKCondLogitOneLik", "InferenceIncidKKGCompRiskDiff",
		"InferenceIncidKKGCompRiskRatio", "InferenceIncidKKGEE", "InferenceIncidKKModifiedPoisson",
		"InferenceIncidKKNewcombeRiskDiff", "InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMCauchit",
		"InferenceOrdinalKKCLMMCloglog", "InferenceOrdinalKKCLMMProbit", "InferenceOrdinalKKCondAdjCatLogitRegr",
		"InferenceOrdinalKKGEE", "InferenceOrdinalKKGLMM", "InferencePropKKGEE", "InferencePropKKGLMM",
		"InferencePropKKQuantileRegrIVWC", "InferencePropKKQuantileRegrOneLik")
	variance_component = c("InferenceContinKKGLMM", "InferenceCountKKGLMM", "InferencePropKKGLMM",
		"InferenceOrdinalKKGLMM", "InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMCauchit",
		"InferenceOrdinalKKCLMMCloglog", "InferenceOrdinalKKCLMMProbit",
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC", "InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik",
		"InferenceSurvivalGLMMWeibullFrailtyNormalIVWC", "InferenceSurvivalGLMMWeibullFrailtyNormalOneLik")
	quantile_regr = c("InferenceContinQuantileRegr", "InferenceContinKKQuantileRegrIVWC",
		"InferenceContinKKQuantileRegrOneLik", "InferencePropQuantileRegr",
		"InferencePropKKQuantileRegrIVWC", "InferencePropKKQuantileRegrOneLik")
	# Designs that balance covariates or restrict the randomization.
	covariate_balancing = c("DesignFixedBlocking", "DesignFixedOptimalBlocks", "DesignFixedRerandomization",
		"DesignFixedOptimal", "DesignFixedBinaryMatch", "DesignFixedGreedy", "DesignFixedGreedyDOptimal",
		"DesignFixedMatchingGreedyPairSwitching", "DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneSPBR",
		"DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")
	rbind(
		# ---- design layer ----
		# Unequal allocation: the smaller arm drives the constant. The documented
		# small-sample excess of the HC2 / delta-method Wald at prob_T = 0.2, n = 50 is in
		# inference_continuous_lin.R:29, inference_incid_wald.R:18, inference_ordinal_gcomp.R:20,
		# inference_survival_weibull.R:489 (single n, so it fixes the n_eff rule, not an order).
		e("design", design = "DesignFixedBernoulli@prob_T=0.2", procedure = asy, n_eff = "n_min_arm"),
		# Cluster designs: the number of clusters (not applicable to the calibration study).
		e("design", design = c("DesignFixedCluster", "DesignFixedBlockedCluster"), procedure = asy, n_eff = "n_clusters"),

		# ---- class layer: effective n ----
		e("class", class = survival_events, n_eff = "n_events"),
		e("class", class = hurdle_nonzero, n_eff = "n_nonzero"),
		e("class", class = incid_events, n_eff = "n_events"),
		e("class", class = "InferenceIncidCMH", n_eff = "n_strata"),
		e("class", class = "InferenceOrdinalPairedSignTest", n_eff = "n_pairs"),
		e("class", class = setdiff(kk_pairs_reservoir, c(survival_events, hurdle_nonzero)), n_eff = "n_pairs_plus_reservoir"),

		# ---- class layer: rates ----
		# Difference in means is unbiased under (complete / Bernoulli) randomization.
		e("class", class = simple_unadjusted, bias_order = Inf, basis = "theory",
			reference_key = "Neyman1923, ImbensRubin2015",
			reference = "Neyman (1923); Imbens & Rubin (2015) Causal Inference ch. 6: the difference in means is unbiased under randomization"),
		# Density-based (Powell "nid" kernel sparsity) Wald standard error.
		e("class", class = quantile_regr, procedure = "wald", size_order = 2 / 3, regularity = "nonparametric_rate",
			basis = "literature",
			reference_key = "HallSheather1988, Koenker1994, Koenker2005",
			reference = paste("Wald SE is the quantreg 'nid' kernel-sparsity estimate (inference_continuous_quantile_regr.R:16).",
				"Hall & Sheather (1988): studentized sample-quantile interval with estimated sparsity has coverage error O(n^-2/3);",
				"Koenker (1994) uses the same bandwidth for regression quantiles; extension to the regression Wald is by analogy, not proved here")),
		# Random-effect variance near zero.
		e("class", class = variance_component, procedure = asy, size_order = "unknown", regularity = "variance_component",
			basis = "unknown",
			reference_key = "SelfLiang1987, StramLee1994",
			reference = paste("Random-intercept variance near zero is a non-standard limit for variance tests (Self & Liang 1987; Stram & Lee 1994);",
				"its effect on the fixed-effect treatment test is not characterised here. Documented excess: inference_continuous_KK_glmm.R:21 (Wald up to 8.5% at nominal 5%, n = 50)")),
		# Zero / one inflation mixtures.
		e("class", class = c("InferenceCountZeroInflatedPoisson", "InferenceCountZeroInflatedNegBin", "InferencePropZeroOneInflatedBetaRegr"),
			procedure = asy, size_order = "unknown", regularity = "mixture", basis = "unknown",
			reference_key = "SelfLiang1987",
			reference = "Mixture likelihood: the inflation probability can sit on the boundary (inference_count_zero_inflated.R:37), where the information is singular; no rate known"),
		# Boundary MLE.
		e("class", class = "InferenceIncidLogBinomial", procedure = asy, size_order = "unknown", regularity = "boundary", basis = "unknown",
			reference_key = "SelfLiang1987",
			reference = "MLE on the exp(X beta) <= 1 boundary; documented Wald size about 0.17 in boundary fits (inference_incidence_log_binomial.R:729)"),
		e("class", class = "InferenceIncidBinomialIdentityRiskDiff", procedure = asy, size_order = "unknown", regularity = "boundary", basis = "unknown",
			reference_key = "SelfLiang1987",
			reference = "Identity-link MLE can sit on the probability boundary (inference_incidence_binomial_identity.R:411)"),
		# Davies (1977) non-regular case.
		e("class", class = "InferenceOrdinalStereotypeLogitRegr", procedure = asy, size_order = "unknown", regularity = "other", basis = "unknown",
			reference_key = "Davies1977",
			reference = "Category-score parameters are unidentified under the null (Davies 1977), so the LR limit need not be chi-square (inference_ordinal_stereotype_logit.R:792)"),
		# M-estimators with estimated scale.
		e("class", class = c("InferenceContinRobustRegr", "InferenceContinKKRobustRegrIVWC", "InferenceContinKKRobustRegrOneLik"),
			procedure = asy, size_order = "unknown", regularity = "other", basis = "unknown",
			reference_key = "Huber1981",
			reference = "Robust regression with estimated scale: Huber (1981) gives the first-order limit; no Edgeworth order was found. Documented excess: inference_continuous_KK_robust_regr_one_lik.R:589"),

		# ---- class_design layer: design mismatch ----
		# A two-sample pooled-variance / Welch standard error ignores the design's
		# covariate balancing. When the balanced covariates are prognostic (they are in the
		# calibration study) it is conservative by an amount that does not vanish with n.
		# Zero when the covariates are not prognostic: this is an upper-bound statement.
		e("class_design", class = simple_unadjusted, design = covariate_balancing, procedure = model_based,
			size_order = 0, regularity = "design_mismatch", basis = "literature",
			reference_key = "BaiRomanoShaikh2021, BugniCanayShaikh2018, MaHuZhang2015, LiDingRubin2018",
			reference = paste("Conservative two-sample variance under matching / stratification / rerandomization: Bai, Romano & Shaikh (2021 JASA),",
				"Bugni, Canay & Shaikh (2018 JASA), Ma, Hu & Zhang (2015), Li, Ding & Rubin (2018 PNAS)"))

		# ---- triple layer ----
		# Empty on purpose: no single triple is known to differ from what the layers
		# above give. The mechanism is exercised by a synthetic test.
	)
})

#' Problems with the registry's internal consistency (character vector, empty
#' when consistent). Pure: needs neither R6 nor the package. Whether class and
#' design names are real EDI classes is checked in the test suite, because the
#' generators do not exist yet when this file is collated.
#' @keywords internal
#' @noRd
inference_convergence_validate = function(defaults = EDI_CONVERGENCE_PROCEDURE_DEFAULTS, overrides = EDI_CONVERGENCE_OVERRIDES,
		regime = EDI_INFERENCE_PROCEDURE_REGIME) {
	prob = character(0L)
	add = function(...) prob <<- c(prob, sprintf(...))
	order_ok = function(x) is.numeric(x) & !is.na(x) & x >= 0
	d = defaults
	if (!setequal(d$procedure, names(regime)) || anyDuplicated(d$procedure)) add("procedure layer does not cover exactly the regime labels")
	dm = match(d$procedure, names(regime))
	fin = regime[dm] == "finite_sample"
	if (!all(order_ok(d$size_order))) add("procedure layer: size_order must be numeric >= 0 or Inf")
	if (!all(order_ok(d$bias_order))) add("procedure layer: bias_order must be numeric >= 0 or Inf")
	if (any(fin & !is.infinite(d$size_order)) || any(!fin & is.infinite(d$size_order))) add("procedure layer: size_order is Inf exactly for finite-sample procedures")
	if (!all(d$n_eff %in% EDI_CONVERGENCE_N_EFF) || !all(d$regularity %in% EDI_CONVERGENCE_REGULARITY)) add("procedure layer: n_eff / regularity outside vocabulary")
	if (!all(d$basis %in% setdiff(EDI_CONVERGENCE_BASIS, "unknown")) || any(is.na(d$reference) | !nzchar(d$reference))) add("procedure layer: basis outside vocabulary (or 'unknown') or empty reference")
	o = overrides
	if (NROW(o) == 0L) return(prob)
	if (!all(o$layer %in% setdiff(names(EDI_CONVERGENCE_LAYERS), "procedure"))) add("override layer must be one of design, class, class_design, triple")
	shape = list(design = c(TRUE, FALSE), class = c(FALSE, TRUE), class_design = c(TRUE, TRUE), triple = c(TRUE, TRUE))
	for (l in intersect(names(shape), unique(o$layer))) {
		r = o[o$layer == l, , drop = FALSE]
		if (any(is.na(r$design) != !shape[[l]][1L]) || any(is.na(r$class) != !shape[[l]][2L])) add("layer '%s': design / class keys have the wrong shape", l)
		if (l == "triple" && any(is.na(r$procedure))) add("layer 'triple': procedure is required")
	}
	if (!all(is.na(o$procedure) | o$procedure %in% names(regime))) add("override names a procedure that is not a sentinel label")
	key = paste(o$layer, o$design, o$class, o$procedure)
	if (anyDuplicated(key)) add("duplicate override keys: %s", paste(unique(key[duplicated(key)]), collapse = "; "))
	if (!all(is.na(o$n_eff) | o$n_eff %in% EDI_CONVERGENCE_N_EFF)) add("override n_eff outside vocabulary")
	if (!all(is.na(o$regularity) | o$regularity %in% EDI_CONVERGENCE_REGULARITY)) add("override regularity outside vocabulary")
	if (!all(is.na(o$basis) | o$basis %in% EDI_CONVERGENCE_BASIS)) add("override basis outside vocabulary")
	if (any(!is.na(o$size_order) & !order_ok(o$size_order)) || any(!is.na(o$bias_order) & !order_ok(o$bias_order))) add("override orders must be numeric >= 0 or Inf")
	sets_size = !is.na(o$size_order) | o$size_unknown
	sets_bias = !is.na(o$bias_order) | o$bias_unknown
	bearing = sets_size | sets_bias | !is.na(o$regularity)
	if (any(bearing & (is.na(o$basis) | is.na(o$reference) | !nzchar(o$reference)))) add("an entry that sets an order or regularity needs a basis and a reference")
	if (any((o$size_unknown | o$bias_unknown) & !(o$basis %in% "unknown"))) add("an explicit unknown order must carry basis 'unknown'")
	if (any(o$basis %in% "unknown" & !(o$size_unknown | o$bias_unknown))) add("basis 'unknown' needs an explicit unknown order")
	if (any(sets_size & is.na(o$procedure))) add("an entry that sets the size order must name its procedures")
	pr = match(o$procedure, names(regime))
	if (any(sets_size & !is.na(pr) & regime[pr] == "finite_sample")) add("finite-sample procedures keep size_order Inf; an override may not set it")
	if (any(!is.na(o$size_order) & is.infinite(o$size_order))) add("an override may not set an infinite size order")
	# v1.0.5 TODO-195: citation keys are REFERENCES.md keys; only their shape is checked here
	# (this file is base R and cannot read REFERENCES.md; the test suite resolves them).
	key_ok = function(k) is.na(k) | grepl("^[A-Za-z][A-Za-z0-9]*(, [A-Za-z][A-Za-z0-9]*)*$", k)
	for (cn in c("reference_key", "bias_reference_key")) {
		if (cn %in% names(d) && !all(key_ok(d[[cn]]))) add("procedure layer: malformed %s", cn)
		if (cn %in% names(o) && !all(key_ok(o[[cn]]))) add("override: malformed %s", cn)
	}
	prob
}

#' Resolves the convergence expectation of design x class x procedure triples
#' (recycled to a common length). `design` is a design class name or the
#' calibration study's label ("DesignFixedBernoulli@prob_T=0.2"). Returns one
#' row per triple: the TODO-192 `regime`, `size_order`, `bias_order`, `n_eff`,
#' `regularity`, `basis` / `reference` (of the size order), `bias_basis` /
#' `bias_reference`, the matching `reference_key` / `bias_reference_key` (comma-separated
#' REFERENCES.md citation keys), and `<field>_layer` = the layer that supplied each field.
#' An unregistered procedure stops with an error.
#'
#' @keywords internal
#' @noRd
inference_convergence_expectation = function(design, class, procedure,
		defaults = EDI_CONVERGENCE_PROCEDURE_DEFAULTS, overrides = EDI_CONVERGENCE_OVERRIDES) {
	lens = c(length(design), length(class), length(procedure))
	n = if (any(lens == 0L)) 0L else max(lens)
	D = as.character(rep_len(design, n)); C = as.character(rep_len(class, n)); P = as.character(rep_len(procedure, n))
	D_base = sub("@.*$", "", D)
	pi = match(P, defaults$procedure)
	if (anyNA(pi)) stop("unregistered procedure label(s): ", paste(unique(P[is.na(pi)]), collapse = ", "), call. = FALSE)
	regime = inference_procedure_regime(P)
	# Citation keys (v1.0.5 TODO-195); tolerate synthetic tables without the columns.
	col_or_na = function(df, nm, idx) if (nm %in% names(df)) as.character(df[[nm]][idx]) else rep(NA_character_, length(idx))
	out = data.frame(design = D, class = C, procedure = P, regime = regime,
		size_order = defaults$size_order[pi], bias_order = defaults$bias_order[pi],
		n_eff = defaults$n_eff[pi], regularity = defaults$regularity[pi],
		basis = ifelse(defaults$class_independent[pi], defaults$basis[pi], "assumed_default"),
		reference = ifelse(defaults$class_independent[pi], defaults$reference[pi],
			paste0("procedure default, class and design not examined: ", defaults$reference[pi])),
		bias_basis = ifelse(defaults$class_independent[pi], defaults$basis[pi], "assumed_default"),
		bias_reference = ifelse(defaults$class_independent[pi], defaults$reference[pi],
			paste0("procedure default, class and design not examined: ", defaults$reference[pi])),
		reference_key = col_or_na(defaults, "reference_key", pi), bias_reference_key = col_or_na(defaults, "bias_reference_key", pi),
		size_layer = rep("procedure", n), bias_layer = rep("procedure", n), n_eff_layer = rep("procedure", n),
		regularity_layer = rep("procedure", n), stringsAsFactors = FALSE)
	score = list(size = numeric(n), bias = numeric(n), n_eff = numeric(n), regularity = numeric(n))
	for (i in seq_len(NROW(overrides))) {
		e = overrides[i, , drop = FALSE]
		hit = (is.na(e$design) | D == e$design | D_base == e$design) &
			(is.na(e$class) | C == e$class) & (is.na(e$procedure) | P == e$procedure)
		if (!any(hit)) next
		idx = which(hit)
		s = unname(EDI_CONVERGENCE_LAYERS[e$layer]) * 10 + (!is.na(e$procedure)) + 2 * (!is.na(e$design) && grepl("@", e$design, fixed = TRUE))
		take = function(field) idx[score[[field]][idx] < s]
		k = if (e$size_unknown || !is.na(e$size_order)) take("size") else integer(0L)
		if (length(k)) {
			out$size_order[k] = if (e$size_unknown) NA_real_ else e$size_order
			out$basis[k] = e$basis; out$reference[k] = e$reference
			out$reference_key[k] = col_or_na(e, "reference_key", 1L)
			out$size_layer[k] = e$layer; score$size[k] = s
		}
		k = if (e$bias_unknown || !is.na(e$bias_order)) take("bias") else integer(0L)
		if (length(k)) {
			out$bias_order[k] = if (e$bias_unknown) NA_real_ else e$bias_order
			out$bias_basis[k] = e$basis; out$bias_reference[k] = e$reference
			out$bias_reference_key[k] = col_or_na(e, "reference_key", 1L)
			out$bias_layer[k] = e$layer; score$bias[k] = s
		}
		k = if (!is.na(e$n_eff)) take("n_eff") else integer(0L)
		if (length(k)) { out$n_eff[k] = e$n_eff; out$n_eff_layer[k] = e$layer; score$n_eff[k] = s }
		k = if (!is.na(e$regularity)) take("regularity") else integer(0L)
		if (length(k)) { out$regularity[k] = e$regularity; out$regularity_layer[k] = e$layer; score$regularity[k] = s }
	}
	out
}
