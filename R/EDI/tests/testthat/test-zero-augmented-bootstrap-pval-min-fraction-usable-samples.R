# v1.0.6-TODO-12 follow-up: the zero-augmented count classes override the
# nonparametric- and Bayesian-bootstrap p-values (to refuse BCa); the overrides
# must accept min_fraction_usable_samples and pass it to the base methods.

test_that("zero-augmented bootstrap p-value overrides forward min_fraction_usable_samples", {
	set.seed(4)
	n = 20
	w = rep(c(1, 0), n / 2)
	x1 = rnorm(n)
	# few positive counts: many bootstrap draws leave the count-part treatment unidentified (NA)
	y = rep(0, n)
	y[c(1, 2, 4, 7)] = c(2, 1, 3, 1)
	des = DesignFixediBCRD$new(n = n, response_type = "count")
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf = InferenceCountHurdlePoisson$new(des, model_formula = ~ 1, verbose = FALSE)
	for (m in c("compute_bootstrap_two_sided_pval", "compute_bayesian_bootstrap_two_sided_pval")) {
		expect_identical(formals(inf[[m]])$min_fraction_usable_samples, 0.95, info = m)
	}
	expect_error(inf$compute_bootstrap_two_sided_pval(B = 20, min_fraction_usable_samples = 2, show_progress = FALSE))
	set.seed(1)
	strict = suppressWarnings(inf$compute_bootstrap_two_sided_pval(B = 40, na.rm = TRUE, show_progress = FALSE,
		min_fraction_usable_samples = 1))
	set.seed(1)
	loose = suppressWarnings(inf$compute_bootstrap_two_sided_pval(B = 40, na.rm = TRUE, show_progress = FALSE,
		min_fraction_usable_samples = 0))
	expect_true(is.na(strict))
	expect_true(is.finite(loose))
	set.seed(2)
	strict_bb = suppressWarnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = 40, na.rm = TRUE, show_progress = FALSE,
		min_fraction_usable_samples = 1))
	set.seed(2)
	loose_bb = suppressWarnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = 40, na.rm = TRUE, show_progress = FALSE,
		min_fraction_usable_samples = 0))
	expect_true(is.finite(loose_bb))
	expect_true(is.na(strict_bb) || identical(strict_bb, loose_bb))
})
