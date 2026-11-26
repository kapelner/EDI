library(testthat)
library(EDI)

# v1.0.6-TODO-230: InferenceCountZeroInflatedPoisson, InferenceCountHurdlePoisson,
# InferenceCountZeroInflatedNegBin and InferenceCountHurdleNegBin listed score /
# gradient / lik_ratio / lik_ratio_bartlett_approx in get_supported_testing_types(),
# but compute_asymp_confidence_interval() / compute_asymp_two_sided_pval() always
# returned the Wald result ("the testing type you ask for is the test you get",
# DECISION-v1.0.6-TODO-380c). Checks, per class and supported type, that the asymp
# p-value and CI equal the direct compute_<type>_*() method on a fresh object, that
# Wald is unchanged, and that an unknown type stops. Also: the hurdle NegBin direct
# compute_gradient_confidence_interval() inverted the configured type (Wald by
# default), so it returned the Wald interval.
#
# The Bartlett factor is stubbed to 1 (as in
# test-asymp-ci-and-pval-defined-for-every-supported-testing-type.R) to keep the
# file fast; the factor itself is covered elsewhere.

za_tt_classes = c("InferenceCountZeroInflatedPoisson", "InferenceCountHurdlePoisson",
	"InferenceCountZeroInflatedNegBin", "InferenceCountHurdleNegBin")

za_tt_design = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(100)
		n = 40L
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		y = c(rep(0L, 8L), rpois(n - 8L, 3))
		d = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
		d$add_all_subjects_to_experiment(X)
		d$assign_w_to_all_subjects()
		d$add_all_subject_responses(y)
		cache <<- d
		d
	}
})

za_tt_new = function(cn, testing_type = NULL) {
	inf = suppressWarnings(get(cn, envir = asNamespace("EDI"))$new(za_tt_design(), verbose = FALSE))
	pe = inf$.__enclos_env__$private
	if (exists("get_bartlett_factor_approx", envir = pe, inherits = FALSE)) {
		locked = bindingIsLocked("get_bartlett_factor_approx", pe)
		if (locked) unlockBinding("get_bartlett_factor_approx", pe)
		assign("get_bartlett_factor_approx", function(...) 1, envir = pe)
		if (locked) lockBinding("get_bartlett_factor_approx", pe)
	}
	if (!is.null(testing_type)) inf$set_testing_type(testing_type)
	inf
}

test_that("each zero-augmented count class lists the four likelihood types besides Wald", {
	for (cn in za_tt_classes) {
		expect_setequal(za_tt_new(cn)$get_supported_testing_types(),
			c("wald", "score", "gradient", "lik_ratio", "lik_ratio_bartlett_approx"))
	}
})

test_that("compute_asymp_*() equals the direct compute_<type>_*() method for every supported type", {
	n_checked = 0L
	for (cn in za_tt_classes) {
		wald_pv = suppressWarnings(za_tt_new(cn, "wald")$compute_asymp_two_sided_pval())
		for (tt in setdiff(za_tt_new(cn)$get_supported_testing_types(), "wald")) {
			label = paste(cn, tt)
			asymp = za_tt_new(cn, tt)
			direct = za_tt_new(cn)
			pv = suppressWarnings(asymp$compute_asymp_two_sided_pval(delta = 0))
			ci = suppressWarnings(asymp$compute_asymp_confidence_interval(alpha = 0.05))
			pv_direct = suppressWarnings(direct[[paste0("compute_", tt, "_two_sided_pval")]](delta = 0))
			ci_direct = suppressWarnings(direct[[paste0("compute_", tt, "_confidence_interval")]](alpha = 0.05))
			expect_true(is.finite(pv) && pv > 0 && pv < 1, info = label)
			expect_true(all(is.finite(ci)) && ci[1] < ci[2], info = label)
			expect_equal(pv, pv_direct, tolerance = 1e-10, info = label)
			expect_equal(as.numeric(ci), as.numeric(ci_direct), tolerance = 1e-10, info = label)
			# The bug: every type returned the Wald p-value.
			expect_false(isTRUE(all.equal(pv, wald_pv, tolerance = 1e-8)), info = label)
			# The interval inverts the same test: p at each bound is alpha.
			expect_equal(suppressWarnings(asymp$compute_asymp_two_sided_pval(delta = ci[1])), 0.05, tolerance = 1e-2, info = label)
			expect_equal(suppressWarnings(asymp$compute_asymp_two_sided_pval(delta = ci[2])), 0.05, tolerance = 1e-2, info = label)
			n_checked = n_checked + 1L
		}
	}
	expect_equal(n_checked, 16L)
})

test_that("Wald results are unchanged and equal the direct Wald methods", {
	# Pre-fix values on this fixture (Wald was the only path before v1.0.6-TODO-230).
	expected = list(
		InferenceCountZeroInflatedPoisson = c(0.655285, -0.576724, 0.362738),
		InferenceCountHurdlePoisson = c(0.565830, -0.562950, 0.307839),
		InferenceCountZeroInflatedNegBin = c(0.661507, -0.581682, 0.369254),
		InferenceCountHurdleNegBin = c(0.593405, -0.595971, 0.340790)
	)
	for (cn in za_tt_classes) {
		inf = za_tt_new(cn, "wald")
		got = suppressWarnings(c(inf$compute_asymp_two_sided_pval(), inf$compute_asymp_confidence_interval()))
		expect_equal(as.numeric(got), expected[[cn]], tolerance = 1e-5, info = cn)
		direct = za_tt_new(cn)
		expect_equal(as.numeric(got),
			as.numeric(suppressWarnings(c(direct$compute_wald_two_sided_pval(), direct$compute_wald_confidence_interval()))),
			tolerance = 1e-10, info = cn)
	}
})

test_that("an unknown testing type stops instead of returning Wald", {
	for (cn in za_tt_classes) {
		inf = za_tt_new(cn)
		expect_error(inf$set_testing_type("lik_ratio_bartlett_exact"), info = cn)
		# Bypass set_testing_type()'s own check to reach the dispatch default.
		inf$.__enclos_env__$private$testing_type = "not_a_testing_type"
		expect_error(inf$compute_asymp_two_sided_pval(), "Unsupported testing_type", info = cn)
		expect_error(inf$compute_asymp_confidence_interval(), "Unsupported testing_type", info = cn)
	}
})

test_that("hurdle NegBin's direct gradient CI inverts the gradient test, not the configured Wald", {
	inf = za_tt_new("InferenceCountHurdleNegBin")
	expect_identical(inf$get_testing_type(), "wald")
	ci_grad = suppressWarnings(inf$compute_gradient_confidence_interval())
	ci_wald = suppressWarnings(za_tt_new("InferenceCountHurdleNegBin")$compute_wald_confidence_interval())
	expect_false(isTRUE(all.equal(as.numeric(ci_grad), as.numeric(ci_wald), tolerance = 1e-6)))
	expect_equal(suppressWarnings(inf$compute_gradient_two_sided_pval(delta = ci_grad[1])), 0.05, tolerance = 1e-2)
	expect_equal(suppressWarnings(inf$compute_gradient_two_sided_pval(delta = ci_grad[2])), 0.05, tolerance = 1e-2)
})
