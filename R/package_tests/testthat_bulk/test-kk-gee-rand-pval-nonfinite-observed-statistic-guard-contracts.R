# Untested-code audit, 2026-11-24: covers R/EDI/R/inference_mixin_kk_gee_shared.R:183-184
# (compute_rand_two_sided_pval; region unt-9b0c3da228aa).
# Reference: Documented guard contract: an NA_real_ return and the recorded reason
# 'randomization_observed_statistic_unavailable' (edi_record_procedure_failure,
# helper_robust_sandwich.R:975).
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 2 of 2
# target lines (6.3 s).

library(testthat)
library(EDI)

test_that("KK GEE randomization p-value returns NA and records the documented reason when the observed statistic is non-finite", {
	set.seed(11L)
	n = 30L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	des$add_all_subject_responses(rpois(n, 2))
	inf = InferenceCountPoissonKKGEE$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	# Defensive guard (contract section 5): no public input makes the observed GEE statistic non-finite
	# without also flagging it nonestimable, so the private observed-statistic method is stubbed.
	unlockBinding("compute_treatment_estimate_during_randomization_inference", priv)
	priv$compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE) NaN

	pval = inf$compute_rand_two_sided_pval(r = 20L, show_progress = FALSE)
	# Documented contract: NA p-value plus the recorded failure reason (as a procedure failure when the
	# Wald fit is intact, else as the nonestimable reason; see edi_record_procedure_failure()).
	expect_identical(pval, NA_real_)
	reasons = c(unlist(priv$cached_values$procedure_failure_reason), inf$get_nonestimable_reason())
	expect_true("randomization_observed_statistic_unavailable" %in% reasons)
})
