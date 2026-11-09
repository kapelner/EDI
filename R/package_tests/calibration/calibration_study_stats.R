# Mergeable sufficient statistics for the published calibration study
# (release_v1_2_0.md TODO-36). A campaign is ~800k replicates and ~40M result rows;
# no step ever re-reads them. Each shard reduces its own rows to per-cell counts
# and sums (cal_stats_from_rows), the publish step adds a wave's shards to the
# campaign's running totals (cal_stats_merge), and analyze_calibration_study.R
# works on the totals alone. No EDI needed.
#
# Two tables, both keyed by the cell plus effect_label:
#   tests  per (cell, method): reps, n_p, rej (p < 0.05), rej10 (p < 0.10), n_ci,
#          cov (CI holds the null value), cdf_<u> = #{p <= u} at CAL_STATS_U
#          (the p-value calibration curve), fit_secs.
#   est    per estimand cell (no method; one estimate per replicate): reps, n_est
#          (finite), n_below / n_above (estimate below / above the null value: a
#          sign test of median-unbiasedness, which unlike a median merges), sum_d,
#          sum_d2 (d = estimate - null value), null_value.

CAL_STATS_CELL <- c("response_type", "design", "prob_T", "inference_class", "formula", "n", "n_nominal", "effect_label")
CAL_STATS_U <- c(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9)
cal_stats_u_cols <- function() sprintf("cdf_%s", format(CAL_STATS_U, scientific = FALSE, drop0trailing = TRUE))

cal_stats_prepare <- function(d) {
	d$formula[is.na(d$formula)] <- ""
	if (!("prob_T" %in% names(d))) d$prob_T <- 0.5
	d$prob_T[is.na(d$prob_T)] <- 0.5
	if (!("effect_label" %in% names(d))) d$effect_label <- "null"
	if (!("n_nominal" %in% names(d))) d$n_nominal <- d$n
	d
}

cal_stats_from_rows <- function(d) {
	d <- cal_stats_prepare(d)
	ucols <- cal_stats_u_cols()
	tkey <- do.call(paste, c(d[c(CAL_STATS_CELL, "method")], sep = "\r"))
	tests <- do.call(rbind, lapply(split(seq_len(nrow(d)), tkey), function(idx) {
		x <- d[idx, ]
		p <- x$pval[is.finite(x$pval)]
		fin_ci <- is.finite(x$ci_a) & is.finite(x$ci_b)
		cdf <- vapply(CAL_STATS_U, function(u) sum(p <= u), numeric(1L))
		out <- data.frame(x[1L, c(CAL_STATS_CELL, "method")], reps = nrow(x), n_p = length(p), rej = sum(p < 0.05),
			rej10 = sum(p < 0.10), n_ci = sum(fin_ci),
			cov = sum(fin_ci & x$ci_a <= x$null_value & x$null_value <= x$ci_b, na.rm = TRUE),
			fit_secs = sum(x$fit_secs, na.rm = TRUE), stringsAsFactors = FALSE)
		out[ucols] <- as.list(cdf)
		out
	}))
	ekey <- do.call(paste, c(d[CAL_STATS_CELL], sep = "\r"))
	est <- do.call(rbind, lapply(split(seq_len(nrow(d)), ekey), function(idx) {
		x <- d[idx, ]
		x <- x[order(!is.finite(x$estimate)), ]
		x <- x[!duplicated(x$rep), ]
		dev <- x$estimate - x$null_value
		f <- is.finite(dev)
		data.frame(x[1L, CAL_STATS_CELL], reps = nrow(x), n_est = sum(f), n_below = sum(dev[f] < 0),
			n_above = sum(dev[f] > 0), sum_d = sum(dev[f]), sum_d2 = sum(dev[f]^2),
			null_value = x$null_value[which(is.finite(x$null_value))[1L]], stringsAsFactors = FALSE)
	}))
	rownames(tests) <- NULL
	rownames(est) <- NULL
	list(tests = tests, est = est)
}

# Adds tables of the same kind (NULLs allowed); sums every count / sum column,
# keeps the first null_value.
cal_stats_merge <- function(tabs, kind) {
	tabs <- Filter(function(x) !is.null(x) && nrow(x), tabs)
	if (!length(tabs)) return(NULL)
	all <- do.call(rbind, lapply(tabs, cal_stats_prepare))
	keys <- if (identical(kind, "tests")) c(CAL_STATS_CELL, "method") else CAL_STATS_CELL
	num <- setdiff(names(all), c(keys, "null_value"))
	k <- do.call(paste, c(all[keys], sep = "\r"))
	first <- !duplicated(k)
	out <- all[first, c(keys, if ("null_value" %in% names(all)) "null_value"), drop = FALSE]
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
