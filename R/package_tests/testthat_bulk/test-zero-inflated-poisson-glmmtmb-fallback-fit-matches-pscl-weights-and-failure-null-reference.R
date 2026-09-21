library(testthat)
library(EDI)
skip_if_not_installed("glmmTMB"); skip_if_not_installed("pscl")

# InferenceCountZeroInflatedPoisson private fit_zero_augmented_model(dat, X_fit, Xzi_fit, weights) (the glmmTMB fallback fit) and za_family():
# conditional and zero-inflation coefficients equal pscl::zeroinfl; prior weights are honoured (weight 2 on every row leaves the MLE
# unchanged); failures return NULL. References: pscl::zeroinfl.

set.seed(4); n <- 200L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
zi <- rbinom(n, 1, plogis(-1 + 0.5 * X$x1)); y <- ifelse(zi == 1, 0L, rpois(n, exp(0.3 + 0.4 * w + 0.3 * X$x1))); d$add_all_subject_responses(y)
inf <- InferenceCountZeroInflatedPoisson$new(d, verbose = FALSE); p <- inf$.__enclos_env__$private
Xc <- cbind(1, w, X$x1, X$x2); colnames(Xc) <- c("(Intercept)", "w", "x1", "x2")
dat <- data.frame(y = y, w = w, x1 = X$x1, x2 = X$x2)
zf <- pscl::zeroinfl(y ~ w + x1 + x2 | w + x1 + x2, data = dat)

test_that("the model family is Poisson with a log link", {
	fam <- p$za_family()
	expect_identical(fam$family, "poisson"); expect_identical(fam$link, "log")
})

test_that("conditional and zero-inflation coefficients equal zeroinfl's", {
	m <- p$fit_zero_augmented_model(dat, Xc, Xc)
	expect_s3_class(m, "glmmTMB")
	fx <- glmmTMB::fixef(m)
	expect_equal(unname(fx$cond), unname(coef(zf, "count")), tolerance = 1e-3)
	expect_equal(unname(fx$zi), unname(coef(zf, "zero")), tolerance = 1e-3)
	expect_identical(names(fx$cond), c("(Intercept)", "w", "x1", "x2"))
})

test_that("a smaller covariate set in the zero-inflation part is respected", {
	Xzi <- Xc[, c("(Intercept)", "w"), drop = FALSE]
	m <- p$fit_zero_augmented_model(dat, Xc, Xzi)
	zf2 <- pscl::zeroinfl(y ~ w + x1 + x2 | w, data = dat)
	expect_equal(unname(glmmTMB::fixef(m)$cond), unname(coef(zf2, "count")), tolerance = 1e-3)
	expect_length(glmmTMB::fixef(m)$zi, 2L)
})

test_that("uniform prior weights leave the estimates unchanged; unequal weights change them", {
	base <- glmmTMB::fixef(p$fit_zero_augmented_model(dat, Xc, Xc))$cond
	w2 <- glmmTMB::fixef(p$fit_zero_augmented_model(dat, Xc, Xc, weights = rep(2, n)))$cond
	expect_equal(unname(w2), unname(base), tolerance = 1e-3)
	set.seed(9); rw <- runif(n, 0.2, 3)
	wv <- glmmTMB::fixef(p$fit_zero_augmented_model(dat, Xc, Xc, weights = rw))$cond
	expect_gt(max(abs(wv - base)), 1e-3)
})

test_that("fit failures return NULL: missing data columns, mismatched frames", {
	expect_null(p$fit_zero_augmented_model(dat[, c("y", "w")], Xc, Xc))
	expect_null(p$fit_zero_augmented_model(dat[1:5, ], Xc, Xc, weights = rep(1, 3)))
})
