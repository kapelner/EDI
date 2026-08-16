#' A Stratified Permuted-Block Sequential Design (SPBR) with Fixed Block Size
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} implementing classical
#' stratified permuted-block randomization: subjects are assigned from a per-stratum
#' queue of pre-shuffled treatment labels (a "block" of \code{block_size} labels,
#' containing exactly \code{round(block_size * prob_T)} treated and the remainder
#' control, in random order), refilled with a fresh randomly-ordered block of the
#' \strong{same fixed size} whenever a stratum's queue empties. This is the
#' fixed-block-size, mandatory-stratification counterpart of
#' \code{\link[EDI:DesignSeqOneByOneRandomBlockSize]{DesignSeqOneByOneRandomBlockSize}}
#' (which varies block size across draws and makes stratification optional): here,
#' \code{strata_cols} is required, and a single fixed \code{block_size} is used for
#' every stratum and every block, guaranteeing exact treatment/control balance within
#' each stratum at every block boundary.
#'
#' @details
#' \strong{Block-size / \code{prob_T} compatibility.} \code{block_size} must yield an
#' integer number of treated subjects: the constructor errors unless
#' \code{abs(block_size * prob_T - round(block_size * prob_T)) <= 1e-10}.
#'
#' \strong{Per-stratum queues.} As in
#' \code{\link[EDI:DesignSeqOneByOneRandomBlockSize]{DesignSeqOneByOneRandomBlockSize}},
#' \code{private$strata_states} is a hashed environment mapping each stratum key
#' (concatenated \code{strata_cols} values, \code{"NA"} for missing) to the vector of
#' not-yet-used assignments remaining in that stratum's current block;
#' \code{assign_wt()} pops the next assignment, refilling with a fresh block when
#' empty. \code{draw_bootstrap_indices()} resamples within strata by default
#' (\code{bootstrap_type = "within_blocks"} or \code{NULL}) or resamples whole strata
#' otherwise.
#'
#' @references Zelen, M. (1974). "The randomization and stratification of patients to
#'   clinical trials." \emph{Journal of Chronic Diseases}, 27(7-8), 365-375,
#'   \doi{10.1016/0021-9681(74)90015-0}, for stratified permuted-block randomization.
#'   See also \href{https://en.wikipedia.org/wiki/Block_randomisation}{block
#'   randomisation} for orientation, and
#'   \code{\link[EDI:DesignSeqOneByOneRandomBlockSize]{DesignSeqOneByOneRandomBlockSize}}
#'   for the randomly-varying-block-size variant.
#' @examples
#' seq_des = DesignSeqOneByOneSPBR$new(strata_cols = 'x1', n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = factor(1, levels=1:2)))
#' @export
DesignSeqOneByOneSPBR = R6::R6Class("DesignSeqOneByOneSPBR",
	inherit = DesignSeqOneByOne,
	public = list(
		#' @description Initialize a stratified permuted-block sequential experimental
		#'   design with fixed block size (see class documentation for the exact
		#'   block-refill rule).
		#'
		#' @param strata_cols A character vector of column names to use for stratification.
		#' @param block_size The size of the permuted blocks (fixed; see class
		#'   documentation for its compatibility requirement with \code{prob_T}).
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Probability of treatment assignment.
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return  A new `DesignSeqOneByOneSPBR` object
		initialize = function(
						strata_cols,
						block_size = 4,
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
			private$blocking_capable = TRUE
			private$strata_cols = strata_cols
			private$block_size = as.integer(block_size)
			private$uses_covariates = TRUE
			private$strata_states = new.env(parent = emptyenv())
			
			if (should_run_asserts()) {
				if (abs(block_size * prob_T - round(block_size * prob_T)) > 1e-10) {
					stop("block_size must result in an integer number of treatment assignments (block_size * prob_T).")
				}
			}
		},
		#' @description Pop the next treatment assignment from the current subject's
		#'   stratum block queue (see class documentation), refilling that queue with
		#'   a freshly drawn fixed-size, randomly-ordered block first if it is empty.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			x_new = private$Xraw[private$t, ]
			key = private$get_strata_key(x_row = x_new)
			
			if (is.null(private$strata_states[[key]]) || length(private$strata_states[[key]]) == 0) {
				n_T = round(private$block_size * private$prob_T)
				n_C = private$block_size - n_T
				new_block = sample(c(rep(1, n_T), rep(0, n_C)))
				private$strata_states[[key]] = new_block
			}
			
			block = private$strata_states[[key]]
			w_t = block[1]
			private$strata_states[[key]] = block[-1]
			w_t
		}
	),
	private = list(
		strata_cols = NULL,
		block_size = NULL,
		strata_states = NULL,
		draw_ws_raw = function(r = 100){
			strata_keys = vapply(1:private$t, function(i) {
				private$get_strata_key(private$Xraw[i, ])
			}, character(1))

			generate_permutations_spbr_cpp(
				as.character(unname(strata_keys)),
				as.integer(private$block_size),
				as.numeric(private$prob_T),
				as.integer(r)
			)$w_mat
		},
		draw_bootstrap_indices = function(bootstrap_type = NULL){
			strata_keys = vapply(1:private$t, function(i) {
				private$get_strata_key(private$Xraw[i, ])
			}, character(1))
			if (is.null(bootstrap_type) || bootstrap_type == "within_blocks") {
				strata_ids = match(strata_keys, unique(strata_keys))
				list(i_b = stratified_bootstrap_indices_cpp(as.integer(strata_ids)), m_vec_b = NULL)
			} else {
				group_id = match(strata_keys, unique(strata_keys))
				i_b = resample_group_rows_cpp(as.integer(group_id), length(unique(group_id)))
				list(i_b = as.integer(i_b), m_vec_b = NULL)
			}
		},
		get_strata_key = function(x_row) {
			vals = vapply(private$strata_cols, function(col) {
				val = x_row[[col]]
				if (is.na(val)) "NA" else as.character(val)
			}, character(1))
			paste(vals, collapse = "|")
		}
	)
)
