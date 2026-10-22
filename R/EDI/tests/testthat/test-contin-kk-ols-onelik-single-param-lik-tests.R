library(testthat)
library(EDI)

# TODO-122: with beta_T the only column of the stacked design (all-matched design,
# ~1 formula) the null fit had every parameter fixed, fast_ols_with_var_cpp threw
# "at least one parameter must remain free", and the score / LR p-values and CIs
# were NA. Reference: the pair-difference regression d ~ 1 with sigma^2 fixed at
# var(d) (the class's likelihood convention), referred to chi-square(1) (no
# Bartlett correction is applied by default).

make_single_param_kk_ols_design = function() {
	set.seed(1)
	n = 40L
	des = DesignFixedBinaryMatch$new(
		response_type = "continuous", n = n, m = rep(seq_len(n / 2L), each = 2L),
		design_formula = ~ 1, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = as.vector(replicate(n / 2L, sample(0:1)))
	des$assign_w_to_all_subjects(w)
	y = 0.5 * w + rep(rnorm(n / 2L), each = 2L) + rnorm(n)
	des$add_all_subject_responses(y)
	idx = matrix(seq_len(n), nrow = 2L)
	d = apply(idx, 2L, function(i) (y[i] * ifelse(w[i] == 1, 1, -1))[1L] + (y[i] * ifelse(w[i] == 1, 1, -1))[2L])
	list(des = des, d = d)
}

test_that("KKOLSOneLik score/LR/Wald are finite and match the pair-difference regression when beta_T is the only parameter", {
	s = make_single_param_kk_ols_design()
	d = s$d; m = length(d)
	chisq_p = function(delta) stats::pchisq(m * (mean(d) - delta)^2 / stats::var(d), 1, lower.tail = FALSE)
	ref_ci = mean(d) + c(-1, 1) * stats::qnorm(0.975) * stats::sd(d) / sqrt(m)
	inf = InferenceContinKKOLSOneLik$new(s$des, verbose = FALSE)
	expect_equal(inf$compute_estimate(), mean(d), tolerance = 1e-8)
	for (type in c("score", "lik_ratio")) {
		inf$set_testing_type(type)
		expect_equal(inf$compute_asymp_two_sided_pval(delta = 0), chisq_p(0), tolerance = 1e-6, info = type)
		ci = inf$compute_asymp_confidence_interval()
		expect_true(all(is.finite(ci)), info = type)
		expect_lt(ci[[1L]], inf$compute_estimate()); expect_gt(ci[[2L]], inf$compute_estimate())
		expect_equal(unname(ci), ref_ci, tolerance = 1e-4, info = type)
		# non-zero null
		expect_equal(inf$compute_asymp_two_sided_pval(delta = 0.3), chisq_p(0.3), tolerance = 1e-6, info = type)
	}
	inf$set_testing_type("wald")
	expect_true(is.finite(inf$compute_asymp_two_sided_pval(delta = 0)))
	expect_true(all(is.finite(inf$compute_asymp_confidence_interval())))
})
