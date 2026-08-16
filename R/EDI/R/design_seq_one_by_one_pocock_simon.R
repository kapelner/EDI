#' Pocock and Simon's (1975) Minimization Sequential Design
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} implementing Pocock and
#' Simon's minimization method: for each categorical covariate in \code{strata_cols},
#' the design tracks a running treated/control count per covariate \emph{level}
#' (\code{private$counts}), and for a new subject computes, for each candidate
#' treatment arm \eqn{k \in \{0, 1\}}, a weighted total imbalance
#' \deqn{G_k = \sum_{j} weights_j \cdot \mathrm{Var}\big(\text{counts at subject's level of covariate } j,
#' \text{ after hypothetically assigning arm } k\big),}
#' where the variance is taken across the two treatment arms' hypothetical counts at
#' that covariate level (so \eqn{G_k} is large when arm \eqn{k} would leave the
#' subject's covariate-level counts unbalanced, summed with \code{weights} across
#' covariates). The subject is then assigned to whichever arm minimizes \eqn{G_k} with
#' probability \code{p_best} (and to the other arm with probability
#' \code{1 - p_best}), or — if the two arms are exactly tied — via a plain
#' \eqn{\mathrm{Bernoulli}(prob\_T)} draw. Unlike
#' \code{\link[EDI:DesignSeqOneByOneAtkinson]{DesignSeqOneByOneAtkinson}}/
#' \code{\link[EDI:DesignSeqOneByOneKK14]{DesignSeqOneByOneKK14}}, which use continuous
#' covariate distances, minimization operates on categorical/discretized strata and
#' balances marginal covariate-level counts directly rather than a multivariate
#' distance or matched-pair structure.
#'
#' @details
#' \strong{Level bookkeeping.} \code{private$ensure_factor_metadata()} maintains a
#' mapping from each observed level of each \code{strata_cols} column to a row index
#' in \code{private$counts} (an (total levels across all covariates) x 2 matrix of
#' running treated/control counts), growing both the level map and \code{counts} as
#' new levels are encountered; missing values are treated as their own level
#' (\code{"NA"}).
#'
#' \strong{Non-resampling bootstrap.} \code{draw_bootstrap_indices()} always performs a
#' plain i.i.d. nonparametric bootstrap over subjects (\code{sample_int_replace_cpp()}),
#' since minimization's adaptive assignment process has no simple exchangeable
#' resampling unit to preserve (each subject's assignment probability depends on the
#' full sequence of covariate levels and assignments that preceded it).
#'
#' @references Pocock, S. J., and Simon, R. (1975). "Sequential treatment assignment
#'   with balancing for prognostic factors in the controlled clinical trial."
#'   \emph{Biometrics}, 31(1), 103-115, \doi{10.2307/2529712}. See also
#'   \href{https://en.wikipedia.org/wiki/Minimisation_(clinical_trials)}{minimisation
#'   (clinical trials)} for orientation.
#' @examples
#' seq_des = DesignSeqOneByOnePocockSimon$new(strata_cols = 'x1', n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = factor(1, levels=1:2)))
#' @export
DesignSeqOneByOnePocockSimon = R6::R6Class("DesignSeqOneByOnePocockSimon",
	inherit = DesignSeqOneByOne,
	public = list(
		#' @description Initialize a Pocock and Simon (1975) minimization sequential
		#'   experimental design (see class documentation for the exact imbalance
		#'   criterion and assignment rule).
		#'
		#' @param strata_cols     The names of the covariates to be used for minimization. These
		#'   must be factor or categorical variables.
		#' @param weights 		A numeric vector of per-covariate weights \eqn{weights_j}
		#'   in the imbalance criterion \eqn{G_k} (see class documentation), one per
		#'   entry of \code{strata_cols}, in the same order. Defaults to 1 for all
		#'   (equal-weighted covariates).
		#' @param p_best          The probability of assigning the treatment arm that
		#'   minimizes \eqn{G_k} (see class documentation); the complementary arm is
		#'   assigned with probability \code{1 - p_best}. Defaults to 0.8 (an 80/20
		#'   biased coin favoring the balancing arm, rather than a fully deterministic
		#'   minimization rule).
		#' @param response_type 	The data type of response values.
		#' @param prob_T  The probability of the treatment assignment used only when
		#'   the two arms' imbalance is exactly tied (see class documentation).
		#' @param include_is_missing_as_a_new_feature  Flag for missingness indicators.
		#' @param n  		The sample size.
		#' @param verbose  Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return 			A new `DesignSeqOneByOnePocockSimon` object
		#'
		initialize = function(
				strata_cols,
				weights = NULL,
				p_best = 0.8,
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
				assertCharacter(strata_cols, min.len = 1)
				assertNumeric(p_best, lower = 0.5, upper = 1)
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			
			private$strata_cols = strata_cols
			private$p_best = p_best
			private$uses_covariates = TRUE
			
			if (is.null(weights)){
				private$weights = rep(1, length(strata_cols))
			} else {
				if (should_run_asserts()) {
					assertNumeric(weights, len = length(strata_cols), lower = 0)
				}
				private$weights = weights
			}
		},
		#' @description Draw the next subject's treatment assignment via Pocock and
		#'   Simon minimization (see class documentation for the exact imbalance
		#'   criterion \eqn{G_k} and the \code{p_best}/\code{prob_T} assignment rule),
		#'   and update the running per-covariate-level treated/control counts
		#'   in-place to reflect this assignment.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			private$ensure_factor_metadata()
			subject_levels_idx = private$get_subject_levels_idx(private$Xraw[private$t, ])
			
			if (is.null(private$counts)){
				private$counts = matrix(0, nrow = private$num_levels_total, ncol = 2)
			}
			
			# Call Rcpp function that assigns and updates counts in-place
			pocock_simon_assign_and_update_cpp(
				private$counts, 
				as.integer(subject_levels_idx), 
				private$weights, 
				private$p_best, 
				private$prob_T
			)
		}
	),
	private = list(
		draw_ws_raw = function(r = 100){
			private$ensure_factor_metadata()
			n = self$get_n()
			x_levels_matrix = matrix(NA_integer_, nrow = n, ncol = length(private$strata_cols))
			for (i in 1 : n){
				x_levels_matrix[i, ] = private$get_subject_levels_idx(private$Xraw[i, ])
			}
			generate_permutations_pocock_simon_cpp(
				x_levels_matrix,
				as.integer(private$num_levels_total),
				private$weights,
				private$p_best,
				private$prob_T,
				as.integer(r)
			)$w_mat
		},
		p_best = NULL,
		weights = NULL,
		counts = NULL,
		num_levels_total = NULL,
		strata_level_rows = NULL,
		draw_bootstrap_indices = function(bootstrap_type = NULL) {
			list(i_b = sample_int_replace_cpp(private$t, private$t), m_vec_b = NULL)
		},
		ensure_factor_metadata = function(){
			if (is.null(private$strata_level_rows)) private$strata_level_rows = vector("list", length(private$strata_cols))
			if (length(private$strata_level_rows) != length(private$strata_cols)) {
				private$strata_level_rows = vector("list", length(private$strata_cols))
			}
			names(private$strata_level_rows) = private$strata_cols
			next_row = 1L
			for (col in private$strata_cols) {
				row_map = private$strata_level_rows[[col]]
				if (is.null(row_map)) row_map = integer(0)
				col_vals = private$Xraw[[col]]
				col_keys = ifelse(is.na(col_vals), "NA", as.character(col_vals))
				new_levels = setdiff(unique(col_keys), names(row_map))
				if (length(new_levels) > 0L) {
					new_rows = seq.int(next_row, length.out = length(new_levels))
					names(new_rows) = new_levels
					row_map = c(row_map, new_rows)
				}
				private$strata_level_rows[[col]] = row_map
				if (length(row_map) > 0L) next_row = max(unname(row_map)) + 1L
			}
			private$num_levels_total = max(0L, next_row - 1L)
			if (!is.null(private$counts) && nrow(private$counts) < private$num_levels_total) {
				expanded = matrix(0, nrow = private$num_levels_total, ncol = 2L)
				expanded[seq_len(nrow(private$counts)), ] = private$counts
				private$counts = expanded
			}
		},
		get_subject_levels_idx = function(x_row){
			private$ensure_factor_metadata()
			vapply(private$strata_cols, function(col) {
				key = if (is.na(x_row[[col]])) "NA" else as.character(x_row[[col]])
				row_idx = private$strata_level_rows[[col]][[key]]
				if (should_run_asserts()) {
					if (is.null(row_idx) || !is.finite(row_idx)) {
						stop("Unknown strata level encountered for Pocock-Simon column ", col, ": ", key)
					}
				}
				as.integer(row_idx)
			}, integer(1))
		}
	)
)
