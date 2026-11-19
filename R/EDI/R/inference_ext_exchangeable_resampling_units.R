#' Shared Exchangeable Resampling Unit Helpers
#'
#' Internal helpers for resampling methods that operate on empirical units.
#' m-out-of-n bootstrap and PRW subsampling share unit discovery but differ in
#' replacement semantics and calibration.
#'
#' Pattern-1 file-split extension, spliced into exactly one class
#' (\code{InferenceNonParamBootstrap}) -- not a reusable mixin.
#'
#' @keywords internal
#' @noRd
InferenceExtExchangeableResamplingUnits = list(
	public = list(),
	private = list(
		resolve_resampling_unit = function(unit = "auto"){
			unit = tolower(as.character(unit)[1L])
			valid = c("auto", "observation", "cluster", "block", "pair", "matched_set")
			if (should_run_asserts()) assertChoice(unit, valid)
			if (unit != "auto") return(unit)
			design_obj = private$des_obj
			is_matching_design = isTRUE(design_obj$is_matching_design())
			is_cluster_design = design_obj$is_a_cluster_capable()
			is_blocking_design = isTRUE(design_obj$is_blocking_design())
			if (is_matching_design) {
				if (isTRUE(private$is_KK)) "matched_set" else "pair"
			} else if (is_cluster_design) {
				"cluster"
			} else if (is_blocking_design) {
				"observation"
			} else {
				"observation"
			}
		},
		get_exchangeable_units = function(unit = "auto", resampling_type = NULL){
			design_obj = private$des_obj
			n = if (!is.null(design_obj)) design_obj$get_n() else private$n
			n = as.integer(n)
			if (!is.finite(n) || n <= 0L) {
				stop("Exchangeable resampling units are unavailable.", call. = FALSE)
			}
			unit = private$resolve_resampling_unit(unit)
			des_priv = private$des_obj_priv_int
			all_idx = seq_len(n)
			make_info = function(units, unit_type, strata_ids = NULL, unit_kind = NULL, m_vec_full = NULL){
				list(
					units = units,
					unit_type = unit_type,
					strata_ids = strata_ids,
					unit_kind = unit_kind,
					m_vec_full = m_vec_full,
					n_units = length(units)
				)
			}
			if (unit %in% c("pair", "matched_set")) {
				if (is.null(des_priv) || !is.function(des_priv$init_matching_bootstrap_structure)) {
					stop("Matching structure is unavailable for resampling.", call. = FALSE)
				}
				des_priv$init_matching_bootstrap_structure()
				pair_rows = des_priv$boot_pair_rows
				i_reservoir = des_priv$boot_i_reservoir
				units = list()
				unit_kind = character(0)
				if (!is.null(pair_rows) && nrow(pair_rows) > 0L) {
					for (i in seq_len(nrow(pair_rows))) {
						units[[length(units) + 1L]] = as.integer(pair_rows[i, ])
						unit_kind = c(unit_kind, "pair")
					}
				}
				if (!is.null(i_reservoir) && length(i_reservoir) > 0L) {
					for (i in seq_along(i_reservoir)) {
						units[[length(units) + 1L]] = as.integer(i_reservoir[i])
						unit_kind = c(unit_kind, "reservoir")
					}
				}
				if (!length(units)) stop("Matching structure has no exchangeable units.", call. = FALSE)
				return(make_info(units, unit, unit_kind = unit_kind, m_vec_full = private$m))
			}
			if (unit == "cluster") {
				cluster_ids = private$get_resampling_cluster_ids()
				if (is.null(cluster_ids)) stop("Cluster IDs are unavailable for resampling.", call. = FALSE)
				group_vals = unique(cluster_ids[!is.na(cluster_ids)])
				units = lapply(group_vals, function(g) all_idx[cluster_ids == g])
				strata_ids = private$get_resampling_strata_ids()
				unit_strata = NULL
				if (!is.null(strata_ids)) {
					unit_strata = vapply(units, function(idx) as.character(strata_ids[idx[1L]]), character(1))
				}
				return(make_info(units, "cluster", strata_ids = unit_strata))
			}
			if (unit == "block" || identical(resampling_type, "resample_blocks")) {
				block_ids = private$get_resampling_block_ids()
				if (is.null(block_ids)) stop("Block IDs are unavailable for resampling.", call. = FALSE)
				block_vals = sort(unique(block_ids[is.finite(block_ids) & block_ids > 0L]))
				units = lapply(block_vals, function(g) all_idx[block_ids == g])
				return(make_info(units, "block"))
			}
			strata_ids = private$get_resampling_strata_ids()
			make_info(lapply(all_idx, function(i) i), "observation", strata_ids = strata_ids)
		},
		get_resampling_cluster_ids = function(){
			des_priv = private$des_obj_priv_int
			if (is.null(des_priv) || is.null(des_priv$cluster_col) || is.null(des_priv$Xraw)) return(NULL)
			n = private$des_obj$get_n()
			as.character(des_priv$Xraw[seq_len(n), ][[des_priv$cluster_col]])
		},
		get_resampling_strata_ids = function(){
			des_priv = private$des_obj_priv_int
			if (is.null(des_priv) || !is.function(des_priv$get_strata_keys)) return(NULL)
			tryCatch(as.character(des_priv$get_strata_keys()), error = function(e) NULL)
		},
		get_resampling_block_ids = function(){
			if (is.null(private$des_obj) || !is.function(private$des_obj$get_block_ids)) return(NULL)
			tryCatch(as.integer(private$des_obj$get_block_ids()), error = function(e) NULL)
		},
		resampling_effective_p = function(){
			X = tryCatch(private$get_X(), error = function(e) private$X)
			if (is.null(X)) return(1L)
			max(1L, as.integer(NCOL(X)))
		},
		resolve_resampling_size = function(size, n_units, label, deterministic_exponent = 0.7){
			if (is.list(size)) stop(label, " selection must be resolved before drawing.", call. = FALSE)
			if (is.null(size)) {
				size = floor(as.numeric(n_units) ^ deterministic_exponent)
			}
			size = as.integer(size)[1L]
			min_size = max(5L, private$resampling_effective_p() + 2L)
			max_size = floor(as.integer(n_units) / 2L)
			if (!is.finite(size) || size < min_size || size > max_size) {
				stop(label, " must satisfy ", min_size, " <= ", label, " <= ", max_size, ".", call. = FALSE)
			}
			size
		},
		allocate_resampling_sizes_by_stratum = function(total_size, strata_ids, replace){
			strata_ids = as.character(strata_ids)
			strata_vals = unique(strata_ids)
			counts = tabulate(match(strata_ids, strata_vals), nbins = length(strata_vals))
			raw = total_size * counts / sum(counts)
			alloc = floor(raw)
			remaining = as.integer(total_size) - sum(alloc)
			if (remaining > 0L) {
				ord = order(raw - alloc, decreasing = TRUE)
				alloc[ord[seq_len(remaining)]] = alloc[ord[seq_len(remaining)]] + 1L
			}
			if (!isTRUE(replace) && any(alloc > counts)) {
				stop("Subsampling stratum is too small for the requested subsample size.", call. = FALSE)
			}
			names(alloc) = strata_vals
			alloc
		},
		sample_exchangeable_unit_ids = function(unit_info, size, replace, stratified = TRUE){
			n_units = length(unit_info$units)
			if (n_units == 0L) stop("No exchangeable units are available.", call. = FALSE)
			if (isTRUE(stratified) && !is.null(unit_info$strata_ids)) {
				alloc = private$allocate_resampling_sizes_by_stratum(size, unit_info$strata_ids, replace = replace)
				out = integer(0)
				for (stratum in names(alloc)) {
					k = as.integer(alloc[[stratum]])
					if (k <= 0L) next
					ids = which(unit_info$strata_ids == stratum)
					out = c(out, sample(ids, k, replace = replace))
				}
				return(as.integer(out))
			}
			sample.int(n_units, size, replace = replace)
		},
		build_resampling_draw_from_units = function(unit_info, selected_unit_ids, size_label, preserve_order = FALSE){
			selected_unit_ids = as.integer(selected_unit_ids)
			if (!length(selected_unit_ids)) return(list(i_b = integer(0), m_vec_b = NULL))
			rows = as.integer(unlist(unit_info$units[selected_unit_ids], use.names = FALSE))
			m_vec_b = NULL
			if (!is.null(unit_info$unit_kind)) {
				m_out = integer(0)
				pair_id = 0L
				for (unit_id in selected_unit_ids) {
					unit_rows = unit_info$units[[unit_id]]
					if (identical(unit_info$unit_kind[[unit_id]], "pair")) {
						pair_id = pair_id + 1L
						m_out = c(m_out, rep(pair_id, length(unit_rows)))
					} else {
						m_out = c(m_out, rep(0L, length(unit_rows)))
					}
				}
				m_vec_b = as.integer(m_out)
			} else if (!is.null(unit_info$m_vec_full)) {
				m_vec_b = private$renumber_match_ids(unit_info$m_vec_full[rows])
			}
			if (isTRUE(preserve_order)) {
				ord = order(rows)
				rows = rows[ord]
				if (!is.null(m_vec_b)) m_vec_b = m_vec_b[ord]
			}
			draw = list(i_b = rows, m_vec_b = m_vec_b)
			draw$unit_ids = selected_unit_ids
			draw$unit_type = unit_info$unit_type
			draw$n_units = unit_info$n_units
			draw[[size_label]] = length(selected_unit_ids)
			draw
		},
		generate_exchangeable_resampling_draws = function(unit_info, B, size, replace, stratified = TRUE, preserve_order = FALSE, size_label){
			B = as.integer(B)
			size = as.integer(size)
			draws = tryCatch(
				exchangeable_resampling_draws_cpp(
					units = unit_info$units,
					strata_ids_sexp = unit_info$strata_ids %||% NULL,
					unit_kind_sexp = unit_info$unit_kind %||% NULL,
					m_vec_full_sexp = unit_info$m_vec_full %||% NULL,
					B = B,
					size = size,
					replace = isTRUE(replace),
					stratified = isTRUE(stratified),
					preserve_order = isTRUE(preserve_order),
					unit_type = unit_info$unit_type,
					size_label = size_label
				),
				error = function(e) NULL
			)
			if (!is.null(draws)) return(draws)
			replicate(B, {
				selected = private$sample_exchangeable_unit_ids(
					unit_info = unit_info,
					size = size,
					replace = replace,
					stratified = stratified
				)
				private$build_resampling_draw_from_units(unit_info, selected, size_label = size_label, preserve_order = preserve_order)
			}, simplify = FALSE)
		},
		compute_resampling_draw_distribution = function(draws, operation, show_progress = TRUE, debug = FALSE, cache_key = NULL){
			private$check_bootstrap_replicate_deadline(paste0(operation, " setup"))
			private$ensure_resampling_distribution_cache(operation)
			if (!isTRUE(debug) && !is.null(cache_key)) {
				cached = private$get_cached_resampling_distribution(operation, cache_key)
				if (!is.null(cached)) return(cached)
			}
			n_draws = length(draws)
			if (n_draws == 0L) return(numeric(0))
			# v1.0.6-TODO-230: ratio estimands mark a degenerate subsampling / m-out-of-n draw
			# NaN (unusable) on every path: the reused worker, the fresh-object path and debug.
			degenerate_rule = if (operation %in% c("subsampling", "m_out_of_n_boot")) edi_ratio_resampling_degenerate_rule(self, private) else NULL
			mark_draw = function(theta, draw, worker_priv = NULL) {
				if (is.null(degenerate_rule)) return(theta)
				edi_mark_degenerate_resampling_draw(self, private, operation, theta, draw, worker_priv = worker_priv, rule = degenerate_rule)
			}
			if (isTRUE(debug)) {
				debug_results = lapply(draws, function(draw) {
					private$check_bootstrap_replicate_deadline(paste0(operation, " debug replicate"))
					iter_warns = character(0)
					iter_errs = character(0)
					iter_val = withCallingHandlers(
						tryCatch({
							sub_inf = private$bootstrap_subset_inference(draw, smooth = FALSE)
							if (is.null(sub_inf)) NA_real_ else mark_draw(as.numeric(sub_inf$compute_estimate(estimate_only = TRUE))[1L], draw, sub_inf$.__enclos_env__$private)
						}, error = function(e) {
							if (private$is_resampling_control_condition(e)) stop(e)
							iter_errs <<- c(iter_errs, conditionMessage(e))
							NA_real_
						}),
						warning = function(w) { iter_warns <<- c(iter_warns, conditionMessage(w)); invokeRestart("muffleWarning") }
					)
					private$check_bootstrap_replicate_deadline(paste0(operation, " debug replicate"))
					list(val = as.numeric(iter_val)[1L], errors = iter_errs, warnings = iter_warns)
				})
				values = vapply(debug_results, function(x) x$val, numeric(1))
				errors_list = lapply(debug_results, `[[`, "errors")
				warnings_list = lapply(debug_results, `[[`, "warnings")
				num_errors_vec = lengths(errors_list)
				num_warnings_vec = lengths(warnings_list)
				if (!is.null(cache_key)) private$set_cached_resampling_distribution(operation, cache_key, values)
				return(list(
					values = values,
					errors = errors_list,
					warnings = warnings_list,
					num_errors = num_errors_vec,
					num_warnings = num_warnings_vec,
					prop_iterations_with_errors = mean(num_errors_vec > 0),
					prop_iterations_with_warnings = mean(num_warnings_vec > 0),
					prop_illegal_values = mean(!is.finite(values)),
					finite_fraction = mean(is.finite(values)),
					num_degenerate = sum(is.nan(values))
				))
			}
			actual_cores = private$effective_parallel_cores(operation, self$num_cores)
			reusable = isTRUE(private$use_reusable_bootstrap_worker())
			values = if (reusable) {
				private$compute_reusable_bootstrap_worker_distribution(
					draws = draws,
					actual_cores = actual_cores,
					show_progress = show_progress,
					operation = operation
				)
			} else {
				as.numeric(unlist(private$par_lapply(seq_along(draws), function(i) {
					private$check_bootstrap_replicate_deadline(paste0(operation, " replicate"))
					sub_inf = private$bootstrap_subset_inference(draws[[i]], smooth = FALSE)
					if (is.null(sub_inf)) return(NA_real_)
					out = tryCatch({
						theta = as.numeric(sub_inf$compute_estimate(estimate_only = TRUE))[1L]
						if (is.finite(theta)) mark_draw(theta, draws[[i]], sub_inf$.__enclos_env__$private) else NA_real_
					}, error = private$resampling_error_to_na)
					private$check_bootstrap_replicate_deadline(paste0(operation, " replicate"))
					out
				}, n_cores = actual_cores, show_progress = show_progress), use.names = FALSE))
			}
			if (!is.numeric(values)) values = as.numeric(values)
			# The reused worker has no per-draw object left here; the draw's arm rule is
			# applied to its rows (the g-computation worker also applies its fit rule).
			if (!is.null(degenerate_rule) && reusable) {
				values = vapply(seq_along(values), function(i) mark_draw(values[i], draws[[i]]), numeric(1L))
			}
			if (!is.null(cache_key)) private$set_cached_resampling_distribution(operation, cache_key, values)
			values
		},
		get_cached_centered_resampling_pivot = function(operation, cache_key){
			cache_name = paste0(operation, "_centered_pivot_cache")
			cache = private$cached_values[[cache_name]]
			if (is.null(cache)) return(NULL)
			cache[[cache_key]]
		},
		set_cached_centered_resampling_pivot = function(operation, cache_key, value){
			cache_name = paste0(operation, "_centered_pivot_cache")
			if (is.null(private$cached_values[[cache_name]])) {
				private$cached_values[[cache_name]] = list()
			}
			private$cached_values[[cache_name]][[cache_key]] = value
			invisible(value)
		},
		# Resolves a list-valued size spec (b = list(...) / m = list(...)) to one
		# size via the family's minimum-volatility selector. alpha is the CI
		# level for CI targets; NULL (p-value targets) uses size$alpha, default
		# 0.05. Returns the selected size, which may be NA when selection fails;
		# the caller records the failure. Shared by the generic setup below and
		# the risk-ratio log-scale pivots (v1.0.6-TODO-196).
		select_resampling_size_from_spec = function(family, size, B, alpha = NULL, resampling_type = NULL, scaling = "sqrt_n", show_progress = TRUE){
			m_out_of_n = identical(family, "m_out_of_n")
			selector = if (m_out_of_n) self$select_optimal_m_out_of_n_bootstrap else self$select_optimal_b_subsampling
			selection = do.call(selector, c(
				list(
					B = as.integer(size$B %||% min(as.integer(B), 251L)),
					alpha = if (!is.null(alpha)) alpha else as.numeric(size$alpha %||% 0.05)
				),
				stats::setNames(list(resampling_type), if (m_out_of_n) "bootstrap_type" else "subsampling_type"),
				list(scaling = scaling, show_progress = show_progress),
				size[setdiff(names(size), c("method", "B", "alpha"))]
			))
			selection[[if (m_out_of_n) "m_optimal" else "b_optimal"]]
		},
		# Shared setup for the centered-pivot p-value and CI of the m-out-of-n
		# bootstrap (family "m_out_of_n") and PRW subsampling (family
		# "subsampling"), target "pval" or "ci" (v1.0.6-TODO-194). The four
		# callers held four copies of this, and the subsampling copies had lost
		# the setup deadline check. Runs the deadline check, the optional
		# minimum-volatility size selection (size given as a list), size
		# resolution, the family's centered pivot and the usable-replicate count.
		# Returns list(pivot = <pivot>) on success, or list(value = <NA p-value
		# or NA CI>) with the failure already recorded, exactly as each caller
		# recorded it before.
		resampling_centered_pivot_for_inference = function(family, target, B, size, alpha = NULL, show_progress = TRUE, min_number_usable_samples = 5L, resampling_type = NULL, scaling = "sqrt_n"){
			m_out_of_n = identical(family, "m_out_of_n")
			is_ci = identical(target, "ci")
			private$check_bootstrap_replicate_deadline(paste(
				if (m_out_of_n) "m-out-of-n bootstrap" else "subsampling",
				if (is_ci) "CI setup" else "p-value setup"
			))
			fail = function(reason, procedure = NULL, harden_only = TRUE, detail = NULL){
				record = !harden_only || isTRUE(private$harden)
				label = paste(if (m_out_of_n) "m-out-of-n bootstrap" else "subsampling", if (is_ci) "confidence interval" else "p-value")
				if (is_ci) {
					if (!record) return(list(value = c(NA_real_, NA_real_)))
					if (is.null(detail)) return(list(value = private$missing_bootstrap_ci(alpha, reason, stage = "estimate", procedure = procedure)))
					value = private$missing_bootstrap_ci(alpha, reason, stage = "estimate", procedure = procedure, warn = FALSE)
					edi_warn_procedure_na(self, private, procedure = label, reason = reason, detail = detail)
					return(list(value = value))
				}
				if (record) {
					edi_record_procedure_failure(self, private, reason, "estimate", procedure = procedure)
					# Warn like the CI branch (missing_bootstrap_ci()) instead of a silent NA (v1.0.6-TODO-207).
					edi_warn_procedure_na(self, private, procedure = label, reason = reason, detail = detail)
				}
				list(value = NA_real_)
			}
			if (is.list(size)) {
				size = private$select_resampling_size_from_spec(family, size, B = B, alpha = if (is_ci) alpha else NULL,
					resampling_type = resampling_type, scaling = scaling, show_progress = show_progress)
				if (!is.numeric(size) || length(size) != 1L || !is.finite(size)) {
					return(fail(if (m_out_of_n) "m_out_of_n_m_selection_failed" else "subsampling_b_selection_failed", harden_only = FALSE))
				}
			}
			unit_info = private$get_exchangeable_units(unit = "auto", resampling_type = resampling_type)
			size = private$resolve_resampling_size(size, unit_info$n_units, if (m_out_of_n) "m" else "b")
			pivot = if (m_out_of_n) {
				private$m_out_of_n_bootstrap_centered_pivot(B = B, m = size, unit_info = unit_info, show_progress = show_progress, bootstrap_type = resampling_type, scaling = scaling)
			} else {
				private$subsampling_centered_pivot(B = B, b = size, unit_info = unit_info, show_progress = show_progress, subsampling_type = resampling_type, scaling = scaling)
			}
			# v1.0.6-TODO-230: too few usable draws for a ratio estimand is recorded and warned
			# even unhardened (the risk-ratio pivots do the same).
			if (!isTRUE(pivot$ok)) return(fail(pivot$reason, procedure = family, harden_only = is.null(pivot$detail), detail = pivot$detail))
			if (length(pivot$finite) < as.integer(min_number_usable_samples)) {
				return(fail(paste0(family, "_too_few_finite_estimates")))
			}
			list(pivot = pivot)
		},
		resampling_ci_from_centered_distribution = function(centered_scaled, alpha, est, n_units, scaling = "sqrt_n"){
			centered_scaled = centered_scaled[is.finite(centered_scaled)]
			if (!length(centered_scaled)) return(c(NA_real_, NA_real_))
			tau_n = private$resampling_scaling_factor(n_units, scaling)
			q = stats::quantile(centered_scaled, probs = c(alpha / 2, 1 - alpha / 2), names = FALSE, type = 8)
			ci = c(est - q[2L] / tau_n, est - q[1L] / tau_n)
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			ci
		},
		resampling_centered_pval = function(centered_scaled, est, delta, n_units, scaling = "sqrt_n"){
			centered_scaled = centered_scaled[is.finite(centered_scaled)]
			if (!length(centered_scaled)) return(NA_real_)
			tau_n = private$resampling_scaling_factor(n_units, scaling)
			t_obs = tau_n * (as.numeric(est)[1L] - as.numeric(delta)[1L])
			p_raw = 2 * min(mean(centered_scaled <= t_obs), mean(centered_scaled >= t_obs))
			min(1, max(2 / length(centered_scaled), p_raw))
		},
		resampling_scaling_factor = function(size, scaling = "sqrt_n"){
			if (identical(scaling, "sqrt_n")) return(sqrt(as.numeric(size)[1L]))
			if (is.list(scaling) && !is.null(scaling$rate_exponent)) {
				return(as.numeric(size)[1L] ^ as.numeric(scaling$rate_exponent)[1L])
			}
			if (is.function(scaling)) return(as.numeric(scaling(size))[1L])
			stop("Unsupported resampling scaling.", call. = FALSE)
		}
	)
)

#' Degenerate-draw rule for ratio estimands in subsampling / m-out-of-n (v1.0.6-TODO-230).
#'
#' At the small sizes subsampling and the m-out-of-n bootstrap draw at (\code{b = m =
#' floor(n^0.7)} by default), a draw in which a treatment arm has no events (or, for a
#' logit-scale estimand, only events; for a count, a zero total) has no finite log ratio:
#' the fitter stops near \eqn{\pm 20} and the draw is an atom, not a sample from the law the
#' pivot estimates. Kept, such atoms land in the tail the test uses and put a floor of about
#' twice their fraction under the p-value (v1.0.6-TODO-191). This returns the rule for the
#' calling class, or \code{NULL} when the class keeps every finite draw:
#' \describe{
#'   \item{\code{arm}}{\code{function(y, w)}: \code{TRUE} when the draw's responses
#'     \code{y} and assignments \code{w} make the ratio degenerate.}
#'   \item{\code{fit}}{\code{NULL} or \code{function(worker_priv)}: \code{TRUE} when the
#'     fit on the draw (the private environment of the object that estimated it) is
#'     non-converged or separated. Only the g-computation risk ratio has one (its reused
#'     worker applies it itself; the debug and non-reused paths call it here).}
#' }
#' Additive estimands (\code{"marginal_mean_diff"}, the g-computation risk difference)
#' have no rule. The cap on the usable fraction is \code{ratio_resampling_min_fraction_usable}.
#'
#' @keywords internal
#' @noRd
edi_ratio_resampling_degenerate_rule = function(self, private){
	cls = class(self)[1L]
	estimand = tryCatch(self$get_estimand(), error = function(e) "conditional")
	if (identical(estimand, "marginal_mean_diff")) return(NULL)
	no_or_all_events = function(y, w){
		for (arm in c(0, 1)) {
			in_arm = w == arm
			n_arm = sum(in_arm)
			events = sum(y[in_arm])
			if (n_arm == 0L || events == 0 || events == n_arm) return(TRUE)
		}
		FALSE
	}
	no_events = function(y, w){
		for (arm in c(0, 1)) {
			in_arm = w == arm
			if (!any(in_arm) || sum(y[in_arm]) == 0) return(TRUE)
		}
		FALSE
	}
	switch(cls,
		# log odds ratio (or a marginal ratio from the logit fit): zero or all events in an arm,
		# or a (quasi-)separated fit (a fitted probability numerically 0 or 1, the
		# v1.0.6-TODO-109 criterion), where the coefficient sits where the fitter stopped.
		InferenceIncidLogRegr = list(arm = no_or_all_events, fit = function(worker_priv){
			mod = worker_priv$cached_mod
			n_extreme = if (is.null(mod)) NA_integer_ else edi_logistic_n_fitted_extreme(mod$X, mod$b)
			isTRUE(!is.na(n_extreme) && n_extreme > 0L)
		}),
		InferenceIncidKKGEE = list(arm = no_or_all_events, fit = NULL),
		# log risk ratio (log link) / log rate ratio: an arm with no events is the atom; an
		# arm with only events has a finite risk of 1.
		InferenceIncidModifiedPoisson = ,
		InferenceIncidLogBinomial = ,
		InferenceCountPoisson = list(arm = no_events, fit = NULL),
		InferenceIncidGCompRiskRatio = ,
		InferenceIncidKKGCompRiskRatio = if (identical(private$get_estimand_type(), "RR")) {
			list(arm = no_or_all_events, fit = gcomp_rr_resample_is_degenerate)
		} else NULL,
		NULL
	)
}

#' Minimum usable fraction of the B draws for the generic subsampling / m-out-of-n pivot of a
#' class with a degenerate-draw rule (v1.0.6-TODO-230). Same value and reasoning as the
#' g-computation risk ratio's \code{min_fraction_usable_samples} default (owner decision
#' 2026-11-19): degenerate draws pile up in the data sets with an extreme estimate, so a
#' stricter cap (0.95) returned \code{NA} on most data sets a test should reject.
#'
#' @keywords internal
#' @noRd
ratio_resampling_min_fraction_usable = 0.8

#' Returns \code{theta}, or \code{NaN} when the subsampling / m-out-of-n draw is degenerate
#' under the class's rule (\code{edi_ratio_resampling_degenerate_rule()}). \code{draw} is the
#' resampling draw (its \code{i_b} rows index the full data); \code{worker_priv}, when given, is
#' the private environment of the object that estimated the draw (for the fit rule). Other
#' operations, non-finite \code{theta} and classes without a rule pass through.
#'
#' @keywords internal
#' @noRd
edi_mark_degenerate_resampling_draw = function(self, private, operation, theta, draw, worker_priv = NULL, rule = NULL){
	if (!(operation %in% c("subsampling", "m_out_of_n_boot"))) return(theta)
	if (length(theta) != 1L || !is.finite(theta)) return(theta)
	if (is.null(rule)) rule = edi_ratio_resampling_degenerate_rule(self, private)
	if (is.null(rule)) return(theta)
	rows = draw$i_b
	if (length(rows)) {
		y = as.numeric(private$y)[rows]
		w = as.numeric(private$w)[rows]
		ok = !is.na(y) & !is.na(w)
		if (isTRUE(rule$arm(y[ok], w[ok]))) return(NaN)
	}
	if (!is.null(worker_priv) && is.function(rule$fit) && isTRUE(rule$fit(worker_priv))) return(NaN)
	theta
}

#' The pivot-level cap (v1.0.6-TODO-230): \code{NULL} when the draws are acceptable, else the
#' failure list (\code{ok = FALSE}, a reason and a warning detail) for the generic subsampling /
#' m-out-of-n centered pivots. Applies only to classes with a degenerate-draw rule; there a
#' failed fit (\code{NA}) and a degenerate draw (\code{NaN}) both count as unusable.
#'
#' @keywords internal
#' @noRd
edi_ratio_resampling_usable_fraction_failure = function(self, private, family, draws){
	if (is.null(edi_ratio_resampling_degenerate_rule(self, private))) return(NULL)
	n_total = length(draws)
	n_usable = sum(is.finite(draws))
	if (!n_total || !bootstrap_valid_fraction_too_low(n_usable, n_total, ratio_resampling_min_fraction_usable)) return(NULL)
	n_degenerate = sum(is.nan(draws))
	what = if (identical(family, "subsampling")) "subsamples" else "m-out-of-n resamples"
	list(
		ok = FALSE,
		reason = paste0(family, "_too_few_usable_draws_fraction"),
		detail = paste0("Only ", n_usable, " of ", n_total, " ", what, " were usable (",
			format(round(100 * n_usable / n_total, 1), nsmall = 1), "%; ", n_degenerate,
			" degenerate: a treatment arm with no events (on the logit scale also only events; for a count a zero total) or a separated logistic fit; ",
			n_total - n_usable - n_degenerate, " failed). At least ",
			format(100 * ratio_resampling_min_fraction_usable), "% are needed. A degenerate draw's log ratio sits ",
			"where the fitter stopped (about +/-20), not in the sampling law the pivot needs, and keeping ",
			"only the usable draws would describe only the resamples where the estimator worked. ",
			"Use the ordinary bootstrap (compute_bootstrap_two_sided_pval() / compute_bootstrap_confidence_interval()) ",
			"or a larger ", if (identical(family, "subsampling")) "b" else "m", ".")
	)
}

#' Reused-worker version of \code{edi_mark_degenerate_resampling_draw()} (v1.0.6-TODO-230).
#'
#' Called from \code{compute_bootstrap_worker_estimate()} with the worker that just estimated
#' the draw, so the fit rule (non-convergence, separation) can read the worker's fit. Acts only
#' while \code{private$active_resampling_operation} is \code{"subsampling"} or
#' \code{"m_out_of_n_boot"}; the bootstrap, Bayesian bootstrap, jackknife and randomization
#' replicates are unchanged.
#'
#' @keywords internal
#' @noRd
edi_mark_degenerate_resampling_worker_draw = function(self, private, theta, worker_state){
	op = private$active_resampling_operation
	if (is.null(op) || !(op %in% c("subsampling", "m_out_of_n_boot"))) return(theta)
	if (length(theta) != 1L || !is.finite(theta)) return(theta)
	rule = edi_ratio_resampling_degenerate_rule(self, private)
	worker_priv = worker_state$worker_priv
	if (is.null(rule) || is.null(worker_priv)) return(theta)
	y = as.numeric(worker_priv$y)
	w = as.numeric(worker_priv$w)
	ok = !is.na(y) & !is.na(w)
	if (isTRUE(rule$arm(y[ok], w[ok]))) return(NaN)
	if (is.function(rule$fit) && isTRUE(rule$fit(worker_priv))) return(NaN)
	theta
}
