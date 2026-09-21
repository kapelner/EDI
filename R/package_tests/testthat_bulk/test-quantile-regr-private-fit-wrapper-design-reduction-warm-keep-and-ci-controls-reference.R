library(testthat)
library(EDI)
skip_if_not_installed("quantreg")

# InferenceContinQuantileRegr private helpers: fit_quantile_model(X, estimate_only) (rq.fit "br" coefficients named by column,
# or a full quantreg::rq object), reduce_design_matrix_for_quantile(X, reuse_factorizations) (rank-reduce keeping treatment;
# cached column subset reused when it is still full rank), get_ci_fit_controls() (flags from the randomization MC control) and
# set_failed_fit_cache(). Reference: quantreg::rq on the same matrix and hand-built control lists.

set.seed(2); n <- 60L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
w <- d$get_w(); y <- rnorm(n) + w + X$x1; d$add_all_subject_responses(y)
mk <- function(tau = 0.5) {
	inf <- InferenceContinQuantileRegr$new(d, tau = tau, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}
f <- mk(); Xf <- f$p$build_design_matrix()

test_that("estimate-only fit returns rq.fit(br) coefficients named by design column; full fit is an rq object with the same coefficients", {
	ref <- quantreg::rq.fit(Xf, y, tau = 0.5, method = "br")$coefficients
	e <- f$p$fit_quantile_model(Xf, estimate_only = TRUE)
	expect_equal(as.numeric(e$coefficients), as.numeric(ref), tolerance = 1e-8)
	expect_identical(names(e$coefficients), colnames(Xf))
	full <- f$p$fit_quantile_model(Xf, estimate_only = FALSE)
	expect_s3_class(full, "rq")
	expect_equal(unname(coef(full)), unname(ref), tolerance = 1e-8)
})

test_that("tau is honoured: an upper quantile fit differs from the median and matches rq at that tau", {
	g <- mk(tau = 0.8); Xg <- g$p$build_design_matrix()
	e <- g$p$fit_quantile_model(Xg, estimate_only = TRUE)
	expect_equal(unname(e$coefficients), unname(suppressWarnings(quantreg::rq.fit(Xg, y, tau = 0.8, method = "br"))$coefficients), tolerance = 1e-8)
	expect_gt(max(abs(e$coefficients - f$p$fit_quantile_model(Xf, TRUE)$coefficients)), 1e-3)
})

test_that("a class estimate equals the treatment coefficient of the rq fit", {
	expect_equal(f$inf$compute_estimate(), unname(quantreg::rq.fit(Xf, y, tau = 0.5, method = "br")$coefficients[2]), tolerance = 1e-8)
})

test_that("reduction keeps a full-rank design (treatment at position 2), drops a duplicated column, and rejects < 2 columns", {
	r <- f$p$reduce_design_matrix_for_quantile(Xf)
	expect_identical(r$j_treat, 2L); expect_identical(colnames(r$X), colnames(Xf))
	Xd <- cbind(Xf, dup = Xf[, "x1"])
	r2 <- f$p$reduce_design_matrix_for_quantile(Xd)
	expect_identical(colnames(r2$X), colnames(Xf)); expect_identical(r2$j_treat, 2L)
	one <- f$p$reduce_design_matrix_for_quantile(matrix(1:4, ncol = 1))
	expect_null(one$X); expect_true(is.na(one$j_treat))
	v <- f$p$reduce_design_matrix_for_quantile(c(1, 2, 3, 4, 5, 6))                    # plain vector is reshaped to two columns
	expect_identical(v$j_treat, 2L)
})

test_that("factorization reuse: the kept-column cache is written on reuse and reused only while it stays full rank", {
	g <- mk(); Xg <- g$p$build_design_matrix()
	expect_identical(g$p$fit_warm_keep, integer(0))
	g$p$reduce_design_matrix_for_quantile(Xg, reuse_factorizations = TRUE)
	expect_identical(g$p$fit_warm_keep, 1:4)
	g$p$fit_warm_keep <- c(1L, 2L)
	r <- g$p$reduce_design_matrix_for_quantile(Xg, reuse_factorizations = TRUE)
	expect_identical(colnames(r$X), c("(Intercept)", "treatment")); expect_identical(r$j_treat, 2L)      # cached subset reused
	r_no <- g$p$reduce_design_matrix_for_quantile(Xg, reuse_factorizations = FALSE)
	expect_identical(colnames(r_no$X), colnames(Xg))                                                      # ignored without the flag
	g$p$fit_warm_keep <- c(1L, 9L)                                                                        # out-of-range cache is ignored
	expect_identical(colnames(g$p$reduce_design_matrix_for_quantile(Xg, reuse_factorizations = TRUE)$X), colnames(Xg))
	g$p$fit_warm_keep <- c(1L, 3L)                                                                        # missing the treatment column: ignored
	expect_identical(colnames(g$p$reduce_design_matrix_for_quantile(Xg, reuse_factorizations = TRUE)$X), colnames(Xg))
})

test_that("CI fit controls default to FALSE and follow the randomization MC control flags", {
	g <- mk()
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = FALSE, reuse_factorizations = FALSE))
	g$p$randomization_mc_control <- list(fit_warm_start_enable = TRUE)
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = TRUE, reuse_factorizations = FALSE))
	g$p$randomization_mc_control <- list(fit_warm_start_enable = FALSE, fit_reuse_factorizations = TRUE)
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = FALSE, reuse_factorizations = TRUE))
	g$p$randomization_mc_control <- list(fit_warm_start_enable = "yes", fit_reuse_factorizations = 1)     # only strict TRUE counts
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = FALSE, reuse_factorizations = FALSE))
})

test_that("set_failed_fit_cache marks estimate, SE and df as NA", {
	g <- mk(); g$p$set_failed_fit_cache()
	expect_true(is.na(g$p$cached_values$beta_hat_T)); expect_true(is.na(g$p$cached_values$s_beta_hat_T)); expect_true(is.na(g$p$cached_values$df))
})
