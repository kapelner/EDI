library(testthat)
library(EDI)

# inference_component_source_parts() (contracts_mixins.R) has three branches: (1) an R6ClassGenerator
# source, whose public_methods/private_methods/private_fields are extracted (with the auto-generated
# 'clone' method stripped from public); (2) a plain list(public =, private =) source, used verbatim;
# (3) anything else raises "Inference component source must be an R6 generator or public/private
# list." A codebase-wide grep confirmed this exact error message had zero test references anywhere --
# the function's only direct caller in the test suite (test-mixin-contracts.R) always passes a
# well-formed real component source, and the other references to the function name are comments, never
# exercising branch 3 or independently verifying branches 1/2's own extraction contract (the 'clone'
# stripping in particular).

test_that("an R6ClassGenerator source extracts public_methods (with 'clone' stripped) and private_methods/private_fields", {
	gen <- R6::R6Class("EdiTestComponentSourceGen",
		public = list(bar = function() 1),
		private = list(baz = 2)
	)
	out <- EDI:::inference_component_source_parts(gen)
	expect_identical(names(out$public), "bar")
	expect_false("clone" %in% names(out$public))
	expect_identical(names(out$private), "baz")
})

test_that("a plain list(public =, private =) source is used verbatim", {
	src <- list(public = list(bar = function() 1), private = list(baz = 2))
	out <- EDI:::inference_component_source_parts(src)
	expect_identical(names(out$public), "bar")
	expect_identical(names(out$private), "baz")
})

test_that("anything else raises the documented guard message", {
	expect_error(
		EDI:::inference_component_source_parts(list(foo = 1)),
		"Inference component source must be an R6 generator or public/private list.",
		fixed = TRUE
	)
	expect_error(
		EDI:::inference_component_source_parts(5),
		"Inference component source must be an R6 generator or public/private list.",
		fixed = TRUE
	)
	expect_error(
		EDI:::inference_component_source_parts(NULL),
		"Inference component source must be an R6 generator or public/private list.",
		fixed = TRUE
	)
})
