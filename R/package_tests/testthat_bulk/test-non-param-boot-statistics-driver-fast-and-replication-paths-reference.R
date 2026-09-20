library(testthat)
library(EDI)

# InferenceNonParamBootstrap$approximate_bootstrap_statistics_beta_hat_T(): the
# fast path (no SE, no smoothing: delegates to the distribution method), the
# per-replicate path (statistics matrix, na.rm filtering, require_se filtering,
# empty results), argument validation and operation-flag cleanup. The
# per-replicate statistics are stubbed so the driver's own logic is exact.

np_fx <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, p = inf$.__enclos_env__$private, n = n)
}

stub_priv <- function(p, name, fn) { unlockBinding(name, p); assign(name, fn, envir = p) }

test_that("fast path returns the bootstrap distribution with NA SEs, dropping non-finite draws when na.rm", {
	f <- np_fx()
	set.seed(5); ref <- f$inf$approximate_bootstrap_distribution_beta_hat_T(B = 30L, show_progress = FALSE)
	set.seed(5); out <- f$p$approximate_bootstrap_statistics_beta_hat_T(B = 30L, show_progress = FALSE)
	expect_equal(names(out), c("theta", "se"))
	expect_equal(out$theta, ref[is.finite(ref)])
	expect_true(all(is.na(out$se)))
	expect_equal(length(out$se), length(out$theta))
	# na.rm = FALSE keeps whatever the distribution produced.
	set.seed(5); keep <- f$p$approximate_bootstrap_statistics_beta_hat_T(B = 30L, show_progress = FALSE, na.rm = FALSE)
	expect_equal(keep$theta, ref)
	expect_null(f$p$active_resampling_operation)                       # flag is cleared on exit
})

test_that("fast path with an empty distribution returns empty theta and se", {
	f <- np_fx()
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bootstrap_distribution_beta_hat_T <- function(B, show_progress = FALSE) c(NA_real_, Inf)
	out <- f$p$approximate_bootstrap_statistics_beta_hat_T(B = 5L, show_progress = FALSE)
	expect_identical(out, list(theta = numeric(0), se = numeric(0)))
})

replication_stub <- function(f, rows) {
	i <- 0L
	seen <- list()
	stub_priv(f$p, "bootstrap_sample_indices", function(n) list(i_b = seq_len(n)))
	stub_priv(f$p, "bootstrap_replication_stats", function(idx, smooth = FALSE, require_se = FALSE) {
		i <<- i + 1L
		seen[[i]] <<- list(smooth = smooth, require_se = require_se)
		rows[[i]]
	})
	function() seen
}

test_that("per-replicate path assembles a B x 2 matrix, forwarding smooth / require_se, and filters non-finite thetas", {
	f <- np_fx()
	rows <- list(c(1, 0.1), c(NA, 0.2), c(3, NA), c(Inf, 0.4), c(5, 0.5))
	seen <- replication_stub(f, rows)
	out <- f$p$approximate_bootstrap_statistics_beta_hat_T(B = 5L, show_progress = FALSE, smooth = TRUE)
	expect_equal(out$theta, c(1, 3, 5))
	expect_equal(out$se, c(0.1, NA, 0.5))
	expect_true(all(vapply(seen(), function(s) isTRUE(s$smooth) && !isTRUE(s$require_se), logical(1))))
	expect_length(seen(), 5L)
	g <- np_fx(); seen_g <- replication_stub(g, rows)
	keep <- g$p$approximate_bootstrap_statistics_beta_hat_T(B = 5L, show_progress = FALSE, na.rm = FALSE, smooth = TRUE)
	expect_equal(keep$theta, c(1, NA, 3, Inf, 5))
	expect_equal(keep$se, c(0.1, 0.2, NA, 0.4, 0.5))
})

test_that("require_se also drops draws whose SE is missing or non-positive", {
	f <- np_fx()
	rows <- list(c(1, 0.1), c(2, NA), c(3, 0), c(4, -1), c(5, 0.5), c(NA, 0.3))
	seen <- replication_stub(f, rows)
	out <- f$p$approximate_bootstrap_statistics_beta_hat_T(B = 6L, show_progress = FALSE, require_se = TRUE)
	expect_equal(out$theta, c(1, 5))
	expect_equal(out$se, c(0.1, 0.5))
	expect_true(all(vapply(seen(), function(s) isTRUE(s$require_se), logical(1))))
	g <- np_fx(); replication_stub(g, list(c(1, NA), c(2, 0)))
	expect_identical(g$p$approximate_bootstrap_statistics_beta_hat_T(B = 2L, show_progress = FALSE, require_se = TRUE),
		list(theta = numeric(0), se = numeric(0)))
})

test_that("B and require_se are validated; the operation flag is set during the run and cleared afterwards", {
	f <- np_fx()
	expect_error(f$p$approximate_bootstrap_statistics_beta_hat_T(B = 0L, show_progress = FALSE))
	expect_error(f$p$approximate_bootstrap_statistics_beta_hat_T(B = 3L, show_progress = FALSE, require_se = "yes"))
	flag <- NULL
	stub_priv(f$p, "bootstrap_sample_indices", function(n) list(i_b = seq_len(n)))
	stub_priv(f$p, "bootstrap_replication_stats", function(idx, smooth = FALSE, require_se = FALSE) {
		flag <<- f$p$active_resampling_operation; c(1, 0.1)
	})
	f$p$approximate_bootstrap_statistics_beta_hat_T(B = 2L, show_progress = FALSE, smooth = TRUE)
	expect_equal(flag, "non_param_boot")
	expect_null(f$p$active_resampling_operation)
})

test_that("a progress bar is only created for B > 1 and does not change results", {
	f <- np_fx()
	replication_stub(f, list(c(1, 0.1), c(2, 0.2), c(3, 0.3)))
	out <- suppressMessages(capture.output(res <- f$p$approximate_bootstrap_statistics_beta_hat_T(B = 3L, show_progress = TRUE, smooth = TRUE)))
	expect_equal(res$theta, c(1, 2, 3))
	expect_true(any(nzchar(out)))                                        # txtProgressBar wrote to stdout
})
