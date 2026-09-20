library(testthat)
library(EDI)

# InferenceIncidKKModifiedPoisson$compute_estimate_with_bootstrap_weights() —
# a KK-clustered marginal modified-Poisson refit, distinct from the plain
# (non-KK) InferenceIncidModifiedPoisson already covered elsewhere. Existing
# coverage (migration-golden, parametric-bootstrap-lr-all-capable-classes)
# only exercises unit weights via B=21 row-resampling equivalence, never a
# genuinely-varying-weight refit checked against an independent reference.

make_kk_modpois_fixture <- function(seed = 20260918L, n = 72L){
	set.seed(seed)
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
		y_i <- rbinom(1L, 1L, plogis(-0.30 + 0.55 * w_i + 0.25 * x1[i] - 0.15 * x2[i]))
		des$add_one_subject_response(i, y_i)
	}
	des
}

install_bb_context <- function(inf, n_rows){
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n_rows), unit_group_id = rep(1L, n_rows), n_units = n_rows
	)
	inf
}

test_that("KK modified-Poisson weighted-bootstrap refit matches an independent weighted glm.fit(poisson)", {
	des <- make_kk_modpois_fixture()
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	X <- as.matrix(priv$build_design_matrix())
	y <- as.numeric(priv$y)
	n <- nrow(X)
	install_bb_context(inf, n)

	set.seed(1L)
	weights <- runif(n, 0.2, 3)

	est <- inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)

	ref_fit <- glm.fit(X, y, weights = weights, family = poisson())
	ref_beta_T <- unname(ref_fit$coefficients[2L])

	expect_equal(est, ref_beta_T, tolerance = 1e-4)

	# SE/df are never populated on this path, regardless of estimate_only
	expect_true(is.na(priv$last_weighted_refit$s_beta_hat_T))
	inf2 <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	install_bb_context(inf2, n)
	inf2$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	expect_true(is.na(inf2$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
})

test_that("unit weights reproduce compute_estimate() via the effectively-constant shortcut", {
	des <- make_kk_modpois_fixture(seed = 20260919L)
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)

	unweighted <- as.numeric(inf$compute_estimate(estimate_only = TRUE))[1]

	inf2 <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	n <- length(inf2$.__enclos_env__$private$y)
	install_bb_context(inf2, n)
	weighted_unit <- inf2$compute_estimate_with_bootstrap_weights(rep(1, n), estimate_only = TRUE)

	expect_equal(weighted_unit, unweighted, tolerance = 1e-10)
})

test_that("genuinely varying weights diverge from the unweighted estimate", {
	des <- make_kk_modpois_fixture(seed = 20260920L)
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	n <- length(priv$y)

	unweighted <- as.numeric(inf$compute_estimate(estimate_only = TRUE))[1]

	set.seed(2L)
	weights <- runif(n, 0.1, 5)
	inf2 <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	install_bb_context(inf2, n)
	weighted <- inf2$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)

	expect_true(abs(weighted - unweighted) > 1e-4)
})

test_that("all-zero weights return NA", {
	des <- make_kk_modpois_fixture(seed = 20260921L)
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	n <- length(inf$.__enclos_env__$private$y)
	install_bb_context(inf, n)

	result <- inf$compute_estimate_with_bootstrap_weights(rep(0, n), estimate_only = TRUE)
	expect_true(is.na(result))
})
