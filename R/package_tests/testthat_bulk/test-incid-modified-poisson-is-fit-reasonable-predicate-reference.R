library(testthat)
library(EDI)

# InferenceIncidModifiedPoisson's private is_modified_poisson_fit_reasonable(mod, X_fit, j_treat)
# coefficient/linear-predictor plausibility guard: NULL mod/b, an invalid j_treat (non-scalar, non-finite,
# < 1), fewer coefficients than j_treat, non-finite coefficients, |coefficient| beyond
# max_abs_reasonable_coef, an explicit converged = FALSE flag, and -- only when X_fit is supplied -- the
# fitted linear predictor X_fit %*% b beyond max_abs_reasonable_linear_predictor. This well-tested class
# (fit estimates checked elsewhere against an independent modified-Poisson/robust-SE reference) had no
# test anywhere exercising this guard directly, unlike the analogous is_probit_fit_reasonable() predicate
# on InferenceIncidProbitRegr (now covered separately).

fx <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))
	inf <- InferenceIncidModifiedPoisson$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}

test_that("default bounds are 25 on both the coefficient magnitude and the fitted linear predictor", {
	f <- fx()
	expect_equal(f$p$max_abs_reasonable_coef, 25)
	expect_equal(f$p$max_abs_reasonable_linear_predictor, 25)
})

test_that("NULL mod, NULL b, and an invalid j_treat are all unreasonable", {
	f <- fx(); g <- f$p$is_modified_poisson_fit_reasonable
	expect_false(g(NULL))
	expect_false(g(list()))                                        # mod$b is NULL
	expect_true(g(list(b = c(1, 2, 3))))                            # default j_treat = 2, in range: sanity baseline
	expect_false(g(list(b = c(1, 2, 3)), j_treat = 0))              # j_treat < 1
	expect_false(g(list(b = c(1, 2, 3)), j_treat = NA))             # j_treat non-finite
	expect_false(g(list(b = c(1, 2, 3)), j_treat = c(1, 2)))        # j_treat not scalar
})

test_that("fewer coefficients than j_treat, and any non-finite coefficient, are unreasonable", {
	f <- fx(); g <- f$p$is_modified_poisson_fit_reasonable
	expect_false(g(list(b = c(1)), j_treat = 2))                    # length(b) < j_treat
	expect_false(g(list(b = c(1, NA_real_, 3))))
	expect_false(g(list(b = c(1, Inf, 3))))
})

test_that("the coefficient bound is inclusive; a converged = FALSE flag is always unreasonable regardless", {
	f <- fx(); g <- f$p$is_modified_poisson_fit_reasonable
	expect_true(g(list(b = c(1, 25, 3))))                           # exactly at the bound: reasonable
	expect_false(g(list(b = c(1, 25.01, 3))))                       # just beyond: unreasonable
	expect_false(g(list(b = c(1, 2, 3), converged = FALSE)))
	expect_true(g(list(b = c(1, 2, 3), converged = TRUE)))
	expect_true(g(list(b = c(1, 2, 3))))                            # converged absent: not checked
})

test_that("the linear-predictor bound is only checked when X_fit is supplied, and is inclusive at the bound", {
	f <- fx(); g <- f$p$is_modified_poisson_fit_reasonable
	X <- matrix(1, nrow = 1, ncol = 1)
	expect_true(g(list(b = 25, converged = TRUE), X_fit = X, j_treat = 1))       # eta = 25: at the bound, reasonable
	expect_false(g(list(b = 25.01, converged = TRUE), X_fit = X, j_treat = 1))   # coefficient bound already fails here too
	X2 <- matrix(c(1, 1, 1, 0, 1, 0, 1, 2, 3), nrow = 3)
	expect_true(g(list(b = c(0, 0, 0)), X_fit = X2))                # eta all zero: reasonable
	expect_false(g(list(b = c(0, 0, 10)), X_fit = X2))              # eta = c(10, 20, 30): beyond the bound
	expect_true(g(list(b = c(0, 0, 10))))                           # same coefficients, no X_fit given: bound not applied
})
