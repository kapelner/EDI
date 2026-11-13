# Synthetic campaign for the calibration study's tests and for looking at the per-class pages and figures
# (v1.0.5 TODO-203). Not part of the study. No EDI needed.
#
#   cal_synth_campaign(root, id, cal_dir) builds <root>/campaigns/<id>/ with campaign.env, status.txt, runs.txt,
#   figures.md, plan.csv (from plan_calibration_study.R on a small roster), stats/tests.csv.gz and est.csv.gz.
#   Three classes, two designs, n = 50 / 200 / 1000, null and power20 / power50 / power80 (100 / 50 replicates):
#     InferenceContinLin   complete in every unit (wald size 0.13 at n = 50, converging; rand 0.06 throughout)
#     InferenceContinOLS   null units at n = 50 and 200 complete, n = 1000 and the power units missing; wald size 0.22 at n = 200
#     InferenceIncidLogit  not started
#   Returns list(cdir, plan, roster_path).

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

cal_synth_roster <- function() {
	data.frame(
		response_type = c(rep("continuous", 4L), rep("incidence", 2L)),
		design = c("DesignFixedBernoulli", "DesignFixediBCRD", "DesignFixedBernoulli", "DesignFixediBCRD", "DesignFixedBernoulli", "DesignFixediBCRD"),
		design_rank = rep(c(1L, 2L), 3L), matched = FALSE,
		inf_class = c("InferenceContinLin", "InferenceContinLin", "InferenceContinOLS", "InferenceContinOLS", "InferenceIncidLogit", "InferenceIncidLogit"),
		n_size = c(4L, 4L, 6L, 6L, 4L, 4L), n_cov = c(2L, 2L, 4L, 4L, 4L, 4L), secs_n50 = c(0.1, 0.1, 0.2, 0.2, 0.3, 0.3), stringsAsFactors = FALSE)
}

cal_synth_campaign <- function(root, id = "2026-11-10-abcd1234", cal_dir, null_reps = 100L, power_reps = 50L, seed = 1L) {
	stats_env <- new.env()
	sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = stats_env)
	sys.source(file.path(cal_dir, "calibration_study_plan_common.R"), envir = stats_env)
	cdir <- file.path(root, "campaigns", id)
	dir.create(file.path(cdir, "stats"), recursive = TRUE)
	roster_path <- file.path(root, "roster.csv")
	utils::write.csv(cal_synth_roster(), roster_path, row.names = FALSE)
	res <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(cal_dir, "plan_calibration_study.R")), "--plan-only",
		"--roster", shQuote(roster_path), "--null-reps", null_reps, "--power-reps", power_reps, "--plan-out", shQuote(file.path(cdir, "plan.csv"))),
		stdout = TRUE, stderr = TRUE))
	if (!is.null(attr(res, "status"))) stop("planner failed: ", paste(res, collapse = "\n"))
	plan <- read_csv_fast(file.path(cdir, "plan.csv"), stringsAsFactors = FALSE)
	u <- stats_env$cal_stats_u_cols()
	procs <- list(InferenceContinLin = c("wald", "rand"), InferenceContinOLS = c("wald", "score", "rand"), InferenceIncidLogit = c("wald", "exact"))
	set.seed(seed)
	run <- function(r) {
		if (r$inf_class == "InferenceIncidLogit") return(FALSE)
		if (r$inf_class == "InferenceContinOLS" && (r$effect != "null" || r$n == 1000L)) return(FALSE)
		TRUE
	}
	tests <- list(); est <- list()
	for (i in seq_len(nrow(plan))) {
		r <- plan[i, ]
		if (!run(r)) next
		for (fm in c("~1", "~.")) {
			neff <- r$n
			for (pr in procs[[r$inf_class]]) {
				base <- if (pr == "rand") 0.06 else if (r$inf_class == "InferenceContinOLS" && pr == "wald" && r$n == 200L) 0.22 else 0.05 + 3 / neff
				null <- r$effect == "null"
				rej <- if (null) stats::rbinom(1L, r$reps, base) else stats::rbinom(1L, r$reps, 0.2 + 0.3 * (r$effect != "power20"))
				has_ci <- pr != "rand"
				cov <- stats::rbinom(1L, r$reps, 1 - base)
				t <- data.frame(response_type = r$response_type, design = sub("@.*$", "", r$design), prob_T = 0.5, inf_class = r$inf_class, formula = fm,
					n = r$n, n_nominal = r$n, effect_label = r$effect, stage = "screen", inf_procedure = pr, reps = r$reps, n_p = r$reps, rej = rej,
					rej10 = min(r$reps, rej * 2L), n_ci = if (has_ci) r$reps else 0L, cov = if (has_ci) cov else 0L, fit_secs = 0.1 * r$reps,
					stringsAsFactors = FALSE)
				t[u] <- lapply(seq_along(u), function(j) 0L)
				tests[[length(tests) + 1L]] <- t
			}
			sd <- 2 / sqrt(r$n)
			est[[length(est) + 1L]] <- data.frame(response_type = r$response_type, design = sub("@.*$", "", r$design), prob_T = 0.5, inf_class = r$inf_class,
				formula = fm, n = r$n, n_nominal = r$n, effect_label = r$effect, stage = "screen", reps = r$reps, n_est = r$reps, n_below = r$reps %/% 2L,
				n_above = r$reps - r$reps %/% 2L, sum_d = 0.5 / r$n * r$reps, sum_d2 = sd^2 * r$reps, null_value = 0,
				estimand_true = if (r$effect == "null") 0 else 1, stringsAsFactors = FALSE)
		}
	}
	utils::write.csv(do.call(rbind, tests), gzfile(file.path(cdir, "stats", "tests.csv.gz")), row.names = FALSE)
	utils::write.csv(do.call(rbind, est), gzfile(file.path(cdir, "stats", "est.csv.gz")), row.names = FALSE)
	writeLines(c("SHA=0123456789abcdef0123456789abcdef01234567", "STARTED=2026-11-10T00:00Z", "ANALYSIS_SHA=fedcba9876543210fedcba9876543210fedcba98"),
		file.path(cdir, "campaign.env"))
	writeLines("running", file.path(cdir, "status.txt"))
	writeLines("12345", file.path(cdir, "runs.txt"))
	writeLines(c("### Null treatment effect (beta_T = 0)", "", "#### Continuous", "", "<picture>c</picture>", "", "#### Incidence", "", "<picture>i</picture>", "",
		"### Non-null treatment effect (beta_T != 0)", "", "No power cells.", ""), file.path(cdir, "figures.md"))
	list(cdir = cdir, plan = plan, roster_path = roster_path)
}
