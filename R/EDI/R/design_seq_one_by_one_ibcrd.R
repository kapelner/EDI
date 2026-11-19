#' A Sequential Design Guaranteeing Exact Terminal Balance (Random Allocation Rule)
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} implementing the "random
#' allocation rule" (a sequential realization of complete randomization): treatment is
#' assigned to each arriving subject with probability equal to the fraction of
#' \strong{remaining treatment slots} among all remaining slots,
#' \eqn{\Pr(w_t = 1) = n_{T,\mathrm{rem}} / (n_{T,\mathrm{rem}} + n_{C,\mathrm{rem}})},
#' where \eqn{n_{T,\mathrm{rem}} = \mathrm{round}(n \cdot prob\_T) - n_T} and
#' \eqn{n_{C,\mathrm{rem}} = (n - \mathrm{round}(n \cdot prob\_T)) - n_C} are the
#' treatment/control slots not yet used, given the running counts \eqn{n_T}, \eqn{n_C}.
#' This guarantees the realized sequence, once all \eqn{n} subjects have arrived, has
#' \emph{exactly} \eqn{\mathrm{round}(n \cdot prob\_T)} treated subjects — the same
#' terminal allocation-count guarantee as
#' \code{\link[EDI:DesignFixediBCRD]{DesignFixediBCRD}}'s complete randomization, but
#' realized online as subjects arrive one at a time rather than all at once, and with
#' every prefix of the sequence itself drawn from the correct conditional (hypergeometric)
#' distribution given the slots used so far. If a slot type is exhausted
#' (\eqn{n_{T,\mathrm{rem}} \le 0} or \eqn{n_{C,\mathrm{rem}} \le 0}), the remaining
#' subjects are deterministically assigned to whichever type still has open slots.
#'
#' @details
#' \strong{\code{n} is required.} The rule balances toward the planned sample size, so
#' \code{n} must be supplied at construction; \code{n = NULL} is an error. When the
#' sample size is not known in advance, use
#' \code{\link[EDI:DesignSeqOneByOneBernoulli]{DesignSeqOneByOneBernoulli}} (or another
#' sequential design that does not need \code{n}). Before v1.0.6, \code{n = NULL} was
#' accepted and fell back to Bernoulli assignment, but the randomization draws still
#' forced exact balance, so its randomization distribution was wrong.
#'
#' \strong{Single implicit block.} \code{add_one_subject_to_experiment_and_assign()}
#' overrides the inherited method only to additionally set \code{private$m} to a
#' constant vector of 1s (a single block containing every subject enrolled so far)
#' after each assignment, mirroring the fixed-sample
#' \code{\link[EDI:DesignFixediBCRD]{DesignFixediBCRD}}'s single-block convention for
#' shared blocking/matching machinery.
#'
#' @references Rosenberger, W. F., and Lachin, J. M. (2016). \emph{Randomization in
#'   Clinical Trials: Theory and Practice} (2nd ed.), Wiley, for the random allocation
#'   rule as a sequential implementation of complete randomization. See also
#'   \code{\link[EDI:DesignFixediBCRD]{DesignFixediBCRD}} for the fixed-sample (all-at-once)
#'   version of the same terminal randomization law.
#' @examples
#' seq_des = DesignSeqOneByOneiBCRD$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneiBCRD = define_design_class(
	classname = "DesignSeqOneByOneiBCRD",
	inherit = DesignSeqOneByOne,
	components = "BlockingStructure",
	public = list(
		#' @description Initialize a sequential design targeting exact terminal
		#'   treatment/control balance (see class documentation for the assignment
		#'   rule).
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Target probability of treatment assignment; the terminal
		#'   number of treated subjects is fixed at \code{round(n * prob_T)} (see class
		#'   documentation).
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The planned (target) sample size, required (a positive integer): the
		#'   rule balances toward it. \code{NULL} is an error; use
		#'   \code{\link[EDI:DesignSeqOneByOneBernoulli]{DesignSeqOneByOneBernoulli}} when the
		#'   sample size is not known in advance.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return  A new `DesignSeqOneByOneiBCRD` object
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
			# v1.0.6-TODO-187: n is required (owner decision 2026-11-19). Checked even with
			# edi.run_asserts off: the assignment rule and the randomization redraw both
			# balance toward n, so there is nothing correct to do without it.
			if (is.null(n)) {
				stop("DesignSeqOneByOneiBCRD needs n: the random allocation rule balances toward a planned ",
					"sample size; use DesignSeqOneByOneBernoulli when n is unknown.", call. = FALSE)
			}
			checkmate::assertCount(n, positive = TRUE)
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$blocking_capable = TRUE
		},
		#' @description Add one subject to the experiment and assign treatment via
		#'   \code{assign_wt()} (delegating to the inherited
		#'   \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne$add_one_subject_to_experiment_and_assign()}}),
		#'   then set \code{private$m} to a single-block vector of 1s covering every
		#'   subject enrolled so far (see class documentation), overwritten on every
		#'   call rather than only once all subjects have arrived.
		#' @param x_new A data frame with one row representing the new subject's covariates.
		#' @return The treatment assignment (0 or 1) for the newly added subject.
		add_one_subject_to_experiment_and_assign = function(x_new){
			w_t = super$add_one_subject_to_experiment_and_assign(x_new)
			private$m = rep(1L, private$t)
			w_t
		},
		#' @description Draw the next subject's treatment assignment via the random
		#'   allocation rule (see class documentation): with probability equal to the
		#'   fraction of remaining treatment slots among all remaining slots, or a
		#'   deterministic assignment if one slot type is exhausted.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			# n is always set (the constructor requires it, v1.0.6-TODO-187).
			nT = sum(private$w == 1, na.rm = TRUE)
			nC = sum(private$w == 0, na.rm = TRUE)
			nT_rem = round(private$n * private$prob_T) - nT
			nC_rem = (private$n - round(private$n * private$prob_T)) - nC

			if (nT_rem <= 0) return(0)
			if (nC_rem <= 0) return(1)

			rbinom(1, 1, nT_rem / (nT_rem + nC_rem))
		}
	),
	private = list(
		draw_ws_raw = function(r = 100){
			# v1.0.6-TODO-183: one row per enrolled subject (t), like every other
			# sequential design. The rule balances toward the planned n, so draw full
			# n-subject sequences and keep their first t rows (the law of the subjects
			# enrolled so far); a no-op once the trial is complete.
			w_mat = generate_permutations_ibcrd_cpp(
				as.integer(self$get_n()),
				as.integer(r),
				as.numeric(private$prob_T)
			)$w_mat
			w_mat[seq_len(private$t), , drop = FALSE]
		}
	)
)
