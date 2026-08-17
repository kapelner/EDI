
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
#' support blocking; or if the design has any left-/interval-censored
#' subjects (`has_general_censoring`) but the class's
#' `supports_general_censoring` metadata is `FALSE` -- the latter two mirror
#' `Inference$initialize()`'s own construction-time gate exactly. Ordinary
#' right-censoring alone (`any_censoring` without `has_general_censoring`)
#' never excludes a class.
#'
#' @keywords internal
#' @noRd
is_inference_class_compatible_with_design_metadata = function(nm, design_meta) {
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
#'   This class does not itself compute any estimates, p-values, or confidence
#'   intervals; it only discovers and validates which inference classes are
#'   applicable and, once constructed, does not eagerly construct any of them.
#'   \code{lock_objects = FALSE} allows ad hoc fields to be attached to an
#'   instance after construction.
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
				if (!is(des_obj, "Design")) {
					stop("InferenceSuite: des_obj must be a Design object.")
				}
				if (!is.list(inference_params)) {
					stop("InferenceSuite: inference_params must be a list.")
				}
			}
			if (length(inference_params) > 0L &&
					(is.null(names(inference_params)) ||
					 any(nchar(names(inference_params)) == 0L))) {
				stop("InferenceSuite: inference_params must be a fully named list.")
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
		}
	),
	private = list(
		des_obj          = NULL,
		inference_params = NULL
	)
)
