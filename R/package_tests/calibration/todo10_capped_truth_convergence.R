#!/usr/bin/env Rscript
# TODO-10 (release_v1_0_5.md; linked plan bug_fix_plans/mc_coverage_truth_covariate_mismatch.md
# -> TODO-6): capped-covariate MC coverage-truth convergence check for the two
# KK-matched Cox classes, G4-C calibration runbook R7 (decision G6 #19).
#
# Classes: InferenceSurvivalKKStratCoxPHOneLik, InferenceSurvivalKKLWACoxPHOneLik (the two
# entries of COVERAGE_TRUTH_UNAVAILABLE in comprehensive_tests.R). The truth is
# computed exactly as comprehensive_tests.R's compute_mc_coverage_truth_simframe()
# does (SimulationFramework, DesignFixedBinaryMatch, the harness's survival
# censoring and apply_treatment_effect_and_noise(), both parsed from
# comprehensive_tests.R), except that the real covariates are CAPPED to the first
# K columns of the harness dataset's X (default K = 6, the plan's 5-8 range) and
# the rows are built by one of two schemes:
#   block     : block-recycled rows (the harness's construction: rows 1..n0 repeated);
#   bootstrap : paired (X, y_base) rows resampled with replacement (sensitivity analysis).
# Grid: mc_n in {3000, 6000, 12000} x scheme x 3 seeds (seed base + 1..3) per class x dataset
# x beta_T. The request type is asymp_ci so each fit also yields a model-based
# standard error at that mc_n (MC SE = CI width / (2 * qnorm(0.975))); the truth
# itself is the fit's estimate, which SimulationFramework computes before any
# inference type (so it equals the harness's asymp_pval truth).
#
# Pass (owner-approved 2026-10-23, closing-audit decision 2; runbook R7), per class x dataset x beta_T:
#   (a) at the largest mc_n, every pair of estimates (2 schemes x 3 seeds) differs by
#       <= 2 * sqrt(se_i^2 + se_j^2);
#   (b) for every scheme x seed, |est(largest mc_n) - est(second-largest mc_n)| < se(largest mc_n).
# If the check fails, the classes stay in COVERAGE_TRUTH_UNAVAILABLE.
# Runtime warning: DesignFixedBinaryMatch runs nbpMatching non-bipartite matching on
# mc_n subjects (O(n^3) time, O(n^2) memory); mc_n = 12000 may be very slow or exceed
# memory. Use --mc-n / --datasets / --classes to stage the run.
#
# Usage:
#   Rscript R/package_tests/calibration/todo10_capped_truth_convergence.R --out-dir $D \
#     [--classes InferenceSurvivalKKStratCoxPHOneLik,InferenceSurvivalKKLWACoxPHOneLik]
#     [--datasets all|d1,d2] [--betas 0,0.5] [--K 6] [--mc-n 3000,6000,12000] [--seeds 1:3]
#     [--seed-base 10000] [--schemes block,bootstrap] [--timeout-sec 0] [--smoke]

local({
	f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
	here <- dirname(normalizePath(sub("^--file=", "", f[[1L]])))
	source(file.path(here, "calibration_common.R"))
}, envir = globalenv())

TODO10_CLASSES <- c("InferenceSurvivalKKStratCoxPHOneLik", "InferenceSurvivalKKLWACoxPHOneLik")

ROW_COLUMNS <- c(
	"class", "dataset", "beta_T", "scheme", "mc_n", "seed_index", "seed", "K", "covariates", "status", "estimate", "se",
	"ci_lo", "ci_hi", "inference_type", "result_rows", "elapsed_sec", "warnings", "error_message"
)

todo10_harness_env <- function(repo_root) {
	env <- new.env(parent = globalenv())
	runner <- file.path(repo_root, "R", "package_tests", "comprehensive_tests.R")
	calib_eval_harness_objects(runner, c("SD_NOISE_BY_RESPONSE_TYPE", "sd_noise_for", "prob_censoring", "apply_treatment_effect_and_noise"), env)
	environment(env$apply_treatment_effect_and_noise) <- env
	env
}

# class_names may name several classes: SimulationFramework builds the
# DesignFixedBinaryMatch design (the nbpMatching cost) once and fits every
# class on that same assignment and response; res$inference holds the class.
todo10_fit_truth <- function(class_names, dataset, D, beta_val, scheme, mc_n, K, harness, inference_type = "asymp_ci") {
	y_base <- D$y_original[["survival"]]
	real_X <- as.data.frame(D$X)[, seq_len(min(K, ncol(D$X))), drop = FALSE]
	n0 <- length(y_base)
	if (nrow(real_X) != n0) stop("dataset X and y_base row counts differ")
	idx <- if (identical(scheme, "block")) rep(seq_len(n0), ceiling(mc_n / n0))[seq_len(mc_n)] else
		sample.int(n0, mc_n, replace = TRUE)
	assign("beta_T", beta_val, envir = harness)
	custom_data <- function(state, rep) {
		list(X = real_X[idx[seq_len(state$n)], , drop = FALSE], y_linear_model = as.numeric(y_base)[idx[seq_len(state$n)]])
	}
	custom_apply <- function(y_linear_model, w, state) {
		n <- length(y_linear_model)
		y_lin <- y_linear_model
		dead_mc <- rep(1L, n)
		t_f_mc <- stats::quantile(y_lin, .95)
		cens <- stats::runif(n) < harness$prob_censoring | y_lin >= t_f_mc
		if (any(cens)) {
			y_lin[cens] <- stats::runif(sum(cens), 0, y_lin[cens])
			dead_mc[cens] <- 0
		}
		y <- vapply(seq_len(n), function(i) harness$apply_treatment_effect_and_noise(y_lin[i], w[i], "survival"), numeric(1))
		list(y = y, dead = dead_mc)
	}
	results_filename <- tempfile(fileext = ".csv")
	on.exit(unlink(Sys.glob(paste0(sub("\\.csv$", "", results_filename), "*")), recursive = TRUE, force = TRUE), add = TRUE)
	itp <- list(list())
	names(itp) <- inference_type
	sim <- SimulationFramework$new(
		response_type = "survival",
		design_classes_and_params = list(DesignFixedBinaryMatch),
		inference_classes_and_params = lapply(class_names, get, envir = asNamespace("EDI")),
		inference_types_and_params = itp,
		n = mc_n, p = ncol(real_X), Nrep_W = 1L, Nrep_Y_w = 1L,
		betaT = beta_val,
		custom_replication_data_generator = custom_data,
		custom_apply_treatment_and_noise = custom_apply,
		results_filename = results_filename,
		continue_from_last_result_row = FALSE,
		verbose = FALSE,
		stop_on_error = FALSE
	)
	sim$run()
	res <- SimulationFrameworkReport$new(sim)$get_results()
	list(res = res, covariates = names(real_X))
}

main <- function(args) {
	usage <- paste(
		"Usage: Rscript R/package_tests/calibration/todo10_capped_truth_convergence.R --out-dir DIR",
		"  [--classes C1,C2] [--datasets all|d1,d2] [--betas 0,0.5] [--K 6] [--mc-n 3000,6000,12000]",
		"  [--seeds 1:3] [--seed-base 10000] [--schemes block,bootstrap] [--timeout-sec 0] [--smoke]",
		"--smoke: --datasets pte_example --betas 0.5 --mc-n 200,300,400 --seeds 1:2 (mechanics only).", sep = "\n")
	opt <- calib_parse_args(args, defaults = list(out_dir = "", classes = paste(TODO10_CLASSES, collapse = ","),
		datasets = "all", betas = "0.5", K = "6", mc_n = "3000,6000,12000", seeds = "1:3", seed_base = "10000",
		schemes = "block,bootstrap", timeout_sec = "0"), flags = "smoke", usage = usage)
	if (opt$smoke) {
		if (identical(opt$datasets, "all")) opt$datasets <- "pte_example"
		if (identical(opt$mc_n, "3000,6000,12000")) opt$mc_n <- "200,300,400"
		if (identical(opt$seeds, "1:3")) opt$seeds <- "1:2"
	}
	script <- calib_script_path()
	repo_root <- calib_find_repo_root(dirname(script))
	out_dir <- calib_prepare_output_dir(opt$out_dir, repo_root)
	calib_load_installed_edi(repo_root)
	classes <- calib_parse_chr_set(opt$classes)
	if (!all(classes %in% TODO10_CLASSES)) stop("classes must be among ", paste(TODO10_CLASSES, collapse = ", "))
	datasets_all <- calib_load_harness_datasets(repo_root)
	surv_ds <- names(datasets_all)[vapply(datasets_all, function(d) "survival" %in% names(d$y_original), logical(1L))]
	datasets <- if (identical(opt$datasets, "all")) surv_ds else calib_parse_chr_set(opt$datasets)
	if (!all(datasets %in% surv_ds)) stop("datasets must have a survival response: ", paste(surv_ds, collapse = ", "))
	betas <- calib_parse_num_set(opt$betas)
	K <- as.integer(opt$K)
	mc_ns <- sort(as.integer(calib_parse_num_set(opt$mc_n)))
	seed_idx <- calib_parse_int_set(opt$seeds)
	seed_base <- as.integer(opt$seed_base)
	schemes <- calib_parse_chr_set(opt$schemes)
	if (!all(schemes %in% c("block", "bootstrap"))) stop("schemes must be block and/or bootstrap")
	timeout <- as.numeric(opt$timeout_sec)
	harness <- todo10_harness_env(repo_root)
	prov <- calib_capture_provenance(repo_root, script, out_dir, args, seed_base + seed_idx, extra = list(
		study = "TODO-10 capped matched-Cox MC truth convergence (G4-C R7)", smoke = opt$smoke, classes = classes,
		datasets = datasets, betas = betas, K = K, mc_n = mc_ns, schemes = schemes,
		sd_noise = harness$sd_noise_for("survival"), prob_censoring = harness$prob_censoring,
		harness_runner_sha256 = calib_sha256(file.path(repo_root, "R", "package_tests", "comprehensive_tests.R")),
		dataset_loader_sha256 = calib_sha256(file.path(repo_root, "R", "package_tests", "_dataset_load.R")),
		dataset_rows_sha256 = vapply(datasets, function(d) calib_object_sha256(list(X = datasets_all[[d]]$X,
			y = datasets_all[[d]]$y_original$survival)), character(1L))))
	cat("EDI", prov$edi_package_version, "from", prov$edi_package_path, "DLL sha256", prov$edi_dll_sha256, "\n")
	write_row <- calib_row_writer(file.path(out_dir, "rows.csv"), ROW_COLUMNS)

	# One shared fit per dataset x beta x scheme x mc_n x seed covers every class
	# (same seed, so the same rows, censoring, assignment and matching). A class
	# with no asymp_ci row falls back to asymp_pval in a fit of its own.
	class_res <- function(v, cls) {
		if (is.null(v) || !nrow(v$res)) return(v$res[0L, , drop = FALSE])
		v$res[as.character(v$res$inference) == cls, , drop = FALSE]
	}
	for (ds in datasets) for (b in betas) for (sch in schemes) for (mc_n in mc_ns) for (s in seed_idx) {
		seed <- seed_base + s
		r <- calib_eval(function() {
			set.seed(seed)
			out <- todo10_fit_truth(classes, ds, datasets_all[[ds]], b, sch, mc_n, K, harness, "asymp_ci")
			out$inference_type <- stats::setNames(rep("asymp_ci", length(classes)), classes)
			for (cls in classes) if (!nrow(class_res(out, cls))) {
				set.seed(seed)
				fb <- todo10_fit_truth(cls, ds, datasets_all[[ds]], b, sch, mc_n, K, harness, "asymp_pval")
				out$res <- rbind(out$res[as.character(out$res$inference) != cls, , drop = FALSE], fb$res, make.row.names = FALSE)
				out$inference_type[[cls]] <- "asymp_pval"
			}
			out
		}, is_ok = function(v) all(vapply(classes, function(cls) {
			x <- class_res(v, cls)
			nrow(x) >= 1L && is.finite(as.numeric(x$estimate[1L]))
		}, logical(1L))), timeout_sec = timeout)
		v <- r$value
		for (cls in classes) {
			x <- class_res(v, cls)
			base <- list(class = cls, dataset = ds, beta_T = b, scheme = sch, mc_n = mc_n, seed_index = s, seed = seed, K = K)
			est <- if (nrow(x)) as.numeric(x$estimate[1L]) else NA_real_
			lo <- if ("ci_lo" %in% names(x) && nrow(x)) as.numeric(x$ci_lo[1L]) else NA_real_
			hi <- if ("ci_hi" %in% names(x) && nrow(x)) as.numeric(x$ci_hi[1L]) else NA_real_
			se <- if (is.finite(lo) && is.finite(hi)) (hi - lo) / (2 * stats::qnorm(0.975)) else NA_real_
			status <- if (identical(r$status, "ok") || is.finite(est)) r$status else "invalid"
			# elapsed_sec is the shared fit's wall time (both classes together).
			write_row(c(base, list(covariates = if (is.null(v)) NA else paste(v$covariates, collapse = ";"), status = status,
				estimate = est, se = se, ci_lo = lo, ci_hi = hi, inference_type = if (is.null(v)) NA else v$inference_type[[cls]],
				result_rows = nrow(x), elapsed_sec = r$elapsed_sec,
				warnings = calib_clean_msg(r$warnings), error_message = calib_clean_msg(r$error_message))))
			cat(sprintf("%s %s beta %g %s mc_n %d seed %d: est %s se %s (%s, %.1fs shared)\n", cls, ds, b, sch, mc_n, seed,
				format(signif(est, 5)), format(signif(se, 3)), status, r$elapsed_sec))
		}
	}

	rows <- calib_read_rows(file.path(out_dir, "rows.csv"))
	summ <- todo10_convergence_summary(rows, mc_ns)
	utils::write.csv(summ, file.path(out_dir, "convergence_summary.csv"), row.names = FALSE, na = "NA")
	all_pass <- nrow(summ) > 0L && all(summ$pass %in% TRUE)
	writeLines(c("# TODO-10 capped matched-Cox MC truth convergence (G4-C R7)", "",
		if (opt$smoke) "**SMOKE RUN: mechanics only, not evidence.**" else NULL, "",
		sprintf("K = %d (first K harness covariates); mc_n = %s; schemes = %s; seeds = %s.", K, paste(mc_ns, collapse = ","),
			paste(schemes, collapse = ","), calib_describe_ints(seed_base + seed_idx)),
		"Pass (owner-approved 2026-10-23): (a) all estimates at the largest mc_n agree pairwise within 2 combined MC SEs;",
		"(b) every scheme x seed moves < 1 MC SE between the two largest mc_n. Fail -> classes stay unavailable.",
		sprintf("Overall: %s", if (all_pass) "PASS (classes may leave COVERAGE_TRUTH_UNAVAILABLE once the harness cap lands)" else
			"NOT PASSED (keep both classes in COVERAGE_TRUTH_UNAVAILABLE)"), "",
		calib_write_markdown_table(summ)), file.path(out_dir, "convergence_summary.md"))
	print(summ, row.names = FALSE)
	calib_finish_provenance(out_dir)
	cat("wrote", out_dir, "\n")
}

todo10_convergence_summary <- function(rows, mc_ns) {
	top <- max(mc_ns)
	prev <- if (length(mc_ns) >= 2L) sort(mc_ns, decreasing = TRUE)[2L] else NA_integer_
	groups <- unique(rows[c("class", "dataset", "beta_T")])
	do.call(rbind, lapply(seq_len(nrow(groups)), function(i) {
		g <- rows[rows$class == groups$class[i] & rows$dataset == groups$dataset[i] & rows$beta_T == groups$beta_T[i], , drop = FALSE]
		at_top <- g[g$mc_n == top, , drop = FALSE]
		ok_top <- at_top$status == "ok" & is.finite(at_top$estimate) & is.finite(at_top$se)
		pair_ok <- NA
		max_pair_z <- NA_real_
		if (sum(ok_top) >= 2L) {
			e <- at_top$estimate[ok_top]
			s <- at_top$se[ok_top]
			z <- outer(seq_along(e), seq_along(e), Vectorize(function(a, b) if (a < b) abs(e[a] - e[b]) / sqrt(s[a]^2 + s[b]^2) else NA_real_))
			max_pair_z <- max(z, na.rm = TRUE)
			pair_ok <- max_pair_z <= 2
		}
		step_ok <- NA
		max_step_z <- NA_real_
		if (is.finite(prev)) {
			key <- function(d) paste(d$scheme, d$seed_index)
			a <- at_top[ok_top, , drop = FALSE]
			p <- g[g$mc_n == prev & g$status == "ok" & is.finite(g$estimate), , drop = FALSE]
			m <- match(key(a), key(p))
			if (length(m) && all(!is.na(m))) {
				zz <- abs(a$estimate - p$estimate[m]) / a$se
				max_step_z <- max(zz)
				step_ok <- all(zz < 1)
			}
		}
		data.frame(class = groups$class[i], dataset = groups$dataset[i], beta_T = groups$beta_T[i],
			fits = nrow(g), fits_ok = sum(g$status == "ok"), top_mc_n = top, top_fits_ok = sum(ok_top),
			mean_estimate_top = if (any(ok_top)) mean(at_top$estimate[ok_top]) else NA_real_,
			sd_estimate_top = if (sum(ok_top) >= 2L) stats::sd(at_top$estimate[ok_top]) else NA_real_,
			mean_se_top = if (any(ok_top)) mean(at_top$se[ok_top]) else NA_real_,
			max_pairwise_z_top = max_pair_z, pairwise_within_2se = pair_ok,
			prev_mc_n = prev, max_step_z = max_step_z, step_below_1se = step_ok,
			pass = isTRUE(pair_ok) && isTRUE(step_ok) && sum(ok_top) == nrow(at_top), stringsAsFactors = FALSE)
	}))
}

main(commandArgs(trailingOnly = TRUE))
