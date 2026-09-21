library(testthat)
library(EDI)
skip_if_not_installed("sandwich")

# InferenceCountRobustPoisson private fit_count_model_with_var(X, estimate_only): Poisson MLE with the HC0 sandwich variance of the treatment
# coefficient; rank-deficient columns are dropped (their coefficient reported NA, names kept), too-small designs return NA lists.
# References: stats::glm(poisson) coefficients and sandwich::vcovHC(type = "HC0").

set.seed(3); n <- 100L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
y <- rpois(n, exp(0.2 + 0.4 * w + 0.3 * X$x1)); d$add_all_subject_responses(y)
mk <- function() { inf <- InferenceCountRobustPoisson$new(d, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }
f <- mk(); Xd <- f$p$build_design_matrix()
ref <- glm(y ~ w + x1 + x2, data = data.frame(y, w, X), family = poisson)

test_that("coefficients equal the Poisson MLE and the treatment variance is the HC0 sandwich entry", {
	r <- mk()$p$fit_count_model_with_var(Xd)
	expect_equal(unname(r$b), unname(coef(ref)), tolerance = 1e-6)
	expect_identical(names(r$b), colnames(Xd)); expect_identical(r$j_treat, 2L)
	expect_equal(r$ssq_b_2, unname(sandwich::vcovHC(ref, type = "HC0")[2, 2]), tolerance = 1e-5)
	expect_true(all(c("mod", "XtWX", "X_fit") %in% names(r)))
})

test_that("class estimate and Wald SE come from this fit", {
	g <- mk()
	expect_equal(unname(g$inf$compute_estimate()), unname(coef(ref)[2]), tolerance = 1e-6)
	expect_equal(g$p$get_standard_error(), sqrt(unname(sandwich::vcovHC(ref, type = "HC0")[2, 2])), tolerance = 1e-5)
})

test_that("estimate-only mode skips the variance", {
	r <- mk()$p$fit_count_model_with_var(Xd, estimate_only = TRUE)
	expect_equal(unname(r$b), unname(coef(ref)), tolerance = 1e-6); expect_true(is.na(r$ssq_b_2))
})

test_that("a duplicated covariate is dropped: its coefficient is NA, the rest match the reduced glm, names retained", {
	Xdup <- cbind(Xd, dup = Xd[, "x1"])
	r <- mk()$p$fit_count_model_with_var(Xdup)
	expect_identical(names(r$b), colnames(Xdup))
	expect_equal(sum(is.na(r$b)), 1L)
	kept <- !is.na(r$b)
	expect_equal(unname(r$b[kept][1:4]), unname(coef(ref)), tolerance = 1e-5)
	expect_equal(r$ssq_b_2, unname(sandwich::vcovHC(ref, type = "HC0")[2, 2]), tolerance = 1e-4)
})

test_that("a design with no more rows than columns returns an all-NA coefficient vector and NA variance", {
	r <- mk()$p$fit_count_model_with_var(Xd[1:3, ])
	expect_true(all(is.na(r$b))); expect_true(is.na(r$ssq_b_2)); expect_length(r$b, ncol(Xd))
})
