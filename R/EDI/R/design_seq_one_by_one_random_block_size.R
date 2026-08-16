#' A Sequential Permuted-Block Design with Randomly Varying Block Sizes
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} implementing permuted-block
#' randomization with randomly varying block size: subjects are assigned from a queue
#' of pre-shuffled treatment labels (a "block"), refilled with a fresh
#' \code{\link[base]{sample}}d block whenever it empties. Each new block's size is
#' itself drawn uniformly at random from \code{block_sizes} (rather than being fixed),
#' and each block internally contains exactly \code{round(block_size * prob_T)} treated
#' and \code{block_size - round(block_size * prob_T)} control labels in random order.
#' Randomizing the block size (rather than using a single fixed block length, as in
#' classical permuted-block designs) is a standard clinical-trials safeguard against
#' \strong{selection bias}: with a fixed, known block size, unblinded staff could
#' predict the last assignment(s) in a block from the ones already observed, whereas an
#' unpredictable block size makes this much harder while still guaranteeing
#' near-perfect treatment/control balance throughout enrollment (balance is exact at
#' every block boundary and never worse than one full block's imbalance in between). If
#' \code{strata_cols} is supplied, a separate independent sequence of blocks is
#' maintained per stratum (one queue per distinct combination of \code{strata_cols}
#' values), so balance holds within each stratum, not just overall.
#'
#' @details
#' \strong{Block-size / \code{prob_T} compatibility.} Every entry of \code{block_sizes}
#' must yield an integer number of treated subjects when multiplied by \code{prob_T}
#' (checked at construction: \code{abs(bs * prob_T - round(bs * prob_T)) <= 1e-10} for
#' every \code{bs}); a block size that would require a fractional number of treated
#' subjects is rejected.
#'
#' \strong{Per-stratum queues.} \code{private$strata_states} is a hashed environment
#' mapping each stratum key (or the literal key \code{"overall"} when
#' \code{strata_cols} is \code{NULL}) to the vector of not-yet-used assignments
#' remaining in that stratum's current block; \code{assign_wt()} pops the next
#' assignment from the relevant queue, refilling it with a freshly drawn block (random
#' size, randomly ordered) whenever it is empty.
#'
#' \strong{Bootstrap.} \code{draw_bootstrap_indices()} resamples within strata (via
#' \code{stratified_bootstrap_indices_cpp()}) when \code{strata_cols} is supplied, or
#' performs a plain i.i.d. nonparametric bootstrap over subjects otherwise.
#'
#' @references Efron, B. (1971). "Forcing a sequential experiment to be balanced."
#'   \emph{Biometrika}, 58(3), 403-417, \doi{10.1093/biomet/58.3.403}, for sequential
#'   balanced-block randomization background. See also
#'   \href{https://en.wikipedia.org/wiki/Block_randomisation}{block randomisation} for
#'   orientation on permuted-block designs and the selection-bias rationale for varying
#'   block size.
#' @examples
#' seq_des = DesignSeqOneByOneRandomBlockSize$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneRandomBlockSize = R6::R6Class("DesignSeqOneByOneRandomBlockSize",
	inherit = DesignSeqOneByOne,
	public = list(
		#'
		#' @description Initialize a sequential permuted-block experimental design
		#'   with randomly varying block size (see class documentation for the exact
		#'   block-refill rule and its selection-bias rationale).
		#'
		#' @param strata_cols A character vector of column names to use for stratification. If
		#'   NULL, simple blocking is used.
		#' @param block_sizes A vector of positive integers representing the possible block sizes
		#'   to choose from.
		#' Each must be a multiple of the inverse of \code{prob_T} to ensure integer
		#' treatment/control counts.
		#' @param  response_type 	The data type of response values which must be one of the following:
		#' 								"continuous",
		#' 								"incidence",
		#' 								"proportion",
		#' 								"count",
		#' 								"survival",
		#' 								"ordinal".
		#' @param  prob_T  The probability of the treatment assignment. This defaults to \code{0.5}.
		#' @param include_is_missing_as_a_new_feature     If missing data is present in a variable,
		#'   should we include another dummy variable for its missingness? Default is \code{TRUE}.
		#' @param  n  		The sample size (if fixed). Default is \code{NULL} for not fixed.
		#' @param verbose A flag indicating whether messages should be displayed. Default is \code{FALSE}.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#' @return  A new `DesignSeqOneByOneRandomBlockSize` object
		#'
		initialize = function(
						strata_cols = NULL,
						block_sizes = c(4, 6, 8),
						response_type,
						prob_T = 0.5,
						include_is_missing_as_a_new_feature = TRUE,
						n = NULL,

						verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL) {
			if (should_run_asserts()) {
				assertIntegerish(block_sizes, lower = 1, any.missing = FALSE, min.len = 1)
			}
			
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$blocking_capable = TRUE
			private$strata_cols = strata_cols
			private$block_sizes = as.integer(block_sizes)
			private$uses_covariates = !is.null(strata_cols)
			private$strata_states = new.env(parent = emptyenv())
			
			# Validation for block sizes and prob_T
			for (bs in private$block_sizes) {
				if (should_run_asserts()) {
					if (abs(bs * prob_T - round(bs * prob_T)) > 1e-10) {
						stop("All block_sizes must result in an integer number of treatment assignments (bs * prob_T).")
					}
				}
			}
		},
		#' @description Pop the next treatment assignment from the current subject's
		#'   stratum block queue (see class documentation), refilling that queue with
		#'   a freshly drawn random-size, randomly-ordered block first if it is empty.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			key = "overall"
			if (private$uses_covariates) {
				x_new = private$Xraw[private$t, ]
				key = private$get_strata_key(x_row = x_new)
			}
			if (is.null(private$strata_states[[key]]) || length(private$strata_states[[key]]) == 0) {
				# Randomly choose next block size
				current_block_size = sample(private$block_sizes, 1)
				# Refill block
				n_T = round(current_block_size * private$prob_T)
				n_C = current_block_size - n_T
				new_block = sample(c(rep(1, n_T), rep(0, n_C)))
				private$strata_states[[key]] = new_block
			}
			# Pop one
			block = private$strata_states[[key]]
			w_t = block[1]
			private$strata_states[[key]] = block[-1]
			w_t
		}
	),
	private = list(
		strata_cols = NULL,
		block_sizes = NULL,
		strata_states = NULL, # hash map of stratum -> vector of remaining assignments
		draw_bootstrap_indices = function(bootstrap_type = NULL) {
			i_b = if (private$uses_covariates) {
				strata_keys = vapply(1:private$t, function(i) {
					private$get_strata_key(private$Xraw[i, ])
				}, character(1))
				strata_ids = match(strata_keys, unique(strata_keys))
				stratified_bootstrap_indices_cpp(as.integer(strata_ids))
			} else {
				sample_int_replace_cpp(private$t, private$t)
			}
			list(i_b = i_b, m_vec_b = NULL)
		},
		get_strata_key = function(x_row) {
			# Concatenate strata column values into a key string
			vals = vapply(private$strata_cols, function(col) {
				val = x_row[[col]]
				if (is.na(val)) "NA" else as.character(val)
			}, character(1))
			paste(vals, collapse = "|")
		}
	)
)
