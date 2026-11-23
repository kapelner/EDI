# v1.0.6-TODO-345 (ds-inference-suite-44883784401-f13, ds-count-44883784401-f7): a shared warm start made
# results depend on call order. (1) InferenceCountNegBin's score-test null fit started from the mutable
# backend warm start (and from starts chained across deltas), which a score-CI search moves, so the score
# p-value changed after a CI (0.8837140 fresh vs 0.8837136). (2) With every control count 0 the Poisson
# MLE is on a separation boundary (coefficients ~ -22 / +23); Poisson, QuasiPoisson and RobustPoisson
# randomization refits warm-started there could not move, so every draw equalled the observed estimate
# (p = 1), or, once unconverged fits are rejected, every draw was NA. The NegBin null fit now always
# starts from the full-data MLE, and a Poisson-family start beyond +-15 is never stored as a warm start.

test_that("NegBin score p-value is identical with and without a prior score CI", {
	set.seed(345)
	n = 50
	X = data.frame(x1 = rnorm(n))
	des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(MASS::rnegbin(n, mu = exp(1 + 0.4 * des$get_w() + 0.3 * X$x1), theta = 2))
	make = function() {
		inf = InferenceCountNegBin$new(des, verbose = FALSE)
		inf$set_testing_type("score")
		inf
	}
	fresh = make()
	p_fresh = fresh$compute_asymp_two_sided_pval()
	after = make()
	ci = after$compute_asymp_confidence_interval()
	p_after = after$compute_asymp_two_sided_pval()
	expect_true(all(is.finite(ci)))
	expect_true(is.finite(p_fresh))
	expect_identical(p_after, p_fresh)
})

test_that("Poisson-family randomization refits are not frozen at a separated observed fit", {
	set.seed(7)
	n = 30
	X = data.frame(x1 = rnorm(n))
	des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(ifelse(w == 1, stats::rpois(n, 3), 0L))
	r = 49
	for (cl in c("InferenceCountPoisson", "InferenceCountQuasiPoisson", "InferenceCountRobustPoisson")) {
		inf = get(cl, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
		est = inf$compute_estimate()
		expect_gt(est, 15, label = cl)
		# the separated full fit is not kept as a warm start
		expect_null(inf$.__enclos_env__$private$fit_warm_start, label = cl)
		set.seed(1)
		p = inf$compute_rand_two_sided_pval(r = r)
		# every draw is a cold fit of a less extreme allocation, so the observed one is the most extreme
		expect_true(is.finite(p), label = cl)
		expect_lte(p, 2 / (r + 1) + 1e-12, label = cl)
	}
})

test_that("an ordinary Poisson fit still keeps its warm start", {
	set.seed(8)
	n = 40
	X = data.frame(x1 = rnorm(n))
	des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(stats::rpois(n, exp(1 + 0.3 * des$get_w())))
	inf = InferenceCountPoisson$new(des, verbose = FALSE)
	inf$compute_estimate()
	expect_false(is.null(inf$.__enclos_env__$private$fit_warm_start))
})
