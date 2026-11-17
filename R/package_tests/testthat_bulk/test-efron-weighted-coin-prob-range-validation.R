library(testthat)
library(EDI)

# v1.0.6-TODO-70 (GitHub issue #28): DesignSeqOneByOneEfron documented weighted_coin_prob > 0.5
# but never checked it. Efron (1971) defines the biased coin for p > 1/2; p = 1 is the
# deterministic limit (the under-represented arm always gets the next subject) and existing
# tests rely on it, so the constructor accepts 0.5 < p <= 1 and rejects everything else.

efron = function(p, ...) DesignSeqOneByOneEfron$new(response_type = "continuous", n = 10L, weighted_coin_prob = p, verbose = FALSE, ...)

test_that("weighted_coin_prob outside (0.5, 1] is rejected at construction", {
	for (bad in list(0.5, 0.4, 0, -0.2, 1 + 1e-9, 2, NA_real_, NaN, Inf, c(0.6, 0.7), "0.7", NULL)) {
		expect_error(efron(bad), "weighted_coin_prob must be a single number with 0.5 < weighted_coin_prob <= 1",
			info = paste(deparse(bad), collapse = ""))
	}
})

test_that("values in (0.5, 1] are accepted, the default is Efron's 2/3, and p = 1 is deterministic when imbalanced", {
	for (ok in c(0.5 + 1e-9, 0.6, 0.75, 1)) {
		expect_identical(efron(ok)$.__enclos_env__$private$weighted_coin_prob, ok)
	}
	des = DesignSeqOneByOneEfron$new(response_type = "continuous", n = 10L, verbose = FALSE)
	expect_identical(des$.__enclos_env__$private$weighted_coin_prob, 2 / 3)
	# p = 1: the running counts never differ by more than one
	W = efron(1, seed = 4L)$.__enclos_env__$private$draw_ws_raw(r = 50L)
	expect_true(all(apply(W, 2, function(w) max(abs(cumsum(2 * w - 1)))) <= 1))
})
