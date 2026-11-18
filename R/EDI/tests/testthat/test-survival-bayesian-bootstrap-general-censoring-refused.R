# v1.0.6-TODO-141: the Bayesian bootstrap under left-/interval-censoring used to fail inside every
# Dirichlet-weighted draw (the interval-censored fits take no case weights) and come back NA with a
# misleading "too few finite draws" / "non-finite replicates" reason, or (RestrictedMeanDiff's
# p-value) a silent NA. It now stops up front with one clear error for the CI, the p-value and the
# draw distribution. Right-censored data keep working.

survival_classes_accepting_general_censoring = c(
	"InferenceSurvivalKMDiff",
	"InferenceSurvivalRestrictedMeanDiff",
	"InferenceSurvivalGehanWilcox",
	"InferenceSurvivalLogRank",
	"InferenceSurvivalWeibullRegr"
)

make_bb_censoring_design = function(interval){
	set.seed(7); n = 120
	des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	t_event = rweibull(n, 1.5, 12 * exp(0.4 * w))
	if (interval) {
		L = floor(t_event / 3) * 3
		des$add_all_subject_responses(y_Ls = L, y_Rs = L + 3)
	} else {
		c_t = rexp(n, 1 / 20); ev = t_event <= c_t
		des$add_all_subject_responses(ys = ifelse(ev, t_event, NA), y_Ls = ifelse(ev, NA, c_t), y_Rs = ifelse(ev, NA, Inf))
	}
	des
}

test_that("Bayesian bootstrap refuses interval-censored data up front for every general-censoring survival class", {
	des = make_bb_censoring_design(interval = TRUE)
	for (cl in survival_classes_accepting_general_censoring) {
		gen = get(cl)
		expect_error(
			gen$new(des)$compute_bayesian_bootstrap_confidence_interval(B = 21, show_progress = FALSE),
			"Bayesian bootstrap is not (yet )?supported for left-/interval-censored", info = cl
		)
		expect_error(
			gen$new(des)$compute_bayesian_bootstrap_two_sided_pval(B = 21, show_progress = FALSE),
			"Bayesian bootstrap is not (yet )?supported for left-/interval-censored", info = cl
		)
		expect_error(
			gen$new(des)$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 21, show_progress = FALSE),
			"Bayesian bootstrap is not supported for left-/interval-censored", info = cl
		)
	}
})

test_that("Bayesian bootstrap still gives finite results on right-censored data for the same classes", {
	des = make_bb_censoring_design(interval = FALSE)
	for (cl in survival_classes_accepting_general_censoring) {
		gen = get(cl)
		set.seed(1)
		ci = gen$new(des)$compute_bayesian_bootstrap_confidence_interval(B = 51, show_progress = FALSE)
		expect_true(all(is.finite(ci)), info = cl)
		set.seed(1)
		p = gen$new(des)$compute_bayesian_bootstrap_two_sided_pval(B = 51, show_progress = FALSE)
		expect_true(is.finite(p) && p >= 0 && p <= 1, info = cl)
	}
})
