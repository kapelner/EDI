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
#' shuffles (portable Fisher-Yates) a fresh copy of it
#' per replicate column, seeded from R's own RNG stream (so \code{seed} governs
#' reproducibility here).
#' \code{assign_w_to_all_subjects()} draws one such allocation (\code{r = 1}) and applies
#' it to all subjects.
#'
#' \strong{Rounding of the treated count.} \eqn{n_T} is R's \code{round(n * prob_T)},
#' which rounds a .5 tie to even (e.g. \code{n = 21}, \code{prob_T = 0.5} gives 10
#' treated), the same count \code{\link[EDI:DesignSeqOneByOneiBCRD]{DesignSeqOneByOneiBCRD}}
#' targets. The realized allocation and every randomization redraw come from the same
#' kernel, so they always agree. (Before v1.0.6 a .5 tie was rounded up here, giving 11
#' treated at \code{n = 21}.)
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
DesignFixediBCRD = define_design_class(
	classname = "DesignFixediBCRD",
	inherit = DesignFixed,
	components = "BlockingStructure",
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
		#' @param n The sample size. If \code{NULL} (default), \code{n} is set to
		#'   \code{nrow(X_all)} when the subjects are added with
		#'   \code{add_all_subjects_to_experiment()}; a given \code{n} must equal
		#'   \code{nrow(X_all)}. Assigning before the subjects are added needs \code{n}
		#'   (a covariate-free design such as iBCRD or Bernoulli can then assign without
		#'   \code{X}).
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
				private$blocking_capable = TRUE
				self$set_m(rep(1L, as.integer(n)))
			}
		}
	),
	private = list(
		draw_ws_raw = function(r){
			private$maybe_set_seed()
			# v1.0.6-TODO-234: n_T is R's round(n * prob_T) (half to even), the count
			# DesignSeqOneByOneiBCRD targets. The kernel rounds with std::round (half away
			# from zero), so hand it n_T / n: std::round(n * (n_T / n)) lands exactly on n_T.
			n = as.integer(self$get_n())
			n_T = round(n * private$prob_T)
			generate_permutations_ibcrd_cpp(
				n,
				as.integer(r),
				as.numeric(n_T / n)
			)$w_mat
		}
	)
)
