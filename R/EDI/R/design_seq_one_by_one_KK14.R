#' Kapelner and Krieger's (2014) Sequential "Matching-on-the-Fly" Design
#'
#' A \code{\link[EDI:DesignSeqOneByOne]{DesignSeqOneByOne}} that matches subjects to
#' each other \strong{as they arrive}, rather than requiring all subjects up front (as
#' \code{\link[EDI:DesignFixedBinaryMatch]{DesignFixedBinaryMatch}} does): each new
#' subject is either matched to its nearest (Mahalanobis-distance) unmatched prior
#' subject in the "reservoir" — if that distance is small enough to pass a
#' statistical closeness test — and assigned the \strong{opposite} treatment from its
#' match, or, if no sufficiently close match exists (or matching hasn't started yet),
#' randomized and added to the reservoir for future subjects to potentially match
#' against.
#'
#' @details
#' \strong{Burn-in.} For the first \code{t_0_pct * n} subjects (default 35\%), or
#' whenever no covariates are yet available, subjects are simply randomized
#' (\eqn{\mathrm{Bernoulli}(prob\_T)}) and placed in the reservoir (\code{private$m}
#' set to 0 for that subject) — matching does not begin until enough subjects have
#' accumulated to estimate a stable covariate covariance structure.
#'
#' \strong{Matching test.} Once past burn-in, for new subject \eqn{t} with covariate
#' vector \eqn{x_t}, the squared Mahalanobis distance (via
#' \code{compute_proportional_mahal_distances_cpp()}, using the sample covariance of
#' all prior subjects' covariates, ridge-regularized by \code{.Machine$double.eps}) to
#' every subject currently in the reservoir is computed, and the closest one is a
#' candidate match. The match is \strong{accepted} only if that squared distance falls
#' below a threshold \eqn{T^2_{\mathrm{cutoff}}} derived from an F critical value,
#' \deqn{T^2_{\mathrm{cutoff}} = \frac{p(n-1)}{n-p} \, F_{p,\, t-p}(\lambda),}
#' where \eqn{p} is the rank of the covariate matrix so far, \eqn{n} is the design's
#' target (planned) sample size, \eqn{t} is the number of subjects enrolled so far, and
#' \eqn{\lambda} (\code{lambda}, default 0.1) is the F-distribution quantile level —
#' i.e. this is a
#' Hotelling's \eqn{T^2}-type test of whether the candidate pair's covariate
#' difference is small enough to plausibly be exchangeable "noise" rather than a
#' meaningful covariate mismatch; \code{lambda} controls how strict that test is
#' (smaller \code{lambda} accepts fewer, closer matches). If accepted, both subjects
#' are recorded as a new match (\code{private$m}), and the new subject receives the
#' \strong{opposite} treatment of its match, guaranteeing exactly one treated and one
#' control per matched pair — the same guarantee
#' \code{\link[EDI:DesignFixedBinaryMatch]{DesignFixedBinaryMatch}} provides, but
#' formed incrementally rather than all at once. If rejected (or the reservoir is
#' empty), the subject is randomized and added to the reservoir instead.
#'
#' \strong{Lifecycle note.} The \code{morrison} and \code{p} constructor arguments are
#' currently recorded on the object but not consulted anywhere in the matching or
#' assignment logic in this version of the class; treat them as reserved for future use
#' rather than as active configuration.
#'
#' @references Kapelner, A., and Krieger, A. M. (2014). "Matching on-the-fly: Sequential
#'   allocation with higher power and efficiency." \emph{Biometrics}, 70(2), 378-388,
#'   \doi{10.1111/biom.12148}. See also
#'   \href{https://en.wikipedia.org/wiki/Hotelling\%27s_T-squared_distribution}{Hotelling's
#'   T-squared distribution} for the matching-test statistic, and
#'   \href{https://en.wikipedia.org/wiki/Mahalanobis_distance}{Mahalanobis distance}.
#' @examples
#' seq_des = DesignSeqOneByOneKK14$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneKK14 = define_design_class(
	classname = "DesignSeqOneByOneKK14",
	inherit = DesignSeqOneByOne,
	components = "MatchingStructure",
	# MatchingStructure auto-expands to include its BlockingStructure dependency; both
	# provide draw_bootstrap_indices, and the pair-preserving MatchingStructure version
	# (processed after its dependency) must win -- this class had no override of its
	# own, so it was already using this exact function via inheritance from
	# DesignMatching (reference-identity, not just behavioral equivalence).
	overrides = list(private = "draw_bootstrap_indices"),
	public = list(
		#' @description Characterization: this design matches subjects to each other
		#'   incrementally as they arrive (see class documentation), so it is
		#'   KK matching-on-the-fly-capable by construction.
		#' @return Always \code{TRUE} for this class.
		is_a_kk_matching_capable = function() TRUE,
		#' @description Initialize a KK14 sequential matching-on-the-fly experimental
		#'   design (see class documentation for the burn-in and matching-test rules).
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Probability of treatment assignment used for burn-in/
		#'   unmatched (reservoir) subjects; matched subjects instead always receive
		#'   the opposite assignment of their match (see class documentation).
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param lambda The F-distribution quantile level controlling how strict the
		#'   matching-acceptance test is (default 0.1; smaller values accept fewer,
		#'   closer matches). See class documentation for the exact threshold formula.
		#' @param t_0_pct The fraction of \code{n} subjects to randomize into the
		#'   reservoir before matching begins (default 0.35).
		#' @param morrison Currently unused by this class's matching/assignment logic;
		#'   reserved for future use.
		#' @param p Currently unused by this class's matching/assignment logic;
		#'   reserved for future use.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return  A new `DesignSeqOneByOneKK14` object
		initialize = function(
						response_type,
						prob_T = 0.5,
						include_is_missing_as_a_new_feature = TRUE,
						n = NULL,

						verbose = FALSE,
						lambda = NULL,
						t_0_pct = NULL,
						morrison = FALSE,
						p = NULL,
						missingness_method = "impute",
						design_formula = ~ .,
						seed = NULL
					) {
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$blocking_capable = TRUE
			private$matching_capable = TRUE
			private$uses_covariates = TRUE
			private$lambda = if (is.null(lambda)) 0.1 else lambda
			private$t_0_pct = if (is.null(t_0_pct)) 0.35 else t_0_pct
			private$morrison = morrison
			private$p = p
		},
		#' @description Draw the next subject's treatment assignment via KK14
		#'   matching-on-the-fly (see class documentation): during burn-in, or if no
		#'   sufficiently close reservoir match exists, randomize and add the subject
		#'   to the reservoir; otherwise match to the nearest reservoir subject and
		#'   assign the opposite treatment.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			wt = 	if (private$too_early_to_match()){
						#we're early, so randomize
						private$m[private$t] = 0 #zero means "reservoir", >0 means match number
						private$assign_wt_Bernoulli()
					} else {
						all_subject_data = private$compute_all_subject_data()
						#compute inverse sample covariance of all past subjects (with eps regularization)
						S_xs_inv = solve(var(all_subject_data$X_prev) + diag(.Machine$double.eps, all_subject_data$rank_prev), tol = .Machine$double.xmin)
						#now find the best match in the reservoir
						reservoir_indices = which(private$m[1 : (private$t - 1)] == 0)
						if (length(reservoir_indices) == 0){
							private$m[private$t] = 0
							return(private$assign_wt_Bernoulli())
						}
						sqd_distances_times_two = compute_proportional_mahal_distances_cpp(
							all_subject_data$xt_prev,
							all_subject_data$X_prev,
							as.integer(reservoir_indices),
							S_xs_inv
						)
						#compute F-test threshold
						F_crit = qf(private$compute_lambda(), all_subject_data$rank_prev, private$t - all_subject_data$rank_prev)
						n = self$get_n()
						T_cutoff_sq = all_subject_data$rank_prev * (n - 1) / (n - all_subject_data$rank_prev) * F_crit
						min_sqd_dist_index = which(sqd_distances_times_two == min(sqd_distances_times_two))
						if (length(min_sqd_dist_index) > 1) min_sqd_dist_index = min_sqd_dist_index[1]
						if (sqd_distances_times_two[min_sqd_dist_index] < T_cutoff_sq){
							#we matched!
							match_num = max(private$m) + 1
							#update previous subject's match number
							private$m[reservoir_indices[min_sqd_dist_index]] = match_num
							#update current subject's match number
							private$m[private$t] = match_num
							#assign opposite
							1 - private$w[reservoir_indices[min_sqd_dist_index]]
						} else { #otherwise, randomize and add it to the reservoir
							private$m[private$t] = 0
							private$assign_wt_Bernoulli()
						}
					}
			if (should_run_asserts()) {
				if (is.na(private$m[private$t])){
					stop("no match data recorded")
				}
			}
			wt
		}
	),
	private = list(
		m = NULL,
		draw_ws_raw = function(r = 100){
			generate_permutations_matching_cpp(
				as.integer(private$m),
				as.integer(r),
				as.numeric(private$prob_T)
			)$w_mat
		},
		lambda = NULL,
		t_0_pct = NULL,
		morrison = NULL,
		p = NULL,
		compute_lambda = function(){
			private$lambda
		},
		too_early_to_match = function(){
			private$t <= private$t_0_pct * private$n ||
				is.null(private$X) ||
				ncol(as.matrix(private$X)) == 0L
		}
	)
)
