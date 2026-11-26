library(testthat)
library(EDI)

# v1.0.6-TODO-151 follow-up (owner 2026-11-19): run_all_inference(r = , B = ) pass the draw count
# to every randomization procedure (r) and every bootstrap procedure (B) under each method's own
# argument name; NULL (default) leaves every call exactly as before.

# A fake inference object exposing every capability; each method records the args it got.
fake_inf_210 = function(){
	seen = new.env()
	obj = new.env()
	obj$seen = seen
	obj$capabilities = function() c("wald", "randomization_test", "randomization_ci", "randomization_bootstrap",
		"randomization_bootstrap_ci", "nonparametric_bootstrap", "bayesian_bootstrap", "parametric_likelihood_bootstrap",
		"likelihood_tests", "jackknife")
	mk = function(name, formal_txt) {
		f = eval(parse(text = sprintf("function(%s) NULL", formal_txt)))
		body(f) = bquote({ args = as.list(environment()); assign(.(name), args, envir = seen); if (grepl("interval", .(name))) c(-1, 1) else 0.5 })
		environment(f) = environment()
		f
	}
	obj$compute_rand_two_sided_pval = mk("compute_rand_two_sided_pval", "r = 501, delta = 0, show_progress = TRUE")
	obj$compute_rand_confidence_interval = mk("compute_rand_confidence_interval", "alpha = 0.05, r = 501, show_progress = TRUE")
	obj$compute_rand_bootstrap_two_sided_pval = mk("compute_rand_bootstrap_two_sided_pval", "delta = 0, B = 501, show_progress = TRUE")
	obj$compute_rand_bootstrap_confidence_interval = mk("compute_rand_bootstrap_confidence_interval", "alpha = 0.05, B = 501, show_progress = TRUE")
	obj$compute_bootstrap_two_sided_pval = mk("compute_bootstrap_two_sided_pval", "delta = 0, B = 501, show_progress = TRUE")
	obj$compute_bootstrap_confidence_interval = mk("compute_bootstrap_confidence_interval", "alpha = 0.05, B = 501, show_progress = TRUE")
	obj$compute_bayesian_bootstrap_two_sided_pval = mk("compute_bayesian_bootstrap_two_sided_pval", "delta = 0, B = 501, show_progress = TRUE")
	obj$compute_bayesian_bootstrap_confidence_interval = mk("compute_bayesian_bootstrap_confidence_interval", "alpha = 0.05, B = 501, show_progress = TRUE")
	obj$compute_lik_ratio_bootstrap_two_sided_pval = mk("compute_lik_ratio_bootstrap_two_sided_pval", "delta = 0, B = 199, show_progress = FALSE")
	obj$compute_lik_ratio_bootstrap_confidence_interval = mk("compute_lik_ratio_bootstrap_confidence_interval", "alpha = 0.05, B = 199, show_progress = FALSE")
	obj$compute_param_bootstrap_pval = mk("compute_param_bootstrap_pval", "delta, B = 199, show_progress = FALSE")
	obj$compute_param_bootstrap_confidence_interval = mk("compute_param_bootstrap_confidence_interval", "alpha = 0.05, B = 199, show_progress = FALSE")
	obj
}

expected_210 = list(
	rand = list(pval = "compute_rand_two_sided_pval", ci = "compute_rand_confidence_interval", formal = "r", count = "r"),
	rand_bootstrap = list(pval = "compute_rand_bootstrap_two_sided_pval", ci = "compute_rand_bootstrap_confidence_interval", formal = "B", count = "r"),
	bootstrap = list(pval = "compute_bootstrap_two_sided_pval", ci = "compute_bootstrap_confidence_interval", formal = "B", count = "B"),
	bayes_boot = list(pval = "compute_bayesian_bootstrap_two_sided_pval", ci = "compute_bayesian_bootstrap_confidence_interval", formal = "B", count = "B"),
	param_boot = list(pval = "compute_lik_ratio_bootstrap_two_sided_pval", ci = "compute_lik_ratio_bootstrap_confidence_interval", formal = "B", count = "B"),
	param_boot_direct = list(pval = "compute_param_bootstrap_pval", ci = "compute_param_bootstrap_confidence_interval", formal = "B", count = "B")
)

test_that("r reaches the randomization procedures and B the bootstrap procedures under their own names", {
	call_ci = getFromNamespace("run_all_inference_call_ci_for_method", "EDI")
	call_pv = getFromNamespace("run_all_inference_call_pval_for_method", "EDI")
	counts = list(r = 37L, B = 41L)
	for (m in names(expected_210)) {
		ex = expected_210[[m]]
		inf = fake_inf_210()
		call_pv(inf, m, resample_counts = counts)
		call_ci(inf, 0.05, m, resample_counts = counts)
		want = counts[[ex$count]]
		expect_identical(get(ex$pval, envir = inf$seen)[[ex$formal]], want, info = paste(m, "pval"))
		expect_identical(get(ex$ci, envir = inf$seen)[[ex$formal]], want, info = paste(m, "ci"))
	}
})

test_that("NULL counts (the default) leave every call at the method's own default", {
	call_ci = getFromNamespace("run_all_inference_call_ci_for_method", "EDI")
	call_pv = getFromNamespace("run_all_inference_call_pval_for_method", "EDI")
	for (m in names(expected_210)) {
		ex = expected_210[[m]]
		for (counts in list(NULL, list(r = NULL, B = NULL))) {
			inf = fake_inf_210()
			call_pv(inf, m, resample_counts = counts)
			call_ci(inf, 0.05, m, resample_counts = counts)
			default = eval(formals(inf[[ex$pval]])[[ex$formal]])
			expect_identical(get(ex$pval, envir = inf$seen)[[ex$formal]], default, info = m)
		}
	}
	args_fn = getFromNamespace("run_all_inference_resample_count_args", "EDI")
	expect_identical(args_fn(function(B = 1) NULL, "bootstrap", list(r = NULL, B = NULL)), list())
	expect_identical(args_fn(function(B = 1) NULL, "wald", list(r = 5L, B = 5L)), list())
	expect_identical(args_fn(function(...) NULL, "rand", list(r = 5L, B = NULL)), list(r = 5L))
	expect_identical(args_fn(function(alpha = 0.05) NULL, "bootstrap", list(r = NULL, B = 5L)), list())
})

suite_design_210 = function(n = 24L){
	set.seed(20261119)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(1 + 0.5 * des$get_w() + rnorm(n))
	des
}

test_that("run_all_inference threads r and B to the calls (sequential and fork-dispatch paths) and records them", {
	seen = list()
	orig_pv = getFromNamespace("run_all_inference_call_pval_for_method", "EDI")
	local_mocked_bindings(run_all_inference_call_pval_for_method = function(inf_obj, method, type = NA_character_, resample_counts = NULL){
		seen[[length(seen) + 1L]] <<- list(method = method, counts = resample_counts)
		orig_pv(inf_obj, method, type, resample_counts)
	}, .package = "EDI")
	withr::local_envvar(EDI_TESTING_DISABLE_FORK_CLUSTER = "true")
	for (cores in c(1L, 2L)) {
		seen = list()
		suite = InferenceSuite$new(suite_design_210())
		res = NULL
		utils::capture.output(res <- suppressWarnings(suppressMessages(suite$run_all_inference(
			screen = TRUE, html = FALSE, plots = FALSE, output_dir = tempdir(), num_cores = cores,
			classes = "InferenceAllSimpleAverageDiff", methods = c("rand", "bootstrap"), r = 23L, B = 29L))))
		expect_identical(res$resample_counts, list(r = 23L, B = 29L), info = paste("cores", cores))
		expect_setequal(vapply(seen, `[[`, "", "method"), c("rand", "bootstrap"))
		for (s in seen) expect_identical(s$counts, list(r = 23L, B = 29L), info = paste("cores", cores))
		rand_p = res$results_table$pval[res$results_table$method == "rand"]
		expect_true(all(is.finite(rand_p)), info = paste("cores", cores))
		expect_true(all(rand_p >= 2 / 23 - 1e-12), info = paste("cores", cores))   # floor 2 / r with r = 23
	}
	suite = InferenceSuite$new(suite_design_210())
	utils::capture.output(res <- suppressWarnings(suppressMessages(suite$run_all_inference(
		screen = TRUE, html = FALSE, plots = FALSE, output_dir = tempdir(),
		classes = "InferenceAllSimpleAverageDiff", methods = "wald"))))
	expect_identical(res$resample_counts, list(r = NULL, B = NULL))
})

test_that("r and B must be positive integers or NULL", {
	suite = InferenceSuite$new(suite_design_210())
	expect_error(suite$run_all_inference(screen = TRUE, plots = FALSE, methods = "wald", r = 0L), "r")
	expect_error(suite$run_all_inference(screen = TRUE, plots = FALSE, methods = "wald", B = 2.5), "B")
	expect_error(suite$run_all_inference(screen = TRUE, plots = FALSE, methods = "wald", B = c(10L, 20L)), "B")
})
