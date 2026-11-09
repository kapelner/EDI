# Mergeable sufficient statistics for the published calibration study
# (release_v1_2_0.md TODO-36). A campaign is ~800k replicates and ~40M result rows;
# no step ever re-reads them. Each shard reduces its own rows to per-cell counts
# and sums (cal_stats_from_rows), the publish step adds a wave's shards to the
# campaign's running totals (cal_stats_merge), and analyze_calibration_study.R
# works on the totals alone. No EDI needed.
#
# Two tables, both keyed by the cell plus effect_label:
#   tests  per (cell, inf_procedure): reps, n_p, rej (p < 0.05), rej10 (p < 0.10), n_ci,
#          cov (CI holds estimand_true; n_ci counts finite CIs with a known estimand_true), cdf_<u> = #{p <= u} at CAL_STATS_U
#          (the p-value calibration curve), fit_secs.
#   est    per estimand cell (no inf_procedure; one beta_T_hat per replicate): reps, n_est
#          (finite), n_below / n_above (beta_T_hat below / above estimand_true: a
#          sign test of median-unbiasedness, which unlike a median merges), sum_d,
#          sum_d2 (d = beta_T_hat - estimand_true), null_value, estimand_true.

# stage: "screen" (replicates 1..9999) or "confirm" (the two-stage gate's fresh
# replicates, CAL_STUDY_CONFIRM_REP0 + 1 on): kept apart so a confirmation is
# judged on its new replicates alone.
CAL_STATS_CELL <- c("response_type", "design", "prob_T", "inf_class", "formula", "n", "n_nominal", "effect_label", "stage")
CAL_STATS_U <- c(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9)
cal_stats_u_cols <- function() sprintf("cdf_%s", format(CAL_STATS_U, scientific = FALSE, drop0trailing = TRUE))

cal_stats_prepare <- function(d) {
	d$formula[is.na(d$formula)] <- ""
	if (!("prob_T" %in% names(d))) d$prob_T <- 0.5
	d$prob_T[is.na(d$prob_T)] <- 0.5
	if (!("effect_label" %in% names(d))) d$effect_label <- "null"
	if (!("n_nominal" %in% names(d))) d$n_nominal <- d$n
	if (!("stage" %in% names(d))) d$stage <- rep("screen", nrow(d))
	d$stage[is.na(d$stage)] <- "screen"
	d
}

# What coverage and bias are measured against: estimand_true (the null value under
# the null, the truth table's value at a power effect, NA where it has none);
# rows written before that column existed fall back to the null value.
cal_stats_target <- function(d) if ("estimand_true" %in% names(d)) d$estimand_true else d$null_value

cal_stats_from_rows <- function(d) {
	d <- cal_stats_prepare(d)
	ucols <- cal_stats_u_cols()
	tkey <- do.call(paste, c(d[c(CAL_STATS_CELL, "inf_procedure")], sep = "\r"))
	tests <- do.call(rbind, lapply(split(seq_len(nrow(d)), tkey), function(idx) {
		x <- d[idx, ]
		p <- x$pval[is.finite(x$pval)]
		target <- cal_stats_target(x)
		fin_ci <- is.finite(x$ci_beta_T_a) & is.finite(x$ci_beta_T_b) & is.finite(target)
		cdf <- vapply(CAL_STATS_U, function(u) sum(p <= u), numeric(1L))
		out <- data.frame(x[1L, c(CAL_STATS_CELL, "inf_procedure")], reps = nrow(x), n_p = length(p), rej = sum(p < 0.05),
			rej10 = sum(p < 0.10), n_ci = sum(fin_ci),
			cov = sum(fin_ci & x$ci_beta_T_a <= target & target <= x$ci_beta_T_b, na.rm = TRUE),
			fit_secs = sum(x$fit_secs, na.rm = TRUE), stringsAsFactors = FALSE)
		out[ucols] <- as.list(cdf)
		out
	}))
	ekey <- do.call(paste, c(d[CAL_STATS_CELL], sep = "\r"))
	est <- do.call(rbind, lapply(split(seq_len(nrow(d)), ekey), function(idx) {
		x <- d[idx, ]
		x <- x[order(!is.finite(x$beta_T_hat)), ]
		x <- x[!duplicated(x$rep), ]
		target <- cal_stats_target(x)
		dev <- x$beta_T_hat - target
		f <- is.finite(dev)
		data.frame(x[1L, CAL_STATS_CELL], reps = nrow(x), n_est = sum(f), n_below = sum(dev[f] < 0),
			n_above = sum(dev[f] > 0), sum_d = sum(dev[f]), sum_d2 = sum(dev[f]^2),
			null_value = x$null_value[which(is.finite(x$null_value))[1L]],
			estimand_true = target[which(is.finite(target))[1L]], stringsAsFactors = FALSE)
	}))
	rownames(tests) <- NULL
	rownames(est) <- NULL
	list(tests = tests, est = est)
}

# Adds tables of the same kind (NULLs allowed); sums every count / sum column,
# keeps the first null_value / estimand_true (constant within a cell).
cal_stats_merge <- function(tabs, kind) {
	tabs <- Filter(function(x) !is.null(x) && nrow(x), tabs)
	if (!length(tabs)) return(NULL)
	all <- do.call(rbind, lapply(tabs, cal_stats_prepare))
	keys <- if (identical(kind, "tests")) c(CAL_STATS_CELL, "inf_procedure") else CAL_STATS_CELL
	const <- intersect(c("null_value", "estimand_true"), names(all))
	num <- setdiff(names(all), c(keys, const))
	k <- do.call(paste, c(all[keys], sep = "\r"))
	first <- !duplicated(k)
	out <- all[first, c(keys, const), drop = FALSE]
	g <- factor(k, levels = k[first])
	for (col in num) out[[col]] <- as.numeric(tapply(all[[col]], g, sum, na.rm = TRUE))
	rownames(out) <- NULL
	out
}

cal_stats_read <- function(path) {
	if (!file.exists(path)) return(NULL)
	utils::read.csv(path, stringsAsFactors = FALSE, colClasses = c(formula = "character"), check.names = FALSE)
}
cal_stats_write <- function(x, path) {
	con <- gzfile(path, "w")
	on.exit(close(con))
	utils::write.csv(x, con, row.names = FALSE)
}
