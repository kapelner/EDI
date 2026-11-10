# Realised effective sample size and rendered validity columns (v1.0.5 TODO-194).
#
# Reads the registry in inference_procedure_regime.R (the single source of truth
# for regime, rate order, n_eff rule and basis) and a design's realised data to
# say, for a design x class x procedure triple, what the effective n actually is
# here. Shared by run_all_inference()'s validity columns and the lookup accessor.

#' Realised effective-n counts of a design: one named numeric per `n_eff` rule
#' of `EDI_CONVERGENCE_N_EFF`. A count that does not apply to this design or
#' response type (no matching, no clusters, no censoring, ...) is `NA`. Never
#' errors: any accessor that fails yields `NA` for the counts that need it.
#'
#' Definitions (decisions, the registry only names the rules):
#' * `n`: subjects with an observed response.
#' * `n_pairs`: matched pairs; `n_pairs_plus_reservoir`: matched pairs plus
#'   unmatched (singleton) reservoir subjects, i.e. the number of independent
#'   units the matching induces (`get_matching_cluster_ids()`).
#' * `n_min_arm`: size of the smaller arm among assigned subjects with a response.
#' * `n_events`: survival, observed events; incidence, the smaller of the number
#'   of 1s and 0s (the rarer outcome governs the information); `NA` otherwise.
#' * `n_nonzero`: responses strictly greater than zero (count / hurdle models).
#' * `n_clusters`: distinct clusters of a cluster design; `n_strata`: distinct
#'   blocks of a blocking design.
#'
#' @param des_obj A design object.
#' @return A named numeric vector over `EDI_CONVERGENCE_N_EFF`.
#' @keywords internal
#' @noRd
edi_inference_validity_counts = function(des_obj) {
	out = stats::setNames(rep(NA_real_, length(EDI_CONVERGENCE_N_EFF)), EDI_CONVERGENCE_N_EFF)
	safe = function(expr) tryCatch(expr, error = function(e) NULL)
	y = safe(des_obj$get_y())
	w = safe(des_obj$get_w())
	rt = safe(des_obj$get_response_type())
	n_total = safe(des_obj$get_n())
	has_y = if (!is.null(y)) !is.na(y) else NULL
	out[["n"]] = if (!is.null(has_y)) as.numeric(sum(has_y)) else if (!is.null(n_total)) as.numeric(n_total) else NA_real_
	if (!is.null(y) && !is.null(w) && length(w) == length(y)) {
		ok = has_y & !is.na(w)
		out[["n_min_arm"]] = as.numeric(min(sum(ok & w == 1), sum(ok & w == 0)))
	}
	if (!is.null(y)) {
		yy = y[has_y]
		out[["n_nonzero"]] = as.numeric(sum(yy > 0))
		if (identical(rt, "incidence")) {
			out[["n_events"]] = as.numeric(min(sum(yy == 1), sum(yy == 0)))
		} else if (identical(rt, "survival")) {
			dead = safe(des_obj$get_effective_dead())
			if (!is.null(dead) && length(dead) == length(y)) out[["n_events"]] = as.numeric(sum(dead[has_y] == 1, na.rm = TRUE))
		}
	}
	is_matching = isTRUE(safe(des_obj$is_matching_design()))
	if (is_matching) {
		ids = safe(des_obj$get_matching_cluster_ids())
		if (!is.null(ids)) {
			sizes = tabulate(match(ids, unique(ids)))
			out[["n_pairs"]] = as.numeric(sum(sizes >= 2L))
			out[["n_pairs_plus_reservoir"]] = as.numeric(length(sizes))
		}
	}
	if (isTRUE(safe(des_obj$is_blocking_design()))) {
		ids = safe(des_obj$get_block_ids())
		if (!is.null(ids)) out[["n_strata"]] = as.numeric(length(unique(ids[!is.na(ids)])))
	}
	if (isTRUE(safe(des_obj$is_a_cluster_capable()))) {
		# No public accessor for the cluster column; read the design's own state.
		priv = safe(des_obj$.__enclos_env__$private)
		col = priv$cluster_col
		xraw = safe(des_obj$get_X_raw())
		if (!is.null(col) && !is.null(xraw) && col %in% names(xraw)) {
			cl = xraw[[col]]
			out[["n_clusters"]] = as.numeric(length(unique(cl[!is.na(cl)])))
		}
	}
	out
}

#' Effective n for one or more `n_eff` rules on a design.
#'
#' @param des_obj A design object.
#' @param rule Character vector of rules (`EDI_CONVERGENCE_N_EFF`).
#' @param counts Optional precomputed `edi_inference_validity_counts(des_obj)`.
#' @return Numeric vector, `NA` where the rule does not apply to the design.
#' @keywords internal
#' @noRd
edi_inference_validity_n_eff = function(des_obj, rule, counts = edi_inference_validity_counts(des_obj)) {
	unname(counts[as.character(rule)])
}

#' Registry design key of a design object: the class name, plus the
#' calibration study's `@prob_T=<p>` suffix for a design with unequal
#' allocation (so the unequal-allocation registry entry applies to every design that supports it).
#' @keywords internal
#' @noRd
edi_inference_validity_design_label = function(des_obj) {
	base = class(des_obj)[[1L]]
	p = tryCatch(des_obj$get_prob_T(), error = function(e) NULL)
	if (is.numeric(p) && length(p) == 1L && !is.na(p) && abs(p - 0.5) > 1e-12) {
		return(paste0(base, "@prob_T=", format(p, trim = TRUE)))
	}
	base
}

#' Renders a registry size order: `Inf` -> "exact", `0` -> "O(1)", `NA` ->
#' "unknown", otherwise "O(n_eff^-<order>)" with simple fractions (2/3) kept
#' as fractions.
#' @param size_order Numeric vector.
#' @return Character vector.
#' @keywords internal
#' @noRd
edi_inference_validity_render_order = function(size_order) {
	one = function(x) {
		if (is.na(x)) return("unknown")
		if (is.infinite(x)) return("exact")
		if (x == 0) return("O(1)")
		txt = NULL
		for (den in 1:6) {
			num = x * den
			if (abs(num - round(num)) < 1e-9) {
				num = as.integer(round(num))
				txt = if (den == 1L) as.character(num) else sprintf("%d/%d", num, den)
				break
			}
		}
		if (is.null(txt)) txt = format(signif(x, 3L))
		sprintf("O(n_eff^-%s)", txt)
	}
	vapply(as.numeric(size_order), one, character(1L))
}

#' The validity columns for triples on one design: `regime`, `n_eff` (rule and
#' value, e.g. "n_pairs = 25"), `size_order` (rendered) and `rate_basis` (the
#' registry basis of the size order). `class` and `procedure` are recycled to a
#' common length. A procedure that is `NA` or not in the registry (a failed or
#' custom row) yields `NA` in every column instead of an error.
#'
#' @param des_obj A design object.
#' @param class Inference class name(s).
#' @param procedure `run_all_inference()` sentinel label(s).
#' @return A data.frame with `length(class)` (recycled) rows and the four columns.
#' @keywords internal
#' @noRd
edi_inference_validity_columns = function(des_obj, class, procedure) {
	n = if (length(class) == 0L || length(procedure) == 0L) 0L else max(length(class), length(procedure))
	cls = as.character(rep_len(class, n)); proc = as.character(rep_len(procedure, n))
	out = data.frame(regime = rep(NA_character_, n), n_eff = rep(NA_character_, n),
		size_order = rep(NA_character_, n), rate_basis = rep(NA_character_, n), stringsAsFactors = FALSE)
	known = !is.na(proc) & proc %in% names(EDI_INFERENCE_PROCEDURE_REGIME)
	if (!any(known)) return(out)
	ex = inference_convergence_expectation(edi_inference_validity_design_label(des_obj), cls[known], proc[known])
	val = edi_inference_validity_n_eff(des_obj, ex$n_eff)
	out$regime[known] = ex$regime
	out$n_eff[known] = sprintf("%s = %s", ex$n_eff, ifelse(is.na(val), "NA", format(val, trim = TRUE)))
	out$size_order[known] = edi_inference_validity_render_order(ex$size_order)
	out$rate_basis[known] = ex$basis
	out
}
