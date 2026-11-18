# v1.0.6-TODO-135: a jackknife with very few deletion units (e.g. leave-one-block-out on a
# 2-stratum design) returned a finite but meaningless SE with no warning (SE 0.0176 vs a Wald
# SE of 0.0316, p ~ 4.6e-16 in the v1.0.6-TODO-127 repro). With G units the jackknife variance
# has G - 1 df and the jackknife-Wald p-value / CI use the normal reference, so
# compute_jackknife_summary() now returns NA with an edi_procedure_na_warning (reason
# "jackknife_too_few_deletion_units") when G < EDI_JACKKNIFE_MIN_DELETION_UNITS (5). At or
# above the threshold results are unchanged.

fx_jk_few_units_blocking = function(n_blocks, n = 40L, seed = 1L){
	set.seed(seed)
	X = data.frame(x = rnorm(n), s = factor(rep(letters[seq_len(n_blocks)], length.out = n)))
	des = DesignFixedBlocking$new(strata_cols = "s", response_type = "continuous", n = n, seed = seed,
		verbose = FALSE, equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	des
}

fx_jk_few_units_cluster = function(n_clusters){
	n = 2L * n_clusters
	des = DesignFixedCluster$new(n = n, response_type = "continuous", cluster_col = "cl", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq_len(n),
		cl = factor(rep(seq_len(n_clusters), each = 2L), levels = seq_len(n_clusters))))
	des$overwrite_all_subject_assignments(rep(rep(c(1, 0), length.out = n_clusters), each = 2L))
	set.seed(n_clusters)
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	des
}

# Runs expr with the minimum-units threshold set to `value` (2 = the pre-v1.0.6-TODO-135 rule).
with_jk_min_units = function(value, expr){
	ns = asNamespace("EDI")
	old = get("EDI_JACKKNIFE_MIN_DELETION_UNITS", envir = ns)
	locked = bindingIsLocked("EDI_JACKKNIFE_MIN_DELETION_UNITS", ns)
	if (locked) unlockBinding("EDI_JACKKNIFE_MIN_DELETION_UNITS", ns)
	assign("EDI_JACKKNIFE_MIN_DELETION_UNITS", value, envir = ns)
	on.exit({
		assign("EDI_JACKKNIFE_MIN_DELETION_UNITS", old, envir = ns)
		if (locked) lockBinding("EDI_JACKKNIFE_MIN_DELETION_UNITS", ns)
	}, add = TRUE)
	force(expr)
}

jk_outputs = function(inf, unit = "auto"){
	suppressWarnings(list(
		est = inf$compute_jackknife_estimate(unit = unit),
		bias = inf$compute_jackknife_bias_estimate(unit = unit),
		se = inf$compute_jackknife_std_error(unit = unit),
		pval = inf$compute_jackknife_wald_two_sided_pval(unit = unit),
		ci = unname(inf$compute_jackknife_wald_confidence_interval(unit = unit))
	))
}

test_that("the threshold is 5 deletion units", {
	expect_identical(EDI:::EDI_JACKKNIFE_MIN_DELETION_UNITS, 5L)
})

for (G in 2:4) local({
	G = G
	test_that(paste0("leave-one-block-out with ", G, " blocks: every jackknife output is NA and warns with the reason"), {
		inf = InferenceAllSimpleAverageDiff$new(fx_jk_few_units_blocking(G), verbose = FALSE)
		inf$num_cores = 1L
		p = inf$.__enclos_env__$private
		wald_ci = inf$compute_asymp_confidence_interval()
		jack = inf$approximate_jackknife_distribution_beta_hat_T()
		expect_length(jack, G)
		expect_true(all(is.finite(jack)))
		expect_warning(se <- inf$compute_jackknife_std_error(), "jackknife_too_few_deletion_units",
			class = "edi_procedure_na_warning")
		expect_true(is.na(se))
		expect_warning(est <- inf$compute_jackknife_estimate(), "only [0-9]+ deletion units",
			class = "edi_procedure_na_warning")
		expect_true(is.na(est))
		expect_warning(b <- inf$compute_jackknife_bias_estimate(), "jackknife_too_few_deletion_units",
			class = "edi_procedure_na_warning")
		expect_true(is.na(b))
		expect_warning(pv <- inf$compute_jackknife_wald_two_sided_pval(), "jackknife_too_few_deletion_units",
			class = "edi_procedure_na_warning")
		expect_true(is.na(pv))
		expect_warning(ci <- inf$compute_jackknife_wald_confidence_interval(), "jackknife_too_few_deletion_units",
			class = "edi_procedure_na_warning")
		expect_true(all(is.na(ci)))
		expect_identical(p$cached_values$jackknife_n_deletion_units, list(n = G, unit = "block"))
		# The model-based Wald state is untouched.
		expect_identical(inf$compute_asymp_confidence_interval(), wald_ci)
		expect_true(all(is.finite(wald_ci)))
	})
})

test_that("the v1.0.6-TODO-127 case (2 strata, OLS) is NA with a warning instead of a meaningless SE", {
	set.seed(1)
	n = 40L
	X = data.frame(x = rnorm(n), s = factor(rep(c("a", "b"), each = n / 2)))
	des = DesignFixedBlocking$new(strata_cols = "s", response_type = "continuous", n = n, seed = 1,
		design_formula = ~ x + s, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	inf = InferenceContinOLS$new(des, verbose = FALSE)
	inf$num_cores = 1L
	# Before the guard this was finite (0.776 here) and came with no warning.
	old_se = with_jk_min_units(2L, InferenceContinOLS$new(des, verbose = FALSE)$compute_jackknife_std_error())
	expect_true(is.finite(old_se))
	expect_warning(se <- inf$compute_jackknife_std_error(), "jackknife_too_few_deletion_units",
		class = "edi_procedure_na_warning")
	expect_true(is.na(se))
})

test_that("cluster jackknife: 4 clusters is NA with a warning, 5 clusters is finite", {
	inf4 = InferenceAllSimpleAverageDiff$new(fx_jk_few_units_cluster(4L), verbose = FALSE)
	expect_length(inf4$approximate_jackknife_distribution_beta_hat_T(unit = "cluster"), 4L)
	expect_warning(se4 <- inf4$compute_jackknife_std_error(unit = "cluster"), "unit = \"cluster\"",
		class = "edi_procedure_na_warning")
	expect_true(is.na(se4))
	inf5 = InferenceAllSimpleAverageDiff$new(fx_jk_few_units_cluster(5L), verbose = FALSE)
	expect_silent(se5 <- inf5$compute_jackknife_std_error(unit = "cluster"))
	expect_true(is.finite(se5) && se5 > 0)
})

test_that("at or above the threshold every jackknife output is identical to the pre-guard rule", {
	for (G in c(5L, 6L, 8L)) {
		des = fx_jk_few_units_blocking(G, n = 48L)
		new = jk_outputs(InferenceAllSimpleAverageDiff$new(des, verbose = FALSE))
		old = with_jk_min_units(2L, jk_outputs(InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)))
		expect_identical(new, old)
		expect_true(all(is.finite(unlist(new))))
	}
	# Leave-one-observation-out on a non-blocking design (n units) is unchanged too.
	des = DesignFixedBernoulli$new(n = 30L, response_type = "continuous", verbose = FALSE)
	set.seed(3)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(30L)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(30L) + des$get_w())
	expect_identical(jk_outputs(InferenceContinOLS$new(des, verbose = FALSE)),
		with_jk_min_units(2L, jk_outputs(InferenceContinOLS$new(des, verbose = FALSE))))
})

# Owner decision 2026-11-18 (follow-up to v1.0.6-TODO-135): BCa is gated too. Its acceleration
# is a skewness estimated from the G jackknife replicates (identically 0 at G = 2) and the
# bootstrap resamples only those G units, so below EDI_JACKKNIFE_MIN_DELETION_UNITS the BCa CI
# and p-value (plain and Bayesian) are NA with exactly one edi_procedure_na_warning.
bca_outputs = function(des, bayes = FALSE, seed = 11L){
	run_one = function(f){
		inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
		inf$num_cores = 1L
		inf$set_seed(seed)
		ws = list()
		val = withCallingHandlers(f(inf), warning = function(w){
			ws[[length(ws) + 1L]] <<- w
			invokeRestart("muffleWarning")
		})
		list(val = unname(val), warnings = ws, inf = inf)
	}
	if (bayes) {
		list(
			ci = run_one(function(inf) inf$compute_bayesian_bootstrap_confidence_interval(B = 201, type = "bca",
				show_progress = FALSE, weighting_unit_type = "resample_blocks")),
			pval = run_one(function(inf) inf$compute_bayesian_bootstrap_two_sided_pval(B = 201, type = "bca",
				show_progress = FALSE, weighting_unit_type = "resample_blocks"))
		)
	} else {
		list(
			ci = run_one(function(inf) inf$compute_bootstrap_confidence_interval(B = 201, type = "bca", show_progress = FALSE)),
			pval = run_one(function(inf) inf$compute_bootstrap_two_sided_pval(B = 201, type = "bca", show_progress = FALSE))
		)
	}
}

for (G in 2:4) local({
	G = G
	test_that(paste0("BCa with ", G, " blocks: plain and Bayesian CI and p-value are NA and warn exactly once"), {
		des = fx_jk_few_units_blocking(G)
		for (bayes in c(FALSE, TRUE)) {
			out = bca_outputs(des, bayes = bayes)
			reason = paste0(if (bayes) "bayesian_" else "", "bootstrap_bca_jackknife_too_few_deletion_units")
			for (what in names(out)) {
				info = paste(if (bayes) "bayesian" else "plain", what)
				expect_true(all(is.na(out[[what]]$val)), info = info)
				expect_length(out[[what]]$warnings, 1L)
				w = out[[what]]$warnings[[1L]]
				expect_s3_class(w, "edi_procedure_na_warning")
				expect_identical(w$reason, reason, info = info)
				expect_match(conditionMessage(w), paste0("only ", G, " deletion units"), info = info)
				# A bootstrap-procedure failure: the model-based Wald state stays valid.
				expect_false(out[[what]]$inf$is_nonestimable("any"), info = info)
			}
		}
		# The plain-bootstrap message names the jackknife unit.
		expect_match(conditionMessage(bca_outputs(des)$ci$warnings[[1L]]), "unit = \"block\"", fixed = TRUE)
	})
})

test_that("BCa at or above the threshold is identical to the pre-guard rule (plain and Bayesian)", {
	strip = function(o) lapply(o, function(x) list(val = x$val, warnings = lapply(x$warnings, conditionMessage)))
	for (G in c(5L, 7L, 8L)) {
		des = fx_jk_few_units_blocking(G, n = 48L)
		for (bayes in c(FALSE, TRUE)) {
			new = strip(bca_outputs(des, bayes = bayes))
			old = with_jk_min_units(2L, strip(bca_outputs(des, bayes = bayes)))
			expect_identical(new, old, info = paste(G, bayes))
			if (G >= 7L) expect_true(all(is.finite(unlist(lapply(new, `[[`, "val")))), info = paste(G, bayes))
		}
	}
	# Under the pre-guard rule 2 blocks gave a finite BCa interval (acceleration exactly 0).
	old2 = with_jk_min_units(2L, bca_outputs(fx_jk_few_units_blocking(2L)))
	expect_true(all(is.finite(old2$ci$val)))
	expect_length(old2$ci$warnings, 0L)
})
