library(testthat)
library(EDI)

# KK (matched pairs + reservoir) count classes against independent constructions:
# InferenceCountKKCondPoissonOneLik = the joint conditional-Poisson(pairs, Binomial) + reservoir-Poisson maximum
# likelihood (derivative-free optimum), InferenceCountPoissonKKGEE ~ geepack::geeglm(poisson, exchangeable), and
# InferenceCountKKGLMM = the random-intercept Poisson GLMM (glmer). SUSPECTED SOURCE BUG (pinned, not fixed):
# the KK GLMM classes fit fast_poisson_glmm_cpp with optimization_alg = "newton_raphson", which on some datasets
# (the seed-6 fixture here) collapses log sigma to about -3.5, reports converged = TRUE with a gradient norm of
# ~0.3, and lands at a worse likelihood and a biased treatment coefficient (0.5475 vs the L-BFGS / glmer 0.5359).
# On most datasets the two optimizers agree (checked below).

skip_if_not_installed("geepack")
skip_if_not_installed("lme4")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed, sd_u = 0.6) {
	set.seed(seed)
	n <- 120L
	des <- DesignSeqOneByOneKK14$new(response_type = "count", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * sd_u
	y <- as.numeric(rpois(n, exp(0.4 + 0.5 * w + 0.3 * X$x + u)))
	des$add_all_subject_responses(y)
	d <- data.frame(y = y, w = w, x = X$x, m = m)
	d$g <- ifelse(d$m > 0, paste0("p", d$m), paste0("s", seq_along(d$m)))
	list(des = des, d = d)
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)

test_that("conditional-Poisson one-likelihood class equals the joint pair-binomial + reservoir-Poisson maximum likelihood", {
	f <- fx(6L)
	d <- f$d
	pr <- d[d$m > 0, ]
	rows <- t(vapply(sort(unique(pr$m)), function(k) { a <- pr[pr$m == k, ]; t1 <- a[a$w == 1, ]; t0 <- a[a$w == 0, ]; c(t1$y, t1$y + t0$y, t1$x - t0$x) }, numeric(3)))
	res <- d[d$m == 0, ]
	ll <- function(p) sum(dbinom(rows[, 1], rows[, 2], plogis(p[2] + rows[, 3] * p[3]), log = TRUE)) +
		sum(dpois(res$y, exp(p[1] + p[2] * res$w + p[3] * res$x), log = TRUE))
	o <- optim(c(0.3, 0.4, 0.2), function(p) -ll(p), method = "BFGS", control = list(reltol = 1e-12))
	expect_equal(unname(new_inf("InferenceCountKKCondPoissonOneLik", f$des)$compute_estimate()), o$par[2], tolerance = 1e-4)
})

test_that("KK GEE class is within 1% of geeglm (exchangeable) clustered by pair", {
	f <- fx(6L)
	o <- f$d[order(f$d$g), ]
	gee <- geepack::geeglm(y ~ w + x, id = factor(g), data = o, family = poisson, corstr = "exchangeable")
	expect_equal(unname(new_inf("InferenceCountPoissonKKGEE", f$des)$compute_estimate()), unname(coef(gee)["w"]), tolerance = 1e-2, scale = 1)
})

test_that("KK GLMM class agrees with the L-BFGS fit / glmer on datasets where the Newton optimizer behaves", {
	for (s in c(701L, 702L, 703L, 704L)) {
		f <- fx(s, sd_u = 0.7)
		fit <- suppressMessages(suppressWarnings(lme4::glmer(y ~ w + x + (1 | g), family = poisson, data = f$d, nAGQ = 25)))
		expect_equal(unname(new_inf("InferenceCountKKGLMM", f$des)$compute_estimate()), unname(lme4::fixef(fit)["w"]), tolerance = 5e-3, scale = 1, info = as.character(s))
	}
})

test_that("SUSPECTED SOURCE BUG (pinned): on the seed-6 fixture the Newton-optimizer KK GLMM fit collapses sigma and is biased vs L-BFGS / glmer", {
	f <- fx(6L)
	inf <- new_inf("InferenceCountKKGLMM", f$des)
	est <- unname(inf$compute_estimate())
	pv <- inf$.__enclos_env__$private
	expect_identical(pv$optimization_alg, "newton_raphson")
	fit <- pv$cached_mod
	expect_true(fit$converged)
	expect_lt(as.numeric(fit$log_sigma), -2.5)                              # sigma collapsed
	expect_gt(as.numeric(fit$gradient_norm), 0.1)                           # yet flagged converged with a large gradient
	glmer_fit <- suppressMessages(suppressWarnings(lme4::glmer(y ~ w + x + (1 | g), family = poisson, data = f$d, nAGQ = 25)))
	expect_gt(abs(est - unname(lme4::fixef(glmer_fit)["w"])), 0.005)         # biased relative to the ML solution (0.5359)
	Xf <- as.matrix(pv$create_design_matrix()); g <- as.integer(pv$m); g[is.na(g)] <- 0L; ri <- which(g == 0L); g[ri] <- max(g) + seq_along(ri)
	lb <- K("fast_poisson_glmm_cpp")(Xf, as.numeric(pv$y), g, 1L, n_gh = 40L)
	expect_equal(as.numeric(lb$b[2]), unname(lme4::fixef(glmer_fit)["w"]), tolerance = 1e-3)   # the L-BFGS kernel fit is right
	expect_gt(as.numeric(fit$neg_loglik) - as.numeric(lb$neg_loglik), 1)
})
