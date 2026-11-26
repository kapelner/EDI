# v1.0.6-TODO-91: the incidence g-computation risk-ratio jackknife-Wald p-value and CI
# (plain InferenceIncidGCompRiskRatio and KK InferenceIncidKKGCompRiskRatio) built their own
# log-scale SE, rejecting only <= 1 usable replicate. They skipped the v1.0.6-TODO-89
# minimum-units guard (3 blocks gave a finite p-value), silently dropped failed or
# non-positive replicates, never flagged extreme replicates (KK, 6 pairs: CI 1e-13 to 1e14)
# and returned NA with no warning. They now apply the compute_jackknife_summary() guards
# (edi_rr_jackknife_log_summary()) and warn via edi_warn_jackknife_na() on every NA. With
# 5+ units and no failure the result is unchanged (the old log-scale formula).

gcomp_rr_jk_blocking = function(G, seed, n = 60L){
	set.seed(seed)
	X = data.frame(x = rnorm(n), s = factor(rep(letters[seq_len(G)], length.out = n)))
	des = DesignFixedBlocking$new(strata_cols = "s", response_type = "incidence", n = n, seed = seed,
		verbose = FALSE, equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.5 * X$x)))
	des
}

gcomp_rr_jk_kk = function(n_pairs, seed){
	set.seed(seed)
	n = 2L * n_pairs
	x = rnorm(n)
	des = DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n_pairs), each = 2L),
		verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w = rep(c(0, 1), n_pairs)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.5 + 1.0 * w + 0.4 * x)))
	des
}

gcomp_rr_jk_new = function(kind, estimand, units, seed){
	if (kind == "plain") {
		gen = if (estimand == "RR") InferenceIncidGCompRiskRatio else InferenceIncidGCompRiskDiff
		inf = gen$new(gcomp_rr_jk_blocking(units, seed), verbose = FALSE)
	} else {
		gen = if (estimand == "RR") InferenceIncidKKGCompRiskRatio else InferenceIncidKKGCompRiskDiff
		inf = suppressWarnings(gen$new(gcomp_rr_jk_kk(units, seed), model_formula = ~ x, verbose = FALSE))
	}
	inf$num_cores = 1L
	suppressWarnings(inf$compute_estimate(), classes = "edi_logistic_separation_warning")
	inf
}

# v1.0.6-TODO-1 (5bdb9dfb): the automatic jackknife unit on DesignFixedBlocking is now one subject
# within its stratum, so the plain (blocking) cases ask for leave-one-block-out explicitly; the KK
# cases keep the automatic unit (one matched pair).
jk_unit = function(kind) if (kind == "plain") "block" else "auto"

for (kind in c("plain", "KK")) for (estimand in c("RD", "RR")) local({
	kind = kind
	estimand = estimand
	test_that(paste0(kind, " g-computation ", estimand, " with 3 deletion units: jackknife-Wald p-value and CI are NA and warn"), {
		inf = gcomp_rr_jk_new(kind, estimand, 3L, seed = 2L)
		u = jk_unit(kind)
		for (k in 1:2) {   # every call warns, not only the first
			expect_warning(pv <- inf$compute_jackknife_wald_two_sided_pval(unit = u), "jackknife_too_few_deletion_units",
				class = "edi_procedure_na_warning")
			expect_true(is.na(pv))
			expect_warning(ci <- inf$compute_jackknife_wald_confidence_interval(unit = u), "only 3 deletion units",
				class = "edi_procedure_na_warning")
			expect_true(all(is.na(ci)))
			expect_identical(names(ci), c("2.5%", "97.5%"))
		}
		expect_false(isTRUE(inf$is_nonestimable("any")))   # a jackknife failure keeps the Wald state
	})
})

test_that("plain and KK g-computation RR/RD with 6 deletion units and no failure are finite, silent and equal the log-scale formula", {
	cases = list(list(kind = "plain", seed = 2L), list(kind = "KK", seed = 4L))
	for (cs in cases) for (estimand in c("RD", "RR")) {
		inf = gcomp_rr_jk_new(cs$kind, estimand, 6L, seed = cs$seed)
		u = jk_unit(cs$kind)
		expect_silent(pv <- inf$compute_jackknife_wald_two_sided_pval(unit = u))
		expect_silent(ci <- inf$compute_jackknife_wald_confidence_interval(unit = u))
		expect_true(is.finite(pv))
		expect_true(all(is.finite(ci)))
		jack = inf$approximate_jackknife_distribution_beta_hat_T(unit = u)
		expect_length(jack, 6L)
		if (estimand == "RR") {
			# The pre-v1.0.6-TODO-91 formula: log(est) +/- z * SE of the log replicates.
			est = as.numeric(inf$compute_estimate())
			lj = log(jack)
			se = sqrt((5 / 6) * sum((lj - mean(lj))^2))
			expect_equal(pv, 2 * pnorm(-abs(log(est) / se)), tolerance = 1e-12)
			expect_equal(unname(ci), exp(log(est) + c(-1, 1) * qnorm(0.975) * se), tolerance = 1e-12)
		}
	}
})

test_that("KK g-computation RR with 6 pairs and extreme leave-one-pair-out risk ratios is NA with a warning (was a 1e-13 to 1e14 CI)", {
	inf = gcomp_rr_jk_new("KK", "RR", 6L, seed = 1L)
	expect_warning(pv <- inf$compute_jackknife_wald_two_sided_pval(), "jackknife_extreme_finite_estimates",
		class = "edi_procedure_na_warning")
	expect_true(is.na(pv))
	expect_warning(ci <- inf$compute_jackknife_wald_confidence_interval(), "jackknife_extreme_finite_estimates",
		class = "edi_procedure_na_warning")
	expect_true(all(is.na(ci)))
})

test_that("a failed or non-positive replicate is no longer dropped silently: NA with the specific reason", {
	for (kind in c("plain", "KK")) {
		for (bad in list(list(v = NA_real_, why = "jackknife_nonfinite_replicate_estimates"),
		                 list(v = 0, why = "jackknife_nonpositive_risk_ratio_replicates"))) {
			inf = gcomp_rr_jk_new(kind, "RR", 6L, seed = if (kind == "plain") 2L else 4L)
			p = inf$.__enclos_env__$private
			jack = as.numeric(p$approximate_jackknife_distribution_beta_hat_T_private(unit = "auto"))
			jack[2L] = bad$v
			unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", p)
			p$approximate_jackknife_distribution_beta_hat_T_private = function(unit = "auto") jack
			expect_warning(pv <- inf$compute_jackknife_wald_two_sided_pval(), bad$why, class = "edi_procedure_na_warning")
			expect_true(is.na(pv))
			expect_warning(ci <- inf$compute_jackknife_wald_confidence_interval(), bad$why, class = "edi_procedure_na_warning")
			expect_true(all(is.na(ci)))
		}
	}
})

test_that("an invalid null ratio and an unusable original estimate warn with their reasons", {
	inf = gcomp_rr_jk_new("plain", "RR", 6L, seed = 2L)
	expect_warning(pv <- inf$compute_jackknife_wald_two_sided_pval(delta = 0), "jackknife_log_risk_ratio_null_unavailable",
		class = "edi_procedure_na_warning")
	expect_true(is.na(pv))
	inf2 = gcomp_rr_jk_new("KK", "RR", 6L, seed = 4L)
	unlockBinding("compute_estimate", inf2)
	inf2$compute_estimate = function(estimate_only = FALSE) -0.2
	expect_warning(ci <- inf2$compute_jackknife_wald_confidence_interval(), "jackknife_original_risk_ratio_unavailable",
		class = "edi_procedure_na_warning")
	expect_true(all(is.na(ci)))
})
