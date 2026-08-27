#' Persistence layer for \code{tune_EDI_for_this_machine()}
#'
#' \code{local_machine_optimization.md} TODO-5: the per-user config file,
#' the hardware fingerprint, conversion of raw per-axis benchmark deviations
#' into setter-shaped policy diffs, and a \strong{merge-aware} apply path.
#' The apply path is merge-aware for a reason worth stating up front: the
#' existing \code{set_*_dispatch_policy()} setters merge via
#' \code{utils::modifyList()}, which for a \emph{named atomic vector} element
#' (every \code{inference_class_overrides} table) replaces the whole vector
#' rather than merging into it -- so naively passing a one-class diff through
#' a setter would silently wipe every other shipped override. Everything here
#' that applies a diff prepends the diff's entries onto the current table and
#' keeps the rest (first-match-wins semantics in every dispatcher, so
#' prepending is what makes the diff take effect).
#'
#' @keywords internal
#' @noRd
NULL

#' @keywords internal
#' @noRd
EDI_TUNING_SCHEMA_VERSION = 1L

#' @keywords internal
#' @noRd
EDI_TUNING_CONFIG_FILENAME = "machine_policies.rds"

#' Directory holding the per-user tuning config file
#'
#' \code{tools::R_user_dir("EDI", which = "config")} -- the CRAN-sanctioned
#' per-user config location -- unless \code{edi_env$tuning_config_dir_override}
#' is set (tests point it at a \code{tempdir()} so they never touch the real
#' user config).
#'
#' @keywords internal
#' @noRd
edi_tuning_config_dir = function() {
	override = edi_env$tuning_config_dir_override
	if (!is.null(override)) return(override)
	tools::R_user_dir("EDI", which = "config")
}

#' @keywords internal
#' @noRd
edi_tuning_config_path = function() {
	file.path(edi_tuning_config_dir(), EDI_TUNING_CONFIG_FILENAME)
}

#' A best-effort fingerprint of the machine a tuning run happened on
#'
#' Every field is wrapped so an unreadable source yields \code{NA}, never an
#' error -- this is descriptive provenance, not a gate. Used for the
#' load-time "hardware appears to have changed, consider re-running" message
#' (TODO-9) and for \code{get_local_EDI_optimization()}'s display.
#'
#' @keywords internal
#' @noRd
edi_tuning_hardware_fingerprint = function() {
	safe = function(expr) tryCatch(expr, error = function(e) NA, warning = function(w) NA)
	cpu_model = safe({
		if (file.exists("/proc/cpuinfo")) {
			lines = readLines("/proc/cpuinfo", n = 200L, warn = FALSE)
			hit = grep("^model name", lines, value = TRUE)
			if (length(hit)) trimws(sub("^model name\\s*:\\s*", "", hit[[1]])) else NA_character_
		} else if (identical(Sys.info()[["sysname"]], "Darwin")) {
			trimws(system("sysctl -n machdep.cpu.brand_string", intern = TRUE))
		} else {
			NA_character_
		}
	})
	total_ram_bytes = safe({
		if (file.exists("/proc/meminfo")) {
			lines = readLines("/proc/meminfo", n = 5L, warn = FALSE)
			hit = grep("^MemTotal", lines, value = TRUE)
			if (length(hit)) as.numeric(gsub("[^0-9]", "", hit[[1]])) * 1024 else NA_real_
		} else {
			NA_real_
		}
	})
	list(
		logical_cores = safe(as.integer(parallel::detectCores(logical = TRUE))),
		physical_cores = safe(as.integer(parallel::detectCores(logical = FALSE))),
		cpu_model = cpu_model,
		total_ram_bytes = total_ram_bytes,
		blas = safe(unname(extSoftVersion()[["BLAS"]])),
		lapack = safe(unname(La_library())),
		platform = safe(R.version$platform),
		r_version = safe(R.version.string)
	)
}

#' Prepend a named atomic override vector onto a current one, keeping the
#' rest
#'
#' The one merge primitive every apply path below uses. Entries in
#' \code{new} come first (so, under first-match-wins dispatch, they win);
#' entries in \code{current} whose names do not appear in \code{new} are
#' kept after them in their original order.
#'
#' @keywords internal
#' @noRd
edi_tuning_merge_override_vector = function(current, new) {
	if (is.null(new) || length(new) == 0L) return(current)
	if (is.null(current) || length(current) == 0L) return(new)
	keep = current[setdiff(names(current), names(new))]
	c(new, keep)
}

#' Cold-start / optimizer deviations -> a per-class override vector
#'
#' Both of these axes have \strong{no} sample-size layer in their dispatch
#' tables, so a deviation can only be stored as a single per-class value.
#' Rule: a class's flip is stored only if it won at \strong{every} tested
#' \code{n} in \code{n_grid} \emph{and} every win agreed on the same \code{to}
#' value -- a flip that only pays off at some sizes is not a clean per-class
#' judgment, and the plan's "ties keep the shipped default" spirit says leave
#' it alone. Returns \code{NULL} when nothing qualifies.
#'
#' @keywords internal
#' @noRd
edi_tuning_per_class_override_from_deviations = function(deviations, n_grid) {
	if (length(deviations) == 0L) return(NULL)
	n_grid = sort(unique(as.integer(n_grid)))
	by_class = split(deviations, vapply(deviations, `[[`, character(1), "class"))
	out = c()
	for (cl in names(by_class)) {
		devs = by_class[[cl]]
		ns = sort(unique(vapply(devs, function(d) as.integer(d$n), integer(1))))
		tos = unique(vapply(devs, function(d) as.character(d$to), character(1)))
		if (identical(ns, n_grid) && length(tos) == 1L) {
			val = if (is.logical(devs[[1]]$to)) as.logical(tos) else tos
			out = c(out, stats::setNames(val, paste0("^", cl, "$")))
		}
	}
	if (length(out) == 0L) NULL else out
}

#' Warm-start deviations (per operation) -> n-conditioned rules
#'
#' One rule per deviation over the half-open range \code{[n_k, n_{k+1})}
#' of the tested grid (\code{Inf} past the last point), in the exact
#' \code{list(pattern, value, n_min, n_max)} shape
#' \code{get_warm_start_dispatch_policy()} uses. Returns a list keyed by
#' operation, each \code{list(n_conditioned_overrides = <rules>)}, or
#' \code{NULL} when nothing qualifies.
#'
#' @keywords internal
#' @noRd
edi_tuning_warm_start_diff_from_deviations = function(deviations_by_operation, n_grid) {
	if (length(deviations_by_operation) == 0L) return(NULL)
	n_grid = sort(unique(as.integer(n_grid)))
	next_n = function(n) {
		idx = match(n, n_grid)
		if (is.na(idx) || idx == length(n_grid)) Inf else n_grid[[idx + 1L]]
	}
	out = list()
	for (op in names(deviations_by_operation)) {
		devs = deviations_by_operation[[op]]
		if (length(devs) == 0L) next
		rules = lapply(devs, function(d) {
			list(pattern = paste0("^", d$class, "$"), value = isTRUE(d$to),
			     n_min = as.integer(d$n), n_max = next_n(as.integer(d$n)))
		})
		out[[op]] = list(n_conditioned_overrides = rules)
	}
	if (length(out) == 0L) NULL else out
}

#' Parallel crossover deviations -> a recorded-only parallel diff
#'
#' Per TODO-1(d) (user decision 2026-08-17) the preferred core count is
#' \strong{recorded, never auto-applied} at load. And there is currently no
#' runtime table for per-family crossover thresholds at all
#' (\code{get_parallel_dispatch_policy()} is a serial blocklist only), so
#' this diff has nothing to be applied \emph{to} yet -- it is stored for
#' \code{get_local_EDI_optimization()}'s display and for the parallel
#' heuristics to consume once such a knob exists. \code{preferred_num_cores}
#' is the \code{num_cores} value whose crossover wins had the largest mean
#' relative improvement (ties -> the smaller core count).
#'
#' @keywords internal
#' @noRd
edi_tuning_parallel_diff_from_deviations = function(deviations) {
	if (length(deviations) == 0L) return(NULL)
	ks = vapply(deviations, function(d) as.integer(d$num_cores), integer(1))
	gains = vapply(deviations, function(d) as.numeric(d$rel_improvement), numeric(1))
	mean_gain = tapply(gains, ks, mean)
	best = as.integer(names(mean_gain))[which(mean_gain == max(mean_gain))]
	list(
		crossover = lapply(deviations, function(d) {
			list(class = d$class, response_type = d$response_type, operation = d$operation,
			     num_cores = as.integer(d$num_cores), crossover_n = as.integer(d$crossover_n),
			     rel_improvement = as.numeric(d$rel_improvement))
		}),
		preferred_num_cores = min(best)
	)
}

#' Assemble every axis's raw deviations into one setter-shaped policy-diff list
#'
#' @param axis_results A list with any of: \code{cold_start =
#'   list(deviations, n_grid)}, \code{warm_start = list(deviations =
#'   <list keyed by operation>, n_grid)}, \code{optimizer = list(deviations,
#'   n_grid)}, \code{parallel = list(deviations)}.
#' @return \code{list(cold_start, warm_start, optimizer, parallel)}, each
#'   \code{NULL} when that axis produced no storable deviation.
#' @keywords internal
#' @noRd
edi_tuning_build_policy_diffs = function(axis_results) {
	cs = axis_results$cold_start
	ws = axis_results$warm_start
	op = axis_results$optimizer
	pa = axis_results$parallel
	cs_vec = if (!is.null(cs)) edi_tuning_per_class_override_from_deviations(cs$deviations, cs$n_grid) else NULL
	op_vec = if (!is.null(op)) edi_tuning_per_class_override_from_deviations(op$deviations, op$n_grid) else NULL
	list(
		cold_start = if (is.null(cs_vec)) NULL else list(inference_class_overrides = cs_vec),
		warm_start = if (!is.null(ws)) edi_tuning_warm_start_diff_from_deviations(ws$deviations, ws$n_grid) else NULL,
		optimizer = if (is.null(op_vec)) NULL else list(inference_class_overrides = op_vec),
		parallel = if (!is.null(pa)) edi_tuning_parallel_diff_from_deviations(pa$deviations) else NULL
	)
}

#' Apply a policy-diff list to the live dispatch tables, merge-aware
#'
#' Cold start and optimizer: prepend the diff's per-class entries onto the
#' current \code{inference_class_overrides} (see
#' \code{\link{edi_tuning_merge_override_vector}}) and push the \emph{full
#' merged} vector through the setter -- never the bare diff, which would
#' wipe the rest (see this file's header). Warm start, per operation: the new
#' n-conditioned rules go first; if a flipped class also sits in that
#' operation's \emph{unconditional} \code{inference_class_overrides} (which
#' the dispatcher checks \emph{before} any n-conditioned rule, so the new
#' rule could never win), that unconditional entry is removed and its value
#' re-expressed as a catch-all \code{[-Inf, Inf)} n-conditioned rule placed
#' \emph{after} the new rules and \emph{before} the pre-existing rules --
#' preserving exactly the prior behavior at every \code{n} the new rules do
#' not cover. Parallel: recorded-only, nothing applied (see
#' \code{\link{edi_tuning_parallel_diff_from_deviations}}).
#'
#' @param diffs As returned by \code{\link{edi_tuning_build_policy_diffs}}.
#' @return Invisibly, a character vector of the axes that were applied.
#' @keywords internal
#' @noRd
edi_tuning_apply_policy_diffs = function(diffs) {
	checkmate::assertList(diffs, names = "named")
	applied = character(0)

	if (!is.null(diffs$cold_start)) {
		cur = edi_env$cold_start_dispatch_policy_config$inference_class_overrides
		merged = edi_tuning_merge_override_vector(cur, diffs$cold_start$inference_class_overrides)
		set_cold_start_dispatch_policy(list(inference_class_overrides = merged))
		applied = c(applied, "cold_start")
	}

	if (!is.null(diffs$optimizer)) {
		cur = edi_env$optimization_dispatch_policy_config$inference_class_overrides
		merged = edi_tuning_merge_override_vector(cur, diffs$optimizer$inference_class_overrides)
		set_optimization_dispatch_policy(list(inference_class_overrides = merged))
		applied = c(applied, "optimizer")
	}

	if (!is.null(diffs$warm_start)) {
		for (op in names(diffs$warm_start)) {
			new_rules = diffs$warm_start[[op]]$n_conditioned_overrides
			if (length(new_rules) == 0L) next
			cur_op = edi_env$warm_start_dispatch_policy_config[[op]]
			if (is.null(cur_op)) cur_op = list(inference_class_overrides = character(0), n_conditioned_overrides = list())
			cur_uncond = cur_op$inference_class_overrides
			cur_rules = cur_op$n_conditioned_overrides %||% list()
			new_patterns = vapply(new_rules, `[[`, character(1), "pattern")
			conflicting = intersect(names(cur_uncond), new_patterns)
			catch_alls = lapply(conflicting, function(p) {
				list(pattern = p, value = isTRUE(cur_uncond[[p]]), n_min = -Inf, n_max = Inf)
			})
			pruned_uncond = cur_uncond[setdiff(names(cur_uncond), conflicting)]
			if (length(pruned_uncond) == 0L) pruned_uncond = character(0)
			set_warm_start_dispatch_policy(stats::setNames(list(list(
				inference_class_overrides = pruned_uncond,
				n_conditioned_overrides = c(new_rules, catch_alls, cur_rules)
			)), op))
		}
		applied = c(applied, "warm_start")
	}

	invisible(applied)
}

#' The policy surfaces the tuner must never touch (TODO-6)
#'
#' Two things are deliberately \strong{untunable}, and the reason is
#' correctness, not performance: (1) the bootstrap confidence-interval
#' \emph{type} policy (\code{get_bootstrap_dispatch_policy()}: BCa vs.
#' percentile is a statistical-validity judgment -- "BCa is empirically
#' unreliable for these classes" -- so machine timing has no say); (2) the
#' parallel policy's serial blocklist (\code{get_parallel_dispatch_policy()}:
#' those entries exist because the operation is \emph{not parallel-safe} for
#' that class/response type, so the tuner must never propose un-serializing
#' them). \code{\link{edi_tuning_assert_diffs_respect_untunable}} is the
#' hard gate; \code{\link{edi_tuning_parallel_families}} is the soft one
#' (it never even benchmarks blocklisted combinations).
#'
#' @keywords internal
#' @noRd
EDI_TUNING_UNTUNABLE_SURFACES = c("bootstrap_ci_type", "parallel_safety_blocklist")

#' Assert a policy-diff list touches no untunable surface; error if it does
#'
#' Checked against the \strong{shipped} parallel blocklist
#' (\code{get_parallel_dispatch_policy()}), not the live, possibly
#' user-modified one -- the blocklist is a safety fact about the code, not a
#' preference. Called by \code{\link{tune_EDI_for_this_machine}} on every
#' run (including \code{dry_run}) before anything is written or applied.
#'
#' @param diffs As returned by \code{\link{edi_tuning_build_policy_diffs}}.
#' @return Invisibly \code{TRUE}; otherwise a \code{stop()} naming the
#'   violation.
#' @keywords internal
#' @noRd
edi_tuning_assert_diffs_respect_untunable = function(diffs) {
	checkmate::assertList(diffs, names = "named")
	known = c("cold_start", "warm_start", "optimizer", "parallel")
	unknown = setdiff(names(diffs), known)
	if (length(unknown) > 0L) {
		stop(sprintf("Tuner produced a diff for untunable/unknown policy surface(s): %s. Only %s may be tuned.",
		             paste(unknown, collapse = ", "), paste(known, collapse = ", ")), call. = FALSE)
	}
	if (!is.null(diffs$parallel) && length(diffs$parallel$crossover) > 0L) {
		shipped = get_parallel_dispatch_policy()
		matches_any = function(value, patterns) {
			if (is.null(patterns) || length(patterns) == 0L) return(FALSE)
			any(vapply(patterns, function(p) grepl(p, value, perl = TRUE), logical(1)))
		}
		for (r in diffs$parallel$crossover) {
			op_cfg = shipped[[r$operation]]
			if (is.null(op_cfg)) {
				stop(sprintf("Parallel diff names unknown operation `%s`.", r$operation), call. = FALSE)
			}
			if (matches_any(r$class, op_cfg$serial_inference_class_patterns) ||
			    matches_any(r$response_type, op_cfg$serial_response_types)) {
				stop(sprintf(paste0(
					"Tuner proposed un-serializing %s (%s, operation `%s`), which the shipped parallel ",
					"policy forces serial for parallel-SAFETY reasons, not performance. Refusing."),
					r$class, r$response_type, r$operation), call. = FALSE)
			}
		}
	}
	invisible(TRUE)
}

#' Is this a config object this package version knows how to apply?
#'
#' @keywords internal
#' @noRd
edi_tuning_validate_config = function(obj) {
	is.list(obj) &&
		identical(as.integer(obj$schema_version %||% NA_integer_), EDI_TUNING_SCHEMA_VERSION) &&
		is.list(obj$policy_diffs)
}

#' @keywords internal
#' @noRd
edi_tuning_write_config = function(config) {
	dir = edi_tuning_config_dir()
	if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
	saveRDS(config, edi_tuning_config_path())
	invisible(edi_tuning_config_path())
}

#' Read the config file, or \code{NULL} if absent/unreadable (never errors)
#'
#' @keywords internal
#' @noRd
edi_tuning_read_config = function() {
	path = edi_tuning_config_path()
	if (!file.exists(path)) return(NULL)
	tryCatch(readRDS(path), error = function(e) NULL, warning = function(w) NULL)
}

#' Environment variable that disables the load-time import entirely
#'
#' Set \code{EDI_SKIP_LOCAL_TUNING=1} (any non-empty, non-"0"/"false" value)
#' to make \code{library(EDI)} ignore any saved machine tuning -- useful on
#' CI and for "is the saved tuning what's causing this?" debugging.
#'
#' @keywords internal
#' @noRd
EDI_TUNING_SKIP_ENV_VAR = "EDI_SKIP_LOCAL_TUNING"

#' @keywords internal
#' @noRd
edi_tuning_skip_requested = function() {
	v = tolower(trimws(Sys.getenv(EDI_TUNING_SKIP_ENV_VAR, unset = "")))
	nzchar(v) && !(v %in% c("0", "false", "no"))
}

#' Import this machine's saved tuning at package load (TODO-9)
#'
#' Called from \code{.onLoad()} after the single-threaded-by-default
#' \code{set_package_threads(1L)} call. Rules (all from the plan's
#' "Load-time import" section):
#' \itemize{
#' \item \strong{Fail open, quietly.} No file -> do nothing, say nothing.
#'   Unreadable/corrupt file, unknown \code{schema_version}, or a diff the
#'   setters reject -> ignore the file \emph{entirely} (every policy reset to
#'   its shipped default, so a half-applied diff can never leave a mixed
#'   state) and emit one \code{packageStartupMessage} asking the user to
#'   re-run \code{tune_EDI_for_this_machine()}. Never errors at load time.
#' \item \strong{Fingerprint mismatch} (logical core count or CPU model
#'   differs from the saved one): still apply -- the saved policies are
#'   probably better than nothing -- but \code{packageStartupMessage} that
#'   the hardware appears to have changed and suggest re-running.
#' \item \strong{Version skew} needs nothing special: diffs reference classes
#'   by the same regex-pattern keys the tables use, so a pattern matching a
#'   class that no longer exists is inert, and classes added since tuning
#'   fall through to shipped defaults.
#' \item The parallel diff is \strong{recorded-only} -- the apply path never
#'   touches the active core count (TODO-1(d), user decision 2026-08-17).
#' }
#'
#' @param quiet If \code{TRUE}, suppress the startup messages (the status
#'   is still returned). \code{.onLoad()} passes \code{FALSE}.
#' @return Invisibly, one of \code{"skipped"} (env var), \code{"none"} (no
#'   file), \code{"invalid"} (file ignored), \code{"error"} (apply failed,
#'   file ignored, policies reset), \code{"applied"}, or
#'   \code{"applied_hardware_changed"}.
#' @keywords internal
#' @noRd
edi_tuning_import_saved_policies = function(quiet = FALSE) {
	say = function(...) if (!quiet) packageStartupMessage(...)
	if (edi_tuning_skip_requested()) return(invisible("skipped"))

	obj = edi_tuning_read_config()
	if (is.null(obj)) {
		if (file.exists(edi_tuning_config_path())) {
			say("EDI: the saved local machine tuning at ", edi_tuning_config_path(),
			    " could not be read and was ignored; shipped defaults are in effect. Re-run tune_EDI_for_this_machine() to regenerate it.")
			return(invisible("invalid"))
		}
		return(invisible("none"))
	}
	if (!edi_tuning_validate_config(obj)) {
		say("EDI: the saved local machine tuning at ", edi_tuning_config_path(),
		    " is from an incompatible schema and was ignored; shipped defaults are in effect. Re-run tune_EDI_for_this_machine() to regenerate it.")
		return(invisible("invalid"))
	}

	ok = tryCatch({
		edi_tuning_assert_diffs_respect_untunable(obj$policy_diffs)
		edi_tuning_apply_policy_diffs(obj$policy_diffs)
		TRUE
	}, error = function(e) {
		# Never leave a partially-applied state: back to shipped defaults.
		set_cold_start_dispatch_policy(reset = TRUE)
		set_warm_start_dispatch_policy(reset = TRUE)
		set_optimization_dispatch_policy(reset = TRUE)
		say("EDI: the saved local machine tuning at ", edi_tuning_config_path(),
		    " could not be applied (", conditionMessage(e), ") and was ignored; shipped defaults are in effect. Re-run tune_EDI_for_this_machine() to regenerate it.")
		FALSE
	})
	if (!ok) return(invisible("error"))

	saved_fp = obj$hardware_fingerprint
	now_fp = edi_tuning_hardware_fingerprint()
	differs = function(a, b) !is.null(a) && !is.null(b) && !is.na(a) && !is.na(b) && !identical(a, b)
	hw_changed = differs(saved_fp$logical_cores, now_fp$logical_cores) || differs(saved_fp$cpu_model, now_fp$cpu_model)
	if (hw_changed) {
		say("EDI: applied the saved local machine tuning, but this machine's hardware appears to differ from the one it was measured on (",
		    saved_fp$cpu_model %||% "?", " / ", saved_fp$logical_cores %||% "?", " cores then; ",
		    now_fp$cpu_model %||% "?", " / ", now_fp$logical_cores %||% "?", " cores now). Consider re-running tune_EDI_for_this_machine().")
		return(invisible("applied_hardware_changed"))
	}

	# The parallel-crossover axis is deliberately never auto-applied by
	# edi_tuning_apply_policy_diffs() (opt-in only, per TODO-1(d)), so unlike
	# the cold-start/warm-start/optimizer diffs it leaves no other trace once
	# the tuning run's console output has scrolled away -- a user who ran
	# tune_EDI_for_this_machine() once, non-interactively or in a session
	# they didn't watch, would otherwise never learn their machine has a
	# faster core count available. Surface it once per session at load time,
	# same as the hardware-changed notice above.
	preferred_num_cores = obj$policy_diffs$parallel$preferred_num_cores
	if (!is.null(preferred_num_cores)) {
		say("EDI: this machine's saved tuning found parallel execution fastest at ", preferred_num_cores,
		    " cores. This is not applied automatically -- call set_num_cores(", preferred_num_cores,
		    ") to opt in.")
	}
	invisible("applied")
}

#' Delete this machine's saved EDI tuning and return to shipped defaults
#'
#' Removes the per-user config file written by
#' \code{\link{tune_EDI_for_this_machine}} (so the next \code{library(EDI)}
#' starts from the package's built-in performance-policy defaults) and
#' resets the in-session cold-start, warm-start, and optimizer-algorithm
#' dispatch policies to those defaults right away.
#'
#' @return Invisibly, \code{TRUE} if a saved tuning existed and was removed,
#'   \code{FALSE} if there was none.
#' @seealso \code{\link{tune_EDI_for_this_machine}},
#'   \code{\link{get_local_EDI_optimization}}.
#' @examples
#' \donttest{
#' clear_local_EDI_optimization()
#' }
#' @export
clear_local_EDI_optimization = function() {
	path = edi_tuning_config_path()
	existed = file.exists(path)
	if (existed) unlink(path)
	set_cold_start_dispatch_policy(reset = TRUE)
	set_warm_start_dispatch_policy(reset = TRUE)
	set_optimization_dispatch_policy(reset = TRUE)
	invisible(existed)
}

#' Show this machine's saved EDI tuning, if any
#'
#' Reads the per-user config file written by
#' \code{\link{tune_EDI_for_this_machine}} and returns it as an
#' \code{EDILocalMachineTuning} object (whose print method shows when and
#' how it was produced, the hardware fingerprint it was measured on, and
#' every policy deviation it stores). Does \strong{not} apply anything --
#' application happens inside \code{tune_EDI_for_this_machine()} itself and
#' at package load.
#'
#' @return Invisibly, the saved \code{EDILocalMachineTuning} object, or
#'   \code{NULL} (with a message) if no valid saved tuning exists.
#' @seealso \code{\link{tune_EDI_for_this_machine}},
#'   \code{\link{clear_local_EDI_optimization}}.
#' @examples
#' \donttest{
#' get_local_EDI_optimization()
#' }
#' @export
get_local_EDI_optimization = function() {
	obj = edi_tuning_read_config()
	if (is.null(obj) || !edi_tuning_validate_config(obj)) {
		message("No saved local EDI tuning found (or it is from an incompatible schema). Run tune_EDI_for_this_machine() to create one.")
		return(invisible(NULL))
	}
	class(obj) = "EDILocalMachineTuning"
	print(obj)
	invisible(obj)
}
