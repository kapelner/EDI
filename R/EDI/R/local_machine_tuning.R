#' \code{tune_EDI_for_this_machine()}: the user-facing assembly
#'
#' \code{local_machine_optimization.md} TODO-5. Orchestrates the four
#' per-axis tuners in \code{local_machine_tuning_axes.R} over the harness in
#' \code{local_machine_tuning_harness.R}, drives the same rolling-update
#' screen progress bar as \code{InferenceSuite$run_all_inference()}, builds
#' setter-shaped policy diffs, persists them (\code{local_machine_tuning_persistence.R}),
#' applies them in-session, and returns a printable result object.
#'
#' @keywords internal
#' @noRd
NULL

#' @keywords internal
#' @noRd
EDI_TUNING_AXES = c("cold_start", "warm_start", "optimizer", "parallel")

#' Can the parallel axis run on this machine/session at all?
#'
#' Unix only (the fork-cluster path), with at least two logical cores.
#'
#' @keywords internal
#' @noRd
edi_tuning_parallel_axis_available = function() {
	identical(.Platform$OS.type, "unix") &&
		isTRUE(tryCatch(parallel::detectCores() >= 2L, error = function(e) FALSE))
}

#' Restrict a per-axis default family set to a user-supplied class list
#'
#' @keywords internal
#' @noRd
edi_tuning_restrict_families = function(families, class_filter) {
	if (is.null(class_filter)) return(families)
	families[families$class %in% class_filter, , drop = FALSE]
}

#' Under \code{effort = "quick"}, narrow the warm-start families to the
#' classes the shipped warm-start tables already name (largest known effect
#' sizes); the cold-start and optimizer families are already scoped that way
#' by construction, and the parallel axis is narrowed separately
#' (\code{bootstrap} operation only).
#'
#' @keywords internal
#' @noRd
edi_tuning_quick_warm_start_families = function(families) {
	pol = get_warm_start_dispatch_policy()
	patterns = character(0)
	for (op in setdiff(names(pol), "default")) {
		patterns = c(patterns, names(pol[[op]]$inference_class_overrides %||% character(0)))
		rules = pol[[op]]$n_conditioned_overrides %||% list()
		patterns = c(patterns, vapply(rules, `[[`, character(1), "pattern"))
	}
	patterns = unique(patterns)
	if (length(patterns) == 0L || nrow(families) == 0L) return(families)
	keep = vapply(families$class, function(cl) any(vapply(patterns, function(p) grepl(p, cl, perl = TRUE), logical(1))), logical(1))
	families[keep, , drop = FALSE]
}

#' Total number of progress cells a tuning run will execute, known up front
#'
#' One cell per (family, n) for the cold-start, optimizer, and each warm-start
#' operation; for the parallel axis, the \emph{worst case} of one per
#' (operation, num_cores, family, n) -- the parallel tuner fires its callback
#' for skipped grid points too (with \code{NA}), so \code{n_done} always
#' reaches this count. The same number drives the up-front wall-time
#' estimate and the live bar's denominator.
#'
#' @keywords internal
#' @noRd
edi_tuning_count_cells = function(plan) {
	total = 0L
	if (!is.null(plan$cold_start)) total = total + nrow(plan$cold_start$families) * length(plan$cold_start$n_grid)
	if (!is.null(plan$optimizer)) total = total + nrow(plan$optimizer$families) * length(plan$optimizer$n_grid)
	if (!is.null(plan$warm_start)) {
		for (op in names(plan$warm_start$families_by_operation)) {
			total = total + nrow(plan$warm_start$families_by_operation[[op]]) * length(plan$warm_start$n_grid)
		}
	}
	if (!is.null(plan$parallel)) {
		for (op in names(plan$parallel$families_by_operation)) {
			total = total + nrow(plan$parallel$families_by_operation[[op]]) * length(plan$parallel$n_grid) * length(plan$parallel$num_cores_grid)
		}
	}
	as.integer(total)
}

#' Nominal wall-time range per effort tier, for the up-front message
#'
#' @keywords internal
#' @noRd
edi_tuning_effort_nominal_time = function(effort) {
	switch(effort, quick = "roughly 2-5 minutes", standard = "roughly 15-30 minutes", thorough = "roughly 1-2 hours", "unknown")
}

#' Best-effort 1-minute load average, or \code{NA} where unavailable
#'
#' Linux: \code{/proc/loadavg}. macOS/other Unix: parse \code{uptime}.
#' Windows: \code{NA} (no cheap equivalent; the calibration check below
#' still runs there).
#'
#' @keywords internal
#' @noRd
edi_tuning_machine_load = function() {
	tryCatch({
		if (file.exists("/proc/loadavg")) {
			as.numeric(strsplit(readLines("/proc/loadavg", n = 1L, warn = FALSE), "\\s+")[[1]][[1]])
		} else if (identical(.Platform$OS.type, "unix")) {
			up = system("uptime", intern = TRUE)
			m = regmatches(up, regexpr("load averages?:\\s*[0-9.]+", up))
			if (length(m)) as.numeric(sub(".*:\\s*", "", m[[1]])) else NA_real_
		} else {
			NA_real_
		}
	}, error = function(e) NA_real_, warning = function(w) NA_real_)
}

#' Does the machine look too busy for a trustworthy tuning run? (TODO-7)
#'
#' Two independent signals, either of which trips the guard: (1) the
#' 1-minute load average exceeds \code{load_ratio_threshold} x logical
#' cores (other processes are already consuming a material share of the
#' CPU); (2) a quick calibration -- \code{calib_reps} timings of one small,
#' fixed, pure-R operation -- shows a coefficient of variation
#' (IQR / median) above \code{calib_cv_threshold}, i.e. the machine's
#' timing is noisy right now regardless of what load average says (this is
#' what catches contention on platforms where load average is \code{NA},
#' and frequency-scaling/thermal noise anywhere). A tuning run under
#' contention reproduces the exact problem this feature exists to fix --
#' defaults measured on a busy box -- so the caller refuses to run unless
#' \code{force = TRUE}.
#'
#' @return A list: \code{busy} (logical), \code{load_1min}, \code{cores},
#'   \code{load_ratio}, \code{calib_cv}, and \code{reasons} (character,
#'   empty when not busy).
#' @keywords internal
#' @noRd
edi_tuning_machine_looks_busy = function(load_ratio_threshold = 0.5, calib_cv_threshold = 0.5, calib_reps = 15L) {
	cores = tryCatch(as.integer(parallel::detectCores()), error = function(e) NA_integer_)
	load_1min = edi_tuning_machine_load()
	load_ratio = if (is.finite(load_1min) && is.finite(cores) && cores > 0L) load_1min / cores else NA_real_

	calib_times = vapply(seq_len(calib_reps), function(i) {
		t0 = proc.time()[["elapsed"]]
		x = matrix(seq_len(40000L) %% 97L, 200L, 200L) / 97
		invisible(sum(crossprod(x)))
		proc.time()[["elapsed"]] - t0
	}, numeric(1))
	med = stats::median(calib_times)
	calib_cv = if (is.finite(med) && med > 0) stats::IQR(calib_times) / med else NA_real_

	reasons = character(0)
	if (is.finite(load_ratio) && load_ratio > load_ratio_threshold) {
		reasons = c(reasons, sprintf("1-minute load average %.2f on %d cores (ratio %.2f > %.2f)", load_1min, cores, load_ratio, load_ratio_threshold))
	}
	if (is.finite(calib_cv) && calib_cv > calib_cv_threshold) {
		reasons = c(reasons, sprintf("calibration timings are noisy (IQR/median %.2f > %.2f)", calib_cv, calib_cv_threshold))
	}
	list(busy = length(reasons) > 0L, load_1min = load_1min, cores = cores, load_ratio = load_ratio, calib_cv = calib_cv, reasons = reasons)
}

#' Benchmark this machine and tune EDI's performance-policy defaults to it
#'
#' Every performance-policy default shipped in EDI (whether an inference
#' class uses a smart cold start, whether resampling reuses warm starts and
#' at what sample sizes, which optimizer algorithm a family uses, and at what
#' sample size parallel bootstrapping starts to beat serial) was measured
#' empirically on the maintainer's machine. Yours differs -- core count,
#' cache, BLAS, compiler flags -- so a policy that is net-positive there can
#' be net-negative here, and vice versa. This function re-runs those
#' benchmarks \strong{on your hardware}, decides the winning setting per
#' axis, saves the result to a per-user config file, and applies it
#' immediately; every later \code{library(EDI)} re-applies it. Hardware
#' changed? Re-run; it overwrites.
#'
#' @details
#' \strong{What is tuned.} Four axes, each against the corresponding
#' \code{get_*_dispatch_policy()} table: cold start
#' (\code{\link{get_cold_start_dispatch_policy}}), warm start per resampling
#' operation (\code{\link{get_warm_start_dispatch_policy}}), optimizer
#' algorithm (\code{\link{get_optimization_dispatch_policy}}), and the
#' parallel-vs-serial crossover sample size per family
#' (\code{\link{get_parallel_dispatch_policy}}). The bootstrap
#' confidence-interval \emph{type} policy is a statistical-validity table,
#' not a performance one, and is never touched; nor are entries in the
#' parallel policy's serial blocklist that exist for parallel safety.
#'
#' \strong{How a deviation is accepted.} Per axis, per (family, sample
#' size) cell, both settings are timed on identical synthetic data --
#' interleaved (A/B/A/B) for the cold-start/warm-start/optimizer axes, and
#' blocked (all serial reps, then all parallel reps) for the parallel axis,
#' whose fork-cluster setup cost rules out per-replicate interleaving. A
#' candidate displaces the shipped default only if its median time is at
#' least 5\% better \emph{and} that improvement exceeds twice the candidate's
#' own interquartile spread; ties keep the shipped default. The optimizer
#' axis additionally requires the candidate to have converged on every
#' replicate of the cell -- speed never trumps a convergence failure. Only
#' \emph{deviations} from the shipped defaults are stored, in the exact shape
#' the matching \code{set_*_dispatch_policy()} setter accepts, and they are
#' merged into (never replacing) the shipped tables.
#'
#' \strong{Progress.} A single progress bar with a running
#' estimated-time-left is redrawn in place as each benchmark cell completes
#' -- the same bar \code{InferenceSuite$run_all_inference()} shows.
#'
#' \strong{Correctness gate.} A timing win alone does not displace a shipped
#' default: every accepted deviation is re-fit once under \emph{both}
#' settings on identical synthetic data and the outputs compared (point
#' estimates for cold start/optimizer/parallel; the resampling operation's
#' own output, RNG-matched, for warm start). A disagreement -- or an
#' unverifiable comparison -- discards the deviation, with a
#' \code{warning()} naming it; discarded deviations are available on the
#' returned object via \code{attr(x, "discarded_by_correctness_gate")} and
#' are never written to the config file or applied.
#'
#' \strong{The optimizer axis and \code{converged_fn}.} There is not yet a
#' generic, class-independent accessor on an inference object that reports
#' whether its fit converged, so the optimizer axis needs you to supply one
#' as \code{converged_fn(inf)}. When \code{axes} is left \code{NULL} the
#' optimizer axis is included only if \code{converged_fn} is given; asking
#' for it explicitly without one is an error. An always-\code{TRUE}
#' \code{converged_fn} disables the convergence guard and is \strong{not}
#' appropriate for a real tuning run.
#'
#' \strong{The parallel axis.} Runs only on Unix-alikes with at least two
#' logical cores (it benchmarks a real fork cluster). Its preferred core
#' count is \emph{recorded only} -- never applied at package load -- you
#' still opt into parallelism with \code{\link{set_num_cores}}.
#'
#' \strong{Idle machine.} Run this on an otherwise idle machine; a tuning
#' run under contention measures the contention, not the hardware. Before
#' benchmarking, the function checks the 1-minute load average against the
#' core count and times a small fixed calibration operation for noise; if
#' either says the machine is busy it refuses to run (interactively, it
#' asks first) unless \code{force = TRUE}.
#'
#' @param effort One of \code{"standard"} (default; moderate sample-size
#'   grid and replicate count), \code{"quick"} (coarser grid, fewer
#'   replicates, warm-start families narrowed to those the shipped tables
#'   already name, parallel axis on the bootstrap operation only), or
#'   \code{"thorough"} (full grid, more replicates).
#' @param axes Which axes to tune: any subset of \code{"cold_start"},
#'   \code{"warm_start"}, \code{"optimizer"}, \code{"parallel"}. \code{NULL}
#'   (default) means all that are available here -- see Details for when
#'   the optimizer and parallel axes are included.
#' @param families Optional character vector of inference class names to
#'   restrict every axis to; \code{NULL} (default) tunes every class each
#'   axis governs.
#' @param n_grid Optional integer vector of sample sizes overriding the
#'   effort tier's grid.
#' @param reps Optional replicate count per timed cell overriding the
#'   effort tier's.
#' @param num_cores_grid Optional integer vector of core counts (each
#'   \eqn{\ge 2}) for the parallel axis; default \code{c(2, detectCores())}.
#' @param converged_fn \code{function(inf) -> logical(1)}, required for the
#'   optimizer axis (see Details).
#' @param quiet If \code{TRUE}, print nothing (no preamble, no progress bar,
#'   no summary).
#' @param dry_run If \code{TRUE}, run every benchmark and print the would-be
#'   policy changes, but write no file and apply nothing.
#' @param force If \code{FALSE} (default), refuse to run when the machine
#'   looks busy (see Details: "Idle machine") -- in an interactive session
#'   you are asked whether to proceed anyway; non-interactively it is an
#'   error. \code{TRUE} skips the check. Applies under \code{dry_run} too,
#'   since a dry run still benchmarks.
#' @return Invisibly, an \code{EDILocalMachineTuning} object: the policy
#'   diffs (\code{policy_diffs}), the raw per-axis deviations
#'   (\code{raw_deviations}), the hardware fingerprint, the effort/grid/reps
#'   used, timing, and the config file path -- printable via
#'   \code{print()}.
#' @seealso \code{\link{get_local_EDI_optimization}} to see what is saved,
#'   \code{\link{clear_local_EDI_optimization}} to return to shipped
#'   defaults; the underlying tables:
#'   \code{\link{get_cold_start_dispatch_policy}},
#'   \code{\link{get_warm_start_dispatch_policy}},
#'   \code{\link{get_optimization_dispatch_policy}},
#'   \code{\link{get_parallel_dispatch_policy}}.
#' @examples
#' \donttest{
#' # See what would change without writing anything. force = TRUE skips the
#' # idle-machine contention guard (see Details/`force` above) -- an example
#' # must not fail just because the machine running R CMD check happens to
#' # be busy (e.g. a shared CI runner); the guard itself has its own
#' # dedicated tests (test-local-machine-tuning-assembly.R).
#' res = tune_EDI_for_this_machine(effort = "quick", dry_run = TRUE, force = TRUE)
#' print(res)
#' }
#' @export
tune_EDI_for_this_machine = function(effort = c("standard", "quick", "thorough"),
                                     axes = NULL, families = NULL, n_grid = NULL, reps = NULL,
                                     num_cores_grid = NULL, converged_fn = NULL,
                                     quiet = FALSE, dry_run = FALSE, force = FALSE) {
	effort = match.arg(effort)
	checkmate::assertFlag(quiet)
	checkmate::assertFlag(dry_run)
	checkmate::assertFlag(force)
	if (!is.null(families)) checkmate::assertCharacter(families, min.len = 1L, any.missing = FALSE)
	if (!is.null(converged_fn)) checkmate::assertFunction(converged_fn, nargs = 1L)

	preset = edi_tuning_effort_presets()[[effort]]
	if (is.null(n_grid)) n_grid = preset$n_grid
	if (is.null(reps)) reps = preset$reps
	checkmate::assertIntegerish(n_grid, min.len = 1L, lower = 1L)
	checkmate::assertCount(reps, positive = TRUE)
	n_grid = sort(unique(as.integer(n_grid)))

	parallel_ok = edi_tuning_parallel_axis_available()
	if (is.null(axes)) {
		axes = c("cold_start", "warm_start",
		         if (!is.null(converged_fn)) "optimizer",
		         if (parallel_ok) "parallel")
	} else {
		checkmate::assertCharacter(axes, min.len = 1L, any.missing = FALSE, unique = TRUE)
		checkmate::assertSubset(axes, EDI_TUNING_AXES)
		if ("optimizer" %in% axes && is.null(converged_fn)) {
			stop("The optimizer axis requires `converged_fn` (a function(inf) -> logical(1)); see ?tune_EDI_for_this_machine.", call. = FALSE)
		}
		if ("parallel" %in% axes && !parallel_ok) {
			stop("The parallel axis needs a Unix-alike with >= 2 logical cores.", call. = FALSE)
		}
	}

	if ("parallel" %in% axes) {
		if (is.null(num_cores_grid)) {
			num_cores_grid = unique(c(2L, as.integer(parallel::detectCores())))
		}
		checkmate::assertIntegerish(num_cores_grid, min.len = 1L, lower = 2L, unique = TRUE)
		num_cores_grid = sort(as.integer(num_cores_grid))
	}

	# ---- Build the plan (families per axis) so n_total is known up front ----
	plan = list()
	if ("cold_start" %in% axes) {
		plan$cold_start = list(families = edi_tuning_restrict_families(edi_tuning_cold_start_families(), families), n_grid = n_grid)
	}
	if ("optimizer" %in% axes) {
		plan$optimizer = list(families = edi_tuning_restrict_families(edi_tuning_optimizer_algorithm_families(), families), n_grid = n_grid)
	}
	if ("warm_start" %in% axes) {
		ops = names(EDI_TUNING_WARM_START_OPERATION_CALLS)
		fams = stats::setNames(lapply(ops, function(op) {
			f = edi_tuning_restrict_families(edi_tuning_warm_start_families(op), families)
			if (identical(effort, "quick")) f = edi_tuning_quick_warm_start_families(f)
			f
		}), ops)
		plan$warm_start = list(families_by_operation = fams, n_grid = n_grid)
	}
	if ("parallel" %in% axes) {
		ops = names(EDI_TUNING_PARALLEL_OPERATION_TO_WARM_START_OPERATION)
		if (identical(effort, "quick")) ops = "bootstrap"
		fams = stats::setNames(lapply(ops, function(op) edi_tuning_restrict_families(edi_tuning_parallel_families(op), families)), ops)
		plan$parallel = list(families_by_operation = fams, n_grid = n_grid, num_cores_grid = num_cores_grid)
	}
	n_total = edi_tuning_count_cells(plan)

	# ---- Preamble ----
	if (!quiet) {
		cat(sprintf("tune_EDI_for_this_machine(): effort = \"%s\", axes = %s\n", effort, paste(axes, collapse = ", ")))
		cat(sprintf("  %d benchmark cells, n-grid = {%s}, %d replicates per cell. Expect %s.\n",
		            n_total, paste(n_grid, collapse = ", "), reps, edi_tuning_effort_nominal_time(effort)))
		cat("  Please keep the machine otherwise idle while this runs.\n")
		if (dry_run) cat("  dry_run = TRUE: nothing will be written or applied.\n")
	}

	# ---- Contention guard (TODO-7): refuse to benchmark a busy machine ----
	if (!force) {
		busy = edi_tuning_machine_looks_busy()
		if (isTRUE(busy$busy)) {
			why = paste0("  - ", busy$reasons, collapse = "\n")
			msg = paste0("This machine looks busy right now:\n", why,
			             "\nA tuning run under contention measures the contention, not the hardware -- the exact problem tune_EDI_for_this_machine() exists to fix.")
			proceed = FALSE
			if (interactive() && !quiet) {
				cat(msg, "\n")
				ans = tolower(trimws(readline("Proceed anyway? [y/N]: ")))
				proceed = ans %in% c("y", "yes")
			}
			if (!proceed) {
				stop(msg, "\nRe-run when the machine is idle, or pass force = TRUE to override.", call. = FALSE)
			}
		}
	}

	# ---- Progress-bar driver (same bar as InferenceSuite$run_all_inference()) ----
	bar = new.env(parent = emptyenv())
	bar$n_done = 0L
	bar$elapsed = numeric(n_total)
	on_cell_done = function(secs) {
		bar$n_done = bar$n_done + 1L
		if (is.na(secs)) {
			prev = bar$elapsed[seq_len(bar$n_done - 1L)]
			secs = if (length(prev)) mean(prev) else 0
		}
		if (bar$n_done <= n_total) bar$elapsed[bar$n_done] = secs
		if (!quiet) {
			cat("\r\033[K")
			cat(run_all_inference_progress_bar_line(min(bar$n_done, n_total), n_total, bar$elapsed, label = "Cells"))
		}
	}
	t_start = Sys.time()
	if (!quiet) cat(run_all_inference_progress_bar_line(0L, n_total, bar$elapsed, label = "Cells"))

	# ---- Run axes ----
	raw = list()
	if (!is.null(plan$cold_start)) {
		raw$cold_start = list(
			deviations = edi_tuning_tune_cold_start(n_grid = n_grid, reps = reps, families = plan$cold_start$families, on_cell_done = on_cell_done),
			n_grid = n_grid
		)
	}
	if (!is.null(plan$warm_start)) {
		devs = list()
		for (op in names(plan$warm_start$families_by_operation)) {
			devs[[op]] = edi_tuning_tune_warm_start(operation = op, n_grid = n_grid, reps = reps,
			                                        families = plan$warm_start$families_by_operation[[op]], on_cell_done = on_cell_done)
		}
		raw$warm_start = list(deviations = devs, n_grid = n_grid)
	}
	if (!is.null(plan$optimizer)) {
		raw$optimizer = list(
			deviations = edi_tuning_tune_optimizer_algorithm(converged_fn = converged_fn, n_grid = n_grid, reps = reps,
			                                                families = plan$optimizer$families, on_cell_done = on_cell_done),
			n_grid = n_grid
		)
	}
	if (!is.null(plan$parallel)) {
		devs = list()
		for (op in names(plan$parallel$families_by_operation)) {
			for (k in plan$parallel$num_cores_grid) {
				devs = c(devs, edi_tuning_tune_parallel_crossover(operation = op, num_cores = k, n_grid = n_grid, reps = reps,
				                                                  families = plan$parallel$families_by_operation[[op]], on_cell_done = on_cell_done))
			}
		}
		raw$parallel = list(deviations = devs)
	}
	elapsed_total = as.numeric(difftime(Sys.time(), t_start, units = "secs"))
	if (!quiet) {
		cat("\r\033[K")
		cat(sprintf("Status: Completed in %s.\n", run_all_inference_fmt_completed_secs(elapsed_total)))
	}

	# ---- Correctness gate (TODO-8): re-fit every accepted deviation once under
	# both settings and require agreement before it can displace a shipped
	# default. Disagreeing/unverifiable deviations are discarded (warning()
	# already emitted inside the gate) and kept on the result for inspection.
	discarded = list()
	if (!is.null(raw$cold_start)) {
		g = edi_tuning_apply_correctness_gate(raw$cold_start$deviations, edi_tuning_verify_cold_start_deviation, "cold start")
		raw$cold_start$deviations = g$kept
		discarded$cold_start = g$discarded
	}
	if (!is.null(raw$optimizer)) {
		g = edi_tuning_apply_correctness_gate(raw$optimizer$deviations, edi_tuning_verify_optimizer_deviation, "optimizer")
		raw$optimizer$deviations = g$kept
		discarded$optimizer = g$discarded
	}
	if (!is.null(raw$warm_start)) {
		discarded$warm_start = list()
		for (op in names(raw$warm_start$deviations)) {
			verify_fn = function(dev) edi_tuning_verify_warm_start_deviation(dev, operation = op)
			g = edi_tuning_apply_correctness_gate(raw$warm_start$deviations[[op]], verify_fn, sprintf("warm start (%s)", op))
			raw$warm_start$deviations[[op]] = g$kept
			discarded$warm_start[[op]] = g$discarded
		}
	}
	if (!is.null(raw$parallel)) {
		g = edi_tuning_apply_correctness_gate(raw$parallel$deviations, edi_tuning_verify_parallel_deviation, "parallel")
		raw$parallel$deviations = g$kept
		discarded$parallel = g$discarded
	}

	# ---- Diffs, result, persist, apply ----
	diffs = edi_tuning_build_policy_diffs(raw)
	# TODO-6 hard gate: never emit a diff touching the bootstrap-CI-type policy
	# or the parallel-safety serial blocklist -- asserted on every run, dry or
	# not, before anything is written or applied.
	edi_tuning_assert_diffs_respect_untunable(diffs)
	result = list(
		schema_version = EDI_TUNING_SCHEMA_VERSION,
		edi_version = tryCatch(as.character(utils::packageVersion("EDI")), error = function(e) NA_character_),
		timestamp = Sys.time(),
		effort = effort, axes = axes, n_grid = n_grid, reps = reps,
		num_cores_grid = if ("parallel" %in% axes) num_cores_grid else NULL,
		hardware_fingerprint = edi_tuning_hardware_fingerprint(),
		policy_diffs = diffs,
		n_cells = n_total,
		elapsed_secs_total = elapsed_total,
		dry_run = dry_run,
		config_path = edi_tuning_config_path(),
		n_discarded_by_correctness_gate = length(unlist(discarded, recursive = FALSE))
	)
	class(result) = "EDILocalMachineTuning"
	# The raw deviations and the correctness-gate's discards travel on the
	# returned object only (for inspection); the file stores the diffs +
	# provenance (the plan's file schema) -- discarded deviations never appear
	# there, since they were rejected specifically so they would not be applied.
	attr(result, "raw_deviations") = raw
	attr(result, "discarded_by_correctness_gate") = discarded

	if (!dry_run) {
		to_save = unclass(result)
		edi_tuning_write_config(to_save)
		edi_tuning_apply_policy_diffs(diffs)
	}
	if (!quiet) print(result)
	invisible(result)
}

#' @export
print.EDILocalMachineTuning = function(x, ...) {
	cat("EDI local machine tuning", if (isTRUE(x$dry_run)) "(dry run -- not saved, not applied)" else "", "\n")
	cat(sprintf("  Run: %s | EDI %s | effort = %s | %d cells in %s\n",
	            format(x$timestamp, "%Y-%m-%d %H:%M:%S"), x$edi_version %||% "?", x$effort,
	            x$n_cells %||% NA_integer_, run_all_inference_fmt_completed_secs(x$elapsed_secs_total %||% 0)))
	fp = x$hardware_fingerprint
	if (!is.null(fp)) {
		cat(sprintf("  Machine: %s | %s logical / %s physical cores | BLAS: %s\n",
		            fp$cpu_model %||% "?", fp$logical_cores %||% "?", fp$physical_cores %||% "?", fp$blas %||% "?"))
	}
	if (!isTRUE(x$dry_run)) cat(sprintf("  File: %s\n", x$config_path))
	d = x$policy_diffs
	cat("Deviations from shipped defaults:\n")
	none = TRUE
	if (!is.null(d$cold_start)) {
		none = FALSE
		v = d$cold_start$inference_class_overrides
		for (p in names(v)) cat(sprintf("  cold start : %-45s smart_cold_start = %s\n", p, v[[p]]))
	}
	if (!is.null(d$optimizer)) {
		none = FALSE
		v = d$optimizer$inference_class_overrides
		for (p in names(v)) cat(sprintf("  optimizer  : %-45s algorithm = %s\n", p, v[[p]]))
	}
	if (!is.null(d$warm_start)) {
		none = FALSE
		for (op in names(d$warm_start)) {
			for (r in d$warm_start[[op]]$n_conditioned_overrides) {
				cat(sprintf("  warm start : %-45s %-14s warm_start = %s for n in [%s, %s)\n",
				            r$pattern, paste0("(", op, ")"), r$value, format(r$n_min), format(r$n_max)))
			}
		}
	}
	if (!is.null(d$parallel)) {
		none = FALSE
		for (r in d$parallel$crossover) {
			cat(sprintf("  parallel   : %-45s %-14s %d cores beat serial from n = %d (%.0f%% faster)\n",
			            r$class, paste0("(", r$operation, ")"), r$num_cores, r$crossover_n, 100 * r$rel_improvement))
		}
		cat(sprintf("  parallel   : preferred core count = %d (recorded only; opt in via set_num_cores())\n", d$parallel$preferred_num_cores))
	}
	if (none) cat("  (none -- the shipped defaults already win on this machine)\n")
	n_disc = x$n_discarded_by_correctness_gate %||% 0L
	if (n_disc > 0L) {
		cat(sprintf("  (%d timing win%s discarded by the correctness gate -- see attr(x, \"discarded_by_correctness_gate\"))\n",
		            n_disc, if (n_disc == 1L) "" else "s"))
	}
	invisible(x)
}
