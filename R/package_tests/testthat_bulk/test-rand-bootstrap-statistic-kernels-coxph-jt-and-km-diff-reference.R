library(testthat)
library(EDI)

# Bootstrap-randomization statistic kernels, one value per (resample, assignment) column:
# compute_coxph_rand_bootstrap_cpp (Cox treatment coefficient, Breslow ties, treated times shifted by
# exp(delta)), compute_jt_rand_bootstrap_parallel_cpp (Jonckheere-Terpstra / Mann-Whitney statistic
# U / (n1 n0) - 1/2 with ties counted half), and compute_survival_stat_diff_rand_bootstrap_serial_cpp /
# _parallel_cpp (Kaplan-Meier median difference and RMST difference, each group truncated at its own last
# time). References: survival::coxph / survfit and direct pairwise counts.

skip_if_not_installed("survival")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 80L; w <- rep(0:1, each = 40L)
	y <- rexp(n, exp(0.5 * w) / 5); dead <- rbinom(n, 1, 0.8)
	B <- 5L
	i_mat <- vapply(seq_len(B), function(b) sample(n, n, TRUE), integer(n))
	w_mat <- vapply(seq_len(B), function(b) sample(w), numeric(n)); storage.mode(w_mat) <- "integer"
	list(n = n, w = w, y = y, dead = dead, B = B, i_mat = i_mat, w_mat = w_mat)
}
shift <- function(yy, ww, delta) { yy[ww == 1] <- yy[ww == 1] * exp(delta); yy }

test_that("Cox bootstrap coefficient equals coxph(ties = 'breslow') on each resample, with the multiplicative treated shift", {
	f <- fx()
	for (delta in c(0, 0.5, -0.3)) {
		got <- K("compute_coxph_rand_bootstrap_cpp")(f$y, f$dead, f$i_mat, f$w_mat, delta, 1L)
		ref <- vapply(seq_len(f$B), function(b) {
			yy <- shift(f$y[f$i_mat[, b]], f$w_mat[, b], delta); dd <- f$dead[f$i_mat[, b]]; ww <- f$w_mat[, b]
			unname(coef(survival::coxph(survival::Surv(yy, dd) ~ ww, ties = "breslow")))
		}, 0)
		expect_equal(as.numeric(got), ref, tolerance = 1e-6, info = as.character(delta))
	}
})

test_that("JT bootstrap statistic is U / (n1 n0) - 1/2 with ties counted one half", {
	f <- fx()
	set.seed(5)
	yo <- as.numeric(sample(1:4, f$n, TRUE, prob = c(0.2, 0.3, 0.3, 0.2))) + f$w * (runif(f$n) < 0.3)
	got <- K("compute_jt_rand_bootstrap_parallel_cpp")(yo, f$i_mat, f$w_mat, 1L)
	ref <- vapply(seq_len(f$B), function(b) {
		yy <- yo[f$i_mat[, b]]; ww <- f$w_mat[, b]
		a <- yy[ww == 1]; c0 <- yy[ww == 0]
		(sum(outer(a, c0, ">")) + 0.5 * sum(outer(a, c0, "=="))) / (length(a) * length(c0)) - 0.5
	}, 0)
	expect_equal(as.numeric(got), ref, tolerance = 1e-12)
	# Bounded in [-1/2, 1/2].
	expect_true(all(abs(got) <= 0.5))
})

test_that("KM median difference and RMST difference per resample match survfit; serial and parallel kernels agree", {
	f <- fx()
	km <- function(yy, dd, ww, stat) {
		fit <- survival::survfit(survival::Surv(yy, dd) ~ ww)
		if (stat == "rmst") { tb <- summary(fit, rmean = "individual")$table; unname(tb["ww=1", "rmean"] - tb["ww=0", "rmean"]) }
		else { q <- unname(quantile(fit, 0.5)$quantile); q[2] - q[1] }
	}
	for (spec in list(c("median", "median"), c("restricted_mean", "rmst"))) {
		got <- K("compute_survival_stat_diff_rand_bootstrap_serial_cpp")(f$y, f$dead, f$i_mat, f$w_mat, 0, spec[1])
		ref <- vapply(seq_len(f$B), function(b) km(f$y[f$i_mat[, b]], f$dead[f$i_mat[, b]], f$w_mat[, b], spec[2]), 0)
		expect_equal(as.numeric(got), ref, tolerance = 1e-8, info = spec[1])
	}
	par <- K("compute_survival_stat_diff_rand_bootstrap_parallel_cpp")(f$y, f$dead, f$i_mat, f$w_mat, 0, FALSE, matrix(0, 0, 0), 1L)
	ser <- K("compute_survival_stat_diff_rand_bootstrap_serial_cpp")(f$y, f$dead, f$i_mat, f$w_mat, 0, "median")
	expect_equal(as.numeric(par), as.numeric(ser), tolerance = 1e-12)
})
