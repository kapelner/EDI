# Covariate balance of the calibration study's assignments (owner, 2026-11-17). For one replicate (its covariates X
# and assignment w) cal_balance_metrics() gives the canonical imbalance measures (MatchIt / cobalt; Morgan & Rubin
# 2012), on the p = 5 study covariates with x4, x5 as 0/1:
#   mean_abs_smd, max_abs_smd      |mean_T - mean_C| / sqrt((s2_T + s2_C) / 2), mean and max over covariates
#   mean_abs_log_vr, max_abs_log_vr |log(s2_T / s2_C)| (variance ratio on the log scale, 0 = equal spread)
#   mean_ks, max_ks                Kolmogorov-Smirnov: largest gap between the arms' empirical CDFs
#   mahal_p                        Mahalanobis M = d' [S (1/n_T + 1/n_C)]^-1 d over p; about chi2_p / p (mean 1)
#                                  under complete randomization
#   energy                         energy distance between the arms on covariates scaled by their pooled SD
# Every design of a replicate sees the same X (cal_study_seed() depends on response type, n and rep only), so the
# designs are compared on identical subjects.
#
# Mergeable per-unit statistics (cal_balance_stats()): reps, sum_<m> and sum2_<m> per metric (mean and SD), and
# counts le_<m>_<u> of replicates with the metric <= u on a log grid for mahal_p and max_abs_smd (median and 95th
# percentile, 12% relative resolution). cal_balance_merge() adds tables; cal_balance_summary() turns them into
# means, SDs and quantiles. Written by the shard runner (stats/balance.csv.gz, merged per wave) and by
# balance_calibration_study.R (a campaign's one-off backfill, balance/backfill.csv.gz).

CAL_BALANCE_METRICS <- c("mean_abs_smd", "max_abs_smd", "mean_abs_log_vr", "max_abs_log_vr", "mean_ks", "max_ks",
	"mahal_p", "energy")
CAL_BALANCE_Q_METRICS <- c("mahal_p", "max_abs_smd")
CAL_BALANCE_GRID <- signif(10^seq(-5, 1.5, by = 0.05), 4)
CAL_BALANCE_KEYS <- c("response_type", "design", "prob_T", "n", "n_nominal", "effect_label")

cal_balance_numeric_X <- function(X) {
	as.matrix(data.frame(lapply(X, function(v) if (is.factor(v)) as.integer(v) - 1L else as.numeric(v))))
}

cal_balance_metrics <- function(X, w) {
	Z <- cal_balance_numeric_X(X)
	t <- as.integer(w) == 1L
	na <- stats::setNames(as.list(rep(NA_real_, length(CAL_BALANCE_METRICS))), CAL_BALANCE_METRICS)
	if (sum(t) < 2L || sum(!t) < 2L) return(as.data.frame(na))
	mT <- colMeans(Z[t, , drop = FALSE]); mC <- colMeans(Z[!t, , drop = FALSE])
	vT <- apply(Z[t, , drop = FALSE], 2L, stats::var); vC <- apply(Z[!t, , drop = FALSE], 2L, stats::var)
	sd_p <- sqrt((vT + vC) / 2)
	smd <- ifelse(sd_p > 0, (mT - mC) / sd_p, 0)
	lvr <- ifelse(vT > 0 & vC > 0, log(vT / vC), NA_real_)
	ks <- vapply(seq_len(ncol(Z)), function(j) {
		v <- sort(unique(Z[, j]))
		max(abs(stats::ecdf(Z[t, j])(v) - stats::ecdf(Z[!t, j])(v)))
	}, numeric(1L))
	d <- mT - mC
	S <- stats::cov(Z) * (1 / sum(t) + 1 / sum(!t))
	M <- tryCatch(as.numeric(crossprod(d, solve(S, d))), error = function(e) NA_real_)
	sdz <- apply(Z, 2L, stats::sd); sdz[sdz == 0] <- 1
	D <- as.matrix(stats::dist(sweep(Z, 2L, sdz, "/")))
	energy <- 2 * mean(D[t, !t]) - mean(D[t, t]) - mean(D[!t, !t])
	data.frame(mean_abs_smd = mean(abs(smd)), max_abs_smd = max(abs(smd)),
		mean_abs_log_vr = mean(abs(lvr), na.rm = TRUE), max_abs_log_vr = suppressWarnings(max(abs(lvr), na.rm = TRUE)),
		mean_ks = mean(ks), max_ks = max(ks), mahal_p = M / ncol(Z), energy = energy)
}

cal_balance_grid_cols <- function(m) sprintf("le_%s_%.3e", m, CAL_BALANCE_GRID)

# Per-replicate rows (CAL_BALANCE_KEYS, rep, the metrics) -> mergeable statistics, one row per unit.
cal_balance_stats <- function(r) {
	if (is.null(r) || !nrow(r)) return(NULL)
	k <- do.call(paste, c(r[CAL_BALANCE_KEYS], sep = "\r"))
	out <- do.call(rbind, lapply(split(seq_len(nrow(r)), k), function(idx) {
		x <- r[idx, ]
		o <- data.frame(x[1L, CAL_BALANCE_KEYS], reps = nrow(x), stringsAsFactors = FALSE)
		for (m in CAL_BALANCE_METRICS) {
			v <- x[[m]][is.finite(x[[m]])]
			o[[paste0("n_", m)]] <- length(v); o[[paste0("sum_", m)]] <- sum(v); o[[paste0("sum2_", m)]] <- sum(v^2)
		}
		for (m in CAL_BALANCE_Q_METRICS) {
			v <- x[[m]][is.finite(x[[m]])]
			o[cal_balance_grid_cols(m)] <- as.list(vapply(CAL_BALANCE_GRID, function(u) sum(v <= u), numeric(1L)))
		}
		o
	}))
	rownames(out) <- NULL
	out
}

cal_balance_read <- function(path) {
	if (!file.exists(path)) return(NULL)
	read_csv_fast(path, stringsAsFactors = FALSE, check.names = FALSE)
}

cal_balance_merge <- function(tabs) {
	tabs <- Filter(function(x) !is.null(x) && nrow(x), tabs)
	if (!length(tabs)) return(NULL)
	all <- do.call(rbind, tabs)
	k <- do.call(paste, c(all[CAL_BALANCE_KEYS], sep = "\r"))
	first <- !duplicated(k)
	out <- all[first, CAL_BALANCE_KEYS, drop = FALSE]
	g <- factor(k, levels = k[first])
	for (col in setdiff(names(all), CAL_BALANCE_KEYS)) out[[col]] <- as.numeric(tapply(all[[col]], g, sum, na.rm = TRUE))
	rownames(out) <- NULL
	out
}

# Quantile q of metric m from the le_ counts: log-linear interpolation between grid points.
cal_balance_quantile <- function(row, m, q) {
	cnt <- as.numeric(row[cal_balance_grid_cols(m)])
	n <- row[[paste0("n_", m)]]
	if (!is.finite(n) || n < 1) return(NA_real_)
	target <- q * n
	i <- which(cnt >= target)[1L]
	if (is.na(i)) return(Inf)
	if (i == 1L) return(CAL_BALANCE_GRID[1L])
	lo <- cnt[i - 1L]; hi <- cnt[i]
	f <- if (hi > lo) (target - lo) / (hi - lo) else 1
	exp(log(CAL_BALANCE_GRID[i - 1L]) + f * (log(CAL_BALANCE_GRID[i]) - log(CAL_BALANCE_GRID[i - 1L])))
}

# Merged statistics -> one row per unit: reps, mean and SD of every metric, median and 95th percentile of
# mahal_p and max_abs_smd.
cal_balance_summary <- function(st) {
	if (is.null(st) || !nrow(st)) return(NULL)
	out <- st[c(CAL_BALANCE_KEYS, "reps")]
	for (m in CAL_BALANCE_METRICS) {
		n <- st[[paste0("n_", m)]]; s <- st[[paste0("sum_", m)]]; s2 <- st[[paste0("sum2_", m)]]
		out[[m]] <- ifelse(n > 0, s / n, NA_real_)
		out[[paste0(m, "_sd")]] <- ifelse(n > 1, sqrt(pmax(s2 - n * out[[m]]^2, 0) / (n - 1)), NA_real_)
	}
	for (m in CAL_BALANCE_Q_METRICS) for (q in c(0.5, 0.95))
		out[[sprintf("%s_q%02d", m, round(100 * q))]] <- vapply(seq_len(nrow(st)), function(i) cal_balance_quantile(st[i, ], m, q), numeric(1L))
	out
}
