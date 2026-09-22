library(testthat)
library(EDI)

# InferenceIncidMiettinenNurminenRiskDiff's private get_counts() (per-arm n/x/p from private$w, private$y) and
# mn_eps() (sqrt(.Machine$double.eps)) had no test calling them directly. The class's own compute_estimate()/CI/
# p-value are already independently verified elsewhere (restricted-MLE score reference, and an "unavailable when
# an arm is empty" NA check), but that empty-arm test only asserts NA outputs -- never that the object is actually
# flagged nonestimable, at which stage, or with which reason -- and never calls get_counts() directly to confirm
# what it returns for the degenerate all-one-arm case that triggers set_failed_fit_cache().

mk <- function(y, w) {
	n <- length(y)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

test_that("get_counts() returns the exact per-arm n/x/p computed directly from w and y", {
	set.seed(1); n <- 20L; w <- rep(c(0, 1), length.out = n); y <- rbinom(n, 1, 0.5)
	des <- mk(y, w)
	inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	counts <- inf$.__enclos_env__$private$get_counts()
	expect_equal(counts$n_t, sum(w == 1)); expect_equal(counts$n_c, sum(w == 0))
	expect_equal(counts$x_t, sum(y[w == 1])); expect_equal(counts$x_c, sum(y[w == 0]))
	expect_equal(counts$p_t, sum(y[w == 1]) / sum(w == 1)); expect_equal(counts$p_c, sum(y[w == 0]) / sum(w == 0))
})

test_that("mn_eps() is exactly sqrt(.Machine$double.eps)", {
	des <- mk(rbinom(10, 1, 0.5), rep(0:1, 5))
	inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	expect_identical(inf$.__enclos_env__$private$mn_eps(), sqrt(.Machine$double.eps))
})

test_that("an empty arm: get_counts() reports n = 0 and p = NA for that arm, and the estimate is nonestimable with a specific reason at the 'estimate' stage", {
	set.seed(2); n <- 10L; y <- rbinom(n, 1, 0.5)
	des <- mk(y, rep(1, n))                                                          # every subject treated: control arm empty
	inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	counts <- inf$.__enclos_env__$private$get_counts()
	expect_equal(counts$n_c, 0L); expect_true(is.na(counts$p_c))
	expect_equal(counts$n_t, n); expect_equal(counts$p_t, sum(y) / n)

	est <- inf$compute_estimate()
	expect_true(is.na(est))
	expect_true(inf$is_nonestimable("any"))
	expect_true(inf$is_nonestimable("estimate"))
	expect_false(inf$is_nonestimable("se"))
	expect_identical(inf$get_nonestimable_reason(), "miettinen_nurminen_fit_unavailable")
	expect_null(inf$.__enclos_env__$private$cached_values$mn_counts)                 # cleared by set_failed_fit_cache()
})

test_that("the symmetric empty-arm case (control-only) behaves the same way", {
	set.seed(3); n <- 8L; y <- rbinom(n, 1, 0.5)
	des <- mk(y, rep(0, n))
	inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	counts <- inf$.__enclos_env__$private$get_counts()
	expect_equal(counts$n_t, 0L); expect_true(is.na(counts$p_t))
	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "miettinen_nurminen_fit_unavailable")
})
