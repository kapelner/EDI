# InferenceSurvivalKMDiff's Wald CI/p-value combine each arm's Brookmeyer-Crowley
# median CI by MOVER (Zou and Donner 2008), keeping each side's half-width. The
# old symmetric back-calculated SE spread a lopsided treated-arm interval onto
# both sides and missed a large effect at prob_T = 0.2 (pre-push sign check,
# 2026-11-03).

km_mover_fixture <- function() {
	set.seed(20261103L)
	n <- 300L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", prob_T = 0.2)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	t <- rweibull(n, 1.5, ifelse(w == 1, 2, 1))
	cens <- rexp(n, 0.3)
	ev <- t <= cens
	obs <- pmin(t, cens)
	des$add_all_subject_responses(ys = ifelse(ev, obs, NA), y_Ls = ifelse(ev, NA, obs), y_Rs = ifelse(ev, NA, Inf))
	list(des = des, y = obs, dead = as.integer(ev), w = w)
}

mover_half_widths_reference <- function(y, dead, w, alpha) {
	q <- stats::quantile(survival::survfit(survival::Surv(y, dead) ~ w, conf.int = 1 - alpha), 0.5)
	m <- q$quantile[, 1]; l <- q$lower[, 1]; u <- q$upper[, 1]
	d <- unname(m[["w=1"]] - m[["w=0"]])
	c(lower = sqrt((m[["w=1"]] - l[["w=1"]])^2 + (u[["w=0"]] - m[["w=0"]])^2),
	  upper = sqrt((u[["w=1"]] - m[["w=1"]])^2 + (m[["w=0"]] - l[["w=0"]])^2))
}

test_that("KMDiff asymptotic CI is the MOVER combination of the arms' median CIs", {
	fx <- km_mover_fixture()
	inf <- InferenceSurvivalKMDiff$new(fx$des)
	for (alpha in c(0.05, 0.1)) {
		ci <- inf$compute_asymp_confidence_interval(alpha = alpha)
		hw <- mover_half_widths_reference(fx$y, fx$dead, fx$w, alpha)
		est <- inf$compute_estimate()
		expect_equal(unname(ci), unname(c(est - hw[["lower"]], est + hw[["upper"]])), tolerance = 1e-8)
		# The fixture's treated arm is small, so its interval is lopsided.
		if (alpha == 0.05) expect_false(isTRUE(all.equal(hw[["lower"]], hw[["upper"]])))
	}
})

test_that("KMDiff asymptotic p-value is 0.05 at both 95% MOVER bounds", {
	fx <- km_mover_fixture()
	inf <- InferenceSurvivalKMDiff$new(fx$des)
	ci <- inf$compute_asymp_confidence_interval(alpha = 0.05)
	expect_equal(inf$compute_asymp_two_sided_pval(delta = ci[[1]]), 0.05, tolerance = 1e-8)
	expect_equal(inf$compute_asymp_two_sided_pval(delta = ci[[2]]), 0.05, tolerance = 1e-8)
	p0 <- inf$compute_asymp_two_sided_pval(delta = 0)
	expect_identical(p0 < 0.05, ci[[1]] > 0 || ci[[2]] < 0)
})
