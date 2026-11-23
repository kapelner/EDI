library(testthat)
library(EDI)

# v1.1.0-TODO-265 (DECISION-v1.1.0-TODO-265, owner 2026-11-23). The KK CLMM randomization p-value grew faster
# than n because clmm_accept_fit()'s Newton retry reran the kernel's whole variance multistart (the start plus
# log sigma -1, 0, 1, -8, each with numerical Hessians): 6-9 s of a 7-10 s redraw at n = 1000. The retry now
# polishes from the L-BFGS point only (fast_ordinal_clmm_cpp(variance_multistart = FALSE)), except for a fit at
# the sigma -> 0 boundary with gradient norm > clmm_retry_multistart_gradient (1e-3), where single-start Newton
# can stay on the flat boundary while another start reaches the interior MLE.
# Checked: (1) the kernel flag runs one start and, from a stationary point, gives the multistart result;
# (2) the retry's flag for an interior and a boundary fit; (3) the boundary case of
# test-ordinal-kk-clmm-stationary-fit-kkt.R still reaches the interior optimum.

gen <- function(seed, n, sb) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "ordinal", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w(); m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(c(m, 1)))[pmax(m, 1)], 0) * sb
	eta <- 0.5 * w + 0.4 * X$x + u
	cp <- sapply(c(-1, 0, 1), function(t) plogis(t - eta)); uu <- runif(n)
	des$add_all_subject_responses(1L + rowSums(uu > cp))
	des
}
kernel_args <- function(p) {
	X <- p$clmm_X_for_rcpp(); yl <- sort(unique(p$y))
	list(X = X, y = as.integer(match(p$y, yl)), group_id = as.integer(p$clmm_group_id()), K = length(yl), j_T = 0L,
		link = "logit", estimate_only = TRUE)
}

test_that("variance_multistart = FALSE polishes from the given point and matches the multistart there", {
	des <- gen(2200L, 200L, 0.6)
	inf <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
	p <- inf$.__enclos_env__$private
	fit <- p$cached_mod
	a <- kernel_args(p)
	a$warm_start_params <- as.numeric(c(fit$alpha, fit$b, fit$log_sigma))
	a$optimization_alg <- "newton_raphson"; a$eps_g <- 1e-6
	one <- do.call(EDI:::fast_ordinal_clmm_cpp, c(a, list(variance_multistart = FALSE)))
	all5 <- do.call(EDI:::fast_ordinal_clmm_cpp, a)
	expect_equal(one$b, all5$b, tolerance = 1e-8, scale = 1)
	expect_equal(one$log_sigma, all5$log_sigma, tolerance = 1e-6, scale = 1)
	expect_lte(abs(one$neg_loglik - all5$neg_loglik), 1e-9)
	expect_lte(one$gradient_norm, 1e-4)
	# Started far from the optimum, one start keeps its own basin's answer: a different (worse) value than the
	# multistart from log sigma = -8 is possible, never a better one.
	b <- a; b$warm_start_params[length(b$warm_start_params)] <- -8
	far_one <- do.call(EDI:::fast_ordinal_clmm_cpp, c(b, list(variance_multistart = FALSE)))
	far_all <- do.call(EDI:::fast_ordinal_clmm_cpp, b)
	expect_lte(far_all$neg_loglik, far_one$neg_loglik + 1e-9)
})

test_that("the Newton retry keeps the variance multistart only for a large-gradient boundary fit", {
	des <- gen(2201L, 60L, 0)
	inf <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	seen <- list()
	real <- EDI:::fast_ordinal_clmm_cpp
	local_mocked_bindings(fast_ordinal_clmm_cpp = function(...) {
		args <- list(...)
		if (identical(args$optimization_alg, "newton_raphson")) seen[[length(seen) + 1L]] <<- args$variance_multistart
		real(...)
	}, .package = "EDI")
	a <- kernel_args(p); a$eps_g <- 1e-12
	base <- do.call(real, a)
	mk <- function(log_sigma, gn) { f <- base; f$converged <- TRUE; f$log_sigma <- log_sigma; f$gradient_norm <- gn; f }
	p$clmm_accept_fit(mk(-0.5, 5e-3), a)       # interior, large gradient: single start
	p$clmm_accept_fit(mk(-5, 2e-4), a)         # boundary, small gradient: single start
	p$clmm_accept_fit(mk(-5, 5e-3), a)         # boundary, gradient > 1e-3: multistart
	expect_identical(unlist(seen), c(FALSE, FALSE, TRUE))
})

test_that("a loosened fit stuck at the boundary still reaches the interior optimum through the retry", {
	des <- gen(1060L, 60L, 0.6)
	inf <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$clmm_eps_g <- 1e-2
	est <- unname(inf$compute_estimate(estimate_only = TRUE))
	ref <- unname(InferenceOrdinalKKCLMM$new(des, verbose = FALSE)$compute_estimate(estimate_only = TRUE))
	expect_equal(est, ref, tolerance = 1e-5, scale = 1)
	expect_gt(p$cached_mod$log_sigma, -4.5)
})
