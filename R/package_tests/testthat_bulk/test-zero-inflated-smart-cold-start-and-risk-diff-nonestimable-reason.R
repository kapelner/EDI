# v1.0.6-TODO-105: InferenceCountZeroInflatedPoisson and InferenceCountZeroInflatedNegBin
# accept smart_cold_start_default (as their hurdle siblings and the shared
# zero-augmented abstract already did) and forward it to the fit.
# v1.0.6-TODO-107: InferenceIncidRiskDiff's private shared() records a class-specific
# generate_mod_nonestimable_reason when generate_mod() returns NULL, as
# StandardModelCacheSource's shared() does, instead of always "model_fit_unavailable".

simulate_zi_count_design = function(seed = 1L, n = 200L){
	set.seed(seed)
	seq_des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	x1 = rnorm(n)
	for (i in seq_len(n)) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
	w = seq_des$get_w()
	y = ifelse(rbinom(n, 1L, plogis(-1 + 0.3 * w)) == 1L, 0, rpois(n, exp(0.5 + 0.4 * w + 0.2 * x1)))
	seq_des$add_all_subject_responses(y)
	seq_des
}

simulate_incid_design = function(seed = 1L, n = 40L, y = NULL){
	set.seed(seed)
	seq_des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	seq_des$add_all_subject_responses(if (is.null(y)) rbinom(n, 1L, 0.5) else y)
	seq_des
}

for (cls_name in c("InferenceCountZeroInflatedPoisson", "InferenceCountZeroInflatedNegBin")) {
	test_that(paste0(cls_name, " accepts and stores smart_cold_start_default"), {
		seq_des = simulate_zi_count_design(1L)
		cls = get(cls_name)
		expect_true("smart_cold_start_default" %in% names(formals(cls$public_methods$initialize)))
		inf_default = cls$new(seq_des)
		inf_false = cls$new(seq_des, smart_cold_start_default = FALSE)
		inf_true = cls$new(seq_des, smart_cold_start_default = TRUE)
		expect_false(inf_false$.__enclos_env__$private$smart_cold_start_default)
		expect_true(inf_true$.__enclos_env__$private$smart_cold_start_default)
		est_default = inf_default$compute_estimate()
		expect_true(is.finite(est_default))
		# Passing the resolved default explicitly reproduces the default fit.
		resolved_default = inf_default$.__enclos_env__$private$smart_cold_start_default
		inf_resolved = cls$new(seq_des, smart_cold_start_default = resolved_default)
		expect_identical(inf_resolved$compute_estimate(), est_default)
		expect_true(is.finite(inf_false$compute_estimate()))
	})
}

test_that("InferenceIncidRiskDiff: an all-zero response keeps the estimate and marks only the SE non-estimable", {
	# v1.0.6-TODO-197 (2026-11-24): with y all 0 the fit is perfect (RD = 0, HC0 variance 0). It used
	# to be rejected outright (reason model_fit_unavailable, estimate NA); the finite estimate is now
	# kept and only the SE is non-estimable.
	seq_des = simulate_incid_design(3L, y = rep(0, 40L))
	inf = InferenceIncidRiskDiff$new(seq_des)
	ci = suppressWarnings(inf$compute_asymp_confidence_interval())
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "model_standard_error_unavailable")
	expect_equal(as.numeric(inf$compute_estimate()), 0)
})

test_that("InferenceIncidRiskDiff: a NULL fit records the class-specific generate_mod_nonestimable_reason", {
	seq_des = simulate_incid_design(3L)
	inf = InferenceIncidRiskDiff$new(seq_des)
	priv = inf$.__enclos_env__$private
	unlockBinding("generate_mod", priv)
	priv$generate_mod = function(estimate_only = FALSE){
		priv$cached_values$generate_mod_nonestimable_reason = "risk_diff_specific_test_reason"
		NULL
	}
	expect_true(is.na(suppressWarnings(inf$compute_estimate())))
	expect_identical(inf$get_nonestimable_reason(), "risk_diff_specific_test_reason")
})
