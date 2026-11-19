library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d03c4f45b (InferencePropKKGEE):
# - under (quasi-)complete separation the asymptotic p-value and CI are NA, with exactly one
#   edi_logistic_separation_warning per object (silent inside resampling), and the point estimate is
#   returned unchanged (inference_proportion_KK_combined.R:17);
# - use_rcpp = TRUE falls back to geepack::geeglm when the Rcpp solver fails
#   (inference_proportion_KK_combined.R:61).

prop_kk_gee_design = function(y_fun, n = 40, seed = 1) {
	set.seed(seed)
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	des$add_all_subject_responses(y_fun(des$get_w()))
	des
}

collect_warning_classes_prop_gee = function(expr) {
	classes = character()
	value = withCallingHandlers(expr, warning = function(w) {
		classes <<- c(classes, class(w)[1L])
		invokeRestart("muffleWarning")
	})
	list(value = value, classes = classes)
}

test_that("InferencePropKKGEE under separation: one warning, NA p-value and CI, finite unchanged estimate", {
	skip_if_not_installed("geepack")
	# Every treated response is exactly 1: the logit GEE is separated on treatment.
	des = prop_kk_gee_design(function(w) ifelse(w == 1, 1, runif(length(w), 0.2, 0.6)))
	for (use_rcpp in c(TRUE, FALSE)) {
		est_first = suppressWarnings(InferencePropKKGEE$new(des, use_rcpp = use_rcpp)$compute_estimate(estimate_only = TRUE))
		inf = InferencePropKKGEE$new(des, use_rcpp = use_rcpp)
		res = collect_warning_classes_prop_gee(list(
			p = inf$compute_asymp_two_sided_pval(),
			ci = inf$compute_asymp_confidence_interval(),
			est = inf$compute_estimate()
		))
		expect_identical(sum(res$classes == "edi_logistic_separation_warning"), 1L)
		expect_true(is.na(res$value$p))
		expect_length(res$value$ci, 2L)
		expect_true(all(is.na(res$value$ci)))
		expect_true(is.finite(res$value$est))
		expect_gt(abs(res$value$est), 10)
		# The separation check does not change the point estimate.
		expect_equal(res$value$est, est_first, tolerance = 1e-6)
		expect_true(inf$is_nonestimable("se"))
	}
})

test_that("InferencePropKKGEE separation warning is not repeated by resampling on the same object", {
	skip_if_not_installed("geepack")
	des = prop_kk_gee_design(function(w) ifelse(w == 1, 1, runif(length(w), 0.2, 0.6)))
	inf = InferencePropKKGEE$new(des)
	res = collect_warning_classes_prop_gee({
		inf$compute_asymp_two_sided_pval()
		inf$compute_rand_two_sided_pval(r = 19, show_progress = FALSE)
		inf$approximate_jackknife_distribution_beta_hat_T()
	})
	expect_identical(sum(res$classes == "edi_logistic_separation_warning"), 1L)

	# Resampling first, on a fresh object: still at most one warning in total.
	inf2 = InferencePropKKGEE$new(des)
	res2 = collect_warning_classes_prop_gee({
		inf2$compute_rand_two_sided_pval(r = 19, show_progress = FALSE)
		inf2$approximate_jackknife_distribution_beta_hat_T()
		inf2$compute_asymp_confidence_interval()
	})
	expect_lte(sum(res2$classes == "edi_logistic_separation_warning"), 1L)
})

test_that("InferencePropKKGEE(use_rcpp = TRUE) falls back to geepack::geeglm when the Rcpp GEE solver errors", {
	skip_if_not_installed("geepack")
	des = prop_kk_gee_design(function(w) plogis(rnorm(length(w), 0.3 * w)), seed = 3)
	est_geepack = InferencePropKKGEE$new(des, use_rcpp = FALSE)$compute_estimate()
	n_calls = 0L
	with_mocked_bindings(
		gee_pairs_singletons_cpp = function(...) {
			n_calls <<- n_calls + 1L
			stop("mocked Rcpp GEE failure")
		},
		.package = "EDI",
		code = {
			inf = InferencePropKKGEE$new(des, use_rcpp = TRUE)
			est = inf$compute_estimate()
			mod = inf$.__enclos_env__$private$fit_gee_with_fallback(std_err = TRUE)
		}
	)
	expect_gt(n_calls, 0L)
	expect_s3_class(mod, "geeglm")
	expect_true(is.finite(est))
	expect_equal(est, est_geepack, tolerance = 1e-8)
})
