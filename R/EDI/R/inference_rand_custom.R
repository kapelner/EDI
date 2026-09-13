#' Randomization test/CI on a user-supplied statistic
#'
#' Runs a randomization test (and, via \code{compute_rand_confidence_
#' interval()}, a randomization confidence interval) for an arbitrary
#' user-supplied statistic, without writing an \code{Inference} subclass.
#' The statistic function is called once per permutation as
#' \code{fn(y, w, dead)} -- plain numeric/integer vectors: the current
#' (possibly permuted) response, treatment assignment, and event indicator.
#' It must return one scalar. For maximum speed, supply
#' \code{custom_randomization_statistic_cpp} instead: C++ source defining a
#' function of \code{(NumericVector y, IntegerVector w)} or
#' \code{(NumericVector y, IntegerVector w, IntegerVector dead)} returning a
#' scalar \code{double}, using the same convention as
#' \code{DesignFixedOptimal}'s \code{custom_objective}.
#'
#' Only a randomization test and randomization confidence interval are
#' available -- there is no package point-estimator, Wald path, or bootstrap
#' machinery on this class, so no other action needs disabling.
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
			list(estimate = private$evaluate_stat(dat$y, dat$w, dat$dead))
		}
	),
	private = list(
		custom_randomization_statistic_function = NULL,
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
				compiled = Rcpp::cppFunction(fn)
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
			if (!is.null(cpp_fn)) {
				arity = length(formals(cpp_fn))
				return(as.numeric(if (arity >= 3L) cpp_fn(y, as.integer(w), as.integer(dead)) else cpp_fn(y, as.integer(w)))[1L])
			}
			as.numeric(private$custom_randomization_statistic_function(y, w, dead))[1L]
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
			cpp_fn_override = if (!is.null(private$compiled_cpp_stat_src)) local({
				.src = private$compiled_cpp_stat_src; .fn = NULL
				function(){ if (is.null(.fn)) .fn <<- Rcpp::cppFunction(.src); .fn }
			})() else NULL
			vapply(seq_len(ncol(w_mat)), function(j) private$evaluate_stat(y, w_mat[, j], dead, cpp_fn_override), numeric(1L))
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
