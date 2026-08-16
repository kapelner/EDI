#' A Fixed Design
#'
#' An abstract R6 Class encapsulating the data and functionality for a fixed experimental design.
#' This class takes care of whole-experiment randomization.
#'
#' @keywords internal
#' @examples
#' \dontrun{
#' des = DesignFixed$new(n = 10, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10)))
#' des$assign_w_to_all_subjects()
#' }
DesignFixed = R6::R6Class("DesignFixed",
	lock_objects = FALSE,
	inherit = DesignMatching,
	public = list(
		#' @description Initialize a fixed experimental design
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Probability of treatment assignment.
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param  n  		The sample size.
		#' @param verbose A flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#' @param ... Extra arguments passed to the \code{Design} superclass.
		#'
		#' @return  A new `DesignFixed` object
		initialize = function(
				response_type,
				prob_T = 0.5,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL,
				...
			) {
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed, ...)
		},
		#' @description Assign treatment to all subjects in the fixed experiment.
		#' @param w_precomputed Optional \{0,1\} numeric vector of length n. If supplied the
		#'   allocation is used directly and
		#'   \code{draw_ws_according_to_design} is not called (avoids e.g. the Java
		#'   round-trip for \code{DesignFixedGreedy}).
		assign_w_to_all_subjects = function(w_precomputed = NULL){
			if (!is.null(w_precomputed)) {
				private$w[1:self$get_n()] = as.numeric(w_precomputed)
			} else {
				private$w[1:self$get_n()] = private$draw_ws_raw(1)[, 1]
			}
		},
		#' @description Add all subjects' covariates to a fixed design at once.
		#'
		#' @param X_all A data frame containing the full covariate matrix.
		#' @return Invisibly returns the design object.
		add_all_subjects_to_experiment = function(X_all){
			n_all = nrow(X_all)
			n_expected = self$get_n()
			if (should_run_asserts()) {
				assertClass(X_all, "data.frame")
				self$assert_fixed_sample()
				assertStrataClusterArgs(
					strata_cols = private$strata_cols,
					cluster_col = private$cluster_col,
					data = X_all,
					context = paste0(class(self)[1L], "$add_all_subjects_to_experiment")
				)
				if (n_all != n_expected){
					stop("X_all must have exactly ", n_expected, " rows for this fixed design.")
				}
				if (private$t > 0L || nrow(private$Xraw) > 0L){
					stop("Subjects have already been added to this design.")
				}
			}
			private$Xraw = copy(as.data.table(X_all))
			private$p_raw_t = ncol(private$Xraw)
			private$t = n_all
			private$covariate_impute_if_necessary_and_then_create_model_matrix()
			invisible(self)
		},
		#' @description Add all subject responses for a fixed design.
		#'
		#' @param ys The exact responses as a numeric vector, \code{NA} for any
		#'   subject whose response is censored (supply \code{y_Ls}/\code{y_Rs}
		#'   for those instead).
		#' @param y_Ls The censored-response lower bounds, \code{NA} for any
		#'   subject with an exact response in \code{ys}. Right-censored:
		#'   the last known event-free time (pair with \code{y_Rs = Inf}).
		#'   Left-censored: \code{0}, stated explicitly. Interval-censored:
		#'   the interval's lower bound. Storage accepts any well-formed
		#'   left-/interval-censored value; whether a given \code{Inference}
		#'   class can actually consume it depends on that class (most
		#'   survival \code{Inference} classes still only accept exact/
		#'   right-censored data and will reject construction with a clear
		#'   error otherwise -- see individual class docs).
		#' @param y_Rs The censored-response upper bounds, \code{NA} for any
		#'   subject with an exact response in \code{ys}. Right-censored:
		#'   \code{Inf}. Left-/interval-censored: the confirmed-by time /
		#'   interval upper bound.
		add_all_subject_responses = function(ys = NULL, y_Ls = NULL, y_Rs = NULL){
			if (is.null(ys)) ys = rep(NA_real_, private$t)
			if (is.null(y_Ls)) y_Ls = rep(NA_real_, private$t)
			if (is.null(y_Rs)) y_Rs = rep(NA_real_, private$t)
			if (should_run_asserts()) {
				self$assert_fixed_sample()
				if (private$response_type == "ordinal" && is.factor(ys)){
					assertFactor(ys, len = private$t, ordered = TRUE, any.missing = FALSE)
				} else {
					assertNumeric(ys, len = private$t)
				}
				assertNumeric(y_Ls, len = private$t)
				assertNumeric(y_Rs, len = private$t)
			}
			has_y = if (is.factor(ys)) !is.na(as.integer(ys)) else !is.na(ys)
			has_bounds = !is.na(y_Ls) & !is.na(y_Rs)
			# Always enforced, never gated behind should_run_asserts() -- see the
			# note above Design's equivalent checks (design_abstract.R): a
			# left-/interval-censored row that slips past this gate is stored
			# silently and later misread by get_effective_time()/
			# get_effective_dead() as ordinary right-censoring, not a cryptic
			# error.
			partial_bounds = xor(is.na(y_Ls), is.na(y_Rs))
			if (any(partial_bounds)){
				stop("y_Ls and y_Rs must be supplied together (both or neither) for every subject.")
			}
			if (any(has_y & has_bounds)){
				stop("Supply either ys or (y_Ls, y_Rs) for each subject, not both.")
			}
			if (any(!has_y & !has_bounds)){
				stop("Each subject needs either ys or both y_Ls and y_Rs.")
			}
			if (any(has_bounds) && private$response_type != "survival"){
				stop("censored observations are only available for survival response types")
			}
			if (any(has_bounds)){
				if (any(!is.finite(y_Ls[has_bounds]) | y_Ls[has_bounds] < 0)){
					stop("y_L must be finite and >= 0 for every censored subject.")
				}
				if (any(!(y_Rs[has_bounds] > y_Ls[has_bounds]))){
					stop("y_R must be strictly greater than y_L for every censored subject.")
				}
			}
			if (should_run_asserts()) {
				private$assert_y(ys[has_y], private$response_type)
			}

			if (private$response_type == "ordinal" && is.factor(ys)){
				levs = levels(ys)
				private$ordinal_levels = levs
				if (private$response_type_original == "ordinal" && is.null(private$original_ordinal_levels)){
					private$original_ordinal_levels = levs
				}
				ys = as.integer(ys)
			}
			private$y = as.numeric(ys)
			private$y_original = as.numeric(ys)
			private$y_L = as.numeric(y_Ls)
			private$y_R = as.numeric(y_Rs)
			private$y_i_t_i = as.list(seq_len(private$t))
		},
		#' @description Overwrite all subject assignments for a fixed design.
		#'
		#' @param w A \{0,1\} vector of subject assignments (1 = treated, 0 = control).
		overwrite_all_subject_assignments = function(w){
			if (should_run_asserts()) {
				assertIntegerish(w, lower = 0, upper = 1, any.missing = FALSE, len = private$t)
				if (any(!(w %in% c(0L, 1L)))) {
					stop("overwrite_all_subject_assignments: w must contain only 0 (control) or 1 (treated).")
				}
			}
			private$w = as.numeric(w)
		}
	),
	private = list()
)
