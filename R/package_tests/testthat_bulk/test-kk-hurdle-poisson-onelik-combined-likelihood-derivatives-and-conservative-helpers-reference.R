library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonOneLik: the combined (matched hurdle-GLMM + reservoir Poisson)
# log-likelihood, checked against numerical derivatives of itself (score = -grad(neg-loglik),
# Hessian = -Hess(neg-loglik)), a reservoir-only closed form, weighting semantics,
# information_inverse_diagonal_entry(), and the file's pure conservative-inference helpers
# (.conservative_kk_onelik_pval / _ci and the jackknife SE inflation).

Z <- function(x) get(x, envir = asNamespace("EDI"))

hurdle_fx <- function(seed = 4L, np = 25L, ns = 15L) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	w <- des$get_w(); g <- c(rep(seq_len(np), each = 2L), np + seq_len(ns)); u <- rnorm(max(g), 0, 0.5)
	y <- rpois(n, exp(0.5 + 0.3 * w + 0.2 * X$x1 + u[g]))
	des$add_all_subject_responses(y)
	inf <- InferenceCountKKHurdlePoissonOneLik$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	Xf <- p$build_model_matrix()
	list(inf = inf, p = p, Xf = Xf, dat = p$build_combined_hurdle_data(Xf, 2L), n = n, y = y, w = w, x1 = X$x1, np = np, ns = ns)
}

par0 <- c(0.3, 0.2, 0.1, -0.4)                                                   # (intercept, w, x1, log sigma)

test_that("model matrix and combined data split matched pairs from reservoir subjects", {
	f <- hurdle_fx()
	expect_equal(colnames(f$Xf), c("(Intercept)", "w", "x1"))
	expect_equal(f$dat$matched_idx, seq_len(2L * f$np))
	expect_equal(f$dat$reservoir_idx, 2L * f$np + seq_len(f$ns))
	expect_equal(f$dat$group_id, rep(seq_len(f$np), each = 2L))
	expect_equal(f$dat$y_reservoir, as.numeric(f$y[f$dat$reservoir_idx]))
	expect_equal(f$dat$j_treat, 2L)
	wd <- f$p$build_weighted_combined_hurdle_data(f$Xf, 2L, c(rep(1, f$n - 1L), NA))
	expect_equal(wd$weights_reservoir[length(wd$weights_reservoir)], 0)             # NA weights become 0
	expect_equal(f$p$build_weighted_combined_hurdle_data(f$Xf, 2L, NULL)$weights_matched, rep(1, 2L * f$np))
})

test_that("score and Hessian are the derivatives of the log-likelihood (negatives of the neg-loglik derivatives)", {
	f <- hurdle_fx()
	nl <- function(b) f$p$combined_hurdle_neg_loglik(b, f$dat)
	expect_equal(f$p$combined_hurdle_score(par0, f$dat), -numDeriv::grad(nl, par0), tolerance = 1e-5)
	H <- f$p$combined_hurdle_hessian(par0, f$dat)
	expect_equal(H, -numDeriv::hessian(nl, par0), tolerance = 1e-3)
	expect_equal(H, t(H), tolerance = 1e-8)
})

test_that("reservoir-only data reduce to the Poisson log-likelihood; its score and Hessian are the glm ones", {
	f <- hurdle_fx()
	f$p$m <- rep(0L, f$n)
	dat <- f$p$build_combined_hurdle_data(f$Xf, 2L)
	expect_length(dat$matched_idx, 0L)
	beta <- par0[1:3]; eta <- drop(f$Xf %*% beta)
	ref_nll <- -sum(dpois(f$y, exp(eta), log = TRUE))
	expect_equal(f$p$combined_hurdle_neg_loglik(par0, dat), ref_nll, tolerance = 1e-10)
	sc <- f$p$combined_hurdle_score(par0, dat)
	expect_equal(unname(sc[1:3]), unname(drop(crossprod(f$Xf, f$y - exp(eta)))), tolerance = 1e-8)
	expect_equal(sc[4], 0)                                                          # no matched pairs: the variance parameter is unidentified
	H <- f$p$combined_hurdle_hessian(par0, dat)
	expect_equal(unname(H[1:3, 1:3]), unname(-crossprod(f$Xf, exp(eta) * f$Xf)), tolerance = 1e-8)
	expect_equal(H[4, ], rep(0, 4)); expect_equal(H[, 4], rep(0, 4))
})

test_that("unit row weights reproduce the unweighted likelihood; zero weights drop those rows", {
	f <- hurdle_fx()
	ones <- f$p$build_weighted_combined_hurdle_data(f$Xf, 2L, rep(1, f$n))
	expect_equal(f$p$combined_hurdle_neg_loglik(par0, ones), f$p$combined_hurdle_neg_loglik(par0, f$dat), tolerance = 1e-8)
	expect_equal(f$p$combined_hurdle_score(par0, ones), f$p$combined_hurdle_score(par0, f$dat), tolerance = 1e-6)
	# Zero-weighting the last three reservoir subjects equals removing them.
	wts <- rep(1, f$n); drop_i <- (f$n - 2L):f$n; wts[drop_i] <- 0
	weighted <- f$p$build_weighted_combined_hurdle_data(f$Xf, 2L, wts)
	reduced <- f$dat
	reduced$X_reservoir <- reduced$X_reservoir[seq_len(f$ns - 3L), , drop = FALSE]; reduced$y_reservoir <- reduced$y_reservoir[seq_len(f$ns - 3L)]
	reduced$reservoir_idx <- reduced$reservoir_idx[seq_len(f$ns - 3L)]
	expect_equal(f$p$combined_hurdle_neg_loglik(par0, weighted), f$p$combined_hurdle_neg_loglik(par0, reduced), tolerance = 1e-8)
	# Doubling every weight doubles the contribution.
	twos <- f$p$build_weighted_combined_hurdle_data(f$Xf, 2L, rep(2, f$n))
	expect_equal(f$p$combined_hurdle_neg_loglik(par0, twos), 2 * f$p$combined_hurdle_neg_loglik(par0, f$dat), tolerance = 1e-6)
})

test_that("information_inverse_diagonal_entry: exact inverse when regular, pseudo-inverse for a consistent singular case, NA otherwise", {
	f <- hurdle_fx()
	g <- f$p$information_inverse_diagonal_entry
	A <- matrix(c(4, 1, 1, 3), 2)
	expect_equal(g(A, 1), solve(A)[1, 1], tolerance = 1e-12)
	expect_equal(g(A, 2), solve(A)[2, 2], tolerance = 1e-12)
	S <- matrix(c(2, 0, 0, 0), 2)                                                     # singular, but coordinate 1 is identified
	expect_equal(g(S, 1), 0.5, tolerance = 1e-10)
	expect_true(is.na(g(S, 2)))                                                       # the unidentified coordinate has no finite variance
	indef <- matrix(c(1, 0, 0, -1), 2)                                                # indefinite: only a non-negative inverse diagonal entry is accepted
	expect_equal(g(indef, 1), 1)
	expect_true(is.na(g(indef, 2)))
	expect_true(is.na(g(A, 3))); expect_true(is.na(g(A, 0))); expect_true(is.na(g(A, c(1, 2))))
	expect_true(is.na(g(matrix(c(1, NA, NA, 1), 2), 1))); expect_true(is.na(g(matrix(1:6, 2), 1)))
	expect_equal(g(matrix(c(4, 1.2, 1, 3), 2), 1), solve((matrix(c(4, 1.2, 1, 3), 2) + t(matrix(c(4, 1.2, 1, 3), 2))) / 2)[1, 1], tolerance = 1e-12)   # symmetrised first
})

test_that("conservative p-value: the larger finite p-value, clipped to [0, 1]", {
	f <- Z(".conservative_kk_onelik_pval")
	expect_equal(f(0.04, 0.2), 0.2); expect_equal(f(0.3, 0.01), 0.3)
	expect_equal(f(0.04, NA), 0.04); expect_equal(f(NA, 0.5), 0.5)
	expect_true(is.na(f(NA, NaN)))
	expect_equal(f(1.7, 0.2), 1); expect_equal(f(-0.5, -0.1), 0)
})

test_that("conservative CI: the union of the two intervals, or whichever one is finite, with the alpha labels", {
	f <- Z(".conservative_kk_onelik_ci")
	expect_equal(as.numeric(f(c(0, 2), c(1, 3), alpha = 0.1)), c(0, 3))
	expect_equal(names(f(c(0, 2), c(1, 3), alpha = 0.1)), c("5%", "95%"))
	expect_equal(as.numeric(f(c(0.5, 1), c(0, 3))), c(0, 3))                          # design interval contains the model one
	expect_equal(as.numeric(f(c(NA, 2), c(1, 3))), c(1, 3))
	expect_equal(as.numeric(f(c(0, 2), c(Inf, NA))), c(0, 2))
	expect_true(all(is.na(f(c(NA, NA), numeric(0)))))
	expect_equal(names(f(NULL, NULL)), c("2.5%", "97.5%"))
})

test_that("jackknife SE inflation replaces the model SE only when the jackknife SE is larger, and records the source", {
	f <- Z(".inflate_kk_onelik_standard_error_with_jackknife")
	mk <- function(beta, se, jack_se, active = NULL) {
		e <- new.env()
		e$active_resampling_operation <- active
		e$cached_values <- list(beta_hat_T = beta, s_beta_hat_T = se)
		e$compute_jackknife_summary <- function(unit) list(std_error = jack_se)
		e
	}
	e <- mk(1, 0.2, 0.5); f(e, NULL)
	expect_equal(e$cached_values$s_beta_hat_T, 0.5); expect_equal(e$cached_values$s_beta_hat_T_model, 0.2)
	expect_equal(e$cached_values$s_beta_hat_T_source, "jackknife")
	e2 <- mk(1, 0.5, 0.2); f(e2, NULL)                                                 # smaller jackknife SE: unchanged
	expect_equal(e2$cached_values$s_beta_hat_T, 0.5); expect_null(e2$cached_values$s_beta_hat_T_source)
	e3 <- mk(1, NA_real_, 0.3); f(e3, NULL); expect_equal(e3$cached_values$s_beta_hat_T, 0.3)   # missing model SE is replaced
	for (bad in list(mk(NA_real_, 0.2, 0.5), mk(1, 0.2, NA_real_), mk(1, 0.2, 0), mk(1, 0.2, 0.5, active = "jackknife"))) {
		before <- bad$cached_values; f(bad, NULL); expect_identical(bad$cached_values, before)
	}
	e4 <- mk(1, 0.2, 0.5); e4$compute_jackknife_summary <- function(unit) stop("boom")
	f(e4, NULL); expect_equal(e4$cached_values$s_beta_hat_T, 0.2)                     # a failing jackknife never changes the SE
})
