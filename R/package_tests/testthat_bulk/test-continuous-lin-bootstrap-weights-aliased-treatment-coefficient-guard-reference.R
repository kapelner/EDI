library(testthat)
library(EDI)

# InferenceContinLin's weighted-refit implementation (public method
# compute_estimate_with_bootstrap_weights(), whose actual body is installed at
# construction time as private$weighted_refit_impl() by the isolation-wrapper
# machinery in inference_all_abstract.R) has two distinct "give up and return
# NA" branches:
#   1) no rows survive the finite/positive-weight filter (or the design is
#      already unusable before weighting) -- covered by the existing
#      test-continuous-lin-bootstrap-weights-wls-and-affine-null-draw-coefs-lm
#      -reference.R file's "all-zero weights" case.
#   2) rows DO survive the filter and lm.wfit() DOES return a fit, but the
#      treatment coefficient itself comes back non-finite -- e.g. because the
#      surviving rows happen to make the design rank-deficient and R aliases
#      the treatment column to NA. That second branch (inference_continuous_lin.R,
#      the `length(coef_hat) < j_treat || !is.finite(coef_hat[j_treat])` guard)
#      had no test reference anywhere: every existing weighted-refit test either
#      keeps a design that stays full column rank, or drops every row.
#
# Zeroing out every control-arm row's weight leaves only treatment-arm rows,
# which makes the "treatment" design column constant (all 1s) and therefore
# collinear with the intercept -- lm.wfit() aliases (NA's) the treatment
# coefficient, independently reproduced below via a direct lm() fit on the
# same kept rows.

set.seed(21); n <- 40L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 5L, verbose = FALSE)
des$add_all_subjects_to_experiment(X)
des$assign_w_to_all_subjects()
w <- des$get_w()
set.seed(22); y <- rnorm(n) + 1.5 * w + X$x1
des$add_all_subject_responses(y)
Xc <- scale(as.matrix(X), center = TRUE, scale = FALSE)

mk <- function() {
	inf <- InferenceContinLin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	list(inf = inf, p = p)
}

test_that("weights that keep only treatment-arm rows alias the treatment coefficient to NA (rank-deficient WLS design)", {
	f <- mk()
	wt <- ifelse(w == 1, 1, 0)
	stopifnot(sum(w == 1) > 0, sum(w == 0) > 0)

	est <- f$inf$compute_estimate_with_bootstrap_weights(wt)
	expect_true(is.na(est))

	# independent reference: the same weighted fit via base lm(), on the kept
	# (treatment-arm-only) rows, aliases the "w" coefficient to NA because it
	# is collinear with the intercept once no control-arm rows remain
	d_ref <- data.frame(y = y, w = w, Xc)[w == 1, ]
	wt_ref <- as.numeric(wt[w == 1])
	fit_ref <- lm(y ~ w * (x1 + x2), data = d_ref, weights = wt_ref)
	expect_true(is.na(coef(fit_ref)["w"]))

	f$p$weighted_refit_impl(wt)
	expect_true(is.na(f$p$cached_values$beta_hat_T))
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))
	expect_true(is.na(f$p$cached_values$df))
})
