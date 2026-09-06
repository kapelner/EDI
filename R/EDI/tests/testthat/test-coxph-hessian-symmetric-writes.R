cox_loglik_reference <- function(X, y, dead, beta) {
  eta <- drop(X %*% beta)
  event_times <- sort(unique(y[dead > 0.5]))
  sum(vapply(event_times, function(tk) {
    events <- dead > 0.5 & y == tk
    risk <- y >= tk
    sum(eta[events]) - sum(events) * log(sum(exp(eta[risk])))
  }, numeric(1L)))
}

stratified_cox_loglik_reference <- function(X, y, dead, strata, beta) {
  sum(vapply(split(seq_along(y), strata), function(idx) {
    cox_loglik_reference(X[idx, , drop = FALSE], y[idx], dead[idx], beta)
  }, numeric(1L)))
}

test_that("coxph Hessian symmetric writes match independent numerical derivatives", {
  skip_if_not_installed("numDeriv")
  set.seed(5301)
  n <- 80L
  p <- 3L
  X <- matrix(rnorm(n * p), n, p)
  beta <- c(0.35, -0.25, 0.15)
  y <- rexp(n, rate = 0.12 * exp(drop(X %*% beta)))
  dead <- as.numeric(seq_len(n) %% 5L != 0L)
  params <- c(0.2, -0.1, 0.05)

  hessian <- EDI:::get_coxph_hessian_cpp(X, y, dead, params)
  hessian_ref <- numDeriv::hessian(
    function(par) cox_loglik_reference(X, y, dead, par),
    params
  )

  expect_equal(unname(hessian), unname(hessian_ref), tolerance = 1e-5)
  expect_equal(unname(hessian), unname(t(hessian)), tolerance = 0)
})

test_that("stratified coxph Hessian symmetric writes match independent numerical derivatives", {
  skip_if_not_installed("numDeriv")
  set.seed(5302)
  n <- 96L
  p <- 2L
  strata <- rep(seq_len(4L), each = n / 4L)
  X <- matrix(rnorm(n * p), n, p)
  beta <- c(0.3, -0.2)
  y <- rexp(n, rate = rep(c(0.08, 0.11, 0.14, 0.17), each = n / 4L) * exp(drop(X %*% beta)))
  dead <- as.numeric(seq_len(n) %% 4L != 0L)
  params <- c(0.15, -0.05)

  hessian <- EDI:::get_stratified_coxph_hessian_cpp(X, y, dead, as.integer(strata), params)
  hessian_ref <- numDeriv::hessian(
    function(par) stratified_cox_loglik_reference(X, y, dead, strata, par),
    params
  )

  expect_equal(unname(hessian), unname(hessian_ref), tolerance = 1e-5)
  expect_equal(unname(hessian), unname(t(hessian)), tolerance = 0)
})

test_that("coxph Hessian symmetric writes are repeatable", {
  set.seed(5303)
  n <- 70L
  p <- 3L
  X <- matrix(rnorm(n * p), n, p)
  y <- rexp(n, rate = 0.1)
  dead <- as.numeric(seq_len(n) %% 6L != 0L)
  params <- c(0.2, -0.1, 0.05)

  hessian1 <- EDI:::get_coxph_hessian_cpp(X, y, dead, params)
  hessian2 <- EDI:::get_coxph_hessian_cpp(X, y, dead, params)

  expect_equal(hessian1, hessian2, tolerance = 0)
})

test_that(".fit_survival_coxph_kernel handles a zero-column design matrix", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# .fit_survival_coxph_fixed_kernel() passes the free (non-fixed) columns
	# of X to .fit_survival_coxph_kernel() -- when the only covariate is the
	# fixed treatment column (e.g. testing beta_T = delta on a model_formula
	# = ~1 fit), that leaves a 0-column X. paste0("x", seq_len(0)) does not
	# return character(0) the way most vectorized functions would for a
	# zero-length input -- paste0() silently drops zero-length arguments
	# instead, so it returned "x" (length 1), and assigning that single name
	# to a 0-column matrix's colnames<- errored ("length of 'dimnames' [2]
	# not equal to array extent"). survival::coxph.fit() itself handles a
	# 0-column x with an offset fine, so this was purely the colnames guard.
	set.seed(6401)
	n <- 40L
	y <- rexp(n, rate = 0.3)
	dead <- rep(1, n)
	X0 <- matrix(numeric(0), nrow = n, ncol = 0L)
	offset <- rnorm(n, 0, 0.2)

	fit <- EDI:::.fit_survival_coxph_kernel(X0, y, dead, offset = offset)

	expect_false(is.null(fit))
	expect_true(is.finite(fit$neg_ll))
	expect_length(fit$b, 0L)

	w <- rep(c(1, 0), length.out = n)
	fixed <- EDI:::.fit_survival_coxph_fixed_kernel(matrix(w, ncol = 1, dimnames = list(NULL, "treatment")), y, dead, fixed_idx = 1L, fixed_value = 0)

	expect_false(is.null(fixed))
	expect_true(isTRUE(fixed$converged))
	expect_true(is.finite(fixed$neg_ll))
})

test_that("InferenceSurvivalCoxPHRegr likelihood tests are estimable with an intercept-only formula", {
	# End-to-end regression for the same 0-column-refit bug: with
	# model_formula = ~1 the only covariate is the treatment column, so the
	# LR/score/gradient null refit (which fixes that column) previously hit
	# the 0-column .fit_survival_coxph_kernel() bug and every one of these
	# came back NA/non-estimable even though compute_estimate() succeeded.
	set.seed(6402)
	n <- 60L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	y <- rexp(n, rate = 0.3)
	add_all_subject_responses_seq(des, y, deads = rep(1L, n))

	inf <- InferenceSurvivalCoxPHRegr$new(des, model_formula = ~ 1, verbose = FALSE)
	est <- inf$compute_estimate()
	expect_true(is.finite(est))

	p_lr <- inf$compute_lik_ratio_two_sided_pval()
	p_score <- inf$compute_score_two_sided_pval()
	p_gradient <- inf$compute_gradient_two_sided_pval()

	expect_true(is.finite(p_lr) && p_lr >= 0 && p_lr <= 1)
	expect_true(is.finite(p_score) && p_score >= 0 && p_score <= 1)
	expect_true(is.finite(p_gradient) && p_gradient >= 0 && p_gradient <= 1)
	expect_false(inf$is_nonestimable())
})

test_that("InferenceSurvivalStratCoxPHRegr score test returns a finite p-value and CI", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# observed_information/fisher_information/information in this class's
	# get_likelihood_test_spec() returned the raw (negative semi-definite)
	# Cox partial-likelihood Hessian without negating it, unlike the
	# sibling InferenceSurvivalCoxPHRegr which does negate. The C++ score
	# test helper requires a positive-definite information matrix and
	# silently returns NA otherwise, so compute_score_two_sided_pval and
	# compute_score_confidence_interval were 100% NA regardless of formula.
	set.seed(9902L)
	n <- 80L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	y <- rexp(n, rate = 0.2)
	add_all_subject_responses_seq(des, y, deads = rep(1L, n))

	for (form in list(~1, ~x1)) {
		inf <- InferenceSurvivalStratCoxPHRegr$new(des, model_formula = form, verbose = FALSE)
		p <- inf$compute_score_two_sided_pval()
		ci <- inf$compute_score_confidence_interval()

		expect_true(is.finite(p) && p >= 0 && p <= 1)
		expect_true(all(is.finite(ci)))
		expect_lt(ci[1], ci[2])
	}
})
