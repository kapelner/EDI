#!/usr/bin/env Rscript
# Figures for the published calibration study (release_v1_2_0.md TODO-36), from
# analyze_calibration_study.R's tables. Each figure is written twice, <name>.png (light) and
# <name>-dark.png, and README fragment lines embed both with a GitHub <picture>
# element that follows the reader's theme.
#
# The fragment has two sections, each by response type (owner, 2026-11-09):
# "Null treatment effect" (beta_T = 0)
#   overview-<rt>.png          class x design grid: worst size / coverage status
#   size-<rt>.png              size per class x method x formula, Bernoulli, by n
#   coverage-<rt>.png          coverage, same layout
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
#   convergence-grid-<rt>.png / convergence-grid-nonnull-<rt>.png  class x design grid of verdicts per procedure
#
# Usage: Rscript R/package_tests/calibration/plot_calibration_study.R --summary-dir DIR \
#          --out-dir DIR [--fragment FILE] [--fig-prefix figures/]

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
		save_both(function(th) ggplot(ov, aes(design_label, cls, fill = verdict)) +
			geom_tile(colour = th$surface, linewidth = 0.5, show.legend = TRUE) + facet_wrap(~ panel) +
			scale_fill_manual(values = CONV_VERDICT, drop = FALSE, name = "verdict",
				guide = guide_legend(override.aes = list(colour = "#898781", linewidth = 0.5))) +
			labs(title = regime_title(sprintf("%s: convergence verdicts, every class on every design", tools::toTitleCase(rt)), null),
				subtitle = wrap_sub("Worst verdict over formulas, effects and the size / coverage metrics (slower > faster > consistent > undetermined > not applicable), by procedure; bias is a property of the estimator", 110),
				x = NULL, y = NULL) +
			scale_x_discrete(guide = guide_axis(angle = 45)),
			paste0("convergence-grid", sfx, "-", rt), 11, 3.9 + 0.2 * length(unique(ov$cls)) * ceiling(length(unique(ov$panel)) / 3), sprintf("%s convergence verdicts", rt))
	}
	invisible(NULL)
}

rts <- unique(s$response_type)
md <- c(md, "### Null treatment effect (beta_T = 0)", "")
for (rt in c(intersect(RT_ORDER, rts), sort(setdiff(rts, RT_ORDER)))) {
	x <- s[s$response_type == rt, ]
	md <- c(md, sprintf("#### %s", tools::toTitleCase(rt)), "")

	# Overview: worst status per class x design over methods, formulas and n.
	rank <- c(pass = 1L, `too few results` = 0L, accepted = 2L, fail = 3L)
	ov <- aggregate(status ~ cls + design_label, x, function(v) v[[which.max(rank[v])]])
	ov$status <- factor(ov$status, levels = names(STATUS))
	save_both(function(th) ggplot(ov, aes(design_label, cls, fill = status)) +
		# show.legend = TRUE: every status gets a swatch even when no cell has it (ggplot
		# otherwise draws an absent level's key empty); grey key borders keep the light
		# swatches visible on the page.
		geom_tile(colour = th$surface, linewidth = 0.8, show.legend = TRUE) +
		scale_fill_manual(values = STATUS, drop = FALSE, name = "worst cell",
			guide = guide_legend(override.aes = list(colour = "#898781", linewidth = 0.5))) +
		labs(title = regime_title(sprintf("%s: size and coverage, every class on every design", tools::toTitleCase(rt)), TRUE),
			subtitle = wrap_sub("Worst status over the fast procedures, both formulas and all n"), x = NULL, y = NULL) +
		scale_x_discrete(guide = guide_axis(angle = 45)),
		paste0("overview-", rt), 9, 2.9 + 0.22 * length(unique(ov$cls)), sprintf("%s overview", rt))

	xb <- x[x$design_label == baseline_design & is.finite(x$size), ]
	if (nrow(xb)) {
		xb$row <- paste(xb$cls, xb$inf_procedure, xb$formula)
		xb$nf <- n_fac(xb$n_nominal)
		xb$k <- round(xb$size * xb$n_p)
		xb$lo <- cp_lo(xb$k, xb$n_p)
		xb$hi <- cp_hi(xb$k, xb$n_p)
		save_both(function(th) ggplot(xb, aes(size, row, colour = nf, shape = nf)) +
			geom_vline(xintercept = 0.05, colour = th$ink2, linewidth = 0.4, linetype = "dashed") +
			geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0, linewidth = 0.4,
				position = position_dodge(width = 0.6)) +
			geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
			scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
			labs(title = regime_title(sprintf("%s: Type I error (size), Bernoulli design", tools::toTitleCase(rt)), TRUE),
				subtitle = wrap_sub(sprintf("Nominal 5%% (dashed); bars are exact 95%% Monte Carlo intervals (%s replicates per cell)", rep_range(xb$n_p))), x = "size", y = NULL),
			paste0("size-", rt), 8, 2 + 0.16 * length(unique(xb$row)), sprintf("%s size", rt))
	}
	xc <- x[x$design_label == baseline_design & is.finite(x$coverage), ]
	if (nrow(xc)) {
		xc$row <- paste(xc$cls, xc$inf_procedure, xc$formula)
		xc$nf <- n_fac(xc$n_nominal)
		xc$k <- round(xc$coverage * xc$n_ci)
		xc$lo <- cp_lo(xc$k, xc$n_ci)
		xc$hi <- cp_hi(xc$k, xc$n_ci)
		save_both(function(th) ggplot(xc, aes(coverage, row, colour = nf, shape = nf)) +
			geom_vline(xintercept = 0.95, colour = th$ink2, linewidth = 0.4, linetype = "dashed") +
			geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0, linewidth = 0.4,
				position = position_dodge(width = 0.6)) +
			geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
			scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
			labs(title = regime_title(sprintf("%s: 95%% CI coverage, Bernoulli design", tools::toTitleCase(rt)), TRUE),
				subtitle = wrap_sub(sprintf("Nominal 95%% (dashed); bars are exact 95%% Monte Carlo intervals (%s replicates per cell)", rep_range(xc$n_ci))), x = "coverage", y = NULL),
			paste0("coverage-", rt), 8, 2 + 0.16 * length(unique(xc$row)), sprintf("%s coverage", rt))
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
			save_both(function(th) ggplot(r, aes(u, dev, colour = inf_procedure)) +
				geom_hline(yintercept = 0, colour = th$ink2, linewidth = 0.4) +
				geom_vline(xintercept = 0.05, colour = th$muted, linewidth = 0.3, linetype = "dashed") +
				geom_line(linewidth = 0.6) + geom_point(size = 1) + facet_wrap(~ cls) +
				scale_x_sqrt(breaks = c(0.01, 0.05, 0.2, 0.5, 1)) +
				scale_colour_manual(values = c(th$series, "#e87ba4", "#6250d6"), name = NULL, drop = TRUE) +
				labs(title = regime_title(sprintf("%s: null p-value calibration (Bernoulli, ~ ., n = 200)", tools::toTitleCase(rt)), TRUE),
					subtitle = wrap_sub("P(p <= u) - u: 0 is perfect calibration; above 0 rejects too often at level u (dashed: u = 0.05)"),
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
			ov$status <- factor(ov$status, levels = names(STATUS_NONNULL))
			save_both(function(th) ggplot(ov, aes(design_label, cls, fill = status)) +
				geom_tile(colour = th$surface, linewidth = 0.8, show.legend = TRUE) +
				scale_fill_manual(values = STATUS_NONNULL, drop = FALSE, name = "worst cell",
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
