library(testthat)
library(EDI)

# InferenceIncidMiettinenNurminenRiskDiff$compute_asymp_two_sided_pval(): after computing mn_pvalue_cpp()'s
# restricted-MLE score p-value for a candidate null delta, the result is asserted finite, erroring otherwise --
# naturally reached (not just via corrupted internal state) by a delta outside the risk-difference's valid
# [-1, 1] range, for which the C++ kernel's restricted-MLE optimization has no feasible solution and returns NA.
# Had no test calling this method with an out-of-range delta; existing coverage of the class's asymp p-value only
# exercises deltas within [-1, 1] (including the empty-arm NA-without-error path, a different guard).

fx <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	InferenceIncidMiettinenNurminenRiskDiff$new(des, verbose = FALSE)
}

test_that("a delta outside the valid [-1, 1] risk-difference range errors with the documented message", {
	for (d in c(1.5, -1.5, 2, -2)) {
		inf <- fx()
		expect_error(
			inf$compute_asymp_two_sided_pval(delta = d),
			"Miettinen-Nurminen risk-difference: could not compute a finite score statistic\\.",
			info = d
		)
	}
})

test_that("deltas within the valid range do not trip the guard and return finite p-values", {
	inf <- fx()
	for (d in c(-0.5, 0, 0.3, 0.99, -0.99)) {
		pv <- inf$compute_asymp_two_sided_pval(delta = d)
		expect_true(is.finite(pv) && pv >= 0 && pv <= 1, info = d)
	}
})

test_that("with assertions disabled, an out-of-range delta returns NA instead of erroring", {
	inf <- fx()
	old <- getOption("edi.run_asserts")
	on.exit(options(edi.run_asserts = old), add = TRUE)
	options(edi.run_asserts = FALSE)
	out <- tryCatch(inf$compute_asymp_two_sided_pval(delta = 1.5), error = function(e) e)
	expect_false(inherits(out, "error"))
	expect_true(is.na(out))
})
