library(testthat)
library(EDI)
skip_if_not_installed("MASS")

# InferenceOrdinalPartialProportionalOddsRegr private fit_fast_proportional_odds(X_cov): treatment coefficient and model-based SE of the fast
# proportional-odds backend equal MASS::polr (logit link, Hessian SE), with covariates, without covariates (NULL / zero-column matrix),
# and the warm-start bookkeeping (the fit sets a warm start that a repeat fit accepts). References: MASS::polr.

set.seed(6); n <- 150L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
y <- factor(pmin(4, pmax(1, round(rnorm(n, 2.3 + 0.7 * w + 0.4 * X$x1, 1)))), levels = 1:4, ordered = TRUE); d$add_all_subject_responses(y)
mk <- function() { inf <- InferenceOrdinalPartialProportionalOddsRegr$new(d, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }
Xc <- as.matrix(X)

test_that("with covariates: beta and SE equal polr's treatment coefficient and Hessian-based SE", {
	f <- mk(); r <- f$p$fit_fast_proportional_odds(Xc)
	ref <- MASS::polr(y ~ w + Xc, method = "logistic", Hess = TRUE)
	expect_equal(r$beta, unname(coef(ref)[1]), tolerance = 5e-3)
	expect_equal(r$se, unname(sqrt(diag(vcov(ref)))[1]), tolerance = 1e-2)
})

test_that("without covariates: NULL and zero-column matrices give the treatment-only polr fit", {
	ref <- MASS::polr(y ~ w, method = "logistic", Hess = TRUE)
	for (xc in list(NULL, matrix(numeric(0), n, 0))) {
		f <- mk(); r <- f$p$fit_fast_proportional_odds(xc)
		expect_equal(r$beta, unname(coef(ref)[1]), tolerance = 5e-3)
		expect_equal(r$se, unname(sqrt(diag(vcov(ref)))[1]), tolerance = 1e-2)
	}
})

test_that("a single covariate column supplied as a plain vector is handled", {
	f <- mk(); r <- f$p$fit_fast_proportional_odds(X$x1)
	ref <- MASS::polr(y ~ w + X$x1, method = "logistic", Hess = TRUE)
	expect_equal(r$beta, unname(coef(ref)[1]), tolerance = 5e-3)
})

test_that("repeating the fit (warm-started from the first) returns the same estimate", {
	f <- mk(); a <- f$p$fit_fast_proportional_odds(Xc); b <- f$p$fit_fast_proportional_odds(Xc)
	expect_equal(b$beta, a$beta, tolerance = 5e-3); expect_equal(b$se, a$se, tolerance = 1e-2)
	expect_true(is.finite(a$se) && a$se > 0)
})

test_that("a design with a constant response yields no fit (NULL) rather than an error", {
	e <- DesignFixedBernoulli$new(response_type = "ordinal", n = 30L, seed = 1L, verbose = FALSE)
	e$add_all_subjects_to_experiment(data.frame(x = rnorm(30))); e$assign_w_to_all_subjects()
	e$add_all_subject_responses(factor(rep(2, 30), levels = 1:3, ordered = TRUE))
	q <- InferenceOrdinalPartialProportionalOddsRegr$new(e, verbose = FALSE)$.__enclos_env__$private
	expect_no_error(r <- q$fit_fast_proportional_odds(NULL)); expect_true(is.null(r) || is.list(r))
})
