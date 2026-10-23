#!/usr/bin/env Rscript
# TODO-67 (release_v1_0_5.md; linked plan bug_fix_plans/kk21_weibull_irls_wrong_fixed_point.md
# -> TODO-5): KK21 survival-weight matching quality, replacement protocol,
# G4-C calibration runbook R6 (decision G6 #24).
#
# This is a REPLACEMENT fixture, not a historical replay of
# project_kk21_speedup_vs_glm_weights_20261008 (its inputs are unrecoverable).
#
# Fixture (extends the seed-6721 generator of
# R/package_tests/testthat_bulk/test-kk21-stepwise-survival-weibull-mle-score-reference.R):
#   case c = 0..199, case seed = 6721 + c; set.seed(case seed); n = 120;
#   five named covariates x1..x5 ~ N(0, 1) with prespecified Weibull (log-scale)
#   effects (0.8, 0.5, 0.25, 0.1, 0); latent U ~ Unif(0, 1); event flag ~ Bernoulli(0.8)
#   (the fixture's censoring mechanism); time = scale * (-log U)^(1/1.4) with
#   scale = exp(0.35 * w + X %*% beta), i.e. rweibull(shape = 1.4) driven by the fixed U,
#   so a subject's time changes between arms only through its own assignment w.
#   Balanced treatment comes from the design (KK21 matching / Bernoulli reservoir).
# Paired arms per case: DesignSeqOneByOneKK21(response_type = "survival", n = 120,
#   seed = case seed + 2e6) after set.seed(case seed + 1e6), subjects added one at a
#   time with their response recorded right after assignment. Everything is fixed
#   except the survival-weight implementation:
#     corrected : the installed native kk21_survival_weights_cpp() (the fixed Weibull fit);
#     old       : a pure-R port of the PRE-FIX kk21_survival_weights_cpp() (alternating
#                 IRLS with working response log_y - sigma*adj/w and the wrong-sign sigma
#                 score; source: git show 51d9167c^:R/EDI/src/kk21_weights.cpp, ~L744-904),
#                 injected into the CURRENT KK21 matching by giving the design's private
#                 compute_weights() a lookup environment whose kk21_survival_weights_cpp is
#                 the port (no other code path changes). Injection is verified per case
#                 (the design's recorded weights must equal the port's normalized output);
#                 if it cannot be verified the script reports it and stops (runbook R6:
#                 do not substitute EDI 1.0.2).
# Recorded per case x arm: both final weight vectors and their ranks, univariate
#   survreg |z| reference ranks (diagnostic), assignments, matched pairs, mASMD over x1..x5
#   in the matched subjects (|mean_T - mean_C| / sqrt((var_T + var_C) / 2), SDs from all n
#   subjects of that arm's sample), matched fraction / pair count, status, and per case
#   delta = mASMD_corrected - mASMD_old.
# Denominator: all attempted cases. A case nonestimable in an arm (error, zero pairs,
#   non-finite mASMD) stays in the denominator as a failure for that arm; the delta
#   summary uses cases estimable in both arms and is reported next to those counts.
# Pass (runbook proposal; the owner confirms the margin BEFORE the run):
#   upper 95% bound of mean paired delta <= 0.01 (noninferiority);
#   corrected mean matched fraction >= old mean - 0.02 (all cases; failed arm = 0);
#   corrected nonestimable count <= old nonestimable count.
# Also run (native sub-gate, runbook R6):
#   Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-kk21-stepwise-survival-weibull-mle-score-reference.R")'
#
# Usage:
#   Rscript R/benchmark/benchmark_todo67_kk21_matching_quality.R --out-dir $D [--cases 0:199]
#     [--n 120] [--margin 0.01] [--fraction-guard 0.02] [--timeout-sec 0] [--smoke]

local({
	f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
	here <- dirname(normalizePath(sub("^--file=", "", f[[1L]])))
	source(file.path(here, "..", "package_tests", "calibration", "calibration_common.R"))
}, envir = globalenv())

TODO67_BETA <- c(x1 = 0.8, x2 = 0.5, x3 = 0.25, x4 = 0.1, x5 = 0)
TODO67_SHAPE <- 1.4
TODO67_TREAT <- 0.35
TODO67_EVENT_P <- 0.8
TODO67_SEED0 <- 6721L

# ---------------------------------------------------------------------------
# Pure-R port of the PRE-FIX native code (commit 51d9167c^, kk21_weights.cpp).
# ---------------------------------------------------------------------------
old_univariate_weibull_tstat <- function(log_y, delta, x, maxit = 30L, tol = 1e-5) {
	n <- length(log_y)
	if (n < 4L) return(-1)
	n_events <- sum(delta)
	if (n_events < 2) return(-1)
	clamp_z <- function(z) pmin(20, pmax(-20, z))
	X <- cbind(1, x)
	XtX <- crossprod(X)
	q <- qr(XtX)
	if (q$rank < 2L) return(-1)
	beta <- qr.solve(q, crossprod(X, log_y))
	resid <- as.numeric(log_y - X %*% beta)
	scale <- sqrt(sum(resid[delta > 0.5]^2) / max(1, n_events - 2))
	scale <- max(0.01, min(10, scale))
	sum_d <- sum(delta > 0.5)
	for (iter in seq_len(maxit)) {
		z <- clamp_z(resid / scale)
		w <- exp(z)
		adj <- ifelse(delta > 0.5, z - 1 + w, w)
		pseudo <- log_y - scale * adj / w
		XwX <- matrix(c(sum(w), sum(w * x), sum(w * x), sum(w * x * x)), 2L, 2L)
		Xwz <- c(sum(w * pseudo), sum(w * x * pseudo))
		qw <- qr(XwX)
		if (qw$rank < 2L) return(-1)
		beta_new <- qr.solve(qw, Xwz)
		resid_new <- as.numeric(log_y - X %*% beta_new)
		scale_new <- scale
		if (sum_d > 0) {
			z_new <- clamp_z(resid_new / scale)
			score <- sum(delta * (z_new - 1) - z_new * exp(z_new)) / scale
			info <- sum_d / (scale * scale)
			if (abs(info) > 1e-10) scale_new <- max(0.01, min(10, scale - score / info))
		}
		diff <- sqrt(sum((beta_new - beta)^2)) + abs(scale_new - scale)
		beta <- beta_new
		scale <- scale_new
		resid <- resid_new
		if (diff < tol) break
	}
	wv <- exp(clamp_z(resid / scale)) / (scale * scale)
	info_mat <- crossprod(X, wv * X)
	var_1 <- tryCatch(solve(info_mat)[2L, 2L], error = function(e) {
		tryCatch(qr.solve(qr(info_mat), c(0, 1))[2L], error = function(e2) NA_real_)
	})
	if (!is.finite(var_1) || var_1 <= 0) return(-1)
	se <- sqrt(var_1)
	if (!is.finite(se) || se <= 0) return(-1)
	abs(beta[2L] / se)
}

old_kk21_survival_weights <- function(X, y, delta) {
	X <- as.matrix(X)
	n <- nrow(X)
	p <- ncol(X)
	eps <- .Machine$double.eps
	weights <- numeric(p)
	if (n < 2L || p == 0L) return(rep(eps, p))
	log_y <- log(pmax(as.numeric(y), 1e-10))
	delta <- as.numeric(delta)
	sumy <- sum(log_y)
	sumy2 <- sum(log_y^2)
	ybar <- sumy / n
	for (j in seq_len(p)) {
		tstat <- old_univariate_weibull_tstat(log_y, delta, X[, j])
		if (tstat > 0 && is.finite(tstat)) {
			weights[j] <- tstat
			next
		}
		x <- X[, j]
		sumx <- sum(x); sumx2 <- sum(x * x); sumxy <- sum(x * log_y)
		xbar <- sumx / n
		varx <- sumx2 - n * xbar * xbar
		if (varx <= eps || n <= 2L) { weights[j] <- eps; next }
		b1 <- (sumxy - n * xbar * ybar) / varx
		b0 <- ybar - b1 * xbar
		sse <- sumy2 + n * b0 * b0 + b1 * b1 * sumx2 + 2 * b0 * b1 * sumx - 2 * b0 * sumy - 2 * b1 * sumxy
		if (n <= 2L || sse <= 0) { weights[j] <- eps; next }
		se_b1 <- sqrt((sse / (n - 2)) / varx)
		weights[j] <- if (!is.finite(se_b1) || se_b1 <= 0) eps else abs(b1 / se_b1)
	}
	weights
}

# ---------------------------------------------------------------------------
# Fixture and one arm.
# ---------------------------------------------------------------------------
todo67_fixture <- function(case_seed, n) {
	set.seed(case_seed)
	X <- matrix(stats::rnorm(n * length(TODO67_BETA)), n, length(TODO67_BETA), dimnames = list(NULL, names(TODO67_BETA)))
	U <- stats::runif(n)
	event <- stats::rbinom(n, 1L, TODO67_EVENT_P)
	list(X = as.data.frame(X), U = U, event = event)
}

todo67_time <- function(fx, i, w_i) {
	scale <- exp(TODO67_TREAT * w_i + sum(unlist(fx$X[i, ]) * TODO67_BETA))
	scale * (-log(fx$U[i]))^(1 / TODO67_SHAPE)
}

todo67_run_arm <- function(fx, case_seed, n, arm) {
	set.seed(case_seed + 1000000L)
	des <- DesignSeqOneByOneKK21$new(response_type = "survival", n = n, seed = case_seed + 2000000L, verbose = FALSE)
	priv <- des$.__enclos_env__$private
	orig <- priv$compute_weights
	inject <- new.env(parent = environment(orig))
	inject$calls <- 0L
	inject$last_raw <- NULL
	native <- EDI:::kk21_survival_weights_cpp
	inject$kk21_survival_weights_cpp <- function(X, y, delta) {
		raw <- if (identical(arm, "old")) old_kk21_survival_weights(X, y, delta) else as.numeric(native(X, y, delta))
		inject$calls <- inject$calls + 1L
		inject$last_raw <- raw
		raw
	}
	patched <- orig
	environment(patched) <- inject
	unlockBinding("compute_weights", priv)
	assign("compute_weights", patched, envir = priv)
	lockBinding("compute_weights", priv)
	time <- numeric(n)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(fx$X[i, , drop = FALSE])
		time[i] <- todo67_time(fx, i, w_i)
		if (fx$event[i] == 1L) des$add_one_subject_response(i, y = time[i]) else
			des$add_one_subject_response(i, y_L = time[i], y_R = Inf)
	}
	w <- as.numeric(des$get_w())
	m <- as.integer(priv$m)
	m[is.na(m)] <- 0L
	final_w <- des$get_covariate_weights()
	inj_ok <- if (inject$calls > 0L && !is.null(inject$last_raw) && !is.null(final_w) &&
			length(final_w) == length(inject$last_raw)) {
		isTRUE(all.equal(unname(as.numeric(final_w)), inject$last_raw / sum(inject$last_raw), tolerance = 1e-10))
	} else NA
	list(w = w, m = m, time = time, final_weights = final_w, survival_weight_calls = inject$calls,
		injection_verified = inj_ok)
}

todo67_masmd <- function(X, w, m) {
	tab <- table(m[m > 0L])
	pair_ids <- as.integer(names(tab)[tab == 2L])
	matched <- m %in% pair_ids
	pairs <- length(pair_ids)
	if (!pairs) return(list(masmd = NA_real_, pairs = 0L, matched_fraction = 0, asmd = rep(NA_real_, ncol(X))))
	asmd <- vapply(names(X), function(v) {
		x <- X[[v]]
		sd_pool <- sqrt((stats::var(x[w == 1]) + stats::var(x[w == 0])) / 2)
		abs(mean(x[matched & w == 1]) - mean(x[matched & w == 0])) / sd_pool
	}, numeric(1L))
	list(masmd = mean(asmd), pairs = pairs, matched_fraction = 2 * pairs / length(w), asmd = asmd)
}

todo67_survreg_ref <- function(X, time, event) {
	vapply(names(X), function(v) {
		fit <- tryCatch(survival::survreg(survival::Surv(time, event) ~ X[[v]], dist = "weibull"), error = function(e) NULL)
		if (is.null(fit)) return(NA_real_)
		z <- tryCatch(summary(fit)$table[2L, "z"], error = function(e) NA_real_)
		abs(z)
	}, numeric(1L))
}

ROW_COLUMNS <- c(
	"case", "case_seed", "arm", "status", "masmd", "pairs", "matched_fraction", "n_treated", "survival_weight_calls",
	"injection_verified", "weights", "weight_ranks", "survreg_abs_z", "survreg_ranks", "spearman_weights_vs_survreg",
	"asmd", "assignments", "match_ids", "realized_censoring", "input_sha256", "elapsed_sec", "error_message"
)

main <- function(args) {
	usage <- paste(
		"Usage: Rscript R/benchmark/benchmark_todo67_kk21_matching_quality.R --out-dir DIR [--cases 0:199] [--n 120]",
		"  [--margin 0.01] [--fraction-guard 0.02] [--timeout-sec 0] [--smoke]",
		"--smoke: --cases 0:2 (mechanics only; never evidence).", sep = "\n")
	opt <- calib_parse_args(args, defaults = list(out_dir = "", cases = "0:199", n = "120", margin = "0.01",
		fraction_guard = "0.02", timeout_sec = "0"), flags = "smoke", usage = usage)
	if (opt$smoke && identical(opt$cases, "0:199")) opt$cases <- "0:2"
	script <- calib_script_path()
	repo_root <- calib_find_repo_root(dirname(script))
	out_dir <- calib_prepare_output_dir(opt$out_dir, repo_root)
	calib_load_installed_edi(repo_root)
	if (!requireNamespace("survival", quietly = TRUE)) stop("package survival is required")
	cases <- calib_parse_int_set(opt$cases, "cases")
	n <- as.integer(opt$n)
	margin <- as.numeric(opt$margin)
	guard <- as.numeric(opt$fraction_guard)
	timeout <- as.numeric(opt$timeout_sec)
	seeds <- TODO67_SEED0 + cases
	prov <- calib_capture_provenance(repo_root, script, out_dir, args, seeds, extra = list(
		study = "TODO-67 KK21 survival-weight matching quality, replacement protocol (G4-C R6)", smoke = opt$smoke,
		fixture = list(n = n, beta = TODO67_BETA, shape = TODO67_SHAPE, treatment_effect = TODO67_TREAT,
			event_probability = TODO67_EVENT_P, label = "replacement fixture, not a historical replay"),
		old_weights_source = "pure-R port of kk21_weights.cpp at 51d9167c^ (pre-fix univariate_weibull_tstat + OLS fallback)",
		margin = margin, fraction_guard = guard))
	cat("EDI", prov$edi_package_version, "from", prov$edi_package_path, "DLL sha256", prov$edi_dll_sha256, "\n")
	write_row <- calib_row_writer(file.path(out_dir, "rows.csv"), ROW_COLUMNS)
	collapse <- function(x, digits = 6L) if (is.null(x) || !length(x)) NA_character_ else paste(signif(as.numeric(x), digits), collapse = ";")

	for (ci in seq_along(cases)) {
		case <- cases[[ci]]
		case_seed <- seeds[[ci]]
		fx <- todo67_fixture(case_seed, n)
		input_sha <- calib_object_sha256(fx)
		for (arm in c("old", "corrected")) {
			r <- calib_eval(function() todo67_run_arm(fx, case_seed, n, arm), is_ok = function(v) !is.null(v$w), timeout_sec = timeout)
			if (r$status != "ok") {
				write_row(list(case = case, case_seed = case_seed, arm = arm, status = r$status, pairs = 0L, matched_fraction = 0,
					input_sha256 = input_sha, elapsed_sec = r$elapsed_sec, error_message = calib_clean_msg(r$error_message)))
				next
			}
			v <- r$value
			if (identical(arm, "old") && isFALSE(v$injection_verified)) {
				stop("case ", case, ": the injected old weights do not match the design's recorded weights; ",
					"KK21 did not accept the injected weights (runbook R6: report and stop; do not substitute EDI 1.0.2).")
			}
			q <- todo67_masmd(fx$X, v$w, v$m)
			ref <- todo67_survreg_ref(fx$X, v$time, fx$event)
			fw <- v$final_weights
			fw_named <- if (!is.null(fw)) fw[intersect(names(fw), names(TODO67_BETA))] else NULL
			sp <- if (length(fw_named) == length(ref) && all(is.finite(ref))) suppressWarnings(stats::cor(fw_named, ref[names(fw_named)], method = "spearman")) else NA_real_
			ok <- is.finite(q$masmd) && q$pairs > 0L
			write_row(list(case = case, case_seed = case_seed, arm = arm, status = if (ok) "ok" else "nonestimable",
				masmd = q$masmd, pairs = q$pairs, matched_fraction = q$matched_fraction, n_treated = sum(v$w),
				survival_weight_calls = v$survival_weight_calls, injection_verified = v$injection_verified,
				weights = if (is.null(fw)) NA else paste(paste0(names(fw), "=", signif(fw, 6)), collapse = ";"),
				weight_ranks = if (is.null(fw)) NA else paste(rank(-fw, ties.method = "min"), collapse = ";"),
				survreg_abs_z = collapse(ref), survreg_ranks = paste(rank(-ref, ties.method = "min", na.last = "keep"), collapse = ";"),
				spearman_weights_vs_survreg = sp, asmd = collapse(q$asmd), assignments = paste(v$w, collapse = ""),
				match_ids = paste(v$m, collapse = ";"), realized_censoring = mean(fx$event == 0L), input_sha256 = input_sha,
				elapsed_sec = r$elapsed_sec, error_message = NA))
		}
		if (opt$smoke || ci %% 10L == 0L) cat(sprintf("case %d done\n", case))
	}

	rows <- calib_read_rows(file.path(out_dir, "rows.csv"))
	todo67_summarize(rows, cases, out_dir, margin, guard, opt$smoke)
	calib_finish_provenance(out_dir)
	cat("wrote", out_dir, "\n")
}

todo67_summarize <- function(rows, cases, out_dir, margin, guard, smoke) {
	old <- rows[rows$arm == "old", , drop = FALSE]
	new <- rows[rows$arm == "corrected", , drop = FALSE]
	j <- merge(old[c("case", "status", "masmd", "matched_fraction", "pairs")], new[c("case", "status", "masmd", "matched_fraction", "pairs")],
		by = "case", all = TRUE, suffixes = c("_old", "_corrected"))
	j$delta <- ifelse(j$status_old %in% "ok" & j$status_corrected %in% "ok", j$masmd_corrected - j$masmd_old, NA_real_)
	utils::write.csv(j, file.path(out_dir, "paired_cases.csv"), row.names = FALSE, na = "NA")
	both <- is.finite(j$delta)
	d <- j$delta[both]
	upper <- if (length(d) >= 2L) mean(d) + stats::qt(0.975, length(d) - 1L) * stats::sd(d) / sqrt(length(d)) else NA_real_
	lower <- if (length(d) >= 2L) mean(d) - stats::qt(0.975, length(d) - 1L) * stats::sd(d) / sqrt(length(d)) else NA_real_
	mf <- function(x) { x[!is.finite(x)] <- 0; mean(x) }
	ne_old <- sum(!j$status_old %in% "ok")
	ne_new <- sum(!j$status_corrected %in% "ok")
	summ <- data.frame(
		cases_attempted = length(cases), estimable_old = sum(j$status_old %in% "ok"), estimable_corrected = sum(j$status_corrected %in% "ok"),
		estimable_both = sum(both), nonestimable_old = ne_old, nonestimable_corrected = ne_new,
		mean_masmd_old = mean(j$masmd_old[j$status_old %in% "ok"]), mean_masmd_corrected = mean(j$masmd_corrected[j$status_corrected %in% "ok"]),
		mean_delta = if (length(d)) mean(d) else NA_real_, delta_ci95_lower = lower, delta_ci95_upper = upper,
		mean_matched_fraction_old = mf(j$matched_fraction_old), mean_matched_fraction_corrected = mf(j$matched_fraction_corrected),
		margin = margin, fraction_guard = guard, stringsAsFactors = FALSE)
	summ$noninferior <- is.finite(upper) && upper <= margin
	summ$fraction_guard_ok <- summ$mean_matched_fraction_corrected >= summ$mean_matched_fraction_old - guard
	summ$nonestimable_ok <- ne_new <= ne_old
	summ$pass <- summ$noninferior && summ$fraction_guard_ok && summ$nonestimable_ok
	utils::write.csv(summ, file.path(out_dir, "summary.csv"), row.names = FALSE, na = "NA")
	inj <- rows$injection_verified[rows$arm == "old"]
	writeLines(c("# TODO-67 KK21 survival-weight matching quality (G4-C R6, replacement protocol)", "",
		if (smoke) "**SMOKE RUN: mechanics only, not evidence.**" else NULL, "",
		"Replacement fixture (seed-6721 generator extended to x1..x5); not a historical replay.",
		sprintf("Old-weight injection verified in %d/%d old-arm cases (NA = the Weibull weight path was never reached).",
			sum(inj %in% TRUE), length(inj)),
		sprintf("Overall (proposed margins, owner to confirm): %s", if (isTRUE(summ$pass)) "PASS" else "NOT PASSED"), "",
		calib_write_markdown_table(summ)), file.path(out_dir, "summary.md"))
	print(summ, row.names = FALSE)
	invisible(summ)
}

main(commandArgs(trailingOnly = TRUE))
