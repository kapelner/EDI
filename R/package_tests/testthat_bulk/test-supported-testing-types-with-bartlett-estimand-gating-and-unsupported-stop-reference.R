library(testthat)
library(EDI)

# InferenceAsympLik private get_supported_testing_types_with_bartlett(): the base supported types plus the Bartlett
# lik-ratio variants the class supports (approx / exact), de-duplicated, collapsing to "wald" when a non-conditional
# marginal estimand is selected; stop_bartlett_unsupported() message; the public get_supported_testing_types()
# mirrors it. Real OLS (approx-Bartlett) and logistic (marginal-estimand) objects are the fixtures.

mk <- function(cls, rt, y_fn, n = 40L, seed = 1L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = rt, n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(y_fn(d$get_w(), n))
	inf <- cls$new(d, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}
ols <- mk(InferenceContinOLS, "continuous", function(w, n) rnorm(n) + w)
lg <- mk(InferenceIncidLogRegr, "incidence", function(w, n) rbinom(n, 1, 0.3 + 0.3 * w))

test_that("base types come from the impl; Bartlett variants are appended per the support flags", {
	for (f in list(ols, lg)) {
		base <- f$p$get_supported_testing_types_impl()
		got <- f$p$get_supported_testing_types_with_bartlett()
		expect_identical(got[seq_along(base)], base)
		extra <- setdiff(got, base)
		expect_identical("lik_ratio_bartlett_approx" %in% extra, isTRUE(f$p$supports_bartlett_likelihood_ratio_approx()))
		expect_identical("lik_ratio_bartlett_exact" %in% extra, isTRUE(f$p$supports_bartlett_likelihood_ratio_exact()))
		expect_false(anyDuplicated(got) > 0)
		expect_identical(f$inf$get_supported_testing_types(), got)
	}
	expect_identical(ols$p$get_supported_testing_types_with_bartlett(),
		c("wald", "score", "gradient", "lik_ratio", "lik_ratio_bartlett_approx"))
})

test_that("stubbing the support flags adds / removes the Bartlett variants (both, one, none)", {
	f <- mk(InferenceContinOLS, "continuous", function(w, n) rnorm(n) + w)
	for (nm in c("supports_bartlett_likelihood_ratio_approx", "supports_bartlett_likelihood_ratio_exact")) unlockBinding(nm, f$p)
	stub <- function(a, e) { f$p$supports_bartlett_likelihood_ratio_approx <- function() a; f$p$supports_bartlett_likelihood_ratio_exact <- function() e }
	base <- f$p$get_supported_testing_types_impl()
	stub(FALSE, FALSE); expect_identical(f$p$get_supported_testing_types_with_bartlett(), base)
	stub(TRUE, FALSE); expect_identical(f$p$get_supported_testing_types_with_bartlett(), c(base, "lik_ratio_bartlett_approx"))
	stub(FALSE, TRUE); expect_identical(f$p$get_supported_testing_types_with_bartlett(), c(base, "lik_ratio_bartlett_exact"))
	stub(TRUE, TRUE); expect_identical(f$p$get_supported_testing_types_with_bartlett(), c(base, "lik_ratio_bartlett_approx", "lik_ratio_bartlett_exact"))
})

test_that("a non-conditional marginal estimand collapses the supported set to Wald; switching back restores it", {
	f <- mk(InferenceIncidLogRegr, "incidence", function(w, n) rbinom(n, 1, 0.3 + 0.3 * w))
	full <- f$p$get_supported_testing_types_with_bartlett()
	expect_gt(length(full), 1L)
	expect_true(isTRUE(f$inf$supports("marginal_estimand")))
	for (est in setdiff(f$inf$get_supported_estimands(), "conditional")) {
		f$inf$set_estimand(est)
		expect_identical(f$p$get_supported_testing_types_with_bartlett(), "wald", info = est)
		expect_identical(f$inf$get_supported_testing_types(), "wald", info = est)
	}
	f$inf$set_estimand("conditional")
	expect_identical(f$p$get_supported_testing_types_with_bartlett(), full)
})

test_that("classes without the marginal-estimand capability are unaffected by that gate", {
	expect_false(isTRUE(ols$inf$supports("marginal_estimand")))
	expect_gt(length(ols$p$get_supported_testing_types_with_bartlett()), 1L)
})

test_that("stop_bartlett_unsupported names the class and points at the two support predicates", {
	expect_error(lg$p$stop_bartlett_unsupported(),
		"InferenceIncidLogRegr does not support Bartlett-corrected likelihood-ratio inference")
	expect_error(ols$p$stop_bartlett_unsupported(), "supports_bartlett_likelihood_ratio_exact\\(\\) / supports_bartlett_likelihood_ratio_approx\\(\\)")
	expect_error(ols$p$stop_bartlett_unsupported(), "InferenceContinOLS")
})
