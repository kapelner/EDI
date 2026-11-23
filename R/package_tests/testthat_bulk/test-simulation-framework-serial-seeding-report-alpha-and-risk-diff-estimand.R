# v1.0.6-TODO-354 (ds-simulation-framework-44883784401-f4/-f5): the serial SimulationFramework loop seeded
# once for the whole run while the fork / mirai paths seed replication i with seed + i, so results depended
# on num_cores and a resumed run (continue_from_last_result_row) replayed the first replications' data.
# v1.0.6-TODO-356 (ds-simulation-framework-44883784401-f9): SimulationFrameworkReport$new(sim, alpha = a)
# tested coverage of intervals built at the framework's alpha against 1 - a.
# v1.0.6-TODO-357 (ds-simulation-framework-44883784401-f10): InferenceIncidGCompRiskDiff (and
# InferenceIncidBinomialIdentityRiskDiff) were scored against the logit-scale betaT instead of the risk
# difference.

make_seeded_sim = function(nrep, cores, file, cont = FALSE){
	SimulationFramework$new(
		response_type = "continuous",
		# One (design, inference) cell: the fork path seeds per replication and the mirai path per
		# (replication, cell), so with one cell every backend uses seed + rep (a shard that already
		# started mirai daemons runs num_cores = 2 on mirai).
		design_classes_and_params = list(DesignFixediBCRD = list()),
		inference_classes_and_params = list(InferenceContinOLS = list()),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
		n = 20, p = 2, Nrep_W = nrep, betaT = 1, num_cores = cores, seed = 42L,
		results_filename = file, continue_from_last_result_row = cont, verbose = FALSE
	)
}
sim_result_rows = function(r){
	k = c("rep", "design", "inference", "inference_type", "estimate", "ci_lo", "ci_hi", "pval")
	r = as.data.frame(r)[, k]
	r = r[order(r$rep, r$design, r$inference_type), ]
	rownames(r) = NULL
	r
}

test_that("a seeded serial run reproduces the 2-core run and a resumed run equals a fresh one", {
	skip_on_os("windows")
	fresh = make_seeded_sim(4L, 1L, tempfile(fileext = ".csv"))
	fresh$run()
	r_fresh = sim_result_rows(SimulationFrameworkReport$new(fresh)$get_results())

	two_cores = make_seeded_sim(4L, 2L, tempfile(fileext = ".csv"))
	two_cores$run()
	expect_equal(sim_result_rows(SimulationFrameworkReport$new(two_cores)$get_results()), r_fresh)

	f = tempfile(fileext = ".csv")
	first = make_seeded_sim(2L, 1L, f)
	first$run()
	resumed = make_seeded_sim(4L, 1L, f, cont = TRUE)
	resumed$run()
	r_resumed = sim_result_rows(SimulationFrameworkReport$new(resumed)$get_results())
	expect_equal(r_resumed, r_fresh)
	# the resumed replications are new data, not a replay of replications 1 and 2
	expect_false(isTRUE(all.equal(r_resumed$estimate[r_resumed$rep == 3], r_resumed$estimate[r_resumed$rep == 1])))
})

test_that("an alpha override changes power / size but not the coverage test, and risk differences are scored on the RD scale", {
	sim = SimulationFramework$new(
		response_type = "incidence",
		design_classes_and_params = list(DesignFixediBCRD = list()),
		inference_classes_and_params = list(InferenceIncidGCompRiskDiff = list(), InferenceIncidNewcombeRiskDiff = list()),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
		n = 200, p = 2, Nrep_W = 10L, betaT = 1, seed = 7L,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE, verbose = FALSE
	)
	suppressWarnings(sim$run())
	report = SimulationFrameworkReport$new(sim)
	res = report$get_results()
	te = tapply(res$true_estimand, res$inference, mean)
	# G-comp RD and Newcombe RD target the same risk difference, not betaT = 1
	expect_equal(unname(te["InferenceIncidGCompRiskDiff"]), unname(te["InferenceIncidNewcombeRiskDiff"]))
	expect_lt(abs(te[["InferenceIncidGCompRiskDiff"]]), 0.5)
	s_default = report$summarize()
	s_override = SimulationFrameworkReport$new(sim, alpha = 0.2)$summarize()
	expect_identical(s_override$coverage, s_default$coverage)
	expect_identical(s_override$coverage_pval, s_default$coverage_pval)
	expect_true(any(is.finite(s_default$coverage_pval)))
})

test_that("every incidence risk-difference class is scored against the mean-difference estimand", {
	rd_classes = grep("^InferenceIncid.*RiskDiff$", ls(asNamespace("EDI")), value = TRUE)
	expect_true(length(rd_classes) >= 6L)
	for (cl in rd_classes) {
		gen = get(cl, envir = asNamespace("EDI"))
		if (!inherits(gen, "R6ClassGenerator")) next
		expect_true(cl %in% EDI:::EDI_SIM_MEAN_DIFF_INFERENCE_CLASSES, info = cl)
	}
})
