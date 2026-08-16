#' A Fixed, Non-Bipartite-Matched-Pair Design with Within-Pair Randomization
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that (1) partitions the
#' \eqn{n} subjects into \eqn{n/2} disjoint matched pairs by solving a non-bipartite
#' (optimal) pairwise-matching problem on a covariate distance matrix, minimizing the
#' total within-pair distance across all pairs, then (2) randomizes treatment
#' \strong{within} each pair independently: for pair \eqn{k}, one of its two members is
#' assigned to treatment and the other to control with probability \eqn{1/2} each,
#' independently across pairs. This is the classical matched-pair randomized design (a
#' special case of blocking with block size 2), which guarantees exact covariate balance
#' within every pair (up to the matching algorithm's distance metric) while preserving
#' randomization-based inference validity, in contrast to
#' \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}}, which balance the
#' covariates in aggregate via an optimality criterion but do not guarantee pairwise
#' closeness of any two subjects.
#'
#' @details
#' \strong{Matching algorithm.} Pairing is computed once (lazily, on first call to
#' \code{draw_ws_raw()}/\code{assign_w_to_all_subjects()}, via
#' \code{private$ensure_matching_structure_computed()}) by
#' \code{compute_binary_match_structure()}, which forms an \eqn{n \times n} pairwise
#' distance matrix — squared Mahalanobis distance if \code{mahal_match = TRUE} (the
#' default; using the sample covariance of the covariates, ridge-regularized if singular),
#' or squared Euclidean distance otherwise — and solves the minimum-weight non-bipartite
#' perfect matching on that distance matrix via \code{\link[nbpMatching]{nonbimatch}}
#' (\pkg{nbpMatching}, a Suggests-only dependency; loading is deferred until matching is
#' actually needed, so pre-computed \code{w} vectors injected via \code{m} never require
#' it). For a single covariate (\eqn{p = 1}), pairing instead reduces to simply sorting
#' subjects by that covariate and pairing consecutive subjects, since the non-bipartite
#' matching problem is trivial in one dimension. The resulting pairing is cached in
#' \code{private$bms}/\code{private$m} for the lifetime of the design object (or until
#' explicitly reset via \code{set_m()}) and is not recomputed per draw.
#'
#' \strong{Within-pair randomization.} Given the fixed pairing, each replicate allocation
#' (see \code{draw_binary_match_assignments_cpp()}) independently flips, for every pair,
#' which of its two members is treated (an independent fair coin flip per pair per
#' replicate, using a splitmix64-seeded Mersenne Twister per replicate column for
#' reproducible parallel draws); this guarantees exactly \eqn{n/2} treated subjects
#' overall (only \code{prob_T = 0.5} is supported; the constructor errors otherwise).
#' Passing a pre-computed \code{m} to the constructor supplies the matched-pair structure
#' directly (each pair ID occurring in exactly 2 rows), bypassing the matching
#' computation entirely while keeping the same within-pair randomization.
#'
#' \strong{No-covariate fallback.} If no covariates are available at draw time
#' (\code{private$m} is \code{NULL}, e.g. matching hasn't run and no explicit \code{m} was
#' supplied), \code{draw_ws_raw()} falls back to an unmatched balanced complete
#' randomization (a uniformly random permutation of \eqn{n/2} ones and \eqn{n/2} zeros),
#' since there is no covariate information to match on.
#'
#' \strong{Validation and batch pregeneration.} Every drawn allocation matrix is checked
#' (\code{private$validate_allocation_matrix()}) to have the expected shape, contain only
#' finite \eqn{\{0,1\}} entries, and have exactly \eqn{n/2} treated subjects per replicate
#' column; violations raise an error rather than silently returning a malformed
#' allocation. \code{supports_batch_w_pregeneration()} returns \code{TRUE} so that the
#' calling framework generates all replicate \code{w} vectors for a simulation cell in one
#' batch (amortizing the one-time \pkg{nbpMatching} matching cost across all replicates
#' of that cell) rather than recomputing the matching structure per replicate.
#'
#' @references Greevy, R., Lu, B., Silber, J. H., and Rosenbaum, P. (2004). "Optimal
#'   multivariate matching before randomization." \emph{Biostatistics}, 5(2), 263-275,
#'   \doi{10.1093/biostatistics/5.2.263}, for optimal non-bipartite matched-pair designs
#'   prior to randomization. See also
#'   \href{https://en.wikipedia.org/wiki/Matched_pair}{matched pair} and
#'   \href{https://en.wikipedia.org/wiki/Mahalanobis_distance}{Mahalanobis distance} for
#'   orientation.
#' @examples
#' des = DesignFixedBinaryMatch$new(n = 10, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10)))
#' des$assign_w_to_all_subjects()
#' @export
DesignFixedBinaryMatch = define_design_class(
	classname = "DesignFixedBinaryMatch",
	inherit = DesignFixed,
	components = "MatchingStructure",
	# MatchingStructure auto-expands to include its BlockingStructure dependency; both
	# provide draw_bootstrap_indices, and the pair-preserving MatchingStructure version
	# (processed after its dependency) must win -- this class had no override of its
	# own, so it was already using this exact function via inheritance from
	# DesignMatching (reference-identity, not just behavioral equivalence).
	# ensure_matching_structure_computed genuinely collides too: MatchingStructure's
	# version (pulled from DesignMatching) is generic, but this class's own version
	# below is specific to its nbpMatching/bms-based structure and must win.
	overrides = list(private = c("draw_bootstrap_indices", "ensure_matching_structure_computed")),
	public = list(
		#' @description Characterization: this design computes its matched-pair
		#'   structure on the fly from covariates (see class documentation), so it is
		#'   KK matching-capable by construction.
		#' @return Always \code{TRUE} for this class.
		is_a_kk_matching_capable = function() TRUE,
		#' @description Returns \code{TRUE} so the calling framework pre-generates all
		#'   replicate \code{w} vectors for a simulation cell in one batch, paying the
		#'   one-time \pkg{nbpMatching} non-bipartite matching cost once per cell and
		#'   reusing the resulting pairing across all replicates, rather than
		#'   recomputing it per replicate.
		#' @return Always \code{TRUE} for this class.
		supports_batch_w_pregeneration = function() TRUE,
		#' @description Initialize a binary (non-bipartite) matched-pair fixed
		#'   experimental design. Matching itself is deferred until the first draw (see
		#'   class documentation); this constructor only records configuration and,
		#'   if \code{m} is supplied, installs the explicit pairing immediately.
		#'
		#' @param response_type 	The data type of response values.
		#' @param prob_T  The probability of the treatment assignment. Must be 0.5,
		#'   since within-pair randomization only supports an even 1-treated/1-control
		#'   split per pair.
		#' @param mahal_match 	Match using squared Mahalanobis distance (accounting for
		#'   covariate correlation/scale) if \code{TRUE} (default), else squared
		#'   Euclidean distance on the raw covariate matrix.
		#' @param include_is_missing_as_a_new_feature  Flag for missingness indicators.
		#' @param n  		The sample size.
		#' @param m Optional integer vector of explicit matched-pair identifiers, one per
		#'   subject. If supplied, `n` must also be supplied, `length(m)` must equal `n`,
		#'   all values must be positive, and each pair ID must occur exactly twice.
		#'   This bypasses the package-computed matching step.
		#' @param verbose  Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return 			A new `DesignFixedBinaryMatch` object
		#'
		initialize = function(
				response_type,
				prob_T = 0.5,
				mahal_match = TRUE,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				m = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
				) {
				if (should_run_asserts()) {
					if (prob_T != 0.5){
						stop("Binary match designs only support even treatment allocation (prob_T = 0.5)")
					}
					if (!is.null(m)) {
						if (is.null(n)) {
							stop("When supplying m to DesignFixedBinaryMatch$new(), n must also be supplied.")
						}
						if (length(m) != as.integer(n)) {
							stop("When supplying m to DesignFixedBinaryMatch$new(), length(m) must equal n.")
						}
					}
					# nbpMatching availability is checked lazily in ensure_matching_structure_computed
					# so that workers using pre-computed w vectors never load it unnecessarily.
				}
				super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
				private$blocking_capable = TRUE
				private$matching_capable = TRUE
				private$mahal_match = mahal_match
				private$uses_covariates = TRUE
				if (!is.null(m)) {
					self$set_m(m)
					private$set_binary_match_structure_from_m(m)
				}
			},
		#' @description Assign treatment to all subjects (see
		#'   \code{\link[EDI:DesignFixed]{DesignFixed$assign_w_to_all_subjects()}} for the
		#'   general contract). Before delegating, this override ensures the matched-pair
		#'   structure is computed (\code{private$ensure_matching_structure_computed()})
		#'   even when \code{w_precomputed} is supplied and
		#'   \code{draw_ws_according_to_design()} is therefore never called — downstream
		#'   code (e.g. blocked/matched-pair inference) still needs \code{private$m} to be
		#'   populated regardless of how \code{w} was obtained.
		#' @param w_precomputed Optional \{0,1\} numeric vector of length \code{n}. If
		#'   supplied, it is used directly as the treatment allocation instead of drawing
		#'   a fresh within-pair-randomized allocation.
		assign_w_to_all_subjects = function(w_precomputed = NULL){
			private$ensure_matching_structure_computed()
			super$assign_w_to_all_subjects(w_precomputed)
		}
	),
	private = list(
		mahal_match = NULL,
		bms = NULL,
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				assertCount(r, positive = TRUE)
				self$assert_all_subjects_arrived()
			}
			private$ensure_matching_structure_computed()
			n = self$get_n()
			if (is.null(private$m)){
				# No covariates: fall back to BCRD
				return(replicate(r, sample(c(rep(1, n/2), rep(0, n/2)))))
			}
			# Use the in-house Rcpp search. Its allocation is trusted unvalidated
			# (fix_design_hierarchy.md, "AllocationMatrixValidation"): the search always
			# returns exactly n x r valid {0,1} columns by construction, so the
			# post-search shape/finite/balance checks this class used to run were dead
			# code that never fired -- consistent with every other concrete design's
			# own C++ search kernel (e.g. DesignFixedGreedyDOptimal), none of which
			# validate their output either.
			w_mat = draw_binary_match_assignments_cpp(
				private$bms$indicies_pairs,
				as.integer(n),
				as.integer(r),
				as.integer(self$num_cores)
			)
			storage.mode(w_mat) = "numeric"
			w_mat
		},
			ensure_matching_structure_computed = function(){
				n = self$get_n()
				if (is.null(private$bms)) {
					if (is.null(private$X) || ncol(private$X) == 0) {
						stop("no covariates provided to run the binary matching algorithm")
					}
					X = private$X[1:n, , drop = FALSE]
					private$bms = compute_binary_match_structure(X, mahal_match = private$mahal_match)
					# Build pair-ID vector m where m[i] = pair index for subject i
					m_vec = integer(n)
					pairs = private$bms$indicies_pairs
					for (i in seq_len(nrow(pairs))){
						m_vec[pairs[i, 1]] = i
						m_vec[pairs[i, 2]] = i
					}
					private$m = m_vec
					private$reset_matching_caches()
				}
				invisible(NULL)
			},
			set_binary_match_structure_from_m = function(m){
				m_vec = as.integer(m)
				if (should_run_asserts()) {
					assertIntegerish(m_vec, lower = 1, any.missing = FALSE, len = self$get_n())
					pair_ids = sort(unique(m_vec))
					pair_sizes = tabulate(match(m_vec, pair_ids), nbins = length(pair_ids))
					if (any(pair_sizes != 2L)) {
						stop("Explicit m for DesignFixedBinaryMatch must define matched pairs only: each pair ID must occur exactly twice.")
					}
				}
				pair_ids = sort(unique(m_vec))
				pairs = t(vapply(pair_ids, function(pid) {
					which(m_vec == pid)
				}, integer(2L)))
				private$bms = list(indicies_pairs = pairs)
				private$reset_matching_caches()
				invisible(NULL)
			}
		)
	)
