library(testthat)
library(EDI)

# contracts_mixins.R's entry_kinds(entries): classifies each named entry of a component's
# public/private slot list as "method" (a function) or "state" (anything else) -- the
# distinction combine_component_slot() uses to decide whether a name collision across
# mixed-in components/host overrides is allowed (state names may be shared/aggregated,
# method names may not). Used only internally by combine_component_slot() (assemble_public/
# assemble_private's own callers), which is itself only exercised end-to-end via
# define_inference_class()/component composition -- entry_kinds()'s own name<->kind mapping,
# and its empty-input and non-function-state-value branches, had no direct test anywhere.

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("entry_kinds returns an empty named character vector for an empty list", {
	r <- K("entry_kinds")(list())
	expect_type(r, "character")
	expect_length(r, 0L)
})

test_that("entry_kinds classifies functions as \"method\" and everything else as \"state\", preserving names", {
	entries <- list(
		a_number = 1,
		a_string = "x",
		a_list = list(1, 2),
		a_null = NULL,
		a_fn = function(x) x,
		another_fn = mean
	)
	r <- K("entry_kinds")(entries)
	expect_identical(names(r), names(entries))
	expect_identical(unname(r), c("state", "state", "state", "state", "method", "method"))
})

test_that("entry_kinds treats every entry of a single-kind list uniformly", {
	all_state <- K("entry_kinds")(list(x = 1, y = "two", z = TRUE))
	expect_true(all(all_state == "state"))

	all_method <- K("entry_kinds")(list(f = function() 1, g = function() 2))
	expect_true(all(all_method == "method"))
})

test_that("entry_kinds distinguishes a bound R6-style method from a same-named data field", {
	# Mirrors the shape combine_component_slot() feeds it: a component's own
	# already-resolved public/private list (functions and plain values side by side).
	fake_component_private = list(
		max_iter = 100L,
		tolerance = 1e-8,
		fit_impl = function(X, y) NULL,
		validate_inputs = function(X) TRUE
	)
	r <- K("entry_kinds")(fake_component_private)
	expect_identical(r[["max_iter"]], "state")
	expect_identical(r[["tolerance"]], "state")
	expect_identical(r[["fit_impl"]], "method")
	expect_identical(r[["validate_inputs"]], "method")
})
