# v1.0.6-TODO-274: the logit-link KK GEE classes blank the SE (asymptotic p and CI NA)
# under (quasi-)complete separation. The v1.0.6-TODO-118 rule fired whenever one fitted
# |eta| reached qlogis(1 - 1e-8), which a single high-leverage subject reaches in a fit
# whose solution exists. Now that screen is confirmed by the exact data check
# EDI:::edi_binary_data_separated() before anything is blanked.

kk14_incidence_high_leverage = function(seed = 2, n = 40, xbig = 25) {
	set.seed(seed)
	des = EDI::DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	X$x1[n] = xbig
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, ])
	w = des$get_w()
	y = rbinom(n, 1, plogis(0.3 * w + X$x1))
	y[n] = 1
	des$add_all_subject_responses(y)
	list(des = des, X = cbind(1, w, as.matrix(X)), y = y)
}

kk14_incidence_separated = function(seed = 1, n = 40) {
	set.seed(seed)
	des = EDI::DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	w = des$get_w()
	des$add_all_subject_responses(ifelse(w == 1, 1, rbinom(n, 1, 0.4)))
	des
}

separation_warning_count = function(expr) {
	n = 0L
	value = withCallingHandlers(expr, warning = function(w) {
		if (inherits(w, "edi_logistic_separation_warning")) n <<- n + 1L
		invokeRestart("muffleWarning")
	})
	list(value = value, n = n)
}

test_that("edi_binary_data_separated() matches the known separation status", {
	sep = EDI:::edi_binary_data_separated
	set.seed(3)
	x = rnorm(30)
	expect_true(sep(cbind(1, x), as.numeric(x > 0)))                      # complete
	g = rep(0:1, 15)
	expect_true(sep(cbind(1, g), ifelse(g == 1, 1, rbinom(30, 1, 0.4))))  # quasi-complete
	expect_false(sep(cbind(1, x), as.numeric(rank(x) %% 4 %in% c(1, 2))))  # overlapping
	expect_false(sep(cbind(1, x), as.numeric(rank(x) == 30 | rank(x) %% 2 == 0)))  # extreme x has y = 1, still overlapping
	expect_false(sep(cbind(1, x, x), rep(c(0, 1, 1, 0), length.out = 30)))  # rank-deficient, overlapping
	expect_true(sep(cbind(1, g), ifelse(g == 1, 1, runif(30, 0.2, 0.6))))  # fractional, quasi-complete
	expect_false(sep(cbind(1, g), runif(30, 0.2, 0.8)))                   # fractional, interior
	expect_true(is.na(sep(cbind(1, x), c(NA, rep(0:1, length.out = 29)))))
	f = kk14_incidence_high_leverage()
	expect_false(sep(f$X, f$y))
})

test_that("a high-leverage subject with fitted probability ~1 does not blank the KK GEE SE", {
	f = kk14_incidence_high_leverage()
	# the screen fires: one fitted probability within 1e-8 of 1 ...
	g = suppressWarnings(stats::glm(f$y ~ f$X[, -1], family = stats::binomial))
	expect_true(g$converged)
	expect_true(all(abs(stats::coef(g)) < 5))
	for (use_rcpp in c(TRUE, FALSE)) {
		if (!use_rcpp && !requireNamespace("geepack", quietly = TRUE)) next
		inf = EDI::InferenceIncidKKGEE$new(f$des, use_rcpp = use_rcpp)
		priv = inf$.__enclos_env__$private
		mod = priv$fit_gee_with_fallback(std_err = TRUE)
		eta = priv$gee_fitted_linear_predictor(mod)
		expect_gte(EDI:::edi_logistic_n_fitted_extreme(matrix(eta, ncol = 1L), 1), 1L)
		# ... but the data are not separated, so the Wald results stay finite, silently
		expect_false(priv$gee_fit_data_separated(mod))
		res = separation_warning_count(list(
			est = inf$compute_estimate(),
			p = inf$compute_asymp_two_sided_pval(),
			ci = inf$compute_asymp_confidence_interval()
		))
		expect_identical(res$n, 0L)
		expect_lt(abs(res$value$est), 5)
		expect_true(is.finite(res$value$p))
		expect_true(all(is.finite(res$value$ci)))
		expect_false(inf$is_nonestimable("se"))
	}
})

test_that("a separated KK GEE fit still warns once and returns NA Wald results", {
	des = kk14_incidence_separated()
	for (use_rcpp in c(TRUE, FALSE)) {
		if (!use_rcpp && !requireNamespace("geepack", quietly = TRUE)) next
		inf = EDI::InferenceIncidKKGEE$new(des, use_rcpp = use_rcpp)
		res = separation_warning_count(list(
			p = inf$compute_asymp_two_sided_pval(),
			ci = inf$compute_asymp_confidence_interval(),
			est = inf$compute_estimate()
		))
		expect_identical(res$n, 1L)
		expect_true(is.na(res$value$p))
		expect_true(all(is.na(res$value$ci)))
		expect_gt(abs(res$value$est), 10)
		expect_true(inf$is_nonestimable("se"))
		priv = inf$.__enclos_env__$private
		expect_true(priv$gee_fit_data_separated(priv$fit_gee_with_fallback(std_err = TRUE)))
	}
})

test_that("the separation check falls back to the screen when the fit data cannot be recovered", {
	des = kk14_incidence_separated()
	inf = EDI::InferenceIncidKKGEE$new(des)
	expect_true(is.na(inf$.__enclos_env__$private$gee_fit_data_separated(list(beta = 1))))
})
