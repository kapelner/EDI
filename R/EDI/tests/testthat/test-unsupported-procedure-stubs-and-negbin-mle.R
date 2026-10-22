context("TODO-116: unsupported-procedure stubs keep caches; NegBin fit reaches the MLE")

make_count_design_116 = function(n = 80L, seed = 116L){
	set.seed(seed)
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(as.integer(rnbinom(n, size = 2, mu = 3)))
	des
}

capture_unsupported_116 = function(expr){
	cond = NULL
	val = withCallingHandlers(expr, warning = function(w){
		if (inherits(w, "edi_unsupported_procedure")) cond <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, condition = cond)
}

test_that("NegBin jackknife stubs warn with a classed condition and do not clear the cached SE", {
	des = make_count_design_116()
	inf = InferenceCountNegBin$new(des, verbose = FALSE)
	ci_before = inf$compute_asymp_confidence_interval()
	cv = function() inf$.__enclos_env__$private$cached_values
	se_before = cv()$s_beta_hat_T
	est_before = cv()$beta_hat_T
	expect_true(is.finite(se_before))

	calls = list(
		function() inf$compute_jackknife_estimate(),
		function() inf$compute_jackknife_bias_estimate(),
		function() inf$compute_jackknife_std_error(),
		function() inf$compute_jackknife_wald_two_sided_pval(),
		function() inf$compute_jackknife_wald_confidence_interval()
	)
	for (f in calls) {
		out = capture_unsupported_116(f())
		expect_s3_class(out$condition, "edi_unsupported_procedure")
		expect_true(all(is.na(out$value)))
		expect_identical(cv()$s_beta_hat_T, se_before)
		expect_identical(cv()$beta_hat_T, est_before)
		expect_false(isTRUE(inf$is_nonestimable("any")))
	}
	# the next asymptotic CI is unchanged (no refit from a perturbed warm start)
	expect_identical(inf$compute_asymp_confidence_interval(), ci_before)
})

test_that("other documented stub classes also keep the cached estimate/SE", {
	des = make_count_design_116()
	for (cls in c("InferenceCountHurdleNegBin", "InferenceCountZeroInflatedPoisson")) {
		inf = suppressWarnings(get(cls)$new(des, verbose = FALSE))
		est = suppressWarnings(inf$compute_estimate())
		if (!is.finite(est)) next
		suppressWarnings(try(inf$compute_asymp_confidence_interval(), silent = TRUE))
		cv = inf$.__enclos_env__$private$cached_values
		se_before = cv$s_beta_hat_T
		out = capture_unsupported_116(inf$compute_jackknife_std_error())
		expect_s3_class(out$condition, "edi_unsupported_procedure")
		expect_identical(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, se_before)
		expect_identical(inf$.__enclos_env__$private$cached_values$beta_hat_T, est)
	}

	n = 40L
	set.seed(3)
	desc = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) desc$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	desc$add_all_subject_responses(rnorm(n))
	inf = InferenceAllSimpleWilcox$new(desc, verbose = FALSE)
	est = inf$compute_estimate()
	out = capture_unsupported_116(inf$compute_jackknife_estimate())
	expect_s3_class(out$condition, "edi_unsupported_procedure")
	expect_identical(inf$.__enclos_env__$private$cached_values$beta_hat_T, est)
})

test_that("NegBin fit reaches the MLE (matches MASS::glm.nb)", {
	skip_if_not_installed("MASS")
	for (seed in c(1L, 3L)) {
		des = make_count_design_116(n = 150L, seed = seed)
		inf = InferenceCountNegBin$new(des, verbose = FALSE)
		est = inf$compute_estimate()
		d = data.frame(y = des$get_y(), w = des$get_w(), x1 = as.numeric(as.matrix(des$get_X())[, 1L]))
		m = MASS::glm.nb(y ~ w + x1, data = d, control = glm.control(epsilon = 1e-12, maxit = 100))
		expect_equal(est, unname(coef(m)[["w"]]), tolerance = 1e-5, scale = 1)
		expect_equal(inf$.__enclos_env__$private$cached_mod$theta_hat, m$theta, tolerance = 1e-4, scale = 1)
	}
})
