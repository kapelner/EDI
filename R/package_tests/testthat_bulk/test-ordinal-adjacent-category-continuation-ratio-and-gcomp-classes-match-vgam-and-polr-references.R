library(testthat)
library(EDI)

# More ordinal classes against independent fits: the adjacent-category logit class equals VGAM::vglm(acat,
# parallel, reverse = FALSE) (estimate and Wald interval), the continuation-ratio class equals
# VGAM::vglm(cratio, parallel) (estimate and interval), and the ordinal g-computation mean-difference class
# equals the standardized difference of expected category scores (1..K) from a proportional-odds fit.

skip_if_not_installed("VGAM")
skip_if_not_installed("MASS")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 200L
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	list(des = des, d = data.frame(y = factor(y, ordered = TRUE), w = w, x = x), x = x)
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)

test_that("adjacent-category logit class equals vglm(acat, parallel): estimate and interval", {
	f <- fx()
	fit <- VGAM::vglm(y ~ w + x, family = VGAM::acat(parallel = TRUE, reverse = FALSE), data = f$d)
	inf <- new_inf("InferenceOrdinalAdjCatLogitRegr", f$des)
	expect_equal(unname(inf$compute_estimate()), unname(VGAM::coef(fit)["w"]), tolerance = 1e-4)
	expect_equal(unname(inf$compute_asymp_confidence_interval(0.05)), unname(VGAM::confint(fit)["w", ]), tolerance = 5e-3, scale = 1)
})

test_that("continuation-ratio class equals vglm(cratio, parallel): estimate and interval", {
	f <- fx()
	fit <- VGAM::vglm(y ~ w + x, family = VGAM::cratio(parallel = TRUE), data = f$d)
	inf <- new_inf("InferenceOrdinalContRatioRegr", f$des)
	expect_equal(unname(inf$compute_estimate()), unname(VGAM::coef(fit)["w"]), tolerance = 1e-3)
	expect_equal(unname(inf$compute_asymp_confidence_interval(0.05)), unname(VGAM::confint(fit)["w", ]), tolerance = 1e-2, scale = 1)
})

test_that("g-computation mean-difference class equals the standardized difference of expected category scores", {
	f <- fx()
	po <- MASS::polr(y ~ w + x, data = f$d)
	p1 <- predict(po, data.frame(w = 1, x = f$x), type = "probs"); p0 <- predict(po, data.frame(w = 0, x = f$x), type = "probs")
	ref <- mean(p1 %*% 1:4) - mean(p0 %*% 1:4)
	inf <- new_inf("InferenceOrdinalGCompMeanDiff", f$des)
	expect_equal(unname(inf$compute_estimate()), ref, tolerance = 2e-3, scale = 1)
	ci <- unname(inf$compute_asymp_confidence_interval(0.05))
	expect_true(ci[1] < ref && ref < ci[2])
})

test_that("the acat and cratio estimates have the sign of the treatment effect and differ from proportional odds", {
	f <- fx()
	po <- unname(coef(MASS::polr(y ~ w + x, data = f$d))["w"])
	ac <- new_inf("InferenceOrdinalAdjCatLogitRegr", f$des)$compute_estimate()
	cr <- new_inf("InferenceOrdinalContRatioRegr", f$des)$compute_estimate()
	expect_true(ac > 0 && cr > 0 && po > 0)
	expect_gt(abs(ac - po), 0.05); expect_gt(abs(cr - po), 0.05)
})
