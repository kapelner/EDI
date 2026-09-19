library(testthat)
library(EDI)

# InferenceMarginalEstimand (inference_all_abstract_marginal_estimand.R) is the
# shared set_estimand()/get_estimand()/get_supported_estimands() mixin composed
# by several classes (beta regression, ZOIB, zero-augmented Poisson) whose
# marginal_mean_diff/marginal_ratio delta-method paths already have dedicated
# tests this session. Those tests exercise concrete subclasses; the mixin's own
# contract -- case-insensitive normalization and the per-class
# "does not support estimand" rejection (distinct from normalize_estimand()'s
# syntax rejection, already covered in test-marginal-gcomp-helper-contracts.R)
# -- was never checked directly on the base mixin, which implicitly supports
# only "conditional" until a subclass overrides get_supported_estimands_impl().

test_that("set_estimand() normalizes case/whitespace-free spellings and rejects unsupported values on the base mixin", {
	m <- EDI:::InferenceMarginalEstimand$new()
	# The mixin is designed to be composed into a full Inference class that
	# provides supports(); on a bare standalone instance (lock_objects = FALSE),
	# stub it out so set_estimand()'s likelihood_tests cross-check short-circuits.
	m$supports <- function(x) FALSE
	expect_equal(m$get_supported_estimands(), "conditional")
	expect_equal(m$get_estimand(), "conditional")

	# Case-insensitive normalization: uppercase/mixed-case input round-trips to
	# the canonical lowercase spelling via normalize_estimand(); CONDITIONAL is
	# supported (it's the only one for the base mixin), so this succeeds.
	expect_silent(m$set_estimand("CONDITIONAL"))
	expect_silent(m$set_estimand("Conditional"))
	expect_equal(m$get_estimand(), "conditional")

	# A syntactically valid but per-class-unsupported estimand: normalize_estimand()
	# accepts the spelling, but get_supported_estimands_impl()'s base default
	# (only "conditional") rejects it -- the distinct branch from the
	# already-covered "Unrecognized estimand" syntax error.
	expect_error(
		m$set_estimand("MARGINAL_MEAN_DIFF"),
		'does not support estimand = "marginal_mean_diff".*Supported values are: conditional'
	)
	expect_error(
		m$set_estimand("marginal_ratio"),
		'does not support estimand = "marginal_ratio"'
	)
	# A rejected set_estimand() call leaves the estimand unchanged.
	expect_equal(m$get_estimand(), "conditional")

	# Truly unrecognized spelling still hits normalize_estimand()'s syntax check first.
	expect_error(m$set_estimand("risk_difference"), "Unrecognized estimand")
})

test_that("get_estimand()/get_supported_estimands() reflect a subclass's overridden support set", {
	# InferencePropBetaRegr overrides get_supported_estimands_impl() to add
	# marginal_mean_diff; confirm the base mixin's get/set plumbing correctly
	# picks up a host class's override rather than hard-coding "conditional".
	Sub <- R6::R6Class("SubEstimand",
		lock_objects = FALSE,
		inherit = EDI:::InferenceMarginalEstimand,
		private = list(
			get_supported_estimands_impl = function() c("conditional", "marginal_mean_diff")
		)
	)
	s <- Sub$new()
	s$supports <- function(x) FALSE
	expect_equal(s$get_supported_estimands(), c("conditional", "marginal_mean_diff"))
	expect_silent(s$set_estimand("MARGINAL_MEAN_DIFF"))
	expect_equal(s$get_estimand(), "marginal_mean_diff")
	expect_error(s$set_estimand("marginal_ratio"), "does not support estimand")
	# Rejection leaves the previously-set estimand untouched.
	expect_equal(s$get_estimand(), "marginal_mean_diff")
})
