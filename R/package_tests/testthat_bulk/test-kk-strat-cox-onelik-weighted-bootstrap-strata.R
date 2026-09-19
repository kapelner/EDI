library(testthat)
library(EDI)
library(survival)

# InferenceSurvivalKKStratCoxPHOneLik$compute_estimate_with_bootstrap_weights()
# (inference_survival_KK_strat_cox.R) dispatches to weighted_cox_bootstrap_surrogate_fit()
# with an explicit `strata` argument (matched pairs share a stratum id;
# reservoir singletons each get their own distinct stratum) -- a code path
# distinct from the already-covered KK-LWA-Cox-OneLik (no strata argument at
# all). Grepped "KKStratCox" together with "bootstrap_weights" across
# testthat/testthat_bulk/R/EDI/tests/testthat: only name-existence checks in
# test-partial-likelihood-migration-baseline.R, never an actual invocation
# with real weights against an independent reference.

make_kk_strat_cox_onelik_fixture <- function(n = 24L, seed = 20260918L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y_lat <- exp(0.8 - 0.3 * ((w_i + 1) / 2) + 0.15 * X$x1[i]) * rexp(1L)
		cens <- rexp(1L, rate = 0.15)
		if (y_lat <= cens) {
			des$add_one_subject_response(i, y = max(y_lat, 0.05))
		} else {
			des$add_one_subject_response(i, y_L = max(cens, 0.05), y_R = Inf)
		}
	}
	inf <- InferenceSurvivalKKStratCoxPHOneLik$new(des)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	list(inf = inf, priv = priv)
}

reference_strata_for <- function(priv) {
	m_vec <- priv$m
	m_vec[is.na(m_vec)] <- 0L
	strata <- m_vec
	res_idx <- which(strata == 0L)
	if (length(res_idx) > 0L) {
		max_m <- max(strata)
		strata[res_idx] <- max_m + seq_along(res_idx)
	}
	strata
}

test_that("compute_estimate_with_bootstrap_weights matches an independent stratified weighted coxph fit", {
	f <- make_kk_strat_cox_onelik_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	expect_true(ctx$n_units < f$priv$n)

	set.seed(1)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	row_weights <- f$priv$expand_subject_or_block_weights_to_row_weights(unit_weights)

	m_vec <- f$priv$m
	m_vec[is.na(m_vec)] <- 0L
	for (m0 in setdiff(unique(m_vec), 0L)) {
		expect_equal(length(unique(row_weights[m_vec == m0])), 1L)
	}

	est <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	strata <- reference_strata_for(f$priv)
	X_fit <- cbind(treatment = f$priv$w, f$priv$get_X())
	dat <- as.data.frame(X_fit)
	dat$time <- f$priv$y
	dat$dead <- f$priv$dead
	dat$strata <- factor(strata)
	ref <- survival::coxph(
		stats::as.formula(paste0("survival::Surv(time, dead) ~ ", paste(colnames(X_fit), collapse = " + "), " + strata(strata)")),
		data = dat, weights = row_weights
	)
	expect_equal(est, unname(coef(ref)["treatment"]), tolerance = 1e-6)

	# A non-stratified reference must NOT match -- confirms the strata argument
	# genuinely changes the fit, not a no-op.
	ref_no_strata <- survival::coxph(
		stats::as.formula(paste0("survival::Surv(time, dead) ~ ", paste(colnames(X_fit), collapse = " + "))),
		data = dat, weights = row_weights
	)
	expect_false(isTRUE(all.equal(est, unname(coef(ref_no_strata)["treatment"]), tolerance = 1e-4)))

	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(unit_weights, estimate_only = TRUE), est)
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
})

test_that("effectively-constant unit weights shortcut to the primary MLE rather than the strata surrogate", {
	f <- make_kk_strat_cox_onelik_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	direct <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))[1L]

	shortcut <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units))
	expect_equal(shortcut, direct, tolerance = 1e-8)

	scaled <- f$inf$compute_estimate_with_bootstrap_weights(rep(3.5, ctx$n_units))
	expect_equal(scaled, direct, tolerance = 1e-8)

	set.seed(2)
	unit_weights <- runif(ctx$n_units, 0.5, 2)
	weighted <- f$inf$compute_estimate_with_bootstrap_weights(unit_weights)
	expect_false(isTRUE(all.equal(weighted, direct)))
})

test_that("degenerate all-zero unit weights make the surrogate fit fail and return NA", {
	f <- make_kk_strat_cox_onelik_fixture()
	ctx <- f$priv$current_bayesian_bootstrap_context
	result <- f$inf$compute_estimate_with_bootstrap_weights(rep(0, ctx$n_units))
	expect_true(is.na(result))
})
