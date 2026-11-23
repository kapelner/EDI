#' A Fixed Design
#'
#' An abstract R6 Class encapsulating the data and functionality for a fixed experimental design.
#' This class takes care of whole-experiment randomization.
#'
#' @keywords internal
#' @examples
#' # DesignFixed is abstract and cannot be instantiated directly; construct a
#' # concrete subclass instead, e.g.:
#' des = DesignFixedBernoulli$new(n = 10, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10)))
#' des$assign_w_to_all_subjects()
DesignFixed = R6::R6Class("DesignFixed",
	lock_objects = FALSE,
	inherit = Design,
	public = list(
		#' @description Initialize a fixed experimental design
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param  prob_T  Probability of treatment assignment.
		#' @param include_is_missing_as_a_new_feature     Flag for missingness indicators.
		#' @param n The sample size. If \code{NULL} (default), \code{n} is set to
		#'   \code{nrow(X_all)} when the subjects are added with
		#'   \code{add_all_subjects_to_experiment()}; a given \code{n} must equal
		#'   \code{nrow(X_all)}. Assigning before the subjects are added needs \code{n}
		#'   (a covariate-free design such as iBCRD or Bernoulli can then assign without
		#'   \code{X}).
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
		#'   \code{draw_ws_according_to_design} is not called (avoids re-running a
		#'   costly allocation search, e.g. for \code{DesignFixedGreedy}).
		assign_w_to_all_subjects = function(w_precomputed = NULL){
			private$assert_n_known_for_assignment()
			if (!is.null(w_precomputed)) {
				w_precomputed = private$validate_w_precomputed(w_precomputed)
				private$w[1:self$get_n()] = w_precomputed
			} else {
				private$w[1:self$get_n()] = private$draw_ws_raw(1)[, 1]
			}
		},
		#' @description Add all subjects' covariates to a fixed design at once.
		#'
		#' @param X_all A data frame containing the full covariate matrix.
		#' @return Invisibly returns the design object.
		add_all_subjects_to_experiment = function(X_all){
			if (should_run_asserts()) assertClass(X_all, "data.frame")
			n_all = nrow(X_all)
			# v1.0.6-TODO-298 (owner ruling 2026-11-23): a fixed design built without n takes n from
			# X_all. Fixed designs with covariates carry n in X_all, and the covariate-free ones
			# (iBCRD, Bernoulli) can still be given n to assign without X. Always on.
			if (!isTRUE(private$fixed_sample) && private$t == 0L) {
				private$set_n_from_subjects(n_all)
			}
			n_expected = self$get_n()
			# Owner wording (2026-11-23); always enforced, a wrong-length X_all is never stored.
			if (n_all != n_expected){
				stop("X_all must have exactly n = ", n_expected, " rows, but has ", n_all, ".", call. = FALSE)
			}
			if (should_run_asserts()) {
				self$assert_fixed_sample()
				assertStrataClusterArgs(
					strata_cols = private$strata_cols,
					cluster_col = private$cluster_col,
					data = X_all,
					context = paste0(class(self)[1L], "$add_all_subjects_to_experiment")
				)
				if (private$t > 0L || nrow(private$Xraw) > 0L){
					stop("Subjects have already been added to this design.")
				}
			}
			# as.data.table.data.frame() already allocates an independent table;
			# only an incoming data.table needs an explicit copy to avoid aliasing
			# the caller's object.
			private$Xraw = if (is.data.table(X_all)) copy(X_all) else as.data.table(X_all)
			private$p_raw_t = ncol(private$Xraw)
			private$t = n_all
			private$X = NULL
			private$Ximp = NULL
			private$model_matrix_stale = TRUE
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
					# NA allowed: an NA in ys marks a censored subject entered through y_Ls/y_Rs;
					# non-survival NAs are rejected below, always on (v1.0.6-TODO-93).
					# checkmate-loose: NA in ys marks a censored row whose response is in y_Ls/y_Rs.
					assertNumeric(ys, len = private$t)
				}
				# NA allowed in y_Ls/y_Rs: NA marks a subject with an exact response in ys.
				# checkmate-loose: NA marks a row with an exact response in ys.
				assertNumeric(y_Ls, len = private$t)
				# checkmate-loose: NA marks an exact row; y_Rs = Inf is right-censored.
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
				stop(missing_response_error_message(private$response_type, which(!has_y & !has_bounds)[1L], vectorized = TRUE), call. = FALSE)
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
			if (private$response_type == "ordinal" && is.factor(ys)){
				levs = levels(ys)
				private$ordinal_levels = levs
				if (private$response_type_original == "ordinal" && is.null(private$original_ordinal_levels)){
					private$original_ordinal_levels = levs
				}
				ys = as.integer(ys)
			}
			if (should_run_asserts()) {
				private$assert_y(ys[has_y], private$response_type)
			}
			private$y = as.numeric(ys)
			private$y_original = as.numeric(ys)
			private$y_L = as.numeric(y_Ls)
			private$y_R = as.numeric(y_Rs)
			private$y_i_t_i = as.list(seq_len(private$t))
		}
		# overwrite_all_subject_assignments() is inherited from Design (one shared body,
		# v1.0.6-TODO-154).
	),
	private = list(
		# v1.0.6-TODO-298: fix n (and size w / y / y_L / y_R, as Design$initialize() does for a
		# given n) from the number of subjects added to a design built with n = NULL.
		set_n_from_subjects = function(n){
			n = as.integer(n)
			private$n = n
			private$fixed_sample = TRUE
			private$y =          rep(NA_real_, n)
			private$y_original = rep(NA_real_, n)
			private$w =          rep(NA_real_, n)
			private$y_L =        rep(NA_real_, n)
			private$y_R =        rep(NA_real_, n)
			invisible(NULL)
		},
		# v1.0.6-TODO-298: assigning needs n. With n = NULL and no subjects yet it is unknown, which
		# used to fail with "replacement has length zero" or "argument is of length zero".
		assert_n_known_for_assignment = function(){
			if (!isTRUE(private$fixed_sample) && private$t == 0L) {
				stop(class(self)[1L], ": n is not known yet; pass n to $new() or add the subjects first ",
					"(add_all_subjects_to_experiment()).", call. = FALSE)
			}
			invisible(NULL)
		},
		# v1.0.6-TODO-300 / -301: w_precomputed was stored as.numeric() unchecked, so a 1/2-coded
		# vector was kept and inference returned NA, and a cluster design accepted an assignment
		# that varies within clusters.
		validate_w_precomputed = function(w){
			n = self$get_n()
			if (is.factor(w) || !(is.numeric(w) || is.logical(w))) {
				stop("w_precomputed must be a numeric or logical 0/1 vector, not ", class(w)[1L], ".", call. = FALSE)
			}
			if (length(w) != n) {
				stop("w_precomputed must have length n = ", n, " (got ", length(w), ").", call. = FALSE)
			}
			if (anyNA(w)) stop("w_precomputed must not contain NA.", call. = FALSE)
			w = as.numeric(w)
			bad = setdiff(unique(w), c(0, 1))
			if (length(bad)) {
				stop("w_precomputed must contain only 0 (control) and 1 (treatment); found ",
					paste(utils::head(sort(bad), 5L), collapse = ", "), ".", call. = FALSE)
			}
			if (all(w == 1) || all(w == 0)) {
				stop("w_precomputed must assign at least one subject to each arm.", call. = FALSE)
			}
			cluster_col = private$cluster_col
			if (!is.null(cluster_col) && cluster_col %in% names(private$Xraw)) {
				cl = as.character(private$Xraw[[cluster_col]])[seq_len(n)]
				n_arms = tapply(w, cl, function(v) length(unique(v)))
				mixed = names(n_arms)[n_arms > 1L]
				if (length(mixed)) {
					stop("w_precomputed must give every subject in a cluster the same assignment; it varies within ",
						length(mixed), " cluster(s) of ", cluster_col, ", e.g. ",
						paste(utils::head(mixed, 5L), collapse = ", "), ".", call. = FALSE)
				}
			}
			w
		},
		draw_ws_raw = function(r = 100){
			stop("draw_ws_raw must be implemented by a concrete design subclass.")
		}
	)
)
