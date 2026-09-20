library(testthat)
library(EDI)

# InferenceAsympLik's *_impl layer: every testing-type p-value / interval implementation delegates to the
# right worker with the right testing_type (and Bartlett B), and the combined Bartlett entry points prefer
# an exact factor over an approximate one, warn when a supplied B is ignored, and stop with an
# explanatory message when neither is available. Workers are replaced by recorders, so only routing is tested.

lk_fx <- function(n = 60L, seed = 2L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rbinom(n, 1, plogis(0.4 * w)))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}

recorded <- function(f) {
	log <- new.env(); log$calls <- list()
	rec <- function(name, ret) { force(name); force(ret); function(...) { log$calls[[length(log$calls) + 1L]] <- c(list(fn = name), list(...)); ret } }
	for (nm in c("compute_likelihood_test_two_sided_pval", "invert_test_pval_confidence_interval", "invert_gradient_ci_uniroot", "invert_lik_ratio_ci_newton")) {
		unlockBinding(nm, f$p)
		assign(nm, rec(nm, if (grepl("pval$", nm)) 0.123 else c(-1, 1)), envir = f$p)
	}
	log
}

test_that("p-value implementations pass their own testing type (and the Bartlett B) to the shared p-value worker", {
	f <- lk_fx(); log <- recorded(f)
	expect_equal(f$p$compute_score_two_sided_pval_impl(0.3), 0.123)
	expect_equal(f$p$compute_gradient_two_sided_pval_impl(0.3), 0.123)
	expect_equal(f$p$compute_lik_ratio_two_sided_pval_impl(0.3), 0.123)
	expect_equal(f$p$compute_lik_ratio_bartlett_approx_two_sided_pval_impl(0.3, B = 77), 0.123)
	expect_equal(f$p$compute_lik_ratio_bartlett_exact_two_sided_pval_impl(0.3), 0.123)
	types <- vapply(log$calls, function(cl) cl$testing_type, character(1))
	expect_equal(types, c("score", "gradient", "lik_ratio", "lik_ratio_bartlett_approx", "lik_ratio_bartlett_exact"))
	expect_true(all(vapply(log$calls, function(cl) cl$delta == 0.3, logical(1))))
	expect_equal(log$calls[[4]]$bartlett_B, 77)
	expect_null(log$calls[[5]]$bartlett_B)
	expect_equal(f$p$compute_lik_ratio_bartlett_approx_two_sided_pval_impl(0)  , 0.123)
	expect_equal(log$calls[[6]]$bartlett_B, 99)                                       # default B
})

test_that("interval implementations route to the inversion worker matching their test", {
	f <- lk_fx(); log <- recorded(f)
	f$p$compute_score_confidence_interval_impl(0.1)
	f$p$compute_gradient_confidence_interval_impl(0.1)
	f$p$compute_lik_ratio_confidence_interval_impl(0.1)
	f$p$compute_lik_ratio_bartlett_approx_confidence_interval_impl(0.1, B = 55)
	f$p$compute_lik_ratio_bartlett_exact_confidence_interval_impl(0.1)
	fns <- vapply(log$calls, function(cl) cl$fn, character(1))
	expect_equal(fns, c("invert_test_pval_confidence_interval", "invert_gradient_ci_uniroot", "invert_lik_ratio_ci_newton",
		"invert_test_pval_confidence_interval", "invert_test_pval_confidence_interval"))
	expect_equal(log$calls[[1]]$testing_type, "score")
	expect_equal(log$calls[[4]]$testing_type, "lik_ratio_bartlett_approx"); expect_equal(log$calls[[4]]$bartlett_B, 55)
	expect_equal(log$calls[[5]]$testing_type, "lik_ratio_bartlett_exact")
	expect_true(all(vapply(log$calls[c(2, 3)], function(cl) cl[[2]] == 0.1, logical(1))))
})

set_support <- function(f, exact, approx) {
	for (nm in c("supports_bartlett_likelihood_ratio_exact", "supports_bartlett_likelihood_ratio_approx")) unlockBinding(nm, f$p)
	f$p$supports_bartlett_likelihood_ratio_exact <- function() exact
	f$p$supports_bartlett_likelihood_ratio_approx <- function() approx
}

test_that("combined Bartlett p-value: exact wins over approximate, warning only when B was supplied", {
	f <- lk_fx(); log <- recorded(f); set_support(f, TRUE, TRUE)
	expect_silent(f$p$compute_lik_ratio_bartlett_two_sided_pval_impl(0.2))
	expect_equal(log$calls[[1]]$testing_type, "lik_ratio_bartlett_exact")
	expect_warning(f$p$compute_lik_ratio_bartlett_two_sided_pval_impl(0.2, B = 50, B_missing = FALSE), "B is ignored")
	expect_equal(log$calls[[2]]$testing_type, "lik_ratio_bartlett_exact")
	g <- lk_fx(); glog <- recorded(g); set_support(g, FALSE, TRUE)
	expect_silent(g$p$compute_lik_ratio_bartlett_two_sided_pval_impl(0.2, B = 42, B_missing = FALSE))
	expect_equal(glog$calls[[1]]$testing_type, "lik_ratio_bartlett_approx"); expect_equal(glog$calls[[1]]$bartlett_B, 42)
})

test_that("combined Bartlett interval mirrors the p-value routing", {
	f <- lk_fx(); log <- recorded(f); set_support(f, TRUE, FALSE)
	expect_silent(f$p$compute_lik_ratio_bartlett_confidence_interval_impl(0.05))
	expect_equal(log$calls[[1]]$testing_type, "lik_ratio_bartlett_exact")
	expect_warning(f$p$compute_lik_ratio_bartlett_confidence_interval_impl(0.05, B = 10, B_missing = FALSE), "B is ignored")
	g <- lk_fx(); glog <- recorded(g); set_support(g, FALSE, TRUE)
	g$p$compute_lik_ratio_bartlett_confidence_interval_impl(0.05, B = 33, B_missing = FALSE)
	expect_equal(glog$calls[[1]]$testing_type, "lik_ratio_bartlett_approx"); expect_equal(glog$calls[[1]]$bartlett_B, 33)
})

test_that("without any Bartlett support both combined entry points stop with the class name and the capability hints", {
	f <- lk_fx(); recorded(f); set_support(f, FALSE, FALSE)
	for (fn in list(function() f$p$compute_lik_ratio_bartlett_two_sided_pval_impl(0.1), function() f$p$compute_lik_ratio_bartlett_confidence_interval_impl(0.1))) {
		expect_error(fn(), "InferenceIncidLogRegr does not support Bartlett-corrected likelihood-ratio inference")
		expect_error(fn(), "supports_bartlett_likelihood_ratio_exact\\(\\) / supports_bartlett_likelihood_ratio_approx\\(\\)")
	}
	expect_warning(f$p$warn_bartlett_B_ignored_by_exact(), "InferenceIncidLogRegr has an exact Bartlett correction factor")
})
