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
	p <- zoib$.__enclos_env__$private
	ws <- p$create_bootstrap_worker_state()
	idx <- seq_len(n - 1L) # omit the only nonzero zero/one covariate value

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
	expect_true("beta_x" %in% colnames(ws$runtime$X))
	expect_false("rare_zero_one" %in% colnames(ws$runtime$X))
	expect_true("rare_zero_one" %in% colnames(ws$runtime$X_zero_one))
	expect_false("beta_x" %in% colnames(ws$runtime$X_zero_one))
	expect_false(ws$runtime$fast_path_ready)

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
