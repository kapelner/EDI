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

# TODO-116: unsupported-procedure stubs signal a classed `edi_unsupported_procedure` warning, return NA, record
# cached_values$unsupported_procedure_reason, and leave is_nonestimable() and the Wald caches untouched.
unsup <- function(expr) { val <- NULL; expect_warning(val <- expr, class = "edi_unsupported_procedure"); val }
unsup_reason <- function(inf) inf$.__enclos_env__$private$cached_values$unsupported_procedure_reason

test_that("KK Wilcox IVWC jackknife methods return NA, warn, and record the class-specific 'kk_'-prefixed reason without touching primary state", {
	reason <- "kk_wilcox_hl_jackknife_not_supported"

	f <- kk_wilcox_fx(seed = 2L)
	expect_true(is.na(unsup(f$inf$compute_jackknife_estimate())))
	expect_false(f$inf$is_nonestimable("any"))
	expect_identical(unsup_reason(f$inf), reason)

	g <- kk_wilcox_fx(seed = 3L)
	expect_true(is.na(unsup(g$inf$compute_jackknife_bias_estimate())))
	expect_false(g$inf$is_nonestimable("any"))
	expect_identical(unsup_reason(g$inf), reason)

	for (m in list(function(i) i$compute_jackknife_std_error(), function(i) i$compute_jackknife_wald_two_sided_pval(0.1))) {
		h <- kk_wilcox_fx(seed = 4L)
		expect_true(is.na(unsup(m(h$inf))))
		expect_false(h$inf$is_nonestimable("se"))
		expect_false(h$inf$is_nonestimable("estimate"))
		expect_identical(unsup_reason(h$inf), reason)
	}

	k <- kk_wilcox_fx(seed = 5L)
	ci <- unsup(k$inf$compute_jackknife_wald_confidence_interval(0.1))
	expect_length(ci, 2L)
	expect_true(all(is.na(ci)))
	expect_false(k$inf$is_nonestimable("se"))

	# the unit argument is accepted and ignored, same contract as the simple-Wilcox sibling
	expect_true(is.na(unsup(kk_wilcox_fx(seed = 6L)$inf$compute_jackknife_estimate(unit = "observation"))))
})

test_that("KK Wilcox fast randomization accepts the dispatcher's double permutation matrices", {
	f <- kk_wilcox_fx(n = 20L, seed = 7L)
	p <- f$inf$.__enclos_env__$private
	p$compute_basic_match_data()
	# `generate_permutations()` caches assignment matrices as doubles.  The
	# native fast kernel maps them as MatrixXi, so this boundary conversion must
	# happen here rather than relying on the fallback to conceal a type error.
	w <- as.numeric(p$w)
	m <- as.numeric(p$m); m[is.na(m)] <- 0
	perms_double <- list(w_mat = cbind(w, 1 - w), m_mat = cbind(m, m))
	expect_identical(typeof(perms_double$w_mat), "double")
	expect_identical(typeof(perms_double$m_mat), "double")
	got_double <- p$compute_fast_randomization_distr(
		p$y, perms_double, delta = 0, transform_responses = "none"
	)
	perms_integer <- list(
		w_mat = matrix(as.integer(perms_double$w_mat), nrow = length(w)),
		m_mat = matrix(as.integer(perms_double$m_mat), nrow = length(m))
	)
	got_integer <- p$compute_fast_randomization_distr(
		p$y, perms_integer, delta = 0, transform_responses = "none"
	)
	expect_length(got_double, 2L)
	expect_true(all(is.finite(got_double)))
	expect_equal(got_double, got_integer, tolerance = 1e-10)
})
