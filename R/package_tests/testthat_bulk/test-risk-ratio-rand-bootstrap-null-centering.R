library(testthat)
library(EDI)

# v1.0.6-TODO-102: the raw risk-ratio g-computation classes estimate RR (not log RR),
# so the studentized bootstrap-randomization pivot (t - c) / se must be centered at
# c = 1 under the default sharp null delta = 0; it was centered at 0. Their RD
# siblings stay centered at 0. A nonzero delta on incidence is refused, as in
# compute_rand_two_sided_pval().

rr_null_fixture = function(cl, n = 80L) {
	set.seed(11)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = if (grepl("KK", cl)) {
		DesignFixedBinaryMatch$new(n = n, response_type = "incidence", verbose = FALSE)
	} else {
		DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	}
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.5 * X$x1)))
	get(cl)$new(des, verbose = FALSE)
}

brt_pval_and_manual = function(inf, center, type = "studentized", B = 39L) {
	priv = inf$.__enclos_env__$private
	set.seed(5)
	draws = priv$generate_rand_bootstrap_draws(B, materialize_w = TRUE)
	p = suppressWarnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, type = type, show_progress = FALSE, rand_bootstrap_draws = draws))
	t = as.numeric(inf$compute_estimate())[1L]
	stats = priv$compute_brt_null_statistics_with_se(draws, 0, "none", priv$y, .Machine$double.eps)
	se = priv$infer_original_se()
	sym = identical(type, "symmetric-percentile-t")
	manual = priv$compute_two_sided_brt_pval_studentized(t, stats$t0, stats$se0, center, se, symmetric = sym)
	at_zero = priv$compute_two_sided_brt_pval_studentized(t, stats$t0, stats$se0, 0, se, symmetric = sym)
	list(p = p, manual = manual, at_zero = at_zero)
}

for (cl in c("InferenceIncidGCompRiskRatio", "InferenceIncidKKGCompRiskRatio")) {
	test_that(paste(cl, "studentized BRT pivots at RR = 1 under delta = 0"), {
		skip_on_cran()
		for (type in c("studentized", "symmetric-percentile-t")) {
			r = brt_pval_and_manual(rr_null_fixture(cl), center = 1, type = type)
			# The KK class's replicates used to cache no beta_hat_T (all t0 NA); fixed with this TODO.
			expect_true(is.finite(r$p))
			expect_false(isTRUE(all.equal(r$p, r$at_zero)))
			expect_equal(r$p, r$manual)
		}
	})
	test_that(paste(cl, "BRT refuses a nonzero delta on incidence"), {
		inf = rr_null_fixture(cl)
		expect_error(inf$compute_rand_bootstrap_two_sided_pval(B = 19, delta = 0.2, show_progress = FALSE),
			"delta nonzero not supported for incidence")
	})
}

test_that("risk-difference g-computation studentized BRT still pivots at 0", {
	skip_on_cran()
	r = brt_pval_and_manual(rr_null_fixture("InferenceIncidGCompRiskDiff"), center = 0)
	expect_true(is.finite(r$p))
	expect_equal(r$p, r$manual)
})
