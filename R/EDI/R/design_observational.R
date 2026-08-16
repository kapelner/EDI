#' A Fixed Observational (Non-Randomized) Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} whose treatment
#' assignment vector \eqn{w} is supplied by the user (e.g. via
#' \code{assign_w_to_all_subjects(w_precomputed = ...)} or
#' \code{overwrite_all_subject_assignments()}) rather than drawn from any
#' randomization mechanism. Unlike every other \code{DesignFixed} subclass, there is no
#' \code{prob_T} to specify -- treatment was not assigned by the experimenter according
#' to a known probability law, so no such probability exists to declare.
#'
#' @details
#' \strong{No draw mechanism.} \code{draw_ws_according_to_design()} (and, transitively,
#' the fallback branch of \code{assign_w_to_all_subjects()} that would otherwise call
#' it) always throws. Any inference procedure that must redraw \eqn{w} from the design's
#' own randomization law -- randomization tests, randomization confidence intervals, and
#' randomization/assignment bootstrap -- therefore throws the same clear error rather
#' than silently fabricating a randomization mechanism that never existed. Procedures
#' that resample \emph{subjects} instead of redrawing \eqn{w} (plain nonparametric
#' bootstrap, Bayesian bootstrap) are unaffected and remain available, since resampling
#' subjects with their observed, fixed assignment does not require a known randomization
#' probability.
#'
#' \strong{No balance target.} \code{assert_even_allocation()} is a no-op here (rather
#' than the inherited check against \code{prob_T = 0.5}): there is no targeted
#' allocation ratio for an observational design to be out of balance with.
#'
#' @keywords internal
#' @examples
#' des = ObservationalDesign$new(n = 10, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10)))
#' des$assign_w_to_all_subjects(w_precomputed = rbinom(10, 1, 0.3))
#' @export
ObservationalDesign = R6::R6Class("ObservationalDesign",
	inherit = DesignFixed,
	public = list(
		#' @description Initialize a fixed observational (non-randomized) design. No
		#'   treatment vector is drawn or requested here; the constructor only records
		#'   configuration (covariates, response type, etc.) and internally fixes
		#'   \code{prob_T = 0.5} purely so the shared \code{Design}/\code{DesignFixed}
		#'   machinery has a value to store — it is never used to draw or validate an
		#'   allocation for this class (see \code{assert_even_allocation()} and class
		#'   documentation). \eqn{w} itself is supplied afterward via
		#'   \code{assign_w_to_all_subjects(w_precomputed = ...)} or
		#'   \code{overwrite_all_subject_assignments()}.
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility. Note this design has no
		#'   randomization mechanism to seed (see class documentation); \code{seed} only
		#'   affects RNG-dependent behavior inherited from \code{Design} unrelated to
		#'   treatment assignment (e.g. imputation, bootstrap resampling).
		#'
		#' @return  A new `ObservationalDesign` object
		initialize = function(
				response_type,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			super$initialize(response_type, 0.5, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
		},
		#' @description Observational designs have no targeted allocation ratio to
		#'   check balance against, so this is a no-op rather than an error (contrast
		#'   with the inherited \code{Design$assert_even_allocation()}, which errors if
		#'   the realized allocation deviates from \code{prob_T = 0.5}).
		#' @return \code{invisible(NULL)}, always; never errors.
		assert_even_allocation = function(){
			invisible(NULL)
		},
		#' @description Characterization: \code{FALSE} -- this design has no
		#'   randomization mechanism to redraw \eqn{w} from (see class documentation).
		#'   Metadata-declared replacement for the old \code{draw_ws_raw()} throwing
		#'   stub (still present below as a fallback for any caller that reaches it
		#'   without checking this first -- see \code{fix_design_hierarchy.md},
		#'   "Observational Design Migration").
		#' @return Always \code{FALSE} for this class.
		supports_randomization_draw = function(){
			FALSE
		},
		#' @description Characterization: \code{FALSE} -- this design has no
		#'   randomization mechanism to replay against resampled data (bootstrap
		#'   randomization test eligibility). Plain nonparametric/Bayesian/m-out-of-n/
		#'   PRW-subsampling bootstrap are unaffected (see
		#'   \code{Design$supports_resampling()}'s documentation) and remain available.
		#' @return Always \code{FALSE} for this class.
		supports_resampling_replay = function(){
			FALSE
		}
	),
	private = list(
		# Metadata (supports_randomization_draw() = FALSE above, randomization_family
		# = "none") is now the primary signal callers should check; this throwing stub
		# remains as a fallback for any caller that reaches draw_ws_according_to_design()
		# without checking supports("randomization_draw") first, so behavior doesn't
		# regress for existing code relying on the tryCatch-and-message pattern this
		# class has always documented (fix_design_hierarchy.md, "Observational Design
		# Migration").
		draw_ws_raw = function(r = 1L){
			stop("This operation is not supported. Observational designs are not controlled designs based on randomized allocations.")
		}
	)
)
