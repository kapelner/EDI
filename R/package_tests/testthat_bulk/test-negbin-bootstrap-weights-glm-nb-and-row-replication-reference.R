library(testthat)
library(EDI)

# InferenceCountNegBin$compute_estimate_with_bootstrap_weights(): weighted NB2 fit through the C++ kernel.
# References: MASS::glm.nb(weights) (fast optimizers agree only loosely) and integer-weight == row-replication
# equivalence; SE/df stay NA; zero weights are equivalent to dropping the rows.

skip_if_not_installed("MASS")
set.seed(21); n <- 120L
X <- data.frame(x1 = rnorm(n))
des <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 5L, verbose = FALSE)
des$add_all_subjects_to_experiment(X)
des$assign_w_to_all_subjects()
w <- des$get_w()
set.seed(22); y <- rnbinom(n, mu = exp(0.6 + 0.4 * w + 0.3 * X$x1), size = 2)
des$add_all_subject_responses(y)
mk <- function() {
	inf <- InferenceCountNegBin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	list(inf = inf, p = p)
}
d <- data.frame(y = y, w = w, x1 = X$x1)

test_that("integer weights reproduce the row-replicated glm.nb estimate", {
	set.seed(1); wt <- sample(0:3, n, replace = TRUE)
	est <- mk()$inf$compute_estimate_with_bootstrap_weights(wt)
	ref <- unname(coef(MASS::glm.nb(y ~ w + x1, data = d[rep(seq_len(n), wt), ]))["w"])
	expect_equal(est, ref, tolerance = 2e-2)
	expect_equal(mk()$inf$compute_estimate_with_bootstrap_weights(wt), est, tolerance = 1e-6)
})

test_that("continuous weights agree with MASS::glm.nb(weights) and cache no SE or df", {
	set.seed(2); wt <- rexp(n)
	f <- mk()
	est <- f$inf$compute_estimate_with_bootstrap_weights(wt)
	ref <- suppressWarnings(unname(coef(MASS::glm.nb(y ~ w + x1, data = d, weights = wt))["w"]))
	expect_equal(est, ref, tolerance = 5e-2)
	f$p$weighted_refit_impl(wt)
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))
	expect_true(is.na(f$p$cached_values$df))
	expect_equal(f$p$cached_values$beta_hat_T, est, tolerance = 1e-3)   # second fit is warm-started
})

test_that("zero-weight rows are equivalent to dropping them", {
	set.seed(3); wt <- rexp(n); wt[1:15] <- 0
	est <- mk()$inf$compute_estimate_with_bootstrap_weights(wt)
	ref <- unname(coef(MASS::glm.nb(y ~ w + x1, data = d[-(1:15), ], weights = wt[-(1:15)]))["w"])
	expect_true(is.finite(est))
	expect_equal(est, ref, tolerance = 5e-2)
})
