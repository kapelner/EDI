library(testthat)
library(EDI)

# InferenceIncidLogRegr private likelihood-test plumbing: get_likelihood_test_spec() (full fit, neg_loglik, score,
# information, fit_null with the treatment coefficient fixed) and simulate_under_lik_null(). Independent references:
# the direct Bernoulli log-likelihood, numDeriv, and stats::glm(offset = delta * treatment).

skip_if_not_installed("numDeriv")
set.seed(61); n <- 120L
des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
x <- rnorm(n)
des$add_all_subjects_to_experiment(data.frame(x = x))
des$overwrite_all_subject_assignments(rep(0:1, length.out = n))
w <- des$get_w()
des$add_all_subject_responses(rbinom(n, 1, plogis(-0.4 + 0.7 * w + 0.5 * x)))
mk <- function() {
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}
ref_ll <- function(b, X, y) { eta <- as.numeric(X %*% b); sum(y * eta - log1p(exp(eta))) }

test_that("spec neg_loglik, score and information match the Bernoulli log-likelihood, numDeriv and the glm MLE", {
	f <- mk(); sp <- f$p$get_likelihood_test_spec()
	expect_equal(sp$j, 2L)
	fit <- sp$full_fit; b <- as.numeric(fit$b)
	g <- glm(sp$y ~ sp$X - 1, family = binomial())
	expect_equal(b, unname(coef(g)), tolerance = 1e-4)
	expect_equal(sp$neg_loglik(fit), -ref_ll(b, sp$X, sp$y), tolerance = 1e-10)
	expect_equal(sp$neg_loglik(fit), -as.numeric(logLik(g)), tolerance = 1e-5)
	expect_equal(fit$neg_loglik, sp$neg_loglik(fit), tolerance = 1e-6)
	bp <- b + c(0.02, -0.03, 0.01)
	expect_equal(as.numeric(sp$score(list(b = bp))), numDeriv::grad(function(p) ref_ll(p, sp$X, sp$y), bp), tolerance = 1e-5)
	H <- numDeriv::hessian(function(p) ref_ll(p, sp$X, sp$y), b)
	expect_equal(unname(sp$observed_information(fit)), unname(-H), tolerance = 1e-4)
	expect_equal(sp$fisher_information(fit), sp$observed_information(fit))
	expect_equal(sp$information(fit), sp$observed_information(fit))
	expect_equal(sp$extract_start(fit), b)
})

test_that("fit_null(delta) equals the offset glm with the treatment coefficient fixed at delta", {
	f <- mk(); sp <- f$p$get_likelihood_test_spec()
	for (delta in c(0, 0.6, -0.8)) {
		nf <- sp$fit_null(delta)
		ref <- glm(sp$y ~ sp$X[, -2] - 1, offset = delta * sp$X[, 2], family = binomial())
		expect_equal(as.numeric(nf$b)[2], delta)
		expect_equal(as.numeric(nf$b)[-2], unname(coef(ref)), tolerance = 1e-4, info = as.character(delta))
		expect_equal(sp$neg_loglik(nf), -as.numeric(logLik(ref)), tolerance = 1e-5, info = as.character(delta))
	}
	nf0 <- sp$fit_null(0)
	lr <- 2 * (sp$neg_loglik(nf0) - sp$neg_loglik(sp$full_fit))
	expect_gte(lr, -1e-8)
})

test_that("simulate_under_lik_null draws a Bernoulli response from the null fit and returns usable refit closures", {
	f <- mk(); sp <- f$p$get_likelihood_test_spec()
	nf <- sp$fit_null(0)
	set.seed(3)
	bs <- f$p$simulate_under_lik_null(sp, 0, nf)
	expect_true(all(bs$worker_data$y %in% c(0, 1)))
	expect_length(bs$worker_data$y, n)
	expect_true(is.function(bs$fit_null)); expect_true(is.function(bs$neg_loglik))
	yb <- bs$worker_data$y
	g <- glm(yb ~ sp$X - 1, family = binomial())
	expect_equal(as.numeric(bs$full_fit$b), unname(coef(g)), tolerance = 1e-3)
	nb <- bs$fit_null(0)
	refn <- glm(yb ~ sp$X[, -2] - 1, offset = 0 * sp$X[, 2], family = binomial())
	expect_equal(as.numeric(nb$b)[-2], unname(coef(refn)), tolerance = 1e-3)
	expect_equal(bs$neg_loglik(bs$full_fit), -as.numeric(logLik(g)), tolerance = 1e-3)
	means <- replicate(200, mean(f$p$simulate_under_lik_null(sp, 0, nf)$worker_data$y))
	expect_equal(mean(means), mean(plogis(as.numeric(sp$X %*% as.numeric(nf$b)))), tolerance = 0.03)
})
