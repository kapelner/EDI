#' A Fixed-Sample-Size Bernoulli (Independent-Coin-Flip) Randomized Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} in which each subject's
#' treatment assignment \eqn{w_i} is drawn independently as
#' \eqn{w_i \stackrel{iid}{\sim} \mathrm{Bernoulli}(p)}, \eqn{i = 1, \dots, n}, where
#' \eqn{p} is \code{prob_T}. This is the classical Bernoulli (independent-coin-flip)
#' randomized design: unlike
#' \code{\link[EDI:DesignFixediBCRD]{DesignFixediBCRD}} (complete randomization), which
#' fixes the number of treated subjects at exactly \eqn{\mathrm{round}(np)}, a Bernoulli
#' design leaves the realized number of treated subjects
#' \eqn{n_T = \sum_i w_i \sim \mathrm{Binomial}(n, p)} random; the trade-off is
#' independence across subjects (useful for some asymptotic/martingale arguments) at the
#' cost of not guaranteeing exact balance, which can matter for small \eqn{n} or for
#' inference procedures (e.g. exact permutation tests over a fixed number of treated) that
#' assume a fixed \eqn{n_T}.
#'
#' @details
#' \strong{Draw mechanism.} \code{draw_ws_raw(r)} delegates to
#' \code{generate_permutations_bernoulli_cpp()}, which fills an \eqn{n \times r} matrix of
#' independent \eqn{\mathrm{Bernoulli}(p)} draws (one column per requested replicate,
#' via a Mersenne Twister RNG seeded once per call from R's RNG state), so
#' \code{r} replicate allocation vectors are generated with a single C++ call rather than
#' \code{r} separate calls into R's own random-number generation.
#' \code{assign_w_to_all_subjects()} draws a single such allocation
#' (\code{r = 1}) and applies it to all subjects at once.
#'
#' \strong{No exchange/balance search.} Because subjects are treated independently, there
#' is no optimization step analogous to
#' \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}}: covariates, if supplied, do
#' not influence the assignment probabilities or realized allocation at all.
#'
#' @references Neyman, J. (1923, transl. 1990). "On the Application of Probability
#'   Theory to Agricultural Experiments." \emph{Statistical Science}, 5(4), 465-472, for
#'   the potential-outcomes framework under which Bernoulli and complete randomization are
#'   compared; see also
#'   \href{https://en.wikipedia.org/wiki/Randomized_experiment}{randomized experiment} for
#'   orientation on Bernoulli vs. complete (restricted) randomization.
#' @examples
#' des = DesignFixedBernoulli$new(n = 10, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10)))
#' des$assign_w_to_all_subjects()
#' @export
DesignFixedBernoulli = define_design_class(
	classname = "DesignFixedBernoulli",
	inherit = DesignFixed,
	components = character(),
	public = list(
		#' @description Characterization: this design draws each subject's treatment
		#'   assignment as an independent \eqn{\mathrm{Bernoulli}(p)} coin flip (see class
		#'   documentation), so it is Bernoulli-capable by construction.
		#' @return Always \code{TRUE} for this class.
		is_a_bernoulli_capable = function() TRUE,
		#' @description Initialize a fixed Bernoulli (independent-coin-flip) experimental
		#'   design. Unlike \code{\link[EDI:DesignFixediBCRD]{DesignFixediBCRD}}, the
		#'   realized number of treated subjects is not fixed at \code{n * prob_T}; it is
		#'   random (\eqn{\mathrm{Binomial}(n, prob\_T)}) because each subject's assignment
		#'   is an independent coin flip (see class documentation).
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Per-subject probability \eqn{p} that a given subject is
		#'   assigned to treatment; need not be \code{0.5} (unlike
		#'   \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}}).
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return  A new `DesignFixedBernoulli` object
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
		}
	),
	private = list(
		draw_ws_raw = function(r){
			private$maybe_set_seed()
			generate_permutations_bernoulli_cpp(
				as.integer(self$get_n()),
				as.integer(r),
				as.numeric(private$prob_T)
			)$w_mat
		}
	)
)
