library(testthat)
library(EDI)

# C++ matching kernels: draw_matching_bootstrap_sample_cpp (pair-preserving bootstrap: resampled
# reservoir units, then whole resampled pairs, with a 0 / pair-id vector), compute_matching_grouping_cpp
# and compute_cluster_ids_cpp (cluster ids, pair-active and reservoir indicators) and
# match_stats_from_indices_cpp (matched-pair differences and reservoir split, checked against a
# hand computation on the identity resample).

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("the matched-pair bootstrap resamples reservoir units and whole pairs, with 0 / pair ids in m_vec_b", {
	pairs <- matrix(c(1, 2, 3, 4, 5, 6), 3, 2, byrow = TRUE); res <- c(7L, 8L, 9L)
	set.seed(1)
	seen_pairs <- character(0)
	for (k in 1:200) {
		r <- K("draw_matching_bootstrap_sample_cpp")(res, pairs, 3L)
		expect_length(r$i_b, 9L)
		expect_equal(r$m_vec_b, c(0L, 0L, 0L, 1L, 1L, 2L, 2L, 3L, 3L))
		expect_true(all(r$i_b[1:3] %in% res))
		pr <- matrix(r$i_b[4:9], 3, 2, byrow = TRUE)
		for (i in 1:3) {
			key <- paste(pr[i, ], collapse = "-")
			expect_true(key %in% c("1-2", "3-4", "5-6"))                # a whole original pair, members kept together
			seen_pairs <- c(seen_pairs, key)
		}
	}
	# Resampling is with replacement and covers every pair.
	expect_setequal(unique(seen_pairs), c("1-2", "3-4", "5-6"))
	# Every pair is drawn with roughly equal frequency.
	freq <- table(seen_pairs) / length(seen_pairs)
	expect_true(all(abs(as.numeric(freq) - 1 / 3) < 0.06))
})

test_that("the matching bootstrap handles an empty reservoir", {
	set.seed(3)
	r <- K("draw_matching_bootstrap_sample_cpp")(integer(0), matrix(c(1, 2, 3, 4), 2, 2, byrow = TRUE), 0L)
	expect_length(r$i_b, 4L)
	expect_equal(r$m_vec_b, c(1L, 1L, 2L, 2L))
})

test_that("multi-row reservoir draws preserve the existing seeded sample and RNG state", {
	reservoir <- c(7L, 13L, 29L)
	seed <- 20261020L
	set.seed(seed)
	expected <- sample(reservoir, 12L, replace = TRUE)
	expected_rng <- .Random.seed
	set.seed(seed)
	r <- K("draw_matching_bootstrap_sample_cpp")(reservoir, matrix(integer(0), 0L, 2L), 12L)
	expect_identical(as.integer(r$i_b), as.integer(expected))
	expect_identical(.Random.seed, expected_rng)
})

test_that("a singleton reservoir unit is resampled with replacement without changing pair units", {
	set.seed(31)
	r <- K("draw_matching_bootstrap_sample_cpp")(7L, matrix(c(1, 2), 1, 2), 4L)
	expect_length(r$i_b, 6L)
	expect_equal(as.integer(r$i_b[1:4]), rep(7L, 4L))
	expect_equal(r$m_vec_b, c(rep(0L, 4L), 1L, 1L))
	expect_equal(as.integer(r$i_b[5:6]), c(1L, 2L))
})

test_that("singleton reservoir and multiple pair draws follow the seeded reference order", {
	reservoir <- 7L
	pair_rows <- matrix(c(1L, 2L, 3L, 4L, 5L, 6L), ncol = 2L, byrow = TRUE)
	n_reservoir <- 4L
	seed <- 20261021L
	set.seed(seed)
	expected_reservoir <- reservoir[sample.int(length(reservoir), n_reservoir, replace = TRUE)]
	expected_pair_ids <- sample.int(nrow(pair_rows), nrow(pair_rows), replace = TRUE)
	expected_pairs <- pair_rows[expected_pair_ids, , drop = FALSE]
	expected_rng <- .Random.seed
	expected_i_b <- c(expected_reservoir, as.integer(t(expected_pairs)))
	expected_m_vec_b <- c(rep(0L, n_reservoir), rep(seq_len(nrow(pair_rows)), each = 2L))

	set.seed(seed)
	r <- K("draw_matching_bootstrap_sample_cpp")(reservoir, pair_rows, n_reservoir)
	expect_identical(as.integer(r$i_b), expected_i_b)
	expect_identical(as.integer(r$m_vec_b), expected_m_vec_b)
	expect_identical(.Random.seed, expected_rng)
})

test_that("grouping gives pairs a shared cluster id, reservoir / NA units their own, with the active and reservoir flags", {
	g <- K("compute_matching_grouping_cpp")(c(1, 1, 2, 2, 0, 0, NA))
	expect_equal(as.numeric(g$cluster_id), c(1, 1, 2, 2, 3, 4, 5))
	expect_equal(as.numeric(g$pair_active), c(1, 1, 1, 1, 0, 0, 0))
	expect_equal(as.numeric(g$reservoir_ind), c(0, 0, 0, 0, 1, 1, 1))
	expect_equal(as.numeric(K("compute_cluster_ids_cpp")(c(1L, 1L, 2L, 2L, 0L, 0L))), c(1, 1, 2, 2, 3, 4))
})

test_that("match statistics on the identity resample equal the hand-computed pair differences and reservoir split", {
	m <- c(1L, 1L, 2L, 2L, 0L, 0L); y <- c(1, 2, 3, 5, 4, 6); w <- c(1, 0, 1, 0, 1, 0)
	X <- cbind(1:6, c(2, 1, 4, 3, 6, 5))
	s <- K("match_stats_from_indices_cpp")(X, y, w, m, 1:6, 2L)
	tr <- c(1, 3); co <- c(2, 4)                                          # treated / control member of each pair
	expect_equal(unname(s$X_matched_diffs), unname(X[tr, ] - X[co, ]))
	expect_equal(as.numeric(s$yTs_matched), y[tr]); expect_equal(as.numeric(s$yCs_matched), y[co])
	expect_equal(as.numeric(s$y_matched_diffs), y[tr] - y[co])
	expect_equal(unname(s$X_reservoir), unname(X[5:6, ]))
	expect_equal(as.numeric(s$y_reservoir), y[5:6]); expect_equal(as.integer(s$w_reservoir), c(1L, 0L))
	expect_equal(c(s$nRT, s$nRC, s$m), c(1L, 1L, 2L))
})
