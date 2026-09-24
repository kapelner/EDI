library(testthat)
library(EDI)

# Several KK compound-estimator classes' compute_asymp_two_sided_pval(delta) methods only support
# testing against the sharp null (delta = 0); a nonzero delta falls to a `should_run_asserts()`-gated
# stop() (in normal operation always firing, since assertions are on by default): "Testing non-zero
# delta is not yet implemented for this class." on InferenceCountKKHurdlePoissonIVWC (inference_
# count_KK_cond_poisson.R), InferenceSurvivalKKStratCoxPHIVWC (inference_survival_KK_strat_cox.R), and
# InferenceSurvivalKKLWACoxPHIVWC (inference_survival_KK_lwa_cox_ivwc_abstract.R); and the differently-
# worded sibling "Testing non-zero delta is not yet implemented for the combined rank estimator." on
# InferenceAllKKWilcoxIVWC (inference_all_KK_wilcox_ivwc.R). A codebase-wide grep confirmed neither
# message had any test reference anywhere, despite all 4 classes being otherwise extensively tested
# elsewhere (matched-reservoir combination branches, nonestimable guards, migration-golden parity) --
# every existing reference tests delta = 0 (the default) only.

test_that("InferenceCountKKHurdlePoissonIVWC rejects a nonzero delta with the documented message", {
	set.seed(1L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.3 * w)))
	inf <- InferenceCountKKHurdlePoissonIVWC$new(des, verbose = FALSE)
	expect_error(
		inf$compute_asymp_two_sided_pval(delta = 0.5),
		"Testing non-zero delta is not yet implemented for this class.",
		fixed = TRUE
	)
})

test_that("InferenceSurvivalKKStratCoxPHIVWC and InferenceSurvivalKKLWACoxPHIVWC both reject a nonzero delta with the same documented message", {
	set.seed(2L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))

	inf_strat <- InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)
	expect_error(
		inf_strat$compute_asymp_two_sided_pval(delta = 0.5),
		"Testing non-zero delta is not yet implemented for this class.",
		fixed = TRUE
	)

	inf_lwa <- InferenceSurvivalKKLWACoxPHIVWC$new(des, verbose = FALSE)
	expect_error(
		inf_lwa$compute_asymp_two_sided_pval(delta = 0.5),
		"Testing non-zero delta is not yet implemented for this class.",
		fixed = TRUE
	)
})

test_that("InferenceAllKKWilcoxIVWC rejects a nonzero delta with its own differently-worded documented message", {
	set.seed(3L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	inf <- InferenceAllKKWilcoxIVWC$new(des, verbose = FALSE)
	expect_error(
		inf$compute_asymp_two_sided_pval(delta = 0.5),
		"Testing non-zero delta is not yet implemented for the combined rank estimator.",
		fixed = TRUE
	)
})

test_that("delta = 0 (the default) never triggers any of the four guards", {
	set.seed(4L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.3 * w)))
	inf <- InferenceCountKKHurdlePoissonIVWC$new(des, verbose = FALSE)
	expect_no_error(inf$compute_asymp_two_sided_pval(delta = 0))
})
