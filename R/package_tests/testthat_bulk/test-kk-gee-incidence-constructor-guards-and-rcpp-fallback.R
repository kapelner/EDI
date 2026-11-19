library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d334f1c8f (InferenceIncidKKGEE): initialize validates the
# matched/reservoir design and the incidence response; use_rcpp = TRUE (the default) uses the Rcpp
# GEE solver and falls back to geepack::geeglm when that solver fails.

make_kk_gee_design <- function(seed, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

test_that("InferenceIncidKKGEE initialize rejects a non-KK design and a non-incidence KK design", {
	set.seed(1)
	bern <- DesignSeqOneByOneBernoulli$new(n = 10L, response_type = "incidence")
	for (i in 1:10) bern$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	bern$add_all_subject_responses(rbinom(10, 1, 0.5))
	expect_error(InferenceIncidKKGEE$new(bern), "requires a KK matching")

	kk_cont <- DesignSeqOneByOneKK14$new(n = 10L, response_type = "continuous")
	for (i in 1:10) kk_cont$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	kk_cont$add_all_subject_responses(rnorm(10))
	expect_error(InferenceIncidKKGEE$new(kk_cont), "does not support response type 'continuous'")
})

test_that("InferenceIncidKKGEE defaults to use_rcpp = TRUE and falls back to geepack::geeglm when the Rcpp solver fails", {
	skip_if_not_installed("geepack")
	des <- make_kk_gee_design(21L)
	inf_default <- InferenceIncidKKGEE$new(des, verbose = FALSE)
	expect_true(inf_default$.__enclos_env__$private$use_rcpp)

	inf_geepack <- InferenceIncidKKGEE$new(des, use_rcpp = FALSE, verbose = FALSE)
	est_geepack <- inf_geepack$compute_estimate()
	expect_true(is.finite(est_geepack))

	# Independent geepack reference on the class's own sorted fit data.
	fd <- inf_geepack$.__enclos_env__$private$build_gee_fit_data()
	ref <- suppressWarnings(geepack::geeglm(y ~ ., family = binomial(), data = data.frame(y = fd$y_sorted, fd$dat),
		id = fd$id_sorted, corstr = "exchangeable"))
	expect_equal(est_geepack, unname(coef(ref)["w"]), tolerance = 1e-8)

	calls <- 0L
	local_mocked_bindings(
		gee_pairs_singletons_cpp = function(...) { calls <<- calls + 1L; list(converged = FALSE, beta = NA_real_) },
		.package = "EDI"
	)
	inf_fb <- InferenceIncidKKGEE$new(des, verbose = FALSE)
	est_fb <- inf_fb$compute_estimate()
	expect_gt(calls, 0L)
	expect_equal(est_fb, est_geepack, tolerance = 1e-8)
})
