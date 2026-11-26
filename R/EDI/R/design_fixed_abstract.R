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
			# v1.0.6-TODO-185 (owner ruling 2026-11-23): a fixed design built without n takes n from
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
		}
	),
	private = list(
		# v1.0.6-TODO-185: fix n (and size w / y / y_L / y_R, as Design$initialize() does for a
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
		# v1.0.6-TODO-185: assigning needs n. With n = NULL and no subjects yet it is unknown, which
		# used to fail with "replacement has length zero" or "argument is of length zero".
		assert_n_known_for_assignment = function(){
			if (!isTRUE(private$fixed_sample) && private$t == 0L) {
				stop(class(self)[1L], ": n is not known yet; pass n to $new() or add the subjects first ",
					"(add_all_subjects_to_experiment()).", call. = FALSE)
			}
			invisible(NULL)
		},
		# v1.0.6-TODO-187 / v1.0.6-TODO-188: w_precomputed was stored as.numeric() unchecked, so a 1/2-coded
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
