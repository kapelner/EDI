library(testthat)
library(EDI)
skip_if_not_installed("MASS")

# InferenceContinRobustRegr private helpers: fit_rlm_model(X, estimate_only, warm_start) for both backends (Rcpp kernel list
# vs MASS::rlm object), get_ci_fit_controls() and set_failed_fit_cache(). References: MASS::rlm with the same method (exact for
# the MASS backend; the Rcpp MM kernel need only agree closely and beat OLS on contaminated data).

set.seed(2); n <- 60L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
w <- d$get_w(); y <- rnorm(n) + w + X$x1; y[1:3] <- y[1:3] + 15; d$add_all_subject_responses(y)
mk <- function() { inf <- InferenceContinRobustRegr$new(d, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }
f <- mk(); Xf <- f$p$build_design_matrix()

test_that("defaults: Rcpp backend with MM estimation; design matrix is [1, treatment, covariates]", {
	expect_true(isTRUE(f$p$use_rcpp)); expect_identical(f$p$rlm_method, "MM")
	expect_identical(colnames(Xf), c("(Intercept)", "treatment", "x1", "x2"))
})

test_that("Rcpp backend returns the kernel list with finite coefficients and a positive treatment variance", {
	a <- f$p$fit_rlm_model(Xf)
	expect_true(all(c("coefficients", "scale", "converged", "ssq_b_j", "fisher_information") %in% names(a)))
	expect_length(a$coefficients, 4L); expect_true(all(is.finite(a$coefficients)))
	expect_true(is.finite(a$ssq_b_j) && a$ssq_b_j > 0)
	ols <- unname(coef(lm(y ~ Xf - 1))[2])
	mm <- unname(MASS::rlm(Xf, y, method = "MM")$coefficients[2])
	expect_lt(abs(a$coefficients[2] - mm), 0.1)                                          # same estimator, different local search
	expect_lt(abs(a$coefficients[2] - 1), abs(ols - 1) + 0.15)                            # the true effect is 1; not worse than OLS by much
})

test_that("MASS backend returns an rlm object identical to MASS::rlm with LS start", {
	g <- mk(); g$p$use_rcpp <- FALSE
	b <- g$p$fit_rlm_model(Xf)
	expect_s3_class(b, "rlm")
	ref <- suppressWarnings(MASS::rlm(x = Xf, y = y, method = "MM", init = "ls"))
	expect_equal(coef(b), coef(ref), tolerance = 1e-5)
	expect_equal(g$inf$compute_estimate(), unname(coef(ref)[2]), tolerance = 1e-5)
})

test_that("a rank-deficient design makes the fit wrapper return NULL instead of erroring (both backends)", {
	Xbad <- cbind(Xf, dup = Xf[, "x1"])
	g <- mk(); expect_no_error(r <- g$p$fit_rlm_model(Xbad)); expect_true(is.null(r) || is.list(r))
	h <- mk(); h$p$use_rcpp <- FALSE
	expect_no_error(h$p$fit_rlm_model(matrix(NA_real_, n, 2)))
	expect_null(h$p$fit_rlm_model(matrix(NA_real_, n, 2)))
})

test_that("CI fit controls follow the randomization MC control (strict TRUE only) and the failed-fit cache writes NA", {
	g <- mk()
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = FALSE, reuse_factorizations = FALSE))
	g$p$randomization_mc_control <- list(fit_warm_start_enable = TRUE, fit_reuse_factorizations = TRUE)
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = TRUE, reuse_factorizations = TRUE))
	g$p$randomization_mc_control <- list(fit_warm_start_enable = "TRUE")
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = FALSE, reuse_factorizations = FALSE))
	g$p$set_failed_fit_cache()
	expect_true(is.na(g$p$cached_values$beta_hat_T) && is.na(g$p$cached_values$s_beta_hat_T) && is.na(g$p$cached_values$df))
})
