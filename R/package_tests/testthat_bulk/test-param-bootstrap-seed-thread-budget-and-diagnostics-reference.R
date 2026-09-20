library(testthat)
library(EDI)

# InferenceParamBootstrap's private execution-context helpers:
# use_deterministic_param_bootstrap(), with_param_bootstrap_seed() (seeded,
# RNG-kind-pinned, state-restoring evaluation), with_param_bootstrap_thread_budget()
# (temporary thread override, restored on exit) and
# summarize_param_bootstrap_diagnostics() (per-reason counts / proportions).
# None had a direct test reference. The sibling simulator/result-helper file
# covers the simulation and single-replicate helpers.

pb_ctx <- function(seed = NULL, n = 40L, data_seed = 2L) {
	set.seed(data_seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$seed <- seed
	list(inf = inf, priv = priv)
}

test_that("deterministic mode follows a finite seed", {
	expect_false(pb_ctx(NULL)$priv$use_deterministic_param_bootstrap())
	expect_true(pb_ctx(7L)$priv$use_deterministic_param_bootstrap())
	expect_false(pb_ctx(NA_real_)$priv$use_deterministic_param_bootstrap())
	expect_false(pb_ctx(Inf)$priv$use_deterministic_param_bootstrap())
})

test_that("seeded evaluation reproduces set.seed draws under the pinned Mersenne-Twister kinds", {
	p <- pb_ctx()$priv
	a <- p$with_param_bootstrap_seed(123L, c(runif(3), rnorm(2), sample(10, 3)))
	old <- RNGkind()
	on.exit(do.call(RNGkind, as.list(old)), add = TRUE)
	RNGkind(kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
	set.seed(123L)
	b <- c(runif(3), rnorm(2), sample(10, 3))
	expect_equal(a, b)
	# Repeating gives identical results; a different seed differs.
	expect_equal(p$with_param_bootstrap_seed(123L, c(runif(3), rnorm(2), sample(10, 3))), a)
	expect_false(identical(p$with_param_bootstrap_seed(124L, runif(3)), a[1:3]))
})

test_that("seeded evaluation restores the caller's RNG kind and stream, including when none existed", {
	p <- pb_ctx()$priv
	old <- RNGkind()
	on.exit(do.call(RNGkind, as.list(old)), add = TRUE)

	RNGkind(kind = "Wichmann-Hill", normal.kind = "Box-Muller", sample.kind = "Rejection")
	set.seed(5)
	before_seed <- .Random.seed
	kind_before <- RNGkind()
	p$with_param_bootstrap_seed(99L, runif(4))
	expect_identical(RNGkind(), kind_before)
	expect_identical(.Random.seed, before_seed)

	# Non-finite / NULL seeds evaluate the expression unchanged (no reseeding).
	set.seed(6)
	expected <- { set.seed(6); runif(2) }
	set.seed(6)
	expect_equal(p$with_param_bootstrap_seed(NULL, runif(2)), expected)
	set.seed(6)
	expect_equal(p$with_param_bootstrap_seed(NA_real_, runif(2)), expected)

	# With no pre-existing stream, the helper leaves none behind.
	if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
	p$with_param_bootstrap_seed(3L, runif(1))
	expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
})

test_that("the thread budget override is visible inside and restored after evaluation, even on error", {
	p <- pb_ctx()$priv
	edi_env <- asNamespace("EDI")$edi_env
	prev <- edi_env$num_cores_override
	seen <- p$with_param_bootstrap_thread_budget(3L, get("num_cores_override", envir = edi_env))
	expect_equal(seen, 3L)
	expect_identical(edi_env$num_cores_override, prev)

	# Budgets below one are raised to one, and only the first element is used.
	expect_equal(p$with_param_bootstrap_thread_budget(0L, get("num_cores_override", envir = edi_env)), 1L)
	expect_equal(p$with_param_bootstrap_thread_budget(c(2L, 5L), get("num_cores_override", envir = edi_env)), 2L)

	expect_error(p$with_param_bootstrap_thread_budget(4L, stop("inside")), "inside")
	expect_identical(edi_env$num_cores_override, prev)
	expect_equal(p$with_param_bootstrap_thread_budget(2L, "value"), "value")
})

test_that("diagnostics summarize counts, proportions and attempts by failure reason", {
	p <- pb_ctx()$priv
	ok <- function(lr, attempts = 1L) list(success = TRUE, lr = lr, reason = "success", attempts = attempts)
	bad <- function(reason, attempts = 2L) list(success = FALSE, lr = NA_real_, reason = reason, attempts = attempts)
	results <- list(
		ok(1.2), ok(3.4, 2L), bad("full_refit_failure"), bad("null_refit_failure", 3L),
		bad("simulated_data_failure"), bad("non_finite_lr"), bad("something_new"), bad("full_refit_failure")
	)
	d <- p$summarize_param_bootstrap_diagnostics(results, B = 8, min_number_usable_samples = 5L,
		max_attempts_per_replicate = 3L, used_reusable_worker = TRUE, used_deterministic_mode = TRUE)

	expect_equal(c(d$B, d$n_success, d$n_failure), c(8L, 2L, 6L))
	expect_equal(d$success_fraction, 2 / 8)
	expect_equal(d$reason_counts$success, 2L)
	expect_equal(d$reason_counts$full_refit_failure, 2L)
	expect_equal(d$reason_counts$null_refit_failure, 1L)
	expect_equal(d$reason_counts$simulated_data_failure, 1L)
	expect_equal(d$reason_counts$non_finite_lr, 1L)
	expect_equal(d$reason_counts$extreme_lr, 0L)
	expect_equal(d$reason_counts$unknown_failure, 1L)                  # unrecognized reasons are bucketed
	expect_equal(sum(unlist(d$reason_counts)), 8L)
	expect_equal(names(d$reason_counts), c("success", "simulated_data_failure", "full_refit_failure",
		"null_refit_failure", "non_finite_lr", "extreme_lr", "unknown_failure"))
	expect_equal(d$prop_full_refit_failure, 2 / 8)
	expect_equal(d$prop_null_refit_failure, 1 / 8)
	expect_equal(d$prop_simulated_data_failure, 1 / 8)
	expect_equal(d$prop_non_finite_lr, 1 / 8)
	expect_equal(d$mean_attempts, mean(c(1, 2, 2, 3, 2, 2, 2, 2)))
	expect_true(d$used_reusable_worker && d$used_deterministic_mode)
	expect_equal(c(d$min_number_usable_samples, d$max_attempts_per_replicate), c(5L, 3L))
	expect_length(d$replicate_results, 8L)
})

test_that("diagnostics tolerate empty and malformed replicate lists", {
	p <- pb_ctx()$priv
	d0 <- p$summarize_param_bootstrap_diagnostics(NULL, B = 5, min_number_usable_samples = 2L,
		max_attempts_per_replicate = 1L, used_reusable_worker = FALSE)
	expect_equal(c(d0$n_success, d0$n_failure), c(0L, 0L))
	expect_true(is.nan(d0$success_fraction))
	expect_equal(d0$prop_full_refit_failure, 0)
	expect_false(d0$used_deterministic_mode)

	d1 <- p$summarize_param_bootstrap_diagnostics(list(list(), list(lr = 2, attempts = 1L)), B = 2,
		min_number_usable_samples = 1L, max_attempts_per_replicate = 1L, used_reusable_worker = FALSE)
	expect_equal(d1$n_success, 1L)                                     # success is judged by a finite lr
	expect_equal(d1$reason_counts$unknown_failure, 2L)                 # missing reasons -> unknown_failure
})
