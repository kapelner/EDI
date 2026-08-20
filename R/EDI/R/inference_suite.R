
#' Normalizes a completed `Design` object into the flat metadata shape
#' inference-class discovery (`InferenceSuite`, and any future `Design`-side
#' discovery method built on the same normalized-design-metadata helper --
#' see `fix_inference_hierarchy.md`'s "Discovery"/"Design-Side Discovery API"
#' sections) filters candidate classes against. Treats censoring as two
#' independent axes, matching the construction-time gate in
#' `Inference$initialize()` exactly: `any_censoring` (any censored subject at
#' all, right- or general-) and `has_general_censoring` (any subject with a
#' finite `y_R`, i.e. left- or interval-censored) are reported separately,
#' since a class can support one without the other.
#'
#' @keywords internal
#' @noRd
normalize_inference_design_metadata = function(des_obj) {
	list(
		response_type = des_obj$get_response_type(),
		is_kk = isTRUE(des_obj$is_a_kk_matching_capable()),
		is_blocking = isTRUE(des_obj$supports("blocking")),
		any_censoring = isTRUE(des_obj$any_censoring()),
		has_general_censoring = isTRUE(des_obj$has_general_censoring())
	)
}

#' Per-class compatibility metadata read from the inference class registry,
#' shaped for `is_inference_class_compatible_with_design_metadata()`. Kept as
#' a standalone function (not a private InferenceSuite method) so both
#' `InferenceSuite` and `Design$applicable_inference_class_names()` share
#' exactly one copy of this lookup.
#'
#' @keywords internal
#' @noRd
inference_class_compatibility_metadata = function(nm) {
	metadata = get_inference_class_metadata(nm)
	list(
		abstract = isTRUE(metadata$abstract),
		exported = isTRUE(metadata$exported),
		response_types = metadata$response_types %||% character(),
		requires_kk = grepl("KK", nm, fixed = TRUE),
		requires_blocking = isTRUE(metadata$requires_blocking_design),
		supports_general_censoring = isTRUE(metadata$supports_general_censoring)
	)
}

#' Whether inference class `nm` is compatible with normalized design metadata
#' `design_meta` (see `normalize_inference_design_metadata()`). A candidate is
#' excluded if it is abstract or not exported; if it declares no compatible
#' response types, or none match `design_meta$response_type`; if it requires
#' KK matching (name contains `"KK"`) but the design isn't KK-capable; if its
#' `requires_blocking_design` metadata is `TRUE` but the design doesn't
#' support blocking; if the design has any left-/interval-censored
#' subjects (`has_general_censoring`) but the class's
#' `supports_general_censoring` metadata is `FALSE` -- the latter two mirror
#' `Inference$initialize()`'s own construction-time gate exactly; or if its
#' name contains `"IVWC"` -- the legacy inverse-variance-weighted-combination
#' KK estimators are deprecated in favor of the `OneLik` joint-likelihood
#' variants and are never surfaced by `InferenceSuite` discovery, even though
#' they remain independently constructible/exported for backwards
#' compatibility. Ordinary right-censoring alone (`any_censoring` without
#' `has_general_censoring`) never excludes a class.
#'
#' @keywords internal
#' @noRd
is_inference_class_compatible_with_design_metadata = function(nm, design_meta) {
	if (grepl("IVWC", nm, fixed = TRUE)) return(FALSE)
	class_meta = inference_class_compatibility_metadata(nm)
	if (isTRUE(class_meta$abstract) || !isTRUE(class_meta$exported)) return(FALSE)
	if (length(class_meta$response_types) == 0L) return(FALSE)
	if (!(design_meta$response_type %in% class_meta$response_types)) {
		return(FALSE)
	}
	if (isTRUE(class_meta$requires_kk) && !isTRUE(design_meta$is_kk)) return(FALSE)
	if (isTRUE(class_meta$requires_blocking) && !isTRUE(design_meta$is_blocking)) return(FALSE)
	if (isTRUE(design_meta$has_general_censoring) && !isTRUE(class_meta$supports_general_censoring)) {
		return(FALSE)
	}
	TRUE
}

#' Registered-but-unavailable packages for inference class `nm` (character(0)
#' if none or all installed).
#'
#' @keywords internal
#' @noRd
missing_required_packages_for_inference_class = function(nm) {
	required = get_inference_class_metadata(nm)$required_packages %||% character()
	if (length(required) == 0L) return(character())
	Filter(function(pkg) !requireNamespace(pkg, quietly = TRUE), required)
}

#' Splits every exported, non-abstract, design-compatible `Inference` class
#' for `des_obj` into an `applicable` sorted character vector and an
#' `unavailable_due_to_missing_packages` named list (class name -> missing
#' package names), per the `Discovery` rules in `fix_inference_hierarchy.md`.
#' The single implementation backing both `InferenceSuite` discovery and
#' `Design$applicable_inference_class_names()`/
#' `Design$unavailable_inference_classes_due_to_missing_packages()`.
#'
#' @keywords internal
#' @noRd
discover_applicable_inference_classes = function(des_obj) {
	registry = inference_class_registry_as_list()
	design_meta = normalize_inference_design_metadata(des_obj)
	candidates = names(Filter(function(metadata) {
		isTRUE(metadata$exported) && !isTRUE(metadata$abstract)
	}, registry))
	design_compatible = Filter(function(nm) {
		is_inference_class_compatible_with_design_metadata(nm, design_meta)
	}, candidates)
	unavailable = list()
	applicable = character()
	for (nm in design_compatible) {
		missing_pkgs = missing_required_packages_for_inference_class(nm)
		if (length(missing_pkgs) > 0L) {
			unavailable[[nm]] = missing_pkgs
		} else {
			applicable = c(applicable, nm)
		}
	}
	list(
		applicable = sort(applicable),
		unavailable_due_to_missing_packages = unavailable[sort(names(unavailable))]
	)
}

#' Backs `Design$applicable_inference_class_names()`.
#'
#' @keywords internal
#' @noRd
applicable_inference_class_names_for_design = function(des_obj) {
	discover_applicable_inference_classes(des_obj)$applicable
}

#' Backs `Design$unavailable_inference_classes_due_to_missing_packages()`.
#'
#' @keywords internal
#' @noRd
unavailable_inference_classes_due_to_missing_packages_for_design = function(des_obj) {
	discover_applicable_inference_classes(des_obj)$unavailable_due_to_missing_packages
}

#' CI/p-value method dispatch tables backing `InferenceSuite$
#' run_all_inference()`'s `methods` argument -- one row per method sentinel
#' label. There is no generic `compute_ci()`/`compute_pval()` on
#' `Inference` -- concrete classes expose capability-gated,
#' differently-named methods -- so each table entry pairs a capability
#' (checked via `obj$capabilities()`) with the method it gates and the
#' sentinel label `run_all_inference()`'s `methods` argument uses to
#' request it. No longer priority-ordered/cascading as of 2026-08-19 (per
#' user request -- every applicable sentinel gets its own row instead of
#' one row per class picking the first available); the name is kept for
#' now rather than renamed mid-refactor. See `inference_suite_inspect.md`'s
#' "Method Selection Policy" section for the original (now superseded)
#' cascade rationale.
#'
#' @keywords internal
#' @noRd
#' Covers every testing-procedure capability declared in
#' `contracts_mixins.R`'s `public_methods_for_capability` (2026-08-19 audit,
#' after user feedback that the original four-sentinel list omitted most of
#' the package's actual inference machinery): asymptotic Wald, exact,
#' randomization (test-statistic and randomization-bootstrap variants),
#' jackknife, the three `likelihood_tests` sub-procedures (score/
#' likelihood-ratio/gradient -- one capability, three independent tests),
#' parametric-likelihood-bootstrap, and Bayesian-bootstrap. Deliberately
#' excludes `likelihood_ratio`/`estimating_equation_likelihood_ratio` as
#' separate sentinels -- both capabilities gate the exact same
#' `compute_lik_ratio_*` method pair as `likelihood_tests`'s `lik_ratio`
#' sub-procedure already covers, so they'd be a duplicate row, not a
#' distinct test.
#'
#' TODO-23 (inference_suite_plan.md, unblocked 2026-08-19 once
#' `fix_inference_hierarchy.md`'s `public_methods_for_capability`
#' completeness audit landed a permanent regression test guaranteeing that
#' registry is exhaustive): derives the CI-side/p-value-side method-priority
#' specs by reading `contracts_mixins.R`'s `public_methods_for_capability`
#' registry directly and asserting (via `stopifnot`, at package-load time)
#' that every listed `(capability, method)` pair genuinely exists there --
#' rather than a hand-typed literal with no connection to the registry.
#' If a capability/method pair is ever renamed or removed from
#' `contracts_mixins.R`, the package now fails to load with a clear error
#' instead of `run_all_inference()` silently keeping a stale sentinel.
#'
#' The `(capability, method) -> label` mapping itself is still an explicit
#' table -- this is deliberate, not a shortcoming: `contracts_mixins.R`'s
#' registry is keyed by *capability*, and several capabilities intentionally
#' contribute more than one sentinel (`likelihood_tests` -> `score`/
#' `lik_ratio`/`gradient`/`lik_ratio_bartlett_approx`/
#' `lik_ratio_bartlett_exact`) or a non-canonical method pair (`wald`
#' capability's canonical pair is `compute_asymp_*`, not the duplicate-alias
#' `compute_wald_*` pair also registered under the same capability) -- so
#' "one sentinel per capability key" is not a valid auto-derivation rule on
#' its own. `run_all_inference_check_sentinel_completeness()` below is the
#' actual completeness guarantee: it walks every `compute_*_confidence_
#' interval`/`compute_*_two_sided_pval*` method in the live registry and
#' fails loudly if any of them is neither covered by this spec nor in the
#' small, documented `EDI_INFERENCE_SUITE_DELIBERATELY_UNSENTINELED_METHODS`
#' allowlist -- so a *new* capability/method pair added later cannot go
#' silently unrepresented the way the original hand-maintained list could.
#'
#' @keywords internal
#' @noRd
run_all_inference_derive_method_priority = function(spec) {
	lapply(spec, function(e) {
		registered = public_methods_for_capability[[e$capability]]
		if (is.null(registered) || !(e$method %in% registered)) {
			stop(sprintf(
				"run_all_inference: sentinel '%s' expects method '%s' registered under capability '%s' in contracts_mixins.R's public_methods_for_capability, but it is not there anymore -- update EDI_INFERENCE_SUITE_*_METHOD_PRIORITY in inference_suite.R to match the current registry.",
				e$label, e$method, e$capability
			))
		}
		e
	})
}

#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY = run_all_inference_derive_method_priority(list(
	list(capability = "wald", method = "compute_asymp_confidence_interval", label = "wald"),
	list(capability = "exact_test", method = "compute_exact_confidence_interval", label = "exact"),
	list(capability = "randomization_ci", method = "compute_rand_confidence_interval", label = "rand"),
	list(capability = "randomization_bootstrap_ci", method = "compute_rand_bootstrap_confidence_interval", label = "rand_bootstrap"),
	list(capability = "jackknife", method = "compute_jackknife_wald_confidence_interval", label = "jackknife"),
	list(capability = "likelihood_tests", method = "compute_score_confidence_interval", label = "score"),
	list(capability = "likelihood_tests", method = "compute_lik_ratio_confidence_interval", label = "lik_ratio"),
	list(capability = "likelihood_tests", method = "compute_gradient_confidence_interval", label = "gradient"),
	# 2026-08-19 (inference_suite_inspect.md audit): Bartlett-corrected
	# likelihood-ratio CIs. Gated by "likelihood_tests", same precedent
	# imprecision already accepted by the score/lik_ratio/gradient rows
	# above (that capability doesn't distinguish which of the four
	# testing types a class actually supports either) -- the real,
	# per-instance gate is supports_bartlett_likelihood_ratio_approx()/
	# _exact(), checked internally by these methods (surfaced via
	# get_supported_testing_types()) and degrading to NA/error caught by
	# this table's tryCatch wrapper, not a capability flag; see the
	# "compute_lik_ratio_bartlett_exact_two_sided_pval()... not gated by
	# any registered capability" TODO for why no new capability was added.
	# The plain "lik_ratio_bartlett" auto-selecting (exact-over-approx)
	# dispatcher is deliberately NOT its own sentinel (removed 2026-08-19,
	# user decision) -- it is only a convenience wrapper that dispatches to
	# whichever of the two real sentinels below is available, not a
	# distinct inference procedure; including it would add a third row
	# that's always a duplicate of whichever of "_exact"/"_approx" it
	# happened to pick.
	list(capability = "likelihood_tests", method = "compute_lik_ratio_bartlett_approx_confidence_interval", label = "lik_ratio_bartlett_approx"),
	list(capability = "likelihood_tests", method = "compute_lik_ratio_bartlett_exact_confidence_interval", label = "lik_ratio_bartlett_exact"),
	list(capability = "parametric_likelihood_bootstrap", method = "compute_lik_ratio_bootstrap_confidence_interval", label = "param_boot"),
	# TODO-23 completeness pass (2026-08-19): distinct from "param_boot"
	# above -- compute_lik_ratio_bootstrap_confidence_interval is a
	# bootstrap-calibrated *likelihood-ratio test* CI, while
	# compute_param_bootstrap_confidence_interval is a direct parametric-
	# bootstrap estimate/CI/pval for the treatment coefficient itself (two
	# genuinely different procedures on the same ParametricLikelihoodBootstrap
	# component, both real public methods per contracts_mixins.R's
	# completeness audit -- previously the second one was never registered
	# under any sentinel at all).
	list(capability = "parametric_likelihood_bootstrap", method = "compute_param_bootstrap_confidence_interval", label = "param_boot_direct"),
	list(capability = "bayesian_bootstrap", method = "compute_bayesian_bootstrap_confidence_interval", label = "bayes_boot"),
	list(capability = "nonparametric_bootstrap", method = "compute_bootstrap_confidence_interval", label = "bootstrap")
))

#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY = run_all_inference_derive_method_priority(list(
	list(capability = "wald", method = "compute_asymp_two_sided_pval", label = "wald"),
	list(capability = "exact_test", method = "compute_exact_two_sided_pval_for_treatment_effect", label = "exact"),
	list(capability = "randomization_test", method = "compute_rand_two_sided_pval", label = "rand"),
	list(capability = "randomization_bootstrap", method = "compute_rand_bootstrap_two_sided_pval", label = "rand_bootstrap"),
	list(capability = "jackknife", method = "compute_jackknife_wald_two_sided_pval", label = "jackknife"),
	list(capability = "likelihood_tests", method = "compute_score_two_sided_pval", label = "score"),
	list(capability = "likelihood_tests", method = "compute_lik_ratio_two_sided_pval", label = "lik_ratio"),
	list(capability = "likelihood_tests", method = "compute_gradient_two_sided_pval", label = "gradient"),
	# See the matching CI-table entries above for why these are gated by
	# "likelihood_tests" (same precedent as score/lik_ratio/gradient)
	# rather than a new capability, and for why the plain "lik_ratio_
	# bartlett" auto-selecting dispatcher has no entry of its own.
	list(capability = "likelihood_tests", method = "compute_lik_ratio_bartlett_approx_two_sided_pval", label = "lik_ratio_bartlett_approx"),
	list(capability = "likelihood_tests", method = "compute_lik_ratio_bartlett_exact_two_sided_pval", label = "lik_ratio_bartlett_exact"),
	list(capability = "parametric_likelihood_bootstrap", method = "compute_lik_ratio_bootstrap_two_sided_pval", label = "param_boot"),
	# See the matching CI-table entry above for why compute_param_bootstrap_pval
	# is a distinct sentinel ("param_boot_direct") from "param_boot".
	list(capability = "parametric_likelihood_bootstrap", method = "compute_param_bootstrap_pval", label = "param_boot_direct"),
	list(capability = "bayesian_bootstrap", method = "compute_bayesian_bootstrap_two_sided_pval", label = "bayes_boot"),
	list(capability = "nonparametric_bootstrap", method = "compute_bootstrap_two_sided_pval", label = "bootstrap")
))

#' The full set of method sentinel strings `run_all_inference()`'s `methods`
#' argument accepts -- the union of every `label` appearing in
#' `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY`/`EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY`
#' (TODO-23: computed from those two derived specs, not typed out a second
#' time), which in turn covers every testing-procedure capability in
#' `contracts_mixins.R`'s `public_methods_for_capability` (13 sentinels as of
#' 2026-08-19, widened earlier the same day from an initial four --
#' `"wald"`/`"exact"`/`"rand"`/`"bootstrap"` -- that omitted most of the
#' package's actual inference machinery, per user feedback). `methods = NULL`
#' (the default) resolves to every sentinel -- "truly all the possible
#' methods" per user request, 2026-08-19, replacing the earlier single-
#' cascade-winner design (`run_all_inference_select_ci()`/
#' `run_all_inference_select_pval()`, removed the same day).
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_METHOD_SENTINELS = union(
	vapply(EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY, `[[`, character(1L), "label"),
	vapply(EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY, `[[`, character(1L), "label")
)

#' Methods genuinely registered under `public_methods_for_capability` as a
#' `compute_*_confidence_interval`/`compute_*_two_sided_pval*` pair but
#' deliberately not surfaced as their own `run_all_inference()` sentinel --
#' each with a one-line reason so this allowlist can't silently grow by
#' accident. Consulted only by `run_all_inference_check_sentinel_
#' completeness()` (TODO-23's drift guard, exercised by
#' `test-inference-suite-run-all-inference.R`).
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_DELIBERATELY_UNSENTINELED_METHODS = c(
	# "wald" capability registers both compute_asymp_* (chosen as the
	# canonical "wald" sentinel above) and compute_wald_* -- a duplicate
	# alias pair on the same capability, same underlying procedure.
	"compute_wald_confidence_interval", "compute_wald_two_sided_pval",
	# Plain best-available (exact-over-approx) Bartlett dispatcher -- a
	# convenience wrapper around the two real "_approx"/"_exact" sentinels
	# above, not a distinct inference procedure (removed as its own
	# sentinel 2026-08-19, user decision).
	"compute_lik_ratio_bartlett_confidence_interval", "compute_lik_ratio_bartlett_two_sided_pval",
	# Distinct resampling schemes on NonparametricBootstrap, folded into the
	# "nonparametric_bootstrap" capability alongside the canonical bootstrap
	# methods (fix_inference_hierarchy.md's completeness audit) but not yet
	# given their own sentinel or `type` values -- open scope question,
	# tracked separately, not part of TODO-22/23's scope.
	"compute_m_out_of_n_bootstrap_confidence_interval", "compute_m_out_of_n_bootstrap_two_sided_pval",
	"compute_subsampling_confidence_interval", "compute_subsampling_two_sided_pval"
)

#' TODO-23's drift guard: every `compute_*_confidence_interval`/
#' `compute_*_two_sided_pval*` method registered anywhere in
#' `public_methods_for_capability` (excluding the two capabilities --
#' `likelihood_ratio`/`estimating_equation_likelihood_ratio` -- that
#' register the exact same method names as `likelihood_tests`'s own
#' `lik_ratio` sub-procedure, an intentional duplicate already covered)
#' must be either (a) one of the methods already named in
#' `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY`/`_PVAL_METHOD_PRIORITY`, or
#' (b) explicitly listed in
#' `EDI_INFERENCE_SUITE_DELIBERATELY_UNSENTINELED_METHODS` with a reason.
#' Returns the character vector of any method that is neither -- empty
#' means the sentinel tables are complete relative to the live registry.
#'
#' @keywords internal
#' @noRd
run_all_inference_check_sentinel_completeness = function() {
	excluded_capabilities = c("likelihood_ratio", "estimating_equation_likelihood_ratio")
	covered = union(
		vapply(EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY, `[[`, character(1L), "method"),
		vapply(EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY, `[[`, character(1L), "method")
	)
	covered = union(covered, EDI_INFERENCE_SUITE_DELIBERATELY_UNSENTINELED_METHODS)
	all_methods = character()
	for (cap in setdiff(names(public_methods_for_capability), excluded_capabilities)) {
		methods = public_methods_for_capability[[cap]]
		all_methods = c(all_methods, grep("^compute_.*(_confidence_interval|_two_sided_pval|_pval)$", methods, value = TRUE))
	}
	setdiff(unique(all_methods), covered)
}

#' TODO-22: sentinels that carry a second, `type`-valued fan-out axis --
#' the three resampling method families whose CI/pval calls accept a `type`
#' argument selecting among several distinct resampling/CI-construction
#' flavors (percentile, BCa, studentized, symmetric, smoothed, etc.). Every
#' other sentinel has no type axis at all. Named by CI-side accessor and
#' pval-side accessor so `run_all_inference_probe_supported_types()` can
#' look either up without a second hardcoded switch.
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_TYPED_SENTINEL_ACCESSORS = list(
	bootstrap      = list(ci = "get_supported_bootstrap_ci_types",           pval = "get_supported_bootstrap_pval_types"),
	bayes_boot     = list(ci = "get_supported_bayesian_bootstrap_ci_types",  pval = "get_supported_bayesian_bootstrap_pval_types"),
	rand_bootstrap = list(ci = "get_supported_rand_bootstrap_ci_types",      pval = "get_supported_rand_bootstrap_pval_types")
)

#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_TYPED_SENTINELS = names(EDI_INFERENCE_SUITE_TYPED_SENTINEL_ACCESSORS)

#' Real runtime introspection of class `nm`'s valid `type` values for typed
#' sentinel `sentinel` on `side` ("ci"/"pval") -- TODO-22's explicit
#' requirement ("query it at runtime via the ... accessors on the
#' constructed inference object -- NOT a hardcoded table"), not a literal
#' type-choices table in this file. These six accessors
#' (`get_supported_bootstrap_{pval,ci}_types()` etc.) are backed by a
#' private constant field the component's own `assertChoice(type, ...)`
#' call reads from directly (`fix_inference_hierarchy.md`'s accessor TODO),
#' so this can never drift from what the real `compute_*` call will accept.
#'
#' The field itself turns out not to be reachable off the un-instantiated
#' R6 generator (`cls$private_fields[[...]]` is `NULL` for these -- verified
#' directly, not assumed) even though it is a class-body literal default,
#' so this constructs a throwaway instance of `nm` (same construction
#' `run_all_inference_one_class()` performs for the real fit) purely to
#' call the accessor. This is a deliberate, narrow exception to this file's
#' otherwise-universal "discovery reads metadata, never constructors" rule
#' (`inference_class_accepts_model_formula()`'s docs) -- the type
#' vocabulary genuinely is only queryable off a live instance, so
#' `run_all_inference_build_tasks()` pays one extra (cheap) construction per
#' (class, formula-slot, typed sentinel) to plan the `type` fan-out, on top
#' of the real fit's own construction later. Returns `character(0)`, never
#' an error, if `nm` lacks this sentinel's capability on this side at all,
#' or if construction fails for any reason -- mirrors this file's
#' established "missing capability -> empty, never abort discovery"
#' pattern; a class that can't even be probed simply contributes no typed
#' tasks for this sentinel, the same outcome as genuinely lacking it.
#'
#' @keywords internal
#' @noRd
run_all_inference_probe_supported_types = function(nm, des_obj, params, sentinel, side) {
	accessors = EDI_INFERENCE_SUITE_TYPED_SENTINEL_ACCESSORS[[sentinel]]
	if (is.null(accessors)) return(character())
	accessor = accessors[[side]]
	priority = if (side == "ci") EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY else EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY
	entry = Find(function(e) identical(e$label, sentinel), priority)
	if (is.null(entry) || !(entry$capability %in% get_effective_capabilities(nm))) return(character())
	tryCatch({
		cls = get(nm, envir = getNamespace("EDI"))
		inf_obj = do.call(cls$new, c(list(des_obj = des_obj), params))
		types = inf_obj[[accessor]]()
		if (is.character(types)) types else character()
	}, error = function(e) character())
}

#' Union of CI-side and pval-side supported `type` values for class `nm`,
#' typed sentinel `sentinel`, intersected with `requested_types` (`NULL`
#' means "every valid type" -- the default when `methods` doesn't request
#' this sentinel by name, or requests it with no explicit type subset).
#' Backs `run_all_inference_build_tasks()`'s `type` fan-out. A requested
#' type this class doesn't support on *either* side silently drops out here
#' (no task for it, no error) -- CI-only/pval-only support for a given type
#' is resolved per-side later, inside `run_all_inference_call_ci_for_method()`/
#' `run_all_inference_call_pval_for_method()`, exactly mirroring how a
#' missing sentinel capability already degrades to `NA` there rather than
#' erroring.
#'
#' @keywords internal
#' @noRd
run_all_inference_class_typed_task_types = function(nm, des_obj, params, sentinel, requested_types, basic_only = FALSE) {
	available = union(
		run_all_inference_probe_supported_types(nm, des_obj, params, sentinel, "ci"),
		run_all_inference_probe_supported_types(nm, des_obj, params, sentinel, "pval")
	)
	# `basic_bootstrap = TRUE` convenience flag (2026-08-19): restrict to just
	# this class's first (i.e. default) type, the same one the underlying
	# `compute_*` methods themselves fall back to when `type` isn't passed --
	# only applied when the caller didn't already name explicit types for
	# this sentinel (`requested_types` non-`NULL` always wins).
	if (basic_only && is.null(requested_types) && length(available) > 0L) {
		available = available[1L]
	}
	if (is.null(requested_types)) return(available)
	intersect(requested_types, available)
}

#' Normalizes `run_all_inference()`'s `methods` argument (TODO-22) into
#' `list(sentinels, type_requests)`: `sentinels` is the character vector of
#' method sentinels to fit (unchanged meaning from before TODO-22);
#' `type_requests` is a named list, `sentinel -> character vector of
#' requested type values, or NULL for "every valid type"`, consulted only
#' for `EDI_INFERENCE_SUITE_TYPED_SENTINELS`. Accepts either shape a caller
#' passes: the legacy flat character vector of sentinels (equivalent to
#' every sentinel getting `type_requests[[s]] = NULL`), or the new named
#' list `list(bootstrap = c("percentile", "bca"), rand_bootstrap = NULL)`
#' (list names are the requested sentinels -- a sentinel present as a name
#' with value `NULL` still means "every valid type" for it, exactly like
#' the flat-vector shape; to *not* fit a sentinel at all, simply don't name
#' it). `NULL` (the top-level default) means every sentinel, every type.
#'
#' @keywords internal
#' @noRd
run_all_inference_normalize_methods = function(methods) {
	if (is.null(methods)) {
		return(list(sentinels = EDI_INFERENCE_SUITE_METHOD_SENTINELS, type_requests = list()))
	}
	if (is.list(methods)) {
		list(sentinels = names(methods), type_requests = methods)
	} else {
		list(sentinels = methods, type_requests = list())
	}
}

#' Whether inference class `nm` has *any* capability (CI or p-value) for
#' method sentinel `m`, checked via the registry's
#' `get_effective_capabilities()` -- no instantiation needed, matching the
#' architecture's "discovery reads metadata, never constructors" rule (same
#' pattern `inference_class_accepts_model_formula()` uses for `formulas`).
#'
#' @keywords internal
#' @noRd
inference_class_has_method = function(nm, m) {
	caps = get_effective_capabilities(nm)
	entry_ci = Find(function(e) identical(e$label, m), EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY)
	entry_pval = Find(function(e) identical(e$label, m), EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY)
	(!is.null(entry_ci) && entry_ci$capability %in% caps) ||
		(!is.null(entry_pval) && entry_pval$capability %in% caps)
}

#' Which of `methods` (already validated against `EDI_INFERENCE_SUITE_METHOD_SENTINELS`)
#' class `nm` has any capability for -- backs `run_all_inference_build_tasks()`'s
#' `methods` fan-out, same registry-only, no-instantiation approach as
#' `inference_class_accepts_model_formula()`.
#'
#' @keywords internal
#' @noRd
run_all_inference_class_applicable_methods = function(nm, methods) {
	Filter(function(m) inference_class_has_method(nm, m), methods)
}

#' Calls inference class `inf_obj`'s CI method for sentinel `method` (one of
#' `EDI_INFERENCE_SUITE_METHOD_SENTINELS`) directly -- no cascading to a
#' different sentinel if this one is unavailable or fails, unlike the
#' removed `run_all_inference_select_ci()`. Returns
#' `list(lower, upper, method)`. `method` in the return value reports
#' `entry$label` whenever an attempt was actually made -- i.e. whenever
#' `inf_obj` has this sentinel's CI capability at all -- **even if the call
#' itself errored or returned a non-finite interval** (per user request,
#' 2026-08-19: "always print out the value of ci_method... otherwise we
#' don't know what method actually failed"); `lower`/`upper` are `NA_real_`
#' in that failure case, but `method` still names which sentinel was tried.
#' `method` is `NA_character_` only when no attempt was possible at all --
#' `inf_obj` genuinely lacks this sentinel's CI capability.
#'
#' `type` (TODO-22, only consulted when `method %in%
#' EDI_INFERENCE_SUITE_TYPED_SENTINELS`): if non-`NA` but not one of this
#' `inf_obj`'s own `get_supported_*_ci_types()` values, the CI side simply
#' doesn't apply for this `type` -- returns `NA_real_`/`NA_real_` with
#' `method = entry$label` still reported (the requested `type` was valid on
#' the pval side for this class, just not the CI side; mirrors the existing
#' "capability doesn't apply to this row" degrade-to-`NA` pattern rather
#' than erroring). `NA` `type` (the default, and always the case for
#' non-typed sentinels) omits the `type` argument entirely, i.e. whatever
#' the method's own default resolves to.
#'
#' @keywords internal
#' @noRd
run_all_inference_call_ci_for_method = function(inf_obj, alpha, method, type = NA_character_) {
	entry = Find(function(e) identical(e$label, method), EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY)
	if (is.null(entry) || !(entry$capability %in% inf_obj$capabilities())) {
		return(list(lower = NA_real_, upper = NA_real_, method = NA_character_))
	}
	call_args = list(alpha = alpha)
	if (!is.na(type) && method %in% EDI_INFERENCE_SUITE_TYPED_SENTINELS) {
		ci_types = tryCatch(inf_obj[[EDI_INFERENCE_SUITE_TYPED_SENTINEL_ACCESSORS[[method]]$ci]](), error = function(e) character())
		if (!(type %in% ci_types)) {
			return(list(lower = NA_real_, upper = NA_real_, method = entry$label))
		}
		call_args$type = type
	}
	# Bootstrap-family methods print their own per-replicate progress bar by
	# default (`show_progress = TRUE`), which is never cleared and clutters
	# `run_all_inference()`'s own live table/progress bar -- suppress it
	# whenever the underlying method actually accepts the argument.
	if ("show_progress" %in% names(formals(inf_obj[[entry$method]]))) {
		call_args$show_progress = FALSE
	}
	ci = tryCatch(do.call(inf_obj[[entry$method]], call_args), error = function(e) NULL)
	if (!is.null(ci) && length(ci) == 2L && all(is.finite(ci))) {
		return(list(lower = ci[[1L]], upper = ci[[2L]], method = entry$label))
	}
	list(lower = NA_real_, upper = NA_real_, method = entry$label)
}

#' Calls inference class `inf_obj`'s p-value method for sentinel `method`
#' (one of `EDI_INFERENCE_SUITE_METHOD_SENTINELS`) directly -- see
#' `run_all_inference_call_ci_for_method()`'s docs for the no-cascading
#' rationale and the "`method` reports the attempted sentinel even on
#' failure" behavior, which applies here identically. Returns
#' `list(pval, method)`; `method` is `NA_character_` only when `inf_obj`
#' has no p-value capability for this sentinel at all (no attempt made).
#'
#' `type` behaves identically to `run_all_inference_call_ci_for_method()`'s
#' own `type` argument, checked against `get_supported_*_pval_types()`
#' instead -- see that function's docs.
#'
#' @keywords internal
#' @noRd
run_all_inference_call_pval_for_method = function(inf_obj, method, type = NA_character_) {
	entry = Find(function(e) identical(e$label, method), EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY)
	if (is.null(entry) || !(entry$capability %in% inf_obj$capabilities())) {
		return(list(pval = NA_real_, method = NA_character_))
	}
	# Never force `delta = 0` -- let the method's own formal default govern
	# (per user request, 2026-08-20, "is this coded somewhere in the
	# Inference classes?"). Real bug found and fixed here: hardcoding
	# `delta = 0` silently defeated classes like `InferenceIncidGCompRiskRatio`
	# (a genuine raw-ratio-scale estimand -- `compute_estimate()` returns
	# the actual ratio, confirmed by reading source) whose own
	# `compute_asymp_two_sided_pval(delta = NULL)` resolves the omitted
	# argument via a private `default_null_value()` (`1` for `"RR"`, `0`
	# otherwise) -- forcing `delta = 0` from here always tested the wrong
	# null (`RR = 0`, a degenerate/nonsensical hypothesis) instead of the
	# correct `RR = 1`. Only exception: a method whose `delta` has *no*
	# formal default at all (`compute_param_bootstrap_pval` is the one
	# case in this package) must still be given something explicitly, so
	# `0` is supplied only then -- unchanged, pre-existing behavior for
	# that one sentinel, not made any better or worse by this fix.
	f_formals = formals(inf_obj[[entry$method]])
	call_args = if ("delta" %in% names(f_formals) && identical(f_formals$delta, quote(expr = ))) {
		list(delta = 0)
	} else {
		list()
	}
	if (!is.na(type) && method %in% EDI_INFERENCE_SUITE_TYPED_SENTINELS) {
		pval_types = tryCatch(inf_obj[[EDI_INFERENCE_SUITE_TYPED_SENTINEL_ACCESSORS[[method]]$pval]](), error = function(e) character())
		if (!(type %in% pval_types)) {
			return(list(pval = NA_real_, method = entry$label))
		}
		call_args$type = type
	}
	# See the matching CI-side comment above: suppress bootstrap-family
	# methods' own per-replicate progress bar, never cleared otherwise.
	if ("show_progress" %in% names(formals(inf_obj[[entry$method]]))) {
		call_args$show_progress = FALSE
	}
	pv = tryCatch(do.call(inf_obj[[entry$method]], call_args), error = function(e) NULL)
	if (!is.null(pv) && length(pv) == 1L && is.finite(pv)) {
		return(list(pval = pv, method = entry$label))
	}
	list(pval = NA_real_, method = entry$label)
}

#' Estimand label for `cls_name`, read from the class metadata registry's
#' `estimand` field (`inference_class_registry.R`'s
#' `infer_inference_estimand_type()`, folded in at
#' `populate_inference_class_registry()` time by walking the generator's
#' declared `get_estimand_type()` private method -- see that class's own
#' roxygen on `Inference$get_estimand_type()` for the full design). Registry
#' lookup, not instance introspection: works even for a class whose
#' construction/fit failed (no `inf_obj` needed), and matches the
#' architecture's "Discovery reads metadata, never constructors" rule.
#' `NA_character_` for any class that hasn't declared one (still the vast
#' majority as of this writing -- declaring a value is opt-in, not
#' required).
#'
#' @keywords internal
#' @noRd
#' Estimand tags (the raw `EDI_INFERENCE_ESTIMAND_TAGS` values) that are
#' genuinely on a **raw multiplicative** scale -- positive support, null
#' effect at 1, e.g. `"RR"` (risk ratio), `"hazard_ratio"` -- as opposed to
#' every other estimand tag in the registry, which is either already a
#' *difference* (`"RD"`, `"mean_difference"`, ...) or already
#' **log-transformed** by the estimator itself (`"log_odds_ratio_*"`,
#' `"log_rate_ratio_*"`, `"log_time_ratio"`, ...) -- for those, the reported
#' number is already an additive effect on the log scale, so a *further*
#' log10 transform of that number would be nonsensical (and can be
#' negative, which log10 can't even display). Per user request, 2026-08-20
#' ("for each estimand, decide if it makes sense to display on a log10
#' scale") -- used by `run_all_inference_plot_estimates()`/
#' `run_all_inference_plot_ci_forest()` to pick `scale_x_log10()` (null
#' reference line at 1) vs. linear (null at 0) per estimand, closing the
#' "ratio-scale nulls would need a per-class scale declaration" known
#' limitation those two functions previously documented.
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_LOG_SCALE_ESTIMANDS = c("RR", "hazard_ratio")

#' Whether estimand `estimand` should render on a log10 x-axis, further
#' gated on every value actually being finite and strictly positive (log10
#' requires positive support -- a class that somehow reports a
#' non-positive point estimate/CI bound for a nominally ratio-scale
#' estimand falls back to linear rather than producing an unplottable
#' panel).
#'
#' @keywords internal
#' @noRd
run_all_inference_estimand_use_log10 = function(estimand, values) {
	!is.na(estimand) && estimand %in% EDI_INFERENCE_LOG_SCALE_ESTIMANDS &&
		length(values) > 0L && all(is.finite(values)) && all(values > 0)
}

run_all_inference_estimand = function(cls_name) {
	tryCatch(
		get_inference_class_metadata(cls_name)$estimand %||% NA_character_,
		error = function(e) NA_character_
	)
}

#' Constructs, fits, and summarizes one inference class for
#' `InferenceSuite$run_all_inference()`. Never throws -- construction/fit
#' failures are caught and turned into `status = "error"`/`"nonest"`/
#' `"timeout"` rows instead of aborting the whole report (see
#' `inference_suite_inspect.md`'s "Per-Class Failure Isolation" section).
#' The `diagnostics` sub-list is v1.0.0-scoped to \code{NA} placeholders --
#' there is no generic native-diagnostics accessor on \code{Inference} yet
#' (that is \code{public_diagnostics_api_spec.md}'s TODO-9..12); it is wired
#' up in v1.1.0 per that plan's TODO-19.
#'
#' `max_secs_per_class` (\code{NULL} = no limit) is enforced via
#' \code{setTimeLimit(elapsed = ...)}, reset via \code{on.exit()} so the
#' limit never leaks past this one class's fit. \strong{Known limitation}
#' (documented per \code{inference_suite_inspect.md}'s TODO-12): R's time
#' limits are checked at R-level interrupt points and are not guaranteed to
#' interrupt a single long-running native (C/C++/BLAS) call with no
#' intervening R-level check: this reliably cuts off slow *R-level* work
#' (e.g. many bootstrap/randomization replicates, each its own R-level
#' call) but may not interrupt one very slow single native fit.
#'
#' Whether inference class `nm`'s constructor syntactically accepts a
#' `model_formula` argument, checked via `formals()` on the R6 generator's
#' `$new()` (auto-derived from `initialize()`'s own formals -- an R6
#' generator's `$new` always mirrors its `initialize` method's signature).
#' Purely syntactic: `TRUE` does not mean the class's fit actually reads the
#' formula, only that a caller may legally pass one at construction time --
#' see the `adjusts_for_covariates` registry field (audited in full in
#' `fix_inference_hierarchy.md`, 2026-08-19) for that separate, harder
#' question. Backs `run_all_inference_build_tasks()`'s `formulas` fan-out.
#'
#' @keywords internal
#' @noRd
inference_class_accepts_model_formula = function(nm) {
	cls = get(nm, envir = getNamespace("EDI"))
	"model_formula" %in% names(formals(cls$new))
}

#' Normalizes `InferenceSuite$run_all_inference()`'s `formulas` argument
#' into `NULL` or a plain list of `formula` objects, accepting every input
#' shape a caller might reasonably pass: a single bare formula (`~ .`), a
#' character formula string (`"~ ."`), or a collection of either --
#' including `c(~ 1, ~ .)`, which base R already returns as a plain `list`
#' of two `formula` objects (formulas have no `c()` method of their own), so
#' no special-casing is needed for that shape specifically. Character
#' elements are converted via `stats::as.formula()`; formula elements pass
#' through unchanged. Does not validate -- `run_all_inference()` asserts the
#' *pre*-normalization input shape itself (so a malformed element reports
#' clearly against what the caller actually typed).
#'
#' @keywords internal
#' @noRd
run_all_inference_normalize_formulas = function(formulas) {
	if (is.null(formulas)) return(NULL)
	if (inherits(formulas, "formula")) formulas = list(formulas)
	formulas = as.list(formulas)
	lapply(formulas, function(f) if (is.character(f)) stats::as.formula(f) else f)
}

#' Expands `cls_names` x `formulas` x `methods` into one fitting task per
#' (class, formula, method) combination, for `InferenceSuite$
#' run_all_inference()`'s `formulas`/`methods` arguments.
#'
#' \strong{Formula dimension}: `formulas = NULL` (the default) contributes
#' one formula-slot per class with `model_formula = NULL` -- identical to
#' pre-`formulas` behavior, since `model_formula = NULL` at construction
#' already resolves to `des_obj$get_design_formula()` (default `~ .`). When
#' `formulas` is non-`NULL` (already normalized to a list of `formula`
#' objects by `run_all_inference_normalize_formulas()`): classes for which
#' `inference_class_accepts_model_formula()` is `TRUE` get one formula-slot
#' per formula in `formulas`; classes for which it is `FALSE` still get
#' exactly one formula-slot (`model_formula = NULL`, ignoring `formulas`).
#'
#' \strong{Method dimension}: for each formula-slot, one task per method
#' sentinel in `run_all_inference_class_applicable_methods(nm, methods)` --
#' i.e. only sentinels the class has *any* CI or p-value capability for
#' among the requested `methods`. A class with zero applicable methods
#' among `methods` still gets exactly one task with `method = NA_character_`
#' (mirrors the pre-`methods` "no capability -> NA" row, rather than
#' silently dropping the class from the table).
#'
#' \strong{Type dimension} (TODO-22): for each applicable method sentinel
#' that is one of `EDI_INFERENCE_SUITE_TYPED_SENTINELS` (`"bootstrap"`/
#' `"bayes_boot"`/`"rand_bootstrap"`), one task per `type` value in
#' `run_all_inference_class_typed_task_types(nm, des_obj, params, m,
#' type_requests[[m]])` -- i.e. every `type` this class actually supports
#' (on the CI side, the pval side, or both), intersected with
#' `type_requests[[m]]` if the caller asked for a specific subset. A typed
#' sentinel with zero resulting types (no capability, probe failed, or the
#' caller's requested types don't intersect what this class supports) still
#' gets exactly one task with `type = NA_character_` (same "no task
#' silently dropped" rule the method dimension already follows). Non-typed
#' sentinels always get exactly one task, `type = NA_character_`.
#'
#' Each task's `result_name` is the plain class name (optionally
#' `"<class>[<deparsed formula>]"` if more than one formula-slot applies)
#' when the class contributes exactly one task per formula-slot, or that
#' same base with `"{<method>}"` (or `"{<method>:<type>}"` for a typed
#' sentinel with more than one resulting type) appended when more than one
#' method/type combination is applicable for that class, so
#' `results`/`results_table` row identifiers stay unique.
#'
#' @param cls_names Character vector of class names to build tasks for.
#' @param formulas `NULL`, or a list of `formula` objects (see
#'   `run_all_inference_normalize_formulas()`).
#' @param methods Character vector of method sentinels (subset of
#'   `EDI_INFERENCE_SUITE_METHOD_SENTINELS`) to fan out over.
#' @param des_obj The `Design` object being fit against -- only used to
#'   probe typed sentinels' valid `type` values (see
#'   `run_all_inference_probe_supported_types()`'s docs on why this is a
#'   deliberate, narrow exception to "discovery never constructs").
#'   `NULL` is fine when no requested `methods` are typed sentinels (no
#'   probing needed).
#' @param inference_params Named list, class name -> constructor params
#'   (`InferenceSuite$new()`'s own `inference_params`), used for the same
#'   typed-sentinel probe construction.
#' @param type_requests Named list, sentinel -> character vector of
#'   requested `type` values or `NULL` for "every valid type" (see
#'   `run_all_inference_normalize_methods()`).
#' @return A list of `list(cls_name, model_formula, method, type, result_name)`.
#'
#' @keywords internal
#' @noRd
run_all_inference_build_tasks = function(cls_names, formulas, methods, des_obj = NULL, inference_params = list(), type_requests = list(), basic_bootstrap = FALSE) {
	tasks = list()
	for (nm in cls_names) {
		formula_slots = if (is.null(formulas)) {
			list(list(model_formula = NULL, formula_tag = NULL))
		} else if (inference_class_accepts_model_formula(nm)) {
			lapply(formulas, function(f) list(model_formula = f, formula_tag = deparse1(f)))
		} else {
			list(list(model_formula = NULL, formula_tag = NULL))
		}
		applicable_methods = run_all_inference_class_applicable_methods(nm, methods)
		method_type_slots = list()
		for (m in applicable_methods) {
			if (m %in% EDI_INFERENCE_SUITE_TYPED_SENTINELS) {
				params_nm = inference_params[[nm]] %||% list()
				types = run_all_inference_class_typed_task_types(nm, des_obj, params_nm, m, type_requests[[m]], basic_only = basic_bootstrap)
				if (length(types) == 0L) {
					method_type_slots[[length(method_type_slots) + 1L]] = list(method = m, type = NA_character_)
				} else {
					for (ty in types) {
						method_type_slots[[length(method_type_slots) + 1L]] = list(method = m, type = ty)
					}
				}
			} else {
				method_type_slots[[length(method_type_slots) + 1L]] = list(method = m, type = NA_character_)
			}
		}
		if (length(method_type_slots) == 0L) method_type_slots = list(list(method = NA_character_, type = NA_character_))
		multi_method = length(method_type_slots) > 1L
		for (fs in formula_slots) {
			for (mt in method_type_slots) {
				result_name = if (is.null(fs$formula_tag)) nm else sprintf("%s[%s]", nm, fs$formula_tag)
				if (multi_method && !is.na(mt$method)) {
					tag = if (!is.na(mt$type)) sprintf("%s:%s", mt$method, mt$type) else mt$method
					result_name = sprintf("%s{%s}", result_name, tag)
				}
				tasks[[length(tasks) + 1L]] = list(
					cls_name = nm, model_formula = fs$model_formula,
					method = mt$method, type = mt$type, result_name = result_name
				)
			}
		}
	}
	tasks
}

#' @keywords internal
#' @noRd
run_all_inference_one_class = function(cls_name, des_obj, params, alpha, design_family, response_type, max_secs_per_class = NULL, method = NA_character_, type = NA_character_) {
	t0 = Sys.time()
	row = list(
		inference_class = cls_name,
		method          = method,
		type            = type,
		response_type   = response_type,
		design_family   = design_family,
		likelihood_tier = get_inference_class_metadata(cls_name)$likelihood_tier %||% NA_character_,
		cov_model       = NA_character_,
		estimate        = NA_real_,
		se              = NA_real_,
		ci_a            = NA_real_,
		ci_b            = NA_real_,
		ci_method       = NA_character_,
		pval            = NA_real_,
		pval_method     = NA_character_,
		# Registry-level fact (like likelihood_tier above), not dependent on
		# fit success -- set unconditionally here rather than only inside the
		# "ok" branch below, so a nonestimable/error/timeout row still reports
		# what this class targets.
		estimand        = run_all_inference_estimand(cls_name),
		fit_secs        = NA_real_,
		warnings        = NA_character_,
		status          = "error",
		message         = NA_character_,
		diagnostics     = list(
			converged = NA, hit_iteration_cap = NA,
			iterations = NA_integer_, optimizer = NA_character_
		)
	)
	collected_warnings = character()
	outcome = withCallingHandlers(
		tryCatch({
			if (!is.null(max_secs_per_class)) {
				setTimeLimit(elapsed = max_secs_per_class, transient = TRUE)
				on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
			}
			cls = get(cls_name, envir = getNamespace("EDI"))
			inf_obj = do.call(cls$new, c(list(des_obj = des_obj), params))
			estimate = inf_obj$compute_estimate()
			se = tryCatch({
				priv = inf_obj$.__enclos_env__$private
				if (is.function(priv$get_standard_error)) as.numeric(priv$get_standard_error()) else NA_real_
			}, error = function(e) NA_real_)
			ci = if (is.na(method)) {
				list(lower = NA_real_, upper = NA_real_, method = NA_character_)
			} else {
				run_all_inference_call_ci_for_method(inf_obj, alpha, method, type)
			}
			pv = if (is.na(method)) {
				list(pval = NA_real_, method = NA_character_)
			} else {
				run_all_inference_call_pval_for_method(inf_obj, method, type)
			}
			# Always populated once construction succeeds (Inference$initialize()
			# always sets private$model_formula, even for classes -- e.g.
			# SimpleMeanDifferenceSource -- that accept a model_formula argument
			# but never actually use it in the fit). Reporting it here is a
			# statement of "what formula this instance was constructed with," not
			# a claim that every class's fit is a function of it. Classes whose
			# registry `adjusts_for_covariates` is confirmed `FALSE` (audited in
			# fix_inference_hierarchy.md, 2026-08-19) report a blank formula here
			# instead, matching inference_suite_inspect.md's agreed design
			# ("formula is blank for classes that don't take a formula"). `TRUE`/
			# `NA` (unaudited) classes keep reporting the real formula string.
			cov_model = if (isFALSE(get_inference_class_metadata(cls_name)$adjusts_for_covariates)) {
				NA_character_
			} else {
				tryCatch(deparse1(inf_obj$get_model_formula()), error = function(e) NA_character_)
			}
			if (isTRUE(inf_obj$is_nonestimable("any"))) {
				list(
					status = "nonest", cov_model = cov_model,
					message = inf_obj$get_nonestimable_reason() %||% NA_character_
				)
			} else {
				list(
					status = "ok", cov_model = cov_model, estimate = as.numeric(estimate), se = se,
					ci_a = ci$lower, ci_b = ci$upper, ci_method = ci$method,
					pval = pv$pval, pval_method = pv$method
				)
			}
		}, error = function(e) {
			if (!is.null(max_secs_per_class) && grepl("time limit", conditionMessage(e), fixed = TRUE)) {
				list(
					status = "timeout",
					message = sprintf("exceeded max_secs_per_class = %s seconds", max_secs_per_class)
				)
			} else {
				list(status = "error", message = conditionMessage(e))
			}
		}),
		warning = function(w) {
			collected_warnings <<- c(collected_warnings, conditionMessage(w))
			invokeRestart("muffleWarning")
		}
	)
	row = utils::modifyList(row, outcome)
	row$warnings  = if (length(collected_warnings) > 0L) paste(collected_warnings, collapse = "; ") else NA_character_
	row$fit_secs  = as.numeric(difftime(Sys.time(), t0, units = "secs"))
	row
}

#' Formats a duration in seconds as `"Xd Xh Xm Xs"` (only nonzero leading
#' units shown), reusing `simulations_framework.R`'s `.fmt_secs()`
#' convention for `run_all_inference()`'s screen progress bar.
#'
#' @keywords internal
#' @noRd
run_all_inference_fmt_secs = function(secs) {
	secs = max(0, secs)
	d = floor(secs / 86400); secs = secs %% 86400
	h = floor(secs / 3600);  secs = secs %% 3600
	m = floor(secs / 60);    s = round(secs %% 60)
	parts = character()
	if (d > 0) parts = c(parts, paste0(d, "d"))
	if (h > 0) parts = c(parts, paste0(h, "h"))
	if (m > 0) parts = c(parts, paste0(m, "m"))
	parts = c(parts, paste0(s, "s"))
	paste(parts, collapse = " ")
}

#' Formats a completion-time duration for `run_all_inference()`'s final
#' "Status: Completed in ..." screen message: seconds alone under a minute
#' (`"30s"`), minutes-and-seconds at or above a minute (`"1min 30s"`) --
#' deliberately never rolls into hours/days regardless of magnitude (per
#' user request), unlike `run_all_inference_fmt_secs()`'s ETA formatting,
#' which does.
#'
#' @keywords internal
#' @noRd
run_all_inference_fmt_completed_secs = function(secs) {
	secs = max(0L, round(secs))
	if (secs < 60L) return(sprintf("%ds", secs))
	m = secs %/% 60L
	s = secs %% 60L
	sprintf("%dmin %ds", m, s)
}

#' The subset of `run_all_inference_build_display_table()`'s display columns
#' shown during `screen = TRUE` live streaming: everything except `weight`,
#' which cannot be computed per-row (it depends on the full, final
#' `estimand` grouping across every row, not knowable until every class has
#' fit). Column order/labels otherwise match the final pretty-printed table
#' (`print.EDIInferenceSuiteResults()`) exactly, per user request
#' (2026-08-19: "it should look identical to what happens on print()").
#'
#' @keywords internal
#' @noRd
#' `"method"` is deliberately not a display column here (never was in
#' `print()`'s pretty table either) -- per user request, 2026-08-20:
#' "it's not in the print table. Let's drop." `results_table$method` (the
#' *requested* sentinel, as opposed to `ci_method`/`pval_method`'s
#' *actually-used-per-side* outcome) remains a real column for programmatic
#' use, just not rendered.
EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS = c(
	"inference class", "cov mod", "estimand", "est", "se",
	"ci_a", "ci_b", "ci method", "pval", "pval method (if different)", "status"
)

#' Fixed per-column character-width caps for the wrapped text table (both
#' the live `screen = TRUE` table and `print()`'s pretty table share these).
#' Per user request, 2026-08-19 ("imagine a row is actually two rows but
#' each cell is wrapped -- the row length is not wrapped"): every column
#' stays present in a single logical row -- unlike the earlier "split half
#' the columns onto line 1, half onto line 2" design (which the user
#' rejected as still "not the format I want") -- and any cell whose text
#' overflows its column's cap word-wraps onto a second physical line
#' (`run_all_inference_wrap_cell_2lines()`), so the row as a whole prints as
#' two aligned physical lines but every column occupies the same x-position
#' on both. Caps chosen to force wrapping for the columns that actually
#' carry long text (`inference class`/`method`/`ci method`/`pval method`)
#' while staying tight for short numeric columns, keeping total row width
#' compact regardless of how long any single value gets.
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS = c(
	`inference class` = 14L, `cov mod` = 7L, estimand = 10L,
	est = 8L, se = 8L, ci_a = 8L, ci_b = 8L, `ci method` = 12L,
	pval = 9L, `pval method (if different)` = 14L, weight = 6L, status = 7L
)

#' Word-wraps `text` to at most 2 lines no wider than `width` characters
#' (via `strwrap()`, so it breaks at word boundaries, not mid-word -- per
#' user request, 2026-08-19: `"inference class"` -> `"inference"` /
#' `"class"`, `"mean diff"` -> `"mean"` / `"diff"`). `NA` displays as the
#' literal string `"NA"` (this file's usual convention). Any content beyond
#' the second line is folded back onto it (space-joined) and hard-truncated
#' to `width` if it still doesn't fit -- a deliberate last resort so a
#' single very long word never breaks the table's fixed column alignment,
#' at the cost of that rare cell's tail being cut off.
#'
#' @return `c(line1, line2)`; `line2` is `""` when everything fit on line 1.
#'
#' @keywords internal
#' @noRd
run_all_inference_wrap_cell_2lines = function(text, width) {
	text = if (is.na(text)) "NA" else as.character(text)
	if (nchar(text) <= width) return(c(text, ""))
	words = strsplit(text, " ", fixed = TRUE)[[1]]
	if (length(words) < 2L) {
		# One un-splittable "word" longer than the column -- hard-wrap at
		# `width` (rare; only very long single tokens hit this).
		lines = strwrap(text, width = max(1L, width))
		return(c(lines[1L], if (length(lines) > 1L) substr(paste(lines[-1L], collapse = " "), 1L, width) else ""))
	}
	# Split into two halves by word count (per user request, 2026-08-20:
	# "Mean Δ Pooled Var" -> "Mean Δ" / "Pooled Var", not `strwrap()`'s
	# greedy fill-to-width, which had packed 3 of the 4 words onto line 1
	# and left the 4th stranded alone on line 2) -- same balanced-halves
	# scheme `run_all_inference_format_html_table()`'s `wrap_html()` already
	# uses for `<br>`-wrapped header/cell text.
	k = ceiling(length(words) / 2L)
	line1 = paste(words[seq_len(k)], collapse = " ")
	line2 = paste(words[(k + 1L):length(words)], collapse = " ")
	if (nchar(line2) > width) line2 = substr(line2, 1L, width)
	c(line1, line2)
}

#' Renders one logical table row (or the header row) as two aligned
#' physical lines, each column word-wrapped independently to its own
#' `EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS` cap (looked up by `headers`,
#' so the same function renders both the live table's column set -- has
#' `"method"` -- and the pretty table's -- has `"weight"` instead). Backs
#' both `run_all_inference_build_live_table_header()`/`run_all_inference_
#' print_row()` and `run_all_inference_format_pretty_table()`, so the two
#' stay visually identical (per the file's established "screen output looks
#' identical to print()" requirement).
#'
#' @param vals,headers Parallel character vectors, one value/header per
#'   column.
#' @return `c(line1, line2)`.
#'
#' @keywords internal
#' @noRd
run_all_inference_fmt_wrapped_row = function(vals, headers) {
	widths = EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS[headers]
	cells = mapply(run_all_inference_wrap_cell_2lines, vals, widths, SIMPLIFY = FALSE)
	fmt = function(which_line) paste(
		mapply(function(c, w) formatC(c[[which_line]], width = -w), cells, widths),
		collapse = "  "
	)
	c(fmt(1L), fmt(2L))
}

#' Short display form of a method-sentinel label (`EDI_INFERENCE_SUITE_METHOD_SENTINELS`
#' value, e.g. `"rand_bootstrap"`) for the `method`/`ci_method`/`pval_method`
#' display columns -- purely cosmetic, like `estimand_short_label()`/
#' `inference_class_short_label()`: never touches `results_table$method`/
#' `ci_method`/`pval_method` themselves, or the `methods` argument's actual
#' sentinel vocabulary, only how a sentinel is printed. `NA_character_`
#' passes through unchanged.
#'
#' @keywords internal
#' @noRd
method_short_label = function(m) {
	vapply(m, function(x) {
		if (is.na(x)) return(NA_character_)
		switch(x,
			rand_bootstrap = "rand boot",
			lik_ratio_bartlett_exact = "LR Bartlett",
			lik_ratio_bartlett_approx = "LR ≈Bartlett",
			bayes_boot = "bayes boot",
			bootstrap = "boot",
			param_boot_direct = "param boot",
			x
		)
	}, character(1L), USE.NAMES = FALSE)
}

#' Like `method_short_label()`, but appends `" (type)"` when `type` is
#' non-`NA` for that element (TODO-22) -- used for the `ci method`/
#' `pval method` display columns, which are what actually distinguishes
#' e.g. `"boot (bca)"` from `"boot (percentile)"` on a given row (the row's
#' own `method`/`type` request may name a typed sentinel with no explicit
#' type restriction, but `ci_method`/`pval_method` always report the exact
#' sentinel *and type actually used* once fit). `method`/`type` are
#' recycled against each other via `mapply()`.
#'
#' @keywords internal
#' @noRd
#' Display abbreviation for a bootstrap-family `type` value, shown inside
#' the parentheses appended by `method_with_type_short_label()` (e.g.
#' `"boot (%ile)"`, `"bayes boot (bayes-wald)"`). `bayes_boot`'s `type`
#' values get their own `bayes-`-prefixed abbreviations since that family
#' alone distinguishes `"basic"` from `"wald"`; every other typed sentinel
#' (`bootstrap`, `rand_bootstrap`) shares the plain abbreviations. Falls
#' back to the raw `type` string for any value not in this table (e.g.
#' `"bootstrap-t"`, `"prepivoted"`, `"double-bootstrap"`, `"calibrated"`,
#' `"smoothed"`).
#'
#' @keywords internal
#' @noRd
type_short_label = function(method, type) {
	if (identical(method, "bayes_boot")) {
		switch(type,
			percentile = "pctile",
			symmetric = "symm",
			basic = "basic",
			wald = "wald",
			bca = "bca",
			studentized = "stud",
			`bootstrap-t` = "t",
			prepivoted = "prepiv",
			`double-bootstrap` = "dbl-boot",
			calibrated = "calib",
			smoothed = "smth",
			type
		)
	} else {
		switch(type,
			percentile = "%ile",
			symmetric = "symm",
			`symmetric-percentile-t` = "symm t",
			basic = "basic",
			bca = "bca",
			studentized = "stud",
			`bootstrap-t` = "t",
			prepivoted = "prepiv",
			`double-bootstrap` = "dbl-boot",
			calibrated = "calib",
			smoothed = "smth",
			m_out_of_n_bootstrap = "m-out-n",
			subsampling = "PRW-sub",
			type
		)
	}
}

method_with_type_short_label = function(method, type) {
	mapply(function(m, ty) {
		if (is.na(m)) return(NA_character_)
		lbl = method_short_label(m)
		if (!is.na(ty)) sprintf("%s (%s)", lbl, type_short_label(m, ty)) else lbl
	}, method, type, USE.NAMES = FALSE)
}

#' Per-task display fields known *before any class is constructed or
#' fitted* -- everything derivable from `task$cls_name`/`task$model_formula`/
#' `task$method` and registry metadata alone: `inference_class`'s short
#' label, the `method` sentinel, the raw (undisplayed-yet) `cov_model`
#' formula string, and the `estimand`. This is what makes precomputing the
#' live table's column widths *before* the fitting loop starts possible --
#' see `run_all_inference_build_live_table_header()`. `cov_model_raw`
#' mirrors `run_all_inference_one_class()`'s own construction-time
#' resolution logic (`adjusts_for_covariates == FALSE` -> blank;
#' otherwise the task's own formula, or `des_obj$get_design_formula()`
#' when the task carries none) without constructing anything.
#'
#' @keywords internal
#' @noRd
run_all_inference_static_row_fields = function(task, des_obj) {
	adjusts = get_inference_class_metadata(task$cls_name)$adjusts_for_covariates
	cov_model_raw = if (isFALSE(adjusts)) {
		NA_character_
	} else {
		f = task$model_formula %||% des_obj$get_design_formula()
		tryCatch(deparse1(f), error = function(e) NA_character_)
	}
	list(
		inference_class_disp = inference_class_short_label(task$cls_name),
		cov_model_raw = cov_model_raw,
		estimand_disp = {
			e = run_all_inference_estimand(task$cls_name)
			if (is.na(e)) "NA" else estimand_short_label(e)
		}
	)
}

#' Precomputes everything the live `screen = TRUE` table needs before the
#' fitting loop starts: one header line + a double (`=`) rule sized to fit
#' every task's `inference class`/`method`/`cov mod`/`estimand` values (the
#' only display columns knowable ahead of fitting -- see
#' `run_all_inference_static_row_fields()`), a fixed-width reservation for
#' the fit-time-only columns (`estimate`/`se`/`ci_a`/`ci_b`/`ci_method`/
#' `pval`/`pval_method`/`status`, sized from the known-in-advance value
#' vocabularies: `EDI_INFERENCE_SUITE_METHOD_SENTINELS` for the method
#' columns, the fixed `status` value set for that column), and the
#' `cov_model` letter-key legend, assigned in the exact same order
#' (`estimand`, then `inference_class`) `run_all_inference_build_display_table()`
#' uses for the final table -- so a formula that gets labeled `"(A)"` live
#' is still `"(A)"` in the final `print(res)`, not a different, independently
#' re-assigned letter.
#'
#' @param tasks The task list `run_all_inference_build_tasks()` returns.
#' @param des_obj The `Design` object being fit against.
#' @return `list(header_lines, total_width, widths, statics, cov_key)` --
#'   `statics` is a list parallel to `tasks`, each element already carrying
#'   its fully-rendered, NA-handled `cov_model` display string
#'   (`cov_model_disp`) alongside the fields from
#'   `run_all_inference_static_row_fields()`.
#'
#' @keywords internal
#' @noRd
run_all_inference_build_live_table_header = function(tasks, des_obj) {
	statics = lapply(tasks, run_all_inference_static_row_fields, des_obj = des_obj)
	estimands_for_sort = vapply(tasks, function(t) run_all_inference_estimand(t$cls_name) %||% NA_character_, character(1L))
	sort_idx = order(estimands_for_sort, vapply(tasks, `[[`, character(1L), "cls_name"), na.last = TRUE)
	cov = cov_model_display(vapply(statics, `[[`, character(1L), "cov_model_raw")[sort_idx])
	key = cov$key
	render_cov = function(raw) {
		if (is.na(raw)) return("")
		if (raw %in% c("~1", "~.")) return(raw)
		if (raw %in% names(key)) return(sprintf("(%s)", key[[raw]]))
		raw
	}
	statics = lapply(statics, function(s) {
		s$cov_model_disp = render_cov(s$cov_model_raw)
		s
	})

	# Wrapped-cell table (per user request, 2026-08-19: "imagine a row is
	# actually two rows but each cell is wrapped -- the row length is not
	# wrapped") -- every column stays in one logical row at a fixed
	# character-width cap (`EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS`), and
	# any cell whose text overflows its cap word-wraps onto that row's
	# second physical line (`run_all_inference_fmt_wrapped_row()`). Replaces
	# two earlier, both-rejected designs: a mechanical half-the-columns
	# split, and (before that) growing each column to fit its longest
	# possible value, which -- once TODO-22's typed-sentinel `"<method>
	# (<type>)"` suffixes were accounted for -- produced a ragged, way-too-
	# wide table.
	widths = EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS[EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS]
	header_lines = run_all_inference_fmt_wrapped_row(EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS, EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS)
	total_width = max(nchar(header_lines))
	list(
		header_lines = c(header_lines, strrep("=", total_width)),
		total_width = total_width, widths = widths, statics = statics, cov_key = key
	)
}

#' Prints one `run_all_inference()` result row to the console (shared by both
#' the sequential and fork-cluster-parallel code paths in
#' `InferenceSuite$run_all_inference()`, so the two produce identically
#' formatted rows), using the exact same headers/column order/alignment as
#' `print.EDIInferenceSuiteResults()`'s final pretty table -- widths
#' precomputed once by `run_all_inference_build_live_table_header()` before
#' the fitting loop starts (per user request, 2026-08-19: "it should look
#' identical to what happens on print()"). `estimate`/`se`/`ci_a`/`ci_b`/
#' `pval` format via `run_all_inference_sigfig()`, same as the final table.
#'
#' @param r One `run_all_inference_one_class()` result row.
#' @param static The matching element of `run_all_inference_build_live_
#'   table_header()`'s `statics` list (same task index as `r`).
#' @param widths Unused parameter kept for call-site compatibility (column
#'   widths are now the fixed `EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS`,
#'   looked up by `run_all_inference_fmt_wrapped_row()` itself).
#'
#' @keywords internal
#' @noRd
run_all_inference_print_row = function(r, static, widths) {
	na_chr = function(x) if (is.na(x)) "NA" else x
	ci_disp = na_chr(method_with_type_short_label(r$ci_method, r$type %||% NA_character_))
	pval_disp = na_chr(method_with_type_short_label(r$pval_method, r$type %||% NA_character_))
	# `pval method (if different)` only displays when it actually differs
	# from `ci method` (per user request, 2026-08-20) -- blank, not "NA",
	# when it matches (the usual case) or when it's genuinely `NA`.
	if (identical(pval_disp, ci_disp)) pval_disp = ""
	vals = c(
		static$inference_class_disp,
		static$cov_model_disp,
		static$estimand_disp,
		run_all_inference_sigfig(r$estimate, 3L),
		run_all_inference_sigfig(r$se, 3L),
		run_all_inference_sigfig(r$ci_a, 3L),
		run_all_inference_sigfig(r$ci_b, 3L),
		ci_disp,
		run_all_inference_sigfig(r$pval, 3L, scientific = TRUE),
		pval_disp,
		r$status
	)
	lines = run_all_inference_fmt_wrapped_row(vals, EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS)
	cat(lines[[1L]], "\n", lines[[2L]], "\n", sep = "")
}

#' Prints the `cov_model` letter-key legend beneath the live table's bottom
#' rule, same format/content as `run_all_inference_format_pretty_table()`'s
#' own trailing legend -- keeps `screen = TRUE` output "identical to what
#' happens on print()" (per user request, 2026-08-19) including this piece.
#' No-op if `cov_key` is empty.
#'
#' @keywords internal
#' @noRd
run_all_inference_print_live_cov_key = function(cov_key) {
	if (length(cov_key) == 0L) return(invisible(NULL))
	cat("\nCov mod key:\n")
	for (f in names(cov_key)) {
		cat(sprintf('  (%s)  "%s"\n', cov_key[[f]], f))
	}
}

#' Renders one `run_all_inference()` progress-bar line: a bracketed
#' percent-fill bar plus an ETA estimated from the mean per-class elapsed
#' time so far, following `simulations_framework.R`'s
#' `.draw_simulation_progress_bars()` bar-rendering/ETA-estimation pattern
#' (`SimulationFramework`'s own screen progress bar). A single instance of
#' this bar lives at the bottom of the screen, redrawn in place via `\r`
#' as each class completes (per user request, 2026-08-19) -- result rows
#' print *above* it (`run_all_inference_print_row()`), never interleaved
#' with separate bar lines per row. The final "completed" message is a
#' separate, single line printed once after the loop
#' (`run_all_inference_fmt_completed_secs()`), not embedded in this
#' function -- so this function only ever renders the in-progress state
#' (`n_done < n_total`) or the just-before-final 100% frame.
#'
#' @keywords internal
#' @noRd
run_all_inference_progress_bar_line = function(n_done, n_total, elapsed_secs_so_far) {
	width = getOption("width", 80L)
	if (is.null(width) || width < 40L) width = 80L
	prop = if (n_total > 0L) n_done / n_total else 1
	eta_str = if (n_done >= n_total) {
		"Estimated Time Left: 0s"
	} else if (n_done > 0L) {
		mean_secs = mean(elapsed_secs_so_far[seq_len(n_done)])
		paste0("Estimated Time Left: ", run_all_inference_fmt_secs(mean_secs * (n_total - n_done)))
	} else {
		"Status: Estimating..."
	}
	label = sprintf("Classes %d/%d", n_done, n_total)
	# Sized to fit `n_total` (the largest either number ever gets) in full --
	# the old fixed `label_width = 14L` combined with `substr(label, 1, 14)`
	# silently truncated the *denominator* once task counts reached 3+
	# digits (e.g. "Classes 107/187" -> "Classes 107/18", chopping the
	# trailing "7" off `n_total`), which is the real bug behind the user's
	# "the total number of classes must be >18" report, 2026-08-20 -- not a
	# logic error in how `n_total` itself was computed.
	label_width = max(14L, nchar(sprintf("Classes %d/%d", n_total, n_total)))
	padded_label = sprintf("%-*s", label_width, label)
	bar_width = max(10L, width - label_width - nchar(eta_str) - 10L)
	pct_str = sprintf(" %d%% ", floor(prop * 100))
	fill = max(0L, min(bar_width, floor(prop * bar_width)))
	full_bar = paste0(strrep("=", fill), strrep(" ", bar_width - fill))
	n_pct = nchar(pct_str)
	if (bar_width >= n_pct) {
		start_pos = (bar_width - n_pct) %/% 2 + 1
		substr(full_bar, start_pos, start_pos + n_pct - 1) = pct_str
	}
	sprintf("%s[%s] %s", padded_label, full_bar, eta_str)
}

#' Formats the `unavailable_due_to_missing_packages` footer text shared by
#' both `screen` and `html` output (see `inference_suite_inspect.md`'s
#' Output Modes section) -- one line per otherwise-applicable class listing
#' its missing packages, or a one-line "none" message if empty.
#'
#' @keywords internal
#' @noRd
run_all_inference_unavailable_footer_lines = function(unavailable_due_to_missing_packages) {
	if (length(unavailable_due_to_missing_packages) == 0L) {
		return("(none -- every design-compatible class has its required packages installed)")
	}
	nm = names(unavailable_due_to_missing_packages)
	vapply(seq_along(unavailable_due_to_missing_packages), function(i) {
		pkgs = paste(sprintf('"%s"', unavailable_due_to_missing_packages[[i]]), collapse = ", ")
		sprintf("%s - requires install.packages(%s)", nm[[i]], pkgs)
	}, character(1L))
}

#' Renders a self-contained (no JS, no external assets) HTML report for
#' `run_all_inference()`'s `html = TRUE` mode: the results table (via
#' `run_all_inference_format_html_table()`, which shares its row order and
#' per-cell display formatting exactly with
#' `run_all_inference_format_pretty_table()`'s text/screen rendering -- see
#' `run_all_inference_build_display_table()`, the one shared builder both
#' call), the design metadata, the unavailable-classes footer, and -- when
#' `out$plots` contains built ggplot objects -- both visualizations embedded
#' as base64-inlined PNGs (`run_all_inference_plot_to_base64_png()`), so the
#' page stays offline-renderable. Silently omits the Visualizations section
#' if `ggplot2`/`jsonlite` weren't available to build/encode them (already
#' warned about upstream in `run_all_inference_build_plots()`), rather than
#' erroring the whole HTML render over an optional add-on.
#'
#' @keywords internal
#' @noRd
run_all_inference_render_html = function(out) {
	html_table = run_all_inference_format_html_table(out$results_table)
	table_html = html_table$table_html
	cov_key_html = html_table$key_html
	combined_evidence_html = sprintf(
		"<p>%s</p>",
		gsub("\n", "<br>", htmltools_escape_or_identity(run_all_inference_combined_evidence_summary_line(out$combined_evidence)), fixed = TRUE)
	)
	footer_lines = run_all_inference_unavailable_footer_lines(out$unavailable_due_to_missing_packages)
	footer_html = paste0("<li>", vapply(footer_lines, htmltools_escape_or_identity, character(1L)), "</li>", collapse = "\n")
	unavailable_heading = sprintf(
		"The following Inference %s unavailable",
		if (length(out$unavailable_due_to_missing_packages) == 1L) "class is" else "classes are"
	)
	# One image per estimand for each visualization (TODO, 2026-08-19: matches
	# the "one PDF per estimand" split -- see `run_all_inference_plot_
	# estimates()`/`run_all_inference_plot_ci_forest()`'s docs), each sized
	# independently from its own content (`run_all_inference_plot_to_
	# base64_png()`'s `width = NULL` default; CI forest height still scales
	# from that one estimand's row count only, never summed across estimands
	# -- the fix for the `ggsave()` "Dimensions exceed 50 inches" error).
	estimand_heading = function(e) if (identical(e, "estimand unspecified")) e else estimand_short_label(e)
	estimates_html = vapply(names(out$plots$estimates), function(e) {
		p = out$plots$estimates[[e]]
		b64 = run_all_inference_plot_to_base64_png(p, height = min(48, max(6, 0.22 * nrow(p$data) + 2)))
		if (is.null(b64)) return("")
		h = estimand_heading(e)
		sprintf(
			'<h3>%s</h3>\n<img src="data:image/png;base64,%s" alt="Estimate number line -- %s" style="max-width:100%%;">',
			htmltools_escape_or_identity(h), b64, htmltools_escape_or_identity(h)
		)
	}, character(1L), USE.NAMES = FALSE)
	ci_forest_html = vapply(names(out$plots$ci_forest), function(e) {
		p = out$plots$ci_forest[[e]]
		b64 = run_all_inference_plot_to_base64_png(p, height = min(48, max(6, 0.35 * nrow(p$data) + 1.5)))
		if (is.null(b64)) return("")
		h = estimand_heading(e)
		sprintf(
			'<h3>%s</h3>\n<img src="data:image/png;base64,%s" alt="CI forest plot -- %s" style="max-width:100%%;">',
			htmltools_escape_or_identity(h), b64, htmltools_escape_or_identity(h)
		)
	}, character(1L), USE.NAMES = FALSE)
	images_html = paste0(c(
		if (any(nzchar(estimates_html))) c("<h2>Estimates</h2>", estimates_html[nzchar(estimates_html)]),
		if (any(nzchar(ci_forest_html))) c("<h2>Confidence intervals</h2>", ci_forest_html[nzchar(ci_forest_html)])
	), collapse = "\n")
	design = out$design
	sprintf('<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>InferenceSuite results -- %s</title>
<style>
body { font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; margin: 2rem; color: #1a1a1a; }
h1 { font-size: 1.3rem; }
h2 { font-size: 1.05rem; margin-top: 2rem; }
table.results { border-collapse: collapse; width: auto; margin-left: auto; margin-right: auto; font-size: 0.85rem; }
table.results th, table.results td { border: 1px solid #ccc; padding: 4px 8px; text-align: left; white-space: nowrap; }
table.results th { background: #f0f0f0; border-bottom: 3px double #888; }
table.results tr.group-start td { border-top: 2px solid #888; }
tr:nth-child(even) { background: #fafafa; }
.meta { color: #555; font-size: 0.9rem; }
.status-error { color: #b00020; }
.status-nonest { color: #a06800; }
</style>
</head>
<body>
<h1>InferenceSuite$run_all_inference() results</h1>
<p class="meta">
Design: %s (%s, %s)&nbsp;&middot;&nbsp; n = %s&nbsp;&middot;&nbsp;
alpha = %s&nbsp;&middot;&nbsp; generated %s&nbsp;&middot;&nbsp;
total time %.2fs&nbsp;&middot;&nbsp; EDI %s
</p>
%s
%s
%s
%s
<h2>%s</h2>
<ul>
%s
</ul>
</body>
</html>
', out$timestamp, design_class_short_label(design$design_class), design$response_type, design$design_family, design$n,
		out$alpha, out$timestamp, out$total_secs, out$edi_version, table_html, cov_key_html,
		combined_evidence_html, images_html, unavailable_heading, footer_html)
}

#' Escapes `&`, `<`, `>` for embedding free text into the HTML report
#' without pulling in an `htmltools`/`xml2` dependency for one call site.
#'
#' @keywords internal
#' @noRd
htmltools_escape_or_identity = function(x) {
	x = gsub("&", "&amp;", x, fixed = TRUE)
	x = gsub("<", "&lt;", x, fixed = TRUE)
	x = gsub(">", "&gt;", x, fixed = TRUE)
	x
}

#' Excel-column-style bijective base-26 letter label for position `i`
#' (1-indexed): `1`-`26` -> `"A"`-`"Z"`, `27` -> `"AA"`, etc. -- unlike
#' `cov_model_display()`'s plain `LETTERS[i]` (which silently produces `NA`
#' past 26), this never runs out, needed here since an estimand can
#' realistically accumulate more than 26 point-estimate rows across
#' classes x formulas x methods x types.
#'
#' @keywords internal
#' @noRd
#' Substitutes `"Δ"` (used by `inference_class_short_label()`/`estimand_
#' short_label()`, e.g. `"Mean Δ"`, `"risk Δ"`) back to plain `"diff"` for
#' text that ends up in a `ggplot2` plot -- per user request, 2026-08-20:
#' titles were rendering as `"mean ."` because the PDF device's default
#' font has no glyph for the Greek capital delta, so the character prints
#' as a `.`-shaped tofu box. The Unicode character itself renders fine in
#' the console/HTML table (both real UTF-8 text contexts), so this is
#' applied only at plot-label call sites, never inside
#' `inference_class_short_label()`/`estimand_short_label()` themselves --
#' those stay the single source of truth for the table's own display text.
#'
#' @keywords internal
#' @noRd
run_all_inference_plot_safe_text = function(x) {
	gsub("Δ", "diff", x, fixed = TRUE)
}

run_all_inference_letter_label = function(i) {
	label = ""
	while (i > 0L) {
		r = (i - 1L) %% 26L
		label = paste0(LETTERS[r + 1L], label)
		i = (i - 1L) %/% 26L
	}
	label
}

#' Display label for the estimation method a class's `compute_estimate()`
#' actually uses, shown in the estimates plot's letter key (e.g. `"(A)
#' Logistic Regr (MLE)"`) -- per user request, 2026-08-20: "usually will be
#' just MLE ... in future might be different (e.g. Firth)". Every class in
#' this package fits by maximum likelihood (or an asymptotically-equivalent
#' closed-form/M-estimator) today, so this is currently a constant; it's
#' its own function (rather than a literal `"MLE"` inlined at the call
#' site) so a future penalized/robust-estimator class has one place to
#' declare its actual estimation method once it exists, without touching
#' the plotting code.
#'
#' @keywords internal
#' @noRd
inference_class_estimation_method = function(cls_name) {
	"MLE"
}

#' Estimate-number-line visualization for `run_all_inference()`'s
#' `plots`/`pdf`/`html` output (see `inference_suite_inspect.md`'s
#' Visualizations section): every `status == "ok"` class's point estimate
#' on one shared axis (a single letter marks each point -- per user
#' request, 2026-08-20, replacing the earlier full-text-label-per-point
#' design, which crowded/overlapped once several methods landed on nearly
#' the same estimate -- with a `"(A) <inference class> (<estimation
#' method>)"` key printed as the plot's caption), and a box-and-whisker
#' summary of the estimate values underneath, faceted by `estimand`
#' (`"estimand unspecified"` for the majority of classes -- only a handful
#' declare a private `get_estimand_type()`, see `run_all_inference_
#' estimand()`) so estimates on different scales never share an axis.
#' Points whose estimates are within 1% of the estimand's value range of
#' each other are given a small vertical jitter (per user request,
#' 2026-08-20) so their letter markers don't sit exactly on top of one
#' another; genuinely distinct estimates are never jittered.
#'
#' Returns a **named list** of one ggplot per `estimand` (name = the raw
#' `estimand` value, `"estimand unspecified"` for `NA`), not a single
#' faceted plot -- per user request, 2026-08-19 ("one PDF per estimand"),
#' replacing the earlier single `facet_wrap(~estimand_facet)` plot, which
#' couldn't give each estimand its own appropriately-sized page/panel and
#' crowded very different estimand scales onto one image. `character(0)`
#' rows return `list()`. Method labels are rotated 90 degrees (vertical
#' text) rather than the previous 45-degree diagonal, per the same request,
#' so labels stack compactly instead of running diagonally into
#' neighboring points as more classes are added.
#'
#' @keywords internal
#' @noRd
run_all_inference_plot_estimates = function(results_table) {
	df = results_table[
		results_table$status == "ok" & is.finite(results_table$estimate),
		, drop = FALSE
	]
	if (nrow(df) == 0L) return(list())
	df$estimand_facet = ifelse(is.na(df$estimand), "estimand unspecified", df$estimand)
	# Same class abbreviation as the pretty-print table (per user request,
	# 2026-08-19: "use same abbreviations as the pretty print").
	df$inference_class_disp = run_all_inference_plot_safe_text(vapply(df$inference_class, inference_class_short_label, character(1L)))
	df$estimation_method = vapply(df$inference_class, inference_class_estimation_method, character(1L))
	df$y_dot = 1
	estimands = sort(unique(df$estimand_facet))
	stats::setNames(lapply(estimands, function(e) {
		d = df[df$estimand_facet == e, , drop = FALSE]
		d = d[order(d$estimate), , drop = FALSE]
		d$letter = vapply(seq_len(nrow(d)), run_all_inference_letter_label, character(1L))
		# Formula in the key parenthetical when this row actually has one
		# (per user request, 2026-08-20: "(A) Logistic Regr (MLE, ~ .)" --
		# omit entirely, not even a trailing comma, when `cov_model` is `NA`
		# or blank -- the same "blank means no formula" convention
		# `cov_model_display()` already uses for the main table).
		formula_suffix = ifelse(
			is.na(d$cov_model) | !nzchar(d$cov_model), "",
			paste0(", ", d$cov_model)
		)
		key_lines = sprintf(
			"(%s) %s (%s%s)", d$letter, d$inference_class_disp, d$estimation_method, formula_suffix
		)
		# Small vertical jitter for points within 1% of the estimand's value
		# range of each other (per user request, 2026-08-20) -- letters
		# would otherwise sit exactly on top of one another for
		# near-identical estimates across methods; genuinely distinct
		# estimates (more than 1% of the range apart) are never jittered.
		rng = diff(range(d$estimate))
		tol = if (rng > 0) rng * 0.01 else .Machine$double.eps
		cluster = cumsum(c(TRUE, diff(d$estimate) > tol))
		d$y_jitter = unlist(lapply(split(seq_len(nrow(d)), cluster), function(idx) {
			k = length(idx)
			seq(-(k - 1L), k - 1L, by = 2L) * 0.06
		}), use.names = FALSE)
		e_disp = if (identical(e, "estimand unspecified")) e else run_all_inference_plot_safe_text(estimand_short_label(e))
		use_log10 = run_all_inference_estimand_use_log10(e, d$estimate)
		x_scale = if (use_log10) {
			ggplot2::scale_x_log10(expand = ggplot2::expansion(mult = c(0.15, 0.15)))
		} else {
			ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.15, 0.15)))
		}
		ggplot2::ggplot(d, ggplot2::aes(x = estimate)) +
			# Thinner box (was `width = 0.6`) sitting flush on the axis --
			# `y = -0.22` with `width = 0.3` puts its bottom edge at exactly
			# the plot's own lower y-limit below, so there's no visible gap
			# between the box and the x-axis (per user request, 2026-08-20).
			ggplot2::geom_boxplot(
				ggplot2::aes(y = -0.22), orientation = "y", width = 0.3, outlier.shape = NA
			) +
			ggplot2::geom_text(
				ggplot2::aes(y = y_dot + y_jitter, label = letter),
				fontface = "bold", size = 3.5
			) +
			x_scale +
			# Tight y-limits (was `c(-1, y_max)`, `y_max` growing with row
			# count to fit staircased text labels) -- letters need far less
			# vertical room than the old full-text labels, and the lower
			# bound now matches the box's own bottom edge exactly (per user
			# request, 2026-08-20: "no space between box and whisker plot
			# and x-axis"; "eliminate extra vertical space").
			ggplot2::scale_y_continuous(limits = c(-0.37, 1.5), breaks = NULL, expand = c(0, 0)) +
			ggplot2::coord_cartesian(clip = "off") +
			# No title -- folded into the x-axis label instead (per user
			# request, 2026-08-20: "risk ratio estimate", not a separate
			# "Point estimates -- risk ratio" title), and the log10-scale
			# transform is never named in the label even when `use_log10`
			# is active (per the same request).
			ggplot2::labs(
				x = sprintf("%s estimate", e_disp), y = NULL,
				caption = paste(key_lines, collapse = "\n")
			) +
			ggplot2::theme_minimal() +
			ggplot2::theme(
				panel.grid.major.y = ggplot2::element_blank(),
				panel.grid.minor.y = ggplot2::element_blank(),
				plot.caption = ggplot2::element_text(hjust = 0, size = 7, lineheight = 1.2),
				# Wider left margin than the old single-plot version (was
				# l = 5pt) -- per user request, 2026-08-19: text was getting
				# cut off on the left.
				plot.margin = ggplot2::margin(t = 5, r = 20, b = 5, l = 25, unit = "pt")
			)
	}), estimands)
}

#' Annotated CI forest plot for `run_all_inference()`'s `plots`/`pdf`/`html`
#' output -- the merged former p-value/CI plots (user decision, 2026-08-17;
#' see `inference_suite_inspect.md`'s Visualizations section): every
#' `status == "ok"` class with a finite CI, one horizontal segment each
#' marked with a single letter (not per-point text -- per user request,
#' 2026-08-20, "that will compress the vertical height of the PDFs
#' substantially"), a `"(A) <class> (<method>): p = ..., CI width = ..."`
#' key line per letter printed as the plot's caption, segment color keyed
#' to significance at `alpha`, and a reference line at the null value -- drawn
#' at 1 on a log10 x-axis for the two raw-ratio-scale estimands
#' (`EDI_INFERENCE_LOG_SCALE_ESTIMANDS`: `"RR"`, `"hazard_ratio"`), at 0 on
#' a linear axis for every other estimand (per user request, 2026-08-20;
#' `run_all_inference_estimand_use_log10()`). **Remaining limitation:**
#' this only covers those two estimand tags -- any estimand this package
#' has not tagged as raw-ratio-scale still gets a linear axis / null-at-0,
#' even if it turns out to also warrant a log transform.
#'
#' Returns a **named list** of one CI forest ggplot per `estimand` (name =
#' the raw `estimand` value, `"estimand unspecified"` for `NA`), not a
#' single faceted plot -- per user request, 2026-08-19 ("one PDF per
#' estimand"). This also directly fixes a real bug: the old single-plot,
#' `facet_wrap(~estimand_facet)` design sized its PDF/PNG page height from
#' the row count \strong{summed across every estimand}
#' (`run_all_inference_save_plots_pdf()`'s old `n_ci_rows`), which could
#' exceed `ggplot2::ggsave()`'s 50-inch `limitsize` cap once enough classes/
#' methods/types were fit across several estimands (confirmed via the
#' `ggsave()` error the user hit, 2026-08-19) -- splitting per estimand
#' means each page's height only ever scales with \emph{that one
#' estimand's} row count. `list()` if there are no plottable rows.
#'
#' @keywords internal
#' @noRd
run_all_inference_plot_ci_forest = function(results_table, alpha) {
	df = results_table[
		results_table$status == "ok" &
			is.finite(results_table$ci_a) & is.finite(results_table$ci_b),
		, drop = FALSE
	]
	if (nrow(df) == 0L) return(list())
	df$estimand_facet = ifelse(is.na(df$estimand), "estimand unspecified", df$estimand)
	df$significant = !is.na(df$pval) & df$pval < alpha
	pval_num = ifelse(
		is.na(df$pval), "NA",
		ifelse(df$pval < 1e-4, sprintf("%.2e", df$pval), sprintf("%.4f", df$pval))
	)
	width_num = sprintf("%.3g", df$ci_b - df$ci_a)
	# Same class/method abbreviations as the pretty-print table (per user
	# request, 2026-08-19).
	df$inference_class_disp = run_all_inference_plot_safe_text(vapply(df$inference_class, inference_class_short_label, character(1L)))
	ci_disp = method_with_type_short_label(df$ci_method, df$type)
	pval_disp = method_with_type_short_label(df$pval_method, df$type)
	ci_disp_na = ifelse(is.na(ci_disp), "NA", ci_disp)
	pval_disp_na = ifelse(is.na(pval_disp), "NA", pval_disp)
	# Don't print "(jackknife / jackknife)" -- only show the pval-side
	# method when it actually differs from the CI-side one (per user
	# request, 2026-08-20; same "if different" rule already applied to the
	# `pval method (if different)` table column).
	method_paren = ifelse(ci_disp_na == pval_disp_na, ci_disp_na, sprintf("%s / %s", ci_disp_na, pval_disp_na))
	# Per user request, 2026-08-20: replace the old per-point stacked text
	# (class/method under each point, p-value left of it, width right of
	# it) with a single letter marker at each point and a `"(A) <class>
	# (<method>): p = ..., CI width = ..."` key line printed as the plot's
	# caption -- "that will compress the vertical height of the PDFs
	# substantially" (no more per-point text competing for vertical room).
	df$key_line = sprintf(
		"%s (%s): p = %s, CI width = %s", df$inference_class_disp, method_paren, pval_num, width_num
	)
	estimands = sort(unique(df$estimand_facet))
	stats::setNames(lapply(estimands, function(e) {
		d = df[df$estimand_facet == e, , drop = FALSE]
		d = d[order(d$estimate), , drop = FALSE]
		d$y = seq_len(nrow(d))
		d$letter = vapply(seq_len(nrow(d)), run_all_inference_letter_label, character(1L))
		key_lines = sprintf("(%s) %s", d$letter, d$key_line)
		# Per-estimand Cauchy-combined p-value (per user request, 2026-08-20:
		# "each illustration gets its own cauchy combined pval since it is
		# its own estimand") -- unweighted combination over this estimand's
		# own usable rows only, the same `run_all_inference_combine_
		# pvalues()` the per-estimand breakdown lines already use
		# (`run_all_inference_per_estimand_breakdown_lines()`), just scoped
		# to this one plot's `d` instead of the whole results table.
		combined = run_all_inference_combine_pvalues(d$pval[is.finite(d$pval)])
		combined_str = if (is.na(combined$pval)) "NA" else formatC(combined$pval, digits = 3, format = "g")
		e_disp = if (identical(e, "estimand unspecified")) e else run_all_inference_plot_safe_text(estimand_short_label(e))
		# Per user request, 2026-08-20 ("for each estimand, decide if it
		# makes sense to display on a log10 scale"): closes this function's
		# previously-documented known limitation ("the null-value reference
		# line is always drawn at zero -- ratio-scale nulls ... would need a
		# per-class scale declaration") for the two raw-ratio-scale
		# estimands (`EDI_INFERENCE_LOG_SCALE_ESTIMANDS`) -- log10 x-axis,
		# null reference line at 1 instead of 0.
		use_log10 = run_all_inference_estimand_use_log10(e, c(d$ci_a, d$ci_b, d$estimate))
		null_x = if (use_log10) 1 else 0
		x_scale = if (use_log10) {
			ggplot2::scale_x_log10(expand = ggplot2::expansion(mult = c(0.15, 0.15)))
		} else {
			ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.15, 0.15)))
		}
		ggplot2::ggplot(d, ggplot2::aes(y = y)) +
			ggplot2::geom_vline(xintercept = null_x, linetype = "dashed", color = "grey40") +
			ggplot2::geom_segment(
				ggplot2::aes(x = ci_a, xend = ci_b, yend = y, color = significant),
				linewidth = 1
			) +
			ggplot2::geom_text(
				ggplot2::aes(x = estimate, label = letter, color = significant),
				fontface = "bold", size = 3.5
			) +
			ggplot2::scale_color_manual(
				values = c(`TRUE` = "#1a7a3c", `FALSE` = "#888888"), guide = "none"
			) +
			# Less vertical space between rows than the old `mult = 0.15`
			# (per user request, 2026-08-19) -- tightened further now that
			# no per-point text needs vertical room (per user request,
			# 2026-08-20).
			ggplot2::scale_y_continuous(breaks = NULL, expand = ggplot2::expansion(mult = 0.05)) +
			x_scale +
			# Minimal title (just "95% CIs", per user request, 2026-08-20 --
			# not the earlier "XX% confidence intervals -- <estimand>",
			# which is now redundant with the x-axis label carrying the
			# estimand name), and no subtitle (the significance-color
			# explanation, removed per user request, 2026-08-20 -- the
			# letter key's caption is now the only annotation).
			ggplot2::labs(
				x = e_disp, y = NULL,
				title = sprintf("%g%% CIs (combined p = %s)", 100 * (1 - alpha), combined_str),
				caption = paste(key_lines, collapse = "\n")
			) +
			ggplot2::theme_minimal() +
			ggplot2::theme(
				panel.grid.major.y = ggplot2::element_blank(),
				panel.grid.minor.y = ggplot2::element_blank(),
				plot.caption = ggplot2::element_text(hjust = 0, size = 7, lineheight = 1.2),
				plot.margin = ggplot2::margin(t = 5, r = 20, b = 5, l = 25, unit = "pt")
			)
	}), estimands)
}

#' Builds both `run_all_inference()` visualizations. Each of `estimates`/
#' `ci_forest` is a **named list** of one ggplot per `estimand` (see
#' `run_all_inference_plot_estimates()`/`run_all_inference_plot_ci_forest()`'s
#' own docs -- TODO, 2026-08-19: split from a single faceted plot each, so
#' every estimand gets its own appropriately-sized page/image), or
#' `list(estimates = list(), ci_forest = list())` with a `warning()` (not an
#' error -- per-feature decision) if the optional `ggplot2` dependency is
#' not installed.
#'
#' @keywords internal
#' @noRd
run_all_inference_build_plots = function(results_table, alpha) {
	if (!requireNamespace("ggplot2", quietly = TRUE)) {
		warning(
			"InferenceSuite$run_all_inference: the 'ggplot2' package is not installed -- ",
			"skipping plots (estimate number line / CI forest). Install 'ggplot2' to enable them.",
			call. = FALSE
		)
		return(list(estimates = list(), ci_forest = list()))
	}
	list(
		estimates = run_all_inference_plot_estimates(results_table),
		ci_forest = run_all_inference_plot_ci_forest(results_table, alpha)
	)
}

#' Saves `run_all_inference()`'s plots to **two** separate timestamped
#' multi-page PDFs -- `path_estimates` (one page per estimand's estimates
#' plot) and `path_ci_forest` (one page per estimand's CI forest plot) --
#' per user request, 2026-08-19 ("one PDF per estimand for estimates ...
#' one PDF per estimand for CI"), replacing the earlier single two-page PDF.
#' A `pdf()` device can't vary page size page-to-page without reopening the
#' file (which would truncate pages already written), so all pages within
#' one file share that file's single page height -- for `path_estimates`
#' this is always a fixed 6in (the estimates plot never stacks rows
#' vertically, so it doesn't need to scale with row count at all); for
#' `path_ci_forest` it's sized from the \emph{largest single estimand's} row
#' count (not summed across estimands, unlike the old design -- the actual
#' cause of the `ggplot2::ggsave()` "Dimensions exceed 50 inches" error the
#' user hit, since a page's height only ever needs to fit one estimand's
#' rows now), capped at 48in to stay under `ggsave()`-style size sanity
#' limits even for a single very-large estimand.
#'
#' @param plots `run_all_inference_build_plots()`'s return value (named
#'   lists of ggplots, one per estimand, possibly empty).
#' @param path_estimates,path_ci_forest File paths for the two PDFs.
#' @return Invisibly, `NULL`. Skips writing a file for a plot list that's
#'   empty (nothing plottable for that visualization).
#'
#' @keywords internal
#' @noRd
#' Longest text label actually drawn on plot `p` (its `method_label`/
#' `pval_label`/`width_label` columns, whichever are present) -- used to
#' size a plot's page/image width from its real content instead of a flat
#' constant, per user request, 2026-08-19 ("the PDFs don't have to be
#' regular width size -- they can be cropped to whatever the width truly
#' is"). Returns `0L` if `p` has none of those columns.
#'
#' @keywords internal
#' @noRd
run_all_inference_plot_max_label_chars = function(p) {
	d = p$data
	label_cols = intersect(c("method_label", "pval_label", "width_label"), names(d))
	data_max = if (length(label_cols) == 0L) {
		0L
	} else {
		max(vapply(label_cols, function(cn) max(nchar(as.character(d[[cn]])), 0L), integer(1L)))
	}
	# The estimates plot (per user request, 2026-08-20) has no long text in
	# its data any more -- its longest text now lives in the caption's
	# per-line letter key (`"(A) <class> (<method>, <formula>)"`), which
	# `p$data` doesn't capture at all.
	caption = p$labels$caption %||% ""
	caption_max = if (nzchar(caption)) max(nchar(strsplit(caption, "\n", fixed = TRUE)[[1L]])) else 0L
	max(data_max, caption_max)
}

#' Saves `run_all_inference()`'s plots to **two** separate timestamped
#' multi-page PDFs -- `path_estimates` (one page per estimand's estimates
#' plot) and `path_ci_forest` (one page per estimand's CI forest plot) --
#' per user request, 2026-08-19 ("one PDF per estimand for estimates ...
#' one PDF per estimand for CI"), replacing the earlier single two-page PDF.
#' A `pdf()` device can't vary page size page-to-page without reopening the
#' file (which would truncate pages already written), so all pages within
#' one file share that file's single page height/width -- height for
#' `path_estimates` is always a fixed 6in (the estimates plot never stacks
#' rows vertically, so it doesn't need to scale with row count at all); for
#' `path_ci_forest` it's sized from the \emph{largest single estimand's} row
#' count (not summed across estimands, unlike the old design -- the actual
#' cause of the `ggplot2::ggsave()` "Dimensions exceed 50 inches" error the
#' user hit, since a page's height only ever needs to fit one estimand's
#' rows now), capped at 48in to stay under `ggsave()`-style size sanity
#' limits even for a single very-large estimand. Width for both files is
#' likewise sized from real content (`run_all_inference_plot_max_label_
#' chars()`'s longest on-page text label, the widest the estimates plot's
#' rotated-vertical labels ever need since they no longer run diagonally
#' outward) rather than a flat constant (per the same request).
#'
#' @param plots `run_all_inference_build_plots()`'s return value (named
#'   lists of ggplots, one per estimand, possibly empty).
#' @param path_estimates,path_ci_forest File paths for the two PDFs.
#' @return Invisibly, `NULL`. Skips writing a file for a plot list that's
#'   empty (nothing plottable for that visualization).
#'
#' @keywords internal
#' @noRd
run_all_inference_save_plots_pdf = function(plots, path_estimates, path_ci_forest) {
	if (length(plots$estimates) > 0L) {
		max_chars = max(vapply(plots$estimates, run_all_inference_plot_max_label_chars, integer(1L)))
		width = min(10, max(5, 4 + 0.03 * max_chars))
		# Scales with the largest single estimand's row count -- the
		# staircased labels (`run_all_inference_plot_estimates()`, per user
		# request, 2026-08-20: labels were overlapping) need proportionally
		# more vertical room as more methods/classes land in one estimand.
		est_rows = vapply(plots$estimates, function(p) nrow(p$data), integer(1L))
		height = min(48, max(6, 0.22 * max(est_rows) + 2))
		grDevices::pdf(path_estimates, width = width, height = height, onefile = TRUE)
		for (p in plots$estimates) print(p)
		grDevices::dev.off()
	}
	if (length(plots$ci_forest) > 0L) {
		ci_rows = vapply(plots$ci_forest, function(p) nrow(p$data), integer(1L))
		height = min(48, max(6, 0.35 * max(ci_rows) + 1.5))
		max_chars = max(vapply(plots$ci_forest, run_all_inference_plot_max_label_chars, integer(1L)))
		width = min(14, max(6, 3 + 0.09 * max_chars))
		grDevices::pdf(path_ci_forest, width = width, height = height, onefile = TRUE)
		for (p in plots$ci_forest) print(p)
		grDevices::dev.off()
	}
	invisible(NULL)
}

#' Base64-PNG-encodes one ggplot object for inline embedding into the
#' self-contained HTML report (`run_all_inference_render_html()`) -- keeps
#' the HTML offline-renderable per the no-external-assets rule. Returns
#' `NULL` (not an error) if `plot` is `NULL` or `jsonlite` (used for
#' base64 encoding) is not installed.
#'
#' @keywords internal
#' @noRd
run_all_inference_plot_to_base64_png = function(plot, width = NULL, height = 6) {
	if (is.null(plot) || !requireNamespace("jsonlite", quietly = TRUE)) return(NULL)
	if (is.null(width)) {
		# Per-image sizing from real content (unlike a shared PDF page, each
		# HTML `<img>` is its own independent `ggsave()` call, so it can be
		# cropped to exactly what this one plot needs -- per user request,
		# 2026-08-19).
		width = min(14, max(6, 3 + 0.09 * run_all_inference_plot_max_label_chars(plot)))
	}
	tmp = tempfile(fileext = ".png")
	on.exit(unlink(tmp), add = TRUE)
	ggplot2::ggsave(tmp, plot = plot, width = width, height = height, dpi = 110, bg = "white")
	jsonlite::base64_enc(readBin(tmp, "raw", file.info(tmp)$size))
}

#' Combines p-values `pvals` via the Cauchy combination test (CCT):
#' `T = sum(w_i * tan((0.5 - p_i) * pi))`,
#' `combined_pval = 0.5 - atan(T) / pi`. Its defining property -- the reason
#' it backs `run_all_inference()`'s Combined Evidence Metric rather than
#' Fisher's/Stouffer's/minP -- is that the combined p-value is
#' asymptotically valid under \strong{arbitrary and unknown dependence}
#' among the `p_i`, with no covariance matrix to estimate and no resampling
#' to calibrate it; see `inference_suite_inspect.md`'s "Combined Evidence
#' Metric" section for the full union-intersection-test rationale and
#' interpretation caveat.
#'
#' This is a flat, non-group-aware combiner: `weights` is already the final
#' per-`p_i` weight vector by the time it reaches here. The
#' `"estimand_grouped"` two-stage combination (within-`estimand` CCT, then
#' across-group CCT) is mathematically equivalent to one flat call with a
#' particular closed-form weight vector (`w_i = 1 / (G * m_i)`), so no
#' separate grouped-combiner code path exists -- the caller computes that
#' vector and passes it in as `weights` (see TODO-15/16 in the plan doc).
#'
#' Deliberately does not clip `pvals` away from exactly 0/1 or guard the
#' <2-usable-p-values degenerate case -- that hardening is
#' `inference_suite_inspect.md → TODO-17`, scoped separately from this
#' formula implementation.
#'
#' @references Liu, Y. and Xie, J. (2020), "Cauchy combination test: a
#'   powerful test with analytic p-value calculation under arbitrary
#'   dependency structures," \emph{Journal of the American Statistical
#'   Association}, 115(529), 393-402.
#'
#' @param pvals Numeric vector of p-values to combine, each in `(0, 1)`.
#' @param weights Numeric vector the same length as `pvals`, or `NULL`
#'   (default) for equal weights `1 / length(pvals)`. Need not sum to 1 --
#'   renormalized internally so the effective weights always do.
#' @return The combined p-value, a numeric scalar in `(0, 1)`.
#'
#' Per-row weight under the `"estimand_grouped"` Combined Evidence policy:
#' equal weight across `estimand` groups, split evenly within each group --
#' `w_i = 1 / (G * m_i)` for usable rows (`status == "ok"` and a finite
#' `pval`), where `G` is the number of distinct `estimand` values among
#' usable rows and `m_i` is the size of row `i`'s own group. `NA_real_` for
#' any non-usable row (nonestimable/error/timeout, or `status == "ok"` with
#' no finite `pval`), since it contributes nothing to the combined p-value.
#' Feeds `cct_combine_pvalues()`/`run_all_inference_combine_pvalues()` as the
#' `weights` argument. Returns all-`NA_real_` if there are no usable rows.
#'
#' @param results_table A `run_all_inference()`-shaped results table with
#'   `status`, `pval`, and `estimand` columns.
#' @return A numeric vector the same length/order as `results_table`'s rows.
#'
#' Acronyms `inference_class_wordify()` treats as atomic tokens rather than
#' splitting letter-by-letter -- both when they stand alone inside an
#' otherwise all-caps run with no case transition to key off (e.g. the `KK`
#' in `KKGLMM`, or the `T`/`KK` in `AdjustedTKK`) and as a whitelist so a
#' *known* multi-letter acronym is never itself broken apart.
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_CLASS_ACRONYMS = c("GLMM", "IVWC", "KK14", "KK21", "KK", "OLS", "GEE", "CMH", "RD", "RR", "T")

#' Response-family/cross-response-type name prefixes
#' `inference_class_short_label()` strips (after the shared `"Inference"`
#' prefix), matching the same vocabulary `infer_inference_response_types()`
#' (`inference_class_registry.R`) uses to *classify* a class by response
#' type -- but tuned for "what's a redundant prefix to a human reading a
#' results table," not for response-type regex matching, so this list is
#' deliberately its own copy rather than reused from that function (e.g.
#' `Bai` needs no entry here since `InferenceBaiAdjustedTKK14` already reads
#' fine as `Bai Adjusted T KK` without stripping anything first).
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_CLASS_PREFIXES = c("Contin", "Count", "Incidence", "Incid", "Ordinal", "Prop", "Survival", "All")

#' Splits an all-caps run with no internal case transition (e.g. `"KKGLMM"`,
#' or the `"TKK"` left over from `"AdjustedTKK"`) into its constituent
#' `EDI_INFERENCE_CLASS_ACRONYMS` tokens, greedily matching the longest
#' acronym at each position. A character with no acronym match at its
#' position falls through as its own single-character token.
#'
#' @keywords internal
#' @noRd
inference_class_split_caps_run = function(run) {
	out = character(0)
	i = 1L
	n = nchar(run)
	while (i <= n) {
		matched = FALSE
		for (a in EDI_INFERENCE_CLASS_ACRONYMS) {
			la = nchar(a)
			if (i + la - 1L <= n && substr(run, i, i + la - 1L) == a) {
				out = c(out, a); i = i + la; matched = TRUE; break
			}
		}
		if (!matched) { out = c(out, substr(run, i, i)); i = i + 1L }
	}
	out
}

#' Splits a `PascalCase`/acronym-bearing class-name remainder (post
#' `"Inference"`-and-prefix stripping, e.g. `"SimpleMeanDiff"`, `"KKGLMM"`,
#' `"BaiAdjustedTKK"`) into space-separated words for display. Two boundary
#' rules run first (standard camelCase splitting: lower-to-upper, and
#' acronym-to-capitalized-word), which alone resolves most cases (e.g.
#' `"KKMeanDiff"` -> `"KK Mean Diff"`); any leftover all-caps run with no
#' case transition at all (e.g. `"GLMM"` glued directly onto another
#' acronym, or `"TKK"`) is then split via
#' `inference_class_split_caps_run()`'s acronym dictionary, since case
#' patterns alone can't disambiguate that case.
#'
#' @keywords internal
#' @noRd
inference_class_wordify = function(label) {
	parts = strsplit(label, "(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", perl = TRUE)[[1]]
	words = character(0)
	for (p in parts) {
		# `[A-Z]{2,}[0-9]*` (not plain `[A-Z]{2,}`) so a digit-suffixed
		# acronym run (e.g. "TKK14" -- "T" and "KK14" glued together with
		# no case transition for the boundary regex above to catch) still
		# gets routed through the acronym splitter, not left as one fused
		# token. Found 2026-08-19 reverting the KK14/KK21-collapsing
		# short-circuit that had been masking this: without that
		# short-circuit, "BaiAdjustedTKK14" reached here and rendered as
		# "Bai Adjusted TKK14", no space before "KK14".
		if (grepl("^[A-Z]{2,}[0-9]*$", p) && !(p %in% EDI_INFERENCE_CLASS_ACRONYMS)) {
			words = c(words, inference_class_split_caps_run(p))
		} else {
			words = c(words, p)
		}
	}
	paste(words, collapse = " ")
}

#' Short, human-readable display label for inference class `name`: strips
#' the shared `"Inference"` prefix, strips one leading
#' `EDI_INFERENCE_CLASS_PREFIXES` response-family segment if present,
#' collapses a trailing `KK14`/`KK21` design-variant suffix to a bare `KK`
#' (safe because those variants are mutually exclusive per design -- see
#' `is_inference_class_compatible_with_design_metadata()`'s KK-matching
#' gate -- so they never collide within one results table), then
#' word-splits the remainder via `inference_class_wordify()`. Falls back to
#' the `"Inference"`-stripped name alone (word-split) if no known prefix
#' matches, rather than guessing at an unfamiliar naming convention. Purely
#' cosmetic: never touches `results_table$inference_class` itself, which
#' stays the real, `EDI::`-resolvable class name for programmatic use.
#'
#' @keywords internal
#' @noRd
#' Short display form of a `Design` class name (`class(des_obj)[[1L]]`,
#' e.g. `"DesignSeqOneByOneKK21"`), used wherever `run_all_inference()`
#' reports the design being fit (`print.EDIInferenceSuiteResults()`'s
#' summary line, the HTML report header) -- per user request, 2026-08-19:
#' `"DesignSeqOneByOneKK21"` -> `"KK21 Seq (one by one)"`, not the raw class
#' name. Only the `"SeqOneByOne"`/`"Fixed"` family prefixes are recognized
#' (the two design families this package actually has); anything else falls
#' back to the class name with just `"Design"` stripped, matching this
#' file's established "unknown input degrades gracefully, never errors"
#' convention rather than guessing at an unfamiliar naming scheme.
#'
#' @keywords internal
#' @noRd
design_class_short_label = function(name) {
	rest = sub("^Design", "", name)
	if (startsWith(rest, "SeqOneByOne")) {
		algo = substring(rest, nchar("SeqOneByOne") + 1L)
		return(sprintf("%s Seq (one by one)", algo))
	}
	if (startsWith(rest, "Fixed")) {
		algo = substring(rest, nchar("Fixed") + 1L)
		return(sprintf("%s Fixed", algo))
	}
	rest
}

inference_class_short_label = function(name) {
	rest = sub("^Inference", "", name)
	for (p in EDI_INFERENCE_CLASS_PREFIXES) {
		if (startsWith(rest, p)) { rest = substring(rest, nchar(p) + 1L); break }
	}
	# "Simple" (e.g. the leftover from InferenceAllSimpleMeanDiff after "All"
	# is stripped above) carries no information once the response-family
	# prefix is already gone -- every remaining class name in this family is
	# implicitly "simple" relative to its KK/GEE/GLMM-adjusted counterparts.
	if (startsWith(rest, "Simple")) rest = substring(rest, nchar("Simple") + 1L)
	# Deliberately NOT collapsing a trailing KK14/KK21 suffix (e.g.
	# BaiAdjustedTKK14/BaiAdjustedTKK21) to a bare "KK" -- reverted
	# 2026-08-19 per user correction: the two design variants are only
	# guaranteed not to co-occur *within a single InferenceSuite table*
	# (mutually exclusive per design), which does not hold once results
	# from two different runs/designs are compared side by side (saved
	# JSON, two terminal sessions, etc.) -- collapsing the distinction
	# there would silently make a KK14 result and a KK21 result look
	# identical. KK14/KK21 are genuinely different designs; keep the
	# distinction in the display name unconditionally.
	# "OneLik" carries no information once IVWC classes are excluded from
	# InferenceSuite discovery entirely (2026-08-19) -- every remaining
	# KK-family class in the suite is implicitly "one likelihood," so this
	# suffix is pure noise here; a class actually named *IVWC still says so
	# (that word is never stripped).
	rest = sub("OneLik$", "", rest)
	words = strsplit(inference_class_wordify(rest), " ", fixed = TRUE)[[1]]
	word_abbrev = c(Binomial = "Binom", Identity = "Ident")
	words = ifelse(words %in% names(word_abbrev), word_abbrev[words], words)
	# "Nurminen" dropped entirely (not abbreviated) from
	# InferenceIncidMiettinenNurminenRiskDiff-style names, per user request
	# (2026-08-19) -- "Miettinen" alone is unambiguous within this package.
	words = words[!(words %in% c("Nurminen"))]
	label = paste(words, collapse = " ")
	# "Diff" -> "Δ" everywhere in the label (generalized 2026-08-20 from an
	# earlier "Mean Diff"-only override, per user request: "everywhere in
	# pretty print that says 'Diff' should be 'Δ' instead"), e.g. "Mean
	# Diff" -> "Mean Δ", "G Comp Risk Diff" -> "G Comp Risk Δ".
	label = gsub("\\bDiff\\b", "Δ", label)
	label
}

#' Short display form of an `estimand` registry value: underscores to
#' spaces, then a small fixed set of word abbreviations
#' (`difference`->`diff`, `stochastic`->`stoch`, `superiority`->`super`).
#' `NA_character_` passes through unchanged. Purely cosmetic, like
#' `inference_class_short_label()` -- never touches
#' `results_table$estimand` itself, which stays the canonical registry
#' string used for `"estimand_grouped"` weighting/grouping logic.
#'
#' @keywords internal
#' @noRd
estimand_short_label = function(estimand) {
	vapply(estimand, function(e) {
		if (is.na(e)) return(NA_character_)
		if (identical(e, "RD")) return("risk Δ")
		if (identical(e, "RR")) return("risk ratio")
		if (identical(e, "hodges_lehmann_shift")) return("HL shift")
		s = gsub("log_odds", "logodds", e, fixed = TRUE)
		s = gsub("_", " ", s, fixed = TRUE)
		s = gsub("difference", "diff", s, fixed = TRUE)
		s = gsub("stochastic", "stoch", s, fixed = TRUE)
		s = gsub("superiority", "super", s, fixed = TRUE)
		s = gsub("conditional", "cond", s, fixed = TRUE)
		# Unambiguous within this package's estimand vocabulary without the
		# trailing noun (per user request, 2026-08-19): "logodds ratio ..."
		# is always the log-odds-ratio scale, and "probit effect ..." is
		# always the probit-index scale -- no other estimand family uses
		# either word, so dropping them loses no information here.
		s = gsub("logodds ratio", "logodds", s, fixed = TRUE)
		s = gsub("probit effect", "probit", s, fixed = TRUE)
		# "diff" -> "Δ" everywhere (per user request, 2026-08-20, matching
		# `inference_class_short_label()`'s equivalent "Diff" -> "Δ" rule),
		# e.g. "median diff" -> "median Δ".
		s = gsub("\\bdiff\\b", "Δ", s)
		s
	}, character(1L), USE.NAMES = FALSE)
}

#' Short display form for a vector of `cov_model` values (deparsed formula
#' strings, or `NA`): the treatment-only (`"~1"`) and all-covariates
#' (`"~.""`) sentinels are shown as-is; every other distinct formula string
#' is assigned a letter (`"(A)"`, `"(B)"`, ...) in first-encountered order,
#' with the full mapping returned separately as `key` so the caller can
#' print a legend once rather than repeating long formula strings on every
#' row. `NA` displays as an empty string (blank), unlike every other
#' display column in `run_all_inference_format_pretty_table()`, which use
#' the literal string `"NA"` -- `cov_model` is blank specifically because a
#' missing value here means "no formula applies to this class" (e.g.
#' `SimpleMeanDiff`), a structurally different fact than "this class has a
#' formula but the value came back missing," so it reads better as an
#' absence than as an explicit `NA`.
#'
#' @param cov_models Character vector (may contain `NA`) of deparsed
#'   formula strings, e.g. `results_table$cov_model`.
#' @return `list(disp = <character vector, same length as cov_models>, key
#'   = <named character vector: formula string -> letter>)`.
#'
#' @keywords internal
#' @noRd
cov_model_display = function(cov_models) {
	key = character(0)
	disp = character(length(cov_models))
	sentinels = c("~1", "~.")
	for (i in seq_along(cov_models)) {
		f = cov_models[[i]]
		if (is.na(f)) { disp[[i]] = ""; next }
		if (f %in% sentinels) { disp[[i]] = f; next }
		if (!(f %in% names(key))) {
			key[f] = LETTERS[length(key) + 1L]
		}
		disp[[i]] = sprintf("(%s)", key[[f]])
	}
	list(disp = disp, key = key)
}

#' Rounds `x` to `n` significant figures and formats as a fixed-point
#' string by default (used for e.g. the `weight` column, whose values are
#' always in `(0, 1]` and read more naturally as `"0.031"` than
#' `"3.1e-02"`), or compact scientific notation when `scientific = TRUE`
#' (used for `pval`, where fixed-point at 3 significant figures would
#' otherwise force long strings like `"0.0000120"` for a small p-value).
#' `NA` passes through as the string `"NA"` either way.
#'
#' @param scientific If `TRUE`, format as `<mantissa>e<exponent>` (e.g.
#'   `"1.2e-05"`) instead of fixed-point.
#'
#' @keywords internal
#' @noRd
run_all_inference_sigfig = function(x, n = 2L, scientific = FALSE) {
	vapply(x, function(v) {
		if (is.na(v)) return("NA")
		if (v == 0) return(if (scientific) "0e+00" else "0.0")
		if (scientific) return(formatC(v, digits = n - 1L, format = "e"))
		d = n - 1L - floor(log10(abs(v)))
		formatC(round(v, d), digits = max(d, 0L), format = "f")
	}, character(1L), USE.NAMES = FALSE)
}

#' Builds the single shared display representation both
#' `run_all_inference_format_pretty_table()` (text/screen) and
#' `run_all_inference_format_html_table()` (HTML report) render from --
#' guarantees the two surfaces show identical row order and identical
#' per-cell display strings, since neither computes its own version of
#' either. Rows sorted by (real, underscored) `estimand`; every display-only
#' transform used by both renderers is applied here once: `inference_class`
#' via `inference_class_short_label()`, `estimand` via
#' `estimand_short_label()`, `cov_model` via `cov_model_display()`,
#' `estimate`/`se`/`ci_a`/`ci_b`/`weight` via `run_all_inference_sigfig()`
#' (3 significant figures, fixed-point; 2 for `weight`), `pval` via the same
#' helper with `scientific = TRUE` (fixed-point at 3 significant figures
#' would otherwise force long strings like `"0.0000120"` for small
#' p-values). Never mutates `results_table` itself. `NA`/`NA_real_`/
#' `NA_character_` all display as the literal string `"NA"` (except
#' `cov_model`, which displays blank -- see `cov_model_display()`).
#'
#' @param results_table A `run_all_inference()`-shaped results table.
#' @return `NULL` if `results_table` has zero rows, else
#'   `list(tbl = <results_table, sorted>, display = <data.frame, same
#'   sorted row order, all-character display columns>, cov_key = <named
#'   character vector: formula string -> letter, possibly empty>)`.
#'
#' @keywords internal
#' @noRd
run_all_inference_build_display_table = function(results_table) {
	tbl = results_table
	if (nrow(tbl) == 0L) return(NULL)
	tbl = tbl[order(tbl$estimand, tbl$inference_class, na.last = TRUE), , drop = FALSE]

	cov = cov_model_display(tbl$cov_model)
	na_chr = function(x) ifelse(is.na(x), "NA", x)

	ci_disp = na_chr(method_with_type_short_label(tbl$ci_method, tbl$type))
	pval_disp = na_chr(method_with_type_short_label(tbl$pval_method, tbl$type))
	# `pval method (if different)` only displays when it actually differs
	# from `ci method` (per user request, 2026-08-20) -- blank, not "NA",
	# when it matches (the usual case) or when it's genuinely `NA`.
	pval_disp[pval_disp == ci_disp] = ""

	display = data.frame(
		`inference class` = vapply(tbl$inference_class, inference_class_short_label, character(1L)),
		`cov mod`          = cov$disp,
		estimand           = na_chr(estimand_short_label(tbl$estimand)),
		est                = run_all_inference_sigfig(tbl$estimate, 3L),
		se                 = run_all_inference_sigfig(tbl$se, 3L),
		ci_a               = run_all_inference_sigfig(tbl$ci_a, 3L),
		ci_b               = run_all_inference_sigfig(tbl$ci_b, 3L),
		`ci method`        = ci_disp,
		pval               = run_all_inference_sigfig(tbl$pval, 3L, scientific = TRUE),
		`pval method (if different)` = pval_disp,
		weight             = run_all_inference_sigfig(tbl$weight, 2L),
		status             = tbl$status,
		check.names = FALSE, stringsAsFactors = FALSE
	)

	list(tbl = tbl, display = display, cov_key = cov$key)
}

#' Renders `results_table` as an aligned, left-justified text table for
#' `print.EDIInferenceSuiteResults()`, from the shared display built by
#' `run_all_inference_build_display_table()`: a double-rule (`=`) under the
#' header, a single rule (`-`) between `estimand` groups and once more at
#' the bottom, and a `cov_model` letter-key legend appended after the table
#' when non-empty -- see `run_all_inference_build_display_table()`'s own
#' documentation for the per-column display transforms, which this function
#' does not duplicate.
#'
#' @param results_table A `run_all_inference()`-shaped results table.
#' @return A character vector, one table line per element (plus a blank
#'   line and legend lines at the end if any `cov_model` value needed a
#'   letter key). `"(no rows)"` if `results_table` has zero rows.
#'
#' @keywords internal
#' @noRd
run_all_inference_format_pretty_table = function(results_table) {
	built = run_all_inference_build_display_table(results_table)
	if (is.null(built)) return("(no rows)")
	tbl = built$tbl; display = built$display; cov_key = built$cov_key

	headers = names(display)

	# Wrapped-cell table (per user request, 2026-08-19: "imagine a row is
	# actually two rows but each cell is wrapped -- the row length is not
	# wrapped") -- shares `run_all_inference_fmt_wrapped_row()`/the fixed
	# `EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS` with the live table
	# (`run_all_inference_build_live_table_header()`/`run_all_inference_
	# print_row()`), so the two stay visually identical.
	header_lines = run_all_inference_fmt_wrapped_row(headers, headers)
	total_width = max(nchar(header_lines))
	lines = c(header_lines, strrep("=", total_width))
	prev_estimand = NULL
	for (i in seq_len(nrow(display))) {
		if (!is.null(prev_estimand) && !identical(tbl$estimand[[i]], prev_estimand)) {
			lines = c(lines, strrep("-", total_width))
		}
		vals = as.character(display[i, ])
		lines = c(lines, run_all_inference_fmt_wrapped_row(vals, headers))
		prev_estimand = tbl$estimand[[i]]
	}
	lines = c(lines, strrep("-", total_width))

	if (length(cov_key) > 0L) {
		lines = c(lines, "", "Cov mod key:")
		for (f in names(cov_key)) {
			lines = c(lines, sprintf('  (%s)  "%s"', cov_key[[f]], f))
		}
	}
	lines
}

#' Renders `results_table` as an HTML `<table>` for
#' `run_all_inference()`'s `html = TRUE` report, from the exact same shared
#' display (`run_all_inference_build_display_table()`) and row order
#' `run_all_inference_format_pretty_table()` renders as text -- same
#' `estimand` sort, same per-column abbreviations/formatting, same
#' `cov_model` letter key. The visual equivalent of the text renderer's
#' rules: the first row of each new `estimand` group (after the first) gets
#' CSS class `group-start` (a top border, via `table.results
#' tr.group-start td` in `run_all_inference_render_html()`'s `<style>`)
#' mirroring the single `-` rule between groups in the text version; the
#' header/bottom rules are plain CSS on `table.results th`/the table's own
#' border, needing no per-row class. Every cell is HTML-escaped via
#' `htmltools_escape_or_identity()`. Returns `list(table_html, key_html)` --
#' `key_html` is `""` when no `cov_model` letter key was needed, matching
#' the text renderer's "omit the legend entirely" behavior.
#'
#' @param results_table A `run_all_inference()`-shaped results table.
#' @return `list(table_html = <character(1)>, key_html = <character(1)>)`.
#'   `table_html` is a `"(no rows)"` `<p>` and `key_html` is `""` if
#'   `results_table` has zero rows.
#'
#' @keywords internal
#' @noRd
run_all_inference_format_html_table = function(results_table) {
	built = run_all_inference_build_display_table(results_table)
	if (is.null(built)) return(list(table_html = "<p>(no rows)</p>", key_html = ""))
	tbl = built$tbl; display = built$display; cov_key = built$cov_key

	esc = function(x) htmltools_escape_or_identity(as.character(x))
	# Word-wraps a header/cell string onto two lines via `<br>` when it has
	# more than one word (split as evenly as possible), e.g. `"cov mod"` ->
	# `"cov<br>mod"`, `"Mean Diff Pooled Var"` -> `"Mean Δ<br>Pooled Var"` --
	# keeps HTML table columns narrow without truncating any number (numeric
	# cells are always single tokens, so never wrapped) or text (per user
	# request, 2026-08-19: "the wrapping should be so that you can read the
	# first row and see all the numbers -- the text should just wrap").
	wrap_html = function(x) {
		vapply(esc(x), function(s) {
			words = strsplit(s, " ", fixed = TRUE)[[1]]
			if (length(words) < 2L) return(s)
			k = ceiling(length(words) / 2L)
			paste0(paste(words[seq_len(k)], collapse = " "), "<br>", paste(words[(k + 1L):length(words)], collapse = " "))
		}, character(1L), USE.NAMES = FALSE)
	}
	header_html = paste0("<th>", wrap_html(names(display)), "</th>", collapse = "")
	prev_estimand = NULL
	row_html = vapply(seq_len(nrow(display)), function(i) {
		group_start = !is.null(prev_estimand) && !identical(tbl$estimand[[i]], prev_estimand)
		prev_estimand <<- tbl$estimand[[i]]
		cls = paste(c(
			paste0("status-", tbl$status[[i]]),
			if (group_start) "group-start"
		), collapse = " ")
		cells = paste0("<td>", wrap_html(display[i, ]), "</td>", collapse = "")
		sprintf('<tr class="%s">%s</tr>', cls, cells)
	}, character(1L))
	table_html = sprintf(
		'<table class="results">\n<thead><tr>%s</tr></thead>\n<tbody>\n%s\n</tbody>\n</table>',
		header_html, paste(row_html, collapse = "\n")
	)

	key_html = if (length(cov_key) > 0L) {
		items = vapply(names(cov_key), function(f) {
			sprintf("<li>(%s)&nbsp;&nbsp;<code>%s</code></li>", esc(cov_key[[f]]), esc(f))
		}, character(1L), USE.NAMES = FALSE)
		sprintf("<h2>Cov mod key</h2>\n<ul>\n%s\n</ul>", paste(items, collapse = "\n"))
	} else {
		""
	}
	list(table_html = table_html, key_html = key_html)
}

#' @keywords internal
#' @noRd
run_all_inference_estimand_grouped_weights = function(results_table) {
	usable = results_table$status == "ok" & is.finite(results_table$pval)
	w = rep(NA_real_, nrow(results_table))
	if (!any(usable)) return(w)
	estimands = results_table$estimand[usable]
	group_sizes = table(estimands)
	G = length(group_sizes)
	w[usable] = 1 / (G * as.numeric(group_sizes[estimands]))
	w
}

#' Per-row combined-evidence weight under `run_all_inference()`'s
#' user-selectable `combined_evidence_weighting` policy
#' (`inference_suite_inspect.md`'s TODO-15: "the user decides, the package
#' does not silently pick a policy"). A row is `"usable"` -- eligible for a
#' nonzero weight -- when `status == "ok"`, its `pval` is finite, and
#' (when `estimands` is non-`NULL`) its `estimand` is in `estimands`; every
#' non-usable row gets `NA_real_` regardless of policy.
#'
#' - `"estimand_grouped"`: `w_i = 1 / (G * m_i)` -- see
#'   `run_all_inference_estimand_grouped_weights()`'s docs for the formula's
#'   rationale; `G`/`m_i` are computed over the (possibly `estimands`-)
#'   filtered usable set.
#' - `"equal"`: flat `w_i = 1 / k` over the `k` usable rows, no grouping.
#' - `"custom"`: `custom_weights` is a named numeric vector (`inference_class`
#'   name -> weight); a usable row whose class isn't named gets weight `0`.
#'
#' @keywords internal
#' @noRd
run_all_inference_compute_combined_evidence_weights = function(results_table, weighting, estimands = NULL, custom_weights = NULL) {
	usable = results_table$status == "ok" & is.finite(results_table$pval)
	if (!is.null(estimands)) {
		usable = usable & results_table$estimand %in% estimands
	}
	w = rep(NA_real_, nrow(results_table))
	if (!any(usable)) return(w)
	if (identical(weighting, "equal")) {
		w[usable] = 1 / sum(usable)
	} else if (identical(weighting, "estimand_grouped")) {
		est = results_table$estimand[usable]
		group_sizes = table(est)
		G = length(group_sizes)
		w[usable] = 1 / (G * as.numeric(group_sizes[est]))
	} else if (identical(weighting, "custom")) {
		cw = custom_weights[results_table$inference_class[usable]]
		cw[is.na(cw)] = 0
		w[usable] = as.numeric(cw)
	} else {
		stop("run_all_inference_compute_combined_evidence_weights: unknown weighting '", weighting, "'.")
	}
	w
}

#' @keywords internal
#' @noRd
cct_combine_pvalues = function(pvals, weights = NULL) {
	cct_combine_pvalues_full(pvals, weights)$pval
}

#' Same computation as `cct_combine_pvalues()`, additionally returning the
#' raw CCT statistic `T` (before the `0.5 - atan(T)/pi` transform to a
#' p-value) -- `run_all_inference()`'s `combined_evidence$stat` field needs
#' this raw value, not just the final p-value.
#'
#' @keywords internal
#' @noRd
cct_combine_pvalues_full = function(pvals, weights = NULL) {
	pvals = as.numeric(pvals)
	if (is.null(weights)) {
		weights = rep(1 / length(pvals), length(pvals))
	} else {
		weights = as.numeric(weights)
		weights = weights / sum(weights)
	}
	stat = sum(weights * tan((0.5 - pvals) * pi))
	list(pval = 0.5 - atan(stat) / pi, stat = stat)
}

#' Edge-case-hardened wrapper around `cct_combine_pvalues_full()` for
#' `run_all_inference()`'s Combined Evidence Metric
#' (`inference_suite_inspect.md → TODO-17`), wired into
#' `run_all_inference()`'s `combined_evidence` return element (TODO-16):
#'
#' - Drops `NA` p-values (already excluded from `pvals`/`weights` upstream in
#'   the usual case, but tolerated here too).
#' - Fewer than 2 usable p-values after dropping `NA`s: returns
#'   `pval = stat = NA_real_` rather than silently treating a single
#'   p-value as if it were a combined one -- a "combination" of one
#'   p-value is just that p-value, not a meaningful combined-evidence claim.
#' - Clips every usable p-value to `[pval_eps, 1 - pval_eps]` before the
#'   `tan((0.5 - p) * pi)` transform, avoiding the `+-Inf`/degenerate
#'   `atan()` input a p-value of exactly 0 or 1 would otherwise produce.
#'
#' @param pvals Numeric vector of p-values to combine; `NA` entries are
#'   dropped before counting/combining.
#' @param weights Numeric vector the same length as `pvals`, aligned
#'   positionally, or `NULL` for equal weights over the usable p-values.
#'   Need not sum to 1 -- renormalized internally.
#' @param pval_eps Clip p-values to `[pval_eps, 1 - pval_eps]` before
#'   combining. Default `1e-4`.
#' @return `list(pval, stat, n_used)`.
#'
#' @keywords internal
#' @noRd
run_all_inference_combine_pvalues = function(pvals, weights = NULL, pval_eps = 1e-4) {
	pvals = as.numeric(pvals)
	usable = !is.na(pvals)
	n_used = sum(usable)
	if (n_used < 2L) return(list(pval = NA_real_, stat = NA_real_, n_used = n_used))
	pvals = pvals[usable]
	if (!is.null(weights)) weights = as.numeric(weights)[usable]
	pvals = pmin(pmax(pvals, pval_eps), 1 - pval_eps)
	full = cct_combine_pvalues_full(pvals, weights)
	list(pval = full$pval, stat = full$stat, n_used = n_used)
}

#' Formats the one-line Combined Evidence summary
#' `run_all_inference()`'s `screen`/`html` output, and
#' `print.EDIInferenceSuiteResults()`, all print beneath the per-class table
#' (`inference_suite_inspect.md`'s TODO-16 "Output wiring"):
#' `"Combined evidence across G = <n> estimands (k = <n> classes,
#' weighting = <weighting>): p = <value>"`.
#'
#' @keywords internal
#' @noRd
run_all_inference_combined_evidence_summary_line = function(combined_evidence) {
	# Display-only relabeling of the `combined_evidence_weighting` value
	# (per user request, 2026-08-19) -- the argument/return-value string
	# itself stays "estimand_grouped" (unchanged API); only this printed
	# line reads it as prose.
	weighting_disp = switch(combined_evidence$weighting,
		estimand_grouped = "uniform within estimand",
		combined_evidence$weighting
	)
	# Multi-line wording/wrap per user request, 2026-08-20.
	sprintf(
		"Combined evidence against the sharp null across %d estimands\n(%d inferences, weighting = %s):\np = %s",
		combined_evidence$n_estimand_groups, combined_evidence$n_classes_used,
		weighting_disp,
		if (is.na(combined_evidence$pval)) "NA" else formatC(combined_evidence$pval, digits = 3, format = "g")
	)
}

#' Compact per-`estimand` breakdown lines (TODO-16a): one line per distinct
#' `estimand` among usable (`status == "ok"`, finite `pval`, non-`NA`
#' `estimand`) rows, showing that group's own within-group CCT
#' sub-combination p-value (equal weighting within the group -- a
#' generically meaningful summary regardless of the overall
#' `combined_evidence_weighting` policy actually in effect). Printed
#' immediately above the overall Combined Evidence summary line
#' (`run_all_inference_combined_evidence_summary_line()`) in `screen`
#' output and `print.EDIInferenceSuiteResults()`, so a reader sees "here's
#' what each estimand group says" before "here's the one number combining
#' all of them." Rows print in the same sorted `estimand` order as
#' `results_table` (TODO-16a).
#'
#' @param results_table A `run_all_inference()`-shaped results table
#'   (post-TODO-16a sort, though this function does not depend on that).
#' @return A character vector, one line per `estimand` group; empty if no
#'   row is usable.
#'
#' @keywords internal
#' @noRd
run_all_inference_per_estimand_breakdown_lines = function(results_table) {
	usable = results_table$status == "ok" & is.finite(results_table$pval) & !is.na(results_table$estimand)
	if (!any(usable)) return(character(0))
	est = results_table$estimand[usable]
	pv = results_table$pval[usable]
	groups = split(pv, est)
	vapply(names(groups), function(g) {
		combined = run_all_inference_combine_pvalues(groups[[g]])
		p_str = if (is.na(combined$pval)) "NA" else formatC(combined$pval, digits = 3, format = "g")
		# Same abbreviated form as the main table's `estimand` column
		# (per user request, 2026-08-19) -- `names(groups)` is still the
		# raw registry `estimand` string (needed for `split()`/lookup), so
		# abbreviate only for display here, not for the grouping itself.
		sprintf("  %s (%d inferences): p = %s", estimand_short_label(g), length(groups[[g]]), p_str)
	}, character(1L), USE.NAMES = FALSE)
}


#' Inference Suite: Discover and Bundle Every Applicable Inference Class for a Design
#'
#' A lightweight coordinator (not itself an \code{Inference} subclass, and not
#' part of the \code{Inference} R6 hierarchy) that pairs a single completed
#' \code{\link[EDI:Design]{Design}} object with the full set of concrete
#' \code{Inference} classes compatible with it. On construction, the suite
#' consults package-level inference metadata to discover every exported,
#' non-abstract \code{Inference} subclass whose declared response-type,
#' matched-design (KK), blocking, and censoring requirements are all satisfied
#' by \code{des_obj}, storing the resulting sorted class-name vector in
#' \code{applicable_design_classes}. Because discovery is driven by metadata
#' lookups rather than by actually attempting to construct each candidate
#' class, the applicable list automatically stays current as new inference
#' classes are registered elsewhere in the package, without this class needing
#' any changes, and without risking side effects (e.g. an optional-package
#' load failure inside some class's constructor) from a doomed construction
#' attempt.
#'
#' @details \strong{Compatibility rules} (see
#'   \code{is_inference_class_compatible_with_design_metadata()}, also used by
#'   \code{\link[EDI:Design]{Design}}'s own
#'   \code{applicable_inference_class_names()}): a candidate class is
#'   excluded if it is abstract or not exported; if it declares no compatible
#'   response types, or none match \code{des_obj}'s response type; if its name
#'   contains \code{"KK"} (a matched-design-only class) but \code{des_obj} does
#'   not support KK matching; if the class's \code{requires_blocking_design()}
#'   is \code{TRUE} (currently only \code{InferenceIncidExtendedRobins} --
#'   \code{InferenceIncidCMH} works on both blocking and non-blocking designs
#'   via different standard-error estimators, so it is \strong{not} excluded)
#'   but \code{des_obj} does not support blocking; or if \code{des_obj} has any
#'   left-/interval-censored subjects (a finite \code{y_R}) but the class's
#'   \code{supports_interval_or_left_censored_data()} is \code{FALSE} --
#'   both of the latter two mirror \code{Inference$initialize()}'s own
#'   construction-time gate exactly, via each class's registered
#'   \code{requires_blocking_design}/\code{supports_general_censoring}
#'   metadata (see \code{infer_inference_requires_blocking_design()}/
#'   \code{infer_inference_supports_general_censoring()} in
#'   \code{inference_class_registry.R}). Ordinary right-censoring alone never
#'   excludes a class. The KK-name-pattern rule is still hardcoded in this
#'   class rather than looked up from a central registry.
#'
#'   A class that is design-compatible but whose registered
#'   \code{required_packages} are not all installed is excluded from
#'   \code{applicable_design_classes} and reported separately, by class name,
#'   in \code{unavailable_due_to_missing_packages} -- so callers can tell "not
#'   applicable to this design" apart from "applicable, but an optional
#'   dependency isn't installed" (see the \code{Discovery} section of
#'   \code{fix_inference_hierarchy.md}). Package availability is never a
#'   reason a class is treated as design-incompatible.
#'
#'   Construction itself does not compute any estimates, p-values, or
#'   confidence intervals -- it only discovers and validates which inference
#'   classes are applicable and does not eagerly construct any of them. This
#'   class's \code{run_all_inference()} method does that: it constructs and
#'   fits every applicable class and returns a uniform
#'   comparison across them (see that method's own documentation for the
#'   output schema, the CI/p-value method selection policy, and the
#'   \code{screen}/\code{html}/\code{plots}/\code{pdf}/
#'   \code{save_results_as_JSON} output options). \code{lock_objects = FALSE}
#'   allows ad hoc fields to be attached to an instance after construction.
#'
#'   \strong{Every row this class discovers and fits is a test about the
#'   same outcome variable, by construction.} \code{response_type} is a
#'   required, immutable constructor argument on \code{\link[EDI:Design]{Design}}
#'   (read-only thereafter via \code{get_response_type()}), and this class
#'   discovers every candidate in \code{applicable_design_classes} from one
#'   attached \code{Design} object's one \code{response_type} -- there is no
#'   code path here that spans two response types in a single instance. This
#'   matters beyond bookkeeping: a planned comparison-across-classes feature
#'   (a single combined-evidence p-value summarizing every row, via a
#'   dependence-robust combination test) relies on every combined class
#'   sharing one sharp null of "no treatment effect on this outcome" --
#'   which only holds when every test concerns the same outcome variable
#'   (combining, say, a survival model's p-value with an unrelated
#'   continuous-outcome model's p-value would not be valid, since a real
#'   effect on one with none on the other is entirely plausible). That
#'   precondition is guaranteed here structurally, not by caller discipline.
#'
#' \strong{Combined Evidence interpretation caveat (read before using
#' \code{combined_evidence$pval}):} the Cauchy combination test is a
#' union-intersection test of \eqn{H_0: \theta_1 = 0 \cap \theta_2 = 0 \cap
#' \dots \cap \theta_k = 0} against the alternative that \strong{at least
#' one} \eqn{\theta_i \neq 0}. A significant \code{combined_evidence$pval}
#' is therefore \strong{evidence of an effect in at least one of these
#' senses, not evidence for a specific estimate or direction} -- it does
#' not say which class's estimand is nonzero, nor does a small combined
#' p-value imply every (or even most) constituent p-values were small. Do
#' not report \code{combined_evidence$pval} as if it estimated a single
#' effect size, and do not treat it as validating any one class's estimate
#' over another's; its only valid use is as evidence that *some* legitimate
#' way of looking for a treatment effect on this outcome found one.
#'
#' This same-\code{Y} precondition is guaranteed \emph{within} one
#' \code{InferenceSuite} instance structurally (one \code{Design}, one
#' \code{response_type}), but the architecture cannot stop a caller from
#' manually combining raw \code{pval}s pulled from two separate
#' \code{InferenceSuite} objects' \code{results_table}s outside
#' \code{cct_combine_pvalues()} -- doing so is outside this function's
#' validity guarantee and is not a supported use of this metric.
#' @references Madigan, D., Ryan, P. B., and Schuemie, M. (2013), "Does
#'   design matter? Systematic evaluation of the impact of analytical
#'   choices on effect estimates in observational studies," \emph{Therapeutic
#'   Advances in Drug Safety}, 4(2), 53-62, PMID 25083251 -- the motivating
#'   finding behind this class's "every legitimate way to look for an
#'   effect, compared honestly" default output.
#'
#'   Liu, Y. and Xie, J. (2020), "Cauchy combination test: a powerful test
#'   with analytic p-value calculation under arbitrary dependency
#'   structures," \emph{Journal of the American Statistical Association},
#'   115(529), 393-402 -- \code{run_all_inference()}'s Combined Evidence
#'   Metric.
#' @export
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 20, response_type = "continuous")
#' for (i in 1:20) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rnorm(20))
#'
#' suite = InferenceSuite$new(seq_des)
#' suite$applicable_design_classes
#'
#' # Fit and compare every applicable class:
#' results = suite$run_all_inference(screen = TRUE)
#' results$results_table
#' }
InferenceSuite = R6::R6Class("InferenceSuite",
	lock_objects = FALSE,
	public = list(
		#' @field applicable_design_classes Character vector of applicable inference
		#'   class names derived during initialization.
		applicable_design_classes = NULL,
		#' @field unavailable_due_to_missing_packages A named list, one entry per
		#'   otherwise-design-compatible class whose registered \code{required_packages}
		#'   are not all installed: names are class names, values are the character
		#'   vector of missing package names. These classes are excluded from
		#'   \code{applicable_design_classes} but are reported here separately from
		#'   plain design/response-type incompatibility (see the class-level docs'
		#'   "Discovery" rules), so callers can distinguish "not applicable to this
		#'   design" from "applicable, but an optional dependency isn't installed."
		#'   Empty named list if every design-compatible class has all required
		#'   packages available.
		unavailable_due_to_missing_packages = NULL,
		#' @description Discover every \code{Inference} class applicable to \code{des_obj}
		#'   (see the class-level documentation for the compatibility rules) and validate
		#'   any per-class constructor overrides in \code{inference_params}, storing
		#'   \code{applicable_design_classes} for later use. This constructor does
		#'   \strong{not} instantiate any \code{Inference} object itself; callers are
		#'   expected to construct the specific classes they need (optionally passing the
		#'   validated \code{inference_params}) from the discovered list.
		#' @param des_obj A completed \code{\link[EDI:Design]{Design}} object (validated via
		#'   \code{\link[methods]{is}(des_obj, "Design")} when assertions are enabled; see
		#'   \code{\link{toggle_asserts}}).
		#' @param inference_params A named list of lists supplying additional
		#'   constructor arguments for specific inference classes.  Each name
		#'   must be the name of a concrete \code{Inference} subclass that is applicable
		#'   to \code{des_obj} (checked against \code{applicable_design_classes} once
		#'   discovered — an inapplicable class name raises an error); the
		#'   corresponding list contains keyword arguments (beyond
		#'   \code{des_obj}) forwarded to that class's \code{initialize}, and every
		#'   argument name supplied must match a formal parameter of that class's
		#'   \code{initialize} method (other than \code{des_obj} and \code{...}) or an
		#'   error is raised naming the unknown argument(s) and the valid ones.
		#'   Defaults to an empty list (no extra arguments for any class).
		#' @param model_formula Accepted for interface/future-extension purposes but
		#'   currently \strong{not used anywhere in this method's body} — supplying a
		#'   non-\code{NULL} value has no effect on discovery, validation, or any stored
		#'   state. Do not rely on this parameter to affect covariate adjustment; a
		#'   design's own model formula and design matrix are what individual
		#'   \code{Inference} classes actually consult when later constructed from this
		#'   suite's discovered class list.
		initialize = function(des_obj, model_formula = NULL, inference_params = list()) {
			if (should_run_asserts()) {
				assertClass(des_obj, "Design")
				assertList(inference_params, names = "unique")
			}
			# ── 1. Discover applicable classes ────────────────────────────────
			self$applicable_design_classes = des_obj$applicable_inference_class_names()
			self$unavailable_due_to_missing_packages = des_obj$unavailable_inference_classes_due_to_missing_packages()
			# ── 2. Validate inference_params ──────────────────────────────────
			for (cls_name in names(inference_params)) {
				# Must be applicable for this design
				if (should_run_asserts()) {
					if (!(cls_name %in% self$applicable_design_classes)) {
						stop(sprintf(
							"InferenceSuite: '%s' is not applicable for this design/response_type combination.",
							cls_name))
					}
				}
				# All supplied param names must be formals of initialize
				params = inference_params[[cls_name]]
				if (should_run_asserts()) {
					if (!is.list(params)) {
						stop(sprintf(
							"InferenceSuite: params for '%s' must be a list.", cls_name))
					}
					if (length(params) > 0L) {
						cls        = get(cls_name, envir = getNamespace("EDI"))
						init_fn    = cls$public_methods$initialize
						valid_args = setdiff(names(formals(init_fn)), c("des_obj", "..."))
						unknown    = setdiff(names(params), valid_args)
						if (length(unknown) > 0L) {
							stop(sprintf(
								"InferenceSuite: unknown argument(s) for '%s': %s\n  Valid: %s",
								cls_name,
								paste(unknown,    collapse = ", "),
								paste(valid_args, collapse = ", ")))
						}
					}
				}
			}
			private$des_obj          = des_obj
			private$inference_params = inference_params
		},
		#' @description Construct and fit every class in \code{applicable_design_classes},
		#'   and report one uniform comparison row per class -- estimate, SE, CI, p-value
		#'   (each via the highest-priority available method; see
		#'   \code{inference_suite_inspect.md}'s "Method Selection Policy"), likelihood
		#'   tier, estimand (where declared), fit time, captured warnings, and status.
		#'   Unlike the constructor, this method fits models and is not free; call it
		#'   explicitly when you want the comparison, not automatically.
		#'
		#'   A single class's construction or fit failure never aborts the report -- it
		#'   is caught and recorded as that class's \code{status}/\code{message} (see
		#'   "Per-Class Failure Isolation" in the design doc).
		#'
		#'   \strong{Side effects (v1.0.0 slice):} \code{screen} prints each row as its
		#'   class finishes fitting (computation order), not buffered to the end, with a
		#'   percent-done/estimated-time-remaining progress bar line underneath each row
		#'   (the ETA is the mean per-class elapsed time so far times classes remaining),
		#'   followed by a footer listing classes excluded for missing optional packages.
		#'   \code{html = TRUE} writes a self-contained, timestamped HTML report (the
		#'   same table plus the same footer) to the \strong{current working directory}
		#'   and opens it via \code{\link[utils]{browseURL}}; it requires the
		#'   \pkg{knitr} package. The \code{plots} ggplot2 visualizations, and their
		#'   embedding into this HTML report, are not yet implemented
		#'   (\code{inference_suite_inspect.md} TODO-7); \code{pdf} output is not yet a
		#'   parameter of this method.
		#' @param screen Print results to the console as each class finishes. At least
		#'   one of \code{screen}/\code{html} must be \code{TRUE}.
		#' @param html Render, save (current working directory, timestamped filename),
		#'   and auto-open a self-contained HTML report of the results.
		#' @param alpha Significance level: confidence intervals are computed at
		#'   \code{1 - alpha} and \code{alpha} is the significance threshold used
		#'   anywhere the report flags significance. Default \code{0.05}.
		#' @param save_results_as_JSON If \code{TRUE}, serialize the return object
		#'   (excluding plot objects) to a timestamped JSON file in the current working
		#'   directory. Requires the optional \pkg{jsonlite} package; if it is not
		#'   installed, a \code{warning()} is issued and this artifact is skipped rather
		#'   than erroring. Default \code{FALSE}.
		#' @param plots If \code{TRUE}, build and display (on the current graphics
		#'   device) two \pkg{ggplot2} visualizations: an estimate number line
		#'   (class/method labels above each point at 45 degrees, a box-and-whisker
		#'   summary underneath) and an annotated confidence-interval forest plot
		#'   (p-value left of each interval, interval width right of it, class/method
		#'   labeled underneath, color-keyed to significance at \code{alpha}). Requires
		#'   the optional \pkg{ggplot2} package; if it is not installed, a
		#'   \code{warning()} is issued and plotting is skipped rather than erroring.
		#'   Defaults to the value of \code{screen}.
		#' @param pdf If \code{TRUE}, save both visualizations to one timestamped,
		#'   two-page PDF file in the current working directory (page height scales
		#'   with the number of classes in the CI forest plot). Same \pkg{ggplot2}
		#'   dependency and missing-package handling as \code{plots}. Default
		#'   \code{FALSE}.
		#' @param classes Optional character vector restricting which applicable
		#'   classes to fit -- e.g. re-running against only the few classes a user is
		#'   actually deciding between, without reconstructing the suite. Every name
		#'   must already be in \code{applicable_design_classes} or this errors,
		#'   naming the unknown name(s) and the valid ones. \code{NULL} (default)
		#'   fits every applicable class.
		#' @param exclude_classes Optional character vector of applicable classes to
		#'   skip, applied after \code{classes}. Same validation as \code{classes}.
		#'   Default none.
		#' @param max_secs_per_class Optional per-class elapsed-time limit in seconds
		#'   (via \code{\link{setTimeLimit}}), after which that class's row gets
		#'   \code{status = "timeout"} instead of hanging the whole report. Protects
		#'   against one pathological class (e.g. a bootstrap/randomization method
		#'   with many replicates) blocking every other class. \strong{Known
		#'   limitation:} R's time limits are checked at R-level interrupt points, so
		#'   this reliably cuts off slow R-level work but is not guaranteed to
		#'   interrupt one very slow single native (C/C++/BLAS) call with no
		#'   intervening R-level check. \code{NULL} (default) means no limit.
		#' @param num_cores If greater than \code{1}, fit classes in parallel across
		#'   this many forked workers (\code{\link[parallel]{makeForkCluster}}) --
		#'   Unix/Linux only; on other platforms this falls back to sequential
		#'   (\code{num_cores = 1}) with a \code{warning()}. \strong{Screen output
		#'   changes under parallel execution:} fitting is a single blocking call
		#'   that only returns once every worker has finished, so there is no
		#'   meaningful per-class ETA to show while running -- \code{screen = TRUE}
		#'   instead prints a "fitting N classes across K workers" message up front,
		#'   then every result row together once complete, then a total-elapsed-time
		#'   summary line (a deliberate design choice, not a degraded default -- see
		#'   \code{inference_suite_inspect.md}'s TODO-13). Default \code{1L}
		#'   (sequential, with the normal incremental streaming/progress bar).
		#' @param formulas \code{NULL} (default), a single formula (\code{~ .}), a
		#'   single formula string (\code{"~ ."}), or a collection of either --
		#'   including \code{c(~ 1, ~ .)}, which base R already returns as a plain
		#'   \code{list} of \code{formula} objects (formulas have no \code{c()}
		#'   method of their own), or a character vector
		#'   (\code{c("~ .", "~ age + sex * smoking")}). \code{NULL}
		#'   means each class fits once with its own default formula -- identical
		#'   to omitting this argument entirely, since \code{model_formula = NULL}
		#'   at construction already resolves to \code{des_obj$get_design_formula()}
		#'   (default \code{~ .}). When non-\code{NULL}, only classes whose
		#'   constructor \strong{syntactically} accepts a \code{model_formula}
		#'   argument are fit once per formula in \code{formulas} (one
		#'   \code{results_table} row each, disambiguated in \code{results} by
		#'   \code{"<class>[<formula>]"} names); classes without a
		#'   \code{model_formula} constructor argument at all still fit exactly
		#'   once, ignoring \code{formulas}. Note this is a syntactic check
		#'   (does the constructor accept one), not a semantic one (does the fit
		#'   actually use it) -- some classes accept-and-ignore \code{model_formula}
		#'   (e.g. \code{InferenceAllSimpleMeanDiff}'s unadjusted Welch's t-test);
		#'   see \code{fix_inference_hierarchy.md}'s
		#'   \code{adjusts_for_covariates} registry-metadata audit, which makes
		#'   the \code{cov_model} column semantics-aware wherever that audit has
		#'   landed.
		#' @param methods \code{NULL} (default), a character vector of method
		#'   sentinel strings, or (TODO-22) a named list \code{sentinel ->
		#'   character vector of requested \code{type} values, or \code{NULL}}
		#'   restricting which inference method(s) -- and, for the three
		#'   resampling sentinels marked "typed" below, which resampling/CI-
		#'   construction \code{type} flavor(s) -- get fit and reported per
		#'   class. \code{NULL} means \strong{every} sentinel in
		#'   \code{EDI_INFERENCE_SUITE_METHOD_SENTINELS}, and for each typed
		#'   sentinel, \strong{every} \code{type} value that class supports
		#'   (queried at runtime via its own \code{get_supported_bootstrap_
		#'   {pval,ci}_types()} / \code{get_supported_bayesian_bootstrap_
		#'   {pval,ci}_types()} / \code{get_supported_rand_bootstrap_
		#'   {pval,ci}_types()} accessor -- never a hardcoded type table in this
		#'   package) -- i.e. truly all possible methods and all their
		#'   resampling flavors, not a single "best available" pick (per user
		#'   request, 2026-08-19, replacing the earlier design where each class
		#'   contributed exactly one row via a fixed wald-first cascade).
		#'   List-shaped example: \code{methods = list(bootstrap = c("percentile",
		#'   "bca"), rand_bootstrap = NULL)} fits only \code{"bootstrap"}
		#'   (restricted to the \code{"percentile"}/\code{"bca"} types that class
		#'   actually supports) and \code{"rand_bootstrap"} (every type that
		#'   class supports); a sentinel present as a list name with value
		#'   \code{NULL} still means "every valid type" for it, exactly like the
		#'   flat-vector shape -- to \emph{not} fit a sentinel at all, simply
		#'   don't name it. Requesting a \code{type} for a sentinel with no
		#'   \code{type} axis (any sentinel not marked "typed" below) errors.
		#'   Valid sentinels, each corresponding to one asymptotic/exact/
		#'   randomization/resampling inference family a class may (or may not)
		#'   implement:
		#'   \describe{
		#'     \item{\code{"wald"}}{Asymptotic Wald inference --
		#'       \code{compute_asymp_confidence_interval()}/
		#'       \code{compute_asymp_two_sided_pval()} (capability
		#'       \code{"wald"}). The standard closed-form normal-approximation
		#'       CI/test.}
		#'     \item{\code{"exact"}}{Exact inference --
		#'       \code{compute_exact_confidence_interval()}/
		#'       \code{compute_exact_two_sided_pval_for_treatment_effect()}
		#'       (capability \code{"exact_test"}). Finite-sample-exact methods
		#'       (e.g. Fisher's exact test, exact binomial).}
		#'     \item{\code{"rand"}}{Randomization inference --
		#'       \code{compute_rand_confidence_interval()}/
		#'       \code{compute_rand_two_sided_pval()} (capabilities
		#'       \code{"randomization_ci"}/\code{"randomization_test"} --
		#'       distinct capability names for the CI vs. p-value side, since a
		#'       class can support one without the other). Design-based
		#'       inference via re-randomizing the observed treatment
		#'       assignment.}
		#'     \item{\code{"rand_bootstrap"} (typed)}{Randomization-bootstrap
		#'       inference -- \code{compute_rand_bootstrap_confidence_interval()}/
		#'       \code{compute_rand_bootstrap_two_sided_pval()} (capabilities
		#'       \code{"randomization_bootstrap_ci"}/\code{"randomization_bootstrap"} --
		#'       distinct capability names for the CI vs. p-value side, since a
		#'       class can support one without the other). Resamples under the
		#'       randomization null rather than the usual iid-resampling
		#'       bootstrap. \code{type} (both sides agree on the same four
		#'       values, unlike \code{"bootstrap"}/\code{"bayes_boot"} below):
		#'       \code{"percentile"}, \code{"studentized"},
		#'       \code{"symmetric-percentile-t"}, \code{"smoothed"}.}
		#'     \item{\code{"jackknife"}}{Jackknife-Wald inference --
		#'       \code{compute_jackknife_wald_confidence_interval()}/
		#'       \code{compute_jackknife_wald_two_sided_pval()} (capability
		#'       \code{"jackknife"}). Leave-one-out variance estimate feeding a
		#'       Wald-style CI/test.}
		#'     \item{\code{"score"}}{Score (Rao) test -- \code{compute_score_confidence_interval()}/
		#'       \code{compute_score_two_sided_pval()} (capability
		#'       \code{"likelihood_tests"}, one of its three independent
		#'       sub-procedures).}
		#'     \item{\code{"lik_ratio"}}{Likelihood-ratio test --
		#'       \code{compute_lik_ratio_confidence_interval()}/
		#'       \code{compute_lik_ratio_two_sided_pval()} (capability
		#'       \code{"likelihood_tests"}).}
		#'     \item{\code{"gradient"}}{Gradient test --
		#'       \code{compute_gradient_confidence_interval()}/
		#'       \code{compute_gradient_two_sided_pval()} (capability
		#'       \code{"likelihood_tests"}).}
		#'     (The plain, "best available" auto-selecting
		#'     \code{compute_lik_ratio_bartlett_two_sided_pval()}/
		#'     \code{compute_lik_ratio_bartlett_confidence_interval()}
		#'     dispatcher is deliberately not its own sentinel -- it only picks
		#'     between the two explicit variants below depending on which this
		#'     class implements, so it is never a distinct inference procedure.)
		#'     \item{\code{"lik_ratio_bartlett_approx"}}{Bartlett-corrected
		#'       likelihood-ratio test, Monte-Carlo-approximated correction factor
		#'       pinned explicitly (for reproducibility) --
		#'       \code{compute_lik_ratio_bartlett_approx_confidence_interval()}/
		#'       \code{compute_lik_ratio_bartlett_approx_two_sided_pval()}
		#'       (capability \code{"likelihood_tests"}; degrades to \code{NA} for
		#'       classes without an approximate Bartlett factor).}
		#'     \item{\code{"lik_ratio_bartlett_exact"}}{Bartlett-corrected
		#'       likelihood-ratio test, closed-form analytic correction factor
		#'       pinned explicitly -- \code{compute_lik_ratio_bartlett_exact_confidence_interval()}/
		#'       \code{compute_lik_ratio_bartlett_exact_two_sided_pval()}
		#'       (capability \code{"likelihood_tests"}; degrades to \code{NA} for
		#'       classes without an exact Bartlett factor).}
		#'     \item{\code{"param_boot"}}{Bootstrap-calibrated likelihood-ratio
		#'       test -- \code{compute_lik_ratio_bootstrap_confidence_interval()}/
		#'       \code{compute_lik_ratio_bootstrap_two_sided_pval()} (capability
		#'       \code{"parametric_likelihood_bootstrap"}).}
		#'     \item{\code{"param_boot_direct"}}{Direct parametric-bootstrap
		#'       estimate/CI/pval for the treatment coefficient itself --
		#'       \code{compute_param_bootstrap_confidence_interval()}/
		#'       \code{compute_param_bootstrap_pval()} (capability
		#'       \code{"parametric_likelihood_bootstrap"}; distinct from
		#'       \code{"param_boot"} above, which is a bootstrap-calibrated
		#'       likelihood-ratio \emph{test}, not a direct estimate).}
		#'     \item{\code{"bayes_boot"} (typed)}{Bayesian bootstrap inference --
		#'       \code{compute_bayesian_bootstrap_confidence_interval()}/
		#'       \code{compute_bayesian_bootstrap_two_sided_pval()} (capability
		#'       \code{"bayesian_bootstrap"}). CI-side \code{type}:
		#'       \code{"percentile"}, \code{"basic"}, \code{"wald"},
		#'       \code{"studentized"}, \code{"bootstrap-t"}, \code{"bca"};
		#'       pval-side \code{type} swaps \code{"basic"} for
		#'       \code{"symmetric"} (all others the same).}
		#'     \item{\code{"bootstrap"} (typed)}{Nonparametric bootstrap
		#'       inference -- \code{compute_bootstrap_confidence_interval()}/
		#'       \code{compute_bootstrap_two_sided_pval()} (capability
		#'       \code{"nonparametric_bootstrap"}). CI-side \code{type}:
		#'       \code{"percentile"}, \code{"basic"}, \code{"studentized"},
		#'       \code{"bootstrap-t"}, \code{"symmetric-percentile-t"},
		#'       \code{"bca"}, \code{"prepivoted"}, \code{"double-bootstrap"},
		#'       \code{"calibrated"}, \code{"smoothed"}; pval-side \code{type}
		#'       is a smaller set -- \code{"percentile"}, \code{"symmetric"},
		#'       \code{"studentized"}, \code{"bootstrap-t"}, \code{"bca"} --
		#'       neither \code{"basic"} nor the other CI-only variants apply on
		#'       the pval side.}
		#'   }
		#'   For the three "typed" sentinels above, an exhaustive \code{type}
		#'   list is documented here for orientation only -- the actual set
		#'   consulted at runtime always comes from that class's own accessor
		#'   (see the top of this section), so a class need not support every
		#'   value listed.
		#'   (\code{"likelihood_ratio"}/\code{"estimating_equation_likelihood_ratio"}
		#'   are deliberately not separate sentinels -- both capabilities gate
		#'   the exact same method pair \code{"lik_ratio"} above already covers.)
		#'   For each class, only sentinels the class has \emph{any} CI or
		#'   p-value capability for (among the requested \code{methods}) get a
		#'   row; for a typed sentinel, one row per \code{type} that class
		#'   actually supports (intersected with any requested type subset) --
		#'   a class with zero applicable sentinels, or a typed sentinel with
		#'   zero resulting types, still gets exactly one row with
		#'   \code{method}/\code{type = NA_character_} (mirrors the
		#'   pre-\code{methods} "no capability" row) rather than being silently
		#'   dropped. A class contributing more than one applicable-sentinel row
		#'   is disambiguated in \code{results}/\code{results_table} by
		#'   \code{"<class>{<method>}"} or \code{"<class>{<method>:<type>}"}
		#'   (or with a \code{"[<formula>]"} tag too under simultaneous
		#'   \code{formulas} fan-out) names. Unlike the removed cascade,
		#'   \code{ci_method}/\code{pval_method} on a given row now always
		#'   match that row's own \code{method} (or are \code{NA} if this class
		#'   lacks that half of the sentinel's capability, \strong{including}
		#'   when \code{type} is valid on one side but not the other) --
		#'   there is no fallback to a different sentinel within one row.
		#' @param basic_bootstrap \code{FALSE} (default). Convenience flag: when
		#'   \code{TRUE}, restricts every typed sentinel (\code{"bootstrap"}/
		#'   \code{"bayes_boot"}/\code{"rand_bootstrap"}) to just that class's
		#'   first (i.e. default) \code{type} value instead of fitting every
		#'   \code{type} it supports -- "just run the default bootstrap flavor
		#'   for nonparametric/Bayesian/randomization resampling" without
		#'   having to spell out \code{methods = list(bootstrap = ..., bayes_boot
		#'   = ..., rand_bootstrap = ...)} by hand. Only takes effect for a
		#'   typed sentinel the caller didn't already restrict via an explicit
		#'   \code{methods} list entry -- an explicit \code{type} request there
		#'   always wins over this flag. No effect on non-typed sentinels
		#'   (\code{"param_boot"}/\code{"param_boot_direct"} included -- neither
		#'   has a \code{type} axis, so they already run their one procedure).
		#' @param combined_evidence_estimands \code{NULL} (default: include every
		#'   declared \code{estimand}), or a character vector of \code{estimand}
		#'   values to restrict the Combined Evidence p-value/weights to.
		#'   Validated argument-time against the \code{estimand} values actually
		#'   declared among \code{classes}/\code{exclude_classes}-filtered
		#'   candidates.
		#' @param combined_evidence_weighting One of \code{"estimand_grouped"}
		#'   (default -- \code{w_i = 1 / (G * m_i)}), \code{"equal"} (flat
		#'   \code{w_i = 1/k}), or \code{"custom"} (caller supplies
		#'   \code{combined_evidence_weights}). See
		#'   \code{inference_suite_inspect.md}'s TODO-15.
		#' @param combined_evidence_weights Named numeric vector
		#'   (\code{inference_class} name -> weight), required when and only
		#'   when \code{combined_evidence_weighting = "custom"}. Names must be a
		#'   subset of the classes being fit; an unnamed usable class defaults to
		#'   weight \code{0} (excluded). Need not pre-sum to 1.
		#' @return Invisibly, an object of class \code{c("EDIInferenceSuiteResults", "list")}
		#'   with elements \code{results} (one named sub-list per class, in computation
		#'   order), \code{results_table} (the same rows as a flat \code{data.frame},
		#'   sorted/grouped by \code{estimand} -- \code{NA_character_} last -- with a
		#'   secondary sort by \code{inference_class}; includes the \code{weight}
		#'   column driven by \code{combined_evidence_weighting}/
		#'   \code{combined_evidence_estimands}), \code{combined_evidence}
		#'   (\code{list(pval, stat, method = "cauchy_combination", n_classes_used,
		#'   n_estimand_groups, estimands_used, weighting, weights_used,
		#'   classes_used)} -- the Cauchy-combination-test p-value/statistic
		#'   across all usable rows under the resolved weighting policy;
		#'   \code{weights_used}/\code{classes_used} are keyed/valued by each
		#'   row's \code{results} name, not \code{results_table$inference_class}
		#'   directly, since that column can repeat under \code{formulas};
		#'   \code{pval = stat = NA_real_} if fewer than 2 rows are usable),
		#'   \code{design}, \code{alpha}, \code{unavailable_due_to_missing_packages},
		#'   \code{plots} (\code{list(estimates, ci_forest)}; each of those is itself a
		#'   named list of one \code{ggplot} object per \code{estimand} -- possibly
		#'   empty -- rather than a single plot, since each visualization is now
		#'   split one-per-estimand, per user request, 2026-08-19),
		#'   \code{files} (\code{list(html, pdf, json)}; \code{html}/\code{json} are
		#'   each a path or \code{NULL}, \code{pdf} is itself
		#'   \code{list(estimates, ci_forest)} of two paths (or \code{NULL}s) --
		#'   \strong{two separate PDF files}, one per visualization, each a
		#'   multi-page PDF with one page per estimand), \code{timestamp},
		#'   \code{total_secs}, and \code{edi_version}.
		run_all_inference = function(screen = TRUE, html = FALSE, alpha = 0.05, save_results_as_JSON = FALSE, plots = screen, pdf = FALSE,
				classes = NULL, exclude_classes = character(), max_secs_per_class = NULL, num_cores = 1L, formulas = NULL,
				methods = NULL, basic_bootstrap = FALSE,
				combined_evidence_estimands = NULL,
				combined_evidence_weighting = c("estimand_grouped", "equal", "custom"),
				combined_evidence_weights = NULL) {
			if (should_run_asserts()) {
				assertFlag(screen)
				assertFlag(html)
				assertNumber(alpha, lower = 0, upper = 1)
				assertFlag(save_results_as_JSON)
				assertFlag(plots)
				assertFlag(pdf)
				assertFlag(basic_bootstrap)
				assertCharacter(classes, null.ok = TRUE)
				assertCharacter(exclude_classes)
				assertNumber(max_secs_per_class, lower = 0, null.ok = TRUE)
				assertCount(num_cores, positive = TRUE)
				if (!is.null(formulas)) {
					formulas_check = if (inherits(formulas, "formula")) list(formulas) else as.list(formulas)
					if (length(formulas_check) == 0L) {
						stop("InferenceSuite$run_all_inference: `formulas` must have at least one element if not NULL.")
					}
					for (f in formulas_check) {
						if (!inherits(f, "formula") && !(is.character(f) && length(f) == 1L && !is.na(f))) {
							stop(
								"InferenceSuite$run_all_inference: every element of `formulas` must be a formula ",
								"object or a single formula string, e.g. formulas = c(~ 1, ~ .) or ",
								"formulas = c(\"~ 1\", \"~ .\")."
							)
						}
					}
				}
				# TODO-22: `methods` accepts either the legacy flat character
				# vector of sentinels, or a named list `sentinel -> character
				# vector of requested type values (or NULL)` for the three typed
				# sentinels -- see run_all_inference_normalize_methods()'s docs.
				if (!is.null(methods) && !is.list(methods)) {
					assertCharacter(methods, min.len = 1L, any.missing = FALSE, unique = TRUE)
				} else if (is.list(methods)) {
					assertList(methods, names = "unique")
					if (length(methods) == 0L || any(names(methods) == "")) {
						stop(
							"InferenceSuite$run_all_inference: a list-valued `methods` must have ",
							"every element named by the sentinel it requests, e.g. ",
							"methods = list(bootstrap = c(\"percentile\", \"bca\"), rand_bootstrap = NULL)."
						)
					}
					for (s in names(methods)) {
						if (!is.null(methods[[s]])) assertCharacter(methods[[s]], min.len = 1L, any.missing = FALSE, unique = TRUE)
						if (!is.null(methods[[s]]) && !(s %in% EDI_INFERENCE_SUITE_TYPED_SENTINELS)) {
							stop(sprintf(
								"InferenceSuite$run_all_inference: `methods` requests type value(s) for sentinel '%s', which has no `type` axis -- only %s do. Use `methods = list(%s = NULL)` (or omit `type`) to request '%s' with no type restriction.",
								s, paste(EDI_INFERENCE_SUITE_TYPED_SENTINELS, collapse = "/"), s, s
							))
						}
					}
				}
				unknown_m = setdiff(run_all_inference_normalize_methods(methods)$sentinels, EDI_INFERENCE_SUITE_METHOD_SENTINELS)
				if (length(unknown_m) > 0L) {
					stop(sprintf(
						"InferenceSuite$run_all_inference: unknown `methods` value(s): %s\n  Valid sentinels: %s",
						paste(unknown_m, collapse = ", "), paste(EDI_INFERENCE_SUITE_METHOD_SENTINELS, collapse = ", ")
					))
				}
				assertCharacter(combined_evidence_estimands, min.len = 1L, any.missing = FALSE, null.ok = TRUE)
			}
			methods_norm = run_all_inference_normalize_methods(methods)
			methods = methods_norm$sentinels
			type_requests = methods_norm$type_requests
			combined_evidence_weighting = match.arg(combined_evidence_weighting, c("estimand_grouped", "equal", "custom"))
			formulas = run_all_inference_normalize_formulas(formulas)
			if (!screen && !html) {
				stop("InferenceSuite$run_all_inference: at least one of `screen`/`html` must be TRUE.")
			}
			if (should_run_asserts()) {
				if (!is.null(classes)) {
					unknown = setdiff(classes, self$applicable_design_classes)
					if (length(unknown) > 0L) {
						stop(sprintf(
							"InferenceSuite$run_all_inference: unknown/inapplicable class(es) in `classes`: %s\n  Applicable: %s",
							paste(unknown, collapse = ", "), paste(self$applicable_design_classes, collapse = ", ")))
					}
				}
				if (length(exclude_classes) > 0L) {
					unknown = setdiff(exclude_classes, self$applicable_design_classes)
					if (length(unknown) > 0L) {
						stop(sprintf(
							"InferenceSuite$run_all_inference: unknown/inapplicable class(es) in `exclude_classes`: %s\n  Applicable: %s",
							paste(unknown, collapse = ", "), paste(self$applicable_design_classes, collapse = ", ")))
					}
				}
			}
			des_obj         = private$des_obj
			design_meta     = normalize_inference_design_metadata(des_obj)
			design_family   = if (isTRUE(design_meta$is_kk)) "kk_matched_pair" else "iid"
			response_type   = design_meta$response_type
			cls_names       = if (is.null(classes)) self$applicable_design_classes else classes
			cls_names       = setdiff(cls_names, exclude_classes)
			if (should_run_asserts()) {
				if (!is.null(combined_evidence_estimands)) {
					known_estimands = unique(stats::na.omit(vapply(cls_names, function(nm) {
						get_inference_class_metadata(nm)$estimand %||% NA_character_
					}, character(1L))))
					unknown_e = setdiff(combined_evidence_estimands, known_estimands)
					if (length(unknown_e) > 0L) {
						stop(sprintf(
							"InferenceSuite$run_all_inference: unknown `combined_evidence_estimands` value(s): %s\n  Declared estimands among these classes: %s",
							paste(unknown_e, collapse = ", "),
							if (length(known_estimands)) paste(known_estimands, collapse = ", ") else "(none declared)"
						))
					}
				}
				if (identical(combined_evidence_weighting, "custom")) {
					if (is.null(combined_evidence_weights) || is.null(names(combined_evidence_weights)) ||
							any(names(combined_evidence_weights) == "")) {
						stop(
							"InferenceSuite$run_all_inference: combined_evidence_weighting = \"custom\" requires ",
							"`combined_evidence_weights`, a named numeric vector (inference class name -> weight)."
						)
					}
					assertNumeric(combined_evidence_weights, any.missing = FALSE)
					if (any(combined_evidence_weights < 0)) {
						stop("InferenceSuite$run_all_inference: `combined_evidence_weights` must be non-negative.")
					}
					unknown_w = setdiff(names(combined_evidence_weights), cls_names)
					if (length(unknown_w) > 0L) {
						stop(sprintf(
							"InferenceSuite$run_all_inference: `combined_evidence_weights` names not among the classes being fit: %s",
							paste(unknown_w, collapse = ", ")
						))
					}
				} else if (!is.null(combined_evidence_weights)) {
					stop(
						"InferenceSuite$run_all_inference: `combined_evidence_weights` is only used when ",
						"combined_evidence_weighting = \"custom\"; got weighting = \"", combined_evidence_weighting, "\"."
					)
				}
			}
			tasks           = run_all_inference_build_tasks(cls_names, formulas, methods, des_obj, private$inference_params, type_requests, basic_bootstrap)
			n_total         = length(tasks)
			t_start         = Sys.time()
			results         = vector("list", n_total)
			names(results)  = vapply(tasks, `[[`, character(1L), "result_name")
			live_header     = if (screen && n_total > 0L) run_all_inference_build_live_table_header(tasks, des_obj) else NULL

			use_fork_cluster = num_cores > 1L && .Platform$OS.type == "unix"
			if (num_cores > 1L && !use_fork_cluster) {
				warning(
					"InferenceSuite$run_all_inference: num_cores > 1 is only supported via fork clusters ",
					"(Unix/Linux) -- falling back to num_cores = 1 (sequential) on this platform.",
					call. = FALSE
				)
			}

			if (use_fork_cluster && n_total > 0L) {
				# Fork clusters (parallel::makeForkCluster()) inherit the master
				# process's entire memory via copy-on-write, so this closure needs no
				# clusterExport() -- des_obj/alpha/etc. are already in its enclosing
				# frame. Screen output cannot stream per-class as it completes here:
				# clusterApply() is a single blocking call that returns only once every
				# worker has finished, so there is no meaningful per-row ETA to show
				# (deliberate design decision, not an oversight -- see
				# inference_suite_inspect.md's TODO-13).
				if (screen) {
					cat(sprintf("Fitting %d task(s) across %d parallel workers...\n", n_total, num_cores))
					cat(live_header$header_lines, sep = "\n")
				}
				cl = parallel::makeForkCluster(num_cores)
				on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
				worker_fn = function(task) {
					params = private$inference_params[[task$cls_name]] %||% list()
					if (!is.null(task$model_formula)) {
						params$model_formula = task$model_formula
					}
					run_all_inference_one_class(
						task$cls_name, des_obj, params, alpha, design_family, response_type, max_secs_per_class, task$method, task$type
					)
				}
				results_list = parallel::clusterApply(cl, tasks, worker_fn)
				names(results_list) = names(results)
				results = results_list
				if (screen) {
					for (i in seq_along(tasks)) {
						run_all_inference_print_row(results[[i]], live_header$statics[[i]], live_header$widths)
					}
					cat(strrep("-", live_header$total_width), "\n", sep = "")
					run_all_inference_print_live_cov_key(live_header$cov_key)
					cat(sprintf(
						"Status: Completed in %s.\n",
						run_all_inference_fmt_completed_secs(as.numeric(difftime(Sys.time(), t_start, units = "secs")))
					))
				}
			} else {
				elapsed_secs_so_far = numeric(n_total)
				# Single progress bar lives at the bottom of the screen, redrawn
				# in place via "\r\033[K" (return to line start, clear it) as each
				# class completes; each just-finished class's result row prints
				# above it and scrolls into normal terminal history -- never a
				# separate bar line per row (per user request, 2026-08-19). The
				# header/rule print once, before the loop, using widths already
				# computed from the full task list -- estimand-grouped mid-stream
				# break lines are deliberately not attempted (rows stream in
				# completion order, not estimand order; see TODO-16a's own
				# "can't pre-sort without buffering" reasoning).
				if (screen) {
					cat(live_header$header_lines, sep = "\n")
					cat(run_all_inference_progress_bar_line(0L, n_total, elapsed_secs_so_far))
				}
				for (i in seq_along(tasks)) {
					task     = tasks[[i]]
					params   = private$inference_params[[task$cls_name]] %||% list()
					if (!is.null(task$model_formula)) {
						params$model_formula = task$model_formula
					}
					results[[i]] = run_all_inference_one_class(
						task$cls_name, des_obj, params, alpha, design_family, response_type, max_secs_per_class, task$method, task$type
					)
					elapsed_secs_so_far[[i]] = results[[i]]$fit_secs
					if (screen) {
						cat("\r\033[K")
						run_all_inference_print_row(results[[i]], live_header$statics[[i]], live_header$widths)
						cat(run_all_inference_progress_bar_line(i, n_total, elapsed_secs_so_far))
					}
				}
				if (screen) {
					cat("\r\033[K")
					if (n_total > 0L) {
						cat(strrep("-", live_header$total_width), "\n", sep = "")
						run_all_inference_print_live_cov_key(live_header$cov_key)
					}
					cat(sprintf(
						"Status: Completed in %s.\n",
						run_all_inference_fmt_completed_secs(as.numeric(difftime(Sys.time(), t_start, units = "secs")))
					))
				}
			}
			if (screen) {
				n_unavail = length(self$unavailable_due_to_missing_packages)
				if (n_unavail > 0L) {
					cat(sprintf(
						"\nThe following Inference %s unavailable:\n",
						if (n_unavail == 1L) "class is" else "classes are"
					))
					cat(paste0("  ", run_all_inference_unavailable_footer_lines(self$unavailable_due_to_missing_packages)), sep = "\n")
				}
			}
			results_table = do.call(rbind.data.frame, lapply(results, function(r) {
				data.frame(
					inference_class = r$inference_class, method = r$method, type = r$type %||% NA_character_,
					cov_model = r$cov_model,
					response_type = r$response_type,
					design_family = r$design_family, likelihood_tier = r$likelihood_tier,
					estimate = r$estimate, se = r$se,
					ci_a = r$ci_a, ci_b = r$ci_b, ci_method = r$ci_method,
					pval = r$pval, pval_method = r$pval_method, estimand = r$estimand,
					fit_secs = r$fit_secs, warnings = r$warnings,
					status = r$status, message = r$message,
					stringsAsFactors = FALSE
				)
			}))
			rownames(results_table) = NULL
			results_table$weight = run_all_inference_compute_combined_evidence_weights(
				results_table, combined_evidence_weighting,
				estimands = combined_evidence_estimands, custom_weights = combined_evidence_weights
			)
			# `row_ids` (== `names(results)`) rather than `results_table$inference_class`
			# because `formulas` can produce more than one row per class --
			# `results`'s own "<class>[<formula>]" disambiguation is the only
			# per-row-unique identifier available. Computed before the TODO-16a
			# estimand sort below, then reordered by the same index, so it stays
			# aligned to `results_table`'s rows however they end up ordered.
			row_ids = names(results)
			# TODO-16a: results_table (and, downstream, the html report's table)
			# is sorted/grouped by estimand -- NA_character_ last as its own
			# group -- with a secondary sort by inference_class within each
			# group. `results` (the list) deliberately stays in computation
			# order; only this data.frame's row order changes.
			sort_idx = order(results_table$estimand, results_table$inference_class, na.last = TRUE)
			results_table = results_table[sort_idx, , drop = FALSE]
			row_ids = row_ids[sort_idx]
			rownames(results_table) = NULL
			combined_usable = !is.na(results_table$weight)
			combined = run_all_inference_combine_pvalues(results_table$pval, results_table$weight)
			out = list(
				results = results,
				results_table = results_table,
				design = list(
					response_type = response_type, design_family = design_family,
					design_class = class(des_obj)[[1L]], n = des_obj$get_n()
				),
				alpha = alpha,
				unavailable_due_to_missing_packages = self$unavailable_due_to_missing_packages,
				combined_evidence = list(
					pval = combined$pval,
					stat = combined$stat,
					method = "cauchy_combination",
					n_classes_used = combined$n_used,
					n_estimand_groups = length(unique(stats::na.omit(results_table$estimand[combined_usable]))),
					estimands_used = sort(unique(stats::na.omit(results_table$estimand[combined_usable]))),
					weighting = combined_evidence_weighting,
					weights_used = stats::setNames(results_table$weight, row_ids),
					classes_used = row_ids[combined_usable]
				),
				plots = list(estimates = list(), ci_forest = list()),
				files = list(html = NULL, pdf = list(estimates = NULL, ci_forest = NULL), json = NULL),
				timestamp = format(Sys.time(), "%Y%m%d_%H%M%S"),
				total_secs = as.numeric(difftime(Sys.time(), t_start, units = "secs")),
				edi_version = as.character(utils::packageVersion("EDI"))
			)
			class(out) = c("EDIInferenceSuiteResults", "list")
			if (screen) {
				breakdown = run_all_inference_per_estimand_breakdown_lines(results_table)
				if (length(breakdown) > 0L) {
					cat("\n", paste(breakdown, collapse = "\n"), "\n", sep = "")
				}
				cat("\n", run_all_inference_combined_evidence_summary_line(out$combined_evidence), "\n", sep = "")
			}
			if (plots || pdf || html) {
				out$plots = run_all_inference_build_plots(results_table, alpha)
			}
			if (plots) {
				for (p in out$plots$estimates) tryCatch(print(p), error = function(e) invisible(NULL))
				for (p in out$plots$ci_forest) tryCatch(print(p), error = function(e) invisible(NULL))
			}
			if (pdf && (length(out$plots$estimates) > 0L || length(out$plots$ci_forest) > 0L)) {
				pdf_path_estimates = file.path(getwd(), sprintf("inference_suite_results_estimates_%s.pdf", out$timestamp))
				pdf_path_ci_forest = file.path(getwd(), sprintf("inference_suite_results_ci_forest_%s.pdf", out$timestamp))
				run_all_inference_save_plots_pdf(out$plots, pdf_path_estimates, pdf_path_ci_forest)
				out$files$pdf = list(
					estimates = if (length(out$plots$estimates) > 0L) pdf_path_estimates else NULL,
					ci_forest = if (length(out$plots$ci_forest) > 0L) pdf_path_ci_forest else NULL
				)
			}
			if (html) {
				html_path = file.path(getwd(), sprintf("inference_suite_results_%s.html", out$timestamp))
				writeLines(run_all_inference_render_html(out), html_path, useBytes = TRUE)
				out$files$html = html_path
				utils::browseURL(html_path)
			}
			if (save_results_as_JSON) {
				if (!requireNamespace("jsonlite", quietly = TRUE)) {
					warning(
						"InferenceSuite$run_all_inference: the 'jsonlite' package is not installed -- ",
						"skipping save_results_as_JSON. Install 'jsonlite' to enable it.",
						call. = FALSE
					)
				} else {
					json_path = file.path(getwd(), sprintf("inference_suite_results_%s.json", out$timestamp))
					jsonlite::write_json(out[setdiff(names(out), "plots")], json_path, auto_unbox = TRUE, null = "null", na = "null")
					out$files$json = json_path
				}
			}
			invisible(out)
		}
	),
	private = list(
		des_obj          = NULL,
		inference_params = NULL
	)
)

#' Prints the results table from an \code{\link[EDI:InferenceSuite]{InferenceSuite}}
#' \code{run_all_inference()} call -- the same table \code{screen = TRUE} prints during
#' the call itself, so a user who assigned the return value and later types its name
#' (or calls \code{print()} on it) sees a readable table rather than a raw nested list
#' dump. The table itself is rendered by
#' \code{run_all_inference_format_pretty_table()}: rows sorted by
#' \code{estimand}, with a double rule under the header and a single rule
#' between \code{estimand} groups and at the bottom, class names and
#' \code{estimand} values shortened for display (never the underlying
#' \code{results_table} values), and a \code{cov_model} letter-key legend
#' appended when applicable -- see that function's own documentation for
#' the exact column-by-column rendering rules.
#' @param x An \code{EDIInferenceSuiteResults} object, as returned by
#'   \code{InferenceSuite$run_all_inference()}.
#' @param ... Ignored; present for S3 consistency with the generic.
#' @return \code{x}, invisibly.
#' @export
print.EDIInferenceSuiteResults = function(x, ...) {
	cat(sprintf(
		"<EDIInferenceSuiteResults> %d class(es) -- %s (%s, %s), n = %s\n",
		nrow(x$results_table), design_class_short_label(x$design$design_class), x$design$response_type,
		x$design$design_family, x$design$n
	))
	cat(run_all_inference_format_pretty_table(x$results_table), sep = "\n")
	breakdown = run_all_inference_per_estimand_breakdown_lines(x$results_table)
	if (length(breakdown) > 0L) {
		cat("\n", paste(breakdown, collapse = "\n"), "\n", sep = "")
	}
	cat("\n", run_all_inference_combined_evidence_summary_line(x$combined_evidence), "\n", sep = "")
	invisible(x)
}

#' Summarizes an \code{\link[EDI:InferenceSuite]{InferenceSuite}} \code{run_all_inference()}
#' result: counts by \code{status}, the estimate range across \code{status == "ok"}
#' classes, and how many reject at \code{alpha}.
#' @param object An \code{EDIInferenceSuiteResults} object, as returned by
#'   \code{InferenceSuite$run_all_inference()}.
#' @param ... Ignored; present for S3 consistency with the generic.
#' @return An object of class \code{summary.EDIInferenceSuiteResults}, printable via its
#'   own \code{print} method.
#' @export
summary.EDIInferenceSuiteResults = function(object, ...) {
	tbl = object$results_table
	ok = tbl[tbl$status == "ok", , drop = FALSE]
	structure(
		list(
			n_classes = nrow(tbl),
			status_counts = table(factor(tbl$status, levels = c("ok", "nonest", "error", "timeout"))),
			estimate_range = if (nrow(ok) > 0L) range(ok$estimate, na.rm = TRUE) else c(NA_real_, NA_real_),
			alpha = object$alpha,
			n_significant = sum(!is.na(ok$pval) & ok$pval < object$alpha)
		),
		class = "summary.EDIInferenceSuiteResults"
	)
}

#' @param x A \code{summary.EDIInferenceSuiteResults} object, as returned by
#'   \code{\link{summary.EDIInferenceSuiteResults}}.
#' @param ... Ignored; present for S3 consistency with the generic.
#' @return \code{x}, invisibly.
#' @export
#' @rdname summary.EDIInferenceSuiteResults
print.summary.EDIInferenceSuiteResults = function(x, ...) {
	cat("InferenceSuite$run_all_inference() summary\n")
	cat(sprintf("  classes:            %d\n", x$n_classes))
	for (nm in names(x$status_counts)) {
		cat(sprintf("    %-13s %d\n", paste0(nm, ":"), x$status_counts[[nm]]))
	}
	cat(sprintf(
		"  estimate range:     [%s, %s]\n",
		if (is.na(x$estimate_range[1])) "NA" else formatC(x$estimate_range[1], digits = 4, format = "g"),
		if (is.na(x$estimate_range[2])) "NA" else formatC(x$estimate_range[2], digits = 4, format = "g")
	))
	cat(sprintf("  significant (alpha = %g): %d\n", x$alpha, x$n_significant))
	invisible(x)
}
