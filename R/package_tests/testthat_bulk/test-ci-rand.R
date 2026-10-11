.libPaths(c("Rlib", .libPaths()))
library(testthat)
library(EDI)
library(data.table)

affine_rand_fixture <- function(seed = 2002L, n = 30L) {
	set.seed(seed)
	x <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(x)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(0.8 * w + 0.2 * x$x1 + rnorm(n, sd = 0.5))
	des
}

test_that("tier-1 affine randomization reuse exactly reproduces impute-then-permute distributions", {
	des <- affine_rand_fixture()
	classes <- list(
		InferenceAllSimpleAverageDiff, InferenceAllSimpleMeanDiffPooledVar,
		InferenceContinOLS, InferenceContinLin
	)
	for (cls in classes) {
		inf <- cls$new(des, model_formula = ~., verbose = FALSE)
		inf$num_cores <- 1L
		p <- inf$.__enclos_env__$private
		perms <- p$generate_permutations(51L)
		invisible(inf$compute_rand_two_sided_pval(r = 51L, delta = 0, show_progress = FALSE, permutations = perms))
		expect_true(p$supports_additive_delta_shift("none"), info = class(inf)[1L])
		expect_length(p$cached_values$t0s_rand, 51L)
		expect_length(p$cached_values$t0s_rand_slopes, 51L)
		for (delta in c(-1, -0.1, 0, 0.1, 1)) {
			slow <- inf$approximate_randomization_distribution_beta_hat_T(
				r = 51L, delta = delta, show_progress = FALSE, permutations = perms
			)
			affine <- p$cached_values$t0s_rand + delta * p$cached_values$t0s_rand_slopes
			expect_equal(sort(affine), sort(slow), tolerance = 1e-12,
				info = paste(class(inf)[1L], "delta", delta))
		}
	}
})

test_that("affine CI reuse performs one distribution computation and matches the uncached search", {
	des <- affine_rand_fixture(seed = 2003L, n = 24L)
	fast <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	slow <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	for (inf in list(fast, slow)) inf$num_cores <- 1L
	perms <- fast$.__enclos_env__$private$generate_permutations(99L)
	for (inf in list(fast, slow)) {
		p <- inf$.__enclos_env__$private
		unlockBinding("generate_permutations", p)
		p$generate_permutations <- function(r) perms
	}
	fast_p <- fast$.__enclos_env__$private
	n_distribution_calls <- 0L
	original_prefix <- fast_p$get_randomization_distribution_prefix
	unlockBinding("get_randomization_distribution_prefix", fast_p)
	fast_p$get_randomization_distribution_prefix <- function(...) {
		n_distribution_calls <<- n_distribution_calls + 1L
		original_prefix(...)
	}
	slow_p <- slow$.__enclos_env__$private
	unlockBinding("supports_additive_delta_shift", slow_p)
	slow_p$supports_additive_delta_shift <- function(...) FALSE
	ctrl <- list(mc_enable = FALSE, high_precision_confirm = FALSE, seed = "none")
	ci_fast <- fast$compute_rand_confidence_interval(alpha = 0.2, r = 99L, pval_epsilon = 0.02, show_progress = FALSE, ci_search_control = ctrl)
	ci_slow <- slow$compute_rand_confidence_interval(alpha = 0.2, r = 99L, pval_epsilon = 0.02, show_progress = FALSE, ci_search_control = ctrl)
	expect_identical(n_distribution_calls, 1L)
	expect_equal(as.numeric(ci_fast), as.numeric(ci_slow), tolerance = 0.02)
})

test_that("affine CI refreshes a complete cache from different permutations", {
	des <- affine_rand_fixture(seed = 2005L, n = 24L)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	stale_perms <- p$generate_permutations(99L)
	invisible(inf$compute_rand_two_sided_pval(
		r = 99L, delta = 0, show_progress = FALSE, permutations = stale_perms
	))
	ci_perms <- stale_perms[, rev(seq_len(ncol(stale_perms))), drop = FALSE]
	expect_false(identical(p$stable_signature(stale_perms), p$stable_signature(ci_perms)))

	unlockBinding("generate_permutations", p)
	p$generate_permutations <- function(r) ci_perms
	n_distribution_calls <- 0L
	original_prefix <- p$get_randomization_distribution_prefix
	unlockBinding("get_randomization_distribution_prefix", p)
	p$get_randomization_distribution_prefix <- function(...) {
		n_distribution_calls <<- n_distribution_calls + 1L
		original_prefix(...)
	}
	ctrl <- list(mc_enable = FALSE, high_precision_confirm = FALSE, seed = "none")
	invisible(inf$compute_rand_confidence_interval(
		alpha = 0.2, r = 99L, pval_epsilon = 0.02, show_progress = FALSE,
		ci_search_control = ctrl
	))
	expect_identical(n_distribution_calls, 1L)
	expect_identical(
		p$cached_values$t0s_rand_permutation_signature,
		p$stable_signature(ci_perms)
	)
})

test_that("non-affine estimators and an early-stopped MC prefix never populate the affine cache", {
	des <- affine_rand_fixture(seed = 2004L, n = 30L)
	wilcox <- InferenceAllSimpleWilcox$new(des, verbose = FALSE)
	expect_false(wilcox$.__enclos_env__$private$supports_additive_delta_shift("none"))
	expect_false(isTRUE(EDI:::get_inference_class_metadata("InferenceAllSimpleWilcox")$supports_additive_delta_shift))

	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$randomization_mc_control <- list(
		mc_enable = TRUE, mc_batch_size = 25L, mc_min_draws = 50L,
		mc_conf_level = 0.90, mc_stop_threshold = 0.5
	)
	invisible(inf$compute_rand_two_sided_pval(r = 199L, delta = 0, show_progress = FALSE))
	expect_null(p$cached_values$t0s_rand)
})

make_exact_fisher_2x2 <- function(w, y) {
	matrix(
		c(
			sum(w == 1L & y == 1L),
			sum(w == 1L & y == 0L),
			sum(w == 0L & y == 1L),
			sum(w == 0L & y == 0L)
		),
		nrow = 2,
		byrow = TRUE
	)
}

format_exact_fisher_tables <- function(table_list) {
	table_list <- Filter(function(tab) sum(tab[1, ]) > 0L && sum(tab[2, ]) > 0L, table_list)
	if (length(table_list) == 1L) {
		return(table_list[[1]])
	}
	table_array <- array(0, dim = c(2L, 2L, length(table_list)))
	for (k in seq_along(table_list)) {
		table_array[, , k] <- table_list[[k]]
	}
	table_array
}

build_blocking_exact_fisher_tables <- function(des) {
	des_priv <- des$.__enclos_env__$private
	w <- des_priv$w
	y <- des_priv$y
	strata_cols <- des_priv$strata_cols
	if (is.null(strata_cols) || length(strata_cols) == 0L) {
		return(make_exact_fisher_2x2(w, y))
	}
	Xraw <- des_priv$Xraw
	strata_keys <- vapply(seq_along(w), function(i) {
		paste(vapply(strata_cols, function(col) {
			val <- Xraw[i, ][[col]]
			if (is.na(val)) "NA" else as.character(val)
		}, character(1)), collapse = "|")
	}, character(1))
	format_exact_fisher_tables(lapply(split(seq_along(w), strata_keys), function(idx) {
		make_exact_fisher_2x2(w[idx], y[idx])
	}))
}

build_kk_exact_fisher_tables <- function(des) {
	des_priv <- des$.__enclos_env__$private
	w <- des_priv$w
	y <- des_priv$y
	m <- as.integer(des_priv$m)
	m[is.na(m)] <- 0L
	table_list <- lapply(sort(unique(m[m > 0L])), function(match_id) {
		idx <- which(m == match_id)
		make_exact_fisher_2x2(w[idx], y[idx])
	})
	reservoir_idx <- which(m == 0L)
	if (length(reservoir_idx) > 0L) {
		table_list[[length(table_list) + 1L]] <- make_exact_fisher_2x2(w[reservoir_idx], y[reservoir_idx])
	}
	format_exact_fisher_tables(table_list)
}

test_that("compute_rand_confidence_interval works for continuous response", {
	set.seed(123)
	n <- 40
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = TRUE)
	for (i in 1:n) {
	des$add_one_subject_to_experiment_and_assign(data.table(x1 = rnorm(1), x2 = rnorm(1)))
	}
	# Add treatment effect of 1.0
	treatment <- des$.__enclos_env__$private$w
	y <- rnorm(n) + treatment * 1.0
	add_all_subject_responses_seq(des, y)

	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = TRUE)

	# Compute randomization CI
	# Using small nsim for speed in tests
	ci <- inf$compute_rand_confidence_interval(alpha = 0.05, r = 51, pval_epsilon = 0.05)

	expect_equal(length(ci), 2)
	expect_true(ci[1] < ci[2])
	# The estimate should be within the CI
	est <- inf$compute_estimate()
	expect_true(est >= ci[1] && est <= ci[2])

	message("Continuous Rand CI: [", ci[1], ", ", ci[2], "] Est: ", est)
})

test_that("compute_rand_confidence_interval works for proportion response", {
	set.seed(123)
	n <- 100
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	for (i in 1:n) {
	des$add_one_subject_to_experiment_and_assign(data.table(x1 = rnorm(1)))
	}
	treatment <- des$.__enclos_env__$private$w
	# Simulate proportions
	mu <- plogis(-0.5 + treatment * 1.0)
	y <- rbeta(n, shape1 = mu * 10, shape2 = (1 - mu) * 10)
	add_all_subject_responses_seq(des, y)

	inf <- InferencePropBetaRegr$new(des, verbose = FALSE)

	# Compute randomization CI
	ci <- inf$compute_rand_confidence_interval(alpha = 0.05, r = 51, pval_epsilon = 0.05)

	expect_equal(length(ci), 2)
	expect_true(ci[1] < ci[2])
	expect_true(all(is.finite(ci)))

	est <- inf$compute_estimate()
	expect_true(est >= ci[1] && est <= ci[2])

	message("Proportion Rand CI: [", ci[1], ", ", ci[2], "] Est: ", est)
})

test_that("proportion quantile randomization CI shifts on the logit scale once", {
	skip_if_not_installed("quantreg")
	set.seed(124)
	n <- 48
	des <- DesignSeqOneByOneiBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	x <- rnorm(n)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.table(x1 = x[i]))
	}
	w <- des$.__enclos_env__$private$w
	mu <- plogis(-0.25 + 0.7 * w + 0.2 * x)
	y <- rbeta(n, shape1 = mu * 12, shape2 = (1 - mu) * 12)
	add_all_subject_responses_seq(des, y)

	inf <- InferencePropQuantileRegr$new(des, model_formula = ~ x1, verbose = FALSE)
	ci <- inf$compute_rand_confidence_interval(
		alpha = 0.10,
		r = 31,
		pval_epsilon = 0.10,
		show_progress = FALSE,
		ci_search_control = list(max_expansions = 2L, mc_enable = FALSE)
	)

	expect_equal(length(ci), 2)
	expect_true(all(is.finite(ci)))
	expect_true(ci[1] < ci[2])
})

test_that("compute_rand_confidence_interval works for survival response (uncensored)", {
	set.seed(123)
	n <- 50
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in 1:n) {
	des$add_one_subject_to_experiment_and_assign(data.table(x1 = rnorm(1)))
	}
	treatment <- des$.__enclos_env__$private$w
	# Simulate survival times (log-normal)
	y <- exp(1.0 + treatment * 0.8 + rnorm(n, 0, 0.5))
	add_all_subject_responses_seq(des, y, deads = rep(1, n)) # All events, no censoring

	inf <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)

	# Compute randomization CI
	ci <- inf$compute_rand_confidence_interval(alpha = 0.05, r = 51, pval_epsilon = 0.05)

	expect_equal(length(ci), 2)
	expect_true(ci[1] < ci[2])

	est <- inf$compute_estimate()
	# Both quantities are log-time-ratio effects; a valid interval need not be
	# positive, but must bracket the estimate on that same scale.
	expect_true(est >= ci[1] && est <= ci[2])

	message("Survival Rand CI: [", ci[1], ", ", ci[2], "] Est: ", est)
})

test_that("compute_rand_confidence_interval rejects ordinal model-coefficient estimands (cumulative logit)", {
	# InferenceOrdinalPropOddsRegr is one of the classes in
	# EDI_ORDINAL_MODEL_COEFFICIENT_INFERENCE_CLASSES
	# (inference_class_registry.R): its treatment effect is a model
	# coefficient, and generic randomization-CI inversion imposes a nonzero
	# null by shifting the observed ordinal category codes by `delta`, which
	# is not a sharp-null transformation for this estimand. This is a
	# deliberate statistical-correctness gate (see
	# test-ordinal-model-coefficient-randomization-ci-disabled.R for the
	# general contract across every class in that list), not a bug -- this
	# test previously expected a (statistically invalid) CI to be returned;
	# it now pins the documented rejection instead.
	set.seed(456)
	n <- 40
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.table(x1 = rnorm(1)))
	}
	treatment <- des$.__enclos_env__$private$w
	score <- rnorm(n, mean = treatment * 0.5)
	y <- 1L + (score > 0) + (score > 1)
	add_all_subject_responses_seq(des, y)

	inf <- InferenceOrdinalPropOddsRegr$new(des, verbose = FALSE)

	expect_error(
		inf$compute_rand_confidence_interval(alpha = 0.05, r = 51, pval_epsilon = 0.05, show_progress = FALSE),
		"not implemented for ordinal model-coefficient estimands"
	)
})

test_that("compute_rand_confidence_interval throws error for unsupported types", {
	n <- 20
	des_incid <- DesignSeqOneByOneEfron$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in 1:n) des_incid$add_one_subject_to_experiment_and_assign(data.table(x=1))
	add_all_subject_responses_seq(des_incid, rbinom(n, 1, 0.5))
	inf_incid <- InferenceIncidLogRegr$new(des_incid)
	# Randomization CIs are temporarily disabled for every incidence
	# response (2026-08-27, see incidence_randomization_cis.md) -- this now
	# errors unconditionally for incidence, not just for the
	# non-Zhang-eligible design this test originally targeted.
	expect_error(inf_incid$compute_rand_confidence_interval(), "temporarily disabled for incidence responses")

	des_count <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	for (i in 1:n) des_count$add_one_subject_to_experiment_and_assign(data.table(x=1))
	add_all_subject_responses_seq(des_count, rpois(n, 5))
	inf_count <- InferenceCountNegBin$new(des_count)
	ci_count <- inf_count$compute_rand_confidence_interval(alpha = 0.05, r = 51, pval_epsilon = 0.05)
	expect_equal(length(ci_count), 2)
	expect_true(ci_count[1] < ci_count[2])
	expect_true(all(is.finite(ci_count)))
})

test_that("FixedRerandomization incidence randomization uses design draws, not Zhang", {
	set.seed(123)
	n <- 20
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignFixedRerandomization$new(
		n = n,
		response_type = "incidence",
		obj_val_cutoff = 100,
		verbose = FALSE
	)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))

	old_asserts <- EDI:::should_run_asserts()
	on.exit(toggle_asserts(old_asserts), add = TRUE)
	toggle_asserts(TRUE)

	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	expect_no_error(p <- inf$compute_rand_two_sided_pval(r = 11, show_progress = FALSE))
	expect_true(is.finite(p))
	expect_error(
		inf$compute_rand_two_sided_pval(r = 11, type = "Zhang", show_progress = FALSE),
		"Randomization type dispatch"
	)
})

test_that("Zhang incidence inference is available through the exact API; randomization CI is blocked", {
	# Randomization CIs are temporarily disabled for every incidence
	# response (2026-08-27, see incidence_randomization_cis.md): the Zhang
	# exact-combined CI `compute_rand_confidence_interval()` used to
	# dispatch to is always on the log-odds-ratio scale and was being
	# reported verbatim regardless of the calling class's own estimand --
	# this test used to assert `compute_rand_confidence_interval()` and
	# `compute_exact_confidence_interval()` agree, which was really just
	# confirming the bug's own self-consistency for a log-odds-ratio class,
	# not that the CI was correct for classes on other scales. The
	# `compute_rand_two_sided_pval()`/`compute_exact_two_sided_pval_for_
	# treatment_effect()` p-value agreement is untouched by the stopgap
	# (scale-invariant at the sharp null, see that plan's own root-cause
	# writeup) and still tested here directly against the exact API.
	set.seed(321)
	n <- 24
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.table(x1 = rnorm(1), x2 = rnorm(1)))
	}
	treatment <- des$.__enclos_env__$private$w
	prob <- plogis(-0.2 + 0.8 * treatment)
	add_all_subject_responses_seq(des, rbinom(n, 1, prob))

	inf_rand <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf_serial <- InferenceIncidExactZhang$new(des, verbose = FALSE)
	inf_parallel <- InferenceIncidExactZhang$new(des, verbose = FALSE)

	expect_error(
		inf_rand$compute_rand_confidence_interval(alpha = 0.10, pval_epsilon = 0.01, show_progress = FALSE),
		"temporarily disabled for incidence responses"
	)
	ci_exact_serial <- inf_serial$compute_exact_confidence_interval(alpha = 0.10, pval_epsilon = 0.01)
	ci_exact_parallel <- inf_parallel$compute_exact_confidence_interval(alpha = 0.10, pval_epsilon = 0.01)
	p_rand <- inf_rand$compute_rand_two_sided_pval(delta = 0)
	p_exact <- inf_serial$compute_exact_two_sided_pval_for_treatment_effect(delta = 0)

	expect_length(ci_exact_serial, 2)
	expect_true(all(is.finite(ci_exact_serial)))
	expect_equal(ci_exact_parallel, ci_exact_serial, tolerance = 1e-8)
	expect_true(is.finite(p_rand))
	expect_equal(p_exact, p_rand, tolerance = 1e-12)
})

test_that("Fisher exact inference matches fisher.test for iBCRD incidence", {
	set.seed(2026)
	n <- 20
	des <- DesignSeqOneByOneiBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.table(x1 = rnorm(1)))
	}
	w <- des$.__enclos_env__$private$w
	y <- rbinom(n, 1, plogis(-0.3 + 0.7 * w))
	add_all_subject_responses_seq(des, y)

	ref <- stats::fisher.test(make_exact_fisher_2x2(w, y), conf.level = 0.90)
	inf_exact <- InferenceIncidExactFisher$new(des, verbose = FALSE)

	ci_exact <- inf_exact$compute_exact_confidence_interval(alpha = 0.10)
	p_exact <- inf_exact$compute_exact_two_sided_pval_for_treatment_effect(delta = 0)

	expect_equal(inf_exact$compute_estimate(), log(as.numeric(ref$estimate)), tolerance = 1e-12)
	expect_equal(unname(ci_exact), log(as.numeric(ref$conf.int)), tolerance = 1e-12)
	expect_equal(p_exact, ref$p.value, tolerance = 1e-12)
})

test_that("Fisher exact inference matches mantelhaen.test for blocking incidence", {
	set.seed(2027)
	n <- 16
	x_dat <- data.table(site = rep(c("A", "B"), each = n / 2), x1 = rnorm(n))
	des <- DesignSeqOneByOneSPBR$new(
		strata_cols = "site",
		block_size = 4,
		n = n,
		response_type = "incidence",
		verbose = FALSE
	)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(x_dat[i, ])
	}
	w <- des$.__enclos_env__$private$w
	y <- rbinom(n, 1, plogis(-0.5 + 0.9 * w + 0.4 * (x_dat$site == "B")))
	add_all_subject_responses_seq(des, y)

	ref_tables <- build_blocking_exact_fisher_tables(des)
	ref <- stats::mantelhaen.test(ref_tables, exact = TRUE, conf.level = 0.95)
	inf_exact <- InferenceIncidExactFisher$new(des, verbose = FALSE)

	ci_exact <- inf_exact$compute_exact_confidence_interval(alpha = 0.05)
	p_exact <- inf_exact$compute_exact_two_sided_pval_for_treatment_effect(delta = 0)

	expect_equal(inf_exact$compute_estimate(), log(as.numeric(ref$estimate)), tolerance = 1e-12)
	expect_equal(unname(ci_exact), log(as.numeric(ref$conf.int)), tolerance = 1e-12)
	expect_equal(p_exact, ref$p.value, tolerance = 1e-12)
	expect_error(
		inf_exact$compute_exact_two_sided_pval_for_treatment_effect(delta = 0.2),
		"Stratified Fisher exact inference only supports delta = 0"
	)
})

test_that("Fisher exact inference matches mantelhaen.test for KK incidence", {
	set.seed(2028)
	x_dat <- data.table(x1 = c(-3, 3, -3.01, 3.01, 0, 0.01))
	des <- DesignSeqOneByOneKK14$new(
		n = nrow(x_dat),
		response_type = "incidence",
		t_0_pct = 0.34,
		lambda = 0.99,
		verbose = FALSE
	)
	for (i in seq_len(nrow(x_dat))) {
		des$add_one_subject_to_experiment_and_assign(x_dat[i, ])
	}
	m <- des$.__enclos_env__$private$m
	expect_true(any(m > 0L))

	w <- des$.__enclos_env__$private$w
	y <- c(1L, 0L, 0L, 1L, 1L, 0L)
	add_all_subject_responses_seq(des, y)

	ref_tables <- build_kk_exact_fisher_tables(des)
	ref <- stats::mantelhaen.test(ref_tables, exact = TRUE, conf.level = 0.95)
	inf_exact <- InferenceIncidExactFisher$new(des, verbose = FALSE)

	ci_exact <- inf_exact$compute_exact_confidence_interval(alpha = 0.05)
	p_exact <- inf_exact$compute_exact_two_sided_pval_for_treatment_effect(delta = 0)

	expect_equal(inf_exact$compute_estimate(), log(as.numeric(ref$estimate)), tolerance = 1e-12)
	expect_equal(unname(ci_exact), log(as.numeric(ref$conf.int)), tolerance = 1e-12)
	expect_equal(p_exact, ref$p.value, tolerance = 1e-12)
})

test_that("Fisher exact inference is rejected for unsupported incidence designs", {
	n <- 12
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.table(x1 = i))
	}
	add_all_subject_responses_seq(des, rep(c(0L, 1L), length.out = n))

	# Design-compatibility validation now runs at construction time (fail
	# fast), not lazily at the first exact-inference call.
	expect_error(
		InferenceIncidExactFisher$new(des, verbose = FALSE),
		"Fisher exact inference requires iBCRD, blocking, or matching designs"
	)
})
