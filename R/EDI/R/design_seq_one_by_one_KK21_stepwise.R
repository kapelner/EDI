#' Stepwise Variant of the KK21 Outcome-Weighted Sequential Matching Design
#'
#' A \code{\link[EDI:DesignSeqOneByOneKK21]{DesignSeqOneByOneKK21}} variant that
#' computes its per-covariate matching weights via \strong{forward stepwise selection}
#' (\code{compute_weights_KK21stepwise()}) instead of KK21's independent
#' marginal-association regressions: covariates are added to a growing "selected" set
#' one at a time, at each step choosing whichever remaining covariate has the largest
#' absolute association statistic \emph{conditional on} (i.e. in a model that also
#' includes) the covariates already selected and the treatment-assignment column,
#' rather than each covariate's association with the response considered in isolation.
#' This targets the case where covariates are mutually correlated: KK21's marginal
#' weights can assign similar high weight to several collinear prognostic covariates
#' (effectively double-counting the same information), whereas the stepwise conditional
#' weights down-weight a covariate once its explanatory content is already captured by
#' previously selected covariates.
#'
#' @details
#' \strong{Weight computation.} For each response type, a family-appropriate model
#' (OLS/logistic/negative-binomial/beta/AFT survival/proportional-odds, matching the
#' same response-type dispatch and \code{*_use_speedup} fast-path conventions as
#' \code{\link[EDI:DesignSeqOneByOneKK21]{DesignSeqOneByOneKK21}}) is repeatedly refit,
#' each time regressing the response on one candidate remaining covariate plus all
#' previously selected covariates plus the treatment column \code{ws}; the candidate
#' with the largest absolute association statistic is selected next and assigned that
#' statistic as its weight, then removed from the candidate pool, and the process
#' repeats until every covariate has been assigned a weight (an \eqn{O(p^2)} number of
#' model fits per assignment call, for \eqn{p} covariates). If a candidate's model fit
#' fails to converge (e.g. perfect separation or rank deficiency) partway through, the
#' remaining not-yet-selected covariates' weights are left \code{NA} internally and then
#' replaced with 0 (excluding them from the weighted matching distance) rather than
#' propagating the failure.
#'
#' \strong{Everything else is inherited from KK21.} Burn-in fallback to KK14, the
#' bootstrapped acceptance-threshold test, matched-pair assignment, and the
#' \code{morrison}/\code{lambda}/\code{t_0_pct} matching-schedule options are all
#' unchanged from \code{\link[EDI:DesignSeqOneByOneKK21]{DesignSeqOneByOneKK21}}; only
#' \emph{how} the covariate weight vector is computed differs.
#'
#' @references Kapelner, A., and Krieger, A. M. (2014). "Matching on-the-fly: Sequential
#'   allocation with higher power and efficiency." \emph{Biometrics}, 70(2), 378-388,
#'   \doi{10.1111/biom.12148}, for the base matching-on-the-fly algorithm; the
#'   outcome-weighted extension follows Kapelner and Krieger (2021), with this class
#'   using a forward-stepwise (rather than marginal) weight-estimation scheme. See also
#'   Morrison, T., and Owen, A. B. (2025) for the alternative \code{morrison = TRUE}
#'   threshold calibration referenced by the \code{morrison} argument.
#' @examples
#' seq_des = DesignSeqOneByOneKK21stepwise$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' @export
DesignSeqOneByOneKK21stepwise = R6::R6Class("DesignSeqOneByOneKK21stepwise",
	inherit = DesignSeqOneByOneKK21,
	# See DesignSeqOneByOneKK21's identical note: DesignSeqOneByOneKK14 (further up this
	# chain) is built via define_design_class(), which requires lock_objects = FALSE;
	# every subclass down the chain must repeat it explicitly.
	lock_objects = FALSE,
	public = list(
		#'
		#' @description Initialize a matching-on-the-fly sequential experimental design
		#' whose covariate matching weights are computed via forward stepwise
		#' selection (see class documentation), based on the stepwise version of
		#' Kapelner and Krieger (2021) with option to use matching parameters of Morrison and Owen
		#' (2025)
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
		#' @param ... Extra arguments passed to the \code{DesignSeqOneByOneKK21} superclass.
		#' @return  A new `DesignSeqOneByOneKK21stepwise` object
		#'
		#' @examples
		#' \dontrun{
		#' seq_des = DesignSeqOneByOneKK21stepwise$new(n = 6, response_type = "continuous")
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
			...
		){
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, lambda, t_0_pct, morrison, p, num_boot, count_use_speedup, proportion_use_speedup, survival_use_speedup_for_no_censoring, ordinal_use_speedup, missingness_method, design_formula, ...)
		}
	),
	private = list(
		compute_weights = function(all_subject_data){ #stepwise function
			xs = all_subject_data$X_all_with_y_scaled
			ys = all_subject_data$y_all
			ws = all_subject_data$w_all_with_y_scaled
			deads = all_subject_data$dead_all
			# The C++ stepwise functions initialize all weights to NA and fill them as each
			# step succeeds. When perfect separation (or rank deficiency) causes an early
			# break, the remaining features retain NA. Replace NA with 0 so those features
			# are simply excluded from distance matching rather than crashing the design.
			na0 = function(w) { w[is.na(w)] = 0; w }
			if (private$response_type == "continuous"){
				return(na0(kk21_stepwise_continuous_weights_cpp(xs, ys, ws)))
			}
			if (private$response_type == "incidence"){
				return(na0(kk21_stepwise_logistic_weights_cpp(xs, ys, ws)))
			}
			if (private$response_type == "count" && private$count_use_speedup){
				return(na0(kk21_stepwise_continuous_weights_cpp(xs, log(ys + 1), ws)))
			}
			if (private$response_type == "proportion" && private$proportion_use_speedup){
				ys_adj = ys
				ys_adj[ys_adj == 0] = .Machine$double.eps
				ys_adj[ys_adj == 1] = 1 - .Machine$double.eps
				return(na0(kk21_stepwise_continuous_weights_cpp(xs, log(ys_adj / (1 - ys_adj)), ws)))
			}
			if (private$response_type == "survival"){
				if (private$survival_use_speedup_for_no_censoring && all(deads == 1)){
					return(na0(kk21_stepwise_continuous_weights_cpp(xs, log(ys), ws)))
				}
				return(na0(kk21_stepwise_survival_weights_cpp(xs, ys, deads, ws)))
			}
			if (private$response_type == "count" && !private$count_use_speedup){
				return(na0(kk21_stepwise_negbin_weights_cpp(xs, ys, ws)))
			}
			if (private$response_type == "proportion" && !private$proportion_use_speedup){
				return(na0(kk21_stepwise_beta_weights_cpp(xs, ys, ws)))
			}
			if (private$response_type == "ordinal" && private$ordinal_use_speedup){
				return(na0(kk21_stepwise_continuous_weights_cpp(xs, ys, ws)))
			}
			if (private$response_type == "ordinal" && !private$ordinal_use_speedup){
				return(na0(kk21_stepwise_ordinal_weights_cpp(xs, ys, ws)))
			}
			# Fallback for future response types (should not reach here for current types)
			private[[paste0("compute_weights_KK21stepwise_", private$response_type)]](
				xs,
				ys,
				ws,
				deads
			)
		},
		compute_weights_KK21stepwise = function(X, response_obj, ws, abs_z_compute_fun){
			p = ncol(X)
			weights = array(NA, p)
			j_droppeds = integer(0)
			X_stepwise = matrix(NA, nrow = nrow(X), ncol = p)
			n_stepwise = 0L
			repeat {
				covs_to_try = setdiff(seq_len(p), j_droppeds)
				if (length(covs_to_try) == 0){ #if there's none left, we jet
					break
				}
				abs_approx_zs = array(NA, p)
				X_sw_current = X_stepwise[, seq_len(n_stepwise), drop = FALSE]
				for (j in covs_to_try){
					abs_approx_zs[j] = abs_z_compute_fun(response_obj, cbind(X[, j], X_sw_current, ws))
				}
				j_max = which.max(abs_approx_zs)
				weights[j_max] = abs_approx_zs[j_max]
				j_droppeds = c(j_droppeds, j_max)
				n_stepwise = n_stepwise + 1L
				X_stepwise[, n_stepwise] = X[, j_max]
			}
#			if (any(is.na(weights))){
#				stop("boom")
#			}
			weights
		},
		compute_weights_KK21stepwise_continuous = function(xs, ys, ws, ...){
			private$compute_weights_KK21stepwise(xs, ys, ws, function(response_obj, covariate_data_matrix){
#				ols_mod = lm(response_obj ~ covariate_data_matrix)
#				abs(stats::coef(suppressWarnings(summary(ols_mod)))[2, 3])
				mod = fast_ols_with_var_cpp(cbind(1, covariate_data_matrix), response_obj)
				abs(mod$b[2] / sqrt(mod$ssq_b_j))
			})
		},
		compute_weights_KK21stepwise_incidence = function(xs, ys, ws, ...){
			private$compute_weights_KK21stepwise(xs, ys, ws, function(response_obj, covariate_data_matrix){
#				logistic_regr_mod = suppressWarnings(glm(response_obj ~ covariate_data_matrix, family = "binomial"))
#				abs(stats::coef(summary_glm_lean(logistic_regr_mod))[2, 3])
				mod = fast_logistic_regression_with_var(cbind(1, covariate_data_matrix), response_obj)
				abs(mod$b[2] / sqrt(mod$ssq_b_2))
			})
		},
		compute_weights_KK21stepwise_count = function(xs, ys, ws, ...){
			if (!private$count_use_speedup){
				weight = private$compute_weights_KK21stepwise(xs, ys, ws, function(response_obj, covariate_data_matrix){
							negbin_regr_mod = robust_negbinreg(response_obj ~ ., cbind(data.frame(response_obj = response_obj), covariate_data_matrix))
							abs(stats::coef(summary_glm_lean(negbin_regr_mod))[2, 3])
			#				mod = fast_negbin_regression_with_var(cbind(1, covariate_data_matrix), response_obj)
			#				abs(mod$b[2] / sqrt(mod$ssq_b_2))
						})
				if (!is.na(weight)){
					return(weight)
				}
			}
			private$compute_weights_KK21stepwise_continuous(xs, log(ys + 1), ws, ...)
		},
		compute_weights_KK21stepwise_proportion = function(xs, ys, ws, ...){
			if (!private$proportion_use_speedup){
				tryCatch({
					weight = 	private$compute_weights_KK21stepwise(xs, ys, ws, function(response_obj, covariate_data_matrix){
									mod = fast_beta_regression_with_var(X = cbind(1, covariate_data_matrix), y = response_obj)
									abs(mod$b[2] / sqrt(mod$ssq_b_2))
								})
					if (!is.na(weight)){
						return(weight)
					}
				}, error = function(e){})
			}
			#if that didn't work, let's just use the continuous weights on a transformed proportion
			ys[ys == 0] = .Machine$double.eps
			ys[ys == 1] = 1 - .Machine$double.eps
			private$compute_weights_KK21stepwise_continuous(xs, log(ys / (1 - ys)), ws, ...)
		},
		compute_weights_KK21stepwise_survival = function(xs, ys, ws, deaths){
			private$compute_weights_KK21stepwise(xs, survival::Surv(ys, deaths), ws, function(response_obj, covariate_data_matrix){
				#sometimes the weibull is unstable... so try other distributions... this doesn't matter since we are just trying to get weights
				#and we are not relying on the model assumptions
				for (dist in c("weibull", "lognormal", "loglogistic")){
					surv_regr_mod = robust_survreg_with_surv_object(response_obj, covariate_data_matrix, dist = dist)
					if (is.null(surv_regr_mod)){
						break
					}
					summary_surv_regr_mod = suppressWarnings(summary(surv_regr_mod)$table)
					if (any(is.nan(summary_surv_regr_mod))){
						break
					}
					weight = ifelse(nrow(summary_surv_regr_mod) >= 2, abs(summary_surv_regr_mod[2, 3]), NA)
					#1 - summary(weibull_regr_mod)$table[2, 4]
					if (!is.na(weight)){
						return(weight)
					}
				}
				#if that didn't work, default to OLS and log the survival times... again... this doesn't matter since we are just trying to get weights
				#and we are not relying on the model assumptions
				ols_mod = lm(log(as.numeric(response_obj)[1 : length(response_obj)]) ~ covariate_data_matrix)
				abs(stats::coef(suppressWarnings(summary(ols_mod)))[2, 3])
			})
		},
		compute_weights_KK21stepwise_ordinal = function(xs, ys, ws, ...){
			if (!private$ordinal_use_speedup){
				tryCatch({
					weight = private$compute_weights_KK21stepwise(xs, ys, ws, function(response_obj, covariate_data_matrix){
						ordinal_mod = suppressWarnings(MASS::polr(factor(response_obj) ~ ., data = data.frame(response_obj = response_obj, covariate_data_matrix), Hess = TRUE))
						summary_ordinal_mod = stats::coef(summary(ordinal_mod))
						abs(summary_ordinal_mod[1, 3])
					})
					if (!is.na(weight)){
						return(weight)
					}
				}, error = function(e){})
			}
			private$compute_weights_KK21stepwise_continuous(xs, ys, ws, ...)
		}
	)
)
