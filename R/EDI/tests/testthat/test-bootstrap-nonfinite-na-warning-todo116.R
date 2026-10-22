context("TODO-116: bootstrap p-value NA from non-finite replicates explains itself")

# Deterministic fixture: a healthy InferenceAllSimpleAverageDiff whose bootstrap
# (and Bayesian bootstrap) distribution is stubbed to a fixed vector of B values
# with k non-finite entries. No optimizer is involved, so the non-finite count
# cannot drift when an unrelated estimator is fixed.
fx_nf_116 = function(n = 40L, seed = 111, k = 7L, B = 101L, stub = TRUE){
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n, sd = 0.5))
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores = 1L
	if (stub) {
		est = as.numeric(inf$compute_estimate())
		draws = est + seq(-1, 1, length.out = B)
		if (k > 0L) draws[seq_len(k) * 3L] = rep(c(NA_real_, Inf, -Inf, NaN), length.out = k)
		stub_fn = function(...) draws
		for (nm in c("approximate_bootstrap_distribution_beta_hat_T", "approximate_bayesian_bootstrap_distribution_beta_hat_T")) {
			if (bindingIsLocked(nm, inf)) unlockBinding(nm, inf)
			assign(nm, stub_fn, envir = inf)
		}
	}
	inf
}

test_that("NA p-value from non-finite replicates warns once, values unchanged, CI/na.rm = TRUE still finite", {
	inf = fx_nf_116()
	expect_warning(
		p <- inf$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		class = "edi_bootstrap_nonfinite_na_warning")
	expect_true(is.na(p))
	# once per object: a second NA p-value is silent
	expect_no_warning(p2 <- inf$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		message = "edi_bootstrap_nonfinite_na_warning")
	expect_true(is.na(p2))
	# na.rm = TRUE: finite p-value, no such warning
	p3 = withCallingHandlers(
		inf$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", na.rm = TRUE, show_progress = FALSE),
		edi_bootstrap_nonfinite_na_warning = function(w) stop("unexpected edi_bootstrap_nonfinite_na_warning"))
	expect_true(is.finite(p3))
})

test_that("warning message reports counts and can be suppressed by class", {
	inf = fx_nf_116(seed = 2, k = 7L, B = 101L)
	w = tryCatch(inf$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		edi_bootstrap_nonfinite_na_warning = function(w) w)
	expect_s3_class(w, "edi_bootstrap_nonfinite_na_warning")
	expect_match(conditionMessage(w), "7 of 101 bootstrap replicates were non-finite")
	expect_match(conditionMessage(w), "na.rm = TRUE")
	expect_identical(w$n_nonfinite, 7L)
	expect_identical(w$n_total, 101L)
	inf2 = fx_nf_116(seed = 2)
	expect_no_warning(suppressWarnings(
		inf2$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		classes = "edi_bootstrap_nonfinite_na_warning"), message = "edi_bootstrap_nonfinite_na_warning")
})

test_that("Bayesian bootstrap p-value path warns once with the same class", {
	inf = fx_nf_116(k = 5L)
	w = tryCatch(inf$compute_bayesian_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		edi_bootstrap_nonfinite_na_warning = function(w) w)
	expect_s3_class(w, "edi_bootstrap_nonfinite_na_warning")
	expect_identical(w$n_nonfinite, 5L)
	expect_identical(w$n_total, 101L)
	expect_match(conditionMessage(w), "compute_bayesian_bootstrap_two_sided_pval")
	expect_match(conditionMessage(w), "na.rm = TRUE")
	expect_no_warning(p2 <- inf$compute_bayesian_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		message = "edi_bootstrap_nonfinite_na_warning")
	expect_true(is.na(p2))
	p3 = withCallingHandlers(
		inf$compute_bayesian_bootstrap_two_sided_pval(B = 101, type = "percentile", na.rm = TRUE, show_progress = FALSE),
		edi_bootstrap_nonfinite_na_warning = function(w) stop("unexpected warning"))
	expect_true(is.finite(p3))
})

test_that("no warning when every replicate is finite", {
	inf = fx_nf_116(k = 0L)
	p = withCallingHandlers(
		inf$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		edi_bootstrap_nonfinite_na_warning = function(w) stop("unexpected warning"))
	expect_true(is.finite(p))
	# real (unstubbed) healthy fit stays silent as well
	set.seed(1); n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	inf2 = InferenceContinOLS$new(des, verbose = FALSE)
	p2 = withCallingHandlers(
		inf2$compute_bootstrap_two_sided_pval(B = 51, type = "percentile", show_progress = FALSE),
		edi_bootstrap_nonfinite_na_warning = function(w) stop("unexpected warning"))
	expect_true(is.finite(p2))
})

test_that("warning is silent while a resampling operation is active", {
	inf = fx_nf_116()
	priv = inf$.__enclos_env__$private
	priv$active_resampling_operation = "bootstrap"
	p = withCallingHandlers(
		inf$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		edi_bootstrap_nonfinite_na_warning = function(w) stop("unexpected warning"))
	expect_true(is.na(p))
	priv$active_resampling_operation = NULL
	expect_warning(inf$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE),
		class = "edi_bootstrap_nonfinite_na_warning")
})
