library(testthat)
library(EDI)

# greedy_design_search_cpp(X_raw, r, objective, n_iter, indicies_pairs): exhaustive mode (n_iter = -1)
# ends every replicate at a strict local optimum of the imbalance objective under all single
# treated<->control swaps (Mahalanobis and standardized-L1 definitions written out from the raw
# covariates); pair-constrained mode keeps exactly one treated unit per pair; the search is
# seeded from R's RNG; finite n_iter improves on complete randomization; unknown objectives fall
# back to the L1 objective; odd n treats floor(n / 2) units.

K <- function(x) get(x, envir = asNamespace("EDI"))
n <- 12L
set.seed(2)
X <- matrix(rnorm(n * 3), n, 3)

obj_mahal <- function(w) {
	Xc <- scale(X, scale = FALSE); S <- crossprod(Xc) / (n - 1)
	d <- crossprod(Xc, 2 * w - 1) / n
	drop(t(d) %*% solve(S) %*% d)
}
obj_l1 <- function(w) {
	Xc <- scale(X, scale = FALSE); sd_j <- sqrt(colSums(Xc^2) / (n - 1))
	sum(abs(crossprod(sweep(Xc, 2, sd_j, "/"), 2 * w - 1) / n))
}
best_swap <- function(w, obj) {
	best <- Inf
	for (i in which(w == 1)) for (k in which(w == 0)) { w2 <- w; w2[i] <- 0; w2[k] <- 1; best <- min(best, obj(w2)) }
	best
}

test_that("exhaustive search returns balanced allocations that no single swap improves (both objectives)", {
	set.seed(1)
	for (spec in list(list("mahal_dist", obj_mahal), list("abs_sum_diff", obj_l1))) {
		W <- K("greedy_design_search_cpp")(X, 8L, spec[[1]], -1L)
		expect_equal(dim(W), c(n, 8L))
		expect_true(all(W %in% c(0, 1)))
		expect_true(all(colSums(W) == n / 2))
		for (j in seq_len(ncol(W))) {
			w <- W[, j]
			expect_gte(best_swap(w, spec[[2]]), spec[[2]](w) - 1e-10)
		}
	}
})

test_that("the search improves on complete randomization, and finite n_iter is stochastic but balanced", {
	set.seed(6)
	Wf <- K("greedy_design_search_cpp")(X, 200L, "mahal_dist", 30L)
	expect_true(all(colSums(Wf) == n / 2))
	rnd <- replicate(200, obj_mahal(sample(rep(0:1, n / 2))))
	expect_lt(mean(apply(Wf, 2, obj_mahal)), 0.5 * mean(rnd))
})

test_that("pair-constrained mode keeps exactly one treated unit per pair", {
	set.seed(3)
	pr <- matrix(1:12, 6, 2, byrow = TRUE)
	W <- K("greedy_design_search_cpp")(X, 20L, "mahal_dist", -1L, pr)
	for (j in seq_len(ncol(W))) expect_equal(W[pr[, 1], j] + W[pr[, 2], j], rep(1, 6))
	# Local optimality within the pair-flip neighbourhood.
	for (j in 1:5) {
		w <- W[, j]; cur <- obj_mahal(w); best <- Inf
		for (p in 1:6) { w2 <- w; w2[pr[p, ]] <- w[rev(pr[p, ])]; best <- min(best, obj_mahal(w2)) }
		expect_gte(best, cur - 1e-10)
	}
})

test_that("the search is reproducible under set.seed and varies across seeds", {
	set.seed(5); a <- K("greedy_design_search_cpp")(X, 4L, "mahal_dist", -1L)
	set.seed(5); b <- K("greedy_design_search_cpp")(X, 4L, "mahal_dist", -1L)
	set.seed(6); c <- K("greedy_design_search_cpp")(X, 4L, "mahal_dist", -1L)
	expect_identical(a, b)
	expect_false(identical(a, c))
})

test_that("an unrecognised objective silently behaves as abs_sum_diff; odd n treats floor(n / 2) units", {
	set.seed(1); a <- K("greedy_design_search_cpp")(X, 3L, "not_an_objective", -1L)
	set.seed(1); b <- K("greedy_design_search_cpp")(X, 3L, "abs_sum_diff", -1L)
	set.seed(1); d <- K("greedy_design_search_cpp")(X, 3L, "mahal_dist", -1L)
	expect_identical(a, b)
	expect_false(identical(a, d))
	odd <- K("greedy_design_search_cpp")(X[1:11, ], 3L, "mahal_dist", -1L)
	expect_equal(dim(odd), c(11L, 3L))
	expect_true(all(colSums(odd) == 5))
})
