library(testthat)
library(EDI)

# generate_permutations_pocock_simon_cpp (generate_permutations.cpp) has three independent input
# guards; test-pocock-simon-permutation-kernel-marginal-balance-rule-replay-and-tie-handling-
# reference.R already covers 2 of them ("num_levels_total must be positive" and "weights length must
# match the number of covariates"), but its own comment/test block never exercises the third:
# `if (row_idx < 0 || row_idx >= num_levels_total) throw std::invalid_argument("x_levels_matrix
# contains a level index outside 1..num_levels_total")` -- confirmed via grep to have no test
# reference anywhere. The identical guard on the file-sibling pocock_simon_redraw_w_cpp (a different
# exported function reusing the same validation pattern) was already closed this stretch in
# test-pocock-simon-redraw-w-kernel-input-guards-and-output-contract-reference.R; this file closes
# the last remaining copy, on generate_permutations_pocock_simon_cpp itself.

K <- get("generate_permutations_pocock_simon_cpp", envir = asNamespace("EDI"))
set.seed(101); n <- 40L
lv <- cbind(sample(1:2, n, TRUE), 2L + sample(1:3, n, TRUE))
storage.mode(lv) <- "integer"
wts <- c(1, 2)
nlev <- 5L

test_that("a level index outside 1..num_levels_total in x_levels_matrix throws the level-index error", {
	lv_bad <- lv
	lv_bad[1, 1] <- 99L
	expect_error(K(lv_bad, nlev, wts, 1, 0.5, 5L), "x_levels_matrix contains a level index outside 1\\.\\.num_levels_total")

	lv_bad2 <- lv
	lv_bad2[3, 2] <- 0L
	expect_error(K(lv_bad2, nlev, wts, 1, 0.5, 5L), "x_levels_matrix contains a level index outside 1\\.\\.num_levels_total")
})

test_that("in-range level indices (1..num_levels_total) do not trigger the guard", {
	out <- K(lv, nlev, wts, 1, 0.5, 5L)
	expect_equal(dim(out$w_mat), c(n, 5L))
	expect_true(all(out$w_mat %in% 0:1))
})
