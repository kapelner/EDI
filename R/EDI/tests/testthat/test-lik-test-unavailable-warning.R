library(testthat)
library(EDI)

# TODO-115 (general guard): when a likelihood test (score / LR / gradient /
# Bartlett) comes back NA although the Wald result is finite, the shared
# likelihood-test machinery warns (classed edi_lik_test_unavailable_warning,
# once per object and testing type, quoting the swallowed error), without
# changing the returned NA. It must stay silent for healthy objects and inside
# resampling workers.

make_t115b_matched = function() {
	set.seed(1)
	n = 40L
	des = DesignFixedBinaryMatch$new(
		response_type = "incidence", n = n, m = rep(seq_len(n / 2L), each = 2L),
		design_formula = ~ 1, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = as.vector(replicate(n / 2L, sample(0:1)))
	des$assign_w_to_all_subjects(w)
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.5 * w + rep(rnorm(n / 2L, 0, 0.5), each = 2L))))
	des
}

make_t115b_logit = function() {
	set.seed(2)
	n = 60L
	des = DesignFixediBCRD$new(response_type = "incidence", n = n, design_formula = ~ x1, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = sample(rep(0:1, n / 2L))
	des$assign_w_to_all_subjects(w)
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.6 * w)))
	des
}

# Make the null refit throw, as a swallowed solver error would.
sabotage_null_fit = function(inf, msg = "forced null-fit failure") {
	priv = inf$.__enclos_env__$private
	orig = priv$get_likelihood_test_spec
	if (bindingIsLocked("get_likelihood_test_spec", priv)) unlockBinding("get_likelihood_test_spec", priv)
	priv$get_likelihood_test_spec = function() {
		spec = orig()
		if (is.null(spec)) return(spec)
		spec$fit_null = function(delta, start = NULL) stop(msg)
		spec
	}
	invisible(inf)
}

collect_unavailable = function(expr) {
	conds = list()
	val = withCallingHandlers(expr, warning = function(w) {
		if (inherits(w, "edi_lik_test_unavailable_warning")) conds[[length(conds) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, conds = conds)
}

for (case in c("KKCondLogitOneLik", "LogRegr")) {
	mk = function() {
		if (case == "KKCondLogitOneLik") InferenceIncidKKCondLogitOneLik$new(make_t115b_matched(), verbose = FALSE)
		else InferenceIncidLogRegr$new(make_t115b_logit(), verbose = FALSE)
	}

	test_that(paste(case, ": forced failing null fit warns once per testing type with the reason, NA unchanged"), {
		inf = mk()
		est = inf$compute_estimate()
		expect_true(is.finite(est))
		sabotage_null_fit(inf)
		inf$set_testing_type("score")
		r = collect_unavailable(inf$compute_asymp_two_sided_pval(0))
		expect_true(is.na(r$value))
		expect_length(r$conds, 1L)
		expect_identical(r$conds[[1L]]$testing_type, "score")
		expect_match(r$conds[[1L]]$reason, "forced null-fit failure", fixed = TRUE)
		expect_match(conditionMessage(r$conds[[1L]]), "forced null-fit failure", fixed = TRUE)
		# second call: no repeat for the same testing type
		r2 = collect_unavailable(inf$compute_asymp_two_sided_pval(0))
		expect_true(is.na(r2$value))
		expect_length(r2$conds, 0L)
		# a different testing type warns once on its own
		inf$set_testing_type("lik_ratio")
		r3 = collect_unavailable(inf$compute_asymp_two_sided_pval(0))
		expect_true(is.na(r3$value))
		expect_length(r3$conds, 1L)
		expect_identical(r3$conds[[1L]]$testing_type, "lik_ratio")
	})

	test_that(paste(case, ": healthy object is silent for every supported likelihood test"), {
		inf = mk()
		for (tt in c("score", "lik_ratio", "gradient")) {
			if (!tt %in% inf$get_supported_testing_types()) next
			inf$set_testing_type(tt)
			r = collect_unavailable({
				p = inf$compute_asymp_two_sided_pval(0)
				ci = inf$compute_asymp_confidence_interval()
				p
			})
			expect_true(is.finite(r$value), info = tt)
			expect_length(r$conds, 0L)
		}
	})

	test_that(paste(case, ": silent inside a resampling worker context"), {
		inf = mk()
		inf$compute_estimate()
		sabotage_null_fit(inf)
		inf$.__enclos_env__$private$active_resampling_operation = "bootstrap"
		inf$set_testing_type("score")
		r = collect_unavailable(inf$compute_asymp_two_sided_pval(0))
		expect_true(is.na(r$value))
		expect_length(r$conds, 0L)
	})
}

test_that("a failing null fit warns once on the CI path too, quoting the reason", {
	inf = InferenceIncidLogRegr$new(make_t115b_logit(), verbose = FALSE)
	inf$compute_estimate()
	sabotage_null_fit(inf, "forced CI null-fit failure")
	inf$set_testing_type("score")
	r = collect_unavailable(inf$compute_asymp_confidence_interval())
	expect_true(all(is.na(r$value)))
	expect_length(r$conds, 1L)
	expect_match(r$conds[[1L]]$reason, "forced CI null-fit failure", fixed = TRUE)
})

test_that("legitimately non-estimable objects do not trigger the guard", {
	set.seed(3)
	n = 20L
	des = DesignFixediBCRD$new(response_type = "incidence", n = n, design_formula = ~ 1, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects(sample(rep(0:1, n / 2L)))
	des$add_all_subject_responses(rep(1L, n))  # no outcome variation
	inf = InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf$set_testing_type("score")
	r = collect_unavailable(suppressWarnings(inf$compute_asymp_two_sided_pval(0)))
	expect_length(r$conds, 0L)
})
