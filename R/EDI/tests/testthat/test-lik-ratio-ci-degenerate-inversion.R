library(testthat)
library(EDI)

# A likelihood-ratio CI whose two bounds both collapse onto the point estimate is
# a failed inversion, not a confidence interval. Found 2026-09-20 in raw
# comprehensive_tests results: OrdinalStereotypeLogitRegr's lik_ratio CI was
# zero-width in 5.6% of rows and lik_ratio_bootstrap in 28% (all of them missing
# the truth; the remaining intervals covered ~0.94). Two independent causes:
#   * finalize_inverted_ci() only treated bit-identical bounds as the sentinel, but
#     Newton ends converge to within ~1e-4..1e-6 of the estimate;
#   * compute_lik_ratio_bootstrap_confidence_interval() returned c(est, est) when
#     the bootstrap p-value AT the estimate was < alpha (it should be ~1 there).

lr_fixture = function() {
	set.seed(2026)
	n = 70L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	w = rbinom(n, 1, 0.5)
	y = as.integer(cut(0.7 * X$x1 + rlogis(n), c(-Inf, -1.2, -0.2, 0.9, Inf)))
	d = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$overwrite_all_subject_assignments(w)
	d$add_all_subject_responses(y)
	InferenceOrdinalStereotypeLogitRegr$new(d)
}

test_that("finalize_inverted_ci rejects near-degenerate bounds (not just bit-identical ones)", {
	inst = lr_fixture()
	priv = inst$.__enclos_env__$private
	est = -0.64
	wald = c(-2.03, 0.75)
	# Bounds equal to within 1e-7: a collapsed inversion. Falls back to Wald (which brackets est).
	got = priv$finalize_inverted_ci(c(est, est + 1e-7), 0.05, est, wald, "unavailable")
	expect_equal(as.numeric(got), wald)
	# Same collapse with a Wald interval that does not bracket est: non-estimable, NA.
	got_na = priv$finalize_inverted_ci(c(est, est + 1e-7), 0.05, est, c(0.1, 0.9), "unavailable")
	expect_true(all(is.na(got_na)))
	# A genuine, comparably-wide interval passes through untouched.
	real = c(-1.7, 0.6)
	expect_equal(as.numeric(priv$finalize_inverted_ci(real, 0.05, est, wald, "unavailable")), real)
})

test_that("LR bootstrap CI reports NA, not a zero-width interval at the estimate, when p(est) < alpha", {
	inst = lr_fixture()
	suppressWarnings(inst$compute_estimate())
	if (bindingIsLocked("compute_lik_ratio_bootstrap_two_sided_pval", inst)) unlockBinding("compute_lik_ratio_bootstrap_two_sided_pval", inst)
	inst$compute_lik_ratio_bootstrap_two_sided_pval = function(...) 0.001
	ci = suppressMessages(suppressWarnings(inst$compute_lik_ratio_bootstrap_confidence_interval(B = 19)))
	expect_true(all(is.na(ci)))
})
