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
#' \strong{Per-stratum queues.} \code{private$strata_states} is a named list
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
#' \strong{Jackknife.} \code{assign_wt()} records the permuted block each subject was
#' assigned from (and each block's stratum and drawn size), and the jackknife's automatic
#' deletion unit is that block (\code{unit = "permuted_block"}), the randomization unit of
#' this design. A stratum's trailing block that was not filled is merged into that
#' stratum's previous block, as on
#' \code{\link[EDI:DesignSeqOneByOneSPBR]{DesignSeqOneByOneSPBR}}; the variance pools the
#' replicates' spread within strata (the stratified jackknife of Wolter 2007, Sec. 4.5;
#' formulas in \code{\link[EDI:InferenceJackknife]{InferenceJackknife}}). Without
#' \code{strata_cols} all blocks form one stratum. The jackknife-Wald test and interval use
#' the t distribution with \eqn{\sum_h (n_h - 1)} degrees of freedom, \eqn{n_h} the number
#' of blocks in stratum \eqn{h}. Before EDI 1.0.6 a replicate deleted a
#' whole stratum (2-4 replicates on typical data, so the jackknife was \code{NA}), and a
#' design object saved before 1.0.6, which has no block record, still does
#' (v1.0.6-TODO-231).
#' When any stratum holds fewer than 10 permuted-block units, the automatic unit is one subject
#' within its stratum instead (\code{unit = "observation_within_block"}, the same stratified
#' jackknife with subjects as units): with few blocks in a stratum the permuted-block
#' jackknife-Wald test was too liberal (v1.0.6-TODO-270). An explicit
#' \code{unit = "permuted_block"} still deletes permuted blocks.
#'
#' @references Efron, B. (1971). "Forcing a sequential experiment to be balanced."
#'   \emph{Biometrika}, 58(3), 403-417, \doi{10.1093/biomet/58.3.403}, for sequential
#'   balanced-block randomization background. See also
#'   \href{https://en.wikipedia.org/wiki/Randomized_controlled_trial#Restricted}{block randomisation} for
#'   orientation on permuted-block designs and the selection-bias rationale for varying
#'   block size.
#' @examples
#' seq_des = DesignSeqOneByOneRandomBlockSize$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneRandomBlockSize = define_design_class(
	classname = "DesignSeqOneByOneRandomBlockSize",
	inherit = DesignSeqOneByOne,
	components = c("BlockingStructure", "SequentialStrataBootstrap"),
	overrides = list(private = "draw_bootstrap_indices"),
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
			private$sequential_bootstrap_whole_group = FALSE
			# v1.0.6-TODO-350: a plain list, not an environment. R6's clone(deep = TRUE) and the
			# v1.0.6-TODO-316 rollback snapshot copy fields by reference, so an environment was
			# shared with every copy and a copy's assignments advanced the original's queues.
			# A list is copied on modify. Keys get a "s:" prefix because a list element named ""
			# cannot be looked up.
			private$strata_states = list()
			
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
			key = paste0("s:", key)
			if (is.null(private$strata_states[[key]]) || length(private$strata_states[[key]]) == 0) {
				# Randomly choose next block size
				current_block_size = private$block_sizes[sample.int(length(private$block_sizes), 1L)]
				# Refill block
				n_T = round(current_block_size * private$prob_T)
				n_C = current_block_size - n_T
				new_block = sample(c(rep(1, n_T), rep(0, n_C)))
				private$strata_states[[key]] = new_block
				# v1.0.6-TODO-231: number the new block and remember its stratum and size, so the
				# jackknife can delete one permuted block at a time (block sizes are random, so the
				# blocks cannot be rebuilt afterwards from the enrolment order the way SPBR's are).
				private$permuted_block_keys = c(private$permuted_block_keys, key)
				private$permuted_block_sizes = c(private$permuted_block_sizes, as.integer(current_block_size))
				private$current_permuted_block_by_key[[key]] = length(private$permuted_block_keys)
			}
			# Pop one
			block = private$strata_states[[key]]
			w_t = block[1]
			private$strata_states[[key]] = block[-1]
			t = private$t
			if (length(t) == 1L && !is.na(t) && t >= 1L) {
				if (length(private$permuted_block_ids) < t) length(private$permuted_block_ids) = t
				private$permuted_block_ids[t] = as.integer(private$current_permuted_block_by_key[[key]] %||% NA_integer_)
			}
			w_t
		}
	),
	private = list(
		strata_cols = NULL,
		block_sizes = NULL,
		strata_states = NULL, # hash map of stratum -> vector of remaining assignments
		# v1.0.6-TODO-231: the permuted blocks as assign_wt() drew them. permuted_block_ids[t] is the
		# block of subject t; permuted_block_keys[b] / permuted_block_sizes[b] are block b's stratum key
		# and drawn size; current_permuted_block_by_key[[key]] is the stratum's block being filled.
		# A plain list/vectors (not an environment) so duplicate()'s shallow clone copies them.
		permuted_block_ids = integer(0),
		permuted_block_keys = character(0),
		permuted_block_sizes = integer(0),
		current_permuted_block_by_key = list(),
		draw_ws_raw = function(r = 100){
			strata_keys = if (private$uses_covariates) {
				vapply(seq_len(private$t), function(i) {
					private$get_strata_key(private$Xraw[i, ])
				}, character(1))
			} else {
				rep("overall", private$t)
			}
			w_mat = replicate(r, random_block_size_redraw_w_cpp(
				as.character(unname(strata_keys)),
				as.integer(private$block_sizes),
				as.numeric(private$prob_T)
			))
			matrix(as.numeric(w_mat), nrow = private$t, ncol = r)
		},
		sequential_bootstrap_whole_group = FALSE
	)
)
