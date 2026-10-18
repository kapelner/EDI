library(testthat)
library(EDI)

# 128 columns * 160 subjects exceeds both should_parallelize_replicates
# gates (128 replicates and 20,000 total work), while staying a small shard.
make_threshold_resampling_fixture <- function() {
	set.seed(20260916)
	n <- 160L
	B <- 128L
	list(
		X = cbind(x = rnorm(n)), y = rnorm(n),
		y_ord = sample(1:5, n, replace = TRUE),
		w = rep(0:1, n / 2L),
		w_mat = replicate(B, sample(rep(0:1, n / 2L))),
		indices = replicate(B, sample.int(n, n, replace = TRUE))
	)
}

threshold_ridit_reference <- function(y, w, reference) {
	# Mirrors inference_ordinal_ridit.R's documented orientation: with a
	# control or pooled reference, the TARGET is the treatment arm, evaluated
	# against that reference's ridit map (treated mean ridit - 0.5). With a
	# treatment reference, the roles swap -- the TARGET is the control arm,
	# evaluated against the treatment arm's own ridit map, and the result is
	# negated (0.5 - control mean ridit) -- "essential because the reference
	# group's own mean ridit is 0.5 by construction" (a treatment-vs-itself
	# self-comparison, which this function previously computed by mistake,
	# always trivially ~0 instead of the documented mirror comparison).
	treatment_reference <- identical(reference, "treatment")
	target <- if (treatment_reference) y[w == 0L] else y[w == 1L]
	ref <- switch(reference, pooled = y, control = y[w == 0L], treatment = y[w == 1L])
	if (!length(target) || !length(ref)) return(NA_real_)
	levels <- sort(unique(ref))
	scores <- vapply(levels, function(z) mean(ref < z) + mean(ref == z) / 2, numeric(1))
	# The kernel interpolates scores for categories absent from the reference.
	mapped <- approx(levels, scores, xout = target, rule = 1)$y
	mapped[target < min(levels)] <- 0
	mapped[target > max(levels)] <- 1
	if (treatment_reference) 0.5 - mean(mapped) else mean(mapped) - .5
}

ols_bootstrap_fixture <- function(n = 32L, seed = 20261018L, rare_covariate = FALSE) {
	set.seed(seed)
	x <- if (rare_covariate) c(rep(0, n / 2L), rep(1, n / 2L)) else rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- 1.2 + 0.7 * w + 0.4 * x + rnorm(n, sd = 0.2)
	des$add_all_subject_responses(y)
	inf <- InferenceContinOLS$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, X = inf$.__enclos_env__$private$create_design_matrix(), y = y, w = w)
}

set_fixed_bootstrap_draws <- function(inf, draws) {
	p <- inf$.__enclos_env__$private
	unlockBinding("bootstrap_sample_indices", p)
	i <- 0L
	assign("bootstrap_sample_indices", function(n, bootstrap_type = NULL) {
		i <<- i + 1L
		draws[[i]]
	}, envir = p)
}

test_that("OLS bootstrap parallel dispatch preserves zero-based sample indices", {
	f <- make_threshold_resampling_fixture()
	indices0 <- f$indices - 1L
	expected <- vapply(seq_len(ncol(indices0)), function(b) {
		i <- f$indices[, b]
		unname(lm.fit(cbind(1, f$w[i], f$X[i, , drop = FALSE]), f$y[i])$coefficients[2])
	}, numeric(1))
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w, indices0, cores), expected, tolerance = 1e-10)
	}
	indices0[1, 1] <- -1L
	expect_true(is.na(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w, indices0, 2L)[1]))
	short <- indices0[1:40, 2:4, drop = FALSE]
	expected_short <- vapply(seq_len(ncol(short)), function(b) {
		i <- short[, b] + 1L
		unname(lm.fit(cbind(1, f$w[i], f$X[i, , drop = FALSE]), f$y[i])$coefficients[2])
	}, numeric(1))
	expect_equal(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w, short, 0L), expected_short, tolerance = 1e-10)
	expect_length(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w, indices0[, FALSE], 2L), 0L)
	expect_error(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w[-1], indices0, 1L), "length must match")
})

test_that("public OLS percentile bootstrap dispatch matches fixed-index lm.fit references", {
	f <- ols_bootstrap_fixture()
	n <- length(f$y)
	set.seed(20261019)
	draws <- lapply(seq_len(24L), function(b) {
		repeat {
			idx <- sample.int(n, n, replace = TRUE)
			if (qr(f$X[idx, , drop = FALSE])$rank == ncol(f$X)) break
		}
		list(i_b = idx, m_vec_b = NULL)
	})
	expect_true(all(vapply(draws, function(d) qr(f$X[d$i_b, , drop = FALSE])$rank == ncol(f$X), logical(1))))
	set_fixed_bootstrap_draws(f$inf, draws)
	p <- f$inf$.__enclos_env__$private
	original_hook <- p$compute_fast_non_param_bootstrap_distr
	hook_called <- FALSE
	unlockBinding("compute_fast_non_param_bootstrap_distr", p)
	assign("compute_fast_non_param_bootstrap_distr", function(boot_draws, bootstrap_type = NULL) {
		hook_called <<- TRUE
		original_hook(boot_draws, bootstrap_type)
	}, envir = p)
	ref <- vapply(draws, function(d) {
		unname(stats::lm.fit(f$X[d$i_b, , drop = FALSE], f$y[d$i_b])$coefficients[2L])
	}, numeric(1))
	# Compare the fast hook's entire distribution to an independent per-draw
	# lm.fit reference, not only the public CI endpoints derived from it.
	fast_ref <- original_hook(draws)
	expect_equal(unname(fast_ref), unname(ref), tolerance = 1e-10)
	ci <- f$inf$compute_bootstrap_confidence_interval(
		alpha = 0.2, B = length(draws), type = "percentile", show_progress = FALSE
	)
	expect_true(hook_called)
	expect_equal(unname(ci), unname(stats::quantile(ref, c(0.1, 0.9), names = FALSE, type = 8)), tolerance = 1e-8)
})

test_that("rank-deficient OLS bootstrap draws fall back to the hardened worker", {
	f <- ols_bootstrap_fixture(rare_covariate = TRUE)
	base <- which(f$X[, 3L] == 0)
	set.seed(20261020)
	draws <- lapply(seq_len(16L), function(b) {
		repeat {
			idx <- sample(base, length(f$y), replace = TRUE)
			if (any(f$w[idx] == 0L) && any(f$w[idx] == 1L)) break
		}
		list(i_b = idx, m_vec_b = NULL)
	})
	idx <- draws[[1L]]$i_b
	expect_lt(qr(f$X[idx, , drop = FALSE])$rank, ncol(f$X))
	set_fixed_bootstrap_draws(f$inf, draws)
	p <- f$inf$.__enclos_env__$private
	original_hook <- p$compute_fast_non_param_bootstrap_distr
	hook_returned_null <- FALSE
	unlockBinding("compute_fast_non_param_bootstrap_distr", p)
	assign("compute_fast_non_param_bootstrap_distr", function(boot_draws, bootstrap_type = NULL) {
		out <- original_hook(boot_draws, bootstrap_type)
		hook_returned_null <<- is.null(out)
		out
	}, envir = p)
	ref <- unname(stats::lm.fit(f$X[idx, , drop = FALSE], f$y[idx])$coefficients[2L])
	ci <- f$inf$compute_bootstrap_confidence_interval(
		alpha = 0.2, B = length(draws), type = "percentile", show_progress = FALSE
	)
	expect_true(hook_returned_null)
	expect_true(is.finite(ref))
	ref_distr <- vapply(draws, function(d) {
		unname(stats::lm.fit(f$X[d$i_b, , drop = FALSE], f$y[d$i_b])$coefficients[2L])
	}, numeric(1))
	expect_equal(unname(ci), unname(stats::quantile(ref_distr, c(0.1, 0.9), names = FALSE, type = 8)), tolerance = 1e-8)
})

test_that("debug bootstrap diagnostics bypass the OLS batch hook", {
	f <- ols_bootstrap_fixture()
	n <- length(f$y)
	set.seed(20261021)
	draws <- lapply(seq_len(5L), function(b) {
		repeat {
			idx <- sample.int(n, n, replace = TRUE)
			if (qr(f$X[idx, , drop = FALSE])$rank == ncol(f$X)) break
		}
		list(i_b = idx, m_vec_b = NULL)
	})
	set_fixed_bootstrap_draws(f$inf, draws)
	p <- f$inf$.__enclos_env__$private
	original_hook <- p$compute_fast_non_param_bootstrap_distr
	hook_called <- FALSE
	unlockBinding("compute_fast_non_param_bootstrap_distr", p)
	assign("compute_fast_non_param_bootstrap_distr", function(boot_draws, bootstrap_type = NULL) {
		hook_called <<- TRUE
		original_hook(boot_draws, bootstrap_type)
	}, envir = p)
	out <- f$inf$approximate_bootstrap_distribution_beta_hat_T(
		B = length(draws), show_progress = FALSE, debug = TRUE
	)
	expect_false(hook_called)
	expect_length(out$values, length(draws))
})

test_that("OLS batch hook declines unsupported schemes, structured designs, and malformed draws", {
	f <- ols_bootstrap_fixture()
	p <- f$inf$.__enclos_env__$private
	n <- length(f$y)
	valid_draw <- list(i_b = seq_len(n), m_vec_b = NULL)
	expect_null(p$compute_fast_non_param_bootstrap_distr(
		list(valid_draw), bootstrap_type = "within_blocks"
	))
	expect_null(p$compute_fast_non_param_bootstrap_distr(list(list(i_b = seq_len(n - 1L)))))
	expect_null(p$compute_fast_non_param_bootstrap_distr(list(list(i_b = c(0L, seq_len(n - 1L))))))

	blocked <- DesignFixedBlocking$new(
		n = n, B_target = 4L, response_type = "continuous", verbose = FALSE
	)
	unlockBinding("des_obj", p)
	assign("des_obj", blocked, envir = p)
	expect_null(p$compute_fast_non_param_bootstrap_distr(list(valid_draw)))
})

test_that("a non-finite native batch result declines to the generic fallback", {
	f <- ols_bootstrap_fixture()
	p <- f$inf$.__enclos_env__$private
	unlockBinding("y", p)
	assign("y", rep(NA_real_, length(f$y)), envir = p)
	valid_draw <- list(i_b = seq_along(f$y), m_vec_b = NULL)
	expect_null(p$compute_fast_non_param_bootstrap_distr(list(valid_draw)))
})

test_that("ridit bootstrap kernels agree with empirical reference scores above the parallel gate", {
	f <- make_threshold_resampling_fixture()
	for (reference in c("pooled", "control", "treatment")) {
		expected_boot <- vapply(seq_len(ncol(f$indices)), function(b) {
			i <- f$indices[, b]
			threshold_ridit_reference(f$y_ord[i], f$w[i], reference)
		}, numeric(1))
		expected_rand <- vapply(seq_len(ncol(f$indices)), function(b) {
			threshold_ridit_reference(f$y_ord[f$indices[, b]], f$w_mat[, b], reference)
		}, numeric(1))
		for (cores in c(1L, 2L)) {
			expect_equal(EDI:::compute_ridit_bootstrap_parallel_cpp(f$w, f$y_ord, f$indices, reference, cores), expected_boot)
			expect_equal(EDI:::compute_ridit_rand_bootstrap_parallel_cpp(f$y_ord, f$indices, f$w_mat, reference, cores), expected_rand)
		}
	}
	indices <- f$indices
	indices[1, 1] <- -1L
	expect_true(is.na(EDI:::compute_ridit_bootstrap_parallel_cpp(f$w, f$y_ord, indices, "control", 2L)[1]))
})

test_that("randomization bootstrap OLS shifts resampled noisy responses before fitting", {
	f <- make_threshold_resampling_fixture()
	noise <- matrix(sin(seq_along(f$indices)) / 10, nrow = nrow(f$indices))
	delta <- .4
	expected <- vapply(seq_len(ncol(f$indices)), function(b) {
		i <- f$indices[, b]
		w <- f$w_mat[, b]
		unname(lm.fit(cbind(1, w, f$X[i, , drop = FALSE]), f$y[i] + noise[, b] + delta * w)$coefficients[2])
	}, numeric(1))
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_rand_bootstrap_ols_parallel_cpp(f$y, f$X, f$indices, f$w_mat, delta, noise, cores), expected, tolerance = 1e-10)
	}
	degenerate_w <- cbind(rep(0L, length(f$y)), rep(1L, length(f$y)))
	expect_true(all(is.na(EDI:::compute_rand_bootstrap_ols_parallel_cpp(f$y, f$X, f$indices[, 1:2], degenerate_w, delta, NULL, 2L))))
	# Three observations cannot identify intercept, treatment, and covariate
	# with residual degrees of freedom; the kernel leaves this replicate NA.
	expect_true(is.na(EDI:::compute_rand_bootstrap_ols_parallel_cpp(f$y, f$X, matrix(1:3, ncol = 1), matrix(c(0L, 1L, 0L), ncol = 1), delta, NULL, 1L)))
})

test_that("OLS and tied-rank randomization distributions agree with R above the parallel gate", {
	f <- make_threshold_resampling_fixture()
	for (delta in c(0, .35)) {
		expected_ols <- vapply(seq_len(ncol(f$w_mat)), function(b) {
			w <- f$w_mat[, b]
			unname(lm.fit(cbind(1, w, f$X), f$y + delta * w)$coefficients[2])
		}, numeric(1))
		expected_rank <- vapply(seq_len(ncol(f$w_mat)), function(b) {
			w <- f$w_mat[, b]
			r <- rank(f$y_ord + delta * w)
			mean(r[w == 1L]) - mean(r[w == 0L])
		}, numeric(1))
		expect_equal(EDI:::compute_ols_distr_parallel_cpp(f$X, f$y, f$w_mat, delta, 2L), expected_ols, tolerance = 1e-10)
		expect_equal(EDI:::compute_wilcox_distr_parallel_cpp(f$w_mat, as.numeric(f$y_ord), delta, 2L), expected_rank)
		expect_equal(EDI:::compute_wilcox_distr_from_list_parallel_cpp(lapply(seq_len(ncol(f$w_mat)), function(b) list(w = f$w_mat[, b])), as.numeric(f$y_ord), delta, 2L), expected_rank)
	}
})

test_that("bisection nonfinite midpoints move the conservative search boundary", {
	# Missing midpoints are rejected on both tails of a two-sided p-value.
	# The lower and upper searches must still find their .6 and 1.4 crossings.
	pval <- function(r, delta, transform_responses, num_cores) {
		if (delta %in% c(.5, 1.5)) NA_real_ else min(delta, 2 - delta)
	}
	expect_equal(EDI:::bisection_ci_single_bound_cpp(pval, 1L, 0, 1, .6, .01, "none", TRUE, 2L), .6, tolerance = .01)
	expect_equal(EDI:::bisection_ci_parallel_cpp(pval, 1L, 0, 1, 1, 2, .6, .01, "none", 2L), c(.6, 1.4), tolerance = .01)
})
