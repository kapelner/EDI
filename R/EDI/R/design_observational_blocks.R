#' A Fixed Observational (Non-Randomized) Design With Blocks
#'
#' An \code{\link[EDI:ObservationalDesign]{ObservationalDesign}} whose subjects are
#' additionally partitioned into user-supplied blocks (matched sets / strata), via the
#' block-membership vector \eqn{m}. As with
#' \code{\link[EDI:ObservationalDesign]{ObservationalDesign}}, there is no randomization
#' mechanism at all -- neither the treatment assignment \eqn{w} nor the block membership
#' \eqn{m} is drawn by this class, both are supplied by the user -- so
#' \code{draw_ws_according_to_design()} still always throws (inherited unchanged from
#' \code{ObservationalDesign}).
#'
#' @details
#' \strong{Why blocks, if there's no randomization to block on?} Blocking here is not a
#' randomization restriction (there is none); it is a resampling structure. Supplying
#' \eqn{m} lets bootstrap procedures resample \emph{within} blocks -- exactly as they do
#' for \code{\link[EDI:DesignFixedBlocking]{DesignFixedBlocking}} and
#' \code{\link[EDI:DesignFixedOptimalBlocks]{DesignFixedOptimalBlocks}} -- which is
#' appropriate when the observational data itself has a matched/stratified/clustered
#' structure (e.g. matched case-control sets, repeated measurements within site) that the
#' bootstrap should respect.
#'
#' \strong{Jackknife.} With at least 5 blocks the jackknife's automatic deletion unit is the
#' whole block (\code{unit = "block"}), right when the blocks are matched sets or clusters.
#' With fewer than 5 blocks, leave-one-block-out would have too few units (its
#' jackknife-Wald results would be \code{NA}), so the automatic unit is one subject, the
#' blocks acting as strata (\code{unit = "observation_within_block"}; the stratified
#' jackknife of Wolter 2007, Sec. 4.5, formulas in
#' \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}), with the t reference on
#' \eqn{\sum_h (n_h - 1)} degrees of freedom. Either unit can be requested explicitly
#' (v1.0.6-TODO-231).
#'
#' \strong{No auto-derived n.} Unlike plain \code{ObservationalDesign}, \code{n} is not a
#' constructor argument here at all -- it is always \code{length(m)}, since a block
#' membership vector with one entry per subject already fixes the sample size.
#'
#' @keywords internal
#' @examples
#' des = ObservationalDesignBlocks$new(response_type = 'continuous', m = c(1, 1, 2, 2, 3, 3))
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
#' des$assign_w_to_all_subjects(w_precomputed = c(1, 0, 1, 0, 1, 0))
#' @export
ObservationalDesignBlocks = define_design_class(
	classname = "ObservationalDesignBlocks",
	inherit = ObservationalDesign,
	components = "BlockingStructure",
	public = list(
		#' @description Initialize a fixed observational (non-randomized) design with
		#'   user-supplied block membership. Neither treatment \code{w} nor block
		#'   membership \code{m} is drawn here — both must be supplied (\code{m} at
		#'   construction, \code{w} afterward via
		#'   \code{assign_w_to_all_subjects(w_precomputed = ...)}); see class
		#'   documentation for why blocks are still useful without a randomization
		#'   mechanism to block on.
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param m A positive-integer vector of block (matched-set/stratum) identifiers,
		#'   one entry per subject; a block may contain any number of subjects
		#'   (unlike \code{\link[EDI:ObservationalDesignMatching]{ObservationalDesignMatching}},
		#'   which fixes block size at exactly 2). \code{n} is derived as
		#'   \code{length(m)} and is not a separate argument.
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return  A new `ObservationalDesignBlocks` object
		initialize = function(
				response_type,
				m,
				include_is_missing_as_a_new_feature = TRUE,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			if (should_run_asserts()) {
				assertIntegerish(m, lower = 1, any.missing = FALSE, min.len = 1)
			}
			super$initialize(
				response_type = response_type,
				include_is_missing_as_a_new_feature = include_is_missing_as_a_new_feature,
				n = length(m),
				verbose = verbose,
				missingness_method = missingness_method,
				design_formula = design_formula,
				seed = seed
			)
			private$blocking_capable = TRUE
			self$set_m(as.integer(m))
		}
	)
	# draw_bootstrap_indices is provided by the BlockingStructure component (see
	# `components` above); proven byte-identical to this class's former hand-rolled
	# version via test-design-blocking-structure-bootstrap-golden.R before removal.
)
