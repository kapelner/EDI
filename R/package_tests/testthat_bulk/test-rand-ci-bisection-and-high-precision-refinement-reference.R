library(testthat)
library(EDI)

source(test_path("..", "todo33_trigger_search_provenance.R"), local = TRUE)

# compute_ci_by_inverting_the_randomization_test_iteratively() and
# high_precision_confirm_and_refine_ci_bound() (InferenceRandCI): bisection to the delta where a
# smooth p-value crosses the threshold (closed form for a normal-shaped p-value), NA endpoints
# re-probed by halving, the conservative-boundary message + counter, the deadline stop, and the
# high-precision pass (refine on a verified sign change, else return the outer end).
# compute_randomization_ci_pval_cached() is stubbed with an analytic p-value.

est <- 0.5; sdv <- 0.8
pnorm_p <- function(d) 2 * pnorm(-abs(d - est) / sdv)

fx <- function(pfun = pnorm_p) {
	set.seed(1)
	n <- 12L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	calls <- new.env(); calls$deltas <- numeric(0); calls$controls <- list()
	unlockBinding("compute_randomization_ci_pval_cached", p)
	p$compute_randomization_ci_pval_cached <- function(inf_obj, r, delta, transform_responses, permutations, ci_search_control, ci_pval_cache) {
		calls$deltas <- c(calls$deltas, delta)
		calls$controls[[length(calls$controls) + 1L]] <- ci_search_control
		pfun(delta)
	}
	list(inf = inf, p = p, calls = calls)
}
bisect <- function(f, l, u, lower, th = 0.05, tol = 1e-7, ctrl = list(high_precision_confirm = FALSE)) {
	f$p$compute_ci_by_inverting_the_randomization_test_iteratively(r = 100L, l = l, u = u, pval_th = th, tol = tol,
		transform_responses = "none", lower = lower, show_progress = FALSE, ci_search_control = ctrl)
}

test_that("the lower and upper bounds converge to the normal-theory crossing points", {
	f <- fx()
	z <- qnorm(1 - 0.05 / 2)
	expect_equal(bisect(f, est - 6, est, TRUE), est - z * sdv, tolerance = 1e-4)
	expect_equal(bisect(f, est, est + 6, FALSE), est + z * sdv, tolerance = 1e-4)
	f2 <- fx()
	expect_equal(bisect(f2, est - 6, est, TRUE, th = 0.2), est - qnorm(0.9) * sdv, tolerance = 1e-4)
})

test_that("non-finite endpoint p-values are re-probed by moving that end to the midpoint", {
	pf <- function(d) if (d < est - 4) NA_real_ else pnorm_p(d)
	f <- fx(pf)
	got <- bisect(f, est - 6, est, TRUE)
	expect_equal(got, est - qnorm(0.975) * sdv, tolerance = 1e-4)
	expect_true(is.na(bisect(fx(function(d) NA_real_), est - 6, est, TRUE)))
})

test_that("a still-accepted search boundary is returned as a conservative bound with a message and counter", {
	flat <- function(d) 0.5
	f <- fx(flat)
	expect_message(lo <- bisect(f, est - 6, est, TRUE), "lower bound is conservative")
	expect_equal(lo, est - 6)
	expect_equal(f$p$rand_ci_conservative_count, 1L)
	expect_message(up <- bisect(f, est, est + 6, FALSE), "upper bound is conservative")
	expect_equal(up, est + 6)
	expect_equal(f$p$rand_ci_conservative_count, 2L)
})

test_that("an elapsed deadline stops the search with the step label", {
	f <- fx()
	ctrl <- list(high_precision_confirm = FALSE, timeout_deadline = unname(proc.time()[["elapsed"]]) - 10)
	expect_error(bisect(f, est - 6, est, TRUE, ctrl = ctrl), "Randomization CI bisection reached elapsed time limit")
})

test_that("high-precision confirmation is skipped unless requested (returns the bracket end for the bound's side)", {
	f <- fx()
	p <- f$p
	expect_equal(p$high_precision_confirm_and_refine_ci_bound(1, 2, TRUE, 100L, "none", NULL, list(high_precision_confirm = FALSE), 0.05, 1e-6), 1)
	expect_equal(p$high_precision_confirm_and_refine_ci_bound(1, 2, FALSE, 100L, "none", NULL, list(), 0.05, 1e-6), 2)
	expect_length(f$calls$deltas, 0L)
})

test_that("with confirmation on, the bound is refined on a fresh un-early-stopped evaluation", {
	f <- fx()
	z <- qnorm(0.975)
	ctrl <- list(high_precision_confirm = TRUE, mc_enable = TRUE)
	out <- f$p$high_precision_confirm_and_refine_ci_bound(est - z * sdv - 0.3, est - z * sdv + 0.3, TRUE, 100L, "none", NULL, ctrl, 0.05, 1e-8)
	expect_equal(out, est - z * sdv, tolerance = 1e-3)
	expect_true(all(vapply(f$calls$controls, function(cc) identical(cc$mc_enable, FALSE), logical(1))))
})

test_that("high-precision confirmation isolates the caller's early-stopped p-value cache", {
	f <- fx()
	p <- f$p
	caller_cache <- new.env(parent = emptyenv())
	cache_calls <- list()
	unlockBinding("compute_randomization_ci_pval_cached", p)
	p$compute_randomization_ci_pval_cached <- function(inf_obj, r, delta, transform_responses, permutations, ci_search_control, ci_pval_cache) {
		key <- sprintf("%.17g", delta)
		cache_calls[[length(cache_calls) + 1L]] <<- list(
			delta = delta,
			mc_enable = isTRUE(ci_search_control$mc_enable),
			cache = ci_pval_cache
		)
		if (exists(key, envir = ci_pval_cache, inherits = FALSE)) {
			return(get(key, envir = ci_pval_cache, inherits = FALSE))
		}
		# The cheap pass has a noisy, tolerance-small crossing. The full pass has
		# a distinct, exact step crossing at 1.5; reusing the caller cache would
		# stop at the noisy bracket instead of evaluating a midpoint.
		value <- if (isTRUE(ci_search_control$mc_enable)) {
			if (delta <= 1.5) 0.051 else 0.049
		} else {
			if (delta < 1.5) 0.2 else 0.01
		}
		assign(key, value, envir = ci_pval_cache)
		value
	}

	got <- p$compute_ci_by_inverting_the_randomization_test_iteratively(
		r = 100L, l = 1, u = 2, pval_th = 0.05, tol = 0.01,
		transform_responses = "none", lower = FALSE, show_progress = FALSE,
		ci_search_control = list(mc_enable = TRUE, high_precision_confirm = TRUE),
		ci_pval_cache = caller_cache
	)
	full_calls <- Filter(function(call) !call$mc_enable, cache_calls)
	cheap_calls <- Filter(function(call) call$mc_enable, cache_calls)
	expect_equal(got, 1.5, tolerance = 1e-3)
	expect_length(cheap_calls, 2L)
	expect_true(all(vapply(cheap_calls, function(call) identical(call$cache, caller_cache), logical(1))))
	expect_gt(length(full_calls), 2L)
	expect_true(all(vapply(full_calls, function(call) is.environment(call$cache) && !identical(call$cache, caller_cache), logical(1))))
	expect_true(all(vapply(full_calls, function(call) identical(call$cache, full_calls[[1L]]$cache), logical(1))))
	expect_equal(length(ls(caller_cache, all.names = TRUE)), 2L)
})

test_that("high-precision lower and upper refinements converge to mirrored crossings", {
	z <- qnorm(0.975)
	f <- fx()
	ctrl <- list(high_precision_confirm = TRUE, mc_enable = TRUE)
	lower_crossing <- est - z * sdv
	upper_crossing <- est + z * sdv
	lower <- f$p$high_precision_confirm_and_refine_ci_bound(
		lower_crossing - 0.3, lower_crossing + 0.3, TRUE,
		100L, "none", NULL, ctrl, 0.05, 1e-8
	)
	upper <- f$p$high_precision_confirm_and_refine_ci_bound(
		upper_crossing - 0.3, upper_crossing + 0.3, FALSE,
		100L, "none", NULL, ctrl, 0.05, 1e-8
	)
	expect_equal(lower, lower_crossing, tolerance = 1e-3)
	expect_equal(upper, upper_crossing, tolerance = 1e-3)
	expect_equal(lower + upper, 2 * est, tolerance = 1e-3)
})

test_that("public randomization CI reaches both refinement directions when cheap p-values hide a wide crossing", {
	f <- fx()
	center <- f$inf$compute_estimate()
	threshold <- 0.10
	entry_widths <- numeric(0)
	active_refine_bound <- NULL
	upper_full_precision_deltas <- numeric(0)
	f$p$compute_randomization_ci_pval_cached <- function(inf_obj, r, delta, transform_responses, permutations, ci_search_control, ci_pval_cache) {
		if (identical(active_refine_bound, FALSE) && !isTRUE(ci_search_control$mc_enable)) {
			upper_full_precision_deltas <<- c(upper_full_precision_deltas, delta)
		}
		full_p <- 2 * pnorm(-abs(delta - center) / sdv)
		if (isTRUE(ci_search_control$mc_enable)) {
			return(if (full_p >= threshold) threshold + 0.001 else threshold - 0.001)
		}
		full_p
	}
	original_refine <- f$p$high_precision_confirm_and_refine_ci_bound
	unlockBinding("high_precision_confirm_and_refine_ci_bound", f$p)
	f$p$high_precision_confirm_and_refine_ci_bound <- function(l, u, lower, r, transform_responses, permutations, ci_search_control, pval_th, tol) {
		active_refine_bound <<- lower
		on.exit(active_refine_bound <<- NULL)
		entry_widths <<- c(entry_widths, u - l)
		original_refine(l, u, lower, r, transform_responses, permutations, ci_search_control, pval_th, tol)
	}
	ci <- f$inf$compute_rand_confidence_interval(
		alpha = 0.10, r = 201L, pval_epsilon = 0.01, show_progress = FALSE,
		ci_search_control = list(mc_enable = TRUE, high_precision_confirm = TRUE, seed = "none")
	)
	expect_length(entry_widths, 2L)
	expect_true(all(entry_widths > 0.01))
	# The helper always evaluates the two full-precision endpoints; any further
	# upper-bound evaluation is an inner refinement midpoint. The returned upper
	# limit must still match the independent normal-score crossing below.
	expect_gt(length(upper_full_precision_deltas), 2L)
	expect_equal(as.numeric(ci), center + c(-1, 1) * qnorm(0.95) * sdv, tolerance = 1e-2)
})

test_that("public CI reaches strict refinement on the fixed-permutation p-value path", {
	set.seed(20261021L)
	n <- 8L
	y <- c(0, 1, 2, 4, 5, 7, 8, 10)
	w_obs <- rep(c(1L, 0L), length.out = n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 20261021L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	des$overwrite_all_subject_assignments(w_obs)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private

	# All columns are valid balanced Bernoulli assignments. The schedule makes
	# the first 450 draws straddle alpha narrowly, while the full 501-draw
	# distribution straddles more widely. This is an adversarial deterministic
	# branch witness, not a calibration or real-data result.
	w_hi <- as.integer(seq_len(n) %in% c(5L, 6L, 7L, 8L))
	w_lo <- as.integer(seq_len(n) %in% c(1L, 2L, 3L, 4L))
	w_cross <- as.integer(seq_len(n) %in% c(2L, 3L, 4L, 6L))
	w_mat <- cbind(
		matrix(rep(w_hi, times = 437L), nrow = n),
		matrix(rep(w_lo, times = 12L), nrow = n),
		w_cross,
		matrix(rep(w_lo, times = 51L), nrow = n)
	)
	perms <- list(w_mat = w_mat)

	# Public CI normally primes the OLS affine cache with a full delta=0 pass.
	# Disable only that optimization on this fixture so its real public
	# compute_rand_two_sided_pval calls exercise sequential prefix stopping.
	unlockBinding("generate_permutations", p)
	p$generate_permutations <- function(r) perms
	unlockBinding("supports_additive_delta_shift", p)
	p$supports_additive_delta_shift <- function(transform_responses = "none") FALSE

	observed <- mean(y[w_obs == 1L]) - mean(y[w_obs == 0L])
	manual_t0s <- function(delta, n_draws) {
		w <- w_mat[, seq_len(n_draws), drop = FALSE]
		y0 <- y - delta * w_obs
		n_t <- colSums(w)
		n_c <- colSums(1 - w)
		t0 <- colSums(w * y0) / n_t - colSums((1 - w) * y0) / n_c
		t0
	}
	manual_p <- function(delta, n_draws) {
		t0 <- manual_t0s(delta, n_draws)
		observed_under_null <- observed - delta
		valid <- is.finite(t0)
		p_raw <- 2 * min(sum(t0[valid] >= observed_under_null) / sum(valid), sum(t0[valid] <= observed_under_null) / sum(valid))
		min(1, max(2 / sum(valid), p_raw))
	}
	expect_equal(manual_p(3.5, 450L), 24 / 450, tolerance = 1e-12)
	expect_equal(manual_p(4.5, 450L), 2 / 450, tolerance = 1e-12)
	expect_equal(manual_p(3.5, 501L), 126 / 501, tolerance = 1e-12)
	expect_equal(manual_p(4.5, 501L), 2 / 501, tolerance = 1e-12)

	track <- new.env(parent = emptyenv())
	track$inside_refinement <- FALSE
	track$calls <- list()
	track$entries <- list()
	track$scorer_calls <- list()
	track$active_delta <- NA_real_
	track$active_mc_enable <- NA
	track$active_bound_lower <- NA
	original_cached <- p$compute_randomization_ci_pval_cached
	original_refine <- p$high_precision_confirm_and_refine_ci_bound
	original_scorer <- p$compute_two_sided_randomization_pval_from_t0s
	unlockBinding("compute_randomization_ci_pval_cached", p)
	unlockBinding("high_precision_confirm_and_refine_ci_bound", p)
	unlockBinding("compute_two_sided_randomization_pval_from_t0s", p)
	p$compute_two_sided_randomization_pval_from_t0s <- function(t0s, t, alternative = "two.sided") {  # TODO-113 added `alternative`
		if (isTRUE(track$inside_refinement)) {
			active_mc_control <- p$randomization_mc_control
			track$scorer_calls[[length(track$scorer_calls) + 1L]] <- list(
				t = as.numeric(t), t0s = as.numeric(t0s),
				delta = as.numeric(track$active_delta),
				mc_enable_requested = track$active_mc_enable,
				mc_enable_active = isTRUE(active_mc_control$mc_enable),
				lower = track$active_bound_lower
			)
		}
		original_scorer(t0s, t, alternative)
	}
	p$compute_randomization_ci_pval_cached <- function(inf_obj, r, delta, transform_responses, permutations, ci_search_control, ci_pval_cache) {
		old_delta <- track$active_delta
		old_mc_enable <- track$active_mc_enable
		track$active_delta <- as.numeric(delta)
		track$active_mc_enable <- isTRUE(ci_search_control$mc_enable)
		on.exit({ track$active_delta <- old_delta; track$active_mc_enable <- old_mc_enable }, add = TRUE)
		value <- original_cached(inf_obj, r, delta, transform_responses, permutations, ci_search_control, ci_pval_cache)
		actual_w_mat <- if (is.list(permutations)) permutations$w_mat else NULL
		track$calls[[length(track$calls) + 1L]] <- list(
			delta = as.numeric(delta), value = as.numeric(value),
			mc_enable = isTRUE(ci_search_control$mc_enable),
			inside_refinement = isTRUE(track$inside_refinement),
			permutation_dim = dim(actual_w_mat),
			permutation_matches_fixture = !is.null(actual_w_mat) &&
				identical(unname(actual_w_mat), unname(w_mat))
		)
		value
	}
	p$high_precision_confirm_and_refine_ci_bound <- function(l, u, lower, r, transform_responses, permutations, ci_search_control, pval_th, tol) {
		start <- length(track$calls)
		old_bound <- track$active_bound_lower
		track$active_bound_lower <- lower
		track$inside_refinement <- TRUE
		out <- tryCatch(
			original_refine(l, u, lower, r, transform_responses, permutations, ci_search_control, pval_th, tol),
			finally = { track$inside_refinement <- FALSE; track$active_bound_lower <- old_bound }
		)
		track$entries[[length(track$entries) + 1L]] <- list(
			lower = lower, l = as.numeric(l), u = as.numeric(u), out = as.numeric(out),
			tol = as.numeric(tol), calls = track$calls[seq.int(start + 1L, length(track$calls))]
		)
		out
	}

	alpha <- 0.05
	tol <- 0.05
	ci <- inf$compute_rand_confidence_interval(
		alpha = alpha, r = 501L, pval_epsilon = tol, show_progress = FALSE,
		ci_search_control = list(
			mc_enable = TRUE, mc_batch_size = 50L, mc_min_draws = 450L,
			mc_conf_level = 0.01, # intentionally low to make this branch witness deterministic
			high_precision_confirm = TRUE, pval_cache_enable = FALSE, seed = "none"
		)
	)

	upper <- Filter(function(x) identical(x$lower, FALSE), track$entries)
	expect_length(upper, 1L)
	upper <- upper[[1L]]
	# The cheap 450-draw prefix has a tolerance-small p-value gap at its final
	# bracket, while the fresh 501-draw reference has a real sign-changing gap.
	# The suffix deliberately concentrates crossing assignments to separate the
	# strict-refinement trigger from the cheap pass's Monte Carlo resolution.
	expect_lte(abs(manual_p(upper$l, 450L) - manual_p(upper$u, 450L)), tol)
	expect_gt(abs(manual_p(upper$l, 501L) - manual_p(upper$u, 501L)), tol)
	expect_gt(upper$u - upper$l, tol)
	full_calls <- Filter(function(x) !x$mc_enable, upper$calls)
	full_calls <- lapply(full_calls, function(call) {
		call$oracle_value <- manual_p(call$delta, 501L)
		call
	})
	expect_gte(length(full_calls), 3L)
	expect_true(all(vapply(full_calls, `[[`, logical(1), "permutation_matches_fixture")))
	expect_true(all(vapply(full_calls, function(call) identical(call$permutation_dim, dim(w_mat)), logical(1))))
	scored_upper <- Filter(function(call) identical(call$lower, FALSE) && !isTRUE(call$mc_enable_active), track$scorer_calls)
	expect_length(scored_upper, length(full_calls))
	expect_equal(
		vapply(scored_upper, `[[`, numeric(1), "t"),
		rep(observed, length(full_calls)),
		tolerance = 1e-12
	)
	for (i in seq_along(full_calls)) {
		expect_equal(
			unname(scored_upper[[i]]$t0s) - full_calls[[i]]$delta,
			unname(manual_t0s(full_calls[[i]]$delta, 501L)),
			tolerance = 1e-12
		)
	}
	expect_equal(
		vapply(full_calls, `[[`, numeric(1), "value"),
		vapply(full_calls, `[[`, numeric(1), "oracle_value"),
		tolerance = 1e-12
	)
	expect_equal(full_calls[[1L]]$delta, upper$l, tolerance = 1e-12)
	expect_equal(full_calls[[2L]]$delta, upper$u, tolerance = 1e-12)
	expect_equal(full_calls[[3L]]$delta, (upper$l + upper$u) / 2, tolerance = 1e-12)

	# Independent plain-R inversion of the full fixed-assignment distribution.
	manual_upper <- function(l, u) {
		p_l <- manual_p(l, 501L)
		p_u <- manual_p(u, 501L)
		for (iter in seq_len(15L)) {
			if (abs(u - l) <= tol || abs(p_u - p_l) <= tol) break
			m <- (l + u) / 2
			p_m <- manual_p(m, 501L)
			if (p_m >= alpha) l <- m else u <- m
			p_l <- if (p_m >= alpha) p_m else p_l
			p_u <- if (p_m < alpha) p_m else p_u
		}
		u
	}
	expect_equal(unname(ci[2L]), manual_upper(upper$l, upper$u), tolerance = 1e-12)
	expect_gte(manual_p(upper$l, 501L), alpha)
	expect_lt(manual_p(upper$u, 501L), alpha)

	# Preserve the actual deterministic permutation trigger as a replay bundle,
	# then build a positive-trigger run sidecar. This complements the negative
	# search contract below without running a real-data search or writing to a
	# canonical result location.
	replay_path <- file.path(tempdir(), paste0("todo33-fixed-permutation-trigger-", Sys.getpid(), ".rds"))
	sidecar_path <- file.path(tempdir(), paste0("todo33-fixed-permutation-sidecar-", Sys.getpid(), ".rds"))
	on.exit(unlink(c(replay_path, sidecar_path)), add = TRUE)
	manual_old_upper <- function(l, u) {
		p_l <- manual_p(l, 501L)
		p_u <- manual_p(u, 501L)
		for (iter in seq_len(15L)) {
			if (abs(u - l) <= tol || abs(p_u - p_l) <= tol) break
			m <- (l + u) / 2
			p_m <- manual_p(m, 501L)
			# Pre-fix update rule from 362c5d28fa6233d99d6d6815d1bffa02f5aa33ab:
			# for an upper bound, accepted midpoints incorrectly moved u2 instead of l2.
			if (p_m >= alpha) { u <- m; p_u <- p_m } else { l <- m; p_l <- p_m }
		}
		u
	}
	replay_bundle <- list(
		schema_version = 1L,
		dataset_name = "synthetic-fixed-permutation",
		response = y,
		observed_assignment = w_obs,
		permutation_matrix = unname(w_mat),
		ci_arguments = list(alpha = alpha, r = 501L, pval_epsilon = tol),
		search_control = list(mc_enable = TRUE, mc_batch_size = 50L, mc_min_draws = 450L,
			mc_conf_level = 0.01, high_precision_confirm = TRUE, pval_cache_enable = FALSE, seed = "none"),
		upper_trigger = list(l = upper$l, u = upper$u, output = unname(ci[2L]),
			old_branch_counterfactual = manual_old_upper(upper$l, upper$u))
	)
	saveRDS(replay_bundle, replay_path)

	hash <- function(ch) paste(rep(ch, 64L), collapse = "")
	package_provenance <- list(
		r_version = "R fixture",
		edi_package_version = "1.0.3",
		edi_package_path = "/tmp/EDI-installed",
		edi_namespace_path = "/tmp/EDI-source",
		edi_package_payload_path = "/tmp/checkout/R/EDI",
		edi_package_payload_sha256 = hash("a"),
		edi_dll_path = "/tmp/EDI-installed/libs/EDI.so",
		edi_dll_sha256 = hash("b"),
		checkout_path = "/tmp/checkout",
		checkout_head = paste(rep("c", 40L), collapse = ""),
		checkout_status_porcelain = character(),
		checkout_diff_sha256 = hash("d")
	)
	runner_path <- tempfile("todo33-fixed-permutation-runner-")
	writeLines("# deterministic permutation replay fixture", runner_path)
	on.exit(unlink(runner_path), add = TRUE)
	run_identity <- todo33_capture_search_run_identity(
		repo_root = "/tmp/checkout", runner_path = runner_path,
		provenance_anchor_path = "/tmp/checkout/R/package_tests/comprehensive_tests.R",
		capture_provenance = function(repo_root, runner_path) package_provenance,
		sha256_file = function(path) hash("e")
	)
	trigger_result <- data.frame(seed = 20261021L, trigger = TRUE,
		ci_lower = unname(ci[1L]), ci_upper = unname(ci[2L]))
	sidecar <- todo33_make_search_run_sidecar(
		provenance_before = run_identity,
		provenance_after = run_identity,
		run_spec = list(r = 501L, alpha = alpha, tolerance = tol,
			search_control = replay_bundle$search_control),
		input_data = data.frame(x = seq_len(n), response = y, observed_assignment = w_obs),
		results = trigger_result,
		trigger_replay_paths = replay_path
	)
	todo33_write_search_run_sidecar(sidecar_path, sidecar)
	loaded_sidecar <- readRDS(sidecar_path)
	loaded_replay <- readRDS(loaded_sidecar$trigger_replay_paths[[1L]])
	expect_identical(loaded_sidecar$trigger_count, 1L)
	expect_identical(loaded_replay$permutation_matrix, unname(w_mat))

	# Re-evaluate the independent full-permutation p-value/root reference solely
	# from the serialized replay inputs and trigger bracket.
	replay_manual_p <- function(delta) {
		w <- loaded_replay$permutation_matrix
		y0 <- loaded_replay$response - delta * loaded_replay$observed_assignment
		n_t <- colSums(w)
		n_c <- colSums(1 - w)
		t0 <- colSums(w * y0) / n_t - colSums((1 - w) * y0) / n_c
		observed_replay <- mean(loaded_replay$response[loaded_replay$observed_assignment == 1L]) -
			mean(loaded_replay$response[loaded_replay$observed_assignment == 0L])
		target <- observed_replay - delta
		p_raw <- 2 * min(sum(t0 >= target) / length(t0), sum(t0 <= target) / length(t0))
		min(1, max(2 / length(t0), p_raw))
	}
	replay_upper <- function(l, u) {
		p_l <- replay_manual_p(l)
		p_u <- replay_manual_p(u)
		for (iter in seq_len(15L)) {
			if (abs(u - l) <= tol || abs(p_u - p_l) <= tol) break
			m <- (l + u) / 2
			p_m <- replay_manual_p(m)
			if (p_m >= alpha) l <- m else u <- m
			p_l <- if (p_m >= alpha) p_m else p_l
			p_u <- if (p_m < alpha) p_m else p_u
		}
		u
	}
	replay_old_upper <- function(l, u) {
		p_l <- replay_manual_p(l)
		p_u <- replay_manual_p(u)
		for (iter in seq_len(15L)) {
			if (abs(u - l) <= tol || abs(p_u - p_l) <= tol) break
			m <- (l + u) / 2
			p_m <- replay_manual_p(m)
			if (p_m >= alpha) { u <- m; p_u <- p_m } else { l <- m; p_l <- p_m }
		}
		u
	}
	replayed_upper <- replay_upper(loaded_replay$upper_trigger$l, loaded_replay$upper_trigger$u)
	replayed_old_upper <- replay_old_upper(loaded_replay$upper_trigger$l, loaded_replay$upper_trigger$u)
	expect_equal(replay_upper(loaded_replay$upper_trigger$l, loaded_replay$upper_trigger$u),
		loaded_replay$upper_trigger$output, tolerance = 1e-12)
	expect_equal(replayed_old_upper, loaded_replay$upper_trigger$old_branch_counterfactual, tolerance = 1e-12)
	expect_gt(abs(replayed_upper - replayed_old_upper), tol)
	expect_lt(replay_manual_p(replayed_upper), alpha)
	expect_gte(replay_manual_p(replayed_old_upper), alpha)
})

test_that("same-side full-precision p-values return the conservative outer end; non-finite ones return the input end", {
	ctrl <- list(high_precision_confirm = TRUE)
	f <- fx(function(d) 0.9)                      # both ends accepted
	expect_equal(f$p$high_precision_confirm_and_refine_ci_bound(1, 2, TRUE, 100L, "none", NULL, ctrl, 0.05, 1e-6), 1)
	expect_equal(f$p$high_precision_confirm_and_refine_ci_bound(1, 2, FALSE, 100L, "none", NULL, ctrl, 0.05, 1e-6), 2)
	g <- fx(function(d) 0.001)                    # both ends rejected
	expect_equal(g$p$high_precision_confirm_and_refine_ci_bound(1, 2, TRUE, 100L, "none", NULL, ctrl, 0.05, 1e-6), 1)
	h <- fx(function(d) NA_real_)
	expect_equal(h$p$high_precision_confirm_and_refine_ci_bound(1, 2, FALSE, 100L, "none", NULL, ctrl, 0.05, 1e-6), 2)
})

test_that("the public CI inverts the two-sided test at alpha on one shared fixed permutation set", {
	set.seed(6801L)
	n <- 18L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 6801L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(1.5 * w + rnorm(n, sd = 0.45))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	r <- 399L
	perms <- p$generate_permutations(r)
	unlockBinding("generate_permutations", p)
	p$generate_permutations <- function(r) perms

	alpha <- 0.2
	ci <- suppressMessages(inf$compute_rand_confidence_interval(
		alpha = alpha, r = r, pval_epsilon = 0.01, show_progress = FALSE,
		ci_search_control = list(mc_enable = FALSE, high_precision_confirm = FALSE, seed = "none")
	))
	p_at_bounds <- vapply(as.numeric(ci), function(delta) {
		inf$compute_rand_two_sided_pval(r = r, delta = delta, show_progress = FALSE, permutations = perms)
	}, numeric(1))
	p_at_zero <- inf$compute_rand_two_sided_pval(r = r, delta = 0, show_progress = FALSE, permutations = perms)

	# Discrete p-values and the returned side of each final bracket permit one grid step.
	expect_equal(p_at_bounds, rep(alpha, 2L), tolerance = 0.015)
	expect_identical(!(ci[1] <= 0 && 0 <= ci[2]), p_at_zero < alpha)
})

test_that("TODO-33 run sidecars retain provenance and negative results without replay bundles", {
	hash <- function(ch) paste(rep(ch, 64L), collapse = "")
	package_provenance <- list(
		r_version = "R fixture",
		edi_package_version = "1.0.3",
		edi_package_path = "/tmp/EDI-installed",
		edi_namespace_path = "/tmp/EDI-source",
		edi_package_payload_path = "/tmp/checkout/R/EDI",
		edi_package_payload_sha256 = hash("a"),
		edi_dll_path = "/tmp/EDI-installed/libs/EDI.so",
		edi_dll_sha256 = hash("b"),
		checkout_path = "/tmp/checkout",
		checkout_head = paste(rep("c", 40L), collapse = ""),
		checkout_status_porcelain = character(),
		checkout_diff_sha256 = hash("d")
	)
	runner <- tempfile("todo33-trigger-search-runner-")
	writeLines("# fixed runner fixture", runner)
	on.exit(unlink(runner), add = TRUE)
	captured <- todo33_capture_search_run_identity(
		repo_root = "/tmp/checkout",
		runner_path = runner,
		provenance_anchor_path = "/tmp/checkout/R/package_tests/comprehensive_tests.R",
		capture_provenance = function(repo_root, runner_path) package_provenance,
		sha256_file = function(path) hash("e")
	)
	expect_identical(captured$package_provenance, package_provenance)
	expect_identical(captured$trigger_runner_path, normalizePath(runner, winslash = "/"))
	expect_match(captured$trigger_runner_sha256, "^[[:xdigit:]]{64}$")

	results <- data.frame(seed = c(20261301L, 20261302L), trigger = c(FALSE, FALSE))
	input_data <- data.frame(y = c(1, 2), x = c(3, 4))
	sidecar <- todo33_make_search_run_sidecar(
		provenance_before = captured,
		provenance_after = captured,
		run_spec = list(alpha = 0.10, r = 501L, tolerance = 0.005),
		input_data = input_data,
		results = results,
		trigger_replay_paths = character()
	)
	expect_identical(sidecar$trigger_count, 0L)
	expect_identical(sidecar$results, results)
	expect_identical(sidecar$input_data, input_data)
	expect_length(sidecar$trigger_replay_paths, 0L)
	expect_error(
		todo33_make_search_run_sidecar(
			provenance_before = captured, provenance_after = captured,
			run_spec = list(alpha = 0.10), input_data = input_data,
			results = data.frame(seed = c(20261301L, 20261301L), trigger = c(FALSE, TRUE))
		),
		"unique seeds"
	)
	expect_error(
		todo33_make_search_run_sidecar(
			provenance_before = captured, provenance_after = captured,
			run_spec = list(alpha = 0.10), input_data = input_data,
			results = data.frame(seed = NA_integer_, trigger = FALSE)
		),
		"unique seeds"
	)
	expect_error(
		todo33_make_search_run_sidecar(
			provenance_before = captured, provenance_after = captured,
			run_spec = list(alpha = 0.10), input_data = input_data,
			results = data.frame(seed = 20261301L, trigger = NA)
		),
		"non-missing trigger outcomes"
	)
	positive_results <- data.frame(seed = 20261303L, trigger = TRUE)
	expect_error(
		todo33_make_search_run_sidecar(
			provenance_before = captured, provenance_after = captured,
			run_spec = list(alpha = 0.10), input_data = input_data,
			results = positive_results
		),
		"positive trigger results require at least one replay bundle"
	)
	missing_replay_path <- tempfile("todo33-missing-trigger-replay-")
	expect_false(file.exists(missing_replay_path))
	expect_error(
		todo33_make_search_run_sidecar(
			provenance_before = captured, provenance_after = captured,
			run_spec = list(alpha = 0.10), input_data = input_data,
			results = positive_results, trigger_replay_paths = missing_replay_path
		),
		"replay paths must identify existing replay bundle files"
	)

	path <- file.path(tempdir(), paste0("todo33-negative-run-", Sys.getpid(), ".rds"))
	on.exit(unlink(path), add = TRUE)
	todo33_write_search_run_sidecar(path, sidecar)
	expect_identical(readRDS(path), sidecar)
	expect_error(todo33_write_search_run_sidecar(path, sidecar), "refusing to overwrite")
})
