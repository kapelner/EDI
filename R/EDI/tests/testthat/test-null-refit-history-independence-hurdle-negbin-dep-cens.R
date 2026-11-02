# TODO-180 (v1.0.5, 2026-10-31): the delta-constrained null refits of
# InferenceCountHurdleNegBin and InferenceSurvivalDepCensTransformRegr (score /
# LR / gradient tests and their CI inversion) warm-started from the previous
# delta's null fit and could converge to a different constrained optimum, so a
# p-value depended on what the object had computed before. Calibration null
# replicates (n = 200, Bernoulli design, same generator as
# R/package_tests/calibration/calibration_fast_tier_common.R): HurdleNegBin
# `~1` rep 3, score p at the upper score-CI endpoint 0.049 on the same object vs
# 0.147 on a fresh one; DepCensTransform `~.` rep 9, 0.050 vs 0.771. fit_null
# now ignores the carried start (deterministic starts, lowest neg-loglik), so
# the same object and a fresh object must agree at every delta.

make_todo180_design = function(response_type, rep){
	rt_index = match(response_type, c("continuous", "incidence", "proportion", "count", "ordinal", "survival"))
	set.seed(1e6 * rt_index + 7L * 200L + rep)
	n = 200L
	X = data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	des = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	eta = 0.5 * X$x1 + 0.5 * X$x2
	if (response_type == "count") {
		des$add_all_subject_responses(stats::rpois(n, exp(0.5 + 0.6 * eta)))
	} else {
		t = stats::rweibull(n, shape = 1.5, scale = exp(eta / 1.5))
		cens = stats::rexp(n, 0.3)
		ev = t <= cens
		obs = pmin(t, cens)
		des$add_all_subject_responses(ifelse(ev, obs, NA), y_Ls = ifelse(ev, NA, obs), y_Rs = ifelse(ev, NA, Inf))
	}
	des
}

todo180_cases = list(
	list(cls = "InferenceCountHurdleNegBin", response_type = "count", rep = 3L, fml = ~ 1),
	list(cls = "InferenceSurvivalDepCensTransformRegr", response_type = "survival", rep = 9L, fml = ~ .)
)

for (case in todo180_cases) {
	test_that(paste0(case$cls, " score / LR p-values do not depend on a prior CI inversion (TODO-180)"), {
		des = make_todo180_design(case$response_type, case$rep)
		gen = get(case$cls)
		new_inf = function() suppressWarnings(gen$new(des, model_formula = case$fml, verbose = FALSE))

		inf = new_inf()
		score_ci = suppressWarnings(inf$compute_score_confidence_interval())
		lr_ci = suppressWarnings(inf$compute_lik_ratio_confidence_interval())
		expect_true(all(is.finite(score_ci)))
		expect_true(all(is.finite(lr_ci)))

		for (d in c(unname(score_ci), 0)) {
			p_same = suppressWarnings(inf$compute_score_two_sided_pval(d))
			p_fresh = suppressWarnings(new_inf()$compute_score_two_sided_pval(d))
			expect_true(is.finite(p_same))
			expect_equal(p_same, p_fresh, tolerance = 1e-8)
		}
		for (d in c(unname(lr_ci), 0)) {
			p_same = suppressWarnings(inf$compute_lik_ratio_two_sided_pval(d))
			p_fresh = suppressWarnings(new_inf()$compute_lik_ratio_two_sided_pval(d))
			expect_true(is.finite(p_same))
			expect_equal(p_same, p_fresh, tolerance = 1e-8)
		}
		# The score CI is a real root of its own test at both endpoints.
		p_end = vapply(unname(score_ci), function(d) suppressWarnings(new_inf()$compute_score_two_sided_pval(d)), numeric(1))
		expect_true(all(abs(p_end - 0.05) < 0.002))
	})
}
