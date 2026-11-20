#' Randomization test/CI on a user-supplied statistic
#'
#' Runs a randomization test (and, via
#' \code{compute_rand_confidence_interval()}, a randomization confidence interval) for an arbitrary
#' user-supplied statistic, without writing an \code{Inference} subclass.
#' The statistic function is called once per permutation as
#' \code{fn(y, w, dead)} -- plain numeric/integer vectors: the current
#' (possibly permuted) response, treatment assignment, and event indicator.
#' It must return one scalar (a value of any other length is an error). For maximum speed, supply
#' \code{custom_randomization_statistic_cpp} instead: C++ source defining a
#' function of \code{(NumericVector y, IntegerVector w)} or
#' \code{(NumericVector y, IntegerVector w, IntegerVector dead)} returning a
#' scalar \code{double}, using the same convention as
#' \code{DesignFixedOptimal}'s \code{custom_objective}. The source is compiled with
#' \code{Rcpp::cppFunction()}, which adds its own \code{// [[Rcpp::export]]} tag
#' in front of the first function in the source, so the source must contain exactly
#' one function, the statistic: no helper functions before it (not even a forward
#' declaration or an \code{inline} helper; the first one would be taken as the
#' statistic and fail the argument check) and no \code{// [[Rcpp::export]]} line of
#' your own (the function would be exported twice and the compile fails). Put helper
#' logic in a lambda inside the statistic.
#'
#' Only a randomization test and randomization confidence interval are
#' available -- there is no package point-estimator, Wald path, or bootstrap
#' machinery on this class, so no other action needs disabling.
#'
#' The confidence interval inverts the randomization test over the shift
#' \eqn{\delta} (see below for its scale by response type), whatever the
#' statistic's own units (a t statistic, or \code{-10 * mean difference}, give the
#' same interval). The search is centred on the observed difference in mean
#' response on the shift scale, not on the statistic's observed value. The
#' statistic must respond to the shift (be monotone in \eqn{\delta}); if the test
#' rejects every \eqn{\delta} tried the CI errors instead of returning a rejected
#' band.
#'
#' Draws on which the statistic returns \code{NA}, \code{NaN} or an infinite
#' value are dropped silently (whatever \code{na.rm} is) and the p-value is
#' computed over the finite draws; at least
#' \eqn{\max(10, \lfloor r/10 \rfloor)}{max(10, floor(r/10))} finite draws are
#' required, otherwise the p-value is \code{NA}. See
#' \code{InferenceRand$compute_rand_two_sided_pval()}.
#'
#' \strong{The scale of \code{delta} by response type.} A nonzero \code{delta}
#' tests the sharp null that treatment moves every subject's response by
#' \eqn{\delta} on the \code{transform_responses} scale. The shift is removed from
#' the observed treated units and re-imposed on each draw's treated units on that
#' same scale, and the statistic always sees responses on their own scale. Under
#' the default \code{transform_responses = "none"}:
#' \itemize{
#'   \item continuous: additive, \eqn{y_i(1) = y_i(0) + \delta};
#'     \code{compute_rand_confidence_interval()} is an interval for the additive effect.
#'   \item survival: \eqn{\delta} is a log time ratio, \eqn{y_i(1) = y_i(0) e^\delta}
#'     (censoring times are scaled alike, event indicators unchanged);
#'     \code{compute_rand_confidence_interval()} is an interval for \eqn{\delta}, so
#'     exponentiate its bounds for an interval for the time ratio \eqn{e^\delta}.
#'   \item count: \eqn{\delta} is a log rate ratio, the treated counts multiplied by
#'     \eqn{e^\delta} and rounded to integers.
#'   \item proportion: \eqn{\delta} is a shift on the logit scale (responses clamped by
#'     \code{zero_one_logit_clamp}).
#'   \item incidence: a nonzero \code{delta} is refused.
#' }
#' \code{transform_responses = "log"} or \code{"logit"} selects the multiplicative or
#' logit-scale shift explicitly (on continuous responses too, which then must be
#' positive, or in (0, 1), for the null to make sense). The randomization CI is
#' refused for incidence, count and proportion responses (its bounds would not be
#' on the scale of this class's raw-scale estimate); on those types use the
#' p-value, at \code{delta = 0} or at a chosen \code{delta}.
#'
#' @param des_obj A Design object whose subjects are assigned and responses
#'   recorded.
#' @param custom_randomization_statistic_function A function of
#'   \code{(y, w, dead)} returning one scalar. Exactly one of this or
#'   \code{custom_randomization_statistic_cpp} must be supplied.
#' @param custom_randomization_statistic_cpp Either a C++ source code
#'   string, a pre-compiled Rcpp function, or an
#'   \code{RcppXPtrUtils::cppXPtr()} external pointer. A source string or
#'   Rcpp function must return a scalar \code{double} and accept either
#'   \code{(NumericVector y, IntegerVector w)} or \code{(NumericVector y,
#'   IntegerVector w, IntegerVector dead)}. An external pointer follows the
#'   package-wide \code{user_compiled_fns.h} calling convention shared with
#'   \code{DesignFixedOptimal}'s \code{custom_objective} -- Eigen types:
#'   \code{double f(const Eigen::VectorXd& y, const Eigen::VectorXd& w)}, or
#'   the 3-argument form appending \code{const Eigen::VectorXd& dead} -- and,
#'   like a pre-compiled Rcpp function, is valid in the main process only
#'   (external pointers do not survive serialization to parallel workers;
#'   use a source string for parallel paths).
#' @param verbose Whether to print progress messages.
#' @export
InferenceRandCustom = define_inference_class(
	classname = "InferenceRandCustom",
	inherit = InferenceCustomRand,
	public = list(
		#' @description Initialize.
		#' @param des_obj See class description.
		#' @param custom_randomization_statistic_function See class description.
		#' @param custom_randomization_statistic_cpp See class description.
		#' @param verbose See class description.
		initialize = function(des_obj, custom_randomization_statistic_function = NULL, custom_randomization_statistic_cpp = NULL, verbose = FALSE){
			if (!is.null(custom_randomization_statistic_function) && !is.null(custom_randomization_statistic_cpp)) {
				stop("Supply custom_randomization_statistic_function or custom_randomization_statistic_cpp, not both.", call. = FALSE)
			}
			if (is.null(custom_randomization_statistic_function) && is.null(custom_randomization_statistic_cpp)) {
				stop("InferenceRandCustom requires custom_randomization_statistic_function or custom_randomization_statistic_cpp.", call. = FALSE)
			}
			if (should_run_asserts()) {
				assertFunction(custom_randomization_statistic_function, null.ok = TRUE)
				# evaluate_stat() calls it as f(y, w, dead): a function that cannot take three
				# positional arguments used to fail only at the first draw ("unused argument").
				if (!is.null(custom_randomization_statistic_function)) {
					fmls = names(formals(custom_randomization_statistic_function))
					if (!("..." %in% fmls) && length(fmls) < 3L) {
						stop("custom_randomization_statistic_function must accept three arguments (y, w, dead) or `...`; it has ", length(fmls), ".", call. = FALSE)
					}
				}
			}
			super$initialize(des_obj = des_obj, verbose = verbose)
			# Field names below are deliberately identical to the ones
			# Inference.duplicate() (inference_all_abstract.R) already
			# special-cases for locked-binding cloning
			# (custom_randomization_statistic_function) and to the removed
			# set_custom_randomization_statistic_cpp()'s field names
			# (compiled_cpp_stat_fn/compiled_cpp_stat_src) -- so
			# Inference.duplicate() needs no changes to support this class.
			private$custom_randomization_statistic_function = custom_randomization_statistic_function
			if (!is.null(custom_randomization_statistic_cpp)) {
				private$install_stat_cpp(custom_randomization_statistic_cpp)
			}
		},
		#' @description Calls the user-supplied statistic on the observed data.
		#' @param estimate_only Unused; present for the `fit()` contract.
		fit = function(estimate_only = FALSE){
			dat = self$get_analysis_data()
			est = private$evaluate_stat(dat$y, dat$w, dat$dead)
			# v1.0.6-TODO-111: a statistic that is NA/NaN/Inf on the observed data
			# used to give an NA estimate, p-value and CI with no warning (only the
			# nonestimable reason "custom_estimate_unavailable" was recorded).
			if (!is.finite(est)) {
				stat_arg = if (is.null(private$compiled_cpp_stat_fn)) "custom_randomization_statistic_function" else "custom_randomization_statistic_cpp"
				warning(
					"InferenceRandCustom: the custom statistic (", stat_arg, ") returned ",
					format(est), " on the observed data, so the estimate, randomization p-value and ",
					"randomization CI are NA. Make the statistic return a finite number.",
					call. = FALSE
				)
			}
			list(estimate = est)
		}
	),
	private = list(
		custom_randomization_statistic_function = NULL,
		# The statistic is in arbitrary units, so the randomization-CI search
		# must be centred on the observed difference in mean response on the
		# shift scale and scaled by its Welch SE, not on the statistic's own
		# value. On survival responses the shift is a log-time ratio (see
		# randomization_ci_shifts_raw_survival_times()), so the centre is the
		# difference in mean log time.
		get_randomization_ci_delta_scale_seed = function(){
			y = as.numeric(private$y)
			if (identical(private$des_obj_priv_int$response_type, "survival")) y = log(pmax(.Machine$double.eps, y))
			w = as.numeric(private$w)
			y1 = y[w == 1]
			y0 = y[w == 0]
			if (length(y1) < 1L || length(y0) < 1L) return(NULL)
			est = mean(y1) - mean(y0)
			v1 = if (length(y1) > 1L) stats::var(y1) / length(y1) else NA_real_
			v0 = if (length(y0) > 1L) stats::var(y0) / length(y0) else NA_real_
			se = sqrt(sum(c(v1, v0), na.rm = TRUE))
			list(est = est, se = se)
		},
		# v1.0.6-TODO-286: the survival randomization CI inverts this class's own
		# compute_rand_two_sided_pval(delta) (the statistic sees raw times; delta
		# multiplies the treated times by exp(delta)) instead of evaluating the
		# user's statistic on log times under an additive shift.
		randomization_ci_shifts_raw_survival_times = function() TRUE,
		compiled_cpp_stat_fn = NULL,
		compiled_cpp_stat_src = NULL,
		# Ported unchanged from the removed InferenceRand$set_custom_
		# randomization_statistic_cpp(): source-string compile (source kept
		# for per-worker recompilation), pre-compiled Rcpp function, or XPtr,
		# with the same arity check and the same shared XPtr shim
		# (normalize_user_cpp_fn(), eval_custom_rand_stat_[dead_]xptr_cpp())
		# used by DesignFixedOptimal's custom_objective.
		install_stat_cpp = function(fn){
			if (is.character(fn) && length(fn) == 1L) {
				compiled = cached_cpp_compile(fn)
				arity = length(formals(compiled))
				if (!arity %in% c(2L, 3L)) stop("custom_randomization_statistic_cpp source must define a function with 2 arguments (y, w) or 3 arguments (y, w, dead); got ", arity, ".")
				private[["compiled_cpp_stat_src"]] = fn
				private[["compiled_cpp_stat_fn"]] = compiled
			} else if (typeof(fn) == "externalptr") {
				recorded = attr(fn, "args")
				if (is.null(recorded)) {
					stop(paste0(
						"custom_randomization_statistic_cpp external pointers must carry ",
						"RcppXPtrUtils::cppXPtr()'s recorded signature (a bare externalptr's ",
						"argument count cannot be determined); build the pointer with ",
						"RcppXPtrUtils::cppXPtr()."
					))
				}
				arity = length(recorded)
				if (!arity %in% c(2L, 3L)) stop("custom_randomization_statistic_cpp must accept 2 arguments (y, w) or 3 arguments (y, w, dead); got ", arity, ".")
				normalized = normalize_user_cpp_fn(
					fn, "custom_randomization_statistic_cpp",
					if (arity == 3L) "rand_stat_dead" else "rand_stat"
				)
				xptr = normalized$xptr
				private[["compiled_cpp_stat_src"]] = NULL
				private[["compiled_cpp_stat_fn"]] = if (arity == 3L) {
					function(y, w, dead) eval_custom_rand_stat_dead_xptr_cpp(xptr, as.numeric(y), as.numeric(w), as.numeric(dead))
				} else {
					function(y, w) eval_custom_rand_stat_xptr_cpp(xptr, as.numeric(y), as.numeric(w))
				}
			} else {
				if (!is.function(fn)) stop("custom_randomization_statistic_cpp must be a C++ source string, a compiled Rcpp function, or an RcppXPtrUtils::cppXPtr() external pointer, not a ", class(fn)[1], ".")
				arity = length(formals(fn))
				if (!arity %in% c(2L, 3L)) stop("custom_randomization_statistic_cpp must accept 2 arguments (y, w) or 3 arguments (y, w, dead); got ", arity, ".")
				private[["compiled_cpp_stat_src"]] = NULL
				private[["compiled_cpp_stat_fn"]] = fn
			}
		},
		evaluate_stat = function(y, w, dead, cpp_fn_override = NULL){
			cpp_fn = if (!is.null(cpp_fn_override)) cpp_fn_override else private$compiled_cpp_stat_fn
			val = if (!is.null(cpp_fn)) {
				arity = length(formals(cpp_fn))
				if (arity >= 3L) cpp_fn(y, as.integer(w), as.integer(dead)) else cpp_fn(y, as.integer(w))
			} else {
				private$custom_randomization_statistic_function(y, w, dead)
			}
			# v1.0.6-TODO-83: a statistic returning several values used to be cut to its
			# first element with no error. Checked on every call, so the observed-data
			# call in fit() (made before any draw) is the one the user sees.
			if (length(val) != 1L) {
				stat_arg = if (is.null(cpp_fn)) "custom_randomization_statistic_function" else "custom_randomization_statistic_cpp"
				stop(
					"InferenceRandCustom: the custom statistic (", stat_arg, ") must return one number, ",
					"but it returned ", length(val), " values (class ", class(val)[1L], "). ",
					"Return a single summary, e.g. mean(y[w == 1]) - mean(y[w == 0]).",
					call. = FALSE
				)
			}
			as.numeric(val)
		},
		# Ported from the removed InferenceExtCustomRandomizationStatistic$
		# evaluate_lightweight_custom_randomization_statistic(), minus the
		# environment-proxy branch: every call here uses plain (y, w, dead)
		# args, so there is nothing left to fake. This is the only fast-path
		# method InferenceRandCustom's components (RandomizationTest,
		# RandomizationCI) ever consult -- see approximate_randomization_
		# distribution_beta_hat_T() (inference_all_abstract_rand.R), which
		# both the p-value test and (via per-delta re-evaluation during
		# bisection) the confidence interval search go through.
		compute_fast_randomization_distr = function(y, permutations, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			w_mat = permutations$w_mat
			if (is.null(w_mat)) return(NULL)
			dead = private$dead
			# cpp_fn_override: a worker recompiles its own copy from
			# compiled_cpp_stat_src rather than dereferencing an XPtr serialized
			# from the main process (same rationale as the ported code above).
			cpp_fn_override = if (!is.null(private$compiled_cpp_stat_src)) cached_cpp_compile(private$compiled_cpp_stat_src) else NULL
			# `y` arrives with delta already removed from the observed treated units
			# on the transform_responses scale (setup_randomization_template_and_
			# shifts()); each permuted assignment must re-impose delta on its own
			# treated units on that same scale. Ignoring delta made the null
			# distribution identical for every delta. Re-adding it additively
			# whatever the transform (as this did until v1.0.6-TODO-286) mixed a
			# log/logit removal with an additive re-add on survival, count and
			# proportion responses (and on "log"/"logit" continuous), so no sharp
			# null was tested. shift_randomization_responses() is the helper every
			# base-class path uses, so the re-add inverts the removal exactly.
			delta = as.numeric(delta)[1L]
			response_type = private$des_obj_priv_int$response_type
			vapply(seq_len(ncol(w_mat)), function(j) {
				wj = w_mat[, j]
				y_draw = if (isTRUE(delta != 0)) {
					private$shift_randomization_responses(
						y = y, w = wj, delta = delta, transform_responses = transform_responses,
						response_type = response_type, inverse = FALSE,
						zero_one_logit_clamp = zero_one_logit_clamp
					)
				} else y
				private$evaluate_stat(y_draw, wj, dead, cpp_fn_override)
			}, numeric(1L))
		}
		# Deliberately NOT implementing compute_fast_rand_bootstrap_distr,
		# compute_brt_null_statistics_with_se, or compute_rand_bootstrap_ci_
		# affine_coefs: those back the bootstrap-randomization-test family
		# (RandomizationBootstrap/RandomizationBootstrapCI), which this class
		# does not compose -- they would never be called. Also deliberately
		# not implementing compute_rand_bootstrap_ci_affine_coefs's closed-form
		# shortcut for compute_rand_confidence_interval(): an arbitrary user
		# statistic cannot be assumed affine in delta, so the bisection search
		# (inference_all_abstract_rand_ci.R) is the correct path here.
	),
	metadata = list(likelihood_tier = "none")
)
