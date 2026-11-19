library(testthat)
library(EDI)

# kk_passthrough_compound_host_public$compute_estimate_with_bootstrap_weights (inference_all_abstract_
# KK_passthrough_compound.R), the shared Jackknife/Bayesian-bootstrap weighted-estimate host method
# composed into InferenceKKPassThroughCompound and InferenceKKPassThroughCompoundNoParamBootstrap, had
# only 5.4% line coverage across the whole file despite many indirect references elsewhere in the
# suite (test-mixin-contracts.R etc. check the method's WIRING/composition, never actually calling it).
# Confirmed via grep that `compute_weighted_estimate_ivwc` -- the delegate this method checks for via
# `is.function(private$compute_weighted_estimate_ivwc)` before falling back to its own arithmetic -- has
# zero definitions anywhere in the package, so the fallback body (weighted matched-pair-difference mean
# d_bar_w combined with weighted reservoir treated-minus-control mean r_bar_w, using the observed fit's
# own w_star, or falling back to whichever of the two is usable) is the ONLY code this method ever runs,
# for any class that reaches it. Both host classes are otherwise legacy (per this file's own comment,
# "zero concrete registered classes descend from them" through the normal R6 ladder anymore -- every
# migrated concrete KK class supplies its own compute_estimate_with_bootstrap_weights instead), but they
# remain real, directly-constructible, registered classes (confirmed:
# EDI:::InferenceKKPassThroughCompoundNoParamBootstrap$new() succeeds), so this is live, reachable,
# non-dead code, just never exercised. Reached by constructing the base class directly on a real KK14
# design, installing a
# Bayesian-bootstrap context via the same build_bayesian_bootstrap_context()/current_bayesian_bootstrap_
# context wiring the real bootstrap loop uses (inference_all_abstract_bayesian_bootstrap.R), and
# independently cross-checking every branch against the KKstats cache's own d_bar/r_bar/w_star.
#
# v1.0.6-TODO-217 (2026-11-19): that fallback is gone. It was a raw mean difference pooled with
# the observed w_star, not the estimator of the class reaching it (all zeros for
# InferenceSurvivalKKStratCoxPHIVWC, raw survival-time differences for the other Cox / AFT
# classes, ...). The host now delegates to the class's compute_weighted_estimate_ivwc(), passing
# the draw's row weights in w_info, and otherwise refuses with a clear error. The tests below pin
# that contract on the same two base classes.

fx <- function(seed, n = 40L, cls = "InferenceKKPassThroughCompoundNoParamBootstrap") {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	inf <- get(cls, envir = asNamespace("EDI"), inherits = FALSE)$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	priv$compute_reservoir_and_match_statistics()
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	list(inf = inf, priv = priv, ctx = ctx)
}

test_that("without a weighted refit the host refuses instead of returning a raw mean difference", {
	for (cls in c("InferenceKKPassThroughCompoundNoParamBootstrap", "InferenceKKPassThroughCompound")) {
		f <- fx(1L, cls = cls)
		expect_error(f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$ctx$n_units), estimate_only = FALSE),
			"has no weighted refit of its estimator", info = cls)
	}
})

test_that("the KK dispatcher delegates to compute_weighted_estimate_ivwc() with pair, reservoir and row weights", {
	# The base classes above define no delegate (and their private environments are locked),
	# so check the delegation on a concrete class that has one.
	set.seed(2)
	n <- 40L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n) + 0.8 * des$get_w())
	inf <- InferenceContinKKOLSIVWC$new(des, verbose = FALSE)
	inf$compute_estimate()
	priv <- inf$.__enclos_env__$private
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	seen <- new.env()
	unlockBinding("compute_weighted_estimate_ivwc", priv)
	priv$compute_weighted_estimate_ivwc <- function(w_info, estimate_only = FALSE) {
		seen$w_info <- w_info
		seen$estimate_only <- estimate_only
		42
	}
	set.seed(3)
	w <- runif(ctx$n_units, 0.5, 2)
	out <- inf$compute_estimate_with_bootstrap_weights(w, estimate_only = TRUE)
	expect_identical(out, 42)
	expect_true(seen$estimate_only)
	row_weights <- w[ctx$row_to_unit]
	expect_equal(seen$w_info$row_weights, row_weights)
	m <- priv$m
	pair_ids <- sort(unique(m[m > 0L]))
	expect_equal(as.integer(seen$w_info$pair_ids), as.integer(pair_ids))
	expect_equal(seen$w_info$pair_weights, vapply(pair_ids, function(pid) mean(row_weights[m == pid]), numeric(1)))
	expect_equal(seen$w_info$reservoir_weights, row_weights[which(m == 0L)])
})
