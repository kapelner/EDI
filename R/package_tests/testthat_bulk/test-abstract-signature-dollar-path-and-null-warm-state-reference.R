library(testthat)
library(EDI)

# InferenceAllAbstract's private stable_signature()/extract_dollar_paths()/
# resolve_dollar_path()/get_likelihood_null_warm_state()/
# set_likelihood_null_warm_state() are all pure, self-contained memoization-
# support helpers with zero prior test references anywhere in the suite
# (confirmed via repo-wide grep). Exercised here via direct private access on
# a minimal concrete inference object, matching the pattern already used
# elsewhere in this suite for abstract-base private methods.

make_min_inference <- function() {
	set.seed(1)
	n <- 20L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	InferenceAllSimpleAverageDiff$new(des)
}

test_that("stable_signature is deterministic, distinguishes differing objects, and reproduces its documented strided-hash formula", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private

	obj_a <- list(a = 1, b = 2)
	obj_b <- list(a = 1, b = 3)

	expect_identical(priv$stable_signature(obj_a), priv$stable_signature(obj_a))
	expect_false(identical(priv$stable_signature(obj_a), priv$stable_signature(obj_b)))

	# Independently reproduce the documented strided-subsample hash formula
	# from the source comment, byte for byte.
	ref_stable_signature <- function(obj) {
		raw_sig <- serialize(obj, NULL, xdr = FALSE)
		ints <- as.integer(raw_sig)
		n_ints <- length(ints)
		if (n_ints == 0L) return("0:0:0")
		modulus <- 2147483647
		step <- max(1L, floor(n_ints / 256L))
		idx <- unique(c(1L, seq.int(1L, n_ints, by = step), n_ints))
		sampled <- as.numeric(ints[idx])
		h1 <- as.integer(sum(sampled * (131 + idx %% 97)) %% modulus)
		h2 <- as.integer(sum((sampled + idx) * 65599) %% modulus)
		paste(n_ints, h1, h2, sep = ":")
	}

	for (candidate in list(obj_a, obj_b, list(1:500), "a longer string object for a bigger byte stream", NULL)) {
		expect_identical(priv$stable_signature(candidate), ref_stable_signature(candidate))
	}
})

test_that("resolve_dollar_path walks a chain of $-calls into a character vector and returns NULL for non-symbol roots", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private

	expect_identical(priv$resolve_dollar_path(quote(a$b$c)), c("a", "b", "c"))
	expect_identical(priv$resolve_dollar_path(quote(a$b)), c("a", "b"))
	expect_identical(priv$resolve_dollar_path(quote(a)), "a")
	# A non-symbol root (a function call) can't be resolved to a stable path.
	expect_null(priv$resolve_dollar_path(quote(f(x)$y)))
})

test_that("extract_dollar_paths recursively collects every $-chain in an expression, including nested sub-chains", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private

	paths <- priv$extract_dollar_paths(quote(a$b$c + d$e))
	# The full chain a$b$c is collected, but so is its nested sub-chain a$b
	# (the recursion descends into expr[[2]] of the outer $-call too) -- a
	# real, documented-by-behavior quirk, not asserted as a bug, just pinned.
	expect_length(paths, 3L)
	expect_true(any(vapply(paths, identical, logical(1), c("a", "b", "c"))))
	expect_true(any(vapply(paths, identical, logical(1), c("a", "b"))))
	expect_true(any(vapply(paths, identical, logical(1), c("d", "e"))))

	# An expression with no $-calls at all yields an empty list.
	expect_length(priv$extract_dollar_paths(quote(x + y)), 0L)
})

test_that("get/set_likelihood_null_warm_state round-trip a delta/start pair keyed by string, gated on null_fit_warm_start_enabled", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private

	# Nothing cached yet.
	expect_null(priv$get_likelihood_null_warm_state("k1"))

	priv$set_likelihood_null_warm_state("k1", 0.5, c(1, 2, 3))
	entry <- priv$get_likelihood_null_warm_state("k1")
	expect_equal(entry$delta, 0.5)
	expect_equal(entry$start, c(1, 2, 3))

	# A different key is untouched.
	expect_null(priv$get_likelihood_null_warm_state("k2"))

	# Overwriting the same key replaces rather than merges.
	priv$set_likelihood_null_warm_state("k1", -1.5, c(9))
	entry2 <- priv$get_likelihood_null_warm_state("k1")
	expect_equal(entry2$delta, -1.5)
	expect_equal(entry2$start, 9)

	# When the warm-start feature is disabled, both accessors are no-ops:
	# get returns NULL unconditionally, and set doesn't populate the cache
	# (verified by re-enabling afterward and confirming the key is still empty).
	priv$null_fit_warm_start_enabled <- FALSE
	expect_null(priv$get_likelihood_null_warm_state("k1"))
	priv$set_likelihood_null_warm_state("k3", 2, c(4, 5))
	priv$null_fit_warm_start_enabled <- TRUE
	expect_null(priv$get_likelihood_null_warm_state("k3"))
})
