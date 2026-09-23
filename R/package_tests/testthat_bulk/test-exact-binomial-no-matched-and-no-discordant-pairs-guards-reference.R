library(testthat)
library(EDI)

# InferenceIncidExactBinomial (inference_incidence_exact_binomial.R) has 3 sites, across its
# pval/CI/log-odds-ratio methods, that check the matched/discordant-pair counts returned by
# get_exact_binomial_stats() and cache a nonestimable reason when they're degenerate. None had a
# test reference anywhere:
#   1. pval_exact_binomial(): stats$m <= 0 (no matched pairs at all) -> "exact_binomial_no_matched_pairs".
#   2. ci_exact_binomial(): d_plus + d_minus <= 0 (matched pairs exist, none discordant) ->
#      "exact_binomial_no_discordant_pairs" (distinct from pval_exact_binomial's own handling of the
#      zero-discordant-pairs case, which returns a valid p-value of 1 rather than erroring -- so this
#      isn't simply the same degenerate input reused).
#   3. get_exact_binomial_log_or_estimate(): the same "no matched pairs" guard as (1).
# Reached by overriding the private get_exact_binomial_stats() (unlockBinding) to return a
# hand-built degenerate stats list directly, the same technique already used elsewhere in this suite
# for analogous unreachable-in-practice failure paths -- a real KK-matching-capable design is still
# constructed first (get_exact_binomial_stats() itself, i.e. the real matched-pair computation, is
# already exercised by other reference tests; this test targets only the 3 downstream guards).

exact_binomial_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * X$x1 + 0.5 * w)))
	InferenceIncidExactBinomial$new(des, verbose = FALSE)
}

test_that("pval_exact_binomial() is nonestimable with no matched pairs at all", {
	inf <- exact_binomial_fixture()
	p <- inf$.__enclos_env__$private
	unlockBinding("get_exact_binomial_stats", p)
	p$get_exact_binomial_stats <- function() list(m = 0L, d_plus = 0L, d_minus = 0L)

	res <- p$pval_exact_binomial(0)
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "exact_binomial_no_matched_pairs")
})

test_that("ci_exact_binomial() is nonestimable when matched pairs exist but none are discordant", {
	inf <- exact_binomial_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	unlockBinding("get_exact_binomial_stats", p)
	p$get_exact_binomial_stats <- function() list(m = 5L, d_plus = 0L, d_minus = 0L)

	res <- p$ci_exact_binomial(0.05)
	expect_true(all(is.na(res)))
	expect_identical(inf$get_nonestimable_reason(), "exact_binomial_no_discordant_pairs")
})

test_that("get_exact_binomial_log_or_estimate() is nonestimable with no matched pairs at all", {
	inf <- exact_binomial_fixture(seed = 3L)
	p <- inf$.__enclos_env__$private
	unlockBinding("get_exact_binomial_stats", p)
	p$get_exact_binomial_stats <- function() list(m = 0L, d_plus = 0L, d_minus = 0L)

	res <- p$get_exact_binomial_log_or_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "exact_binomial_no_matched_pairs")
})
