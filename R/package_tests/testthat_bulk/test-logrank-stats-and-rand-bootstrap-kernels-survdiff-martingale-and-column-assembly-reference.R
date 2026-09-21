library(testthat)
library(EDI)

# fast_logrank_stats_cpp(w, y, dead): score = observed - expected events of the treated arm and var_score equal survival::survdiff,
# beta_hat = score * n / (n_t * n_c) (equal to the treated-minus-control mean martingale residual on tie-free data), se_beta_hat
# equals the pooled t-test SE of those residuals on tie-free data. compute_logrank_rand_bootstrap_parallel_cpp(y0, dead, i_mat,
# w_mat, delta, noise_mat, num_cores): every column equals fast_logrank_stats_cpp()$beta_hat on the column's resampled data, with
# treated times multiplied by exp(delta) and optional additive noise applied before the shift; thread count does not matter.

skip_if_not_installed("survival")
K <- function(nm) get(nm, envir = asNamespace("EDI"))
S <- K("fast_logrank_stats_cpp"); B <- K("compute_logrank_rand_bootstrap_parallel_cpp")
set.seed(1); n <- 40L
y <- round(rexp(n, 0.3) * 10) / 10 + 0.1; dead <- rbinom(n, 1, 0.7); w <- rep(0:1, length.out = n)       # ties present
yc <- rexp(n, 0.3); deadc <- rbinom(n, 1, 0.7)                                                             # tie-free

test_that("score and variance equal survdiff's observed-minus-expected and variance (with ties); beta_hat = score * n / (n_t n_c)", {
	r <- S(w, y, dead); sd <- survival::survdiff(survival::Surv(y, dead) ~ w)
	expect_equal(r$score, unname(sd$obs[2] - sd$exp[2]), tolerance = 1e-10)
	expect_equal(r$var_score, unname(sd$var[2, 2]), tolerance = 1e-10)
	expect_equal(r$n_treat, 20L); expect_equal(r$n_control, 20L)
	expect_equal(r$beta_hat, r$score * n / (r$n_treat * r$n_control), tolerance = 1e-10)
})

test_that("tie-free data: beta_hat is the treated-minus-control mean martingale residual and se_beta_hat its pooled t-test SE", {
	r <- S(w, yc, deadc)
	m <- residuals(survival::coxph(survival::Surv(yc, deadc) ~ 1), "martingale")
	expect_equal(r$beta_hat, mean(m[w == 1]) - mean(m[w == 0]), tolerance = 1e-10)
	expect_equal(r$se_beta_hat, unname(t.test(m[w == 1], m[w == 0], var.equal = TRUE)$stderr), tolerance = 1e-6)
})

test_that("bootstrap kernel columns equal the stats kernel on the resampled data (no shift)", {
	set.seed(2); r <- 7L
	i_mat <- replicate(r, sample.int(n, n, TRUE)); w_mat <- replicate(r, sample(w)); storage.mode(i_mat) <- "integer"; storage.mode(w_mat) <- "integer"
	out <- B(yc, as.integer(deadc), i_mat, w_mat, 0, NULL, 1L)
	ref <- vapply(seq_len(r), function(b) S(w_mat[, b], yc[i_mat[, b]], deadc[i_mat[, b]])$beta_hat, numeric(1))
	expect_equal(out, ref, tolerance = 1e-10)
	expect_equal(B(yc, as.integer(deadc), i_mat, w_mat, 0, NULL, 2L), out, tolerance = 1e-14)
})

test_that("delta multiplies the treated times by exp(delta); noise is added before the shift", {
	set.seed(3); r <- 5L
	i_mat <- replicate(r, sample.int(n, n, TRUE)); w_mat <- replicate(r, sample(w)); storage.mode(i_mat) <- "integer"; storage.mode(w_mat) <- "integer"
	d <- 0.4; out <- B(yc, as.integer(deadc), i_mat, w_mat, d, NULL, 1L)
	ref <- vapply(seq_len(r), function(b) { yb <- yc[i_mat[, b]]; yb[w_mat[, b] == 1L] <- yb[w_mat[, b] == 1L] * exp(d)
		S(w_mat[, b], yb, deadc[i_mat[, b]])$beta_hat }, numeric(1))
	expect_equal(out, ref, tolerance = 1e-10)
	noise <- matrix(rnorm(n * r, 0, 0.01), n, r)
	outn <- B(yc, as.integer(deadc), i_mat, w_mat, d, noise, 1L)
	refn <- vapply(seq_len(r), function(b) { yb <- yc[i_mat[, b]] + noise[, b]; yb[w_mat[, b] == 1L] <- yb[w_mat[, b] == 1L] * exp(d)
		S(w_mat[, b], yb, deadc[i_mat[, b]])$beta_hat }, numeric(1))
	expect_equal(outn, refn, tolerance = 1e-10)
	expect_false(isTRUE(all.equal(outn, out)))
})

test_that("a replicate whose resample has an empty arm yields NA", {
	i_mat <- matrix(rep(seq_len(n), 2), n, 2); storage.mode(i_mat) <- "integer"
	w_mat <- cbind(w, rep(1L, n)); storage.mode(w_mat) <- "integer"
	out <- B(yc, as.integer(deadc), i_mat, w_mat, 0, NULL, 1L)
	expect_true(is.finite(out[1]))
	expect_true(is.na(out[2]))
})
