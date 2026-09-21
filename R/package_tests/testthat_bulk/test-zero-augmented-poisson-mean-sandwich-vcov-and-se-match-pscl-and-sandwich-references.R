library(testthat)
library(EDI)
skip_if_not_installed("pscl"); skip_if_not_installed("sandwich")

# Zero-augmented Poisson private helpers: zero_augmented_poisson_mean_from_theta (ZIP mean (1-pi)*lambda; hurdle mean
# (1-pi) * lambda / (1 - exp(-lambda)) with pi = P(Y = 0)), zero_augmented_poisson_sandwich_vcov_full and
# zero_augmented_sandwich_se (HC0-type sandwich around the model-based bread). References: pscl::zeroinfl / pscl::hurdle
# predictions and sandwich::sandwich(). EDI's hurdle zero-part parameters model P(Y = 0), the negative of pscl's P(Y > 0)
# coefficients, so the reference parameters and covariance are sign-flipped on the zero block for the hurdle.

set.seed(4); n <- 200L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
zi <- rbinom(n, 1, plogis(-1 + 0.5 * X$x1)); y <- ifelse(zi == 1, 0L, rpois(n, exp(0.3 + 0.4 * w + 0.3 * X$x1)))
d$add_all_subject_responses(y)
inf <- InferenceCountZeroInflatedPoisson$new(d, verbose = FALSE); p <- inf$.__enclos_env__$private
Xc <- cbind(1, w, X$x1, X$x2); colnames(Xc) <- c("(Intercept)", "treatment", "x1", "x2")
dat <- data.frame(y, w, X)
zf <- pscl::zeroinfl(y ~ w + x1 + x2 | w + x1 + x2, data = dat, dist = "poisson")
hf <- pscl::hurdle(y ~ w + x1 + x2 | w + x1 + x2, data = dat, dist = "poisson")
D <- diag(c(rep(1, 4), rep(-1, 4)))
th_zi <- c(coef(zf, "count"), coef(zf, "zero")); V_zi <- unname(vcov(zf)); S_zi <- unname(sandwich::sandwich(zf))
th_h <- c(coef(hf, "count"), -coef(hf, "zero")); V_h <- unname(D %*% vcov(hf) %*% D); S_h <- unname(D %*% sandwich::sandwich(hf) %*% D)

test_that("ZIP and hurdle-Poisson means equal pscl's fitted responses", {
	expect_equal(p$zero_augmented_poisson_mean_from_theta(th_zi, Xc, Xc, FALSE), unname(predict(zf, type = "response")), tolerance = 1e-8)
	expect_equal(p$zero_augmented_poisson_mean_from_theta(th_h, Xc, Xc, TRUE), unname(predict(hf, type = "response")), tolerance = 1e-8)
})

test_that("mean formula pieces: no inflation gives the Poisson mean; a hurdle with pi = 0 gives the zero-truncated mean; large linear predictors are capped", {
	th0 <- c(0.2, 0.1, 0, 0, -50, 0, 0, 0)                                           # pi ~ 0
	lam <- exp(as.numeric(Xc %*% th0[1:4]))
	expect_equal(p$zero_augmented_poisson_mean_from_theta(th0, Xc, Xc, FALSE), lam, tolerance = 1e-9)
	expect_equal(p$zero_augmented_poisson_mean_from_theta(th0, Xc, Xc, TRUE), lam / (1 - exp(-lam)), tolerance = 1e-9)
	big <- c(1e6, 0, 0, 0, -50, 0, 0, 0)
	expect_true(all(is.finite(p$zero_augmented_poisson_mean_from_theta(big, Xc, Xc, FALSE))))
})

test_that("sandwich vcov equals sandwich::sandwich (ZIP directly; hurdle after the zero-block sign convention)", {
	v1 <- p$zero_augmented_poisson_sandwich_vcov_full(list(params = th_zi, vcov = V_zi), Xc, Xc, is_hurdle = FALSE)
	expect_equal(unname(v1), S_zi, tolerance = 1e-5)
	v2 <- p$zero_augmented_poisson_sandwich_vcov_full(list(params = th_h, vcov = V_h), Xc, Xc, is_hurdle = TRUE)
	expect_equal(unname(v2), S_h, tolerance = 1e-5)
})

test_that("treatment SE is the sqrt of the sandwich diagonal at j_treat; out-of-range j and unusable fits give NA", {
	fit <- list(params = th_zi, vcov = V_zi)
	expect_equal(p$zero_augmented_sandwich_se(fit, Xc, Xc, j_treat = 2L), sqrt(S_zi[2, 2]), tolerance = 1e-5)
	expect_equal(p$zero_augmented_sandwich_se(fit, Xc, Xc), sqrt(S_zi[2, 2]), tolerance = 1e-5)            # default j = 2
	expect_equal(p$zero_augmented_sandwich_se(list(params = th_h, vcov = V_h), Xc, Xc, 3L, is_hurdle = TRUE), sqrt(S_h[3, 3]), tolerance = 1e-5)
	expect_true(is.na(p$zero_augmented_sandwich_se(fit, Xc, Xc, j_treat = 0L)))
	expect_true(is.na(p$zero_augmented_sandwich_se(fit, Xc, Xc, j_treat = 9L)))
	expect_true(is.na(p$zero_augmented_sandwich_se(list(params = th_zi, vcov = V_zi[-1, -1]), Xc, Xc)))            # dimension mismatch
	bad <- th_zi; bad[3] <- NA; expect_true(is.na(p$zero_augmented_sandwich_se(list(params = bad, vcov = V_zi), Xc, Xc)))
	expect_true(is.na(p$zero_augmented_sandwich_se(list(params = th_zi, vcov = NULL), Xc, Xc)))
})

test_that("a degenerate model-based covariance is rejected and flagged", {
	V_bad <- V_zi; V_bad[2, 2] <- 0
	expect_null(p$zero_augmented_poisson_sandwich_vcov_full(list(params = th_zi, vcov = V_bad), Xc, Xc))
	expect_true(isTRUE(p$cached_values$fit_degenerate))
})
