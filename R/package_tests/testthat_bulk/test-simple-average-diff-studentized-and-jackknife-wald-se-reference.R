library(testthat)
library(EDI)

# The shared InferenceAllAverageDiff$compute_estimate_with_bootstrap_weights()
# (R/EDI/R/inference_all_average_diff.R:98), used by every class composing the
# "SimpleMeanDifference" component (InferenceAllSimpleAverageDiff,
# InferenceIncidWald, InferenceIncidCMH, InferenceIncidExtendedRobins), was
# previously only checked for finiteness under unit weights
# (R/EDI/tests/testthat/test-bayesian-bootstrap.R, "next-wave weighted hooks").
# Bootstrap draws use frequency weights: their sum is the resample size. The
# old Kish-effective-size formula counted unequal bootstrap weights twice,
# making replicate SEs about sqrt(2) too large and studentized intervals too
# narrow. Exercised here via InferenceAllSimpleAverageDiff (continuous
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

weighted_frequency_welch_reference <- function(y, w, weights) {
	i_t <- w == 1
	i_c <- w == 0
	y_t <- y[i_t]; rw_t <- weights[i_t]
	y_c <- y[i_c]; rw_c <- weights[i_c]
	mean_t <- sum(y_t * rw_t) / sum(rw_t)
	mean_c <- sum(y_c * rw_c) / sum(rw_c)
	total_weight_t <- sum(rw_t)
	total_weight_c <- sum(rw_c)
	s_t_sq <- sum(rw_t * (y_t - mean_t)^2) / total_weight_t / (total_weight_t - 1)
	s_c_sq <- sum(rw_c * (y_c - mean_c)^2) / total_weight_c / (total_weight_c - 1)
	se <- sqrt(s_t_sq + s_c_sq)
	df <- (s_t_sq + s_c_sq)^2 / (s_t_sq^2 / (total_weight_t - 1) + s_c_sq^2 / (total_weight_c - 1))
	list(est = mean_t - mean_c, se = se, df = df)
}

test_that("SimpleMeanDifference weighted-bootstrap estimate/SE/df match an independent frequency-Welch reference", {
	set.seed(20260918)
	n <- 30L
	w <- rep(c(0, 1), length.out = n)
	y <- rnorm(n)
	des <- make_cont_design(y, w)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	install_unit_bayes_boot_context(inf, n)

	weights <- runif(n, 0.2, 3)
	weights <- weights / sum(weights) * n
	est <- as.numeric(inf$compute_estimate_with_bootstrap_weights(weights))
	ref <- weighted_frequency_welch_reference(y, w, weights)
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
	weights <- weights / sum(weights) * n
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
	weights <- weights / sum(weights) * n
	ref <- weighted_frequency_welch_reference(as.numeric(y_incid), w, weights)

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
	ref_er <- weighted_frequency_welch_reference(as.numeric(y_er), w_er, weights)
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

test_that("SimpleAverageDiff jackknife Wald uses the shared bias-corrected estimate, delete-one SE and normal calibration", {
	y <- c(-1.2, -0.4, 0.1, 0.8, 1.7, -0.9, -0.1, 0.4, 1.1, 2.0)
	w <- rep(0:1, each = 5L)
	inf <- InferenceAllSimpleAverageDiff$new(make_cont_design(y, w))
	theta_hat <- as.numeric(inf$compute_estimate(estimate_only = TRUE))
	jack <- inf$approximate_jackknife_distribution_beta_hat_T(unit = "observation")
	jack_bar <- mean(jack)
	se_hand <- sqrt((length(jack) - 1) / length(jack) * sum((jack - jack_bar)^2))

	expect_equal(inf$compute_jackknife_std_error(unit = "observation"), se_hand, tolerance = 1e-12)
	jack_estimate <- inf$compute_jackknife_estimate(unit = "observation")
	ci <- inf$compute_jackknife_wald_confidence_interval(alpha = 0.05, unit = "observation")
	expect_equal(unname(ci), jack_estimate + c(-1, 1) * qnorm(0.975) * se_hand, tolerance = 1e-12)
	expect_equal(jack_estimate, theta_hat, tolerance = 1e-12)

	welch_se <- sqrt(var(y[w == 1L]) / 5 + var(y[w == 0L]) / 5)
	expect_equal(se_hand / welch_se, sqrt(9 / 8), tolerance = 1e-12)
})
