library(testthat)
library(EDI)

# v1.0.6-TODO-306 (docs-scenarios factorial F7, also ds-incidence-44883784401-f4): when an arm has no
# events the exact-Fisher conditional MLE is infinite; compute_estimate() returned a bare NA with no
# warning. It now warns once (edi_procedure_na_warning, reason exact_fisher_conditional_mle_infinite),
# naming the empty arm; the exact CI and p-value are unchanged.

fisher_zero_arm_fixture = function(design) {
	set.seed(9)
	n = 40
	A = sample(rep(0:1, 20))
	B = integer(n)
	for (a in 0:1) B[A == a] = sample(rep(0:1, 10))
	y = ifelse(A == 0, 0L, rbinom(n, 1, 0.4))
	des = if (design == "blocking") {
		DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "B", verbose = FALSE)
	} else {
		DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	}
	des$add_all_subjects_to_experiment(data.frame(age = rnorm(n), B = factor(B)))
	des$assign_w_to_all_subjects(w_precomputed = A)
	des$add_all_subject_responses(y)
	list(des = des, A = A, B = B, y = y)
}

test_that("an arm with no events gives one classed warning naming it; exact CI and p-value stay valid", {
	for (design in c("blocking", "ibcrd")) {
		f = fisher_zero_arm_fixture(design)
		fe = InferenceIncidExactFisher$new(f$des, verbose = FALSE)
		w = tryCatch(fe$compute_estimate(), edi_procedure_na_warning = function(w) w)
		expect_s3_class(w, "edi_procedure_na_warning")
		expect_identical(w$reason, "exact_fisher_conditional_mle_infinite")
		expect_match(conditionMessage(w), "control arm has no events", fixed = TRUE)
		expect_true(is.na(suppressWarnings(fe$compute_estimate())))
		expect_true(fe$is_nonestimable())
		n_warn = 0L
		withCallingHandlers(fe$compute_estimate(), edi_procedure_na_warning = function(w) {
			n_warn <<- n_warn + 1L; invokeRestart("muffleWarning")
		})
		expect_identical(n_warn, 0L, info = design)
		p = fe$compute_exact_two_sided_pval_for_treatment_effect()
		expect_true(is.finite(p) && p < 0.05, info = design)
		ci = fe$compute_exact_confidence_interval()
		expect_true(is.finite(ci[1]) && is.infinite(ci[2]), info = design)
	}
})
