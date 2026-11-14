# Owner request 2026-11-12 (v1.0.5 G4, survival regeneration batch 1): every
# comprehensive_tests.R case is seeded from its own key just before
# run_tests_for_response(). Before this the runner seeded once at the top, so a
# single-rep (REP_FILTER) job drew the first-rep stream whatever rep it was asked
# for: abalone survival "rep 9" .. "rep 15" came out byte-identical.
library(testthat)
library(EDI)

comprehensive_path <- testthat::test_path("..", "comprehensive_tests.R")
comprehensive_exprs <- parse(comprehensive_path)

case_seed_env <- function() {
	e <- new.env(parent = globalenv())
	for (expr in comprehensive_exprs) {
		if (is.call(expr) && identical(expr[[1L]], as.name("=")) && is.name(expr[[2L]]) &&
			as.character(expr[[2L]]) %in% c("coverage_truth_seed", "comprehensive_case_seed")) eval(expr, envir = e)
	}
	e
}

test_that("the per-case seed separates every component of the case key", {
	e <- case_seed_env()
	expect_true(is.function(e$comprehensive_case_seed))
	base <- list("abalone", 0, 9L, "survival", ~ 1, "Bernoulli", 0.5)
	s0 <- do.call(e$comprehensive_case_seed, base)
	expect_true(is.integer(s0) && length(s0) == 1L && !is.na(s0) && s0 >= 0L)
	expect_identical(do.call(e$comprehensive_case_seed, base), s0)
	variants <- list(
		list(1L, "diamonds"), list(2L, 0.5), list(3L, 10L), list(4L, "continuous"),
		list(5L, ~ .), list(6L, "FixediBCRD"), list(7L, 0.2))
	for (v in variants) {
		args <- base
		args[[v[[1L]]]] <- v[[2L]]
		expect_false(identical(do.call(e$comprehensive_case_seed, args), s0), info = paste("component", v[[1L]]))
	}
	reps <- vapply(1:50, function(r) e$comprehensive_case_seed("abalone", 0, r, "survival", ~ 1, "Bernoulli", 0.5), integer(1))
	expect_identical(anyDuplicated(reps), 0L)
})

test_that("the case loop seeds each case right before run_tests_for_response", {
	src <- readLines(comprehensive_path)
	call_line <- grep("run_tests_for_response(response_type, design_type = design_type", src, fixed = TRUE)
	expect_length(call_line, 1L)
	case_line <- grep("current_case_seed <<- comprehensive_case_seed(dataset_name, beta_T, rep_curr, response_type, model_formula, design_type, prob_T_curr)",
		src, fixed = TRUE)
	expect_length(case_line, 1L)
	seed_line <- grep("set.seed(current_case_seed)", src, fixed = TRUE)
	expect_length(seed_line, 1L)
	expect_identical(seed_line, case_line + 1L)
	# Only the tryCatch( opener may sit between the seed and the call.
	expect_true(seed_line < call_line && call_line - seed_line <= 2L)
})

# 2026-11-14 (release_v1_1_0.md TODO-194): each inference class reseeds from the
# case seed and its own identity, so a class-filtered shard reproduces the full
# loop's rows for that class (checked by running one case with a one-class and a
# three-class filter: all 140 rows identical).
test_that("every inference class reseeds from the case seed and its identity", {
	src <- readLines(comprehensive_path)
	def <- grep("^run_inference_checks = function", src)
	expect_length(def, 1L)
	expect_identical(trimws(src[def + 1L]), "if (!is.na(current_case_seed)) set.seed(comprehensive_class_seed(seq_des_inf, inference_label))")
	expect_length(grep("^comprehensive_class_seed = function", src), 1L)
})
