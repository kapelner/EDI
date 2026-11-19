# Zero-inflated mixtures (ZIP/ZINB) on data with no zeros (2026-11-04): the
# structural-zero probability's MLE is 0 and the zero-inflation submodel is not
# identified. On the user's data the constructor refuses; inside resampling a
# replicate with no zeros gets the non-inflated (Poisson / NB) fit instead of
# an error or a dropped draw. Hurdle models factorize and are unaffected.

zi_no_zero_design <- function(n = 120L, n_zeros = 0L, seed = 11L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "count")
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	y <- rpois(n, exp(1.2 + 0.2 * des$get_w()))
	y[y == 0] <- 1L
	if (n_zeros > 0L) y[seq_len(n_zeros)] <- 0L
	des$add_all_subject_responses(ys = y)
	des
}

test_that("ZIP and ZINB refuse a response with no zeros; hurdle accepts it", {
	des <- zi_no_zero_design()
	expect_error(InferenceCountZeroInflatedPoisson$new(des), "no zeros.*InferenceCountPoisson")
	expect_error(InferenceCountZeroInflatedNegBin$new(des), "no zeros.*InferenceCountNegBin")
	expect_true(is.finite(InferenceCountHurdlePoisson$new(des)$compute_estimate()))
})

test_that("a bootstrap replicate with no zeros gets the Poisson fit, not NA", {
	des <- zi_no_zero_design(n_zeros = 1L)
	inf <- InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ 1)
	expect_true(is.finite(inf$compute_estimate()))
	priv <- inf$.__enclos_env__$private
	ws <- priv$create_bootstrap_worker_state()
	idx <- c(2:120, 2L)  # every row except the single zero
	priv$load_bootstrap_sample_into_worker(ws, idx)
	est <- priv$compute_bootstrap_worker_estimate(ws)
	y_b <- des$get_y()[idx]; w_b <- des$get_w()[idx]
	expect_equal(est, unname(coef(glm(y_b ~ w_b, family = poisson))[2L]), tolerance = 1e-6)
	expect_true(isTRUE(ws$worker_priv$cached_values$zero_inflation_fallback))
	# the data keep their zero, so the full-data fit is the ordinary ZIP fit
	expect_null(priv$cached_values$zero_inflation_fallback)
})

test_that("ZINB bootstrap replicate with no zeros gets the negative binomial fit", {
	des <- zi_no_zero_design(n_zeros = 1L, seed = 12L)
	inf <- InferenceCountZeroInflatedNegBin$new(des, model_formula = ~ 1)
	priv <- inf$.__enclos_env__$private
	invisible(inf$compute_estimate())
	ws <- priv$create_bootstrap_worker_state()
	idx <- c(2:120, 2L)
	priv$load_bootstrap_sample_into_worker(ws, idx)
	est <- priv$compute_bootstrap_worker_estimate(ws)
	expect_true(is.finite(est))
	y_b <- des$get_y()[idx]; w_b <- des$get_w()[idx]
	# NB dispersion may itself sit at its Poisson boundary; the count-part
	# coefficient then matches the Poisson fit.
	expect_equal(est, unname(coef(glm(y_b ~ w_b, family = poisson))[2L]), tolerance = 1e-3)
})

test_that("bootstrap CI with many zero-free replicates has no dropped draws", {
	des <- zi_no_zero_design(n_zeros = 1L, seed = 13L)
	inf <- InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ 1)
	set.seed(1)
	ci <- inf$compute_bootstrap_confidence_interval(B = 101, show_progress = FALSE)
	expect_true(all(is.finite(ci)))
	# every resample is estimable, including the ~37% that miss the only zero
	priv <- inf$.__enclos_env__$private
	ws <- priv$create_bootstrap_worker_state()
	set.seed(2)
	ests <- vapply(1:30, function(b) {
		idx <- sample.int(120L, replace = TRUE)
		priv$load_bootstrap_sample_into_worker(ws, idx)
		priv$compute_bootstrap_worker_estimate(ws)
	}, numeric(1))
	expect_true(all(is.finite(ests)))
})

# docs-claims audit, findings docs-claims-ddb49a587 (ZIP) and docs-claims-d03ccf4c6 (ZINB): the zero-free fallback
# is documented for the Bayesian-bootstrap weighted refit and the parametric-bootstrap simulation too, not only the
# nonparametric-bootstrap worker tested above.
zi_mixed_design <- function(family = c("poisson", "negbin"), n = 60L, seed = 4L) {
	family <- match.arg(family)
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
	w <- des$get_w(); zi <- rbinom(n, 1, 0.3)
	mu <- exp(0.6 + 0.4 * w + 0.2 * X$x1)
	cnt <- if (family == "poisson") rpois(n, mu) else rnbinom(n, mu = mu, size = 3)
	des$add_all_subject_responses(ifelse(zi == 1, 0L, cnt))
	list(des = des, y = des$get_y(), w = w, x1 = X$x1)
}

test_that("ZIP / ZINB Bayesian-bootstrap weights that zero out every zero row give the Poisson / NB fit", {
	f <- zi_mixed_design("poisson")
	inf <- InferenceCountZeroInflatedPoisson$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	keep <- f$y > 0
	expect_true(any(!keep))
	est <- inf$compute_estimate_with_bootstrap_weights(as.numeric(keep))
	ref <- unname(coef(glm(f$y[keep] ~ f$w[keep] + f$x1[keep], family = poisson))[2L])
	expect_equal(est, ref, tolerance = 1e-5)

	g <- zi_mixed_design("negbin")
	inf_nb <- InferenceCountZeroInflatedNegBin$new(g$des, verbose = FALSE)
	priv_nb <- inf_nb$.__enclos_env__$private
	priv_nb$current_bayesian_bootstrap_context <- priv_nb$build_bayesian_bootstrap_context()
	keep_nb <- g$y > 0
	est_nb <- inf_nb$compute_estimate_with_bootstrap_weights(as.numeric(keep_nb))
	ref_nb <- unname(coef(MASS::glm.nb(g$y[keep_nb] ~ g$w[keep_nb] + g$x1[keep_nb]))[2L])
	expect_equal(est_nb, ref_nb, tolerance = 1e-4)
})

test_that("ZIP / ZINB parametric-bootstrap simulations with no zeros are refit, not dropped", {
	f <- zi_mixed_design("poisson")
	inf <- InferenceCountZeroInflatedPoisson$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	invisible(inf$compute_estimate())
	spec <- priv$get_likelihood_test_spec()
	null_fit <- spec$fit_null(0)
	# a null fit with no structural zeros and a large count mean: the simulated response has no zeros
	null_fit$coefficients$cond <- c(log(30), 0, 0.1)
	null_fit$coefficients$zi <- c(-40, 0, 0)
	set.seed(9)
	sim <- priv$simulate_under_lik_null(spec, 0, null_fit)
	expect_false(is.null(sim))
	y_sim <- sim$worker_data$y
	expect_false(any(y_sim == 0))
	expect_true(isTRUE(sim$full_fit$converged))
	expect_equal(unname(sim$full_fit$coefficients$cond),
		unname(coef(glm(y_sim ~ spec$X[, -1L], family = poisson))), tolerance = 1e-5)

	g <- zi_mixed_design("negbin")
	inf_nb <- InferenceCountZeroInflatedNegBin$new(g$des, verbose = FALSE)
	priv_nb <- inf_nb$.__enclos_env__$private
	invisible(inf_nb$compute_estimate())
	spec_nb <- priv_nb$get_likelihood_test_spec()
	null_nb <- spec_nb$fit_null(0)
	p_cond <- ncol(spec_nb$X); p_zi <- ncol(spec_nb$Xzi)
	null_nb$params <- c(log(30), 0, 0.1, rep(0, p_zi), log(5))
	null_nb$params[p_cond + 1L] <- -40
	set.seed(10)
	sim_nb <- priv_nb$simulate_under_lik_null(spec_nb, 0, null_nb)
	expect_false(is.null(sim_nb))
	y_nb <- sim_nb$worker_data$y
	expect_false(any(y_nb == 0))
	ref_nb <- MASS::glm.nb(y_nb ~ spec_nb$X[, -1L])
	expect_equal(as.numeric(sim_nb$full_fit$params[seq_len(p_cond)]), unname(coef(ref_nb)), tolerance = 1e-3)
})
