library(testthat)
library(EDI)

# docs-claims audit, findings:
#   docs-claims-d46172b75 (InferenceOrdinalPropOddsRegr: ordinal-only; score/gradient/LR tests)
#   docs-claims-d69d3b3a4 (InferenceOrdinalAdjCatLogitRegr: score/gradient/LR tests)
#   docs-claims-da57b3793 (InferenceOrdinalOrderedProbitRegr: LR/score/gradient/Wald; weighted probit surrogate)
#   docs-claims-daebe20f7 (InferenceOrdinalCauchitRegr: LR/score/gradient; Bayesian bootstrap available)
#   docs-claims-dfedba9a5 (InferenceOrdinalCloglogRegr: LR/score/gradient; Bayesian bootstrap available)
# The existing smoke helpers skip any testing type that is not advertised, so these assert that
# the types ARE advertised and that each public p-value / CI is valid on a well-behaved fixture.

lik_ord_fixture <- function(seed = 7L, n = 120L) {
	set.seed(seed)
	x1 <- rnorm(n)
	trt <- rep(0:1, n / 2L)
	y <- as.integer(cut(qlogis(runif(n)) + 0.8 * trt + 0.5 * x1, c(-Inf, -1, 0, 1, Inf)))
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(trt)
	des$add_all_subject_responses(y)
	list(des = des, x1 = x1, trt = trt, y = y)
}

expect_score_gradient_lr_available <- function(inf, label) {
	types <- inf$get_supported_testing_types()
	expect_true(all(c("wald", "score", "gradient", "lik_ratio") %in% types), info = label)
	pvals <- c(
		score = inf$compute_score_two_sided_pval(delta = 0),
		gradient = inf$compute_gradient_two_sided_pval(delta = 0),
		lik_ratio = inf$compute_lik_ratio_two_sided_pval(delta = 0),
		wald = inf$compute_wald_two_sided_pval(delta = 0)
	)
	expect_true(all(is.finite(pvals) & pvals >= 0 & pvals <= 1), info = label)
	invisible(pvals)
}

polr_lr_pval <- function(f, method) {
	full <- MASS::polr(ordered(f$y) ~ f$trt + f$x1, method = method)
	null <- MASS::polr(ordered(f$y) ~ f$x1, method = method)
	pchisq(2 * (as.numeric(logLik(full)) - as.numeric(logLik(null))), df = 1, lower.tail = FALSE)
}

test_that("PropOdds rejects a non-ordinal design", {
	set.seed(5)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, n / 2L))
	des$add_all_subject_responses(rnorm(n))
	expect_error(InferenceOrdinalPropOddsRegr$new(des, verbose = FALSE), "ordinal")
})

test_that("PropOdds advertises score/gradient/LR tests and its LR p-value matches the polr LR test", {
	f <- lik_ord_fixture()
	inf <- InferenceOrdinalPropOddsRegr$new(f$des, verbose = FALSE)
	pv <- expect_score_gradient_lr_available(inf, "PropOdds")
	expect_equal(unname(pv["lik_ratio"]), polr_lr_pval(f, "logistic"), tolerance = 1e-4)
})

test_that("AdjCat advertises score/gradient/LR tests with valid p-values and ordered finite CIs", {
	f <- lik_ord_fixture()
	inf <- InferenceOrdinalAdjCatLogitRegr$new(f$des, verbose = FALSE)
	expect_score_gradient_lr_available(inf, "AdjCat")
	for (ci in list(inf$compute_lik_ratio_confidence_interval(alpha = 0.05),
		inf$compute_score_confidence_interval(alpha = 0.05),
		inf$compute_gradient_confidence_interval(alpha = 0.05))) {
		expect_length(ci, 2L)
		expect_true(all(is.finite(ci)) && ci[1] < ci[2])
	}
})

test_that("OrderedProbit advertises LR/score/gradient/Wald tests and its LR p-value matches polr(probit)", {
	f <- lik_ord_fixture()
	inf <- InferenceOrdinalOrderedProbitRegr$new(f$des, verbose = FALSE)
	pv <- expect_score_gradient_lr_available(inf, "OrderedProbit")
	expect_equal(unname(pv["lik_ratio"]), polr_lr_pval(f, "probit"), tolerance = 1e-4)
})

test_that("OrderedProbit weighted bootstrap estimate tracks a weighted polr(probit) fit, NA SE, NA on surrogate failure", {
	f <- lik_ord_fixture()
	inf <- InferenceOrdinalOrderedProbitRegr$new(f$des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	inf$compute_estimate()
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	set.seed(3)
	wts <- rexp(length(f$y)) + 0.1
	got <- inf$compute_estimate_with_bootstrap_weights(wts)
	ref <- suppressWarnings(MASS::polr(ordered(f$y) ~ f$trt + f$x1, weights = wts / mean(wts), method = "probit"))
	expect_equal(got, unname(coef(ref)[1]), tolerance = 1e-3)
	expect_true(is.na(p$last_weighted_refit$s_beta_hat_T))

	local_mocked_bindings(weighted_ordinal_bootstrap_surrogate_fit = function(...) NULL, .package = "EDI")
	expect_true(is.na(inf$compute_estimate_with_bootstrap_weights(wts)))
	expect_true(is.na(p$last_weighted_refit$s_beta_hat_T))
})

test_that("Cauchit advertises LR/score/gradient tests and runs the public Bayesian bootstrap", {
	f <- lik_ord_fixture()
	inf <- InferenceOrdinalCauchitRegr$new(f$des, verbose = FALSE)
	expect_score_gradient_lr_available(inf, "Cauchit")
	expect_true(inf$supports("bayesian_bootstrap")[["bayesian_bootstrap"]])
	set.seed(1)
	pv <- inf$compute_bayesian_bootstrap_two_sided_pval(B = 19, show_progress = FALSE)
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
})

test_that("Cloglog advertises LR/score/gradient tests and runs the public Bayesian bootstrap CI", {
	f <- lik_ord_fixture()
	inf <- InferenceOrdinalCloglogRegr$new(f$des, verbose = FALSE)
	expect_score_gradient_lr_available(inf, "Cloglog")
	expect_true(inf$supports("bayesian_bootstrap")[["bayesian_bootstrap"]])
	set.seed(2)
	ci <- inf$compute_bayesian_bootstrap_confidence_interval(alpha = 0.1, B = 19, show_progress = FALSE)
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)) && ci[1] <= ci[2])
})
