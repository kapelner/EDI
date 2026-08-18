
#' Normalizes a completed `Design` object into the flat metadata shape
#' inference-class discovery (`InferenceSuite`, and any future `Design`-side
#' discovery method built on the same normalized-design-metadata helper --
#' see `fix_inference_hierarchy.md`'s "Discovery"/"Design-Side Discovery API"
#' sections) filters candidate classes against. Treats censoring as two
#' independent axes, matching the construction-time gate in
#' `Inference$initialize()` exactly: `any_censoring` (any censored subject at
#' all, right- or general-) and `has_general_censoring` (any subject with a
#' finite `y_R`, i.e. left- or interval-censored) are reported separately,
#' since a class can support one without the other.
#'
#' @keywords internal
#' @noRd
normalize_inference_design_metadata = function(des_obj) {
	list(
		response_type = des_obj$get_response_type(),
		is_kk = isTRUE(des_obj$is_a_kk_matching_capable()),
		is_blocking = isTRUE(des_obj$supports("blocking")),
		any_censoring = isTRUE(des_obj$any_censoring()),
		has_general_censoring = isTRUE(des_obj$has_general_censoring())
	)
}

#' Per-class compatibility metadata read from the inference class registry,
#' shaped for `is_inference_class_compatible_with_design_metadata()`. Kept as
#' a standalone function (not a private InferenceSuite method) so both
#' `InferenceSuite` and `Design$applicable_inference_class_names()` share
#' exactly one copy of this lookup.
#'
#' @keywords internal
#' @noRd
inference_class_compatibility_metadata = function(nm) {
	metadata = get_inference_class_metadata(nm)
	list(
		abstract = isTRUE(metadata$abstract),
		exported = isTRUE(metadata$exported),
		response_types = metadata$response_types %||% character(),
		requires_kk = grepl("KK", nm, fixed = TRUE),
		requires_blocking = isTRUE(metadata$requires_blocking_design),
		supports_general_censoring = isTRUE(metadata$supports_general_censoring)
	)
}

#' Whether inference class `nm` is compatible with normalized design metadata
#' `design_meta` (see `normalize_inference_design_metadata()`). A candidate is
#' excluded if it is abstract or not exported; if it declares no compatible
#' response types, or none match `design_meta$response_type`; if it requires
#' KK matching (name contains `"KK"`) but the design isn't KK-capable; if its
#' `requires_blocking_design` metadata is `TRUE` but the design doesn't
#' support blocking; or if the design has any left-/interval-censored
#' subjects (`has_general_censoring`) but the class's
#' `supports_general_censoring` metadata is `FALSE` -- the latter two mirror
#' `Inference$initialize()`'s own construction-time gate exactly. Ordinary
#' right-censoring alone (`any_censoring` without `has_general_censoring`)
#' never excludes a class.
#'
#' @keywords internal
#' @noRd
is_inference_class_compatible_with_design_metadata = function(nm, design_meta) {
	class_meta = inference_class_compatibility_metadata(nm)
	if (isTRUE(class_meta$abstract) || !isTRUE(class_meta$exported)) return(FALSE)
	if (length(class_meta$response_types) == 0L) return(FALSE)
	if (!(design_meta$response_type %in% class_meta$response_types)) {
		return(FALSE)
	}
	if (isTRUE(class_meta$requires_kk) && !isTRUE(design_meta$is_kk)) return(FALSE)
	if (isTRUE(class_meta$requires_blocking) && !isTRUE(design_meta$is_blocking)) return(FALSE)
	if (isTRUE(design_meta$has_general_censoring) && !isTRUE(class_meta$supports_general_censoring)) {
		return(FALSE)
	}
	TRUE
}

#' Registered-but-unavailable packages for inference class `nm` (character(0)
#' if none or all installed).
#'
#' @keywords internal
#' @noRd
missing_required_packages_for_inference_class = function(nm) {
	required = get_inference_class_metadata(nm)$required_packages %||% character()
	if (length(required) == 0L) return(character())
	Filter(function(pkg) !requireNamespace(pkg, quietly = TRUE), required)
}

#' Splits every exported, non-abstract, design-compatible `Inference` class
#' for `des_obj` into an `applicable` sorted character vector and an
#' `unavailable_due_to_missing_packages` named list (class name -> missing
#' package names), per the `Discovery` rules in `fix_inference_hierarchy.md`.
#' The single implementation backing both `InferenceSuite` discovery and
#' `Design$applicable_inference_class_names()`/
#' `Design$unavailable_inference_classes_due_to_missing_packages()`.
#'
#' @keywords internal
#' @noRd
discover_applicable_inference_classes = function(des_obj) {
	registry = inference_class_registry_as_list()
	design_meta = normalize_inference_design_metadata(des_obj)
	candidates = names(Filter(function(metadata) {
		isTRUE(metadata$exported) && !isTRUE(metadata$abstract)
	}, registry))
	design_compatible = Filter(function(nm) {
		is_inference_class_compatible_with_design_metadata(nm, design_meta)
	}, candidates)
	unavailable = list()
	applicable = character()
	for (nm in design_compatible) {
		missing_pkgs = missing_required_packages_for_inference_class(nm)
		if (length(missing_pkgs) > 0L) {
			unavailable[[nm]] = missing_pkgs
		} else {
			applicable = c(applicable, nm)
		}
	}
	list(
		applicable = sort(applicable),
		unavailable_due_to_missing_packages = unavailable[sort(names(unavailable))]
	)
}

#' Backs `Design$applicable_inference_class_names()`.
#'
#' @keywords internal
#' @noRd
applicable_inference_class_names_for_design = function(des_obj) {
	discover_applicable_inference_classes(des_obj)$applicable
}

#' Backs `Design$unavailable_inference_classes_due_to_missing_packages()`.
#'
#' @keywords internal
#' @noRd
unavailable_inference_classes_due_to_missing_packages_for_design = function(des_obj) {
	discover_applicable_inference_classes(des_obj)$unavailable_due_to_missing_packages
}

#' Priority-ordered CI/p-value method dispatch tables backing
#' `InferenceSuite$run_all_inference()`'s "primary method" selection. There is
#' no generic `compute_ci()`/`compute_pval()` on `Inference` -- concrete
#' classes expose capability-gated, differently-named methods -- so each
#' table entry pairs a capability (checked via `obj$capabilities()`) with the
#' method it gates. See `inference_suite_inspect.md`'s "Method Selection
#' Policy" section for the full rationale.
#'
#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY = list(
	list(capability = "wald", method = "compute_asymp_confidence_interval", label = "wald"),
	list(capability = "exact_test", method = "compute_exact_confidence_interval", label = "exact"),
	list(capability = "randomization_ci", method = "compute_rand_confidence_interval", label = "randomization"),
	list(capability = "nonparametric_bootstrap", method = "compute_bootstrap_confidence_interval", label = "bootstrap")
)

#' @keywords internal
#' @noRd
EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY = list(
	list(capability = "wald", method = "compute_asymp_two_sided_pval", label = "wald"),
	list(capability = "exact_test", method = "compute_exact_two_sided_pval_for_treatment_effect", label = "exact"),
	list(capability = "randomization_test", method = "compute_rand_two_sided_pval", label = "randomization"),
	list(capability = "nonparametric_bootstrap", method = "compute_bootstrap_two_sided_pval", label = "bootstrap")
)

#' Selects and calls the first available CI method for `inf_obj` per
#' `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY`. Returns
#' `list(lower, upper, method)` with `NA`s if no capability in the table
#' applies, or every applicable call errors/returns a non-finite interval.
#'
#' @keywords internal
#' @noRd
run_all_inference_select_ci = function(inf_obj, alpha) {
	caps = inf_obj$capabilities()
	for (entry in EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY) {
		if (entry$capability %in% caps) {
			ci = tryCatch(inf_obj[[entry$method]](alpha = alpha), error = function(e) NULL)
			if (!is.null(ci) && length(ci) == 2L && all(is.finite(ci))) {
				return(list(lower = ci[[1L]], upper = ci[[2L]], method = entry$label))
			}
		}
	}
	list(lower = NA_real_, upper = NA_real_, method = NA_character_)
}

#' Selects and calls the first available p-value method for `inf_obj` per
#' `EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY`. Returns `list(pval, method)`
#' with `NA`s if no capability in the table applies, or every applicable call
#' errors/returns a non-finite p-value.
#'
#' @keywords internal
#' @noRd
run_all_inference_select_pval = function(inf_obj) {
	caps = inf_obj$capabilities()
	for (entry in EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY) {
		if (entry$capability %in% caps) {
			pv = tryCatch(inf_obj[[entry$method]](delta = 0), error = function(e) NULL)
			if (!is.null(pv) && length(pv) == 1L && is.finite(pv)) {
				return(list(pval = pv, method = entry$label))
			}
		}
	}
	list(pval = NA_real_, method = NA_character_)
}

#' Best-effort estimand label for `inf_obj`: only a handful of classes
#' (currently the incidence g-computation family) declare a private
#' `get_estimand_type()`; every other class reports `NA_character_` until a
#' package-wide estimand registry exists (out of scope for this feature --
#' see `expanded_estimate_report.md`/`marginal_estimand_report.md`).
#'
#' @keywords internal
#' @noRd
run_all_inference_estimand = function(inf_obj) {
	priv = inf_obj$.__enclos_env__$private
	if (is.function(priv$get_estimand_type)) {
		tryCatch(as.character(priv$get_estimand_type()), error = function(e) NA_character_)
	} else {
		NA_character_
	}
}

#' Constructs, fits, and summarizes one inference class for
#' `InferenceSuite$run_all_inference()`. Never throws -- construction/fit
#' failures are caught and turned into `status = "error"`/`"nonestimable"`/
#' `"timeout"` rows instead of aborting the whole report (see
#' `inference_suite_inspect.md`'s "Per-Class Failure Isolation" section).
#' The `diagnostics` sub-list is v1.0.0-scoped to \code{NA} placeholders --
#' there is no generic native-diagnostics accessor on \code{Inference} yet
#' (that is \code{public_diagnostics_api_spec.md}'s TODO-9..12); it is wired
#' up in v1.1.0 per that plan's TODO-19.
#'
#' `max_secs_per_class` (\code{NULL} = no limit) is enforced via
#' \code{setTimeLimit(elapsed = ...)}, reset via \code{on.exit()} so the
#' limit never leaks past this one class's fit. \strong{Known limitation}
#' (documented per \code{inference_suite_inspect.md}'s TODO-12): R's time
#' limits are checked at R-level interrupt points and are not guaranteed to
#' interrupt a single long-running native (C/C++/BLAS) call with no
#' intervening R-level check: this reliably cuts off slow *R-level* work
#' (e.g. many bootstrap/randomization replicates, each its own R-level
#' call) but may not interrupt one very slow single native fit.
#'
#' @keywords internal
#' @noRd
run_all_inference_one_class = function(cls_name, des_obj, params, alpha, design_family, response_type, max_secs_per_class = NULL) {
	t0 = Sys.time()
	row = list(
		inference_class = cls_name,
		response_type   = response_type,
		design_family   = design_family,
		likelihood_tier = get_inference_class_metadata(cls_name)$likelihood_tier %||% NA_character_,
		estimate        = NA_real_,
		se              = NA_real_,
		ci_lower        = NA_real_,
		ci_upper        = NA_real_,
		ci_method       = NA_character_,
		pval            = NA_real_,
		pval_method     = NA_character_,
		estimand        = NA_character_,
		fit_secs        = NA_real_,
		warnings        = NA_character_,
		status          = "error",
		message         = NA_character_,
		diagnostics     = list(
			converged = NA, hit_iteration_cap = NA,
			iterations = NA_integer_, optimizer = NA_character_
		)
	)
	collected_warnings = character()
	outcome = withCallingHandlers(
		tryCatch({
			if (!is.null(max_secs_per_class)) {
				setTimeLimit(elapsed = max_secs_per_class, transient = TRUE)
				on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
			}
			cls = get(cls_name, envir = getNamespace("EDI"))
			inf_obj = do.call(cls$new, c(list(des_obj = des_obj), params))
			estimate = inf_obj$compute_estimate()
			se = tryCatch({
				priv = inf_obj$.__enclos_env__$private
				if (is.function(priv$get_standard_error)) as.numeric(priv$get_standard_error()) else NA_real_
			}, error = function(e) NA_real_)
			ci = run_all_inference_select_ci(inf_obj, alpha)
			pv = run_all_inference_select_pval(inf_obj)
			estimand = run_all_inference_estimand(inf_obj)
			if (isTRUE(inf_obj$is_nonestimable("any"))) {
				list(
					status = "nonestimable",
					message = inf_obj$get_nonestimable_reason() %||% NA_character_
				)
			} else {
				list(
					status = "ok", estimate = as.numeric(estimate), se = se,
					ci_lower = ci$lower, ci_upper = ci$upper, ci_method = ci$method,
					pval = pv$pval, pval_method = pv$method, estimand = estimand
				)
			}
		}, error = function(e) {
			if (!is.null(max_secs_per_class) && grepl("time limit", conditionMessage(e), fixed = TRUE)) {
				list(
					status = "timeout",
					message = sprintf("exceeded max_secs_per_class = %s seconds", max_secs_per_class)
				)
			} else {
				list(status = "error", message = conditionMessage(e))
			}
		}),
		warning = function(w) {
			collected_warnings <<- c(collected_warnings, conditionMessage(w))
			invokeRestart("muffleWarning")
		}
	)
	row = utils::modifyList(row, outcome)
	row$warnings  = if (length(collected_warnings) > 0L) paste(collected_warnings, collapse = "; ") else NA_character_
	row$fit_secs  = as.numeric(difftime(Sys.time(), t0, units = "secs"))
	row
}

#' Formats a duration in seconds as `"Xd Xh Xm Xs"` (only nonzero leading
#' units shown), reusing `simulations_framework.R`'s `.fmt_secs()`
#' convention for `run_all_inference()`'s screen progress bar.
#'
#' @keywords internal
#' @noRd
run_all_inference_fmt_secs = function(secs) {
	secs = max(0, secs)
	d = floor(secs / 86400); secs = secs %% 86400
	h = floor(secs / 3600);  secs = secs %% 3600
	m = floor(secs / 60);    s = round(secs %% 60)
	parts = character()
	if (d > 0) parts = c(parts, paste0(d, "d"))
	if (h > 0) parts = c(parts, paste0(h, "h"))
	if (m > 0) parts = c(parts, paste0(m, "m"))
	parts = c(parts, paste0(s, "s"))
	paste(parts, collapse = " ")
}

#' Prints one `run_all_inference()` result row to the console (shared by both
#' the sequential and fork-cluster-parallel code paths in
#' `InferenceSuite$run_all_inference()`, so the two produce identically
#' formatted rows).
#'
#' @keywords internal
#' @noRd
run_all_inference_print_row = function(i, n_total, r) {
	cat(sprintf(
		"[%d/%d] %-40s status=%-12s estimate=%-12s pval=%-10s (%s)\n",
		i, n_total, r$inference_class, r$status,
		if (is.na(r$estimate)) "NA" else formatC(r$estimate, digits = 4, format = "g"),
		if (is.na(r$pval)) "NA" else formatC(r$pval, digits = 4, format = "g"),
		r$pval_method %||% "NA"
	))
}

#' Renders one `run_all_inference()` progress-bar line: a bracketed
#' percent-fill bar plus an ETA estimated from the mean per-class elapsed
#' time so far, following `simulations_framework.R`'s
#' `.draw_simulation_progress_bars()` bar-rendering/ETA-estimation pattern
#' (`SimulationFramework`'s own screen progress bar). Unlike that
#' implementation, this one prints a fresh line per update rather than an
#' in-place `\r` redraw: `run_all_inference()` only updates once per
#' *completed class* (not many times per second), so each bar line sits
#' directly under that class's just-printed result row, and always emitting
#' a trailing newline avoids interleaving hazards between the row output
#' and the bar when a caller redirects/captures stdout.
#'
#' @keywords internal
#' @noRd
run_all_inference_progress_bar_line = function(n_done, n_total, elapsed_secs_so_far) {
	width = getOption("width", 80L)
	if (is.null(width) || width < 40L) width = 80L
	prop = if (n_total > 0L) n_done / n_total else 1
	eta_str = if (n_done >= n_total) {
		"Status: Completed."
	} else if (n_done > 0L) {
		mean_secs = mean(elapsed_secs_so_far[seq_len(n_done)])
		paste0("Time Left: ", run_all_inference_fmt_secs(mean_secs * (n_total - n_done)))
	} else {
		"Status: Estimating..."
	}
	label = sprintf("Classes %d/%d", n_done, n_total)
	label_width = 14L
	padded_label = sprintf("%-*s", label_width, substr(label, 1, label_width))
	bar_width = max(10L, width - label_width - nchar(eta_str) - 10L)
	pct_str = sprintf(" %d%% ", floor(prop * 100))
	fill = max(0L, min(bar_width, floor(prop * bar_width)))
	full_bar = paste0(strrep("=", fill), strrep(" ", bar_width - fill))
	n_pct = nchar(pct_str)
	if (bar_width >= n_pct) {
		start_pos = (bar_width - n_pct) %/% 2 + 1
		substr(full_bar, start_pos, start_pos + n_pct - 1) = pct_str
	}
	sprintf("%s[%s] %s", padded_label, full_bar, eta_str)
}

#' Formats the `unavailable_due_to_missing_packages` footer text shared by
#' both `screen` and `html` output (see `inference_suite_inspect.md`'s
#' Output Modes section) -- one line per otherwise-applicable class listing
#' its missing packages, or a one-line "none" message if empty.
#'
#' @keywords internal
#' @noRd
run_all_inference_unavailable_footer_lines = function(unavailable_due_to_missing_packages) {
	if (length(unavailable_due_to_missing_packages) == 0L) {
		return("(none -- every design-compatible class has its required packages installed)")
	}
	nm = names(unavailable_due_to_missing_packages)
	vapply(seq_along(unavailable_due_to_missing_packages), function(i) {
		sprintf("%s: requires %s", nm[[i]], paste(unavailable_due_to_missing_packages[[i]], collapse = ", "))
	}, character(1L))
}

#' Renders a self-contained (no JS, no external assets) HTML report for
#' `run_all_inference()`'s `html = TRUE` mode: the results table (via
#' `knitr::kable()`, an already-Suggested dependency -- see
#' `inference_suite_inspect.md`'s Implementation Notes), the design
#' metadata, the unavailable-classes footer, and -- when `out$plots`
#' contains built ggplot objects -- both visualizations embedded as
#' base64-inlined PNGs (`run_all_inference_plot_to_base64_png()`), so the
#' page stays offline-renderable. Silently omits the Visualizations section
#' if `ggplot2`/`jsonlite` weren't available to build/encode them (already
#' warned about upstream in `run_all_inference_build_plots()`), rather than
#' erroring the whole HTML render over an optional add-on.
#'
#' @keywords internal
#' @noRd
run_all_inference_render_html = function(out) {
	if (!requireNamespace("knitr", quietly = TRUE)) {
		stop("InferenceSuite$run_all_inference: html = TRUE requires the 'knitr' package.")
	}
	table_html = knitr::kable(out$results_table, format = "html", table.attr = "class=\"results\"", row.names = FALSE)
	footer_lines = run_all_inference_unavailable_footer_lines(out$unavailable_due_to_missing_packages)
	footer_html = paste0("<li>", vapply(footer_lines, htmltools_escape_or_identity, character(1L)), "</li>", collapse = "\n")
	n_ci_rows = sum(out$results_table$status == "ok" &
		is.finite(out$results_table$ci_lower) & is.finite(out$results_table$ci_upper))
	b64_estimates = run_all_inference_plot_to_base64_png(out$plots$estimates)
	b64_ci_forest = run_all_inference_plot_to_base64_png(
		out$plots$ci_forest, height = max(6, 0.5 * n_ci_rows + 1.5)
	)
	images_html = paste0(c(
		if (!is.null(b64_estimates)) sprintf('<h2>Estimates</h2>\n<img src="data:image/png;base64,%s" alt="Estimate number line" style="max-width:100%%;">', b64_estimates),
		if (!is.null(b64_ci_forest)) sprintf('<h2>Confidence intervals</h2>\n<img src="data:image/png;base64,%s" alt="CI forest plot" style="max-width:100%%;">', b64_ci_forest)
	), collapse = "\n")
	design = out$design
	sprintf('<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>InferenceSuite results -- %s</title>
<style>
body { font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; margin: 2rem; color: #1a1a1a; }
h1 { font-size: 1.3rem; }
h2 { font-size: 1.05rem; margin-top: 2rem; }
table.results { border-collapse: collapse; width: 100%%; font-size: 0.85rem; }
table.results th, table.results td { border: 1px solid #ccc; padding: 4px 8px; text-align: left; white-space: nowrap; }
table.results th { background: #f0f0f0; }
tr:nth-child(even) { background: #fafafa; }
.meta { color: #555; font-size: 0.9rem; }
.status-error { color: #b00020; }
.status-nonestimable { color: #a06800; }
</style>
</head>
<body>
<h1>InferenceSuite$run_all_inference() results</h1>
<p class="meta">
Design: %s (%s, %s)&nbsp;&middot;&nbsp; n = %s&nbsp;&middot;&nbsp;
alpha = %s&nbsp;&middot;&nbsp; generated %s&nbsp;&middot;&nbsp;
total time %.2fs&nbsp;&middot;&nbsp; EDI %s
</p>
%s
%s
<h2>Classes unavailable due to missing packages</h2>
<ul>
%s
</ul>
</body>
</html>
', out$timestamp, design$design_class, design$response_type, design$design_family, design$n,
		out$alpha, out$timestamp, out$total_secs, out$edi_version, table_html, images_html, footer_html)
}

#' Escapes `&`, `<`, `>` for embedding free text into the HTML report
#' without pulling in an `htmltools`/`xml2` dependency for one call site.
#'
#' @keywords internal
#' @noRd
htmltools_escape_or_identity = function(x) {
	x = gsub("&", "&amp;", x, fixed = TRUE)
	x = gsub("<", "&lt;", x, fixed = TRUE)
	x = gsub(">", "&gt;", x, fixed = TRUE)
	x
}

#' Estimate-number-line visualization for `run_all_inference()`'s
#' `plots`/`pdf`/`html` output (see `inference_suite_inspect.md`'s
#' Visualizations section): every `status == "ok"` class's point estimate on
#' one shared axis, its class name and CI/p-value method labeled above the
#' dot at 45 degrees, and a box-and-whisker summary of the estimate values
#' underneath, faceted by `estimand` (`"estimand unspecified"` for the
#' majority of classes -- only a handful declare a private
#' `get_estimand_type()`, see `run_all_inference_estimand()`) so estimates on
#' different scales never share an axis. Returns `NULL` if there is nothing
#' plottable (no `status == "ok"` rows with a finite estimate). Label
#' collisions are not auto-resolved in this first pass (no `ggrepel`
#' dependency added) -- a known limitation for designs with many
#' tightly-clustered estimates, noted in the plan doc.
#'
#' @keywords internal
#' @noRd
run_all_inference_plot_estimates = function(results_table) {
	df = results_table[
		results_table$status == "ok" & is.finite(results_table$estimate),
		, drop = FALSE
	]
	if (nrow(df) == 0L) return(NULL)
	df$estimand_facet = ifelse(is.na(df$estimand), "estimand unspecified", df$estimand)
	df$method_label = sprintf(
		"%s (%s)", df$inference_class,
		ifelse(!is.na(df$ci_method), df$ci_method, ifelse(!is.na(df$pval_method), df$pval_method, "NA"))
	)
	df$y_dot   = 1
	df$y_label = 1.15
	ggplot2::ggplot(df, ggplot2::aes(x = estimate)) +
		ggplot2::geom_boxplot(
			ggplot2::aes(y = 0), orientation = "y", width = 0.6, outlier.shape = NA
		) +
		ggplot2::geom_point(ggplot2::aes(y = y_dot), size = 2) +
		ggplot2::geom_text(
			ggplot2::aes(y = y_label, label = method_label),
			angle = 45, hjust = 0, vjust = 0, size = 3
		) +
		ggplot2::facet_wrap(~estimand_facet, scales = "free_x") +
		ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.06, 0.25))) +
		ggplot2::scale_y_continuous(limits = c(-1, 4.5), breaks = NULL) +
		ggplot2::coord_cartesian(clip = "off") +
		ggplot2::labs(
			x = "Estimate", y = NULL,
			title = "Point estimates across applicable inference classes",
			subtitle = "Box-and-whisker below the number line summarizes cross-estimator spread"
		) +
		ggplot2::theme_minimal() +
		ggplot2::theme(
			panel.grid.major.y = ggplot2::element_blank(),
			panel.grid.minor.y = ggplot2::element_blank(),
			plot.margin = ggplot2::margin(t = 5, r = 20, b = 5, l = 5, unit = "pt")
		)
}

#' Annotated CI forest plot for `run_all_inference()`'s `plots`/`pdf`/`html`
#' output -- the merged former p-value/CI plots (user decision, 2026-08-17;
#' see `inference_suite_inspect.md`'s Visualizations section): every
#' `status == "ok"` class with a finite CI, one horizontal segment each,
#' p-value printed left of the segment, CI width printed right of it, class
#' name and CI/p-value method printed underneath, segment color keyed to
#' significance at `alpha`, and a reference line at the null value. Faceted
#' by `estimand` like `run_all_inference_plot_estimates()`, for the same
#' reason (CI widths aren't comparable across scales). **Known limitation:**
#' the null-value reference line is always drawn at zero -- ratio-scale
#' nulls (e.g. 1, or zero on a log scale) would need a per-class scale
#' declaration that does not exist package-wide yet (same gap as
#' `estimand`). Returns `NULL` if there is nothing plottable (no
#' `status == "ok"` row has a finite CI).
#'
#' @keywords internal
#' @noRd
run_all_inference_plot_ci_forest = function(results_table, alpha) {
	df = results_table[
		results_table$status == "ok" &
			is.finite(results_table$ci_lower) & is.finite(results_table$ci_upper),
		, drop = FALSE
	]
	if (nrow(df) == 0L) return(NULL)
	df$estimand_facet = ifelse(is.na(df$estimand), "estimand unspecified", df$estimand)
	df = df[order(df$estimand_facet, df$estimate), , drop = FALSE]
	df$y = seq_len(nrow(df))
	df$significant = !is.na(df$pval) & df$pval < alpha
	df$pval_label = ifelse(
		is.na(df$pval), "p=NA",
		ifelse(df$pval < 1e-4, sprintf("p=%.2e", df$pval), sprintf("p=%.4f", df$pval))
	)
	df$width_label  = sprintf("width=%.3g", df$ci_upper - df$ci_lower)
	df$method_label = sprintf(
		"%s (%s / %s)", df$inference_class,
		df$ci_method %||% "NA", df$pval_method %||% "NA"
	)
	n_rows = nrow(df)
	ggplot2::ggplot(df, ggplot2::aes(y = y)) +
		ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
		ggplot2::geom_segment(
			ggplot2::aes(x = ci_lower, xend = ci_upper, yend = y, color = significant),
			linewidth = 1
		) +
		ggplot2::geom_point(ggplot2::aes(x = estimate, color = significant), size = 2) +
		ggplot2::geom_text(ggplot2::aes(x = ci_lower, label = pval_label), hjust = 1.15, size = 3) +
		ggplot2::geom_text(ggplot2::aes(x = ci_upper, label = width_label), hjust = -0.15, size = 3) +
		ggplot2::geom_text(
			ggplot2::aes(x = estimate, label = method_label),
			vjust = 2.3, size = 2.7, lineheight = 0.85
		) +
		ggplot2::scale_color_manual(
			values = c(`TRUE` = "#1a7a3c", `FALSE` = "#888888"), guide = "none"
		) +
		ggplot2::facet_wrap(~estimand_facet, scales = "free") +
		ggplot2::scale_y_continuous(breaks = NULL, expand = ggplot2::expansion(mult = 0.15)) +
		ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.25)) +
		ggplot2::labs(
			x = "Estimate & confidence interval", y = NULL,
			title = sprintf("%g%% confidence intervals", 100 * (1 - alpha)),
			subtitle = sprintf("Green = significant at alpha = %g; p-value left of interval, width right of it", alpha)
		) +
		ggplot2::theme_minimal() +
		ggplot2::theme(
			panel.grid.major.y = ggplot2::element_blank(),
			panel.grid.minor.y = ggplot2::element_blank()
		)
}

#' Builds both `run_all_inference()` visualizations, or `list(estimates =
#' NULL, ci_forest = NULL)` with a `warning()` (not an error -- per-feature
#' decision) if the optional `ggplot2` dependency is not installed.
#'
#' @keywords internal
#' @noRd
run_all_inference_build_plots = function(results_table, alpha) {
	if (!requireNamespace("ggplot2", quietly = TRUE)) {
		warning(
			"InferenceSuite$run_all_inference: the 'ggplot2' package is not installed -- ",
			"skipping plots (estimate number line / CI forest). Install 'ggplot2' to enable them.",
			call. = FALSE
		)
		return(list(estimates = NULL, ci_forest = NULL))
	}
	list(
		estimates = run_all_inference_plot_estimates(results_table),
		ci_forest = run_all_inference_plot_ci_forest(results_table, alpha)
	)
}

#' Saves both `run_all_inference()` plots to one timestamped multi-page PDF
#' (two pages, one per plot; skips a `NULL` plot). Both pages share one page
#' height, scaled to the CI-forest plot's row count, so many applicable
#' classes don't get compressed onto a fixed-size page (a single `pdf()`
#' device cannot vary page size page-to-page without reopening the file,
#' which would truncate pages already written -- sizing both pages to the
#' taller plot's requirement avoids that entirely).
#'
#' @keywords internal
#' @noRd
run_all_inference_save_plots_pdf = function(plots, path, n_ci_rows) {
	height = max(6, 0.5 * n_ci_rows + 1.5)
	grDevices::pdf(path, width = 8, height = height, onefile = TRUE)
	on.exit(grDevices::dev.off(), add = TRUE)
	if (!is.null(plots$estimates)) print(plots$estimates)
	if (!is.null(plots$ci_forest)) print(plots$ci_forest)
}

#' Base64-PNG-encodes one ggplot object for inline embedding into the
#' self-contained HTML report (`run_all_inference_render_html()`) -- keeps
#' the HTML offline-renderable per the no-external-assets rule. Returns
#' `NULL` (not an error) if `plot` is `NULL` or `jsonlite` (used for
#' base64 encoding) is not installed.
#'
#' @keywords internal
#' @noRd
run_all_inference_plot_to_base64_png = function(plot, width = 8, height = 6) {
	if (is.null(plot) || !requireNamespace("jsonlite", quietly = TRUE)) return(NULL)
	tmp = tempfile(fileext = ".png")
	on.exit(unlink(tmp), add = TRUE)
	ggplot2::ggsave(tmp, plot = plot, width = width, height = height, dpi = 110, bg = "white")
	jsonlite::base64_enc(readBin(tmp, "raw", file.info(tmp)$size))
}


#' Inference Suite: Discover and Bundle Every Applicable Inference Class for a Design
#'
#' A lightweight coordinator (not itself an \code{Inference} subclass, and not
#' part of the \code{Inference} R6 hierarchy) that pairs a single completed
#' \code{\link[EDI:Design]{Design}} object with the full set of concrete
#' \code{Inference} classes compatible with it. On construction, the suite
#' consults package-level inference metadata to discover every exported,
#' non-abstract \code{Inference} subclass whose declared response-type,
#' matched-design (KK), blocking, and censoring requirements are all satisfied
#' by \code{des_obj}, storing the resulting sorted class-name vector in
#' \code{applicable_design_classes}. Because discovery is driven by metadata
#' lookups rather than by actually attempting to construct each candidate
#' class, the applicable list automatically stays current as new inference
#' classes are registered elsewhere in the package, without this class needing
#' any changes, and without risking side effects (e.g. an optional-package
#' load failure inside some class's constructor) from a doomed construction
#' attempt.
#'
#' @details \strong{Compatibility rules} (see
#'   \code{is_inference_class_compatible_with_design_metadata()}, also used by
#'   \code{\link[EDI:Design]{Design}}'s own
#'   \code{applicable_inference_class_names()}): a candidate class is
#'   excluded if it is abstract or not exported; if it declares no compatible
#'   response types, or none match \code{des_obj}'s response type; if its name
#'   contains \code{"KK"} (a matched-design-only class) but \code{des_obj} does
#'   not support KK matching; if the class's \code{requires_blocking_design()}
#'   is \code{TRUE} (currently only \code{InferenceIncidExtendedRobins} --
#'   \code{InferenceIncidCMH} works on both blocking and non-blocking designs
#'   via different standard-error estimators, so it is \strong{not} excluded)
#'   but \code{des_obj} does not support blocking; or if \code{des_obj} has any
#'   left-/interval-censored subjects (a finite \code{y_R}) but the class's
#'   \code{supports_interval_or_left_censored_data()} is \code{FALSE} --
#'   both of the latter two mirror \code{Inference$initialize()}'s own
#'   construction-time gate exactly, via each class's registered
#'   \code{requires_blocking_design}/\code{supports_general_censoring}
#'   metadata (see \code{infer_inference_requires_blocking_design()}/
#'   \code{infer_inference_supports_general_censoring()} in
#'   \code{inference_class_registry.R}). Ordinary right-censoring alone never
#'   excludes a class. The KK-name-pattern rule is still hardcoded in this
#'   class rather than looked up from a central registry.
#'
#'   A class that is design-compatible but whose registered
#'   \code{required_packages} are not all installed is excluded from
#'   \code{applicable_design_classes} and reported separately, by class name,
#'   in \code{unavailable_due_to_missing_packages} -- so callers can tell "not
#'   applicable to this design" apart from "applicable, but an optional
#'   dependency isn't installed" (see the \code{Discovery} section of
#'   \code{fix_inference_hierarchy.md}). Package availability is never a
#'   reason a class is treated as design-incompatible.
#'
#'   Construction itself does not compute any estimates, p-values, or
#'   confidence intervals -- it only discovers and validates which inference
#'   classes are applicable and does not eagerly construct any of them. This
#'   class's \code{run_all_inference()} method does that: it constructs and
#'   fits every applicable class and returns a uniform
#'   comparison across them (see that method's own documentation for the
#'   output schema, the CI/p-value method selection policy, and the
#'   \code{screen}/\code{html}/\code{plots}/\code{pdf}/
#'   \code{save_results_as_JSON} output options). \code{lock_objects = FALSE}
#'   allows ad hoc fields to be attached to an instance after construction.
#'
#'   \strong{Every row this class discovers and fits is a test about the
#'   same outcome variable, by construction.} \code{response_type} is a
#'   required, immutable constructor argument on \code{\link[EDI:Design]{Design}}
#'   (read-only thereafter via \code{get_response_type()}), and this class
#'   discovers every candidate in \code{applicable_design_classes} from one
#'   attached \code{Design} object's one \code{response_type} -- there is no
#'   code path here that spans two response types in a single instance. This
#'   matters beyond bookkeeping: a planned comparison-across-classes feature
#'   (a single combined-evidence p-value summarizing every row, via a
#'   dependence-robust combination test) relies on every combined class
#'   sharing one sharp null of "no treatment effect on this outcome" --
#'   which only holds when every test concerns the same outcome variable
#'   (combining, say, a survival model's p-value with an unrelated
#'   continuous-outcome model's p-value would not be valid, since a real
#'   effect on one with none on the other is entirely plausible). That
#'   precondition is guaranteed here structurally, not by caller discipline.
#' @export
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 20, response_type = "continuous")
#' for (i in 1:20) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rnorm(20))
#'
#' suite = InferenceSuite$new(seq_des)
#' suite$applicable_design_classes
#'
#' # Fit and compare every applicable class:
#' results = suite$run_all_inference(screen = TRUE)
#' results$results_table
#' }
InferenceSuite = R6::R6Class("InferenceSuite",
	lock_objects = FALSE,
	public = list(
		#' @field applicable_design_classes Character vector of applicable inference
		#'   class names derived during initialization.
		applicable_design_classes = NULL,
		#' @field unavailable_due_to_missing_packages A named list, one entry per
		#'   otherwise-design-compatible class whose registered \code{required_packages}
		#'   are not all installed: names are class names, values are the character
		#'   vector of missing package names. These classes are excluded from
		#'   \code{applicable_design_classes} but are reported here separately from
		#'   plain design/response-type incompatibility (see the class-level docs'
		#'   "Discovery" rules), so callers can distinguish "not applicable to this
		#'   design" from "applicable, but an optional dependency isn't installed."
		#'   Empty named list if every design-compatible class has all required
		#'   packages available.
		unavailable_due_to_missing_packages = NULL,
		#' @description Discover every \code{Inference} class applicable to \code{des_obj}
		#'   (see the class-level documentation for the compatibility rules) and validate
		#'   any per-class constructor overrides in \code{inference_params}, storing
		#'   \code{applicable_design_classes} for later use. This constructor does
		#'   \strong{not} instantiate any \code{Inference} object itself; callers are
		#'   expected to construct the specific classes they need (optionally passing the
		#'   validated \code{inference_params}) from the discovered list.
		#' @param des_obj A completed \code{\link[EDI:Design]{Design}} object (validated via
		#'   \code{\link[methods]{is}(des_obj, "Design")} when assertions are enabled; see
		#'   \code{\link{toggle_asserts}}).
		#' @param inference_params A named list of lists supplying additional
		#'   constructor arguments for specific inference classes.  Each name
		#'   must be the name of a concrete \code{Inference} subclass that is applicable
		#'   to \code{des_obj} (checked against \code{applicable_design_classes} once
		#'   discovered — an inapplicable class name raises an error); the
		#'   corresponding list contains keyword arguments (beyond
		#'   \code{des_obj}) forwarded to that class's \code{initialize}, and every
		#'   argument name supplied must match a formal parameter of that class's
		#'   \code{initialize} method (other than \code{des_obj} and \code{...}) or an
		#'   error is raised naming the unknown argument(s) and the valid ones.
		#'   Defaults to an empty list (no extra arguments for any class).
		#' @param model_formula Accepted for interface/future-extension purposes but
		#'   currently \strong{not used anywhere in this method's body} — supplying a
		#'   non-\code{NULL} value has no effect on discovery, validation, or any stored
		#'   state. Do not rely on this parameter to affect covariate adjustment; a
		#'   design's own model formula and design matrix are what individual
		#'   \code{Inference} classes actually consult when later constructed from this
		#'   suite's discovered class list.
		initialize = function(des_obj, model_formula = NULL, inference_params = list()) {
			if (should_run_asserts()) {
				if (!is(des_obj, "Design")) {
					stop("InferenceSuite: des_obj must be a Design object.")
				}
				if (!is.list(inference_params)) {
					stop("InferenceSuite: inference_params must be a list.")
				}
			}
			if (length(inference_params) > 0L &&
					(is.null(names(inference_params)) ||
					 any(nchar(names(inference_params)) == 0L))) {
				stop("InferenceSuite: inference_params must be a fully named list.")
			}
			# ── 1. Discover applicable classes ────────────────────────────────
			self$applicable_design_classes = des_obj$applicable_inference_class_names()
			self$unavailable_due_to_missing_packages = des_obj$unavailable_inference_classes_due_to_missing_packages()
			# ── 2. Validate inference_params ──────────────────────────────────
			for (cls_name in names(inference_params)) {
				# Must be applicable for this design
				if (should_run_asserts()) {
					if (!(cls_name %in% self$applicable_design_classes)) {
						stop(sprintf(
							"InferenceSuite: '%s' is not applicable for this design/response_type combination.",
							cls_name))
					}
				}
				# All supplied param names must be formals of initialize
				params = inference_params[[cls_name]]
				if (should_run_asserts()) {
					if (!is.list(params)) {
						stop(sprintf(
							"InferenceSuite: params for '%s' must be a list.", cls_name))
					}
					if (length(params) > 0L) {
						cls        = get(cls_name, envir = getNamespace("EDI"))
						init_fn    = cls$public_methods$initialize
						valid_args = setdiff(names(formals(init_fn)), c("des_obj", "..."))
						unknown    = setdiff(names(params), valid_args)
						if (length(unknown) > 0L) {
							stop(sprintf(
								"InferenceSuite: unknown argument(s) for '%s': %s\n  Valid: %s",
								cls_name,
								paste(unknown,    collapse = ", "),
								paste(valid_args, collapse = ", ")))
						}
					}
				}
			}
			private$des_obj          = des_obj
			private$inference_params = inference_params
		},
		#' @description Construct and fit every class in \code{applicable_design_classes},
		#'   and report one uniform comparison row per class -- estimate, SE, CI, p-value
		#'   (each via the highest-priority available method; see
		#'   \code{inference_suite_inspect.md}'s "Method Selection Policy"), likelihood
		#'   tier, estimand (where declared), fit time, captured warnings, and status.
		#'   Unlike the constructor, this method fits models and is not free; call it
		#'   explicitly when you want the comparison, not automatically.
		#'
		#'   A single class's construction or fit failure never aborts the report -- it
		#'   is caught and recorded as that class's \code{status}/\code{message} (see
		#'   "Per-Class Failure Isolation" in the design doc).
		#'
		#'   \strong{Side effects (v1.0.0 slice):} \code{screen} prints each row as its
		#'   class finishes fitting (computation order), not buffered to the end, with a
		#'   percent-done/estimated-time-remaining progress bar line underneath each row
		#'   (the ETA is the mean per-class elapsed time so far times classes remaining),
		#'   followed by a footer listing classes excluded for missing optional packages.
		#'   \code{html = TRUE} writes a self-contained, timestamped HTML report (the
		#'   same table plus the same footer) to the \strong{current working directory}
		#'   and opens it via \code{\link[utils]{browseURL}}; it requires the
		#'   \pkg{knitr} package. The \code{plots} ggplot2 visualizations, and their
		#'   embedding into this HTML report, are not yet implemented
		#'   (\code{inference_suite_inspect.md} TODO-7); \code{pdf} output is not yet a
		#'   parameter of this method.
		#' @param screen Print results to the console as each class finishes. At least
		#'   one of \code{screen}/\code{html} must be \code{TRUE}.
		#' @param html Render, save (current working directory, timestamped filename),
		#'   and auto-open a self-contained HTML report of the results.
		#' @param alpha Significance level: confidence intervals are computed at
		#'   \code{1 - alpha} and \code{alpha} is the significance threshold used
		#'   anywhere the report flags significance. Default \code{0.05}.
		#' @param save_results_as_JSON If \code{TRUE}, serialize the return object
		#'   (excluding plot objects) to a timestamped JSON file in the current working
		#'   directory. Requires the optional \pkg{jsonlite} package; if it is not
		#'   installed, a \code{warning()} is issued and this artifact is skipped rather
		#'   than erroring. Default \code{FALSE}.
		#' @param plots If \code{TRUE}, build and display (on the current graphics
		#'   device) two \pkg{ggplot2} visualizations: an estimate number line
		#'   (class/method labels above each point at 45 degrees, a box-and-whisker
		#'   summary underneath) and an annotated confidence-interval forest plot
		#'   (p-value left of each interval, interval width right of it, class/method
		#'   labeled underneath, color-keyed to significance at \code{alpha}). Requires
		#'   the optional \pkg{ggplot2} package; if it is not installed, a
		#'   \code{warning()} is issued and plotting is skipped rather than erroring.
		#'   Defaults to the value of \code{screen}.
		#' @param pdf If \code{TRUE}, save both visualizations to one timestamped,
		#'   two-page PDF file in the current working directory (page height scales
		#'   with the number of classes in the CI forest plot). Same \pkg{ggplot2}
		#'   dependency and missing-package handling as \code{plots}. Default
		#'   \code{FALSE}.
		#' @param classes Optional character vector restricting which applicable
		#'   classes to fit -- e.g. re-running against only the few classes a user is
		#'   actually deciding between, without reconstructing the suite. Every name
		#'   must already be in \code{applicable_design_classes} or this errors,
		#'   naming the unknown name(s) and the valid ones. \code{NULL} (default)
		#'   fits every applicable class.
		#' @param exclude_classes Optional character vector of applicable classes to
		#'   skip, applied after \code{classes}. Same validation as \code{classes}.
		#'   Default none.
		#' @param max_secs_per_class Optional per-class elapsed-time limit in seconds
		#'   (via \code{\link{setTimeLimit}}), after which that class's row gets
		#'   \code{status = "timeout"} instead of hanging the whole report. Protects
		#'   against one pathological class (e.g. a bootstrap/randomization method
		#'   with many replicates) blocking every other class. \strong{Known
		#'   limitation:} R's time limits are checked at R-level interrupt points, so
		#'   this reliably cuts off slow R-level work but is not guaranteed to
		#'   interrupt one very slow single native (C/C++/BLAS) call with no
		#'   intervening R-level check. \code{NULL} (default) means no limit.
		#' @param num_cores If greater than \code{1}, fit classes in parallel across
		#'   this many forked workers (\code{\link[parallel]{makeForkCluster}}) --
		#'   Unix/Linux only; on other platforms this falls back to sequential
		#'   (\code{num_cores = 1}) with a \code{warning()}. \strong{Screen output
		#'   changes under parallel execution:} fitting is a single blocking call
		#'   that only returns once every worker has finished, so there is no
		#'   meaningful per-class ETA to show while running -- \code{screen = TRUE}
		#'   instead prints a "fitting N classes across K workers" message up front,
		#'   then every result row together once complete, then a total-elapsed-time
		#'   summary line (a deliberate design choice, not a degraded default -- see
		#'   \code{inference_suite_inspect.md}'s TODO-13). Default \code{1L}
		#'   (sequential, with the normal incremental streaming/progress bar).
		#' @return Invisibly, an object of class \code{c("EDIInferenceSuiteResults", "list")}
		#'   with elements \code{results} (one named sub-list per class, in computation
		#'   order), \code{results_table} (the same rows as a flat \code{data.frame}),
		#'   \code{design}, \code{alpha}, \code{unavailable_due_to_missing_packages},
		#'   \code{plots} (\code{list(estimates, ci_forest)}, each a \code{ggplot} object
		#'   or \code{NULL}), \code{files} (\code{list(html, pdf, json)}, each a path or
		#'   \code{NULL}), \code{timestamp}, \code{total_secs}, and \code{edi_version}.
		run_all_inference = function(screen = TRUE, html = FALSE, alpha = 0.05, save_results_as_JSON = FALSE, plots = screen, pdf = FALSE,
				classes = NULL, exclude_classes = character(), max_secs_per_class = NULL, num_cores = 1L) {
			if (should_run_asserts()) {
				assertFlag(screen)
				assertFlag(html)
				assertNumber(alpha, lower = 0, upper = 1)
				assertFlag(save_results_as_JSON)
				assertFlag(plots)
				assertFlag(pdf)
				assertCharacter(classes, null.ok = TRUE)
				assertCharacter(exclude_classes)
				assertNumber(max_secs_per_class, lower = 0, null.ok = TRUE)
				assertCount(num_cores, positive = TRUE)
			}
			if (!screen && !html) {
				stop("InferenceSuite$run_all_inference: at least one of `screen`/`html` must be TRUE.")
			}
			if (should_run_asserts()) {
				if (!is.null(classes)) {
					unknown = setdiff(classes, self$applicable_design_classes)
					if (length(unknown) > 0L) {
						stop(sprintf(
							"InferenceSuite$run_all_inference: unknown/inapplicable class(es) in `classes`: %s\n  Applicable: %s",
							paste(unknown, collapse = ", "), paste(self$applicable_design_classes, collapse = ", ")))
					}
				}
				if (length(exclude_classes) > 0L) {
					unknown = setdiff(exclude_classes, self$applicable_design_classes)
					if (length(unknown) > 0L) {
						stop(sprintf(
							"InferenceSuite$run_all_inference: unknown/inapplicable class(es) in `exclude_classes`: %s\n  Applicable: %s",
							paste(unknown, collapse = ", "), paste(self$applicable_design_classes, collapse = ", ")))
					}
				}
			}
			des_obj         = private$des_obj
			design_meta     = normalize_inference_design_metadata(des_obj)
			design_family   = if (isTRUE(design_meta$is_kk)) "kk_matched_pair" else "iid"
			response_type   = design_meta$response_type
			cls_names       = if (is.null(classes)) self$applicable_design_classes else classes
			cls_names       = setdiff(cls_names, exclude_classes)
			n_total         = length(cls_names)
			t_start         = Sys.time()
			results         = vector("list", n_total)
			names(results)  = cls_names

			use_fork_cluster = num_cores > 1L && .Platform$OS.type == "unix"
			if (num_cores > 1L && !use_fork_cluster) {
				warning(
					"InferenceSuite$run_all_inference: num_cores > 1 is only supported via fork clusters ",
					"(Unix/Linux) -- falling back to num_cores = 1 (sequential) on this platform.",
					call. = FALSE
				)
			}

			if (use_fork_cluster && n_total > 0L) {
				# Fork clusters (parallel::makeForkCluster()) inherit the master
				# process's entire memory via copy-on-write, so this closure needs no
				# clusterExport() -- des_obj/alpha/etc. are already in its enclosing
				# frame. Screen output cannot stream per-class as it completes here:
				# clusterApply() is a single blocking call that returns only once every
				# worker has finished, so there is no meaningful per-row ETA to show
				# (deliberate design decision, not an oversight -- see
				# inference_suite_inspect.md's TODO-13).
				if (screen) cat(sprintf("Fitting %d classes across %d parallel workers...\n", n_total, num_cores))
				cl = parallel::makeForkCluster(num_cores)
				on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
				worker_fn = function(cls_name) {
					params = private$inference_params[[cls_name]] %||% list()
					run_all_inference_one_class(
						cls_name, des_obj, params, alpha, design_family, response_type, max_secs_per_class
					)
				}
				results_list = parallel::clusterApply(cl, cls_names, worker_fn)
				names(results_list) = cls_names
				results = results_list
				if (screen) {
					for (i in seq_along(cls_names)) {
						run_all_inference_print_row(i, n_total, results[[cls_names[[i]]]])
					}
					cat(sprintf("Completed %d classes in %s.\n", n_total, run_all_inference_fmt_secs(as.numeric(difftime(Sys.time(), t_start, units = "secs")))))
				}
			} else {
				elapsed_secs_so_far = numeric(n_total)
				for (i in seq_along(cls_names)) {
					cls_name = cls_names[[i]]
					params   = private$inference_params[[cls_name]] %||% list()
					results[[cls_name]] = run_all_inference_one_class(
						cls_name, des_obj, params, alpha, design_family, response_type, max_secs_per_class
					)
					elapsed_secs_so_far[[i]] = results[[cls_name]]$fit_secs
					if (screen) {
						run_all_inference_print_row(i, n_total, results[[cls_name]])
						cat(run_all_inference_progress_bar_line(i, n_total, elapsed_secs_so_far), "\n")
					}
				}
			}
			if (screen) {
				cat("\nClasses unavailable due to missing packages:\n")
				cat(paste0("  ", run_all_inference_unavailable_footer_lines(self$unavailable_due_to_missing_packages)), sep = "\n")
			}
			results_table = do.call(rbind.data.frame, lapply(results, function(r) {
				data.frame(
					inference_class = r$inference_class, response_type = r$response_type,
					design_family = r$design_family, likelihood_tier = r$likelihood_tier,
					estimate = r$estimate, se = r$se,
					ci_lower = r$ci_lower, ci_upper = r$ci_upper, ci_method = r$ci_method,
					pval = r$pval, pval_method = r$pval_method, estimand = r$estimand,
					fit_secs = r$fit_secs, warnings = r$warnings,
					status = r$status, message = r$message,
					stringsAsFactors = FALSE
				)
			}))
			rownames(results_table) = NULL
			out = list(
				results = results,
				results_table = results_table,
				design = list(
					response_type = response_type, design_family = design_family,
					design_class = class(des_obj)[[1L]], n = des_obj$get_n()
				),
				alpha = alpha,
				unavailable_due_to_missing_packages = self$unavailable_due_to_missing_packages,
				plots = list(estimates = NULL, ci_forest = NULL),
				files = list(html = NULL, pdf = NULL, json = NULL),
				timestamp = format(Sys.time(), "%Y%m%d_%H%M%S"),
				total_secs = as.numeric(difftime(Sys.time(), t_start, units = "secs")),
				edi_version = as.character(utils::packageVersion("EDI"))
			)
			class(out) = c("EDIInferenceSuiteResults", "list")
			if (plots || pdf || html) {
				out$plots = run_all_inference_build_plots(results_table, alpha)
			}
			if (plots) {
				if (!is.null(out$plots$estimates)) {
					tryCatch(print(out$plots$estimates), error = function(e) invisible(NULL))
				}
				if (!is.null(out$plots$ci_forest)) {
					tryCatch(print(out$plots$ci_forest), error = function(e) invisible(NULL))
				}
			}
			if (pdf && (!is.null(out$plots$estimates) || !is.null(out$plots$ci_forest))) {
				pdf_path = file.path(getwd(), sprintf("inference_suite_results_plots_%s.pdf", out$timestamp))
				n_ci_rows = sum(results_table$status == "ok" &
					is.finite(results_table$ci_lower) & is.finite(results_table$ci_upper))
				run_all_inference_save_plots_pdf(out$plots, pdf_path, n_ci_rows)
				out$files$pdf = pdf_path
			}
			if (html) {
				html_path = file.path(getwd(), sprintf("inference_suite_results_%s.html", out$timestamp))
				writeLines(run_all_inference_render_html(out), html_path, useBytes = TRUE)
				out$files$html = html_path
				utils::browseURL(html_path)
			}
			if (save_results_as_JSON) {
				if (!requireNamespace("jsonlite", quietly = TRUE)) {
					warning(
						"InferenceSuite$run_all_inference: the 'jsonlite' package is not installed -- ",
						"skipping save_results_as_JSON. Install 'jsonlite' to enable it.",
						call. = FALSE
					)
				} else {
					json_path = file.path(getwd(), sprintf("inference_suite_results_%s.json", out$timestamp))
					jsonlite::write_json(out[setdiff(names(out), "plots")], json_path, auto_unbox = TRUE, null = "null", na = "null")
					out$files$json = json_path
				}
			}
			invisible(out)
		}
	),
	private = list(
		des_obj          = NULL,
		inference_params = NULL
	)
)

#' Prints the results table from an \code{\link[EDI:InferenceSuite]{InferenceSuite}}
#' \code{run_all_inference()} call -- the same table \code{screen = TRUE} prints during
#' the call itself, so a user who assigned the return value and later types its name
#' (or calls \code{print()} on it) sees a readable table rather than a raw nested list
#' dump.
#' @param x An \code{EDIInferenceSuiteResults} object, as returned by
#'   \code{InferenceSuite$run_all_inference()}.
#' @param ... Ignored; present for S3 consistency with the generic.
#' @return \code{x}, invisibly.
#' @export
print.EDIInferenceSuiteResults = function(x, ...) {
	cat(sprintf(
		"<EDIInferenceSuiteResults> %d class(es) -- %s (%s, %s), n = %s\n",
		nrow(x$results_table), x$design$design_class, x$design$response_type,
		x$design$design_family, x$design$n
	))
	print(x$results_table)
	invisible(x)
}

#' Summarizes an \code{\link[EDI:InferenceSuite]{InferenceSuite}} \code{run_all_inference()}
#' result: counts by \code{status}, the estimate range across \code{status == "ok"}
#' classes, and how many reject at \code{alpha}.
#' @param object An \code{EDIInferenceSuiteResults} object, as returned by
#'   \code{InferenceSuite$run_all_inference()}.
#' @param ... Ignored; present for S3 consistency with the generic.
#' @return An object of class \code{summary.EDIInferenceSuiteResults}, printable via its
#'   own \code{print} method.
#' @export
summary.EDIInferenceSuiteResults = function(object, ...) {
	tbl = object$results_table
	ok = tbl[tbl$status == "ok", , drop = FALSE]
	structure(
		list(
			n_classes = nrow(tbl),
			status_counts = table(factor(tbl$status, levels = c("ok", "nonestimable", "error", "timeout"))),
			estimate_range = if (nrow(ok) > 0L) range(ok$estimate, na.rm = TRUE) else c(NA_real_, NA_real_),
			alpha = object$alpha,
			n_significant = sum(!is.na(ok$pval) & ok$pval < object$alpha)
		),
		class = "summary.EDIInferenceSuiteResults"
	)
}

#' @param x A \code{summary.EDIInferenceSuiteResults} object, as returned by
#'   \code{\link{summary.EDIInferenceSuiteResults}}.
#' @param ... Ignored; present for S3 consistency with the generic.
#' @return \code{x}, invisibly.
#' @export
#' @rdname summary.EDIInferenceSuiteResults
print.summary.EDIInferenceSuiteResults = function(x, ...) {
	cat("InferenceSuite$run_all_inference() summary\n")
	cat(sprintf("  classes:            %d\n", x$n_classes))
	for (nm in names(x$status_counts)) {
		cat(sprintf("    %-13s %d\n", paste0(nm, ":"), x$status_counts[[nm]]))
	}
	cat(sprintf(
		"  estimate range:     [%s, %s]\n",
		if (is.na(x$estimate_range[1])) "NA" else formatC(x$estimate_range[1], digits = 4, format = "g"),
		if (is.na(x$estimate_range[2])) "NA" else formatC(x$estimate_range[2], digits = 4, format = "g")
	))
	cat(sprintf("  significant (alpha = %g): %d\n", x$alpha, x$n_significant))
	invisible(x)
}
