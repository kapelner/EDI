#' Sequential One-by-One Experimental Design
#'
#' Abstract R6 class encapsulating data and functionality for a sequential one-by-
#' one experimental design.
#'
#' @section Sample size and stopping:
#' Subjects are assigned one at a time, but this class does not implement interim
#' outcome monitoring or an outcome-dependent stopping rule. For the usual
#' fixed-sample analysis, specify the target sample size \code{n} before enrollment
#' and stop after exactly \code{n} subjects; the caller is responsible for ending
#' enrollment at that point. With \code{n = NULL}, the class leaves the final sample
#' size unspecified and does not determine when enrollment ends. Inference methods
#' that assume a fixed sample size require the final size to be chosen independently
#' of accumulating outcomes.
#'
#' @section Seed and reproducibility:
#' With a non-\code{NULL} \code{seed}, each assignment draws its randomness from a
#' seed derived from (\code{seed}, the subject's index \code{t}), with the session's
#' random-number state saved before the draw and restored after it. So the
#' allocation depends only on the seed and the subjects' covariates (and, for the
#' KK21 designs, the responses recorded so far); random numbers used between
#' assignments do not change it, a trial saved with \code{saveRDS()} continues
#' after \code{readRDS()} exactly as an uninterrupted run would, and neither
#' construction nor assignment moves the caller's own stream.
#' \code{draw_ws_according_to_design()} on a seeded design likewise runs under a
#' seed derived from (\code{seed}, \code{"redraw"}), so repeated calls return the
#' same draws, as on a fixed design. With \code{seed = NULL} (the default) every
#' assignment draws from the session's stream, as before.
#'
#' @keywords internal
#' @examples
#' # DesignSeqOneByOne is abstract and cannot be instantiated directly;
#' # construct a concrete subclass instead, e.g.:
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
DesignSeqOneByOne = R6::R6Class("DesignSeqOneByOne",
	lock_objects = FALSE,
	inherit = Design,
	public = list(
		#' @description Initialize a sequential one-by-one design.
		#' @param response_type The data type of response values.
		#' @param prob_T The probability of the treatment assignment. Efron,
		#'   Atkinson, Pocock-Simon and the KK designs have no \code{prob_T}
		#'   argument; their allocation is always 1:1.
		#' @param include_is_missing_as_a_new_feature If missing data is present, include a dummy
		#'   variable for it.
		#' @param n The prespecified target sample size for fixed-sample analysis.
		#'   If \code{NULL}, the final sample size is left to the caller; the class
		#'   does not provide a stopping rule.
		#' @param verbose Whether to print progress messages.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility, or \code{NULL} (the default)
		#'   to draw from the session's stream. With a seed, each assignment is drawn
		#'   under a seed derived from (\code{seed}, subject index) and the session's
		#'   stream is restored afterwards; see the "Seed and reproducibility" section.
		#' @param ... Extra arguments passed to the \code{Design} superclass.
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
			# v1.0.6-TODO-177: no set.seed() here any more. A seeded sequential design
			# seeds each assignment from (seed, t) inside add_one_subject_to_experiment_and_assign(),
			# so construction leaves the caller's stream alone.
			private$equal_block_sizes = FALSE
		},
		#' @description Add subject-specific measurements for the next subject entrant.
		#'
		#' @param x_new A data frame with one row representing the new subject's covariates.
		#' @param allow_new_cols Allow new features in the new subject's covariates.
		add_one_subject = function(x_new, allow_new_cols = TRUE){
			# v1.0.6-TODO-351: a fixed-n design takes exactly n subjects. Subject n + 1 used to be
			# accepted (t = n + 1, w grew, get_n() stayed n). Always enforced.
			if (isTRUE(private$fixed_sample) && private$t >= private$n) {
				stop(class(self)[1L], ": all n = ", private$n, " subjects have already been added; ",
					"subject ", private$t + 1L, " cannot be enrolled.", call. = FALSE)
			}
			if (should_run_asserts()) {
				assertClass(x_new, "data.frame")
				if (nrow(x_new) != 1){
					stop("You can only add one subject at a time.")
				}
			}
			# The opt-in preallocated path has already established the schema on
			# subject 1. Identical names/classes and compatible factor levels let
			# us fill the next row without repeating the generic schema machinery.
			if (isTRUE(private$Xraw_preallocated) && private$t < private$n &&
					identical(names(x_new), names(private$Xraw))) {
				same_classes = identical(lapply(x_new, class), private$Xraw_schema_classes)
				factor_levels_ok = identical(
					lapply(which(vapply(x_new, is.factor, logical(1))), function(j) levels(x_new[[j]])),
					private$Xraw_schema_factor_levels
				)
				if (same_classes && factor_levels_ok) {
					next_t = private$t + 1L
					set(private$Xraw, next_t, seq_len(ncol(private$Xraw)), as.list(x_new[1L, ]))
					private$t = next_t
					private$model_matrix_stale = TRUE
					if (private$t > (ncol(private$Xraw) + 2) && private$uses_covariates && private$assignment_rule_reads_model_matrix) {
						private$covariate_impute_if_necessary_and_then_create_model_matrix()
					}
					return(invisible(self))
				}
			}
			if (should_run_asserts()) {
				assertStrataClusterArgs(
					strata_cols = private$strata_cols,
					cluster_col = private$cluster_col,
					data = x_new,
					strata_cols_must_be_factor = !is.null(private$strata_cols),
					context = paste0(class(self)[1L], "$add_one_subject")
				)
			}
			x_new = as.data.table(x_new)
			j_with_NAs = is.na(unlist(x_new))
			# Pocock--Simon treats a missing stratum as a real, separate level.
			# Do not discard a declared stratum merely because the first entrant
			# has a missing value: doing so leaves the subclass without the column
			# it must register.  The historical first-row cleanup still applies to
			# other incomplete covariates.
			j_non_strata_with_NAs = j_with_NAs & !(names(x_new) %in% private$strata_cols)
			if (any(j_non_strata_with_NAs) & private$t == 0){
				# Drop missing attributes, not subject rows: data.table's single
				# bracket argument selects rows even when these are column indices.
				x_new = x_new[, which(!j_non_strata_with_NAs), with = FALSE]
				if (!allow_new_cols){
					warning("There is missing data in the first subject's non-stratum covariate value(s). Setting the flag allow_new_cols = FALSE will disallow additional subjects")
				}
			}
			xnew_data_types = get_column_types_cpp(x_new)
			if (should_run_asserts()) {
				if ("ordered" %in% xnew_data_types){
					stop("Ordered factor data type is not supported; please convert to either an unordered factor or numeric.")
				}
				if ("Date" %in% xnew_data_types){
					stop("Date data type is not supported; please convert to numeric.")
				}
			}
			if (private$t > 0){
				Xraw_data_types = get_column_types_cpp(private$Xraw)
				colnames_Xraw = names(private$Xraw)
				colnames_xnew = names(x_new)
				if (setequal(colnames_Xraw, colnames_xnew)){
					# Type checks describe attributes by name, even when the incoming
					# subject supplies the established columns in a different order.
					xnew_data_types = xnew_data_types[colnames_Xraw]
					# v1.0.6-TODO-351: a value whose type differs from the stored column's (a number
					# arriving as text, say) used to warn and then retype the stored column for every
					# earlier subject. It is now coerced back to the stored type, and refused, naming
					# the column, when that coercion loses the value. Always enforced.
					idx_data_types_that_changed = which(xnew_data_types != Xraw_data_types)
					for (e in idx_data_types_that_changed){
						col = colnames_Xraw[e]
						x_new[[col]] = private$coerce_new_value_to_stored_type(x_new[[col]], Xraw_data_types[e], xnew_data_types[e], col)
					}
				} else {
					if (allow_new_cols){ #make NA's in appropriate places
						new_Xraw_cols = setdiff(colnames_xnew, colnames_Xraw)
						if (length(new_Xraw_cols) > 0){
							new_Xraw_col_types = xnew_data_types[new_Xraw_cols]
							for (j in 1 : length(new_Xraw_cols)){
								private$Xraw[, (new_Xraw_cols[j]) := switch(new_Xraw_col_types[j],
									character = NA_character_,
									factor =    NA_character_, #I think this is correct
									numeric =   NA_real_,
									logical =   NA_real_, #just let it be zero or one
									integer =   NA_real_  #I don't want to take the risk on a decimal popping up somewhere
								)]
							}
						}
						new_xnew_cols = setdiff(colnames_Xraw, colnames_xnew)
						if (length(new_xnew_cols) > 0){
							new_xnew_cols_types = Xraw_data_types[new_xnew_cols]
							for (j in 1 : length(new_xnew_cols)){
								x_new[, (new_xnew_cols[j]) := switch(new_xnew_cols_types[j],
									character = NA_character_,
									factor =    NA_character_, #I think this is correct
									numeric =   NA_real_,
									logical =   NA_real_, #just let it be zero or one
									integer =   NA_real_  #I don't want to take the risk on a decimal popping up somewhere
								)]
							}
						}
					} else {
						stop(paste(
							"The new subject vector has columns:\n  ",
							paste(colnames_xnew, collapse = ", "),
							"\nwhich are not the same as the current dataset's columns:\n  ",
							paste(colnames_Xraw, collapse = ", "),
							"\nIf you want to allow new columns on-the-fly, run this function again with the option\n  'allow_new_cols = TRUE'"
						))
					}
				}
			}
			# Fixed-size sequential rules may opt into one allocation followed by
			# in-place row fills. A late factor level that was not present in the
			# first row falls back to the general rbindlist path, which unions levels.
			next_t = private$t + 1L
			if (private$t == 0L && isTRUE(private$preallocate_Xraw) && private$fixed_sample) {
				private$Xraw_schema_classes = lapply(x_new, class)
				private$Xraw_schema_factor_levels = lapply(which(vapply(x_new, is.factor, logical(1))), function(j) levels(x_new[[j]]))
				private$Xraw = x_new[rep(1L, private$n)]
				if (private$n > 1L) {
					for (j in seq_len(ncol(private$Xraw))) set(private$Xraw, 2L:private$n, j, NA)
				}
				private$Xraw_preallocated = TRUE
			} else if (isTRUE(private$Xraw_preallocated)) {
				factor_cols = names(private$Xraw)[vapply(private$Xraw, is.factor, logical(1))]
				factor_levels_ok = all(vapply(factor_cols, function(col) {
					value = x_new[[col]][1L]
					is.na(value) || as.character(value) %in% levels(private$Xraw[[col]])
				}, logical(1)))
				if (factor_levels_ok) {
					for (j in seq_len(ncol(private$Xraw))) {
						set(private$Xraw, next_t, j, x_new[[names(private$Xraw)[j]]][1L])
					}
				} else {
					private$Xraw = rbindlist(list(private$Xraw[seq_len(private$t)], x_new), use.names = TRUE)
					private$Xraw_preallocated = FALSE
				}
			} else {
				private$Xraw = rbindlist(list(private$Xraw, x_new), use.names = TRUE)
			}
			private$p_raw_t = ncol(private$Xraw)
			#iterate t
			private$t = next_t #t must be an integer for data.table's fast "set" function below to work
			private$model_matrix_stale = TRUE
			#we only bother with imputation and model matrices if we have enough data otherwise it's a huge mess
			#thus, designs cannot utilize imputations nor model matrices until this condition is met
			#luckily, those are the designs implemented herein so we have complete control (if you are extending this package, you'll have to deal with this issue here)
			if (private$t > (ncol(private$Xraw) + 2) & private$uses_covariates & private$assignment_rule_reads_model_matrix){ #we only need to impute if we need the X's to make the allocation decisions
				private$covariate_impute_if_necessary_and_then_create_model_matrix()
			}
		},
		#' @description Adds a subject and assigns treatment.
		#' @param x_new A data frame with one row representing the new subject's covariates.
		#' @return The treatment assignment as \{0,1\} (1 = treated, 0 = control).
		add_one_subject_to_experiment_and_assign = function(x_new){
			private$check_version_compat()
			# v1.0.6-TODO-316: if adding the row or assigning it fails, roll the design back so a
			# refused subject is not left enrolled with w = NA (t advanced, row stored).
			state_before = private$snapshot_subject_state(x_new)
			assigned = FALSE
			on.exit(if (!assigned) private$restore_subject_state(state_before), add = TRUE)
			self$add_one_subject(x_new)
			# v1.0.6-TODO-177: with a seed, subject t's draw comes from (seed, t) with the
			# session's RNG state saved and restored, so it does not depend on anything
			# else drawn in the session (or on a saveRDS()/readRDS() in between). Only this
			# entry point is seeded: the replays inside draw_ws_raw() call assign_wt()
			# directly and keep drawing from the one stream their caller set up.
			w_t = if (is.null(private$seed)) self$assign_wt() else
				private$with_derived_seed(private$t, self$assign_wt())
			if (private$fixed_sample){
				private$w[private$t] = w_t
			} else {
				if (length(private$w) < private$t) {
					private$w = c(private$w, w_t)
				} else {
					private$w[private$t] = w_t
				}
			}
			assigned = TRUE
			private$w[private$t]
		},
		#' @description Assigns treatment to the current subject.
		#' @return The treatment assignment (0 or 1).
		assign_wt = function(){
			stop("Must be implemented by subclass.")
		},
		#' @description Draw treatment assignment vectors according to the design (the
		#'   sequential rule replayed over the enrolled subjects). With a non-\code{NULL}
		#'   \code{seed} the draws run under a seed derived from (\code{seed}, \code{"redraw"})
		#'   with the session's random-number state saved and restored, so repeated calls
		#'   return the same draws and the caller's stream is untouched; with
		#'   \code{seed = NULL} they come from the session's stream.
		#'
		#' @param r Number of vectors to draw. Default is 1.
		#' @return A matrix with one row per enrolled subject and \code{r} columns of
		#'   \{0,1\} entries (1 = treated, 0 = control).
		draw_ws_according_to_design = function(r = 1L){
			if (is.null(private$seed)) return(super$draw_ws_according_to_design(r))
			private$with_derived_seed("redraw", super$draw_ws_according_to_design(r))
		},
		#' @description Prints the current subject's assignment.
		print_current_subject_assignment = function(){
			cat("Subject number", private$t, "is assigned to", ifelse(private$w[private$t] == 1, "TREATMENT", "CONTROL"), "via design", class(self)[1], "\n")
		}
	),
	private = list(
		equal_block_sizes = FALSE,
		# v1.0.6-TODO-351: coerce one new subject's value to the type its column was stored with,
		# or stop naming the column when the value would be lost (non-missing in, NA out).
		coerce_new_value_to_stored_type = function(value, stored_type, new_type, col){
			to_number = function(v) if (is.logical(v) || is.numeric(v)) as.numeric(v) else suppressWarnings(as.numeric(as.character(v)))
			coerced = switch(stored_type,
				numeric = to_number(value),
				integer = {
					v = to_number(value)
					ifelse(is.finite(v) & v == round(v), as.integer(round(v)), NA_integer_)
				},
				logical = if (is.character(value) || is.factor(value)) as.logical(as.character(value)) else {
					v = to_number(value)
					ifelse(v %in% c(0, 1), as.logical(v), NA)
				},
				character = as.character(value),
				factor = factor(as.character(value)),
				value
			)
			if (any(is.na(coerced) & !is.na(value))) {
				stop(class(self)[1L], ": covariate '", col, "' of subject ", private$t + 1L, " is ",
					new_type, " (", paste(format(value), collapse = ", "), ") but was entered as ", stored_type,
					" for the earlier subjects, and it cannot be converted. Enter it as ", stored_type, ".",
					call. = FALSE)
			}
			coerced
		},
		# v1.0.6-TODO-177: evaluate `expr` (a promise, forced after seeding) under
		# set.seed() of the seed derived from this design's seed and `key` (a subject
		# index, or "redraw"), with the session's .Random.seed -- or its absence --
		# saved before and restored after, even if `expr` errors.
		# v1.0.6-TODO-316: the private fields as they were before a subject was added. R values
		# are copy-on-modify, so this keeps references, not copies. The one in-place mutation on
		# the add path that a later rollback could see is a new column added to Xraw by reference
		# (allow_new_cols), so Xraw is deep-copied only when x_new's columns differ. In-place row
		# fills of a preallocated Xraw land past t and are overwritten by the next add.
		subject_state_field_names = NULL,
		snapshot_subject_state = function(x_new){
			nms = private$subject_state_field_names
			if (is.null(nms)) {
				nms = ls(private, all.names = TRUE, sorted = FALSE)
				nms = nms[!vapply(nms, function(nm) is.function(private[[nm]]), logical(1))]
				nms = setdiff(nms, "subject_state_field_names")
				private$subject_state_field_names = nms
			}
			vals = mget(nms, envir = private, inherits = FALSE)
			if (data.table::is.data.table(vals$Xraw) && !identical(names(x_new), names(vals$Xraw))) {
				vals$Xraw = data.table::copy(vals$Xraw)
			}
			vals
		},
		restore_subject_state = function(vals){
			for (nm in names(vals)) assign(nm, vals[[nm]], envir = private)
			invisible(NULL)
		},
		with_derived_seed = function(key, expr){
			had_seed = exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
			if (had_seed) old_seed = get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
			on.exit({
				if (had_seed) {
					assign(".Random.seed", old_seed, envir = .GlobalEnv)
				} else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
					rm(".Random.seed", envir = .GlobalEnv)
				}
			}, add = TRUE)
			set.seed(seq_design_draw_seed(private$seed, key))
			expr
		},
		draw_ws_raw = function(r = 100){
			# v1.0.6-TODO-42: the replay below rebuilds private$w subject by subject (the
			# assign_wt() rules read the running w), so put the realized allocation back
			# afterwards, even if a replay errors. Without this a redraw on a live design
			# (e.g. InferenceIncidCMH's SE path on an Urn design) left the last replayed
			# vector in place of the subjects' real assignments.
			w_realized = private$w
			on.exit(private$w <- w_realized, add = TRUE)
			# v1.0.6-TODO-183: advance private$t through the replay so an assign_wt() /
			# custom assignment_rule() that reads t (or subject t's row) sees the subject
			# being replayed, not the last enrolled one; restore it afterwards.
			t_enrolled = private$t
			on.exit(private$t <- t_enrolled, add = TRUE)
			w_mat = matrix(NA_real_, nrow = t_enrolled, ncol = r)
			for (j in seq_len(r)){
				if (private$fixed_sample) {
					private$w = rep(NA_real_, private$n)
				} else {
					private$w = rep(NA_real_, t_enrolled)
				}
				for (t in seq_len(t_enrolled)){
					private$t = t
					private$w[t] = self$assign_wt()
				}
				w_mat[, j] = private$w[seq_len(t_enrolled)]
			}
			w_mat
		}
	)
)

# v1.0.6-TODO-177: deterministic seed in [0, 2^31 - 1) for one seeded draw of a
# sequential design, from the design's seed and a key (the subject index t, or
# "redraw"): seed per draw index, the rule EDI already uses so results do not depend
# on the thread count. Same polynomial string hash as comprehensive_tests.R's
# coverage_truth_seed() (exact in doubles since h < 2^31); set.seed() then scrambles
# the integer, so neighboring keys give unrelated streams.
seq_design_draw_seed = function(seed, key){
	h = 0
	for (code in utf8ToInt(paste("EDI_seq_one_by_one", format(seed, scientific = FALSE, trim = TRUE), key, sep = "||"))) {
		h = (h * 31 + code) %% 2147483647
	}
	as.integer(h)
}
