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
#' \strong{Solver backend (\code{method = "ompr"} only).} \code{roi_solver} selects the
#' MILP backend \pkg{ompr.roi} dispatches to, a \strong{closed set}
#' \code{c("glpk", "gurobi", "cplex")} (default \code{"glpk"}) -- validated against this
#' set, not passed through to \code{ROI::ROI_registered_solvers()} unchecked, so a typo
#' or an unsupported solver name fails fast with a clear message rather than an opaque
#' \pkg{ompr} error three layers down. Gurobi and CPLEX are supported because they extend
#' which block-formation problems stay practical, not just which are expressible: GLPK's
#' branch-and-bound is single-threaded with no commercial-grade presolve/cutting-plane
#' machinery, while Gurobi/CPLEX are typically an order of magnitude faster on the same
#' MILP and solve in parallel, meaningfully extending the \eqn{n} for which the exact
#' \code{"ompr"} method stays practical. Scope is deliberately closed to these two for
#' now -- not because other ROI plugins (CBC, SYMPHONY, ...) wouldn't work mechanically
#' (the dispatch is generic), but because Gurobi and CPLEX are the two most widely used
#' commercial solvers and the only ones worth a maintained step-by-step guide at this
#' point; extending the closed set is a small, low-risk addition later if a real need for
#' a third backend appears, not a reason to leave the set open-ended now.
#'
#' \strong{Wiring up Gurobi:}
#' \enumerate{
#'   \item Obtain a Gurobi license (a free academic license is available from Gurobi for
#'     non-commercial use) and install the Gurobi Optimizer itself. This sets up
#'     \code{GUROBI_HOME} and the license file (\code{gurobi.lic}, discoverable via the
#'     \code{GRB_LICENSE_FILE} environment variable or Gurobi's default search path) --
#'     entirely outside this package's control or dependency graph.
#'   \item Install Gurobi's own R package. \strong{Not available via CRAN} -- it ships
#'     inside the Gurobi installation itself:
#'     \code{R CMD INSTALL "$GUROBI_HOME/R/gurobi_<version>_R_<Rmajor.minor>.tar.gz"}
#'     (exact filename/path depends on your Gurobi version and platform; see the
#'     \code{R/} subdirectory of your Gurobi install). This is the vendor interface
#'     \code{ROI.plugin.gurobi} wraps -- required even though it's not what you call
#'     directly.
#'   \item Install the ROI bridge package from CRAN:
#'     \code{install.packages("ROI.plugin.gurobi")}. This package \strong{is} on CRAN
#'     (it only depends on \pkg{ROI} + the \code{gurobi} R package from step 2 being
#'     present at load time) and is the only new artifact this class's own dependency
#'     graph ever touches.
#'   \item Verify: after \code{library(ROI.plugin.gurobi)}, \code{"gurobi" \%in\%
#'     ROI::ROI_registered_solvers()} should be \code{TRUE}.
#'   \item Pass \code{roi_solver = "gurobi"} to the constructor.
#' }
#'
#' \strong{Wiring up CPLEX:}
#' \enumerate{
#'   \item Obtain an IBM CPLEX license (a free academic license is available from IBM)
#'     and install IBM ILOG CPLEX Optimization Studio.
#'   \item Install \pkg{Rcplex} (CRAN), CPLEX's R interface. Unlike
#'     \code{ROI.plugin.gurobi}, \pkg{Rcplex} is a \strong{source package that compiles
#'     against your local CPLEX installation} -- it needs to be pointed at your CPLEX
#'     SDK's include/lib directories at install time (typically via \code{configure.args}
#'     to \code{install.packages()}, naming your CPLEX version's
#'     \code{cplex/include}/\code{cplex/lib/<platform>} paths). The exact flag names and
#'     paths are CPLEX-version- and platform-specific -- \strong{follow \pkg{Rcplex}'s
#'     own \code{INSTALL}/README instructions for your installed CPLEX version} rather
#'     than a fixed command copied from here, since this changes across CPLEX releases.
#'   \item Install the ROI bridge package from CRAN:
#'     \code{install.packages("ROI.plugin.cplex")} (depends on \pkg{Rcplex} from step 2
#'     being present and working).
#'   \item Verify: after \code{library(ROI.plugin.cplex)}, \code{"cplex" \%in\%
#'     ROI::ROI_registered_solvers()} should be \code{TRUE}.
#'   \item Pass \code{roi_solver = "cplex"} to the constructor.
#' }
#'
#' \strong{Dependency-graph consequence:} \code{ROI.plugin.gurobi}/\code{ROI.plugin.cplex}
#' (and \pkg{Rcplex}) are \strong{never added to \code{Suggests}} -- they're free/CRAN-
#' available themselves, but declaring them would misrepresent the dependency as
#' something \code{install.packages("EDI", dependencies = TRUE)} could satisfy, when the
#' vendor package/license underneath cannot be. The lazy-check pattern already used for
#' \pkg{ompr}/\pkg{ompr.roi}/\code{ROI.plugin.glpk} extends naturally: check
#' \code{requireNamespace("ROI.plugin.gurobi"/"ROI.plugin.cplex")} at solve time (not at
#' package load or class-definition time) for whichever \code{roi_solver} was requested,
#' and error informatively -- naming the missing package and, if that's present but the
#' solve still fails, noting the likely cause is a missing vendor license/installation,
#' not something this class can diagnose further.
#'
#' \strong{Bootstrap.} \code{draw_bootstrap_indices()} resamples within blocks by
#' default (\code{bootstrap_type = "within_blocks"} or \code{NULL}, via
#' \code{stratified_bootstrap_indices_cpp()}) or resamples whole blocks otherwise (via
#' \code{resample_group_rows_cpp()}), mirroring the block structure in the resampling
#' scheme, as in \code{\link[EDI:DesignFixedBlocking]{DesignFixedBlocking}}. The
#' bootstrap randomization test replays the whole mechanism on each resample: the
#' cached blocking is keyed on the covariate rows it was solved on, so a resample
#' re-solves the optimal blocking on its own covariates (same \code{method},
#' \code{B}, \code{dist} and \code{roi_solver}, under that replay draw's seed) and the
#' assignment is drawn within the new blocks. This costs one block solve per replay
#' draw; ordinary draws on unchanged data reuse the cached blocks.
#'
#' \strong{Cost of randomization-bootstrap replay.} Because every replay draw of a
#' randomization-bootstrap confidence interval or p-value re-solves the blocking on
#' that draw's resampled covariates, the per-draw cost is the cost of one block solve
#' for the chosen \code{method}. Measured extra time per replay draw (one machine,
#' indicative only): about 6 ms for \code{"K-way"} (\eqn{n = 40}, \eqn{B = 5}) and
#' about 21 ms at \eqn{n = 400}, \eqn{B = 20}; about 27-33 ms for \code{"greedy"}
#' (\eqn{n = 40} to \eqn{200}); but about 1.7 s for \code{"ompr"} at \eqn{n = 12},
#' \eqn{B = 3} and about 79 s at \eqn{n = 16}, \eqn{B = 4}, growing rapidly with
#' \eqn{n}. With the exact \code{"ompr"} method, randomization-bootstrap replays are
#' therefore very slow (hours for a few hundred draws at \eqn{n = 16}). When such
#' inference is needed, prefer a heuristic method (\code{"K-way"} or
#' \code{"greedy"}), or use \code{"ompr"} only with a small number of bootstrap
#' replicates.
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
#' if (requireNamespace("anticlust", quietly = TRUE)) {
#' des = DesignFixedOptimalBlocks$new(n = 9, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x = rnorm(9)))
#' des$assign_w_to_all_subjects()
#' }
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
			#' @param roi_solver MILP backend used only when \code{method = "ompr"}. A
			#'   closed set \code{c("glpk", "gurobi", "cplex")}, default \code{"glpk"}.
			#'   See the class documentation's "Solver backend" and wiring-guide
			#'   sections for the Gurobi/CPLEX setup steps.
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
				roi_solver = "glpk",
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
						assertChoice(roi_solver, EDI_OPTIMAL_ROI_SOLVERS)
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
				private$roi_solver = roi_solver
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
		roi_solver = NULL,
		block_ids = NULL,
		block_solve_key = NULL,
		distance_matrix = NULL,
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
			}
			block_ids = private$get_or_compute_block_ids()
			block_ra_batch(block_ids, private$prob_T, r)
		},
		# Bootstrap-randomization replay (2026-10-23, release_v1_0_5.md TODO-131,
		# G6 #51 DECIDED by owner): the resampling machinery hands a duplicated
		# design the bootstrap rows (Xraw/Ximp/X/m subset by i_b) while its cached
		# private$block_ids still indexes the ORIGINAL rows. The replay must run the
		# design's own mechanism on the resample, so the optimal blocking is
		# RE-SOLVED on the resampled covariates (same method/B/dist/roi_solver) and
		# the assignment is drawn within the new blocks. Detection is by data, not
		# by the carried block ids: block_solve_key records the covariate rows the
		# cached solve was run on; normal draws on unchanged data hit the cache.
		# (Replaces the same-day carried-ids rebuild from private$m, which kept the
		# observed blocks; that path is gone -- re-solving is always available.)
		optimal_block_solve_key = function(n){
			src = if (!is.null(private$Xraw)) private$Xraw else private$Ximp
			cols = if (is.null(src)) list() else lapply(seq_len(length(src)), function(j) src[[j]][seq_len(min(n, length(src[[j]])))])
			list(n = as.integer(n), names = names(src), cols = cols)
		},
		# The design's own covariate matrix for the CURRENT (resampled) rows, built
		# from Ximp exactly as covariate_impute_if_necessary_and_then_create_model_matrix()
		# builds private$X (analysis columns, constants dropped, design_formula),
		# without re-imputing and without touching private$X: on a reusable BRT
		# worker private$X holds the INFERENCE's model-formula matrix, not the design's.
		optimal_block_resolve_covariates = function(n){
			if (is.null(private$Ximp) || NROW(private$Ximp) < n) private$ensure_model_matrix_current()
			src = private$Ximp
			cols = lapply(seq_len(length(src)), function(j) src[[j]][seq_len(n)])
			names(cols) = names(src)
			keep = !startsWith(names(cols), ".assignment_only_")
			if (!is.null(private$cluster_col) && length(private$cluster_col) == 1L) {
				keep = keep & names(cols) != private$cluster_col
			}
			keep = keep & vapply(cols, function(col) length(unique(col)) > 1L, logical(1L))
			if (!any(keep)) return(matrix(NA_real_, nrow = n, ncol = 0L))
			df = as.data.frame(cols[keep], check.names = FALSE, stringsAsFactors = FALSE)
			X = create_model_matrix_from_features(private$design_formula, df)
			if (ncol(X) > 0L) {
				X = X[, apply(X, 2L, function(col) length(unique(col)) > 1L), drop = FALSE]
			}
			if (ncol(X) == 0L) return(matrix(NA_real_, nrow = n, ncol = 0L))
			X
		},
		# draw_bootstrap_indices is provided by the BlockingStructure component (see
		# `components` above); proven byte-identical to this class's former hand-rolled
		# version via test-design-blocking-structure-bootstrap-golden.R before removal.
		assert_feasible_block_sizes = function(n){
			private$assert_min_block_size(n, private$B)
			invisible(NULL)
		},
		get_or_compute_block_ids = function(){
			n = self$get_n()
			resolve = FALSE
			if (!is.null(private$block_ids)) {
				key = private$optimal_block_solve_key(n)
				# A NULL key means block_ids of unknown provenance (an object saved
				# before 2026-10-23): re-solve once rather than trust rows it may
				# not index. The solvers are deterministic, so on unchanged data
				# this reproduces the same blocks.
				if (!is.null(private$block_solve_key) && identical(private$block_solve_key, key)) {
					return(private$block_ids)
				}
				resolve = !is.null(private$block_solve_key)
				# Drop the stale solve and its row-indexed distance matrix first, so
				# a failed re-solve leaves nothing for a later draw to reuse.
				private$block_ids = NULL
				private$block_solve_key = NULL
				private$distance_matrix = NULL
			}
			if (should_run_asserts()) {
				private$assert_feasible_block_sizes(n)
			}
			if (resolve) {
				X = private$optimal_block_resolve_covariates(n)
			} else {
				private$ensure_model_matrix_current()
				X = private$X[seq_len(n), , drop = FALSE]
			}
			if (ncol(X) == 0L) {
				private$block_ids = factor(rep(seq_len(private$B), length.out = n))
				private$block_solve_key = private$optimal_block_solve_key(n)
				return(private$block_ids)
			}
			block_ids = switch(private$method,
				greedy = private$solve_greedy_blocks(X),
				`K-way` = private$solve_kway_blocks(X),
				ompr = {
					D = private$get_or_compute_distance_matrix(X)
					private$solve_optimal_blocks(D)
				}
			)
			private$block_ids = block_ids
			private$block_solve_key = private$optimal_block_solve_key(n)
			# On a re-solve, private$m (where get_block_ids() caches block ids) still
			# holds the ids the resampled units carried; point it at the blocks the
			# replayed assignment is actually balanced within.
			if (resolve && !is.null(private$m)) private$m = as.integer(block_ids)
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
			# Only complete rows become blocks 1..B; blockTools' incomplete row (and any
			# complete row beyond the B-th) is left at 0 for the nearest-neighbour fallback
			# below. Complete rows are numbered consecutively: blockTools does not always
			# put its incomplete row last (seen on bootstrap resamples with duplicated
			# rows, 2026-10-23), and indexing labels by row position then left one label
			# empty, so the capacity-limited fallback below ran out of eligible
			# neighbours ("replacement has length zero"). Identical labels whenever the
			# incomplete row is last.
			b = 0L
			for (row in seq_len(nrow(assg_df))) {
				if (b >= B) break
				ids = as.integer(unlist(assg_df[row, id_cols]))
				if (length(ids) != n_tr || anyNA(ids)) next
				b = b + 1L
				block_ids[ids] = b
			}
			# Assign leftover subjects to the nearest block with room for one extra
			# subject. Without the capacity check, several leftovers can join the
			# same block and leave sizes differing by more than one.
			unassigned = which(block_ids == 0L)
			if (length(unassigned) > 0L) {
				block_sizes = tabulate(block_ids, nbins = B)
				max_size = ceiling(n / B)
				for (i in unassigned) {
					eligible_blocks = which(block_sizes < max_size)
					assigned = which(block_ids %in% eligible_blocks)
					b = if (length(assigned) == 0L) {
						# only empty blocks have room (fewer than B complete blockTools rows)
						eligible_blocks[which.min(block_sizes[eligible_blocks])]
					} else {
						dists = rowSums(sweep(X[assigned, , drop = FALSE], 2, X[i, ])^2)
						block_ids[assigned[which.min(dists)]]
					}
					block_ids[i] = b
					block_sizes[b] = block_sizes[b] + 1L
				}
			}
			factor(block_ids, levels = seq_len(B))
		},
		solve_kway_blocks = function(X) {
			n = nrow(X)
			B = private$B
			# balanced_clustering() needs equal-sized groups: hold out the r = n mod B subjects
			# that sit farthest from their (deterministic Ward) cluster centroid, cluster the rest
			# in equal groups, then attach each held-out subject to the nearest group centroid.
			r = n %% B
			assignments = integer(n)
			if (r == 0L) {
				assignments[] = anticlust::balanced_clustering(X, K = B)
			} else {
				rough = stats::cutree(stats::hclust(stats::dist(X), method = "ward.D2"), k = B)
				rough_cen = do.call(rbind, lapply(seq_len(B), function(k) colMeans(X[rough == k, , drop = FALSE])))
				d_own = rowSums((X - rough_cen[rough, , drop = FALSE])^2)
				held = order(d_own, decreasing = TRUE)[seq_len(r)]
				keep = setdiff(seq_len(n), held)
				assignments[keep] = anticlust::balanced_clustering(X[keep, , drop = FALSE], K = B)
				centroids = do.call(rbind, lapply(seq_len(B), function(k) colMeans(X[keep[assignments[keep] == k], , drop = FALSE])))
				for (i in held) {
					assignments[i] = which.min(rowSums(sweep(centroids, 2, X[i, ])^2))
				}
			}
			factor(assignments, levels = seq_len(B))
		},
		solve_optimal_blocks = function(D){
			assert_optimal_roi_solver(private$roi_solver)
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
			model = ompr::add_constraint(model, x[1, 1] == 1)
			model = ompr::add_constraint(model, z[i, j, k] <= x[i, k], i = 1:n, j = 1:n, k = 1:B, i < j)
			model = ompr::add_constraint(model, z[i, j, k] <= x[j, k], i = 1:n, j = 1:n, k = 1:B, i < j)
			model = ompr::add_constraint(model, z[i, j, k] >= x[i, k] + x[j, k] - 1, i = 1:n, j = 1:n, k = 1:B, i < j)
			result = ompr::solve_model(model, ompr.roi::with_ROI(solver = private$roi_solver, verbose = FALSE))
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
