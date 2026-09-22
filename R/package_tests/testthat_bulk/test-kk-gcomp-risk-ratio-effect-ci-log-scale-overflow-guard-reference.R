library(testthat)
library(EDI)

# InferenceIncidKKGCompRiskRatio's compute_effect_confidence_interval() (inherited from
# inference_incidence_KK_gcomp_abstract.R's shared IncidenceKKGComputation component): after
# computing the log-risk-ratio delta-method Wald interval on the log scale (log_rr +/- z*se_log_rr),
# it back-transforms via exp() and explicitly checks the result is finite -- an extreme log-scale
# bound can exponentiate to Inf, caught and converted into an explicit error rather than silently
# returning an infinite/degenerate CI. This is the KK sibling of the already-tested non-KK
# InferenceIncidGCompRiskRatio overflow guard (test-incid-gcomp-risk-ratio-effect-ci-log-scale-
# overflow-guard-reference.R) -- same shape, distinct message ("KK g-computation RR: ..." vs.
# "G-computation RR: ..."), had zero test references anywhere.

rr_fx <- function(seed = 3L, n = 40L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w <- rep(c(0, 1), n / 2L)
	des$overwrite_all_subject_assignments(w)
	y <- rbinom(n, 1, plogis(-0.6 + 0.7 * w + 0.4 * x))
	des$add_all_subject_responses(y)
	InferenceIncidKKGCompRiskRatio$new(des, model_formula = ~ x, verbose = FALSE)
}

test_that("an extreme log-scale bound that exponentiates to Inf is caught and errors with the documented message", {
	inf <- rr_fx()
	p <- inf$.__enclos_env__$private
	p$cached_values$log_rr <- 1000
	p$cached_values$se_log_rr <- 50
	expect_error(
		p$compute_effect_confidence_interval(0.05),
		"KK g-computation RR: could not compute a finite delta-method confidence interval\\."
	)
})

test_that("a moderate log-scale bound does not trip the overflow guard and matches the hand-computed exp(Wald) interval", {
	inf <- rr_fx()
	p <- inf$.__enclos_env__$private
	p$cached_values$log_rr <- 0.3
	p$cached_values$se_log_rr <- 0.2
	ci <- p$compute_effect_confidence_interval(0.05)
	z <- qnorm(0.975)
	ref <- exp(0.3 + c(-1, 1) * z * 0.2)
	expect_equal(as.numeric(ci), ref, tolerance = 1e-10)
	expect_equal(names(ci), c("2.5%", "97.5%"))
})

test_that("the earlier non-finite-input short-circuit (distinct from the overflow guard) still returns NA without erroring", {
	inf <- rr_fx()
	p <- inf$.__enclos_env__$private
	p$cached_values$log_rr <- NA_real_
	p$cached_values$se_log_rr <- 0.2
	ci <- p$compute_effect_confidence_interval(0.05)
	expect_true(all(is.na(ci)))

	inf2 <- rr_fx()
	p2 <- inf2$.__enclos_env__$private
	p2$cached_values$log_rr <- 0.3
	p2$cached_values$se_log_rr <- 0
	ci2 <- p2$compute_effect_confidence_interval(0.05)
	expect_true(all(is.na(ci2)))
})
