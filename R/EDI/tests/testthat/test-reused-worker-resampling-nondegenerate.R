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
# concrete class that goes through the reused-worker randomization path, the
# returned distribution must not be a point mass.
#
# "Every concrete class" means every one the registry lists, so the fixtures
# come in three arms -- a plain sequential Bernoulli design, a KK
# matching-on-the-fly design, and a blocked design -- because ~45% of the
# catalog declares `requires_kk_matching_design` or `requires_blocking_design`
# and cannot be constructed on a Bernoulli design at all. Sweeping only the
# Bernoulli arm would leave the majority of the KK half of the package
# unguarded, which would undercut the whole point of replacing the loader's
# allowlist with a denylist: the guard must not be able to miss a class either.
#
# The degeneracy criterion is self-calibrating rather than a flat `sd() > 0`: a
# small fixture can be legitimately degenerate for a class (a rank statistic on
# heavily tied counts, say), and that is not a defect. So a degenerate
# reused-worker distribution is only a failure when the *same class, same data*
# produces a varying distribution on the standard duplicate-per-iteration path,
# which builds a fresh object per draw and so cannot carry a stale cache.
#
# Kept cheap enough for .githooks/pre-push (see scripts/run_structural_checks.R):
# serial, r = 15 draws, small fixtures, and the (slower) reference path only
# runs for the handful of classes whose fast check came back degenerate.
#
# `scripts/reused_worker_bitforbit_sweep.R` is the companion script that re-runs
# this file's enumeration (it evaluates the helper definitions below, so the two
# can never drift apart in which classes they cover) as a pre-change/post-change
# bit-for-bit comparison. That is how the standing "an already-correct class
# must not move" constraint is verified when this machinery is touched.

RESAMPLING_NONDEGENERATE_N_BERNOULLI = 20L
RESAMPLING_NONDEGENERATE_N_STRUCTURED = 40L
RESAMPLING_NONDEGENERATE_R = 15L
RESAMPLING_NONDEGENERATE_SEED = 20260922L
RESAMPLING_NONDEGENERATE_RESPONSE_TYPES = c(
	"continuous", "incidence", "count", "proportion", "ordinal", "survival"
)

# Classes whose reused-worker randomization path is degenerate for a reason
# OTHER than the stale cache this file guards. Keep this list empty whenever
# possible: the expectation below fails if an entry is fixed (so the entry gets
# removed) or if a new class regresses into degeneracy (so it gets fixed).
#
# Both prior entries fixed 2026-09-23:
#   * InferencePropGCompMeanDiff -- its `compute_bootstrap_worker_estimate()`
#     returned NA unless `worker_state$runtime$sample_usable` was TRUE, a field
#     only the *bootstrap* row-sample loader ever set. Fixed with a dedicated
#     `compute_randomization_worker_estimate()` override that mirrors the
#     already-correct standard-path logic
#     (`compute_treatment_estimate_during_randomization_inference()`'s
#     `shared()` + `cached_values$md`) on the worker clone instead of `self`;
#     see fix_prop_gcomp_sample_usable_gating.md.
#   * InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC -- `shared()`'s
#     inverse-variance pooling weight (`w_star = ssq_r / (ssq_r + ssq_m)`) used
#     `ssq_m`/`ssq_r` unconditionally, both deliberately `NA` under
#     `estimate_only = TRUE` (every resampling draw), making `beta_hat_T`
#     unconditionally NA. Fixed with the same equal-weight fallback already
#     correct elsewhere in the file
#     (`compute_treatment_estimate_during_randomization_inference()`); see
#     fix_glmm_weibull_frailty_ivwc_estimate_only_na_pooling.md.
RESAMPLING_NONDEGENERATE_KNOWN_BROKEN = character(0)

# Responses for the structured-design arms, mirroring the recipe
# `inference_migration_complete_design()` uses for the Bernoulli arm. It is
# mirrored rather than reused because the KK and blocked designs need a
# different subject-entry flow (one-by-one with on-the-fly matching, and
# add-all-then-assign, respectively) than that helper's Bernoulli flow.
resampling_nondegenerate_responses = function(response_type, w01, x){
	n = length(w01)
	linpred = -0.2 + 0.55 * w01 + 0.25 * x$x - 0.15 * x$z
	if (identical(response_type, "continuous")) {
		return(list(y = 0.4 + 0.8 * w01 + 0.35 * x$x - 0.2 * x$z + seq(-0.3, 0.3, length.out = n), dead = NULL))
	}
	if (identical(response_type, "incidence")) {
		return(list(y = as.integer(stats::plogis(linpred) > stats::quantile(stats::plogis(linpred), 0.45)), dead = NULL))
	}
	if (identical(response_type, "count")) {
		return(list(y = as.integer(pmax(0L, round(exp(0.6 + 0.35 * w01 + 0.2 * x$x)))), dead = NULL))
	}
	if (identical(response_type, "proportion")) {
		return(list(y = pmin(0.95, pmax(0.05, stats::plogis(linpred))), dead = NULL))
	}
	if (identical(response_type, "ordinal")) {
		score = linpred + seq(-0.4, 0.4, length.out = n)
		return(list(y = as.integer(cut(score, breaks = c(-Inf, -0.15, 0.25, 0.65, Inf), labels = FALSE)), dead = NULL))
	}
	y_latent = exp(1.2 - 0.25 * w01 + 0.1 * x$x)
	censoring = exp(1.35 + 0.05 * x$z)
	list(y = pmin(y_latent, censoring), dead = as.integer(y_latent <= censoring))
}

resampling_nondegenerate_covariates = function(n, with_block = FALSE){
	x = data.frame(
		x = seq(-1.1, 1.1, length.out = n),
		z = rep(c(0L, 1L, 1L, 0L), length.out = n)
	)
	if (with_block) x$blk = rep(c("a", "b"), each = n %/% 2L)[seq_len(n)]
	x
}

resampling_nondegenerate_bernoulli_design = function(response_type){
	EDI:::inference_migration_complete_design(
		response_type,
		n = RESAMPLING_NONDEGENERATE_N_BERNOULLI,
		seed = RESAMPLING_NONDEGENERATE_SEED
	)
}

resampling_nondegenerate_kk_design = function(response_type){
	n = RESAMPLING_NONDEGENERATE_N_STRUCTURED
	EDI:::inference_migration_with_seed(RESAMPLING_NONDEGENERATE_SEED, {
		x = resampling_nondegenerate_covariates(n)
		des_obj = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
		EDI:::inference_migration_add_subjects(des_obj, x)
		w01 = as.integer(des_obj$.__enclos_env__$private$w == 1L)
		responses = resampling_nondegenerate_responses(response_type, w01, x)
		EDI:::add_all_subject_responses_seq(des_obj, responses$y, deads = responses$dead)
		des_obj
	})
}

resampling_nondegenerate_blocking_design = function(response_type){
	n = RESAMPLING_NONDEGENERATE_N_STRUCTURED
	EDI:::inference_migration_with_seed(RESAMPLING_NONDEGENERATE_SEED, {
		x = resampling_nondegenerate_covariates(n, with_block = TRUE)
		des_obj = DesignFixedBlocking$new(
			n = n, response_type = response_type,
			strata_cols = "blk", equal_block_sizes = TRUE, verbose = FALSE
		)
		des_obj$add_all_subjects_to_experiment(x)
		des_obj$assign_w_to_all_subjects()
		w01 = as.integer(des_obj$get_w() == 1L)
		responses = resampling_nondegenerate_responses(response_type, w01, x)
		if (is.null(responses$dead)) {
			des_obj$add_all_subject_responses(responses$y)
		} else {
			des_obj$add_all_subject_responses(responses$y, responses$dead)
		}
		des_obj
	})
}

# One arm per design family a registered class can require. `selects` is the
# registry predicate, so the split is driven by the classes' own declared
# requirements rather than by a hand-kept class list -- a hardcoded list is what
# let the original bug hide.
resampling_nondegenerate_arms = function(){
	list(
		list(
			name = "bernoulli",
			build = resampling_nondegenerate_bernoulli_design,
			selects = function(entry) {
				!isTRUE(entry$requires_kk_matching_design) && !isTRUE(entry$requires_blocking_design)
			}
		),
		list(
			name = "kk",
			build = resampling_nondegenerate_kk_design,
			selects = function(entry) isTRUE(entry$requires_kk_matching_design)
		),
		list(
			name = "blocking",
			build = resampling_nondegenerate_blocking_design,
			selects = function(entry) isTRUE(entry$requires_blocking_design)
		)
	)
}

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

# Every concrete registered class this arm's design family covers that (a)
# constructs on the fixture and (b) actually uses a reusable randomization
# worker. Returns an empty list when the arm has no classes for this response
# type, so the caller can skip building a fixture it would not use.
resampling_nondegenerate_cases = function(arm, response_type, des_obj){
	ns = asNamespace("EDI")
	registry = EDI:::inference_class_registry_as_list()
	cases = list()
	for (classname in names(registry)) {
		entry = registry[[classname]]
		if (isTRUE(entry$abstract)) next
		if (!isTRUE(response_type %in% entry$response_types)) next
		if (!isTRUE(arm$selects(entry))) next
		if (!exists(classname, envir = ns, inherits = FALSE)) next
		generator = get(classname, envir = ns)
		if (!R6::is.R6Class(generator)) next
		if (is.null(des_obj)) {
			# Caller is only asking whether this arm has any candidate at all.
			cases[[length(cases) + 1L]] = list(classname = classname, generator = generator)
			next
		}
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
	degenerate = character()
	covered = character()
	for (arm in resampling_nondegenerate_arms()) {
		for (response_type in RESAMPLING_NONDEGENERATE_RESPONSE_TYPES) {
			# Don't pay for a fixture no class in this arm would use (e.g. there is
			# no blocking-only survival class).
			if (length(resampling_nondegenerate_cases(arm, response_type, NULL)) == 0L) next
			des_obj = tryCatch(arm$build(response_type), error = function(e) NULL)
			if (is.null(des_obj)) next
			cases = resampling_nondegenerate_cases(arm, response_type, des_obj)
			for (case in cases) {
				label = paste0(case$classname, " (", arm$name, "/", response_type, ")")
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
	}
	# A non-trivial sweep really ran, across all three design families (guards
	# against the enumeration silently collapsing and the test passing vacuously,
	# and against an arm quietly dropping out).
	expect_gt(length(covered), 100L)
	for (arm_name in c("bernoulli", "kk", "blocking")) {
		expect_true(
			any(grepl(paste0("\\(", arm_name, "/"), covered)),
			label = paste0("the ", arm_name, " fixture arm covered at least one class")
		)
	}
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
		des_obj = resampling_nondegenerate_bernoulli_design(case$response_type)
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
	# The KK G-computation pair is deliberately not pinned here: the
	# nonparametric bootstrap is not offered on `DesignSeqOneByOne` designs
	# ("This method is not supported for DesignSeqOneByOne designs."), so the KK
	# half of the catalog reaches the bootstrap loaders only through the
	# randomization-bootstrap operation, which the sweep above already covers.
})
