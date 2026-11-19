library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-dce6a05a5 (InferenceSurvivalDepCensTransformRegr): beta_T, the
# second entry of beta_event, is the event-submodel log-time-ratio of the joint log-normal
# dependent-censoring model. Data simulated from that model with beta_T = 0.5 and rho = 0.5
# (about 45% censored) must give an estimate near 0.5 at large n.

test_that("the estimate recovers the true event-submodel log-time-ratio under correlated log-normal censoring", {
	set.seed(2)
	n <- 3000L
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	rho <- 0.5
	z_event <- rnorm(n)
	z_cens <- rho * z_event + sqrt(1 - rho^2) * rnorm(n)
	t_event <- exp(1 + 0.5 * w + 0.3 * x + 0.8 * z_event)
	t_cens <- exp(1.3 + 0.2 * x + 0.8 * z_cens)
	cens <- t_cens < t_event
	expect_gt(mean(cens), 0.3)
	des$add_all_subject_responses(ys = ifelse(cens, NA_real_, t_event),
		y_Ls = ifelse(cens, t_cens, NA_real_), y_Rs = ifelse(cens, Inf, NA_real_))
	inf <- InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
	est <- inf$compute_estimate()
	expect_true(is.finite(est))
	expect_lt(abs(est - 0.5), 0.1)
	# A naive log-normal AFT that treats censoring as independent is biased here; the joint model is not.
	naive <- survival::survreg(survival::Surv(ifelse(cens, t_cens, t_event), !cens) ~ w + x, dist = "lognormal")
	expect_lt(abs(est - 0.5), abs(unname(coef(naive)["w"]) - 0.5) + 0.1)
})
