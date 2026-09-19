library(testthat)
library(EDI)

# InferenceIncidMiettinenNurminenRiskDiff's compute_estimate_with_bootstrap_weights()
# was previously only checked against compute_estimate() under unit weights
# (R/EDI/tests/testthat/test-bayesian-bootstrap.R, inf_mn block) -- never with
# genuinely varying weights against an independent reference. The class's own
# doc comment states this weighted path is a plain weighted-proportion
# difference that skips the Miettinen-Nurminen score-test machinery entirely
# (and its small-sample bias correction), unlike compute_estimate()'s CI/p-value
# path -- so this test targets that specific weighted-proportion-difference
# formula directly.

make_mn_design <- function(y, w) {
	n <- length(y)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	}
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

weighted_riskdiff_reference <- function(y, w, weights) {
	i_t <- w == 1
	i_c <- w == 0
	p_t <- sum(weights[i_t] * y[i_t]) / sum(weights[i_t])
	p_c <- sum(weights[i_c] * y[i_c]) / sum(weights[i_c])
	p_t - p_c
}

install_unit_bayes_boot_context <- function(inf, n) {
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	invisible(inf)
}

test_that("Miettinen-Nurminen weighted-bootstrap point estimate matches an independent weighted-proportion-difference reference", {
	set.seed(20260918)
	n <- 40L
	w <- rep(c(0, 1), length.out = n)
	y <- rbinom(n, 1, 0.5)
	des <- make_mn_design(y, w)
	inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	install_unit_bayes_boot_context(inf, n)

	weights <- runif(n, 0.2, 3)
	est <- as.numeric(inf$compute_estimate_with_bootstrap_weights(weights))
	expect_equal(est, weighted_riskdiff_reference(y, w, weights), tolerance = 1e-10)

	# Documented contract: this weighted path never computes the score-based
	# variance/df, regardless of estimate_only.
	priv <- inf$.__enclos_env__$private
	expect_true(is.na(priv$cached_values$s_beta_hat_T))
	expect_true(is.na(priv$cached_values$df))

	est_only <- as.numeric(inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	expect_equal(est_only, est, tolerance = 1e-10)
})

test_that("Miettinen-Nurminen weighted-bootstrap reproduces compute_estimate() under unit weights and is weight-scale invariant", {
	set.seed(20260918)
	n <- 30L
	w <- rep(c(0, 1), length.out = n)
	y <- rbinom(n, 1, 0.5)
	des <- make_mn_design(y, w)

	inf1 <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	unweighted_est <- as.numeric(inf1$compute_estimate())
	install_unit_bayes_boot_context(inf1, n)
	unit_weighted_est <- as.numeric(inf1$compute_estimate_with_bootstrap_weights(rep(1, n)))
	expect_equal(unit_weighted_est, unweighted_est, tolerance = 1e-10)

	inf2 <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	install_unit_bayes_boot_context(inf2, n)
	weights <- runif(n, 0.5, 2)
	est <- as.numeric(inf2$compute_estimate_with_bootstrap_weights(weights))
	est_scaled <- as.numeric(inf2$compute_estimate_with_bootstrap_weights(7 * weights))
	expect_equal(est_scaled, est, tolerance = 1e-10)
})

test_that("Miettinen-Nurminen weighted-bootstrap returns NA when one arm's weight collapses to zero", {
	n <- 20L
	w <- rep(c(0, 1), length.out = n)
	y <- rbinom(n, 1, 0.5)
	des <- make_mn_design(y, w)
	inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	install_unit_bayes_boot_context(inf, n)

	weights <- ifelse(w == 1, 0, 1)
	est <- as.numeric(inf$compute_estimate_with_bootstrap_weights(weights))
	expect_true(is.na(est))
})
