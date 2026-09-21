library(testthat)
library(EDI)

# C++ kernels: expand_continuation_ratio_data_cpp (stacked "continued past cut" rows, checked against
# a hand-written expansion), generate_permutations_blocking_cpp (per-stratum fixed treated counts,
# within-stratum exchangeability), collect_discordant_pairs_cpp (discordant matched-pair differences
# for conditional logistic regression) and build_matching_combined_clogit_design_cpp (pair rows
# [0 | t_diff | X_diff] stacked over reservoir rows [1 | w | X]).

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("continuation-ratio expansion emits, per subject, one row per cut up to their category with stratum id = stratum + (cut - 1) * max(stratum)", {
	y <- c(1, 3, 2, 4, 4, 1); w <- c(0, 1, 0, 1, 1, 0); st <- c(1, 1, 2, 2, 1, 2); Kc <- 4L
	got <- K("expand_continuation_ratio_data_cpp")(y, w, st, Kc)
	ref <- do.call(rbind, lapply(seq_along(y), function(i) {
		cuts <- seq_len(min(y[i], Kc - 1L))
		data.frame(y = as.integer(y[i] > cuts), w = w[i], s = st[i] + (cuts - 1L) * max(st))
	}))
	expect_equal(as.integer(got$y), ref$y)
	expect_equal(as.integer(got$w), as.integer(ref$w))
	expect_equal(as.integer(got$strata), as.integer(ref$s))
	# Each subject contributes min(y, K - 1) rows.
	expect_length(got$y, sum(pmin(y, Kc - 1L)))
	# The top category never contributes a terminal (0) row; category 1 contributes exactly one 0-row.
	expect_equal(sum(got$y == 0), sum(y < Kc))
})

test_that("blocking permutations treat exactly round(prob_T * stratum size) units per stratum in every column", {
	set.seed(1)
	st <- list(1:4, 5:8, 9:12, 13:15)
	for (pT in c(0.5, 0.25)) {
		res <- K("generate_permutations_blocking_cpp")(15L, 200L, pT, st)
		W <- res$w_mat
		expect_equal(dim(W), c(15L, 200L))
		expect_null(res$m_mat)
		expect_true(all(W %in% c(0L, 1L)))
		for (s in st) expect_true(all(colSums(W[s, , drop = FALSE]) == round(pT * length(s))), info = paste(pT, length(s)))
	}
})

test_that("within a stratum the treated subset is uniformly random (marginal treatment rate = n_T / size)", {
	set.seed(2)
	W <- K("generate_permutations_blocking_cpp")(15L, 4000L, 0.5, list(1:4, 5:8, 9:12, 13:15))$w_mat
	expect_equal(rowMeans(W)[1:12], rep(0.5, 12), tolerance = 0.06)
	expect_equal(rowMeans(W)[13:15], rep(2 / 3, 3), tolerance = 0.06)          # 2 of 3 treated
	# The draws differ across columns.
	expect_gt(length(unique(apply(W, 2, paste, collapse = ""))), 50L)
})

pair_fixture <- function() {
	list(y = c(1, 0, 1, 1, 0, 1, 1, 1), w = c(1, 0, 0, 1, 1, 0, 1, 0),
		X = matrix(as.numeric(1:16), 8, 2), s = c(1L, 1L, 2L, 2L, 3L, 3L, 4L, 4L))
}

test_that("discordant pair collection keeps only pairs with different outcomes, as first-minus-second differences", {
	f <- pair_fixture()
	d <- K("collect_discordant_pairs_cpp")(f$y, f$w, f$X, f$s)
	pairs <- split(seq_along(f$y), f$s)
	keep <- Filter(function(ix) f$y[ix[1]] != f$y[ix[2]], pairs)
	expect_equal(d$nd, length(keep))
	expect_equal(as.numeric(d$y_01), unname(vapply(keep, function(ix) as.numeric(f$y[ix[1]] > f$y[ix[2]]), 0)))
	expect_equal(as.numeric(d$t_diffs), unname(vapply(keep, function(ix) f$w[ix[1]] - f$w[ix[2]], 0)))
	expect_equal(unname(d$X_diffs), unname(do.call(rbind, lapply(keep, function(ix) f$X[ix[1], ] - f$X[ix[2], ]))))
	# All-concordant input gives no rows.
	none <- K("collect_discordant_pairs_cpp")(rep(1, 8), f$w, f$X, f$s)
	expect_equal(none$nd, 0L)
	expect_equal(nrow(none$X_diffs), 0L)
})

test_that("the combined clogit design stacks pair rows [0 | t_diff | X_diff] over reservoir rows [1 | w | X]", {
	f <- pair_fixture()
	yr <- c(1, 0, 1); wr <- c(1, 0, 1); Xr <- matrix(c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6), 3, 2)
	b <- K("build_matching_combined_clogit_design_cpp")(f$y, f$w, f$X, f$s, yr, wr, Xr)
	d <- K("collect_discordant_pairs_cpp")(f$y, f$w, f$X, f$s)
	expect_equal(b$nd, d$nd)
	expect_equal(dim(b$X_comb), c(d$nd + 3L, 4L))
	expect_equal(unname(b$X_comb[seq_len(d$nd), ]), unname(cbind(0, d$t_diffs, d$X_diffs)))
	expect_equal(unname(b$X_comb[d$nd + 1:3, ]), unname(cbind(1, wr, Xr)))
	expect_equal(as.numeric(b$y_comb), c(as.numeric(d$y_01), yr))
})
