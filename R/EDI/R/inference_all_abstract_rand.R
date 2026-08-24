#' Randomization-based Inference
#'
#' Abstract class for randomization-based inference.
#'
#' @keywords internal
InferenceRand = R6::R6Class("InferenceRand",
	inherit = Inference,
	lock_objects = FALSE,
	public = list(
		#' @description Set a custom R randomization statistic.
		#'
		#' Replaces the default treatment-effect estimate used in
		#' \code{approximate_randomization_distribution_beta_hat_T()} and
		#' \code{compute_randomization_two_sided_pval()} with a user-supplied R
		#' function. The function must return one scalar statistic for the current
		#' randomized outcome/assignment state. Pass \code{NULL} to clear the custom
		#' statistic. This cannot be used at the same time as
		#' \code{set_custom_randomization_statistic_cpp()}.
		#'
		#' @param custom_randomization_statistic_function A function that returns one
		#'   scalar value, or \code{NULL} to restore the class default statistic.
		set_custom_randomization_statistic_function = function(custom_randomization_statistic_function){
			if (!is.null(custom_randomization_statistic_function) && !is.null(private[["compiled_cpp_stat_fn"]])) {
				stop("Cannot specify both custom_randomization_statistic_function and custom_randomization_statistic_cpp.")
			}
			if (should_run_asserts()) {
				assertFunction(custom_randomization_statistic_function, null.ok = TRUE)
			}
			private[["custom_randomization_statistic_function"]] = custom_randomization_statistic_function
			private$cached_values$t0s_rand = NULL
			private$cached_values$rand_distr_cache = list()
			private$cached_values$custom_stat_analysis = NULL
		},
		#' @description Set a custom compiled C++ randomization statistic.
		#'
		#' Replaces the default treatment-effect estimate used in
		#' \code{approximate_randomization_distribution_beta_hat_T()} and
		#' \code{compute_randomization_two_sided_pval()} with a scalar C++ statistic.
		#' A source string is recommended because each parallel worker can compile
		#' its own copy safely. A pre-compiled Rcpp function can be used in the main
		#' process, but external pointers may not survive serialization to workers.
		#' Pass \code{NULL} to clear the custom statistic. This cannot be used at
		#' the same time as \code{set_custom_randomization_statistic_function()}.
		#'
		#' @param fn Either a C++ source code string, a pre-compiled Rcpp function,
		#'   an \code{RcppXPtrUtils::cppXPtr()} external pointer, or
		#'   \code{NULL}. A source string or Rcpp function must return a scalar
		#'   \code{double} and accept either \code{(NumericVector y, IntegerVector w)}
		#'   or \code{(NumericVector y, IntegerVector w, IntegerVector dead)}. An
		#'   external pointer follows the package-wide \code{user_compiled_fns.h}
		#'   calling convention shared with \code{DesignFixedOptimal}'s
		#'   \code{custom_objective} -- Eigen types:
		#'   \code{double f(const Eigen::VectorXd& y, const Eigen::VectorXd& w)}, or
		#'   the 3-argument form appending \code{const Eigen::VectorXd& dead} --
		#'   and, like a pre-compiled Rcpp function, is valid in the main process
		#'   only (external pointers do not survive serialization to parallel
		#'   workers; use a source string for parallel paths).
		set_custom_randomization_statistic_cpp = function(fn){
			if (!is.null(fn) && !is.null(private[["custom_randomization_statistic_function"]])) {
				stop("Cannot specify both custom_randomization_statistic_function and custom_randomization_statistic_cpp.")
			}
			if (!is.null(fn)) {
				if (is.character(fn) && length(fn) == 1L) {
					compiled = Rcpp::cppFunction(fn)
					arity = length(formals(compiled))
					if (!arity %in% c(2L, 3L)) stop("custom_randomization_statistic_cpp source must define a function with 2 arguments (y, w) or 3 arguments (y, w, dead); got ", arity, ".")
					private[["compiled_cpp_stat_src"]] = fn
					private[["compiled_cpp_stat_fn"]] = compiled
				} else if (typeof(fn) == "externalptr") {
					# Uniform XPtr handling with DesignFixedOptimal's custom_objective:
					# shared signature check (normalize_user_cpp_fn), shared eval shims.
					# Normalized into the compiled_cpp_stat_fn slot as an R-callable
					# closure over the shim, so every downstream consultation site
					# (fast-path guards, the lightweight evaluator, arity checks)
					# behaves exactly as with a pre-compiled Rcpp function.
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
			} else {
				private[["compiled_cpp_stat_src"]] = NULL
				private[["compiled_cpp_stat_fn"]] = NULL
			}
			private$cached_values$t0s_rand = NULL
			private$cached_values$rand_distr_cache = list()
			private$cached_values$custom_stat_analysis = NULL
		},
		#' @description Computes the randomization distribution of the treatment effect estimate under the sharp null.
		#'
		#' @param r  					Number of randomization vectors. Default 501.
		#' @param delta  				The null difference. Default 0.
		#' @param transform_responses  Type of transformation. Default "none".
		#' @param show_progress  		Show progress bar. Default TRUE.
		#' @param permutations  		Pre-computed permutations. Default NULL.
		#' @param debug  				If \code{TRUE}, return a list with the distribution values and
		#'   per-iteration diagnostics including error messages, warning messages, counts of each,
		#'   and summary proportions for iterations with errors, warnings, and illegal (non-finite)
		#'   values. Runs serially. Default \code{FALSE}.
		#' @return 	When \code{debug = FALSE} (default), a numeric vector of length \code{r}. When
		#'   \code{debug = TRUE}, a list with: \code{values}, \code{errors} (list of character
		#'   vectors, one per iteration), \code{warnings} (list of character vectors, one per
		#'   iteration), \code{num_errors}, \code{num_warnings},
		#'   \code{prop_iterations_with_errors}, \code{prop_iterations_with_warnings}, and
		#'   \code{prop_illegal_values}.
		#' @param zero_one_logit_clamp The clamping amount for exact 0 and 1 values when logging
		approximate_randomization_distribution_beta_hat_T = function(r = 501, delta = 0, transform_responses = "none", show_progress = TRUE, permutations = NULL, debug = FALSE, zero_one_logit_clamp = .Machine$double.eps){
			private$active_resampling_operation = "rand"
			on.exit(private$active_resampling_operation <- NULL, add = TRUE)
			if (should_run_asserts()) {
				private$assert_design_supports_randomization_draw("Randomization inference")
				assertNumeric(delta); assertCount(r, positive = TRUE); assertFlag(debug)
			}
			mc_control_for_perms = private$randomization_mc_control
			defer_permutation_generation_for_mc =
				is.null(permutations) &&
				private$sequential_mc_control_enabled(mc_control_for_perms) &&
				as.integer(mc_control_for_perms$mc_batch_size) < as.integer(r)
			if (is.null(permutations) && !defer_permutation_generation_for_mc) permutations = private$generate_permutations(r)
			setup = private$setup_randomization_template_and_shifts(delta, transform_responses, zero_one_logit_clamp)
			has_custom_randomization_statistic =
				!is.null(private[["custom_randomization_statistic_function"]]) ||
				!is.null(private[["compiled_cpp_stat_fn"]])
			if (!isTRUE(debug) && !is.null(permutations) && !has_custom_randomization_statistic && private$has_private_method("compute_fast_randomization_distr")) {
				fast_distr = tryCatch(
					private$compute_fast_randomization_distr(setup$y_delta, permutations, delta, transform_responses, zero_one_logit_clamp),
					error = function(e) NULL
				)
				if (!is.null(fast_distr)) return(fast_distr)
				# If fast path threw, fall through to the standard reusable-worker path below.
			}
			if (!isTRUE(debug) && !is.null(permutations) &&
				isTRUE(private$use_reusable_bootstrap_worker()) &&
				!has_custom_randomization_statistic) {
				actual_rand_cores = private$effective_parallel_cores("rand_pval", self$num_cores)
				return(private$compute_randomization_distr_via_reused_worker_states(
					permutations = permutations,
					delta = delta,
					transform_responses = transform_responses,
					actual_rand_cores = actual_rand_cores,
					show_progress = show_progress,
					setup = setup,
					zero_one_logit_clamp = zero_one_logit_clamp
				))
			}
			custom_stat_analysis = private$analyze_custom_randomization_statistic()
			use_lightweight_custom_stat = isTRUE(custom_stat_analysis$can_use_lightweight_yw_only)
			use_perms = !is.null(permutations) && (!is.null(permutations$w_mat) || length(permutations) >= r)
			need_thread_objs = !(use_lightweight_custom_stat && use_perms)
			inf_template = if (need_thread_objs) self$duplicate() else NULL
			des_template = if (need_thread_objs) setup$get_template()$duplicate() else NULL
			# Warm up the design template cache if it uses covariates. The Design
			# owns both the capability check and cache mutation; inference does not
			# reach through its private environment (fix_design_hierarchy.md,
			# Source Invariant #11).
			if (!is.null(des_template)) {
				is_verbose = isTRUE(private$verbose)
				if (is_verbose) cat("Warming up design cache... ")
				tryCatch({
					did_warm = des_template$warm_all_subject_data_cache()
					if (is_verbose) cat(if (isTRUE(did_warm)) "done.\n" else "not needed.\n")
				}, error = function(e) {
					if (is_verbose) cat("failed.\n")
				})
			}
			if (!is.null(inf_template) && private$has_match_structure && private$object_has_private_method(inf_template, "compute_basic_match_data"))
				inf_template$.__enclos_env__$private$compute_basic_match_data()
			if (isTRUE(debug)) {
				debug_results = if (isTRUE(private$use_reusable_bootstrap_worker()) && is.null(private$custom_randomization_statistic_function) && is.null(private[["compiled_cpp_stat_fn"]])){
					# Fast path: use reused workers
					worker_state = private$create_bootstrap_worker_state()
					cleanup_worker = private$cleanup_bootstrap_worker_state
					if (is.function(cleanup_worker)) on.exit(cleanup_worker(worker_state), add = TRUE)
					lapply(seq_len(r), function(idx){
						iter_warns = character(0)
						iter_result = withCallingHandlers(
							tryCatch({
								# Generate permuted weights
								perm_w = if (use_perms) {
									if (!is.null(permutations$w_mat)) {
										j = ((idx - 1L) %% ncol(permutations$w_mat)) + 1L
										permutations$w_mat[, j]
									} else {
										perm_data = permutations[[idx]]
										if (is.list(perm_data) && !is.null(perm_data$w)) perm_data$w else perm_data
									}
								} else {
									sample(private$w)
								}
								# Load into worker
								private$load_resampling_draw_into_worker(
									operation = "rand",
									worker_state = worker_state,
									draw = perm_w,
									delta = delta,
									transform_responses = transform_responses,
									setup = setup,
									zero_one_logit_clamp = zero_one_logit_clamp
								)
								# Compute estimate
								list(val = private$compute_randomization_worker_estimate(worker_state))
							}, error = function(e) list(val = NA_real_, error = conditionMessage(e))),
							warning = function(w) { iter_warns <<- c(iter_warns, conditionMessage(w)); invokeRestart("muffleWarning") }
						)
						list(
							val = as.numeric(iter_result$val)[1L],
							errors = if (!is.null(iter_result$error)) iter_result$error else character(0),
							warnings = iter_warns
						)
					})
				} else {
					# Standard path: duplicate objects (slow)
					lapply(seq_len(r), function(idx) {
						iter_warns = character(0)
						iter_result = withCallingHandlers(
							tryCatch({
								worker_des = if (!is.null(des_template)) setup$get_template()$duplicate() else NULL
								worker_inf = if (!is.null(inf_template)) self$duplicate(verbose = FALSE, make_fork_cluster = FALSE) else NULL
								private$run_randomization_iteration(worker_des, worker_inf, if (use_perms) idx else NULL, permutations, delta, transform_responses, setup$y_delta, setup$base_template_y, setup$base_template_dead, custom_stat_analysis, setup$lightweight_custom_context, debug = TRUE, zero_one_logit_clamp = zero_one_logit_clamp)
							}, error = function(e) list(val = NA_real_, error = conditionMessage(e))),
							warning = function(w) { iter_warns <<- c(iter_warns, conditionMessage(w)); invokeRestart("muffleWarning") }
						)
						list(
							val = as.numeric(iter_result$val)[1L],
							errors = if (!is.null(iter_result$error)) iter_result$error else character(0),
							warnings = iter_warns
						)
					})
				}
				debug_results = debug_results[!vapply(debug_results, is.null, logical(1))]
				if (length(debug_results) == 0L) {
					stop("All randomization iterations failed or returned invalid results. Check for worker crashes or out-of-memory issues.")
				}
				values = sapply(debug_results, `[[`, "val")
				errors_list = lapply(debug_results, `[[`, "errors")
				warnings_list = lapply(debug_results, `[[`, "warnings")
				num_errors_vec = lengths(errors_list)
				num_warnings_vec = lengths(warnings_list)
				return(list(
					values = values,
					errors = errors_list,
					warnings = warnings_list,
					num_errors = num_errors_vec,
					num_warnings = num_warnings_vec,
					prop_iterations_with_errors = mean(num_errors_vec > 0),
					prop_iterations_with_warnings = mean(num_warnings_vec > 0),
					prop_illegal_values = mean(!is.finite(values))
				))
			}
			actual_rand_cores = private$effective_parallel_cores("rand_pval", self$num_cores)
			if (has_custom_randomization_statistic) {
				actual_rand_cores = 1L
			}
			if (actual_rand_cores > 1L && need_thread_objs) {
				do_warmup_iter = function() {
					w_des = if (!is.null(des_template)) des_template$duplicate() else NULL
					w_inf = if (!is.null(inf_template)) inf_template$duplicate(make_fork_cluster = FALSE) else NULL
					private$run_randomization_iteration(w_des, w_inf, if(use_perms) 1L else NULL, permutations, delta, transform_responses, setup$y_delta, setup$base_template_y, setup$base_template_dead, custom_stat_analysis, setup$lightweight_custom_context, zero_one_logit_clamp = zero_one_logit_clamp)
				}
				# Run warmup TWICE and use the second timing. The first call often pays
				# cold-start penalties (C++ JIT, OS page-cache misses, R bytecode compilation)
				# that inflate the estimate 5–15× vs steady-state cost, causing the guard to
				# wrongly choose parallel for small r values like r = 19.
				system.time(do_warmup_iter())  # First call: discarded (cold-start overhead)
				t_rand_warmup = system.time(do_warmup_iter())[[3]]  # Second call: representative cost
				# Existing cluster: ~10ms round-trip overhead. No cluster yet: ~300ms lazy creation.
				fork_overhead_estimate = if (!is.null(get_global_fork_cluster())) 0.01 else 0.3
				if (t_rand_warmup * r < fork_overhead_estimate * actual_rand_cores * 2.0) {
					actual_rand_cores = 1L
				}
			} else if (actual_rand_cores > 1L && !need_thread_objs) {
				# Use warmup timing for the lightweight path, same guard as the thread-obj path above.
				do_warmup_iter_lw = function() {
					private$run_randomization_iteration(
						NULL, NULL,
						if (use_perms) 1L else NULL,
						permutations, delta, transform_responses,
						setup$y_delta, setup$base_template_y, setup$base_template_dead,
						custom_stat_analysis, setup$lightweight_custom_context,
						zero_one_logit_clamp = zero_one_logit_clamp
					)
				}
				system.time(do_warmup_iter_lw())
				t_lw_warmup = system.time(do_warmup_iter_lw())[[3]]
				fork_overhead_estimate = if (!is.null(get_global_fork_cluster())) 0.01 else 0.3
				if (t_lw_warmup * r < fork_overhead_estimate * actual_rand_cores * 2.0) {
					actual_rand_cores = 1L
				}
			}
			beta_hat_T_diff_ws = unlist(private$par_lapply(1:r, function(idx) {
				suppressWarnings({
					worker_des = if (!is.null(des_template)) des_template$duplicate() else NULL
					worker_inf = if (!is.null(inf_template)) inf_template$duplicate(make_fork_cluster = FALSE) else NULL
					private$run_randomization_iteration(worker_des, worker_inf, if(use_perms) idx else NULL, permutations, delta, transform_responses, setup$y_delta, setup$base_template_y, setup$base_template_dead, custom_stat_analysis, setup$lightweight_custom_context, zero_one_logit_clamp = zero_one_logit_clamp)
				})
			}, n_cores = actual_rand_cores, show_progress = show_progress,
			export_list = list(
				des_template = des_template,
				inf_template = inf_template,
				permutations = permutations,
				delta = delta,
				setup = setup,
				custom_stat_analysis = custom_stat_analysis,
				use_perms = use_perms,
				zero_one_logit_clamp = zero_one_logit_clamp
			)))
			if (!is.numeric(beta_hat_T_diff_ws)) beta_hat_T_diff_ws = as.numeric(beta_hat_T_diff_ws)
			beta_hat_T_diff_ws
		},
		#' @description Whether \code{compute_rand_two_sided_pval()} is actually
		#'   usable on this instance right now -- \code{FALSE} exactly when it
		#'   would \code{stop()}: an \code{incidence}-response instance with no
		#'   custom randomization statistic and a design not eligible for
		#'   design-randomization-based incidence inference (see
		#'   \code{private$should_use_design_randomization_for_incidence()}).
		#'   \code{TRUE} for every other case, including every non-incidence
		#'   response type. Public, self-contained (only reads already-set
		#'   instance state, no side effects), so \code{InferenceSuite} can
		#'   check this before attempting the sentinel instead of relying on
		#'   the \code{stop()} being silently swallowed into a \code{pval = NA}
		#'   "ok" row -- the single source of truth for both this check and
		#'   \code{compute_rand_two_sided_pval()}'s own guard, so the two can
		#'   never drift apart (\code{fix_inference_hierarchy.md}'s
		#'   method-level-`stop()` TODO, 2026-08-21).
		#' @return A single logical.
		supports_rand_pval_for_incidence = function(){
			# Zhang-eligible incidence designs (matched-pair or Bernoulli, no
			# custom randomization statistic -- `should_use_zhang_incidence_
			# randomization()`) always support a "rand" p-value via the Zhang
			# exact-combined-test dispatch inside `compute_rand_two_sided_
			# pval()` below, even though the plain permutation path that
			# follows genuinely can't handle incidence responses. Fixed
			# 2026-08-23 (per user request) alongside that dispatch itself --
			# `compute_rand_confidence_interval()` already had this same
			# Zhang escape hatch, but `compute_rand_two_sided_pval()` never
			# did, so a "rand" CI could come back for a row whose "rand"
			# p-value always came back `NA` even though it was actually
			# computable.
			private$should_use_zhang_incidence_randomization() ||
				!(private$des_obj_priv_int$response_type == "incidence" &&
					is.null(private$custom_randomization_statistic_function) &&
					!private$should_use_design_randomization_for_incidence())
		},
		#' @description Computes a randomization-based p-value.
		#' @param r  	Number of randomization vectors.
		#' @param delta  				Null difference.
		#' @param transform_responses  Transformation.
		#' @param na.rm 				Remove NAs.
		#' @param show_progress  	Show progress.
		#' @param permutations  	Pre-computed permutations.
		#' @param zero_one_logit_clamp The clamping amount for exact 0 and 1 values when logging
		#' @return 	Randomization p-value.
		compute_rand_two_sided_pval = function(r = 501, delta = 0, transform_responses = "none", na.rm = TRUE, show_progress = TRUE, permutations = NULL, zero_one_logit_clamp = .Machine$double.eps){
			if (should_run_asserts()) {
				private$assert_design_supports_randomization_draw("Randomization inference")
				assertLogical(na.rm)
				if (!self$supports_rand_pval_for_incidence()) {
					stop("Randomization tests are not supported for incidence. Use Zhang method.")
				}
			}
			# Zhang-dispatch branch (added 2026-08-23, per user request) --
			# mirrors `compute_rand_confidence_interval()`'s own identical
			# branch exactly: a matched-pair or Bernoulli incidence design
			# with no custom randomization statistic reports its "rand"
			# p-value via the Zhang exact combined test
			# (`compute_exact_two_sided_pval_rand()`, already used by this
			# same mixin's CI-side counterpart and by `InferenceIncidExactZhang`
			# itself) rather than the plain permutation machinery below, which
			# was never built to handle incidence responses at all. Closes
			# the asymmetry where a "rand" CI could come back for a row whose
			# "rand" p-value always came back `NA` even though it was
			# actually computable the same way the CI was.
			if (private$should_use_zhang_incidence_randomization()) {
				exact_args = private$normalize_exact_inference_args("Zhang", args_for_type = NULL, pval_epsilon = NULL)
				return(private$compute_exact_two_sided_pval_rand("Zhang", delta, exact_args))
			}
			mc_control_for_perms = private$randomization_mc_control
			defer_permutation_generation_for_mc =
				is.null(permutations) &&
				private$sequential_mc_control_enabled(mc_control_for_perms) &&
				as.integer(mc_control_for_perms$mc_batch_size) < as.integer(r)
			if (is.null(permutations) && !defer_permutation_generation_for_mc) permutations = private$generate_permutations(r)
			if (identical(transform_responses, "none")) {
				transform_responses = switch(
					private$des_obj_priv_int$response_type,
					continuous = "none",
					proportion = "logit",
					count = "log",
					survival = "log",
					"none"
				)
			}
			cache_key = private$build_randomization_distribution_cache_key(r, delta, transform_responses, permutations)
			if (transform_responses == "none" && is.null(private[["custom_randomization_statistic_function"]]) && !is.null(private$cached_values$t0s_rand) && length(private$cached_values$t0s_rand) >= r) {
				t0s = private$cached_values$t0s_rand[seq_len(r)] + delta
				t = private$compute_treatment_estimate_during_randomization_inference()
				if (is.function(self$is_nonestimable) && isTRUE(self$is_nonestimable("estimate"))) return(NA_real_)
				if (length(t) != 1 || !is.finite(t)) {
					if (isTRUE(private$harden)) private$cache_nonestimable_estimate("randomization_observed_statistic_unavailable")
					return(NA_real_)
				}
				na_t0s = !is.finite(t0s)
				nsim_adj = sum(!na_t0s)
				if (nsim_adj == 0L) {
					if (isTRUE(private$harden)) private$cache_nonestimable_estimate("randomization_too_few_finite_estimates")
					return(NA_real_)
				}
				return(min(1, max(2 / nsim_adj, 2 * min(sum(t0s >= t, na.rm = TRUE) / nsim_adj, sum(t0s <= t, na.rm = TRUE) / nsim_adj))))
			}
			private$ensure_resampling_distribution_cache("rand")
			t = if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) {
				custom_stat_analysis = private$analyze_custom_randomization_statistic()
				if (isTRUE(custom_stat_analysis$can_use_lightweight_yw_only)) {
					private$evaluate_lightweight_custom_randomization_statistic(
						private$des_obj_priv_int,
						private$y,
						private$w,
						private$dead
					)
				} else {
					private$custom_randomization_statistic_function()
				}
			} else {
				private$compute_treatment_estimate_during_randomization_inference()
			}
			if (is.function(self$is_nonestimable) && isTRUE(self$is_nonestimable("estimate"))) return(NA_real_)
			if (length(t) != 1 || !is.finite(t)) {
				if (isTRUE(private$harden)) private$cache_nonestimable_estimate("randomization_observed_statistic_unavailable")
				return(NA_real_)
			}
			if (!is.null(private[["custom_randomization_statistic_function"]]) ||
			    !is.null(private[["compiled_cpp_stat_fn"]])) {
				if (!exists("custom_stat_analysis", inherits = FALSE)) {
					custom_stat_analysis = private$analyze_custom_randomization_statistic()
				}
				if (isTRUE(custom_stat_analysis$can_use_lightweight_yw_only)) {
					setup = private$setup_randomization_template_and_shifts(
						delta,
						transform_responses,
						zero_one_logit_clamp
					)
					deadline = suppressWarnings(as.numeric(getOption("EDI.ci_timeout_deadline", default = NA_real_))[1L])
					check_deadline = function(label = "Randomization custom statistic") {
						guard_sec = suppressWarnings(as.numeric(getOption("EDI.ci_timeout_guard_sec", default = 0.5))[1L])
						if (!is.finite(guard_sec) || guard_sec < 0) guard_sec = 0
						if (is.finite(deadline) && proc.time()[["elapsed"]] >= deadline - guard_sec) {
							stop(paste0(label, " reached elapsed time limit"), call. = FALSE)
						}
						invisible(NULL)
					}
					t0s = vapply(seq_len(as.integer(r)), function(idx) {
						if (idx == 1L || idx %% 25L == 0L) check_deadline()
						private$run_randomization_iteration(
							NULL,
							NULL,
							idx,
							permutations,
							delta,
							transform_responses,
							setup$y_delta,
							setup$base_template_y,
							setup$base_template_dead,
							custom_stat_analysis,
							setup$lightweight_custom_context,
							zero_one_logit_clamp = zero_one_logit_clamp
						)
					}, numeric(1))
					check_deadline()
					return(private$compute_two_sided_randomization_pval_from_t0s(t0s, t))
				}
			}
			mc_pval = private$compute_two_sided_pval_with_sequential_mc(
				t = t,
				r = r,
				delta = delta,
				transform_responses = transform_responses,
				show_progress = show_progress,
				permutations = permutations,
				cache_key = cache_key,
				zero_one_logit_clamp = zero_one_logit_clamp
			)
			if (!is.null(mc_pval)) return(mc_pval)
			t0s = private$get_randomization_distribution_prefix(
				r = r,
				delta = delta,
				transform_responses = transform_responses,
				show_progress = show_progress,
				permutations = permutations,
				cache_key = cache_key,
				zero_one_logit_clamp = zero_one_logit_clamp
			)
			private$compute_two_sided_randomization_pval_from_t0s(t0s, t)
		}
		),
	private = c(InferenceExtCustomRandomizationStatistic$private, InferenceExtSequentialMCPval$private, list(
		randomization_mc_control = NULL,
		is_bernoulli_design = function(){
			private$des_obj$is_a_bernoulli_capable()
		},
		should_use_zhang_incidence_randomization = function(){
			private$des_obj_priv_int$response_type == "incidence" &&
				is.null(private$custom_randomization_statistic_function) &&
				is.null(private[["compiled_cpp_stat_fn"]]) &&
				(private$is_bernoulli_design() || isTRUE(private$has_match_structure))
		},
		should_use_design_randomization_for_incidence = function(){
			isTRUE(private$des_obj$randomization_family() == "rerandomization")
		},
		normalize_delta_for_cache = function(delta, resolution = NULL){
			if (!is.finite(delta)) return("NA")
			if (!is.null(resolution) && is.finite(resolution) && resolution > 0) {
				delta = round(as.numeric(delta) / resolution) * resolution
			}
			format(as.numeric(delta), scientific = TRUE, digits = 17)
		},
		compute_randomization_distr_via_reused_worker_states = function(permutations, delta, transform_responses, actual_rand_cores, show_progress, setup, zero_one_logit_clamp) {
			nsim = if (!is.null(permutations$w_mat)) ncol(permutations$w_mat) else length(permutations)
			if (!isTRUE(nsim > 0L)) return(numeric(0))
			deadline = suppressWarnings(as.numeric(getOption("EDI.ci_timeout_deadline", default = NA_real_))[1L])
			check_deadline = function(label = "Randomization reusable-worker draw") {
				guard_sec = suppressWarnings(as.numeric(getOption("EDI.ci_timeout_guard_sec", default = 0.5))[1L])
				if (!is.finite(guard_sec) || guard_sec < 0) guard_sec = 0
				if (is.finite(deadline) && proc.time()[["elapsed"]] >= deadline - guard_sec) {
					stop(paste0(label, " reached elapsed time limit"), call. = FALSE)
				}
				invisible(NULL)
			}
			get_perm_w = if (!is.null(permutations$w_mat)) {
				w_mat_local = permutations$w_mat
				function(i) w_mat_local[, i]
			} else {
				function(i) {
					p = permutations[[i]]
					if (is.list(p) && !is.null(p$w)) p$w else p
				}
			}
			chunk_n = max(1L, min(as.integer(actual_rand_cores), nsim))
			chunk_id = ceiling(seq_len(nsim) / ceiling(nsim / chunk_n))
			chunks = split(seq_len(nsim), chunk_id)
			contract = private$get_resampling_draw_contract("rand")
			# Serial dispatch (chunk_n == 1L, the common case: num_cores = 1 is
			# InferenceSuite's default) is where `create_bootstrap_worker_state()`'s
			# `self$duplicate()` + design `duplicate()` becomes the dominant cost when
			# this whole function is re-invoked many times -- sequential-MC batches
			# (fixed delta) and CI-search bisection steps (varying delta) alike. The
			# key is delta-INDEPENDENT (transform_responses only, 2026-08-24 --
			# widened from also requiring an exact delta match): `load_randomization_
			# perm_into_worker()` unconditionally overwrites every replicate's y/w/
			# fit_warm_start/caches from `worker_state$base_fit_warm_start` (itself
			# always the ORIGINAL pre-loop snapshot, since `worker_state` is a plain
			# list -- copy-on-write, not a shared mutable environment -- so per-
			# replicate warm-start progression inside one call's own loop never
			# writes back into this cache), so reusing the container across
			# different delta values changes nothing about what any individual
			# replicate computes; only the (expensive) duplicated design/inference
			# containers are reused. Session lifetime (when to clear this so a
			# stale worker never leaks into an unrelated later computation) is
			# owned by whichever top-level entry point is active --
			# `compute_two_sided_pval_with_sequential_mc()` for a standalone p-value
			# call, `compute_rand_confidence_interval()` for a CI search (covering
			# every bisection step across both bounds) -- via a reentrancy depth
			# counter (`cached_values$rand_worker_reuse_depth`), since the CI-search
			# path calls the p-value path internally and must not have the inner
			# call's own exit handler clear the cache the outer search still needs.
			# The parallel path (chunk_n > 1L, each chunk needs its own independent
			# worker anyway) is untouched.
			reuse_key = if (chunk_n == 1L) transform_responses else NULL
			get_worker_state = function() {
				cached = private$cached_values$reusable_rand_worker
				if (!is.null(reuse_key) && !is.null(cached) && identical(cached$key, reuse_key)) {
					return(cached$state)
				}
				state = private$create_bootstrap_worker_state()
				if (!is.null(reuse_key)) {
					private$cached_values$reusable_rand_worker = list(key = reuse_key, state = state)
				}
				state
			}
			run_chunk = function(idxs) {
				worker_state = get_worker_state()
				load_draw = private[[contract$loader]]
				estimate_draw = private[[contract$estimator]]
				out = numeric(length(idxs))
				for (k in seq_along(idxs)) {
					check_deadline()
					perm_w = get_perm_w(idxs[k])
					out[k] = tryCatch({
						load_draw(
							worker_state,
							perm_w,
							delta = delta,
							transform_responses = transform_responses,
							setup = setup,
							zero_one_logit_clamp = zero_one_logit_clamp
						)
						as.numeric(estimate_draw(worker_state))[1L]
					}, error = function(e) NA_real_)
					# Sequential null anchoring: after each successful permutation, update
					# base_fit_warm_start to the converged parameters so the next permutation
					# starts from the current null-distribution point rather than the MLE.
					# Iterative models (logistic, Poisson, NegBin, ordinal, survival, etc.) call
					# set_fit_warm_start() inside their fitting function, which writes the converged
					# params to inf_priv$fit_warm_start.  We copy that here.
					# Cold objects (fit_warm_start_enabled = FALSE) have set_fit_warm_start() as a
					# no-op, so inf_priv$fit_warm_start stays NULL and no update occurs.
					if (is.finite(out[k])) {
						inf_priv_seq = if (!is.null(worker_state$worker_inf)) {
							worker_state$worker_inf$.__enclos_env__$private
						} else if (!is.null(worker_state$worker_priv)) {
							worker_state$worker_priv
						} else if (!is.null(worker_state$worker)) {
							worker_state$worker$.__enclos_env__$private
						} else NULL
						if (!is.null(inf_priv_seq)) {
							new_ws = inf_priv_seq$fit_warm_start
							if (!is.null(new_ws) && length(new_ws) > 0L && all(is.finite(new_ws))) {
								worker_state$base_fit_warm_start        = new_ws
								worker_state$base_fit_warm_start_type   = inf_priv_seq$fit_warm_start_type
								# Do NOT carry fit_warm_start_fisher: the Fisher information is
								# X_full'WX_full where X_full = [1 | w | X_cov].  The treatment
								# column w changes every permutation, invalidating all cross-terms
								# involving w.  Force a fresh recompute from the new design matrix.
								worker_state$base_fit_warm_start_fisher = NULL
							}
						}
					}
				}
				check_deadline()
				out
			}
			if (actual_rand_cores <= 1L) return(as.numeric(run_chunk(seq_len(nsim))))
			as.numeric(unlist(private$par_lapply(
				chunks,
				run_chunk,
				n_cores = actual_rand_cores,
				budget = 1L,
				show_progress = show_progress
			), use.names = FALSE))
		},
		build_fast_randomization_worker_cache = function(prev_cache = NULL, preserve_cache_keys = character()){
			cache = list()
			if (is.null(prev_cache)) {
				cache$rand_distr_cache = list()
				return(cache)
			}
			always_keep = c("m_cache", "t0s_rand", "custom_stat_analysis")
			for (nm in unique(c(always_keep, preserve_cache_keys))) {
				if (!is.null(prev_cache[[nm]])) cache[[nm]] = prev_cache[[nm]]
			}
			cache$rand_distr_cache = list()
			cache
		},
		compute_fast_randomization_distr_via_reused_worker = function(y, permutations, delta, transform_responses, preserve_cache_keys = character(), zero_one_logit_clamp = .Machine$double.eps){
			if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)
			if (is.null(permutations)) return(NULL)
			nsim = if (!is.null(permutations$w_mat)) ncol(permutations$w_mat) else length(permutations)
			if (!isTRUE(nsim > 0L)) return(numeric(0))
			get_perm_data = if (!is.null(permutations$w_mat)) {
				w_mat = permutations$w_mat
				m_mat = permutations$m_mat
				function(i) {
					list(
						w = w_mat[, i],
						m_vec = if (!is.null(m_mat)) m_mat[, i] else NULL
					)
				}
			} else {
				function(i) permutations[[i]]
			}
			actual_rand_cores = min(private$effective_parallel_cores("rand_pval", self$num_cores), nsim)
			chunk_n = max(1L, min(as.integer(actual_rand_cores), nsim))
			chunk_id = ceiling(seq_len(nsim) / ceiling(nsim / chunk_n))
			chunks = split(seq_len(nsim), chunk_id)
			run_chunk = function(idxs) {
				worker = self$duplicate(verbose = FALSE, make_fork_cluster = FALSE)
				worker$num_cores = 1L
				w_priv = worker$.__enclos_env__$private
				worker_des = if (!is.null(w_priv$des_obj)) w_priv$des_obj$duplicate(verbose = FALSE) else NULL
				if (!is.null(worker_des)) private$sync_randomization_worker_state(worker_des, worker)
				worker_des_priv = if (!is.null(worker_des)) worker_des$.__enclos_env__$private else NULL
				base_m = w_priv$m
				base_cache = w_priv$cached_values
				w_priv$y = as.numeric(y)
				w_priv$y_temp = w_priv$y
				if (!is.null(worker_des_priv)) {
					worker_des_priv$y = w_priv$y
					if (!is.null(base_m)) worker_des_priv$m = base_m
					private$sync_randomization_worker_state(worker_des, worker)
				}
				out = numeric(length(idxs))
				for (k in seq_along(idxs)) {
					perm_data = get_perm_data(idxs[k])
					if (!is.null(worker_des_priv)) {
						worker_des_priv$w = as.integer(perm_data$w)
						worker_des_priv$m = if (!is.null(perm_data$m_vec)) perm_data$m_vec else base_m
						y_sim = w_priv$y_temp
						if (delta != 0) {
							resp_type = worker_des_priv$response_type
							if (transform_responses == "logit") {
								y_sim[perm_data$w == 1] = inv_logit(logit(y_sim[perm_data$w == 1], zero_one_logit_clamp) + delta, zero_one_logit_clamp)
							} else if (transform_responses == "log" && resp_type == "survival") {
								y_sim[perm_data$w == 1] = y_sim[perm_data$w == 1] * exp(delta)
							} else if (transform_responses == "log" && resp_type == "count") {
								y_sim[perm_data$w == 1] = as.integer(round(y_sim[perm_data$w == 1] * exp(delta)))
							} else if (transform_responses == "log" && resp_type != "count") {
								y_sim[perm_data$w == 1] = y_sim[perm_data$w == 1] * exp(delta)
							} else {
								y_sim[perm_data$w == 1] = y_sim[perm_data$w == 1] + delta
							}
						}
						worker_des_priv$y = y_sim
						private$sync_randomization_worker_state(worker_des, worker)
					} else {
						w_priv$w = as.integer(perm_data$w)
						w_priv$m = if (!is.null(perm_data$m_vec)) perm_data$m_vec else base_m
						y_sim = w_priv$y_temp
						if (delta != 0) {
							resp_type = w_priv$des_obj_priv_int$response_type
							if (transform_responses == "logit") {
								y_sim[perm_data$w == 1] = inv_logit(logit(y_sim[perm_data$w == 1], zero_one_logit_clamp) + delta, zero_one_logit_clamp)
							} else if (transform_responses == "log" && resp_type == "survival") {
								y_sim[perm_data$w == 1] = y_sim[perm_data$w == 1] * exp(delta)
							} else if (transform_responses == "log" && resp_type == "count") {
								y_sim[perm_data$w == 1] = as.integer(round(y_sim[perm_data$w == 1] * exp(delta)))
							} else if (transform_responses == "log" && resp_type != "count") {
								y_sim[perm_data$w == 1] = y_sim[perm_data$w == 1] * exp(delta)
							} else {
								y_sim[perm_data$w == 1] = y_sim[perm_data$w == 1] + delta
							}
						}
						w_priv$y = y_sim
					}
					w_priv$cached_values = private$build_fast_randomization_worker_cache(
						if (k == 1L) base_cache else w_priv$cached_values,
						preserve_cache_keys = preserve_cache_keys
					)
					est = tryCatch(
						w_priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE),
						error = function(e) NA_real_
					)
					if (is.function(worker$is_nonestimable) &&
					    isTRUE(worker$is_nonestimable("estimate"))) {
						est = NA_real_
					}
					if (is.list(est) && "b" %in% names(est)) est = est$b[1]
					out[k] = as.numeric(est)[1]
				}
				out
			}
			as.numeric(unlist(private$par_lapply(
				chunks,
				run_chunk,
				n_cores = actual_rand_cores,
				budget = 1L,
				show_progress = FALSE,
				export_list = list(
					permutations = permutations,
					y = y,
					transform_responses = transform_responses,
					preserve_cache_keys = preserve_cache_keys
				)
			), use.names = FALSE))
		},
		compute_two_sided_randomization_pval_from_t0s = function(t0s, t){
			na_t0s = !is.finite(t0s)
			nsim_adj = sum(!na_t0s)
			min_required = max(10L, as.integer(length(t0s) * 0.10))
			if (nsim_adj < min_required) {
				if (isTRUE(private$harden)) private$cache_nonestimable_estimate("randomization_too_few_finite_estimates")
				return(NA_real_)
			}
			min(1, max(2 / nsim_adj, 2 * min(sum(t0s >= t, na.rm = TRUE) / nsim_adj, sum(t0s <= t, na.rm = TRUE) / nsim_adj)))
		},
		compute_two_sided_randomization_pval_band = function(t0s, t, conf_level){
			valid = is.finite(t0s)
			n = sum(valid)
			if (n == 0L) return(c(NA_real_, NA_real_))
			x_ge = sum(t0s[valid] >= t)
			x_le = sum(t0s[valid] <= t)
			binom_band = function(x){
				alpha_band = 1 - conf_level
				lower = if (x <= 0L) 0 else stats::qbeta(alpha_band / 2, x, n - x + 1)
				upper = if (x >= n) 1 else stats::qbeta(1 - alpha_band / 2, x + 1, n - x)
				c(lower, upper)
			}
			band_ge = binom_band(x_ge)
			band_le = binom_band(x_le)
			band = c(2 * min(band_ge[1], band_le[1]), 2 * min(band_ge[2], band_le[2]))
			pmin(1, pmax(0, band))
		},
		subset_permutations = function(permutations, indices){
			if (is.null(permutations)) return(NULL)
			if (!is.null(permutations$w_mat)) {
				list(
					w_mat = permutations$w_mat[, indices, drop = FALSE],
					m_mat = if (!is.null(permutations$m_mat)) permutations$m_mat[, indices, drop = FALSE] else NULL
				)
			} else {
				permutations[indices]
			}
		},
		get_randomization_distribution_prefix = function(r, delta, transform_responses, show_progress, permutations, cache_key, batch_size = NULL, zero_one_logit_clamp = .Machine$double.eps){
			private$ensure_resampling_distribution_cache("rand")
			cached = if (!is.null(cache_key)) private$get_cached_resampling_distribution("rand", cache_key) else NULL
			if (length(cached) > 0L && !any(is.finite(cached))) {
				cached = NULL
				if (!is.null(cache_key)) private$set_cached_resampling_distribution("rand", cache_key, NULL)
			}
			have = length(cached)
			target = if (is.null(batch_size)) as.integer(r) else min(as.integer(r), have + as.integer(batch_size))
			if (have < target) {
				idx = seq.int(have + 1L, target)
				new_t0s = self$approximate_randomization_distribution_beta_hat_T(
					r = length(idx),
					delta = delta,
					transform_responses = transform_responses,
					show_progress = isTRUE(show_progress) && target >= r && have == 0L,
					permutations = private$subset_permutations(permutations, idx),
					zero_one_logit_clamp = zero_one_logit_clamp
				)
				cached = c(cached, new_t0s)
				if (!is.null(cache_key)) private$set_cached_resampling_distribution("rand", cache_key, cached)
			}
			cached[seq_len(target)]
		},
		compute_two_sided_pval_with_sequential_mc = function(t, r, delta, transform_responses, show_progress, permutations, cache_key, zero_one_logit_clamp = .Machine$double.eps){
			mc_control = private$randomization_mc_control
			if (!private$sequential_mc_control_enabled(mc_control)) return(NULL)
			batch_size = min(as.integer(r), as.integer(mc_control$mc_batch_size))
			min_draws = min(as.integer(r), as.integer(mc_control$mc_min_draws))
			if (batch_size <= 0L || min_draws <= 0L || batch_size >= as.integer(r)) return(NULL)
			conf_level = mc_control$mc_conf_level
			threshold = mc_control$mc_stop_threshold
			# This is one of two top-level entry points that own the reusable
			# randomization-worker cache's lifetime (see `compute_randomization_
			# distr_via_reused_worker_states()`'s `reuse_key` comment) -- a
			# standalone p-value call. The other is `compute_rand_confidence_
			# interval()` (a CI search, which calls this function internally once
			# per bisection step and must keep the SAME cached worker alive across
			# all of them). The reentrancy depth counter lets either one "win":
			# whichever is outermost clears the cache on its own entry/exit; a
			# nested call here (inside an active CI search) just increments/
			# decrements without disturbing it.
			private$begin_rand_worker_reuse_session()
			on.exit(private$end_rand_worker_reuse_session(), add = TRUE)
			repeat {
				t0s = private$get_randomization_distribution_prefix(
					r = r,
					delta = delta,
					transform_responses = transform_responses,
					show_progress = FALSE,
					permutations = permutations,
					cache_key = cache_key,
					batch_size = batch_size,
					zero_one_logit_clamp = zero_one_logit_clamp
				)
				n_valid = sum(is.finite(t0s))
				p_hat = private$compute_two_sided_randomization_pval_from_t0s(t0s, t)
				if (length(t0s) >= as.integer(r) || n_valid < min_draws || !is.finite(p_hat)) {
					if (length(t0s) >= as.integer(r) || !is.finite(p_hat)) return(p_hat)
				} else {
					if (private$sequential_mc_band_excludes_threshold(t0s, t, threshold, conf_level)) return(p_hat)
				}
				if (length(t0s) >= as.integer(r)) return(p_hat)
			}
		},
		generate_permutations = function(r){
			if (should_run_asserts()) {
				assertCount(r, positive = TRUE)
			}
			design_sig = private$stable_signature(list(
				class = class(private$des_obj),
				n = private$n,
				prob_T = private$prob_T,
				m = private$des_obj_priv_int$m,
				strata_cols = private$des_obj_priv_int$strata_cols
			))
			cache_key = paste0(as.integer(r), "|", design_sig)
			cached = private$des_obj_priv_int$permutations_cache[[cache_key]]
			if (!is.null(cached)) return(cached)
			des_template = private$des_obj$duplicate()
			w_mat = des_template$draw_ws_according_to_design(as.integer(r))
			if (!is.matrix(w_mat)) {
				w_mat = matrix(as.numeric(w_mat), nrow = private$n)
			}
			storage.mode(w_mat) = "numeric"
			permutations = list(
				w_mat = w_mat,
				m_mat = NULL
			)
			private$des_obj_priv_int$permutations_cache[[cache_key]] = permutations
			permutations
		},
		build_randomization_distribution_cache_key = function(r, delta, transform_responses, permutations){
			delta_key = formatC(as.numeric(delta), digits = 17, format = "fg", flag = "#")
			perm_sig = private$stable_signature(permutations)
			paste(as.integer(r), delta_key, transform_responses, perm_sig, sep = "|")
		},
		get_resampling_draw_contract = function(operation){
			resampling_draw_contract(operation)
		},
		# Reentrant session boundary for `cached_values$reusable_rand_worker`
		# (see `compute_randomization_distr_via_reused_worker_states()`'s
		# `reuse_key` comment for why cross-delta reuse is safe). A depth
		# counter rather than a plain begin/end pair because two top-level
		# entry points share this cache's lifetime and can nest: a CI search
		# (`compute_rand_confidence_interval()`) calls the p-value path
		# (`compute_two_sided_pval_with_sequential_mc()`) once per bisection
		# step, and only the outermost caller's exit should actually clear
		# the cache -- an inner call clearing it on its own exit would
		# discard the container the still-running outer search needs for
		# its next step.
		begin_rand_worker_reuse_session = function(){
			depth = private$cached_values$rand_worker_reuse_depth %||% 0L
			private$cached_values$rand_worker_reuse_depth = depth + 1L
			if (depth == 0L) private$cached_values$reusable_rand_worker = NULL
			invisible(NULL)
		},
		end_rand_worker_reuse_session = function(){
			depth = max(0L, (private$cached_values$rand_worker_reuse_depth %||% 1L) - 1L)
			private$cached_values$rand_worker_reuse_depth = depth
			if (depth <= 0L) private$cached_values$reusable_rand_worker = NULL
			invisible(NULL)
		},
		ensure_resampling_distribution_cache = function(operation){
			private$cached_values = resampling_distribution_cache_ensure(
				private$cached_values,
				operation
			)
			invisible(private$cached_values)
		},
		get_cached_resampling_distribution = function(operation, cache_key){
			resampling_distribution_cache_get(
				private$cached_values,
				operation,
				cache_key
			)
		},
		set_cached_resampling_distribution = function(operation, cache_key, value){
			private$cached_values = resampling_distribution_cache_set(
				private$cached_values,
				operation,
				cache_key,
				value
			)
			invisible(value)
		},
		load_resampling_draw_into_worker = function(operation, worker_state, draw, ...){
			contract = private$get_resampling_draw_contract(operation)
			loader = private[[contract$loader]]
			if (!is.function(loader)) {
				stop("No resampling draw loader named `", contract$loader, "` for operation `", operation, "`.", call. = FALSE)
			}
			do.call(loader, c(list(worker_state = worker_state, draw = draw), list(...)))
			invisible(worker_state)
		},
		load_randomization_draw_into_worker = function(worker_state, draw, delta, transform_responses, setup, zero_one_logit_clamp = .Machine$double.eps){
			perm_w = if (is.list(draw) && !is.null(draw$w)) draw$w else draw
			private$load_randomization_perm_into_worker(
				worker_state = worker_state,
				perm_w = perm_w,
				delta = delta,
				transform_responses = transform_responses,
				y_delta = setup$y_delta,
				base_template_y = setup$base_template_y,
				base_template_dead = setup$base_template_dead,
				zero_one_logit_clamp = zero_one_logit_clamp
			)
		},
		compute_randomization_worker_estimate = function(worker_state){
			estimator = private[["compute_bootstrap_worker_estimate"]]
			if (!is.function(estimator)) {
				stop("No reusable-worker estimator is available for randomization draws.", call. = FALSE)
			}
			estimator(worker_state)
		},
		shift_randomization_responses = function(y, w, delta, transform_responses, response_type, inverse = FALSE, zero_one_logit_clamp = .Machine$double.eps){
			if (delta == 0) return(y)
			y_shifted = y
			idx_treated = which(w == 1)
			if (length(idx_treated) == 0L) return(y_shifted)
			signed_delta = if (isTRUE(inverse)) -delta else delta
			if (transform_responses == "logit") {
				y_shifted[idx_treated] = inv_logit(logit(y_shifted[idx_treated], zero_one_logit_clamp) + signed_delta, zero_one_logit_clamp)
				return(y_shifted)
			}
			if (transform_responses == "log" && response_type == "survival") {
				y_shifted[idx_treated] = y_shifted[idx_treated] * exp(signed_delta)
				return(y_shifted)
			}
			if (transform_responses == "log" && response_type == "count") {
				y_shifted[idx_treated] = as.integer(round(y_shifted[idx_treated] * exp(signed_delta)))
				return(y_shifted)
			}
			if (transform_responses == "log" && response_type != "count") {
				y_shifted[idx_treated] = y_shifted[idx_treated] * exp(signed_delta)
				return(y_shifted)
			}
			y_shifted[idx_treated] = y_shifted[idx_treated] + signed_delta
			y_shifted
		},
		setup_randomization_template_and_shifts = function(delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			# `y_delta` (and the plain `base_template_y`/`base_template_dead`
			# vectors below) are all the reused-worker fast path -- the common
			# case, hit on every sequential-MC batch -- actually reads off this
			# list (see `load_randomization_draw_into_worker()`). A full duplicated
			# Design `template` object is only needed by the slower "standard"
			# duplicate-per-iteration path and its debug/parallel-warmup variants.
			# Compute the shift directly on the plain `y` vector (no design object
			# needed for that), and build `template` lazily via `get_template()` so
			# callers that never touch it -- e.g. every Poisson/NegBin/logistic/
			# OLS-family class going through the reused-worker path -- never pay a
			# `duplicate()` for a template they'll never use.
			if (should_run_asserts() && delta != 0) {
				if (private$des_obj_priv_int$response_type == "incidence" && is.null(private$custom_randomization_statistic_function)) stop("randomization tests with delta nonzero not supported for incidence")
				# shift_randomization_responses() below only shifts the plain
				# y vector; for a censored subject y is NA (the value lives in
				# y_L/y_R instead), so a nonzero-delta null shift would
				# silently be a no-op for every censored row rather than an
				# error. Block it explicitly instead of returning a quietly
				# wrong null-shifted statistic.
				if (isTRUE(private$has_general_censoring)) stop("randomization tests with delta nonzero are not yet supported for left-/interval-censored survival data.")
			}
			y_delta = if (delta != 0) {
				private$shift_randomization_responses(
					y = private$y,
					w = private$w,
					delta = delta,
					transform_responses = transform_responses,
					response_type = private$des_obj_priv_int$response_type,
					inverse = TRUE,
					zero_one_logit_clamp = zero_one_logit_clamp
				)
			} else {
				private$y
			}
			template_cache = NULL
			get_template = function() {
				if (is.null(template_cache)) {
					template_cache <<- private$des_obj$duplicate()
					template_cache$.__enclos_env__$private$y = y_delta
				}
				template_cache
			}
			list(get_template = get_template, y_delta = y_delta, base_template_y = private$y, base_template_dead = private$dead, lightweight_custom_context = private$des_obj_priv_int)
		},
		load_randomization_perm_into_worker = function(worker_state, perm_w, delta, transform_responses, y_delta, base_template_y, base_template_dead, zero_one_logit_clamp = .Machine$double.eps){
			inf_priv = if (!is.null(worker_state$worker_inf)) {
				worker_state$worker_inf$.__enclos_env__$private
			} else if (!is.null(worker_state$worker_priv)) {
				worker_state$worker_priv
			} else {
				worker_state$worker$.__enclos_env__$private
			}
			des_priv = if (!is.null(worker_state$worker_des)) {
				worker_state$worker_des$.__enclos_env__$private
			} else {
				worker_state$worker_des_priv
			}
			
			# Update design private state
			if (!is.null(des_priv)) des_priv$w = perm_w
			if (delta != 0) {
				y_sim = private$shift_randomization_responses(
					y = y_delta,
					w = perm_w,
					delta = delta,
					transform_responses = transform_responses,
					response_type = if (!is.null(des_priv)) des_priv$response_type else private$des_obj_priv_int$response_type,
					inverse = FALSE,
					zero_one_logit_clamp = zero_one_logit_clamp
				)
				if (!is.null(des_priv)) des_priv$y = y_sim
			} else {
				y_sim = base_template_y
				if (!is.null(des_priv)) des_priv$y = y_sim
			}
			
			# Sync to inference private state
			inf_priv$w = perm_w
			inf_priv$y = y_sim
			inf_priv$y_temp = y_sim
			inf_priv$dead = if (!is.null(des_priv)) des_priv$dead else base_template_dead
			inf_priv$cached_values$KKstats = NULL # reset
			inf_priv$cached_values$beta_hat_T = NULL
			inf_priv$cached_values$s_beta_hat_T = NULL
			inf_priv$likelihood_null_warm_cache = list()
			
			# Reset all private design matrix and covariate caches
			inf_priv$cached_design_matrix = NULL
			inf_priv$cached_w_for_design_matrix = NULL
			inf_priv$cached_harden_for_design_matrix = NULL
			# inf_priv$cached_hardened_X_cov = NULL  # Preserve covariate-only cache under randomization
			inf_priv$cached_reduced_X = NULL
			inf_priv$cached_X_full_for_reduced = NULL
			inf_priv$cached_keep_for_reduced = NULL
			inf_priv$cached_j_treat_for_reduced = NULL
			
			inf_priv$fit_warm_start = worker_state$base_fit_warm_start
			inf_priv$fit_warm_start_type = worker_state$base_fit_warm_start_type
			inf_priv$fit_warm_start_fisher = worker_state$base_fit_warm_start_fisher
			
			if (!is.null(inf_priv$compute_basic_match_data)) inf_priv$compute_basic_match_data()
			invisible(NULL)
		},
		sync_randomization_worker_state = function(thread_des_obj, thread_inf_obj){
			if (is.null(thread_des_obj) || is.null(thread_inf_obj)) return(invisible(NULL))
			des_priv = thread_des_obj$.__enclos_env__$private
			inf_priv = thread_inf_obj$.__enclos_env__$private
			inf_priv$des_obj = thread_des_obj
			inf_priv$des_obj_priv_int = des_priv
			inf_priv$w = des_priv$w
			inf_priv$y = des_priv$y
			inf_priv$y_temp = des_priv$y
			# Design no longer stores a raw dead field (y/y_L/y_R migration,
			# interval_censored_survival_response.md TODO-1) -- des_priv$dead is always
			# NULL now, so this used to silently null out inf_priv$dead on every sync.
			# dead never changes during randomization/permutation (only w, and y under a
			# nonzero delta shift), so simply leave whatever inf_priv$dead already holds
			# (inherited correctly at worker construction/duplication time) untouched.
			# Design$resample_assignment() already resamples y_L/y_R in
			# lockstep with y/w (see TODO-2 in
			# interval_censored_survival_response.md); this call site was the
			# one place that copy never reached the Inference worker's own
			# private$y_L/y_R, leaving them stale post-resample for any class
			# consuming them (TODO-4's Weibull general-censoring dispatch).
			inf_priv$y_L = des_priv$y_L
			inf_priv$y_R = des_priv$y_R
			if (private$has_match_structure) inf_priv$m = des_priv$m
			if (!is.null(inf_priv$compute_basic_match_data)) inf_priv$compute_basic_match_data()
			
			# Reset all private design matrix and covariate caches
			inf_priv$cached_design_matrix = NULL
			inf_priv$cached_w_for_design_matrix = NULL
			inf_priv$cached_harden_for_design_matrix = NULL
			# inf_priv$cached_hardened_X_cov = NULL  # Preserve covariate-only cache under randomization
			inf_priv$cached_reduced_X = NULL
			inf_priv$cached_X_full_for_reduced = NULL
			inf_priv$cached_keep_for_reduced = NULL
			inf_priv$cached_j_treat_for_reduced = NULL
			
			invisible(NULL)
		},
		run_randomization_iteration = function(thread_des_obj, thread_inf_obj, perm_idx, permutations, delta, transform_responses, y_delta, base_template_y, base_template_dead, custom_stat_analysis, lightweight_custom_context, debug = FALSE, zero_one_logit_clamp = .Machine$double.eps){
			use_perms = !is.null(perm_idx)
			get_perm_data = if (use_perms) {
				if (!is.null(permutations$w_mat)) {
					n_avail = ncol(permutations$w_mat)
					function(i) { j = ((i - 1L) %% n_avail) + 1L; list(w = permutations$w_mat[, j], m_vec = if (!is.null(permutations$m_mat)) permutations$m_mat[, j] else NULL) }
				} else function(i) permutations[[i]]
			} else NULL
			if (isTRUE(custom_stat_analysis$can_use_lightweight_yw_only) && use_perms) {
				perm_data = get_perm_data(perm_idx); w_sim = perm_data$w; y_sim = y_delta
				if (delta != 0) {
					y_sim = private$shift_randomization_responses(
						y = y_sim,
						w = w_sim,
						delta = delta,
						transform_responses = transform_responses,
						response_type = lightweight_custom_context$response_type,
						inverse = FALSE,
						zero_one_logit_clamp = zero_one_logit_clamp
					)
				}
				cpp_fn_override = if (is.function(custom_stat_analysis[["get_cpp_fn"]])) custom_stat_analysis$get_cpp_fn() else NULL
				val = private$evaluate_lightweight_custom_randomization_statistic(lightweight_custom_context, y_sim, w_sim, base_template_dead, cpp_fn_override = cpp_fn_override)
				if (isTRUE(debug)) return(list(val = val, error = NULL))
				return(val)
			}
			if (use_perms) {
				perm_data = get_perm_data(perm_idx)
				thread_des_obj$.__enclos_env__$private$w = perm_data$w
				if (!is.null(perm_data$m_vec)) thread_des_obj$.__enclos_env__$private$m = perm_data$m_vec
			} else {
				thread_des_obj$.__enclos_env__$private$resample_assignment()
			}
			if (delta != 0) {
				y_sim = private$shift_randomization_responses(
					y = y_delta,
					w = thread_des_obj$.__enclos_env__$private$w,
					delta = delta,
					transform_responses = transform_responses,
					response_type = thread_des_obj$.__enclos_env__$private$response_type,
					inverse = FALSE,
					zero_one_logit_clamp = zero_one_logit_clamp
				)
				thread_des_obj$.__enclos_env__$private$y = y_sim
			}
			private$sync_randomization_worker_state(thread_des_obj, thread_inf_obj)
			iter_error = NULL
			estimate = tryCatch(
				thread_inf_obj$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE),
				error = function(e) { iter_error <<- conditionMessage(e); NA_real_ }
			)
			if (is.function(thread_inf_obj$is_nonestimable) &&
			    isTRUE(thread_inf_obj$is_nonestimable("estimate"))) {
				estimate = NA_real_
			}
			val = if (is.list(estimate) && "b" %in% names(estimate)) as.numeric(estimate$b[1]) else as.numeric(estimate)
			if (isTRUE(debug)) return(list(val = val, error = iter_error))
			val
		},
		compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE){
			# 2026-08-19 (fix_inference_hierarchy.md "Static Cleanup", "Ban semantic
			# classification through private method-name sniffing"): only the
			# kk_quantile_regr_ivwc capability check is live here -- classes composing
			# the KKQuantileRegrOneLik component always override this whole method
			# (inference_all_KK_quantile_regr_one_lik_abstract.R's own
			# compute_treatment_estimate_during_randomization_inference wins in the
			# component merge), so this base RandomizationTest-component version of the
			# method never actually runs for a OneLik-composing class; the former
			# is_a_kk_quantile_regr_one_lik probe branch was dead code.
			if (identical(private$des_obj_priv_int$response_type, "proportion") &&
			    "kk_quantile_regr_ivwc" %in% self$capabilities()){
				private$y = .sanitize_proportion_response(private$y, interior = TRUE)
				private$cached_values$KKstats = NULL
				private$cached_values$beta_hat_T = NULL
				private$cached_values$s_beta_hat_T = NULL
				if (!is.null(private$compute_basic_match_data)) private$compute_basic_match_data()
				return(self$compute_estimate(estimate_only = estimate_only))
			}
			if (!is.null(private[["compiled_cpp_stat_fn"]])) {
				cpp_fn = private$get_compiled_cpp_stat()
				arity = length(formals(cpp_fn))
				return(as.numeric(
					if (arity >= 3L) cpp_fn(private$y, as.integer(private$w), as.integer(private$dead))
					else cpp_fn(private$y, as.integer(private$w))
				)[1L])
			}
			if (is.null(private$custom_randomization_statistic_function)) self$compute_estimate(estimate_only = estimate_only)
			else private$custom_randomization_statistic_function()
		}
	))
)
