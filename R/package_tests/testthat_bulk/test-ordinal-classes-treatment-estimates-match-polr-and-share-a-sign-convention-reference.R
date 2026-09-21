library(testthat)
library(EDI)

# Class-level ordinal treatment estimates against independent references: the cumulative-link classes
# (proportional odds, probit, cloglog, cauchit) equal MASS::polr's treatment coefficient (so all share the
# "positive effect => positive estimate" convention, including cloglog whose kernel negates internally),
# the proportional-odds Wald CI equals polr's confint.default, and the Jonckheere-Terpstra and control-
# reference ridit classes report the same number (U / (n1 n0) - 1/2), which also equals the direct
# pairwise-count statistic.

skip_if_not_installed("MASS")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 200L
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	list(des = des, w = w, y = y, X = data.frame(y = factor(y, ordered = TRUE), w = w))
}
new_inf <- function(cls, des, ...) get(cls, envir = asNamespace("EDI"))$new(des, verbose = FALSE, ...)

test_that("each cumulative-link class equals polr's treatment coefficient and has a positive sign for a positive effect", {
	f <- fx()
	specs <- list(
		list("InferenceOrdinalPropOddsRegr", "logistic", 5e-3),
		list("InferenceOrdinalOrderedProbitRegr", "probit", 5e-3),
		list("InferenceOrdinalCloglogRegr", "cloglog", 5e-3),
		list("InferenceOrdinalCauchitRegr", "cauchit", 2e-2))
	for (s in specs) {
		est <- new_inf(s[[1]], f$des)$compute_estimate()
		ref <- unname(coef(suppressWarnings(MASS::polr(y ~ w, data = f$X, method = s[[2]])))["w"])
		expect_gt(est, 0)
		expect_equal(est, ref, tolerance = s[[3]], info = s[[1]])
	}
})

test_that("the proportional-odds Wald interval equals polr's confint.default", {
	f <- fx()
	inf <- new_inf("InferenceOrdinalPropOddsRegr", f$des)
	pr <- suppressWarnings(MASS::polr(y ~ w, data = f$X, Hess = TRUE, method = "logistic"))
	expect_equal(unname(inf$compute_asymp_confidence_interval(0.05)), unname(confint.default(pr)["w", ]), tolerance = 5e-3)
})

test_that("the proportional-odds and partial-proportional-odds classes agree on a single-treatment model", {
	f <- fx()
	expect_equal(new_inf("InferenceOrdinalPartialProportionalOddsRegr", f$des)$compute_estimate(),
		new_inf("InferenceOrdinalPropOddsRegr", f$des)$compute_estimate(), tolerance = 1e-3)
})

test_that("Jonckheere-Terpstra and control-reference ridit report the same U / (n1 n0) - 1/2", {
	f <- fx()
	u <- sum(outer(f$y[f$w == 1], f$y[f$w == 0], ">")) + 0.5 * sum(outer(f$y[f$w == 1], f$y[f$w == 0], "=="))
	direct <- u / (sum(f$w == 1) * sum(f$w == 0)) - 0.5
	expect_equal(new_inf("InferenceOrdinalJonckheereTerpstraTest", f$des)$compute_estimate(), direct, tolerance = 1e-10)
	expect_equal(new_inf("InferenceOrdinalRidit", f$des, reference = "control")$compute_estimate(), direct, tolerance = 1e-10)
})

test_that("the probit scale is roughly the logit scale divided by 1.7, cloglog below it, cauchit above it", {
	f <- fx()
	lo <- new_inf("InferenceOrdinalPropOddsRegr", f$des)$compute_estimate()
	pr <- new_inf("InferenceOrdinalOrderedProbitRegr", f$des)$compute_estimate()
	cl <- new_inf("InferenceOrdinalCloglogRegr", f$des)$compute_estimate()
	ca <- new_inf("InferenceOrdinalCauchitRegr", f$des)$compute_estimate()
	expect_equal(pr * 1.7, lo, tolerance = 0.1)
	expect_lt(cl, lo); expect_lt(pr, lo)
	expect_gt(ca, pr)
})
