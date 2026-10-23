library(testthat)
library(EDI)

# v1.0.5 TODO-31 (bug_fix_plans/clmm_sigma_collapse_false_convergence.md TODO-1, E2; owner
# decision G6 #45 (i)/(ii)(a), 2026-10-22). ordinal::clmm fits the log-log model when asked for
# link = "cloglog" and the cloglog model when asked for "loglog" (ordinal 2026.7.26; clm is
# correct). EDI's ordinal_clmm_link_name() probes this once per session and returns the clmm name
# that fits EDI's cloglog model. This file pins (1) the probe/helper contract and (2) that EDI's
# native cloglog CLMM equals ordinal::clmm under the probed name, and is a better true-cloglog fit
# (independent stats::integrate() oracle) than clmm's mislabelled "cloglog" fit.

skip_if_not_installed("ordinal")

F_cloglog <- function(z) -expm1(-exp(z))

# True-cloglog integrated NLL: groups g, thresholds th, linear predictor eta, sigma sig.
cloglog_oracle_nll <- function(y, eta, g, th, sig) {
	up <- c(th, Inf)[y]; lo <- c(-Inf, th)[y]
	tot <- 0
	for (gg in unique(g)) {
		ii <- which(g == gg)
		f <- function(bb) vapply(bb, function(b1) prod(
			F_cloglog(up[ii] - eta[ii] - b1) - F_cloglog(lo[ii] - eta[ii] - b1)), numeric(1L)) * dnorm(bb, 0, sig)
		tot <- tot + log(integrate(f, -10 * sig, 10 * sig, rel.tol = 1e-10)$value)
	}
	-tot
}

test_that("ordinal_clmm_link_name is the identity except for cloglog, which follows the cached probe", {
	for (lk in c("logit", "probit", "cauchit")) expect_identical(EDI:::ordinal_clmm_link_name(lk), lk)
	seed_before <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	probe <- EDI:::ordinal_clmm_cloglog_link_probe()
	seed_after <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	expect_identical(seed_after, seed_before)                     # the probe uses no RNG
	expect_true(probe$name %in% c("cloglog", "loglog"))
	# The matching name's -logLik equals the true-cloglog oracle; the other is far off.
	matched <- probe$name; other <- setdiff(c("cloglog", "loglog"), matched)
	expect_lt(abs(probe$neg_loglik[[matched]] - probe$oracle_nll[[matched]]), 1e-3)
	expect_gt(abs(probe$neg_loglik[[other]] - probe$oracle_nll[[other]]), 1)
	# Installed ordinal (2026.7.26) has the swap; a future upstream fix flips this automatically.
	if (utils::packageVersion("ordinal") <= "2026.7.26") expect_identical(matched, "loglog")
	expect_identical(EDI:::ordinal_clmm_link_name("cloglog"), matched)
	cache <- EDI:::EDI_ORDINAL_CLMM_LINK_NAME_CACHE
	key <- paste0("cloglog@", as.character(utils::packageVersion("ordinal")))
	expect_identical(get(key, envir = cache), matched)
	t0 <- proc.time()[[3L]]
	expect_identical(EDI:::ordinal_clmm_link_name("cloglog"), matched)
	expect_lt(proc.time()[[3L]] - t0, 0.1)                       # cached: no refit
})

test_that("EDI's cloglog CLMM equals ordinal::clmm under the probed name and beats clmm's mislabelled fit", {
	set.seed(1)
	G <- 400L; n <- 2L * G; g <- rep(seq_len(G), each = 2L)
	w <- rbinom(n, 1, 0.5); b <- rnorm(G, 0, 1.2)[g]
	eta <- 0.6 * w + b; th <- c(-1, 0, 1); u <- runif(n)
	y <- 1L + rowSums(u > sapply(th, function(t) F_cloglog(t - eta)))
	d <- data.frame(y = factor(y, ordered = TRUE), w = w, g = factor(g))
	k <- EDI:::fast_ordinal_clmm_cpp(X = cbind(w = w), y = as.integer(y), group_id = as.integer(g),
		K = 4L, j_T = 0L, link = "cloglog", estimate_only = TRUE, eps_g = 1e-12)
	expect_true(isTRUE(k$converged))
	ref <- suppressWarnings(ordinal::clmm(y ~ w + (1 | g), data = d,
		link = EDI:::ordinal_clmm_link_name("cloglog"), nAGQ = 10))
	expect_equal(k$b[1L], unname(coef(ref)["w"]), tolerance = 2e-3, scale = 1)
	expect_equal(k$log_sigma, log(ref$ST[[1L]][1L]), tolerance = 2e-2, scale = 1)
	expect_lt(abs(k$neg_loglik + as.numeric(logLik(ref))), 1e-2)
	# Independent oracle: true-cloglog NLL at EDI's fit vs at clmm's "cloglog"-named fit.
	wrong <- suppressWarnings(ordinal::clmm(y ~ w + (1 | g), data = d,
		link = setdiff(c("cloglog", "loglog"), EDI:::ordinal_clmm_link_name("cloglog")), nAGQ = 10))
	th_edi <- cumsum(c(k$alpha[1L], exp(k$alpha[-1L])))
	nll_edi <- cloglog_oracle_nll(y, k$b[1L] * w, g, th_edi, exp(k$log_sigma))
	nll_wrong <- cloglog_oracle_nll(y, unname(coef(wrong)["w"]) * w, g,
		unname(coef(wrong)[1:3]), wrong$ST[[1L]][1L])
	expect_lt(nll_edi, nll_wrong)
	expect_lt(abs(nll_edi - k$neg_loglik), 1e-2)                  # 20-node GH vs exact integration
})
