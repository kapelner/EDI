library(testthat)
library(EDI)

# v1.1.0 cross_platform_reproducibility.md TODO-2: same-binary determinism
# (owner decision D3, the "exact on one build" level). For every concrete,
# exported, non-IVWC inference class in the registry, at its defaults:
#   - two runs with the same seed, and
#   - a run at set_num_cores(1) and a run at set_num_cores(4)
# must give identical() -- not tolerance-equal -- estimates, SEs, CIs and
# p-values. "Defaults" means the class constructed with no optional
# arguments, then compute_estimate(), get_summary() (estimate, SE, statistic,
# p-value), the asymptotic CI and p-value, and a small randomization p-value
# (the OpenMP and R-worker resampling path every class has). A procedure that
# errors must error with the same message every time.
#
# Fixtures come in three arms, chosen from each class's own registry
# requirements: a fixed Bernoulli design, a KK14 matching-on-the-fly design
# (requires_kk_matching_design), and a blocked design
# (requires_blocking_design). Every design is rebuilt from a fixed seed for
# each run, since a design caches the randomization permutations it drew.
#
# The worker-count invariance tests (test-aa-fork-* and test-zz-mirai-*, with
# helper-worker-count-invariance.R) cover each resampling family on a few
# representative classes; this file covers every class on its default path.
#
# Skipped on CRAN, for the lean pre-push run (EDI_PREPUSH_NO_PARALLEL=true),
# under covr, off Linux, after mirai has been used in the session (fork
# clusters cannot start then), and when fewer than 4 logical cores exist.
# Runs nightly via the repro job's filter ("same-binary-determinism").

SAME_BINARY_N = 40L
SAME_BINARY_DATA_SEED = 20261115L
SAME_BINARY_RUN_SEED = 4242L
SAME_BINARY_RAND_R = 49L
SAME_BINARY_RESPONSE_TYPES = c("continuous", "incidence", "count", "proportion", "survival", "ordinal")

# KNOWN DETERMINISM FAILURES: class|response_type|procedure|comparison, where
# comparison is "rerun" (same seed, same core count) or "cores" (1 vs 4).
# Found 2026-11-16 on the installed EDI 1.0.4 (three full local runs); not
# fixed here. They are reported, not asserted either way, as in
# helper-worker-count-invariance.R's known failures, because the first group
# comes and goes with R's memory layout. Remove an entry once it is fixed.
#
# Each entry cites the release_v1_0_6.md TODO that fixes it.
#
# (1) release_v1_0_6.md TODO-34. Memory-alignment-dependent sums, InferenceBaiAdjustedTKK14/KK21 (every
#     non-resampling output; seen in 3 of 3 runs, on varying comparisons).
#     The estimate is d_bar = mean_cpp(y_matched_diffs), and mean_cpp
#     (_helper_functions.cpp) is Eigen::Map<VectorXd>::mean(). Eigen's
#     vectorized reduction peels scalars until the pointer is packet-aligned,
#     so the summation order depends on where R happened to allocate the
#     vector: the same 17 numbers gave two different means (last bit) across
#     300 fresh copies. Any Eigen::Map reduction (sum, mean, dot, squaredNorm)
#     on R-allocated memory has this property; Bai is where this sweep sees it.
# (2) Fixed 2026-11-19 (release_v1_0_6.md TODO-35, by TODO-61): the worker-count-
#     dependent randomization p-values of InferenceIncidBinomialIdentityRiskDiff,
#     InferenceIncidKKCondLogitGLMMOneLik and InferenceOrdinalGCompMeanDiff came
#     from warm starts chained between replicates within each worker's chunk.
#     Replicates no longer chain, and the three pass (3 local runs).
SAME_BINARY_KNOWN_FAILURES = c(
	as.vector(outer(   # v1.0.6 TODO-34
		c("InferenceBaiAdjustedTKK14|continuous", "InferenceBaiAdjustedTKK21|continuous"),
		as.vector(outer(c("estimate", "summary", "asymp_ci", "asymp_pval"), c("rerun", "cores"), paste, sep = "|")),
		paste, sep = "|"))
)

same_binary_with_seed = function(seed, expr) {
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()) else
		if (exists(".Random.seed", envir = globalenv())) rm(".Random.seed", envir = globalenv()), add = TRUE)
	set.seed(seed)
	expr
}

same_binary_covariates = function(n, with_block = FALSE) {
	x = data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	if (with_block) x$blk = rep(c("a", "b"), each = n %/% 2L)[seq_len(n)]
	x
}

same_binary_responses = function(response_type, w01, x) {
	n = length(w01)
	eta = 0.5 * w01 + 0.3 * x$x1 - 0.2 * x$x2
	switch(response_type,
		continuous = list(y = 1 + eta + stats::rnorm(n)),
		incidence = list(y = stats::rbinom(n, 1L, stats::plogis(-0.2 + eta))),
		count = {
			y = stats::rpois(n, exp(0.4 + eta))
			# structural zeros keep the zero-inflated/hurdle classes identified
			y[seq(3L, n, by = 4L)] = 0L
			list(y = y)
		},
		proportion = list(y = pmin(0.95, pmax(0.05, stats::plogis(-0.1 + eta + stats::rnorm(n, sd = 0.5))))),
		survival = {
			t_event = stats::rexp(n, rate = exp(-0.2 - eta))
			t_cens = stats::rexp(n, rate = 0.25)
			list(y = pmin(t_event, t_cens), dead = as.integer(t_event <= t_cens))
		},
		ordinal = list(y = as.integer(cut(eta + stats::rlogis(n), c(-Inf, -0.8, 0.2, 1.1, Inf))))
	)
}

# Right-censored subjects are recorded as the interval (y_L, Inf).
same_binary_add_responses_fixed = function(des, resp) {
	if (is.null(resp$dead)) return(des$add_all_subject_responses(resp$y))
	ev = resp$dead == 1L
	des$add_all_subject_responses(ifelse(ev, resp$y, NA), y_Ls = ifelse(ev, NA, resp$y), y_Rs = ifelse(ev, NA, Inf))
}

same_binary_arms = list(
	bernoulli = list(
		selects = function(entry) !isTRUE(entry$requires_kk_matching_design) && !isTRUE(entry$requires_blocking_design),
		build = function(response_type) same_binary_with_seed(SAME_BINARY_DATA_SEED, {
			x = same_binary_covariates(SAME_BINARY_N)
			des = DesignFixedBernoulli$new(n = SAME_BINARY_N, response_type = response_type, verbose = FALSE)
			des$add_all_subjects_to_experiment(x)
			des$assign_w_to_all_subjects()
			same_binary_add_responses_fixed(des, same_binary_responses(response_type, as.integer(des$get_w() == 1L), x))
			des
		})
	),
	kk = list(
		selects = function(entry) isTRUE(entry$requires_kk_matching_design),
		build = function(response_type) same_binary_with_seed(SAME_BINARY_DATA_SEED, {
			x = same_binary_covariates(SAME_BINARY_N)
			des = DesignSeqOneByOneKK14$new(n = SAME_BINARY_N, response_type = response_type, verbose = FALSE)
			EDI:::inference_migration_add_subjects(des, x)
			resp = same_binary_responses(response_type, as.integer(des$.__enclos_env__$private$w == 1L), x)
			EDI:::add_all_subject_responses_seq(des, resp$y, deads = resp$dead)
			des
		})
	),
	blocking = list(
		selects = function(entry) isTRUE(entry$requires_blocking_design),
		build = function(response_type) same_binary_with_seed(SAME_BINARY_DATA_SEED, {
			x = same_binary_covariates(SAME_BINARY_N, with_block = TRUE)
			des = DesignFixedBlocking$new(n = SAME_BINARY_N, response_type = response_type,
				strata_cols = "blk", equal_block_sizes = TRUE, verbose = FALSE)
			des$add_all_subjects_to_experiment(x)
			des$assign_w_to_all_subjects()
			same_binary_add_responses_fixed(des, same_binary_responses(response_type, as.integer(des$get_w() == 1L), x))
			des
		})
	)
)

same_binary_procedures = list(
	estimate = function(inf) inf$compute_estimate(),
	# get_summary() also prints the table; only the returned value is compared
	summary = function(inf) { out = NULL; utils::capture.output(out <- inf$get_summary()); out },
	asymp_ci = function(inf) inf$compute_asymp_confidence_interval(),
	asymp_pval = function(inf) inf$compute_asymp_two_sided_pval(),
	rand_pval = function(inf) inf$compute_rand_two_sided_pval(r = SAME_BINARY_RAND_R, show_progress = FALSE)
)

same_binary_cases = function() {
	registry = EDI:::inference_class_registry_as_list()
	ns = asNamespace("EDI")
	cases = list()
	for (entry in registry) {
		if (isTRUE(entry$abstract) || !isTRUE(entry$exported)) next
		if (grepl("IVWC$", entry$name) || identical(entry$name, "InferenceRandCustom")) next
		if (!exists(entry$name, envir = ns, inherits = FALSE)) next
		if (length(entry$required_packages) &&
			!all(vapply(entry$required_packages, requireNamespace, logical(1), quietly = TRUE))) next
		# The class's own arm first; the others are fallbacks for a class whose
		# design-compatibility rule rejects it (InferenceIncidExactFisher needs
		# a blocked or matched design, not a Bernoulli one).
		primary = names(Filter(function(a) a$selects(entry), same_binary_arms))[1L]
		arms = c(primary, setdiff(names(same_binary_arms), primary))
		for (rt in intersect(entry$response_types, SAME_BINARY_RESPONSE_TYPES)) {
			cases[[length(cases) + 1L]] = list(class = entry$name, response_type = rt, arms = arms)
		}
	}
	cases
}

# One run of every default procedure for one case, on a freshly built design
# and inference object. Returns a named list of values (errors as their
# message, tagged) or a construct/compatibility status.
same_binary_run_case = function(case) {
	for (arm in case$arms) {
		des = tryCatch(same_binary_arms[[arm]]$build(case$response_type), error = function(e) e)
		if (inherits(des, "error")) return(list(status = "design_error", arm = arm, detail = conditionMessage(des)))
		reason = tryCatch(EDI:::inference_class_design_compatibility_reason(case$class, des), error = function(e) NA_character_)
		if (is.na(reason)) break
	}
	if (!is.na(reason)) return(list(status = "incompatible", detail = reason))
	generator = get(case$class, envir = asNamespace("EDI"))
	inf = tryCatch(suppressWarnings(suppressMessages(generator$new(des, verbose = FALSE))), error = function(e) e)
	if (inherits(inf, "error")) return(list(status = "construct_error", detail = conditionMessage(inf)))
	inf$set_seed(SAME_BINARY_RUN_SEED)
	values = lapply(same_binary_procedures, function(proc) {
		same_binary_with_seed(SAME_BINARY_RUN_SEED, tryCatch(
			suppressWarnings(suppressMessages(proc(inf))),
			error = function(e) structure(conditionMessage(e), class = "same_binary_error")))
	})
	list(status = "ok", arm = arm, values = values)
}

same_binary_sweep = function(cases, cores) {
	if (cores > 1L) set_num_cores(cores) else unset_num_cores()
	lapply(cases, same_binary_run_case)
}

skip_same_binary_determinism = function() {
	skip_on_cran()
	skip_if_prepush_no_parallel()
	skip_if_not(identical(Sys.info()[["sysname"]], "Linux"), "same-binary determinism is tested on Linux")
	skip_if(identical(Sys.getenv("R_COVR"), "true"),
		"avoid spawning a real fork cluster under covr's gcov-instrumented build")
	skip_if(isTRUE(EDI:::edi_env$mirai_has_been_used),
		"fork clusters cannot be started safely after mirai has been used in this R session")
	available = parallel::detectCores(logical = TRUE)
	skip_if(is.na(available) || available < 4L, "fewer than 4 logical cores available")
	cores_limited = nzchar(Sys.getenv("_R_CHECK_LIMIT_CORES_")) &&
		!tolower(Sys.getenv("_R_CHECK_LIMIT_CORES_")) %in% c("false", "0")
	skip_if(cores_limited, "_R_CHECK_LIMIT_CORES_ caps the core count below 4")
}

test_that("every registry inference class is identical() across reruns and at 1 vs 4 cores", {
	skip_same_binary_determinism()
	on.exit(unset_num_cores(), add = TRUE)
	cases = same_binary_cases()
	expect_gt(length(cases), 80L)
	first = same_binary_sweep(cases, 1L)
	rerun = same_binary_sweep(cases, 1L)
	four = same_binary_sweep(cases, 4L)
	unset_num_cores()

	rows = list()
	failures = character()
	for (i in seq_along(cases)) {
		case = cases[[i]]
		ref = first[[i]]
		for (cmp in c("rerun", "cores")) {
			other = if (identical(cmp, "rerun")) rerun[[i]] else four[[i]]
			if (!identical(ref$status, "ok") || !identical(other$status, "ok")) {
				key = paste(case$class, case$response_type, "construct", cmp, sep = "|")
				same = identical(ref, other)
				if (!same) failures = c(failures, key)
				rows[[length(rows) + 1L]] = data.frame(class = case$class, response_type = case$response_type,
					arm = if (is.null(ref$arm)) NA_character_ else ref$arm, procedure = ref$status, comparison = cmp, identical = same,
					stringsAsFactors = FALSE)
				next
			}
			for (proc in names(same_binary_procedures)) {
				key = paste(case$class, case$response_type, proc, cmp, sep = "|")
				same = identical(ref$values[[proc]], other$values[[proc]])
				if (!same) failures = c(failures, key)
				rows[[length(rows) + 1L]] = data.frame(class = case$class, response_type = case$response_type,
					arm = ref$arm, procedure = proc, comparison = cmp, identical = same,
					stringsAsFactors = FALSE)
			}
		}
	}
	rows = do.call(rbind, rows)
	if (identical(Sys.getenv("EDI_SAME_BINARY_VERBOSE"), "true")) {
		print(rows[!rows$identical, , drop = FALSE], row.names = FALSE)
	}
	# Guard against a vacuous sweep: most classes must have actually run.
	ran = unique(rows$class[rows$procedure %in% names(same_binary_procedures)])
	expect_gt(length(ran), 70L)

	# Known failures are reported, not asserted either way: the alignment-
	# dependent ones come and go with R's memory layout (see the list above).
	unexpected = setdiff(failures, SAME_BINARY_KNOWN_FAILURES)
	expect_true(length(unexpected) == 0L, info = paste0(
		"not identical() across reruns (rerun) or at 1 vs 4 cores (cores):\n  ",
		paste(unexpected, collapse = "\n  ")))
	known_seen = intersect(failures, SAME_BINARY_KNOWN_FAILURES)
	if (length(known_seen) && identical(Sys.getenv("EDI_SAME_BINARY_VERBOSE"), "true")) {
		message("known same-binary determinism failures seen this run:\n  ", paste(known_seen, collapse = "\n  "))
	}
})
