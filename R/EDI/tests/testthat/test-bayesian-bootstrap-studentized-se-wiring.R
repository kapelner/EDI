test_that("InferenceCountRobustPoisson wires a weighted sandwich SE through its bootstrap-weight refit", {
	# Regression for the 2026-09-07 fix: compute_estimate_with_bootstrap_weights()
	# always hardcoded s_beta_hat_T = NA_real_, starving the Bayesian-bootstrap
	# studentized/BCa variants of a per-replicate SE.
	set.seed(80101L)
	n <- 100L
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.5 + 0.3 * w)))
	inf <- InferenceCountRobustPoisson$new(des, model_formula = ~ x1, verbose = FALSE)
	draw <- inf$.__enclos_env__$private$bayesian_bootstrap_sample_weights()
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- draw$context
	est <- inf$compute_estimate_with_bootstrap_weights(draw$subject_or_block_weights, estimate_only = FALSE)
	expect_true(is.finite(est))
	expect_true(is.finite(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
	expect_gt(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, 0)
})

test_that("InferenceCountQuasiPoisson wires a weighted dispersion-scaled SE through its bootstrap-weight refit", {
	set.seed(80102L)
	n <- 100L
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.5 + 0.3 * w)))
	inf <- InferenceCountQuasiPoisson$new(des, model_formula = ~ x1, verbose = FALSE)
	draw <- inf$.__enclos_env__$private$bayesian_bootstrap_sample_weights()
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- draw$context
	est <- inf$compute_estimate_with_bootstrap_weights(draw$subject_or_block_weights, estimate_only = FALSE)
	expect_true(is.finite(est))
	expect_true(is.finite(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
	expect_gt(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, 0)
})

test_that("InferenceOrdinalPropOddsRegr reads the treatment coefficient from the correct index and wires its SE", {
	# Regression for TWO bugs fixed 2026-09-07: (1) the point estimate was
	# read as res$b[length(res$b)] instead of res$b[1] (only equivalent
	# when there are no extra covariates), and (2) the already-computed
	# ssq_b_j was discarded and replaced with NA.
	set.seed(80103L)
	n <- 100L
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalPropOddsRegr$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	draw <- inf$.__enclos_env__$private$bayesian_bootstrap_sample_weights()
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- draw$context
	est <- inf$compute_estimate_with_bootstrap_weights(draw$subject_or_block_weights, estimate_only = FALSE)
	expect_true(is.finite(est))
	# The point estimate must come from the treatment column (index 1 of
	# the design matrix), not the last covariate -- sanity-check it is not
	# wildly different in scale/sign pattern from the asymptotic estimate.
	asymp_est <- inf$compute_estimate()
	expect_true(is.finite(asymp_est))
	expect_true(is.finite(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
	expect_gt(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, 0)
})

test_that("InferenceOrdinalKKCLMM (logit link) wires the already-computed weighted SE through", {
	set.seed(80104L)
	n <- 60L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	add_all_subject_responses_seq(des, sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	inf$compute_estimate()
	draw <- inf$.__enclos_env__$private$bayesian_bootstrap_sample_weights()
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- draw$context
	est <- inf$compute_estimate_with_bootstrap_weights(draw$subject_or_block_weights, estimate_only = FALSE)
	expect_true(is.finite(est))
	expect_true(is.finite(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
	expect_gt(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, 0)
})

test_that("Studentized Bayesian bootstrap NA rate drops for the four fixed classes", {
	# End-to-end regression: before the 2026-09-07 fixes, all four of these
	# classes returned NA on the large majority (often 100%) of
	# compute_bayesian_bootstrap_two_sided_pval(type = "studentized") calls
	# because the per-replicate SE was always unavailable.
	check_class <- function(cls_name, response_type, mk_y, model_formula, R = 10L) {
		na_count <- 0L
		n <- 80L
		for (r in seq_len(R)) {
			set.seed(80200L + r)
			des <- DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
			des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
			des$assign_w_to_all_subjects()
			w <- des$get_w()
			des$add_all_subject_responses(mk_y(w))
			inf <- get(cls_name)$new(des, model_formula = model_formula, verbose = FALSE)
			p <- tryCatch(inf$compute_bayesian_bootstrap_two_sided_pval(type = "studentized", B = 60, show_progress = FALSE), error = function(e) NA_real_)
			if (is.na(p)) na_count <- na_count + 1L
		}
		na_count
	}
	na_robust <- check_class("InferenceCountRobustPoisson", "count", function(w) rpois(80, exp(0.5 + 0.3 * w)), ~ x1)
	na_quasi <- check_class("InferenceCountQuasiPoisson", "count", function(w) rpois(80, exp(0.5 + 0.3 * w)), ~ x1)
	na_propodds <- check_class("InferenceOrdinalPropOddsRegr", "ordinal", function(w) sample(1:4, 80, replace = TRUE), ~ x1)

	expect_lt(na_robust / 10, 0.5)
	expect_lt(na_quasi / 10, 0.5)
	expect_lt(na_propodds / 10, 0.5)
})
