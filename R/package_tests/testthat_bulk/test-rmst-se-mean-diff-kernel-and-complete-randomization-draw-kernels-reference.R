library(testthat)
library(EDI)

# C++ kernels: get_restricted_mean_se_diff (SE of the difference in restricted mean survival time,
# checked against survival::survfit's KM restricted-mean standard errors combined in quadrature),
# compute_simple_mean_diff_parallel_cpp (mean differences for assignment columns with a treated-shift
# delta; identical for 1 and 2 threads) and the complete-randomization draw kernels
# complete_randomization_forced_balanced_cpp / complete_randomization_imbalanced_cpp
# (fixed treated count per draw, seed-determinism, uniform marginals).

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("RMST-difference SE equals sqrt(se1^2 + se0^2) of the Kaplan-Meier restricted means, each group truncated at its OWN last time", {
	set.seed(3)
	n <- 60L
	w <- rep(0:1, each = 30L); y <- rexp(n, 1 / (5 + 2 * w)); dead <- rbinom(n, 1, 0.8)
	km <- survival::survfit(survival::Surv(y, dead) ~ w)
	tab <- summary(km, rmean = "individual")$table
	expect_equal(K("get_restricted_mean_se_diff")(y, dead, w), sqrt(sum(tab[, "se(rmean)"]^2)), tolerance = 1e-6)
	# Swapping arm labels leaves the SE unchanged.
	expect_equal(K("get_restricted_mean_se_diff")(y, dead, 1 - w), K("get_restricted_mean_se_diff")(y, dead, w), tolerance = 1e-10)
})

test_that("mean-difference kernel matches the hand computation, with the shift applied to treated units", {
	set.seed(3)
	n <- 60L; y <- rexp(n, 0.2); W <- matrix(rbinom(n * 4L, 1, 0.5), n, 4L)
	ref <- function(delta) vapply(1:4, function(b) { yy <- y; yy[W[, b] == 1] <- yy[W[, b] == 1] + delta; mean(yy[W[, b] == 1]) - mean(yy[W[, b] == 0]) }, 0)
	for (d in c(0, 0.5, -1)) expect_equal(as.numeric(K("compute_simple_mean_diff_parallel_cpp")(y, W, d, 1L)), ref(d), tolerance = 1e-10)
	expect_equal(as.numeric(K("compute_simple_mean_diff_parallel_cpp")(y, W, 0.5, 2L)), as.numeric(K("compute_simple_mean_diff_parallel_cpp")(y, W, 0.5, 1L)), tolerance = 1e-12)
})

test_that("forced-balanced complete randomization gives n/2 treated per draw, is seed-deterministic and varies with the seed", {
	a <- K("complete_randomization_forced_balanced_cpp")(10L, 500L, 1L)
	expect_equal(dim(a), c(500L, 10L))
	expect_true(all(a %in% c(0, 1)))
	expect_true(all(rowSums(a) == 5))
	expect_identical(a, K("complete_randomization_forced_balanced_cpp")(10L, 500L, 1L))
	expect_false(identical(a, K("complete_randomization_forced_balanced_cpp")(10L, 500L, 2L)))
	expect_equal(colMeans(a), rep(0.5, 10), tolerance = 0.08)              # each unit treated half the time
})

test_that("imbalanced complete randomization treats exactly nT units per draw with uniform marginals", {
	b <- K("complete_randomization_imbalanced_cpp")(10L, 3L, 800L, 7L)
	expect_equal(dim(b), c(800L, 10L))
	expect_true(all(rowSums(b) == 3))
	expect_equal(colMeans(b), rep(0.3, 10), tolerance = 0.08)
	expect_identical(b, K("complete_randomization_imbalanced_cpp")(10L, 3L, 800L, 7L))
	# Distinct assignments appear (C(10, 3) = 120 possible).
	expect_gt(length(unique(apply(b, 1, paste, collapse = ""))), 60L)
})
