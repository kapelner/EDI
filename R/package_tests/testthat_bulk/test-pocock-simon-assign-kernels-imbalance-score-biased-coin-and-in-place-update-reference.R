library(testthat)
library(EDI)

# pocock_simon_assign_cpp / pocock_simon_assign_and_update_cpp: marginal imbalance score
# G_k = sum_j w_j * var_t(counts[level_j, t] + 1{t = k}) (n - 1 divisor over the two arms), the arm with the
# smaller G_k is chosen with probability p_best (deterministic at p_best = 1), a perfect tie is broken by a
# Bernoulli(prob_T) draw, the plain kernel leaves `counts` untouched, and the update kernel increments
# counts[level_j, arm] for every covariate IN PLACE (so any R alias of the matrix sees the change -- documented,
# but worth pinning).

K <- function(x) get(x, envir = asNamespace("EDI"))
G <- function(counts, idx, w, k) sum(w * vapply(seq_along(idx), function(j) {
	cj <- counts[idx[j], ]; cj[k + 1L] <- cj[k + 1L] + 1; var(cj)
}, 0))

counts0 <- matrix(c(5, 2, 3, 3, 1, 4, 2, 2, 6, 1), ncol = 2, byrow = TRUE)   # 5 covariate-level rows x 2 arms

test_that("deterministic minimization picks the arm with the smaller marginal imbalance score", {
	for (idx in list(c(1L, 3L), c(1L, 5L), c(2L, 4L), c(3L, 5L), c(1L, 2L, 3L))) {
		for (w in list(rep(1, length(idx)), seq_along(idx) / 2)) {
			g0 <- G(counts0, idx, w, 0); g1 <- G(counts0, idx, w, 1)
			if (isTRUE(all.equal(g0, g1))) next
			expected <- if (g0 < g1) 0 else 1
			for (rep in 1:5) expect_equal(K("pocock_simon_assign_cpp")(counts0, idx, w, 1, 0.5), expected, info = paste(idx, collapse = ","))
		}
	}
})

test_that("a biased coin assigns the better arm with probability p_best", {
	idx <- c(1L, 5L); w <- c(1, 1)                      # row 1 (5,2), row 5 (6,1): arm 1 is clearly better
	expect_lt(G(counts0, idx, w, 1), G(counts0, idx, w, 0))
	set.seed(1)
	draws <- replicate(2000, K("pocock_simon_assign_cpp")(counts0, idx, w, 0.8, 0.5))
	expect_equal(mean(draws == 1), 0.8, tolerance = 0.04, scale = 1)
	draws75 <- replicate(2000, K("pocock_simon_assign_cpp")(counts0, idx, w, 0.6, 0.5))
	expect_equal(mean(draws75 == 1), 0.6, tolerance = 0.04, scale = 1)
})

test_that("a perfect tie is broken by a Bernoulli(prob_T) draw", {
	idx <- c(1L, 3L); w <- c(1, 1)                      # the fixture rows tie exactly: G_0 = G_1 = 10
	expect_equal(G(counts0, idx, w, 0), G(counts0, idx, w, 1))
	expect_true(all(replicate(50, K("pocock_simon_assign_cpp")(counts0, idx, w, 1, 0)) == 0))
	expect_true(all(replicate(50, K("pocock_simon_assign_cpp")(counts0, idx, w, 1, 1)) == 1))
	set.seed(2)
	expect_equal(mean(replicate(2000, K("pocock_simon_assign_cpp")(counts0, idx, w, 1, 0.3))), 0.3, tolerance = 0.04, scale = 1)
})

test_that("the plain kernel does not modify counts; the update kernel increments the chosen arm's cell for every covariate, in place", {
	idx <- c(1L, 5L); w <- c(1, 1)
	cc <- counts0 + 0
	before <- cc + 0
	K("pocock_simon_assign_cpp")(cc, idx, w, 1, 0.5)
	expect_identical(cc, before)
	a <- K("pocock_simon_assign_and_update_cpp")(cc, idx, w, 1, 0.5)
	expected <- before; expected[idx, a + 1L] <- expected[idx, a + 1L] + 1
	expect_equal(cc, expected)
	expect_equal(sum(cc) - sum(before), length(idx))
	# In-place mutation is visible through an alias created before the call.
	orig <- counts0 + 0; alias <- orig
	K("pocock_simon_assign_and_update_cpp")(orig, idx, w, 1, 0.5)
	expect_identical(alias, orig)
	expect_false(identical(alias, counts0))
})

test_that("the biased-coin draws are reproducible under set.seed", {
	idx <- c(1L, 5L); w <- c(1, 1)
	set.seed(9); a <- replicate(30, K("pocock_simon_assign_cpp")(counts0, idx, w, 0.7, 0.5))
	set.seed(9); b <- replicate(30, K("pocock_simon_assign_cpp")(counts0, idx, w, 0.7, 0.5))
	expect_identical(a, b)
})
