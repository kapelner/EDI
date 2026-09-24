library(testthat)
library(EDI)

# InferenceAbstractKKRankRegrIVWC's initialize() (inference_survival_KK_rank_regr_ivwc_abstract.R)
# rejects construction on an incidence-response design before even reaching the survival-response-
# type assertion: "Rank-based regression is not recommended for incidence data; clogit and compound
# mean diff is recommended." A codebase-wide grep confirmed this exact message had zero test
# references anywhere -- distinct from the already-closed sibling guards on this same abstract class
# (the "Package 'aftgee' is required" guard, and "Testing non-zero delta is not yet implemented",
# closed in test-kk-rank-regr-ivwc-nonzero-delta-not-implemented-guard-reference.R). Exercised via
# the plain public constructor on the concrete leaf InferenceSurvivalKKRankRegrIVWC, no mocking
# needed: the refusal fires before any model fitting.

test_that("constructing on an incidence-response design is rejected with the documented message", {
	set.seed(1)
	n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))

	expect_error(
		InferenceSurvivalKKRankRegrIVWC$new(des, verbose = FALSE),
		"Rank-based regression is not recommended for incidence data; clogit and compound mean diff is recommended.",
		fixed = TRUE
	)
})
