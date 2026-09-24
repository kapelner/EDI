library(testthat)
library(EDI)

# Design$add_one_subject_response(t, y, y_L, y_R) (design_abstract.R) validates the
# exact-vs-censored response shape with four guards: (1) both y and (y_L, y_R) supplied
# together is rejected, (2) neither supplied is rejected, (3) a finite y_L < 0 is rejected,
# (4) y_R <= y_L is rejected. These are documented as "always enforced, never gated behind
# should_run_asserts()" (interval_censored_survival_response.md TODO-1a/TODO-2), since a bad
# row slipping through would later be silently misread by get_effective_time()/
# get_effective_dead(). A codebase-wide grep confirmed all four messages had zero test
# references anywhere -- the corresponding BULK sibling (add_all_subject_responses()'s
# equivalent y_Ls/y_Rs-pairing guards) is already covered, but the single-subject method
# was not. Exercised on a real DesignSeqOneByOneBernoulli survival design via the plain
# public API, no mocking needed.

fx <- function() {
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "survival", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1))
	des
}

test_that("supplying both y and (y_L, y_R) together is rejected", {
	des <- fx()
	expect_error(
		des$add_one_subject_response(1, y = 2, y_L = 1, y_R = 3),
		"Supply either y (exact response) or both y_L and y_R (censored response), not both.",
		fixed = TRUE
	)
})

test_that("supplying neither y nor (y_L, y_R) is rejected", {
	des <- fx()
	expect_error(
		des$add_one_subject_response(1),
		"You must supply either y (exact response) or both y_L and y_R (censored response).",
		fixed = TRUE
	)
})

test_that("a negative y_L is rejected", {
	des <- fx()
	expect_error(
		des$add_one_subject_response(1, y_L = -1, y_R = 3),
		"y_L must be finite and >= 0.",
		fixed = TRUE
	)
})

test_that("a non-finite y_L is rejected by the same guard", {
	des <- fx()
	expect_error(
		des$add_one_subject_response(1, y_L = Inf, y_R = Inf),
		"y_L must be finite and >= 0.",
		fixed = TRUE
	)
})

test_that("y_R <= y_L is rejected", {
	des <- fx()
	expect_error(
		des$add_one_subject_response(1, y_L = 3, y_R = 2),
		"y_R must be strictly greater than y_L.",
		fixed = TRUE
	)
	expect_error(
		des$add_one_subject_response(1, y_L = 3, y_R = 3),
		"y_R must be strictly greater than y_L.",
		fixed = TRUE
	)
})

test_that("a well-formed censored response is accepted without error", {
	des <- fx()
	expect_silent(des$add_one_subject_response(1, y_L = 1, y_R = 3))
})
