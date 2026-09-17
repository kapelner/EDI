library(testthat)
library(EDI)

# With no interior responses, beta mean and precision have zero likelihood information.
test_that("endpoint-only ZOIB score and Hessian reduce to multinomial logit", {
  X <- cbind(1, c(-1, 0, 1, 2))
  Xzi <- cbind(1, c(0.5, -0.5, 1, -1))
  gamma0 <- c(-0.4, 0.3)
  gamma1 <- c(0.2, -0.1)
  params <- c(0.7, -0.2, log(6), gamma0, gamma1)
  logits <- cbind(drop(Xzi %*% gamma0), drop(Xzi %*% gamma1), 0)
  probability <- exp(logits - apply(logits, 1, max))
  probability <- probability / rowSums(probability)
  p0 <- probability[, 1]
  p1 <- probability[, 2]
  expected_H <- matrix(0, 7, 7)
  expected_H[4:5, 4:5] <- -crossprod(Xzi, Xzi * (p0 * (1 - p0)))
  expected_H[6:7, 6:7] <- -crossprod(Xzi, Xzi * (p1 * (1 - p1)))
  expected_H[4:5, 6:7] <- crossprod(Xzi, Xzi * (p0 * p1))
  expected_H[6:7, 4:5] <- t(expected_H[4:5, 6:7])
  for (y in list(rep(0, 4), rep(1, 4), c(0, 1, 1, 0))) {
    expected_score <- c(rep(0, 3), drop(crossprod(Xzi, (y == 0) - p0)),
                        drop(crossprod(Xzi, (y == 1) - p1)))
    score <- EDI:::get_zero_one_inflated_beta_score_cpp(X, Xzi, y, params)
    H <- EDI:::get_zero_one_inflated_beta_hessian_cpp(X, Xzi, y, params)
    expect_equal(as.numeric(score), expected_score, tolerance = 1e-12)
    expect_equal(H, expected_H, tolerance = 1e-12)
    expect_equal(H, t(H), tolerance = 1e-12)
  }
})
