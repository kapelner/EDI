library(testthat)
library(EDI)

# 2026-10-11: moved here from R/EDI/tests/testthat/ -- this file's
# gctorture(TRUE) regression test alone took 692.9s (89% of the entire
# local pre-push test suite's 867s total), since gctorture forces a full GC
# on every single allocation. It still runs via the sharded correctness/
# coverage CI tiers from here; it just no longer dominates every local
# pre-push run or R CMD check invocation.
#
# 2026-10-11: skipped under R_COVR (covr's own env var, same pattern as
# test-parametric-bootstrap-lr.R's "avoid ... under covr's gcov-instrumented
# build") -- gctorture(TRUE) forces a GC on every allocation, and covr's
# line-by-line tracing instrumentation multiplies allocation count per line;
# combined, this hung an entire coverage shard for the full 75-minute job
# timeout (run 38104981120, shard 71, zero test files completed) rather than
# the ~690s this test takes normally. The correctness tier (plain testthat,
# no covr instrumentation) is unaffected and still runs it.

kk21_weight_source_dir = function() {
	candidates = c(
		file.path("R", "EDI", "src"),
		file.path("..", "..", "src"),
		file.path("..", "src"),
		"src"
	)
	hit = candidates[dir.exists(candidates)]
	if (!length(hit)) return(NA_character_)
	hit[[1L]]
}

test_that("native R callbacks do not pass freshly wrapped objects inline", {
	src_dir = kk21_weight_source_dir()
	skip_if(is.na(src_dir), "native source tree is unavailable")
	paths = list.files(src_dir, pattern = "\\.(cpp|h)$", recursive = TRUE, full.names = TRUE)
	source_text = paste(vapply(paths, function(path) {
		paste(readLines(path, warn = FALSE), collapse = "\n")
	}, character(1L)), collapse = "\n")
	kk21_text = paste(readLines(file.path(src_dir, "kk21_weights.cpp"), warn = FALSE), collapse = "\n")

	expect_match(kk21_text, "NumericMatrix Xs = wrap(X);", fixed = TRUE)
	expect_match(kk21_text, "NumericVector ys = wrap(y);", fixed = TRUE)
	expect_match(kk21_text, "List res = f(Xs, ys);", fixed = TRUE)
	expect_false(grepl("\\b[A-Za-z_][A-Za-z0-9_]*\\s*\\(\\s*wrap\\s*\\(", source_text, perl = TRUE))
})

test_that("KK21 ordinal weight callbacks keep wrapped arguments alive under gctorture", {
	skip_if(
		identical(Sys.getenv("R_COVR"), "true"),
		"gctorture(TRUE) under covr's line-tracing instrumentation is catastrophically slow, not just slow"
	)
	set.seed(404)
	n <- 40L
	X <- matrix(rnorm(n * 3L), n, 3L)
	y <- as.numeric(cut(0.8 * X[, 1L] + rlogis(n), c(-Inf, -1.2, 0, 1.2, Inf), labels = FALSE))
	ordinal_weights <- get("kk21_ordinal_weights_cpp", envir = asNamespace("EDI"))
	stepwise_weights <- get("kk21_stepwise_ordinal_weights_cpp", envir = asNamespace("EDI"))
	ordinal_fit <- get("fast_ordinal_regression_with_var_cpp", envir = asNamespace("EDI"))

	baseline <- ordinal_weights(X, y)
	baseline_stepwise <- stepwise_weights(X, y, rep(c(0, 1), length.out = n))
	fit <- ordinal_fit(X[, 1L, drop = FALSE], y)
	expect_equal(baseline[1L], abs(fit$b[1L] / sqrt(fit$ssq_b_j)), tolerance = 1e-10)

	gctorture(TRUE)
	on.exit(gctorture(FALSE), add = TRUE)
	under_gc <- ordinal_weights(X, y)
	under_gc_stepwise <- stepwise_weights(X, y, rep(c(0, 1), length.out = n))
	expect_true(all(is.finite(under_gc)))
	expect_true(all(is.finite(under_gc_stepwise)))
	expect_equal(under_gc, baseline, tolerance = 1e-10)
	expect_equal(under_gc_stepwise, baseline_stepwise, tolerance = 1e-10)
})
