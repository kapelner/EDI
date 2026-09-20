library(testthat)
library(EDI)

# The shared InferenceAllAverageDiff$compute_estimate_with_bootstrap_weights()
# (R/EDI/R/inference_all_average_diff.R:98), used by every class composing the
# "SimpleMeanDifference" component (InferenceAllSimpleAverageDiff,
# InferenceIncidWald, InferenceIncidCMH, InferenceIncidExtendedRobins), was
# previously only checked for finiteness under unit weights
# (R/EDI/tests/testthat/test-bayesian-bootstrap.R, "next-wave weighted hooks").
# Its weighted Welch SE/df formula uses a Kish effective-sample-size correction
# under genuinely varying weights, which had no independent-reference check
# anywhere. Exercised here via InferenceAllSimpleAverageDiff (continuous
# response, the cleanest fixture for this shared mixin) plus a direct check
# that InferenceIncidCMH and InferenceIncidExtendedRobins dispatch to the
# identical shared implementation.

make_cont_design <- function(y, w) {
	n <- length(y)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	}
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

install_unit_bayes_boot_context <- function(inf, n) {
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	invisible(inf)
}

weighted_kish_welch_reference <- function(y, w, weights) {
	i_t <- w == 1
	i_c <- w == 0
	y_t <- y[i_t]; rw_t <- weights[i_t]
	y_c <- y[i_c]; rw_c <- weights[i_c]
	mean_t <- sum(y_t * rw_t) / sum(rw_t)
	mean_c <- sum(y_c * rw_c) / sum(rw_c)
	n_eff_t <- sum(rw_t)^2 / sum(rw_t^2)
	n_eff_c <- sum(rw_c)^2 / sum(rw_c^2)
	s_t_sq <- sum(rw_t * (y_t - mean_t)^2) / sum(rw_t) / (n_eff_t - 1)
	s_c_sq <- sum(rw_c * (y_c - mean_c)^2) / sum(rw_c) / (n_eff_c - 1)
	se <- sqrt(s_t_sq + s_c_sq)
	df <- (s_t_sq + s_c_sq)^2 / (s_t_sq^2 / (n_eff_t - 1) + s_c_sq^2 / (n_eff_c - 1))
	list(est = mean_t - mean_c, se = se, df = df)
}

test_that("SimpleMeanDifference weighted-bootstrap estimate/SE/df match an independent Kish-Welch reference", {
	set.seed(20260918)
	n <- 30L
	w <- rep(c(0, 1), length.out = n)
	y <- rnorm(n)
	des <- make_cont_design(y, w)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	install_unit_bayes_boot_context(inf, n)

	weights <- runif(n, 0.2, 3)
	est <- as.numeric(inf$compute_estimate_with_bootstrap_weights(weights))
	ref <- weighted_kish_welch_reference(y, w, weights)
	expect_equal(est, ref$est, tolerance = 1e-10)

	priv <- inf$.__enclos_env__$private
	expect_equal(priv$last_weighted_refit$s_beta_hat_T, ref$se, tolerance = 1e-10)
	expect_equal(priv$last_weighted_refit$df, ref$df, tolerance = 1e-8)
})

test_that("SimpleMeanDifference weighted-bootstrap estimate_only skips variance and reproduces compute_estimate() at unit weight", {
	set.seed(20260918)
	n <- 24L
	w <- rep(c(0, 1), length.out = n)
	y <- rnorm(n)
	des <- make_cont_design(y, w)

	inf1 <- InferenceAllSimpleAverageDiff$new(des)
	unweighted_est <- as.numeric(inf1$compute_estimate())
	install_unit_bayes_boot_context(inf1, n)
	unit_weighted_est <- as.numeric(inf1$compute_estimate_with_bootstrap_weights(rep(1, n)))
	expect_equal(unit_weighted_est, unweighted_est, tolerance = 1e-10)

	inf2 <- InferenceAllSimpleAverageDiff$new(des)
	install_unit_bayes_boot_context(inf2, n)
	weights <- runif(n, 0.5, 2)
	est_full <- as.numeric(inf2$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE))
	est_only <- as.numeric(inf2$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	expect_equal(est_only, est_full, tolerance = 1e-10)
	expect_true(is.na(inf2$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
})

test_that("InferenceIncidCMH and InferenceIncidExtendedRobins dispatch to the identical shared weighted implementation", {
	set.seed(20260918)
	n <- 30L
	w <- rep(c(0, 1), length.out = n)
	y_incid <- rbinom(n, 1, 0.5)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	}
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y_incid)

	weights <- runif(n, 0.2, 3)
	ref <- weighted_kish_welch_reference(as.numeric(y_incid), w, weights)

	inf_cmh <- InferenceIncidCMH$new(des)
	install_unit_bayes_boot_context(inf_cmh, n)
	est_cmh <- as.numeric(inf_cmh$compute_estimate_with_bootstrap_weights(weights))
	expect_equal(est_cmh, ref$est, tolerance = 1e-10)
	expect_equal(inf_cmh$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T, ref$se, tolerance = 1e-10)

	# InferenceIncidExtendedRobins requires a blocking design with equal block
	# sizes and even allocation, so it needs its own fixture; the actual
	# realized w/y are read back from the constructed Inference object's
	# private fields to build the matching independent reference.
	des_blk <- DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X <- data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2L))
	des_blk$add_all_subjects_to_experiment(X)
	des_blk$assign_w_to_all_subjects()
	des_blk$add_all_subject_responses(rbinom(n, 1, 0.4))

	inf_er <- InferenceIncidExtendedRobins$new(des_blk)
	w_er <- inf_er$.__enclos_env__$private$w
	y_er <- inf_er$.__enclos_env__$private$y
	ref_er <- weighted_kish_welch_reference(as.numeric(y_er), w_er, weights)
	install_unit_bayes_boot_context(inf_er, n)
	est_er <- as.numeric(inf_er$compute_estimate_with_bootstrap_weights(weights))
	expect_equal(est_er, ref_er$est, tolerance = 1e-10)
	expect_equal(inf_er$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T, ref_er$se, tolerance = 1e-10)
})

test_that("SimpleMeanDifference weighted-bootstrap returns NA when all rows are dropped", {
	n <- 16L
	w <- rep(c(0, 1), length.out = n)
	y <- rnorm(n)
	des <- make_cont_design(y, w)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	install_unit_bayes_boot_context(inf, n)

	weights <- rep(0, n)
	est <- as.numeric(inf$compute_estimate_with_bootstrap_weights(weights))
	expect_true(is.na(est))
	expect_true(is.na(inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
})
