#' Efron's (1971) Biased Coin Sequential Design
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} implementing Efron's (1971)
#' biased coin: no covariates are used, only the running counts of treated
#' (\eqn{n_T}) and control (\eqn{n_C}) subjects assigned so far. If the counts are
#' currently equal, the next subject is assigned by a fair \eqn{\mathrm{Bernoulli}(0.5)}
#' coin; otherwise, the next subject is assigned to the currently
#' \strong{under-represented} group with probability \code{weighted_coin_prob}
#' (in \eqn{(0.5, 1]}, e.g. the classical \eqn{2/3}) and to the over-represented group with
#' probability \code{1 - weighted_coin_prob}. This keeps the running treatment/control
#' counts close to balanced throughout enrollment (unlike
#' \code{\link[EDI:DesignSeqOneByOneBernoulli]{DesignSeqOneByOneBernoulli}}, whose
#' running counts can drift arbitrarily far from balanced). For
#' \code{weighted_coin_prob < 1} every step stays randomized (the coin is strictly
#' between \code{1 - weighted_coin_prob} and \code{weighted_coin_prob}). The limit
#' \code{weighted_coin_prob = 1} is allowed: it is deterministic whenever the counts are
#' unequal (the under-represented arm always gets the next subject), so the running
#' counts never differ by more than one and only the fair coin at a tie is random. This is a
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
DesignSeqOneByOneEfron = define_design_class(
	classname = "DesignSeqOneByOneEfron",
	inherit = DesignSeqOneByOne,
	components = character(),
	public = list(
		#' @description Initialize an Efron (1971) biased coin sequential experimental
		#'   design (see class documentation for the exact assignment rule).
		#'   There is no \code{prob_T} argument: allocation is always 1:1
		#'   (\code{prob_T = 0.5}) because the biased coin always pushes the treated count toward the control count, a 1:1 target.
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#' @param weighted_coin_prob The probability of assigning the next
		#'   subject to whichever of treatment/control currently has fewer subjects,
		#'   when the running counts are unequal: a single number with
		#'   \eqn{0.5 < p \le 1} (Efron's \eqn{p > 1/2}); other values error. \eqn{p = 1}
		#'   is the deterministic limit (see class documentation). Default \eqn{2/3}, the
		#'   value from Efron (1971).
		#'
		#' @return  A new `DesignSeqOneByOneEfron` object
		initialize = function(
						response_type,
						include_is_missing_as_a_new_feature = TRUE,
						n = NULL,

						verbose = FALSE,
						weighted_coin_prob = 2/3,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			# v1.0.6-TODO-33: the docs promised p > 0.5 but nothing checked it; a p outside
			# (0.5, 1] gave NA draws (p > 1) or a coin that pushes toward imbalance (p < 0.5).
			# p = 1 (the deterministic limit) stays valid; tests rely on it.
			if (!is.numeric(weighted_coin_prob) || length(weighted_coin_prob) != 1L || is.na(weighted_coin_prob) ||
					!(weighted_coin_prob > 0.5 && weighted_coin_prob <= 1)) {
				stop("weighted_coin_prob must be a single number with 0.5 < weighted_coin_prob <= 1.", call. = FALSE)
			}
			super$initialize(response_type, 0.5, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
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
			# v1.0.6-TODO-129: one row per enrolled subject (t), like every other
			# sequential design; the coin depends only on the running counts, so a t-row
			# replay has the law of the first t subjects. Identical to n once complete.
			generate_permutations_efron_cpp(
				as.integer(private$t),
				as.integer(r),
				as.numeric(private$prob_T),
				as.numeric(private$weighted_coin_prob)
			)$w_mat
		}
	)
)
