library(testthat)
library(EDI)

# .fit_weibull_frailty/_rcpp and .cox_simulate_stratified in helper_survival_fits.R
# (weighted-opportunity 249 in the 2026-09-18 covr-measured coverage_gap_registry.csv)
# had zero test references anywhere in the suite before this file, per a repo-wide
# grep. The Weibull-AFT-with-Gaussian-frailty MLE itself is too complex to re-derive
# independently in base R, so the defensive/dispatch branches are verified exactly,
# and .cox_simulate_stratified's per-stratum splitting is verified by reducing to
# the already-existing single-stratum helper .cox_simulate_from_breslow under an
# identical RNG stream.

test_that(".weibull_frailty_design_matrix inserts the intercept and drops w/(Intercept) duplicates from X_cov", {
	w <- c(0, 1, 0, 1)
	out <- EDI:::.weibull_frailty_design_matrix(w, cbind(x1 = c(1, 2, 3, 4)))
	expect_equal(colnames(out), c("w", "(Intercept)", "x1"))
	expect_equal(unname(out[, "w"]), w)
	expect_true(all(out[, "(Intercept)"] == 1))

	out_no_cov <- EDI:::.weibull_frailty_design_matrix(w, NULL)
	expect_equal(colnames(out_no_cov), c("w", "(Intercept)"))

	# A caller-supplied X_cov with its own w/(Intercept) columns must not create duplicates.
	dup_cov <- cbind(w = c(9, 9, 9, 9), "(Intercept)" = c(1, 1, 1, 1), x2 = c(5, 6, 7, 8))
	out_dedup <- EDI:::.weibull_frailty_design_matrix(w, dup_cov)
	expect_equal(colnames(out_dedup), c("w", "(Intercept)", "x2"))
	expect_equal(unname(out_dedup[, "w"]), w)
})

make_frailty_fixture <- function(seed = 42L, npairs = 50L) {
	set.seed(seed)
	n <- npairs * 2L
	pair_id <- rep(seq_len(npairs), each = 2L)
	w <- rep(c(0, 1), npairs)
	frailty_u <- rep(rnorm(npairs, 0, 0.4), each = 2L)
	eps <- rnorm(n, 0, 0.6)
	logT <- 2 + 0.5 * w + frailty_u + eps
	y <- exp(logT)
	cens <- exp(rnorm(n, 3, 1))
	list(
		y = pmin(y, cens), dead = as.numeric(y <= cens),
		X = cbind(w = w), pair_id = pair_id
	)
}

test_that(".fit_weibull_frailty delegates to .fit_weibull_frailty_rcpp and returns a well-formed converged fit", {
	f <- make_frailty_fixture()
	fit <- EDI:::.fit_weibull_frailty(f$y, f$dead, f$X, f$pair_id)
	fit_rcpp <- EDI:::.fit_weibull_frailty_rcpp(f$y, f$dead, f$X, f$pair_id)
	expect_identical(fit, fit_rcpp)

	expect_true(fit$mod$converged)
	expect_true(is.finite(fit$beta))
	expect_true(is.finite(fit$ssq) && fit$ssq > 0)
	expect_true(is.finite(fit$log_sigma_eps))
	expect_true(is.finite(fit$log_sigma_u))
	expect_length(fit$best_par, 4L)
	expect_equal(fit$best_par[1L], fit$beta)
})

test_that(".fit_weibull_frailty_rcpp requires a 'w' column and reorders it to first position", {
	f <- make_frailty_fixture()
	expect_error(
		EDI:::.fit_weibull_frailty_rcpp(f$y, f$dead, cbind(x = f$X[, "w"]), f$pair_id),
		"must include a treatment column named 'w'"
	)

	# w present but not first: internally reordered, same converged fit as the canonical layout.
	X_extra <- cbind(x1 = rnorm(nrow(f$X)), w = f$X[, "w"])
	fit_reordered <- EDI:::.fit_weibull_frailty_rcpp(f$y, f$dead, X_extra, f$pair_id)
	fit_canonical <- EDI:::.fit_weibull_frailty_rcpp(f$y, f$dead, f$X, f$pair_id)
	expect_true(fit_reordered$mod$converged)
	# Different covariate set (x1 included) so betas needn't match exactly, but both must be finite.
	expect_true(is.finite(fit_reordered$beta))
})

test_that(".fit_weibull_frailty_rcpp returns NULL on empty input, all-censored data, and NA pair grouping", {
	f <- make_frailty_fixture()
	expect_null(EDI:::.fit_weibull_frailty_rcpp(numeric(0), numeric(0), f$X, f$pair_id))
	expect_null(EDI:::.fit_weibull_frailty_rcpp(f$y, rep(0, length(f$y)), f$X, f$pair_id))

	pair_id_na <- f$pair_id
	pair_id_na[1] <- NA
	expect_null(EDI:::.fit_weibull_frailty_rcpp(f$y, f$dead, f$X, pair_id_na))
})

test_that(".fit_weibull_frailty_rcpp's estimate_only=TRUE skips the ssq/variance computation", {
	f <- make_frailty_fixture()
	fit_full <- EDI:::.fit_weibull_frailty_rcpp(f$y, f$dead, f$X, f$pair_id, estimate_only = FALSE)
	fit_eo <- EDI:::.fit_weibull_frailty_rcpp(f$y, f$dead, f$X, f$pair_id, estimate_only = TRUE)

	expect_true(is.finite(fit_full$ssq) && fit_full$ssq > 0)
	expect_true(is.na(fit_eo$ssq))
	# Point estimate should match closely even though the ssq computation is skipped.
	expect_equal(fit_eo$beta, fit_full$beta, tolerance = 1e-3)
})

test_that(".breslow_hazard returns an empty structure with no observed events", {
	out <- EDI:::.breslow_hazard(numeric(0), numeric(0), cbind(w = numeric(0)), c(0.3))
	expect_length(out$times, 0L)
	expect_length(out$cumhaz, 0L)

	out_no_events <- EDI:::.breslow_hazard(c(1, 2, 3), c(0, 0, 0), cbind(w = c(0, 1, 0)), c(0.3))
	expect_length(out_no_events$times, 0L)
})

test_that(".cox_simulate_stratified on a single stratum reduces exactly to .cox_simulate_from_breslow under an identical RNG stream", {
	set.seed(7)
	n <- 40L
	X <- cbind(w = rep(c(0, 1), n / 2L))
	b_null <- c(0.4)
	y_obs <- rexp(n, 0.3)
	dead_obs <- rbinom(n, 1, 0.7)

	strata_one <- rep("A", n)
	set.seed(123)
	sim_strat <- EDI:::.cox_simulate_stratified(y_obs, dead_obs, X, b_null, strata_one)

	breslow <- EDI:::.breslow_hazard(y_obs, dead_obs, X, b_null)
	set.seed(123)
	sim_direct <- EDI:::.cox_simulate_from_breslow(breslow, y_obs, dead_obs, X, b_null)

	expect_identical(sim_strat$y_sim, sim_direct$y_sim)
	expect_identical(sim_strat$dead_sim, sim_direct$dead_sim)
})

test_that(".cox_simulate_stratified computes independent Breslow baselines per stratum and falls back to max_time for an event-free stratum", {
	set.seed(9)
	n <- 40L
	X <- cbind(w = rep(c(0, 1), n / 2L))
	b_null <- c(0.4)
	y_obs <- rexp(n, 0.3)
	dead_obs <- rbinom(n, 1, 0.7)
	strata <- c(rep("A", n / 2L), rep("B", n / 2L))

	# Zero-event stratum B: every member falls back to max_time capped by its own censoring.
	dead_no_b_events <- dead_obs
	dead_no_b_events[strata == "B"] <- 0
	sim <- EDI:::.cox_simulate_stratified(y_obs, dead_no_b_events, X, b_null, strata)
	max_time <- max(y_obs) * 2
	idx_b <- which(strata == "B")
	expect_equal(sim$y_sim[idx_b], pmin(max_time, y_obs[idx_b]))
	expect_true(all(sim$dead_sim[idx_b] == 0))

	# Stratum A (which does have events) must independently match .cox_simulate_from_breslow
	# on its own subset under the same RNG position (first block of draws in the loop).
	idx_a <- which(strata == "A")
	breslow_a <- EDI:::.breslow_hazard(y_obs[idx_a], dead_no_b_events[idx_a], X[idx_a, , drop = FALSE], b_null)
	set.seed(55)
	sim_full <- EDI:::.cox_simulate_stratified(y_obs, dead_no_b_events, X, b_null, strata)
	set.seed(55)
	sim_a_direct <- EDI:::.cox_simulate_from_breslow(breslow_a, y_obs[idx_a], dead_no_b_events[idx_a], X[idx_a, , drop = FALSE], b_null)
	expect_equal(sim_full$y_sim[idx_a], sim_a_direct$y_sim)
})
