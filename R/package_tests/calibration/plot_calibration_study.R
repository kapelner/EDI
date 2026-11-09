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
# calibration_study_stats.R; this script sources nothing).
RT_ORDER <- c("continuous", "incidence", "count", "proportion", "survival", "ordinal")
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
		theme(axis.text.x = element_text(angle = 45, hjust = 1)),
		paste0("overview-", rt), 9, 2 + 0.22 * length(unique(ov$cls)), sprintf("%s overview", rt))

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
			r$inf_procedure <- factor(r$inf_procedure, levels = c("wald", "score", "lik_ratio", "gradient", "exact", "rand"))
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
				theme(axis.text.x = element_text(angle = 45, hjust = 1)),
				paste0("overview-nonnull-", rt), 9, 2 + 0.22 * length(unique(ov$cls)), sprintf("%s non-null overview", rt))
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
}
writeLines(md, fragment)
