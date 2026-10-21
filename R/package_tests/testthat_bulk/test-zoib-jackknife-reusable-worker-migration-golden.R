library(testthat)
library(EDI)

test_that("ZOIB reusable jackknife preserves the finite public legacy result", {
	# Not the tuning fixture (edi_tuning_synthetic_experiment("proportion")): its
	# response is almost a deterministic function of the treatment (cor 0.9), so
	# all 50 leave-one-out replicates agree to ~1e-10 and the jackknife SE is
	# floating-point noise. The summary's |bias| <= 2 * SE guard then sits at a
	# ratio of ~1.0 on that noise and flips to non-estimable under a different
	# build's rounding (CI's portable build returned NA for all three methods).
	# This fixture has real covariate variation and interior-only responses.
	seed <- 20264507L
	set.seed(seed)
	ns <- asNamespace("EDI")
	n <- 50L
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	design <- DesignFixedBernoulli$new(
		n = n, response_type = "proportion", seed = seed, verbose = FALSE
	)
	design$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	design$assign_w_to_all_subjects()
	w <- as.numeric(design$get_w())
	mu <- plogis(0.2 + 0.5 * w + 0.3 * x1 - 0.2 * x2)
	y <- pmin(pmax(rbeta(n, mu * 8, (1 - mu) * 8), 0.02), 0.98)
	design$add_all_subject_responses(y)
	expect_equal(sum(y <= 0 | y >= 1), 0L)

	zoib_generator <- get("InferencePropZeroOneInflatedBetaRegr", envir = ns)
	LegacyZOIB <- R6::R6Class(
		"LegacyZOIBJackknifeMigrationReference",
		inherit = zoib_generator,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)

	reusable <- zoib_generator$new(design, verbose = FALSE)
	legacy <- LegacyZOIB$new(design, verbose = FALSE)
	reusable$num_cores <- 1L
	legacy$num_cores <- 1L

	# The legacy subclass forces the pre-worker, fresh-fit-per-fold path. This is
	# a migration oracle for this performance-only change, not a speed assertion.
	methods <- c(
		"compute_jackknife_estimate",
		"compute_jackknife_std_error",
		"compute_jackknife_wald_two_sided_pval"
	)
	for (method in methods) {
		new_value <- reusable[[method]]()
		legacy_value <- legacy[[method]]()
		expect_length(new_value, 1L)
		expect_true(is.finite(new_value), info = method)
		expect_identical(new_value, legacy_value, info = method)
	}
})

test_that("ZOIB reusable worker keeps distinct component matrices aligned across rank fallback and recovery", {
	seed <- 20261016L
	set.seed(seed)
	n <- 24L
	beta_x <- seq(-1, 1, length.out = n)
	rare_zero_one <- c(rep(0, n - 1L), 1)
	design <- DesignFixedBernoulli$new(
		n = n, response_type = "proportion", seed = seed, verbose = FALSE
	)
	design$add_all_subjects_to_experiment(data.frame(beta_x = beta_x, rare_zero_one = rare_zero_one))
	design$assign_w_to_all_subjects()
	w <- as.numeric(design$get_w())
	y <- plogis(-0.3 + 0.55 * w + 0.25 * beta_x)
	y[seq.int(2L, n, by = 7L)] <- 0
	y[seq.int(5L, n, by = 11L)] <- 1
	design$add_all_subject_responses(y)

	zoib <- InferencePropZeroOneInflatedBetaRegr$new(
		design,
		model_formula = ~ beta_x,
		model_formula_zero_one = ~ rare_zero_one,
		verbose = FALSE
	)
	zoib$num_cores <- 1L
	zoib_generator <- get("InferencePropZeroOneInflatedBetaRegr", envir = asNamespace("EDI"))
	LegacyZOIB <- R6::R6Class(
		"LegacyZOIBBoundaryJackknifeReference",
		inherit = zoib_generator,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)
	legacy <- LegacyZOIB$new(
		design,
		model_formula = ~ beta_x,
		model_formula_zero_one = ~ rare_zero_one,
		verbose = FALSE
	)
	legacy$num_cores <- 1L
	for (method in c(
		"compute_jackknife_estimate",
		"compute_jackknife_std_error",
		"compute_jackknife_wald_two_sided_pval"
	)) {
		new_value <- zoib[[method]]()
		legacy_value <- legacy[[method]]()
		expect_identical(new_value, legacy_value, info = method)
	}
	p <- zoib$.__enclos_env__$private
	ws <- p$create_bootstrap_worker_state()
	idx <- seq_len(n - 1L) # omit the only nonzero zero/one covariate value
	# The full-fit required_cols contract reserves column 2 for treatment in
	# both component matrices. Row-subsetting a worker draw must preserve those
	# frozen names, including the rank-deficient auxiliary-matrix fallback.
	expect_identical(colnames(ws$spec$X_full)[2L], "treatment")
	expect_identical(colnames(ws$spec$X_zero_one_full)[2L], "treatment")

	# The beta and zero/one formulas intentionally use different covariates.
	# Loading one draw must apply its row indices to both matrices, not reuse the
	# beta matrix for the auxiliary components.
	p$load_bootstrap_sample_into_worker(ws, idx)
	expect_named_equal <- function(actual, expected) {
		expect_equal(unname(actual), unname(expected), tolerance = 0)
		expect_identical(colnames(actual), colnames(expected))
	}
	expect_named_equal(ws$runtime$X, ws$spec$X_full[idx, , drop = FALSE])
	expect_named_equal(ws$runtime$X_zero_one, ws$spec$X_zero_one_full[idx, , drop = FALSE])
	expect_identical(colnames(ws$runtime$X)[2L], "treatment")
	expect_identical(colnames(ws$runtime$X_zero_one)[2L], "treatment")
	expect_true("beta_x" %in% colnames(ws$runtime$X))
	expect_false("rare_zero_one" %in% colnames(ws$runtime$X))
	expect_true("rare_zero_one" %in% colnames(ws$runtime$X_zero_one))
	expect_false("beta_x" %in% colnames(ws$runtime$X_zero_one))
	expect_false(ws$runtime$fast_path_ready)

	# Exercise the same matrix-name invariant across ordinary, permuted,
	# duplicated/rank-deficient, and wrapped bootstrap-index representations.
	# Each load must preserve the fixed treatment slot in both components while
	# keeping every other column aligned to the exact sampled rows.
	property_draws <- list(
		full = seq_len(n),
		permuted = rev(seq_len(n)),
		duplicated_without_rare_level = c(seq_len(n - 1L), n - 1L),
		wrapped_bootstrap_draw = list(i_b = idx, m_vec_b = NULL)
	)
	property_ws <- p$create_bootstrap_worker_state()
	for (draw in property_draws) {
		draw_indices = if (is.list(draw)) as.integer(draw$i_b) else as.integer(draw)
		p$load_bootstrap_sample_into_worker(property_ws, draw)
		expect_identical(colnames(property_ws$runtime$X)[2L], "treatment")
		expect_identical(colnames(property_ws$runtime$X_zero_one)[2L], "treatment")
		expect_named_equal(property_ws$runtime$X, property_ws$spec$X_full[draw_indices, , drop = FALSE])
		expect_named_equal(property_ws$runtime$X_zero_one, property_ws$spec$X_zero_one_full[draw_indices, , drop = FALSE])
	}

	# The rank-deficient auxiliary matrix must take the ordinary hardened-fit
	# route and agree with an independently loaded worker using that direct fit.
	fallback_estimate <- p$compute_bootstrap_worker_estimate(ws)
	reference_state <- p$create_bootstrap_worker_state()
	p$load_bootstrap_sample_into_worker(reference_state, idx)
	reference_estimate <- reference_state$worker$compute_estimate(estimate_only = TRUE)
	expect_true(is.finite(fallback_estimate))
	expect_identical(fallback_estimate, as.numeric(reference_estimate)[1L])

	# The same worker must become eligible for the direct native path again once
	# both formula matrices are full rank on a later draw.
	p$load_bootstrap_sample_into_worker(ws, seq_len(n))
	expect_true(ws$runtime$fast_path_ready)
	recovered_estimate <- p$compute_bootstrap_worker_estimate(ws)
	reference_full_state <- p$create_bootstrap_worker_state()
	p$load_bootstrap_sample_into_worker(reference_full_state, seq_len(n))
	reference_full_estimate <- reference_full_state$worker$compute_estimate(estimate_only = TRUE)
	expect_true(is.finite(recovered_estimate))
	expect_identical(recovered_estimate, as.numeric(reference_full_estimate)[1L])
})

test_that("ZOIB jackknife extreme-summary NA decision is identical for equal finite draws across routes", {
	# Isolate the shared pure-R summary guard: do not run a model fit or
	# leave-one-out loop. Both worker-route variants receive the same finite
	# synthetic vector, whose nonzero bias and zero SE trigger the final
	# jackknife_extreme_summary guard.
	n <- 8L
	design <- DesignFixedBernoulli$new(
		n = n, response_type = "proportion", seed = 20261020L, verbose = FALSE
	)
	design$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	design$assign_w_to_all_subjects()
	design$add_all_subject_responses(seq(0.2, 0.8, length.out = n))

	zoib_generator <- get("InferencePropZeroOneInflatedBetaRegr", envir = asNamespace("EDI"))
	LegacyZOIB <- R6::R6Class(
		"LegacyZOIBJackknifeSummaryRouteReference",
		inherit = zoib_generator,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)
	instances <- list(
		reusable = zoib_generator$new(design, verbose = FALSE),
		legacy = LegacyZOIB$new(design, verbose = FALSE)
	)
	jack <- rep(0.25, 4L)
	for (route in names(instances)) {
		inf <- instances[[route]]
		unlockBinding("compute_estimate", inf)
		inf$compute_estimate <- function(estimate_only = FALSE) 0.2
		priv <- inf$.__enclos_env__$private
		unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", priv)
		priv$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") jack
	}

	results <- lapply(instances, function(inf) {
		list(
			summary = inf$.__enclos_env__$private$compute_jackknife_summary(unit = "auto"),
			estimate = inf$compute_jackknife_estimate(),
			reason = inf$get_nonestimable_reason()
		)
	})
	expect_true(all(is.finite(jack)))
	expect_identical(instances$reusable$.__enclos_env__$private$supports_reusable_bootstrap_worker(), TRUE)
	expect_identical(instances$legacy$.__enclos_env__$private$supports_reusable_bootstrap_worker(), FALSE)
	for (result in results) {
		expect_true(all(is.na(c(result$summary$estimate, result$summary$bias, result$summary$std_error))))
		expect_identical(result$summary$distribution, jack)
		expect_identical(result$estimate, NA_real_)
		expect_identical(result$reason, "jackknife_extreme_summary")
	}
	expect_identical(results$reusable, results$legacy)
})

test_that("ZOIB exact diagnosed tuning seed preserves finite jackknife draws across routes", {
	# TODO-4's exact diagnosed no-boundary fixture is important because its
	# public summaries are NA on both routes. Compare the finite underlying
	# leave-one-out values too, so an NA-only equality cannot hide a migration
	# difference. The seed and tuning fixture constructor match the recorded
	# TODO-3 diagnosis; this is parity, not a claim that the summary is estimable.
	n <- 50L
	seed <- 20264492L
	ns <- asNamespace("EDI")
	make_design <- get("edi_tuning_synthetic_experiment", envir = ns)
	design <- make_design("proportion", n = n, seed = seed)
	y <- as.numeric(design$get_y())
	expect_identical(sum(y <= 0 | y >= 1), 0L)

	zoib_generator <- get("InferencePropZeroOneInflatedBetaRegr", envir = ns)
	LegacyZOIB <- R6::R6Class(
		"LegacyZOIBExactTuningJackknifeReference",
		inherit = zoib_generator,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)
	instances <- list(
		reusable = zoib_generator$new(design, verbose = FALSE),
		legacy = LegacyZOIB$new(design, verbose = FALSE)
	)
	for (inf in instances) inf$num_cores <- 1L
	summaries <- lapply(instances, function(inf) {
		inf$.__enclos_env__$private$compute_jackknife_summary(unit = "auto")
	})

	new_summary <- summaries$reusable
	old_summary <- summaries$legacy
	expect_length(new_summary$distribution, n)
	expect_true(all(is.finite(new_summary$distribution)))
	expect_identical(new_summary$distribution, old_summary$distribution)
	expect_identical(new_summary$estimate, NA_real_)
	expect_identical(new_summary$bias, NA_real_)
	expect_identical(new_summary$std_error, NA_real_)
	expect_identical(new_summary, old_summary)
	expect_identical(instances$reusable$get_nonestimable_reason(), "jackknife_extreme_summary")
	expect_identical(instances$legacy$get_nonestimable_reason(), "jackknife_extreme_summary")
	for (method in c(
		"compute_jackknife_estimate",
		"compute_jackknife_std_error",
		"compute_jackknife_wald_two_sided_pval"
	)) {
		expect_identical(instances$reusable[[method]](), instances$legacy[[method]](), info = method)
	}
})
