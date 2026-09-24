library(testthat)
library(EDI)

# contracts_resampling_draws.R's top-level reused_worker_cached_values_for_next_draw() had no test
# reference anywhere by name -- confirmed via a fresh repo-wide scan of every top-level free function.
# It's the pure filtering step at the heart of the reused-worker randomization/bootstrap machinery
# (invoked once per draw to decide what a fresh worker clone inherits from the source's cached_values):
# every "reused worker" test in the suite exercises the surrounding machinery through the public API,
# but none calls this specific pure function directly with a controlled input.
#   1. With the default preserve_cache_keys, only EDI_REUSED_WORKER_CACHE_KEEP_KEYS ("m_cache",
#      "t0s_rand") survive, and only when present and non-NULL in the input; every other key is
#      dropped.
#   2. Extra preserve_cache_keys are kept too, alongside the default set.
#   3. A key present in the keep set but whose value is NULL is still dropped (not carried through as
#      a NULL entry).
#   4. A key entirely absent from cached_values is simply absent from the result -- no error.
#   5. Duplicate/overlapping preserve_cache_keys (including ones already in the default set) don't
#      produce duplicate output entries or errors.
#   6. An empty cached_values list returns an empty list.

f <- EDI:::reused_worker_cached_values_for_next_draw

test_that("with the default preserve_cache_keys, only the two default keep-keys survive, and only when present and non-NULL", {
	cv <- list(m_cache = 1, t0s_rand = 2, other_thing = 3, another = "x")
	expect_identical(f(cv), list(m_cache = 1, t0s_rand = 2))
})

test_that("extra preserve_cache_keys are kept too, alongside the default set", {
	cv <- list(m_cache = 1, t0s_rand = 2, custom_key = "kept", unrelated = "dropped")
	expect_identical(f(cv, preserve_cache_keys = "custom_key"), list(m_cache = 1, t0s_rand = 2, custom_key = "kept"))
})

test_that("a key present in the keep set but whose value is NULL is still dropped, not carried through as NULL", {
	cv <- list(m_cache = NULL, t0s_rand = 5)
	expect_identical(f(cv), list(t0s_rand = 5))
	expect_false("m_cache" %in% names(f(cv)))
})

test_that("a key entirely absent from cached_values is simply absent from the result, no error", {
	cv <- list(t0s_rand = 7)
	res <- f(cv, preserve_cache_keys = "never_present")
	expect_identical(res, list(t0s_rand = 7))
})

test_that("duplicate/overlapping preserve_cache_keys don't produce duplicate output entries or errors", {
	cv <- list(m_cache = 1, t0s_rand = 2, custom_key = "kept")
	res <- f(cv, preserve_cache_keys = c("m_cache", "custom_key", "custom_key", "t0s_rand"))
	expect_identical(res, list(m_cache = 1, t0s_rand = 2, custom_key = "kept"))
	expect_length(res, 3L)
})

test_that("an empty cached_values list returns an empty list", {
	expect_identical(f(list()), list())
	expect_identical(f(list(), preserve_cache_keys = "anything"), list())
})
