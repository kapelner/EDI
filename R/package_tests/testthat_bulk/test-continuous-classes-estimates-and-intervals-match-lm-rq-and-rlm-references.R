library(testthat)
library(EDI)

# Class-level continuous results against independent fits: OLS equals lm (estimate and confint), the Lin
# regression-adjusted class equals OLS to 1e-4 on a randomized design, the quantile-regression class equals
# quantreg::rq(tau = 0.5) (estimate exactly; interval close to rq's nid-based interval), and the robust class
# equals MASS::rlm for method "M" and "MM" when use_rcpp = FALSE (and within 0.5% for the C++ backend).

skip_if_not_installed("quantreg")
skip_if_not_installed("MASS")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 200L
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- 1 + 0.6 * w + 0.5 * x + rt(n, 4)
	des$add_all_subject_responses(y)
	list(des = des, d = data.frame(y = y, w = w, x = x))
}

test_that("OLS class equals lm's treatment coefficient and confidence interval", {
	f <- fx()
	m <- lm(y ~ w + x, data = f$d)
	inf <- K("InferenceContinOLS")$new(f$des, verbose = FALSE)
	expect_equal(unname(inf$compute_estimate()), unname(coef(m)["w"]), tolerance = 1e-10)
	expect_equal(unname(inf$compute_asymp_confidence_interval(0.05)), unname(confint(m)["w", ]), tolerance = 1e-6)
	expect_equal(inf$compute_asymp_two_sided_pval(0), unname(summary(m)$coefficients["w", 4]), tolerance = 1e-6)
})

test_that("Lin's adjusted estimator agrees with OLS on a randomized design (to a small interaction adjustment)", {
	f <- fx()
	expect_equal(unname(K("InferenceContinLin")$new(f$des, verbose = FALSE)$compute_estimate()),
		unname(coef(lm(y ~ w + x, data = f$d))["w"]), tolerance = 1e-3)
})

test_that("quantile-regression class equals rq's median-regression treatment coefficient, with a nearby interval", {
	f <- fx()
	qr <- suppressWarnings(quantreg::rq(y ~ w + x, tau = 0.5, data = f$d))
	inf <- K("InferenceContinQuantileRegr")$new(f$des, verbose = FALSE)
	expect_equal(unname(inf$compute_estimate()), unname(coef(qr)["w"]), tolerance = 1e-6)
	se <- suppressWarnings(summary(qr, se = "nid"))$coefficients["w", 2]
	ref <- unname(coef(qr)["w"]) + c(-1, 1) * qnorm(0.975) * se
	expect_equal(unname(inf$compute_asymp_confidence_interval(0.05)), ref, tolerance = 0.02, scale = 1)
})

test_that("robust class equals MASS::rlm for M and MM (use_rcpp = FALSE), and the C++ backend is within 0.5%", {
	f <- fx()
	for (mt in c("M", "MM")) {
		ref <- unname(coef(MASS::rlm(y ~ w + x, data = f$d, method = mt))["w"])
		slow <- K("InferenceContinRobustRegr")$new(f$des, method = mt, use_rcpp = FALSE, verbose = FALSE)
		fast <- K("InferenceContinRobustRegr")$new(f$des, method = mt, use_rcpp = TRUE, verbose = FALSE)
		expect_equal(unname(slow$compute_estimate()), ref, tolerance = 1e-5, info = mt)
		expect_equal(unname(fast$compute_estimate()), ref, tolerance = 5e-3, scale = 1, info = mt)
	}
	# The Huber (M) and bisquare (MM) fits differ on this heavy-tailed sample.
	m <- unname(coef(MASS::rlm(y ~ w + x, data = f$d, method = "M"))["w"]); mm <- unname(coef(MASS::rlm(y ~ w + x, data = f$d, method = "MM"))["w"])
	expect_gt(abs(mm - m), 0.02)
})
