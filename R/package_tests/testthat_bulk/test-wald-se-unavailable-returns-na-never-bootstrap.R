library(testthat)
library(EDI)

# v1.0.6-TODO-380, owner principle: "If the user wants wald, we should always give
# wald." These Wald confidence-interval / p-value paths used to return the
# nonparametric bootstrap result when the standard error was unavailable. With
# the SE forced unavailable, testing_type = "wald" (compute_asymp_*) and the
# compute_wald_* aliases must give NA, record procedure_failure_reason$wald, and
# raise an edi_wald_unavailable_warning, and must never call the bootstrap
# (stubbed here to stop()). Covered: InferenceCountKKHurdlePoissonOneLik,
# InferenceCountHurdlePoisson, InferenceCountZeroInflatedPoisson /
# InferenceCountZeroInflatedNegBin (also in the zero-inflated reference tests),
# InferenceSurvivalLogRank, InferenceSurvivalGehanWilcox,
# InferenceSurvivalKMDiff (right-censored), InferenceSurvivalRestrictedMeanDiff
# (right-censored) and InferenceOrdinalGCompMeanDiff. The Turnbull (left- /
# interval-censored) paths of the KM and RMST classes have no analytic SE and
# keep the bootstrap by design (test-km-rmst-general-censoring.R).

wna_design = function(response_type, gen = DesignFixedBernoulli, n = 60L, seed = 380L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	d = suppressWarnings(gen$new(n = n, response_type = response_type, verbose = FALSE))
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	y = switch(response_type,
		count = ifelse(runif(n) < 0.3, 0L, rpois(n, exp(0.5 + 0.3 * w + 0.2 * X$x1))),
		survival = rexp(n, rate = exp(-0.3 * w)) + 0.1,
		ordinal = sample(1:4, n, TRUE)
	)
	d$add_all_subject_responses(y)
	d
}

wna_stub = function(env, name, fn) {
	if (bindingIsLocked(name, env)) unlockBinding(name, env)
	assign(name, fn, envir = env)
}

wna_forbid_bootstrap = function(inf) {
	wna_stub(inf, "compute_bootstrap_confidence_interval", function(...) stop("bootstrap must not be called"))
	wna_stub(inf, "compute_bootstrap_two_sided_pval", function(...) stop("bootstrap must not be called"))
	inf
}

# Each case builds a fitted object and then makes its SE unavailable in the way
# the class's Wald path checks it (the caches are only recomputed when NULL).
wna_cases = list(
	InferenceCountKKHurdlePoissonOneLik = function() {
		inf = InferenceCountKKHurdlePoissonOneLik$new(wna_design("count", DesignFixedBinaryMatch), verbose = FALSE)
		suppressWarnings(inf$compute_estimate())
		inf$.__enclos_env__$private$cached_values$s_beta_hat_T = NA_real_
		inf
	},
	InferenceCountHurdlePoisson = function() {
		inf = InferenceCountHurdlePoisson$new(wna_design("count"), verbose = FALSE)
		est = suppressWarnings(suppressMessages(inf$compute_estimate()))
		priv = inf$.__enclos_env__$private
		wna_stub(priv, "get_standard_error", function() NA_real_)
		wna_stub(inf, "compute_estimate", function(estimate_only = FALSE) { priv$cached_values$s_beta_hat_T = NA_real_; est })
		inf
	},
	InferenceCountZeroInflatedNegBin = function() {
		inf = InferenceCountZeroInflatedNegBin$new(wna_design("count"), verbose = FALSE)
		est = suppressWarnings(suppressMessages(inf$compute_estimate()))
		priv = inf$.__enclos_env__$private
		wna_stub(priv, "get_standard_error", function() NA_real_)
		wna_stub(priv, "shared", function(...) { priv$cached_values$s_beta_hat_T = NA_real_; invisible(NULL) })
		inf
	},
	InferenceSurvivalLogRank = function() {
		inf = InferenceSurvivalLogRank$new(wna_design("survival"), verbose = FALSE)
		inf$compute_estimate(estimate_only = FALSE)
		inf$.__enclos_env__$private$cached_values$s_beta_hat_T = NA_real_
		inf
	},
	InferenceSurvivalGehanWilcox = function() {
		inf = InferenceSurvivalGehanWilcox$new(wna_design("survival"), verbose = FALSE)
		inf$compute_estimate(estimate_only = FALSE)
		inf$.__enclos_env__$private$cached_values$s_beta_hat_T = NA_real_
		inf
	},
	InferenceSurvivalKMDiff = function() {
		inf = InferenceSurvivalKMDiff$new(wna_design("survival"), verbose = FALSE)
		inf$compute_estimate(estimate_only = FALSE)
		inf$.__enclos_env__$private$cached_values$s_beta_hat_T = NA_real_
		inf
	},
	InferenceSurvivalRestrictedMeanDiff = function() {
		inf = InferenceSurvivalRestrictedMeanDiff$new(wna_design("survival"), verbose = FALSE)
		inf$compute_estimate(estimate_only = FALSE)
		inf$.__enclos_env__$private$cached_values$s_beta_hat_T = NA_real_
		inf
	},
	InferenceOrdinalGCompMeanDiff = function() {
		inf = InferenceOrdinalGCompMeanDiff$new(wna_design("ordinal"), verbose = FALSE)
		inf$compute_estimate()
		priv = inf$.__enclos_env__$private
		priv$cached_values$se_md = NA_real_
		priv$cached_values$s_beta_hat_T = NA_real_
		inf
	}
)

wna_build = function(cn) {
	inf = tryCatch(suppressWarnings(suppressMessages(wna_cases[[cn]]())), error = function(e) e)
	if (inherits(inf, "error")) {
		pkg = regmatches(conditionMessage(inf), regexpr("[Pp]ackage ['`][A-Za-z0-9.]+['`]", conditionMessage(inf)))
		if (length(pkg)) skip(paste(cn, "needs", pkg))
		stop(inf)
	}
	wna_forbid_bootstrap(inf)
}

for (cn in names(wna_cases)) {
	test_that(paste0(cn, ": testing_type = \"wald\" with the SE unavailable is NA with a reason and a warning, never the bootstrap"), {
		inf = wna_build(cn)
		if (is.function(inf$get_testing_type)) expect_identical(inf$get_testing_type(), "wald")
		expect_warning(ci <- inf$compute_asymp_confidence_interval(alpha = 0.1), class = "edi_wald_unavailable_warning")
		expect_true(is.numeric(ci) && length(ci) == 2L && all(is.na(ci)))
		expect_identical(names(ci), c("5%", "95%"))
		reason = inf$.__enclos_env__$private$cached_values$procedure_failure_reason$wald
		expect_true(is.character(reason) && nzchar(reason))
		# one warning per fit; the p-value is NA and the reason stays recorded
		# InferenceSurvivalGehanWilcox's asymptotic p-value is its rank test, not a Wald test.
		if (!identical(cn, "InferenceSurvivalGehanWilcox")) {
			p = withCallingHandlers(inf$compute_asymp_two_sided_pval(delta = 0),
				edi_wald_unavailable_warning = function(w) invokeRestart("muffleWarning"))
			expect_true(is.numeric(p) && length(p) == 1L && is.na(p))
		}
		# The classes whose compute_wald_* aliases had their own copy of the fallback;
		# on the survival classes compute_wald_* is the generic Wald component.
		if (cn %in% c("InferenceCountKKHurdlePoissonOneLik", "InferenceOrdinalGCompMeanDiff")) {
			expect_true(all(is.na(suppressWarnings(inf$compute_wald_confidence_interval(alpha = 0.1)))))
			expect_true(is.na(suppressWarnings(inf$compute_wald_two_sided_pval(delta = 0))))
		}
	})
}

# v1.0.6-TODO-417 (DECISION-v1.0.6-TODO-380d): the asymptotic rank-test p-values
# (log-rank, Gehan-Wilcoxon) used to fall back to the bootstrap p-value when the
# log-rank null variance (right-censored) or interval::ictest()'s p-value (left- /
# interval-censored) was unavailable. With that quantity forced unavailable, the
# asymptotic p-value is NA, records procedure_failure_reason$rank_test, raises one
# edi_rank_test_unavailable_warning (an edi_procedure_na_warning) per fit, and never
# calls the bootstrap (stubbed to stop()).
rna_interval_design = function(n = 60L, seed = 417L, g = 0.5) {
	set.seed(seed)
	d = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	d$assign_w_to_all_subjects()
	t = rexp(n, rate = 0.15 * exp(0.4 * d$get_w()))
	y_L = floor(t / g) * g
	d$add_all_subject_responses(y_Ls = y_L, y_Rs = y_L + g)
	d
}

rna_cases = list(
	"InferenceSurvivalLogRank (right-censored, null variance unavailable)" = list(
		build = function() {
			inf = InferenceSurvivalLogRank$new(wna_design("survival"), verbose = FALSE)
			inf$compute_estimate(estimate_only = FALSE)
			inf$.__enclos_env__$private$cached_values$logrank_var = NA_real_
			inf
		},
		pval = function(inf) inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0)
	),
	"InferenceSurvivalLogRank (interval-censored, ictest p-value unavailable)" = list(
		interval = TRUE,
		build = function() {
			inf = InferenceSurvivalLogRank$new(rna_interval_design(), verbose = FALSE)
			inf$compute_estimate(estimate_only = FALSE)
			inf$.__enclos_env__$private$cached_values$icen_pval = NA_real_
			inf
		},
		pval = function(inf) inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0)
	),
	"InferenceSurvivalGehanWilcox (interval-censored, ictest p-value unavailable)" = list(
		interval = TRUE,
		build = function() {
			inf = InferenceSurvivalGehanWilcox$new(rna_interval_design(), verbose = FALSE)
			inf$compute_estimate(estimate_only = FALSE)
			inf$.__enclos_env__$private$cached_values$icen_pval = NA_real_
			inf
		},
		pval = function(inf) inf$compute_asymp_two_sided_pval(delta = 0)
	)
)

for (cn in names(rna_cases)) {
	test_that(paste0(cn, ": the asymptotic rank-test p-value is NA with a reason and a warning, never the bootstrap"), {
		cs = rna_cases[[cn]]
		if (isTRUE(cs$interval)) skip_if_not_installed("interval")
		inf = wna_forbid_bootstrap(suppressWarnings(suppressMessages(cs$build())))
		w = NULL
		p1 = withCallingHandlers(cs$pval(inf),
			edi_rank_test_unavailable_warning = function(cond) { w <<- cond; invokeRestart("muffleWarning") })
		expect_s3_class(w, "edi_rank_test_unavailable_warning")
		expect_s3_class(w, "edi_procedure_na_warning")
		expect_true(is.numeric(p1) && length(p1) == 1L && is.na(p1))
		p = withCallingHandlers(cs$pval(inf),
			edi_rank_test_unavailable_warning = function(w) stop("warned twice in one fit"))
		expect_true(is.numeric(p) && length(p) == 1L && is.na(p))
		expect_identical(inf$.__enclos_env__$private$cached_values$procedure_failure_reason$rank_test,
			"rank_test_asymptotic_pvalue_unavailable")
	})
}

test_that("the bootstrap p-value stays reachable through its own method on the log-rank class", {
	inf = InferenceSurvivalLogRank$new(wna_design("survival"), verbose = FALSE)
	inf$compute_estimate(estimate_only = FALSE)
	inf$.__enclos_env__$private$cached_values$logrank_var = NA_real_
	expect_warning(inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(), class = "edi_rank_test_unavailable_warning")
	set.seed(1)
	p = suppressWarnings(inf$compute_bootstrap_two_sided_pval(B = 101, type = "percentile", show_progress = FALSE))
	expect_true(is.numeric(p) && length(p) == 1L && is.finite(p) && p >= 0 && p <= 1)
})
