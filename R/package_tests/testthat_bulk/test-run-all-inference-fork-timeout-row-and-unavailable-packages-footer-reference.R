library(testthat)
library(EDI)

# Two standalone builders behind run_all_inference()'s results table and footer, checked directly against hand-derived expectations (no fitting needed):
#  * run_all_inference_fork_timeout_row(cls_name, design_family, response_type, max_secs_per_class, method, type): the placeholder row a fork worker's
#    force-kill produces -- status = "timeout", fit_secs = max_secs_per_class, every numeric/method/CI field NA, the documented message text, likelihood_tier
#    and estimand looked up (via get_inference_class_metadata()/run_all_inference_estimand()) but NA (not an error) for an unrecognized class, method/type
#    default to NA but pass through when supplied, and the field set is the same 21 names the fitted-row builders use (tau added by v1.0.6-TODO-179).
#  * run_all_inference_unavailable_footer_lines(unavailable_due_to_missing_packages): one "<class> - requires install.packages(<pkgs>)" line per named
#    entry, each package double-quoted and comma-separated in list order; empty input gives character(0).

ns <- asNamespace("EDI")
timeout_row <- get("run_all_inference_fork_timeout_row", envir = ns)
footer_lines <- get("run_all_inference_unavailable_footer_lines", envir = ns)

test_that("fork_timeout_row: status, fit_secs, message and every unfitted field are as documented", {
	r <- timeout_row("InferenceContinOLS", "fixed", "continuous", 30)
	expect_identical(r$status, "timeout")
	expect_identical(r$inference_class, "InferenceContinOLS")
	expect_identical(r$design_family, "fixed"); expect_identical(r$response_type, "continuous")
	expect_equal(r$fit_secs, 30)
	expect_identical(r$message, paste(
		"fork-cluster worker exceeded max_secs_per_class = 30 seconds and was force-killed",
		"(no response from the worker process, not a slow-but-alive R computation)"
	))
	for (fld in c("cov_model", "estimate", "se", "ci_a", "ci_b", "ci_method", "pval", "pval_method", "warnings")) {
		expect_true(is.na(r[[fld]]), info = fld)
	}
	expect_identical(r$method, NA_character_); expect_identical(r$type, NA_character_)
	expect_true(all(vapply(r$diagnostics, function(v) length(v) == 1L && is.na(v), NA)))
	expect_setequal(names(r), c("inference_class", "method", "type", "response_type", "design_family", "likelihood_tier", "cov_model",
		"estimate", "se", "ci_a", "ci_b", "ci_method", "pval", "pval_method", "estimand", "tau", "fit_secs", "warnings", "status", "message", "diagnostics"))
	# v1.0.6-TODO-179: tau was missing, so the results_table build failed on any timeout row
	expect_identical(r$tau, NA_real_)
})

test_that("fork_timeout_row: likelihood_tier and estimand are looked up from real class metadata; method/type pass through when supplied", {
	r <- timeout_row("InferenceContinOLS", "fixed", "continuous", 30)
	expect_identical(r$likelihood_tier, get("get_inference_class_metadata", envir = ns)("InferenceContinOLS")$likelihood_tier)
	expect_identical(r$estimand, get("run_all_inference_estimand", envir = ns)("InferenceContinOLS"))
	r2 <- timeout_row("InferenceContinOLS", "fixed", "continuous", 30, method = "bootstrap", type = "bca")
	expect_identical(r2$method, "bootstrap"); expect_identical(r2$type, "bca")
})

test_that("fork_timeout_row: an unrecognized class gives NA metadata (caught, never an error) rather than aborting the row", {
	r <- timeout_row("NotARealInferenceClass", "fixed", "continuous", 10)
	expect_identical(r$likelihood_tier, NA_character_); expect_identical(r$estimand, NA_character_)
	expect_identical(r$status, "timeout")                                       # the rest of the row still builds fine
})

test_that("unavailable_footer_lines: one line per named entry, packages double-quoted and comma-separated in list order", {
	lines <- footer_lines(setNames(list("betareg", c("VGAM", "survival")), c("InferencePropBetaRegr", "InferenceOrdinalX")))
	expect_identical(lines, c(
		'InferencePropBetaRegr - requires install.packages("betareg")',
		'InferenceOrdinalX - requires install.packages("VGAM", "survival")'
	))
	expect_identical(footer_lines(setNames(list("pkgA"), "ClsA")), 'ClsA - requires install.packages("pkgA")')
})

test_that("unavailable_footer_lines: empty input gives character(0)", {
	expect_identical(footer_lines(list()), character(0))
})

# v1.0.6-TODO-179 (docs-scenarios sequential-designs F5): with num_cores = 2 and max_secs_per_class,
# a fork-timeout row had no tau, and the results_table build failed with "arguments imply differing
# number of rows: 1, 0" after the report was printed, losing every result.
test_that("run_all_inference() returns every row when a fork worker times out", {
	skip_on_os("windows")
	skip_if(parallel::detectCores() < 2L, "needs 2 cores")
	set.seed(20261118)
	n = 60
	X = data.frame(age = round(rnorm(n, 55, 10)), severity = round(rnorm(n), 2))
	y0 = 0.05 * (X$age - 55) + 1.2 * X$severity + rnorm(n)
	d = DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, seed = 7041, verbose = FALSE)
	for (i in 1:n) {
		w = d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		d$add_one_subject_response(i, y0[i] + 0.6 * w)
	}
	suite = InferenceSuite$new(d)
	invisible(capture.output(res <- suppressWarnings(suite$run_all_inference(screen = TRUE, plots = FALSE,
		classes = "InferenceContinRobustRegr", num_cores = 2L, compute_conf_intervals = TRUE, max_secs_per_class = 3))))
	tab = res$results_table
	expect_setequal(tab$method, c("wald", "rand", "jackknife"))
	# the randomization test takes about a minute here, so its row is the forced timeout
	expect_identical(tab$status[tab$method == "rand"], "timeout")
	expect_true(is.na(tab$tau[tab$method == "rand"]))
	expect_identical(tab$status[tab$method == "wald"], "ok")
})
