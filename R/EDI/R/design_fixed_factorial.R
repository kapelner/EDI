#' A Fixed, Balanced Two-Arm Factorial Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} for factorial
#' treatment structures: subjects are assigned to one of the cells of a factorial
#' combination of one or more named factors (e.g. \code{list(treatment = 2)},
#' or, once multi-arm support lands, \code{list(drug = 2, dose = 2)} for a
#' \eqn{2 \times 2} design), with assignment counts balanced as evenly as possible
#' across cells within each replicate draw.
#'
#' \strong{Currently restricted to exactly two total factor-level combinations} (i.e.
#' two arms), e.g. a single two-level factor — the product of levels across all
#' \code{factors} entries must equal exactly 2; the constructor errors otherwise. In this
#' two-arm regime, the design reduces to a balanced complete randomization between cell 1
#' (\eqn{w = 0}) and cell 2 (\eqn{w = 1}), and \code{w} follows the same \{0,1\}
#' internal / \{-1,+1\} public convention as every other \code{Design} subclass, so
#' \code{DesignFixedFactorial} inherits \code{assign_w_to_all_subjects()},
#' \code{draw_ws_according_to_design()}, and \code{get_w()} unmodified from
#' \code{\link[EDI:DesignFixed]{DesignFixed}}/\code{\link[EDI:Design]{Design}} and works
#' unmodified with every \code{\link[EDI:Inference]{Inference}} class; only
#' \code{draw_ws_raw()} (the low-level allocation-vector generator) and
#' \code{get_w_factorial()} (an additional factor-level accessor, see below) are
#' specific to this class. Support for more than two combinations (true multi-factor,
#' multi-arm designs) is tracked separately — see
#' \code{package_metadata/new_feature_plans/multi_arm_designs.md}.
#'
#' @details
#' \strong{Allocation generation.} \code{draw_ws_raw(r)} builds a base allocation vector
#' by repeating the sequence of cell indices \code{0:(num_combinations - 1)} out to
#' length \eqn{n} (so cells are as close to equally represented as possible, off by at
#' most one subject when \eqn{n} is not a multiple of the number of cells), then
#' independently permutes ( \code{\link[base]{sample}}) that base vector once per
#' replicate column to produce \code{r} balanced-but-randomized allocations.
#'
#' @examples
#' des = DesignFixedFactorial$new(n = 12, response_type = 'continuous', factors = list(treatment = 2))
#' des$add_all_subjects_to_experiment(data.frame(x=1:12))
#' des$assign_w_to_all_subjects()
#' @export
DesignFixedFactorial = R6::R6Class("DesignFixedFactorial",
	inherit = DesignFixed,
	public = list(
		#' @description Initialize a factorial fixed experimental design. The product
		#'   of levels implied by \code{factors} must currently equal exactly 2 (see
		#'   class documentation); any other total raises an error.
		#'
		#' @param factors         A list where names are factor names and values are number of
		#'   levels (e.g. list(treatment = 2)). The product of levels across all factors must
		#'   currently equal exactly 2 (two-arm only).
		#' @param response_type 	The data type of response values.
		#' @param include_is_missing_as_a_new_feature  Flag for missingness indicators.
		#' @param n  		The sample size.
		#' @param verbose  Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return 			A new `DesignFixedFactorial` object
		initialize = function(
				factors,
				response_type,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,

				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			if (should_run_asserts()) {
				assertList(factors, types = "numeric", min.len = 1)
			}
			# We don't use prob_T in the standard way here, as we have multiple factors
			# But base Design needs it. We'll set it to 0.5.
			super$initialize(response_type, 0.5, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$factors = factors

			# Precompute all combinations
			private$combinations = expand.grid(lapply(factors, function(l) 1:l))
			private$num_combinations = nrow(private$combinations)
			if (should_run_asserts()) {
				if (private$num_combinations != 2L) {
					stop(
						"DesignFixedFactorial currently only supports exactly two total factor-level ",
						"combinations (two-arm only), e.g. a single two-level factor. The supplied ",
						"'factors' argument implies ", private$num_combinations, " combinations."
					)
				}
			}
		},
		#' @description Decode each subject's scalar cell index (\code{private$w}, in
		#'   \code{0:(num_combinations - 1)}) back into its per-factor level
		#'   assignments, using the same \code{\link[base]{expand.grid}} enumeration
		#'   (\code{private$combinations}) established at construction. This is the
		#'   inverse of the encoding \code{draw_ws_raw()} produces, and is the only way
		#'   to recover individual factor levels once support for more than two total
		#'   combinations lands, since \code{get_w()} (inherited, see class
		#'   documentation) only ever returns the scalar 0/1 (or -1/+1) cell index.
		#'
		#' @return A data frame with \code{n} rows and one column per entry of
		#'   \code{factors}, giving each subject's level (an integer in
		#'   \code{1:levels}) for that factor; \code{NULL} if treatment has not yet
		#'   been assigned to all subjects (i.e. \code{private$w} is empty or contains
		#'   \code{NA}).
		get_w_factorial = function(){
			w_idx = private$w
			if (length(w_idx) == 0 || any(is.na(w_idx))) return(NULL)
			private$combinations[w_idx + 1L, , drop = FALSE]
		}
	),
	private = list(
		factors = NULL,
		combinations = NULL,
		num_combinations = NULL,
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
			}
			n = self$get_n()
			# Standard balanced two-arm factorial: each of the two combinations appears n/2 times.
			# {0,1} storage matches the shared Design/DesignFixed convention (see get_w()/
			# assign_w_to_all_subjects() on the base classes, which this class now inherits
			# unmodified) so every Inference class works against this design unchanged.
			base_alloc = rep(0:(private$num_combinations - 1L), length.out = n)
			w_mat = matrix(NA_integer_, nrow = n, ncol = r)
			for (j in 1:r){
				w_mat[, j] = sample(base_alloc)
			}
			w_mat
		}
	)
)
