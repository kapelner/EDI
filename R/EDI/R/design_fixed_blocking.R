#' A Fixed, Stratified-Block Randomized Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that first partitions
#' subjects into blocks (strata) formed from covariates, then randomizes treatment
#' \strong{independently within each block} at probability \code{prob_T} (via
#' \code{\link[randomizr]{block_ra}} when \pkg{randomizr} is installed, else an internal
#' \code{generate_permutations_blocking_cpp()} fallback). Blocking on a covariate removes
#' its between-block variation from the treatment-effect comparison (comparisons are
#' always within-block), improving precision relative to unblocked randomization whenever
#' the blocking covariate(s) are prognostic of the outcome, at the cost of requiring the
#' analysis to account for the blocking structure (e.g. via a block/stratum fixed effect
#' or a CMH-type test). This differs from
#' \code{\link[EDI:DesignFixedBlockedCluster]{DesignFixedBlockedCluster}}, which
#' randomizes whole \emph{clusters} of subjects together within each block rather than
#' subjects individually.
#'
#' @details
#' \strong{Block construction.} Blocking keys are computed by
#' \code{private$get_strata_keys()} (shared across
#' blocking-structure designs): each column in
#' \code{strata_cols} contributes a categorical key (continuous columns are discretized
#' into \code{preferred_num_bins_for_continuous_covariate} quantile bins), and multiple
#' columns are combined into one composite block key per subject; if \code{strata_cols}
#' is \code{NULL}, all available covariate columns are used. \code{B_target} caps the
#' number of resulting blocks by greedily adding \code{strata_cols} in order only while
#' the running block count stays at or below the target (earlier columns take priority);
#' \code{exact_num_blocks = TRUE} instead hard-fails if the greedy construction does not
#' land on exactly \code{B_target} blocks. \code{equal_block_sizes = TRUE} (the default)
#' additionally requires every block to have the same subject count, checked once at
#' construction (via \code{n \%\% B_target}) if \code{n} and \code{B_target} are both
#' already known, and again once covariates arrive; some downstream inference classes
#' (\code{InferenceIncidCMH}, \code{InferenceIncidExtendedRobins}) require equal block
#' sizes unconditionally, regardless of this flag. An explicit \code{m} (one block ID per
#' subject) bypasses covariate-derived block construction entirely.
#'
#' \strong{Within-block randomization and bootstrap.} Within each block, treatment is
#' assigned independently via \code{\link[randomizr]{block_ra}}'s complete random
#' assignment (subject to rounding, \code{prob_T} of each block's subjects are treated);
#' the internal C++ fallback (\code{generate_permutations_blocking_cpp()}) is used only
#' if \pkg{randomizr} is not installed. \code{draw_bootstrap_indices()} resamples
#' \emph{within} each block by default (\code{bootstrap_type = "within_blocks"} or
#' \code{NULL}, via \code{stratified_bootstrap_indices_cpp()}), or resamples whole blocks
#' with replacement otherwise (via \code{resample_group_rows_cpp()}) — mirroring the
#' block structure in the resampling scheme, analogous to the cluster-level bootstrap in
#' \code{DesignFixedBlockedCluster}.
#'
#' @references Fisher, R. A. (1935). \emph{The Design of Experiments}. Oliver and Boyd,
#'   for the original rationale for blocking in randomized experiments; Cochran, W. G.,
#'   and Cox, G. M. (1957). \emph{Experimental Designs} (2nd ed.), Wiley, for stratified
#'   (randomized block) design theory. See also
#'   \href{https://en.wikipedia.org/wiki/Randomized_block_design}{randomized block
#'   design} for orientation.
#' @examples
#' des = DesignFixedBlocking$new(n = 20, response_type = 'continuous',
#'   strata_cols = 'x2', equal_block_sizes = FALSE)
#' X = data.frame(x1 = rnorm(20), x2 = factor(rep(1:2, 10)))
#' des$add_all_subjects_to_experiment(X)
#' des$assign_w_to_all_subjects()
#' @export
DesignFixedBlocking = define_design_class(
	classname = "DesignFixedBlocking",
	inherit = DesignFixed,
	components = "BlockingStructure",
	public = list(
		#' @description Initialize a fixed stratified-block randomized experimental
		#'   design. Block construction and validation follow the rules described in
		#'   the class documentation; see the parameter descriptions below for the
		#'   greedy \code{B_target}/\code{exact_num_blocks}/\code{equal_block_sizes}
		#'   contract.
		#'
		#' @param strata_cols A character vector of column names to use for stratification.
		#'   If `NULL` (the default), all available covariate columns are used.
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Probability of treatment assignment.
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param preferred_num_bins_for_continuous_covariate The number of quantile bins to use for continuous strata. Default is 2.
		#' @param B_target The target number of blocks. Columns from `strata_cols`
		#'   are added greedily in order, each column being included only if it does not push
		#'   the total number of unique blocks beyond this target. For categorical covariates
		#'   their natural levels are used; for continuous covariates
		#'   `preferred_num_bins_for_continuous_covariate` quantile bins are used. Earlier columns
		#'   are always preferred over later ones. The default is `floor(sqrt(n))` when `n`
		#'   is known at construction time, or is resolved to `floor(sqrt(n))` when subjects
		#'   are added. Set `B_target = NULL` to use all columns unconditionally.
		#'   Set `exact_num_blocks = TRUE` to hard fail if the final key construction
		#'   does not produce exactly `B_target` blocks.
			#' @param exact_num_blocks Whether to require the greedy key construction to produce
			#'   exactly `B_target` blocks. Default `FALSE`.
			#' @param equal_block_sizes Whether to require all blocks to have the same number of
			#'   subjects. Default `TRUE`. When `TRUE` and both `n` and `B_target` are known at
			#'   construction time, an error is raised immediately if `n` is not divisible by
			#'   `B_target`. A second check fires when subjects are added: if the covariate-based
			#'   strata produce unequal block counts the design errors at that point. Set to
			#'   `FALSE` to allow unequal blocks (note that `InferenceIncidCMH` and
			#'   `InferenceIncidExtendedRobins` still require equal block sizes regardless).
			#' @param m Optional integer vector of explicit block identifiers, one per subject.
			#'   If supplied, `n` must also be supplied and `length(m)` must equal `n`.
			#'   The constructor then records this blocking structure immediately via
			#'   `set_m()`, bypassing covariate-derived strata construction.
			#' @param verbose A flag for verbosity.
			#' @param missingness_method How to handle missing values in covariates.
			#' @param design_formula A formula object.
			#' @param seed Integer seed for reproducibility.
		#'
		#' @return  A new `DesignFixedBlocking` object
			initialize = function(
						strata_cols = NULL,
						response_type,
						prob_T = 0.5,
						include_is_missing_as_a_new_feature = TRUE,
						n = NULL,
						preferred_num_bins_for_continuous_covariate = 2,
							B_target = if (!is.null(n)) max(1L, floor(sqrt(n))) else NA_integer_,
							exact_num_blocks = FALSE,
							equal_block_sizes = TRUE,
							m = NULL,
							verbose = FALSE,
					missingness_method = "impute",
					design_formula = ~ .,
					seed = NULL) {
				if (should_run_asserts()) {
					if (!is.null(strata_cols)) assertCharacter(strata_cols, min.len = 1)
				assertCount(preferred_num_bins_for_continuous_covariate, positive = TRUE)
				if (!is.null(B_target) && !is.na(B_target)) assertCount(B_target, positive = TRUE)
					assertLogical(exact_num_blocks, len = 1)
					assertLogical(equal_block_sizes, len = 1)
					if (!is.null(m)) {
						if (is.null(n)) {
							stop("When supplying m to DesignFixedBlocking$new(), n must also be supplied.")
						}
						if (length(m) != as.integer(n)) {
							stop("When supplying m to DesignFixedBlocking$new(), length(m) must equal n.")
						}
					}
					if (isTRUE(equal_block_sizes) && !is.null(n) && !is.null(B_target) && !is.na(B_target)) {
						if (n %% B_target != 0L) {
							stop("equal_block_sizes = TRUE requires n to be divisible by B_target, but n = ",
							n, " is not divisible by B_target = ", B_target, ".")
					}
					private$assert_min_block_size(n, B_target)
				}
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$blocking_capable = TRUE
			private$strata_cols = strata_cols
			private$preferred_num_bins_for_continuous_covariate = preferred_num_bins_for_continuous_covariate
				private$B_target = B_target
				private$exact_num_blocks = exact_num_blocks
				private$equal_block_sizes = equal_block_sizes
				private$uses_covariates = TRUE
				if (!is.null(m)) {
					self$set_m(m)
				}
			}
	),
	private = list(
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
			}

			strata_keys = private$get_strata_keys()

			# Use randomizr::block_ra for canonical stratified blocking if available,
			# or fallback to our C++ implementation.
			if (check_package_installed("randomizr")) {
				w_mat = replicate(r, as.numeric(as.character(randomizr::block_ra(blocks = strata_keys, prob = private$prob_T))))
				storage.mode(w_mat) = "numeric"
				return(w_mat)
			}

			unique_keys = unique(strata_keys)
			strata_indices = lapply(unique_keys, function(key) which(strata_keys == key))

			res = generate_permutations_blocking_cpp(
				as.integer(self$get_n()),
				as.integer(r),
				as.numeric(private$prob_T),
				strata_indices
			)
			w_mat = res$w_mat
			storage.mode(w_mat) = "numeric"
			w_mat
		}
		# draw_bootstrap_indices is provided by the BlockingStructure component (see
		# `components` above); proven byte-identical to this class's former hand-rolled
		# version via test-design-blocking-structure-bootstrap-golden.R before removal.
	)
)
