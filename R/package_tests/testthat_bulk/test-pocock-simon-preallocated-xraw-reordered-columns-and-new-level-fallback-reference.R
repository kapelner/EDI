# Untested-code audit, 2026-11-24: covers R/EDI/R/design_seq_one_by_one_abstract.R:216-227
# (add_one_subject; region unt-8703a3c6983f).
# Reference: A data frame of the entered subjects built by hand in plain R: by-name column matching,
# the union of factor levels, and t rows with no leftover preallocated rows after the fallback.
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 10 of 10
# target lines (5.7 s).

library(testthat)
library(EDI)

test_that("Pocock-Simon preallocated covariate table fills reordered columns by name and falls back to rbind on a new factor level", {
	n = 6L
	des = DesignSeqOneByOnePocockSimon$new(strata_cols = "x1", n = n, response_type = "continuous")
	priv = des$.__enclos_env__$private

	# subject 1: establishes the schema and preallocates n rows
	des$add_one_subject(data.frame(x1 = factor("a"), x2 = 1.5))
	expect_true(isTRUE(priv$Xraw_preallocated))
	expect_identical(nrow(priv$Xraw), n)

	# subject 2: same columns in a different order, known level -> filled by name in place
	des$add_one_subject(data.frame(x2 = -2, x1 = factor("a")))
	X2 = as.data.frame(des$get_X_raw())
	expect_identical(des$get_t(), 2L)
	expect_identical(names(X2), c("x1", "x2"))
	expect_identical(as.character(X2$x1), c("a", "a"))
	expect_equal(X2$x2, c(1.5, -2), tolerance = 0)
	expect_true(isTRUE(priv$Xraw_preallocated))
	expect_identical(nrow(priv$Xraw), n)

	# subject 3: a factor level never seen in the preallocated column -> rbind fallback
	des$add_one_subject(data.frame(x1 = factor("b"), x2 = 0.25))
	expect_false(isTRUE(priv$Xraw_preallocated))
	expect_identical(nrow(priv$Xraw), 3L)

	# subject 4: ordinary append after the fallback
	des$add_one_subject(data.frame(x1 = factor("a"), x2 = 4))

	# reference: the rows exactly as entered, built in plain R
	expected = data.frame(x1 = factor(c("a", "a", "b", "a"), levels = c("a", "b")), x2 = c(1.5, -2, 0.25, 4))
	X = as.data.frame(des$get_X_raw())
	expect_identical(des$get_t(), 4L)
	expect_identical(names(X), names(expected))
	expect_identical(as.character(X$x1), as.character(expected$x1))
	expect_true(is.factor(X$x1))
	expect_setequal(levels(X$x1), levels(expected$x1))
	expect_equal(X$x2, expected$x2, tolerance = 0)
	expect_identical(nrow(priv$Xraw), 4L)
})
