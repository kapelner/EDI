library(testthat)
library(EDI)

# InferenceCountZeroAugmentedPoissonAbstract's private record_zero_augmented_fit_summary(fit, X_full,
# Xzi_full, X_fit, Xzi_fit, is_hurdle) (inference_count_zero_augmented_poisson_abstract.R) builds the
# cached summary table (coefficients, SEs, z-values, p-values) from a completed fit, mapping the
# (possibly covariate-reduced) fitted design's coefficients back onto the FULL design's column names --
# columns present in X_full but dropped from X_fit (e.g. by a covariate-selection retry loop) get an
# explicit NA row rather than being silently omitted. A codebase-wide grep confirmed this method had
# zero test references anywhere, despite the class being otherwise extensively tested. Exercised here
# via direct private-method calls on a real InferenceCountHurdlePoisson instance with hand-built `fit`/
# design-matrix inputs, independent of the real optimizer:
#   1. Full and fitted designs identical: every column gets a real value; row labels use "hurdle:"
#      for the auxiliary component when is_hurdle = TRUE, matching an independently computed z/p-value.
#   2. A covariate dropped from the fitted (but not the full) conditional design: that column's row is
#      NA throughout, and the auxiliary-component row label switches to "zero:" when is_hurdle = FALSE.
#   3. A too-short params vector (fewer than the fitted design's own parameter count) is a no-op --
#      the cache is left completely untouched.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.3 * w)))
	list(inf = InferenceCountHurdlePoisson$new(des, verbose = FALSE), w = w, n = n)
}

test_that("identical full/fitted designs populate every row with real values, using 'hurdle:' labels when is_hurdle = TRUE", {
	f <- fx(1L)
	priv <- f$inf$.__enclos_env__$private
	X_full <- cbind("(Intercept)" = 1, treatment = f$w, x1 = rnorm(f$n))
	Xzi_full <- cbind("(Intercept)" = 1, treatment = f$w)
	fit <- list(params = c(0.1, 0.5, 0.3, -0.2, 0.4), vcov = diag(5))

	priv$record_zero_augmented_fit_summary(fit, X_full, Xzi_full, X_full, Xzi_full, is_hurdle = TRUE)
	tbl <- priv$cached_values$summary_table

	expect_equal(rownames(tbl), c("conditional:(Intercept)", "conditional:treatment", "conditional:x1", "hurdle:(Intercept)", "hurdle:treatment"))
	expect_equal(tbl[, "Value"], setNames(c(0.1, 0.5, 0.3, -0.2, 0.4), rownames(tbl)))
	expect_true(all(is.finite(tbl)))
	z_treat <- 0.5 / 1
	expect_equal(unname(tbl["conditional:treatment", "z value"]), z_treat)
	expect_equal(unname(tbl["conditional:treatment", "Pr(>|z|)"]), 2 * pnorm(-abs(z_treat)))
	expect_equal(unname(priv$cached_values$full_coefficients), c(0.1, 0.5, 0.3))
	expect_equal(unname(priv$cached_values$zero_coefficients), c(-0.2, 0.4))
})

test_that("a covariate dropped from the fitted (but present in the full) design gets an explicit NA row, and 'zero:' labels are used when is_hurdle = FALSE", {
	f <- fx(2L)
	priv <- f$inf$.__enclos_env__$private
	X_full <- cbind("(Intercept)" = 1, treatment = f$w, x1 = rnorm(f$n))
	Xzi_full <- cbind("(Intercept)" = 1, treatment = f$w)
	X_fit_reduced <- cbind("(Intercept)" = 1, treatment = f$w)
	fit <- list(params = c(0.1, 0.5, -0.2, 0.4), vcov = diag(4))

	priv$record_zero_augmented_fit_summary(fit, X_full, Xzi_full, X_fit_reduced, Xzi_full, is_hurdle = FALSE)
	tbl <- priv$cached_values$summary_table

	expect_equal(rownames(tbl), c("conditional:(Intercept)", "conditional:treatment", "conditional:x1", "zero:(Intercept)", "zero:treatment"))
	expect_true(all(is.na(tbl["conditional:x1", ])))
	expect_equal(unname(tbl["conditional:(Intercept)", "Value"]), 0.1)
	expect_equal(unname(tbl["zero:treatment", "Value"]), 0.4)
})

test_that("a params vector shorter than the fitted design's own parameter count is a no-op, leaving the cache untouched", {
	f <- fx(3L)
	priv <- f$inf$.__enclos_env__$private
	X_full <- cbind("(Intercept)" = 1, treatment = f$w, x1 = rnorm(f$n))
	Xzi_full <- cbind("(Intercept)" = 1, treatment = f$w)
	priv$cached_values$summary_table <- "sentinel"

	priv$record_zero_augmented_fit_summary(list(params = c(0.1)), X_full, Xzi_full, X_full, Xzi_full, is_hurdle = TRUE)
	expect_identical(priv$cached_values$summary_table, "sentinel")
})
