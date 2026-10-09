library(testthat)
library(EDI)

test_that("optimal-block distance dispatch agrees with independent pairwise formulas", {
  X <- cbind(c(-2, 0, 1, 4), c(1, -1, 3, 0))
  euclidean <- as.matrix(dist(X))^2
  absolute <- as.matrix(dist(X, method = "manhattan"))
  expect_equal(EDI:::optimal_blocks_distance_matrix_cpp(X, 1L), unname(euclidean))
  expect_equal(EDI:::optimal_blocks_distance_matrix_cpp(X, 2L), unname(absolute))
  custom <- EDI:::optimal_blocks_distance_matrix_cpp(X, 0L,
    dist_fn = function(a, b) sum((a - b)^2) + sum(abs(a - b)))
  expect_equal(custom, unname(euclidean + absolute))
  expect_equal(diag(custom), rep(0, 4))
})

test_that("multivariate binary matching minimizes four-subject Euclidean pairing cost", {
  skip_if_not_installed("nbpMatching")
  X <- cbind(c(0, 0.1, 10, 10.2), c(0, 0.2, 2, 2.1))
  D <- as.matrix(dist(X))
  possible <- list(matrix(c(1, 2, 3, 4), 2, byrow = TRUE),
                   matrix(c(1, 3, 2, 4), 2, byrow = TRUE),
                   matrix(c(1, 4, 2, 3), 2, byrow = TRUE))
  cost <- function(pairs) sum(D[pairs])
  fit <- EDI:::compute_binary_match_structure(X, mahal_match = FALSE)
  expect_equal(cost(fit$indices_pairs), min(vapply(possible, cost, numeric(1))), tolerance = 1e-12)
  expect_equal(sort(as.integer(fit$indices_pairs)), 1:4)

  D2 <- D^2
  cost2 <- function(pairs) sum(D2[pairs])
  legacy <- EDI:::compute_binary_match_structure(X, mahal_match = FALSE,
                                                  match_objective = "squared_distance")
  expect_equal(cost2(legacy$indices_pairs), min(vapply(possible, cost2, numeric(1))), tolerance = 1e-12)
})

test_that("zero diagonal preserves legacy squared-distance pairs and default matches ordinary distance", {
  skip_if_not_installed("nbpMatching")
  canonical_pairs <- function(D) {
    p <- as.matrix(nbpMatching::nonbimatch(nbpMatching::distancematrix(D))$matches[, c("Group1.Row", "Group2.Row")])
    for (i in seq_len(nrow(p))) p[i, ] <- sort(p[i, ])
    unique(p)
  }
  pair_key <- function(p) sort(apply(p, 1L, function(z) paste(sort(z), collapse = ":")))

  for (n in c(20L, 200L, 1000L)) for (p in c(2L, 4L)) {
    set.seed(61000L + n + p)
    X <- matrix(rnorm(n * p), nrow = n)
    for (mahal in c(FALSE, TRUE)) {
      Xd <- if (mahal) {
        Sinv <- solve(stats::var(X)); X %*% t(chol(Sinv))
      } else X
      D2 <- as.matrix(stats::dist(Xd))^2
      old <- D2; diag(old) <- .Machine$double.xmax
      zero <- D2; diag(zero) <- 0
      expect_identical(pair_key(canonical_pairs(zero)), pair_key(canonical_pairs(old)))

      legacy <- EDI:::compute_binary_match_structure(
        X, mahal_match = mahal, match_objective = "squared_distance"
      )
      expect_identical(pair_key(legacy$indices_pairs), pair_key(canonical_pairs(zero)))

      ordinary <- sqrt(D2); diag(ordinary) <- 0
      current <- EDI:::compute_binary_match_structure(X, mahal_match = mahal)
      expect_identical(pair_key(current$indices_pairs), pair_key(canonical_pairs(ordinary)))
    }
  }
})

test_that("cluster allocation batches have fixed treated-cluster counts", {
  skip_if_not_installed("randomizr")
  X <- data.frame(cluster = rep(letters[1:6], c(1, 2, 3, 1, 2, 3)), x = 1:12)
  des <- DesignFixedCluster$new("cluster", "continuous", n = 12, seed = 601)
  des$add_all_subjects_to_experiment(X)
  draws <- des$draw_ws_according_to_design(r = 12)
  representatives <- match(unique(X$cluster), X$cluster)
  expect_equal(colSums(draws[representatives, , drop = FALSE]), rep(3, 12))
  for (cluster in unique(X$cluster)) {
    rows <- which(X$cluster == cluster)
    expect_true(all(draws[rows, , drop = FALSE] ==
                      matrix(draws[rows[1], ], nrow = length(rows), ncol = 12, byrow = TRUE)))
  }
})

test_that("numeric fixed blocking follows quantile geometry on an evenly spaced covariate", {
  skip_if_not_installed("randomizr")
  des <- DesignFixedBlocking$new("x", response_type = "continuous", n = 12,
                                 B_target = 3, exact_num_blocks = TRUE,
                                 preferred_num_bins_for_continuous_covariate = 3, seed = 602)
  des$add_all_subjects_to_experiment(data.frame(x = 1:12))
  des$assign_w_to_all_subjects()
  blocks <- des$get_block_ids()
  expect_equal(as.integer(table(blocks)), c(4L, 4L, 4L))
  expect_equal(as.numeric(rowsum(des$get_w(), blocks)), rep(2, 3))
  expect_true(all(blocks[1:4] == blocks[1]))
  expect_true(all(blocks[5:8] == blocks[5]))
  expect_true(all(blocks[9:12] == blocks[9]))
})
