library(testthat)
library(EDI)

# InferenceAbstractKKOrdinalCLMM's shared_rcpp() branches beyond the level-count
# checks (already covered): solver failure, coefficient/SE plausibility guards
# (max_abs_reasonable_coef), estimate_only vs full caching, warm-start storage,
# compute_ri_estimate_rcpp() (agrees with the fitted estimate, NA on failure),
# the abstract clmm_link() stop and the no-op assert_finite_se().

fx <- function(seed = 11L, n = 60L, effect = 0.5) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(as.integer(cut(effect * w + 0.4 * X$x1 + rlogis(n), c(-Inf, -0.7, 0.7, Inf), labels = FALSE)))
	inf <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}

test_that("a converged fit caches estimate, Inf df, SE, model and a params warm start; estimate_only skips the SE", {
	f <- fx()
	f$inf$compute_estimate(estimate_only = TRUE)
	expect_null(f$p$cached_values$s_beta_hat_T)
	expect_true(is.finite(f$p$cached_values$beta_hat_T))
	expect_equal(f$p$cached_values$df, Inf)
	expect_false(f$inf$is_nonestimable("any"))
	b <- f$p$cached_values$beta_hat_T
	f$p$shared(FALSE)
	expect_equal(f$p$cached_values$beta_hat_T, b, tolerance = 1e-6)
	se <- f$p$cached_values$s_beta_hat_T
	expect_true(is.finite(se) && se > 0)
	expect_equal(se, sqrt(f$p$cached_mod$ssq_b_T))
	expect_equal(length(f$p$get_fit_warm_start("params")), length(f$p$cached_mod$params))
	# Cached: a second full request must not refit (stub the solver path and it still returns).
	unlockBinding("clmm_group_id", f$p)
	f$p$clmm_group_id <- function() stop("must not be called when cached")
	expect_silent(f$p$shared(FALSE))
	expect_silent(f$p$shared(TRUE))
	expect_equal(f$inf$compute_estimate(), b, tolerance = 1e-6)
})

test_that("a failing solver call is nonestimable with reason kk_clmm_rcpp_failed", {
	f <- fx()
	unlockBinding("clmm_link", f$p)
	f$p$clmm_link <- function() "bogus"                       # unknown link -> the C++ call errors
	expect_true(is.na(f$inf$compute_estimate()))
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_identical(f$inf$get_nonestimable_reason(), "kk_clmm_rcpp_failed")
})

test_that("an estimate beyond max_abs_reasonable_coef is nonestimable", {
	f <- fx()
	f$p$max_abs_reasonable_coef <- 1e-9
	expect_true(is.na(f$inf$compute_estimate()))
	expect_identical(f$inf$get_nonestimable_reason(), "kk_clmm_rcpp_nonestimable")
	expect_true(f$inf$is_nonestimable("estimate"))
})

test_that("an SE beyond the plausibility bound keeps the estimate but flags the SE unavailable", {
	# Null-effect fixture so that |estimate| < SE and a bound can separate them.
	seed <- NULL
	for (sd in 1:30) {
		r <- fx(seed = sd, effect = 0)
		r$inf$compute_estimate()
		if (isTRUE(abs(r$p$cached_values$beta_hat_T) < r$p$cached_values$s_beta_hat_T)) { seed <- sd; break }
	}
	skip_if(is.null(seed), "no null-effect fixture with |estimate| < SE found")
	b <- r$p$cached_values$beta_hat_T; se <- r$p$cached_values$s_beta_hat_T
	f <- fx(seed = seed, effect = 0)
	f$p$max_abs_reasonable_coef <- (abs(b) + se) / 2
	expect_equal(f$inf$compute_estimate(), b, tolerance = 1e-6)
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))
	expect_true(f$inf$is_nonestimable("se"))
	expect_identical(f$inf$get_nonestimable_reason(), "kk_clmm_standard_error_unavailable")
})

test_that("compute_ri_estimate_rcpp reproduces the fitted treatment estimate and is NA when the solver fails", {
	f <- fx()
	est <- f$inf$compute_estimate()
	expect_equal(f$p$compute_ri_estimate_rcpp(), est, tolerance = 5e-2)   # looser eps / no warm start than the full fit
	expect_equal(f$p$compute_treatment_estimate_during_randomization_inference(), f$p$compute_ri_estimate_rcpp())
	g <- fx()
	unlockBinding("clmm_link", g$p)
	g$p$clmm_link <- function() "bogus"
	expect_true(is.na(g$p$compute_ri_estimate_rcpp()))
})

test_that("clmm_link() is abstract on the base class and assert_finite_se() never signals", {
	base <- get("InferenceAbstractKKOrdinalCLMM", envir = asNamespace("EDI"))
	hook <- base$private_methods$clmm_link
	env <- new.env(); env$self <- structure(list(), class = "SomeLeaf")
	environment(hook) <- env
	expect_error(hook(), "SomeLeaf must implement clmm_link\\(\\)")
	f <- fx()
	f$p$cached_values$s_beta_hat_T <- NA_real_
	expect_silent(f$p$assert_finite_se())
	f$p$cached_values$s_beta_hat_T <- 0.3
	expect_silent(f$p$assert_finite_se())
})
