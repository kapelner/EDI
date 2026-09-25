library(testthat)
library(EDI)

# DesignFixedRerandomization's draw_ws_raw() (design_fixed_rerandomization.R:189-219), on the C++
# parallel-rejection-sampler path (balanced prob_T = 0.5, even n), errors when the C++ search finds
# fewer than r acceptable allocations within max_draws -- "DesignFixedRerandomization could not
# find <r> acceptable allocation(s) within max_draws = <max_draws> draws (only <found> found).
# Loosen obj_val_cutoff or increase r's underlying search budget." This replaced dead shape/finite/
# balance validation the class used to run (rerandomization_search_cpp is trusted, per the source's
# own AllocationMatrixValidation comment) -- this is the one real remaining failure mode. A
# codebase-wide grep confirmed this exact message had zero test references anywhere. Reached with
# an obj_val_cutoff tight enough (1e-12) that essentially no random allocation can satisfy it,
# forcing the search to exhaust its draw budget -- fast in practice (the C++ rejection sampler
# completes its full max_draws search well within a couple of seconds for a small n).

test_that("an obj_val_cutoff too tight to satisfy raises the documented search-failure message", {
	set.seed(1)
	n <- 10L
	des <- DesignFixedRerandomization$new(response_type = "continuous", n = n, obj_val_cutoff = 1e-12, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))

	expect_error(
		des$assign_w_to_all_subjects(),
		"DesignFixedRerandomization could not find 1 acceptable allocation\\(s\\) within max_draws",
	)
})

test_that("an unconstrained cutoff (the default, Inf) never triggers the guard", {
	set.seed(2)
	n <- 10L
	des <- DesignFixedRerandomization$new(response_type = "continuous", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	expect_no_error(des$assign_w_to_all_subjects())
})
