#!/usr/bin/env Rscript
# Figures for the published calibration study (release_v1_2_0.md TODO-36), from
# analyze_calibration_study.R's tables. Each figure is written twice, <name>.png (light) and
# <name>-dark.png, and README fragment lines embed both with a GitHub <picture>
# element that follows the reader's theme.
#
# The fragment has two sections, each by response type (owner, 2026-11-09):
# "Null treatment effect" (beta_T = 0)
#   overview-<rt>.png          class x design grid per n (stacked): worst status, each square split into size
#                              (upper-left triangle) and coverage (lower-right) (owner, 2026-11-12)
#   size-coverage-<rt>.png     size (top) and 1 - coverage (bottom) per class x method x formula, Bernoulli,
#                              by n, one x axis (owner, 2026-11-12: one figure, stacked)
#   null-bias-<rt>.png         null bias / SD, Bernoulli, by n
#   pvalue-curves-<rt>.png     P(p <= u) - u for null p-values (n = 200, Bernoulli, ~ .)
# "Non-null treatment effect" (beta_T != 0)
#   overview-nonnull-<rt>.png  class x design grid: worst coverage status of the true estimand
#   coverage-nonnull-<rt>.png  coverage of the true estimand, Bernoulli, by effect and n
#   bias-nonnull-<rt>.png      bias / SD against the true estimand, Bernoulli, by effect and n
#   power-designs-<rt>.png     power of the baseline class at the 50% local alternative, by design and n
# and, in both sections, when convergence_summary.csv exists (convergence_calibration_study.R,
# v1.0.5 TODO-199; absent or empty -> skipped):
#   convergence-<rt>.png / convergence-nonnull-<rt>.png          |error| vs n_eff, log-log, asymptotic cells,
#                                                                  expected slope as reference lines
#   convergence-grid[-nonnull]-<rt>-<procedure>.png              class x design grid of verdicts, one figure per procedure
#                                                                  (and -bias), owner 2026-11-12
#
# With --class-figures (v1.0.5 TODO-203, new_feature_plans/v1_0_5/calibration_class_major_campaign_order.md) it also writes
# one convergence figure per inference class, class-<Class>.png (+ -dark): panels procedure (rows) x metric (size error,
# coverage error, bias), x = n_eff, y = |error| on log-log axes, effects (null, power20/50/80) as colours, one line per
# design x formula cell, the registry's expected slope as a reference line and the panel's verdict in its title. The
# README's per-class pages embed them; they are not part of the figures fragment.
#
# Usage: Rscript R/package_tests/calibration/plot_calibration_study.R --summary-dir DIR \
#          --out-dir DIR [--fragment FILE] [--fig-prefix figures/] [--class-figures]

suppressPackageStartupMessages(library(ggplot2))
args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
summary_dir <- arg_value("--summary-dir")
out_dir <- arg_value("--out-dir")
fragment <- arg_value("--fragment", file.path(out_dir, "figures.md"))
fig_prefix <- arg_value("--fig-prefix", "figures/")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Palette: the dataviz reference instance (validated: categorical slots 1-4 pass
# CVD / normal-vision checks on both surfaces; light-mode contrast relief comes
# from point shapes, legends and the CSV tables). Status colours are reserved for
# pass / accepted / fail and always ship with a legend label.
THEMES <- list(
	light = list(surface = "#fcfcfb", ink = "#0b0b0b", ink2 = "#52514e", muted = "#898781", grid = "#e1e0d9",
		axis = "#c3c2b7", series = c("#2a78d6", "#eb6834", "#1baf7a", "#eda100"), mid = "#f0efec",
		div_lo = "#2a78d6", div_hi = "#e34948"),
	dark = list(surface = "#1a1a19", ink = "#f0efec", ink2 = "#c3c2b7", muted = "#898781", grid = "#2c2c2a",
		axis = "#383835", series = c("#3987e5", "#d95926", "#199e70", "#c98500"), mid = "#383835",
		div_lo = "#3987e5", div_hi = "#e66767")
)
STATUS <- c(pass = "#0ca30c", accepted = "#fab219", fail = "#d03b3b", `too few results` = "#898781")
# Away from the null a cell can also have no true estimand value (matched-only
# classes; failed large-sample fits): a light neutral, distinct from "too few".
STATUS_NONNULL <- c(pass = "#0ca30c", fail = "#d03b3b", `too few results` = "#898781", `no true value` = "#dcdbd5")
# Overview grids: a class not run on a design (the design is not applicable to it,
# e.g. a KK class off the KK / matching designs) gets an explicit level drawn in the
# page's surface colour, so the blank square has a legend entry.
NA_DESIGN <- "design not applicable"
complete_overview <- function(ov, levels) {
	full <- expand.grid(cls = unique(ov$cls), design_label = unique(ov$design_label), stringsAsFactors = FALSE)
	ov <- merge(full, ov, all.x = TRUE)
	ov$status <- as.character(ov$status)
	ov$status[is.na(ov$status)] <- NA_DESIGN
	ov$status <- factor(ov$status, levels = c(levels, NA_DESIGN))
	ov
}

theme_cal <- function(th) {
	theme_minimal(base_size = 10) + theme(
		plot.background = element_rect(fill = th$surface, colour = NA),
		panel.background = element_rect(fill = th$surface, colour = NA),
		panel.grid.major = element_line(colour = th$grid, linewidth = 0.3), panel.grid.minor = element_blank(),
		axis.text = element_text(colour = th$ink2), axis.title = element_text(colour = th$ink2),
		plot.title = element_text(colour = th$ink, face = "bold"), plot.subtitle = element_text(colour = th$ink2),
		strip.text = element_text(colour = th$ink, face = "bold"), legend.text = element_text(colour = th$ink2),
		legend.title = element_text(colour = th$ink2), legend.position = "top", plot.caption = element_text(colour = th$muted))
}

md <- character()
# Figure titles say which regime the figure is about: beta_T = 0 (null: size,
# coverage, null bias, p-value calibration) or beta_T != 0 (power), as plotmath.
# Exact (Clopper-Pearson) 95% Monte Carlo interval for k successes in n, the
# same exact binomial the gate tests with. A normal-approximation interval has
# zero width at an observed 0 (or 1) and is too narrow at small counts.
cp_lo <- function(k, n) ifelse(k <= 0, 0, stats::qbeta(0.025, k, n - k + 1))
cp_hi <- function(k, n) ifelse(k >= n, 1, stats::qbeta(0.975, k + 1, n - k))
rep_range <- function(n) if (min(n) == max(n)) format(max(n), big.mark = ",") else
	sprintf("%s-%s", format(min(n), big.mark = ","), format(max(n), big.mark = ","))
# Subtitles wrap to the figure (ggplot does not wrap them itself).
wrap_sub <- function(x, width = 82) paste(strwrap(x, width), collapse = "\n")
regime_title <- function(txt, null) {
	if (null) bquote(.(txt) ~ "(" * beta[T] == 0 * ")") else bquote(.(txt) ~ "(" * beta[T] != 0 * ")")
}
# Note: theme_cal() is added after the figure is built and replaces any theme(axis.text.x = ...) set
# inside it, so angled categorical x labels use scale_x_discrete(guide = guide_axis(angle = 45)), which it keeps.
save_both <- function(build, name, width, height, alt) {
	for (mode in names(THEMES)) {
		p <- build(THEMES[[mode]]) + theme_cal(THEMES[[mode]])
		f <- file.path(out_dir, paste0(name, if (mode == "dark") "-dark" else "", ".png"))
		ggsave(f, p, width = width, height = height, dpi = 150, bg = THEMES[[mode]]$surface, limitsize = FALSE)
	}
	md <<- c(md, sprintf(paste0('<picture><source media="(prefers-color-scheme: dark)" srcset="%s%s-dark.png">',
		'<img alt="%s" src="%s%s.png"></picture>'), fig_prefix, name, alt, fig_prefix, name), "")
}

rd <- function(f) {
	p <- file.path(summary_dir, f)
	if (file.exists(p)) utils::read.csv(p, stringsAsFactors = FALSE, colClasses = c(formula = "character")) else NULL
}
s <- rd("calibration_summary.csv")
b <- rd("null_bias_summary.csv")
nb <- rd("nonnull_bias_summary.csv")
pw <- rd("power_summary.csv")
pc <- rd("pvalue_curves.csv")
cv <- rd("convergence_summary.csv")
cvp <- rd("convergence_points.csv")
if (is.null(s)) {
	# No results yet (the analysis wrote only its "No results yet" markdown): an
	# empty fragment, so the README renders and the publish step goes on.
	dir.create(dirname(fragment), recursive = TRUE, showWarnings = FALSE)
	writeLines(c("No figures yet.", ""), fragment)
	quit(save = "no", status = 0L)
}
for (x in list("s", "b", "nb", "pw", "pc")) if (!is.null(get(x))) {
	v <- get(x)
	v$formula[is.na(v$formula)] <- ""
	v$design_label <- paste0(sub("^Design(Fixed|SeqOneByOne)", "\\1:", v$design), ifelse(v$prob_T != 0.5, paste0(" @", v$prob_T), ""))
	v$design_label <- sub("^SeqOneByOne:", "Seq:", v$design_label)
	if (!("n_nominal" %in% names(v))) v$n_nominal <- v$n
	v$cls <- sub("^Inference", "", v$inf_class)
	assign(x, v)
}
s$status <- ifelse(s$fail_size | s$fail_coverage, "fail", ifelse(is.na(s$p_size) & is.na(s$p_coverage), "too few results",
	# read.csv turns an empty `accepted` into NA, and nzchar(NA) is TRUE.
	ifelse(!is.na(s$accepted) & nzchar(s$accepted), "accepted", "pass")))
n_levels <- sort(unique(s$n_nominal))
n_fac <- function(x) factor(x, levels = n_levels, labels = paste0("n = ", n_levels))
baseline_design <- "Fixed:Bernoulli"

# Response-type order of the figures (same as CAL_STUDY_RT_DISPLAY_ORDER in
# calibration_study_stats.R; this script sources only the registry below).
RT_ORDER <- c("continuous", "incidence", "count", "proportion", "survival", "ordinal")
# Procedure labels (inference_procedure_regime.R, read from the checkout: no EDI installed in the
# publish job). Display order: the monthly tier-1 procedures first, then the rest in registry order.
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))),
	"..", "..", "EDI", "R", "inference_procedure_regime.R"))
PROC_ORDER <- c("wald", "score", "lik_ratio", "gradient", "exact", "rand")
PROC_ORDER <- c(PROC_ORDER, setdiff(names(EDI_INFERENCE_PROCEDURE_REGIME), PROC_ORDER))

# ---- Convergence (v1.0.5 TODO-199) --------------------------------------------------------
# Verdict colours: slower is the warning (status red); the others are neutral or benign.
CONV_VERDICT <- c(slower = "#d03b3b", faster = "#2a78d6", consistent = "#0ca30c", undetermined = "#898781", not_applicable = "#dcdbd5")
conv_ok <- !is.null(cv) && !is.null(cvp) && nrow(cv) > 0L
if (conv_ok) {
	for (x in list("cv", "cvp")) {
		v <- get(x)
		v$formula[is.na(v$formula)] <- ""
		v$design_label <- paste0(sub("^Design(Fixed|SeqOneByOne)", "\\1:", v$design), ifelse(v$prob_T != 0.5, paste0(" @", v$prob_T), ""))
		v$design_label <- sub("^SeqOneByOne:", "Seq:", v$design_label)
		v$cls <- sub("^Inference", "", v$inf_class)
		assign(x, v)
	}
	cvp$verdict <- cv$verdict[match(cvp$cell_id, cv$cell_id)]
	cvp$expected_order <- cv$expected_order[match(cvp$cell_id, cv$cell_id)]
	cvp$regime <- cv$regime[match(cvp$cell_id, cv$cell_id)]
}
conv_metric_label <- function(m) factor(m, levels = c("size", "coverage", "bias"),
	labels = c("size error (size - 0.05)", "coverage error (0.95 - coverage)", "bias"))
# The two convergence figures of one response type and one section (null = beta_T = 0).
conv_figures <- function(rt, null) {
	if (!conv_ok) return(invisible(NULL))
	sec <- if (null) cv$effect_label == "null" else cv$effect_label != "null"
	x <- cv[sec & cv$response_type == rt, ]
	if (!nrow(x)) return(invisible(NULL))
	sfx <- if (null) "" else "-nonnull"
	md <<- c(md, "##### Convergence of the error with n", "",
		sprintf("%d of %d cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.", sum(x$n_points >= 2L), nrow(x)),
		"The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).", "")
	# Figure 1: |error| vs n_eff for the asymptotic cells with a finite positive expected order,
	# baseline design, formula ~. (the Bernoulli design and ~ . are the figures' usual cut), cells with >= 2 sizes.
	pts <- cvp[cvp$cell_id %in% x$cell_id[x$n_points >= 2L & is.finite(x$expected_order) & x$expected_order > 0 & x$regime %in% "asymptotic"] &
		cvp$design_label == baseline_design & cvp$formula == "~." & is.finite(cvp$err) & cvp$err != 0, ]
	if (nrow(pts)) {
		pts$metric_f <- conv_metric_label(pts$metric)
		pts$verdict <- factor(pts$verdict, levels = names(CONV_VERDICT))
		pts$line <- paste(pts$cell_id)
		pts$above <- ifelse(pts$err > 0, "error above 0", "error below 0")
		pts$ae <- abs(pts$err)
		orders <- sort(unique(pts$expected_order))
		# Reference lines: slope -a through the median |error| at the smallest n_eff, per facet and order.
		refs <- do.call(rbind, lapply(split(pts, pts$metric_f), function(d) {
			d0 <- d[d$n_eff == min(d$n_eff), ]
			do.call(rbind, lapply(orders, function(a) data.frame(metric_f = d$metric_f[1L], a = a,
				icpt = log10(stats::median(d0$ae)) + a * log10(min(d$n_eff)))))
		}))
		refs$lab <- factor(sprintf("expected slope -%s", signif(refs$a, 3)), levels = sprintf("expected slope -%s", signif(orders, 3)))
		save_both(function(th) ggplot(pts, aes(n_eff, ae, group = line, colour = verdict)) +
			geom_abline(data = refs, aes(slope = -a, intercept = icpt, linetype = lab), colour = th$ink2, linewidth = 0.4, inherit.aes = FALSE) +
			geom_line(linewidth = 0.4, alpha = 0.7) + geom_point(aes(shape = above), size = 1.4) + facet_wrap(~ metric_f, scales = "free_y", nrow = 1) +
			scale_x_log10() + scale_y_log10() +
			scale_colour_manual(values = CONV_VERDICT, drop = TRUE, name = "verdict") + scale_shape_manual(values = c(16, 1), name = NULL) +
			scale_linetype_manual(values = c("dashed", "dotted", "dotdash", "longdash")[seq_along(levels(refs$lab))], name = NULL) +
			labs(title = regime_title(sprintf("%s: how the error shrinks with n (Bernoulli design, ~ .)", tools::toTitleCase(rt)), null),
				subtitle = wrap_sub("One line per class x procedure; absolute error on log-log axes, so a line parallel to a reference line converges at that order. Open circles: error below 0 (conservative size, over-coverage, negative bias). Points near the Monte Carlo noise floor (size SE about 0.007 at 1,000 replicates) are noise, not signal.", 110),
				x = "effective n (log scale)", y = "|error| (log scale)"),
			paste0("convergence", sfx, "-", rt), 11, 4.5, sprintf("%s convergence of the error with n", rt))
	}
	# Figure 2: verdict grid, class x design per procedure (bias: its own panel).
	asy <- x[x$regime %in% "asymptotic" | x$metric == "bias", ]
	if (nrow(asy)) {
		asy$panel <- ifelse(asy$metric == "bias", "bias (estimator)", asy$inf_procedure)
		rank <- c(slower = 4L, faster = 3L, consistent = 2L, undetermined = 1L, not_applicable = 0L)
		ov <- aggregate(verdict ~ cls + design_label + panel, asy, function(v) v[[which.max(rank[v])]])
		ov$verdict <- factor(ov$verdict, levels = names(CONV_VERDICT))
		# One figure per procedure (owner, 2026-11-12: a facet per procedure left the design labels unreadable), every
		# figure on the full class x design grid so they line up; bias (the estimator's) last.
		panels <- unique(ov$panel)
		panels <- c(intersect(PROC_ORDER, panels), setdiff(sort(setdiff(panels, "bias (estimator)")), PROC_ORDER), intersect("bias (estimator)", panels))
		cls_lv <- sort(unique(ov$cls)); des_lv <- sort(unique(ov$design_label))
		for (pn in panels) {
			op <- ov[ov$panel == pn, , drop = FALSE]
			op$cls <- factor(op$cls, levels = cls_lv); op$design_label <- factor(op$design_label, levels = des_lv)
			save_both(function(th) ggplot(op, aes(design_label, cls, fill = verdict)) +
				geom_tile(colour = th$surface, linewidth = 0.5, show.legend = TRUE) +
				scale_fill_manual(values = CONV_VERDICT, drop = FALSE, name = "verdict",
					guide = guide_legend(override.aes = list(colour = "#898781", linewidth = 0.5))) +
				scale_x_discrete(drop = FALSE, guide = guide_axis(angle = 45)) + scale_y_discrete(drop = FALSE) +
				labs(title = regime_title(sprintf("%s: convergence verdicts, %s", tools::toTitleCase(rt), pn), null),
					subtitle = wrap_sub(if (pn == "bias (estimator)") "Worst verdict over formulas and effects; bias is a property of the estimator, shared by its procedures" else
						"Worst verdict over formulas, effects and the size / coverage metrics (slower > faster > consistent > undetermined > not applicable)", 100),
					x = NULL, y = NULL),
				paste0("convergence-grid", sfx, "-", rt, "-", gsub("[^a-z0-9]+", "-", sub(" \\(estimator\\)", "", pn))), 9,
				3.4 + 0.22 * length(cls_lv), sprintf("%s convergence verdicts: %s", rt, pn))
		}
	}
	invisible(NULL)
}

rts <- unique(s$response_type)
md <- c(md, "### Null treatment effect (beta_T = 0)", "")
for (rt in c(intersect(RT_ORDER, rts), sort(setdiff(rts, RT_ORDER)))) {
	x <- s[s$response_type == rt, ]
	md <- c(md, sprintf("#### %s", tools::toTitleCase(rt)), "")

	# Overview: worst status per class x design x n over methods and formulas, one grid per n stacked
	# (n = 50, 200, 1000 top to bottom), each square split into two triangles (owner, 2026-11-12):
	# upper-left = size, lower-right = coverage. A metric no procedure of the
	# cell has (e.g. coverage when only randomization tests ran) is left blank, like an inapplicable design.
	rank <- c(pass = 1L, `too few results` = 0L, accepted = 2L, fail = 3L)
	is_acc <- !is.na(x$accepted) & nzchar(x$accepted)
	metric_status <- function(fail, p, has) ifelse(!has, NA_character_, ifelse(fail %in% TRUE, "fail",
		ifelse(is.na(p), "too few results", ifelse(is_acc, "accepted", "pass"))))
	x$status_size <- metric_status(x$fail_size, x$p_size, is.finite(x$size) | !is.na(x$p_size))
	x$status_coverage <- metric_status(x$fail_coverage, x$p_coverage, is.finite(x$coverage) | !is.na(x$p_coverage))
	worst <- function(v) { v <- v[!is.na(v)]; if (length(v)) v[[which.max(rank[v])]] else NA_character_ }
	ov <- do.call(rbind, lapply(split(x, list(x$cls, x$design_label, x$n_nominal), drop = TRUE), function(d)
		data.frame(cls = d$cls[1L], design_label = d$design_label[1L], n_nominal = d$n_nominal[1L], size = worst(d$status_size),
			coverage = worst(d$status_coverage), stringsAsFactors = FALSE)))
	cls_levels <- sort(unique(x$cls))
	des_levels <- sort(unique(x$design_label))
	ov$xi <- match(ov$design_label, des_levels)
	ov$yi <- match(ov$cls, cls_levels)
	h <- 0.45
	tri <- do.call(rbind, lapply(seq_len(nrow(ov)), function(i) {
		o <- ov[i, ]
		rbind(data.frame(id = paste(i, "size"), status = o$size, n_nominal = o$n_nominal, x = o$xi + c(-h, -h, h), y = o$yi + c(-h, h, h)),
			data.frame(id = paste(i, "coverage"), status = o$coverage, n_nominal = o$n_nominal, x = o$xi + c(-h, h, h), y = o$yi + c(-h, -h, h)))
	}))
	tri$status[is.na(tri$status)] <- NA_DESIGN
	tri$nf <- n_fac(tri$n_nominal)
	tri$status <- factor(tri$status, levels = c(names(STATUS), NA_DESIGN))
	# Every status gets a legend swatch even when no cell has it (one invisible zero-size polygon per level).
	keys <- data.frame(id = paste("key", levels(tri$status)), status = factor(levels(tri$status), levels = levels(tri$status)),
		x = 1, y = 1, nf = n_fac(min(tri$n_nominal)))
	save_both(function(th) ggplot(tri, aes(x, y, group = id, fill = status)) +
		geom_polygon(colour = th$surface, linewidth = 0.6) +
		geom_polygon(data = keys, colour = NA, show.legend = TRUE) +
		scale_fill_manual(values = c(STATUS, setNames(th$surface, NA_DESIGN)), drop = FALSE, name = "worst cell",
			guide = guide_legend(override.aes = list(colour = "#898781", linewidth = 0.5))) +
		scale_x_continuous(breaks = seq_along(des_levels), labels = des_levels, expand = c(0, 0.1),
			guide = guide_axis(angle = 45)) +
		scale_y_continuous(breaks = seq_along(cls_levels), labels = cls_levels, expand = c(0, 0.1)) +
		coord_fixed() + facet_grid(nf ~ .) +
		labs(title = regime_title(sprintf("%s: size and coverage, every class on every design", tools::toTitleCase(rt)), TRUE),
			subtitle = wrap_sub("One grid per n. Each square: upper-left triangle = size, lower-right = coverage, each held to its level at that n. Worst status over the fast procedures and both formulas; blank = design not applicable, not run at that n, or no such procedure"),
			x = NULL, y = NULL),
		paste0("overview-", rt), 9, 2.9 + 0.22 * length(cls_levels) * length(unique(tri$n_nominal)) + 0.3 * length(unique(tri$n_nominal)),
		sprintf("%s overview: size and coverage by n", rt))

	# Size and coverage in one figure, stacked (owner, 2026-11-12): size on top, 1 - coverage below, on one x
	# axis. At beta_T = 0 a CI that inverts its test misses exactly when the test rejects, so the two panels
	# should agree; where they do not, the CI is not the test's inversion (another SE or reference distribution).
	xb <- x[x$design_label == baseline_design & is.finite(x$size), ]
	xc <- x[x$design_label == baseline_design & is.finite(x$coverage), ]
	if (nrow(xb) || nrow(xc)) {
		panel_levels <- c("size", "miscoverage (1 - coverage)")
		part <- function(d, rate, k_n, panel) {
			if (!nrow(d)) return(NULL)
			k <- round(rate * k_n)
			data.frame(row = paste(d$cls, d$inf_procedure, d$formula), nf = n_fac(d$n_nominal), rate = rate,
				lo = cp_lo(k, k_n), hi = cp_hi(k, k_n), reps = k_n, panel = factor(panel, levels = panel_levels))
		}
		sc <- rbind(part(xb, xb$size, xb$n_p, panel_levels[1L]), part(xc, 1 - xc$coverage, xc$n_ci, panel_levels[2L]))
		n_rows <- length(unique(paste(sc$panel, sc$row)))
		save_both(function(th) ggplot(sc, aes(rate, row, colour = nf, shape = nf)) +
			geom_vline(xintercept = 0.05, colour = th$ink2, linewidth = 0.4, linetype = "dashed") +
			geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0, linewidth = 0.4,
				position = position_dodge(width = 0.6)) +
			geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
			facet_grid(panel ~ ., scales = "free_y", space = "free_y") +
			scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
			labs(title = regime_title(sprintf("%s: size and 95%% CI coverage, Bernoulli design", tools::toTitleCase(rt)), TRUE),
				subtitle = wrap_sub(sprintf("Top: Type I error (size). Bottom: 1 - coverage of the 95%% CI, so both read against nominal 5%% (dashed); a CI that inverts its test misses exactly when the test rejects, so the panels should agree. Bars are exact 95%% Monte Carlo intervals (%s replicates per cell)", rep_range(sc$reps)), 78),
				x = "size (top) / 1 - coverage (bottom)", y = NULL),
			paste0("size-coverage-", rt), 8, 2.6 + 0.16 * n_rows, sprintf("%s size and coverage", rt))
	}
	if (!is.null(b)) {
		bb <- b[b$response_type == rt & b$design_label == baseline_design & is.finite(b$null_bias_std), ]
		if (nrow(bb)) {
			bb$row <- paste(bb$cls, bb$formula)
			bb$nf <- n_fac(bb$n_nominal)
			# 95% Monte Carlo interval for bias / SD: the mean's SE over the SD (about
			# 1 / sqrt(n_est)), t quantile, as the analysis's z-test of the bias.
			bb$half <- stats::qt(0.975, pmax(bb$n_est - 1, 1)) * bb$null_bias_se / bb$null_bias_sd
			save_both(function(th) ggplot(bb, aes(null_bias_std, row, colour = nf, shape = nf)) +
				annotate("rect", xmin = -0.1, xmax = 0.1, ymin = -Inf, ymax = Inf, fill = th$mid) +
				geom_vline(xintercept = 0, colour = th$ink2, linewidth = 0.4) +
				geom_errorbar(aes(xmin = null_bias_std - half, xmax = null_bias_std + half), orientation = "y", width = 0,
					linewidth = 0.4, position = position_dodge(width = 0.6)) +
				geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
				scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
				labs(title = regime_title(sprintf("%s: null bias, Bernoulli design", tools::toTitleCase(rt)), TRUE),
					subtitle = wrap_sub(sprintf("Mean estimate minus the null value, in SDs of the estimate; bars are 95%% Monte Carlo intervals (%s estimates per cell); band = flag threshold (|bias| / SD < 0.1)", rep_range(bb$n_est))),
					x = "null bias / SD", y = NULL),
				paste0("null-bias-", rt), 8, 2 + 0.2 * length(unique(bb$row)), sprintf("%s null bias", rt))
		}
	}
	if (!is.null(pc)) {
		r <- pc[pc$response_type == rt & pc$design == "DesignFixedBernoulli" & pc$prob_T == 0.5 & pc$n_nominal == 200 &
			pc$formula == "~." & pc$n_p >= 30, ]
		if (nrow(r)) {
			r$cls <- sub("^Inference", "", r$inf_class)
			r$inf_procedure <- factor(r$inf_procedure, levels = PROC_ORDER)
			r <- rbind(r, transform(r[!duplicated(r[c("cls", "inf_procedure")]), ], u = 0, dev = 0),
				transform(r[!duplicated(r[c("cls", "inf_procedure")]), ], u = 1, dev = 0))
			r <- r[order(r$cls, r$inf_procedure, r$u), ]
			# Simultaneous 95% band for a perfectly calibrated test (Dvoretzky-Kiefer-Wolfowitz, Massart's constant):
			# P(sup_u |F_n(u) - u| > e) <= 2 exp(-2 n e^2), so e = sqrt(log(2 / 0.05) / (2 n)) ~ 1.36 / sqrt(n), with the
			# class's smallest n_p (its widest band). A whole curve inside the band is consistent with uniform p-values;
			# one point outside rejects uniformity at 5% for that curve. Flat in u, so it is loose near u = 0.05.
			np_cls <- tapply(r$n_p[r$n_p > 0], r$cls[r$n_p > 0], min)
			ug <- seq(0, 1, length.out = 401)
			band <- do.call(rbind, lapply(names(np_cls), function(k)
				data.frame(cls = k, u = ug, half = sqrt(log(2 / 0.05) / (2 * np_cls[[k]])))))
			save_both(function(th) ggplot(r, aes(u, dev, colour = inf_procedure)) +
				geom_ribbon(data = band, aes(x = u, ymin = -half, ymax = half), inherit.aes = FALSE, fill = th$muted, alpha = 0.25) +
				geom_hline(yintercept = 0, colour = th$ink2, linewidth = 0.4) +
				geom_vline(xintercept = 0.05, colour = th$muted, linewidth = 0.3, linetype = "dashed") +
				geom_line(linewidth = 0.6) + geom_point(size = 1) + facet_wrap(~ cls) +
				scale_x_sqrt(breaks = c(0.01, 0.05, 0.2, 0.5, 1)) +
				scale_colour_manual(values = c(th$series, "#e87ba4", "#6250d6"), name = NULL, drop = TRUE) +
				labs(title = regime_title(sprintf("%s: null p-value calibration (Bernoulli, ~ ., n = 200)", tools::toTitleCase(rt)), TRUE),
					subtitle = wrap_sub("P(p <= u) - u: 0 is perfect calibration; above 0 rejects too often at level u (dashed: u = 0.05). Shaded: simultaneous 95% band for uniform p-values (DKW, +-1.36 / sqrt(reps)); a curve leaving it anywhere is miscalibrated beyond Monte Carlo noise"),
					x = "u (square-root scale)", y = "P(p <= u) - u"),
				paste0("pvalue-curves-", rt), 9, 2 + 2 * ceiling(length(unique(r$cls)) / 4), sprintf("%s p-value curves", rt))
		}
	}
	conv_figures(rt, TRUE)
}

# Non-null treatment effect: coverage and bias against each class's true estimand
# value (calibrate_study_truths.R), then power by design.
md <- c(md, "### Non-null treatment effect (beta_T != 0)", "",
	"Coverage and bias are measured against the true value of each class's own estimand; cells with no true value",
	"(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.", "")
eff_fac <- function(x) factor(x, levels = c("power20", "power50", "power80"),
	labels = c("effect for 20% power", "effect for 50% power", "effect for 80% power"))
for (rt in c(intersect(RT_ORDER, rts), sort(setdiff(rts, RT_ORDER)))) {
	md <- c(md, sprintf("#### %s", tools::toTitleCase(rt)), "")
	if (!is.null(pw)) {
		x <- pw[pw$response_type == rt, ]
		x$status <- ifelse(!x$truth_available, "no true value", ifelse(x$fail_coverage %in% TRUE, "fail",
			ifelse(is.na(x$p_coverage), "too few results", "pass")))
		if (nrow(x)) {
			rank <- c(`no true value` = 0L, `too few results` = 1L, pass = 2L, fail = 3L)
			ov <- aggregate(status ~ cls + design_label, x, function(v) v[[which.max(rank[v])]])
			ov <- complete_overview(ov, names(STATUS_NONNULL))
			save_both(function(th) ggplot(ov, aes(design_label, cls, fill = status)) +
				geom_tile(colour = th$surface, linewidth = 0.8, show.legend = TRUE) +
				scale_fill_manual(values = c(STATUS_NONNULL, setNames(th$surface, NA_DESIGN)), drop = FALSE, name = "worst cell",
					guide = guide_legend(override.aes = list(colour = "#898781", linewidth = 0.5))) +
				labs(title = regime_title(sprintf("%s: coverage of the true estimand, every class on every design", tools::toTitleCase(rt)), FALSE),
					subtitle = wrap_sub("Worst status over the fast procedures, both formulas, all n and the three effects"), x = NULL, y = NULL) +
				scale_x_discrete(guide = guide_axis(angle = 45)),
				paste0("overview-nonnull-", rt), 9, 2.9 + 0.22 * length(unique(ov$cls)), sprintf("%s non-null overview", rt))
		}
		xc <- x[x$design_label == baseline_design & x$truth_available & is.finite(x$coverage) & x$n_ci > 0, ]
		if (nrow(xc)) {
			xc$row <- paste(xc$cls, xc$inf_procedure, xc$formula)
			xc$nf <- n_fac(xc$n_nominal)
			xc$ef <- eff_fac(xc$effect_label)
			xc$k <- round(xc$coverage * xc$n_ci)
			xc$lo <- cp_lo(xc$k, xc$n_ci)
			xc$hi <- cp_hi(xc$k, xc$n_ci)
			save_both(function(th) ggplot(xc, aes(coverage, row, colour = nf, shape = nf)) +
				geom_vline(xintercept = 0.95, colour = th$ink2, linewidth = 0.4, linetype = "dashed") +
				geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0, linewidth = 0.4,
					position = position_dodge(width = 0.6)) +
				geom_point(size = 2.2, position = position_dodge(width = 0.6)) + facet_wrap(~ ef, nrow = 1) +
				scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
				labs(title = regime_title(sprintf("%s: 95%% CI coverage of the true estimand, Bernoulli design", tools::toTitleCase(rt)), FALSE),
					subtitle = wrap_sub(sprintf("Nominal 95%% (dashed); bars are exact 95%% Monte Carlo intervals (%s replicates per cell)", rep_range(xc$n_ci)), 110),
					x = "coverage", y = NULL),
				paste0("coverage-nonnull-", rt), 11, 2 + 0.16 * length(unique(xc$row)), sprintf("%s non-null coverage", rt))
		}
	}
	if (!is.null(nb)) {
		bb <- nb[nb$response_type == rt & nb$design_label == baseline_design & is.finite(nb$bias_std) & nb$n_est > 1, ]
		if (nrow(bb)) {
			bb$row <- paste(bb$cls, bb$formula)
			bb$nf <- n_fac(bb$n_nominal)
			bb$ef <- eff_fac(bb$effect_label)
			bb$half <- stats::qt(0.975, pmax(bb$n_est - 1, 1)) * bb$bias_se / bb$bias_sd
			save_both(function(th) ggplot(bb, aes(bias_std, row, colour = nf, shape = nf)) +
				annotate("rect", xmin = -0.1, xmax = 0.1, ymin = -Inf, ymax = Inf, fill = th$mid) +
				geom_vline(xintercept = 0, colour = th$ink2, linewidth = 0.4) +
				geom_errorbar(aes(xmin = bias_std - half, xmax = bias_std + half), orientation = "y", width = 0,
					linewidth = 0.4, position = position_dodge(width = 0.6)) +
				geom_point(size = 2.2, position = position_dodge(width = 0.6)) + facet_wrap(~ ef, nrow = 1) +
				scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
				labs(title = regime_title(sprintf("%s: bias against the true estimand, Bernoulli design", tools::toTitleCase(rt)), FALSE),
					subtitle = wrap_sub(sprintf("Mean estimate minus the true value, in SDs of the estimate; bars are 95%% Monte Carlo intervals (%s estimates per cell); band = flag threshold (|bias| / SD < 0.1)", rep_range(bb$n_est)), 110),
					x = "bias / SD", y = NULL),
				paste0("bias-nonnull-", rt), 11, 2 + 0.2 * length(unique(bb$row)), sprintf("%s non-null bias", rt))
		}
	}
	if (!is.null(pw)) {
		base <- utils::read.csv(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))),
			"calibration_study_effects.csv"), stringsAsFactors = FALSE)
		bc <- sub("^Inference", "", base$baseline_class[base$response_type == rt])
		pp <- pw[pw$response_type == rt & pw$cls %in% bc & pw$formula == "~." & pw$inf_procedure == "wald" & pw$effect_label == "power50", ]
		if (nrow(pp)) {
			pp$nf <- n_fac(pp$n_nominal)
			pp$lo <- cp_lo(pp$rej, pp$n_p)
			pp$hi <- cp_hi(pp$rej, pp$n_p)
			pp$design_label <- stats::reorder(pp$design_label, pp$power, mean)
			save_both(function(th) ggplot(pp, aes(power, design_label, colour = nf, shape = nf)) +
				geom_vline(xintercept = 0.5, colour = th$ink2, linewidth = 0.4, linetype = "dashed") +
				geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0, linewidth = 0.4,
					position = position_dodge(width = 0.6)) +
				geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
				scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
				labs(title = regime_title(sprintf("%s: power by design (%s, Wald, ~ .)", tools::toTitleCase(rt), bc), FALSE),
					subtitle = wrap_sub(sprintf("Effect set for 50%% power on Bernoulli (dashed) at every n; same subjects and outcomes on every design; bars are exact 95%% Monte Carlo intervals (%s replicates per cell)", rep_range(pp$n_p))),
					x = "power", y = NULL),
				paste0("power-designs-", rt), 8, 2 + 0.22 * length(unique(pp$design_label)), sprintf("%s power by design", rt))
		}
	}
	conv_figures(rt, FALSE)
}
writeLines(md, fragment)

# ---- One figure per class (v1.0.5 TODO-203) ------------------------------------------------
if ("--class-figures" %in% args && conv_ok) {
	md_keep <- md
	EFFECT_LEVELS <- c("null", "power20", "power50", "power80")
	VERDICT_RANK <- c(slower = 4L, faster = 3L, consistent = 2L, undetermined = 1L, not_applicable = 0L)  # names() give the verdict
	METRICS <- c("size", "coverage", "bias")
	METRIC_TXT <- c(size = "size error", coverage = "coverage error", bias = "bias")
	cvp$err_ok <- is.finite(cvp$err) & cvp$err != 0 & is.finite(cvp$n_eff)
	classes <- unique(cv[c("response_type", "cls")])
	for (ci in seq_len(nrow(classes))) {
		rt <- classes$response_type[ci]; cl <- classes$cls[ci]
		cvx <- cv[cv$response_type == rt & cv$cls == cl, ]
		px <- cvp[cvp$response_type == rt & cvp$cls == cl & cvp$err_ok, ]
		if (!nrow(px)) next
		px$proc <- ifelse(px$inf_procedure == "(estimator)", "estimator", px$inf_procedure)
		cvx$proc <- ifelse(cvx$inf_procedure == "(estimator)", "estimator", cvx$inf_procedure)
		procs <- unique(px$proc)
		procs <- c(intersect(c(PROC_ORDER, setdiff(procs, c(PROC_ORDER, "estimator"))), procs), intersect("estimator", procs))
		# Panel titles "<procedure>, <metric>: <worst verdict>", three panels to a row.
		lev <- character(); blank <- 0L
		title_of <- function(pr, m) {
			v <- cvx$verdict[cvx$proc == pr & cvx$metric == m]
			if (!length(v)) return(NA_character_)
			sprintf("%s, %s: %s", pr, METRIC_TXT[[m]], sub("_", " ", names(which.max(VERDICT_RANK[v]))))
		}
		for (pr in procs) for (m in METRICS) {
			t <- title_of(pr, m)
			if (!is.na(t)) lev <- c(lev, t)
		}
		px$panel <- NA_character_
		for (pr in procs) for (m in METRICS) {
			i <- px$proc == pr & px$metric == m
			if (any(i)) px$panel[i] <- title_of(pr, m)
		}
		px <- px[!is.na(px$panel), ]
		px$panel <- factor(px$panel, levels = lev)
		px$effect <- factor(px$effect_label, levels = EFFECT_LEVELS)
		px$ae <- abs(px$err)
		px$line <- paste(px$cell_id)
		# Reference line per panel: slope -a (the registry's expected order of the panel's cells) through the median |error| at the smallest n_eff.
		refs <- do.call(rbind, lapply(split(px, px$panel, drop = TRUE), function(d) {
			cx <- cvx[cvx$cell_id %in% d$cell_id, ]
			a <- cx$expected_order[is.finite(cx$expected_order) & cx$expected_order > 0][1L]
			if (is.na(a)) return(NULL)
			data.frame(panel = d$panel[1L], a = a, icpt = log10(stats::median(d$ae[d$n_eff == min(d$n_eff)])) + a * log10(min(d$n_eff)))
		}))
		if (!is.null(refs)) refs$panel <- factor(as.character(refs$panel), levels = lev)
		nrow_f <- ceiling(length(lev) / 3)
		save_both(function(th) {
			g <- ggplot(px, aes(n_eff, ae, group = line, colour = effect)) +
				geom_line(linewidth = 0.35, alpha = 0.5) + geom_point(size = 0.9, alpha = 0.7) +
				facet_wrap(~ panel, ncol = 3, scales = "free_y") +
				scale_x_log10(breaks = c(50, 100, 200, 500, 1000)) + scale_y_log10() +
				scale_colour_manual(values = setNames(th$series, EFFECT_LEVELS), drop = FALSE, name = "effect") +
				labs(title = sprintf("%s: how the error shrinks with n", cl),
					subtitle = wrap_sub("One line per design and formula; absolute error on log-log axes. Dashed: the registry's expected slope, anchored at the median error at the smallest n_eff. Verdicts compare the fitted order with the expected one (consistent, slower, faster); undetermined = error below 2 Monte Carlo SE at fewer than two sizes.", 110),
					x = "effective n (log scale)", y = "|error| (log scale)") +
				theme(strip.text = element_text(size = 8, hjust = 0), panel.spacing = grid::unit(0.6, "lines"))
			if (!is.null(refs)) g <- g + geom_abline(data = refs, aes(slope = -a, intercept = icpt), colour = th$ink2, linewidth = 0.4,
				linetype = "dashed", inherit.aes = FALSE)
			g
		}, paste0("class-", cl), 11, 1.6 + 2.1 * nrow_f, sprintf("%s convergence of the error with n", cl))
	}
	md <- md_keep
}
