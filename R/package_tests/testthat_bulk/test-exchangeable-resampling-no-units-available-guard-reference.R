library(testthat)
library(EDI)

# inference_ext_exchangeable_resampling_units.R's sample_exchangeable_unit_ids() guards against an
# empty unit_info$units list ("No exchangeable units are available."). get_exchangeable_units()
# itself always builds at least one "observation" unit per subject when n > 0 (guarded separately by
# "Exchangeable resampling units are unavailable." for n <= 0, already covered elsewhere), so this
# specific empty-units guard is defensive against a degenerate cluster/block/pair unit_info (e.g. all
# block IDs filtered out as non-positive) rather than something the public API can trivially
# construct -- exercised the same way this session has tested other structurally-real-but-hard-to-
# reach guards: calling the private method directly with a hand-built empty unit_info. Zero test
# references anywhere.

test_that("sample_exchangeable_unit_ids(): an empty unit_info$units errors with the documented message", {
	set.seed(1)
	n <- 20L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(d, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	expect_error(
		priv$sample_exchangeable_unit_ids(list(units = list(), strata_ids = NULL), size = 5L, replace = FALSE),
		"No exchangeable units are available\\."
	)
})

test_that("sample_exchangeable_unit_ids(): a non-empty unit_info draws without error", {
	set.seed(2)
	n <- 20L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 2L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(d, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	unit_info <- priv$get_exchangeable_units("observation")
	expect_gt(unit_info$n_units, 0L)
	ids <- priv$sample_exchangeable_unit_ids(unit_info, size = 5L, replace = FALSE)
	expect_length(ids, 5L)
	expect_true(all(ids >= 1L & ids <= unit_info$n_units))
})
