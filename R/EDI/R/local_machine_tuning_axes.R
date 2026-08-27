#' Per-axis tuners for \code{tune_EDI_for_this_machine()}
#'
#' \code{local_machine_optimization.md} TODO-4. Built on the harness in
#' \code{local_machine_tuning_harness.R}. This file implements all four
#' planned axes: cold start (binary, per-class, no per-n layer), warm
#' start (binary, per-class *and* per-operation, with TODO-2's
#' n-conditioned layer made reachable), optimizer algorithm (categorical,
#' with an all-replicates-converge guard whose oracle is an injected
#' argument -- no generic "did this fit converge" accessor exists on
#' `Inference` objects yet; that's `optimizer_diagnostics_report.md`'s
#' still-open diagnostics chain, not this plan's scope to build), and
#' parallel crossover-n (blocked, not interleaved, timing -- a fork
#' cluster's own setup cost would swamp per-replicate interleaving; see
#' `edi_tuning_blocked_ab()`'s own rationale). The parallel axis's other
#' two tunables from the plan's Architecture section -- best default core
#' count (not just "does *a* fixed K beat serial"), and fork-cluster vs.
#' mirai dispatch preference -- remain open; see that TODO's own notes.
#'
#' @keywords internal
#' @noRd
NULL

#' Shared engine: find binary-setting deviations via interleaved timing
#'
#' Axis-agnostic driver for any TRUE/FALSE performance setting that varies
#' per inference class and (optionally) per sample size: for every family x
#' n-grid cell, interleaved-time the class's *current* setting against its
#' flipped candidate, and keep the flip only if
#' \code{\link{edi_tuning_accept_candidate}} accepts it. Both cold-start and
#' (once wired) warm-start plug into this.
#'
#' @param families A data.frame with \code{class}/\code{response_type}
#'   columns (see \code{\link{edi_tuning_live_families}}), already filtered
#'   to the classes this axis actually governs.
#' @param n_grid Integer vector of sample sizes to test each family at.
#' @param reps Replicates per A/B cell (passed to
#'   \code{\link{edi_tuning_interleaved_ab}}).
#' @param get_current_setting \code{function(class, n) -> logical}: the
#'   setting currently in effect for this class at this sample size
#'   (shipped default or any already-applied override; \code{n} matters for
#'   axes with an n-conditioned layer, e.g. warm start -- axes without one,
#'   e.g. cold start, can just ignore the second argument).
#' @param run_setting \code{function(class, response_type, n, setting,
#'   seed)}: performs one timed unit of work under \code{setting} (return
#'   value ignored; called for its side effect/elapsed time only).
#' @param min_rel_improvement,iqr_multiplier Passed to
#'   \code{\link{edi_tuning_accept_candidate}}.
#' @param seed_fn \code{function(class, n) -> integer}: seed used for both
#'   the baseline and candidate run of a given cell, so they see identical
#'   synthetic data (default: deterministic hash of class name + n).
#' @param on_cell_done Optional \code{function(secs)} called once after each
#'   (family, n) cell finishes, with that cell's total elapsed wall-clock
#'   seconds -- the hook \code{tune_EDI_for_this_machine()} uses to drive
#'   its progress bar. \code{NULL} (default) means no callback.
#' @return A list of accepted deviations, each
#'   \code{list(class, response_type, n, from, to, rel_improvement,
#'   median_baseline, median_candidate)}. Empty list if nothing beat the
#'   noise margin anywhere.
#' @keywords internal
#' @noRd
edi_tuning_tune_binary_axis = function(families, n_grid, reps,
                                        get_current_setting, run_setting,
                                        min_rel_improvement = 0.05, iqr_multiplier = 2,
                                        seed_fn = NULL, on_cell_done = NULL) {
	checkmate::assertDataFrame(families, min.rows = 0L)
	checkmate::assertSubset(c("class", "response_type"), names(families))
	checkmate::assertIntegerish(n_grid, min.len = 1L, lower = 1L)
	checkmate::assertFunction(get_current_setting, nargs = 2L)
	checkmate::assertFunction(run_setting)
	if (!is.null(on_cell_done)) checkmate::assertFunction(on_cell_done, nargs = 1L)
	if (is.null(seed_fn)) {
		seed_fn = function(class, n) {
			edi_tuning_default_seed(class, n)
		}
	}

	deviations = list()
	for (i in seq_len(nrow(families))) {
		cl = families$class[[i]]
		rt = families$response_type[[i]]
		for (n in n_grid) {
			t_cell = proc.time()[["elapsed"]]
			current = isTRUE(get_current_setting(cl, n))
			candidate = !current
			seed = seed_fn(cl, n)
			ab = edi_tuning_interleaved_ab(
				fn_a = function() run_setting(cl, rt, n, current, seed),
				fn_b = function() run_setting(cl, rt, n, candidate, seed),
				reps = reps
			)
			acc = edi_tuning_accept_candidate(ab$times_a, ab$times_b, min_rel_improvement, iqr_multiplier)
			if (!is.null(on_cell_done)) on_cell_done(proc.time()[["elapsed"]] - t_cell)
			if (acc$accept) {
				deviations[[length(deviations) + 1L]] = list(
					class = cl, response_type = rt, n = n,
					from = current, to = candidate,
					rel_improvement = acc$rel_improvement,
					median_baseline = acc$median_baseline,
					median_candidate = acc$median_candidate
				)
			}
		}
	}
	deviations
}

#' Which live families the cold-start axis is meaningful for
#'
#' Restricted to classes matched by \code{get_cold_start_dispatch_policy()}'s
#' own \code{inference_class_overrides} patterns -- the set already known to
#' expose a real \code{smart_cold_start} C++ branch (see
#' \code{cold_starts.md}). Benchmarking classes outside this set would mean
#' guessing whether their kernel even reads the cold-start dispatch table.
#'
#' @return A data.frame (\code{class}, \code{response_type}) subset of
#'   \code{\link{edi_tuning_live_families}}.
#' @keywords internal
#' @noRd
edi_tuning_cold_start_families = function() {
	patterns = names(get_cold_start_dispatch_policy()$inference_class_overrides)
	families = edi_tuning_live_families()
	matches = vapply(families$class, function(cl) {
		any(vapply(patterns, function(p) grepl(p, cl, perl = TRUE), logical(1)))
	}, logical(1))
	families[matches, , drop = FALSE]
}

#' Run one cold-start timing unit: construct an `Inference` object under a
#' forced `smart_cold_start` setting
#'
#' Temporarily overrides \code{class}'s cold-start policy to \code{setting},
#' constructs the class on a fresh synthetic experiment, and restores the
#' pre-call policy state (\code{on.exit}) so this is safe to interleave with
#' any other cold-start policy in effect.
#'
#' @keywords internal
#' @noRd
edi_tuning_cold_start_run_setting = function(class, response_type, n, setting, seed) {
	# Snapshot/restore the raw config directly rather than via
	# set_cold_start_dispatch_policy(prior, reset = TRUE): reset = TRUE ignores
	# its `policy` argument entirely and restores the package's *built-in*
	# default, which would silently discard any override a caller already had
	# in effect before this function ran.
	prior = edi_env$cold_start_dispatch_policy_config
	on.exit(edi_env$cold_start_dispatch_policy_config <- prior, add = TRUE)
	set_cold_start_dispatch_policy(list(
		inference_class_overrides = stats::setNames(setting, paste0("^", class, "$"))
	))
	des = edi_tuning_synthetic_experiment(response_type, n = n, seed = seed)
	generator = get(class, envir = asNamespace("EDI"), inherits = FALSE)
	invisible(generator$new(des))
}

#' Tune the cold-start axis: which classes benefit from a naive zero start
#' on this machine
#'
#' For every class \code{\link{edi_tuning_cold_start_families}} names, times
#' the class's current cold-start setting against its flipped candidate,
#' interleaved, across \code{n_grid}, and keeps only flips that clear
#' \code{\link{edi_tuning_accept_candidate}}'s noise margin.
#'
#' @param n_grid,reps,min_rel_improvement,iqr_multiplier See
#'   \code{\link{edi_tuning_tune_binary_axis}}.
#' @param families Override the default family set (mainly for tests);
#'   \code{NULL} uses \code{\link{edi_tuning_cold_start_families}}.
#' @return A list of accepted deviations from the shipped cold-start policy
#'   (see \code{\link{edi_tuning_tune_binary_axis}}'s return value); each
#'   entry's \code{from}/\code{to} are the \code{smart_cold_start} logical.
#' @keywords internal
#' @noRd
edi_tuning_tune_cold_start = function(n_grid = c(50L, 200L, 1000L), reps = 5L,
                                       min_rel_improvement = 0.05, iqr_multiplier = 2,
                                       families = NULL, on_cell_done = NULL) {
	if (is.null(families)) families = edi_tuning_cold_start_families()
	edi_tuning_tune_binary_axis(
		families = families,
		n_grid = n_grid,
		reps = reps,
		get_current_setting = function(cl, n) edi_cold_start_dispatch_policy(cl),
		run_setting = edi_tuning_cold_start_run_setting,
		min_rel_improvement = min_rel_improvement,
		iqr_multiplier = iqr_multiplier,
		on_cell_done = on_cell_done
	)
}

#' The generic per-operation resampling call the warm-start axis times
#'
#' One representative public method per warm-start operation, called with a
#' small \code{B}/\code{r} (benchmark speed, not accuracy) and
#' \code{show_progress = FALSE}. These are the same method names
#' \code{helper-inference-migration-harness.R}'s
#' \code{inference_migration_method_calls} already exercises across every
#' migrated class, so reusing them here rides an already-audited generic
#' entry point rather than inventing a second one.
#'
#' @keywords internal
#' @noRd
EDI_TUNING_WARM_START_OPERATION_CALLS = list(
	jackknife = list(method = "compute_jackknife_estimate", args = list()),
	# min_number_usable_samples is pinned explicitly (not left at each
	# class's own default) because InferenceSurvivalDepCensTransform's
	# compute_bootstrap_confidence_interval defaults it to 10 -- above this
	# benchmark's B = 9L, which trips assertBootstrapArgs()'s
	# min_number_usable_samples <= B check (confirmed as the cause of
	# tune_EDI_for_this_machine()'s example failing on CI, 2026-08-24).
	# Every other class's default is 5L, so 5L is safe everywhere.
	non_param_boot = list(method = "compute_bootstrap_confidence_interval",
	                       args = list(alpha = 0.2, B = 9L, show_progress = FALSE,
	                                   min_number_usable_samples = 5L)),
	bayesian_boot = list(method = "compute_bayesian_bootstrap_confidence_interval",
	                      args = list(alpha = 0.2, B = 9L, show_progress = FALSE)),
	param_boot = list(method = "compute_param_bootstrap_confidence_interval",
	                   args = list(alpha = 0.2, B = 9L, show_progress = FALSE)),
	rand = list(method = "compute_rand_confidence_interval",
	            args = list(alpha = 0.2, r = 9L, show_progress = FALSE))
)

#' Classes excluded from specific warm-start operations for cost reasons
#' (not correctness -- see each entry's comment)
#'
#' A named list, operation -> character vector of class names to drop from
#' \code{\link{edi_tuning_warm_start_families}(operation)}'s result. Unlike
#' \code{infer_inference_requires_kk_matching_design()}/
#' \code{infer_inference_requires_blocking_design()} (which exclude a class
#' from tuning entirely because the synthetic experiment genuinely can't
#' construct it), this is scoped to one operation only -- the class is fine,
#' fast, and still benchmarked on its other operations.
#'
#' @keywords internal
#' @noRd
EDI_TUNING_WARM_START_OPERATION_EXCLUSIONS = list(
	# 2026-08-27: InferencePropZeroOneInflatedBetaRegr's jackknife (unlike
	# its other resampling operations -- rand/non_param_boot/bayesian_boot/
	# param_boot all benchmark in well under a second) rebuilds a fresh
	# sub-Inference object per leave-one-out fold
	# (supports_reusable_bootstrap_worker() = FALSE for this class) and
	# reruns the full fit_with_hardened_qr_column_dropping() column-
	# selection search from scratch each time. Confirmed via direct
	# profiling: the raw fast_zero_one_inflated_beta_cpp() fit converges
	# correctly and fast (~3ms) in isolation on the exact same data: the
	# ~50x per-fold slowdown is entirely the surrounding column-selection
	# machinery being redone from scratch every fold, not a numerical
	# problem. For a synthetic dataset with no y = 0/1 boundary
	# observations at all (this tuning benchmark's small-n proportion DGP
	# hits exactly that at n = 50), that made a single jackknife call take
	# several seconds and blocked a full tuning run for many minutes. Not a
	# quick fix -- would need a real get_bootstrap_worker_spec()-based
	# reuse implementation for this class, out of scope here.
	jackknife = "InferencePropZeroOneInflatedBetaRegr"
)

#' Does a class (its own generator or an ancestor) define this public method?
#'
#' @keywords internal
#' @noRd
edi_tuning_class_has_public_method = function(class, method_name) {
	generator = get(class, envir = asNamespace("EDI"), inherits = FALSE)
	current = generator
	while (!is.null(current)) {
		if (method_name %in% names(current$public_methods)) return(TRUE)
		current = current$get_inherit()
	}
	FALSE
}

#' Which live families a given warm-start operation is meaningful for
#'
#' Restricted to classes that actually define the operation's generic
#' method (\code{\link{EDI_TUNING_WARM_START_OPERATION_CALLS}}) -- most
#' concrete classes support \code{jackknife}/\code{non_param_boot}, but
#' \code{bayesian_boot}/\code{param_boot}/\code{rand} are capability-gated
#' and only a subset implement them.
#'
#' @param operation One of \code{names(EDI_TUNING_WARM_START_OPERATION_CALLS)}.
#' @return A data.frame (\code{class}, \code{response_type}) subset of
#'   \code{\link{edi_tuning_live_families}}.
#' @keywords internal
#' @noRd
edi_tuning_warm_start_families = function(operation) {
	spec = EDI_TUNING_WARM_START_OPERATION_CALLS[[operation]]
	if (is.null(spec)) {
		stop(sprintf("Unknown warm-start operation `%s`.", operation), call. = FALSE)
	}
	families = edi_tuning_live_families()
	keep = vapply(families$class, edi_tuning_class_has_public_method,
	              logical(1), method_name = spec$method)
	families = families[keep, , drop = FALSE]
	excluded = EDI_TUNING_WARM_START_OPERATION_EXCLUSIONS[[operation]]
	if (!is.null(excluded)) {
		families = families[!(families$class %in% excluded), , drop = FALSE]
	}
	families
}

#' Run one warm-start timing unit: perform one resampling operation under a
#' forced per-class, per-operation warm-start setting
#'
#' Temporarily overrides \code{class}'s warm-start policy for \code{operation}
#' to \code{setting} (unconditionally, i.e. \code{n_min = -Inf}/\code{n_max =
#' Inf} -- overriding *this cell's* decision regardless of where it falls in
#' the built-in n-conditioned table), constructs the class on a fresh
#' synthetic experiment, runs the operation's generic call, and restores the
#' pre-call policy snapshot directly (same rationale as the cold-start
#' restore: \code{reset = TRUE} would discard any override already in
#' effect). A method call that errors as "not implemented/supported" for
#' this class is swallowed (not every class implements every operation, and
#' \code{\link{edi_tuning_warm_start_families}} is the intended filter --
#' this is a defensive fallback, not the primary gate).
#'
#' @keywords internal
#' @noRd
edi_tuning_warm_start_run_setting = function(class, response_type, n, setting, seed, operation) {
	spec = EDI_TUNING_WARM_START_OPERATION_CALLS[[operation]]
	prior = edi_env$warm_start_dispatch_policy_config
	on.exit(edi_env$warm_start_dispatch_policy_config <- prior, add = TRUE)
	set_warm_start_dispatch_policy(stats::setNames(
		list(list(inference_class_overrides = stats::setNames(setting, paste0("^", class, "$")))),
		operation
	))
	des = edi_tuning_synthetic_experiment(response_type, n = n, seed = seed)
	generator = get(class, envir = asNamespace("EDI"), inherits = FALSE)
	inf = generator$new(des)
	# Returns the operation's own result (a CI, a point estimate, ...) rather than
	# discarding it -- edi_tuning_interleaved_ab() already captures every call's
	# return value (results_a/results_b), and TODO-8's correctness gate needs a
	# real fitted operation's output to compare across settings.
	tryCatch(
		do.call(inf[[spec$method]], spec$args),
		error = function(e) {
			if (!grepl("not implemented|not supported|only supported|does not support|does not expose|Must be implemented",
			           conditionMessage(e))) {
				stop(e)
			}
			NULL
		}
	)
}

#' Tune the warm-start axis for one resampling operation: which classes
#' benefit from disabling warm starts on this machine
#'
#' For every class \code{\link{edi_tuning_warm_start_families}} names for
#' \code{operation}, times the class's current warm-start setting (at each
#' \code{n} -- the built-in policy is n-conditioned, so "current" can differ
#' across the grid) against its flipped candidate, interleaved, and keeps
#' only flips that clear \code{\link{edi_tuning_accept_candidate}}'s noise
#' margin. Run once per operation (\code{jackknife}, \code{non_param_boot},
#' \code{bayesian_boot}, \code{param_boot}, \code{rand}) -- the five
#' operations have independent dispatch tables and independent resampling
#' cost profiles, so they are not combined into one call.
#'
#' @param operation One of \code{names(EDI_TUNING_WARM_START_OPERATION_CALLS)}.
#' @param n_grid,reps,min_rel_improvement,iqr_multiplier See
#'   \code{\link{edi_tuning_tune_binary_axis}}.
#' @param families Override the default family set (mainly for tests);
#'   \code{NULL} uses \code{\link{edi_tuning_warm_start_families}(operation)}.
#' @return A list of accepted deviations (see
#'   \code{\link{edi_tuning_tune_binary_axis}}'s return value); each entry's
#'   \code{from}/\code{to} are the warm-start logical for this operation at
#'   that entry's \code{n}.
#' @keywords internal
#' @noRd
edi_tuning_tune_warm_start = function(operation, n_grid = c(50L, 500L), reps = 5L,
                                       min_rel_improvement = 0.05, iqr_multiplier = 2,
                                       families = NULL, on_cell_done = NULL) {
	checkmate::assertChoice(operation, names(EDI_TUNING_WARM_START_OPERATION_CALLS))
	if (is.null(families)) families = edi_tuning_warm_start_families(operation)
	edi_tuning_tune_binary_axis(
		families = families,
		n_grid = n_grid,
		reps = reps,
		get_current_setting = function(cl, n) edi_warm_start_dispatch_policy(cl, operation, n),
		run_setting = function(cl, rt, n, setting, seed) {
			edi_tuning_warm_start_run_setting(cl, rt, n, setting, seed, operation)
		},
		min_rel_improvement = min_rel_improvement,
		iqr_multiplier = iqr_multiplier,
		on_cell_done = on_cell_done
	)
}

#' Shared engine: find categorical-setting deviations via interleaved
#' timing, gated on a convergence guard
#'
#' Generalizes \code{\link{edi_tuning_tune_binary_axis}} to more than two
#' candidate settings, and adds an all-replicates-converge guard: a
#' candidate only wins a cell if it timed faster (past the usual noise
#' margin) AND \code{run_setting} reported convergence (\code{isTRUE()}) on
#' every one of that cell's replicates -- speed never trumps a convergence
#' failure. Among candidates that both converge-every-rep and beat the
#' noise margin, the one with the largest relative improvement wins that
#' cell. The optimizer-algorithm axis plugs into this.
#'
#' @param families,n_grid,reps,min_rel_improvement,iqr_multiplier,seed_fn
#'   See \code{\link{edi_tuning_tune_binary_axis}}.
#' @param candidates Character vector of every settable value for this axis
#'   (e.g. \code{c("newton_raphson", "lbfgs", "irls")}); must have length
#'   >= 2.
#' @param get_current_setting \code{function(class, n) -> character(1)}: the
#'   setting currently in effect.
#' @param run_setting \code{function(class, response_type, n, setting, seed)
#'   -> logical(1)}: performs one timed unit of work under \code{setting}
#'   and returns whether it converged (its return value is read from
#'   \code{\link{edi_tuning_interleaved_ab}}'s captured results, not just
#'   timed).
#' @return A list of accepted deviations, each \code{list(class,
#'   response_type, n, from, to, rel_improvement, median_baseline,
#'   median_candidate)}.
#' @keywords internal
#' @noRd
edi_tuning_tune_categorical_axis = function(families, n_grid, reps, candidates,
                                             get_current_setting, run_setting,
                                             min_rel_improvement = 0.05, iqr_multiplier = 2,
                                             seed_fn = NULL, on_cell_done = NULL) {
	checkmate::assertDataFrame(families, min.rows = 0L)
	checkmate::assertSubset(c("class", "response_type"), names(families))
	checkmate::assertIntegerish(n_grid, min.len = 1L, lower = 1L)
	checkmate::assertCharacter(candidates, min.len = 2L, any.missing = FALSE, unique = TRUE)
	checkmate::assertFunction(get_current_setting, nargs = 2L)
	checkmate::assertFunction(run_setting)
	if (!is.null(on_cell_done)) checkmate::assertFunction(on_cell_done, nargs = 1L)
	if (is.null(seed_fn)) {
		seed_fn = function(class, n) {
			edi_tuning_default_seed(class, n)
		}
	}

	deviations = list()
	for (i in seq_len(nrow(families))) {
		cl = families$class[[i]]
		rt = families$response_type[[i]]
		for (n in n_grid) {
			# One progress "cell" is one (family, n) -- fired once after *all*
			# candidates for that cell are timed, not once per candidate, so the
			# cell count is knowable up front without consulting the current
			# setting (edi_tuning_count_cells()).
			t_cell = proc.time()[["elapsed"]]
			current = as.character(get_current_setting(cl, n))
			seed = seed_fn(cl, n)
			best = NULL
			for (candidate in setdiff(candidates, current)) {
				ab = edi_tuning_interleaved_ab(
					fn_a = function() run_setting(cl, rt, n, current, seed),
					fn_b = function() run_setting(cl, rt, n, candidate, seed),
					reps = reps
				)
				candidate_converged_every_rep = all(vapply(ab$results_b, isTRUE, logical(1)))
				if (!candidate_converged_every_rep) next
				acc = edi_tuning_accept_candidate(ab$times_a, ab$times_b, min_rel_improvement, iqr_multiplier)
				if (acc$accept && (is.null(best) || acc$rel_improvement > best$rel_improvement)) {
					best = list(
						class = cl, response_type = rt, n = n,
						from = current, to = candidate,
						rel_improvement = acc$rel_improvement,
						median_baseline = acc$median_baseline,
						median_candidate = acc$median_candidate
					)
				}
			}
			if (!is.null(on_cell_done)) on_cell_done(proc.time()[["elapsed"]] - t_cell)
			if (!is.null(best)) deviations[[length(deviations) + 1L]] = best
		}
	}
	deviations
}

#' Every algorithm the optimizer axis may choose among
#'
#' @keywords internal
#' @noRd
EDI_TUNING_OPTIMIZER_ALGORITHM_CANDIDATES = c("newton_raphson", "lbfgs", "irls")

#' Which live families the optimizer-algorithm axis is meaningful for
#'
#' Restricted to classes matched by \code{get_optimization_dispatch_policy()}'s
#' own \code{inference_class_overrides} patterns -- the set already known to
#' have an empirically-chosen non-default algorithm, per the same
#' "only benchmark classes we know the dispatch table actually governs"
#' rule \code{\link{edi_tuning_cold_start_families}} follows.
#'
#' @return A data.frame (\code{class}, \code{response_type}) subset of
#'   \code{\link{edi_tuning_live_families}}.
#' @keywords internal
#' @noRd
edi_tuning_optimizer_algorithm_families = function() {
	patterns = names(get_optimization_dispatch_policy()$inference_class_overrides)
	families = edi_tuning_live_families()
	matches = vapply(families$class, function(cl) {
		any(vapply(patterns, function(p) grepl(p, cl, perl = TRUE), logical(1)))
	}, logical(1))
	families[matches, , drop = FALSE]
}

#' Run one optimizer-algorithm timing unit: construct an `Inference` object
#' under a forced algorithm, and report whether it converged
#'
#' Temporarily overrides \code{class}'s optimizer-algorithm policy to
#' \code{algorithm}, constructs the class on a fresh synthetic experiment,
#' and restores the pre-call policy snapshot directly (same rationale as the
#' cold-/warm-start restores). \strong{Convergence is read via
#' \code{converged_fn(inf)}, a caller-supplied oracle} -- there is no
#' generic, class-API-independent "did this fit converge" accessor on
#' \code{Inference} objects yet (that is
#' \code{optimizer_diagnostics_report.md}'s still-open diagnostics chain);
#' until it lands, callers must supply their own (e.g. reading a
#' class-specific private diagnostics field, or -- conservatively -- always
#' returning \code{TRUE} to disable the guard, which is unsafe and should
#' only be used for orchestration testing, never a real tuning run).
#'
#' @param converged_fn \code{function(inf) -> logical(1)}.
#' @keywords internal
#' @noRd
edi_tuning_optimizer_run_setting = function(class, response_type, n, algorithm, seed, converged_fn) {
	inf = edi_tuning_construct_under_optimizer(class, response_type, n, algorithm, seed)
	isTRUE(converged_fn(inf))
}

#' Construct an `Inference` object on a synthetic experiment under a forced
#' optimizer algorithm, restoring the prior policy on exit; returns the object
#'
#' Shared by \code{\link{edi_tuning_optimizer_run_setting}} (timing +
#' convergence) and the TODO-8 correctness gate (re-fit and compare
#' estimates). Note the policy is restored when this function returns, so
#' the object's \emph{construction-time} fit used \code{algorithm}, but any
#' later lazy re-fit it performs would see the restored policy -- callers
#' that need a second fit under the same algorithm must call this again.
#'
#' @keywords internal
#' @noRd
edi_tuning_construct_under_optimizer = function(class, response_type, n, algorithm, seed) {
	prior = edi_env$optimization_dispatch_policy_config
	on.exit(edi_env$optimization_dispatch_policy_config <- prior, add = TRUE)
	set_optimization_dispatch_policy(list(
		inference_class_overrides = stats::setNames(algorithm, paste0("^", class, "$"))
	))
	des = edi_tuning_synthetic_experiment(response_type, n = n, seed = seed)
	generator = get(class, envir = asNamespace("EDI"), inherits = FALSE)
	generator$new(des)
}

#' Tune the optimizer-algorithm axis: which classes benefit from a
#' different solver on this machine
#'
#' For every class \code{\link{edi_tuning_optimizer_algorithm_families}}
#' names, times the class's current algorithm against every other candidate
#' in \code{candidates}, interleaved, across \code{n_grid}, and keeps a
#' switch only if the candidate (a) converges on \strong{every} benchmark
#' replicate for that cell, per \code{converged_fn}, and (b) clears
#' \code{\link{edi_tuning_accept_candidate}}'s noise margin -- speed never
#' trumps a convergence failure. \strong{Requires a real \code{converged_fn}}
#' (see \code{\link{edi_tuning_optimizer_run_setting}}); this function does
#' not supply a default because none can be trusted generically yet.
#'
#' @param converged_fn \code{function(inf) -> logical(1)}, required.
#' @param n_grid,reps,min_rel_improvement,iqr_multiplier See
#'   \code{\link{edi_tuning_tune_categorical_axis}}.
#' @param candidates Defaults to
#'   \code{\link{EDI_TUNING_OPTIMIZER_ALGORITHM_CANDIDATES}}.
#' @param families Override the default family set (mainly for tests);
#'   \code{NULL} uses \code{\link{edi_tuning_optimizer_algorithm_families}}.
#' @return A list of accepted deviations (see
#'   \code{\link{edi_tuning_tune_categorical_axis}}'s return value); each
#'   entry's \code{from}/\code{to} are algorithm-name strings.
#' @keywords internal
#' @noRd
edi_tuning_tune_optimizer_algorithm = function(converged_fn, n_grid = c(50L, 500L), reps = 5L,
                                                min_rel_improvement = 0.05, iqr_multiplier = 2,
                                                candidates = EDI_TUNING_OPTIMIZER_ALGORITHM_CANDIDATES,
                                                families = NULL, on_cell_done = NULL) {
	checkmate::assertFunction(converged_fn, nargs = 1L)
	if (is.null(families)) families = edi_tuning_optimizer_algorithm_families()
	edi_tuning_tune_categorical_axis(
		families = families,
		n_grid = n_grid,
		reps = reps,
		candidates = candidates,
		get_current_setting = function(cl, n) edi_optimization_dispatch_policy(cl),
		run_setting = function(cl, rt, n, algorithm, seed) {
			edi_tuning_optimizer_run_setting(cl, rt, n, algorithm, seed, converged_fn)
		},
		min_rel_improvement = min_rel_improvement,
		iqr_multiplier = iqr_multiplier,
		on_cell_done = on_cell_done
	)
}

#' Map from the parallel-dispatch-policy's operation vocabulary to the
#' warm-start operation vocabulary
#'
#' \code{get_parallel_dispatch_policy()} only governs two operations,
#' \code{"bootstrap"} and \code{"rand_ci"}; these correspond exactly to the
#' warm-start axis's \code{non_param_boot} and \code{rand} operations, so
#' the parallel axis reuses \code{\link{EDI_TUNING_WARM_START_OPERATION_CALLS}}
#' for its actual timed method calls rather than defining a third generic
#' entry point.
#'
#' @keywords internal
#' @noRd
EDI_TUNING_PARALLEL_OPERATION_TO_WARM_START_OPERATION = c(bootstrap = "non_param_boot", rand_ci = "rand")

#' Which live families the parallel-crossover axis is meaningful for, for a
#' given operation
#'
#' Two filters, both required: (1) the class must implement the operation's
#' generic method (same filter warm start uses, via
#' \code{\link{edi_tuning_warm_start_families}}); (2) the class/response-type
#' combination must \strong{not} be forced serial by
#' \code{get_parallel_dispatch_policy()}'s blocklist for this operation
#' (\code{\link{edi_parallel_dispatch_policy}}) -- entries there exist for
#' \strong{parallel-safety}, not performance (see
#' \code{EDI/R/globals.R:515-528}), and this axis must never suggest
#' un-serializing them. This is the concrete enforcement of that constraint
#' for this axis specifically; the general "assert the tuner never emits a
#' diff touching the blocklist" test is TODO-6.
#'
#' @param operation One of \code{"bootstrap"}, \code{"rand_ci"}.
#' @return A data.frame (\code{class}, \code{response_type}) subset of
#'   \code{\link{edi_tuning_live_families}}.
#' @keywords internal
#' @noRd
edi_tuning_parallel_families = function(operation) {
	checkmate::assertChoice(operation, names(EDI_TUNING_PARALLEL_OPERATION_TO_WARM_START_OPERATION))
	ws_operation = EDI_TUNING_PARALLEL_OPERATION_TO_WARM_START_OPERATION[[operation]]
	families = edi_tuning_warm_start_families(ws_operation)
	if (nrow(families) == 0L) return(families)
	keep = mapply(function(cl, rt) {
		!isTRUE(edi_parallel_dispatch_policy(cl, rt, operation)$force_serial)
	}, families$class, families$response_type)
	families[keep, , drop = FALSE]
}

#' Run one parallel-axis timing unit: perform one resampling operation,
#' under whatever core count is currently active
#'
#' Deliberately does \strong{not} touch \code{set_num_cores()} itself --
#' the caller is responsible for setting the core count once per block (see
#' \code{\link{edi_tuning_tune_parallel_crossover}}'s \code{setup_a}/
#' \code{setup_b} use of \code{\link{edi_tuning_blocked_ab}}), since
#' creating/tearing down a real fork cluster on every replicate would
#' measure cluster-startup noise instead of steady-state parallel
#' throughput -- the entire reason this axis uses blocked, not interleaved,
#' timing.
#'
#' @keywords internal
#' @noRd
edi_tuning_parallel_run_setting = function(class, response_type, n, seed, operation) {
	ws_operation = EDI_TUNING_PARALLEL_OPERATION_TO_WARM_START_OPERATION[[operation]]
	spec = EDI_TUNING_WARM_START_OPERATION_CALLS[[ws_operation]]
	des = edi_tuning_synthetic_experiment(response_type, n = n, seed = seed)
	generator = get(class, envir = asNamespace("EDI"), inherits = FALSE)
	inf = generator$new(des)
	# 2026-08-27: a class passing edi_tuning_parallel_families()'s method-
	# existence filter is necessary but not sufficient -- it can still throw
	# a legitimate "not implemented for this response type/estimand" error
	# at call time (e.g. InferenceOrdinal*'s randomization CI, unsupported
	# for ordinal model-coefficient estimands). edi_tuning_warm_start_run_
	# setting() above already tolerates exactly this via the same tryCatch/
	# regex; this sibling function lacked it entirely, so the same class of
	# error that the warm-start axis silently skips instead propagated
	# uncaught here and killed the whole tuning run mid-parallel-axis
	# (confirmed via a real run: InferenceOrdinal*'s compute_rand_
	# confidence_interval() at the rand_ci parallel cell, cell 876/1056).
	tryCatch(
		do.call(inf[[spec$method]], spec$args),
		error = function(e) {
			if (!grepl("not implemented|not supported|only supported|does not support|does not expose|Must be implemented",
			           conditionMessage(e))) {
				stop(e)
			}
			NULL
		}
	)
	invisible(NULL)
}

#' Tune the parallel-crossover axis: the smallest sample size at which a
#' fork cluster beats serial execution, per family
#'
#' For every class \code{\link{edi_tuning_parallel_families}} names for
#' \code{operation}, scans \code{n_grid} in ascending order and, at each
#' \code{n}, blocked-times (\code{\link{edi_tuning_blocked_ab}} --
#' \strong{not} interleaved; see that function's own rationale) a
#' \code{reps}-replicate serial block (\code{num_cores = 1}) against a
#' \code{reps}-replicate parallel block (\code{num_cores = num_cores}),
#' each block paying its own \code{set_num_cores()} cost exactly once via
#' \code{setup_a}/\code{setup_b}. The smallest \code{n} where the parallel
#' block clears \code{\link{edi_tuning_accept_candidate}}'s noise margin is
#' that family's crossover point; the scan stops there (larger \code{n}
#' only makes parallel's advantage larger, per the cost model this axis is
#' built on). A family with no crossover anywhere in \code{n_grid} is
#' reported as \code{crossover_n = NA} (parallel never won at any tested
#' size for this family). \code{a_first} alternates across cells (by
#' family index x n-grid index parity) so the same side doesn't
#' systematically get to run cold every time. The core count is always
#' restored to its pre-call value on exit, including on error, so a
#' benchmarking failure never leaves a stray fork cluster behind.
#'
#' @param operation One of \code{"bootstrap"}, \code{"rand_ci"}.
#' @param num_cores Core count to benchmark against serial (integer >= 2).
#' @param n_grid,reps,min_rel_improvement,iqr_multiplier See
#'   \code{\link{edi_tuning_tune_binary_axis}}.
#' @param families Override the default family set (mainly for tests);
#'   \code{NULL} uses \code{\link{edi_tuning_parallel_families}(operation)}.
#' @return A list with one entry per family that has a crossover point,
#'   each \code{list(class, response_type, operation, num_cores,
#'   crossover_n, rel_improvement)}. Families with no crossover in
#'   \code{n_grid} are omitted (not reported with \code{NA}) -- \code{NULL}
#'   deviations carry no persistable information, matching every other
#'   axis's "only store real deviations" convention.
#' @keywords internal
#' @noRd
edi_tuning_tune_parallel_crossover = function(operation, num_cores, n_grid = c(200L, 1000L, 5000L), reps = 5L,
                                               min_rel_improvement = 0.05, iqr_multiplier = 2,
                                               families = NULL, on_cell_done = NULL) {
	checkmate::assertChoice(operation, names(EDI_TUNING_PARALLEL_OPERATION_TO_WARM_START_OPERATION))
	checkmate::assertCount(num_cores, positive = TRUE)
	if (num_cores < 2L) {
		stop("num_cores must be >= 2 to benchmark parallel against serial.", call. = FALSE)
	}
	checkmate::assertIntegerish(n_grid, min.len = 1L, lower = 1L)
	if (!is.null(on_cell_done)) checkmate::assertFunction(on_cell_done, nargs = 1L)
	if (is.null(families)) families = edi_tuning_parallel_families(operation)

	n_grid = sort(unique(as.integer(n_grid)))
	prior_cores = get_num_cores()
	on.exit(set_num_cores(prior_cores), add = TRUE)

	deviations = list()
	for (i in seq_len(nrow(families))) {
		cl = families$class[[i]]
		rt = families$response_type[[i]]
		for (j in seq_along(n_grid)) {
			n = n_grid[[j]]
			seed = edi_tuning_default_seed(cl, n)
			a_first = ((i + j) %% 2L) == 0L
			t_cell = proc.time()[["elapsed"]]

			ab = edi_tuning_blocked_ab(
				fn_a = function() edi_tuning_parallel_run_setting(cl, rt, n, seed, operation),
				fn_b = function() edi_tuning_parallel_run_setting(cl, rt, n, seed, operation),
				reps = reps,
				a_first = a_first,
				setup_a = function() set_num_cores(1L),
				setup_b = function() set_num_cores(num_cores)
			)
			acc = edi_tuning_accept_candidate(ab$times_a, ab$times_b, min_rel_improvement, iqr_multiplier)
			if (!is.null(on_cell_done)) on_cell_done(proc.time()[["elapsed"]] - t_cell)
			if (acc$accept) {
				deviations[[length(deviations) + 1L]] = list(
					class = cl, response_type = rt, operation = operation,
					num_cores = num_cores, crossover_n = n,
					rel_improvement = acc$rel_improvement
				)
				# Crossover found: the remaining (larger-n) grid points for this
				# family are skipped. So the up-front worst-case cell count
				# (edi_tuning_count_cells()) still reconciles with n_done, fire
				# the callback once per skipped point with NA elapsed time --
				# the caller's bar driver substitutes its running mean, so the
				# ETA is neither inflated nor deflated by skipped work.
				if (!is.null(on_cell_done) && j < length(n_grid)) {
					for (k in seq_len(length(n_grid) - j)) on_cell_done(NA_real_)
				}
				break
			}
		}
	}
	deviations
}
