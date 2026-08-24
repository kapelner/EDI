#' Benchmark harness for \code{tune_EDI_for_this_machine()}
#'
#' Generic, reusable pieces shared by every per-axis tuner
#' (\code{local_machine_optimization.md}, TODO-4): registry-driven family
#' enumeration, synthetic-data generation per family (delegating to
#' \code{inference_migration_complete_design()} in
#' \code{local_machine_tuning_synthetic_fixtures.R} -- the same recipe the migration golden
#' tests use), interleaved A/B timing with median + IQR, the acceptance rule,
#' and the \code{effort} tiering presets. Nothing here fits a model or reads
#' the real dispatch-policy config tables -- that wiring is TODO-4/5. Nothing
#' here is exported; \code{tune_EDI_for_this_machine()} (TODO-4/5) is the only
#' planned public entry point.
#'
#' @keywords internal
#' @noRd
NULL

#' The default deterministic seed for one (class, n) benchmark cell
#'
#' A stable hash of the class name plus \code{n}, used so a class's A/B
#' timing pair -- and, for TODO-8's correctness gate, its verification
#' re-fit -- see identical synthetic data every time it is regenerated.
#' Every axis engine's default \code{seed_fn} and every axis's own inline
#' seed computation (the parallel tuner, which does not go through the
#' \code{seed_fn} parameter) call this one function, so there is exactly
#' one seed formula to keep in sync -- including with the correctness
#' gate, which must reproduce the same seed to compare apples to apples.
#'
#' @keywords internal
#' @noRd
edi_tuning_default_seed = function(class, n) {
	20260821L + (as.integer(sum(utf8ToInt(class))) %% 10000L) + as.integer(n)
}

#' Enumerate the benchmarkable inference-class families
#'
#' A "family" here is a single concrete, non-abstract inference class that
#' \code{infer_inference_response_types()} maps to exactly one response type
#' (abstract/mixin bases like \code{InferenceAsympLik} or wildcard classes
#' like \code{InferenceAllSimpleWilcox} return zero or multiple response
#' types and are excluded -- there is no single synthetic-data recipe that
#' fits them). Registry-driven: iterating the live namespace means a newly
#' added concrete inference class is picked up automatically, with no list to
#' maintain by hand.
#'
#' The abstractness half of that filter is \code{infer_inference_abstract()}
#' -- not just the response-type-count check above it. A class can be
#' genuinely abstract (never meant to be constructed directly; e.g. requires
#' a design family the generic synthetic fixture below never builds) while
#' still resolving to exactly one response type, e.g.
#' \code{InferenceIncidKKGCompAbstract}, which needs a KK matching-on-the-fly
#' design (per its own \code{@keywords internal} docs).
#'
#' A second, separate filter excludes every \emph{concrete} class for which
#' \code{infer_inference_requires_kk_matching_design()} is \code{TRUE} (e.g.
#' \code{InferenceIncidKKGCompRiskDiff}/\code{RiskRatio}): these are not
#' abstract, so the first filter lets them through, but
#' \code{edi_tuning_synthetic_experiment()} always builds a plain iid
#' \code{DesignSeqOneByOneBernoulli} via
#' \code{inference_migration_complete_design()}, never a KK-matching design,
#' so any such class's \code{initialize()} always rejects it via
#' \code{init_kk_passthrough()}'s design-compatibility check -- confirmed as
#' the cause of \code{tune_EDI_for_this_machine()}'s example failing on CI
#' (2026-08-24).
#'
#' @return A data.frame with one row per family: \code{class} (character,
#'   the R6 classname) and \code{response_type} (character).
#' @keywords internal
#' @noRd
edi_tuning_live_families = function() {
	ns = asNamespace("EDI")
	names = sort(Filter(function(name) {
		obj = get(name, envir = ns, inherits = FALSE)
		is_inference_r6_generator(obj) && identical(obj$classname, name) &&
			!infer_inference_abstract(name) && !infer_inference_requires_kk_matching_design(name)
	}, ls(ns, all.names = TRUE)))
	response_types = lapply(names, infer_inference_response_types)
	keep = lengths(response_types) == 1L
	data.frame(
		class = names[keep],
		response_type = unlist(response_types[keep], use.names = FALSE),
		stringsAsFactors = FALSE
	)
}

#' Build the synthetic experiment a family's benchmark cell runs against
#'
#' Thin wrapper around \code{inference_migration_complete_design()} --
#' present so tuner code names its intent (`edi_tuning_synthetic_experiment`)
#' rather than reaching for a test-fixture-sounding name directly, and so the
#' underlying recipe can be swapped later without touching call sites.
#'
#' @param response_type One of \code{"continuous"}, \code{"incidence"},
#'   \code{"count"}, \code{"proportion"}, \code{"ordinal"}, \code{"survival"}.
#' @param n Sample size for this benchmark cell.
#' @param seed RNG seed; held fixed across the A/B pair of a single cell so
#'   both settings see identical data.
#' @return A completed \code{DesignSeqOneByOneBernoulli}.
#' @keywords internal
#' @noRd
edi_tuning_synthetic_experiment = function(response_type, n, seed = 20260821L) {
	inference_migration_complete_design(response_type = response_type, n = n, seed = seed)
}

#' Time two candidate settings interleaved (A/B/A/B/...), not blocked (A...A/B...B)
#'
#' Interleaving decorrelates thermal/frequency drift across the run from the
#' A-vs-B comparison (a blocked A...A/B...B run confounds "B is slower" with
#' "the machine throttled partway through"). Uses wall-clock elapsed time
#' (\code{proc.time()[["elapsed"]]}), which is what a user waiting on a fit
#' actually experiences (unlike \code{[["user.self"]]}, it also reflects
#' contention from other processes -- deliberately, since the tuner's whole
#' premise is measuring the real machine, contention warts included; see
#' TODO-7's separate up-front contention guard for keeping a tuning *run*
#' itself uncontended).
#'
#' @param fn_a,fn_b Zero-argument thunks for settings A and B. Each is called
#'   \code{reps} times total, interleaved.
#' @param reps Number of timed replicates per setting (>= 1).
#' @return A list with \code{times_a}, \code{times_b} (numeric vectors of
#'   elapsed seconds, length \code{reps} each), \code{median_a},
#'   \code{median_b}, \code{iqr_a}, \code{iqr_b}.
#' @keywords internal
#' @noRd
edi_tuning_interleaved_ab = function(fn_a, fn_b, reps = 5L) {
	checkmate::assertFunction(fn_a, nargs = 0L)
	checkmate::assertFunction(fn_b, nargs = 0L)
	checkmate::assertCount(reps, positive = TRUE)

	times_a = numeric(reps)
	times_b = numeric(reps)
	results_a = vector("list", reps)
	results_b = vector("list", reps)
	for (i in seq_len(reps)) {
		t0 = proc.time()[["elapsed"]]
		results_a[[i]] = fn_a()
		times_a[i] = proc.time()[["elapsed"]] - t0

		t0 = proc.time()[["elapsed"]]
		results_b[[i]] = fn_b()
		times_b[i] = proc.time()[["elapsed"]] - t0
	}
	list(
		times_a = times_a,
		times_b = times_b,
		median_a = stats::median(times_a),
		median_b = stats::median(times_b),
		iqr_a = stats::IQR(times_a),
		iqr_b = stats::IQR(times_b),
		# results_a/results_b: each fn_*()'s return value per replicate, in
		# call order. Most axes (cold/warm start) don't need these -- only
		# axes that must gate on more than timing (e.g. the optimizer axis's
		# all-replicates-converge guard) read them.
		results_a = results_a,
		results_b = results_b
	)
}

#' Time two candidate settings blocked (all of A, then all of B, or vice
#' versa) -- for settings whose own setup cost would swamp per-replicate
#' interleaving
#'
#' \code{\link{edi_tuning_interleaved_ab}} is the default because
#' interleaving decorrelates thermal/frequency drift from the A-vs-B
#' comparison. But some settings carry real \strong{one-time setup cost}
#' that must be paid once and amortized across many replicates to measure
#' fairly -- most notably parallel core count, where each distinct core
#' count means creating (or tearing down) a real OS fork cluster
#' (\code{parallel::makeForkCluster()}), and alternating that setup on
#' every single timed replicate would measure cluster-startup noise
#' instead of steady-state throughput. For those settings, block the
#' replicates instead: run all of one setting's reps together (paying its
#' setup cost once), then all of the other's. To avoid systematically
#' favoring whichever setting warms up the CPU for the other, \code{a_first}
#' lets the caller alternate which setting goes first across different
#' cells (e.g. by parity of a loop index) -- a coarser-grained decorrelation
#' than true interleaving, but the best available once per-candidate setup
#' cost rules out replicate-level interleaving.
#'
#' @param fn_a,fn_b Zero-argument thunks for settings A and B. Each is
#'   called \code{reps} times, but as one contiguous block, not
#'   alternating with the other.
#' @param reps Number of timed replicates per setting (>= 1).
#' @param a_first If \code{TRUE} (default), the A block runs before the B
#'   block; if \code{FALSE}, B runs first. Callers benchmarking many cells
#'   should alternate this across cells.
#' @param setup_a,setup_b Optional zero-argument thunks called \strong{once},
#'   immediately before their block starts (not per replicate) -- this is
#'   the hook for real one-time setup, e.g. \code{set_num_cores(k)}, so it
#'   runs once per block rather than once per replicate. \code{NULL}
#'   (default) means no setup for that side.
#' @return Same shape as \code{\link{edi_tuning_interleaved_ab}}.
#' @keywords internal
#' @noRd
edi_tuning_blocked_ab = function(fn_a, fn_b, reps = 5L, a_first = TRUE, setup_a = NULL, setup_b = NULL) {
	checkmate::assertFunction(fn_a, nargs = 0L)
	checkmate::assertFunction(fn_b, nargs = 0L)
	checkmate::assertCount(reps, positive = TRUE)
	checkmate::assertFlag(a_first)
	if (!is.null(setup_a)) checkmate::assertFunction(setup_a, nargs = 0L)
	if (!is.null(setup_b)) checkmate::assertFunction(setup_b, nargs = 0L)

	run_block = function(fn, setup) {
		if (!is.null(setup)) setup()
		times = numeric(reps)
		results = vector("list", reps)
		for (i in seq_len(reps)) {
			t0 = proc.time()[["elapsed"]]
			results[[i]] = fn()
			times[i] = proc.time()[["elapsed"]] - t0
		}
		list(times = times, results = results)
	}

	if (a_first) {
		block_a = run_block(fn_a, setup_a)
		block_b = run_block(fn_b, setup_b)
	} else {
		block_b = run_block(fn_b, setup_b)
		block_a = run_block(fn_a, setup_a)
	}

	list(
		times_a = block_a$times,
		times_b = block_b$times,
		median_a = stats::median(block_a$times),
		median_b = stats::median(block_b$times),
		iqr_a = stats::IQR(block_a$times),
		iqr_b = stats::IQR(block_b$times),
		results_a = block_a$results,
		results_b = block_b$results
	)
}

#' The tuner's noise-margin acceptance rule
#'
#' A candidate setting only displaces the shipped default when it wins by
#' both: (1) a relative median improvement of at least \code{min_rel_improvement}
#' (default 5%), AND (2) that improvement exceeds \code{iqr_multiplier} times
#' the interquartile spread of the *candidate's* replicate timings (default
#' 2x IQR) -- a small median win inside a noisy candidate's own IQR is not
#' distinguishable from measurement noise. Ties, or a "win" that fails either
#' condition, keep the shipped default.
#'
#' @param baseline_times,candidate_times Numeric vectors of elapsed-time
#'   replicates (as returned by \code{edi_tuning_interleaved_ab()}'s
#'   \code{times_a}/\code{times_b}).
#' @param min_rel_improvement Minimum relative median improvement required
#'   (default 0.05, i.e. 5%).
#' @param iqr_multiplier How many candidate-IQRs the absolute median
#'   improvement must exceed (default 2).
#' @return A list: \code{accept} (logical), \code{median_baseline},
#'   \code{median_candidate}, \code{rel_improvement}, \code{iqr_candidate},
#'   \code{noise_margin} (\code{iqr_multiplier * iqr_candidate}, for
#'   diagnostics/printing).
#' @keywords internal
#' @noRd
edi_tuning_accept_candidate = function(baseline_times, candidate_times,
                                        min_rel_improvement = 0.05, iqr_multiplier = 2) {
	checkmate::assertNumeric(baseline_times, min.len = 1L, any.missing = FALSE)
	checkmate::assertNumeric(candidate_times, min.len = 1L, any.missing = FALSE)
	checkmate::assertNumber(min_rel_improvement, lower = 0)
	checkmate::assertNumber(iqr_multiplier, lower = 0)

	median_baseline = stats::median(baseline_times)
	median_candidate = stats::median(candidate_times)
	iqr_candidate = stats::IQR(candidate_times)
	abs_improvement = median_baseline - median_candidate
	rel_improvement = if (median_baseline > 0) abs_improvement / median_baseline else 0
	noise_margin = iqr_multiplier * iqr_candidate

	accept = (rel_improvement >= min_rel_improvement) && (abs_improvement > noise_margin)

	list(
		accept = isTRUE(accept),
		median_baseline = median_baseline,
		median_candidate = median_candidate,
		rel_improvement = rel_improvement,
		iqr_candidate = iqr_candidate,
		noise_margin = noise_margin
	)
}

#' Effort-tier presets for \code{tune_EDI_for_this_machine(effort = ...)}
#'
#' \code{"quick"} trades coverage for a fast (~2-5 min) run: a coarse n-grid,
#' the fewest replicates, and (via \code{families = "top_effect_size"}, left
#' to the per-axis tuners in TODO-4 to interpret) only the axes/families with
#' the largest shipped effect sizes. \code{"standard"} is the default
#' (~15-30 min): full family coverage, a moderate n-grid, enough replicates
#' for a stable median. \code{"thorough"} (~1-2 hr): the full family x
#' operation x n-grid factorial with more replicates for a tighter noise
#' bound. Concrete family/axis selection under \code{"quick"} is a TODO-4
#' concern (it needs each axis's own effect-size data); this preset only
#' fixes the n-grid and replicate count, which are axis-agnostic.
#'
#' @return A named list (\code{quick}, \code{standard}, \code{thorough}),
#'   each element a list with \code{n_grid} (integer vector), \code{reps}
#'   (replicates per A/B cell), and \code{families} (\code{"all"} or
#'   \code{"top_effect_size"}).
#' @keywords internal
#' @noRd
edi_tuning_effort_presets = function() {
	list(
		quick = list(n_grid = c(50L, 500L), reps = 3L, families = "top_effect_size"),
		standard = list(n_grid = c(50L, 200L, 1000L), reps = 5L, families = "all"),
		thorough = list(n_grid = c(50L, 200L, 500L, 1000L, 5000L), reps = 9L, families = "all")
	)
}
