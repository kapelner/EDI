library(testthat)
library(EDI)

# apply_treatment_and_noise_cpp's "survival" branch (simulation_dgp.cpp) computes the Weibull shape
# as exp(y_linear_model[i] + treatment_shift) per subject and errors ("survival Weibull shape must
# be finite") if that overflows to a non-finite value, mirroring the already-tested sibling guard on
# the "count" branch's Poisson mean ("count Poisson mean must be finite"). The existing reference
# test (test-simulation-dgp-apply-treatment-and-noise-kernel-r-rng-stream-reference.R) exercises the
# count branch's guard but never the survival branch's identically-shaped one -- it had no test
# reference anywhere.

K <- function(x) get(x, envir = asNamespace("EDI"))
call_dgp <- function(lin, w, type, betaT = 0.7, sd = 0.5, pc = 0.3, lev = 5L, phi = 10, k = 1.5, ...) {
	K("apply_treatment_and_noise_cpp")(lin, as.integer(w), type, betaT, sd, pc, as.integer(lev), phi, k, ...)
}

test_that("a linear predictor that overflows exp() on the survival branch errors with the documented message", {
	n <- 40L
	w <- rep(0:1, length.out = n)
	expect_error(
		call_dgp(rep(1000, n), w, "survival"),
		"apply_treatment_and_noise_cpp: survival Weibull shape must be finite\\."
	)
	# a moderate linear predictor is unaffected
	set.seed(1)
	expect_no_error(call_dgp(rnorm(n, 0.2, 0.6), w, "survival"))
})
