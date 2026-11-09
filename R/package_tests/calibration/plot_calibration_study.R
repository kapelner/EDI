#!/usr/bin/env Rscript
# Figures for the published calibration study (release_v1_2_0.md TODO-36), from
# analyze_calibration_study.R's tables. Each figure is written twice, <name>.png (light) and
# <name>-dark.png, and README fragment lines embed both with a GitHub <picture>
# element that follows the reader's theme.
#
#   overview-<rt>.png        class x design grid: worst size / coverage status
#   size-<rt>.png            size per class x method x formula, Bernoulli, by n
#   coverage-<rt>.png        coverage, same layout
#   null-bias-<rt>.png       null bias / SD, Bernoulli, by n
#   pvalue-curves-<rt>.png   P(p <= u) - u for null p-values (n = 200, Bernoulli, ~ .)
#   power-designs-<rt>.png   power of the baseline class at the 50% local alternative, by design and n
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
pw <- rd("power_summary.csv")
pc <- rd("pvalue_curves.csv")
if (is.null(s)) {
	# No results yet (the analysis wrote only its "No results yet" markdown): an
	# empty fragment, so the README renders and the publish step goes on.
	dir.create(dirname(fragment), recursive = TRUE, showWarnings = FALSE)
	writeLines(c("No figures yet.", ""), fragment)
	quit(save = "no", status = 0L)
}
for (x in list("s", "b", "pw", "pc")) if (!is.null(get(x))) {
	v <- get(x)
	v$formula[is.na(v$formula)] <- ""
	v$design_label <- paste0(sub("^Design(Fixed|SeqOneByOne)", "\\1:", v$design), ifelse(v$prob_T != 0.5, paste0(" @", v$prob_T), ""))
	v$design_label <- sub("^SeqOneByOne:", "Seq:", v$design_label)
	if (!("n_nominal" %in% names(v))) v$n_nominal <- v$n
	v$cls <- sub("^Inference", "", v$inf_class)
	assign(x, v)
}
s$status <- ifelse(s$fail_size | s$fail_coverage, "fail", ifelse(is.na(s$p_size) & is.na(s$p_coverage), "too few results",
	ifelse(nzchar(s$accepted), "accepted", "pass")))
n_levels <- sort(unique(s$n_nominal))
n_fac <- function(x) factor(x, levels = n_levels, labels = paste0("n = ", n_levels))
baseline_design <- "Fixed:Bernoulli"

for (rt in sort(unique(s$response_type))) {
	x <- s[s$response_type == rt, ]
	md <- c(md, sprintf("### %s", tools::toTitleCase(rt)), "")

	# Overview: worst status per class x design over methods, formulas and n.
	rank <- c(pass = 1L, `too few results` = 0L, accepted = 2L, fail = 3L)
	ov <- aggregate(status ~ cls + design_label, x, function(v) v[[which.max(rank[v])]])
	ov$status <- factor(ov$status, levels = names(STATUS))
	save_both(function(th) ggplot(ov, aes(design_label, cls, fill = status)) +
		geom_tile(colour = th$surface, linewidth = 0.8) +
		scale_fill_manual(values = STATUS, drop = FALSE, name = "worst cell") +
		labs(title = sprintf("%s: size and coverage, every class on every design", tools::toTitleCase(rt)),
			subtitle = "Worst status over the fast procedures, both formulas and all n", x = NULL, y = NULL) +
		theme(axis.text.x = element_text(angle = 45, hjust = 1)),
		paste0("overview-", rt), 9, 2 + 0.22 * length(unique(ov$cls)), sprintf("%s overview", rt))

	xb <- x[x$design_label == baseline_design & is.finite(x$size), ]
	if (nrow(xb)) {
		xb$row <- paste(xb$cls, xb$inf_procedure, xb$formula)
		xb$nf <- n_fac(xb$n_nominal)
		xb$se <- sqrt(xb$size * (1 - xb$size) / pmax(xb$n_p, 1))
		save_both(function(th) ggplot(xb, aes(size, row, colour = nf, shape = nf)) +
			geom_vline(xintercept = 0.05, colour = th$ink2, linewidth = 0.4, linetype = "dashed") +
			geom_errorbar(aes(xmin = pmax(size - 1.96 * se, 0), xmax = size + 1.96 * se), orientation = "y", width = 0, linewidth = 0.4,
				position = position_dodge(width = 0.6)) +
			geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
			scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
			labs(title = sprintf("%s: Type I error (size), Bernoulli design", tools::toTitleCase(rt)),
				subtitle = "Nominal 5% (dashed); bars are 95% Monte Carlo intervals", x = "size", y = NULL),
			paste0("size-", rt), 8, 2 + 0.16 * length(unique(xb$row)), sprintf("%s size", rt))
	}
	xc <- x[x$design_label == baseline_design & is.finite(x$coverage), ]
	if (nrow(xc)) {
		xc$row <- paste(xc$cls, xc$inf_procedure, xc$formula)
		xc$nf <- n_fac(xc$n_nominal)
		xc$se <- sqrt(xc$coverage * (1 - xc$coverage) / pmax(xc$n_ci, 1))
		save_both(function(th) ggplot(xc, aes(coverage, row, colour = nf, shape = nf)) +
			geom_vline(xintercept = 0.95, colour = th$ink2, linewidth = 0.4, linetype = "dashed") +
			geom_errorbar(aes(xmin = coverage - 1.96 * se, xmax = pmin(coverage + 1.96 * se, 1)), orientation = "y", width = 0, linewidth = 0.4,
				position = position_dodge(width = 0.6)) +
			geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
			scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
			labs(title = sprintf("%s: 95%% CI coverage, Bernoulli design", tools::toTitleCase(rt)),
				subtitle = "Nominal 95% (dashed); bars are 95% Monte Carlo intervals", x = "coverage", y = NULL),
			paste0("coverage-", rt), 8, 2 + 0.16 * length(unique(xc$row)), sprintf("%s coverage", rt))
	}
	if (!is.null(b)) {
		bb <- b[b$response_type == rt & b$design_label == baseline_design & is.finite(b$null_bias_std), ]
		if (nrow(bb)) {
			bb$row <- paste(bb$cls, bb$formula)
			bb$nf <- n_fac(bb$n_nominal)
			save_both(function(th) ggplot(bb, aes(null_bias_std, row, colour = nf, shape = nf)) +
				annotate("rect", xmin = -0.1, xmax = 0.1, ymin = -Inf, ymax = Inf, fill = th$mid) +
				geom_vline(xintercept = 0, colour = th$ink2, linewidth = 0.4) +
				geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
				scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
				labs(title = sprintf("%s: null bias, Bernoulli design", tools::toTitleCase(rt)),
					subtitle = "Mean estimate minus the null value, in SDs of the estimate; band = flag threshold (|bias| / SD < 0.1)",
					x = "null bias / SD", y = NULL),
				paste0("null-bias-", rt), 8, 2 + 0.2 * length(unique(bb$row)), sprintf("%s null bias", rt))
		}
	}
	if (!is.null(pw)) {
		base <- utils::read.csv(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))),
			"calibration_study_effects.csv"), stringsAsFactors = FALSE)
		bc <- sub("^Inference", "", base$baseline_class[base$response_type == rt])
		pp <- pw[pw$response_type == rt & pw$cls %in% bc & pw$formula == "~." & pw$inf_procedure == "wald" & pw$effect_label == "power50", ]
		if (nrow(pp)) {
			pp$nf <- n_fac(pp$n_nominal)
			pp$design_label <- stats::reorder(pp$design_label, pp$power, mean)
			save_both(function(th) ggplot(pp, aes(power, design_label, colour = nf, shape = nf)) +
				geom_vline(xintercept = 0.5, colour = th$ink2, linewidth = 0.4, linetype = "dashed") +
				geom_errorbar(aes(xmin = power - 1.96 * power_se, xmax = power + 1.96 * power_se), orientation = "y", width = 0, linewidth = 0.4,
					position = position_dodge(width = 0.6)) +
				geom_point(size = 2.2, position = position_dodge(width = 0.6)) +
				scale_colour_manual(values = th$series, name = NULL) + scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
				labs(title = sprintf("%s: power by design (%s, Wald, ~ .)", tools::toTitleCase(rt), bc),
					subtitle = "Effect set for 50% power on Bernoulli (dashed) at every n; same subjects and outcomes on every design",
					x = "power", y = NULL),
				paste0("power-designs-", rt), 8, 2 + 0.22 * length(unique(pp$design_label)), sprintf("%s power by design", rt))
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
				labs(title = sprintf("%s: null p-value calibration (Bernoulli, ~ ., n = 200)", tools::toTitleCase(rt)),
					subtitle = "P(p <= u) - u: 0 is perfect calibration; above 0 rejects too often at level u (dashed: u = 0.05)",
					x = "u (square-root scale)", y = "P(p <= u) - u"),
				paste0("pvalue-curves-", rt), 9, 2 + 2 * ceiling(length(unique(r$cls)) / 4), sprintf("%s p-value curves", rt))
		}
	}
}
writeLines(md, fragment)
