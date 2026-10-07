library(EDI)

# Smoothed BRT noise must respect the response support. Raw-scale Gaussian noise
# added to count responses produced negative / non-integer counts, so every
# glmmTMB Poisson fit in the smoothed null distribution failed with
# "negative values not allowed for the 'Poisson' family" (2026-09-15 count suite,
# InferenceCountKKGLMM on diamonds).

make_smoothed_count_kk_design <- function(seed = 20260915L, n = 40L){
	set.seed(seed)
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
		mu_i <- exp(0.20 + 0.35 * w_i + 0.20 * x1[i] - 0.10 * x2[i] + rnorm(1, sd = 0.15))
		des$add_one_subject_response(i, rpois(1L, lambda = mu_i))
	}
	des
}

test_that("add_rand_bootstrap_smooth_noise keeps count responses on the non-negative integer support", {
	des <- make_smoothed_count_kk_design()
	inf <- InferenceCountKKGLMM$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	y <- c(0L, 0L, 1L, 3L, 7L)
	noise <- c(-0.9, 0.4, -0.6, 0.51, -2.7)
	y_count <- priv$add_rand_bootstrap_smooth_noise(y, noise, "count")
	expect_true(is.integer(y_count))
	expect_true(all(y_count >= 0L))
	expect_equal(y_count, c(0L, 0L, 0L, 4L, 4L))
	# continuous responses keep the raw additive kernel noise
	expect_equal(priv$add_rand_bootstrap_smooth_noise(as.numeric(y), noise, "continuous"), as.numeric(y) + noise)
})

test_that("smoothed BRT rejects categorical model refits while preserving real-valued location statistics", {
	for (response_type in c("incidence", "ordinal", "proportion")) {
		set.seed(18L)
		n <- 18L
		des <- DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
		des$assign_w_to_all_subjects()
		y <- switch(response_type,
			incidence = rep(c(0L, 1L), length.out = n),
			ordinal = rep(1:3, length.out = n),
			proportion = seq(0.1, 0.9, length.out = n)
		)
		des$add_all_subject_responses(y)
		location_inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
		expect_true("smoothed" %in% location_inf$get_supported_rand_bootstrap_pval_types())
		expect_identical("smoothed" %in% location_inf$get_supported_rand_bootstrap_ci_types(),
		                 response_type != "incidence")
		if (identical(response_type, "incidence")) {
			expect_error(location_inf$compute_rand_bootstrap_confidence_interval(type = "smoothed", B = 3L, show_progress = FALSE),
			             "not supported for incidence")
		}
		expect_equal(location_inf$.__enclos_env__$private$add_rand_bootstrap_smooth_noise(y, rep(0.1, n), response_type),
		             as.numeric(y) + 0.1)
		draws <- location_inf$.__enclos_env__$private$generate_rand_bootstrap_draws(21L, materialize_w = TRUE)
		for (b in seq_along(draws)) draws[[b]][["smooth_noise"]] <- rep(0.1, n)
		location_null <- location_inf$approximate_rand_bootstrap_distribution_beta_hat_T(
			B = 21L, rand_bootstrap_draws = draws, show_progress = FALSE)
		expect_length(location_null, 21L)
		expect_true(all(is.finite(location_null)))
		expect_true(is.finite(location_inf$compute_rand_bootstrap_two_sided_pval(
			B = 21L, type = "smoothed", rand_bootstrap_draws = draws, show_progress = FALSE)))
		inf <- switch(response_type,
			incidence = InferenceIncidProbitRegr$new(des, verbose = FALSE),
			ordinal = InferenceOrdinalRidit$new(des, verbose = FALSE),
			proportion = InferencePropFractionalLogit$new(des, verbose = FALSE)
		)
		priv <- inf$.__enclos_env__$private
		expect_false("smoothed" %in% inf$get_supported_rand_bootstrap_pval_types())
		expect_false("smoothed" %in% inf$get_supported_rand_bootstrap_ci_types())
		expect_true("percentile" %in% inf$get_supported_rand_bootstrap_pval_types())
		expect_error(inf$compute_rand_bootstrap_two_sided_pval(B = 3L, type = "smoothed", show_progress = FALSE),
		             paste0("not supported for ", response_type, " responses"))
		expect_error(inf$compute_rand_bootstrap_confidence_interval(B = 3L, type = "smoothed", show_progress = FALSE),
		             paste0("not supported for ", response_type, " responses"))
		expect_error(priv$add_rand_bootstrap_smooth_noise(y, rep(0.1, n), response_type),
		             paste0("not supported for ", response_type, " responses"))
		expect_error(inf$approximate_rand_bootstrap_distribution_beta_hat_T(
			B = 1L, rand_bootstrap_draws = list(list(smooth_noise = rep(0.1, n))), show_progress = FALSE),
			paste0("not supported for ", response_type, " responses"))
		if (identical(response_type, "ordinal")) {
			jt <- InferenceOrdinalJonckheereTerpstraTest$new(des, verbose = FALSE)
			expect_false("smoothed" %in% jt$get_supported_rand_bootstrap_pval_types())
			expect_error(jt$compute_rand_bootstrap_two_sided_pval(B = 3L, type = "smoothed", show_progress = FALSE),
			             "not supported for ordinal responses")
		}
	}
})

test_that("historically flagged smoothed classes follow their response and estimator boundary", {
	set.seed(1801L)
	n <- 30L
	incid_des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) incid_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	incid_des$add_all_subject_responses(rbinom(n, 1L, 0.5))
	incid_inf <- InferenceIncidKKCondLogitOneLik$new(incid_des, verbose = FALSE)
	expect_false("smoothed" %in% incid_inf$get_supported_rand_bootstrap_pval_types())
	expect_error(incid_inf$compute_rand_bootstrap_two_sided_pval(B = 3L, type = "smoothed", show_progress = FALSE),
	             "not supported for incidence responses")

	set.seed(1802L)
	n <- 50L
	ordinal_des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	ordinal_des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	ordinal_des$assign_w_to_all_subjects()
	ordinal_des$add_all_subject_responses(as.integer(cut(rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf))))
	ordinal_inf <- InferenceOrdinalGCompMeanDiff$new(ordinal_des, verbose = FALSE)
	expect_false("smoothed" %in% ordinal_inf$get_supported_rand_bootstrap_pval_types())
	expect_error(ordinal_inf$compute_rand_bootstrap_two_sided_pval(B = 3L, type = "smoothed", show_progress = FALSE),
	             "not supported for ordinal responses")

	set.seed(1803L)
	n <- 30L
	continuous_des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) continuous_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	continuous_des$add_all_subject_responses(rnorm(n))
	continuous_inf <- InferenceContinKKRobustRegrOneLik$new(continuous_des, use_rcpp = FALSE, verbose = FALSE)
	expect_true("smoothed" %in% continuous_inf$get_supported_rand_bootstrap_pval_types())
	expect_true(is.finite(continuous_inf$compute_rand_bootstrap_two_sided_pval(
		B = 21L, type = "smoothed", show_progress = FALSE)))
})

test_that("survival CoxPH retains its smoothed bootstrap path", {
	set.seed(1804L)
	n <- 20L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
		des$add_one_subject_response(i, rexp(1))
	}
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	expect_true("smoothed" %in% inf$get_supported_rand_bootstrap_pval_types())
	expect_equal(inf$.__enclos_env__$private$add_rand_bootstrap_smooth_noise(c(1, 2), c(0.1, -0.2), "survival"), c(1.1, 1.8))
	expect_true(is.finite(inf$compute_rand_bootstrap_two_sided_pval(B = 21L, type = "smoothed", show_progress = FALSE)))
})

test_that("smoothed BRT p-value for a glmmTMB Poisson GLMM emits no GLMM fit errors", {
	skip_if_not_installed("glmmTMB")
	des <- make_smoothed_count_kk_design()
	# use_rcpp = FALSE routes every null-draw refit through glmmTMB, whose Poisson
	# family rejects negative responses outright: before the fix all B draws failed
	# ("GLMM FIT ERROR: negative values not allowed for the 'Poisson' family") and the
	# p-value was NA. (With use_rcpp = TRUE the same failure surfaced only at the CI
	# inversion's large null shifts, where round(y_noisy * e^delta) went far negative.)
	inf <- InferenceCountKKGLMM$new(des, model_formula = ~ x1 + x2, use_rcpp = FALSE, verbose = FALSE)
	inf$set_seed(20260915L)
	msgs <- capture_messages(
		pval <- inf$compute_rand_bootstrap_two_sided_pval(B = 12L, type = "smoothed", show_progress = FALSE)
	)
	expect_false(any(grepl("GLMM FIT ERROR", msgs, fixed = TRUE)), info = paste(head(msgs, 3), collapse = "\n"))
	expect_true(is.finite(pval))
	expect_true(pval >= 0 && pval <= 1)
})
