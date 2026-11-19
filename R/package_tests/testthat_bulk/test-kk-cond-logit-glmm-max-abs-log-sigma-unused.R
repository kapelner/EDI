library(testthat)
library(EDI)

# docs-claims audit, findings docs-claims-d28c6b4fe (InferenceIncidKKCondLogitGLMMIVWC) and
# docs-claims-d61b2254a (InferenceIncidKKCondLogitGLMMOneLik): since v1.0.5 the incidence leaves have
# no random effect, so max_abs_log_sigma is accepted but unused. Constructing with very different
# values must succeed and give identical estimates, standard errors and p-values.

make_kk_incid <- function(seed, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "incidence", n = n, verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.7 * w + 0.5 * X$x1)))
	des
}

for (cls in c("InferenceIncidKKCondLogitGLMMIVWC", "InferenceIncidKKCondLogitGLMMOneLik")) {
	test_that(paste0(cls, ": max_abs_log_sigma is accepted but has no effect on the fit"), {
		gen <- get(cls, envir = asNamespace("EDI"))
		des <- make_kk_incid(11L)
		a <- NULL; b <- NULL
		expect_no_error(a <- gen$new(des, max_abs_log_sigma = 0.5, verbose = FALSE))
		expect_no_error(b <- gen$new(des, max_abs_log_sigma = 8, verbose = FALSE))
		est_a <- a$compute_estimate()
		expect_true(is.finite(est_a))
		expect_identical(est_a, b$compute_estimate())
		expect_identical(a$.__enclos_env__$private$get_standard_error(), b$.__enclos_env__$private$get_standard_error())
		expect_identical(a$compute_asymp_two_sided_pval(), b$compute_asymp_two_sided_pval())
		expect_identical(a$compute_asymp_confidence_interval(), b$compute_asymp_confidence_interval())
	})
}
