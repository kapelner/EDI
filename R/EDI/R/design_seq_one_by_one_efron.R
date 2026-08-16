#' Efron's (1971) Biased Coin Sequential Design
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} implementing Efron's (1971)
#' biased coin: no covariates are used, only the running counts of treated
#' (\eqn{n_T}) and control (\eqn{n_C}) subjects assigned so far. If the counts are
#' currently equal, the next subject is assigned by a fair \eqn{\mathrm{Bernoulli}(0.5)}
#' coin; otherwise, the next subject is assigned to the currently
#' \strong{under-represented} group with probability \code{weighted_coin_prob}
#' (\eqn{> 0.5}, e.g. the classical \eqn{2/3}) and to the over-represented group with
#' probability \code{1 - weighted_coin_prob}. This keeps the running treatment/control
#' counts close to balanced throughout enrollment (unlike
#' \code{\link[EDI:DesignSeqOneByOneBernoulli]{DesignSeqOneByOneBernoulli}}, whose
#' running counts can drift arbitrarily far from balanced) while remaining strictly
#' randomized at every step (the coin is always strictly between
#' \code{1 - weighted_coin_prob} and \code{weighted_coin_prob}, never fully
#' deterministic), unlike a purely deterministic alternating allocation. This is a
#' count-balancing design only — it does not use covariates at all, in contrast to
#' \code{\link[EDI:DesignSeqOneByOneAtkinson]{DesignSeqOneByOneAtkinson}}/
#' \code{\link[EDI:DesignSeqOneByOneKK21]{DesignSeqOneByOneKK21}}, which bias the coin
#' toward covariate balance rather than (or in addition to) count balance.
#'
#' @references Efron, B. (1971). "Forcing a sequential experiment to be balanced."
#'   \emph{Biometrika}, 58(3), 403-417, \doi{10.1093/biomet/58.3.403}. See also
#'   \href{https://en.wikipedia.org/wiki/Randomized_experiment}{randomized experiment}
#'   for orientation on biased-coin sequential designs.
#' @examples
#' seq_des = DesignSeqOneByOneEfron$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneEfron = R6::R6Class("DesignSeqOneByOneEfron",
	inherit = DesignSeqOneByOne,
	public = list(
		#' @description Initialize an Efron (1971) biased coin sequential experimental
		#'   design (see class documentation for the exact assignment rule).
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Nominal probability of treatment assignment; used only as
		#'   the fair-coin probability when the running treated/control counts are
		#'   exactly equal (see \code{assign_wt()}).
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#' @param weighted_coin_prob The probability (\eqn{> 0.5}) of assigning the next
		#'   subject to whichever of treatment/control currently has fewer subjects,
		#'   when the running counts are unequal. Default \eqn{2/3}, the value from
		#'   Efron (1971).
		#'
		#' @return  A new `DesignSeqOneByOneEfron` object
		initialize = function(
						response_type,
						prob_T = 0.5,
						include_is_missing_as_a_new_feature = TRUE,
						n = NULL,

						verbose = FALSE,
						weighted_coin_prob = 2/3,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$weighted_coin_prob = weighted_coin_prob
		},
		#' @description Draw the next subject's treatment assignment via Efron's
		#'   (1971) biased coin (see class documentation): a fair coin if the running
		#'   treated/control counts are equal, otherwise a coin biased toward the
		#'   currently under-represented group at probability \code{weighted_coin_prob}.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			#if it's the first subject or if balance is equal, then Bernoulli
			nT = sum(private$w == 1, na.rm = TRUE)
			nC = sum(private$w == 0, na.rm = TRUE)
			
			if (nT == nC){
				private$assign_wt_Bernoulli()
			} else {
				#assign to the group with fewer subjects with probability weighted_coin_prob
				if (nT > nC){
					rbinom(1, 1, 1 - private$weighted_coin_prob)
				} else {
					rbinom(1, 1, private$weighted_coin_prob)
				}
			}
		}
	),
	private = list(
		weighted_coin_prob = NULL,
		draw_ws_raw = function(r = 100){
			generate_permutations_efron_cpp(
				as.integer(self$get_n()),
				as.integer(r),
				as.numeric(private$prob_T),
				as.numeric(private$weighted_coin_prob)
			)$w_mat
		}
	)
)
