library(testthat)
library(EDI)

source(test_path("..", "comprehensive_beta_filter.R"), local = TRUE)

test_that("an unfiltered run keeps the canonical beta sweep", {
	expect_identical(parse_comprehensive_beta_filter("NA"), NA_real_)
	expect_identical(
		resolve_comprehensive_beta_values(c(0, 0.5), NA_real_),
		c(0, 0.5)
	)
})

test_that("an explicit beta filter selects its value even outside the default sweep", {
	expect_identical(parse_comprehensive_beta_filter("0.3"), 0.3)
	expect_identical(resolve_comprehensive_beta_values(c(0, 0.5), 0.3), 0.3)
	expect_identical(resolve_comprehensive_beta_values(c(0, 0.5), 0.5), 0.5)
})

test_that("the runner wires positional argument 7 through to the beta loop", {
	runner_source = paste(
		readLines(test_path("..", "comprehensive_tests.R"), warn = FALSE),
		collapse = "\n"
	)
	# Keep this source-level contract separate from the helpers' value tests:
	# the full runner performs fits at top level, so source it only as text here.
	expect_match(
		runner_source,
		"BETA_T_FILTER = if \\(length\\(args\\) >= 7\\) parse_comprehensive_beta_filter\\(args\\[7\\]\\) else NA_real_"
	)
	expect_match(
		runner_source,
		"beta_T_values = resolve_comprehensive_beta_values\\(c\\(0, 0\\.5\\), BETA_T_FILTER\\)"
	)
	expect_match(
		runner_source,
		"for \\(beta_T_iter_curr in seq_along\\(beta_T_values\\)\\)\\{[[:space:]]*beta_T = beta_T_values\\[beta_T_iter_curr\\]"
	)

	args = c("1", "2", "continuous", "Bernoulli", "NA", "NA", "0.3")
	beta_filter = parse_comprehensive_beta_filter(args[7])
	expect_identical(beta_filter, 0.3)
	expect_identical(resolve_comprehensive_beta_values(c(0, 0.5), beta_filter), 0.3)

	args[7] = "nonsense"
	expect_error(parse_comprehensive_beta_filter(args[7]), "finite number")
})

test_that("malformed explicit beta filters fail closed", {
	expect_error(parse_comprehensive_beta_filter("nonsense"), "finite number")
	expect_error(parse_comprehensive_beta_filter("NaN"), "finite number")
	expect_error(resolve_comprehensive_beta_values(c(0, 0.5), Inf), "finite number")
})
