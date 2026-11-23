library(testthat)
library(EDI)

# v1.0.6-TODO-380 (owner decisions 2026-11-21): testing_type
# "lik_ratio_bartlett_approx_design_conservative" on InferenceCountPoisson,
# InferenceCountKKCondPoissonOneLik and InferenceCountKKHurdlePoissonOneLik is
# the larger of the model-only Bartlett-corrected LR p-value and the design Wald
# p-value, and the union of the two intervals. "lik_ratio_bartlett_approx" is the
# model-only test on all three; on InferenceCountPoisson it used to be the
# design-conservative one, which the new type now returns.
#
# Runtime: the Monte-Carlo Bartlett factor is replaced by a constant (as in
# test-asymp-ci-and-pval-defined-for-every-supported-testing-type.R); the
# combination rule, not the factor, is under test here.

bdc_type = "lik_ratio_bartlett_approx_design_conservative"

bdc_fixtures = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(380)
		n = 40L
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		y = c(rep(0L, 8L), rpois(n - 8L, 3))
		mk = function(gen) {
			d = gen$new(n = n, response_type = "count", verbose = FALSE)
			d$add_all_subjects_to_experiment(X)
			d$assign_w_to_all_subjects()
			d$add_all_subject_responses(y)
			d
		}
		cache <<- list(bern = mk(DesignFixedBernoulli), match = suppressWarnings(mk(DesignFixedBinaryMatch)))
		cache
	}
})

bdc_stub_bartlett_factor = function(inf, factor = 1.3) {
	pe = inf$.__enclos_env__$private
	locked = bindingIsLocked("get_bartlett_factor_approx", pe)
	if (locked) unlockBinding("get_bartlett_factor_approx", pe)
	assign("get_bartlett_factor_approx", function(...) factor, envir = pe)
	if (locked) lockBinding("get_bartlett_factor_approx", pe)
	inf
}

bdc_new = function(gen, d, testing_type = NULL) {
	inf = suppressWarnings(suppressMessages(gen$new(d, verbose = FALSE)))
	bdc_stub_bartlett_factor(inf)
	if (!is.null(testing_type)) inf$set_testing_type(testing_type)
	inf
}

test_that("the three classes list the new type and the others reject it", {
	f = bdc_fixtures()
	for (case in list(list(InferenceCountPoisson, f$bern), list(InferenceCountKKCondPoissonOneLik, f$match),
			list(InferenceCountKKHurdlePoissonOneLik, f$match))) {
		inf = bdc_new(case[[1]], case[[2]])
		expect_true(all(c("lik_ratio_bartlett_approx", bdc_type) %in% inf$get_supported_testing_types()),
			info = class(inf)[1])
	}
	negbin = suppressWarnings(InferenceCountNegBin$new(f$bern, verbose = FALSE))
	expect_false(bdc_type %in% negbin$get_supported_testing_types())
	expect_error(negbin$set_testing_type(bdc_type), "does not support")
})

test_that("KK count OneLik: the new type is the max p-value and the union interval of model-only Bartlett and design Wald", {
	f = bdc_fixtures()
	for (gen in list(InferenceCountKKCondPoissonOneLik, InferenceCountKKHurdlePoissonOneLik)) {
		ref = bdc_new(gen, f$match)
		ci_bartlett = suppressWarnings(ref$compute_lik_ratio_bartlett_approx_confidence_interval(alpha = 0.05))
		p_bartlett = suppressWarnings(ref$compute_lik_ratio_bartlett_approx_two_sided_pval(delta = 0))
		ref_w = bdc_new(gen, f$match)
		ci_wald = suppressWarnings(ref_w$compute_wald_confidence_interval(alpha = 0.05))
		p_wald = suppressWarnings(ref_w$compute_wald_two_sided_pval(delta = 0))
		label = class(ref)[1]
		expect_true(all(is.finite(ci_bartlett)) && all(is.finite(ci_wald)), info = label)
		expect_true(is.finite(p_bartlett) && is.finite(p_wald), info = label)

		inf = bdc_new(gen, f$match, bdc_type)
		ci = suppressWarnings(inf$compute_asymp_confidence_interval(alpha = 0.05))
		p = suppressWarnings(inf$compute_asymp_two_sided_pval(delta = 0))
		expect_identical(names(ci), c("2.5%", "97.5%"), info = label)
		expect_equal(unname(ci), c(min(ci_bartlett[1], ci_wald[1]), max(ci_bartlett[2], ci_wald[2])), tolerance = 1e-8, info = label)
		expect_true(ci[1] <= ci_bartlett[1] + 1e-8 && ci[2] >= ci_bartlett[2] - 1e-8, info = label)
		expect_true(ci[1] <= ci_wald[1] + 1e-8 && ci[2] >= ci_wald[2] - 1e-8, info = label)
		expect_equal(p, max(p_bartlett, p_wald), tolerance = 1e-8, info = label)

		# "lik_ratio_bartlett_approx" stays the model-only test
		inf_b = bdc_new(gen, f$match, "lik_ratio_bartlett_approx")
		expect_equal(suppressWarnings(inf_b$compute_asymp_confidence_interval(alpha = 0.05)), ci_bartlett, tolerance = 1e-8, info = label)
		expect_equal(suppressWarnings(inf_b$compute_asymp_two_sided_pval(delta = 0)), p_bartlett, tolerance = 1e-8, info = label)
	}
})

test_that("InferenceCountPoisson: lik_ratio_bartlett_approx is model-only and the new type is its old design-conservative result", {
	f = bdc_fixtures()
	ref = bdc_new(InferenceCountPoisson, f$bern)
	priv = ref$.__enclos_env__$private
	ci_model = priv$compute_lik_ratio_bartlett_approx_confidence_interval_impl(0.05, B = 99)
	p_model = priv$compute_lik_ratio_bartlett_approx_two_sided_pval_impl(0, B = 99)
	ci_design = priv$design_jackknife_ci(alpha = 0.05)
	p_design = priv$design_jackknife_pval(delta = 0)
	expect_true(all(is.finite(ci_model)) && all(is.finite(ci_design)))
	expect_true(is.finite(p_model) && is.finite(p_design))

	# the public Bartlett methods (and the best-available pair) are the model-only test
	expect_equal(unname(ref$compute_lik_ratio_bartlett_approx_confidence_interval(alpha = 0.05)), unname(ci_model), tolerance = 1e-10)
	expect_equal(ref$compute_lik_ratio_bartlett_approx_two_sided_pval(delta = 0), p_model, tolerance = 1e-10)
	expect_equal(unname(ref$compute_lik_ratio_bartlett_confidence_interval(alpha = 0.05)), unname(ci_model), tolerance = 1e-10)
	expect_equal(ref$compute_lik_ratio_bartlett_two_sided_pval(delta = 0), p_model, tolerance = 1e-10)
	inf_b = bdc_new(InferenceCountPoisson, f$bern, "lik_ratio_bartlett_approx")
	expect_equal(unname(inf_b$compute_asymp_confidence_interval(alpha = 0.05)), unname(ci_model), tolerance = 1e-10)
	expect_equal(inf_b$compute_asymp_two_sided_pval(delta = 0), p_model, tolerance = 1e-10)

	# the new type is what lik_ratio_bartlett_approx returned before: the union with the
	# design jackknife-Wald interval and the larger p-value
	inf = bdc_new(InferenceCountPoisson, f$bern, bdc_type)
	ci = inf$compute_asymp_confidence_interval(alpha = 0.05)
	p = inf$compute_asymp_two_sided_pval(delta = 0)
	expect_equal(unname(ci), c(min(ci_model[1], ci_design[1]), max(ci_model[2], ci_design[2])), tolerance = 1e-10)
	expect_equal(unname(ci), unname(priv$design_conservative_ci(ci_model, alpha = 0.05)), tolerance = 1e-10)
	expect_true(ci[1] <= ci_model[1] && ci[2] >= ci_model[2])
	expect_true(ci[1] <= ci_design[1] && ci[2] >= ci_design[2])
	expect_equal(p, max(p_model, p_design), tolerance = 1e-10)
})
