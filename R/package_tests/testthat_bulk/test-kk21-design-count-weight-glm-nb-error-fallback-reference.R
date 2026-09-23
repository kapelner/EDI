library(testthat)
library(EDI)

# DesignSeqOneByOneKK21$compute_weight_KK21_count() (design_seq_one_by_one_KK21.R), non-speedup
# path, tries MASS::glm.nb() and only falls back to
# compute_weight_KK21_continuous(xs_to_date, log(ys_to_date + 1), ...) when the glm.nb() call
# itself raises an R error (the "nrow(summary) < 2" case is handled inline, inside the same
# tryCatch, and never reaches this fallback). The existing reference tests (test-kk21-design-
# generic-per-covariate-weight-reference.R's "non-speedup path" case and its survival/ordinal/count
# sibling) only exercise glm.nb()'s SUCCESS path on valid non-negative counts; the "glm.nb() itself
# errored" fallback branch had no test reference anywhere.
#
# glm.nb() genuinely raises "negative values not allowed for the 'Poisson' family" on a negative
# response (verified directly below, and confirmed non-hanging -- distinct from this suite's known
# glm.nb-on-constant-response hang), which drives execution past the tryCatch to the continuous
# fallback.

test_that("MASS::glm.nb errors on a negative-count response (confirmed non-hanging)", {
	x <- matrix(c(-0.5, 0.2, 1.1, -1.3, 0.7), 5, 1)
	y <- rep(-1, 5)
	expect_error(
		suppressWarnings(MASS::glm.nb(y ~ x, data = data.frame(x = x[, 1], y = y))),
		"negative values not allowed"
	)
})

test_that("compute_weight_KK21_count's non-speedup path falls back to compute_weight_KK21_continuous on a glm.nb() error", {
	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "count", count_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private

	set.seed(9)
	x <- matrix(rnorm(10), 10, 1)
	y <- rep(-1, 10)
	dd <- rep(1, 10)

	actual <- suppressWarnings(priv$compute_weight_KK21_count(x, y, dd, 1L))
	# independent reference: exactly what the fallback call computes directly
	ref <- priv$compute_weight_KK21_continuous(x, log(y + 1), dd, 1L)
	expect_equal(actual, ref)
})
