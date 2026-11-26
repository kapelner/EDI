# Design balance on real covariates (v1.0.7-TODO-103). A benchmark, not a test: for each
# redistributable CRAN trial of the experimental catalog it keeps the trial's covariates (in
# row order, or enrollment order where the data carry one), discards its outcome and its
# assignment, and assigns the subjects again with every EDI design: the fixed designs on the
# whole matrix, the sequential designs one subject at a time in that order. Each design is
# repeated over seeded draws. Nothing fails on a worse number; a design that errors is
# recorded as such.
#
# It complements the calibration study's balance statistics
# (R/package_tests/calibration/calibration_study_balance.R), which measure balance on that
# study's simulated covariates. The metrics here are the same ones, so the two reports are
# comparable: |SMD| per covariate (mean and max), |log variance ratio|, KS, Mahalanobis
# imbalance over p, energy distance; plus the largest gap in a factor level's share between
# the arms (`max_level_diff`), the treated share's distance from the design's target
# (`share_dev`, target 1/2 for every design here) and each draw's wall time. Covariates are
# numeric-coded for the metrics: factors as level indicators (the reference level dropped
# for the Mahalanobis term), missing values median-imputed with a missingness indicator.
#
# Data: the same rows and loader as the crash corpus (R/package_tests/real_data_catalog.R):
# the patients with the trial's first readable outcome. Trials above 1000 rows are
# subsampled to n = 50, 200 and 1000 (the calibration grid), redrawn per draw; smaller trials
# run at their own n. Settings, recorded per row in `settings`:
#   - strata (DesignFixedBlocking, DesignSeqOneByOnePocockSimon / SPBR / RandomBlockSize,
#     DesignFixedBlockedCluster): the catalog's cluster / center column where the row has
#     one, else up to two covariates with the fewest distinct values (factors first);
#   - DesignFixedCluster / DesignFixedBlockedCluster: only on trials with a catalog cluster
#     column, clustering on it;
#   - response-adaptive sequential designs (KK21, KK21stepwise) see the trial's real outcome
#     of each subject after it is assigned (the outcome is not used otherwise);
#   - every other argument is the design's default. DesignFixedFactorial (needs factors to
#     assign) and the observational designs are not run.
# The trial's own allocation is reported as a reference row ("(trial allocation)").
#
# Usage (from the repo root, against the installed EDI):
#   Rscript R/benchmark/design_balance_real_data.R [options]
#     --datasets a,b    catalog Dataset names (default: every resolvable row)
#     --designs A,B     design classes (default: all, see above)
#     --draws N         seeded draws per (trial, n, design) (default 3)
#     --timeout SECS    wall-clock limit per (trial, n, design), all draws (default 120)
#     --cores N         trials run in parallel (default 1)
#     --shard i/k       run trials i, i + k, ... of the resolvable rows (CI sharding)
#     --out FILE        per-draw CSV (default design_balance_real_data.csv)
#     --report DIR      also write the report (index.html, summary.csv, the CSV) from --out
#     --from-results F  build the report from per-draw CSVs (comma-separated), no runs

suppressPackageStartupMessages({
	library(EDI)
	library(parallel)
})
DB_SCRIPT_DIR <- local({
	file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
	sourced <- Filter(is.character, lapply(rev(sys.frames()), function(f) f$ofile))
	dirname(normalizePath(c(unlist(sourced), file_arg, "R/benchmark/design_balance_real_data.R")[[1L]]))
})
source(file.path(DB_SCRIPT_DIR, "..", "package_tests", "real_data_catalog.R"))
source(file.path(DB_SCRIPT_DIR, "..", "package_tests", "calibration", "calibration_study_balance.R"))

DB_FIXED <- c("DesignFixedBernoulli", "DesignFixediBCRD", "DesignFixedBlocking", "DesignFixedCluster", "DesignFixedBlockedCluster",
	"DesignFixedBinaryMatch", "DesignFixedGreedy", "DesignFixedGreedyDOptimal", "DesignFixedMatchingGreedyPairSwitching",
	"DesignFixedOptimal", "DesignFixedOptimalBlocks", "DesignFixedRerandomization")
DB_SEQ <- c("DesignSeqOneByOneBernoulli", "DesignSeqOneByOneiBCRD", "DesignSeqOneByOneEfron", "DesignSeqOneByOneAtkinson",
	"DesignSeqOneByOneUrn", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise",
	"DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneSPBR", "DesignSeqOneByOneRandomBlockSize")
DB_DESIGNS <- c(DB_FIXED, DB_SEQ)
DB_STRATA <- c("DesignFixedBlocking", "DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneSPBR", "DesignSeqOneByOneRandomBlockSize",
	"DesignFixedBlockedCluster")
DB_CLUSTER <- c("DesignFixedCluster", "DesignFixedBlockedCluster")
DB_RESPONSE_ADAPTIVE <- c("DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")
DB_SUBSAMPLE_N <- c(50L, 200L, 1000L)
DB_METRICS <- c(CAL_BALANCE_METRICS, "max_level_diff", "share_dev")
DB_REFERENCE <- "(trial allocation)"

db_parse_args <- function(argv) {
	opt <- list(datasets = NULL, designs = NULL, draws = 3L, timeout = 120, cores = 1L, shard = NULL,
		out = "design_balance_real_data.csv", report = NULL, from_results = NULL)
	i <- 1L
	while (i <= length(argv)) {
		key <- gsub("-", "_", sub("^--", "", argv[[i]]))
		if (!key %in% names(opt) || i == length(argv)) stop("unknown or valueless argument: ", argv[[i]], call. = FALSE)
		val <- argv[[i + 1L]]
		opt[[key]] <- switch(key,
			datasets = , designs = , from_results = trimws(strsplit(val, ",", fixed = TRUE)[[1L]]),
			draws = , cores = as.integer(val), timeout = as.numeric(val), val)
		i <- i + 2L
	}
	if (!is.null(opt$designs) && length(bad <- setdiff(opt$designs, DB_DESIGNS))) stop("unknown design(s): ", paste(bad, collapse = ", "), call. = FALSE)
	opt
}

# Numeric coding for the metrics: factor -> level indicators; NA -> median + indicator.
db_numeric <- function(X, drop_reference = TRUE) {
	cols <- list()
	for (nm in names(X)) {
		x <- X[[nm]]
		if (is.factor(x)) {
			lv <- levels(x)
			if (drop_reference) lv <- lv[-1L]
			for (l in lv) cols[[paste0(nm, "=", l)]] <- as.numeric(!is.na(x) & x == l)
			if (anyNA(x)) cols[[paste0(nm, "_NA")]] <- as.numeric(is.na(x))
		} else {
			v <- as.numeric(x)
			if (anyNA(v)) {
				cols[[paste0(nm, "_NA")]] <- as.numeric(is.na(v))
				v[is.na(v)] <- stats::median(v, na.rm = TRUE)
			}
			cols[[nm]] <- v
		}
	}
	Z <- as.data.frame(cols, check.names = FALSE)
	Z[, vapply(Z, function(v) length(unique(v)) > 1L, logical(1)), drop = FALSE]
}

db_metrics <- function(X, w) {
	Z <- db_numeric(X)
	if (!ncol(Z)) return(stats::setNames(as.list(rep(NA_real_, length(DB_METRICS))), DB_METRICS))
	# Drop exactly collinear columns so the Mahalanobis term is defined.
	q <- qr(scale(as.matrix(Z)))
	m <- as.list(cal_balance_metrics(Z[, q$pivot[seq_len(q$rank)], drop = FALSE], w))
	# The variance-ratio and KS terms on all columns, not only the independent ones.
	full <- cal_balance_metrics(Z, w)
	for (k in c("mean_abs_smd", "max_abs_smd", "mean_abs_log_vr", "max_abs_log_vr", "mean_ks", "max_ks", "energy")) m[[k]] <- full[[k]]
	fac <- names(X)[vapply(X, is.factor, logical(1))]
	t <- as.integer(w) == 1L
	m$max_level_diff <- if (length(fac)) {
		max(vapply(fac, function(nm) {
			x <- X[[nm]]
			max(vapply(levels(x), function(l) abs(mean(x[t] == l, na.rm = TRUE) - mean(x[!t] == l, na.rm = TRUE)), numeric(1)), na.rm = TRUE)
		}, numeric(1)), na.rm = TRUE)
	} else NA_real_
	m$share_dev <- abs(mean(t) - 0.5)
	m
}

# Strata for the designs that need them: the catalog group column, else up to two
# low-cardinality covariates (factors first).
db_strata <- function(X, group_col, cluster = NULL) {
	if (!is.na(group_col %||% NA) && group_col %in% names(X)) return(group_col)
	k <- vapply(X, function(v) length(unique(v[!is.na(v)])), numeric(1))
	fac <- vapply(X, is.factor, logical(1))
	ok <- k >= 2L & k <= 10L
	# Blocked-cluster designs need strata that nest the clusters: covariates constant within each cluster.
	if (!is.null(cluster)) ok <- ok & vapply(X, function(v) all(tapply(as.character(v), cluster, function(z) length(unique(z)) == 1L)), logical(1))
	if (!any(ok)) {
		if (!is.null(cluster)) stop("skipped: no cluster-level covariate to block on", call. = FALSE)
		return(names(X)[which.min(ifelse(k >= 2L, k, Inf))])
	}
	cand <- names(X)[ok][order(!fac[ok], k[ok])]
	head(cand, 2L)
}

db_design_args <- function(design, X, group_col, rt, n) {
	args <- list(response_type = rt, n = n)
	settings <- "defaults"
	if (design %in% DB_STRATA) {
		st <- if (design %in% DB_CLUSTER) db_strata(X[, setdiff(names(X), group_col), drop = FALSE], NA, cluster = X[[group_col]])
			else db_strata(X, group_col)
		if (design == "DesignFixedBlocking") args <- c(args, list(strata_cols = st, equal_block_sizes = FALSE))
		else args$strata_cols <- st
		settings <- paste0("strata = ", paste(st, collapse = "+"),
			if (!is.na(group_col %||% NA) && identical(st, group_col)) " (catalog)" else " (lowest-cardinality covariates)")
	}
	if (design %in% DB_CLUSTER) {
		args$cluster_col <- group_col
		settings <- paste0(if (settings == "defaults") "" else paste0(settings, "; "), "cluster = ", group_col, " (catalog)")
	}
	if (design == "DesignFixedRerandomization") { args$prop_acceptable <- 0.1; settings <- "prop_acceptable = 0.1" }
	if (design %in% DB_RESPONSE_ADAPTIVE) settings <- "sees each subject's real outcome after assignment"
	list(args = args, settings = settings)
}

# One draw of one design on X (rows already in arrival order). Returns w.
db_assign <- function(design, X, s, group_col, seed) {
	n <- nrow(X)
	rt <- s$type
	da <- db_design_args(design, X, group_col, rt, n)
	# The stratified sequential designs take only categorical strata: code the chosen columns as factors
	# (a missing value is its own level).
	for (col in da$args$strata_cols) {
		v <- as.character(X[[col]])
		v[is.na(v)] <- "(missing)"
		X[[col]] <- factor(v)
	}
	gen <- get(design, envir = asNamespace("EDI"))
	set.seed(seed)
	des <- do.call(gen$new, da$args)
	if (design %in% DB_FIXED) {
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		w <- des$get_w()
	} else {
		w <- integer(n)
		adaptive <- design %in% DB_RESPONSE_ADAPTIVE
		for (t in seq_len(n)) {
			w[t] <- des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
			if (adaptive) {
				y <- if (is.factor(s$ys)) s$ys[t] else s$ys[t]
				if (rt == "survival") des$add_one_subject_response(t, y = if (is.na(y)) NULL else y,
					y_L = if (is.na(s$y_Ls[t])) NULL else s$y_Ls[t], y_R = if (is.na(s$y_Rs[t])) NULL else s$y_Rs[t])
				else des$add_one_subject_response(t, y = y)
			}
		}
	}
	list(w = as.integer(w), settings = da$settings)
}

db_seed <- function(...) {
	h <- 0
	for (b in utf8ToInt(paste(..., sep = "|"))) h <- (h * 31 + b) %% 2147483647
	as.integer(h)
}

# All draws of one (trial, n, design) in a forked child bounded by `timeout`.
db_run_design <- function(design, trial, s, n_target, opt) {
	body <- function() {
		lapply(seq_len(opt$draws), function(d) {
			seed <- db_seed(trial$dataset, n_target, design, d)
			set.seed(seed)
			idx <- if (n_target < nrow(s$X)) sort(sample.int(nrow(s$X), n_target)) else seq_len(nrow(s$X))
			if (!is.null(s$order)) idx <- idx[order(match(idx, s$order))]
			if (design == "DesignFixedMatchingGreedyPairSwitching") idx <- idx[seq_len(length(idx) - length(idx) %% 4L)]
			if (design == "DesignFixedBinaryMatch") idx <- idx[seq_len(length(idx) - length(idx) %% 2L)]
			X <- s$X[idx, , drop = FALSE]
			X[] <- lapply(X, function(v) if (is.factor(v)) droplevels(v) else v)
			sub <- list(type = s$type, ys = if (is.factor(s$ys)) droplevels(s$ys[idx]) else s$ys[idx], y_Ls = s$y_Ls[idx], y_Rs = s$y_Rs[idx])
			gc <- trial$catalog_group_col
			if (!is.na(gc %||% NA)) X[[gc]] <- factor(s$groups[idx])
			t0 <- proc.time()[["elapsed"]]
			res <- tryCatch({
				if (design == DB_REFERENCE) list(w = s$w[idx], settings = "the trial's real assignment")
				else suppressWarnings(db_assign(design, X, sub, gc, seed))
			}, error = function(e) list(error = gsub("\\s+", " ", conditionMessage(e))))
			secs <- proc.time()[["elapsed"]] - t0
			Xm <- if (!is.na(gc %||% NA)) X[, setdiff(names(X), gc), drop = FALSE] else X
			skipped <- !is.null(res$error) && startsWith(res$error, "skipped: ")
			row <- list(draw = d, n = length(idx), secs = round(secs, 3L), settings = res$settings %||% "",
				status = if (is.null(res$error)) "ok" else if (skipped) "skipped" else "error",
				message = substr(sub("^skipped: ", "", res$error %||% ""), 1L, 300L))
			mets <- if (is.null(res$error) && ncol(Xm)) tryCatch(db_metrics(Xm, res$w), error = function(e) NULL) else NULL
			c(row, if (is.null(mets)) stats::setNames(as.list(rep(NA_real_, length(DB_METRICS))), DB_METRICS) else mets)
		})
	}
	job <- mcparallel(body(), silent = TRUE)
	res <- mccollect(job, wait = FALSE, timeout = opt$timeout)
	if (is.null(res)) {
		tools::pskill(job$pid, tools::SIGKILL)
		mccollect(job, wait = TRUE)
		return(list(c(list(draw = NA_integer_, n = n_target, secs = opt$timeout, settings = "", status = "timeout",
			message = sprintf("draws exceeded %gs", opt$timeout)), stats::setNames(as.list(rep(NA_real_, length(DB_METRICS))), DB_METRICS))))
	}
	res <- res[[1L]]
	if (inherits(res, "try-error") || is.null(res)) {
		return(list(c(list(draw = NA_integer_, n = n_target, secs = NA_real_, settings = "", status = "error",
			message = "child process died"), stats::setNames(as.list(rep(NA_real_, length(DB_METRICS))), DB_METRICS))))
	}
	res
}

db_run_trial <- function(trial, opt) {
	s <- rdc_outcome_subset(trial, 1L)
	n_full <- nrow(s$X)
	sizes <- if (n_full > max(DB_SUBSAMPLE_N)) DB_SUBSAMPLE_N else n_full
	designs <- opt$designs %||% DB_DESIGNS
	if (is.na(trial$catalog_group_col %||% NA)) designs <- setdiff(designs, DB_CLUSTER)
	designs <- c(DB_REFERENCE, designs)
	rows <- list()
	for (n_target in sizes) for (d in designs) {
		t0 <- proc.time()[["elapsed"]]
		r <- db_run_design(d, trial, s, n_target, opt)
		for (x in r) rows[[length(rows) + 1L]] <- data.frame(dataset = trial$dataset, n_full = n_full, design = d, x,
			check.names = FALSE, stringsAsFactors = FALSE)
		message(sprintf("  %-34s n=%-5d %-40s %6.1fs", trial$dataset, n_target, d, proc.time()[["elapsed"]] - t0))
	}
	do.call(rbind, rows)
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

db_summary <- function(res) {
	ok <- res[res$status == "ok", , drop = FALSE]
	groups <- split(seq_len(nrow(res)), res$design)
	out <- do.call(rbind, lapply(names(groups), function(d) {
		r <- res[groups[[d]], , drop = FALSE]
		o <- ok[ok$design == d, , drop = FALSE]
		q <- function(v, p) if (length(v <- v[is.finite(v)])) unname(stats::quantile(v, p)) else NA_real_
		data.frame(design = d, trials = length(unique(r$dataset)), draws = nrow(o),
			errors = sum(r$status == "error"), timeouts = sum(r$status == "timeout"),
			max_abs_smd_med = q(o$max_abs_smd, 0.5), max_abs_smd_q25 = q(o$max_abs_smd, 0.25), max_abs_smd_q75 = q(o$max_abs_smd, 0.75),
			mean_abs_smd_med = q(o$mean_abs_smd, 0.5), mahal_p_med = q(o$mahal_p, 0.5), mahal_p_q75 = q(o$mahal_p, 0.75),
			max_ks_med = q(o$max_ks, 0.5), max_level_diff_med = q(o$max_level_diff, 0.5), energy_med = q(o$energy, 0.5),
			share_dev_med = q(o$share_dev, 0.5), share_dev_max = suppressWarnings(max(o$share_dev, na.rm = TRUE)),
			secs_med = q(o$secs, 0.5), secs_max = suppressWarnings(max(o$secs, na.rm = TRUE)), stringsAsFactors = FALSE)
	}))
	out[order(out$design != DB_REFERENCE, out$max_abs_smd_med), , drop = FALSE]
}

db_html <- function(sm, res) {
	f <- function(x, d = 3L) ifelse(is.finite(x), formatC(x, digits = d, format = "fg", flag = "#"), "&ndash;")
	esc <- function(x) gsub("<", "&lt;", gsub("&", "&amp;", x))
	head_row <- "<tr><th>Design</th><th>Trials</th><th>Draws</th><th>Errors / timeouts</th><th>max |SMD| median [IQR]</th><th>mean |SMD|</th><th>Mahalanobis / p median (q75)</th><th>max KS</th><th>max factor-level gap</th><th>energy</th><th>|treated share &minus; &frac12;| median (max)</th><th>seconds per draw median (max)</th></tr>"
	body <- vapply(seq_len(nrow(sm)), function(i) {
		r <- sm[i, ]
		sprintf("<tr%s><td>%s</td><td>%d</td><td>%d</td><td>%d / %d</td><td>%s [%s, %s]</td><td>%s</td><td>%s (%s)</td><td>%s</td><td>%s</td><td>%s</td><td>%s (%s)</td><td>%s (%s)</td></tr>",
			if (r$design == DB_REFERENCE) " class=\"ref\"" else "", esc(r$design), r$trials, r$draws, r$errors, r$timeouts,
			f(r$max_abs_smd_med), f(r$max_abs_smd_q25), f(r$max_abs_smd_q75), f(r$mean_abs_smd_med), f(r$mahal_p_med), f(r$mahal_p_q75),
			f(r$max_ks_med), f(r$max_level_diff_med), f(r$energy_med), f(r$share_dev_med), f(r$share_dev_max), f(r$secs_med, 2L), f(r$secs_max, 2L))
	}, character(1))
	err <- res[res$status != "ok", c("dataset", "n", "design", "status", "message")]
	err <- err[!duplicated(err[c("dataset", "design", "status")]), , drop = FALSE]
	err_rows <- if (nrow(err)) vapply(seq_len(nrow(err)), function(i) sprintf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
		esc(err$dataset[i]), err$n[i], esc(err$design[i]), err$status[i], esc(err$message[i])), character(1)) else character()
	sha <- Sys.getenv("GITHUB_SHA", "")
	c("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
		"<title>Design balance on real trials</title><style>",
		":root{--bg:#fff;--fg:#1b1f24;--muted:#57606a;--line:#d0d7de;--ref:#f6f8fa}",
		"@media (prefers-color-scheme: dark){:root{--bg:#0d1117;--fg:#e6edf3;--muted:#8b949e;--line:#30363d;--ref:#161b22}}",
		"body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;margin:0 auto;max-width:1200px;padding:16px}",
		"table{border-collapse:collapse;width:100%;font-size:13px;font-variant-numeric:tabular-nums}th,td{border-bottom:1px solid var(--line);padding:6px 8px;text-align:right}",
		"th:first-child,td:first-child{text-align:left}tr.ref td{background:var(--ref);font-style:italic}.wrap{overflow-x:auto}p,li{color:var(--muted)}</style></head><body>",
		"<h1>Design balance on real trials</h1>",
		sprintf("<p>Every EDI design re-assigns the patients of %d real randomized trials from EDI's dataset catalog (their covariates kept, their outcome and assignment discarded), %d seeded draws each. Smaller is better in every column. Generated %s%s. Raw rows: <a href=\"design_balance_real_data.csv\">design_balance_real_data.csv</a>; per-design summary: <a href=\"summary.csv\">summary.csv</a>.</p>",
			length(unique(res$dataset)), max(res$draw, na.rm = TRUE), format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC"),
			if (nzchar(sha)) sprintf(" at commit <code>%s</code>", substr(sha, 1L, 12L)) else ""),
		"<ul><li>|SMD|: standardized mean difference per covariate (factor levels as indicators). Mahalanobis / p: about 1 under complete randomization.</li>",
		"<li>Trials above 1000 patients run at n = 50, 200 and 1000, subsampled per draw. Settings each design used (strata, clusters) are in the CSV's <code>settings</code> column.</li>",
		"<li>The italic row is the trials' own allocation, for reference. This is a benchmark, not a test: nothing fails on a worse number.</li></ul>",
		"<div class=\"wrap\"><table>", head_row, body, "</table></div>",
		sprintf("<h2>Errors and timeouts (%d)</h2>", nrow(err)),
		if (nrow(err)) c("<div class=\"wrap\"><table><tr><th>Trial</th><th>n</th><th>Design</th><th>Status</th><th>Message</th></tr>", err_rows, "</table></div>") else "<p>None.</p>",
		"</body></html>")
}

db_write_report <- function(res, dir) {
	dir.create(dir, showWarnings = FALSE, recursive = TRUE)
	sm <- db_summary(res)
	utils::write.csv(res, file.path(dir, "design_balance_real_data.csv"), row.names = FALSE)
	utils::write.csv(sm, file.path(dir, "summary.csv"), row.names = FALSE)
	writeLines(db_html(sm, res), file.path(dir, "index.html"))
	invisible(sm)
}

db_main <- function(argv = commandArgs(trailingOnly = TRUE)) {
	opt <- db_parse_args(argv)
	if (!is.null(opt$from_results)) {
		res <- do.call(rbind, lapply(opt$from_results, utils::read.csv, stringsAsFactors = FALSE, check.names = FALSE))
		db_write_report(res, opt$report %||% "design_balance_report")
		return(invisible(res))
	}
	cat_df <- rdc_catalog()
	if (!is.null(opt$datasets)) {
		miss <- setdiff(opt$datasets, cat_df$dataset)
		if (length(miss)) stop("not in the redistributable CRAN catalog rows: ", paste(miss, collapse = ", "), call. = FALSE)
		cat_df <- cat_df[cat_df$dataset %in% opt$datasets, , drop = FALSE]
	}
	trials <- list()
	for (i in seq_len(nrow(cat_df))) {
		tr <- tryCatch(rdc_resolve(cat_df[i, ], n_max = .Machine$integer.max), error = function(e) NULL)
		if (!is.null(tr) && is.null(tr[["skip"]])) trials[[length(trials) + 1L]] <- tr
	}
	if (!is.null(opt$shard)) {
		ik <- as.integer(strsplit(opt$shard, "/", fixed = TRUE)[[1L]])
		trials <- trials[seq_along(trials) %% ik[2L] == (ik[1L] - 1L) %% ik[2L]]
	}
	message(sprintf("%d trials, %d draws per design", length(trials), opt$draws))
	t0 <- proc.time()[["elapsed"]]
	one <- function(tr) tryCatch(db_run_trial(tr, opt), error = function(e) { message("  ", tr$dataset, ": ", conditionMessage(e)); NULL })
	res_list <- if (opt$cores > 1L) mclapply(trials, one, mc.cores = opt$cores, mc.preschedule = FALSE) else lapply(trials, one)
	res <- do.call(rbind, Filter(is.data.frame, res_list))
	message(sprintf("done: %d rows in %.1f min", NROW(res), (proc.time()[["elapsed"]] - t0) / 60))
	utils::write.csv(res, opt$out, row.names = FALSE)
	if (!is.null(opt$report)) db_write_report(res, opt$report)
	invisible(res)
}

if (sys.nframe() == 0L) db_main()
