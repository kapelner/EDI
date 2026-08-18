#' Marginal vs. Conditional Estimand Switch
#'
#' @name InferenceMarginalEstimand
#' @description Component scaffold providing \code{set_estimand()}/
#' \code{get_estimand()}/\code{get_supported_estimands()} for classes whose
#' reported treatment coefficient is conditional on a latent mixture
#' component -- e.g. the interior beta submodel in zero/one-inflated beta
#' regression, or the count-process submodel in zero-augmented/hurdle
#' Poisson -- rather than the unconditional response mean \eqn{E[Y]}. See
#' \code{marginal_estimand_report.md} for the full design discussion.
#'
#' Mirrors the \code{testing_type} switch (\code{InferenceAsympLik}) on its
#' own, orthogonal axis: default \code{"conditional"} (today's behavior,
#' fully backward compatible -- every class that does not compose this
#' component is implicitly conditional-only), with \code{"marginal_mean_diff"}
#' and \code{"marginal_ratio"} available to classes that declare support for
#' them via their own \code{get_supported_estimands_impl()} override (the
#' same override pattern already used for
#' \code{get_supported_testing_types_impl()}).
#'
#' \strong{Scope note (2026-08-18):} this component provides only the
#' get/set/supported-values switch and the cache-key helper. It does not
#' itself compute any marginal estimate -- no class currently composes it.
#' Wiring a class's own \code{compute_estimate()} to consult
#' \code{self$get_estimand()} and, for a marginal estimand, call into a
#' family-specific model-implied mean function plus a shared
#' g-computation-average/delta-method-gradient helper, is
#' \code{marginal_estimand_report.md → TODO-4/5/9} -- deliberately deferred
#' until their target classes (still on the legacy deep-hierarchy ladder as
#' of this writing) migrate to the shallow hierarchy under
#' \code{fix_inference_hierarchy.md}'s Full-Likelihood Estimators remainder.
#' \code{compute_estimate()} itself stays 100 percent class-owned either way
#' -- this component never overrides or wraps it, so no
#' \code{allowed_host_overrides} declaration is needed.
#'
#' @keywords internal
InferenceMarginalEstimand = R6::R6Class("InferenceMarginalEstimand",
	lock_objects = FALSE,
	public = list(
		#' @description Sets the target estimand for this inference object.
		#' @param estimand One of \code{get_supported_estimands()}. Accepts the
		#'   canonical values (\code{"conditional"}, \code{"marginal_mean_diff"},
		#'   \code{"marginal_ratio"}) case-insensitively.
		#' @return The inference object, invisibly.
		#' @details If this object also composes \code{LikelihoodTests} (checked
		#'   via \code{self$supports("likelihood_tests")}, the sanctioned
		#'   capability query -- see
		#'   \code{marginal_estimand_report.md → TODO-6}), switching to a
		#'   non-\code{"conditional"} estimand shrinks the set of supported
		#'   testing types to \code{"wald"} only. If the currently configured
		#'   \code{testing_type} is no longer in that shrunk set, this errors
		#'   loudly and leaves the estimand unchanged, rather than silently
		#'   leaving the object in an inconsistent state -- the same guarantee
		#'   holds regardless of which of \code{set_testing_type()}/
		#'   \code{set_estimand()} is called first.
		set_estimand = function(estimand){
			estimand = private$normalize_estimand(estimand)
			supported = private$get_supported_estimands_impl()
			if (!estimand %in% supported) {
				stop(
					class(self)[1L], " does not support estimand = \"", estimand,
					"\". Supported values are: ", paste(supported, collapse = ", "),
					call. = FALSE
				)
			}
			old_estimand = private$estimand
			private$estimand = estimand
			if (isTRUE(self$supports("likelihood_tests"))) {
				current_testing_type = self$get_testing_type()
				still_supported = self$get_supported_testing_types()
				if (!current_testing_type %in% still_supported) {
					private$estimand = old_estimand
					stop(
						class(self)[1L], ": cannot set estimand = \"", estimand,
						"\" while testing_type = \"", current_testing_type,
						"\" is configured -- that testing type is not supported under ",
						"this estimand (supported: ", paste(still_supported, collapse = ", "),
						"). Call set_testing_type() to a compatible value first.",
						call. = FALSE
					)
				}
			}
			invisible(self)
		},
		#' @description Gets the current target estimand.
		#' @return A character scalar, one of \code{get_supported_estimands()}.
		get_estimand = function(){
			private$estimand
		},
		#' @description Gets the estimands supported by this inference object.
		#' @return A character vector. Always includes \code{"conditional"}.
		get_supported_estimands = function(){
			private$get_supported_estimands_impl()
		}
	),
	private = list(
		estimand = "conditional",
		#' Canonicalizes a requested estimand value, rejecting anything not in
		#' the fixed set of recognized spellings -- unlike
		#' `get_supported_estimands_impl()` below (host-overridable, varies by
		#' class), this recognizes syntax, not per-class support.
		normalize_estimand = function(estimand){
			if (length(estimand) != 1L) estimand = estimand[1L]
			estimand = tolower(as.character(estimand))
			switch(
				estimand,
				conditional = "conditional",
				marginal_mean_diff = "marginal_mean_diff",
				marginal_ratio = "marginal_ratio",
				stop(
					"Unrecognized estimand \"", estimand, "\". Supported spellings: ",
					"\"conditional\", \"marginal_mean_diff\", \"marginal_ratio\".",
					call. = FALSE
				)
			)
		},
		#' Default: every class implicitly supports only the conditional
		#' estimand until it declares otherwise. Concrete classes override this
		#' private method (via `define_inference_class()`'s `overrides`
		#' argument, the same pattern `get_supported_testing_types_impl()`
		#' already uses) once they wire a marginal mean function.
		get_supported_estimands_impl = function(){
			"conditional"
		},
		#' Cache-key fragment for the current estimand, generalizing
		#' `likelihood_test_delta_key()`'s testing_type/delta pattern to this
		#' orthogonal axis. Any cache keyed partly by estimand should prefix or
		#' combine with this so a cache entry built under one estimand is never
		#' reused under another.
		marginal_estimand_cache_key = function(){
			as.character(private$estimand)
		}
	)
)
