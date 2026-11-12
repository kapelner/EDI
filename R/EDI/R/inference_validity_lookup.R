# User-callable lookup of procedure validity (v1.0.5 TODO-197).
#
# Resolves, for a design x inference class x procedure triple, what the
# convergence registry (inference_procedure_regime.R) says about validity, and,
# when a design with data is available, the realised effective n (counting
# helper shared with run_all_inference(): inference_validity_n_eff.R). Backs the
# public method Inference$get_procedure_validity() and the exported function
# get_inference_procedure_validity(). Nothing here keeps its own copy of a
# regime, rate, rule or reference: every value is read from the registry.

#' Note attached to the `measured` element until measured calibration values
#' ship (v1.0.6 TODO-19, was v1.0.5 TODO-196).
#' @keywords internal
#' @noRd
EDI_PROCEDURE_VALIDITY_MEASURED_NOTE = paste(
	"No measured calibration values are shipped with this version of EDI yet",
	"(planned: size, coverage and bias per design, class, procedure and n from a",
	"complete calibration campaign). Until then only the registry expectation is",
	"reported."
)

#' Hook for v1.0.6 TODO-19's measured values. Returns `NULL` (nothing shipped) or,
#' once the measured table exists, a data.frame of the measured size / coverage /
#' bias rows (with campaign id and EDI commit) for the requested triples.
#' `design` here is the registry design key (class name, optional `@prob_T=`
#' suffix), `n_eff` the realised effective n or `NA`. Only this function needs to
#' change when the measured table lands; the callers below pass its result
#' through as the `measured` element.
#' @keywords internal
#' @noRd
edi_procedure_validity_measured = function(design, class, procedure, n_eff = NA_real_) {
	NULL
}

#' Sentinel procedures a concrete inference class supports by default, in
#' `EDI_INFERENCE_SUITE_METHOD_SENTINELS` order. Same applicability rule as
#' `run_all_inference()` (capability tags, randomization support of the design
#' instance, incidence rand exclusion, permanently non-estimable jackknife).
#' With `des_obj = NULL` the answer is capability-level only. With a live
#' object, `lik_ratio_bartlett_exact` is decided by that object (not by a
#' freshly constructed default one).
#' @keywords internal
#' @noRd
edi_procedure_validity_supported = function(class_name, des_obj = NULL, live_obj = NULL) {
	sentinels = EDI_INFERENCE_SUITE_METHOD_SENTINELS
	bartlett = "lik_ratio_bartlett_exact"
	if (is.null(live_obj)) {
		return(run_all_inference_class_applicable_methods(class_name, sentinels, des_obj))
	}
	out = run_all_inference_class_applicable_methods(class_name, setdiff(sentinels, bartlett), des_obj)
	if (bartlett %in% sentinels && inference_class_has_method(class_name, bartlett, des_obj)) {
		priv = live_obj$.__enclos_env__$private
		if (isTRUE(tryCatch(priv$supports_bartlett_likelihood_ratio_exact(), error = function(e) FALSE))) {
			out = c(out, bartlett)
		}
	}
	intersect(sentinels, out)
}

#' Builds the lookup result for one design key and class.
#'
#' @param design_label Registry design key (class name, optionally with `@prob_T=`).
#' @param class_name Concrete inference class name.
#' @param procedures Sentinel labels to report.
#' @param supported Sentinel labels the class supports (for the `supported` column).
#' @param counts Named realised counts (`edi_inference_validity_counts()`), or `NULL`.
#' @return A list: `expectation` (data.frame), `measured`, `measured_note`.
#' @keywords internal
#' @noRd
edi_procedure_validity_build = function(design_label, class_name, procedures, supported, counts = NULL) {
	exp = inference_convergence_expectation(design_label, class_name, procedures)
	n_eff = if (is.null(counts)) rep(NA_real_, NROW(exp)) else
		as.numeric(unname(counts[as.character(exp$n_eff)]))
	expectation = data.frame(
		design = exp$design, class = exp$class, procedure = exp$procedure,
		supported = exp$procedure %in% supported,
		regime = exp$regime,
		size_order = exp$size_order,
		size_order_label = edi_inference_validity_render_order(exp$size_order),
		bias_order = exp$bias_order,
		n_eff_rule = exp$n_eff,
		n_eff = n_eff,
		regularity = exp$regularity,
		basis = exp$basis, reference = exp$reference,
		bias_basis = exp$bias_basis, bias_reference = exp$bias_reference,
		size_layer = exp$size_layer, bias_layer = exp$bias_layer,
		n_eff_layer = exp$n_eff_layer, regularity_layer = exp$regularity_layer,
		stringsAsFactors = FALSE
	)
	rownames(expectation) = NULL
	measured = edi_procedure_validity_measured(exp$design, exp$class, exp$procedure, n_eff)
	list(expectation = expectation, measured = measured,
		measured_note = if (is.null(measured)) EDI_PROCEDURE_VALIDITY_MEASURED_NOTE else NULL)
}

#' Validates a user-supplied `procedure` against the registry's labels; `NULL`
#' passes through.
#' @keywords internal
#' @noRd
edi_procedure_validity_check_procedure = function(procedure) {
	if (is.null(procedure)) return(NULL)
	if (!is.character(procedure) || length(procedure) < 1L || anyNA(procedure)) {
		stop("`procedure` must be NULL or a non-empty character vector of procedure labels.", call. = FALSE)
	}
	bad = setdiff(procedure, names(EDI_INFERENCE_PROCEDURE_REGIME))
	if (length(bad)) {
		stop("Unknown procedure(s): ", paste(bad, collapse = ", "), ". Valid labels: ",
			paste(names(EDI_INFERENCE_PROCEDURE_REGIME), collapse = ", "), ".", call. = FALSE)
	}
	unique(procedure)
}

#' Implementation behind `Inference$get_procedure_validity()`.
#' @keywords internal
#' @noRd
edi_procedure_validity_for_object = function(inf, procedure = NULL) {
	procedure = edi_procedure_validity_check_procedure(procedure)
	priv = inf$.__enclos_env__$private
	des_obj = priv$des_obj
	# External and test subclasses are not in the registry: resolve through the
	# nearest registered ancestor, as Inference$capabilities() does.
	class_name = Find(function(nm) exists(nm, envir = EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE), class(inf))
	supported = if (is.null(class_name)) character() else
		edi_procedure_validity_supported(class_name, des_obj, live_obj = inf)
	if (is.null(procedure)) procedure = supported
	edi_procedure_validity_build(
		edi_inference_validity_design_label(des_obj), class(inf)[1L], procedure, supported,
		counts = edi_inference_validity_counts(des_obj)
	)
}

#' Procedure validity expectations for a design, inference class and procedure
#'
#' Looks up, without fitting anything, what EDI's validity registry says about
#' how an inference procedure behaves for an inference class on a design: its
#' regime (\code{"asymptotic"}: valid as the effective sample size grows, so
#' small-sample excess is expected; \code{"finite_sample"}: valid at every
#' sample size by construction), the expected order of the size error, the rule
#' for the effective sample size, the regularity of the problem, and the basis
#' and reference of each claim.
#'
#' For the same lookup on a fitted object, including the realised effective
#' sample size of its data, use the method
#' \code{get_procedure_validity()} of the inference object.
#'
#' @param design A design class name such as \code{"DesignFixedBernoulli"}. The
#'   calibration study's label \code{"DesignFixedBernoulli@prob_T=0.2"} selects
#'   the unequal-allocation entries. A \code{Design} object is also accepted; its
#'   realised data then fill in \code{n_eff}.
#' @param inference_class The name of a concrete inference class, such as
#'   \code{"InferenceContinLin"}.
#' @param procedure \code{NULL} (default) for every procedure the class supports
#'   by default, otherwise one or more procedure labels as used in the
#'   \code{method} column of \code{\link[=InferenceSuite]{run_all_inference}()} results, such as
#'   \code{"wald"}, \code{"rand"} or \code{"bootstrap"}.
#'
#' @details Without a design object there is no data, so \code{n_eff} is
#'   \code{NA}; \code{n_eff_rule} still names the rule (for example
#'   \code{"n_pairs"}). Which procedures a class supports is decided from its
#'   capabilities only; a specific design or object can rule out more. With
#'   an explicit \code{procedure} the registry expectation is returned even if
#'   the class does not support it (\code{supported} is then \code{FALSE}).
#'
#'   Values with basis \code{"assumed_default"} are the regular-parametric-model
#'   default for the procedure, not something established for this class;
#'   basis \code{"unknown"} means the order is not known (\code{size_order} is
#'   \code{NA}).
#'
#' @return A list with elements
#'   \describe{
#'     \item{\code{expectation}}{A data frame with one row per procedure:
#'       \code{design}, \code{class}, \code{procedure}, \code{supported},
#'       \code{regime}, \code{size_order} (the size error is
#'       O(n_eff^-size_order); \code{Inf} for exact procedures, \code{NA} when
#'       unknown), \code{size_order_label} (the same, rendered), \code{bias_order},
#'       \code{n_eff_rule}, \code{n_eff} (realised value, or \code{NA}),
#'       \code{regularity}, \code{basis}, \code{reference}, \code{bias_basis},
#'       \code{bias_reference}, and the registry layer that supplied each field.}
#'     \item{\code{measured}}{Measured size, coverage and bias from calibration
#'       campaigns. \code{NULL} in this version: none are shipped yet.}
#'     \item{\code{measured_note}}{A sentence saying why \code{measured} is
#'       \code{NULL}, or \code{NULL} when it is not.}
#'   }
#' @seealso \code{\link[=InferenceSuite]{run_all_inference}} for the same information as columns
#'   of a fitted comparison.
#' @examples
#' v = get_inference_procedure_validity("DesignFixedBernoulli", "InferenceContinLin")
#' v$expectation[, c("procedure", "regime", "size_order_label", "n_eff_rule")]
#' get_inference_procedure_validity(
#'   "DesignFixedBernoulli@prob_T=0.2", "InferenceContinLin", "wald"
#' )$expectation$n_eff_rule
#' @export
get_inference_procedure_validity = function(design, inference_class, procedure = NULL) {
	if (!is.character(inference_class) || length(inference_class) != 1L || is.na(inference_class)) {
		stop("`inference_class` must be a single inference class name.", call. = FALSE)
	}
	procedure = edi_procedure_validity_check_procedure(procedure)
	meta = tryCatch(get_inference_class_metadata(inference_class), error = function(e) {
		stop("`inference_class` '", inference_class, "' is not a registered EDI inference class.", call. = FALSE)
	})
	if (!identical(meta$abstract, FALSE)) {
		stop("`inference_class` '", inference_class, "' is abstract; give a concrete inference class.", call. = FALSE)
	}
	counts = NULL
	if (inherits(design, "Design")) {
		counts = edi_inference_validity_counts(design)
		design_label = edi_inference_validity_design_label(design)
		des_obj = design
	} else {
		if (!is.character(design) || length(design) != 1L || is.na(design)) {
			stop("`design` must be a single design class name or a Design object.", call. = FALSE)
		}
		design_label = design
		des_obj = NULL
		base = sub("@.*$", "", design)
		tryCatch(get_design_class_metadata(base), error = function(e) {
			stop("`design` '", design, "' is not a registered EDI design class.", call. = FALSE)
		})
	}
	supported = edi_procedure_validity_supported(inference_class, des_obj)
	if (is.null(procedure)) procedure = supported
	edi_procedure_validity_build(design_label, inference_class, procedure, supported, counts = counts)
}
