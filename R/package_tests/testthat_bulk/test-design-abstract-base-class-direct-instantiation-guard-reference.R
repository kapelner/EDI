library(testthat)
library(EDI)

# Design$initialize() (design_abstract.R) has a universal guard shared by every abstract Design base
# class: if class(self)[1] is registered abstract in the design class metadata registry
# (is_design_class_abstract()), it stop()s "<leaf_class> is an abstract Design base class and cannot
# be instantiated directly. Use a concrete subclass instead." before any other construction-time
# validation runs. Despite gating the base Design/DesignFixed/DesignSeqOneByOne classes -- and
# despite Design being the ancestor of every real design in the package -- this specific guard had
# zero test references anywhere; every existing test only ever constructs a concrete subclass.

test_that("constructing the base Design class directly errors with the documented message", {
	Design <- getFromNamespace("Design", "EDI")
	expect_error(
		Design$new(response_type = "continuous", n = 6L, verbose = FALSE),
		"Design is an abstract Design base class and cannot be instantiated directly\\. Use a concrete subclass instead\\."
	)
})

test_that("constructing DesignFixed directly errors with the documented message", {
	DesignFixed <- getFromNamespace("DesignFixed", "EDI")
	expect_error(
		DesignFixed$new(response_type = "continuous", n = 6L, verbose = FALSE),
		"DesignFixed is an abstract Design base class and cannot be instantiated directly\\."
	)
})

test_that("constructing DesignSeqOneByOne directly errors with the documented message", {
	DesignSeqOneByOne <- getFromNamespace("DesignSeqOneByOne", "EDI")
	expect_error(
		DesignSeqOneByOne$new(response_type = "continuous", verbose = FALSE),
		"DesignSeqOneByOne is an abstract Design base class and cannot be instantiated directly\\."
	)
})

test_that("constructing a real concrete subclass does not error", {
	expect_no_error(DesignFixedBernoulli$new(response_type = "continuous", n = 6L, verbose = FALSE))
})
