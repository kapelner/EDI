library(testthat)
library(EDI)

# ExactTestSource (inference_all_abstract_exact.R), the shared base of the exact-test
# classes: resolve_exact_type() defaulting, normalize_exact_inference_args() merging,
# assert_exact_inference_params() validation, the "not implemented" stops of the
# by-type hooks, and compute_estimate_with_bootstrap_weights() (integer-rounded
# replication of subjects) exercised through InferenceIncidExactFisher.

src <- get("ExactTestSource", envir = asNamespace("EDI"))

as_method <- function(name, default_type = "MyType") {
	priv <- new.env()
	priv$default_exact_type <- default_type
	fn <- src$private[[name]]
	env <- new.env(parent = asNamespace("EDI")); env$private <- priv; env$self <- structure(list(), class = "Leaf")
	environment(fn) <- env
	list(fn = fn, priv = priv)
}

test_that("type resolution falls back to the class default and validates it as a non-empty string", {
	m <- as_method("resolve_exact_type")
	expect_equal(m$fn(NULL), "MyType")
	expect_equal(m$fn("Other"), "Other")
	expect_error(m$fn(""))
	expect_error(m$fn(c("a", "b")))
	expect_error(m$fn(1))
	m0 <- as_method("resolve_exact_type", default_type = NULL)
	expect_error(m0$fn(NULL))                                            # no default and no explicit type
	withr::local_options(edi.run_asserts = FALSE)
	expect_equal(m$fn(""), "")                                           # unchecked when assertions are off
})

test_that("argument normalisation nests the type's list and merges user-supplied entries over it", {
	m <- as_method("normalize_exact_inference_args")
	expect_equal(m$fn("T"), list(T = list()))
	expect_equal(m$fn("T", list(T = list(a = 1))), list(T = list(a = 1)))
	expect_equal(m$fn("T", list(T = list(a = 1, b = 2), U = list(z = 9))), list(T = list(a = 1, b = 2), U = list(z = 9)))
	expect_error(m$fn("T", "not a list"))
	# modifyList semantics: a NULL entry removes it, nested lists merge recursively.
	expect_equal(m$fn("T", list(T = list(a = 1, b = list(c = 1)))), list(T = list(a = 1, b = list(c = 1))))
})

test_that("parameter assertion returns the type's argument list and rejects malformed inputs", {
	m <- as_method("assert_exact_inference_params")
	expect_equal(m$fn("T", list(T = list(a = 1))), list(a = 1))
	expect_invisible(m$fn("T", list(T = list())))
	expect_error(m$fn("T", list(U = list())), "args_for_type must contain a list for T")
	expect_error(m$fn("T", list(T = 5)))
	expect_error(m$fn("", list(T = list())))
	expect_error(m$fn("T", "x"))
})

test_that("the by-type hooks stop with an explicit not-implemented message after validating their inputs", {
	ci <- as_method("compute_exact_confidence_interval_by_type")
	# The hook validates via private$assert_exact_inference_params, so expose it on the fake private env.
	ci$priv$assert_exact_inference_params <- as_method("assert_exact_inference_params")$fn
	expect_error(ci$fn("T", 0.05, list(T = list())), "Exact confidence intervals are not implemented")
	expect_error(ci$fn("T", 2, list(T = list())))                        # alpha out of range is caught first
	expect_error(ci$fn("T", 0.05, list(U = list())), "must contain a list for T")
	pv <- as_method("compute_exact_two_sided_pval_for_treatment_effect_by_type")
	pv$priv$assert_exact_inference_params <- as_method("assert_exact_inference_params")$fn
	expect_error(pv$fn("T", 0, list(T = list())), "Exact p-values are not implemented")
	expect_error(pv$fn("T", c(0, 1), list(T = list())))                  # delta must be scalar
	expect_true(as_method("is_a_exact")$fn())
})

fisher_fx <- function(n = 40L, seed = 2L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(0.7 * w)); des$add_all_subject_responses(y)
	inf <- InferenceIncidExactFisher$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n)
	list(inf = inf, p = p, n = n, w = w, y = y)
}

test_that("the exact-Fisher class defaults its type and resolves it", {
	f <- fisher_fx()
	expect_equal(f$p$default_exact_type, "Fisher")
	expect_equal(f$p$resolve_exact_type(NULL), "Fisher")
	expect_true(f$p$is_a_exact())
})

test_that("the shared weighted-estimate method is unusable on the exact Fisher class (real source bug, not fixed)", {
	# SOURCE BUG (noted, not fixed): ExactTestSource$compute_estimate_with_bootstrap_weights() calls
	# private$expand_subject_or_block_weights_to_row_weights(), which only the BayesianBootstrap component
	# provides; the exact classes do not compose it, so the method errors instead of resampling.
	f <- fisher_fx()
	est <- f$inf$compute_estimate()
	expect_false(is.function(f$p$expand_subject_or_block_weights_to_row_weights))
	expect_error(f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$n)))
	expect_equal(f$inf$compute_estimate(), est)                         # the failed call leaves the ordinary cache intact
	expect_equal(f$p$weighted_refit_depth, 0L)
})
