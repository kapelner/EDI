library(testthat)
library(EDI)

# InferenceAllKKWilcoxIVWC's five public jackknife methods (inference_all_KK_wilcox_ivwc.R) each
# unconditionally report non-estimable and cache the class-specific reason
# "kk_wilcox_hl_jackknife_not_supported" (distinct from InferenceAllSimpleWilcox's sibling
# "wilcox_hl_jackknife_not_supported", already covered by test-wilcox-jackknife-always-nonestimable-
# and-suite-task-filter-reference.R -- confirmed via a codebase-wide grep that the "kk_"-prefixed
# reason string, unlike its simple-Wilcox sibling, had zero test references anywhere despite
# InferenceAllKKWilcoxIVWC itself being otherwise well-tested elsewhere). Same NA-plus-cached-reason
# contract as the simple-Wilcox sibling; reached on a real KK14-matched design instance, mirroring the
# existing test's structure and assertions but for the KK compound class and its own reason string.

kk_wilcox_fx <- function(n = 12L, seed = 1L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, rnorm(1) + 0.35 * w_i)
	}
	inf <- InferenceAllKKWilcoxIVWC$new(des, verbose = FALSE)
	list(inf = inf, des = des)
}

test_that("jackknife_always_nonestimable() is TRUE for the KK Wilcox IVWC class", {
	f <- kk_wilcox_fx()
	expect_true(f$inf$.__enclos_env__$private$jackknife_always_nonestimable())
})

test_that("KK Wilcox IVWC jackknife methods return NA and cache the class-specific 'kk_'-prefixed reason at the right stage", {
	reason <- "kk_wilcox_hl_jackknife_not_supported"

	f <- kk_wilcox_fx(seed = 2L)
	expect_true(is.na(f$inf$compute_jackknife_estimate()))
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_identical(f$inf$get_nonestimable_reason(), reason)

	g <- kk_wilcox_fx(seed = 3L)
	expect_true(is.na(g$inf$compute_jackknife_bias_estimate()))
	expect_true(g$inf$is_nonestimable("estimate"))
	expect_identical(g$inf$get_nonestimable_reason(), reason)

	for (m in list(function(i) i$compute_jackknife_std_error(), function(i) i$compute_jackknife_wald_two_sided_pval(0.1))) {
		h <- kk_wilcox_fx(seed = 4L)
		expect_true(is.na(m(h$inf)))
		expect_true(h$inf$is_nonestimable("se"))
		expect_false(h$inf$is_nonestimable("estimate"))
		expect_identical(h$inf$get_nonestimable_reason(), reason)
	}

	k <- kk_wilcox_fx(seed = 5L)
	ci <- k$inf$compute_jackknife_wald_confidence_interval(0.1)
	expect_length(ci, 2L)
	expect_true(all(is.na(ci)))
	expect_true(k$inf$is_nonestimable("se"))

	# the unit argument is accepted and ignored, same contract as the simple-Wilcox sibling
	expect_true(is.na(kk_wilcox_fx(seed = 6L)$inf$compute_jackknife_estimate(unit = "observation")))
})
