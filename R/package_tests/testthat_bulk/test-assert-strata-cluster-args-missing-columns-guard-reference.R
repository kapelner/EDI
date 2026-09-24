library(testthat)
library(EDI)

# helper_additional_asserts.R's assertStrataClusterArgs(strata_cols, cluster_col, data, ...) has a
# missing-columns guard distinct from its already-covered sibling ("cluster_col must not also
# appear in strata_cols"): when `data` is supplied, every named strata_cols/cluster_col must
# actually be present in it, or it stops with "<context> references column(s) not present in the
# supplied covariates: <missing>." A codebase-wide grep confirmed this exact message had zero test
# references anywhere, despite assertStrataClusterArgs() itself being widely exercised (5 existing
# test files) -- those exercise the other three guards (the character/length shape checks, the
# cluster-in-strata overlap check, the categorical-column check) but never this one. Exercised via
# a direct namespace call, no Design/Inference fixture needed -- a lightweight, pure-function
# target chosen deliberately given this machine's current load (a heavier InferenceSuite pipeline
# fixture attempted earlier this iteration was abandoned after timing out under contention from
# other concurrent sessions).

test_that("assertStrataClusterArgs() rejects strata_cols/cluster_col not present in the supplied data, naming every missing column", {
	f <- getFromNamespace("assertStrataClusterArgs", "EDI")
	expect_error(
		f(strata_cols = c("a", "b"), cluster_col = "c", data = data.frame(a = 1, x = 2), context = "unit test"),
		"unit test references column\\(s\\) not present in the supplied covariates: b, c\\.",
	)
})

test_that("assertStrataClusterArgs() passes silently when every named column is present in the data", {
	f <- getFromNamespace("assertStrataClusterArgs", "EDI")
	expect_null(f(strata_cols = c("a", "b"), cluster_col = "c", data = data.frame(a = 1, b = 2, c = 3), context = "unit test"))
})

test_that("assertStrataClusterArgs() is a no-op when data is NULL, even with columns that would otherwise be missing", {
	f <- getFromNamespace("assertStrataClusterArgs", "EDI")
	expect_null(f(strata_cols = c("a", "b"), cluster_col = "c", data = NULL, context = "unit test"))
})
