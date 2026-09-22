library(testthat)
library(EDI)

# inference_incidence_gcomp_abstract.R's effects_are_usable(effects, estimate_only) and
# coefficients_are_usable(coef_hat) private predicates on the non-KK InferenceIncidGCompRiskDiff/
# RiskRatio classes -- the same two guards already have dedicated coverage on the KK sibling
# (InferenceIncidKKGCompRiskDiff/RiskRatio, test-kk-gcomp-incidence-weighted-estimate-fit-with-
# sandwich-and-usability-predicates-reference.R), but this non-KK abstract's own copy (a distinct
# definition, not shared code) had zero direct test references anywhere -- the only mention
# anywhere in the suite is a pair of explanatory comments in test-proportion-gcomp-sandwich-
# asymptotic-inference.R (a different, closed class) about why effects_are_usable() isn't
# reachable THERE, which doesn't exercise this predicate at all. Pure predicates, no
# bootstrap-worker interaction.

set.seed(1); n <- 20L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
w <- d$get_w()
d$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.8 * w)))
rd <- list(inf = InferenceIncidGCompRiskDiff$new(d, verbose = FALSE))
rd$p <- rd$inf$.__enclos_env__$private
rr <- list(inf = InferenceIncidGCompRiskRatio$new(d, verbose = FALSE))
rr$p <- rr$inf$.__enclos_env__$private

test_that("effects_are_usable: RD needs a finite estimate (and a positive finite SE for full inference); RR needs positive finite RR, log RR and SE", {
	e <- list(rd = 0.1, se_rd = 0.05, rr = 1.2, log_rr = log(1.2), se_log_rr = 0.1)
	expect_true(rd$p$effects_are_usable(e)); expect_true(rd$p$effects_are_usable(e, estimate_only = TRUE))
	expect_false(rd$p$effects_are_usable(modifyList(e, list(se_rd = 0)))); expect_true(rd$p$effects_are_usable(modifyList(e, list(se_rd = 0)), estimate_only = TRUE))
	expect_false(rd$p$effects_are_usable(modifyList(e, list(rd = NA_real_)), estimate_only = TRUE))
	expect_true(rr$p$effects_are_usable(e)); expect_true(rr$p$effects_are_usable(e, estimate_only = TRUE))
	expect_false(rr$p$effects_are_usable(modifyList(e, list(rr = 0)), estimate_only = TRUE))
	expect_false(rr$p$effects_are_usable(modifyList(e, list(rr = -1))))
	expect_false(rr$p$effects_are_usable(modifyList(e, list(se_log_rr = 0)))); expect_true(rr$p$effects_are_usable(modifyList(e, list(se_log_rr = 0)), estimate_only = TRUE))
	expect_false(rr$p$effects_are_usable(modifyList(e, list(log_rr = Inf))))
})

test_that("coefficients_are_usable: non-empty, finite, and within the maximum reasonable magnitude", {
	m <- rd$p$max_abs_reasonable_coef
	expect_true(rd$p$coefficients_are_usable(c(0.5, -2, m)))
	expect_false(rd$p$coefficients_are_usable(c(0.5, m * 1.01))); expect_false(rd$p$coefficients_are_usable(numeric(0)))
	expect_false(rd$p$coefficients_are_usable(c(1, NA))); expect_false(rd$p$coefficients_are_usable(c(1, Inf)))
})
