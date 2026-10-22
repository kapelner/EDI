library(testthat)
library(EDI)

# TODO-121 (second batch): compute_asymp_two_sided_pval() / compute_asymp_confidence_interval()
# on InferenceSurvivalKKLWACoxPHOneLik, InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik,
# InferenceContinKKGLMM, InferenceIncidKKCondLogitGLMMOneLik and InferencePropKKGLMM ignored
# get_testing_type() and always returned the Wald value (score / LR / gradient labels were
# decoration). InferenceCountKKGLMM dispatched only lik_ratio (score / gradient fell to Wald)
# and its Poisson-GLMM score test used the NEGATIVE of the information matrix.

make_t121b = function(response_type, formula, kk14 = FALSE, n = 40L, seed = 2L) {
	set.seed(seed)
	x1 = rnorm(n)
	if (!kk14) {
		des = DesignFixedBinaryMatch$new(
			response_type = response_type, n = n, m = rep(seq_len(n / 2L), each = 2L),
			design_formula = formula, verbose = FALSE
		)
		des$add_all_subjects_to_experiment(data.frame(x1 = x1))
		w = as.vector(replicate(n / 2L, sample(0:1)))
		des$assign_w_to_all_subjects(w)
	} else {
		des = DesignSeqOneByOneKK14$new(response_type = response_type, n = n, design_formula = formula, verbose = FALSE)
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
		w = des$get_w()
	}
	g = rep(rnorm(n / 2L, 0, 0.3), each = 2L)
	y = switch(response_type,
		count = rpois(n, exp(0.5 + 0.4 * w + g)),
		survival = rexp(n, exp(-(0.4 * w + g))),
		continuous = rnorm(n, 0.4 * w + g),
		proportion = pmin(pmax(plogis(0.4 * w + g + rnorm(n, 0, 0.3)), 0.02), 0.98),
		incidence = rbinom(n, 1, plogis(0.4 * w + g)))
	if (!kk14) des$add_all_subject_responses(y) else for (i in seq_len(n)) des$add_one_subject_response(i, y[i])
	list(des = des, d = data.frame(y = y, w = w, m = rep(seq_len(n / 2L), each = 2L), x1 = x1))
}

pvals_by_type = function(inf, delta = 0, types = c("wald", "score", "lik_ratio", "gradient")) {
	vapply(types, function(tt) {
		inf$set_testing_type(tt)
		suppressWarnings(inf$compute_asymp_two_sided_pval(delta))
	}, numeric(1))
}

expect_lik_tests_not_wald = function(p, types = c("score", "lik_ratio", "gradient"), ballpark = 0.25) {
	for (tt in types) {
		expect_true(is.finite(p[[tt]]), info = tt)
		expect_gt(abs(p[[tt]] - p[["wald"]]), 1e-6)
		expect_lt(abs(p[[tt]] - p[["wald"]]), ballpark)
	}
}

test_that("KKLWACoxPHOneLik honors score / lik_ratio / gradient and matches coxph (Breslow), incl. ~1", {
	skip_if_not_installed("survival")
	suppressMessages(library(survival))
	for (with_cov in c(FALSE, TRUE)) {
		s = make_t121b("survival", if (with_cov) ~ x1 else ~ 1)
		cx = coxph(if (with_cov) Surv(y, rep(1, length(y))) ~ w + x1 else Surv(y, rep(1, length(y))) ~ w,
			data = s$d, ties = "breslow")
		inf = InferenceSurvivalKKLWACoxPHOneLik$new(s$des, verbose = FALSE)
		expect_equal(inf$compute_estimate(), unname(coef(cx)["w"]), tolerance = 1e-4)
		p = pvals_by_type(inf)
		expect_true(all(is.finite(p)))
		expect_gt(abs(p[["score"]] - p[["wald"]]), 1e-5)
		expect_gt(abs(p[["lik_ratio"]] - p[["wald"]]), 1e-5)
		if (!with_cov) {
			# beta_T the only parameter: the null fit is the fixed point (was NA)
			expect_equal(p[["score"]], unname(summary(cx)$sctest["pvalue"]), tolerance = 1e-4)
			expect_equal(p[["lik_ratio"]], unname(summary(cx)$logtest["pvalue"]), tolerance = 1e-4)
		} else {
			cx0 = coxph(Surv(y, rep(1, length(y))) ~ x1 + offset(0 * w), data = s$d, ties = "breslow")
			expect_equal(p[["lik_ratio"]], pchisq(2 * (cx$loglik[2] - tail(cx0$loglik, 1L)), 1, lower.tail = FALSE), tolerance = 1e-4)
		}
		inf$set_testing_type("wald"); ci_w = inf$compute_asymp_confidence_interval()
		inf$set_testing_type("lik_ratio"); ci_l = inf$compute_asymp_confidence_interval()
		expect_true(all(is.finite(ci_l)))
		expect_gt(max(abs(ci_l - ci_w)), 1e-4)
		expect_lt(ci_l[[1L]], inf$compute_estimate()); expect_gt(ci_l[[2L]], inf$compute_estimate())
		inf$set_testing_type("wald")
		expect_equal(inf$compute_asymp_two_sided_pval(0), p[["wald"]])
	}
})

test_that("Loggamma-frailty OneLik honors score / lik_ratio / gradient (pairs + reservoir and all-matched)", {
	for (spec in list(list(~ x1, TRUE), list(~ 1, FALSE))) {
		s = make_t121b("survival", spec[[1L]], kk14 = spec[[2L]])
		inf = InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(s$des, verbose = FALSE)
		inf$compute_estimate()
		expect_lik_tests_not_wald(pvals_by_type(inf))
	}
})

test_that("ContinKKGLMM honors score / lik_ratio / gradient; LR matches glmmTMB ML; CI dispatches", {
	skip_if_not_installed("glmmTMB")
	s = make_t121b("continuous", ~ x1)
	inf = InferenceContinKKGLMM$new(s$des, verbose = FALSE)
	inf$compute_estimate()
	p = pvals_by_type(inf)
	expect_lik_tests_not_wald(p)
	m1 = glmmTMB::glmmTMB(y ~ w + x1 + (1 | m), data = s$d, REML = FALSE)
	m0 = glmmTMB::glmmTMB(y ~ x1 + (1 | m), data = s$d, REML = FALSE)
	lr = as.numeric(2 * (logLik(m1) - logLik(m0)))
	expect_equal(p[["lik_ratio"]], pchisq(lr, 1, lower.tail = FALSE), tolerance = 0.05)
	expect_equal(p[["score"]], pchisq(lr, 1, lower.tail = FALSE), tolerance = 0.25)
	inf$set_testing_type("wald"); ci_w = inf$compute_asymp_confidence_interval()
	inf$set_testing_type("lik_ratio"); ci_l = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci_l)))
	expect_gt(max(abs(ci_l - ci_w)), 1e-5)
	# pairs + reservoir
	s2 = make_t121b("continuous", ~ x1, kk14 = TRUE)
	inf2 = InferenceContinKKGLMM$new(s2$des, verbose = FALSE); inf2$compute_estimate()
	expect_lik_tests_not_wald(pvals_by_type(inf2))
})

test_that("InferenceAbstractKKCondLogitGLMM leaves (Incid OneLik, Prop) honor score / lik_ratio / gradient", {
	for (cl in list(list(InferenceIncidKKCondLogitGLMMOneLik, "incidence"), list(InferencePropKKGLMM, "proportion"))) {
		for (kk14 in c(FALSE, TRUE)) {
			s = make_t121b(cl[[2L]], ~ x1, kk14 = kk14)
			inf = cl[[1L]]$new(s$des, verbose = FALSE)
			inf$compute_estimate()
			expect_lik_tests_not_wald(pvals_by_type(inf))
		}
	}
})

test_that("CountKKGLMM: score / gradient dispatch to the model test; Poisson-GLMM score info has the right sign", {
	s = make_t121b("count", ~ x1)
	inf = InferenceCountKKGLMM$new(s$des, verbose = FALSE)
	inf$compute_estimate()
	priv = inf$.__enclos_env__$private
	pm = c(score = priv$compute_score_two_sided_pval_impl(0),
		lik_ratio = priv$compute_lik_ratio_two_sided_pval_impl(0),
		gradient = priv$compute_gradient_two_sided_pval_impl(0))
	expect_true(all(is.finite(pm)))
	# regression: the un-negated (negative definite) information made score p ~0.25 vs LR ~0.03
	expect_lt(abs(pm[["score"]] - pm[["lik_ratio"]]), 0.03)
	expect_lt(abs(pm[["gradient"]] - pm[["lik_ratio"]]), 0.03)
	# dispatched value = design-conservative max(model, Wald) (documented rule), per type
	p = pvals_by_type(inf)
	for (tt in c("score", "lik_ratio", "gradient")) expect_equal(p[[tt]], max(pm[[tt]], p[["wald"]]), tolerance = 1e-8)
	# score CI no longer silently Wald-identical bookkeeping: it must be a valid interval
	inf$set_testing_type("score")
	ci = suppressWarnings(inf$compute_asymp_confidence_interval())
	expect_true(all(is.finite(ci)))
	expect_lt(ci[[1L]], inf$compute_estimate()); expect_gt(ci[[2L]], inf$compute_estimate())
})
