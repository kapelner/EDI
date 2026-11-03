#' Internal base for user-defined fixed-design extensions
#'
#' \code{DesignFixedCustom} is intentionally not exported. Subclasses implement
#' \code{draw_assignments(r = 1)} and return an \code{n x r} 0/1 assignment
#' matrix. EDI handles subject storage, responses, and validation through
#' \code{DesignFixed}.
#'
#' @keywords internal
DesignFixedCustom = define_design_class(
	classname = "DesignFixedCustom",
	lock_objects = FALSE,
	inherit = DesignFixed,
	components = character(),
	public = list(
		#' @description Draw assignments from the custom design.
		#' @param r Number of assignment vectors to draw.
		#' @return An \code{n x r} matrix of 0/1 assignments.
		draw_assignments = function(r = 1){
			stop("Custom fixed-design subclasses must implement public$draw_assignments(r).")
		}
	),
	private = list(
		draw_ws_raw = function(r = 100){
			if (should_run_asserts()) {
				assertCount(r, positive = TRUE)
			}
			w_mat = self$draw_assignments(r = as.integer(r))
			w_mat = as.matrix(w_mat)
			if (should_run_asserts()) {
				if (nrow(w_mat) != self$get_n() || ncol(w_mat) != as.integer(r)) {
					stop("draw_assignments(r) must return an n x r assignment matrix.", call. = FALSE)
				}
				if (any(!w_mat %in% c(0, 1))) {
					stop("draw_assignments(r) must return only 0/1 assignments.", call. = FALSE)
				}
			}
			warn_if_custom_draws_ignore_prob_T(self, private, w_mat)
			w_mat
		},
		warned_custom_prob_T_mismatch = FALSE
	)
)
#' Internal base for user-defined sequential-design extensions
#'
#' \code{DesignCustomSequential} is intentionally not exported. Subclasses
#' implement \code{assignment_rule()} and return a scalar 0/1 assignment for the
#' current subject. EDI handles subject storage, responses, and redraws through
#' \code{DesignSeqOneByOne}.
#'
#' @keywords internal
DesignCustomSequential = define_design_class(
	classname = "DesignCustomSequential",
	lock_objects = FALSE,
	inherit = DesignSeqOneByOne,
	components = character(),
	public = list(
		#' @description User-defined assignment rule.
		#' @return A binary treatment assignment.
		assignment_rule = function(){
			stop("Custom sequential-design subclasses must implement public$assignment_rule().")
		},
		#' @description Standard internal assignment entry point.
		#' @return A binary treatment assignment.
		assign_wt = function(){
			w_t = self$assignment_rule()
			if (should_run_asserts()) {
				assertChoice(w_t, c(0, 1))
			}
			as.numeric(w_t)
		}
	),
	private = list(
		# Replays assignment_rule() exactly as DesignSeqOneByOne does, then checks
		# the replayed treated share against prob_T (TODO-183).
		draw_ws_raw = function(r = 100){
			w_mat = super$draw_ws_raw(r)
			warn_if_custom_draws_ignore_prob_T(self, private, w_mat)
			w_mat
		},
		warned_custom_prob_T_mismatch = FALSE
	)
)

# Custom designs advertise supports_unequal_allocation = TRUE, but the draws come
# from user code (release_v1_0_5.md TODO-183). Warn once per design object when the
# treated share across the r draws is far from prob_T, i.e. the user's
# draw_assignments()/assignment_rule() ignores it. The tolerance is loose on
# purpose (max(0.1, 5 binomial SEs)) so clustered or otherwise correlated user
# designs do not trigger false alarms; it only catches gross mismatches. Skipped
# with asserts off, like the other draw_assignments() validations.
warn_if_custom_draws_ignore_prob_T = function(design, private_env, w_mat) {
	if (!should_run_asserts() || isTRUE(private_env$warned_custom_prob_T_mismatch) || length(w_mat) == 0L) return(invisible(NULL))
	prob_T = design$get_prob_T()
	share = mean(w_mat)
	tol = max(0.1, 5 * sqrt(prob_T * (1 - prob_T) / length(w_mat)))
	if (is.finite(share) && abs(share - prob_T) > tol) {
		private_env$warned_custom_prob_T_mismatch = TRUE
		warning(sprintf(
			"%s: the custom draws treat %.3f of subjects on average, but prob_T = %g. Make the draw function honour prob_T (get_prob_T()), or construct the design with the prob_T it actually uses.",
			class(design)[1L], share, prob_T
		), call. = FALSE)
	}
	invisible(NULL)
}
