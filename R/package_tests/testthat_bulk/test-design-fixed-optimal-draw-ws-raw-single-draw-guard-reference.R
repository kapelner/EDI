library(testthat)
library(EDI)

# DesignFixedOptimal's private draw_ws_raw(r) rejects any r != 1: "DesignFixedOptimal computes
# exactly one optimal allocation; r > 1 draws are not a randomization distribution and are
# forbidden (randomization tests/CIs are fenced upstream via supports(\"randomization_draw\") =
# FALSE)." A deliberate, always-on design invariant -- since the whole point of the optimal design
# is a single deterministic (solver-chosen) allocation, not a randomization distribution -- but had
# zero test references anywhere.

test_that("draw_ws_raw(r = 2) errors with the documented message", {
	set.seed(1)
	n <- 10L
	des <- DesignFixedOptimal$new(response_type = "continuous", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	priv <- des$.__enclos_env__$private

	expect_error(
		priv$draw_ws_raw(r = 2L),
		"DesignFixedOptimal computes exactly one optimal allocation; r > 1 draws are not a randomization distribution and are forbidden"
	)
})

test_that("draw_ws_raw(r = 1) (the default) does not error", {
	set.seed(2)
	n <- 10L
	des <- DesignFixedOptimal$new(response_type = "continuous", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	priv <- des$.__enclos_env__$private

	expect_no_error(priv$draw_ws_raw(r = 1L))
})
