#!/usr/bin/env Rscript
# TODO-8 (release_v1_0_5.md; linked plan bug_fix_plans/multimodal_log_liks.md -> TODO-4):
# stereotype-logit 400-seed null rerun, G4-C calibration runbook R2 (decisions G6 #32, #20).
#
# A FRESH, provenance-pinned run on the installed (G1) build. It is NOT a replay
# of the Sep 21 / Oct 14 studies: their covariate and cut-point generator is not
# recoverable, so this script defines its own null DGP (below) and records it.
#
# Null DGP per (configuration, seed): set.seed(seed); x ~ N(0, 1);
#   w = balanced 0/1 from DesignFixediBCRD (n/2 treated);
#   y in 1..K from a stereotype-logit model WITHOUT a treatment term:
#     logit_1 = 0, logit_k = alpha_k + phi_k * (0.7 * x), k = 2..K,
#     alpha = seq(-0.2, 0.2, length.out = K - 1), phi = seq(0, 1, length.out = K)[-1]
#   (for K = 3 this is the fixture of test-stereotype-logit-full-fit-multistart.R).
#   The true treatment effect is 0, so the LR p-value's Type-I rate and the
#   LR-bootstrap CI's coverage of 0 are the targets.
# Configurations (strata): "n100_K5" (n = 100, K = 5) and "n50_K3" (n = 50, K = 3).
#
# Per seed x configuration it records (one row per method):
#   estimate               compute_estimate()
#   lik_ratio_pval         compute_lik_ratio_two_sided_pval()
#   lik_ratio_bootstrap_ci compute_lik_ratio_bootstrap_confidence_interval(B = --lrboot-b)
# with status (ok / nonestimable / error / timeout), error stage
# (get_nonestimable_reason(), e.g. model_fit_unavailable), elapsed seconds,
# whether the full-data multistart improved the NLL (the class's own cached
# fit), the zero-width flag, and a DIAGNOSTIC Fisher-information reciprocal
# condition number from a separate single-start EDI:::fast_stereotype_logit_with_var_cpp
# refit of the same data (not the class's usability gate itself).
#
# Outputs in --out-dir (fresh, outside the checkout):
#   rows.csv, provenance.rds/.txt, type1_summary.csv/.md (LR p-value, strata =
#   configurations, #20 rule), ci_coverage.csv, diagnostics.csv, summary.md.
# Pass (runbook R2): #20 rule PASS for the LR p-value in both configurations AND
# zero zero-width CIs. 400 seeds is below #20's 500-per-stratum target; the
# shortfall is stated in the summary. Extending to 1001:1500 needs the owner.
#
# Usage:
#   Rscript R/package_tests/calibration/todo8_stereotype_null_study.R --out-dir $D \
#     [--seeds 1001:1400] [--configs n100_K5,n50_K3] [--lrboot-b 199] [--timeout-sec 0] [--smoke]

local({
	f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
	here <- dirname(normalizePath(sub("^--file=", "", f[[1L]])))
	source(file.path(here, "calibration_common.R"))
	source(file.path(here, "summarize_type1_calibration.R"))
}, envir = globalenv())

TODO8_CONFIGS <- list(
	n100_K5 = list(n = 100L, K = 5L),
	n50_K3 = list(n = 50L, K = 3L)
)

todo8_generate <- function(seed, n, K) {
	set.seed(seed)
	x <- stats::rnorm(n)
	des <- DesignFixediBCRD$new(response_type = "ordinal", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x))
	des$assign_w_to_all_subjects()
	w <- as.numeric(des$get_w())
	alpha <- seq(-0.2, 0.2, length.out = K - 1L)
	phi <- seq(0, 1, length.out = K)[-1L]
	eta <- 0.7 * x
	probs <- t(vapply(eta, function(e) {
		logits <- c(0, alpha + phi * e)
		p <- exp(logits - max(logits))
		p / sum(p)
	}, numeric(K)))
	y <- apply(probs, 1L, function(p) sample.int(K, 1L, prob = p))
	des$add_all_subject_responses(y)
	list(des = des, x = x, w = w, y = y)
}

todo8_rcond_diag <- function(x, w, y) {
	fit <- tryCatch(EDI:::fast_stereotype_logit_with_var_cpp(cbind(treatment = w, x1 = x), as.numeric(y)),
		error = function(e) NULL)
	info <- fit$fisher_information
	if (is.null(info) || !is.matrix(info) || any(!is.finite(info))) return(NA_real_)
	tryCatch(rcond(info), error = function(e) NA_real_)
}

ROW_COLUMNS <- c(
	"config", "n", "K", "seed", "method", "stratum", "status", "error_stage", "estimate", "pval", "ci_lo", "ci_hi",
	"truth", "covers_truth", "zero_width", "multistart_improved", "multistart_improvement", "multistart_selected_start",
	"multistart_n_tried", "fisher_rcond_diag", "rcond_gate", "n_levels_observed", "n_treated", "data_sha256",
	"lrboot_B", "elapsed_sec", "warnings", "error_message"
)

main <- function(args) {
	usage <- paste(
		"Usage: Rscript R/package_tests/calibration/todo8_stereotype_null_study.R --out-dir DIR",
		"  [--seeds 1001:1400] [--configs n100_K5,n50_K3] [--lrboot-b 199] [--alpha 0.05] [--timeout-sec 0] [--smoke]",
		"--smoke: seeds 1001:1003, --lrboot-b 99 (mechanics only; never evidence).", sep = "\n")
	opt <- calib_parse_args(args, defaults = list(out_dir = "", seeds = "1001:1400", configs = "n100_K5,n50_K3",
		lrboot_b = "199", alpha = "0.05", timeout_sec = "0"), flags = "smoke", usage = usage)
	if (opt$smoke) {
		if (identical(opt$seeds, "1001:1400")) opt$seeds <- "1001:1003"
		if (identical(opt$lrboot_b, "199")) opt$lrboot_b <- "99"
	}
	script <- calib_script_path()
	repo_root <- calib_find_repo_root(dirname(script))
	out_dir <- calib_prepare_output_dir(opt$out_dir, repo_root)
	calib_load_installed_edi(repo_root)
	seeds <- calib_parse_int_set(opt$seeds)
	configs <- calib_parse_chr_set(opt$configs)
	if (!all(configs %in% names(TODO8_CONFIGS))) stop("unknown config; choose from ", paste(names(TODO8_CONFIGS), collapse = ", "))
	B <- as.integer(opt$lrboot_b)
	alpha <- as.numeric(opt$alpha)
	timeout <- as.numeric(opt$timeout_sec)
	prov <- calib_capture_provenance(repo_root, script, out_dir, args, seeds, extra = list(
		study = "TODO-8 stereotype-logit null rerun (G4-C R2)", smoke = opt$smoke, configs = TODO8_CONFIGS[configs],
		lrboot_B = B, alpha = alpha, dgp = "see script header (fresh generator; not a historical replay)"))
	cat("EDI", prov$edi_package_version, "from", prov$edi_package_path, "DLL sha256", prov$edi_dll_sha256, "\n")
	write_row <- calib_row_writer(file.path(out_dir, "rows.csv"), ROW_COLUMNS)
	rcond_gate <- sqrt(.Machine$double.eps)

	for (cfg_name in configs) {
		cfg <- TODO8_CONFIGS[[cfg_name]]
		for (seed in seeds) {
			gen <- tryCatch(todo8_generate(seed, cfg$n, cfg$K), error = function(e) e)
			base <- list(config = cfg_name, n = cfg$n, K = cfg$K, seed = seed, stratum = cfg_name, truth = 0, lrboot_B = B)
			if (inherits(gen, "error")) {
				for (m in c("estimate", "lik_ratio_pval", "lik_ratio_bootstrap_ci")) {
					write_row(c(base, list(method = m, status = "error", error_stage = "data_generation",
						error_message = calib_clean_msg(conditionMessage(gen)))))
				}
				next
			}
			data_sha <- calib_object_sha256(list(x = gen$x, w = gen$w, y = gen$y))
			rc <- todo8_rcond_diag(gen$x, gen$w, gen$y)
			common <- c(base, list(n_levels_observed = length(unique(gen$y)), n_treated = sum(gen$w),
				data_sha256 = data_sha, fisher_rcond_diag = rc, rcond_gate = rcond_gate))
			inf <- InferenceOrdinalStereotypeLogitRegr$new(gen$des, verbose = FALSE)
			stage <- function() calib_clean_msg(tryCatch(inf$get_nonestimable_reason(), error = function(e) NA_character_))

			r_est <- calib_eval(function() inf$compute_estimate(), timeout_sec = timeout)
			cm <- tryCatch(inf$.__enclos_env__$private$cached_mod, error = function(e) NULL)
			ms <- list(
				multistart_improvement = calib_num(cm$multistart_improvement),
				multistart_improved = if (is.finite(calib_num(cm$multistart_improvement))) calib_num(cm$multistart_improvement) > 0 else NA,
				multistart_selected_start = if (is.null(cm$multistart_selected_start)) NA_character_ else as.character(cm$multistart_selected_start),
				multistart_n_tried = calib_num(cm$multistart_n_tried)
			)
			est <- calib_num(r_est$value)
			write_row(c(common, ms, list(method = "estimate", status = r_est$status,
				error_stage = if (r_est$status == "ok") NA else stage(), estimate = est,
				elapsed_sec = r_est$elapsed_sec, warnings = calib_clean_msg(r_est$warnings),
				error_message = calib_clean_msg(r_est$error_message))))

			r_p <- calib_eval(function() inf$compute_lik_ratio_two_sided_pval(), timeout_sec = timeout)
			p <- calib_num(r_p$value)
			write_row(c(common, ms, list(method = "lik_ratio_pval", status = r_p$status,
				error_stage = if (r_p$status == "ok") NA else stage(), estimate = est, pval = p,
				elapsed_sec = r_p$elapsed_sec, warnings = calib_clean_msg(r_p$warnings),
				error_message = calib_clean_msg(r_p$error_message))))

			r_ci <- calib_eval(function() inf$compute_lik_ratio_bootstrap_confidence_interval(alpha = alpha, B = B),
				is_ok = function(v) length(v) >= 2L && all(is.finite(as.numeric(v[1:2]))), timeout_sec = timeout)
			lo <- calib_num(r_ci$value, 1L)
			hi <- calib_num(r_ci$value, 2L)
			ci_ok <- r_ci$status == "ok"
			write_row(c(common, ms, list(method = "lik_ratio_bootstrap_ci", status = r_ci$status,
				error_stage = if (ci_ok) NA else stage(), estimate = est, ci_lo = lo, ci_hi = hi,
				covers_truth = if (ci_ok) (lo <= 0 && 0 <= hi) else NA,
				zero_width = if (ci_ok) abs(hi - lo) <= 1e-10 * max(1, abs(est), na.rm = TRUE) else NA,
				elapsed_sec = r_ci$elapsed_sec, warnings = calib_clean_msg(r_ci$warnings),
				error_message = calib_clean_msg(r_ci$error_message))))
			cat(sprintf("%s seed %d: est %s (%s) p %s (%s) ci [%s, %s] (%s) %.1fs\n", cfg_name, seed,
				format(signif(est, 4)), r_est$status, format(signif(p, 4)), r_p$status,
				format(signif(lo, 4)), format(signif(hi, 4)), r_ci$status,
				r_est$elapsed_sec + r_p$elapsed_sec + r_ci$elapsed_sec))
		}
	}

	rows <- calib_read_rows(file.path(out_dir, "rows.csv"))
	todo8_summarize(rows, out_dir, alpha = alpha, n_seeds = length(seeds), smoke = opt$smoke)
	calib_finish_provenance(out_dir)
	cat("wrote", out_dir, "\n")
}

todo8_summarize <- function(rows, out_dir, alpha, n_seeds, smoke) {
	lr <- rows[rows$method == "lik_ratio_pval", , drop = FALSE]
	t1 <- summarize_type1_rows(data.frame(method = "lik_ratio_pval", stratum = lr$stratum, seed = lr$seed,
		pval = lr$pval, status = lr$status, stringsAsFactors = FALSE), alpha = alpha, target = 500L)
	notes <- c(
		sprintf("%d seeds per configuration; #20 targets 500 per stratum (shortfall %d per stratum). Extending needs the owner (runbook R2).",
			n_seeds, max(0L, 500L - n_seeds)),
		"Fresh DGP defined in the script header; not a replay of the historical 386/400 or 169/400 denominators.",
		if (smoke) "SMOKE RUN: mechanics only, not calibration evidence." else NULL)
	write_type1_summary(t1, out_dir, prefix = "type1", notes = notes,
		title = "TODO-8 stereotype-logit null: LR p-value Type-I (G6 #20)")

	ci <- rows[rows$method == "lik_ratio_bootstrap_ci", , drop = FALSE]
	cov <- do.call(rbind, lapply(split(ci, ci$config), function(d) {
		lr_d <- lr[lr$config == d$config[[1L]], , drop = FALSE]
		fin_p_seeds <- lr_d$seed[lr_d$status == "ok" & is.finite(lr_d$pval)]
		fin_ci <- d$status == "ok"
		same <- fin_ci & d$seed %in% fin_p_seeds
		cp_all <- calib_cp_interval(sum(d$covers_truth %in% TRUE & fin_ci), sum(fin_ci))
		cp_same <- calib_cp_interval(sum(d$covers_truth %in% TRUE & same), sum(same))
		data.frame(config = d$config[[1L]], n_att = nrow(d), n_finite_ci = sum(fin_ci),
			covered = sum(d$covers_truth %in% TRUE & fin_ci), coverage = if (sum(fin_ci)) mean(d$covers_truth[fin_ci] %in% TRUE) else NA,
			cp_lower = cp_all[[1L]], cp_upper = cp_all[[2L]],
			n_finite_ci_and_p = sum(same), coverage_on_finite_p_denominator = if (sum(same)) mean(d$covers_truth[same] %in% TRUE) else NA,
			cp_lower_finite_p = cp_same[[1L]], cp_upper_finite_p = cp_same[[2L]],
			zero_width_cis = sum(d$zero_width %in% TRUE), stringsAsFactors = FALSE)
	}))
	utils::write.csv(cov, file.path(out_dir, "ci_coverage.csv"), row.names = FALSE, na = "NA")

	est <- rows[rows$method == "estimate", , drop = FALSE]
	diag <- do.call(rbind, lapply(split(est, est$config), function(d) {
		data.frame(config = d$config[[1L]], seeds = nrow(d), estimate_ok = sum(d$status == "ok"),
			multistart_improved = sum(d$multistart_improved %in% TRUE),
			model_fit_unavailable = sum(grepl("model_fit_unavailable", d$error_stage)),
			other_nonestimable = sum(d$status != "ok" & !grepl("model_fit_unavailable", d$error_stage)),
			rcond_diag_below_gate = sum(is.finite(d$fisher_rcond_diag) & d$fisher_rcond_diag <= d$rcond_gate),
			median_elapsed_sec_all_methods = stats::median(tapply(rows$elapsed_sec[rows$config == d$config[[1L]]],
				rows$seed[rows$config == d$config[[1L]]], sum, na.rm = TRUE)),
			stringsAsFactors = FALSE)
	}))
	utils::write.csv(diag, file.path(out_dir, "diagnostics.csv"), row.names = FALSE, na = "NA")

	pass_t1 <- nrow(t1) > 0L && all(t1$verdict == "PASS")
	pass_zw <- all(cov$zero_width_cis == 0L)
	writeLines(c(
		"# TODO-8 stereotype-logit null rerun (G4-C R2)", "",
		if (smoke) "**SMOKE RUN: mechanics only, not calibration evidence.**" else NULL, "",
		sprintf("Overall (runbook R2 pass rule): %s -- #20 PASS in all configurations: %s; zero zero-width CIs: %s.",
			if (pass_t1 && pass_zw) "PASS" else "NOT PASSED", pass_t1, pass_zw),
		"", "## LR p-value Type-I (type1_summary.csv)", "",
		calib_write_markdown_table(t1[c("stratum", "n_att", "n_fin", "k", "rate", "cp_lower", "cp_upper", "verdict", "meets_target")]),
		"", "## LR-bootstrap CI coverage of 0 (ci_coverage.csv)", "", calib_write_markdown_table(cov),
		"", "## Fit diagnostics (diagnostics.csv)", "", calib_write_markdown_table(diag),
		"", "Notes:", paste0("- ", c(notes,
			"fisher_rcond_diag is from a separate single-start refit (diagnostic); the class gate uses the free-parameter block.",
			"Denominators are this run's own; the historical counts are not reconciled (runbook R2)."))
	), file.path(out_dir, "summary.md"))
	print(t1[c("stratum", "n_att", "n_fin", "k", "rate", "cp_lower", "cp_upper", "verdict")], row.names = FALSE)
	print(cov, row.names = FALSE)
	invisible(NULL)
}

main(commandArgs(trailingOnly = TRUE))
