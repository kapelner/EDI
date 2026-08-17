#' A Sequential Bernoulli (Independent-Coin-Flip) Randomized Design
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} in which each arriving
#' subject's treatment assignment is drawn independently as
#' \eqn{w_t \stackrel{iid}{\sim} \mathrm{Bernoulli}(prob\_T)}, with no dependence on
#' covariates or on prior assignments — the direct sequential-enrollment analog of
#' \code{\link[EDI:DesignFixedBernoulli]{DesignFixedBernoulli}}. As in the fixed-sample
#' version, the realized number of treated subjects after \eqn{t} arrivals is random
#' (\eqn{\mathrm{Binomial}(t, prob\_T)}), in contrast to sequential designs that
#' actively balance assignment counts or covariates (e.g.
#' \code{\link[EDI:DesignSeqOneByOneAtkinson]{DesignSeqOneByOneAtkinson}}).
#'
#' @examples
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneBernoulli = define_design_class(
	classname = "DesignSeqOneByOneBernoulli",
	inherit = DesignSeqOneByOne,
	components = character(),
	public = list(
		#' @description Characterization: this design draws each subject's treatment
		#'   assignment as an independent \eqn{\mathrm{Bernoulli}(prob\_T)} coin flip
		#'   (see class documentation), so it is Bernoulli-capable by construction.
		#' @return Always \code{TRUE} for this class.
		is_a_bernoulli_capable = function() TRUE,
		#' @description Initialize a Bernoulli (independent-coin-flip) sequential
		#'   experimental design.
		#'
		#' @param  response_type 	The data type of response values which must be one of the following:
		#' 								"continuous",
		#' 								"incidence",
		#' 								"proportion",
		#' 								"count",
		#' 								"survival",
		#' 								"ordinal".
		#' @param  prob_T  The probability of the treatment assignment. This defaults to \code{0.5}.
		#' @param include_is_missing_as_a_new_feature     If missing data is present in a variable,
		#'   should we include another dummy variable for its missingness? The default is \code{TRUE}.
		#' @param  n  		The sample size (if fixed). Default is \code{NULL}.
		#' @param verbose A flag indicating whether messages should be displayed.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#' @return  A new `DesignSeqOneByOneBernoulli` object
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
		},
		#' @description Draw the next subject's treatment assignment as a single
		#'   independent \eqn{\mathrm{Bernoulli}(prob\_T)} coin flip (see class
		#'   documentation); does not consult covariates or prior assignments.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			rbinom(1, 1, private$prob_T)
		}
	),
	private = list(
		draw_ws_raw = function(r = 100){
			generate_permutations_bernoulli_cpp(as.integer(private$t), as.integer(r), as.numeric(private$prob_T))$w_mat
		}
	)
)
