library(testthat)
library(EDI)

# set_package_threads() is only ever called as a side-effect setup helper
# in existing tests (setup-thread-limits.R, single-thread-metadata specs);
# its own contract -- the identical()-based short-circuit that skips the
# (relatively slow) Sys.setenv/BLAS-setter calls when re-invoked with the
# same core count, and what it actually sets when it does run -- has no
# dedicated test anywhere.

test_that("set_package_threads() sets the documented env vars and its own cache state, but never the user's options()", {
	on.exit({
		EDI:::set_package_threads(1L)
	}, add = TRUE)

	withr::local_options(mc.cores = NULL)
	options_before <- options()
	EDI:::set_package_threads(3L)
	expect_equal(Sys.getenv("OMP_NUM_THREADS"), "3")
	expect_equal(Sys.getenv("MKL_NUM_THREADS"), "3")
	expect_equal(Sys.getenv("OPENBLAS_NUM_THREADS"), "3")
	expect_equal(Sys.getenv("OMP_DYNAMIC"), "FALSE")
	expect_identical(options(), options_before)                      # CRAN: user's options untouched
	expect_equal(EDI:::edi_env$last_set_threads, 3L)
})

test_that("set_package_threads() short-circuits (skips its own env-setting work) when re-called with an identical core count", {
	on.exit({
		EDI:::set_package_threads(1L)
	}, add = TRUE)

	EDI:::set_package_threads(3L)
	# Clobber an env var set_package_threads() would normally overwrite, then
	# re-invoke with the SAME core count: if the short-circuit fires, the
	# clobbered value survives untouched.
	Sys.setenv(OMP_NUM_THREADS = "999")
	EDI:::set_package_threads(3L)
	expect_equal(Sys.getenv("OMP_NUM_THREADS"), "999")

	# A genuinely different core count still runs the full setter.
	EDI:::set_package_threads(4L)
	expect_equal(Sys.getenv("OMP_NUM_THREADS"), "4")
	expect_equal(EDI:::edi_env$last_set_threads, 4L)
})

test_that("set_package_threads() coerces a non-integer num_cores and treats the coerced value as identical for caching", {
	on.exit({
		EDI:::set_package_threads(1L)
	}, add = TRUE)

	EDI:::set_package_threads(2)
	expect_equal(EDI:::edi_env$last_set_threads, 2L)
	expect_true(is.integer(EDI:::edi_env$last_set_threads))

	Sys.setenv(OMP_NUM_THREADS = "999")
	# 2L (integer) should be identical() to the coerced-from-double 2 above,
	# so this should still short-circuit.
	EDI:::set_package_threads(2L)
	expect_equal(Sys.getenv("OMP_NUM_THREADS"), "999")
})
