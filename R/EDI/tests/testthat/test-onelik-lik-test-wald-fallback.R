library(testthat)
library(EDI)

# TODO-121: score / LR requests on three KK *OneLik classes were silently served
# Wald numbers. (1) InferenceSurvivalKKStratCoxPHOneLik ignored testing_type in
# compute_asymp_two_sided_pval()/compute_asymp_confidence_interval(), and its
# single-parameter (~1) null refit had every parameter fixed. (2)
# InferenceCountKKCondPoissonOneLik exposed no likelihood spec on its pairs-only
# and reservoir-only fallback fits, so the model p-value was NA and the
# conservative max() rule silently kept the design Wald value. References:
# survival::coxph (sctest / logtest) and glm (anova Rao / LRT).

make_t121_matched = function(response_type, formula, n = 40L, seed = 2L) {
	set.seed(seed)
	des = DesignFixedBinaryMatch$new(
		response_type = response_type, n = n, m = rep(seq_len(n / 2L), each = 2L),
		design_formula = formula, verbose = FALSE
	)
	x1 = rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	w = as.vector(replicate(n / 2L, sample(0:1)))
	des$assign_w_to_all_subjects(w)
	g = rep(rnorm(n / 2L, 0, 0.3), each = 2L)
	y = if (response_type == "count") rpois(n, exp(0.5 + 0.4 * w + g)) else rexp(n, exp(-(0.4 * w + g)))
	des$add_all_subject_responses(y)
	list(des = des, d = data.frame(y = y, w = w, m = rep(seq_len(n / 2L), each = 2L), x1 = x1))
}

test_that("StratCoxPHOneLik honors score/lik_ratio and matches coxph (beta_T the only parameter)", {
	skip_if_not_installed("survival")
	suppressMessages(library(survival))
	for (with_cov in c(FALSE, TRUE)) {
		s = make_t121_matched("survival", if (with_cov) ~ x1 else ~ 1)
		f = if (with_cov) Surv(y, rep(1, length(y))) ~ w + x1 + strata(m) else Surv(y, rep(1, length(y))) ~ w + strata(m)
		cx = coxph(f, data = s$d, ties = "breslow")
		inf = InferenceSurvivalKKStratCoxPHOneLik$new(s$des, verbose = FALSE)
		expect_equal(inf$compute_estimate(), unname(coef(cx)["w"]), tolerance = 1e-5)
		inf$set_testing_type("wald")
		p_wald = inf$compute_asymp_two_sided_pval(0)
		inf$set_testing_type("score")
		p_score = inf$compute_asymp_two_sided_pval(0)
		inf$set_testing_type("lik_ratio")
		p_lr = inf$compute_asymp_two_sided_pval(0)
		expect_true(all(is.finite(c(p_wald, p_score, p_lr))))
		expect_gt(abs(p_score - p_wald), 1e-4)
		expect_gt(abs(p_lr - p_wald), 1e-4)
		if (!with_cov) {
			expect_equal(p_score, unname(summary(cx)$sctest["pvalue"]), tolerance = 1e-5)
			expect_equal(p_lr, unname(summary(cx)$logtest["pvalue"]), tolerance = 1e-5)
		} else {
			# test of w with x1 as nuisance: LR from nested coxph fits (offset = delta * w)
			cx0 = coxph(Surv(y, rep(1, length(y))) ~ x1 + strata(m) + offset(0 * w), data = s$d, ties = "breslow")
			expect_equal(p_lr, pchisq(2 * (cx$loglik[2] - tail(cx0$loglik, 1L)), 1, lower.tail = FALSE), tolerance = 1e-4)
		}
		# non-zero null, LR by nested coxph with offset
		d0 = 0.3
		f0 = if (with_cov) Surv(y, rep(1, length(y))) ~ x1 + strata(m) + offset(d0 * w) else Surv(y, rep(1, length(y))) ~ strata(m) + offset(d0 * w)
		cxd = coxph(f0, data = s$d, ties = "breslow")
		expect_equal(inf$compute_asymp_two_sided_pval(d0),
			pchisq(2 * (cx$loglik[2] - tail(cxd$loglik, 1L)), 1, lower.tail = FALSE), tolerance = 1e-4)
		ci = inf$compute_asymp_confidence_interval()
		expect_true(all(is.finite(ci)))
		expect_lt(ci[[1L]], inf$compute_estimate()); expect_gt(ci[[2L]], inf$compute_estimate())
		inf$set_testing_type("wald")
		expect_equal(inf$compute_asymp_two_sided_pval(0), p_wald)
	}
})

test_that("CondPoissonOneLik pairs-only fallback has a real likelihood spec matching glm (Rao / LRT)", {
	for (with_cov in c(FALSE, TRUE)) {
		s = make_t121_matched("count", if (with_cov) ~ x1 else ~ 1)
		inf = InferenceCountKKCondPoissonOneLik$new(s$des, verbose = FALSE)
		inf$compute_estimate()
		expect_false(is.null(inf$.__enclos_env__$private$get_likelihood_test_spec()))
		pr = split(s$d, s$d$m)
		yT = vapply(pr, function(g) g$y[g$w == 1], numeric(1)); nk = vapply(pr, function(g) sum(g$y), numeric(1))
		dx = if (with_cov) vapply(pr, function(g) g$x1[g$w == 1] - g$x1[g$w == 0], numeric(1)) else NULL
		keep = nk > 0
		d2 = data.frame(yT = yT[keep], nk = nk[keep]); if (with_cov) d2$dx = dx[keep]
		# beta_T is the intercept of the pair-level binomial-logit model
		f_full = if (with_cov) cbind(yT, nk - yT) ~ dx else cbind(yT, nk - yT) ~ 1
		f_null = if (with_cov) cbind(yT, nk - yT) ~ 0 + dx else cbind(yT, nk - yT) ~ 0 + offset(rep(0, nrow(d2)))
		full = glm(f_full, family = binomial, data = d2)
		null = glm(f_null, family = binomial, data = d2)
		an = anova(null, full, test = "Rao"); an_lr = anova(null, full, test = "LRT")
		expect_equal(inf$compute_score_two_sided_pval_generic(delta = 0), an[2, "Pr(>Chi)"], tolerance = 1e-5)
		expect_equal(inf$compute_lik_ratio_two_sided_pval_generic(delta = 0), an_lr[2, "Pr(>Chi)"], tolerance = 1e-5)
		# the returned (conservative) value is max(model, design Wald) and is finite
		inf$set_testing_type("score")
		p_cons = expect_no_warning(inf$compute_asymp_two_sided_pval(0))
		p_w = inf$compute_wald_two_sided_pval(0)
		expect_equal(p_cons, max(inf$compute_score_two_sided_pval_generic(delta = 0), p_w), tolerance = 1e-8)
	}
})

test_that("CondPoissonOneLik reservoir-only fallback has a real likelihood spec matching glm", {
	set.seed(3)
	n = 60L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", design_formula = ~ 1, verbose = FALSE)
	x = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(x[i, , drop = FALSE])
	w = des$.__enclos_env__$private$w
	y = rpois(n, exp(0.5 + 0.4 * w))
	for (i in seq_len(n)) des$add_one_subject_response(i, y = y[i])
	inf = InferenceCountKKCondPoissonOneLik$new(des, verbose = FALSE)
	inf$compute_estimate()
	skip_if(inf$.__enclos_env__$private$cached_values$KKstats$m > 0, "design drew matched pairs; reservoir-only path not exercised")
	full = glm(y ~ w, family = poisson); null = glm(y ~ 1, family = poisson)
	expect_equal(inf$compute_score_two_sided_pval_generic(delta = 0), anova(null, full, test = "Rao")[2, "Pr(>Chi)"], tolerance = 1e-5)
	expect_equal(inf$compute_lik_ratio_two_sided_pval_generic(delta = 0), anova(null, full, test = "LRT")[2, "Pr(>Chi)"], tolerance = 1e-5)
})

test_that("a conservative-rule substitution of Wald for an unavailable model test is flagged, not silent", {
	cons = EDI:::.conservative_kk_onelik_pval
	owner = list(self = structure(list(), class = "FakeOneLik"), private = new.env())
	owner$private$cached_values = list()
	expect_warning(p <- cons(NA_real_, 0.3, owner = owner, label = "score"), class = "edi_lik_test_wald_fallback")
	expect_equal(p, 0.3)
	# once per object and testing type
	expect_no_warning(cons(NA_real_, 0.3, owner = owner, label = "score"))
	expect_warning(cons(NA_real_, 0.3, owner = owner, label = "lik_ratio"), class = "edi_lik_test_wald_fallback")
	# finite model p: no warning
	owner2 = list(self = structure(list(), class = "FakeOneLik"), private = new.env()); owner2$private$cached_values = list()
	expect_no_warning(expect_equal(cons(0.2, 0.3, owner = owner2, label = "score"), 0.3))
	ci = EDI:::.conservative_kk_onelik_ci
	expect_warning(ci(c(NA, NA), c(-1, 1), 0.05, owner = owner2, label = "score"), class = "edi_lik_test_wald_fallback")
})
