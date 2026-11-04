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
