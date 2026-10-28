#!/usr/bin/env Rscript
# TODO-18 (release_v1_0_5.md; linked plan bug_fix_plans/rand_bootstrap_smoothed_noise_unclamped.md
# -> TODO-6): smoothed randomization-bootstrap (BRT) true-null calibration roster,
# G4-C calibration runbook R3 (decisions G6 #35: the 9 named cells; G6 #20: rule).
#
# Prerequisite (runbook R3): the plan TODO-1/2 dispatch/support cross-reference
# and continuous-bandwidth investigation come first. This script only runs the
# calibration.
#
# Roster (TODO-18 entry, 2026-10-21 protocol note; cell id: class / model formula):
#   C1 continuous InferenceContinKKRobustRegrOneLik / ~1     C2 continuous InferenceContinOLS / ~.
#   N1 count InferenceAllSimpleAverageDiff / NA              N2 count InferenceCountHurdleNegBin / ~1
#   N3 count InferenceCountHurdlePoisson / ~1                N4 count InferenceCountKKHurdlePoissonOneLik / ~1
#   N5 count InferenceCountPoisson / ~.                      N6 count InferenceCountZeroInflatedNegBin / ~1
#   N7 count InferenceCountZeroInflatedPoisson / ~1
#
# True-null DGP (not fixed by the decisions; agent choice, recorded per row):
# the comprehensive harness's own null DGP -- datasets from
# R/package_tests/_dataset_load.R (loaded as comprehensive_tests.R does) and
# apply_treatment_effect_and_noise() parsed from comprehensive_tests.R, at
# beta_T = 0, per-type SD_NOISE_BY_RESPONSE_TYPE from the harness. Default dataset `diamonds` (n = 148,
# both continuous and count responses). Design: the harness's `FixedBinaryMatch`
# (DesignFixedBinaryMatch) for the KK classes, which require a matched design,
# and the harness's `Bernoulli` (DesignSeqOneByOneBernoulli) otherwise; design
# formula ~. (the historical cells' design/dataset are not recoverable).
#
# Per outer case (cell, case i): seed = cell base + i; set.seed(seed) -> design
# assignment + null responses; set.seed(seed + 10^7) -> B = 101 materialized
# assignments from the class's own generate_rand_bootstrap_draws() (a private
# method, reached through the R6 enclosure); the SAME draws feed
#   percentile: compute_rand_bootstrap_two_sided_pval(type = "percentile", rand_bootstrap_draws = draws)
#   smoothed:   set.seed(seed + 2*10^7); compute_rand_bootstrap_two_sided_pval(type = "smoothed", rand_bootstrap_draws = draws)
# (the smoothed call adds its own kernel noise, bandwidth sd(y)/sqrt(n), from that seed).
# Cases are drawn per cell until both variants have >= --target-finite finite
# p-values (default 500; the plan's ">= 500 estimable" reading of #20) or
# --max-cases is reached.
#
# Outputs in --out-dir: rows.csv (one row per case x variant), type1_summary.csv/.md
# (cell x variant, #20 rule, finite target basis), discordance.csv (paired
# percentile-reject XOR smoothed-reject), guard_check.csv (bounded categorical
# smoothed calls must still be rejected), cells.csv, provenance.rds/.txt, summary.md.
# Pass: #20 PASS for both variants in all 9 cells; discordances reported, not gated.
#
# Usage:
#   Rscript R/package_tests/calibration/todo18_smoothed_brt_null.R --out-dir $D \
#     [--cells C1,C2,N1,...] [--B 101] [--target-finite 500] [--max-cases 1500] [--dataset diamonds] \
#     [--seed-base 18000000] [--timeout-sec 0] [--smoke]

local({
	f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
	here <- dirname(normalizePath(sub("^--file=", "", f[[1L]])))
	source(file.path(here, "calibration_common.R"))
	source(file.path(here, "summarize_type1_calibration.R"))
}, envir = globalenv())

TODO18_CELLS <- data.frame(
	cell = c("C1", "C2", "N1", "N2", "N3", "N4", "N5", "N6", "N7"),
	response_type = c("continuous", "continuous", rep("count", 7L)),
	class = c("InferenceContinKKRobustRegrOneLik", "InferenceContinOLS", "InferenceAllSimpleAverageDiff",
		"InferenceCountHurdleNegBin", "InferenceCountHurdlePoisson", "InferenceCountKKHurdlePoissonOneLik",
		"InferenceCountPoisson", "InferenceCountZeroInflatedNegBin", "InferenceCountZeroInflatedPoisson"),
	formula = c("~1", "~.", "NA", "~1", "~1", "~1", "~.", "~1", "~1"),
	stringsAsFactors = FALSE
)
TODO18_CELLS$design <- ifelse(grepl("KK", TODO18_CELLS$class), "FixedBinaryMatch", "Bernoulli")

ROW_COLUMNS <- c(
	"cell", "stratum", "method", "response_type", "class", "model_formula", "design", "design_formula", "dataset", "n",
	"case", "seed", "draws_seed", "noise_seed", "B", "status", "error_stage", "estimate", "pval", "reject",
	"n_treated", "data_sha256", "elapsed_sec", "warnings", "error_message"
)

todo18_harness_env <- function(repo_root) {
	env <- new.env(parent = globalenv())
	runner <- file.path(repo_root, "R", "package_tests", "comprehensive_tests.R")
	calib_eval_harness_objects(runner, c("SD_NOISE_BY_RESPONSE_TYPE", "sd_noise_for", "apply_treatment_effect_and_noise"), env)
	assign("beta_T", 0, envir = env)
	environment(env$apply_treatment_effect_and_noise) <- env
	env
}

todo18_build_case <- function(cell, D, seed, harness) {
	set.seed(seed)
	X <- as.data.frame(D$X)
	n <- nrow(X) - (nrow(X) %% 4L)
	X <- X[seq_len(n), , drop = FALSE]
	y_base <- as.numeric(D$y_original[[cell$response_type]])[seq_len(n)]
	rt <- cell$response_type
	if (identical(cell$design, "Bernoulli")) {
		des <- DesignSeqOneByOneBernoulli$new(response_type = rt, n = n, design_formula = ~ .)
		for (t in seq_len(n)) {
			w_t <- des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
			des$add_one_subject_response(t, y = harness$apply_treatment_effect_and_noise(y_base[t], w_t, rt))
		}
	} else if (identical(cell$design, "FixedBinaryMatch")) {
		des <- DesignFixedBinaryMatch$new(response_type = rt, n = n, design_formula = ~ .)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		w <- des$get_w()
		for (t in seq_len(n)) des$add_one_subject_response(t, y = harness$apply_treatment_effect_and_noise(y_base[t], w[t], rt))
	} else {
		stop("unsupported design ", cell$design)
	}
	des
}

todo18_new_inference <- function(cell, des) {
	gen <- get(cell$class, envir = asNamespace("EDI"))
	if (identical(cell$formula, "NA")) gen$new(des, verbose = FALSE) else
		gen$new(des, model_formula = stats::as.formula(cell$formula), verbose = FALSE)
}

todo18_guard_check <- function() {
	# Bounded categorical refits must still refuse `smoothed` (TODO-18 partial fix;
	# permanent coverage in test-brt-smoothed-count-support.R / -noise-mat-plumbing.R).
	out <- list()
	set.seed(20261022)
	n <- 40L
	for (spec in list(list(rt = "incidence", cls = "InferenceIncidLogRegr", y = function() stats::rbinom(n, 1, 0.5)),
			list(rt = "ordinal", cls = "InferenceOrdinalRidit", y = function() sample(1:4, n, TRUE)))) {
		res <- tryCatch({
			des <- DesignSeqOneByOneBernoulli$new(response_type = spec$rt, n = n)
			X <- data.frame(x1 = stats::rnorm(n))
			for (t in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
			des$add_all_subject_responses(spec$y())
			inf <- get(spec$cls, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
			v <- inf$compute_rand_bootstrap_two_sided_pval(B = 11, type = "smoothed", show_progress = FALSE)
			list(rejected = FALSE, message = paste("returned", format(v)))
		}, error = function(e) list(rejected = TRUE, message = conditionMessage(e)))
		out[[length(out) + 1L]] <- data.frame(response_type = spec$rt, class = spec$cls, smoothed_rejected = res$rejected,
			message = calib_clean_msg(res$message), stringsAsFactors = FALSE)
	}
	do.call(rbind, out)
}

main <- function(args) {
	usage <- paste(
		"Usage: Rscript R/package_tests/calibration/todo18_smoothed_brt_null.R --out-dir DIR",
		"  [--cells C1,C2,N1,N2,N3,N4,N5,N6,N7] [--B 101] [--target-finite 500] [--max-cases 1500]",
		"  [--dataset diamonds] [--seed-base 18000000] [--alpha 0.05] [--timeout-sec 0] [--smoke]",
		"--smoke: --target-finite 2, --max-cases 2, --B 21 (mechanics only; never evidence).", sep = "\n")
	opt <- calib_parse_args(args, defaults = list(out_dir = "", cells = paste(TODO18_CELLS$cell, collapse = ","),
		B = "101", target_finite = "500", max_cases = "1500", dataset = "diamonds", seed_base = "18000000",
		alpha = "0.05", timeout_sec = "0"), flags = "smoke", usage = usage)
	if (opt$smoke) {
		if (identical(opt$target_finite, "500")) opt$target_finite <- "2"
		if (identical(opt$max_cases, "1500")) opt$max_cases <- "2"
		if (identical(opt$B, "101")) opt$B <- "21"
	}
	script <- calib_script_path()
	repo_root <- calib_find_repo_root(dirname(script))
	out_dir <- calib_prepare_output_dir(opt$out_dir, repo_root)
	calib_load_installed_edi(repo_root)
	cells <- TODO18_CELLS[TODO18_CELLS$cell %in% calib_parse_chr_set(opt$cells), , drop = FALSE]
	if (!nrow(cells)) stop("no cells selected")
	B <- as.integer(opt$B)
	target <- as.integer(opt$target_finite)
	max_cases <- as.integer(opt$max_cases)
	alpha <- as.numeric(opt$alpha)
	timeout <- as.numeric(opt$timeout_sec)
	seed_base <- as.integer(opt$seed_base)
	cell_seed_base <- function(idx) seed_base + idx * 100000L
	datasets <- calib_load_harness_datasets(repo_root)
	D <- datasets[[opt$dataset]]
	if (is.null(D)) stop("unknown harness dataset ", opt$dataset)
	harness <- todo18_harness_env(repo_root)
	cells$dataset <- opt$dataset
	cells$n <- nrow(D$X) - (nrow(D$X) %% 4L)
	cells$seed_first <- vapply(match(cells$cell, TODO18_CELLS$cell), cell_seed_base, integer(1L)) + 1L
	cells$design_formula <- "~."
	cells$dgp <- "comprehensive harness null DGP (beta_T = 0); dataset/design per cell are agent choices"
	utils::write.csv(cells, file.path(out_dir, "cells.csv"), row.names = FALSE)
	all_seeds <- unlist(lapply(cells$seed_first, function(s) s + seq_len(max_cases) - 1L))
	prov <- calib_capture_provenance(repo_root, script, out_dir, args, all_seeds, extra = list(
		study = "TODO-18 smoothed-BRT null roster (G4-C R3)", smoke = opt$smoke, cells = cells, B = B,
		target_finite = target, max_cases = max_cases, alpha = alpha, sd_noise = harness$SD_NOISE_BY_RESPONSE_TYPE,
		harness_runner_sha256 = calib_sha256(file.path(repo_root, "R", "package_tests", "comprehensive_tests.R")),
		dataset_loader_sha256 = calib_sha256(file.path(repo_root, "R", "package_tests", "_dataset_load.R")),
		dataset_rows_sha256 = calib_object_sha256(list(X = D$X, y = D$y_original))))
	cat("EDI", prov$edi_package_version, "from", prov$edi_package_path, "DLL sha256", prov$edi_dll_sha256, "\n")
	guard <- todo18_guard_check()
	utils::write.csv(guard, file.path(out_dir, "guard_check.csv"), row.names = FALSE)
	write_row <- calib_row_writer(file.path(out_dir, "rows.csv"), ROW_COLUMNS)

	for (ci in seq_len(nrow(cells))) {
		cell <- cells[ci, ]
		fin <- c(percentile = 0L, smoothed = 0L)
		case <- 0L
		while (min(fin) < target && case < max_cases) {
			case <- case + 1L
			seed <- cell$seed_first + case - 1L
			base <- list(cell = cell$cell, stratum = cell$cell, response_type = cell$response_type, class = cell$class,
				model_formula = cell$formula, design = cell$design, design_formula = cell$design_formula,
				dataset = cell$dataset, n = cell$n, case = case, seed = seed, draws_seed = seed + 10000000L,
				noise_seed = seed + 20000000L, B = B)
			setup <- calib_eval(function() {
				des <- todo18_build_case(cell, D, seed, harness)
				inf <- todo18_new_inference(cell, des)
				est <- inf$compute_estimate()
				set.seed(seed + 10000000L)
				draws <- inf$.__enclos_env__$private$generate_rand_bootstrap_draws(B, materialize_w = TRUE)
				list(des = des, inf = inf, est = est, draws = draws)
			}, is_ok = function(v) !is.null(v$draws), timeout_sec = timeout)
			if (setup$status != "ok") {
				for (m in c("percentile", "smoothed")) write_row(c(base, list(method = m, status = setup$status,
					error_stage = "setup", elapsed_sec = setup$elapsed_sec, warnings = calib_clean_msg(setup$warnings),
					error_message = calib_clean_msg(setup$error_message))))
				next
			}
			s <- setup$value
			est <- calib_num(s$est)
			data_sha <- calib_object_sha256(list(y = s$des$get_y(), w = s$des$get_w()))
			stage <- function() calib_clean_msg(tryCatch(s$inf$get_nonestimable_reason(), error = function(e) NA_character_))
			for (m in c("percentile", "smoothed")) {
				r <- calib_eval(function() {
					if (m == "smoothed") set.seed(seed + 20000000L)
					s$inf$compute_rand_bootstrap_two_sided_pval(B = B, rand_bootstrap_draws = s$draws, type = m,
						show_progress = FALSE)
				}, is_ok = function(v) length(v) == 1L && is.finite(v) && v >= 0 && v <= 1, timeout_sec = timeout)
				p <- calib_num(r$value)
				if (r$status == "ok") fin[[m]] <- fin[[m]] + 1L
				write_row(c(base, list(method = m, status = r$status, error_stage = if (r$status == "ok") NA else stage(),
					estimate = est, pval = p, reject = if (r$status == "ok") p < alpha else NA,
					n_treated = sum(s$des$get_w()), data_sha256 = data_sha,
					elapsed_sec = r$elapsed_sec + if (m == "percentile") setup$elapsed_sec else 0,
					warnings = calib_clean_msg(r$warnings), error_message = calib_clean_msg(r$error_message))))
			}
			if (case %% 25L == 0L || opt$smoke) cat(sprintf("%s case %d: finite percentile %d smoothed %d\n", cell$cell, case,
				fin[["percentile"]], fin[["smoothed"]]))
		}
		if (min(fin) < target) cat(sprintf("WARNING %s stopped at --max-cases %d with finite counts %d/%d (< %d)\n",
			cell$cell, max_cases, fin[["percentile"]], fin[["smoothed"]], target))
	}

	rows <- calib_read_rows(file.path(out_dir, "rows.csv"))
	todo18_summarize(rows, cells, guard, out_dir, alpha, target, opt$smoke)
	calib_finish_provenance(out_dir)
	cat("wrote", out_dir, "\n")
}

todo18_summarize <- function(rows, cells, guard, out_dir, alpha, target, smoke) {
	t1 <- summarize_type1_rows(data.frame(method = rows$method, stratum = rows$cell, seed = rows$seed,
		pval = rows$pval, status = rows$status, stringsAsFactors = FALSE), alpha = alpha, target = target,
		target_basis = "finite")
	t1 <- merge(cells[c("cell", "class", "formula", "design", "dataset", "n")], t1, by.x = "cell", by.y = "stratum")
	t1$stratum <- t1$cell
	notes <- c("strata = cells; methods = BRT p-value variants paired on identical assignments (B draws) and outer data",
		if (smoke) "SMOKE RUN: mechanics only, not calibration evidence." else NULL)
	write_type1_summary(t1, out_dir, prefix = "type1", notes = notes,
		title = "TODO-18 smoothed-BRT null roster: Type-I per cell x variant (G6 #20)")
	disc <- do.call(rbind, lapply(split(rows, rows$cell), function(d) {
		pc <- d[d$method == "percentile", c("seed", "status", "reject")]
		sm <- d[d$method == "smoothed", c("seed", "status", "reject")]
		j <- merge(pc, sm, by = "seed", suffixes = c("_pct", "_sm"))
		both <- j$status_pct == "ok" & j$status_sm == "ok"
		a <- j$reject_pct %in% TRUE & both
		b <- j$reject_sm %in% TRUE & both
		data.frame(cell = d$cell[[1L]], cases = nrow(j), both_finite = sum(both), both_reject = sum(a & b),
			percentile_only = sum(a & !b), smoothed_only = sum(!a & b), discordant = sum(xor(a, b)),
			discordance_rate = if (sum(both)) sum(xor(a, b)) / sum(both) else NA_real_, stringsAsFactors = FALSE)
	}))
	utils::write.csv(disc, file.path(out_dir, "discordance.csv"), row.names = FALSE, na = "NA")
	# Simultaneous acceptance (owner 2026-10-28, amending G6 #20 for TODO-18 only): Holm across all cell x variant tests.
	# One-sided exact binomial p for H0: rejection rate <= alpha; a row with no finite p-values or below target fails outright.
	t1$p_exceed <- vapply(seq_len(nrow(t1)), function(i) if (t1$n_fin[[i]] > 0L)
		stats::binom.test(as.integer(t1$k[[i]]), as.integer(t1$n_fin[[i]]), p = alpha, alternative = "greater")$p.value else 0, numeric(1))
	t1$p_holm <- stats::p.adjust(t1$p_exceed, method = "holm")
	t1$holm_ok <- t1$p_holm >= alpha & t1$n_fin > 0L & t1$meets_target
	pass <- nrow(t1) == 2L * nrow(cells) && all(t1$holm_ok)
	pass_percell <- nrow(t1) == 2L * nrow(cells) && all(t1$verdict == "PASS")
	writeLines(c(
		"# TODO-18 smoothed-BRT true-null roster (G4-C R3)", "",
		if (smoke) "**SMOKE RUN: mechanics only, not calibration evidence.**" else NULL, "",
		sprintf("Overall (Holm-adjusted one-sided exact binomial across all %d cell x variant tests, familywise alpha %g, n_fin >= target): %s",
			nrow(t1), alpha, if (pass) "PASS" else "NOT PASSED"),
		sprintf("Reported, not gating: unadjusted per-cell Clopper-Pearson (#20) PASS in every cell x variant: %s",
			if (pass_percell) "yes" else "no"),
		sprintf("Bounded categorical smoothed calls rejected: %s", paste(sprintf("%s=%s", guard$class, guard$smoothed_rejected),
			collapse = ", ")),
		"", "## Type-I (type1_summary.csv)", "",
		calib_write_markdown_table(t1[c("cell", "class", "formula", "method", "n_att", "n_fin", "k", "rate", "cp_lower",
			"cp_upper", "verdict", "p_exceed", "p_holm", "holm_ok", "meets_target")]),
		"", "## Paired discordances (discordance.csv; reported, not gated)", "", calib_write_markdown_table(disc),
		"", "Notes:", paste0("- ", c(notes, "Dataset/design per cell are agent choices (cells.csv); the DGP is the harness null DGP.")))
	, file.path(out_dir, "summary.md"))
	print(t1[c("cell", "method", "n_att", "n_fin", "k", "rate", "cp_lower", "cp_upper", "verdict")], row.names = FALSE)
	print(disc, row.names = FALSE)
	print(guard, row.names = FALSE)
	invisible(NULL)
}

main(commandArgs(trailingOnly = TRUE))
