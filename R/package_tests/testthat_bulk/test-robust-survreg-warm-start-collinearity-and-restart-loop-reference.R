library(testthat)
library(EDI)

# robust_survreg() / robust_survreg_with_surv_object(): agreement with a plain
# survival::survreg MLE (Weibull warm-started and other distributions), silent
# removal of collinear columns, and the random-restart loop (NULL after
# num_max_iter failures; recovery after a jittered restart).

surv_fixture <- function(seed = 1L, n = 120L) {
	set.seed(seed)
	x1 <- rnorm(n); x2 <- rnorm(n)
	t_true <- rweibull(n, shape = 1.5, scale = exp(1 + 0.4 * x1 - 0.3 * x2))
	cens <- runif(n, 0, quantile(t_true, 0.85))
	y <- pmin(t_true, cens); dead <- as.integer(t_true <= cens)
	list(y = y, dead = dead, X = cbind(x1 = x1, x2 = x2))
}

test_that("the warm-started Weibull fit reaches the survreg MLE", {
	f <- surv_fixture()
	got <- robust_survreg(f$y, f$dead, f$X)
	ref <- survival::survreg(survival::Surv(f$y, f$dead) ~ f$X, dist = "weibull")
	expect_s3_class(got, "survreg")
	expect_equal(unname(got$coefficients), unname(ref$coefficients), tolerance = 1e-4)
	expect_equal(got$scale, ref$scale, tolerance = 1e-4)
	expect_equal(as.numeric(got$loglik[2]), as.numeric(ref$loglik[2]), tolerance = 1e-6)
})

test_that("robust_survreg equals robust_survreg_with_surv_object on the Surv built from y and dead", {
	f <- surv_fixture(2L)
	a <- robust_survreg(f$y, f$dead, f$X)
	b <- robust_survreg_with_surv_object(survival::Surv(f$y, f$dead), f$X)
	expect_equal(a$coefficients, b$coefficients)
	expect_equal(a$scale, b$scale)
})

test_that("a single covariate vector is accepted", {
	f <- surv_fixture(3L)
	got <- robust_survreg(f$y, f$dead, f$X[, 1])
	ref <- survival::survreg(survival::Surv(f$y, f$dead) ~ f$X[, 1], dist = "weibull")
	expect_length(got$coefficients, 2L)
	expect_equal(unname(got$coefficients), unname(ref$coefficients), tolerance = 1e-4)
})

test_that("non-Weibull distributions skip the warm start and still match survreg", {
	f <- surv_fixture(4L)
	for (d in c("lognormal", "loglogistic", "exponential")) {
		got <- robust_survreg(f$y, f$dead, f$X, dist = d)
		ref <- survival::survreg(survival::Surv(f$y, f$dead) ~ f$X, dist = d)
		expect_equal(unname(got$coefficients), unname(ref$coefficients), tolerance = 1e-3, info = d)
		expect_equal(got$dist, d)
	}
})

test_that("exactly collinear and near-duplicate columns are dropped before fitting", {
	f <- surv_fixture(5L)
	Xdup <- cbind(f$X, dup = f$X[, 1], lin = f$X[, 1] + f$X[, 2])
	got <- robust_survreg(f$y, f$dead, Xdup)
	base <- robust_survreg(f$y, f$dead, f$X)
	expect_false(anyNA(got$coefficients))
	expect_lt(length(got$coefficients), 1L + ncol(Xdup))
	expect_equal(as.numeric(got$loglik[2]), as.numeric(base$loglik[2]), tolerance = 1e-6)
})

test_that("failed survreg attempts exhaust the restart budget and return NULL", {
	f <- surv_fixture(6L)
	calls <- 0L
	local_mocked_bindings(survreg = function(...) { calls <<- calls + 1L; stop("cannot converge") }, .package = "survival")
	expect_null(robust_survreg(f$y, f$dead, f$X, dist = "lognormal", num_max_iter = 4L))
	expect_equal(calls, 4L)
})

test_that("a fit with NA coefficients is retried from a jittered start until a clean fit appears", {
	f <- surv_fixture(7L)
	real <- survival::survreg
	inits <- list()
	calls <- 0L
	local_mocked_bindings(survreg = function(formula, data, dist, init, control, ...) {
		calls <<- calls + 1L
		inits[[calls]] <<- init
		fit <- real(formula, data = data, dist = dist, init = init, control = control)
		if (calls < 3L) fit$coefficients[1] <- NA_real_
		fit
	}, .package = "survival")
	set.seed(10)
	got <- robust_survreg(f$y, f$dead, f$X, dist = "lognormal", num_max_iter = 10L)
	expect_equal(calls, 3L)
	expect_false(anyNA(got$coefficients))
	expect_equal(inits[[1]], rep(0, ncol(f$X) + 1L))   # intercept + one per covariate
	expect_false(isTRUE(all.equal(inits[[2]], inits[[1]])))
	expect_false(isTRUE(all.equal(inits[[3]], inits[[2]])))
})
