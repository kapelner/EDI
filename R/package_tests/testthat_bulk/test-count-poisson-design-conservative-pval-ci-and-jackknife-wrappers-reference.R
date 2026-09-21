library(testthat)
library(EDI)

# InferenceCountPoisson's design-conservative reporting: design_conservative_pval() = max(model p,
# jackknife-Wald p) and design_conservative_ci() = the union (min lower, max upper) of the model
# Wald CI and the jackknife CI, with NA handling; design_jackknife_pval()/_ci() swallow errors and
# invalid outputs. Then end to end: the public Wald p-value / CI equal the glm reference
# widened by the jackknife result (which is why they differ from plain glm inference).

fx <- function() {
	set.seed(11)
	n <- 100L
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rpois(n, exp(0.2 + 0.3 * w + 0.3 * X$x))
	des$add_all_subject_responses(y)
	inf <- InferenceCountPoisson$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	inf$set_estimand("conditional")
	list(inf = inf, p = inf$.__enclos_env__$private, y = y, w = w, x = X$x)
}
stub <- function(p, name, fn) { unlockBinding(name, p); p[[name]] <- fn }

test_that("conservative p-value is the larger of the model and jackknife p-values, falling back when one is missing", {
	f <- fx()
	cases <- list(list(0.03, 0.2, 0.2), list(0.4, 0.05, 0.4), list(0.1, NA_real_, 0.1), list(NA_real_, 0.07, 0.07), list(NA_real_, NA_real_, NA_real_))
	for (cs in cases) {
		stub(f$p, "design_jackknife_pval", local({ v <- cs[[2]]; function(delta = 0) v }))
		expect_equal(f$p$design_conservative_pval(cs[[1]]), cs[[3]])
	}
	stub(f$p, "design_jackknife_pval", function(delta = 0) 0.5)
	expect_equal(f$p$design_conservative_pval(c(0.2, 0.9)), 0.5)          # only the first model p is used
})

test_that("conservative CI is the union of the model and jackknife intervals, with labelled bounds", {
	f <- fx()
	stub(f$p, "design_jackknife_ci", function(alpha = 0.05) c(0.1, 0.9))
	ci <- f$p$design_conservative_ci(c(0.2, 1.2), alpha = 0.1)
	expect_equal(unname(ci), c(0.1, 1.2))
	expect_equal(names(ci), c("5%", "95%"))
	expect_equal(unname(f$p$design_conservative_ci(c(0.0, 0.5))), c(0.0, 0.9))
	stub(f$p, "design_jackknife_ci", function(alpha = 0.05) c(NA_real_, NA_real_))
	expect_equal(unname(f$p$design_conservative_ci(c(0.2, 1.2))), c(0.2, 1.2))
	stub(f$p, "design_jackknife_ci", function(alpha = 0.05) c(0.1, 0.9))
	expect_equal(unname(f$p$design_conservative_ci(c(NA_real_, 1.2))), c(0.1, 0.9))
	expect_equal(unname(f$p$design_conservative_ci(numeric(0))), c(0.1, 0.9))
	stub(f$p, "design_jackknife_ci", function(alpha = 0.05) c(NA_real_, NA_real_))
	expect_equal(unname(f$p$design_conservative_ci(c(NA_real_, NA_real_))), c(NA_real_, NA_real_))
})

test_that("the jackknife wrappers turn errors and out-of-range output into NA", {
	f <- fx()
	inf <- f$inf
	unlockBinding("compute_jackknife_wald_two_sided_pval", inf)
	unlockBinding("compute_jackknife_wald_confidence_interval", inf)
	inf$compute_jackknife_wald_two_sided_pval <- function(delta = 0) stop("no jackknife")
	inf$compute_jackknife_wald_confidence_interval <- function(alpha = 0.05) stop("no jackknife")
	expect_true(is.na(f$p$design_jackknife_pval(0)))
	expect_equal(f$p$design_jackknife_ci(0.05), c(NA_real_, NA_real_))
	inf$compute_jackknife_wald_two_sided_pval <- function(delta = 0) 1.5
	inf$compute_jackknife_wald_confidence_interval <- function(alpha = 0.05) c(2, 1)
	expect_true(is.na(f$p$design_jackknife_pval(0)))
	expect_equal(f$p$design_jackknife_ci(0.05), c(NA_real_, NA_real_))
	inf$compute_jackknife_wald_two_sided_pval <- function(delta = 0) 0.04
	inf$compute_jackknife_wald_confidence_interval <- function(alpha = 0.05) c(-1, 3, 99)
	expect_equal(f$p$design_jackknife_pval(0), 0.04)
	expect_equal(f$p$design_jackknife_ci(0.05), c(-1, 3))
})

test_that("end to end, the public Wald p-value and CI are the glm Wald result widened by the jackknife result", {
	f <- fx()
	g1 <- glm(f$y ~ f$w + f$x, family = poisson())
	s <- summary(g1)$coefficients[2, ]
	glm_p <- unname(s[4])
	glm_ci <- unname(s[1] + c(-1, 1) * qnorm(0.975) * s[2])
	f$inf$set_testing_type("wald")
	jp <- f$inf$compute_jackknife_wald_two_sided_pval(delta = 0)
	jci <- as.numeric(f$inf$compute_jackknife_wald_confidence_interval(alpha = 0.05))
	expect_equal(f$inf$compute_asymp_two_sided_pval(0), max(glm_p, jp), tolerance = 1e-4)
	expect_equal(unname(f$inf$compute_asymp_confidence_interval(0.05)), c(min(glm_ci[1], jci[1]), max(glm_ci[2], jci[2])), tolerance = 1e-4)
	# The conservative result is never narrower than plain glm inference.
	expect_gte(f$inf$compute_asymp_two_sided_pval(0), glm_p - 1e-6)
})
