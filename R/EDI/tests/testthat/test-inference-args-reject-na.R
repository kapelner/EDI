library(testthat)
library(EDI)

# v1.0.6-TODO-100: checkmate's assertNumeric() defaults to any.missing = TRUE,
# so alpha = NA, delta = NA, pval_epsilon = NA, tau = NA, ... used to pass the
# argument checks and come back as an NA interval or p-value. Every
# assertNumeric() on such a scalar now says any.missing = FALSE. This file
# calls the public inference entry points with an NA argument and expects an
# error instead of a returned value.
#
# Not covered (no assertNumeric to tighten; the method has no argument check at
# all and still returns NA on an NA argument): the classes' own overrides of
# compute_asymp_*/wald/score/gradient/lik_ratio p-values, the jackknife Wald
# methods in some classes, and the few (class, method) pairs in
# na_arg_unguarded below. They are tracked as v1.0.6-TODO-105 (sweep:
# R/package_tests/sweep_na_argument_guards.R).

na_arg_fixtures = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(100)
		n = 24L
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		ys = list(
			continuous = rnorm(n), incidence = rbinom(n, 1, 0.5), proportion = runif(n, 0.05, 0.95),
			count = c(rep(0L, 8L), rpois(n - 8L, 3)), survival = rexp(n) + 0.1, ordinal = sample(1:4, n, TRUE)
		)
		mk = function(gen, rt) {
			d = gen$new(n = n, response_type = rt, verbose = FALSE)
			d$add_all_subjects_to_experiment(X)
			d$assign_w_to_all_subjects()
			d$add_all_subject_responses(ys[[rt]])
			d
		}
		out = list()
		for (rt in names(ys)) {
			out[[paste0("bern_", rt)]] = mk(DesignFixedBernoulli, rt)
			out[[paste0("match_", rt)]] = suppressWarnings(mk(DesignFixedBinaryMatch, rt))
		}
		cache <<- out
		out
	}
})

na_arg_build = function(cn) {
	gen = get(cn, envir = asNamespace("EDI"))
	for (d in na_arg_fixtures()) {
		inf = tryCatch(suppressWarnings(suppressMessages(gen$new(d, verbose = FALSE))), error = function(e) NULL)
		if (!is.null(inf)) return(inf)
	}
	NULL
}

# Calls inf[[method]] with `arg` = NA (plus small B / r). Returns "error" with
# the message, or "returned".
na_arg_call = function(inf, method, arg) {
	f = inf[[method]]
	fm = names(formals(f))
	args = stats::setNames(list(NA_real_), arg)
	if ("B" %in% fm) args$B = 11L
	if ("r" %in% fm) args$r = 11L
	if ("show_progress" %in% fm) args$show_progress = FALSE
	tryCatch({
		suppressWarnings(suppressMessages(do.call(f, args)))
		list(outcome = "returned", msg = "")
	}, error = function(e) list(outcome = "error", msg = conditionMessage(e)))
}

na_arg_inference_classes = function() {
	exps = sort(grep("^Inference", getNamespaceExports("EDI"), value = TRUE))
	exps = setdiff(exps, c("InferenceSuite", "InferenceRandCustom"))
	Filter(function(cn) inherits(get(cn, envir = asNamespace("EDI")), "R6ClassGenerator"), exps)
}

# Methods whose argument check lives in a shared base class (bootstrap,
# Bayesian bootstrap, m-out-of-n, subsampling, randomization, exact,
# Bartlett/bootstrap likelihood-ratio intervals, log-rank).
na_arg_shared_method_regex = paste0(
	"^compute_(bootstrap_confidence_interval|bootstrap_two_sided_pval|",
	"bayesian_bootstrap_(confidence_interval|two_sided_pval)|",
	"m_out_of_n_bootstrap_(confidence_interval|two_sided_pval)|",
	"subsampling_(confidence_interval|two_sided_pval)|",
	"rand_two_sided_pval|rand_confidence_interval|",
	"exact_confidence_interval|exact_two_sided_pval_for_treatment_effect|",
	"lik_ratio_bartlett(_exact|_approx)?_confidence_interval|",
	"lik_ratio_bootstrap_(confidence_interval|two_sided_pval)|",
	"asymp_log_rank_two_sided_pval_for_treatment_effect)(_generic)?$"
)

# Overrides with no argument check of their own (v1.0.6-TODO-105): the
# G-computation risk-ratio subsampling / m-out-of-n paths (private
# compute_rr_*() helpers) and the dependent-censoring randomization stubs, which
# return NA as "unsupported" without reading their arguments.
na_arg_unguarded = c(
	"InferenceIncidGCompRiskRatio:compute_subsampling_confidence_interval",
	"InferenceIncidGCompRiskRatio:compute_subsampling_two_sided_pval",
	"InferenceIncidGCompRiskRatio:compute_m_out_of_n_bootstrap_confidence_interval",
	"InferenceIncidGCompRiskRatio:compute_m_out_of_n_bootstrap_two_sided_pval",
	"InferenceIncidKKGCompRiskRatio:compute_subsampling_confidence_interval",
	"InferenceIncidKKGCompRiskRatio:compute_subsampling_two_sided_pval",
	"InferenceIncidKKGCompRiskRatio:compute_m_out_of_n_bootstrap_confidence_interval",
	"InferenceIncidKKGCompRiskRatio:compute_m_out_of_n_bootstrap_two_sided_pval",
	"InferenceSurvivalDepCensTransformRegr:compute_rand_confidence_interval",
	"InferenceSurvivalDepCensTransformRegr:compute_rand_two_sided_pval"
)

test_that("shared resampling / exact / likelihood-ratio entry points reject NA alpha, delta and pval_epsilon", {
	n_checked = 0L
	n_missing_msg = 0L
	for (cn in na_arg_inference_classes()) {
		inf = na_arg_build(cn)
		expect_false(is.null(inf), info = paste(cn, "has no fixture"))
		if (is.null(inf)) next
		meths = grep(na_arg_shared_method_regex, names(inf), value = TRUE)
		for (m in meths) {
			if (paste0(cn, ":", m) %in% na_arg_unguarded) next
			if (!is.function(inf[[m]])) next
			for (a in intersect(c("alpha", "delta", "pval_epsilon"), names(formals(inf[[m]])))) {
				res = na_arg_call(inf, m, a)
				n_checked = n_checked + 1L
				expect_identical(res$outcome, "error", info = paste0(cn, "$", m, "(", a, " = NA)"))
				# the error is checkmate's (not an incidental failure further in),
				# unless the method is unsupported for this class
				if (grepl("missing values", res$msg)) n_missing_msg = n_missing_msg + 1L
				else expect_match(res$msg, "not (supported|implemented)|does not support|Use Zhang",
					info = paste0(cn, "$", m, "(", a, " = NA): ", res$msg))
			}
		}
	}
	expect_gt(n_checked, 400L)
	expect_gt(n_missing_msg, 350L)
})

test_that("classes whose own asymptotic methods were tightened reject NA alpha and delta", {
	classes = c(
		"InferenceAllKKMeanDiffIVWC", "InferenceAllKKWilcoxIVWC", "InferenceAllSimpleMeanDiffPooledVar",
		"InferenceBaiAdjustedTKK14", "InferenceBaiAdjustedTKK21", "InferenceContinKKOLSIVWC",
		"InferenceContinKKOLSOneLik", "InferenceContinKKQuantileRegrIVWC",
		"InferenceContinKKQuantileRegrOneLik", "InferenceContinKKRobustRegrIVWC",
		"InferenceContinKKRobustRegrOneLik", "InferenceContinLin", "InferenceContinQuantileRegr",
		"InferenceContinRobustRegr", "InferenceCountHurdleNegBin", "InferenceCountHurdlePoisson",
		"InferenceCountKKHurdlePoissonIVWC", "InferenceCountPoisson",
		"InferenceCountPoissonKKGEE", "InferenceCountZeroInflatedNegBin",
		"InferenceCountZeroInflatedPoisson", "InferenceIncidGCompRiskDiff",
		"InferenceIncidGCompRiskRatio", "InferenceIncidKKGCompRiskDiff",
		"InferenceIncidKKGCompRiskRatio", "InferenceIncidKKGEE", "InferenceIncidKKModifiedPoisson",
		"InferenceIncidKKNewcombeRiskDiff", "InferenceIncidNewcombeRiskDiff",
		"InferenceIncidWald", "InferenceOrdinalGCompMeanDiff", "InferenceOrdinalJonckheereTerpstraTest",
		"InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMCauchit", "InferenceOrdinalKKCLMMCloglog",
		"InferenceOrdinalKKCLMMProbit", "InferenceOrdinalKKGEE", "InferenceOrdinalPartialProportionalOddsRegr",
		"InferencePropGCompMeanDiff", "InferencePropKKGEE", "InferencePropKKQuantileRegrIVWC",
		"InferencePropKKQuantileRegrOneLik", "InferencePropQuantileRegr",
		"InferenceSurvivalGehanWilcox", "InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC",
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik", "InferenceSurvivalGLMMWeibullFrailtyNormalIVWC",
		"InferenceSurvivalKKLWACoxPHIVWC", "InferenceSurvivalKKLWACoxPHOneLik",
		"InferenceSurvivalKKRankRegrIVWC", "InferenceSurvivalKKStratCoxPHIVWC",
		"InferenceSurvivalKKStratCoxPHOneLik", "InferenceSurvivalKKWeibullMarginal",
		"InferenceSurvivalKMDiff", "InferenceSurvivalLogRank", "InferenceSurvivalRestrictedMeanDiff"
	)
	for (cn in classes) {
		inf = na_arg_build(cn)
		expect_false(is.null(inf), info = cn)
		if (is.null(inf)) next
		res = na_arg_call(inf, "compute_asymp_confidence_interval", "alpha")
		expect_match(res$msg, "missing values", info = paste(cn, "alpha"))
		res = na_arg_call(inf, "compute_asymp_two_sided_pval", "delta")
		expect_match(res$msg, "missing values", info = paste(cn, "delta"))
	}
})

test_that("tau, acc, delta_0 and root_tolerance reject NA", {
	fx = na_arg_fixtures()
	expect_error(InferenceContinQuantileRegr$new(fx$bern_continuous, tau = NA_real_, verbose = FALSE), "missing values")
	expect_error(InferencePropQuantileRegr$new(fx$bern_proportion, tau = NA_real_, verbose = FALSE), "missing values")
	expect_error(InferenceContinKKQuantileRegrOneLik$new(fx$match_continuous, tau = NA_real_, verbose = FALSE), "missing values")
	expect_error(InferenceContinKKQuantileRegrIVWC$new(fx$match_continuous, tau = NA_real_, verbose = FALSE), "missing values")
	expect_error(InferenceContinKKRobustRegrOneLik$new(fx$match_continuous, acc = NA_real_, verbose = FALSE), "missing values")
	expect_error(InferenceContinKKRobustRegrIVWC$new(fx$match_continuous, acc = NA_real_, verbose = FALSE), "missing values")

	# get_exact_fisher_htest() is private; its public callers are the exact methods
	fisher = InferenceIncidExactFisher$new(fx$match_incidence, verbose = FALSE)
	fisher_priv = fisher$.__enclos_env__$private
	expect_error(fisher_priv$get_exact_fisher_htest(delta_0 = NA_real_), "missing values")
	expect_error(fisher_priv$get_exact_fisher_htest(alpha = NA_real_), "missing values")

	pois = InferenceCountPoisson$new(fx$bern_count, verbose = FALSE)
	expect_error(pois$compute_lik_ratio_bootstrap_confidence_interval(B = 11L, root_tolerance = NA_real_), "missing values")
})
