library(testthat)
library(EDI)

# Structural gate for the bug family behind
# `fix_stale_worker_cache_resampling.md`: the reused-worker resampling loaders
# reset a worker's per-class estimate cache between draws, and for years they
# reset only a hardcoded allowlist of four keys
# (`KKstats`/`beta_hat_T`/`s_beta_hat_T`/`likelihood_null_warm_cache`). Every
# class whose `shared()` guards its early return on a *different* key --
# `md` for the G-computation mean-difference classes, `rd`/`rr` for the
# incidence G-computation mixins, `lin_*_complete` for Lin -- therefore never
# refit after draw 1: draws 2..r returned draw 1's cached estimate, so the
# "randomization distribution" was r bit-identical copies of one number and the
# two-sided p-value sat at its floor on every call. Silently wrong numbers, not
# an error, and it took a comprehensive_tests CSV audit to notice.
#
# This file is the general guard that should have caught it first: for every
# concrete class that actually goes through the reused-worker randomization
# path, the returned distribution must not be a point mass.
#
# The criterion is self-calibrating rather than a flat `sd() > 0`: a tiny
# synthetic fixture can be genuinely degenerate for a class (e.g. a rank
# statistic on heavily tied counts), and that is not a defect. So a degenerate
# reused-worker distribution is only a failure when the *same class, same data*
# produces a varying distribution on the standard duplicate-per-iteration path,
# which builds a fresh object per draw and so cannot carry a stale cache.
#
# Kept cheap enough for .githooks/pre-push (see scripts/run_structural_checks.R):
# n = 20 subjects, r = 15 draws, serial, and the (slower) reference path only
# runs for the handful of classes whose fast check came back degenerate.

RESAMPLING_NONDEGENERATE_N = 20L
RESAMPLING_NONDEGENERATE_R = 15L
RESAMPLING_NONDEGENERATE_SEED = 20260922L

# Classes whose reused-worker randomization path is known to be broken for a
# reason OTHER than the stale cache this file guards, and which are therefore
# expected to show up as degenerate here. Keep this list empty whenever
# possible; the expectation below fails if an entry is fixed (so the entry gets
# removed) or if a new class regresses into degeneracy (so it gets fixed).
#
#   * InferencePropGCompMeanDiff -- its `compute_bootstrap_worker_estimate()`
#     returns NA unless `worker_state$runtime$sample_usable` is TRUE, and only
#     the *bootstrap* row-sample loader ever sets that field. The randomization
#     loader installs a permuted assignment without touching `runtime`, so every
#     randomization draw returns NA. That is a worker-state defect, not a
#     `cached_values` one, and needs the class to rebuild its `runtime$
#     current_X_full` from the permuted assignment -- deliberately out of scope
#     for fix_stale_worker_cache_resampling.md (reported there as a follow-up).
RESAMPLING_NONDEGENERATE_KNOWN_BROKEN = c("InferencePropGCompMeanDiff")

# Builds a probe subclass of `generator`:
#   * `compute_fast_randomization_distr()` returns NULL so a class that owns a
#     vectorized kernel still exercises the reused-worker loader (the base class
#     falls through to it whenever the fast path yields NULL);
#   * `supports_reusable_bootstrap_worker()` is forced, so the same probe can
#     produce the reused-worker distribution and the standard-path reference.
# The probe's `parent_env` must chain to the EDI namespace, or the subclass's
# inherited methods cannot see package-internal helpers such as
# `gcomp_standardized_effect_cache_is_ready()`. R6 also evaluates `inherit`
# lazily in that same `parent_env`, so the generator is bound there by name
# rather than passed as a value. `lock_objects = FALSE` matches
# `define_inference_class()`, whose worker machinery adds private bindings at
# runtime.
resampling_nondegenerate_probe = function(generator, classname, reusable){
	probe_env = new.env(parent = asNamespace("EDI"))
	probe_env$resampling_nondegenerate_parent_generator = generator
	R6::R6Class(
		paste0("ReusedWorkerProbe", classname, if (reusable) "Fast" else "Standard"),
		inherit = resampling_nondegenerate_parent_generator,
		lock_objects = FALSE,
		parent_env = probe_env,
		private = list(
			compute_fast_randomization_distr = function(...) NULL,
			# Literal closures, not `function() reusable`: R6 re-enclosures every
			# method into the object's environment, whose parent is `probe_env`,
			# so a method body may not close over this function's locals.
			supports_reusable_bootstrap_worker = if (reusable) function() TRUE else function() FALSE
		)
	)
}

resampling_nondegenerate_distinct_values = function(generator, classname, des_obj, reusable){
	obj = tryCatch(
		resampling_nondegenerate_probe(generator, classname, reusable)$new(des_obj, verbose = FALSE),
		error = function(e) NULL
	)
	if (is.null(obj)) return(NA_integer_)
	obj$num_cores = 1L
	set.seed(RESAMPLING_NONDEGENERATE_SEED)
	values = tryCatch(
		suppressWarnings(as.numeric(obj$approximate_randomization_distribution_beta_hat_T(
			r = RESAMPLING_NONDEGENERATE_R,
			show_progress = FALSE
		))),
		error = function(e) NA_real_
	)
	length(unique(values[is.finite(values)]))
}

# Every concrete registered class x response type that (a) constructs on the
# shared synthetic fixture and (b) actually uses a reusable randomization
# worker. Driven off the registry rather than a hand-kept list so a class added
# later is covered automatically -- a hardcoded list is what let the original
# bug hide.
resampling_nondegenerate_cases = function(response_type, des_obj){
	ns = asNamespace("EDI")
	registry = EDI:::inference_class_registry_as_list()
	cases = list()
	for (classname in names(registry)) {
		entry = registry[[classname]]
		if (isTRUE(entry$abstract)) next
		if (!isTRUE(response_type %in% entry$response_types)) next
		if (isTRUE(entry$requires_kk_matching_design)) next
		if (isTRUE(entry$requires_blocking_design)) next
		if (!exists(classname, envir = ns, inherits = FALSE)) next
		generator = get(classname, envir = ns)
		if (!R6::is.R6Class(generator)) next
		probe = tryCatch(generator$new(des_obj, verbose = FALSE), error = function(e) NULL)
		if (is.null(probe)) next
		probe_private = probe$.__enclos_env__$private
		uses_worker = isTRUE(tryCatch(probe_private$use_reusable_bootstrap_worker(), error = function(e) FALSE))
		if (!uses_worker) next
		if (!is.function(probe$approximate_randomization_distribution_beta_hat_T)) next
		cases[[length(cases) + 1L]] = list(classname = classname, generator = generator)
	}
	cases
}

test_that("reused-worker randomization distributions are not degenerate point masses", {
	response_types = c("continuous", "incidence", "count", "proportion", "ordinal", "survival")
	degenerate = character()
	covered = character()
	for (response_type in response_types) {
		des_obj = EDI:::inference_migration_complete_design(
			response_type,
			n = RESAMPLING_NONDEGENERATE_N,
			seed = RESAMPLING_NONDEGENERATE_SEED
		)
		cases = resampling_nondegenerate_cases(response_type, des_obj)
		for (case in cases) {
			label = paste0(case$classname, " (", response_type, ")")
			covered = c(covered, label)
			n_distinct = resampling_nondegenerate_distinct_values(
				case$generator, case$classname, des_obj, reusable = TRUE
			)
			if (!is.na(n_distinct) && n_distinct > 1L) next
			# Degenerate on the reused-worker path. Only a defect if the standard
			# duplicate-per-iteration path -- immune to worker-cache staleness by
			# construction -- varies on exactly the same data.
			n_distinct_reference = resampling_nondegenerate_distinct_values(
				case$generator, case$classname, des_obj, reusable = FALSE
			)
			if (!is.na(n_distinct_reference) && n_distinct_reference > 1L) {
				degenerate = c(degenerate, label)
			}
		}
	}
	# A non-trivial sweep really ran (guards against the enumeration silently
	# collapsing to zero cases and the test passing vacuously).
	expect_gt(length(covered), 30L)
	expect_identical(
		sort(unique(sub(" \\(.*$", "", degenerate))),
		sort(RESAMPLING_NONDEGENERATE_KNOWN_BROKEN),
		info = paste0(
			"Reused-worker randomization distribution is a point mass while the ",
			"standard path varies, for: ", paste(degenerate, collapse = ", "),
			". See fix_stale_worker_cache_resampling.md -- a class caching its ",
			"point estimate under a key the per-draw loader does not reset will ",
			"return draw 1's value for every later draw."
		)
	)
})

test_that("reused-worker bootstrap distributions are not degenerate for custom-cache-key classes", {
	# The other three reusable-worker operations (non_param_boot, m_out_of_n_boot,
	# rand_bootstrap) all route through load_bootstrap_sample_into_design_backed_
	# worker(), which already replaces the worker's whole `cached_values`. Pin that
	# down for the classes whose `shared()` guards on a custom key, so a future
	# narrowing of that reset is caught here rather than in a results audit.
	cases = list(
		list(classname = "InferenceOrdinalGCompMeanDiff", response_type = "ordinal"),
		list(classname = "InferenceIncidGCompRiskDiff", response_type = "incidence"),
		list(classname = "InferenceIncidGCompRiskRatio", response_type = "incidence"),
		list(classname = "InferenceContinLin", response_type = "continuous")
	)
	for (case in cases) {
		des_obj = EDI:::inference_migration_complete_design(
			case$response_type,
			n = RESAMPLING_NONDEGENERATE_N,
			seed = RESAMPLING_NONDEGENERATE_SEED
		)
		generator = get(case$classname, envir = asNamespace("EDI"))
		obj = generator$new(des_obj, verbose = FALSE)
		obj$num_cores = 1L
		set.seed(RESAMPLING_NONDEGENERATE_SEED)
		values = suppressWarnings(as.numeric(obj$approximate_bootstrap_distribution_beta_hat_T(
			B = RESAMPLING_NONDEGENERATE_R,
			show_progress = FALSE
		)))
		finite_values = values[is.finite(values)]
		expect_gt(length(finite_values), 1L)
		expect_gt(length(unique(finite_values)), 1L)
	}
})
