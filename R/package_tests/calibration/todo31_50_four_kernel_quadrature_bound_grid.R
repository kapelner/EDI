#!/usr/bin/env Rscript
# TODO-31 / TODO-50 (release_v1_0_5.md; linked plans
# bug_fix_plans/glmm_variance_component_sigma_collapse.md -> TODO-1 and
# bug_fix_plans/investigate_count_family_unexplained_miscalibration_cluster.md):
# four-kernel 20-node vs 320-node Gauss-Hermite quadrature bound grid, G4-C
# calibration runbook R8 (owner decision 2026-10-21, "do (1) and revisit after todo153").
#
# Kernels (unexported EDI namespace functions, called directly):
#   fast_ordinal_clmm_cpp, fast_ordinal_glmm_cpp  (random-intercept cumulative logit)
#   fast_logistic_glmm_cpp                        (random-intercept logistic)
#   fast_poisson_glmm_cpp                         (random-intercept Poisson)
# Grid (plan TODO-1 convention of 2026-10-14): n {120, 200} x true sigma {0.6, 0.9}
# x seeds 41001:41010, 40 fits per kernel, 160 (kernel, n, sigma, seed) cells.
# Each cell fits the same data twice, at n_gh = 20 (the shipped default) and at
# n_gh = 320 (the reference optimum), with the same optimizer and default starts.
#
# DGP per (kernel, n, sigma, seed): set.seed(seed); G = n / 5 groups of 5;
#   ordinal  : x ~ N(0,1); u ~ N(0, sigma) per group; y = cut(0.6 x + u + Logistic, c(-Inf, -1, 0.5, Inf))
#              (K = 3; the fixture of test-ordinal-clmm-kernel-...-reference.R); X = x (no intercept column);
#   logistic : X = cbind(1, x ~ N(0,1)); u ~ N(0, sigma); y ~ Bernoulli(plogis(-0.2 + 0.7 x + u))
#              (fixture of test-logistic-glmm-fit-glmer-agreement-...-reference.R);
#   poisson  : x ~ N(0,1); u ~ N(0, sigma); y ~ Poisson(exp(0.4 + 0.3 x + u)); X = cbind(1, x)
#              (fixture of test-poisson-glmm-20-node-vs-320-node-bound.R; its cells are this
#              script's poisson n = 200, sigma = 0.9 cells).
# Both ordinal kernels see identical data for a given (n, sigma, seed).
# Optimizers: poisson uses "newton" by default (the InferenceCountKKGLMM production path and the
# bulk bound test); the others use the kernel default ("lbfgs"). See --poisson-alg / --other-alg.
#
# Comparison (owner-approved bound, 2026-10-21):
#   coefficients: the kernel's fixed-effect vector b (ordinal: the slope only, thresholds are
#     recorded but not gated; logistic/poisson: intercept and slope). SE = the 320-node fit's
#     standard error (ordinal: sqrt(ssq_b_T); logistic/poisson: sqrt(diag(vcov))[seq_along(b)]).
#     Gate: max_j |b20_j - b320_j| / SE_j <= 0.75.
#   log sigma: |log_sigma20 - log_sigma320| <= 0.10.
# A cell is "usable" only when both fits converged with finite b, log sigma and SE (the bulk
# test's rule: a non-converged kernel fit is a failure the R callers already route to a
# fallback, so it does not enter the accuracy bound). Unusable cells are counted and listed.
# Pass, per kernel x n x sigma stratum: every usable cell is within the bound AND at least
# --min-usable-frac (default 0.5, the bulk test's 5 of 10) of the stratum's cells are usable.
# Overall PASS = every stratum passes. A --smoke run is mechanics only, never evidence.
#
# Outputs in --out-dir (fresh, outside the checkout): rows.csv (one row per cell, appended as
# each cell finishes), provenance.rds/.txt, summary.csv, summary.md.
#
# Usage:
#   Rscript R/package_tests/calibration/todo31_50_four_kernel_quadrature_bound_grid.R --out-dir $D \
#     [--kernels clmm,ordinal_glmm,logistic_glmm,poisson_glmm] [--n 120,200] [--sigmas 0.6,0.9]
#     [--seeds 41001:41010] [--n-gh-low 20] [--n-gh-high 320] [--poisson-alg newton] [--other-alg default]
#     [--coef-bound-se 0.75] [--log-sigma-bound 0.10] [--min-usable-frac 0.5] [--timeout-sec 0] [--smoke]

local({
	f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
	here <- dirname(normalizePath(sub("^--file=", "", f[[1L]])))
	source(file.path(here, "calibration_common.R"))
}, envir = globalenv())

QB_KERNELS <- c(
	clmm = "fast_ordinal_clmm_cpp",
	ordinal_glmm = "fast_ordinal_glmm_cpp",
	logistic_glmm = "fast_logistic_glmm_cpp",
	poisson_glmm = "fast_poisson_glmm_cpp"
)
QB_KERNEL_SOURCES <- c(
	clmm = "fast_ordinal_clmm.cpp",
	ordinal_glmm = "fast_ordinal_glmm.cpp",
	logistic_glmm = "fast_logistic_glmm.cpp",
	poisson_glmm = "fast_poisson_glmm.cpp"
)
QB_GROUP_SIZE <- 5L

ROW_COLUMNS <- c(
	"kernel", "kernel_function", "n", "groups", "sigma_true", "seed", "optimizer", "n_gh_low", "n_gh_high",
	"status", "usable", "unusable_reason",
	"converged_low", "converged_high", "hit_cap_low", "hit_cap_high", "num_iter_low", "num_iter_high",
	"gradient_norm_low", "gradient_norm_high", "neg_loglik_low", "neg_loglik_high",
	"n_coef", "coef_low", "coef_high", "se_high", "coef_diff_se", "max_coef_diff_se",
	"log_sigma_low", "log_sigma_high", "log_sigma_diff", "alpha_low", "alpha_high", "max_alpha_diff",
	"coef_within_bound", "log_sigma_within_bound", "within_bound",
	"elapsed_sec", "warnings", "error_message"
)

qb_generate <- function(kernel, n, sigma, seed) {
	if (n %% QB_GROUP_SIZE != 0L) stop("n must be a multiple of ", QB_GROUP_SIZE)
	set.seed(seed)
	G <- n %/% QB_GROUP_SIZE
	g <- rep(seq_len(G), each = QB_GROUP_SIZE)
	if (kernel %in% c("clmm", "ordinal_glmm")) {
		x <- stats::rnorm(n)
		u <- stats::rnorm(G, 0, sigma)[g]
		y <- as.integer(cut(0.6 * x + u + stats::rlogis(n), c(-Inf, -1, 0.5, Inf)))
		return(list(X = matrix(x, ncol = 1L), y = y, g = as.integer(g), G = G))
	}
	if (identical(kernel, "logistic_glmm")) {
		X <- cbind(1, stats::rnorm(n))
		u <- stats::rnorm(G, 0, sigma)[g]
		y <- as.numeric(stats::rbinom(n, 1, stats::plogis(drop(X %*% c(-0.2, 0.7)) + u)))
		return(list(X = X, y = y, g = as.integer(g), G = G))
	}
	x <- stats::rnorm(n)
	u <- stats::rnorm(G, sd = sigma)[g]
	X <- cbind(1, x)
	y <- as.numeric(stats::rpois(n, exp(0.4 + 0.3 * x + u)))
	list(X = X, y = y, g = as.integer(g), G = G)
}

qb_fit <- function(kernel, d, n_gh, alg) {
	f <- get(QB_KERNELS[[kernel]], envir = asNamespace("EDI"))
	if (kernel %in% c("clmm", "ordinal_glmm")) {
		if (identical(alg, "default")) return(f(d$X, d$y, d$g, 3L, 0L, n_gh = as.integer(n_gh)))
		return(f(d$X, d$y, d$g, 3L, 0L, n_gh = as.integer(n_gh), optimization_alg = alg))
	}
	if (identical(alg, "default")) return(f(d$X, d$y, d$g, 1L, n_gh = as.integer(n_gh)))
	f(d$X, d$y, d$g, 1L, n_gh = as.integer(n_gh), optimization_alg = alg)
}

qb_se <- function(kernel, r) {
	b <- as.numeric(r$b)
	if (kernel %in% c("clmm", "ordinal_glmm")) return(sqrt(as.numeric(r$ssq_b_T))[seq_along(b)])
	v <- tryCatch(as.matrix(r$vcov), error = function(e) NULL)
	if (is.null(v) || nrow(v) < length(b)) return(rep(NA_real_, length(b)))
	sqrt(diag(v))[seq_along(b)]
}

qb_scalar <- function(r, name, type = "num") {
	v <- r[[name]]
	if (is.null(v) || !length(v)) return(if (identical(type, "lgl")) NA else NA_real_)
	if (identical(type, "lgl")) as.logical(v[[1L]]) else suppressWarnings(as.numeric(v[[1L]]))
}

qb_join <- function(x) if (!length(x)) NA_character_ else paste(format(signif(as.numeric(x), 10), trim = TRUE), collapse = ";")

qb_compare <- function(kernel, lo, hi, coef_bound, ls_bound) {
	b_lo <- as.numeric(lo$b); b_hi <- as.numeric(hi$b)
	se <- qb_se(kernel, hi)
	ls_lo <- qb_scalar(lo, "log_sigma"); ls_hi <- qb_scalar(hi, "log_sigma")
	reasons <- character()
	if (!isTRUE(qb_scalar(lo, "converged", "lgl"))) reasons <- c(reasons, "low_not_converged")
	if (!isTRUE(qb_scalar(hi, "converged", "lgl"))) reasons <- c(reasons, "high_not_converged")
	if (!length(b_lo) || !all(is.finite(c(b_lo, ls_lo)))) reasons <- c(reasons, "low_nonfinite")
	if (!length(b_hi) || !all(is.finite(c(b_hi, ls_hi)))) reasons <- c(reasons, "high_nonfinite")
	if (length(b_lo) != length(b_hi)) reasons <- c(reasons, "coef_length_mismatch")
	if (!length(se) || !all(is.finite(se) & se > 0)) reasons <- c(reasons, "high_se_nonfinite")
	usable <- !length(reasons)
	d_se <- if (length(b_lo) == length(b_hi) && length(se) == length(b_hi)) abs(b_lo - b_hi) / se else numeric()
	d_ls <- abs(ls_lo - ls_hi)
	a_lo <- as.numeric(lo$alpha); a_hi <- as.numeric(hi$alpha)
	max_d_se <- if (length(d_se) && all(is.finite(d_se))) max(d_se) else NA_real_
	coef_ok <- if (usable) max_d_se <= coef_bound else NA
	ls_ok <- if (usable) d_ls <= ls_bound else NA
	list(
		usable = usable, unusable_reason = if (usable) NA_character_ else paste(reasons, collapse = ";"),
		converged_low = qb_scalar(lo, "converged", "lgl"), converged_high = qb_scalar(hi, "converged", "lgl"),
		hit_cap_low = qb_scalar(lo, "hit_iteration_cap", "lgl"), hit_cap_high = qb_scalar(hi, "hit_iteration_cap", "lgl"),
		num_iter_low = qb_scalar(lo, "num_iter"), num_iter_high = qb_scalar(hi, "num_iter"),
		gradient_norm_low = qb_scalar(lo, "gradient_norm"), gradient_norm_high = qb_scalar(hi, "gradient_norm"),
		neg_loglik_low = qb_scalar(lo, "neg_loglik"), neg_loglik_high = qb_scalar(hi, "neg_loglik"),
		n_coef = length(b_hi), coef_low = qb_join(b_lo), coef_high = qb_join(b_hi), se_high = qb_join(se),
		coef_diff_se = qb_join(d_se), max_coef_diff_se = max_d_se,
		log_sigma_low = ls_lo, log_sigma_high = ls_hi, log_sigma_diff = d_ls,
		alpha_low = qb_join(a_lo), alpha_high = qb_join(a_hi),
		max_alpha_diff = if (length(a_lo) && length(a_lo) == length(a_hi)) max(abs(a_lo - a_hi)) else NA_real_,
		coef_within_bound = coef_ok, log_sigma_within_bound = ls_ok,
		within_bound = if (usable) isTRUE(coef_ok) && isTRUE(ls_ok) else NA
	)
}

qb_summary <- function(rows, min_usable_frac) {
	keys <- unique(rows[c("kernel", "n", "sigma_true")])
	do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
		s <- rows[rows$kernel == keys$kernel[i] & rows$n == keys$n[i] & rows$sigma_true == keys$sigma_true[i], , drop = FALSE]
		u <- s[s$usable %in% TRUE, , drop = FALSE]
		n_usable <- nrow(u)
		n_out <- sum(!(u$within_bound %in% TRUE))
		enough <- n_usable >= ceiling(min_usable_frac * nrow(s))
		data.frame(
			kernel = keys$kernel[i], n = keys$n[i], sigma_true = keys$sigma_true[i], cells = nrow(s),
			errors = sum(s$status %in% c("error", "timeout")), usable = n_usable,
			unusable_seeds = if (any(!(s$usable %in% TRUE))) paste(s$seed[!(s$usable %in% TRUE)], collapse = ";") else "",
			max_coef_diff_se = if (n_usable) max(u$max_coef_diff_se) else NA_real_,
			worst_coef_seed = if (n_usable) u$seed[which.max(u$max_coef_diff_se)] else NA_integer_,
			max_log_sigma_diff = if (n_usable) max(u$log_sigma_diff) else NA_real_,
			worst_log_sigma_seed = if (n_usable) u$seed[which.max(u$log_sigma_diff)] else NA_integer_,
			out_of_bound = n_out,
			out_of_bound_seeds = if (n_out) paste(u$seed[!(u$within_bound %in% TRUE)], collapse = ";") else "",
			enough_usable = enough,
			pass = enough && n_out == 0L,
			stringsAsFactors = FALSE)
	}))
}

main <- function(args) {
	usage <- paste(
		"Usage: Rscript R/package_tests/calibration/todo31_50_four_kernel_quadrature_bound_grid.R --out-dir DIR",
		"  [--kernels clmm,ordinal_glmm,logistic_glmm,poisson_glmm] [--n 120,200] [--sigmas 0.6,0.9]",
		"  [--seeds 41001:41010] [--n-gh-low 20] [--n-gh-high 320] [--poisson-alg newton] [--other-alg default]",
		"  [--coef-bound-se 0.75] [--log-sigma-bound 0.10] [--min-usable-frac 0.5] [--timeout-sec 0] [--smoke]",
		"--smoke: --n 120 --sigmas 0.6 --seeds 41001:41002 (all four kernels; mechanics only, not evidence).", sep = "\n")
	defaults <- list(out_dir = "", kernels = paste(names(QB_KERNELS), collapse = ","), n = "120,200",
		sigmas = "0.6,0.9", seeds = "41001:41010", n_gh_low = "20", n_gh_high = "320", poisson_alg = "newton",
		other_alg = "default", coef_bound_se = "0.75", log_sigma_bound = "0.10", min_usable_frac = "0.5",
		timeout_sec = "0")
	opt <- calib_parse_args(args, defaults = defaults, flags = "smoke", usage = usage)
	if (opt$smoke) {
		if (identical(opt$n, defaults$n)) opt$n <- "120"
		if (identical(opt$sigmas, defaults$sigmas)) opt$sigmas <- "0.6"
		if (identical(opt$seeds, defaults$seeds)) opt$seeds <- "41001:41002"
	}
	script <- calib_script_path()
	repo_root <- calib_find_repo_root(dirname(script))
	out_dir <- calib_prepare_output_dir(opt$out_dir, repo_root)
	calib_load_installed_edi(repo_root)
	kernels <- calib_parse_chr_set(opt$kernels)
	if (!length(kernels) || !all(kernels %in% names(QB_KERNELS))) {
		stop("--kernels must be among ", paste(names(QB_KERNELS), collapse = ", "), call. = FALSE)
	}
	for (k in kernels) {
		if (!exists(QB_KERNELS[[k]], envir = asNamespace("EDI"), inherits = FALSE)) {
			stop("installed EDI has no ", QB_KERNELS[[k]], call. = FALSE)
		}
	}
	ns <- as.integer(calib_parse_num_set(opt$n))
	if (any(ns %% QB_GROUP_SIZE != 0L)) stop("--n values must be multiples of ", QB_GROUP_SIZE, call. = FALSE)
	sigmas <- calib_parse_num_set(opt$sigmas)
	seeds <- calib_parse_int_set(opt$seeds)
	n_gh_low <- as.integer(opt$n_gh_low)
	n_gh_high <- as.integer(opt$n_gh_high)
	coef_bound <- as.numeric(opt$coef_bound_se)
	ls_bound <- as.numeric(opt$log_sigma_bound)
	min_usable_frac <- as.numeric(opt$min_usable_frac)
	timeout <- as.numeric(opt$timeout_sec)
	alg_for <- function(k) if (identical(k, "poisson_glmm")) opt$poisson_alg else opt$other_alg
	src_dir <- file.path(repo_root, "R", "EDI", "src")
	prov <- calib_capture_provenance(repo_root, script, out_dir, args, seeds, extra = list(
		study = "TODO-31/50 four-kernel 20-vs-320 quadrature bound grid (G4-C R8)", smoke = opt$smoke,
		kernels = QB_KERNELS[kernels], n = ns, sigmas = sigmas, group_size = QB_GROUP_SIZE,
		n_gh_low = n_gh_low, n_gh_high = n_gh_high, optimizers = vapply(kernels, alg_for, character(1L)),
		coef_bound_se = coef_bound, log_sigma_bound = ls_bound, min_usable_frac = min_usable_frac,
		kernel_source_sha256 = vapply(QB_KERNEL_SOURCES[kernels], function(f) calib_sha256(file.path(src_dir, f)),
			character(1L)),
		note_kernel_source = paste("kernel_source_sha256 hashes the CHECKOUT's .cpp files; they attest the installed",
			"DLL only if the G1 build receipt names this checkout state (compare checkout_head/checkout_diff_sha256).")))
	cat("EDI", prov$edi_package_version, "from", prov$edi_package_path, "DLL sha256", prov$edi_dll_sha256, "\n")
	write_row <- calib_row_writer(file.path(out_dir, "rows.csv"), ROW_COLUMNS)

	for (k in kernels) for (n in ns) for (sig in sigmas) for (seed in seeds) {
		alg <- alg_for(k)
		base <- list(kernel = k, kernel_function = QB_KERNELS[[k]], n = n, groups = n %/% QB_GROUP_SIZE,
			sigma_true = sig, seed = seed, optimizer = alg, n_gh_low = n_gh_low, n_gh_high = n_gh_high)
		r <- calib_eval(function() {
			d <- qb_generate(k, n, sig, seed)
			lo <- qb_fit(k, d, n_gh_low, alg)
			hi <- qb_fit(k, d, n_gh_high, alg)
			qb_compare(k, lo, hi, coef_bound, ls_bound)
		}, is_ok = function(v) isTRUE(v$usable), timeout_sec = timeout)
		v <- r$value
		status <- if (r$status == "nonestimable") "unusable" else r$status
		if (is.null(v)) v <- list(usable = FALSE, unusable_reason = r$status)
		write_row(c(base, list(status = status), v, list(elapsed_sec = r$elapsed_sec,
			warnings = calib_clean_msg(r$warnings), error_message = calib_clean_msg(r$error_message))))
		cat(sprintf("%-13s n %d sigma %.2f seed %d: %s max|db|/SE %s |dlogsig| %s within %s (%.1fs)\n", k, n, sig, seed,
			status, format(signif(calib_num(v$max_coef_diff_se), 3)), format(signif(calib_num(v$log_sigma_diff), 3)),
			format(if (is.null(v$within_bound)) NA else v$within_bound), r$elapsed_sec))
	}

	rows <- calib_read_rows(file.path(out_dir, "rows.csv"))
	summ <- qb_summary(rows, min_usable_frac)
	utils::write.csv(summ, file.path(out_dir, "summary.csv"), row.names = FALSE, na = "NA")
	all_pass <- nrow(summ) > 0L && all(summ$pass %in% TRUE)
	writeLines(c("# TODO-31/50 four-kernel 20-vs-320 quadrature bound grid (G4-C R8)", "",
		if (opt$smoke) "**SMOKE RUN: mechanics only, not evidence.**" else NULL, "",
		sprintf("EDI %s, DLL sha256 %s, checkout HEAD %s (dirty: %s).", prov$edi_package_version, prov$edi_dll_sha256,
			prov$checkout_head, prov$checkout_dirty),
		sprintf("Kernels: %s; n = %s (groups of %d); true sigma = %s; seeds = %s; n_gh %d vs %d.",
			paste(kernels, collapse = ", "), paste(ns, collapse = ","), QB_GROUP_SIZE, paste(sigmas, collapse = ","),
			calib_describe_ints(seeds), n_gh_low, n_gh_high),
		sprintf("Bound (owner 2026-10-21): max |coef diff| <= %g SE (320-node SE) and |log sigma diff| <= %g, on every usable cell;",
			coef_bound, ls_bound),
		sprintf("a stratum also needs >= %g of its cells usable (both fits converged and finite).", min_usable_frac),
		sprintf("Overall: %s", if (all_pass) "PASS" else "NOT PASSED (see out_of_bound / enough_usable below)"), "",
		calib_write_markdown_table(summ)), file.path(out_dir, "summary.md"))
	print(summ, row.names = FALSE)
	calib_finish_provenance(out_dir, extra = list(overall_pass = all_pass))
	cat("overall:", if (all_pass) "PASS" else "NOT PASSED", "\n")
	cat("wrote", out_dir, "\n")
}

main(commandArgs(trailingOnly = TRUE))
