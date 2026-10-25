#!/usr/bin/env Rscript
# TODO-23 (release_v1_0_5.md; linked plan bug_fix_plans/rmst_mismatched_truncation_horizon.md):
# G4-C calibration runbook R4 (decisions G6 #22, #36).
#
# Mode `coverage` (Part A, plan TODO-5): multi-method RMST coverage calibration.
#   DGP (the plan's 2026-10-16 diagnostic): n = 100 per arm (DesignFixediBCRD, n = 200);
#   exponential event times with rate 0.4 (control) and 0.3 (treatment);
#   administrative follow-up maxima 4 (control) and 10 (treatment): an event is
#   observed if T <= max, otherwise right-censored at max; one administratively
#   censored sentinel per arm (the arm's first subject, observed time = its max)
#   pins each sample's observed arm maximum, so the shared default horizon is
#   tau = min(4, 10) = 4 in every sample. Truth = analytic RMST contrast
#   (1 - exp(-0.3*4))/0.3 - (1 - exp(-0.4*4))/0.4 = 0.334094...
#   Seeds: replicate r uses seed --seed-base + r (base 23000, so r = 1 -> 23001);
#   each family call is preceded by set.seed(seed * 100 + family index).
#   B = 199 for every bootstrap-type interval except the two BCa families (--B-bca,
#   default 999; see TODO23_BCA_FAMILIES); the default-named bootstrap and Bayesian-
#   bootstrap families pass type = "percentile" explicitly. m-out-of-n m and subsampling b use
#   comprehensive_tests.R's default_small_resampling_size() rule.
#   Families: the 14 TODO-23 CI operations (18 until 2026-10-25, when RMST began refusing the 4 rand-bootstrap CIs) (TODO23_OPERATIONS in todo23_expected_roster.R).
#   Pass per family (owner criteria 2026-10-21): coverage on the ALL-ATTEMPTS
#   denominator (invalid / non-finite / missing / error = noncovering), exact
#   binomial 95% interval contains 0.95, and invalid <= 5% of attempts.
#   At least 457 attempts per family; default 460.
#   Outputs: rows.csv (replicate x family), coverage_summary.csv/.md, replicates.csv
#   (per-replicate censoring and arm maxima), provenance.rds/.txt.
#
# Mode `reconcile` (Part B, plan TODO-7): exact-key reconciliation of a FRESH
#   current-source comprehensive survival slice for InferenceSurvivalRestrictedMeanDiff
#   (run with EDI_COMPREHENSIVE_RESULTS_DIR=$RUN and EDI_COMPREHENSIVE_ATTEMPT_MANIFEST=$RUN/attempt_events.csv)
#   against the expected 14-operation roster rebuilt from the current source
#   (todo23_expected_roster.R), using reconcile_todo23_attempts() from
#   R/package_tests/validate_todo23_attempt_reconciliation.R. Rows/events for
#   other classes or operations are counted as out of scope and excluded.
#   Outputs: expected roster, reconciliation tables, reconcile_summary.txt.
#
# Usage:
#   Rscript R/package_tests/calibration/todo23_rmst_coverage.R coverage --out-dir $D \
#     [--reps 460] [--seed-base 23000] [--B 199] [--B-bca 999] [--families all|f1,f2] [--timeout-sec 0] [--smoke]
#   Rscript R/package_tests/calibration/todo23_rmst_coverage.R reconcile --run-dir $RUN --out-dir $D2 \
#     [--events $RUN/attempt_events.csv] [--results <csv>] [--nrep 40]

local({
	f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
	here <- dirname(normalizePath(sub("^--file=", "", f[[1L]])))
	source(file.path(here, "calibration_common.R"))
	source(file.path(here, "todo23_expected_roster.R"))
}, envir = globalenv())

TODO23_RATE_C <- 0.4
TODO23_RATE_T <- 0.3
TODO23_MAX_C <- 4
TODO23_MAX_T <- 10
TODO23_TAU <- min(TODO23_MAX_C, TODO23_MAX_T)
TODO23_TRUTH <- (1 - exp(-TODO23_RATE_T * TODO23_TAU)) / TODO23_RATE_T - (1 - exp(-TODO23_RATE_C * TODO23_TAU)) / TODO23_RATE_C

todo23_generate <- function(seed, n_per_arm = 100L) {
	set.seed(seed)
	n <- 2L * n_per_arm
	des <- DesignFixediBCRD$new(response_type = "survival", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = stats::rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- as.numeric(des$get_w())
	rate <- ifelse(w == 1, TODO23_RATE_T, TODO23_RATE_C)
	admin_max <- ifelse(w == 1, TODO23_MAX_T, TODO23_MAX_C)
	latent <- stats::rexp(n, rate)
	time <- pmin(latent, admin_max)
	dead <- as.integer(latent <= admin_max)
	sentinel <- c(which(w == 0)[1L], which(w == 1)[1L])
	time[sentinel] <- admin_max[sentinel]
	dead[sentinel] <- 0L
	for (i in seq_len(n)) {
		if (dead[i] == 1L) des$add_one_subject_response(i, y = time[i]) else
			des$add_one_subject_response(i, y_L = time[i], y_R = Inf)
	}
	list(des = des, w = w, time = time, dead = dead)
}

todo23_small_resampling_size <- function(inf, n) {
	unit_info <- tryCatch(inf$.__enclos_env__$private$get_exchangeable_units(unit = "auto", resampling_type = NULL),
		error = function(e) NULL)
	n_units <- if (is.list(unit_info) && length(unit_info$n_units) == 1L && is.finite(unit_info$n_units)) as.integer(unit_info$n_units) else as.integer(n)
	p_eff <- tryCatch(as.integer(inf$.__enclos_env__$private$resampling_effective_p()), error = function(e) 1L)
	if (length(p_eff) != 1L || !is.finite(p_eff)) p_eff <- 1L
	min_size <- max(5L, p_eff + 2L)
	max_size <- floor(n_units / 2L)
	if (max_size < min_size) return(NA_integer_)
	as.integer(max(min_size, min(floor(n_units^0.7), max_size)))
}

# Interval type per family is explicit (2026-10-23, R4 smoke finding): the class's
# default nonparametric-bootstrap CI type for RMST is BCa (edi_bootstrap_dispatch_policy),
# so a type-less `compute_bootstrap_confidence_interval` call duplicated the `_bca`
# family. The plan's family (rmst_mismatched_truncation_horizon.md TODO-5 diagnostics)
# is the ordinary PERCENTILE bootstrap, so it now passes type = "percentile"; the
# Bayesian default is percentile already and is pinned the same way. The two BCa
# families use B_bca (default 999): BCa's documented small-B guard (G6 #12) returns
# c(NA, NA) when B is too small, and that counts as invalid under the 5% cap
# (measured 2026-10-23 on 12 R4 replicates: nonparametric BCa 1/12 NA at B = 199,
# 0/12 at B = 501 and 999; Bayesian BCa 0/12 at all three).
TODO23_BCA_FAMILIES <- c("compute_bootstrap_confidence_interval_bca", "compute_bayesian_bootstrap_confidence_interval_bca")

todo23_family_B <- function(family, B, B_bca) if (family %in% TODO23_BCA_FAMILIES) B_bca else B

todo23_family_call <- function(family, inf, alpha, B, m, B_bca = B) {
	B <- todo23_family_B(family, B, B_bca)
	switch(family,
		compute_wald_confidence_interval = inf$compute_wald_confidence_interval(alpha = alpha),
		compute_asymp_confidence_interval = inf$compute_asymp_confidence_interval(alpha = alpha),
		compute_subsampling_confidence_interval = inf$compute_subsampling_confidence_interval(alpha = alpha, B = B, b = m, show_progress = FALSE),
		compute_m_out_of_n_bootstrap_confidence_interval = inf$compute_m_out_of_n_bootstrap_confidence_interval(alpha = alpha, B = B, m = m, show_progress = FALSE),
		compute_jackknife_wald_confidence_interval = inf$compute_jackknife_wald_confidence_interval(alpha = alpha),
		compute_bootstrap_confidence_interval = inf$compute_bootstrap_confidence_interval(alpha = alpha, B = B, type = "percentile", na.rm = TRUE, show_progress = FALSE),
		compute_bootstrap_confidence_interval_basic = inf$compute_bootstrap_confidence_interval(alpha = alpha, B = B, type = "basic", na.rm = TRUE, show_progress = FALSE),
		compute_bootstrap_confidence_interval_bca = inf$compute_bootstrap_confidence_interval(alpha = alpha, B = B, type = "bca", na.rm = TRUE, show_progress = FALSE),
		compute_bootstrap_confidence_interval_studentized = inf$compute_bootstrap_confidence_interval(alpha = alpha, B = B, type = "studentized", na.rm = TRUE, show_progress = FALSE),
		compute_bayesian_bootstrap_confidence_interval = inf$compute_bayesian_bootstrap_confidence_interval(alpha = alpha, B = B, type = "percentile", na.rm = TRUE, show_progress = FALSE),
		compute_bayesian_bootstrap_confidence_interval_basic = inf$compute_bayesian_bootstrap_confidence_interval(alpha = alpha, B = B, type = "basic", na.rm = TRUE, show_progress = FALSE),
		compute_bayesian_bootstrap_confidence_interval_wald = inf$compute_bayesian_bootstrap_confidence_interval(alpha = alpha, B = B, type = "wald", na.rm = TRUE, show_progress = FALSE),
		compute_bayesian_bootstrap_confidence_interval_bca = inf$compute_bayesian_bootstrap_confidence_interval(alpha = alpha, B = B, type = "bca", na.rm = TRUE, show_progress = FALSE),
		compute_bayesian_bootstrap_confidence_interval_studentized = inf$compute_bayesian_bootstrap_confidence_interval(alpha = alpha, B = B, type = "studentized", na.rm = TRUE, show_progress = FALSE),
		stop("unknown family ", family)
	)
}

COVERAGE_ROW_COLUMNS <- c(
	"rep", "seed", "family", "family_seed", "status", "error_stage", "estimate", "ci_lo", "ci_hi", "valid", "covered",
	"truth", "B", "resampling_size", "censored_fraction", "max_time_control", "max_time_treatment", "data_sha256",
	"elapsed_sec", "warnings", "error_message"
)

coverage_mode <- function(args) {
	usage <- paste(
		"Usage: Rscript R/package_tests/calibration/todo23_rmst_coverage.R coverage --out-dir DIR",
		"  [--reps 460] [--seed-base 23000] [--B 199] [--B-bca 999] [--families all|f1,f2] [--alpha 0.05] [--timeout-sec 0] [--smoke]",
		"--B-bca: B for the two BCa families only (BCa's small-B guard returns NA; G6 #12).",
		"--smoke: --reps 2, --B 99, --B-bca 99 (mechanics only; never evidence).", sep = "\n")
	opt <- calib_parse_args(args, defaults = list(out_dir = "", reps = "460", seed_base = "23000", B = "199", B_bca = "999",
		families = "all", alpha = "0.05", timeout_sec = "0"), flags = "smoke", usage = usage)
	if (opt$smoke) {
		if (identical(opt$reps, "460")) opt$reps <- "2"
		if (identical(opt$B, "199")) opt$B <- "99"
		if (identical(opt$B_bca, "999")) opt$B_bca <- "99"
	}
	script <- calib_script_path()
	repo_root <- calib_find_repo_root(dirname(script))
	out_dir <- calib_prepare_output_dir(opt$out_dir, repo_root)
	calib_load_installed_edi(repo_root)
	reps <- as.integer(opt$reps)
	if (reps < 457L && !opt$smoke) message("NOTE: --reps ", reps, " is below the 457 attempts per family the owner criteria require.")
	seeds <- as.integer(opt$seed_base) + seq_len(reps)
	B <- as.integer(opt$B)
	B_bca <- as.integer(opt$B_bca)
	alpha <- as.numeric(opt$alpha)
	timeout <- as.numeric(opt$timeout_sec)
	families <- if (identical(opt$families, "all")) TODO23_OPERATIONS else calib_parse_chr_set(opt$families)
	if (!all(families %in% TODO23_OPERATIONS)) stop("unknown family: ", paste(setdiff(families, TODO23_OPERATIONS), collapse = ", "))
	prov <- calib_capture_provenance(repo_root, script, out_dir, args, seeds, extra = list(
		study = "TODO-23 RMST coverage calibration (G4-C R4 Part A)", smoke = opt$smoke, families = families, B = B, B_bca = B_bca,
		bca_families = TODO23_BCA_FAMILIES, explicit_types = "bootstrap and Bayesian-bootstrap default families pinned to type = percentile",
		alpha = alpha, truth = TODO23_TRUTH, tau = TODO23_TAU,
		dgp = list(n_per_arm = 100L, rate_control = TODO23_RATE_C, rate_treatment = TODO23_RATE_T,
			max_control = TODO23_MAX_C, max_treatment = TODO23_MAX_T, sentinel = "first subject per arm censored at its arm maximum")))
	cat("EDI", prov$edi_package_version, "from", prov$edi_package_path, "DLL sha256", prov$edi_dll_sha256, "\n")
	cat(sprintf("truth (RMST contrast at tau = %g): %.6f\n", TODO23_TAU, TODO23_TRUTH))
	write_row <- calib_row_writer(file.path(out_dir, "rows.csv"), COVERAGE_ROW_COLUMNS)
	rep_rows <- list()

	for (r in seq_len(reps)) {
		seed <- seeds[[r]]
		gen <- tryCatch(todo23_generate(seed), error = function(e) e)
		if (inherits(gen, "error")) {
			for (fam in families) write_row(list(rep = r, seed = seed, family = fam, status = "error", error_stage = "data_generation",
				valid = FALSE, covered = FALSE, truth = TODO23_TRUTH, B = B, error_message = calib_clean_msg(conditionMessage(gen))))
			next
		}
		cens <- mean(gen$dead == 0L)
		maxc <- max(gen$time[gen$w == 0])
		maxt <- max(gen$time[gen$w == 1])
		data_sha <- calib_object_sha256(list(w = gen$w, time = gen$time, dead = gen$dead))
		rep_rows[[r]] <- data.frame(rep = r, seed = seed, censored_fraction = cens, max_time_control = maxc,
			max_time_treatment = maxt, data_sha256 = data_sha)
		t_rep <- 0
		for (j in seq_along(families)) {
			fam <- families[[j]]
			fam_seed <- seed * 100L + match(fam, TODO23_OPERATIONS)
			# Fresh inference object per family so no family warms another's cache.
			inf <- InferenceSurvivalRestrictedMeanDiff$new(gen$des, verbose = FALSE)
			m <- if (fam %in% c("compute_subsampling_confidence_interval", "compute_m_out_of_n_bootstrap_confidence_interval"))
				todo23_small_resampling_size(inf, length(gen$w)) else NA_integer_
			res <- calib_eval(function() {
				set.seed(fam_seed)
				if (!is.na(m) || !fam %in% c("compute_subsampling_confidence_interval", "compute_m_out_of_n_bootstrap_confidence_interval")) {
					todo23_family_call(fam, inf, alpha, B, m, B_bca = B_bca)
				} else stop("too few exchangeable units for a small resampling size")
			}, is_ok = function(v) length(v) >= 2L && all(is.finite(as.numeric(v[1:2]))) && as.numeric(v[1L]) <= as.numeric(v[2L]),
			timeout_sec = timeout)
			lo <- calib_num(res$value, 1L)
			hi <- calib_num(res$value, 2L)
			valid <- identical(res$status, "ok")
			est <- tryCatch(calib_num(inf$compute_estimate()), error = function(e) NA_real_)
			write_row(list(rep = r, seed = seed, family = fam, family_seed = fam_seed, status = res$status,
				error_stage = if (valid) NA else calib_clean_msg(tryCatch(inf$get_nonestimable_reason(), error = function(e) NA_character_)),
				estimate = est, ci_lo = lo, ci_hi = hi, valid = valid,
				covered = valid && lo <= TODO23_TRUTH && TODO23_TRUTH <= hi, truth = TODO23_TRUTH, B = todo23_family_B(fam, B, B_bca), resampling_size = m,
				censored_fraction = cens, max_time_control = maxc, max_time_treatment = maxt, data_sha256 = data_sha,
				elapsed_sec = res$elapsed_sec, warnings = calib_clean_msg(res$warnings), error_message = calib_clean_msg(res$error_message)))
			t_rep <- t_rep + res$elapsed_sec
		}
		cat(sprintf("rep %d (seed %d): censored %.3f, arm maxima %.2f / %.2f, %.1fs\n", r, seed, cens, maxc, maxt, t_rep))
	}
	if (length(rep_rows)) utils::write.csv(do.call(rbind, rep_rows), file.path(out_dir, "replicates.csv"), row.names = FALSE)
	rows <- calib_read_rows(file.path(out_dir, "rows.csv"))
	summ <- todo23_coverage_summary(rows, families)
	utils::write.csv(summ, file.path(out_dir, "coverage_summary.csv"), row.names = FALSE, na = "NA")
	all_pass <- all(summ$pass)
	writeLines(c("# TODO-23 RMST coverage calibration (G4-C R4 Part A)", "",
		if (opt$smoke) "**SMOKE RUN: mechanics only, not calibration evidence.**" else NULL, "",
		sprintf("Truth %.6f (tau = %g). Replicates %d (seeds %s). B = %d (BCa families: B = %d). Default-named bootstrap families use type = percentile.", TODO23_TRUTH, TODO23_TAU, reps,
			calib_describe_ints(seeds), B, B_bca),
		"Pass per family: all-attempts coverage CP 95% interval contains 0.95 AND invalid <= 5%; >= 457 attempts.",
		sprintf("Overall: %s (%d/%d families pass).", if (all_pass) "PASS" else "NOT PASSED", sum(summ$pass), nrow(summ)), "",
		calib_write_markdown_table(summ)), file.path(out_dir, "coverage_summary.md"))
	print(summ, row.names = FALSE)
	calib_finish_provenance(out_dir)
	cat("wrote", out_dir, "\n")
}

todo23_coverage_summary <- function(rows, families) {
	do.call(rbind, lapply(families, function(fam) {
		d <- rows[rows$family == fam, , drop = FALSE]
		att <- nrow(d)
		valid <- sum(d$valid %in% TRUE)
		covered <- sum(d$covered %in% TRUE)
		ci <- calib_cp_interval(covered, att)
		inv <- att - valid
		data.frame(family = fam, attempts = att, valid = valid, invalid = inv,
			invalid_pct = if (att) 100 * inv / att else NA_real_, covered = covered,
			coverage_all_attempts = if (att) covered / att else NA_real_, cp_lower = ci[[1L]], cp_upper = ci[[2L]],
			coverage_valid_only = if (valid) covered / valid else NA_real_,
			enough_attempts = att >= 457L,
			pass = att >= 457L && is.finite(ci[[1L]]) && ci[[1L]] <= 0.95 && 0.95 <= ci[[2L]] && inv <= 0.05 * att,
			median_elapsed_sec = if (att) stats::median(d$elapsed_sec, na.rm = TRUE) else NA_real_,
			stringsAsFactors = FALSE)
	}))
}

reconcile_mode <- function(args) {
	usage <- paste(
		"Usage: Rscript R/package_tests/calibration/todo23_rmst_coverage.R reconcile --run-dir RUN --out-dir DIR",
		"  [--events RUN/attempt_events.csv] [--results <comprehensive results csv>] [--nrep 40]", sep = "\n")
	opt <- calib_parse_args(args, defaults = list(run_dir = "", out_dir = "", events = "", results = "", nrep = ""),
		usage = usage)
	script <- calib_script_path()
	repo_root <- calib_find_repo_root(dirname(script))
	if (!nzchar(opt$run_dir) || !dir.exists(opt$run_dir)) stop("--run-dir must name the comprehensive run directory")
	run_dir <- normalizePath(opt$run_dir, winslash = "/")
	out_dir <- calib_prepare_output_dir(opt$out_dir, repo_root)
	source(file.path(repo_root, "R", "package_tests", "validate_todo23_attempt_reconciliation.R"), local = TRUE)
	results_path <- if (nzchar(opt$results)) opt$results else {
		cand <- list.files(run_dir, pattern = "^comprehensive_tests_results.*survival.*\\.csv$", full.names = TRUE)
		cand <- cand[!grepl("provenance|staging|\\.bak", cand)]
		if (length(cand) != 1L) stop("expected exactly one survival results CSV in ", run_dir, " (found ", length(cand),
			"); pass --results")
		cand
	}
	events_path <- if (nzchar(opt$events)) opt$events else file.path(run_dir, "attempt_events.csv")
	if (!file.exists(events_path)) stop("attempt events file not found: ", events_path,
		" (run comprehensive_tests.R with EDI_COMPREHENSIVE_ATTEMPT_MANIFEST=", events_path, ")")
	manifest <- todo23_expected_roster(repo_root, TODO23_OPERATIONS, nrep = if (nzchar(opt$nrep)) as.integer(opt$nrep) else NULL)
	utils::write.csv(manifest, file.path(out_dir, "todo23_expected_roster.csv"), row.names = FALSE, na = "")
	results <- utils::read.csv(results_path, stringsAsFactors = FALSE, check.names = FALSE)
	events <- utils::read.csv(events_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
	in_scope <- function(df) startsWith(as.character(df$inference_class), "InferenceSurvivalRestrictedMeanDiff") &
		as.character(df$function_run) %in% TODO23_OPERATIONS
	res_scope <- in_scope(results)
	ev_scope <- !is.na(events$function_run) & in_scope(events)
	rec <- reconcile_todo23_attempts(manifest, events[ev_scope | is.na(events$function_run), , drop = FALSE],
		results[res_scope, , drop = FALSE], key_columns = TODO23_KEY_COLUMNS)
	for (nm in c("result_missing", "result_extra", "result_duplicates", "event_missing", "event_extra",
			"terminal_without_result", "result_without_terminal", "terminal_status_mismatches", "terminal_result_counts")) {
		utils::write.csv(rec[[nm]], file.path(out_dir, paste0("reconcile_", nm, ".csv")), row.names = FALSE, na = "")
	}
	status_tab <- table(results$status[res_scope], useNA = "ifany")
	lines <- c(
		"TODO-23 Part B reconciliation (G4-C R4): fresh current-source run vs 14-operation expected roster",
		paste0("run_dir=", run_dir), paste0("results=", results_path, " sha256=", calib_sha256(results_path)),
		paste0("events=", events_path, " sha256=", calib_sha256(events_path)),
		todo23_roster_summary_lines(manifest, file.path(out_dir, "todo23_expected_roster.csv")),
		paste0("result_rows_in_scope=", sum(res_scope), " out_of_scope=", sum(!res_scope)),
		paste0("event_rows_in_scope=", sum(ev_scope), " unkeyed_or_setup=", sum(is.na(events$function_run))),
		paste0("in_scope_result_status=", paste(names(status_tab), status_tab, sep = ":", collapse = ",")),
		paste0("result_missing=", nrow(rec$result_missing)), paste0("result_extra=", nrow(rec$result_extra)),
		paste0("result_duplicates=", nrow(rec$result_duplicates)), paste0("event_missing=", nrow(rec$event_missing)),
		paste0("event_extra=", nrow(rec$event_extra)), paste0("terminal_without_result=", nrow(rec$terminal_without_result)),
		paste0("result_without_terminal=", nrow(rec$result_without_terminal)),
		paste0("terminal_status_mismatches=", nrow(rec$terminal_status_mismatches)),
		"Missing keys whose setup was skipped (setup_skipped events) must be explained before acceptance; then run",
		"audit_comprehensive_results.R --force on the run directory (runbook R4 Part B)."
	)
	writeLines(lines, file.path(out_dir, "reconcile_summary.txt"))
	cat(paste(lines, collapse = "\n"), "\n")
}

main <- function(args) {
	if (!length(args) || args[[1L]] %in% c("-h", "--help")) {
		cat("Usage: Rscript R/package_tests/calibration/todo23_rmst_coverage.R coverage|reconcile [options]  (see header)\n")
		quit(save = "no", status = if (length(args)) 0L else 2L)
	}
	mode <- args[[1L]]
	if (identical(mode, "coverage")) coverage_mode(args[-1L]) else
	if (identical(mode, "reconcile")) reconcile_mode(args[-1L]) else stop("unknown mode ", mode)
}

main(commandArgs(trailingOnly = TRUE))
