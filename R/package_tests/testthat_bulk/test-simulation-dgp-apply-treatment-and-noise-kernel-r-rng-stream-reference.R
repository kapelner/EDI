library(testthat)
library(EDI)

# apply_treatment_and_noise_cpp(y_linear_model, w, response_type, betaT, sd_noise, prob_censoring, n_ordinal_levels,
# phi_proportion, k_survival, clamps...): the simulation DGP kernel. It draws from R's own RNG stream, so each
# response type is reproduced EXACTLY by an R re-implementation that makes the same draws in the same order:
# continuous rnorm(n); incidence runif(n); proportion sequential rbeta; count sequential rpois; survival runif(n)
# for censoring then per subject rweibull(shape = exp(lin), scale = k) and censoring times runif(0, t); ordinal rnorm(n)
# rounded and clamped. Plus the treatment shift applying only to w == 1, clamps and argument validation.

K <- function(x) get(x, envir = asNamespace("EDI"))
call_dgp <- function(lin, w, type, betaT = 0.7, sd = 0.5, pc = 0.3, lev = 5L, phi = 10, k = 1.5, ...) {
	K("apply_treatment_and_noise_cpp")(lin, as.integer(w), type, betaT, sd, pc, as.integer(lev), phi, k, ...)
}
set.seed(1)
n <- 40L
lin <- rnorm(n, 0.2, 0.6)
w <- rep(0:1, length.out = n)
shift <- ifelse(w == 1, 0.7, 0)

test_that("continuous: y = linear predictor + treatment shift + Gaussian noise from R's rnorm stream", {
	set.seed(5); got <- call_dgp(lin, w, "continuous")
	set.seed(5); ref <- lin + shift + rnorm(n, 0, 0.5)
	expect_equal(got$y, ref, tolerance = 1e-12)
	expect_true(all(got$dead == 1L))
})

test_that("incidence: Bernoulli draws from runif against the clamped expit", {
	set.seed(5); got <- call_dgp(lin, w, "incidence")
	set.seed(5); u <- runif(n); p <- pmin(1 - 1e-9, pmax(1e-9, plogis(lin + shift)))
	expect_equal(got$y, as.numeric(u < p))
	# Extreme linear predictors are clamped, not errors.
	set.seed(6); ext <- call_dgp(rep(50, 10), rep(1L, 10), "incidence")
	expect_true(all(ext$y == 1))
})

test_that("proportion: sequential rbeta with mean expit(lin + shift) and precision phi", {
	set.seed(5); got <- call_dgp(lin, w, "proportion", phi = 10)
	set.seed(5); mu <- pmin(1 - 1e-9, pmax(1e-9, plogis(lin + shift)))
	ref <- vapply(seq_len(n), function(i) rbeta(1, mu[i] * 10, (1 - mu[i]) * 10), 0)
	expect_equal(got$y, ref, tolerance = 1e-12)
	expect_true(all(got$y > 0 & got$y < 1))
})

test_that("count: sequential rpois with mean exp(lin + shift), floored at count_clamp", {
	set.seed(5); got <- call_dgp(lin, w, "count")
	set.seed(5); ref <- vapply(seq_len(n), function(i) rpois(1, max(1e-9, exp(lin[i] + shift[i]))), 0)
	expect_equal(got$y, ref)
	expect_true(all(got$y == round(got$y)))
})

test_that("survival: uniform censoring draws first, then Weibull(shape = exp(lin + shift), scale = k) times, censored times uniform below", {
	set.seed(5); got <- call_dgp(lin, w, "survival", pc = 0.3, k = 1.5)
	set.seed(5)
	u <- runif(n); y <- numeric(n); dead <- rep(1L, n)
	for (i in seq_len(n)) {
		t_i <- rweibull(1, shape = max(1e-9, exp(lin[i] + shift[i])), scale = 1.5)
		if (u[i] < 0.3) { t_i <- runif(1, 0, t_i); dead[i] <- 0L }
		y[i] <- t_i
	}
	expect_equal(got$y, y, tolerance = 1e-12)
	expect_equal(got$dead, dead)
	expect_gt(sum(dead == 0L), 0L)
	# prob_censoring = 0 never censors, 1 always does.
	expect_true(all(call_dgp(lin, w, "survival", pc = 0)$dead == 1L))
	expect_true(all(call_dgp(lin, w, "survival", pc = 1)$dead == 0L))
})

test_that("ordinal: rounded Gaussian latent clamped to 1..n_ordinal_levels", {
	set.seed(5); got <- call_dgp(lin * 3 + 2, w, "ordinal", sd = 1, lev = 5L)
	set.seed(5); ref <- pmin(5, pmax(1, round((lin * 3 + 2) + shift + rnorm(n, 0, 1))))
	expect_equal(got$y, ref)
	expect_true(all(got$y >= 1 & got$y <= 5))
})

test_that("arguments are validated: lengths, unknown type, and non-positive / out-of-range parameters", {
	f <- K("apply_treatment_and_noise_cpp")
	expect_error(f(lin, w[-1], "continuous", 0.7, 0.5, 0.3, 5L, 10, 1.5), "same length")
	expect_error(f(lin, w, "bogus", 0.7, 0.5, 0.3, 5L, 10, 1.5), "unknown response_type 'bogus'")
	expect_error(f(lin, w, "proportion", 0.7, 0.5, 0.3, 5L, 0, 1.5), "phi_proportion must be finite and > 0")
	expect_error(f(lin, w, "survival", 0.7, 0.5, 0.3, 5L, 10, -1), "k_survival must be finite and > 0")
	expect_error(f(lin, w, "incidence", 0.7, 0.5, 0.3, 5L, 10, 1.5, 0.6), "incidence_clamp must be finite and in \\(0, 0.5\\)")
	expect_error(f(lin, w, "count", 0.7, 0.5, 0.3, 5L, 10, 1.5, 1e-9, 1e-9, 0), "count_clamp must be finite and > 0")
	expect_error(f(rep(1000, n), w, "count", 0.7, 0.5, 0.3, 5L, 10, 1.5), "count Poisson mean must be finite")
})
