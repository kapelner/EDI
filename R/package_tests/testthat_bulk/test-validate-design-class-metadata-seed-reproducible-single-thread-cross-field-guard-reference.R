library(testthat)
library(EDI)

# design_class_registry.R's validate_design_class_metadata() has a cross-field consistency guard
# beyond the per-field type/shape guards already closed in test-metadata-validators-field-type-
# guards-reference.R (parent/abstract/exported/seed_reproducible_draw): setting
# seed_reproducible_draw_requires_single_thread = TRUE while seed_reproducible_draw is not TRUE is
# nonsensical (the "requires single thread" flag only means anything when reproducibility from a
# seed is actually claimed) and is rejected -- "Design metadata for <name>:
# `seed_reproducible_draw_requires_single_thread` is only meaningful when `seed_reproducible_draw`
# is TRUE." A codebase-wide grep confirmed this exact message had zero test references anywhere.
# Reached by mutating a real, valid metadata record (the same technique the sibling file
# established), for a design that genuinely has seed_reproducible_draw = TRUE by default
# (DesignFixedBernoulli).

test_that("seed_reproducible_draw_requires_single_thread = TRUE with seed_reproducible_draw = FALSE is rejected", {
	valid <- EDI:::get_design_class_metadata("DesignFixedBernoulli")
	expect_true(valid$seed_reproducible_draw)

	bad <- valid
	bad$seed_reproducible_draw <- FALSE
	bad$seed_reproducible_draw_requires_single_thread <- TRUE

	expect_error(
		EDI:::validate_design_class_metadata(bad),
		"seed_reproducible_draw_requires_single_thread` is only meaningful when `seed_reproducible_draw` is TRUE",
	)
})

test_that("the real, unmodified DesignFixedBernoulli metadata validates silently", {
	valid <- EDI:::get_design_class_metadata("DesignFixedBernoulli")
	expect_true(EDI:::validate_design_class_metadata(valid))
})
