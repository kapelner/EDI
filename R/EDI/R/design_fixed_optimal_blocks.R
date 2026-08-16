#' A Fixed, Covariate-Homogeneous-Block Randomized Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that first partitions
#' subjects into \code{B} approximately equal-sized, covariate-homogeneous blocks by
#' (approximately or exactly) minimizing total within-block pairwise covariate distance
#' \eqn{\sum_{k=1}^{B} \sum_{i, j \in \text{block } k, i < j} D(x_i, x_j)}, then
#' randomizes treatment independently within each resulting block at probability
#' \code{prob_T} (via \code{\link[randomizr]{block_ra}}, the same mechanism as
#' \code{\link[EDI:DesignFixedBlocking]{DesignFixedBlocking}}). Unlike
#' \code{DesignFixedBlocking}, which forms blocks from user-specified column-wise
#' strata (categorical levels / quantile bins), here blocks are formed directly from a
#' multivariate distance/clustering criterion over all covariates jointly, so this
#' design generalizes matched-pair designs
#' (\code{\link[EDI:DesignFixedBinaryMatch]{DesignFixedBinaryMatch}}) from block size 2
#' to arbitrary block size \eqn{B}. When \code{B} is omitted and \code{n} is known
#' at initialization, the default is \code{floor(sqrt(n))}, truncated below at 1 (the
#' usual heuristic block count for balancing within-block homogeneity against
#' within-block sample size).
#'
#' @details
#' \strong{Block-formation algorithms.} \code{method} selects among three block
#' construction strategies with different exactness/scalability trade-offs (see the
#' \code{new()} argument documentation for details): \code{"K-way"} (default, balanced
#' k-means-style anticlustering via \pkg{anticlust}, fast and empirically close to
#' optimal), \code{"greedy"} (nearest-neighbor greedy matching via \pkg{blockTools},
#' fast even for large \eqn{n}), and \code{"ompr"} (an exact mixed-integer program
#' solved with GLPK via \pkg{ompr}/\pkg{ompr.roi}, globally optimal but scaling as
#' \eqn{O(n^2 B)} in the number of decision variables — practical only for small
#' \eqn{n}). Block membership is computed lazily (on first draw, via
#' \code{get_or_compute_block_ids()}) and cached in \code{private$block_ids} for reuse
#' across replicates.
#'
#' \strong{Distance specification (\code{"ompr"} only).} \code{dist} selects the
#' pairwise distance \eqn{D(x_i, x_j)} the exact solver minimizes:
#' \code{"euclidean"}, \code{"sum_abs_diff"} (sum of absolute coordinate differences),
#' \code{"mahal"} (default, Mahalanobis distance accounting for covariate
#' correlation/scale), or a user-supplied distance function. The \code{"K-way"} and
#' \code{"greedy"} methods use their own respective packages' built-in distance
#' conventions and do not consult \code{dist}.
#'
#' \strong{No-covariate fallback.} If the covariate matrix has zero columns, block
#' membership is assigned by simple round-robin (\code{rep(seq_len(B), length.out = n)})
#' rather than by any of the three clustering algorithms, since there is no covariate
#' information to cluster on.
#'
#' \strong{Bootstrap.} \code{draw_bootstrap_indices()} resamples within blocks by
#' default (\code{bootstrap_type = "within_blocks"} or \code{NULL}, via
#' \code{stratified_bootstrap_indices_cpp()}) or resamples whole blocks otherwise (via
#' \code{resample_group_rows_cpp()}), mirroring the block structure in the resampling
#' scheme, as in \code{\link[EDI:DesignFixedBlocking]{DesignFixedBlocking}}.
#'
#' @references Higgins, M. J., Sävje, F., and Sekhon, J. S. (2016). "Improving massive
#'   experiments with threshold blocking." \emph{Proceedings of the National Academy of
#'   Sciences}, 113(27), 7369-7376, \doi{10.1073/pnas.1510504113}, for optimal/near-optimal
#'   covariate-based blocking prior to randomization. See also
#'   \href{https://en.wikipedia.org/wiki/Randomized_block_design}{randomized block
#'   design} for orientation and
#'   \href{https://en.wikipedia.org/wiki/Mahalanobis_distance}{Mahalanobis distance} for
#'   the default \code{"ompr"} distance.
#' @examples
#' des = DesignFixedOptimalBlocks$new(n = 9, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x = rnorm(9)))
#' des$assign_w_to_all_subjects()
#' @export
DesignFixedOptimalBlocks = define_design_class(
	classname = "DesignFixedOptimalBlocks",
	inherit = DesignFixed,
	components = "BlockingStructure",
	public = list(
			#' @description Returns \code{TRUE} so the calling framework pre-generates
			#'   all replicate \code{w} vectors for a simulation cell in one batch,
			#'   paying the one-time block-formation cost (K-way anticlustering,
			#'   greedy matching, or the exact \pkg{ompr}/GLPK solve) once per cell and
			#'   reusing the resulting block assignment across replicates, rather than
			#'   recomputing it per replicate.
			#'
			#' @return Always \code{TRUE} for this class.
			supports_batch_w_pregeneration = function() TRUE,
			#' @description Initialize a fixed optimal-blocks design. Block formation
			#'   itself is deferred until the first draw (see class documentation);
			#'   this constructor only validates and records configuration, including
			#'   checking that \code{B} (or its \code{floor(sqrt(n))} default) admits a
			#'   feasible block-size partition of \code{n} when \code{n} is already
			#'   known.
			#' @param B Number of blocks to form. If omitted and \code{n} is supplied,
			#'   defaults to \code{floor(sqrt(n))}, with a minimum of 1.
			#' @param method Algorithm used to partition subjects into blocks.
			#'   \describe{
			#'     \item{\code{"K-way"} (default)}{Balanced k-means anticlustering via
			#'       \code{anticlust::balanced_clustering}.  Requires the
			#'       \pkg{anticlust} package.  Produces well-spread blocks and is
			#'       significantly faster than \code{"greedy"} (e.g., ~10x faster
			#'       for \eqn{n=200, p=10, B=10}) while achieving a better
			#'       within-block distance objective (e.g., ~4\% lower).}
			#'     \item{\code{"greedy"}}{Greedy nearest-neighbour matching
			#'       via \code{blockTools::block}.  Requires the \pkg{blockTools}
			#'       package.  Fast even for large \eqn{n}.}
			#'     \item{\code{"ompr"}}{Exact mixed-integer programme solved with
			#'       GLPK via \pkg{ompr}.  Globally optimal but scales as
			#'       \eqn{O(n^2 B)} in variables and is only practical for small
			#'       \eqn{n}.}
			#'   }
			#' @param dist Distance specification used only when \code{method = "ompr"}.
			#'   Either a function or one of \code{"euclidean"}, \code{"sum_abs_diff"},
			#'   or \code{"mahal"}. Default is \code{"mahal"}.
			#' @param response_type The response type for the design.
			#' @param prob_T Treatment assignment probability within each block.
			#' @param include_is_missing_as_a_new_feature Whether to include missingness indicators.
			#' @param n Planned sample size.
			#' @param verbose Whether to print progress messages.
			#' @param missingness_method How to handle missing values in covariates.
			#' @param design_formula A formula object.
			#' @param seed Integer seed for reproducibility.
			#' @return A new \code{DesignFixedOptimalBlocks} object.
			initialize = function(
				B = NULL,
				method = "K-way",
				dist = "mahal",
				response_type,
				prob_T = 0.5,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
				if (should_run_asserts()) {
					assertChoice(method, c("ompr", "greedy", "K-way"))
				}
				if (should_run_asserts()) {
					if (method == "ompr") {
						if (!(is.function(dist) || (is.character(dist) && length(dist) == 1L)))
							stop("dist must be a function or one of 'euclidean', 'sum_abs_diff', or 'mahal'.")
						if (is.character(dist))
							assertChoice(dist, c("euclidean", "sum_abs_diff", "mahal"))
						assert_optimal_blocks_libraries_installed("DesignFixedOptimalBlocks with method='ompr'")
					} else if (method == "greedy") {
						assert_blocktools_installed("DesignFixedOptimalBlocks with method='greedy'")
					} else {
						assert_anticlust_installed("DesignFixedOptimalBlocks with method='K-way'")
					}
				}
				if (is.null(B)) {
					if (is.null(n)) {
						if (should_run_asserts()) {
							stop("DesignFixedOptimalBlocks requires B when n is not supplied.")
						}
					}
					B = max(1L, floor(sqrt(as.integer(n))))
				}
				if (should_run_asserts()) {
					assertCount(B, positive = TRUE)
				}
				super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
				private$blocking_capable = TRUE
				private$B      = as.integer(B)
				private$method = method
				private$dist_spec = dist
				private$uses_covariates = TRUE
				if (!is.null(n))
					if (should_run_asserts()) {
						private$assert_feasible_block_sizes(as.integer(n))
					}
			}
	),
	private = list(
		B = NULL,
		method = NULL,
		dist_spec = NULL,
		block_ids = NULL,
		distance_matrix = NULL,
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
			}
			block_ids = private$get_or_compute_block_ids()
			w_mat = replicate(r, as.numeric(as.character(randomizr::block_ra(blocks = block_ids, prob = private$prob_T))))
			storage.mode(w_mat) = "numeric"
			w_mat
		},
		# draw_bootstrap_indices is provided by the BlockingStructure component (see
		# `components` above); proven byte-identical to this class's former hand-rolled
		# version via test-design-blocking-structure-bootstrap-golden.R before removal.
		assert_feasible_block_sizes = function(n){
			private$assert_min_block_size(n, private$B)
			invisible(NULL)
		},
		get_or_compute_block_ids = function(){
			if (!is.null(private$block_ids)) {
				return(private$block_ids)
			}
			n = self$get_n()
			if (should_run_asserts()) {
				private$assert_feasible_block_sizes(n)
			}
			if (is.null(private$X)) {
				private$covariate_impute_if_necessary_and_then_create_model_matrix()
			}
			X = private$X[seq_len(n), , drop = FALSE]
			if (ncol(X) == 0L) {
				private$block_ids = factor(rep(seq_len(private$B), length.out = n))
				return(private$block_ids)
			}
			private$block_ids = switch(private$method,
				greedy = private$solve_greedy_blocks(X),
				`K-way` = private$solve_kway_blocks(X),
				ompr = {
					D = private$get_or_compute_distance_matrix(X)
					private$solve_optimal_blocks(D)
				}
			)
			private$block_ids
		},
			get_or_compute_distance_matrix = function(X){
				if (!is.null(private$distance_matrix)) {
					return(private$distance_matrix)
				}
				if (is.function(private$dist_spec)) {
					D = optimal_blocks_distance_matrix_cpp(
						X = X,
						dist_code = 0L,
						dist_fn = private$dist_spec
					)
				} else {
					D = switch(private$dist_spec,
						euclidean = optimal_blocks_distance_matrix_cpp(X, dist_code = 1L),
						sum_abs_diff = optimal_blocks_distance_matrix_cpp(X, dist_code = 2L),
						mahal = optimal_blocks_distance_matrix_cpp(X, dist_code = 3L)
					)
				}
			storage.mode(D) = "double"
			private$distance_matrix = D
			D
		},
		solve_greedy_blocks = function(X) {
			n    = nrow(X)
			B    = private$B
			n_tr = as.integer(floor(n / B))
			df   = data.frame(`.__id__` = seq_len(n), as.data.frame(X), check.names = FALSE)
			block_out = blockTools::block(
				data       = df,
				n.tr       = n_tr,
				id.vars    = ".__id__",
				block.vars = colnames(X)
			)
			# $assg[[1]] is a data.frame: rows=blocks, cols=Treatment 1..n_tr + Max Distance
			assg_df   = blockTools::assignment(block_out)$assg[[1L]]
			id_cols   = grep("^Treatment", colnames(assg_df), value = TRUE)
			block_ids = integer(n)
			for (b in seq_len(nrow(assg_df))) {
				ids = as.integer(unlist(assg_df[b, id_cols]))
				ids = ids[!is.na(ids)]
				block_ids[ids] = b
			}
			# Assign any leftover subjects (n not divisible by n_tr) to nearest assigned neighbour
			unassigned = which(block_ids == 0L)
			if (length(unassigned) > 0L) {
				assigned = which(block_ids > 0L)
				for (i in unassigned) {
					dists = rowSums(sweep(X[assigned, , drop = FALSE], 2, X[i, ])^2)
					block_ids[i] = block_ids[assigned[which.min(dists)]]
				}
			}
			factor(block_ids, levels = seq_len(B))
		},
		solve_kway_blocks = function(X) {
			assignments = anticlust::balanced_clustering(X, K = private$B)
			factor(assignments, levels = seq_len(private$B))
		},
		solve_optimal_blocks = function(D){
			n = nrow(D)
			B = private$B
			lower_size = floor(n / B)
			upper_size = ceiling(n / B)
			model = ompr::MIPModel()
			model = ompr::add_variable(model, x[i, k], i = 1:n, k = 1:B, type = "binary")
			model = ompr::add_variable(model, z[i, j, k], i = 1:n, j = 1:n, k = 1:B, type = "binary", i < j)
			model = ompr::set_objective(
				model,
				ompr::sum_expr(D[i, j] * z[i, j, k], i = 1:n, j = 1:n, k = 1:B, i < j),
				"min"
			)
			model = ompr::add_constraint(model, ompr::sum_expr(x[i, k], k = 1:B) == 1, i = 1:n)
			model = ompr::add_constraint(model, ompr::sum_expr(x[i, k], i = 1:n) >= lower_size, k = 1:B)
			model = ompr::add_constraint(model, ompr::sum_expr(x[i, k], i = 1:n) <= upper_size, k = 1:B)
			model = ompr::add_constraint(model, x[k, k] == 1, k = 1:B)
			model = ompr::add_constraint(model, z[i, j, k] <= x[i, k], i = 1:n, j = 1:n, k = 1:B, i < j)
			model = ompr::add_constraint(model, z[i, j, k] <= x[j, k], i = 1:n, j = 1:n, k = 1:B, i < j)
			model = ompr::add_constraint(model, z[i, j, k] >= x[i, k] + x[j, k] - 1, i = 1:n, j = 1:n, k = 1:B, i < j)
			result = ompr::solve_model(model, ompr.roi::with_ROI(solver = "glpk", verbose = FALSE))
			solution = ompr::get_solution(result, x[i, k])
			if (should_run_asserts()) {
				if (nrow(solution) == 0L) {
					stop("ompr failed to produce a block assignment solution.")
				}
			}
			solution = solution[solution$value > 0.5, , drop = FALSE]
			if (should_run_asserts()) {
				if (nrow(solution) != n) {
					stop("ompr returned an incomplete block assignment.")
				}
			}
			labels = integer(n)
			labels[solution$i] = solution$k
			factor(labels, levels = seq_len(B))
		}
	)
)
