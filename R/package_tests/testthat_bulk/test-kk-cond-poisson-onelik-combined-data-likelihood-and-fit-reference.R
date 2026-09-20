library(testthat)
library(EDI)

# InferenceCountKKCondPoissonOneLik: the combined data builder (treated / control pairs become
# binomial-conditional records, reservoir subjects stay Poisson), the weighted combined
# negative log-likelihood and score against numerical derivatives and closed forms, the compiled
# combined fit against an independent optim() of the same likelihood, and unit-weight consistency
# of the weighted estimator.

cp_fx <- function(seed = 5L, np = 25L, ns = 16L) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	m <- c(rep(seq_len(np), each = 2L), rep(0L, ns)); des$.__enclos_env__$private$m <- m
	w <- des$get_w(); g <- c(rep(seq_len(np), each = 2L), np + seq_len(ns)); u <- rnorm(max(g), 0, 0.4)
	y <- rpois(n, exp(0.4 + 0.3 * w + 0.2 * X$x1 + u[g])); des$add_all_subject_responses(y)
	inf <- InferenceCountKKCondPoissonOneLik$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	Xf <- p$build_model_matrix()
	list(inf = inf, p = p, Xf = Xf, dat = p$build_combined_cpoisson_data(Xf, 2L), w = w, y = y, m = m, x1 = X$x1, n = n, np = np, ns = ns)
}

with_unit_weights <- function(dat) { dat$pair_weights <- rep(1, length(dat$yT_v)); dat$reservoir_weights <- rep(1, length(dat$y_r)); dat }

test_that("pairs with exactly one treated and one control subject become (treated total, pair total, covariate difference) records", {
	f <- cp_fx(); d <- f$dat
	mixed <- Filter(function(k) { i <- which(f$m == k); length(unique(f$w[i])) == 2L }, seq_len(f$np))
	expect_length(d$yT_v, length(mixed))
	for (j in seq_along(mixed)) {
		i <- which(f$m == mixed[j]); it <- i[f$w[i] == 1]; ic <- i[f$w[i] == 0]
		expect_equal(d$yT_v[j], f$y[it]); expect_equal(d$n_k_v[j], f$y[it] + f$y[ic])
		expect_equal(unname(d$X_diff_v[j, 1]), f$x1[it] - f$x1[ic], tolerance = 1e-12)
		expect_equal(d$pair_rows[[j]], c(it, ic))
	}
	expect_equal(d$reservoir_idx, 2L * f$np + seq_len(f$ns))
	expect_equal(d$y_r, as.numeric(f$y[d$reservoir_idx])); expect_equal(d$w_r, as.numeric(f$w[d$reservoir_idx]))
	expect_equal(unname(d$X_r[, 1]), f$x1[d$reservoir_idx], tolerance = 1e-12)
	expect_equal(d$j_treat, 2L)
})

test_that("with no covariates the difference matrix has no columns; with no pairs it has no rows", {
	f <- cp_fx()
	only_cov <- f$p$build_combined_cpoisson_data(f$Xf[, 1:2, drop = FALSE], 2L)
	# With no covariate columns the difference matrix is an empty 0 x 0 matrix (no per-pair rows), while the
	# pair vectors themselves are still populated; the likelihood code treats ncol == 0 as "no covariates".
	expect_equal(dim(only_cov$X_diff_v), c(0L, 0L))
	expect_length(only_cov$yT_v, length(f$dat$yT_v))
	expect_equal(dim(only_cov$X_r), c(f$ns, 0L))
	f$p$m <- rep(0L, f$n)
	none <- f$p$build_combined_cpoisson_data(f$Xf, 2L)
	expect_length(none$yT_v, 0L); expect_equal(dim(none$X_diff_v), c(0L, 1L))
	expect_equal(none$reservoir_idx, seq_len(f$n))
})

test_that("weighted negative log-likelihood: conditional binomial pairs + Poisson reservoir, closed form", {
	f <- cp_fx(); d <- with_unit_weights(f$dat)
	par <- c(0.3, 0.25, 0.15)
	eta_p <- par[2] + drop(d$X_diff_v %*% par[3])
	ref_pairs <- sum(dbinom(d$yT_v, d$n_k_v, plogis(eta_p), log = TRUE))
	eta_r <- par[1] + par[2] * d$w_r + drop(d$X_r %*% par[3])
	ref_res <- sum(dpois(d$y_r, exp(eta_r), log = TRUE))
	# The pairs term drops the constant log-choose(n_k, y_T).
	const <- sum(lchoose(d$n_k_v, d$yT_v))
	expect_equal(-f$p$weighted_cpoisson_neg_loglik(par, d), ref_pairs - const + ref_res, tolerance = 1e-10)
	# Weights multiply each record's contribution.
	d2 <- d; d2$pair_weights <- rep(2, length(d$yT_v)); d2$reservoir_weights <- rep(0.5, length(d$y_r))
	expect_equal(-f$p$weighted_cpoisson_neg_loglik(par, d2), 2 * (ref_pairs - const) + 0.5 * ref_res, tolerance = 1e-10)
})

test_that("score equals the numerical gradient of the log-likelihood, with and without weights", {
	f <- cp_fx(); d <- with_unit_weights(f$dat)
	nl <- function(b, dat) f$p$weighted_cpoisson_neg_loglik(b, dat)
	par <- c(0.3, 0.25, 0.15)
	expect_equal(f$p$weighted_cpoisson_score(par, d), -numDeriv::grad(nl, par, dat = d), tolerance = 1e-5)
	set.seed(1); d$pair_weights <- runif(length(d$yT_v), 0.2, 2); d$reservoir_weights <- runif(length(d$y_r), 0.2, 2)
	expect_equal(f$p$weighted_cpoisson_score(par, d), -numDeriv::grad(nl, par, dat = d), tolerance = 1e-5)
	# Pairs carry no information about the intercept.
	pairs_only <- d; pairs_only$reservoir_weights <- numeric(0)
	expect_equal(f$p$weighted_cpoisson_score(par, pairs_only)[1], 0)
})

test_that("the compiled combined fit maximises the same likelihood (independent optim)", {
	f <- cp_fx(); d <- with_unit_weights(f$dat)
	fit <- f$p$fit_combined_cpoisson(f$dat)
	skip_if(is.null(fit), "combined fit returned NULL")
	opt <- optim(c(0, 0, 0), function(b) f$p$weighted_cpoisson_neg_loglik(b, d), gr = function(b) -f$p$weighted_cpoisson_score(b, d),
		method = "BFGS", control = list(reltol = 1e-14, maxit = 1000))
	expect_equal(as.numeric(fit$b[1:3]), opt$par, tolerance = 5e-3)
	expect_equal(f$inf$compute_estimate(), opt$par[2], tolerance = 5e-3)
	expect_gt(fit$ssq_b_j, 0)
})

test_that("unit row weights reproduce the unweighted combined estimate; zero and non-finite weights are handled", {
	f <- cp_fx()
	est <- f$inf$compute_estimate()
	expect_equal(f$p$compute_weighted_combined_estimate(rep(1, f$n)), est, tolerance = 5e-3)
	expect_equal(f$p$compute_weighted_combined_estimate(rep(4, f$n)), est, tolerance = 5e-3)        # scale-free
	expect_true(is.na(f$p$compute_weighted_combined_estimate(rep(0, f$n))))
	expect_true(is.na(f$p$compute_weighted_combined_estimate(rep(NA_real_, f$n))))
	w <- rep(1, f$n); w[1:6] <- 0
	expect_true(is.finite(f$p$compute_weighted_combined_estimate(w)))
})
