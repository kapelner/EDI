library(testthat)
library(EDI)

# DesignFixedRerandomization's private objective (compute_obj: Mahalanobis and
# absolute-sum-difference balance measures), the single-draw rejection sampler
# (generate_one_rerandomized_w), and the draw_ws_raw() paths: no covariates,
# prop_acceptable (best-r of a larger seeded pool), the cutoff-based C++ search
# (balanced even n), and the pure-R fallback (unbalanced allocation). None had a
# direct test reference. Objectives are recomputed independently from the raw
# covariates.

rerand_design <- function(..., n = 20L, seed = 41L, prob_T = 0.5, X = NULL) {
	set.seed(4)
	if (is.null(X)) X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignFixedRerandomization$new(response_type = "continuous", n = n, prob_T = prob_T, seed = seed, verbose = FALSE, ...)
	des$add_all_subjects_to_experiment(X)
	list(des = des, priv = des$.__enclos_env__$private, X = as.matrix(X))
}

ref_mahal <- function(X, w) {
	d <- colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])
	as.numeric(t(d) %*% solve(var(X)) %*% d)
}
ref_abs <- function(X, w) sum(abs(colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])))

test_that("compute_obj matches the Mahalanobis and absolute-sum-difference definitions", {
	f <- rerand_design(prob_T = 0.4, obj_val_cutoff = 1e6)
	priv <- f$priv
	f$des$draw_ws_according_to_design(r = 2)          # populates S_inv on the pure-R path
	expect_equal(priv$S_inv, solve(var(f$X[1:20, ])), tolerance = 1e-8)
	set.seed(5)
	for (i in 1:3) {
		w <- sample(rep(0:1, 10))
		expect_equal(priv$compute_obj(f$X, w), ref_mahal(f$X, w), tolerance = 1e-8)
	}
	priv$objective <- "abs_sum_diff"
	w <- sample(rep(0:1, 10))
	expect_equal(priv$compute_obj(f$X, w), ref_abs(f$X, w), tolerance = 1e-10)
	priv$objective <- "bogus"
	expect_error(priv$compute_obj(f$X, w), "Unsupported objective")
})

test_that("generate_one_rerandomized_w returns a balanced allocation for prob_T = 0.5 and always meets the cutoff", {
	set.seed(6)
	X <- data.frame(x1 = rnorm(20), x2 = rnorm(20))
	pool <- vapply(1:400, function(i) ref_mahal(as.matrix(X), sample(rep(0:1, 10))), numeric(1))
	cutoff <- unname(quantile(pool, 0.3))
	f <- rerand_design(obj_val_cutoff = cutoff, X = X)
	f$priv$S_inv <- solve(var(f$X))
	set.seed(7)
	for (i in 1:15) {
		w <- f$priv$generate_one_rerandomized_w()
		expect_equal(sum(w), 10)
		expect_true(all(w %in% c(0, 1)))
		expect_lte(ref_mahal(f$X, w), cutoff + 1e-8)
	}
	# No cutoff: the first candidate is accepted.
	g <- rerand_design(X = X)
	g$priv$S_inv <- solve(var(g$X))
	expect_equal(sum(g$priv$generate_one_rerandomized_w()), 10)
})

test_that("cutoff-based search (balanced even n) returns balanced columns whose objective meets the user cutoff", {
	set.seed(8)
	X <- data.frame(x1 = rnorm(20), x2 = rnorm(20))
	pool <- vapply(1:400, function(i) ref_mahal(as.matrix(X), sample(rep(0:1, 10))), numeric(1))
	cutoff <- unname(quantile(pool, 0.3))
	f <- rerand_design(obj_val_cutoff = cutoff, X = X)
	W <- f$des$draw_ws_according_to_design(r = 25)
	expect_equal(dim(W), c(20L, 25L))
	expect_true(all(colSums(W) == 10))
	objs <- apply(W, 2, function(w) ref_mahal(f$X, w))
	expect_true(all(objs <= cutoff + 1e-6))
})

test_that("an impossible cutoff makes the search fail loudly", {
	f <- rerand_design(obj_val_cutoff = 1e-12)
	expect_error(f$des$draw_ws_according_to_design(r = 5), "could not find 5 acceptable allocation")
})

test_that("prop_acceptable returns the r best allocations of a larger seeded pool", {
	seed <- 41L; r <- 5L; prop <- 0.1; n <- 20L
	f <- rerand_design(prop_acceptable = prop, seed = seed)
	W <- f$des$draw_ws_according_to_design(r = r)
	expect_equal(dim(W), c(n, r))
	expect_true(all(colSums(W) == n / 2))

	pool <- EDI:::complete_randomization_forced_balanced_cpp(n, round(r / prop), seed)
	objs <- apply(pool, 1, function(w) ref_mahal(f$X, w))
	best <- pool[order(objs)[seq_len(r)], , drop = FALSE]
	expect_equal(unname(W), unname(t(best)))
	expect_lte(max(apply(W, 2, function(w) ref_mahal(f$X, w))), sort(objs)[r] + 1e-8)
})

test_that("unbalanced allocation uses the pure-R sampler and still respects the cutoff", {
	set.seed(9)
	X <- data.frame(x1 = rnorm(20), x2 = rnorm(20))
	pool <- vapply(1:400, function(i) ref_mahal(as.matrix(X), rbinom(20, 1, 0.4) |> (\(w) { w[1:2] <- 0:1; w })()), numeric(1))
	cutoff <- unname(quantile(pool, 0.5))
	f <- rerand_design(prob_T = 0.4, obj_val_cutoff = cutoff, X = X)
	W <- f$des$draw_ws_according_to_design(r = 12)
	expect_equal(dim(W), c(20L, 12L))
	expect_true(all(W %in% c(0, 1)))
	objs <- apply(W, 2, function(w) if (length(unique(w)) < 2) NA_real_ else ref_mahal(f$X, w))
	expect_true(all(objs[is.finite(objs)] <= cutoff + 1e-6))
})

test_that("with no usable covariates the design falls back to plain balanced complete randomization", {
	f <- rerand_design(obj_val_cutoff = 0.5)
	f$priv$X <- matrix(0, nrow = 20, ncol = 0)
	W <- f$des$draw_ws_according_to_design(r = 6)
	expect_equal(dim(W), c(20L, 6L))
	expect_true(all(colSums(W) == 10))
})
