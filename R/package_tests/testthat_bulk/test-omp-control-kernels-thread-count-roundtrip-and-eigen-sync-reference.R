library(testthat)
library(EDI)

# set_omp_num_threads_cpp / get_omp_max_threads_cpp: the OpenMP thread count round-trips (when built with OpenMP),
# falls back to 1 otherwise. Original state is restored on exit.

E <- asNamespace("EDI")
setn <- get("set_omp_num_threads_cpp", E); getn <- get("get_omp_max_threads_cpp", E)
orig <- getn()
withr::defer(setn(orig), teardown_env())

has_omp <- orig >= 1L   # both builds return >= 1
omp_enabled <- {
	setn(2L); r <- getn(); setn(orig); r == 2L
}

test_that("the getter returns a positive integer", {
	expect_type(getn(), "integer")
	expect_length(getn(), 1L)
	expect_gte(getn(), 1L)
})

test_that("setter/getter round-trip on OpenMP builds; non-OpenMP builds always report 1", {
	if (omp_enabled) {
		for (k in c(1L, 2L, 3L, 1L)) { setn(k); expect_identical(getn(), k) }
	} else {
		for (k in c(1L, 2L, 4L)) { setn(k); expect_identical(getn(), 1L) }
	}
	setn(orig); expect_identical(getn(), if (omp_enabled) orig else 1L)
})

test_that("the setter returns invisibly NULL and is repeatable", {
	expect_null(setn(1L))
	expect_invisible(setn(1L))
	setn(1L); setn(1L); expect_identical(getn(), 1L)
})

test_that("the setter's effect is visible to the R-level package-threads helper when it exists", {
	skip_if_not(exists("set_package_threads", envir = E, mode = "function"))
	setn(1L)
	fn <- get("set_package_threads", envir = E)
	expect_no_error(suppressMessages(try(fn(1L), silent = TRUE)))
	expect_identical(getn(), 1L)
})
