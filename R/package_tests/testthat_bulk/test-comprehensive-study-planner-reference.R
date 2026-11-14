# v1.1.0 TODO-194: the cloud comprehensive study's wave planner
# (R/package_tests/cloud/plan_comprehensive_study.R). Base R + data.table, no EDI.

find_cloud_planner = function() {
	for (d in c(getwd(), dirname(getwd()), dirname(dirname(getwd())))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		f = if (length(top)) file.path(top[1], "R", "package_tests", "cloud", "plan_comprehensive_study.R") else ""
		if (nzchar(f) && file.exists(f)) return(f)
	}
	testthat::skip("plan_comprehensive_study.R not found")
}

load_cloud_planner = function() {
	env = new.env()
	suppressPackageStartupMessages(library(data.table))
	sys.source(find_cloud_planner(), envir = env)
	env
}

toy_costs = function() data.table::data.table(
	response_type = "incidence", dataset = "pima", design = c("Bernoulli", "Bernoulli", "Bernoulli", "FixediBCRD"),
	class = c("InferenceA", "InferenceB", "InferenceBig", "InferenceA"), beta_T = c(0, 0, 0, 0.5),
	sec_per_rep = c(30, 60, 2000, 40), reps_seen = 5L)

testthat::test_that("every piece is planned once: both beta_T values, every rep, one catch-all per case at rep 1", {
	pl = load_cloud_planner()
	res = pl$cs_plan(toy_costs(), NULL, reps = 3L, wave_size = 1000L, speed = 1, overhead_sec = 10, call_minutes = 20, target_minutes = 25)
	p = res$plan
	# 4 (response, dataset, design, class) x 2 beta_T x 3 reps, plus 4 (case, beta_T) catch-alls
	testthat::expect_identical(res$remaining, 4L * 2L * 3L + 4L)
	main = p[classes != "__other__"]
	covered = main[, .(class = unlist(strsplit(classes, ";", fixed = TRUE))), by = .(design, beta_T, reps)][
		, .(rep = as.integer(unlist(strsplit(reps, ",", fixed = TRUE)))), by = .(design, beta_T, class)]
	testthat::expect_identical(nrow(covered), 24L)
	testthat::expect_identical(anyDuplicated(covered), 0L)
	other = p[classes == "__other__"]
	testthat::expect_identical(nrow(other), 4L)
	testthat::expect_true(all(other$reps == "1"))
	testthat::expect_true(all(other$class_regex == "NA"))
	testthat::expect_true(all(grepl("InferenceA", other$exclude_regex, fixed = TRUE)))
	# a class seen at one beta_T gets that cost at the other
	testthat::expect_true(any(main$design == "FixediBCRD" & main$beta_T == 0))
	# the anchored class regex selects exactly its classes and their formula variants
	re = main[grepl("InferenceA;InferenceB|InferenceB;InferenceA", classes)][1L]$class_regex
	testthat::expect_true(all(grepl(re, c("InferenceA", "InferenceB (model_formula=~1)", "InferenceA [design_formula=~.]"))))
	testthat::expect_false(any(grepl(re, c("InferenceAB", "InferenceBig"))))
})

testthat::test_that("an expensive class runs one rep per call, cheap classes share calls across reps", {
	pl = load_cloud_planner()
	p = pl$cs_plan(toy_costs(), NULL, reps = 3L, wave_size = 1000L, speed = 1, overhead_sec = 10, call_minutes = 20, target_minutes = 25)$plan
	big = p[classes == "InferenceBig"]
	testthat::expect_true(all(big$n_reps == 1L))
	cheap = p[design == "Bernoulli" & beta_T == 0 & grepl("InferenceA", classes, fixed = TRUE)]
	testthat::expect_identical(nrow(cheap), 1L)
	testthat::expect_identical(cheap$reps, "1,2,3")
})

testthat::test_that("ledger pieces are not re-planned, and a full ledger means complete", {
	pl = load_cloud_planner()
	costs = toy_costs()
	first = pl$cs_plan(costs, NULL, reps = 2L, wave_size = 1000L, speed = 1, overhead_sec = 10)
	ledger = first$plan[, .(class = unlist(strsplit(classes, ";", fixed = TRUE))), by = .(response_type, dataset, design, beta_T, reps)][
		, .(rep = as.integer(unlist(strsplit(reps, ",", fixed = TRUE)))), by = .(response_type, dataset, design, beta_T, class)]
	half = ledger[rep == 1L | class == "__other__"]
	second = pl$cs_plan(costs, half, reps = 2L, wave_size = 1000L, speed = 1, overhead_sec = 10)
	testthat::expect_identical(second$remaining, first$remaining - nrow(half))
	done = pl$cs_plan(costs, ledger, reps = 2L, wave_size = 1000L, speed = 1, overhead_sec = 10)
	testthat::expect_identical(done$jobs, 0L)
	testthat::expect_identical(done$remaining, 0L)
})

testthat::test_that("the wave holds at most wave_size jobs of at most `procs` processes", {
	pl = load_cloud_planner()
	res = pl$cs_plan(toy_costs(), NULL, reps = 20L, wave_size = 3L, procs = 4L, speed = 1, overhead_sec = 10)
	testthat::expect_lte(res$jobs, 3L)
	testthat::expect_true(all(res$plan$proc %in% 0:3))
	testthat::expect_lt(nrow(res$plan), res$remaining)
})
