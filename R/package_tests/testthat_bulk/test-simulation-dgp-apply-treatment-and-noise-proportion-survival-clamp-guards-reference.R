library(testthat)
library(EDI)

# apply_treatment_and_noise_cpp (simulation_dgp.cpp) validates 7 numeric arguments before generating
# any response. test-simulation-dgp-apply-treatment-and-noise-kernel-r-rng-stream-reference.R already
# covers 5 of them (the y_linear_model/w length mismatch, unknown response_type, phi_proportion,
# k_survival, and incidence_clamp guards), but never exercises the two remaining guards: `if
# (!isfinite(proportion_clamp) || proportion_clamp <= 0 || proportion_clamp >= 0.5) stop(
# "apply_treatment_and_noise_cpp: proportion_clamp must be finite and in (0, 0.5).")` and `if
# (!isfinite(survival_clamp) || survival_clamp <= 0) stop("apply_treatment_and_noise_cpp:
# survival_clamp must be finite and > 0.")`. Confirmed via grep to have no test reference anywhere.

f <- get("apply_treatment_and_noise_cpp", envir = asNamespace("EDI"))
n <- 20L
set.seed(1); lin <- rnorm(n)
w <- rep(0:1, length.out = n)

test_that("proportion_clamp outside (0, 0.5) throws the proportion_clamp validity error", {
	expect_error(
		f(lin, w, "proportion", 0.7, 0.5, 0.3, 5L, 10, 1.5, 1e-9, 0.6),
		"proportion_clamp must be finite and in \\(0, 0.5\\)"
	)
	expect_error(
		f(lin, w, "proportion", 0.7, 0.5, 0.3, 5L, 10, 1.5, 1e-9, 0),
		"proportion_clamp must be finite and in \\(0, 0.5\\)"
	)
})

test_that("a non-positive survival_clamp throws the survival_clamp validity error", {
	expect_error(
		f(lin, w, "survival", 0.7, 0.5, 0.3, 5L, 10, 1.5, 1e-9, 1e-9, 1e-9, 0),
		"survival_clamp must be finite and > 0"
	)
	expect_error(
		f(lin, w, "survival", 0.7, 0.5, 0.3, 5L, 10, 1.5, 1e-9, 1e-9, 1e-9, -1),
		"survival_clamp must be finite and > 0"
	)
})

test_that("well-formed clamp arguments do not trigger either guard", {
	out <- f(lin, w, "proportion", 0.7, 0.5, 0.3, 5L, 10, 1.5, 1e-9, 1e-9)
	expect_true(all(is.finite(out$y)))
	out2 <- f(lin, w, "survival", 0.7, 0.5, 0.3, 5L, 10, 1.5, 1e-9, 1e-9, 1e-9, 1e-9)
	expect_true(all(is.finite(out2$y)))
})
