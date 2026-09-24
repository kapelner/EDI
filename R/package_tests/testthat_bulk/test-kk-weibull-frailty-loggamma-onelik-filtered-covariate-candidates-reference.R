library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik's private filtered_covariate_candidates()
# (inference_survival_GLMM_weibull_frailty_loggamma.R) had no functional test reference anywhere --
# test-partial-likelihood-migration-baseline.R only asserts the sibling design_matrix_candidates()
# name is a declared private-method override, never calls either directly. This method reads
# private$X (not a parameter -- the top-level free function of the same name elsewhere in this file,
# with an X argument, is a DIFFERENT function used only by the IVWC sibling class), so private$X is
# set directly here rather than passed as an argument.
#   1. No covariates: returns a single all-NA-free, zero-column placeholder matrix with the right
#      number of rows.
#   2. Exactly linearly dependent covariates: the base candidate matches drop_linearly_dependent_cols()
#      called directly, independently.
#   3. Well-conditioned (uncorrelated) covariates: a single candidate, identical to the full input --
#      no threshold in c(0.99, 0.9, 0.7) changes anything, so no duplicate candidates are appended.
#   4. Graduated correlation structure (one pair collinear enough to be dropped at threshold 0.99, the
#      rest independent): exactly two distinct candidates -- the full set, then the threshold-reduced
#      set -- matching drop_highly_correlated_cols(threshold = 0.99) called directly, with no further
#      duplicate appended for the 0.9/0.7 thresholds (already-seen column-name sets are de-duplicated).

frailty_fixture <- function(seed, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rexp(n, exp(0.3 * X$x1 + 0.2 * des$get_w())))
	inf <- InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("no covariates: a single zero-column placeholder with the right number of rows", {
	priv <- frailty_fixture(1L)
	priv$X <- matrix(nrow = priv$n, ncol = 0L)
	cands <- priv$filtered_covariate_candidates()
	expect_length(cands, 1L)
	expect_equal(dim(cands[[1L]]), c(priv$n, 0L))
})

test_that("exactly linearly dependent covariates: the base candidate matches drop_linearly_dependent_cols() directly", {
	priv <- frailty_fixture(2L)
	set.seed(3L); a <- rnorm(priv$n); b <- 2 * a                                    # exactly rank-deficient
	priv$X <- cbind(a = a, b = b)
	ref <- EDI:::drop_linearly_dependent_cols(priv$X)$M

	cands <- priv$filtered_covariate_candidates()
	expect_identical(cands[[1L]], ref)
	expect_lt(ncol(ref), ncol(priv$X))                                              # the dependency really was removed
})

test_that("well-conditioned covariates: a single candidate, identical to the full input", {
	priv <- frailty_fixture(4L)
	set.seed(5L)
	priv$X <- cbind(c1 = rnorm(priv$n), c2 = rnorm(priv$n), c3 = rnorm(priv$n))
	cands <- priv$filtered_covariate_candidates()
	expect_length(cands, 1L)
	expect_equal(cands[[1L]], priv$X, check.attributes = FALSE)
})

test_that("graduated correlation: exactly two distinct candidates, the second matching an independent drop_highly_correlated_cols(threshold = 0.99) call", {
	priv <- frailty_fixture(6L)
	set.seed(7L)
	c1 <- rnorm(priv$n); c2 <- c1 + rnorm(priv$n, sd = 0.05); c3 <- rnorm(priv$n)
	priv$X <- cbind(c1 = c1, c2 = c2, c3 = c3)
	expect_gt(cor(c1, c2), 0.99)                                                    # confirm the fixture really crosses the first threshold

	cands <- priv$filtered_covariate_candidates()
	expect_length(cands, 2L)
	expect_equal(cands[[1L]], priv$X, check.attributes = FALSE)                     # first candidate is the unreduced set
	ref_reduced <- EDI:::drop_highly_correlated_cols(priv$X, threshold = 0.99)$M
	expect_identical(cands[[2L]], ref_reduced)
	expect_lt(ncol(cands[[2L]]), ncol(priv$X))
	expect_true("c3" %in% colnames(cands[[2L]]))                                    # the uncorrelated column always survives

	keys <- vapply(cands, function(m) paste(colnames(m), collapse = "|"), character(1))
	expect_equal(length(keys), length(unique(keys)))                                # no duplicate column-name sets
})
