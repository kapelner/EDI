library(testthat)
library(EDI)

# KK OneLik count classes' remaining private layers: fit_combined_hurdle() (unconstrained MLE vs an
# independent BFGS of the same likelihood, treatment held fixed via fixed_idx, information-based SE,
# estimate_only), reduce_combined_covariates() (QR rank reduction of the stacked pair + reservoir
# design, treatment and intercept always kept) and set_failed_combined_cache().

hz_fx <- function(seed = 4L, np = 25L, ns = 15L) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	w <- des$get_w(); g <- c(rep(seq_len(np), each = 2L), np + seq_len(ns)); u <- rnorm(max(g), 0, 0.5)
	y <- rpois(n, exp(0.5 + 0.3 * w + 0.2 * X$x1 + u[g])); des$add_all_subject_responses(y)
	inf <- InferenceCountKKHurdlePoissonOneLik$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	Xf <- p$build_model_matrix()
	list(inf = inf, p = p, Xf = Xf, dat = p$build_combined_hurdle_data(Xf, 2L), n = n)
}

test_that("unconstrained combined hurdle fit reaches the same optimum as an independent BFGS of the likelihood", {
	f <- hz_fx()
	fit <- f$p$fit_combined_hurdle(f$dat)
	skip_if(is.null(fit), "combined fit returned NULL")
	expect_equal(length(fit$params), 4L)
	expect_equal(fit$b, fit$params[1:3]); expect_equal(fit$log_sigma, fit$params[4])
	nl <- function(b) f$p$combined_hurdle_neg_loglik(b, f$dat)
	gr <- function(b) -f$p$combined_hurdle_score(b, f$dat)
	opt <- optim(fit$params, nl, gr, method = "BFGS", control = list(reltol = 1e-12, maxit = 500))
	expect_equal(fit$neg_loglik, nl(fit$params), tolerance = 1e-10)
	expect_lte(fit$neg_loglik, opt$value + 1e-4)
	expect_lt(max(abs(f$p$combined_hurdle_score(fit$params, f$dat))), 0.05)                 # first-order stationarity
	expect_true(fit$converged)
	expect_equal(fit$information, fit$observed_information); expect_equal(fit$information, -fit$hessian)
	expect_equal(fit$information, t(fit$information), tolerance = 1e-8)
	expect_equal(fit$ssq_b_T, solve(fit$information)[2, 2], tolerance = 1e-6)
	expect_gt(fit$ssq_b_T, 0)
})

test_that("estimate_only skips the variance; fixed coordinates stay fixed and cannot beat the free optimum", {
	f <- hz_fx()
	full <- f$p$fit_combined_hurdle(f$dat)
	skip_if(is.null(full))
	eo <- f$p$fit_combined_hurdle(f$dat, estimate_only = TRUE)
	expect_true(is.na(eo$ssq_b_T))
	expect_equal(eo$params, full$params, tolerance = 1e-3)
	fixed <- f$p$fit_combined_hurdle(f$dat, fixed_idx = 2L, fixed_values = 0.2)
	expect_equal(fixed$params[2], 0.2)
	expect_gte(fixed$neg_loglik, full$neg_loglik - 1e-6)
	# Pinning the treatment at its MLE recovers the full optimum.
	at_mle <- f$p$fit_combined_hurdle(f$dat, fixed_idx = 2L, fixed_values = full$params[2])
	expect_equal(at_mle$neg_loglik, full$neg_loglik, tolerance = 1e-4)
	# Likelihood-ratio statistic for a null value is non-negative.
	expect_gte(2 * (fixed$neg_loglik - full$neg_loglik), -1e-6)
})

cp_priv <- function(seed = 5L, np = 20L, ns = 10L) {
	set.seed(seed); n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	des$add_all_subject_responses(rpois(n, 3))
	inf <- InferenceCountKKCondPoissonOneLik$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}

test_that("covariate reduction keeps every column of a full-rank design and drops exactly the dependent ones otherwise", {
	f <- cp_priv()
	set.seed(1)
	Xd <- cbind(a = rnorm(10), b = rnorm(10)); Xr <- cbind(a = rnorm(8), b = rnorm(8)); wr <- rep(0:1, 4)
	expect_equal(f$p$reduce_combined_covariates(Xd, Xr, wr), 1:2)
	# A covariate that is a copy of another (in both parts) is dropped; the survivor index refers to the covariate list.
	Xd3 <- cbind(Xd, dup = Xd[, "a"]); Xr3 <- cbind(Xr, dup = Xr[, "a"])
	keep <- f$p$reduce_combined_covariates(Xd3, Xr3, wr)
	expect_length(keep, 2L); expect_true(all(keep %in% 1:3))
	expect_false(all(c(1L, 3L) %in% keep))                                                 # never both copies of the same column
	# An all-zero covariate column is dropped.
	Xz <- cbind(Xd, z = 0); Xzr <- cbind(Xr, z = 0)
	expect_equal(f$p$reduce_combined_covariates(Xz, Xzr, wr), 1:2)
	# No records at all: nothing to keep.
	expect_identical(f$p$reduce_combined_covariates(matrix(numeric(0), 0, 2), matrix(numeric(0), 0, 2), numeric(0)), integer(0))
})

test_that("failed-fit cache: NA estimate and SE with the documented nonestimable reason", {
	f <- cp_priv()
	f$p$cached_values$beta_hat_T <- 1.2
	f$p$set_failed_combined_cache()
	expect_true(is.na(f$p$cached_values$beta_hat_T)); expect_true(is.na(f$p$cached_values$s_beta_hat_T))
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_identical(f$inf$get_nonestimable_reason(), "kk_cpoisson_onelik_fit_failed")
})
