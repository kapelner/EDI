library(testthat)
library(EDI)

# InferenceNonParamBootstrap's design-backed reusable worker: create_design_backed_bootstrap_worker_state()
# (independent duplicate of the object and its design; snapshot of the base data incl. effective survival
# times / event indicators) and load_bootstrap_sample_into_design_backed_worker() (row subsetting of w, y,
# X, dead, m, cache resets, KK match-id override), checked by recomputing the estimate on the loaded sample.

wk_fx <- function(n = 30L, seed = 4L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- w + rnorm(n)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des); inf$num_cores <- 1L
	list(inf = inf, p = inf$.__enclos_env__$private, des = des, w = w, y = y, n = n)
}

mean_diff <- function(y, w) mean(y[w == 1]) - mean(y[w == 0])

bootstrap_matrix_fixture <- function(kind, n = 1000L, seed) {
	set.seed(seed)
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	response_type <- switch(kind,
		OLS = "continuous",
		logistic = "incidence",
		Cox = "survival"
	)
	design_class <- if (identical(kind, "Cox")) DesignFixediBCRD else DesignFixedBernoulli
	des <- design_class$new(n = n, response_type = response_type, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$assign_w_to_all_subjects()
	w <- as.numeric(des$get_w())
	if (identical(kind, "OLS")) {
		y <- 0.5 + 0.7 * w + 0.4 * x1 - 0.2 * x2 + rnorm(n)
		des$add_all_subject_responses(y)
		inf <- InferenceContinOLS$new(des, model_formula = ~., verbose = FALSE)
	} else if (identical(kind, "logistic")) {
		y <- rbinom(n, size = 1L, prob = plogis(-0.4 + 0.7 * w + 0.3 * x1 - 0.2 * x2))
		des$add_all_subject_responses(y)
		inf <- InferenceIncidLogRegr$new(des, model_formula = ~., verbose = FALSE)
	} else {
		y <- rexp(n, rate = exp(0.25 * w + 0.2 * x1 - 0.15 * x2))
		des$add_all_subject_responses(y)
		inf <- InferenceSurvivalCoxPHRegr$new(des, model_formula = ~., verbose = FALSE)
	}
	inf$num_cores <- 1L
	invisible(inf$compute_estimate(estimate_only = TRUE))
	list(inf = inf, w = w, y = y, x1 = x1, x2 = x2, n = n)
}

bootstrap_matrix_reference <- function(kind, y, w, x1, x2, indices) {
	X <- cbind(`(Intercept)` = 1, treatment = w[indices], x1 = x1[indices], x2 = x2[indices])
	if (identical(kind, "OLS")) {
		return(unname(stats::lm.fit(X, y[indices])$coefficients[2L]))
	}
	if (identical(kind, "logistic")) {
		return(unname(stats::glm.fit(X, y[indices], family = stats::binomial())$coefficients[2L]))
	}
	df <- data.frame(time = y[indices], treatment = w[indices], x1 = x1[indices], x2 = x2[indices])
	unname(survival::coxph(survival::Surv(time) ~ treatment + x1 + x2, data = df, ties = "breslow")$coefficients[1L])
}

checkout_design_backed_sample_loader <- function(parent_private){
	source_candidates = c(
		file.path("R", "EDI", "R", "inference_all_abstract_non_param_boot.R"),
		file.path("..", "..", "EDI", "R", "inference_all_abstract_non_param_boot.R")
	)
	source_file = source_candidates[file.exists(source_candidates)][1L]
	if (is.na(source_file)) stop("Could not locate checkout bootstrap source")
	source_lines = readLines(source_file, warn = FALSE)
	start_line = grep("^\\s*load_bootstrap_sample_into_design_backed_worker\\s*=\\s*function\\s*\\(", source_lines)
	if (!length(start_line)) stop("Could not locate checkout design-backed loader")
	partial = character()
	definition = NULL
	for (line in source_lines[seq.int(start_line[1L], length(source_lines))]) {
		partial = c(partial, line)
		candidate = sub(",\\s*$", "", paste(partial, collapse = "\n"))
		parsed = tryCatch(parse(text = candidate), error = function(e) NULL)
		if (length(parsed) == 1L) {
			assignment = parsed[[1L]]
			if (is.call(assignment) && identical(assignment[[1L]], as.name("=")) &&
					identical(assignment[[2L]], as.name("load_bootstrap_sample_into_design_backed_worker"))) {
				definition = assignment[[3L]]
				break
			}
		}
	}
	if (is.null(definition)) stop("Could not extract checkout design-backed loader")
	eval_env = new.env(parent = asNamespace("EDI"))
	eval_env$private = parent_private
	eval_env$qr_calls = 0L
	eval_env$qr = function(...) {
		eval_env$qr_calls = eval_env$qr_calls + 1L
		base::qr(...)
	}
	eval(definition, envir = eval_env)
}

test_that("worker state: an independent single-core duplicate plus a snapshot of the base data", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	expect_equal(ws$n, f$n)
	expect_equal(ws$base_w, as.numeric(f$w)); expect_equal(ws$base_y, f$y)
	expect_equal(ws$base_dead, rep(1, f$n))                                              # exact responses: all events
	expect_null(ws$base_m)
	expect_equal(nrow(ws$base_X), f$n)
	expect_equal(nrow(ws$base_Xraw), f$n)
	expect_false(identical(ws$worker, f$inf))
	expect_equal(ws$worker$num_cores, 1L)
	expect_false(identical(ws$worker_des_priv, f$p$des_obj_priv_int))                    # the design was duplicated too
	expect_identical(ws$worker_priv$des_obj_priv_int, ws$worker_des_priv)
	expect_equal(ws$base_Xraw, as.data.frame(f$p$des_obj_priv_int$Xraw))
})

test_that("checkout sample loader reuses only an exact prior full-rank matrix certificate", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	load_checkout <- checkout_design_backed_sample_loader(f$p)
	full_rank_indices <- seq_len(f$n)

	load_checkout(ws, full_rank_indices)
	expect_equal(environment(load_checkout)$qr_calls, 1L)
	expect_true(isTRUE(ws$worker_priv$bootstrap_qr_rank_certificate$mode == "unweighted"))
	expect_false(ws$worker_des_priv$model_matrix_stale)

	# Identical X_rank means the earlier QR certifies this draw exactly.
	load_checkout(ws, full_rank_indices)
	expect_equal(environment(load_checkout)$qr_calls, 1L)
	expect_false(ws$worker_des_priv$model_matrix_stale)

	# Repeatedly selecting one row makes intercept and treatment collinear.
	# The stale full-rank certificate must not bypass this draw's QR/rebuild.
	load_checkout(ws, rep(1L, f$n))
	expect_equal(environment(load_checkout)$qr_calls, 2L)
	expect_null(ws$worker_priv$X)
	expect_true(ws$worker_des_priv$model_matrix_stale)
	expect_null(ws$worker_priv$bootstrap_qr_rank_certificate)
})

test_that("loading a sample subsets the worker's data and the estimate equals the estimate on those rows", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	set.seed(3)
	idx <- sample(f$n, f$n, replace = TRUE)
	while (length(unique(f$w[idx])) < 2L) idx <- sample(f$n, f$n, replace = TRUE)
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, idx)
	wp <- ws$worker_priv
	expect_equal(wp$w, as.numeric(f$w[idx])); expect_equal(wp$y, f$y[idx]); expect_equal(wp$y_temp, f$y[idx])
	expect_equal(wp$n, f$n); expect_equal(nrow(wp$X), f$n)
	expect_equal(c(ws$worker_des_priv$n, ws$worker_des_priv$t), c(f$n, f$n))              # the worker design's size follows the sample
	expect_equal(ws$worker$compute_estimate(estimate_only = TRUE), mean_diff(f$y[idx], f$w[idx]), tolerance = 1e-10)
	# The source object is untouched.
	expect_equal(f$inf$compute_estimate(), mean_diff(f$y, f$w), tolerance = 1e-10)
	expect_equal(f$p$w, f$w)
})

test_that("duplicated bootstrap rows retain their columns without unique row-name construction", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	idx <- c(2L, 2L, 5L, 2L, 7L)
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, idx)
	xraw <- ws$worker_des_priv$Xraw
	ximp <- ws$worker_des_priv$Ximp
	expect_equal(as.list(xraw), as.list(as.data.frame(f$p$des_obj_priv_int$Xraw)[idx, , drop = FALSE]))
	expect_equal(as.list(ximp), as.list(as.data.frame(f$p$des_obj_priv_int$Ximp)[idx, , drop = FALSE]))
	expect_identical(row.names(xraw), as.character(seq_along(idx)))
	expect_identical(row.names(ximp), as.character(seq_along(idx)))
})

test_that("a smaller sample changes n, drops every derived cache and can be reloaded repeatedly", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	wp <- ws$worker_priv
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, 1:10)
	wp$cached_values$beta_hat_T <- 5; wp$cached_reduced_X <- matrix(1); wp$cached_design_matrix <- matrix(2); wp$cached_mod <- list(b = 1)
	expect_equal(wp$n, 10L)
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, 11:30)
	expect_equal(wp$n, 20L); expect_equal(wp$w, as.numeric(f$w[11:30]))
	expect_length(wp$cached_values, 0L)
	expect_null(wp$cached_reduced_X); expect_null(wp$cached_design_matrix); expect_null(wp$cached_mod)
	expect_equal(ws$worker$compute_estimate(estimate_only = TRUE), mean_diff(f$y[11:30], f$w[11:30]), tolerance = 1e-10)
})

test_that("a reused OLS worker fits each resampled design matrix, not the first draw's", {
	set.seed(28L)
	n <- 40L
	x1 <- rnorm(n); x2 <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- 2 * w + 0.6 * x1 - 0.3 * x2 + rnorm(n, sd = 0.5)
	des$add_all_subject_responses(y)
	inf <- InferenceContinOLS$new(des, model_formula = ~., harden = FALSE, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	ws <- p$create_design_backed_bootstrap_worker_state()
	first_idx <- sample.int(n, n, replace = TRUE)
	second_idx <- sample.int(n, n, replace = TRUE)
	p$load_bootstrap_sample_into_design_backed_worker(ws, first_idx)
	first <- p$compute_bootstrap_worker_estimate(ws)
	expect_false(is.null(ws$worker_priv$cached_design_matrix))
	p$load_bootstrap_sample_into_design_backed_worker(ws, second_idx)
	expect_null(ws$worker_priv$cached_design_matrix)
	expect_null(ws$worker_priv$cached_hardened_X_cov)
	second <- p$compute_bootstrap_worker_estimate(ws)
	fresh_ws <- p$create_design_backed_bootstrap_worker_state()
	p$load_bootstrap_sample_into_design_backed_worker(fresh_ws, second_idx)
	fresh_second <- p$compute_bootstrap_worker_estimate(fresh_ws)
	X_second <- cbind(1, w[second_idx], x1[second_idx], x2[second_idx])
	reference_second <- unname(stats::lm.fit(X_second, y[second_idx])$coefficients[2L])
	expect_true(is.finite(first) && is.finite(second))
	expect_gt(abs(second - first), 0.01)
	expect_equal(second, fresh_second, tolerance = 1e-8)
	expect_equal(second, reference_second, tolerance = 1e-8)
})

test_that("direct-subset bootstrap estimates match rebuilt matrices on OLS, logistic, and Cox fixtures", {
	kinds <- c("OLS", "logistic", "Cox")
	seeds <- c(20261014L, 20261015L, 20261016L)
	for (j in seq_along(kinds)) {
		kind <- kinds[[j]]
		fixture <- bootstrap_matrix_fixture(kind, n = 1000L, seed = seeds[[j]])
		p <- fixture$inf$.__enclos_env__$private
		# Evaluate the checkout loader definition instead of trusting the installed
		# package's R layer; the installed native fitters remain the execution
		# backend under compile=FALSE.
		checkout_loader <- checkout_design_backed_sample_loader(p)
		direct_state <- p$create_design_backed_bootstrap_worker_state()
		rebuilt_state <- p$create_design_backed_bootstrap_worker_state()
		# Removing the cached full-data matrix makes the loader mark the design
		# stale. Materialize the draw-specific matrix explicitly, as the historical
		# per-draw rebuild path did before fitting the worker estimate.
		rebuilt_state$base_X <- NULL
		set.seed(seeds[[j]] + 1000L)
		draws <- replicate(5L, sample.int(fixture$n, fixture$n, replace = TRUE), simplify = FALSE)
		for (indices in draws) {
			checkout_loader(direct_state, indices)
			direct <- p$compute_bootstrap_worker_estimate(direct_state)

			checkout_loader(rebuilt_state, indices)
			rebuilt_priv <- rebuilt_state$worker$.__enclos_env__$private
			rebuilt_priv$X <- rebuilt_priv$get_X()
			rebuilt <- p$compute_bootstrap_worker_estimate(rebuilt_state)

			reference <- bootstrap_matrix_reference(
				kind, fixture$y, fixture$w, fixture$x1, fixture$x2, indices
			)
			expect_true(is.finite(direct) && is.finite(rebuilt) && is.finite(reference))
			expect_equal(direct, rebuilt, tolerance = 1e-10)
			expect_equal(direct, reference, tolerance = 1e-10)
		}
	}
})

test_that("TODO-58 planned OLS public percentile CI matches the boot lm.fit statistic on fixed draws", {
	n <- 1000L
	B <- 31L
	fixture_seed <- 22422L
	row_seed <- 414230L
	set.seed(fixture_seed)
	X <- matrix(stats::rnorm(n * 5L), n, 5L)
	X[, 1L] <- 1
	beta <- stats::rnorm(5L) * 0.5
	n_treat <- floor(n / 2L)
	w <- sample(c(rep(1, n_treat), rep(0, n - n_treat)))
	y <- drop(X %*% beta + 0.5 * w + stats::rnorm(n, 0, 0.5))
	X_cov <- as.data.frame(X[, -1L, drop = FALSE])
	names(X_cov) <- paste0("x", seq_len(ncol(X_cov)))
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(X_cov)
	des$assign_w_to_all_subjects(as.numeric(w))
	des$add_all_subject_responses(y)

	# This is the OLS fixture and n from the TODO-58 runner. Generate one
	# explicit, seeded index set through the design's actual resampling method,
	# then evaluate the exact statistic used by the runner's boot::boot reference.
	set.seed(row_seed)
	indices <- lapply(seq_len(B), function(i) {
		as.integer(des$.__enclos_env__$private$draw_bootstrap_indices()$i_b)
	})
	X_full <- cbind(`(Intercept)` = 1, treatment = w, as.matrix(X_cov))
	reference <- vapply(indices, function(idx) {
		unname(stats::lm.fit(X_full[idx, , drop = FALSE], y[idx])$coefficients[2L])
	}, numeric(1L))

	inf <- InferenceContinOLS$new(des, model_formula = ~., verbose = FALSE)
	inf$num_cores <- 1L
	set.seed(row_seed)
	observed <- inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE)
	expect_equal(as.numeric(observed), reference, tolerance = 1e-10)

	# The public CI uses the same predeclared percentile probabilities and EDI's
	# type-8 quantile rule. A fresh inference object ensures this exercises the
	# public procedure rather than a previously cached distribution.
	ci_inf <- InferenceContinOLS$new(des, model_formula = ~., verbose = FALSE)
	ci_inf$num_cores <- 1L
	set.seed(row_seed)
	observed_ci <- ci_inf$compute_bootstrap_confidence_interval(
		B = B, type = "percentile", show_progress = FALSE
	)
	reference_ci <- stats::quantile(reference, probs = c(0.025, 0.975), names = FALSE, type = 8)
	expect_equal(as.numeric(observed_ci), as.numeric(reference_ci), tolerance = 1e-10)
})

test_that("a bootstrap sample that makes a rare covariate constant falls back to the rebuild path", {
	set.seed(290L)
	n <- 30L
	x <- rnorm(n)
	rare <- c(rep(0, n - 1L), 1)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x, rare = rare))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- 1.5 * w + 0.4 * x + 0.7 * rare + rnorm(n, sd = 0.2)
	des$add_all_subject_responses(y)
	inf <- InferenceContinOLS$new(des, model_formula = ~., harden = TRUE, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	ws <- p$create_design_backed_bootstrap_worker_state()
	idx <- seq_len(n - 1L) # omit the sole rare-level row
	p$load_bootstrap_sample_into_design_backed_worker(ws, idx)
	expect_null(ws$worker_priv$X)
	expect_null(ws$worker_des_priv$X)
	expect_true(ws$worker_des_priv$model_matrix_stale)
	estimate <- p$compute_bootstrap_worker_estimate(ws)
	reference <- unname(stats::lm.fit(cbind(1, w[idx], x[idx]), y[idx])$coefficients[2L])
	expect_equal(estimate, reference, tolerance = 1e-10)

	# The same reusable worker must return to the direct-subset path after a
	# rank-deficient draw; its stale flag belongs to the draw, not the worker.
	direct_idx <- seq_len(n)
	p$load_bootstrap_sample_into_design_backed_worker(ws, direct_idx)
	expect_false(ws$worker_des_priv$model_matrix_stale)
	expect_equal(ws$worker_priv$X, ws$base_X[direct_idx, , drop = FALSE])
	direct_estimate <- p$compute_bootstrap_worker_estimate(ws)
	direct_reference <- unname(stats::lm.fit(cbind(1, w[direct_idx], x[direct_idx], rare[direct_idx]), y[direct_idx])$coefficients[2L])
	expect_equal(direct_estimate, direct_reference, tolerance = 1e-10)

	# A factor level present in the base model matrix but absent from the draw
	# leaves an all-zero direct-subset column. The reusable worker must rebuild
	# from the subset, just as the historical formula/model.matrix path did.
	set.seed(291L)
	factor_x <- rnorm(n)
	segment <- factor(c(rep("common", n - 1L), "rare"), levels = c("common", "rare"))
	factor_des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	factor_des$add_all_subjects_to_experiment(data.frame(x = factor_x, segment = segment))
	factor_des$assign_w_to_all_subjects()
	factor_w <- as.numeric(factor_des$get_w())
	factor_y <- 1.5 * factor_w + 0.4 * factor_x + 0.7 * as.numeric(segment == "rare") + rnorm(n, sd = 0.2)
	factor_des$add_all_subject_responses(factor_y)
	factor_inf <- InferenceContinOLS$new(factor_des, model_formula = ~., harden = TRUE, verbose = FALSE)
	factor_p <- factor_inf$.__enclos_env__$private
	factor_ws <- factor_p$create_design_backed_bootstrap_worker_state()
	factor_idx <- seq_len(n - 1L) # the draw omits the sole observation at the rare factor level
	factor_p$load_bootstrap_sample_into_design_backed_worker(factor_ws, factor_idx)
	expect_null(factor_ws$worker_priv$X)
	expect_true(factor_ws$worker_des_priv$model_matrix_stale)
	factor_estimate <- factor_p$compute_bootstrap_worker_estimate(factor_ws)
	factor_df <- data.frame(treatment = factor_w[factor_idx], x = factor_x[factor_idx])
	# `segment` is constant in this draw, so the independent reference uses
	# the reduced model matrix after removing that nonestimable term.
	factor_reference_X <- stats::model.matrix(~ treatment + x, data = factor_df)
	factor_reference <- unname(stats::lm.fit(factor_reference_X, factor_y[factor_idx])$coefficients["treatment"])
	expect_equal(factor_estimate, factor_reference, tolerance = 1e-10)
})

test_that("the indices may be a bare vector or a list draw with i_b (and an optional m_vec_b override)", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	idx <- c(2, 5, 7, 9, 20, 21)
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, list(i_b = idx, m_vec_b = NULL))
	expect_equal(ws$worker_priv$w, as.numeric(f$w[idx]))
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, as.numeric(idx))              # doubles are coerced to integer rows
	expect_equal(ws$worker_priv$y, f$y[idx])
	expect_null(ws$worker_priv$m %||% NULL)
})

test_that("KK designs: the match vector is subset by row unless the draw supplies its own renumbered ids", {
	set.seed(6); np <- 8L; ns <- 4L; n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	m <- c(rep(seq_len(np), each = 2L), rep(0L, ns)); des$.__enclos_env__$private$m <- m
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des); p <- inf$.__enclos_env__$private
	ws <- p$create_design_backed_bootstrap_worker_state()
	expect_equal(as.integer(ws$base_m), m)
	idx <- c(1L, 2L, 5L, 6L, 17L, 18L)
	p$load_bootstrap_sample_into_design_backed_worker(ws, idx)
	expect_equal(as.integer(ws$worker_priv$m), m[idx])
	p$load_bootstrap_sample_into_design_backed_worker(ws, list(i_b = idx, m_vec_b = c(1L, 1L, 2L, 2L, 0L, 0L)))
	expect_equal(as.integer(ws$worker_priv$m), c(1L, 1L, 2L, 2L, 0L, 0L))
})

test_that("survival responses: the base response is the effective time and the event indicator follows censoring", {
	set.seed(8); n <- 24L
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	t <- rexp(n); d <- rep(c(1, 0, 1, 1), length.out = n)
	des$add_all_subject_responses(ifelse(d == 1, t, NA), ifelse(d == 1, NA, t), ifelse(d == 1, NA, Inf))
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE); p <- inf$.__enclos_env__$private
	ws <- p$create_design_backed_bootstrap_worker_state()
	expect_equal(ws$base_y, t); expect_equal(ws$base_dead, d)
	idx <- c(1L, 2L, 3L, 4L, 4L, 2L)
	p$load_bootstrap_sample_into_design_backed_worker(ws, idx)
	expect_equal(ws$worker_priv$y, t[idx]); expect_equal(ws$worker_priv$dead, d[idx])
	expect_true(ws$worker_priv$any_censoring)
	p$load_bootstrap_sample_into_design_backed_worker(ws, c(1L, 3L, 4L))               # only events
	expect_false(ws$worker_priv$any_censoring)
})
