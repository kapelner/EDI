library(testthat)
library(EDI)

# generate_permutations_pocock_simon_cpp(x_levels_matrix, num_levels_total, weights, p_best, prob_T, nsim): for each
# subject the treatment minimising the weighted sum over covariates of within-level arm-count variance is "best" and
# is assigned with probability p_best (ties broken by prob_T). Reference: an R replay of that rule on the returned
# columns. Deterministic corners (p_best = 1 / 0), the interior frequency, tie handling, and input validation.

K <- get("generate_permutations_pocock_simon_cpp", envir = asNamespace("EDI"))
set.seed(71); n <- 40L
# two covariates with 2 and 3 levels; global level rows are 1-based: cov1 -> 1:2, cov2 -> 3:5
lv <- cbind(sample(1:2, n, TRUE), 2L + sample(1:3, n, TRUE)); storage.mode(lv) <- "integer"
wts <- c(1, 2); nlev <- 5L

replay <- function(W, lv, wts, keep_ties = FALSE) {
	# per step: G for assigning 0 and 1; returns data.frame(step gap G1 - G0, assigned)
	out <- vector("list", ncol(W))
	for (b in seq_len(ncol(W))) {
		cnt <- matrix(0, nrow(lv) * 0 + max(lv), 2)
		rows <- numeric(nrow(lv)); asg <- W[, b]
		for (i in seq_len(nrow(lv))) {
			G <- vapply(0:1, function(k) sum(wts * vapply(seq_len(ncol(lv)), function(j) {
				r <- lv[i, j]; c0 <- cnt[r, 1] + (k == 0); c1 <- cnt[r, 2] + (k == 1)
				m <- (c0 + c1) / 2; (c0 - m)^2 + (c1 - m)^2
			}, numeric(1))), numeric(1))
			rows[i] <- G[2] - G[1]
			for (j in seq_len(ncol(lv))) cnt[lv[i, j], asg[i] + 1] <- cnt[lv[i, j], asg[i] + 1] + 1
		}
		out[[b]] <- data.frame(gap = rows, w = asg)
	}
	do.call(rbind, out)
}

test_that("p_best = 1: every non-tied step assigns the arm with the smaller balance score", {
	set.seed(1); W <- K(lv, nlev, wts, 1, 0.5, 40L)$w_mat
	expect_equal(dim(W), c(n, 40L)); expect_true(all(W %in% 0:1))
	r <- replay(W, lv, wts)
	expect_true(all(r$w[r$gap < -1e-12] == 1L))
	expect_true(all(r$w[r$gap > 1e-12] == 0L))
	expect_gt(sum(abs(r$gap) < 1e-12), 0L)                 # the fixture does exercise ties
})

test_that("p_best = 0: every non-tied step assigns the arm with the larger balance score", {
	set.seed(2); r <- replay(K(lv, nlev, wts, 0, 0.5, 40L)$w_mat, lv, wts)
	expect_true(all(r$w[r$gap < -1e-12] == 0L))
	expect_true(all(r$w[r$gap > 1e-12] == 1L))
})

test_that("ties are broken by prob_T when p_best = 1 (prob_T = 1 / 0 send every tie to arm 1 / 0)", {
	set.seed(3); r1 <- replay(K(lv, nlev, wts, 1, 1, 40L)$w_mat, lv, wts)
	expect_true(all(r1$w[abs(r1$gap) < 1e-12] == 1L))
	r0 <- replay(K(lv, nlev, wts, 1, 0, 40L)$w_mat, lv, wts)
	expect_true(all(r0$w[abs(r0$gap) < 1e-12] == 0L))
})

test_that("interior p_best: the better arm is chosen with frequency p_best at non-tied steps", {
	set.seed(4); p <- 0.8
	r <- replay(K(lv, nlev, wts, p, 0.5, 400L)$w_mat, lv, wts)
	nt <- abs(r$gap) > 1e-12
	best_chosen <- ifelse(r$gap[nt] < 0, r$w[nt] == 1L, r$w[nt] == 0L)
	expect_equal(mean(best_chosen), p, tolerance = 4 * sqrt(p * (1 - p) / sum(nt)) / p)
})

test_that("reproducible under set.seed and returns a NULL m_mat", {
	set.seed(5); a <- K(lv, nlev, wts, 0.8, 0.5, 10L); set.seed(5); b <- K(lv, nlev, wts, 0.8, 0.5, 10L)
	expect_identical(a$w_mat, b$w_mat); expect_null(a$m_mat)
})

test_that("input validation errors", {
	expect_error(K(lv, 0L, wts, 1, 0.5, 5L), "num_levels_total must be positive")
	expect_error(K(lv, nlev, 1, 1, 0.5, 5L), "weights length must match the number of covariates")
	bad <- lv; bad[1, 1] <- 99L
	expect_error(K(bad, nlev, wts, 1, 0.5, 5L), "outside 1..num_levels_total")
	bad0 <- lv; bad0[2, 2] <- 0L
	expect_error(K(bad0, nlev, wts, 1, 0.5, 5L), "outside 1..num_levels_total")
})
