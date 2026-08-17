#' Wei's (1977, 1978) Adaptive Urn Sequential Design, UD(\eqn{\alpha}, \eqn{\beta})
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} implementing Wei's
#' adaptive biased-coin urn design \eqn{UD(\alpha, \beta)}: conceptually, an urn starts
#' with \eqn{\alpha} balls of each type (treatment and control), and each assignment
#' is drawn proportionally to the current ball counts, then \eqn{\beta} balls of the
#' \strong{opposite} type to whatever was drawn are added back to the urn (so drawing
#' treatment adds \eqn{\beta} control balls, and vice versa), pushing subsequent draws
#' toward the under-represented arm. No covariates are used; only the running
#' treated/control counts \eqn{n_T}, \eqn{n_C} matter, via the closed-form assignment
#' probability
#' \deqn{\Pr(w_t = 1) = \frac{\alpha + \beta \, n_C}{2\alpha + \beta (n_T + n_C)}.}
#' Like \code{\link[EDI:DesignSeqOneByOneEfron]{DesignSeqOneByOneEfron}}, this design
#' balances running assignment counts online while remaining strictly randomized (the
#' probability is always strictly between 0 and 1 for finite \eqn{\alpha, \beta > 0});
#' unlike Efron's design (which only distinguishes "balanced" vs. "imbalanced" and
#' applies a single fixed \code{weighted_coin_prob} in the imbalanced case), the urn
#' design's bias toward the under-represented arm scales continuously and smoothly with
#' the current \emph{degree} of imbalance, tuned by the ratio \eqn{\beta/\alpha}: larger
#' \eqn{\beta/\alpha} yields stronger balancing pressure, and \eqn{\beta = 0} recovers a
#' fixed \eqn{\mathrm{Bernoulli}(0.5)} coin (no adaptation at all).
#'
#' @references Wei, L. J. (1977). "A class of designs for sequential clinical trials."
#'   \emph{Journal of the American Statistical Association}, 72(358), 382-386,
#'   \doi{10.1080/01621459.1977.10481006}; Wei, L. J. (1978). "The adaptive biased coin
#'   design for sequential experiments." \emph{The Annals of Statistics}, 6(1), 92-100,
#'   \doi{10.1214/aos/1176344068}. See also
#'   \href{https://en.wikipedia.org/wiki/Randomized_experiment}{randomized experiment}
#'   for orientation on adaptive biased-coin sequential designs.
#' @examples
#' seq_des = DesignSeqOneByOneUrn$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneUrn = define_design_class(
	classname = "DesignSeqOneByOneUrn",
	inherit = DesignSeqOneByOne,
	components = character(),
	public = list(
		#'
		#' @description Initialize Wei's UD(\eqn{\alpha}, \eqn{\beta}) adaptive urn
		#'   sequential experimental design (see class documentation for the exact
		#'   assignment-probability formula).
		#'
		#' @param alpha The initial number of balls of each type (Treatment/Control) in
		#'   the conceptual urn; larger \code{alpha} relative to \code{beta} weakens
		#'   the balancing effect (assignment probabilities stay closer to 0.5 for
		#'   longer).
		#' @param beta The number of balls of the \strong{opposite} type added to the
		#'   urn after each assignment; \code{beta = 0} recovers an unbiased
		#'   \eqn{\mathrm{Bernoulli}(0.5)} coin (no balancing).
		#' @param  response_type 	The data type of response values.
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#' @return  A new `DesignSeqOneByOneUrn` object
		#'
		initialize = function(
						alpha = 1,
						beta = 1,
						response_type,
						include_is_missing_as_a_new_feature = TRUE,
						n = NULL,

						verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			if (should_run_asserts()) {
				assertNumber(alpha, lower = 0)
				assertNumber(beta, lower = 0)
			}

			super$initialize(response_type, 0.5, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			
			private$alpha = alpha
			private$beta = beta
		},
		#' @description Draw the next subject's treatment assignment from Wei's
		#'   UD(\eqn{\alpha}, \eqn{\beta}) urn probability (see class documentation),
		#'   computed from the running treated/control counts.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			# Probability of Treatment based on current counts
			# In Wei's Urn, P(T) = (alpha + beta * nC) / (2 * alpha + beta * (nT + nC))
			# where nT and nC are current counts of assigned subjects.
			nT = sum(private$w == 1, na.rm = TRUE)
			nC = sum(private$w == 0, na.rm = TRUE)
			
			prob_T = (private$alpha + private$beta * nC) / (2 * private$alpha + private$beta * (nT + nC))
			
			rbinom(1, 1, prob_T)
		}
	),
	private = list(
		alpha = NULL,
		beta = NULL
	)
)
