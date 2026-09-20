library(testthat)
library(EDI)

# Remaining small private helpers of InferenceAllAbstract: get_w_signed(), the
# capability-literal defaults, try_cached_reduced_design_keep() (validation,
# rank check, treatment-only fast path and cache reuse), has_private_method(),
# get_fit_warm_start_weights() size/enabled gating, the likelihood test-eval
# cache entry round trip, use_reusable_bootstrap_worker() gating and
# get_analysis_data() assembly.

fx <- function(n = 20L, seed = 1L, cov = TRUE) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(if (cov) data.frame(x1 = rnorm(n), x2 = rnorm(n)) else data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, y = y, n = n)
}

test_that("get_w_signed maps {0,1} to {-1,+1} for vectors and matrices", {
	p <- fx()$p
	expect_equal(p$get_w_signed(c(0, 1, 1, 0)), c(-1, 1, 1, -1))
	m <- matrix(c(0, 1, 1, 0, 1, 1), 2)
	expect_equal(p$get_w_signed(m), 2 * m - 1)
	expect_equal(dim(p$get_w_signed(m)), dim(m))
})

test_that("capability literals default to FALSE / FALSE / NA on the plain abstract layer", {
	p <- fx()$p
	expect_false(p$supports_interval_or_left_censored_data())
	expect_false(p$requires_blocking_design())
	expect_identical(p$get_estimand_type(), NA_character_)
})

test_that("has_private_method only reports names present in the private env", {
	p <- fx()$p
	expect_true(p$has_private_method("stable_signature"))
	expect_false(p$has_private_method("no_such_method"))
	expect_true(p$object_has_private_method(fx(seed = 2L)$inf, "stable_signature"))
	expect_false(p$object_has_private_method(fx(seed = 2L)$inf, "nope"))
})

test_that("try_cached_reduced_design_keep validates the kept columns and rejects rank-deficient sets", {
	p <- fx()$p
	set.seed(3)
	X <- cbind(1, rbinom(20, 1, 0.5), rnorm(20), rnorm(20))
	p$reduced_design_keep_cache <- NULL
	expect_null(p$try_cached_reduced_design_keep(X, keep = NULL))
	expect_null(p$try_cached_reduced_design_keep(X, keep = integer(0)))
	expect_null(p$try_cached_reduced_design_keep(X, keep = c(1L, 9L)))           # out of range
	expect_null(p$try_cached_reduced_design_keep(X, keep = c(0L, 2L)))           # below 1
	expect_null(p$try_cached_reduced_design_keep(X, keep = c(1L, 3L)))           # treatment column (2) missing
	r <- p$try_cached_reduced_design_keep(X, keep = c(4L, 2L, 1L, 2L))           # sorted and de-duplicated
	expect_equal(r$keep, c(1L, 2L, 4L))
	expect_equal(r$j_treat, 2L)
	expect_equal(r$X, X[, c(1, 2, 4)])
	Xd <- cbind(X, X[, 3] * 2)                                                   # collinear extra column
	expect_null(p$try_cached_reduced_design_keep(Xd, keep = c(1L, 2L, 3L, 5L)))
})

test_that("treatment-only reduction: fast path, constant treatment/intercept and cache reuse", {
	p <- fx()$p
	w <- rep(0:1, 10)
	X2 <- cbind(1, w)
	r <- p$try_cached_reduced_design_keep(X2, keep = c(1L, 2L))
	expect_equal(r$X, X2); expect_equal(r$j_treat, 2L)
	expect_equal(p$cached_j_treat_for_reduced, 2L)
	expect_identical(p$cached_X_full_for_reduced, X2)
	# Second call with an identical matrix and keep takes the cached track.
	p$cached_reduced_X <- X2 * 1                       # same values; cache hit must return the stored matrix object
	expect_equal(p$try_cached_reduced_design_keep(X2, keep = c(1L, 2L))$X, X2)
	# Constant treatment column: no usable reduction.
	expect_null(p$try_cached_reduced_design_keep(cbind(1, rep(1, 20)), keep = c(1L, 2L)))
	# Non-constant intercept is not a treatment-only design.
	expect_null(p$reduce_treatment_only_design_fast(cbind(seq_len(20), w)))
	expect_null(p$reduce_treatment_only_design_fast(cbind(1, c(NA, w[-1]))))
	expect_null(p$reduce_treatment_only_design_fast(matrix(1, 20, 3)))
	f <- p$reduce_treatment_only_design_fast(cbind(1, rep(0, 20)))
	expect_null(f$X); expect_equal(f$keep, 1L); expect_true(is.na(f$j_treat))
})

test_that("fit warm-start weights are returned only when enabled and of the expected length", {
	f <- fx()
	p <- f$p
	p$fit_warm_start_weights <- c(1, 2, 3)
	p$fit_warm_start_enabled <- TRUE
	expect_equal(p$get_fit_warm_start_weights(), c(1, 2, 3))
	expect_equal(p$get_fit_warm_start_weights(3L), c(1, 2, 3))
	expect_null(p$get_fit_warm_start_weights(4L))
	p$fit_warm_start_enabled <- FALSE
	expect_null(p$get_fit_warm_start_weights())
	p$fit_warm_start_enabled <- TRUE
	p$fit_warm_start_weights <- NULL
	expect_null(p$get_fit_warm_start_weights())
})

test_that("likelihood test-eval cache: entries keyed by type and normalised delta; -0 shares 0's slot; clear empties", {
	p <- fx()$p
	expect_length(p$get_likelihood_test_eval_cache(), 0L)
	expect_null(p$get_likelihood_test_eval_entry("score", 0.5))
	expect_identical(p$set_likelihood_test_eval_entry("score", 0.5, list(v = 1)), list(v = 1))
	p$set_likelihood_test_eval_entry("wald", 0.5, list(v = 2))
	p$set_likelihood_test_eval_entry("score", 0, list(v = 3))
	expect_equal(p$get_likelihood_test_eval_entry("score", 0.5)$v, 1)
	expect_equal(p$get_likelihood_test_eval_entry("wald", 0.5)$v, 2)
	expect_equal(p$get_likelihood_test_eval_entry("score", -0)$v, 3)
	expect_equal(p$get_likelihood_test_eval_entry("score", 1e-20)$v, 3)          # |delta| < eps collapses to 0
	expect_length(p$get_likelihood_test_eval_cache(), 3L)
	expect_equal(p$likelihood_test_delta_key("score", 0.5), sprintf("score::%.17g", 0.5))
	p$clear_likelihood_test_eval_cache()
	expect_length(p$get_likelihood_test_eval_cache(), 0L)
	expect_null(p$get_likelihood_test_eval_entry("score", 0.5))
})

test_that("use_reusable_bootstrap_worker needs the flag, a supporting private method that returns TRUE and does not error", {
	p <- fx()$p
	p$reusable_bootstrap_worker_enabled <- FALSE
	expect_false(p$use_reusable_bootstrap_worker())
	p$reusable_bootstrap_worker_enabled <- TRUE
	has <- p$has_private_method("supports_reusable_bootstrap_worker")
	if (has) {
		unlockBinding("supports_reusable_bootstrap_worker", p)
		p$supports_reusable_bootstrap_worker <- function() TRUE
		expect_true(p$use_reusable_bootstrap_worker())
		p$supports_reusable_bootstrap_worker <- function() stop("boom")
		expect_false(p$use_reusable_bootstrap_worker())
		p$supports_reusable_bootstrap_worker <- function() NA
		expect_false(p$use_reusable_bootstrap_worker())
	} else {
		expect_false(p$use_reusable_bootstrap_worker())
	}
})

test_that("get_analysis_data assembles y, w, dead and named covariates", {
	f <- fx()
	d <- f$inf$get_analysis_data()
	expect_s3_class(d, "data.frame")
	expect_equal(d$y, f$y)
	expect_equal(d$w, f$w)
	expect_equal(nrow(d), f$n)
	expect_true(all(c("x1", "x2") %in% names(d)))
	expect_equal(ncol(d), 3L + 2L)
	expect_equal(d$x1, as.data.frame(f$inf$get_covariates())$x1)
})
