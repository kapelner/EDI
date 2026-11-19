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
	# The noise keeps beta_x an ordinary covariate: without it logit(y) is an
	# exact linear function of w and beta_x, and the v1.0.6-TODO-158
	# perfect-predictor check drops beta_x in the constructor.
	y <- plogis(-0.3 + 0.55 * w + 0.25 * beta_x + rnorm(n, sd = 0.3))
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
	# >= 5 replicates so the v1.0.6-TODO-135 minimum-deletion-units guard (EDI_JACKKNIFE_MIN_DELETION_UNITS) does not fire first.
	jack <- rep(0.25, 5L)
	for (route in names(instances)) {
		inf <- instances[[route]]
		unlockBinding("compute_estimate", inf)
		inf$compute_estimate <- function(estimate_only = FALSE) 0.2
		priv <- inf$.__enclos_env__$private
		unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", priv)
		priv$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") jack
	}

	# The NA estimate is announced by one edi_procedure_na_warning per route
	# (v1.0.6-TODO-212 (2): it used to leak out of the test); expect exactly those.
	na_warnings <- list()
	results <- withCallingHandlers(
		lapply(instances, function(inf) {
			list(
				summary = inf$.__enclos_env__$private$compute_jackknife_summary(unit = "auto"),
				estimate = inf$compute_jackknife_estimate(),
				reason = inf$.__enclos_env__$private$cached_values$procedure_failure_reason$jackknife
			)
		}),
		edi_procedure_na_warning = function(cnd) {
			na_warnings[[length(na_warnings) + 1L]] <<- cnd
			invokeRestart("muffleWarning")
		}
	)
	expect_length(na_warnings, length(instances))
	for (cnd in na_warnings) {
		expect_match(conditionMessage(cnd), "compute_jackknife_estimate() returned NA (reason: jackknife_extreme_summary)", fixed = TRUE)
	}
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
	# The tuning fixture's proportion response was noise-free (y = plogis(linpred)),
	# so logit(y) was an exact linear function of w, x and z: since
	# v1.0.6-TODO-158 both routes dropped x and z (v1.0.6-TODO-190 asserted that
	# drop here). The fixture now adds a little logit-scale noise
	# (v1.0.6-TODO-204), so both routes keep x and z and must raise no
	# edi_perfect_predictor_warning, and the summaries are finite. Compare the
	# leave-one-out values too, so a summary-only equality cannot hide a
	# migration difference. The NA-producing extreme-summary guard is covered by
	# the synthetic test above; the failed-direct-fit fallback by the next test.
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
	dropped <- list()
	make_instance <- function(generator, route) {
		withCallingHandlers(
			generator$new(design, verbose = FALSE),
			edi_perfect_predictor_warning = function(cnd) {
				dropped[[route]] <<- cnd$dropped
				invokeRestart("muffleWarning")
			}
		)
	}
	instances <- list(
		reusable = make_instance(zoib_generator, "reusable"),
		legacy = make_instance(LegacyZOIB, "legacy")
	)
	expect_length(dropped, 0L)
	for (inf in instances) expect_identical(colnames(inf$.__enclos_env__$private$X), c("x", "z"))
	for (inf in instances) inf$num_cores <- 1L
	summaries <- lapply(instances, function(inf) {
		inf$.__enclos_env__$private$compute_jackknife_summary(unit = "auto")
	})

	new_summary <- summaries$reusable
	old_summary <- summaries$legacy
	expect_length(new_summary$distribution, n)
	expect_true(all(is.finite(new_summary$distribution)))
	expect_identical(new_summary$distribution, old_summary$distribution)
	expect_true(all(is.finite(c(new_summary$estimate, new_summary$bias, new_summary$std_error))))
	expect_identical(new_summary, old_summary)
	expect_null(instances$reusable$.__enclos_env__$private$cached_values$procedure_failure_reason$jackknife)
	expect_null(instances$legacy$.__enclos_env__$private$cached_values$procedure_failure_reason$jackknife)
	for (method in c(
		"compute_jackknife_estimate",
		"compute_jackknife_std_error",
		"compute_jackknife_wald_two_sided_pval"
	)) {
		expect_identical(instances$reusable[[method]](), instances$legacy[[method]](), info = method)
	}
})

test_that("ZOIB reusable jackknife skips futile full-matrix refits after a failed direct fit (TODO-1 option (a))", {
	# On the exact diagnosed tuning seed 8 of 50 direct leave-one-out fits are
	# non-finite. The ordinary fallback used to refit the identical failed
	# p-column matrix twice before dropping a column (24 extra native calls).
	# The reusable route now skips those two deterministic repeats, so it must
	# make no more native calls than the forced-legacy route while returning
	# bit-identical draws. Call COUNTS are the metric (wall clock is host-noisy).
	ns <- asNamespace("EDI")
	# The diagnosed failures need the pre-v1.0.6-TODO-204 tuning fixture: its
	# noise-free proportion response (logit(y) exactly linear in w, x and z) is
	# what makes 8 direct fits fail. The shared fixture now adds noise, so this
	# test rebuilds the old recipe locally (same seed, same assignment draws).
	design <- get("inference_migration_with_seed", envir = ns)(20264492L, {
		n <- 50L
		x <- data.frame(x = seq(-1.1, 1.1, length.out = n), z = rep(c(0L, 1L, 1L, 0L), length.out = n))
		des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
		get("inference_migration_add_subjects", envir = ns)(des, x)
		w01 <- as.integer(des$.__enclos_env__$private$w == 1L)
		linpred <- -0.2 + 0.55 * w01 + 0.25 * x$x - 0.15 * x$z
		get("add_all_subject_responses_seq", envir = ns)(des, pmin(0.95, pmax(0.05, plogis(linpred))))
		des
	})
	zoib_generator <- get("InferencePropZeroOneInflatedBetaRegr", envir = ns)
	LegacyZOIB <- R6::R6Class(
		"LegacyZOIBCallCountReference",
		inherit = zoib_generator,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)
	# The 8 failed fits come from x and z being exact predictors of logit(y)
	# on this noise-free design. Since v1.0.6-TODO-158 the constructor drops
	# them, which removes the failures, so this test stubs the detector to
	# keep the diagnosed covariates and still reach the fallback it guards.
	orig_detect <- get("edi_find_perfect_predictors", envir = ns)
	unlockBinding("edi_find_perfect_predictors", ns)
	assign("edi_find_perfect_predictors", function(targets, X, w) {
		list(drop = integer(0), scales = character(0))
	}, envir = ns)
	lockBinding("edi_find_perfect_predictors", ns)
	on.exit({
		unlockBinding("edi_find_perfect_predictors", ns)
		assign("edi_find_perfect_predictors", orig_detect, envir = ns)
		lockBinding("edi_find_perfect_predictors", ns)
	}, add = TRUE)
	orig <- get("fast_zero_one_inflated_beta_cpp", envir = ns)
	n_calls <- 0L
	unlockBinding("fast_zero_one_inflated_beta_cpp", ns)
	assign("fast_zero_one_inflated_beta_cpp", function(...) {
		n_calls <<- n_calls + 1L
		orig(...)
	}, envir = ns)
	lockBinding("fast_zero_one_inflated_beta_cpp", ns)
	on.exit({
		unlockBinding("fast_zero_one_inflated_beta_cpp", ns)
		assign("fast_zero_one_inflated_beta_cpp", orig, envir = ns)
		lockBinding("fast_zero_one_inflated_beta_cpp", ns)
	}, add = TRUE)
	# The full fit on this deliberately noise-free design drops z for
	# (quasi-)separation (edi_covariate_dropped_warning); that is the diagnosed
	# pathology, not a test failure.
	measure <- function(generator) suppressWarnings(classes = "edi_covariate_dropped_warning", {
		inf <- generator$new(design, verbose = FALSE)
		inf$num_cores <- 1L
		n_calls <<- 0L
		summary <- inf$.__enclos_env__$private$compute_jackknife_summary(unit = "auto")
		list(summary = summary, calls = n_calls, priv = inf$.__enclos_env__$private)
	})
	reusable <- measure(zoib_generator)
	legacy <- measure(LegacyZOIB)
	expect_identical(reusable$summary$distribution, legacy$summary$distribution)
	expect_identical(reusable$summary, legacy$summary)
	# Non-vacuity: the legacy route must have hit failed direct fits (more
	# than one native call per fold plus the full fit).
	expect_gt(legacy$calls, 51L)
	expect_lte(reusable$calls, legacy$calls)
	# The skip flag is scoped to the fallback and must not leak.
	expect_null(reusable$priv$zoib_skip_full_fit_ncol)
})
