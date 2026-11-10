library(testthat)
library(EDI)

# v1.0.5 TODO-192: R/EDI/R/inference_procedure_regime.R maps every
# run_all_inference() sentinel label to "asymptotic" or "finite_sample". The
# registry is self-contained (the calibration publish job sources it without EDI
# installed), so it is sourced here from the checkout, and compared with the
# sentinel tables of the loaded package.

regime_repo_file = function(...) {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		f = file.path(dir, ...)
		if (file.exists(f)) return(f)
		dir = dirname(dir)
	}
	NA_character_
}
regime_file = regime_repo_file("R", "EDI", "R", "inference_procedure_regime.R")
sentinel_labels = function() {
	union(
		vapply(EDI:::EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY, `[[`, character(1L), "label"),
		vapply(EDI:::EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY, `[[`, character(1L), "label")
	)
}
load_regime = function() {
	env = new.env(parent = baseenv())
	sys.source(regime_file, envir = env)
	env
}

test_that("the registry file is found in the checkout", {
	expect_false(is.na(regime_file))
})

test_that("every sentinel label has a regime and every regime entry is a sentinel", {
	env = load_regime()
	labels = sentinel_labels()
	expect_equal(length(labels), 14L)
	expect_setequal(names(env$EDI_INFERENCE_PROCEDURE_REGIME), labels)
	expect_false(anyDuplicated(names(env$EDI_INFERENCE_PROCEDURE_REGIME)) > 0L)
})

test_that("regime values and the key procedures are classified as ruled", {
	env = load_regime()
	reg = env$EDI_INFERENCE_PROCEDURE_REGIME
	expect_identical(env$EDI_INFERENCE_PROCEDURE_REGIMES, c("asymptotic", "finite_sample"))
	expect_true(all(reg %in% env$EDI_INFERENCE_PROCEDURE_REGIMES))
	expect_identical(unname(reg[c("exact", "rand")]), c("finite_sample", "finite_sample"))
	expect_identical(unname(reg[c("wald", "score", "lik_ratio", "gradient")]), rep("asymptotic", 4L))
	# Resampling the data does not inherit the randomization test's exactness.
	expect_identical(unname(reg["rand_bootstrap"]), "asymptotic")
})

test_that("inference_procedure_regime() is vectorised and NA for unknown labels", {
	env = load_regime()
	out = env$inference_procedure_regime(c("rand", "wald", "no_such_procedure", "exact"))
	expect_identical(out, c("finite_sample", "asymptotic", NA_character_, "finite_sample"))
	expect_identical(env$inference_procedure_regime(character(0)), character(0))
})

test_that("the file sources into an empty environment with base R only", {
	# What the publish job does: no EDI, no packages beyond base.
	env = new.env(parent = baseenv())
	expect_no_error(sys.source(regime_file, envir = env))
	expect_true(all(c("EDI_INFERENCE_PROCEDURE_REGIMES", "EDI_INFERENCE_PROCEDURE_REGIME", "inference_procedure_regime") %in% ls(env)))
})

test_that("the loaded package carries the same table as the checkout file", {
	skip_if(!exists("EDI_INFERENCE_PROCEDURE_REGIME", envir = asNamespace("EDI"), inherits = FALSE),
		"installed EDI predates the registry")
	expect_identical(EDI:::EDI_INFERENCE_PROCEDURE_REGIME, load_regime()$EDI_INFERENCE_PROCEDURE_REGIME)
})
