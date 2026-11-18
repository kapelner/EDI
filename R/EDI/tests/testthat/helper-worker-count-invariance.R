# Shared machinery for the registry-driven worker-count invariance tests
# (v1.1.0 TODO-48 (2); cross_platform_reproducibility.md TODO-2):
#   test-aa-fork-worker-count-invariance-registry.R  (fork backend)
#   test-zz-mirai-worker-count-invariance-registry.R    (mirai backend)
# The two backends live in separate files because a fork cluster cannot be
# started once mirai has been used in the same R session (globals.R,
# make_configured_fork_cluster()); the fork file is named test-aa-* so it runs
# before any file that starts mirai daemons.
#
# Only function definitions live here: nothing runs at load time.

# Core counts to compare. CRAN policy allows at most 2 cores, so 4 needs
# NOT_CRAN=true; R CMD check --as-cran's _R_CHECK_LIMIT_CORES_ also caps at 2.
worker_invariance_core_counts = function() {
	available = parallel::detectCores(logical = TRUE)
	if (is.na(available)) available = 1L
	cores_limited = nzchar(Sys.getenv("_R_CHECK_LIMIT_CORES_")) &&
		!tolower(Sys.getenv("_R_CHECK_LIMIT_CORES_")) %in% c("false", "0")
	counts = 1L
	if (available >= 2L) counts = c(counts, 2L)
	if (available >= 4L && identical(Sys.getenv("NOT_CRAN"), "true") && !cores_limited) counts = c(counts, 4L)
	counts
}

worker_invariance_exhaustive = function() {
	identical(Sys.getenv("EDI_EXHAUSTIVE_WORKER_TESTS"), "true")
}

worker_invariance_with_seed = function(seed, expr) {
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(seed)
	expr
}

# One small data set per response type, rebuilt from a fixed seed on every
# call. A fresh design per run matters: the design caches the randomization
# permutations, which would otherwise be drawn once and shared by every core
# count, making the randomization comparison vacuous.
worker_invariance_design = function(response_type, n = 40L) {
	worker_invariance_with_seed(20261114L, {
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		w = des$get_w()
		eta = 0.5 * w + 0.3 * X$x1 - 0.2 * X$x2
		y = switch(response_type,
			continuous = 1 + eta + rnorm(n),
			incidence = stats::rbinom(n, 1L, stats::plogis(-0.2 + eta)),
			count = stats::rpois(n, exp(0.4 + eta)),
			proportion = stats::plogis(-0.1 + eta + rnorm(n, sd = 0.5)),
			survival = stats::rexp(n, rate = exp(-0.2 - eta)),
			ordinal = as.integer(cut(eta + stats::rlogis(n), c(-Inf, -0.8, 0.2, 1.1, Inf)))
		)
		des$add_all_subject_responses(y)
		des
	})
}

# Resampling procedures. Each is called with a small B/r; a procedure the class
# lacks is skipped by name, and one that errors is compared by its error
# message (it must fail the same way at every core count).
worker_invariance_procedures = list(
	estimate = list(method = "compute_estimate", args = list()),
	asymp_ci = list(method = "compute_asymp_confidence_interval", args = list()),
	asymp_pval = list(method = "compute_asymp_two_sided_pval", args = list()),
	bootstrap_ci = list(method = "compute_bootstrap_confidence_interval", args = list(B = 39L, show_progress = FALSE)),
	bootstrap_pval = list(method = "compute_bootstrap_two_sided_pval", args = list(B = 39L, show_progress = FALSE)),
	bayesian_bootstrap_ci = list(method = "compute_bayesian_bootstrap_confidence_interval", args = list(B = 39L, show_progress = FALSE)),
	bayesian_bootstrap_pval = list(method = "compute_bayesian_bootstrap_two_sided_pval", args = list(B = 39L, show_progress = FALSE)),
	rand_pval = list(method = "compute_rand_two_sided_pval", args = list(r = 39L, show_progress = FALSE)),
	rand_ci = list(method = "compute_rand_confidence_interval", args = list(r = 39L, show_progress = FALSE)),
	# The root search makes dozens of p-value calls, each a round trip to the
	# workers, so the parallel-dispatching randomization CI uses a smaller r.
	rand_ci_parallel = list(method = "compute_rand_confidence_interval", args = list(r = 19L, show_progress = FALSE)),
	rand_bootstrap_pval = list(method = "compute_rand_bootstrap_two_sided_pval", args = list(B = 39L, show_progress = FALSE)),
	param_bootstrap_lr_pval = list(method = "compute_lik_ratio_bootstrap_two_sided_pval", args = list(B = 19L, show_progress = FALSE)),
	param_bootstrap_ci = list(method = "compute_param_bootstrap_confidence_interval", args = list(B = 19L, show_progress = FALSE))
)

# Default (fast) coverage: one representative registry class per response
# type, and each resampling family on one class where it actually dispatches
# to R workers at 2 and 4 cores (measured 2026-11-14 on 12-core Linux: all of
# them on fork; on mirai the Bayesian bootstrap fell back to serial at 4
# daemons through its warmup heuristic, so it is a worker test there at 2
# only). The dispatched_cores column of the sweep report shows it per run:
#   nonparametric bootstrap CI    InferenceIncidLogRegr
#   Bayesian bootstrap CI / pval  InferenceOrdinalPropOddsRegr / InferenceCountPoisson
#   randomization p-value         InferenceSurvivalWeibullRegr
#   randomization bootstrap pval  InferencePropFractionalLogit
#   parametric bootstrap LR pval  InferenceContinOLS
#   asymptotic CI (dispatches)    InferenceCountPoisson
#   randomization p-value and CI  InferenceAllSimpleMeanDiffPooledVar (C++
#                                 kernel; no R workers, OpenMP budget only)
# Estimates and asymptotic CIs/p-values (OpenMP thread budget) run on every
# class. Why the default is this thin:
#   - Each parallel run costs ~0.5-1 s in worker round trips whatever B is, so
#     running every family on all seven classes took ~65 s on fork alone. The
#     default takes ~20 s on fork and ~40 s on mirai (daemon start-up and
#     loading EDI in each daemon dominate there).
#   - The randomization CI's root search makes dozens of p-value calls, each a
#     round trip to the workers (~11 s per backend at r = 19). It reuses the
#     p-value's parallel path, so its parallel form (rand_ci_parallel) runs
#     only in the exhaustive sweep.
#   - Bayesian bootstrap is forced serial for incidence and survival, and the
#     continuous classes' randomization runs in C++, so those pairings would
#     be vacuous as worker tests.
# Each class must be in EDI's inference registry, concrete and exported, and
# list its response type there; the test fails if one drops out, so the list
# cannot silently rot. EDI_EXHAUSTIVE_WORKER_TESTS=true replaces it with every
# procedure on every concrete, exported, non-IVWC registry class that runs on
# a plain Bernoulli design (no KK matching or blocking): more than 10 minutes
# per backend (an attempt on fork was cut off at 580 s on 2026-11-14).
worker_invariance_representatives = list(
	list(class = "InferenceAllSimpleMeanDiffPooledVar", response_type = "continuous",
		procedures = c("estimate", "asymp_ci", "rand_pval", "rand_ci")),
	list(class = "InferenceContinOLS", response_type = "continuous",
		procedures = c("estimate", "asymp_ci", "param_bootstrap_lr_pval")),
	list(class = "InferenceIncidLogRegr", response_type = "incidence",
		procedures = c("estimate", "asymp_pval", "bootstrap_ci")),
	list(class = "InferenceCountPoisson", response_type = "count",
		procedures = c("estimate", "asymp_ci", "bayesian_bootstrap_pval")),
	list(class = "InferencePropFractionalLogit", response_type = "proportion",
		procedures = c("estimate", "asymp_ci", "rand_bootstrap_pval")),
	list(class = "InferenceOrdinalPropOddsRegr", response_type = "ordinal",
		procedures = c("estimate", "asymp_ci", "bayesian_bootstrap_ci")),
	list(class = "InferenceSurvivalWeibullRegr", response_type = "survival",
		procedures = c("estimate", "asymp_ci", "rand_pval")),
	# Was the known failure of v1.0.6-TODO-22 (resamples drawn inside the
	# worker chunks); kept as the regression case for it.
	list(class = "InferencePropGCompMeanDiff", response_type = "proportion",
		procedures = c("bootstrap_ci", "bootstrap_pval"))
)

# KNOWN INVARIANCE FAILURES: keys class|response|procedure that the sweep
# reports instead of asserting. Empty since 2026-11-18: the one entry found by
# the first exhaustive sweep (InferencePropGCompMeanDiff bootstrap_ci and
# bootstrap_pval, whose worker chunks drew from their own RNG streams) was
# fixed as v1.0.6-TODO-22, and the nightly sweep found no other.
worker_invariance_known_failures = character(0)

worker_invariance_registry_cases = function() {
	registry = EDI:::inference_class_registry_as_list()
	concrete = Filter(function(e) !isTRUE(e$abstract) && isTRUE(e$exported), registry)
	if (!worker_invariance_exhaustive()) {
		for (case in worker_invariance_representatives) {
			entry = concrete[[case$class]]
			testthat::expect_false(is.null(entry),
				info = paste(case$class, "is no longer a concrete exported registry class"))
			if (!is.null(entry)) {
				testthat::expect_true(case$response_type %in% entry$response_types,
					info = paste(case$class, "no longer lists response type", case$response_type))
			}
			testthat::expect_true(all(case$procedures %in% names(worker_invariance_procedures)),
				info = paste(case$class, "lists an unknown procedure"))
		}
		return(Filter(function(case) !is.null(concrete[[case$class]]), worker_invariance_representatives))
	}
	cases = list()
	for (entry in concrete) {
		if (grepl("IVWC$", entry$name) || identical(entry$name, "InferenceRandCustom")) next
		if (isTRUE(entry$requires_kk_matching_design) || isTRUE(entry$requires_blocking_design)) next
		if (grepl("KK", entry$name)) next
		if (length(entry$required_packages) &&
			!all(vapply(entry$required_packages, requireNamespace, logical(1), quietly = TRUE))) next
		for (rt in intersect(entry$response_types, c("continuous", "incidence", "count", "proportion", "survival", "ordinal"))) {
			cases[[length(cases) + 1L]] = list(class = entry$name, response_type = rt,
				procedures = setdiff(names(worker_invariance_procedures), "rand_ci"))
		}
	}
	cases
}

# Builds a fresh design and inference object, wraps par_lapply() to record the
# n_cores it is handed (so the report can tell a real parallel dispatch from a
# heuristic fallback to serial), and runs one procedure. Returns the value (or
# the error message) and the n_cores values seen.
worker_invariance_run_once = function(case, procedure, seed = 99L) {
	des = worker_invariance_design(case$response_type)
	inference_class = get(case$class, envir = asNamespace("EDI"))
	inf = tryCatch(suppressWarnings(suppressMessages(inference_class$new(des, verbose = FALSE))),
		error = function(e) e)
	if (inherits(inf, "error")) return(list(status = "construct_error", value = conditionMessage(inf), used = integer()))
	if (!is.function(inf[[procedure$method]])) return(list(status = "absent", value = NULL, used = integer()))
	inf$set_seed(seed)
	priv = inf$.__enclos_env__$private
	used = integer()
	if (is.function(priv$par_lapply)) {
		original = priv$par_lapply
		unlockBinding("par_lapply", priv)
		priv$par_lapply = function(..., n_cores = self$num_cores) {
			used <<- c(used, as.integer(n_cores))
			original(..., n_cores = n_cores)
		}
		environment(priv$par_lapply) = list2env(list(original = original, self = inf), parent = environment())
		lockBinding("par_lapply", priv)
	}
	started = proc.time()[["elapsed"]]
	value = worker_invariance_with_seed(seed, tryCatch(
		suppressWarnings(suppressMessages(do.call(inf[[procedure$method]], procedure$args))),
		error = function(e) structure(conditionMessage(e), class = "worker_invariance_error")
	))
	status = if (inherits(value, "worker_invariance_error")) "error" else "ok"
	list(status = status, value = unclass(value), used = used, elapsed = proc.time()[["elapsed"]] - started)
}

# Runs every (case, procedure) at every core count on one backend and returns
# one row per (class, response type, procedure, core count). The serial run
# (1 core) is the reference: every other core count must be identical() to it.
worker_invariance_sweep = function(backend, core_counts = worker_invariance_core_counts(), known_failures = worker_invariance_known_failures) {
	stopifnot(backend %in% c("fork", "mirai"))
	pinned = !worker_invariance_exhaustive()
	cases = worker_invariance_registry_cases()
	results = list()
	for (cores in core_counts) {
		if (cores > 1L) {
			set_num_cores(cores, force_mirai = identical(backend, "mirai"))
		} else {
			unset_num_cores()
		}
		for (case in cases) {
			procs = worker_invariance_procedures[case$procedures]
			for (proc_name in names(procs)) {
				key = paste(case$class, case$response_type, proc_name, sep = "|")
				run = worker_invariance_run_once(case, procs[[proc_name]])
				results[[key]][[as.character(cores)]] = run
			}
		}
	}
	unset_num_cores()

	rows = list()
	for (key in names(results)) {
		by_cores = results[[key]]
		reference = by_cores[["1"]]
		parts = strsplit(key, "|", fixed = TRUE)[[1]]
		# A pinned representative must actually run its listed procedures, or
		# the invariance comparison below would be vacuous.
		if (pinned) {
			testthat::expect_identical(reference$status, "ok", info = paste0(
				parts[1], "$", parts[3], " (", parts[2], ") did not run serially: ",
				paste(unlist(reference$value), collapse = " ")))
		}
		for (cores in setdiff(names(by_cores), "1")) {
			run = by_cores[[cores]]
			if (identical(reference$status, "absent") || identical(reference$status, "construct_error")) next
			label = paste0(parts[1], "$", parts[3], " (", parts[2], ") on ", backend, ": 1 vs ", cores, " cores")
			# The nonparametric bootstrap has no serial-fallback heuristic, so
			# it must reach the workers; otherwise a future change making it
			# serial would turn this test into a no-op. Other families may
			# legitimately fall back to serial (warmup-timing heuristics,
			# dispatch policy), and are reported rather than asserted.
			if (pinned && parts[3] %in% c("bootstrap_ci", "bootstrap_pval") && identical(reference$status, "ok")) {
				testthat::expect_true(any(run$used == as.integer(cores)),
					info = paste(label, "-- bootstrap never dispatched to the workers"))
			}
			same = identical(run$status, reference$status) && identical(run$value, reference$value)
			# A known failure is reported, not asserted either way: whether it
			# differs depends on whether the run reached the workers (a mirai run
			# at 2 daemons can fall back to serial and match). The report's
			# known_failure column shows it.
			if (!(key %in% known_failures)) {
				testthat::expect_identical(run$status, reference$status, info = label)
				testthat::expect_identical(run$value, reference$value, info = label)
			}
			rows[[length(rows) + 1L]] = data.frame(
				backend = backend, class = parts[1], response_type = parts[2], procedure = parts[3],
				cores = as.integer(cores), status = run$status,
				dispatched_cores = if (length(run$used)) max(run$used) else NA_integer_,
				identical = same, known_failure = key %in% known_failures, seconds_serial = round(reference$elapsed, 2),
				seconds = round(run$elapsed, 2), stringsAsFactors = FALSE
			)
		}
	}
	do.call(rbind, rows)
}

# Parallel design draws: the OpenMP draw kernels (greedy, D-optimal,
# rerandomization, binary match) read the thread budget that set_num_cores()
# sets, so draw under set_num_cores(k) on this backend and compare the
# allocation matrices. test-cross-platform-reproducibility-digests.R covers the
# same kernels through set_package_threads() only.
worker_invariance_design_draws = function(backend, core_counts = worker_invariance_core_counts()) {
	builders = list(
		DesignFixedBernoulli = function(n) DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE),
		DesignFixedRerandomization = function(n) DesignFixedRerandomization$new(n = n, response_type = "continuous", obj_val_cutoff = Inf, verbose = FALSE),
		DesignFixedGreedy = function(n) DesignFixedGreedy$new(n = n, response_type = "continuous", verbose = FALSE),
		DesignFixedGreedyDOptimal = function(n) DesignFixedGreedyDOptimal$new(n = n, response_type = "continuous", verbose = FALSE)
	)
	if (requireNamespace("nbpMatching", quietly = TRUE)) {
		builders$DesignFixedBinaryMatch = function(n) DesignFixedBinaryMatch$new(n = n, response_type = "continuous", verbose = FALSE)
	}
	n = 40L
	X = worker_invariance_with_seed(7L, data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n)))
	draws = list()
	for (cores in core_counts) {
		if (cores > 1L) set_num_cores(cores, force_mirai = identical(backend, "mirai")) else unset_num_cores()
		for (name in names(builders)) {
			des = builders[[name]](n)
			des$add_all_subjects_to_experiment(X)
			draws[[name]][[as.character(cores)]] = worker_invariance_with_seed(20261114L, des$draw_ws_according_to_design(25L))
		}
	}
	unset_num_cores()
	for (name in names(draws)) {
		for (cores in setdiff(names(draws[[name]]), "1")) {
			testthat::expect_identical(draws[[name]][[cores]], draws[[name]][["1"]],
				info = paste(name, "draws on", backend, ": 1 vs", cores, "cores"))
		}
	}
	invisible(draws)
}

worker_invariance_report = function(rows) {
	if (is.null(rows) || !nrow(rows)) return(invisible(NULL))
	if (identical(Sys.getenv("EDI_WORKER_INVARIANCE_VERBOSE"), "true")) print(rows, row.names = FALSE)
	invisible(rows)
}
