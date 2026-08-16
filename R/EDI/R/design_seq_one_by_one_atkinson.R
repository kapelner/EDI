#' Atkinson's (1982) Covariate-Adjusted Biased Coin Sequential Design
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} that assigns each newly
#' arriving subject's treatment via Atkinson's (1982) \eqn{D_A}-optimum biased coin: a
#' coin whose treatment probability is skewed away from \code{prob_T} toward whichever
#' assignment would most improve the current design's efficiency for estimating the
#' treatment effect \eqn{D_A}-optimally, given the covariates observed so far. Compared
#' to a fixed-probability coin (e.g.
#' \code{\link[EDI:DesignSeqOneByOneBernoulli]{DesignSeqOneByOneBernoulli}}), this
#' improves covariate balance/estimation efficiency online without ever fully
#' determinizing the assignment (the coin is always strictly between 0 and 1, so
#' randomization-based inference remains valid), at the cost of requiring a numerically
#' well-conditioned design matrix to compute the bias.
#'
#' @details
#' \strong{Assignment rule.} For subject \eqn{t}, let \eqn{Z_{t-1} = [w_{1:t-1}, 1,
#' X_{1:t-1}]} be the (treatment, intercept, covariates) design matrix accumulated from
#' the first \eqn{t-1} subjects, and let \eqn{M = (t-1)(Z_{t-1}^\top Z_{t-1})^{-1}}.
#' Writing \eqn{x_t} for the new subject's covariate vector (with a leading 1 for the
#' intercept) and \eqn{A = M_{[1, 2:]} \cdot x_t} (the treatment row of \eqn{M},
#' projected onto \eqn{x_t}), the treatment probability is
#' \deqn{\pi_t = \frac{\big(M_{11}/A + 1\big)^2}{\big(M_{11}/A + 1\big)^2 + 1},}
#' clamped to \eqn{[0, 1]}, and subject \eqn{t} is assigned to treatment with
#' probability \eqn{\pi_t}. This is Atkinson's biased-coin formula for
#' \eqn{D_A}-optimal sequential design: the coin biases toward the assignment that
#' would most reduce the variance of the treatment-effect estimate under the linear
#' model implied by \eqn{Z_t}, converging toward more extreme (but never
#' fully deterministic) probabilities as the current covariate imbalance grows in
#' directions that matter for that estimate.
#'
#' \strong{Fallback to a fair(-ish) coin.} For the first
#' \code{ncol(private$Xraw) + 3} subjects (too few observations for
#' \eqn{Z_{t-1}^\top Z_{t-1}} to be reliably invertible), and whenever the C++
#' computation encounters a non-invertible design matrix, a non-finite bias term, or any
#' other numerical failure (caught via \code{tryCatch()}), assignment falls back to an
#' unbiased \eqn{\mathrm{Bernoulli}(prob\_T)} draw instead of Atkinson's rule.
#'
#' \strong{Reproducibility.} The per-subject C++ draw (\code{atkinson_assign_weight_cpp()})
#' seeds its own generator from R's RNG stream per call, so \code{seed} governs
#' reproducibility of the resulting assignment sequence in the usual way.
#'
#' @references Atkinson, A. C. (1982). "Optimum biased coin designs for sequential
#'   clinical trials with prognostic factors." \emph{Biometrika}, 69(1), 61-67,
#'   \doi{10.1093/biomet/69.1.61}. See also
#'   \href{https://en.wikipedia.org/wiki/Randomized_experiment}{randomized experiment}
#'   for orientation on biased-coin sequential designs.
#' @examples
#' seq_des = DesignSeqOneByOneAtkinson$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneAtkinson = R6::R6Class("DesignSeqOneByOneAtkinson",
	inherit = DesignSeqOneByOne,
	public = list(
		#' @description Initialize an Atkinson (1982) biased-coin sequential
		#'   experimental design (see class documentation for the assignment rule).
		#'
		#' @param  response_type 	The data type of response values.
		#' @param  prob_T  The nominal probability of treatment assignment; used as
		#'   the fallback coin probability early in the trial and whenever Atkinson's
		#'   rule cannot be computed (see class documentation), and as the reference
		#'   probability the biased coin is skewed away from otherwise.
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return 			A new `DesignSeqOneByOneAtkinson` object
		#'
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
			private$uses_covariates = TRUE
		},
		#' @description Draw the next subject's treatment assignment via Atkinson's
		#'   (1982) \eqn{D_A}-optimum biased coin (see class documentation for the
		#'   exact probability formula), falling back to an unbiased
		#'   \eqn{\mathrm{Bernoulli}(prob\_T)} draw early in the trial or on numerical
		#'   failure of the biased-coin computation.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			#if it's too early in the trial or if all the assignments are the same, then randomize
			if (private$t <= ncol(private$Xraw) + 2 + 1){
				rbinom(1, 1, private$prob_T)
			} else {
				all_subject_data = private$compute_all_subject_data()
				tryCatch({
					atkinson_assign_weight_cpp(
						private$w[1 : (private$t - 1)],
						all_subject_data$X_prev,
						all_subject_data$xt_prev,
						all_subject_data$rank_prev,
						private$t
					)
				}, error = function(e){
					rbinom(1, 1, private$prob_T)
				})
			}
		}
	),
	private = list(
		draw_ws_raw = function(r = 100){
			generate_permutations_atkinson_cpp(
				as.matrix(private$X[1:private$t, , drop = FALSE]),
				as.integer(private$t),
				as.integer(ncol(private$Xraw)),
				as.numeric(private$prob_T),
				as.integer(r)
			)$w_mat
		}
	)
)
