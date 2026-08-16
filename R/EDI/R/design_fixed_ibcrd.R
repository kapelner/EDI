#' A Fixed, Individually Balanced Completely Randomized Design (iBCRD)
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} implementing the
#' individually balanced complete randomized design (iBCRD): the number of treated
#' subjects is fixed at exactly \eqn{n_T = \mathrm{round}(n \cdot prob\_T)}, and each
#' allocation \eqn{w} with exactly \eqn{n_T} ones is drawn uniformly at random from the
#' \eqn{\binom{n}{n_T}} possible such allocations (via a Fisher-Yates shuffle of a base
#' vector with \eqn{n_T} ones and \eqn{n - n_T} zeros). This is the classical "complete
#' randomization" reference design of randomization inference: unlike
#' \code{\link[EDI:DesignFixedBernoulli]{DesignFixedBernoulli}} (independent per-subject
#' coin flips, random \eqn{n_T}), \eqn{n_T} is fixed here, which is what makes exact
#' permutation/randomization tests over the \eqn{\binom{n}{n_T}} allocations well-defined;
#' unlike \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}}/
#' \code{\link[EDI:DesignFixedGreedy]{DesignFixedGreedy}}, no covariate information is
#' used to select among those allocations — every one of the \eqn{\binom{n}{n_T}}
#' allocations is equally likely.
#'
#' @details
#' \strong{Draw mechanism.} \code{draw_ws_raw(r)} delegates to
#' \code{generate_permutations_ibcrd_cpp()}, which builds one base allocation vector
#' (\eqn{n_T} ones followed by \eqn{n - n_T} zeros) and independently
#' shuffles (Fisher-Yates via \code{std::shuffle}) a fresh copy of it
#' per replicate column, seeded from R's own RNG stream (so \code{seed} does govern
#' reproducibility here, unlike the A-/D-optimal exchange searches).
#' \code{assign_w_to_all_subjects()} draws one such allocation (\code{r = 1}) and applies
#' it to all subjects.
#'
#' \strong{Single implicit block.} The constructor sets \code{private$m} to a constant
#' vector of 1s (a single block containing every subject) once \code{n} is known, so that
#' shared blocking/matching machinery that expects a block-membership vector treats the
#' whole sample as one block by default.
#'
#' @references Fisher, R. A. (1935). \emph{The Design of Experiments}. Oliver and Boyd,
#'   for complete randomization as the canonical reference design of randomization
#'   inference. See also
#'   \href{https://en.wikipedia.org/wiki/Randomized_experiment}{randomized experiment}
#'   for orientation on complete vs. Bernoulli randomization.
#' @examples
#' des = DesignFixediBCRD$new(n = 10, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10)))
#' des$assign_w_to_all_subjects()
#' @export
DesignFixediBCRD = R6::R6Class("DesignFixediBCRD",
	inherit = DesignFixed,
	public = list(
		#' @description Initialize a fixed individually balanced completely randomized
		#'   experimental design (see class documentation for the exact randomization
		#'   law).
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Target probability of treatment assignment; the realized
		#'   number of treated subjects is fixed at \code{round(n * prob_T)} for every
		#'   draw (unlike \code{\link[EDI:DesignFixedBernoulli]{DesignFixedBernoulli}},
		#'   where it is random).
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return  A new `DesignFixediBCRD` object
		initialize = function(
						response_type,
						prob_T = 0.5,
						include_is_missing_as_a_new_feature = TRUE,
						n = NULL,

						verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			if (!is.null(n)) {
				private$m = rep(1L, as.integer(n))
			}
		}
	),
	private = list(
		draw_ws_raw = function(r){
			private$maybe_set_seed()
			generate_permutations_ibcrd_cpp(
				as.integer(self$get_n()),
				as.integer(r),
				as.numeric(private$prob_T)
			)$w_mat
		}
	)
)
