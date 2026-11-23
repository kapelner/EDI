library(testthat)
library(EDI)

# v1.1.0-TODO-267 (owner 2026-11-24, DECISION-v1.1.0-TODO-267 (a)): the KK CLMM classes offer an opt-in
# randomization statistic, compute_rand_two_sided_pval(type = "score"): the score for the treatment
# coefficient at the null fit (treatment coefficient fixed at 0), T(w) = sum_i w_i r_i, one inner product per
# redraw. Checked: the analytic score equals a numeric derivative of the null log-likelihood; the p-value equals
# a hand computation on the same draws (+1 rule, both tails, one-sided); seeded reproducibility and its own
# cache entry; the default (type = NULL) is unchanged; other types, nonzero delta and non-CLMM classes refuse it.

gen <- function(seed, n = 80L, sb = 0.6, effect = 0) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "ordinal", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w(); m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(c(m, 1)))[pmax(m, 1)], 0) * sb
	eta <- effect * w + 0.4 * X$x + u
	cp <- sapply(c(-1, 0, 1), function(t) plogis(t - eta)); uu <- runif(n)
	des$add_all_subject_responses(1L + rowSums(uu > cp))
	des
}

# Marginal log-likelihood of the CLMM (same 20-node Gauss-Hermite rule as the kernel) at the null fit's
# thresholds, covariate effects and sigma, with the treatment coefficient set to b_T.
link_cdf <- list(logit = plogis, probit = pnorm, cauchit = pcauchy, cloglog = function(z) -expm1(-exp(z)))
null_loglik <- function(p, b_T) {
	Fc <- link_cdf[[p$clmm_link()]]
	X <- p$clmm_X_for_rcpp(); gid <- as.integer(p$clmm_group_id())
	yl <- sort(unique(p$y)); y <- match(p$y, yl); K <- length(yl)
	a <- list(X = X, y = as.integer(y), group_id = gid, K = K, j_T = 0L, link = p$clmm_link(), estimate_only = TRUE,
		eps_g = 1e-12, fixed_idx = K, fixed_values = 0)
	f <- do.call(EDI:::fast_ordinal_clmm_cpp, a)
	alpha <- cumsum(c(f$alpha[1], exp(f$alpha[-1]))); b <- f$b; b[1] <- b_T
	J <- matrix(0, 20, 20); for (k in 1:19) { J[k, k + 1] <- J[k + 1, k] <- sqrt(k / 2) }
	es <- eigen(J, symmetric = TRUE); lw <- log(sqrt(pi) * es$vectors[1, ]^2) - 0.5 * log(pi)
	E <- outer(drop(X %*% b), sqrt(2) * exp(f$log_sigma) * es$values, "+")
	lp <- log(pmax(Fc(c(alpha, Inf)[y] - E) - Fc(c(-Inf, alpha)[y] - E), 1e-15))
	G <- sweep(rowsum(lp, gid), 2, lw, "+")
	sum(apply(G, 1, function(v) max(v) + log(sum(exp(v - max(v))))))
}

test_that("the score residuals give the derivative of the null log-likelihood in the treatment coefficient", {
	des <- gen(1)
	for (cls in c("InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMProbit", "InferenceOrdinalKKCLMMCauchit",
			"InferenceOrdinalKKCLMMCloglog")) {
		p <- get(cls)$new(des, verbose = FALSE)$.__enclos_env__$private
		r <- p$clmm_score_residuals()
		expect_length(r, 80L)
		h <- 1e-5
		numeric_score <- (null_loglik(p, h) - null_loglik(p, -h)) / (2 * h)
		expect_equal(sum(p$w * r), numeric_score, tolerance = 1e-5, scale = 1, info = cls)
	}
})

test_that("the score p-value is the +1 randomization p-value of sum(w * r) on the same draws", {
	inf <- InferenceOrdinalKKCLMM$new(gen(2), verbose = FALSE)
	inf$set_seed(5)
	p <- inf$.__enclos_env__$private
	perms <- p$generate_permutations(199L)
	r <- p$clmm_score_residuals()
	t0 <- drop(crossprod(perms$w_mat, r)); t <- sum(p$w * r)
	tol <- EDI:::rand_tie_tolerance(t0, t)
	ge <- sum(t0 >= t - tol); le <- sum(t0 <= t + tol); B <- length(t0)
	expect_equal(inf$compute_rand_two_sided_pval(r = 199L, type = "score"), min(1, 2 * (1 + min(ge, le)) / (1 + B)))
	expect_equal(inf$compute_rand_two_sided_pval(r = 199L, type = "score", alternative = "greater"), (1 + ge) / (1 + B))
	expect_equal(inf$compute_rand_two_sided_pval(r = 199L, type = "score", alternative = "less"), (1 + le) / (1 + B))
	# Supplied draws give the same answer as the design's own.
	expect_equal(inf$compute_rand_two_sided_pval(r = 199L, type = "score", permutations = perms),
		inf$compute_rand_two_sided_pval(r = 199L, type = "score"))
})

test_that("score p-values are seeded, cached under their own key, and leave the default statistic unchanged", {
	des <- gen(3)
	a <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE); a$set_seed(9)
	b <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE); b$set_seed(9)
	p_default_before <- a$compute_rand_two_sided_pval(r = 41L, show_progress = FALSE)
	p_score <- a$compute_rand_two_sided_pval(r = 41L, type = "score")
	expect_identical(a$compute_rand_two_sided_pval(r = 41L, show_progress = FALSE), p_default_before)
	expect_identical(b$compute_rand_two_sided_pval(r = 41L, type = "score"), p_score)
	keys <- names(a$.__enclos_env__$private$cached_values$resampling_distribution_cache$rand %||% list())
	if (length(keys)) expect_true(any(startsWith(keys, "type=score|")) && any(!startsWith(keys, "type=score|")))
	fresh <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE); fresh$set_seed(9)
	expect_identical(fresh$compute_rand_two_sided_pval(r = 41L, show_progress = FALSE), p_default_before)
})

test_that("every KK CLMM link offers type = 'score'; other types, delta != 0 and other classes refuse it", {
	des <- gen(4)
	for (cls in c("InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMProbit", "InferenceOrdinalKKCLMMCauchit",
			"InferenceOrdinalKKCLMMCloglog")) {
		inf <- get(cls)$new(des, verbose = FALSE); inf$set_seed(1)
		pv <- inf$compute_rand_two_sided_pval(r = 99L, type = "score")
		expect_true(is.finite(pv) && pv > 0 && pv <= 1, info = cls)
	}
	inf <- InferenceOrdinalKKCLMM$new(des, verbose = FALSE)
	expect_error(inf$compute_rand_two_sided_pval(type = "score", delta = 0.5), "delta = 0")
	# DECISION-v1.1.0-TODO-267b (d): the default statistic also refuses delta != 0 (the level shift would
	# test a different hypothesis than "log-odds coefficient = delta").
	expect_error(inf$compute_rand_two_sided_pval(r = 99L, delta = 0.5), "only delta = 0")
	expect_error(inf$compute_rand_two_sided_pval(type = "score", transform_responses = "log"), "transform_responses")
	expect_error(inf$compute_rand_two_sided_pval(type = "Zhang"))
	other <- InferenceOrdinalPropOddsRegr$new(des, verbose = FALSE)
	expect_error(other$compute_rand_two_sided_pval(type = "score"))
})
