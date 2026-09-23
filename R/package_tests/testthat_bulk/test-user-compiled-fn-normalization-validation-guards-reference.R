library(testthat)
library(EDI)

# helper_user_compiled_fn.R's normalize_user_cpp_fn() -- the shared entry point for every
# user-supplied compiled C++ input (DesignFixedOptimal's custom_objective, the custom randomization
# statistic's XPtr form) -- has five sibling validation guards, all fired in pure R before any real
# compilation or execution: an unknown signature-convention name, a plain R function (refused for
# performance reasons), a multi-element character source vector, an input of the wrong type
# entirely, and (on the sibling wrapper assert_custom_objective_xptr()) a NULL custom_objective.
# None require RcppXPtrUtils to actually be installed or invoked. Zero test references anywhere for
# any of the five messages.

test_that("normalize_user_cpp_fn(): an unknown signature_name errors with the documented message", {
	f <- getFromNamespace("normalize_user_cpp_fn", "EDI")
	expect_error(
		f(1, "custom_objective", "bogus_signature_xyz"),
		"Unknown user C\\+\\+ signature convention 'bogus_signature_xyz'\\."
	)
})

test_that("normalize_user_cpp_fn(): a plain R function is refused with the performance-reason message", {
	f <- getFromNamespace("normalize_user_cpp_fn", "EDI")
	expect_error(
		f(function(X, w) 1, "custom_objective", "design_objective"),
		"not an R function: it is evaluated once per candidate inside a compiled hot loop"
	)
})

test_that("normalize_user_cpp_fn(): a multi-element character source vector errors with the documented message", {
	f <- getFromNamespace("normalize_user_cpp_fn", "EDI")
	expect_error(
		f(c("code1", "code2"), "custom_objective", "design_objective"),
		"custom_objective: a C\\+\\+ source input must be a single string\\."
	)
})

test_that("normalize_user_cpp_fn(): an input of the wrong type errors with the documented message", {
	f <- getFromNamespace("normalize_user_cpp_fn", "EDI")
	expect_error(
		f(list(1, 2), "custom_objective", "design_objective"),
		"must be an RcppXPtrUtils::cppXPtr\\(\\) external pointer or a single C\\+\\+ source string \\(got a list\\)\\."
	)
})

test_that("assert_custom_objective_xptr(): NULL errors with the documented message", {
	g <- getFromNamespace("assert_custom_objective_xptr", "EDI")
	expect_error(
		g(NULL),
		'custom_objective is required when objective = "custom"'
	)
})
