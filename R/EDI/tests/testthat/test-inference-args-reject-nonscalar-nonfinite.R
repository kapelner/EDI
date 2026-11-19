library(testthat)
library(EDI)

# v1.0.6-TODO-106 (audit of checkmate defaults beyond any.missing): the alpha,
# delta, pval_epsilon, tau and acc asserts had no len = 1, so a length-2 alpha
# gave a four-number "interval" and a length-2 delta a vector of p-values, and
# delta had no finite = TRUE, so delta = Inf returned p = 0. The alpha upper bound
# was 1 - .Machine$double.xmin, which equals 1 in double precision, so alpha = 1
# passed too (a zero-width interval); it is now 1 - .Machine$double.eps. This
# file calls the same public entry points as test-inference-args-reject-na.R with
# a length-2, infinite or unit argument and expects checkmate's error instead of
# a returned value.
#
# Same exclusions as that file: the classes' own overrides with no argument
# check at all (v1.0.6-TODO-105) and the pairs in nsnf_unguarded below.

nsnf_fixtures = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(106)
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

nsnf_build = function(cn) {
	gen = get(cn, envir = asNamespace("EDI"))
	for (d in nsnf_fixtures()) {
		inf = tryCatch(suppressWarnings(suppressMessages(gen$new(d, verbose = FALSE))), error = function(e) NULL)
		if (!is.null(inf)) return(inf)
	}
	NULL
}

nsnf_call = function(inf, method, arg, value) {
	f = inf[[method]]
	fm = names(formals(f))
	args = stats::setNames(list(value), arg)
	if ("B" %in% fm) args$B = 11L
	if ("r" %in% fm) args$r = 11L
	if ("show_progress" %in% fm) args$show_progress = FALSE
	tryCatch({
		suppressWarnings(suppressMessages(do.call(f, args)))
		list(outcome = "returned", msg = "")
	}, error = function(e) list(outcome = "error", msg = conditionMessage(e)))
}

nsnf_inference_classes = function() {
	exps = sort(grep("^Inference", getNamespaceExports("EDI"), value = TRUE))
	exps = setdiff(exps, c("InferenceSuite", "InferenceRandCustom"))
	Filter(function(cn) inherits(get(cn, envir = asNamespace("EDI")), "R6ClassGenerator"), exps)
}

nsnf_shared_method_regex = paste0(
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

# Same as na_arg_unguarded in test-inference-args-reject-na.R (v1.0.6-TODO-105), plus
# InferenceIncidKKCondLogitOneLik's compute_rand_two_sided_pval override, which returns NA
# before reaching the shared argument check when the fitted estimate is not finite (as on
# this fixture); also v1.0.6-TODO-105.
nsnf_unguarded = c(
	"InferenceIncidKKCondLogitOneLik:compute_rand_two_sided_pval",
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

nsnf_bad_values = list(
	alpha = list(two = c(0.05, 0.1), one = 1),
	delta = list(inf = Inf, neg_inf = -Inf, two = c(0, 1)),
	pval_epsilon = list(two = c(0.005, 0.01))
)
nsnf_expected_msg = "Must have length 1|Must be finite|Element 1 is not <="
nsnf_unsupported_msg = "not (supported|implemented)|does not support|Use Zhang"

test_that("shared resampling / exact / likelihood-ratio entry points reject length-2 and infinite alpha, delta and pval_epsilon", {
	n_checked = 0L
	n_checkmate_msg = 0L
	for (cn in nsnf_inference_classes()) {
		inf = nsnf_build(cn)
		expect_false(is.null(inf), info = paste(cn, "has no fixture"))
		if (is.null(inf)) next
		meths = grep(nsnf_shared_method_regex, names(inf), value = TRUE)
		for (m in meths) {
			if (paste0(cn, ":", m) %in% nsnf_unguarded) next
			if (!is.function(inf[[m]])) next
			for (a in intersect(names(nsnf_bad_values), names(formals(inf[[m]])))) {
				for (vn in names(nsnf_bad_values[[a]])) {
					res = nsnf_call(inf, m, a, nsnf_bad_values[[a]][[vn]])
					label = paste0(cn, "$", m, "(", a, " = ", vn, ")")
					n_checked = n_checked + 1L
					expect_identical(res$outcome, "error", info = label)
					if (grepl(nsnf_expected_msg, res$msg)) n_checkmate_msg = n_checkmate_msg + 1L
					else expect_match(res$msg, nsnf_unsupported_msg, info = paste0(label, ": ", res$msg))
				}
			}
		}
	}
	expect_gt(n_checked, 600L)
	expect_gt(n_checkmate_msg, 500L)
})

test_that("classes whose own asymptotic methods assert alpha and delta reject length-2 and infinite values", {
	classes = c(
		"InferenceAllKKMeanDiffIVWC", "InferenceAllSimpleMeanDiffPooledVar", "InferenceContinLin",
		"InferenceContinKKOLSOneLik", "InferenceContinQuantileRegr", "InferenceCountPoisson",
		"InferenceCountHurdlePoisson", "InferenceIncidGCompRiskDiff", "InferenceIncidNewcombeRiskDiff",
		"InferenceOrdinalPartialProportionalOddsRegr", "InferencePropGCompMeanDiff",
		"InferenceSurvivalKMDiff", "InferenceSurvivalLogRank", "InferenceSurvivalRestrictedMeanDiff"
	)
	for (cn in classes) {
		inf = nsnf_build(cn)
		expect_false(is.null(inf), info = cn)
		if (is.null(inf)) next
		res = nsnf_call(inf, "compute_asymp_confidence_interval", "alpha", c(0.05, 0.1))
		expect_match(res$msg, "Must have length 1", info = paste(cn, "alpha"))
		res = nsnf_call(inf, "compute_asymp_confidence_interval", "alpha", 1)
		expect_match(res$msg, "not <=", info = paste(cn, "alpha = 1"))
		res = nsnf_call(inf, "compute_asymp_two_sided_pval", "delta", Inf)
		expect_match(res$msg, "Must be finite", info = paste(cn, "delta = Inf"))
		res = nsnf_call(inf, "compute_asymp_two_sided_pval", "delta", c(0, 1))
		expect_match(res$msg, "Must have length 1", info = paste(cn, "delta length 2"))
	}
	# a valid scalar still works
	inf = nsnf_build("InferenceAllSimpleMeanDiffPooledVar")
	expect_true(is.finite(inf$compute_asymp_two_sided_pval(delta = 0.25)))
	expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
})

test_that("tau, acc and root_tolerance reject length-2 or infinite values", {
	fx = nsnf_fixtures()
	expect_error(InferenceContinQuantileRegr$new(fx$bern_continuous, tau = c(0.25, 0.75), verbose = FALSE), "Must have length 1")
	expect_error(InferencePropQuantileRegr$new(fx$bern_proportion, tau = c(0.25, 0.75), verbose = FALSE), "Must have length 1")
	expect_error(InferenceContinKKRobustRegrOneLik$new(fx$match_continuous, acc = c(1e-6, 1e-4), verbose = FALSE), "Must have length 1")
	pois = InferenceCountPoisson$new(fx$bern_count, verbose = FALSE)
	expect_error(pois$compute_lik_ratio_bootstrap_confidence_interval(B = 39L, root_tolerance = Inf), "Must be finite")
	expect_error(pois$compute_lik_ratio_bootstrap_confidence_interval(B = 39L, root_tolerance = c(0.1, 0.2)), "Must have length 1")
})

test_that("randomization show_progress and na.rm must be a single TRUE/FALSE", {
	fx = nsnf_fixtures()
	inf = InferenceAllSimpleMeanDiffPooledVar$new(fx$bern_continuous, verbose = FALSE)
	expect_error(inf$compute_rand_two_sided_pval(r = 11L, na.rm = NA, show_progress = FALSE), "na.rm")
	expect_error(inf$compute_rand_two_sided_pval(r = 11L, na.rm = c(TRUE, FALSE), show_progress = FALSE), "na.rm")
	expect_error(inf$compute_rand_confidence_interval(r = 11L, show_progress = NA), "show_progress")
})

test_that("InferenceRandCustom rejects a statistic that cannot take (y, w, dead)", {
	d = nsnf_fixtures()$bern_continuous
	expect_error(
		InferenceRandCustom$new(d, custom_randomization_statistic_function = function(y, w) mean(y[w == 1]) - mean(y[w == 0])),
		"three arguments"
	)
	expect_s3_class(InferenceRandCustom$new(d, custom_randomization_statistic_function = function(y, w, dead) 1), "InferenceRandCustom")
	expect_s3_class(InferenceRandCustom$new(d, custom_randomization_statistic_function = function(...) 1), "InferenceRandCustom")
})

test_that("InferenceSuite run_all_inference rejects alpha in {0, 1}, max_secs_per_class = 0 and NA class names", {
	d = nsnf_fixtures()$bern_continuous
	s = InferenceSuite$new(d)
	expect_error(s$run_all_inference(screen = TRUE, alpha = 0), "alpha")
	expect_error(s$run_all_inference(screen = TRUE, alpha = 1), "alpha")
	expect_error(s$run_all_inference(screen = TRUE, max_secs_per_class = 0), "max_secs_per_class")
	expect_error(s$run_all_inference(screen = TRUE, classes = NA_character_), "classes")
	expect_error(s$run_all_inference(screen = TRUE, exclude_classes = NA_character_), "exclude_classes")
})
