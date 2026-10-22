#' Batched complete random assignment within blocks (all draws at once)
#'
#' Draws an \code{n x r} 0/1 matrix whose columns are independent blocked
#' assignments with the same per-block law as \code{randomizr::block_ra(blocks,
#' prob = prob)}: in a block of size \code{N}, the number treated is
#' \code{floor(N * prob)} or \code{ceiling(N * prob)} (the latter with
#' probability equal to the fractional part; \code{floor} when
#' \code{ceiling(N * prob) == N} and \code{N > 1}; a singleton block is treated
#' with probability \code{prob}), and the treated set is a uniformly random
#' subset of that size. Vectorized across draws in a single R process using one
#' RNG stream, so the result depends only on the seed (never on the number of
#' cores). It is NOT bit-for-bit identical to a \code{replicate()} of
#' \code{block_ra} calls under the same seed (different RNG consumption order).
#' @keywords internal
#' @noRd
block_ra_batch = function(blocks, prob, r) {
	n = length(blocks)
	r = as.integer(r)
	w_mat = matrix(0, nrow = n, ncol = r)
	if (n == 0L || r == 0L) return(w_mat)
	groups = split(seq_len(n), blocks, drop = TRUE)
	draw_id = seq_len(r)
	for (idx in groups) {
		N = length(idx)
		m_floor = floor(N * prob)
		m_ceiling = ceiling(N * prob)
		if (N == 1L) {
			# singleton block: randomizr treats it as Bernoulli(prob) (the "floor when
			# ceiling == N" rule applies only to N > 1)
			w_mat[idx, ] = as.numeric(stats::runif(r) < prob)
			next
		}
		if (m_ceiling == N || m_ceiling == m_floor) {
			n_T = rep.int(m_floor, r)
		} else {
			n_T = m_floor + as.integer(stats::runif(r) < (N * prob - m_floor))
		}
		U = stats::runif(N * r)
		# within-column ranks of U: sort by (draw, U), then rank = position within draw
		col_id = rep(draw_id, each = N)
		o = order(col_id, U)
		rk = integer(N * r)
		rk[o] = rep.int(seq_len(N), r)
		w_mat[idx, ] = matrix(as.numeric(rk <= rep(n_T, each = N)), N, r)
	}
	w_mat
}

#' Largest divisor of n at most target (used for the default B_target of
#' \code{\link[EDI:DesignFixedBlocking]{DesignFixedBlocking}}, so the default always
#' satisfies \code{equal_block_sizes = TRUE} without needing to error).
#' @keywords internal
#' @noRd
largest_divisor_at_most = function(n, target) {
	for (b in as.integer(target):1L) {
		if (n %% b == 0L) return(b)
	}
	1L
}

#' A Fixed, Stratified-Block Randomized Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that first partitions
#' subjects into blocks (strata) formed from covariates, then randomizes treatment
#' \strong{independently within each block} at probability \code{prob_T} (via
#' the same per-block law as \code{\link[randomizr]{block_ra}}, drawn for all
#' \code{r} draws at once in vectorized R). Blocking on a covariate removes
#' its between-block variation from the treatment-effect comparison (comparisons are
#' always within-block), improving precision relative to unblocked randomization whenever
#' the blocking covariate(s) are prognostic of the outcome. See the section
#' \dQuote{How inference accounts for the blocks} for which inference routes respect the
#' blocks and which do not. This differs from
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
#' assigned independently with \code{\link[randomizr]{block_ra}}'s complete random
#' assignment law (subject to rounding, \code{prob_T} of each block's subjects are treated;
#' a fractional \code{N * prob_T} is rounded up with probability equal to its fractional
#' part). All \code{r} draws are generated in one batched, vectorized pass in the main
#' process from a single RNG stream, so results depend only on \code{seed}, never on
#' \code{set_num_cores()} (which parallelizes the statistic, not the draws). \code{draw_bootstrap_indices()} resamples
#' \emph{within} each block by default (\code{bootstrap_type = "within_blocks"} or
#' \code{NULL}, via \code{stratified_bootstrap_indices_cpp()}), or resamples whole blocks
#' with replacement otherwise (via \code{resample_group_rows_cpp()}) — mirroring the
#' block structure in the resampling scheme, analogous to the cluster-level bootstrap in
#' \code{DesignFixedBlockedCluster}.
#'
#' @section How inference accounts for the blocks:
#' \itemize{
#'   \item \strong{Block-aware:} randomization inference (re-draws within blocks),
#'     the bootstrap and the jackknife (resample within blocks), and the
#'     block-stratified tests \code{InferenceIncidCMH} and
#'     \code{InferenceIncidExtendedRobins}.
#'   \item \strong{Not block-aware:} the regression-type classes (OLS, Lin, robust,
#'     quantile, GLM, ordinal, survival regressions, ...) add \emph{no} block fixed
#'     effects automatically; the blocks enter the model only if the blocking column is
#'     itself supplied as a covariate. There is currently no option to add them.
#'   \item \strong{Unadjusted estimators.} If the same proportion is treated in every
#'     block, an unadjusted pooled estimator (e.g. the mean difference or OLS) stays
#'     unbiased and its asymptotic SE is conservative: it does not remove the
#'     between-block variance, so intervals over-cover and power is lost.
#'   \item \strong{Caveat: unequal allocation across blocks.} The per-block rule treats
#'     \code{floor(N * prob_T)} or \code{ceiling(N * prob_T)} subjects, and
#'     \code{floor} when \code{ceiling(N * prob_T) == N} (and \code{N > 1}). With
#'     \code{equal_block_sizes = TRUE} and moderate \code{prob_T} the proportion
#'     treated is essentially the same in all blocks, but with
#'     \code{equal_block_sizes = FALSE} (or a user-supplied \code{m}) very small blocks
#'     combined with a large \code{prob_T} are treated at a lower proportion than
#'     large blocks (e.g. \code{prob_T = 0.8}: a block of 2 treats exactly 1 subject).
#'     If block size or membership is also related to the outcome, the pooled
#'     treated-versus-control comparison is then confounded by block (Simpson's
#'     paradox) and \emph{the estimate itself} can be biased; adjust for blocks
#'     (include the blocking covariate(s) as factor covariates) in that case. A
#'     simulation (blocks of size 2, 20, 2, 20, block effects 2, 4, 6, 8,
#'     \code{prob_T = 0.8}, true effect 0) gave a mean OLS estimate of about 0.29.
#' }
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
		#'   If `NULL` (the default), all available covariate columns are used. Character and
		#'   factor columns form one stratum per level. A numeric column that is integer-valued
		#'   with at most 10 distinct values (for example a site code 1..4) is also treated as
		#'   categorical, one stratum per value; other numeric columns are quantile-binned into
		#'   `preferred_num_bins_for_continuous_covariate` bins. (Changed in 1.0.5: an integer
		#'   site code used to be binned, e.g. 4 sites into 2 blocks.)
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
		#'   are always preferred over later ones. Default: if you name `strata_cols`
		#'   explicitly and leave `B_target` unset, it behaves like `B_target = NULL`: ALL named
		#'   columns are used and the number of blocks is whatever their cross-classification
		#'   gives (named strata are never silently dropped, e.g. at prime `n`). Note that with
		#'   `equal_block_sizes = TRUE` this errors when the cells are not equal-sized (for
		#'   example 2 sex cells at odd `n`); set `equal_block_sizes = FALSE` or pass an
		#'   explicit `B_target`. If `strata_cols = NULL` (all covariates available) the default
		#'   is the largest divisor of `n` that is at most `floor(sqrt(n))` (so it always
		#'   satisfies `equal_block_sizes = TRUE`); if `n` is not yet known it is resolved to
		#'   `floor(sqrt(n))` when subjects are added. The same cap is used when
		#'   `exact_num_blocks = TRUE` and `B_target` is unset. Set `B_target = NULL` to use all
		#'   columns unconditionally. An explicitly supplied `B_target` that does not divide `n`
		#'   still errors immediately when `equal_block_sizes = TRUE`. (Changed in 1.0.5: before,
		#'   the sqrt-based cap also applied to named `strata_cols`.)
		#'   Set `exact_num_blocks = TRUE` to hard fail if the final key construction
		#'   does not produce exactly `B_target` blocks.
			#' @param exact_num_blocks Whether to require the greedy key construction to produce
			#'   exactly `B_target` blocks. Default `FALSE`.
			#' @param equal_block_sizes Whether to require all blocks to have the same number of
			#'   subjects. Default `TRUE`. When `TRUE` and both `n` and `B_target` are known at
			#'   construction time, an error is raised immediately if `n` is not divisible by
			#'   `B_target`. A second check fires when subjects are added: if the covariate-based
			#'   strata produce unequal block sizes the design errors at that point with a message
			#'   suggesting `equal_block_sizes = FALSE`. This is the usual outcome when named
			#'   `strata_cols` are used without `B_target` and the strata cells do not divide `n`. Set to
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
							B_target = NULL,
							exact_num_blocks = FALSE,
							equal_block_sizes = TRUE,
							m = NULL,
							verbose = FALSE,
					missingness_method = "impute",
					design_formula = ~ .,
					seed = NULL) {
				if (missing(B_target)) {
					# TODO-102: explicitly named strata_cols are never silently capped away; the
					# default cap applies only when strata_cols is NULL, or when exact_num_blocks
					# = TRUE (which needs a numeric target).
					B_target = if (!is.null(strata_cols) && !isTRUE(exact_num_blocks)) {
						NULL
					} else if (!is.null(n)) {
						largest_divisor_at_most(n, max(1L, floor(sqrt(n))))
					} else {
						NA_integer_
					}
				}
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

			strata_keys = self$get_block_ids()

			# Batched across draws (TODO-118); same per-block law as randomizr::block_ra.
			block_ra_batch(strata_keys, private$prob_T, r)
		}
		# draw_bootstrap_indices is provided by the BlockingStructure component (see
		# `components` above); proven byte-identical to this class's former hand-rolled
		# version via test-design-blocking-structure-bootstrap-golden.R before removal.
	)
)
