# Generated "Small-sample behaviour" help-page section (v1.0.5 TODO-195).
#
# `rd_small_sample_section(class_name)` is called from a roxygen `@eval` tag in
# every concrete inference class's roxygen block. It renders the class's
# expected size / coverage-error orders from the convergence-rate registry
# (inference_procedure_regime.R) and the citations from REFERENCES.md, so the
# help pages keep no second copy of a rate, regime or reference. Not exported,
# not used at run time: it only executes while the Rd files are generated.

#' Short descriptions of the effective-n rules (`EDI_CONVERGENCE_N_EFF`).
#' @keywords internal
#' @noRd
RD_SS_N_EFF_LABEL = c(
	n = "subjects", n_pairs = "matched pairs", n_pairs_plus_reservoir = "pairs + reservoir",
	n_min_arm = "smaller arm", n_events = "events", n_nonzero = "nonzero counts",
	n_clusters = "clusters", n_strata = "strata"
)

#' What each non-regular regularity class means, in one sentence. A regular
#' parametric model needs none.
#' @keywords internal
#' @noRd
RD_SS_N_EFF_SENTENCE = c(
	n = "the number of subjects", n_pairs = "the number of matched pairs",
	n_pairs_plus_reservoir = "the number of matched pairs plus reservoir subjects",
	n_min_arm = "the size of the smaller arm", n_events = "the number of events",
	n_nonzero = "the number of nonzero counts", n_clusters = "the number of clusters",
	n_strata = "the number of strata"
)

#' @keywords internal
#' @noRd
RD_SS_REGULARITY_NOTE = c(
	boundary = "the maximum-likelihood estimate can sit on the boundary of the parameter space, where the usual chi-square and normal limits fail",
	variance_component = "a random-effect variance near zero is a non-standard limit that affects the standard tests",
	mixture = "the mixing probability can sit on the boundary and the information can be singular",
	nonparametric_rate = "the standard error needs a nonparametric (kernel sparsity) estimate, so the rate is slower than the parametric one",
	design_mismatch = "the variance formula ignores the design's covariate balancing, so the procedure is conservative by an amount that does not vanish with n (an upper-bound statement: it is zero when the balanced covariates are not prognostic)",
	other = "a non-standard limit or an estimated scale, so the regular-model rate is not established"
)

#' Reads REFERENCES.md and returns a named character vector (citation key ->
#' one-paragraph citation text, already converted to Rd). The file is only
#' present in a source checkout, so this returns `character(0)` when it cannot
#' be found and the section then lists bare keys.
#' @keywords internal
#' @noRd
rd_ss_references_md = function() {
	cands = c("EDI/REFERENCES.md", "REFERENCES.md", "R/EDI/REFERENCES.md",
		system.file("REFERENCES.md", package = "EDI"))
	path = Find(function(p) nzchar(p) && file.exists(p), cands)
	if (is.null(path)) return(character(0L))
	lines = readLines(path, warn = FALSE)
	starts = grep("^- \\*\\*\\[[A-Za-z0-9]+\\]\\*\\*", lines)
	out = character(length(starts))
	for (i in seq_along(starts)) {
		end = starts[i]
		while (end + 1L <= length(lines) && nzchar(trimws(lines[end + 1L])) && !grepl("^- \\*\\*\\[", lines[end + 1L])) end = end + 1L
		txt = paste(trimws(lines[starts[i]:end]), collapse = " ")
		names(out)[i] = sub("^- \\*\\*\\[([A-Za-z0-9]+)\\]\\*\\*.*$", "\\1", txt)
		txt = sub("^- \\*\\*\\[[A-Za-z0-9]+\\]\\*\\*\\s*", "", txt)
		# Keep the bibliographic text only: cut at the first em dash (the "Used by:" tail,
		# or Kallus's long annotation).
		txt = sub(paste0("\\s*", intToUtf8(8212L), ".*$"), "", txt)
		if (!grepl("[.)]$", txt)) txt = paste0(txt, ".")
		txt = gsub("%", "\\\\%", txt)
		txt = gsub("\\*([^*]+)\\*", "\\\\emph{\\1}", txt)
		out[i] = txt
	}
	stats::setNames(out, names(out))
}

#' @keywords internal
#' @noRd
rd_ss_split_keys = function(x) {
	x = x[!is.na(x)]
	if (!length(x)) return(character(0L))
	unique(unlist(strsplit(x, ",\\s*"), use.names = FALSE))
}

#' @keywords internal
#' @noRd
rd_ss_order_text = function(order, unknown = is.na(order)) {
	vapply(seq_along(order), function(i) {
		o = order[i]
		if (unknown[i]) return("unknown")
		if (is.infinite(o)) return("exact")
		if (o == 0) return("\\eqn{O(1)}{O(1)}")
		p = if (isTRUE(all.equal(o, 2 / 3))) "2/3" else format(o)
		sprintf("\\eqn{O(n_{eff}^{-%s})}{O(n_eff^-%s)}", p, p)
	}, character(1L))
}

#' @keywords internal
#' @noRd
rd_ss_basis_text = function(basis) {
	c(theory = "theory", literature = "literature", assumed_default = "assumed default",
		empirical = "empirical", unknown = "unknown")[basis]
}

#' @keywords internal
#' @noRd
rd_ss_keys_text = function(k) ifelse(is.na(k) | !nzchar(k), "-", paste0("[", gsub(", ", "], [", k), "]"))

#' @keywords internal
#' @noRd
rd_ss_design_text = function(d) {
	generic = d == "@prob_T"  # the registry key for any design with unequal allocation
	d = sub("@prob_T=", " (prob_T = ", d, fixed = TRUE)
	ifelse(generic, "any design with unequal allocation (\\code{prob_T} not 0.5)",
		paste0("\\code{", ifelse(grepl("(prob_T", d, fixed = TRUE), paste0(d, ")"), d), "}"))
}

#' Roxygen lines for the "Small-sample behaviour" section of one inference
#' class, for use as `@eval rd_small_sample_section("InferenceXxx")`.
#'
#' Rows are the class's capability-level procedures (the same applicability
#' rule the calibration planner uses), resolved on a balanced complete-
#' randomization design; designs for which the registry differs are listed
#' separately. Rates for which the registry has only the procedure's regular-
#' model default are labelled "assumed default"; classes with no known rate say
#' "unknown". Nothing is invented: every shown rate carries the registry's
#' citation keys, expanded from REFERENCES.md.
#'
#' @param class_name Name of a concrete, registered inference class.
#' @return Character vector of roxygen lines (no leading `#'`).
#' @keywords internal
#' @noRd
rd_small_sample_section = function(class_name) {
	stopifnot(is.character(class_name), length(class_name) == 1L)
	procs = names(EDI_INFERENCE_PROCEDURE_REGIME)
	procs = procs[vapply(procs, function(p) inference_class_has_method(class_name, p), logical(1L))]
	if (!length(procs)) stop("rd_small_sample_section: class '", class_name, "' supports no registered procedure", call. = FALSE)
	base_design = "DesignFixediBCRD"
	base = inference_convergence_expectation(base_design, class_name, procs)

	# Designs for which some resolved field differs from the balanced baseline.
	cls_hit = is.na(EDI_CONVERGENCE_OVERRIDES$class) | EDI_CONVERGENCE_OVERRIDES$class == class_name
	dkeys = unique(EDI_CONVERGENCE_OVERRIDES$design[cls_hit & !is.na(EDI_CONVERGENCE_OVERRIDES$design)])
	diffs = list()
	for (d in dkeys) {
		r = inference_convergence_expectation(d, class_name, procs)
		size_same = (is.na(r$size_order) & is.na(base$size_order)) |
			(!is.na(r$size_order) & !is.na(base$size_order) & r$size_order == base$size_order)
		changed = which(!(r$n_eff == base$n_eff & r$regularity == base$regularity & size_same))
		for (i in changed) {
			parts = character(0L)
			if (r$n_eff[i] != base$n_eff[i]) parts = c(parts, sprintf("the effective n is %s", RD_SS_N_EFF_SENTENCE[[r$n_eff[i]]]))
			if (!size_same[i]) {
				parts = c(parts, sprintf("the error order is %s (%s; %s)", rd_ss_order_text(r$size_order[i]),
					sub("_", " ", r$regularity[i]), rd_ss_keys_text(r$reference_key[i])))
			}
			diffs[[length(diffs) + 1L]] = data.frame(design = d, procedure = r$procedure[i],
				txt = paste(parts, collapse = "; "), key = r$reference_key[i], stringsAsFactors = FALSE)
		}
	}
	diffs = if (length(diffs)) do.call(rbind, diffs) else NULL

	keys = rd_ss_split_keys(base$reference_key)
	cell = function(x) paste(x, collapse = " \\tab ")
	rows = vapply(seq_len(NROW(base)), function(i) {
		cell(c(sprintf("\\code{%s}", base$procedure[i]),
			sub("_", " ", base$regime[i]),
			rd_ss_order_text(base$size_order[i], is.na(base$size_order[i])),
			RD_SS_N_EFF_LABEL[[base$n_eff[i]]],
			sub("_", " ", base$regularity[i]),
			rd_ss_basis_text(base$basis[i]),
			rd_ss_keys_text(base$reference_key[i])))
	}, character(1L))
	header = cell(sprintf("\\strong{%s}", c("Procedure", "Regime", "Error order", "Effective n", "Regularity", "Basis", "References")))

	out = c(
		"@section Small-sample behaviour:",
		"How fast the size (and coverage) error of each procedure is expected to vanish as the",
		"effective sample size \\eqn{n_{eff}}{n_eff} grows, from EDI's convergence-rate registry",
		"(\\code{inference_convergence_expectation()}). \\emph{Exact} procedures are valid at every",
		"n by construction; the others are asymptotic, so a small-sample excess is expected, and",
		"its constant is not given by an order. The table is the expectation for a balanced",
		"complete-randomization design; it is not a measured size. Reference keys are explained",
		"under References.",
		"",
		sprintf("\\tabular{lllllll}{%s \\cr", header),
		paste0(rows, c(rep(" \\cr", length(rows) - 1L), "}")),
		""
	)

	# Bias of the point estimate: stated from the asymptotic rows only (an exact-only class has none to describe).
	asy = base[base$regime == "asymptotic", , drop = FALSE]
	bias = unique(data.frame(o = asy$bias_order, b = asy$bias_basis, k = asy$bias_reference_key, stringsAsFactors = FALSE))
	if (NROW(bias) == 1L) {
		btxt = if (is.infinite(bias$o)) "The point estimate is unbiased under randomization"
			else sprintf("The point estimate's bias is of order \\eqn{O(n_{eff}^{-%s})}{O(n_eff^-%s)}", format(bias$o), format(bias$o))
		out = c(out, sprintf("%s (%s: %s).", btxt, rd_ss_basis_text(bias$b), rd_ss_keys_text(bias$k)), "")
	}

	if (any(base$basis == "assumed_default")) {
		out = c(out, "Rows with basis \\emph{assumed default}: the order shown is the procedure's rate in a",
			"regular parametric model, and the cited works establish it for that case only. EDI has not",
			"derived it for this class.", "")
	}
	if (any(base$basis == "unknown")) {
		out = c(out, "Rows with order \\emph{unknown}: no rate is known for this class and procedure, so none is",
			"claimed; the cited works describe the non-standard limit, not a rate. Expect a small-sample",
			"excess of unquantified size.", "")
	}
	reg = setdiff(unique(base$regularity), "regular")
	for (g in intersect(names(RD_SS_REGULARITY_NOTE), reg)) {
		out = c(out, sprintf("Regularity \\emph{%s}: %s.", sub("_", " ", g), RD_SS_REGULARITY_NOTE[[g]]), "")
	}
	if (any(base$procedure %in% c("lik_ratio_bartlett_approx", "lik_ratio_bartlett_exact"))) {
		out = c(out, "The procedure list is by declared capability; an object can still report a procedure",
			"(for example a Bartlett correction) as unavailable through \\code{get_supported_testing_types()}.", "")
	}

	if (!is.null(diffs)) {
		# One item per (change, procedure set); designs sharing both are listed together.
		per = split(diffs, paste(diffs$design, diffs$txt, sep = "\r"))
		cells = data.frame(
			design = vapply(per, function(g) g$design[1L], character(1L)),
			txt = vapply(per, function(g) g$txt[1L], character(1L)),
			procs = vapply(per, function(g) paste(g$procedure, collapse = ", "), character(1L)),
			key = vapply(per, function(g) g$key[1L], character(1L)), stringsAsFactors = FALSE)
		items = character(0L)
		for (s in unique(paste(cells$txt, cells$procs, sep = "\r"))) {
			g = cells[paste(cells$txt, cells$procs, sep = "\r") == s, , drop = FALSE]
			items = c(items, sprintf("\\item On %s, for %s: %s.",
				paste(rd_ss_design_text(g$design), collapse = ", "),
				paste0("\\code{", strsplit(g$procs[1L], ", ", fixed = TRUE)[[1L]], "}", collapse = ", "), g$txt[1L]))
			keys = union(keys, rd_ss_split_keys(g$key))
		}
		out = c(out, "Design-specific differences from the table:", "\\itemize{", items, "}", "")
	}

	if (NROW(bias) == 1L) keys = union(keys, rd_ss_split_keys(bias$k))
	md = rd_ss_references_md()
	refs = vapply(keys, function(k) {
		txt = unname(md[k])
		if (is.na(txt)) sprintf("[%s]", k) else sprintf("[%s] %s", k, txt)
	}, character(1L))
	c(out, "@references", unlist(lapply(unname(refs), function(r) c(r, "")), use.names = FALSE))
}
