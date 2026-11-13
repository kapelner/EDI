#!/usr/bin/env Rscript
# Convergence slopes of the published calibration study (v1.0.5 TODO-199,
# new_feature_plans/v1_0_5/calibration_convergence_slopes.md; consumer of the registry of
# TODO-193). For every cell of the study, across the sample sizes the campaign ran,
# how fast does the error shrink, and does that match the registry's expected order?
#
#   size error       size(n) - 0.05                 (tests: rej, n_p)
#   coverage error   0.95 - coverage(n)             (tests: cov, n_ci), null and at each power effect
#   bias             mean(beta_hat - truth)         (est: sum_d, sum_d2, n_est), null and non-null
#
# Two estimates per cell and metric (the x-axis is log n_eff, n_eff from the
# registry's rule, nominal at the design's allocation; see "n_eff" below):
#   1. loglog_*: the log-log regression the owner asked for, weighted least squares of
#      log|error| on log n_eff (weights from the delta-method variance of log|error|);
#      slope < 0 is convergence, the expected slope is -expected_order. Caveat, always
#      true: with a Monte Carlo noise floor (1,000 replicates: size SE about 0.007,
#      while an O(1/n) excess at n = 1000 is about 0.001) |error| at large n is mostly
#      noise, which biases this slope toward 0, and a sign change makes the log
#      undefined. Reported, never the verdict.
#   2. a_hat / a_ci_*: the noise-aware power-law fit (the verdict). Size: rej ~
#      Binomial(n_p, 0.05 + d * (n_eff / n_ref)^-a); coverage likewise around 0.95;
#      bias: normal with its SE, bias(n) = d * (n_eff / n_ref)^-b; maximum likelihood over
#      (d, a), a in [0, 5], profile-likelihood 95% CI for a, and a likelihood-ratio test
#      of a free vs a fixed at the registry's expected order (lr_p).
# A fit that errors for one cell is that cell's verdict `undetermined` (note "power-law fit error"), never a stopped run.
# Verdict: consistent (the expected order is in the CI, lr_p >= 0.05), slower (rejected,
# a_hat below the expected order: the warning case), faster, undetermined (the error is
# not measurable, |error| < 2 Monte Carlo SE, at fewer than 2 sizes, or fewer than 2
# sizes ran), not_applicable (finite-sample procedure, expected order Inf / 0 / unknown
# in the registry). Reported here; the gate (analyze_calibration_study.R, TODO-200) turns a `slower` verdict
# with a significant large-n excess into a rate-check failure. `basis` is the registry's basis for the
# expected order (size_order for size / coverage, bias_basis for bias), so an
# "assumed_default" expectation is visible.
#
# n_eff: the registry names a rule per triple. Stats do not carry n_events, n_nonzero,
# n_clusters or n_strata, so n_eff_flag records what was used: "nominal" (n, n/2 pairs,
# n * min(p, 1-p) smaller arm; n/2 for pairs-plus-reservoir is a lower bound), or
# "proxy_n" (n used in place of the data-dependent count). Every rule is proportional
# to n, so the slope in n_eff equals the slope in n; for proxy_n the true count may
# scale differently with n (e.g. events with the censoring rate), so read such slopes
# with that in mind.
#
# Bias is a property of the estimator, not of an inference procedure: bias rows have
# inf_procedure "(estimator)" and are resolved against the registry as procedure "wald".
#
# Provisional (v1.0.5 TODO-203): with a plan (plan.csv of the campaign, --plan; default <stats-dir>/../plan.csv, from
# plan_calibration_study.R) a row is provisional until its class is complete for the row's effect group (every screening
# unit of the class under the null for null rows, at the power effects for the others, has all its replicates), because
# campaigns run class by class. Without a plan, or with --final, as before: provisional unless --final.
#
# Usage: Rscript R/package_tests/calibration/convergence_calibration_study.R --stats-dir DIR \
#          --out-dir DIR [--final] [--plan FILE]
# Writes convergence_summary.csv (one row per cell x metric x effect), convergence_points.csv
# (one row per cell x n), convergence_summary.md. Base R only; no EDI needed (the publish job
# has none): the registry is sourced from the checkout.

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

CONV_A_MAX <- 5
CONV_A_STEP <- 0.1
CONV_MIN_FINITE <- 30L
CONV_Z <- 2
CONV_LEVEL <- c(size = 0.05, coverage = 0.95)

# ---- n_eff ----------------------------------------------------------------------------

conv_n_eff <- function(rule, n, prob_T) {
	ne <- n
	pairs <- rule %in% c("n_pairs", "n_pairs_plus_reservoir")
	ne[pairs] <- n[pairs] / 2
	arm <- rule == "n_min_arm"
	ne[arm] <- n[arm] * pmin(prob_T[arm], 1 - prob_T[arm])
	ne
}
conv_n_eff_flag <- function(rule) {
	ifelse(rule %in% c("n", "n_pairs", "n_min_arm"), "nominal",
		ifelse(rule == "n_pairs_plus_reservoir", "nominal (pairs only: lower bound)", "proxy_n"))
}

# ---- registry expectation per row (shared with the gate) ------------------------------

# Expectation and nominal n_eff of each row, from the registry (inference_convergence_expectation(),
# TODO-193) and the n_eff rule above. `design` is the plain design class name (the `@prob_T=`
# label is built here). A procedure label the regime registry does not know gets NA fields
# (regime NA); n_eff then falls back to n. Columns: regime, size_order, bias_order, n_eff_rule,
# regularity, basis_size, basis_bias, reference_size, reference_bias, n_eff, n_eff_flag.
# Shared by the gate (analyze_calibration_study.R), so both read one n_eff computation.
conv_expectations <- function(design, prob_T, inf_class, inf_procedure, n_nominal) {
	design_label <- ifelse(prob_T != 0.5, paste0(design, "@prob_T=", prob_T), design)
	registered <- inf_procedure %in% names(EDI_INFERENCE_PROCEDURE_REGIME)
	tk <- paste(design_label, inf_class, inf_procedure, sep = "\r")
	u <- !duplicated(tk) & registered
	ex <- if (any(u)) inference_convergence_expectation(design_label[u], inf_class[u], inf_procedure[u]) else NULL
	ex_i <- match(tk, tk[u])
	ex_i[!registered] <- NA_integer_
	g <- function(col) if (is.null(ex)) rep(NA, length(tk)) else ex[[col]][ex_i]
	out <- data.frame(regime = as.character(g("regime")), size_order = as.numeric(g("size_order")), bias_order = as.numeric(g("bias_order")),
		n_eff_rule = as.character(g("n_eff")), regularity = as.character(g("regularity")),
		basis_size = as.character(g("basis")), basis_bias = as.character(g("bias_basis")),
		reference_size = as.character(g("reference")), reference_bias = as.character(g("bias_reference")),
		stringsAsFactors = FALSE)
	out$n_eff_rule[is.na(out$n_eff_rule)] <- "n"
	out$n_eff <- conv_n_eff(out$n_eff_rule, n_nominal, prob_T)
	out$n_eff_flag <- conv_n_eff_flag(out$n_eff_rule)
	out
}

# ---- power-law fit ----------------------------------------------------------------------

# Log-likelihood profiled over the offset d for a fixed order a. kind "binom": y counts of m
# trials around `base`, p = base + d x; kind "normal": y estimates with standard errors m.
# x = (n_eff / smallest n_eff)^-a, so d is the error at the smallest n.
conv_profile_at <- function(a, neff, y, m, base, kind) {
	x <- (neff / min(neff))^(-a)
	if (kind == "binom") {
		eps <- 1e-9
		lo <- max((eps - base) / x)
		hi <- min((1 - eps - base) / x)
		o <- stats::optimize(function(d) {
			p <- base + d * x
			sum(y * log(p) + (m - y) * log1p(-p))
		}, c(lo, hi), maximum = TRUE, tol = 1e-12)
		list(ll = o$objective, d = o$maximum)
	} else {
		w <- 1 / m^2
		d <- sum(w * x * y) / sum(w * x^2)
		list(ll = -0.5 * sum(w * (y - d * x)^2), d = d)
	}
}

# Maximum likelihood over (d, a), profile CI for a, LR test of a = a0. NULL when it cannot
# be fitted (fewer than 2 sizes, non-finite inputs).
conv_fit <- function(neff, y, m, base, kind, a0) {
	ok <- is.finite(neff) & is.finite(y) & is.finite(m) & neff > 0
	if (sum(ok) < 2L || length(unique(neff[ok])) < 2L) return(NULL)
	neff <- neff[ok]; y <- y[ok]; m <- m[ok]
	prof <- function(a) conv_profile_at(a, neff, y, m, base, kind)$ll
	grid <- seq(0, CONV_A_MAX, by = CONV_A_STEP)
	pl <- vapply(grid, prof, numeric(1L))
	if (!all(is.finite(pl))) return(NULL)
	i <- which.max(pl)
	o <- stats::optimize(prof, c(grid[max(i - 1L, 1L)], grid[min(i + 1L, length(grid))]), maximum = TRUE, tol = 1e-8)
	a_hat <- if (o$objective > pl[i]) o$maximum else grid[i]
	ll_max <- max(o$objective, pl[i])
	cut <- ll_max - stats::qchisq(0.95, 1) / 2
	crossing <- function(lo, hi) stats::uniroot(function(a) prof(a) - cut, c(lo, hi), tol = 1e-6)$root
	below <- which(pl < cut)
	lo_idx <- below[below < i]
	hi_idx <- below[below > i]
	a_lo <- if (length(lo_idx)) crossing(grid[max(lo_idx)], grid[max(lo_idx) + 1L]) else 0
	a_hi <- if (length(hi_idx)) crossing(grid[min(hi_idx) - 1L], grid[min(hi_idx)]) else Inf
	lr <- NA_real_
	lr_p <- NA_real_
	if (is.finite(a0) && a0 >= 0) {
		lr <- max(0, 2 * (ll_max - prof(a0)))
		lr_p <- stats::pchisq(lr, 1, lower.tail = FALSE)
	}
	d_hat <- conv_profile_at(a_hat, neff, y, m, base, kind)$d
	list(a_hat = a_hat, a_lo = a_lo, a_hi = a_hi, d_hat = d_hat, n_ref = min(neff), lr = lr, lr_p = lr_p)
}

# Weighted log-log regression of log|err| on log n_eff, weights 1 / var(log|err|) with the
# delta-method var = (se / err)^2; the SE is the fixed-weight one (no residual scaling, so
# it exists with 2 points). NULL with fewer than 2 nonzero errors at distinct n_eff.
conv_loglog <- function(neff, err, se) {
	ok <- is.finite(neff) & is.finite(err) & is.finite(se) & err != 0 & se > 0
	if (sum(ok) < 2L || length(unique(neff[ok])) < 2L) return(NULL)
	lx <- log(neff[ok]); ly <- log(abs(err[ok])); w <- (err[ok] / se[ok])^2
	xb <- sum(w * lx) / sum(w)
	sxx <- sum(w * (lx - xb)^2)
	slope <- sum(w * (lx - xb) * (ly - sum(w * ly) / sum(w))) / sxx
	list(slope = slope, se = 1 / sqrt(sxx), n = sum(ok), sign_change = length(unique(sign(err[ok]))) > 1L)
}

# ---- one cell x metric -> one summary row -------------------------------------------

# pts: data.frame(n_nominal, n_eff, err, se0 [SE of the error if there were none], se [SE for
# the log-log weights], y, m) ordered by n. `exp`: one row of the registry's resolver output;
# `kind`/`base`: the likelihood. Returns a named list (one row).
conv_cell_row <- function(pts, metric, kind, base, regime, expected, expected_basis, note0 = "") {
	pts <- pts[order(pts$n_eff), ]
	n_pts <- nrow(pts)
	z <- abs(pts$err) / pts$se0
	n_meas <- sum(z > CONV_Z, na.rm = TRUE)
	last <- n_pts
	row <- list(n_values = paste(pts$n_nominal, collapse = ";"), n_eff_values = paste(signif(pts$n_eff, 6), collapse = ";"),
		errors = paste(signif(pts$err, 5), collapse = ";"), ses = paste(signif(pts$se0, 4), collapse = ";"),
		n_points = n_pts, n_measurable = n_meas, err_largest_n = pts$err[last], mc_se_largest_n = pts$se0[last],
		noise_dominated_largest_n = abs(pts$err[last]) < CONV_Z * pts$se0[last])
	empty <- list(loglog_slope = NA_real_, loglog_slope_se = NA_real_, loglog_a = NA_real_, loglog_n_points = 0L,
		loglog_sign_change = NA, a_hat = NA_real_, a_ci_lo = NA_real_, a_ci_hi = NA_real_, err_at_n_ref = NA_real_,
		n_ref = NA_real_, lr_stat = NA_real_, lr_p = NA_real_)
	row <- c(row, empty)
	finish <- function(verdict, note) {
		row$verdict <- verdict
		row$note <- trimws(paste(note0, note))
		row
	}
	if (identical(regime, "finite_sample") || (is.finite(expected) == FALSE && !is.na(expected)))
		return(finish("not_applicable", if (metric == "bias") "unbiased by construction in the registry (order Inf)" else
			"finite-sample procedure: no asymptotic rate"))
	if (is.na(expected)) note0 <- trimws(paste(note0, "expected order unknown in the registry (basis unknown); fit reported, no verdict"))
	if (!is.na(expected) && expected == 0)
		return(finish("not_applicable", sprintf("expected O(1) error (design mismatch): the level is err_largest_n = %s", signif(pts$err[last], 4))))
	ll <- conv_loglog(pts$n_eff, pts$err, pts$se)
	if (!is.null(ll)) {
		row$loglog_slope <- ll$slope; row$loglog_slope_se <- ll$se; row$loglog_a <- -ll$slope
		row$loglog_n_points <- ll$n; row$loglog_sign_change <- ll$sign_change
	}
	if (n_pts < 2L) return(finish("undetermined", "only one sample size so far"))
	if (n_meas < 2L) return(finish("undetermined", sprintf("error measurable (>= %g MC SE) at %d size(s), need 2", CONV_Z, n_meas)))
	fit <- tryCatch(conv_fit(pts$n_eff, pts$y, pts$m, base, kind, if (is.na(expected)) NA_real_ else expected),
		error = function(e) structure(list(), class = "conv_fit_error", msg = conditionMessage(e)))
	if (inherits(fit, "conv_fit_error")) return(finish("undetermined", paste("power-law fit error:", attr(fit, "msg"))))
	if (is.null(fit)) return(finish("undetermined", "power-law fit failed"))
	sgn <- if (metric == "coverage") -1 else 1   # coverage error = 0.95 - coverage = -d
	row$a_hat <- fit$a_hat; row$a_ci_lo <- fit$a_lo; row$a_ci_hi <- fit$a_hi
	row$err_at_n_ref <- sgn * fit$d_hat; row$n_ref <- fit$n_ref; row$lr_stat <- fit$lr; row$lr_p <- fit$lr_p
	if (is.na(expected)) return(finish("not_applicable", "expected order unknown in the registry (basis unknown); fit reported, no verdict"))
	verdict <- if (fit$lr_p >= 0.05) "consistent" else if (fit$a_hat < expected) "slower" else "faster"
	finish(verdict, if (identical(expected_basis, "assumed_default") && verdict != "consistent")
		"expectation is an assumed default: a mismatch may mean the default is wrong, not the procedure" else "")
}

# ---- main -----------------------------------------------------------------------------

conv_main <- function(args) {
	arg_value <- function(flag, default = NULL) {
		i <- match(flag, args)
		if (is.na(i) || i == length(args)) default else args[[i + 1L]]
	}
	script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
	source(file.path(script_dir, "calibration_study_stats.R"))
	source(file.path(script_dir, "calibration_study_plan_common.R"))
	# The registry, read from the checkout: this job runs without EDI installed.
	source(file.path(script_dir, "..", "..", "EDI", "R", "inference_procedure_regime.R"))
	stats_dir <- arg_value("--stats-dir")
	out_dir <- arg_value("--out-dir")
	final <- "--final" %in% args
	dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
	tests <- cal_stats_prepare(cal_stats_read(file.path(stats_dir, "tests.csv.gz")))
	est <- cal_stats_prepare(cal_stats_read(file.path(stats_dir, "est.csv.gz")))
	if (is.null(tests) || !nrow(tests)) {
		writeLines(c("## Convergence slopes", "", "No results yet.", ""), file.path(out_dir, "convergence_summary.md"))
		return(invisible(NULL))
	}
	# Class completeness from the plan (see the header), computed before the stage filter.
	plan_path <- arg_value("--plan", file.path(dirname(normalizePath(stats_dir, mustWork = FALSE)), "plan.csv"))
	class_prog <- NULL
	if (file.exists(plan_path)) {
		plan <- read_csv_fast(plan_path, stringsAsFactors = FALSE)
		plan$key <- cal_plan_key(plan$response_type, plan$design, plan$n, plan$effect, plan$inf_class)
		plan$rep_from <- 1L
		class_prog <- cal_class_progress(cal_unit_progress(plan, tests))
	}
	tests <- tests[tests$stage == "screen", ]
	est <- if (is.null(est)) NULL else est[est$stage == "screen", ]

	# Point table: one row per cell x metric x effect x n.
	cellc <- c("response_type", "design", "prob_T", "inf_class", "formula", "inf_procedure")
	mk <- function(d, metric, err, se0, y, m, base, kind) {
		if (!nrow(d)) return(NULL)
		data.frame(d[c(cellc, "effect_label", "n_nominal")], metric = metric, kind = kind, base = base,
			err = err, se0 = se0, y = y, m = m, stringsAsFactors = FALSE)
	}
	pt <- NULL
	t_s <- tests[tests$effect_label == "null" & tests$n_p >= CONV_MIN_FINITE, ]
	pt <- rbind(pt, mk(t_s, "size", t_s$rej / t_s$n_p - CONV_LEVEL[["size"]],
		sqrt(CONV_LEVEL[["size"]] * (1 - CONV_LEVEL[["size"]]) / t_s$n_p), t_s$rej, t_s$n_p, CONV_LEVEL[["size"]], "binom"))
	t_c <- tests[tests$n_ci >= CONV_MIN_FINITE, ]
	pt <- rbind(pt, mk(t_c, "coverage", CONV_LEVEL[["coverage"]] - t_c$cov / t_c$n_ci,
		sqrt(CONV_LEVEL[["coverage"]] * (1 - CONV_LEVEL[["coverage"]]) / t_c$n_ci), t_c$cov, t_c$n_ci, CONV_LEVEL[["coverage"]], "binom"))
	if (!is.null(est) && nrow(est)) {
		e <- est[est$n_est >= CONV_MIN_FINITE, ]
		e$inf_procedure <- "(estimator)"
		bias <- e$sum_d / e$n_est
		sd <- sqrt(pmax(e$sum_d2 - e$n_est * bias^2, 0) / (e$n_est - 1))
		se <- sd / sqrt(e$n_est)
		keep <- is.finite(se) & se > 0
		e <- e[keep, ]
		pt <- rbind(pt, mk(e, "bias", bias[keep], se[keep], bias[keep], se[keep], 0, "normal"))
	}
	if (is.null(pt) || !nrow(pt)) {
		writeLines(c("## Convergence slopes", "", "No cell has enough results yet.", ""), file.path(out_dir, "convergence_summary.md"))
		return(invisible(NULL))
	}
	# Standard error of the observed error for the log-log weights (continuity-corrected for counts).
	pt$se <- pt$se0
	bin <- pt$kind == "binom"
	p_obs <- (pt$y[bin] + 0.5) / (pt$m[bin] + 1)
	pt$se[bin] <- sqrt(p_obs * (1 - p_obs) / pt$m[bin])

	# Registry expectation per (design label, class, procedure).
	pt$proc_resolve <- ifelse(pt$inf_procedure == "(estimator)", "wald", pt$inf_procedure)
	ex <- conv_expectations(pt$design, pt$prob_T, pt$inf_class, pt$proc_resolve, pt$n_nominal)
	pt <- cbind(pt, ex[setdiff(names(ex), names(pt))])

	# One summary row per cell x metric x effect.
	ck <- do.call(paste, c(pt[c(cellc, "effect_label", "metric")], sep = "\r"))
	groups <- split(seq_len(nrow(pt)), factor(ck, levels = unique(ck)))
	rows <- vector("list", length(groups))
	for (gi in seq_along(groups)) {
		ix <- groups[[gi]]
		p1 <- pt[ix[1L], ]
		is_bias <- p1$metric == "bias"
		pts <- pt[ix, c("n_nominal", "n_eff", "err", "se0", "se", "y", "m")]
		pts <- pts[!duplicated(pts$n_nominal), ]
		if (is.na(p1$regime)) {
			r <- conv_cell_row(pts, p1$metric, p1$kind, p1$base, "finite_sample", NA_real_, NA_character_)
			r$verdict <- "not_applicable"; r$note <- "procedure not in the regime registry"
		} else {
			expected <- if (is_bias) p1$bias_order else p1$size_order
			if (!is_bias && identical(p1$regime, "finite_sample")) expected <- Inf
			r <- conv_cell_row(pts, p1$metric, p1$kind, p1$base, p1$regime, expected,
				if (is_bias) p1$basis_bias else p1$basis_size)
		}
		meta <- list(cell_id = gi, response_type = p1$response_type, design = p1$design, prob_T = p1$prob_T,
			inf_class = p1$inf_class, formula = p1$formula, inf_procedure = p1$inf_procedure, effect_label = p1$effect_label,
			metric = p1$metric, regime = if (is.na(p1$regime)) NA_character_ else p1$regime,
			expected_order = if (is_bias) p1$bias_order else if (identical(p1$regime, "finite_sample")) Inf else p1$size_order,
			basis = if (is_bias) p1$basis_bias else p1$basis_size,
			regularity = p1$regularity, n_eff_rule = p1$n_eff_rule, n_eff_flag = conv_n_eff_flag(p1$n_eff_rule),
			reference = if (is_bias) p1$reference_bias else p1$reference_size)
		rows[[gi]] <- c(meta, r)
	}
	flat <- lapply(rows, function(r) { r[vapply(r, is.null, logical(1L))] <- NA; as.data.frame(r, stringsAsFactors = FALSE) })
	summ <- do.call(rbind, flat)
	summ$provisional <- !final
	if (!final && !is.null(class_prog)) {
		cs <- class_prog[match(paste(summ$response_type, summ$inf_class), paste(class_prog$response_type, class_prog$inf_class)), ]
		phase_status <- ifelse(summ$effect_label == "null", cs$null_status, cs$nonnull_status)
		summ$provisional <- !(phase_status %in% "complete")
	}
	pt$cell_id <- rep(seq_along(groups), lengths(groups))
	utils::write.csv(summ, file.path(out_dir, "convergence_summary.csv"), row.names = FALSE)
	utils::write.csv(pt[c("cell_id", "response_type", "design", "prob_T", "inf_class", "formula", "inf_procedure", "effect_label",
		"metric", "n_nominal", "n_eff", "err", "se0")], file.path(out_dir, "convergence_points.csv"), row.names = FALSE)
	writeLines(conv_markdown(summ, !any(summ$provisional)), file.path(out_dir, "convergence_summary.md"))
	invisible(summ)
}

# Headline text for the campaign README and the job log.
conv_markdown <- function(summ, final) {
	vc <- table(factor(summ$verdict, levels = c("consistent", "slower", "faster", "undetermined", "not_applicable")))
	multi <- summ[summ$n_points >= 2L, ]
	md <- c("## Convergence slopes", "",
		sprintf("%s%d cell-metrics: %s. %d of them ran at two or more sample sizes.", if (final) "" else "**Provisional.** ", nrow(summ),
			paste(sprintf("%d %s", vc, names(vc)), collapse = ", "), nrow(multi)),
		"",
		paste("Each asymptotic cell's error (size - 5%, 95% - coverage, bias) is fitted against n_eff with a noise-aware power law",
			"(binomial / normal likelihood, 95% profile CI for the order `a`) and compared with the registry's expected order",
			"(`consistent`, `slower`, `faster`; `undetermined` = the error is below 2 Monte Carlo SE at fewer than 2 sizes). The",
			"log-log regression of |error| on n_eff is in the table too (`loglog_slope`, expected `-expected_order`), but it is biased",
			"toward 0 wherever |error| is dominated by Monte Carlo noise: with 1,000 replicates the size SE is about 0.007, while an O(1/n)",
			"excess at n = 1000 is about 0.001. Reported, not gated."), "")
	if (nrow(multi) == 0L) md <- c(md, "No cell has run at two sample sizes yet, so every verdict is `undetermined` or `not_applicable`.", "")
	sl <- summ[summ$verdict == "slower", ]
	if (nrow(sl)) {
		sl <- sl[order(sl$lr_p), ]
		shown <- utils::head(sl, 25L)
		fmt <- function(x) ifelse(is.finite(x), formatC(x, digits = 2, format = "f"), ifelse(is.na(x), "NA", "Inf"))
		md <- c(md, sprintf("### Cells converging slower than expected (%d%s)", nrow(sl), if (nrow(sl) > nrow(shown)) sprintf(", %d shown", nrow(shown)) else ""), "",
			"| class | design | procedure | formula | metric | effect | expected | a (95% CI) | basis |", "|---|---|---|---|---|---|---|---|---|",
			sprintf("| %s | %s | %s | `%s` | %s | %s | %s | %s (%s, %s) | %s |", sub("^Inference", "", shown$inf_class),
				sub("^Design", "", shown$design), shown$inf_procedure, shown$formula, shown$metric, shown$effect_label,
				fmt(shown$expected_order), fmt(shown$a_hat), fmt(shown$a_ci_lo), fmt(shown$a_ci_hi), shown$basis), "")
	}
	md
}

if (sys.nframe() == 0L) {
	# An error here is a bug in the check, not a calibration result (v1.0.5 TODO-200 failure
	# contract): fit failures are caught per cell and recorded as `undetermined`, so anything
	# that reaches this point stops the analyze job's step.
	conv_main(commandArgs(TRUE))
	quit(save = "no", status = 0L)
}
