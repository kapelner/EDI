library(testthat)
library(EDI)

# InferenceAllSimpleAverageDiff$compute_brt_null_statistics_with_se(): (t0, se0) of the
# mean difference on each bootstrap draw with the treated responses shifted by delta.
# Reference: Welch difference and SE computed by hand from the draw. The serial /
# reused-worker path (transform not in the C++ kernel's code map) is checked exactly.
# The compiled batch kernel compute_rand_bootstrap_mean_diff_se_parallel_cpp must return
# row 1 = t0, row 2 = se (its former row-major fill bug was fixed in source; these tests
# need a rebuild to pass against an older installed build).

fx <- function(n = 30L, B = 5L) {
	set.seed(3)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE, seed = 3L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnorm(n) + 0.5 * w
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	draws <- lapply(seq_len(B), function(b) list(i_b = sample(n, n, TRUE), w_b = sample(rep(0:1, length.out = n))))
	list(priv = inf$.__enclos_env__$private, y = y, draws = draws)
}

ref_stat <- function(y, d, delta) {
	ys <- y[d$i_b]; ww <- d$w_b
	ys[ww == 1] <- ys[ww == 1] + delta
	a <- ys[ww == 1]; b <- ys[ww == 0]
	c(mean(a) - mean(b), sqrt(var(a) / length(a) + var(b) / length(b)))
}

test_that("the non-kernel path returns each draw's Welch mean difference and SE with the shift on treated units", {
	f <- fx()
	for (delta in c(0, 0.3, -1)) {
		out <- f$priv$compute_brt_null_statistics_with_se(f$draws, delta, "sqrt", f$y, .Machine$double.eps)
		ref <- vapply(f$draws, ref_stat, numeric(2), y = f$y, delta = delta)
		expect_equal(out$t0, ref[1, ], tolerance = 1e-10, info = delta)
		expect_equal(out$se0, ref[2, ], tolerance = 1e-10, info = delta)
	}
})

test_that("an empty draw list returns empty statistics", {
	f <- fx()
	out <- f$priv$compute_brt_null_statistics_with_se(list(), 0, "none", f$y, .Machine$double.eps)
	expect_equal(out, list(t0 = numeric(0), se0 = numeric(0)))
})

test_that("draws with fewer than two units in an arm give NA statistics in the C++ kernel", {
	set.seed(1)
	n <- 8L; y <- rnorm(n)
	i_mat <- matrix(seq_len(n), n, 2)
	w_mat <- cbind(c(1L, rep(0L, 7)), rep(c(0L, 1L), 4))
	k <- get("compute_rand_bootstrap_mean_diff_se_parallel_cpp", envir = asNamespace("EDI"))(y, i_mat, w_mat, 0, 0L, 1e-12, 1L)
	expect_equal(dim(k), c(2L, 2L))
	expect_true(is.na(k[1, 1]) && is.na(k[2, 1]))            # draw 1: one treated unit
	expect_false(is.na(k[1, 2]) || is.na(k[2, 2]))           # draw 2: four per arm
})

test_that("the batch kernel returns a 2 x B matrix with row 1 = t0 and row 2 = se", {
	set.seed(1)
	n <- 12L; y <- rnorm(n); B <- 3L
	i_mat <- matrix(sample(n, n * B, TRUE), n, B)
	w_mat <- matrix(rep(c(0L, 1L), length.out = n * B), n, B)
	k <- get("compute_rand_bootstrap_mean_diff_se_parallel_cpp", envir = asNamespace("EDI"))(y, i_mat, w_mat, 0, 0L, 1e-12, 1L)
	ref <- vapply(seq_len(B), function(b) ref_stat(y, list(i_b = i_mat[, b], w_b = w_mat[, b]), 0), numeric(2))
	expect_equal(k[1, ], ref[1, ], tolerance = 1e-10)
	expect_equal(k[2, ], ref[2, ], tolerance = 1e-10)
})

test_that("the compiled path (transform none / log / logit) agrees with the serial path on the same draws", {
	f <- fx()
	for (delta in c(0, 0.3)) {
		fast <- f$priv$compute_brt_null_statistics_with_se(f$draws, delta, "none", f$y, .Machine$double.eps)
		ref <- vapply(f$draws, ref_stat, numeric(2), y = f$y, delta = delta)
		expect_equal(fast$t0, ref[1, ], tolerance = 1e-10, info = delta)
		expect_equal(fast$se0, ref[2, ], tolerance = 1e-10, info = delta)
	}
})
