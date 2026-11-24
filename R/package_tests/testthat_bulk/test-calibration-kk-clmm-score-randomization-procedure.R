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

library(testthat)

# v1.1.0-TODO-269: the published calibration study runs the KK CLMM classes' opt-in score-statistic randomization
# test, compute_rand_two_sided_pval(type = "score") (DECISION-v1.1.0-TODO-267 (a)), as an extra tier-1 p-value-only
# procedure `rand_score` (CAL_EXTRA_PVAL_PROCEDURES, calibration_fast_tier_common.R): only for the four KK CLMM
# classes, riding on their `rand` task (same formula, same r, same draws), skipped on an EDI without the statistic,
# and gated through the registry as a variant of `rand` (EDI_INFERENCE_PROCEDURE_VARIANTS).

rs_cal_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		d = file.path(dir, "R", "package_tests", "calibration")
		if (file.exists(file.path(d, "calibration_study_common.R"))) return(d)
		dir = dirname(dir)
	}
	NA_character_
}
cal_dir = rs_cal_dir()
skip_if(is.na(cal_dir), "calibration scripts not found")
CLMM_CLASSES = c("InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMProbit", "InferenceOrdinalKKCLMMCauchit", "InferenceOrdinalKKCLMMCloglog")

# The fast-tier core alone defines the extra-procedure machinery; it needs no EDI to be sourced.
ft = new.env(parent = globalenv())
sys.source(file.path(cal_dir, "calibration_fast_tier_common.R"), envir = ft)
reg = new.env(parent = globalenv())
sys.source(file.path(cal_dir, "..", "..", "EDI", "R", "inference_procedure_regime.R"), envir = reg)

task = function(cls, method, formula = ~ 1) {
	tag = deparse1(formula)
	list(cls_name = cls, model_formula = formula, method = method, type = NA_character_, result_name = sprintf("%s[%s]{%s}", cls, tag, method))
}

test_that("rand_score is declared for exactly the four KK CLMM classes, on rand, with type = \"score\"", {
	e = ft$CAL_EXTRA_PVAL_PROCEDURES$rand_score
	expect_identical(e$base, "rand")
	expect_identical(e$method, "compute_rand_two_sided_pval")
	expect_identical(e$args, list(type = "score"))
	expect_setequal(e$classes, CLMM_CLASSES)
	# No r and no permutations are passed: the method's default r (the same as `rand`'s) and the design's cached draws.
	expect_false(any(c("r", "permutations") %in% names(e$args)))
})

test_that("an extra task is added right after its base task, only for its classes, only when requested and supported", {
	tasks = list(task("InferenceOrdinalKKCLMM", "wald"), task("InferenceOrdinalKKCLMM", "rand"),
		task("InferenceOrdinalPropOddsRegr", "rand"), task("InferenceOrdinalKKCLMM", "rand", ~ .))
	yes = function(label, cls, extras) cls %in% extras[[label]]$classes
	out = ft$cal_add_extra_tasks(tasks, c("wald", "rand", "rand_score"), applies = yes)
	m = vapply(out, `[[`, "", "method")
	cl = vapply(out, `[[`, "", "cls_name")
	expect_identical(m, c("wald", "rand", "rand_score", "rand", "rand", "rand_score"))
	expect_identical(cl, c(rep("InferenceOrdinalKKCLMM", 3L), "InferenceOrdinalPropOddsRegr", rep("InferenceOrdinalKKCLMM", 2L)))
	expect_identical(out[[3L]]$result_name, "InferenceOrdinalKKCLMM[~1]{rand_score}")
	expect_identical(deparse1(out[[6L]]$model_formula), "~.")
	# Not requested (the fast tier's methods, or an older tier-1 list): unchanged.
	expect_identical(ft$cal_add_extra_tasks(tasks, c("wald", "rand"), applies = yes), tasks)
	# The installed EDI lacks the statistic: skipped cleanly, nothing added.
	expect_identical(ft$cal_add_extra_tasks(tasks, c("rand", "rand_score"), applies = function(...) FALSE), tasks)
	# No base task (a design without randomization draws has no `rand` task): nothing added.
	no_rand = tasks[1L]
	expect_identical(ft$cal_add_extra_tasks(no_rand, c("wald", "rand_score"), applies = yes), no_rand)
})

test_that("the capability check walks the class's R6 ancestry for the private method", {
	skip_if_not_installed("R6")
	ns = new.env()
	ns$Base = R6::R6Class("Base", private = list(compute_clmm_score_rand_pval = function() 1))
	ns$Child = R6::R6Class("Child", inherit = Base, parent_env = ns)
	ns$Old = R6::R6Class("Old", private = list(other = function() 1))
	ns$NotAClass = function() 1
	expect_true(ft$cal_class_has_private_method("Base", "compute_clmm_score_rand_pval", ns = ns))
	expect_true(ft$cal_class_has_private_method("Child", "compute_clmm_score_rand_pval", ns = ns))
	expect_false(ft$cal_class_has_private_method("Old", "compute_clmm_score_rand_pval", ns = ns))
	expect_false(ft$cal_class_has_private_method("NotAClass", "compute_clmm_score_rand_pval", ns = ns))
	expect_false(ft$cal_class_has_private_method("Missing", "compute_clmm_score_rand_pval", ns = ns))
	expect_false(ft$cal_extra_procedure_applies("rand_score", "InferenceOrdinalPropOddsRegr", has_method = function(...) TRUE))
	expect_true(ft$cal_extra_procedure_applies("rand_score", "InferenceOrdinalKKCLMMCauchit", has_method = function(...) TRUE))
	expect_false(ft$cal_extra_procedure_applies("rand_score", "InferenceOrdinalKKCLMMCauchit", has_method = function(...) FALSE))
	expect_false(ft$cal_extra_procedure_applies("no_such", "InferenceOrdinalKKCLMM", has_method = function(...) TRUE))
})

test_that("cal_extra_pval() calls the method with type = \"score\" and no progress bar, and reports errors like the suite", {
	seen = NULL
	ok = list(compute_rand_two_sided_pval = function(r = 501, type = NULL, show_progress = TRUE) { seen <<- list(r = r, type = type, sp = show_progress); 0.25 })
	expect_identical(ft$cal_extra_pval(ok, "rand_score"), list(pval = 0.25, method = "rand_score"))
	expect_identical(seen, list(r = 501, type = "score", sp = FALSE))
	bad = list(compute_rand_two_sided_pval = function(type = NULL) stop("no null fit"))
	expect_identical(ft$cal_extra_pval(bad, "rand_score"), list(pval = NA_real_, method = "rand_score", error = "no null fit"))
	na = list(compute_rand_two_sided_pval = function(type = NULL) NA_real_)
	expect_identical(ft$cal_extra_pval(na, "rand_score")$error, "returned a non-finite p-value")
	expect_identical(ft$cal_extra_pval(list(), "rand_score"), list(pval = NA_real_, method = NA_character_))
})

test_that("the registry resolves rand_score as a variant of rand in regime and convergence expectation", {
	expect_identical(reg$EDI_INFERENCE_PROCEDURE_VARIANTS, c(rand_score = "rand"))
	# Every variant points at a sentinel and is not one itself (the regime table must stay the sentinel list).
	expect_true(all(reg$EDI_INFERENCE_PROCEDURE_VARIANTS %in% names(reg$EDI_INFERENCE_PROCEDURE_REGIME)))
	expect_false(any(names(reg$EDI_INFERENCE_PROCEDURE_VARIANTS) %in% names(reg$EDI_INFERENCE_PROCEDURE_REGIME)))
	expect_identical(reg$inference_procedure_base_label(c("rand_score", "wald", "mystery")), c("rand", "wald", "mystery"))
	expect_identical(reg$inference_procedure_regime(c("rand_score", "rand", "wald", "mystery")), c("finite_sample", "finite_sample", "asymptotic", NA))
	for (d in c("DesignSeqOneByOneKK14", "DesignFixedBinaryMatch")) for (cl in CLMM_CLASSES) {
		a = reg$inference_convergence_expectation(d, cl, "rand_score")
		b = reg$inference_convergence_expectation(d, cl, "rand")
		expect_identical(a$procedure, "rand_score")
		expect_identical(a[setdiff(names(a), "procedure")], b[setdiff(names(b), "procedure")], info = paste(d, cl))
	}
	expect_error(reg$inference_convergence_expectation("DesignFixedBernoulli", "InferenceContinLin", "mystery"), "mystery")
})

test_that("tier 1 lists rand_score as a p-value-only procedure next to rand", {
	src = readLines(file.path(cal_dir, "calibration_study_common.R"))
	e = new.env()
	eval(parse(text = grep("^CAL_STUDY_TIER1_(METHODS|PVAL_ONLY) <-", src, value = TRUE)), envir = e)
	expect_true(all(c("rand", "rand_score") %in% e$CAL_STUDY_TIER1_METHODS))
	expect_setequal(e$CAL_STUDY_TIER1_PVAL_ONLY, c("rand", "rand_score"))
})

# With the installed EDI: the roster counts rand_score as a size test only, and a real replicate runs it on the same draws.
edi_ok = requireNamespace("EDI", quietly = TRUE)
score_ok = edi_ok && ft$cal_class_has_private_method("InferenceOrdinalKKCLMM", "compute_clmm_score_rand_pval")

test_that("roster and runner: rand_score is a size test without a CI, for the KK CLMM classes only (installed EDI)", {
	skip_if_not(edi_ok, "EDI not installed")
	st = new.env(parent = globalenv())
	st$script_dir = cal_dir
	suppressPackageStartupMessages(library(EDI))
	sys.source(file.path(cal_dir, "calibration_study_stats.R"), envir = st)
	sys.source(file.path(cal_dir, "calibration_study_common.R"), envir = st)
	sys.source(file.path(cal_dir, "build_calibration_study_roster.R"), envir = st)
	r = st$cal_roster_enumerate("ordinal", "DesignSeqOneByOneKK14", 50L)
	des = st$cal_study_throwaway_design("ordinal", "DesignSeqOneByOneKK14", 50L)
	for (k in seq_len(nrow(r))) {
		tk = get("cal_task_list", envir = globalenv())(des, r$inf_class[[k]], st$CAL_STUDY_TIER1_METHODS)
		m = vapply(tk, `[[`, "", "method")
		n_rs = sum(m == "rand_score")
		if (r$inf_class[[k]] %in% CLMM_CLASSES && score_ok) expect_identical(n_rs, sum(m == "rand"), info = r$inf_class[[k]])
		else expect_identical(n_rs, 0L, info = r$inf_class[[k]])
		expect_identical(r$n_size[[k]], length(tk))
		expect_identical(r$n_cov[[k]], sum(!(m %in% c("rand", "rand_score"))))
	}
	# An EDI without the statistic (the campaign 2026-11-15-e36c7710 commit): no rand_score task, and nothing errors.
	if (!score_ok) expect_false(any(vapply(get("cal_task_list", envir = globalenv())(des, "InferenceOrdinalKKCLMM", st$CAL_STUDY_TIER1_METHODS),
		`[[`, "", "method") == "rand_score"))
})

test_that("a real replicate runs rand_score with rand's draws and writes a p-value without a CI (installed EDI with the statistic)", {
	skip_if_not(score_ok, "installed EDI has no compute_rand_two_sided_pval(type = \"score\") for the KK CLMM classes")
	st = new.env(parent = globalenv())
	st$script_dir = cal_dir
	suppressPackageStartupMessages(library(EDI))
	sys.source(file.path(cal_dir, "calibration_study_common.R"), envir = st)
	# calibration_study_common.R source()s the fast-tier core into the global environment, as the runner does.
	g = globalenv()
	old_formulas = g$CAL_FORMULAS
	g$CAL_FORMULAS = list(~ 1)   # one formula keeps the default randomization p-value to one refit pass
	on.exit(g$CAL_FORMULAS <- old_formulas, add = TRUE)
	des = st$cal_study_throwaway_design("ordinal", "DesignSeqOneByOneKK14", 50L)
	tab = g$cal_run_tasks(des, "InferenceOrdinalKKCLMM", methods = c("rand", "rand_score"), pval_only = c("rand", "rand_score"))
	expect_identical(tab$method, c("rand", "rand_score"))
	rs = tab[tab$method == "rand_score", ]
	expect_identical(rs$status, "ok")
	expect_true(is.finite(rs$pval) && rs$pval > 0 && rs$pval <= 1)
	expect_true(is.na(rs$ci_a) && is.na(rs$ci_b))
	expect_identical(rs$estimate, tab$estimate[tab$method == "rand"])
	# Both used one set of draws: the design's permutation cache holds a single entry, and a fresh object's
	# type = "score" p-value on that design (which reads the cache) is the row's.
	cache = des$.__enclos_env__$private$permutations_cache
	expect_identical(length(cache), 1L)
	inf = EDI::InferenceOrdinalKKCLMM$new(des, model_formula = ~ 1)   # the row's formula (CAL_FORMULAS above)
	expect_equal(inf$compute_rand_two_sided_pval(type = "score", show_progress = FALSE), rs$pval)
})
