#' Kapelner and Krieger's (2021) Outcome-Weighted Sequential Matching-on-the-Fly Design
#'
#' A \code{\link[EDI:DesignSeqOneByOneKK14]{DesignSeqOneByOneKK14}} extension that
#' replaces KK14's unweighted Mahalanobis matching distance with a
#' \strong{response-weighted} squared distance: at each assignment, a per-covariate
#' weight vector is re-estimated from the responses observed so far (weighting each
#' covariate by the estimated strength of its association with the response, e.g. an
#' absolute standardized regression coefficient), and the new subject is matched to its
#' nearest reservoir subject under that weighted distance rather than the raw
#' (unweighted) Mahalanobis distance KK14 uses. Weighting the match by outcome
#' association means matching effort is spent preferentially on \emph{prognostic}
#' covariates (those that actually explain outcome variance) rather than equally on
#' every covariate, which is intended to improve estimator efficiency beyond what
#' outcome-agnostic matching achieves. \code{morrison = TRUE} additionally switches to
#' Morrison and Owen's (2025) alternative calibration of the matching-acceptance
#' threshold (differing in the fixed- vs. variable-\eqn{n} settings) and removes KK14's
#' burn-in wait before matching begins.
#'
#' @details
#' \strong{Weight estimation.} \code{compute_weights()} dispatches on
#' \code{response_type} to a corresponding \code{kk21_*_weights_cpp()} backend that fits
#' a per-covariate simple regression of the response on that covariate (given all
#' responses observed so far) and returns the absolute t-statistic (coefficient over its
#' standard error) as that covariate's weight: OLS for \code{"continuous"}, logistic for
#' \code{"incidence"}, negative-binomial (or, if \code{count_use_speedup = TRUE}, OLS on
#' \code{log(y + 1)}) for \code{"count"}, beta regression (or OLS on the logit scale if
#' \code{proportion_use_speedup = TRUE}) for \code{"proportion"}, Weibull/lognormal/
#' log-logistic AFT (or OLS on \code{log(y)} if
#' \code{survival_use_speedup_for_no_censoring = TRUE} and there is no censoring yet)
#' for \code{"survival"}, and proportional-odds (or OLS on the numeric-coerced level if
#' \code{ordinal_use_speedup = TRUE}) for \code{"ordinal"}. Weights are normalized to
#' sum to 1 and cached per-iteration in \code{private$iteration_weights} (retrievable
#' via \code{get_iteration_weights()}); the \code{*_use_speedup} flags trade weight
#' accuracy for speed by substituting a fast continuous-regression proxy for the
#' response-type-appropriate GLM/AFT/ordinal fit on every single assignment call.
#'
#' \strong{Weighted matching test.} The weighted squared distance from the new subject
#' to every reservoir subject is computed
#' (\code{compute_weighted_sqd_distances_cpp()}), and the match is accepted only if the
#' minimum weighted distance falls below the \code{private$compute_lambda()} quantile of
#' a \emph{bootstrapped} reference distribution of weighted pairwise distances among
#' subjects enrolled so far (\code{compute_bootstrapped_weighted_sqd_distances_cpp()},
#' \code{num_boot} resamples) — a nonparametric, simulation-based acceptance threshold,
#' in contrast to KK14's closed-form F-distribution threshold. As in KK14, an accepted
#' match receives the opposite treatment of its match; a rejected (or empty-reservoir)
#' draw is randomized and added to the reservoir.
#'
#' \strong{Fallback to KK14.} Before enough responses have accumulated to fit the
#' weight-estimation regressions reliably (fewer than \code{2 * (ncol(X) + 2)}
#' non-missing responses — two observations per regression parameter, at minimum
#' \code{ncol(X) + 2}), \code{assign_wt()} falls back to the inherited (unweighted) KK14
#' assignment rule entirely, via \code{super$assign_wt()}.
#'
#' @references Kapelner, A., and Krieger, A. M. (2014). "Matching on-the-fly: Sequential
#'   allocation with higher power and efficiency." \emph{Biometrics}, 70(2), 378-388,
#'   \doi{10.1111/biom.12148}, for the base matching-on-the-fly algorithm this class
#'   extends with outcome-weighted distances (Kapelner and Krieger, 2021); see also
#'   Morrison, T., and Owen, A. B. (2025) for the alternative \code{morrison = TRUE}
#'   threshold calibration referenced by the \code{morrison} argument.
#' @examples
#' seq_des = DesignSeqOneByOneKK21$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneKK21 = R6::R6Class("DesignSeqOneByOneKK21",
	inherit = DesignSeqOneByOneKK14,
	# DesignSeqOneByOneKK14 is built via define_design_class(), which requires
	# lock_objects = FALSE; R6 resolves lock_objects from the leaf class actually
	# instantiated, not inherited from a parent generator, so this subclass must repeat
	# it explicitly or super$initialize() fails trying to set fields KK14 itself owns
	# ("cannot add bindings to a locked environment" -- confirmed empirically).
	lock_objects = FALSE,
	public = list(
		#'
		#' @description Initialize a matching-on-the-fly sequential experimental design which matches based on
		#' Kapelner and Krieger (2021) with
		#' option to use matching parameters of Morrison and Owen (2025)
		#'
		#' @param  response_type 	The data type of response values which must be one of the following:
		#' 								"continuous",
		#' 								"incidence",
		#' 								"proportion",
		#' 								"count",
		#' 								"survival".
		#'                                                                 This package will enforce
		#' that all added responses via the \code{add_one_subject_response} method will be
		#' 								of the appropriate type.
		#' @param  prob_T  The probability of the treatment assignment. This defaults to \code{0.5}.
		#' @param include_is_missing_as_a_new_feature     If missing data is present in a variable,
		#'   should we include another dummy variable for its
		#'                                                                 missingness in addition to
		#' imputing its value? If the feature is type factor, instead of creating
		#' 								a new column, we allow missingness to be its own level. The default is \code{TRUE}.
		#' @param  n  		The sample size (if fixed). Default is \code{NULL} for not fixed.
		#' @param verbose A flag indicating whether messages should be
		#'   displayed to the user. Default is \code{FALSE}.
		#' @param lambda   The quantile cutoff of the subject distance distribution for determining
		#'   matches. If unspecified and \code{morrison = FALSE}, default is 10\%.
		#' @param t_0_pct  The percentage of total sample size n where matching begins. If unspecified
		#'   and \code{morrison = FALSE}, default is 35\%.
		#' @param morrison        Default is \code{FALSE} which implies matching via the KK14
		#'   algorithm using \code{lambda} and \code{t_0_pct} matching.
		#'                                                 If \code{TRUE}, we use Morrison and Owen
		#' (2025)'s formula for \code{lambda} which differs in the fixed n versus variable n
		#'                                                 settings and matching begins immediately
		#' with no wait for a certain reservoir size like in KK14.
		#' @param p                       The number of covariate features. Must be specified when
		#'   \code{morrison = TRUE} otherwise do not specify this argument.
		#' @param num_boot the number of bootstrap samples taken to approximate the subject-distance
		#'   distribution. Default is 500.
		#' @param count_use_speedup               Should we speed up the estimation of the weights in
		#'   the response = count case via a continuous regression on log(y + 1).
		#'                                                         instead of a negative binomial
		#' regression each time? This is at the expense of the weights being less accurate. Default is
		#' \code{TRUE}.
		#' @param proportion_use_speedup  Should we speed up the estimation of the weights in the
		#'   response = proportion case via a continuous regression on log(y / (1 - y))
		#'                                                         instead of a beta regression each
		#' time? This is at the expense of the weights being less accurate. Default is \code{TRUE}.
		#' @param survival_use_speedup_for_no_censoring   Should we speed up the estimation of the
		#'   weights in the response = survival case via a continuous regression on log(y)
		#'                                                         instead of a Weibull AFT regression
		#' each time, but only when there is no censoring in the data collected so far?
		#'                                                         This is at the expense of the
		#' weights being less accurate when censoring is present. Default is \code{TRUE}.
		#' @param ordinal_use_speedup     Should we speed up the estimation of the weights in the
		#'   response = ordinal case via a continuous regression on the ordinal levels coerced to
		#'   numeric.
		#'                                                         instead of a proportional odds
		#' model each time? This is at the expense of the weights being less accurate. Default is
		#' \code{TRUE}.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#' @param ... Extra arguments passed to the \code{DesignSeqOneByOneKK14} superclass.
		#'
		#' @return  A new `DesignSeqOneByOneKK21` object
		#'
		#' @examples
		#' \donttest{
		#' seq_des = DesignSeqOneByOneKK21$new(n = 6, response_type = "continuous")
		#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
		#' }
		#'
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
			num_boot = NULL,
			count_use_speedup = TRUE,
			proportion_use_speedup = TRUE,
			survival_use_speedup_for_no_censoring = TRUE,
			ordinal_use_speedup = TRUE,
			missingness_method = "impute",
			design_formula = ~ .,
			seed = NULL,
			...
		){
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, lambda, t_0_pct, morrison, p, missingness_method, design_formula, seed = seed, ...)
			if (is.null(num_boot)){
				num_boot = 500
			} else {
				if (should_run_asserts()) {
					assertCount(num_boot, positive = TRUE)
				}
			}
			private$num_boot = num_boot
			if (should_run_asserts()) {
				assertFlag(count_use_speedup)
				assertFlag(proportion_use_speedup)
				assertFlag(survival_use_speedup_for_no_censoring)
				assertFlag(ordinal_use_speedup)
			}
			private$count_use_speedup = count_use_speedup
			private$proportion_use_speedup = proportion_use_speedup
			private$survival_use_speedup_for_no_censoring = survival_use_speedup_for_no_censoring
			private$ordinal_use_speedup = ordinal_use_speedup
			private$uses_covariates = TRUE
			private$iteration_weights = list()
		},
		#' @description Retrieve the full history of normalized covariate weight
		#'   vectors computed by \code{compute_weights()} across every assignment call
		#'   so far (see class documentation), keyed by subject index \code{t}, for
		#'   inspecting how the outcome-informed weighting evolved as data accrued.
		#'
		#' @return A list of numeric weight vectors (one per assignment call at which
		#'   weights were computed), each summing to 1 and named by covariate.
		get_iteration_weights = function(){
			private$iteration_weights
		},
		#' @description Retrieve the normalized covariate weight vector from the most
		#'   recent assignment call (see class documentation for how weights are
		#'   estimated).
		#'
		#' @return  A numeric vector of weights, one per covariate, summing to 1 and
		#'   named by covariate; \code{NULL} if weights have not yet been computed
		#'   (e.g. still in the KK14 fallback regime).
		get_covariate_weights = function(){
			private$covariate_weights
		},
		#' @description Draw the next subject's treatment assignment via the KK21
		#'   outcome-weighted matching-on-the-fly rule (see class documentation):
		#'   falls back to unweighted KK14 matching if too few responses have
		#'   accumulated to estimate covariate weights, otherwise re-estimates weights,
		#'   matches to the nearest reservoir subject under the weighted distance if it
		#'   clears the bootstrapped acceptance threshold (assigning the opposite
		#'   treatment), or randomizes into the reservoir otherwise.
		#'
		#' @return 	The treatment assignment (0 or 1) for the next subject.
		assign_wt = function(){
			wt = 	if (private$too_early_to_match()){
						#we're early or the reservoir is empty, so randomize
						#cat("    assign_wt", class(self)[1], " t", private$t, "\n")
						private$m[private$t] = 0
						private$assign_wt_Bernoulli()
					} else if (is.null(private$X) | (sum(!is.na(private$y)) < 2 * (ncol(private$X) + 2))){
						#This is the number of responses collected before
						#the algorithm begins estimating the covariate-specific weights. If left unspecified this defaults to \code{2 * (p + 2)} i.e. two data points
						#for every glm regression parameter estimated (p covariates, the intercept and the coefficient of the additive treatment effect). The minimum
						#value is p + 2 to allow OLS to estimate. If this number of not met, we default to KK14 matching (which is better than nothing as it matches
						#the covariate distributions at the very least).
						super$assign_wt()
					} else {
						all_subject_data = private$compute_all_subject_data()
						#1) need to calculate the weights - this is different between KK21 and KK21stepwise
						raw_weights = private$compute_weights(all_subject_data)
						if (should_run_asserts()) {
							if (any(is.na(raw_weights)) | any(is.infinite(raw_weights)) | any(is.nan(raw_weights)) | any(raw_weights < 0)){
								stop("raw weight values illegal in design ", class(self)[1])
							}
						}
						#ensure the weights are normalized
						private$covariate_weights = raw_weights / sum(raw_weights)
						names(private$covariate_weights) = colnames(all_subject_data$X_all_with_y_scaled)
						private$iteration_weights[[private$t]] = private$covariate_weights
						#cat("    assign_wt_KK21 using sorted weights t", private$t, "weights", sort(weights), "\n")
						#2) now iterate over all items in reservoir and calculate the weighted sqd distiance vs new guy
						reservoir_indices = which(private$m == 0)
						if (length(reservoir_indices) == 0){
							private$m[private$t] = 0
							return(private$assign_wt_Bernoulli())
						}
						weighted_features = colnames(all_subject_data$X_all_with_y_scaled)
						available_features = colnames(all_subject_data$X_all_scaled)
						common_weighted_features = intersect(weighted_features, available_features)
							if (length(common_weighted_features) == 0){
								private$m[private$t] = 0
								private$assign_wt_Bernoulli()
							} else {
								x_new = all_subject_data$xt_all_scaled[common_weighted_features]
								X_all_scaled_col_subset = all_subject_data$X_all_scaled[, common_weighted_features, drop = FALSE]
								covariate_weights_for_distance = private$covariate_weights[common_weighted_features]
#						weighted_sqd_distances = array(NA, length(reservoir_indices))
#						for (r in 1 : length(reservoir_indices)){
#							x_r_x_new_delta = x_new - X_all_scaled_col_subset[reservoir_indices[r], ]
#							weighted_sqd_distances[r] = x_r_x_new_delta^2 %*% private$covariate_weights
#						}
								weighted_sqd_distances = compute_weighted_sqd_distances_cpp(
														x_new,
													    X_all_scaled_col_subset,
													    reservoir_indices,
													    covariate_weights_for_distance
													 )
								#3) find minimum weighted sqd distiance index
								min_weighted_sqd_dist_index = which(weighted_sqd_distances == min(weighted_sqd_distances))
								#generate a cutoff for the weighted minimum distance squared based on bootstrap
#						bootstrapped_weighted_sqd_distances = array(NA, private$num_boot)
#						for (b in 1 : private$num_boot){
#							two_xs  = X_all_scaled_col_subset[sample.int(private$t, 2), ] #private$X[sample_int_ccrank(private$t, 2, rep(1, (private$t))), ]
#							delta_x = two_xs[1, ] - two_xs[2, ]
#							bootstrapped_weighted_sqd_distances[b] = delta_x^2 %*% private$covariate_weights
#						}
								bootstrapped_weighted_sqd_distances = compute_bootstrapped_weighted_sqd_distances_cpp(
																    X_all_scaled_col_subset,
																    covariate_weights_for_distance,
																    private$t,
																    private$num_boot
																  )
								min_weighted_dsqd_cutoff_sq = stats::quantile(bootstrapped_weighted_sqd_distances, private$compute_lambda())
								#5) Now, does the minimum make the cut?
								if (length(weighted_sqd_distances[min_weighted_sqd_dist_index]) > 1 || length(min_weighted_dsqd_cutoff_sq) > 1){
									min_weighted_sqd_dist_index = min_weighted_sqd_dist_index[1] #if there's a tie, just take the first one
								}
								#  (a) if it's smaller than the threshold, we're in business: match it
								if (weighted_sqd_distances[min_weighted_sqd_dist_index] < min_weighted_dsqd_cutoff_sq){
									new_match_id = max(private$m, na.rm = TRUE) + 1 #the ID of a new match
									private$m[reservoir_indices[min_weighted_sqd_dist_index]] = new_match_id
									private$m[private$t] = new_match_id
									#assign opposite
									1 - private$w[reservoir_indices[min_weighted_sqd_dist_index]]
								# (b) otherwise, randomize and add it to the reservoir
								} else {
									private$m[private$t] = 0
									private$assign_wt_Bernoulli()
								}
							}
					}
			if (should_run_asserts()) {
				if (is.na(private$m[private$t])){ #this should never happen
					stop("no match data recorded")
				}
			}
			wt
		}
	),
	private = list(
		covariate_weights = NULL,
		iteration_weights = NULL,
		num_boot = NULL,
		count_use_speedup = NULL,
		proportion_use_speedup = NULL,
		survival_use_speedup_for_no_censoring = NULL,
		ordinal_use_speedup = NULL,
		duplicate = function(){
			d = super$duplicate()
			d
		},
		compute_weights = function(all_subject_data){
			xs = all_subject_data$X_all_with_y_scaled
			i_y_present = which(!(is.na(private$y) & is.na(private$y_L) & is.na(private$y_R)))
			y_eff = self$get_effective_time()
			dead_eff = self$get_effective_dead()
			ys = y_eff[i_y_present]
			deads = dead_eff[i_y_present]
			if (private$too_early_to_match()){
				return(rep(1, all_subject_data$rank_all_with_y_scaled))
			}
			if (private$response_type == "continuous"){
				return(kk21_continuous_weights_cpp(as.matrix(xs), as.numeric(ys)))
			}
			if (private$response_type == "incidence"){
				return(kk21_logistic_weights_cpp(as.matrix(xs), as.numeric(ys)))
			}
			if (private$response_type == "count" && private$count_use_speedup){
				return(kk21_continuous_weights_cpp(as.matrix(xs), as.numeric(log(ys + 1))))
			}
			if (private$response_type == "proportion" && private$proportion_use_speedup){
				return(kk21_continuous_weights_cpp(as.matrix(xs), as.numeric(log(ys / (1 - ys)))))
			}
			if (private$response_type == "survival"){
				if (private$survival_use_speedup_for_no_censoring && all(deads == 1)){
					return(kk21_continuous_weights_cpp(as.matrix(xs), as.numeric(log(ys))))
				}
				return(kk21_survival_weights_cpp(as.matrix(xs), as.numeric(ys), as.numeric(deads)))
			}
			if (private$response_type == "count" && !private$count_use_speedup){
				return(kk21_negbin_weights_cpp(as.matrix(xs), as.numeric(ys)))
			}
			if (private$response_type == "proportion" && !private$proportion_use_speedup){
				return(kk21_beta_weights_cpp(as.matrix(xs), as.numeric(ys)))
			}
			if (private$response_type == "ordinal" && private$ordinal_use_speedup){
				return(kk21_continuous_weights_cpp(as.matrix(xs), as.numeric(ys)))
			}
			if (private$response_type == "ordinal" && !private$ordinal_use_speedup){
				return(kk21_ordinal_weights_cpp(as.matrix(xs), as.numeric(ys)))
			}
			# Fallback loop for any future response types (should not reach here for current types)
			raw_weights = array(NA, all_subject_data$rank_all_with_y_scaled)
			for (j in 1 : all_subject_data$rank_all_with_y_scaled){
				raw_weights[j] = private[[paste0("compute_weight_KK21_", private$response_type)]](
					xs,
					ys,
					deads,
					j
				)
			}
			raw_weights
		},
		compute_weight_KK21_continuous = function(xs_to_date, ys_to_date, deaths_to_date, j){
			if (nrow(xs_to_date) == 1){
				.Machine$double.eps
			} else {
				mod = fast_ols_with_var_cpp(cbind(1, xs_to_date[, j, drop = FALSE]), ys_to_date)
				abs(mod$b[2] / sqrt(mod$ssq_b_j))
			}
#			ols_mod = lm(ys_to_date ~ xs_to_date[, j])
#			summary_ols_mod = suppressWarnings(stats::coef(summary(ols_mod)))
#
#
#			#1 - stats::coef(summary(logistic_regr_mod))[2, 4]
#			#if there was only one row, then this feature was all one unique value... so send back a weight of nada
#			ifelse(nrow(summary_ols_mod) >= 2, abs(summary_ols_mod[2, 3]) )
		},
		compute_weight_KK21_incidence = function(xs_to_date, ys_to_date, deaths_to_date, j){
			if (nrow(xs_to_date) == 1){
				.Machine$double.eps
			} else {
				mod = fast_logistic_regression_with_var(as.matrix(cbind(1, xs_to_date[, j, drop = FALSE])), as.numeric(ys_to_date))
				abs(mod$b[2] / sqrt(mod$ssq_b_2))
			}
		},
		compute_weight_KK21_count = function(xs_to_date, ys_to_date, deaths_to_date, j){
			if (!private$count_use_speedup){
				tryCatch({
					negbin_regr_mod = suppressWarnings(MASS::glm.nb(y ~ x, data = data.frame(x = xs_to_date[, j], y = ys_to_date)))
					summary_negbin_regr_mod = stats::coef(summary_glm_lean(negbin_regr_mod))
					#1 - stats::coef(summary(negbin_regr_mod))[2, 4]
					#if there was only one row, then this feature was all one unique value... so send back a weight of nada
					return(ifelse(nrow(summary_negbin_regr_mod) >= 2, abs(summary_negbin_regr_mod[2, 3]), .Machine$double.eps))
				}, error = function(e){}) #sometimes these glm's blow up and we don't really care that much
			}
			#if that didn't work, let's just use the continuous weights on a transformed proportion
			private$compute_weight_KK21_continuous(xs_to_date, log(ys_to_date + 1), deaths_to_date, j)
		},
		compute_weight_KK21_proportion = function(xs_to_date, ys_to_date, deaths_to_date, j){
			#sometimes the beta regression is unstable...
			tryCatch({
				mod = fast_beta_regression_with_var(X = as.matrix(cbind(1, xs_to_date[, j])), y = as.numeric(ys_to_date))
				weight = abs(mod$b[2] / sqrt(mod$ssq_b_2))
				if (!is.na(weight)){
					return(weight)
				}
			}, error = function(e){})
			#if that didn't work, default to OLS and logit the proportions... again... this doesn't matter since we are just trying to get weights
			#and we are not relying on the model assumptions being true
			private$compute_weight_KK21_continuous(xs_to_date, logit(ys_to_date), deaths_to_date, j)
		},
		compute_weight_KK21_survival = function(xs_to_date, ys_to_date, deaths_to_date, j){
			surv_obj = survival::Surv(ys_to_date, deaths_to_date)
			#sometimes the weibull is unstable... so try other distributions... this doesn't matter since we are just trying to get weights
			#and we are not relying on the model assumptions
			for (dist in c("weibull", "lognormal", "loglogistic")){
				surv_regr_mod = robust_survreg_with_surv_object(surv_obj, xs_to_date[, j], dist = dist)
				if (is.null(surv_regr_mod)){
					next
				}
				summary_surv_regr_mod = suppressWarnings(summary(surv_regr_mod)$table)
				if (any(is.nan(summary_surv_regr_mod))){
					next
				}
				weight = ifelse(nrow(summary_surv_regr_mod) >= 2, abs(summary_surv_regr_mod[2, 3]), NA)
				#1 - summary(weibull_regr_mod)$table[2, 4]
				if (!is.na(weight)){ #sometimes these glm's blow up and we don't really care that much
					return(weight)
				}
			}
			#if that didn't work, default to OLS and log the survival times... again... this doesn't matter since we are just trying to get weights
			#and we are not relying on the model assumptions being true, this ignores censoring
			private$compute_weight_KK21_continuous(xs_to_date, log(ys_to_date), deaths_to_date, j)
		},
		compute_weight_KK21_ordinal = function(xs_to_date, ys_to_date, deaths_to_date, j){
			#sometimes the ordinal regression is unstable...
			tryCatch({
				ordinal_mod = suppressWarnings(MASS::polr(factor(y) ~ x, data = data.frame(x = xs_to_date[, j], y = ys_to_date), Hess = TRUE))
				summary_ordinal_mod = stats::coef(summary(ordinal_mod))
				return(ifelse(nrow(summary_ordinal_mod) >= 1, abs(summary_ordinal_mod[1, 3]), .Machine$double.eps))
			}, error = function(e){})
			#if that didn't work, default to OLS
			private$compute_weight_KK21_continuous(xs_to_date, ys_to_date, deaths_to_date, j)
		}
	)
)
