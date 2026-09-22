library(testthat)
library(EDI)

# run_all_inference_print_live_cov_key(cov_key): prints nothing (returns invisible(NULL), no output) when cov_key has length 0 (including NULL); otherwise
# prints a "Cov mod key:" header preceded by a blank line, then one '  (<value>)  "<name>"' line per entry, values and names taken verbatim (no formula
# re-deparsing -- the cov_key's own strings are printed as-is), in the input's own name order.

ns <- asNamespace("EDI")
print_key <- get("run_all_inference_print_live_cov_key", envir = ns)

test_that("an empty or NULL cov_key prints nothing and returns invisible(NULL)", {
	expect_identical(capture.output(r <- print_key(list())), character(0))
	expect_null(r)
	expect_identical(capture.output(r2 <- print_key(NULL)), character(0))
	expect_null(r2)
})

test_that("a non-empty cov_key prints a blank line, a header, and one line per entry in input order, verbatim", {
	out <- capture.output(print_key(list(A = "~ x1 + x2", B = "~ .")))
	expect_identical(out, c("", "Cov mod key:", '  (~ x1 + x2)  "A"', '  (~ .)  "B"'))
})

test_that("entries are printed in the list's own order, even when that differs from alphabetical, and a single entry works", {
	out <- capture.output(print_key(list(Z = "~ zed", A = "~ ay")))
	expect_identical(out, c("", "Cov mod key:", '  (~ zed)  "Z"', '  (~ ay)  "A"'))
	out2 <- capture.output(print_key(list(Solo = "~ .")))
	expect_identical(out2, c("", "Cov mod key:", '  (~ .)  "Solo"'))
})

test_that("the value string is printed verbatim, even one containing quotes or parentheses -- no escaping or re-deparsing", {
	out <- capture.output(print_key(list(X = 'formula(y ~ x, data = "foo")')))
	expect_identical(out, c("", "Cov mod key:", '  (formula(y ~ x, data = "foo"))  "X"'))
})
