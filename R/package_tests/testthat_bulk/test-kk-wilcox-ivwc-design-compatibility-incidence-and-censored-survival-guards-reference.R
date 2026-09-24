library(testthat)
library(EDI)

# InferenceAllKKWilcoxIVWC's own design_compatibility_reason() (inference_all_KK_wilcox_ivwc.R),
# consulted by initialize() via the shared stop_if_design_incompatible() dispatcher, rejects two
# design shapes at construction time: an "incidence" response_type ("Rank-based compound inference is
# not recommended for incidence data; clogit or compound mean difference estimators are preferred.")
# and any censored survival data ("InferenceAllKKWilcoxIVWC does not currently support censored
# survival data. Use restricted mean or Cox-based methods instead."). A codebase-wide grep confirmed
# both exact messages had zero test references anywhere -- the only existing references to
# stop_if_design_incompatible() (test-design-registry-extension-contracts.R,
# test-design-inference-introspection-audit.R) exercise the generic dispatcher mechanism with a fake
# reason function, never this class's own real reasons against real incidence/censored-survival KK
# design fixtures. (This is a sibling gap to the class's jackknife guards already closed this stretch
# in test-kk-wilcox-ivwc-jackknife-always-nonestimable-reference.R -- a different branch of the same
# well-tested class.)

kk_design <- function(seed, response_type, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	list(des = des, X = X)
}

test_that("an incidence-response KK design is rejected with the documented message", {
	f <- kk_design(1L, "incidence")
	w <- f$des$get_w()
	f$des$add_all_subject_responses(rbinom(length(w), 1, plogis(0.3 * w)))
	expect_error(
		InferenceAllKKWilcoxIVWC$new(f$des, verbose = FALSE),
		"Rank-based compound inference is not recommended for incidence data; clogit or compound mean difference estimators are preferred.",
		fixed = TRUE
	)
})

test_that("a survival KK design WITH censoring is rejected with the documented message", {
	f <- kk_design(2L, "survival")
	for (i in seq_len(nrow(f$X))) {
		w_i <- f$des$get_w()[i]
		event_time <- rexp(1, exp(-0.3 * w_i))
		if (i %% 3 == 0) {
			f$des$add_one_subject_response(i, y_L = event_time * 0.5, y_R = Inf)
		} else {
			f$des$add_one_subject_response(i, y = event_time)
		}
	}
	expect_true(f$des$any_censoring())
	expect_error(
		InferenceAllKKWilcoxIVWC$new(f$des, verbose = FALSE),
		"InferenceAllKKWilcoxIVWC does not currently support censored survival data. Use restricted mean or Cox-based methods instead.",
		fixed = TRUE
	)
})

test_that("a survival KK design WITHOUT censoring constructs without error", {
	f <- kk_design(3L, "survival")
	for (i in seq_len(nrow(f$X))) {
		w_i <- f$des$get_w()[i]
		f$des$add_one_subject_response(i, y = rexp(1, exp(-0.3 * w_i)))
	}
	expect_false(f$des$any_censoring())
	expect_no_error(InferenceAllKKWilcoxIVWC$new(f$des, verbose = FALSE))
})
