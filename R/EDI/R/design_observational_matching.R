#' A Fixed Observational (Non-Randomized) Matched-Pair Design
#'
#' An \code{\link[EDI:ObservationalDesign]{ObservationalDesign}} whose \eqn{n} subjects
#' are organized into \eqn{n/2} matched pairs, each of size exactly 2. This is a
#' convenience wrapper: it builds the canonical pair-membership vector
#' \eqn{m = (1, 1, 2, 2, \dots, n/2, n/2)} internally -- subject \eqn{2k - 1} and subject
#' \eqn{2k} are pair \eqn{k} -- and installs it via \code{set_m()}, so the caller need
#' only supply subjects (and, later, responses) in that paired order; there is no
#' separate \code{m} argument to get wrong.
#'
#' @details
#' \strong{Why not just \code{ObservationalDesignBlocks} with block size 2?} It would
#' look equivalent but silently behave differently: matching is a distinct capability
#' (\code{private$matching_capable}, checked via \code{is_matching_design()}) from
#' generic blocking, and several \code{Inference} components (jackknife, nonparametric
#' bootstrap, Bayesian bootstrap, exchangeable-resampling-unit selection) branch on it to
#' use pair-preserving resampling (\code{DesignMatching}'s own
#' \code{draw_bootstrap_indices()}, via \code{draw_matching_bootstrap_sample_cpp()})
#' instead of generic per-stratum resampling. \code{ObservationalDesignBlocks} overrides
#' \code{draw_bootstrap_indices()} with the generic stratified version, so subclassing it
#' here would advertise \code{is_matching_design() == TRUE} while still running the
#' wrong bootstrap underneath. This class instead extends
#' \code{\link[EDI:ObservationalDesign]{ObservationalDesign}} directly -- the same
#' relationship \code{\link[EDI:DesignFixedBinaryMatch]{DesignFixedBinaryMatch}} has to
#' \code{\link[EDI:DesignFixed]{DesignFixed}} -- so it inherits
#' \code{DesignMatching}'s real matched-pair bootstrap machinery unmodified.
#'
#' @keywords internal
#' @examples
#' des = ObservationalDesignMatching$new(response_type = 'continuous', n = 6)
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
#' des$assign_w_to_all_subjects(w_precomputed = c(1, 0, 0, 1, 1, 0))
#' @export
ObservationalDesignMatching = define_design_class(
	classname = "ObservationalDesignMatching",
	inherit = ObservationalDesign,
	components = "MatchingStructure",
	# MatchingStructure auto-expands to include its BlockingStructure dependency; both
	# provide draw_bootstrap_indices, and the pair-preserving MatchingStructure version
	# (processed after its dependency) must win -- this class had no override of its
	# own, so it was already using this exact function via inheritance from
	# DesignMatching (reference-identity, not just behavioral equivalence).
	overrides = list(private = "draw_bootstrap_indices"),
	public = list(
		#' @description Initialize a fixed observational (non-randomized) design whose
		#'   subjects are organized into \code{n / 2} matched pairs of size 2 (subjects
		#'   \code{2k - 1} and \code{2k} form pair \code{k}). Unlike
		#'   \code{\link[EDI:ObservationalDesignBlocks]{ObservationalDesignBlocks}}
		#'   there is no separate \code{m} argument — the pair structure is fixed by
		#'   subject order and installed automatically via \code{set_m()}, and
		#'   \code{private$matching_capable} is set so downstream \code{Inference}
		#'   classes use pair-preserving (not generic stratified) resampling (see class
		#'   documentation). As with every \code{ObservationalDesign}, \eqn{w} itself is
		#'   supplied afterward via
		#'   \code{assign_w_to_all_subjects(w_precomputed = ...)}, in the same paired
		#'   subject order.
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param n The sample size; must be even (subjects \code{2k - 1}/\code{2k} form
		#'   pair \code{k}, so an odd \code{n} would leave one subject unpaired).
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return  A new `ObservationalDesignMatching` object
		initialize = function(
				response_type,
				n,
				include_is_missing_as_a_new_feature = TRUE,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			if (should_run_asserts()) {
				assertCount(n, positive = TRUE)
				if (n %% 2 != 0){
					stop("ObservationalDesignMatching requires an even n (subjects are organized into pairs).")
				}
			}
			super$initialize(
				response_type = response_type,
				include_is_missing_as_a_new_feature = include_is_missing_as_a_new_feature,
				n = n,
				verbose = verbose,
				missingness_method = missingness_method,
				design_formula = design_formula,
				seed = seed
			)
			private$blocking_capable = TRUE
			private$matching_capable = TRUE
			self$set_m(rep(seq_len(n %/% 2L), each = 2L))
		}
	)
)
