library(testthat)
library(EDI)

# Three well-tested design classes each require even/divisible-by-4 sample sizes or balanced allocation, but none
# of these five specific argument-validation guards had a test triggering them (only their normal, valid-input
# paths were exercised elsewhere): ObservationalDesignMatching$new() requires an even n (constructed-time);
# DesignFixedMatchingGreedyPairSwitching$new() requires prob_T = 0.5 (construction-time) and, separately,
# draw_ws_raw() (reached via assign_w_to_all_subjects()) requires n divisible by 4; DesignFixedGreedy's
# draw_ws_raw() requires an even n -- both of the latter two are checked lazily at assignment time, not
# construction, since draw_ws_raw()'s own n %% ... check is what fires (the constructors accept any n).

test_that("ObservationalDesignMatching rejects an odd n at construction", {
	expect_error(
		ObservationalDesignMatching$new(response_type = "continuous", n = 7L, verbose = FALSE),
		"ObservationalDesignMatching requires an even n \\(subjects are organized into pairs\\)\\."
	)
	expect_no_error(ObservationalDesignMatching$new(response_type = "continuous", n = 8L, verbose = FALSE))
})

test_that("DesignFixedMatchingGreedyPairSwitching rejects prob_T != 0.5 at construction", {
	expect_error(
		DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", prob_T = 0.4, n = 8L, verbose = FALSE),
		"DesignFixedMatchingGreedyPairSwitching only supports balanced designs \\(prob_T = 0.5\\)\\."
	)
})

test_that("DesignFixedMatchingGreedyPairSwitching rejects n not divisible by 4, only once assignment is actually requested", {
	des <- DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", n = 6L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
	expect_error(
		des$assign_w_to_all_subjects(),
		"DesignFixedMatchingGreedyPairSwitching requires n divisible by 4\\."
	)

	des2 <- DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", n = 8L, verbose = FALSE)
	des2$add_all_subjects_to_experiment(data.frame(x1 = rnorm(8)))
	w2 <- des2$assign_w_to_all_subjects()
	expect_length(w2, 8L)
})

test_that("DesignFixedGreedy rejects an odd n, only once assignment is actually requested (construction itself accepts any n)", {
	des <- DesignFixedGreedy$new(response_type = "continuous", n = 7L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(7)))
	expect_error(
		des$assign_w_to_all_subjects(),
		"DesignFixedGreedy requires an even number of subjects\\."
	)

	des2 <- DesignFixedGreedy$new(response_type = "continuous", n = 8L, verbose = FALSE)
	des2$add_all_subjects_to_experiment(data.frame(x1 = rnorm(8)))
	w2 <- des2$assign_w_to_all_subjects()
	expect_length(w2, 8L)
	expect_equal(sum(w2 == 1), 4L)                                        # balanced within the pair-switching kernel
})
