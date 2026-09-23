library(testthat)
library(EDI)

# mean_cpp/var_cpp (_helper_functions.cpp) have documented NA edge cases distinct from their
# already-tested normal-input path (test-poisson-probit-kernels-hodges-lehmann-and-missingness-
# utility-reference.R uses only a random length-20 vector): mean_cpp returns NA for an empty input,
# and var_cpp returns NA for any input of length <= 1 (including empty). Neither edge case had a
# test reference anywhere. Reference: base R's own mean()/var() give the identical NA results for
# these same inputs.

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("mean_cpp returns NA for an empty vector, matching base R's mean(numeric(0))", {
	expect_true(is.na(K("mean_cpp")(numeric(0))))
	expect_true(is.na(mean(numeric(0))))
})

test_that("var_cpp returns NA for an empty or length-one vector, matching base R's var()", {
	expect_true(is.na(K("var_cpp")(numeric(0))))
	expect_true(is.na(var(numeric(0))))
	expect_true(is.na(K("var_cpp")(5)))
	expect_true(is.na(var(5)))
	expect_true(is.na(K("var_cpp")(-3.2)))
})

test_that("mean_cpp on a singleton is unaffected (only var_cpp has the length-1 guard)", {
	expect_equal(K("mean_cpp")(5), 5)
	expect_equal(K("mean_cpp")(-3.2), -3.2)
})
