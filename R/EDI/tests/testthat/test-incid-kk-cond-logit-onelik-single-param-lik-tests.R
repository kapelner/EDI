library(testthat)
library(EDI)

# TODO-115 (harness T39): with beta_T the only free parameter (all-matched design,
# ~1 formula) fit_null had every parameter fixed, the solver threw "at least one
# parameter must remain free", tryCatch turned it into NULL, and the score / LR
# p-values and CIs were silently NA. References: survival::clogit.

make_single_param_clogit_design = function() {
	set.seed(1)
	n = 40L
	des = DesignFixedBinaryMatch$new(
		response_type = "incidence", n = n, m = rep(seq_len(n / 2L), each = 2L),
		design_formula = ~ 1, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = as.vector(replicate(n / 2L, sample(0:1)))
	des$assign_w_to_all_subjects(w)
	y = rbinom(n, 1, plogis(-0.3 + 0.5 * w + rep(rnorm(n / 2L, 0, 0.5), each = 2L)))
	des$add_all_subject_responses(y)
	list(des = des, d = data.frame(y = y, w = w, m = rep(seq_len(n / 2L), each = 2L)))
}

test_that("KKCondLogitOneLik score/LR tests are finite and match clogit when beta_T is the only parameter", {
	skip_if_not_installed("survival")
	suppressMessages(library(survival))  # clogit() evaluates coxph() unqualified
	s = make_single_param_clogit_design()
	cl = survival::clogit(y ~ w + survival::strata(m), data = s$d)
	inf = InferenceIncidKKCondLogitOneLik$new(s$des, verbose = FALSE)
	expect_equal(inf$compute_estimate(), unname(coef(cl)), tolerance = 1e-6)

	inf$set_testing_type("score")
	expect_equal(inf$compute_asymp_two_sided_pval(delta = 0), unname(summary(cl)$sctest["pvalue"]), tolerance = 1e-5)
	ci = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci)))
	expect_lt(ci[[1L]], inf$compute_estimate()); expect_gt(ci[[2L]], inf$compute_estimate())

	inf$set_testing_type("lik_ratio")
	expect_equal(inf$compute_asymp_two_sided_pval(delta = 0), unname(summary(cl)$logtest["pvalue"]), tolerance = 1e-5)
	# non-zero null: exact conditional LR computed by hand,
	# ll(b) = b * (#discordant pairs with the treated subject positive) - n_disc * log(1 + exp(b))
	d0 = 0.5
	pr = split(s$d, s$d$m)
	disc = Filter(function(g) sum(g$y) == 1L, pr)
	n_t = sum(vapply(disc, function(g) g$y[g$w == 1L] == 1L, logical(1)))
	ll = function(b) b * n_t - length(disc) * log1p(exp(b))
	p_ref = pchisq(2 * (ll(unname(coef(cl))) - ll(d0)), 1, lower.tail = FALSE)
	expect_equal(inf$compute_asymp_two_sided_pval(delta = d0), p_ref, tolerance = 1e-5)
	ci = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci)))
})
