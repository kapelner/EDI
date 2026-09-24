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

fx <- function(seed, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	inf <- EDI:::InferenceKKPassThroughCompoundNoParamBootstrap$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	priv$compute_reservoir_and_match_statistics()
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	list(inf = inf, priv = priv, ctx = ctx)
}

test_that("uniform (all-1) unit weights reproduce the observed KKstats-combined point estimate exactly", {
	f <- fx(1L)
	out <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$ctx$n_units), estimate_only = FALSE)
	KKstats <- f$priv$cached_values$KKstats
	expect_equal(out, KKstats$w_star * KKstats$d_bar + (1 - KKstats$w_star) * KKstats$r_bar, tolerance = 1e-10)
})

test_that("zeroing every reservoir unit's weight falls back to the (weighted) matched-pair difference mean alone (d_bar)", {
	f <- fx(2L)
	unit_counts <- table(f$ctx$row_to_unit)
	reservoir_units <- as.integer(names(unit_counts)[unit_counts == 1L])
	w <- rep(1, f$ctx$n_units); w[reservoir_units] <- 0
	out <- f$inf$compute_estimate_with_bootstrap_weights(w, estimate_only = FALSE)
	expect_equal(out, f$priv$cached_values$KKstats$d_bar, tolerance = 1e-10)
})

test_that("zeroing every matched-pair unit's weight falls back to the (weighted) reservoir mean difference alone (r_bar)", {
	f <- fx(3L)
	unit_counts <- table(f$ctx$row_to_unit)
	pair_units <- as.integer(names(unit_counts)[unit_counts == 2L])
	w <- rep(1, f$ctx$n_units); w[pair_units] <- 0
	out <- f$inf$compute_estimate_with_bootstrap_weights(w, estimate_only = FALSE)
	expect_equal(out, f$priv$cached_values$KKstats$r_bar, tolerance = 1e-10)
})

test_that("all-zero unit weights leave both sub-estimates undefined, returning NA", {
	f <- fx(4L)
	out <- f$inf$compute_estimate_with_bootstrap_weights(rep(0, f$ctx$n_units), estimate_only = FALSE)
	expect_true(is.na(out))
})

test_that("an NA w_star (observed-fit weighting undefined) with both sub-estimates usable falls back to d_bar_w over r_bar_w", {
	f <- fx(5L)
	f$priv$cached_values$KKstats$w_star <- NA_real_
	out <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$ctx$n_units), estimate_only = FALSE)
	unit_counts <- table(f$ctx$row_to_unit)
	reservoir_units <- as.integer(names(unit_counts)[unit_counts == 1L])
	w_zero_res <- rep(1, f$ctx$n_units); w_zero_res[reservoir_units] <- 0
	d_bar_w_only <- f$inf$compute_estimate_with_bootstrap_weights(w_zero_res, estimate_only = FALSE)
	expect_equal(out, d_bar_w_only, tolerance = 1e-10)
})
