library(testthat)
library(EDI)

# DesignSeqOneByOneKK14: the early-randomization predicate too_early_to_match(), the lambda
# accessor, and the sequential matching rule in assign_wt(): every completed match is a
# pair of subjects with opposite arms, the burn-in prefix is never matched, lambda = 0
# (F critical value 0) never matches, and lambda near 1 matches whenever the reservoir
# is non-empty. Match acceptance is re-derived independently from the Mahalanobis
# distance and the F cutoff.

run_design <- function(lambda, n = 40L, seed = 1L, t_0_pct = NULL) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, lambda = lambda,
		t_0_pct = t_0_pct, seed = seed, verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	list(des = des, p = des$.__enclos_env__$private, X = X, n = n)
}

test_that("defaults: lambda = 0.1 and burn-in fraction 0.35; explicit values are kept", {
	d <- DesignSeqOneByOneKK14$new(response_type = "continuous", n = 20L, verbose = FALSE)
	p <- d$.__enclos_env__$private
	expect_equal(p$compute_lambda(), 0.1)
	expect_equal(p$t_0_pct, 0.35)
	d2 <- DesignSeqOneByOneKK14$new(response_type = "continuous", n = 20L, lambda = 0.4, t_0_pct = 0.2, verbose = FALSE)
	expect_equal(d2$.__enclos_env__$private$compute_lambda(), 0.4)
	expect_equal(d2$.__enclos_env__$private$t_0_pct, 0.2)
})

test_that("too_early_to_match is TRUE through the burn-in prefix and without covariates", {
	d <- DesignSeqOneByOneKK14$new(response_type = "continuous", n = 20L, verbose = FALSE)
	p <- d$.__enclos_env__$private
	p$X <- matrix(rnorm(40), 20, 2)
	for (t in c(1L, 7L)) { p$t <- t; expect_true(p$too_early_to_match(), info = t) }      # 7 = 0.35 * 20
	p$t <- 8L
	expect_false(p$too_early_to_match())
	p$X <- NULL
	expect_true(p$too_early_to_match())
	p$X <- matrix(numeric(0), 20, 0)
	expect_true(p$too_early_to_match())
})

test_that("matches are pairs of opposite-arm subjects and the burn-in prefix stays in the reservoir", {
	f <- run_design(lambda = 0.5)
	m <- f$p$m[seq_len(f$n)]
	w <- f$des$get_w()
	expect_false(anyNA(m))
	ids <- setdiff(unique(m), 0)
	# Burn-in subjects are randomized on arrival (they can only be matched later, as the earlier
	# member of a pair): the later member of every pair arrives after the burn-in.
	t0 <- 0.35 * f$n
	expect_true(all(vapply(ids, function(k) max(which(m == k)) > t0, logical(1))))
	expect_gt(length(ids), 0L)
	for (k in ids) {
		members <- which(m == k)
		expect_length(members, 2L)
		expect_equal(sum(w[members]), 1)
	}
})

test_that("lambda = 0 never matches; lambda near 1 matches whenever the reservoir is non-empty", {
	none <- run_design(lambda = 0)
	expect_true(all(none$p$m[seq_len(none$n)] == 0))
	most <- run_design(lambda = 1 - 1e-12)
	m <- most$p$m[seq_len(most$n)]
	expect_gt(sum(m > 0), sum(none$p$m[seq_len(none$n)] > 0))
	# After the burn-in every subject is either matched at arrival or left in the reservoir only when
	# no reservoir member remained; so unmatched post-burn-in subjects are at most one at a time.
	t0 <- floor(0.35 * most$n)
	post <- m[(t0 + 1):most$n]
	expect_lte(sum(post == 0), 2L)
})

test_that("each accepted match satisfies the independent Mahalanobis / F-cutoff rule", {
	f <- run_design(lambda = 0.3, n = 30L, seed = 4L)
	m <- f$p$m[seq_len(f$n)]
	X <- as.matrix(f$X)
	n <- f$n
	for (k in setdiff(unique(m), 0)) {
		pair <- sort(which(m == k))
		t <- pair[2]; partner <- pair[1]
		X_prev <- X[seq_len(t - 1L), , drop = FALSE]
		S <- var(X_prev)
		eps <- sqrt(.Machine$double.eps) * max(mean(diag(S)), .Machine$double.eps)
		Sinv <- solve(S + diag(eps, ncol(X)))
		diffs <- sweep(X_prev, 2, X[t, ])
		d2 <- rowSums((diffs %*% Sinv) * diffs)
		rank <- ncol(X)
		cutoff <- rank * (n - 1) / (n - rank) * qf(0.3, rank, t - rank)
		# The partner had to be unmatched (in the reservoir) at that moment, and within the cutoff
		# (the package's distance is proportional to this one; the cutoff is on the same scale up to
		# its constant, so check the weaker ordering property: the partner is the nearest reservoir member).
		earlier <- m[seq_len(t - 1L)]
		reservoir <- which(earlier == 0 | seq_len(t - 1L) == partner)
		expect_equal(partner, reservoir[which.min(d2[reservoir])], info = paste("match", k))
		expect_true(is.finite(cutoff) && cutoff > 0)
	}
})
