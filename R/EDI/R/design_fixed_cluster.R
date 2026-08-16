#' A Fixed, Unblocked Cluster Randomized Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} in which whole clusters
#' of subjects (identified by \code{cluster_col}), rather than individual subjects, are
#' the unit of randomization: every subject in a given cluster always receives the same
#' treatment assignment. This is the unblocked analog of
#' \code{\link[EDI:DesignFixedBlockedCluster]{DesignFixedBlockedCluster}} — there is no
#' stratification step here, so clusters are randomized to treatment as a single pool
#' rather than within strata. Cluster-level randomization is required whenever
#' individual-level randomization would create within-cluster interference/spillover
#' that violates SUTVA (e.g. clusters are classrooms, clinics, villages, or households),
#' at the cost of an effective sample size driven by the number of \emph{clusters}, not
#' subjects, and a corresponding need for cluster-aware inference.
#'
#' @details
#' \strong{Randomization mechanism.} \code{draw_ws_raw(r)} extracts each subject's
#' cluster ID from \code{cluster_col} (erroring if any are missing) and calls
#' \code{\link[randomizr]{cluster_ra}} (\pkg{randomizr}) once per replicate, which
#' performs complete random assignment at the cluster level: subject to rounding,
#' \code{prob_T} of clusters are assigned to treatment, and all subjects sharing a
#' cluster inherit that cluster's assignment. \code{r} independent replicate columns are
#' generated via \code{replicate()} (one \pkg{randomizr} call per replicate).
#'
#' \strong{Cluster-aware bootstrap.} \code{draw_bootstrap_indices()} overrides the
#' default subject-level bootstrap to resample whole clusters with replacement (via
#' \code{resample_group_rows_cpp()}) rather than individual rows, since outcomes are
#' correlated within a cluster (shared assignment plus, typically, shared context) and
#' the exchangeable resampling unit for a valid bootstrap variance/interval estimate is
#' therefore the cluster, not the subject.
#'
#' @references Middleton, J. A., and Aronow, P. M. (2015). "Unbiased estimation of the
#'   average treatment effect in cluster-randomized experiments." \emph{Statistics,
#'   Politics and Policy}, 6(1-2), 39-75, \doi{10.1515/spp-2013-0002}. See also
#'   \href{https://en.wikipedia.org/wiki/Cluster_randomised_controlled_trial}{cluster
#'   randomized controlled trial} for orientation, and
#'   \code{\link[EDI:DesignFixedBlockedCluster]{DesignFixedBlockedCluster}} for the
#'   blocked variant of this design.
#' @examples
#' des = DesignFixedCluster$new(n = 20, response_type = 'continuous', cluster_col = 'cl')
#' X = data.frame(x = rnorm(20), cl = factor(rep(1:5, each = 4)))
#' des$add_all_subjects_to_experiment(X)
#' des$assign_w_to_all_subjects()
#' @export
DesignFixedCluster = define_design_class(
	classname = "DesignFixedCluster",
	inherit = DesignFixed,
	components = "ClusterStructure",
	public = list(
		#' @description Characterization: this design randomizes whole clusters (see
		#'   class documentation), so it is cluster-structured by construction.
		#' @return Always \code{TRUE} for this class.
		is_a_cluster_capable = function() TRUE,
		#' @description Initialize a cluster randomized fixed experimental design (no
		#'   blocking/stratification; see
		#'   \code{\link[EDI:DesignFixedBlockedCluster]{DesignFixedBlockedCluster}} if
		#'   stratification is also needed).
		#'
		#' @param cluster_col 	The column name in the data that identifies the cluster for each subject.
		#' @param response_type 	The data type of response values.
		#' @param prob_T  The target probability that a given cluster is assigned to
		#'   treatment (subjects inherit their cluster's assignment).
		#' @param include_is_missing_as_a_new_feature  Flag for missingness indicators.
		#' @param n  		The sample size.
		#' @param verbose  Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return 			A new `DesignFixedCluster` object
		#'
		initialize = function(
				cluster_col,
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
				assertCharacter(cluster_col, len = 1)
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$cluster_col = cluster_col
			private$uses_covariates = TRUE
		}
	),
	private = list(
		# draw_bootstrap_indices is provided by the ClusterStructure component (see
		# `components` above); proven byte-identical to this class's former hand-rolled
		# version via test-design-cluster-structure-golden.R before removal.
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
			}
			cluster_ids = as.character(private$Xraw[[private$cluster_col]])
			if (should_run_asserts()) {
				if (any(is.na(cluster_ids))){
					stop("Cluster IDs cannot be missing.")
				}
			}

			# Use randomizr::cluster_ra for canonical cluster randomization
			w_mat = replicate(r, as.numeric(as.character(randomizr::cluster_ra(clusters = cluster_ids, prob = private$prob_T))))
			storage.mode(w_mat) = "numeric"
			w_mat
		}
	)
)
