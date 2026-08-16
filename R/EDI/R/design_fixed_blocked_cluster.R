#' A Fixed, Blocked-and-Clustered Randomized Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} in which the unit of
#' randomization is the \strong{cluster}, not the individual subject: within each block
#' (stratum, formed from \code{strata_cols}), whole clusters (identified by
#' \code{cluster_col}) are jointly randomized to treatment or control, so all subjects in
#' the same cluster always receive the same assignment. This is the design used when
#' individual-level randomization is infeasible or invalid (e.g. clusters are classrooms,
#' clinics, or households where within-cluster interference/spillover would violate
#' SUTVA under individual randomization), combined with blocking to improve precision by
#' comparing clusters only to other clusters in the same stratum.
#'
#' @details
#' \strong{Randomization mechanism.} Blocking keys are computed per subject via
#' \code{private$get_strata_keys()} (shared with other
#' \code{\link[EDI:DesignBlocking]{DesignBlocking}} subclasses): categorical columns in
#' \code{strata_cols} are used as-is, continuous columns are discretized into
#' \code{preferred_num_bins_for_continuous_covariate} quantile-based bins, and multiple
#' \code{strata_cols} are combined into a single composite block key. Within each
#' resulting block, whole clusters (by \code{cluster_col}) are randomized to treatment
#' with probability \code{prob_T} via \code{\link[randomizr]{block_and_cluster_ra}}
#' (\pkg{randomizr}), which performs blocked-and-clustered complete random assignment:
#' within each block, clusters (not subjects) are permuted so that, subject to rounding,
#' the target proportion \code{prob_T} of clusters in that block is treated, and every
#' subject in a treated cluster receives \eqn{w = 1}. \code{r} independent replicate
#' allocation columns are generated via \code{replicate()} (one \pkg{randomizr} call per
#' replicate; there is no batch/vectorized draw path for this design, unlike
#' \code{\link[EDI:DesignFixedBinaryMatch]{DesignFixedBinaryMatch}}).
#'
#' \strong{Cluster-aware bootstrap.} \code{draw_bootstrap_indices()} overrides the default
#' subject-level bootstrap to resample at the cluster level via
#' \code{resample_group_rows_cpp()}: with \code{bootstrap_type = "within_blocks"}
#' (the default when \code{bootstrap_type} is \code{NULL}), clusters are resampled with
#' replacement \emph{within} each block, preserving the block structure; otherwise, whole
#' blocks (strata) are themselves resampled with replacement. This mirrors the standard
#' cluster-robust bootstrap principle that resampling must occur at the level of the
#' randomization unit (clusters), not individual subjects, to yield a valid
#' variance/interval estimate under cluster-correlated outcomes.
#'
#' @references Middleton, J. A., and Aronow, P. M. (2015). "Unbiased estimation of the
#'   average treatment effect in cluster-randomized experiments." \emph{Statistics,
#'   Politics and Policy}, 6(1-2), 39-75, \doi{10.1515/spp-2013-0002}, for
#'   blocked/clustered randomized-assignment inference; see also the \pkg{randomizr}
#'   \href{https://declaredesign.org/r/randomizr/articles/randomizr_vignette.html}{package
#'   vignette} for the assignment-generation conventions this design relies on, and
#'   \href{https://en.wikipedia.org/wiki/Cluster_randomised_controlled_trial}{cluster
#'   randomized controlled trial} for orientation.
#' @examples
#' des = DesignFixedBlockedCluster$new(n = 20, response_type = 'continuous',
#'   strata_cols = 'x2', cluster_col = 'cl')
#' X = data.frame(x1 = rnorm(20), x2 = factor(rep(1:2, each = 10)), cl = factor(rep(1:10, each = 2)))
#' des$add_all_subjects_to_experiment(X)
#' des$assign_w_to_all_subjects()
#' @export
DesignFixedBlockedCluster = define_design_class(
	classname = "DesignFixedBlockedCluster",
	inherit = DesignFixed,
	components = c("BlockingStructure", "ClusterStructure"),
	# ClusterStructure's strata-aware draw_bootstrap_indices must win over
	# BlockingStructure's plain block-based one; both provide the method since
	# BlockingStructure gained its own generalization alongside ClusterStructure's.
	overrides = list(private = "draw_bootstrap_indices"),
	public = list(
		#' @description Characterization: this design randomizes whole clusters (see
		#'   class documentation), so it is cluster-structured by construction.
		#' @return Always \code{TRUE} for this class.
		is_a_cluster_capable = function() TRUE,
		#' @description Initialize a blocked and cluster randomized fixed experimental
		#'   design.
		#'
		#' @param strata_cols 	A character vector of column names to use for stratification (blocks).
		#' @param cluster_col 	The column name in the data that identifies the cluster for each subject.
		#' @param response_type 	The data type of response values.
		#' @param prob_T  The target probability that a given cluster within a block is
		#'   assigned to treatment (subjects inherit their cluster's assignment).
		#' @param include_is_missing_as_a_new_feature  Flag for missingness indicators.
		#' @param n  		The sample size.
		#' @param preferred_num_bins_for_continuous_covariate The number of quantile bins to use for continuous strata. Default is 2.
		#' @param num_bins_for_continuous_covariate Deprecated alias for
		#'   `preferred_num_bins_for_continuous_covariate`.
		#' @param verbose  Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return 			A new `DesignFixedBlockedCluster` object
		#'
		initialize = function(
				strata_cols,
				cluster_col,
				response_type,
				prob_T = 0.5,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				preferred_num_bins_for_continuous_covariate = 2,
				num_bins_for_continuous_covariate = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			if (!is.null(num_bins_for_continuous_covariate)) {
				preferred_num_bins_for_continuous_covariate = num_bins_for_continuous_covariate
			}
			if (should_run_asserts()) {
				assertCharacter(strata_cols, min.len = 1)
				assertCharacter(cluster_col, len = 1)
				assertCount(preferred_num_bins_for_continuous_covariate, positive = TRUE)
				assertStrataClusterArgs(
					strata_cols = strata_cols,
					cluster_col = cluster_col,
					context = "DesignFixedBlockedCluster$new"
				)
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$blocking_capable = TRUE
			private$strata_cols = strata_cols
			private$cluster_col = cluster_col
			private$preferred_num_bins_for_continuous_covariate = preferred_num_bins_for_continuous_covariate
			private$uses_covariates = TRUE
		}
	),
	private = list(
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
			}

			strata_keys = private$get_strata_keys()

			cluster_ids = as.character(private$Xraw[[private$cluster_col]])

			# Use randomizr::block_and_cluster_ra for canonical blocked and clustered randomization
			w_mat = replicate(r, as.numeric(as.character(randomizr::block_and_cluster_ra(
				blocks = strata_keys,
				clusters = cluster_ids,
				prob = private$prob_T
			))))
			storage.mode(w_mat) = "numeric"
			w_mat
		}
		# draw_bootstrap_indices is provided by the ClusterStructure component (see
		# `components`/`overrides` above); proven byte-identical to this class's former
		# hand-rolled version via test-design-cluster-structure-golden.R before removal.
	)
)
