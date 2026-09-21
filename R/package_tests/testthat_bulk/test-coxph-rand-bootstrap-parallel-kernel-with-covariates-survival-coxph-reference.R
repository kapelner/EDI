library(testthat)
library(EDI)

# compute_coxph_rand_bootstrap_parallel_cpp(y0, dead, Xc, i_mat, w_mat, delta, noise_mat, num_cores): each column fits a Cox model (Breslow ties, no
# intercept) of Surv(y0[i_b] (+ noise), dead[i_b]) on [w_b, Xc[i_b, ]] with the treated times multiplied by exp(delta), and returns the treatment
# coefficient. Reference: survival::coxph(ties = "breslow") on the assembled data (tolerance 1e-4: the kernel stops at Newton tol 1e-6),
# multiplicative shift, noise-before-shift ordering, no-covariate designs, thread invariance, and NA for resamples with < 2 treated / control.

skip_if_not_installed("survival")
K <- get("compute_coxph_rand_bootstrap_parallel_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 80L; B <- 6L
Xc <- cbind(a = rnorm(n), b = rbinom(n, 1, 0.5))
y0 <- rexp(n, exp(0.3 * Xc[, 1])) ; dead <- rbinom(n, 1, 0.75)                     # tie-free times
i_mat <- replicate(B, sample.int(n, n, TRUE)); storage.mode(i_mat) <- "integer"
w_mat <- replicate(B, sample(rep(0:1, length.out = n))); storage.mode(w_mat) <- "integer"

ref <- function(delta = 0, noise = NULL, X = Xc, y = y0, ties = "breslow") vapply(seq_len(B), function(b) {
	i <- i_mat[, b]; w <- w_mat[, b]
	yy <- y[i] + if (is.null(noise)) 0 else noise[, b]
	yy[w == 1L] <- yy[w == 1L] * exp(delta)
	d <- data.frame(t = yy, e = dead[i], w = w); if (ncol(X)) d <- cbind(d, as.data.frame(X[i, , drop = FALSE]))
	unname(coef(survival::coxph(survival::Surv(t, e) ~ ., data = d, ties = ties))["w"])
}, numeric(1))

test_that("columns equal coxph on the resampled data with covariates, and with the multiplicative delta shift", {
	expect_equal(K(y0, dead, Xc, i_mat, w_mat, 0, NULL, 1L), ref(0), tolerance = 1e-4)
	for (d in c(0.4, -0.7)) expect_equal(K(y0, dead, Xc, i_mat, w_mat, d, NULL, 1L), ref(d), tolerance = 1e-4, info = as.character(d))
})

test_that("noise is added before the shift", {
	set.seed(2); noise <- matrix(rnorm(n * B, 0, 0.01), n, B)
	out <- K(y0, dead, Xc, i_mat, w_mat, 0.3, noise, 1L)
	expect_equal(out, ref(0.3, noise), tolerance = 1e-4)
	expect_false(isTRUE(all.equal(out, K(y0, dead, Xc, i_mat, w_mat, 0.3, NULL, 1L), tolerance = 1e-8)))
})

test_that("no-covariate design and tied times (Breslow) agree with coxph; thread count does not matter", {
	X0 <- matrix(numeric(0), n, 0)
	expect_equal(K(y0, dead, X0, i_mat, w_mat, 0, NULL, 1L), ref(0, X = X0), tolerance = 1e-4)
	ytie <- round(y0 * 5) / 5 + 0.2
	expect_equal(K(ytie, dead, Xc, i_mat, w_mat, 0, NULL, 1L), ref(0, y = ytie, ties = "breslow"), tolerance = 1e-4)
	expect_equal(K(y0, dead, Xc, i_mat, w_mat, 0.2, NULL, 2L), K(y0, dead, Xc, i_mat, w_mat, 0.2, NULL, 1L), tolerance = 1e-12)
})

test_that("resamples with fewer than two treated or two control rows return NA", {
	w2 <- w_mat; w2[, 1] <- 0L; w2[1, 1] <- 1L; w2[, 2] <- 1L; w2[1, 2] <- 0L
	out <- K(y0, dead, Xc, i_mat, w2, 0, NULL, 1L)
	expect_true(is.na(out[1])); expect_true(is.na(out[2])); expect_true(all(is.finite(out[-(1:2)])))
})
