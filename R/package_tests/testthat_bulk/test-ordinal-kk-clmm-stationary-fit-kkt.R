library(testthat)
library(EDI)

# v1.0.5 TODO-31 (bug_fix_plans/clmm_sigma_collapse_false_convergence.md TODO-3/TODO-4, E4-E6;
# G6 #45 (iii)(a), 2026-10-22). The native CLMM kernel's `converged` is LBFGSpp's lenient flag
# (the relative-f stop counts as converged), and at the old clmm_eps_g = 1e-6 every class fit
# stopped with gradient norm ~1e-2 (360/360 in the sweep) and the treatment up to 6.4e-3 from the
# stationary point. With clmm_eps_g = 1e-12 plus the gradient acceptance (<= 1e-4, one Newton
# retry, else NA "kk_clmm_rcpp_not_stationary") every class fit is a stationary point: the
# treatment agrees with a kernel Newton polish, and a lower-variance-boundary fit has a positive
# one-sided tau-score (KKT). After plan TODO-5 (C++), also assert gradient_norm <= max(1e-5, eps_g)
# and variance_boundary_tau_score > 0 whenever variance_boundary_hit.

cls <- c(logit = "InferenceOrdinalKKCLMM", probit = "InferenceOrdinalKKCLMMProbit",
	cauchit = "InferenceOrdinalKKCLMMCauchit", cloglog = "InferenceOrdinalKKCLMMCloglog")
Fc <- list(logit = plogis, probit = pnorm, cauchit = pcauchy, cloglog = function(z) -expm1(-exp(z)))

gen <- function(seed, link, n, sb) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "ordinal", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w(); m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(c(m, 1)))[pmax(m, 1)], 0) * sb
	eta <- 0.5 * w + 0.4 * X$x + u
	cp <- sapply(c(-1, 0, 1), function(t) Fc[[link]](t - eta)); uu <- runif(n)
	y <- 1L + rowSums(uu > cp)
	des$add_all_subject_responses(y)
	des
}

test_that("every KK CLMM class fit is stationary (gradient, Newton polish, boundary KKT)", {
	n_boundary <- 0L
	for (link in names(cls)) for (n in c(60L, 200L)) for (sb in c(0, 0.6)) for (s in 1:3) {
		info <- sprintf("%s n=%d sb=%.1f seed=%d", link, n, sb, s)
		des <- gen(1000L * s + n, link, n, sb)
		inf <- get(cls[[link]])$new(des, verbose = FALSE)
		est <- unname(inf$compute_estimate(estimate_only = TRUE))
		p <- inf$.__enclos_env__$private
		fit <- p$cached_mod
		expect_true(is.finite(est), info = info)
		expect_true(isTRUE(fit$converged), info = info)
		expect_lte(fit$gradient_norm, 1e-4)
		X <- p$clmm_X_for_rcpp(); gid <- as.integer(p$clmm_group_id())
		yl <- sort(unique(p$y)); y <- as.integer(match(p$y, yl)); K <- length(yl)
		par <- c(fit$alpha, fit$b, fit$log_sigma)
		call <- function(...) EDI:::fast_ordinal_clmm_cpp(X = X, y = y, group_id = gid, K = K, j_T = 0L,
			link = link, estimate_only = TRUE, optimization_alg = "newton_raphson", eps_g = 1e-10, ...)
		polish <- call(warm_start_params = par)
		expect_lte(polish$neg_loglik, fit$neg_loglik + 1e-8)
		expect_equal(est, polish$b[1L], tolerance = 1e-5, scale = 1, info = info)
		if (fit$log_sigma <= -4.5) {
			n_boundary <- n_boundary + 1L
			expect_true(isTRUE(p$cached_values$clmm_variance_boundary), info = info)
			prof <- function(ls) call(warm_start_params = replace(par, length(par), ls),
				fixed_idx = length(par), fixed_values = ls)$neg_loglik
			expect_gt((prof(log(0.1)) - prof(-5)) / 0.01, 0, label = paste("tau-score", info))
		}
	}
	expect_gt(n_boundary, 0L)                                      # the boundary branch is exercised
})

test_that("a non-stationary native fit is retried with Newton, and NA with its own reason if that fails", {
	des <- gen(1060L, "logit", 60L, 0.6)
	# Force the first fit to stop early (non-stationary): loose tolerance, acceptance as shipped.
	inf <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$clmm_eps_g <- 1e-2
	est <- unname(inf$compute_estimate(estimate_only = TRUE))
	expect_true(is.finite(est))
	expect_lte(p$cached_mod$gradient_norm, 1e-4)                   # the accepted fit is the retry
	ref <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	expect_equal(est, unname(ref$compute_estimate(estimate_only = TRUE)), tolerance = 1e-5, scale = 1)
	# An unattainable acceptance threshold: converged-but-not-stationary -> NA with the new reason.
	bad <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	bp <- bad$.__enclos_env__$private
	bp$clmm_gradient_accept <- 0
	expect_true(is.na(bad$compute_estimate(estimate_only = TRUE)))
	expect_true(bad$is_nonestimable("estimate"))
	expect_identical(bad$get_nonestimable_reason(), "kk_clmm_rcpp_not_stationary")
	expect_true(is.na(bp$compute_ri_estimate_rcpp()))
})
