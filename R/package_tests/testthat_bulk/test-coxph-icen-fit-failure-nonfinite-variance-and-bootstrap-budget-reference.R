library(testthat)
library(EDI)

# generate_mod_icen() branches the real-fit dispatch test does not reach, driven by a
# mocked icenReg::ic_sp(): fit failure -> NA result, non-finite covariance -> NA vcov
# but finite point estimate, the bs_samples budget (0 for estimate_only, icen_bs_samples
# otherwise), the treatment-only formula, and the [y, y] / (y_L, y_R) interval encoding.

skip_if_not_installed("icenReg")

des_icen <- function() {
	ys   <- c(1,  NA, NA, 2.5, NA, NA)
	y_Ls <- c(NA, 3,  2,  NA,  4,  3)
	y_Rs <- c(NA, Inf, 5, NA,  Inf, 6)
	des <- DesignFixedBernoulli$new(n = 6L, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(6L)))
	des$overwrite_all_subject_assignments(c(0, 0, 0, 1, 1, 1))
	des$add_all_subject_responses(ys, y_Ls, y_Rs)
	des
}
mk <- function() {
	inf <- InferenceSurvivalCoxPHRegr$new(des_icen(), model_formula = ~1, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}
fake_fit <- function(coef = 0.4, var = matrix(0.09, 1, 1, dimnames = list("treatment", "treatment")), llk = -7.5) {
	structure(list(coefficients = c(treatment = coef), var = var, llk = llk), class = "fake_ic")
}

test_that("a failed ic_sp fit returns the all-NA result and clears the likelihood-test context", {
	f <- mk()
	f$priv$cached_values$likelihood_test_context <- list(stale = TRUE)
	local_mocked_bindings(ic_sp = function(...) stop("no convergence"), .package = "icenReg")
	out <- f$priv$generate_mod_icen()
	expect_equal(out$b, rep(NA_real_, 2L))
	expect_equal(dim(out$vcov), c(2L, 2L))
	expect_true(all(is.na(out$vcov)))
	expect_null(f$priv$cached_values$likelihood_test_context)
})

test_that("a finite fit maps into the padded (intercept-slot zero) result with negated log-likelihood", {
	f <- mk()
	local_mocked_bindings(ic_sp = function(...) fake_fit(0.4, matrix(0.09, 1, 1, dimnames = list("treatment", "treatment")), -7.5), .package = "icenReg")
	out <- f$priv$generate_mod_icen()
	expect_equal(out$beta_hat_T, 0.4)
	expect_equal(out$b, c(0, 0.4))
	expect_equal(out$ssq_b_2, 0.09)
	expect_equal(out$vcov, matrix(c(0, 0, 0, 0.09), 2, 2))
	expect_equal(out$neg_log_lik, 7.5)
})

test_that("a non-finite covariance keeps the point estimate but returns an NA vcov and ssq_b_2", {
	f <- mk()
	local_mocked_bindings(ic_sp = function(...) fake_fit(0.4, matrix(NA_real_, 1, 1, dimnames = list("treatment", "treatment"))), .package = "icenReg")
	out <- f$priv$generate_mod_icen()
	expect_equal(out$beta_hat_T, 0.4)
	expect_true(is.na(out$ssq_b_2))
	expect_true(all(is.na(out$vcov)))
	expect_equal(dim(out$vcov), c(2L, 2L))
	expect_equal(out$neg_log_lik, 7.5)
	# A covariance missing the covariate's row/column is treated the same way.
	local_mocked_bindings(ic_sp = function(...) fake_fit(0.4, matrix(1, 1, 1, dimnames = list("other", "other"))), .package = "icenReg")
	out2 <- f$priv$generate_mod_icen()
	expect_true(all(is.na(out2$vcov)))
})

test_that("the bootstrap budget is 0 for estimate_only and icen_bs_samples otherwise; the data uses [y,y] and (y_L,y_R) intervals", {
	f <- mk()
	seen <- list()
	local_mocked_bindings(ic_sp = function(formula, data, model, bs_samples) {
		seen[[length(seen) + 1L]] <<- list(formula = formula, data = data, model = model, bs = bs_samples)
		fake_fit()
	}, .package = "icenReg")
	f$priv$generate_mod_icen(estimate_only = TRUE)
	f$priv$generate_mod_icen(estimate_only = FALSE)
	expect_equal(seen[[1]]$bs, 0L)
	expect_equal(seen[[2]]$bs, f$priv$icen_bs_samples)
	expect_equal(seen[[1]]$model, "ph")
	expect_equal(deparse(seen[[1]]$formula), "cbind(.icen_L, .icen_R) ~ treatment")
	d <- seen[[1]]$data
	expect_equal(d$treatment, c(0, 0, 0, 1, 1, 1))
	expect_equal(d$.icen_L, c(1, 3, 2, 2.5, 4, 3))
	expect_equal(d$.icen_R, c(1, Inf, 5, 2.5, Inf, 6))
})

test_that("estimate_only returns a NULL vcov and NA variance with the padded coefficient vector", {
	f <- mk()
	local_mocked_bindings(ic_sp = function(...) fake_fit(-0.2), .package = "icenReg")
	out <- f$priv$generate_mod_icen(estimate_only = TRUE)
	expect_equal(out$beta_hat_T, -0.2)
	expect_equal(out$b, c(0, -0.2))
	expect_null(out$vcov)
	expect_true(is.na(out$ssq_b_2))
	expect_true(is.na(out$neg_log_lik))
})
