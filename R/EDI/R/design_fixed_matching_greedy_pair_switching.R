#' A Fixed, Matched-Pair Design with Greedy Which-Member-Treated Optimization
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that combines
#' \code{\link[EDI:DesignFixedBinaryMatch]{DesignFixedBinaryMatch}}'s non-bipartite
#' matched-pair structure with \code{\link[EDI:DesignFixedGreedy]{DesignFixedGreedy}}'s
#' greedy imbalance-minimization search, restricted so every move respects the pairing:
#' subjects are first paired by covariate closeness (as in
#' \code{DesignFixedBinaryMatch}), guaranteeing exactly one treated and one control
#' subject per pair; then, rather than assigning within-pair treatment status by a coin
#' flip, the greedy search (\code{greedy_design_search_cpp()}, pair-constrained mode)
#' chooses \emph{which} member of each pair is treated so as to directly minimize the
#' same aggregate covariate-imbalance objective as
#' \code{\link[EDI:DesignFixedGreedy]{DesignFixedGreedy}} (squared Mahalanobis distance
#' or sum of absolute standardized mean differences between the treated and control
#' group means) across the \emph{whole} sample, not just within each pair. This targets
#' both close within-pair matches (from the matching step) and low aggregate covariate
#' imbalance (from the greedy refinement) simultaneously — a strictly more constrained
#' search than plain \code{DesignFixedGreedy}, since only the \eqn{2^{n/2}}
#' which-member-treated assignments consistent with the fixed pairing are considered,
#' rather than all \eqn{\binom{n}{n/2}} balanced allocations.
#'
#' @details
#' \strong{Search algorithm.} Pairing is computed by
#' \code{compute_binary_match_structure()} exactly as in
#' \code{\link[EDI:DesignFixedBinaryMatch]{DesignFixedBinaryMatch}} (Mahalanobis or
#' Euclidean distance per \code{objective}), lazily on first draw and cached in
#' \code{private$bms}. Given the pairing, each replicate search initializes with a
#' random coin flip per pair (which member starts treated), then in exhaustive mode
#' (\code{n_iter = Inf}, default) repeatedly finds and applies the single pair-flip that
#' most decreases the imbalance objective, stopping at a strict local optimum (or runs
#' exactly \code{n_iter} random-pair stochastic flip-if-improving steps otherwise, with
#' patience-based early stopping) — the same two search modes as
#' \code{\link[EDI:DesignFixedGreedy]{DesignFixedGreedy}}, but with moves restricted to
#' "flip which side of a given pair is treated" rather than "swap any treated/control
#' pair of subjects." Random initialization and swap selection are seeded from R's own
#' RNG (via \code{greedy_design_search_cpp()}'s per-thread seeding), so \code{seed} does
#' govern reproducibility here.
#'
#' \strong{Pair-preserving bootstrap.} \code{draw_bootstrap_indices()} resamples whole
#' matched pairs (via \code{draw_matching_bootstrap_sample_cpp()}) rather than
#' individual subjects, since the greedy search only ever flips which member of a pair
#' is treated (never crosses pairs), so \eqn{w} always has exactly one treated subject
#' per pair — the pair, not the subject, is the exchangeable resampling unit.
#'
#' \strong{Constraints.} Only \code{prob_T = 0.5} is supported (the constructor errors
#' otherwise), and \code{n} must be divisible by 4 (\code{draw_ws_raw()} errors
#' otherwise); \code{n/2} matched pairs are formed regardless of parity, but the
#' additional divisible-by-4 requirement is enforced by this class specifically (unlike
#' \code{\link[EDI:DesignFixedBinaryMatch]{DesignFixedBinaryMatch}}, which only requires
#' even \code{n}).
#'
#' @references Krieger, A. M., Azriel, D., and Kapelner, A. (2019). "Nearly random
#'   designs with greatly improved balance." \emph{Biometrika}, 106(3), 695-701,
#'   \doi{10.1093/biomet/asz026}; Greevy, R., Lu, B., Silber, J. H., and Rosenbaum, P.
#'   (2004). "Optimal multivariate matching before randomization."
#'   \emph{Biostatistics}, 5(2), 263-275, \doi{10.1093/biostatistics/5.2.263}, for the
#'   matched-pair design this class refines.
#' @examples
#' \dontrun{
#' des = DesignFixedMatchingGreedyPairSwitching$new(n = 10, response_type = 'continuous')
#' }
#' @export
DesignFixedMatchingGreedyPairSwitching = define_design_class(
	classname = "DesignFixedMatchingGreedyPairSwitching",
	inherit = DesignFixed,
	components = c("MatchingStructure", "BatchWPregeneration"),
	overrides = list(
		public = "supports_batch_w_pregeneration",
		private = c("draw_bootstrap_indices", "ensure_matching_structure_computed")
	),
	public = list(
		#' @description Initialize a fixed design that performs binary matching followed
		#'   by greedy which-member-treated optimization (see class documentation).
		#'   Only \code{prob_T = 0.5} is supported, and \code{n} must be divisible by 4.
		#'
		#' @param response_type The data type of response values.
		#' @param prob_T The probability of treatment assignment. Must be \code{0.5}.
		#' @param include_is_missing_as_a_new_feature Flag for missingness indicators.
		#' @param n The sample size; must be divisible by 4.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param objective The covariate-imbalance objective to minimize when choosing
		#'   which pair member is treated: either \code{"mahal_dist"} (default, squared
		#'   Mahalanobis distance between treated/control means, also used as the
		#'   matching distance) or \code{"abs_sum_diff"} (sum of absolute standardized
		#'   mean differences); see class documentation for the exact criteria.
		#' @param n_iter Number of swap iterations. \code{Inf} (default) uses exhaustive
		#'   best-improvement search guaranteed to reach a strict local optimum. A positive
		#'   integer runs that many stochastic random-pair iterations with patience-based
		#'   early stopping.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return A new \code{DesignFixedMatchingGreedyPairSwitching} object.
		initialize = function(
				response_type,
				prob_T = 0.5,
				include_is_missing_as_a_new_feature = TRUE,
				n,
				verbose = FALSE,
				objective = "mahal_dist",
				n_iter = Inf,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			if (should_run_asserts()) {
				if (prob_T != 0.5) {
					stop("DesignFixedMatchingGreedyPairSwitching only supports balanced designs (prob_T = 0.5).")
				}
			}
			if (should_run_asserts()) {
				if (!is.infinite(n_iter) && (!is.numeric(n_iter) || length(n_iter) != 1L || n_iter <= 0 || n_iter != floor(n_iter)))
					stop("n_iter must be Inf or a positive integer")
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$objective = objective
			private$n_iter    = n_iter
			private$uses_covariates = TRUE
			private$blocking_capable = TRUE
			private$matching_capable = TRUE
		},
		#' @description Returns \code{TRUE} so the calling framework pre-generates all
		#'   replicate \code{w} vectors for a simulation cell in one batched call to
		#'   \code{greedy_design_search_cpp()}, paying the one-time \pkg{nbpMatching}
		#'   pairing cost once per cell (cached in \code{private$bms}) and reusing it
		#'   across all replicates and the OpenMP-parallelized greedy searches, rather
		#'   than recomputing the pairing per replicate.
		#'
		#' @return Always \code{TRUE} for this class.
		supports_batch_w_pregeneration = function() TRUE
	),
	private = list(
		objective = NULL,
		n_iter    = NULL,
		bms = NULL,
		ensure_pair_structure_computed = function(){
			if (is.null(private$bms)) {
				n = self$get_n()
				private$covariate_impute_if_necessary_and_then_create_model_matrix()
				if (is.null(private$X) || ncol(private$X) == 0) return(invisible(NULL))
				X = private$X[1:n, , drop = FALSE]
				private$bms = compute_binary_match_structure(X, mahal_match = (private$objective == "mahal_dist"))
			}
			if (!is.null(private$bms)) {
				pair_rows = private$bms$indicies_pairs
				m = integer(self$get_n())
				for (pair_id in seq_len(nrow(pair_rows))) m[pair_rows[pair_id, ]] = pair_id
				private$m = as.integer(m)
			}
			invisible(NULL)
		},
		ensure_matching_structure_computed = function(){
			private$ensure_pair_structure_computed()
		},
		draw_bootstrap_indices = function(bootstrap_type = NULL){
			# The greedy search only flips assignments within binary-match pairs
			# (pair_cur_t in greedy_design_search_cpp), so w always has exactly one
			# treated subject per pair: the exchangeable resampling unit is the pair.
			private$ensure_pair_structure_computed()
			if (is.null(private$bms)) {
				return(list(i_b = sample_int_replace_cpp(private$t, private$t), m_vec_b = NULL))
			}
			pair_rows = private$bms$indicies_pairs
			storage.mode(pair_rows) = "integer"
			draw_matching_bootstrap_sample_cpp(
				i_reservoir = integer(0),
				pair_rows = pair_rows,
				n_reservoir = 0L
			)
		},
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				assertCount(r, positive = TRUE)
				self$assert_all_subjects_arrived()
			}
			n = self$get_n()
			if (should_run_asserts()) {
				if (n %% 4 != 0) {
					stop("DesignFixedMatchingGreedyPairSwitching requires n divisible by 4.")
				}
			}
			private$covariate_impute_if_necessary_and_then_create_model_matrix()
			X = private$X[1:n, , drop = FALSE]
			private$ensure_pair_structure_computed()
			pairs_mat = private$bms$indicies_pairs
			storage.mode(pairs_mat) = "integer"
			cpp_n_iter = if (is.infinite(private$n_iter)) -1L else as.integer(private$n_iter)
			# Trusted unvalidated (fix_design_hierarchy.md, "AllocationMatrixValidation"):
			# greedy_design_search_cpp always returns exactly n x r valid {0,1} columns
			# by construction, so the post-search shape/finite/balance checks this class
			# used to run were dead code that never fired.
			greedy_design_search_cpp(
				X_raw          = X,
				r              = as.integer(r),
				objective      = private$objective,
				n_iter         = cpp_n_iter,
				indicies_pairs = pairs_mat
			)
		}
	)
)
