# v1.0.6-TODO-118: InferenceIncidKKGEE under (quasi-)complete separation used to
# return estimate ~50 with a collapsed sandwich SE and asymptotic p = 0, silently.
# Now the logit-link KK GEE classes warn once (edi_logistic_separation_warning)
# and return NA for the asymptotic p-value and CI; the estimate is unchanged.

make_kk14_design = function(response_type, y_fun, n = 40, seed = 1) {
	set.seed(seed)
	des = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	des$add_all_subject_responses(y_fun(des$get_w()))
	des
}

collect_warning_classes = function(expr) {
	classes = character()
	value = withCallingHandlers(expr, warning = function(w) {
		classes <<- c(classes, class(w)[1L])
		invokeRestart("muffleWarning")
	})
	list(value = value, classes = classes)
}

test_that("InferenceIncidKKGEE warns once and returns NA Wald results under separation", {
	skip_if_not_installed("geepack")
	des = make_kk14_design("incidence", function(w) ifelse(w == 1, 1, rbinom(length(w), 1, 0.4)))
	expect_true(all(des$get_y()[des$get_w() == 1] == 1))
	for (use_rcpp in c(TRUE, FALSE)) {
		inf = InferenceIncidKKGEE$new(des, use_rcpp = use_rcpp)
		res = collect_warning_classes(list(
			p = inf$compute_asymp_two_sided_pval(),
			ci = inf$compute_asymp_confidence_interval(),
			est = inf$compute_estimate()
		))
		expect_identical(sum(res$classes == "edi_logistic_separation_warning"), 1L)
		expect_true(is.na(res$value$p))
		expect_true(all(is.na(res$value$ci)))
		expect_true(is.finite(res$value$est))
		expect_gt(abs(res$value$est), 10)
		expect_true(inf$is_nonestimable("se"))
	}
	expect_warning(InferenceIncidKKGEE$new(des)$compute_estimate(), class = "edi_logistic_separation_warning")
})

test_that("InferenceIncidKKGEE gives no separation warning and finite Wald results on ordinary data", {
	des = make_kk14_design("incidence", function(w) rbinom(length(w), 1, ifelse(w == 1, 0.6, 0.4)))
	inf = InferenceIncidKKGEE$new(des)
	res = collect_warning_classes(list(p = inf$compute_asymp_two_sided_pval(), ci = inf$compute_asymp_confidence_interval()))
	expect_false("edi_logistic_separation_warning" %in% res$classes)
	expect_true(is.finite(res$value$p))
	expect_true(all(is.finite(res$value$ci)))
})

test_that("the Rcpp GEE result carries X_fit so the linear predictor can be formed", {
	des = make_kk14_design("incidence", function(w) rbinom(length(w), 1, ifelse(w == 1, 0.6, 0.4)))
	inf = InferenceIncidKKGEE$new(des)
	priv = inf$.__enclos_env__$private
	mod = priv$fit_gee_with_fallback(std_err = TRUE)
	skip_if(inherits(mod, "geeglm"), "Rcpp GEE solver did not converge on this draw")
	eta = priv$gee_fitted_linear_predictor(mod)
	expect_length(eta, des$get_n())
	expect_equal(eta, as.numeric(mod$X_fit %*% mod$beta))
})

test_that("InferencePropKKGEE (logit link) is covered; the Poisson KK GEE is not touched by the check", {
	skip_if_not_installed("geepack")
	des = make_kk14_design("proportion", function(w) ifelse(w == 1, 1, runif(length(w), 0.2, 0.6)))
	inf = InferencePropKKGEE$new(des)
	res = collect_warning_classes(list(est = inf$compute_estimate(), p = inf$compute_asymp_two_sided_pval()))
	expect_true("edi_logistic_separation_warning" %in% res$classes)
	expect_true(is.na(res$value$p))

	des_c = make_kk14_design("count", function(w) rpois(length(w), ifelse(w == 1, 4, 2)))
	inf_c = InferenceCountPoissonKKGEE$new(des_c)
	expect_false(inf_c$.__enclos_env__$private$gee_uses_logit_link())
})
