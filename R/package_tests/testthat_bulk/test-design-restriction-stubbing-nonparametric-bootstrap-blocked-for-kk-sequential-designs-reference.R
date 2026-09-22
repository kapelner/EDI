library(testthat)
library(EDI)

# apply_inference_design_restrictions() / get_design_excluded_inference_capabilities(): every DesignSeqOneByOne descendant except the concrete
# DesignSeqOneByOneBernoulli class (whose assignment does not depend on prior subjects) has its nonparametric-bootstrap public methods replaced with a stub
# that stop()s "This method is not supported for DesignSeqOneByOne designs.", at construction time, on the instance only (never the class). Every alias of
# that capability that actually exists on the class is stubbed. capabilities() drops "nonparametric_bootstrap" for restricted instances. Fixed (non-
# sequential) designs and DesignSeqOneByOneBernoulli itself are unrestricted; a KK21 (DesignSeqOneByOne descendant) is restricted the same as KK14.

mk <- function(design_cls, ...) {
	set.seed(1); n <- 10L
	d <- design_cls$new(n = n, response_type = "continuous", verbose = FALSE, ...)
	if (is.function(d$add_one_subject_to_experiment_and_assign)) {
		for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
		d$add_all_subject_responses(rnorm(n))
	} else {
		d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	}
	InferenceContinOLS$new(d, verbose = FALSE)
}

test_that("KK14 (a DesignSeqOneByOne descendant): the bootstrap CI method and its aliases are stubbed to a locked-binding error; capabilities() drops it", {
	inf <- mk(DesignSeqOneByOneKK14)
	expect_error(inf$compute_bootstrap_confidence_interval(), "This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
	expect_false("nonparametric_bootstrap" %in% inf$capabilities())
	for (m in c("approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", "select_optimal_m_out_of_n_bootstrap",
			"approximate_subsampling_distribution_beta_hat_T", "select_optimal_b_subsampling", "compute_subsampling_sensitivity")) {
		expect_true(is.function(inf[[m]]), info = m)
		expect_error(inf[[m]](), "This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE, info = m)
	}
	expect_error(inf$compute_asymp_confidence_interval(), NA)                          # unrelated capabilities are untouched
})

test_that("KK21 (a different DesignSeqOneByOne descendant) is restricted the same way", {
	inf <- mk(DesignSeqOneByOneKK21)
	expect_error(inf$compute_bootstrap_confidence_interval(), "This method is not supported for DesignSeqOneByOne designs.", fixed = TRUE)
})

test_that("DesignSeqOneByOneBernoulli itself is the documented exception: unrestricted", {
	inf <- mk(DesignSeqOneByOneBernoulli)
	expect_true(is.finite(inf$compute_bootstrap_confidence_interval()[1]))
	expect_true("nonparametric_bootstrap" %in% inf$capabilities())
})

test_that("a fixed (non-sequential) design is unrestricted", {
	inf <- mk(DesignFixedBernoulli, seed = 1L)
	expect_true(is.finite(inf$compute_bootstrap_confidence_interval()[1]))
	expect_true("nonparametric_bootstrap" %in% inf$capabilities())
})

test_that("the restriction applies to the instance, not the class: a fresh Bernoulli instance from the same class is never touched", {
	inf_kk <- mk(DesignSeqOneByOneKK14)
	inf_bern <- mk(DesignSeqOneByOneBernoulli)
	expect_error(inf_kk$compute_bootstrap_confidence_interval(), "This method is not supported")
	expect_true(is.finite(inf_bern$compute_bootstrap_confidence_interval()[1]))
})
