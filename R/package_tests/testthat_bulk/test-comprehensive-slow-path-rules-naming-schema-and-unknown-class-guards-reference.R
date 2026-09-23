library(testthat)
library(EDI)

# comprehensive_slow_paths.R's validate_comprehensive_slow_path_rules() has three sibling guards
# beyond the ones already tested (test-comprehensive-slow-path-registry.R covers "unique nonempty
# strings" per-rule, "Invalid comprehensive exact-operation", and "concrete classes" for abstract
# class names): the rules argument itself must be a uniquely-named list ("Comprehensive slow-path
# rules must be a uniquely named list."), the rule name set must exactly match the expected schema
# ("Comprehensive slow-path rule schema mismatch; missing: ...; unexpected: ..."), and every
# referenced class name must actually be a registered inference class ("Comprehensive slow-path
# rules name unknown inference class(es): ..."). None had any test references anywhere.

test_that("validate_comprehensive_slow_path_rules(): an unnamed list errors with the documented message", {
	validate <- getFromNamespace("validate_comprehensive_slow_path_rules", "EDI")
	bad <- unname(EDI::EDI_COMPREHENSIVE_SLOW_PATHS)
	expect_error(validate(bad), "Comprehensive slow-path rules must be a uniquely named list\\.")
})

test_that("validate_comprehensive_slow_path_rules(): an unexpected rule name errors with the documented schema-mismatch message", {
	validate <- getFromNamespace("validate_comprehensive_slow_path_rules", "EDI")
	bad <- EDI::EDI_COMPREHENSIVE_SLOW_PATHS
	bad$extra_unknown_rule <- character(0)
	expect_error(validate(bad), "Comprehensive slow-path rule schema mismatch.*unexpected: extra_unknown_rule")
})

test_that("validate_comprehensive_slow_path_rules(): a missing required rule errors with the documented schema-mismatch message", {
	validate <- getFromNamespace("validate_comprehensive_slow_path_rules", "EDI")
	bad <- EDI::EDI_COMPREHENSIVE_SLOW_PATHS
	bad$rand <- NULL
	expect_error(validate(bad), "Comprehensive slow-path rule schema mismatch.*missing: rand")
})

test_that("validate_comprehensive_slow_path_rules(): a nonexistent inference class name errors with the documented message", {
	validate <- getFromNamespace("validate_comprehensive_slow_path_rules", "EDI")
	bad <- EDI::EDI_COMPREHENSIVE_SLOW_PATHS
	bad$rand <- c(bad$rand, "InferenceNoSuchClassAtAll")
	expect_error(validate(bad), "Comprehensive slow-path rules name unknown inference class\\(es\\): InferenceNoSuchClassAtAll")
})
