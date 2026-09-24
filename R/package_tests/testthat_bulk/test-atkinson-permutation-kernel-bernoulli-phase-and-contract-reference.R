library(testthat)
library(EDI)

# generate_permutations_atkinson_cpp (generate_permutations.cpp) draws nsim simulated Atkinson
# D-optimal sequential randomization sequences of length n, used by DesignSeqOneByOneAtkinson's
# private draw_ws_raw() for randomization-inference draws (design_seq_one_by_one_atkinson.R). A
# codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/
# confirms ZERO test references of any kind for this exported kernel by name -- the existing
# DesignSeqOneByOneAtkinson tests (test-atkinson-degenerate-covariate-crash-and-normal-branch.R
# etc.) exercise the LIVE per-subject assignment path (atkinson_assign_weight_cpp, a different
# function), never this batch-simulation kernel.
#
# For the first bernoulli_threshold = p_raw + 2 + 1 subjects, every draw is an unconditional
# Bernoulli(prob_T) coin flip (documented in the source: the D-optimal weight computation needs a
# minimum number of prior subjects to be well-defined); reimplementing the full Atkinson D-optimal
# weight formula for later subjects is out of scope here, so this file pins the verifiable contract:
# output shape/range, the exact-Bernoulli(prob_T) early phase (checked via binom.test, a standard
# non-flaky way to validate a probabilistic kernel), and reproducibility under set.seed().

f <- get("generate_permutations_atkinson_cpp", envir = asNamespace("EDI"))

fx <- function(seed = 61L, n = 20L, p_raw = 2L) {
	set.seed(seed)
	X <- cbind(1, matrix(rnorm(n * p_raw), n, p_raw))
	list(X = X, n = n, p_raw = p_raw)
}

test_that("output has the requested shape, is binary-valued, and m_mat is NULL", {
	d <- fx()
	set.seed(71)
	out <- f(d$X, d$n, d$p_raw, 0.5, 200L)
	expect_named(out, c("w_mat", "m_mat"))
	expect_equal(dim(out$w_mat), c(d$n, 200L))
	expect_true(all(out$w_mat %in% 0:1))
	expect_null(out$m_mat)
})

test_that("the first bernoulli_threshold = p_raw + 2 + 1 rows are unconditional Bernoulli(prob_T) draws, independent of X", {
	d <- fx(seed = 72L)
	bernoulli_threshold <- d$p_raw + 2L + 1L
	set.seed(73)
	out <- f(d$X, d$n, d$p_raw, 0.3, 3000L)
	early <- out$w_mat[seq_len(bernoulli_threshold), , drop = FALSE]
	pvals <- apply(early, 1, function(r) binom.test(sum(r), length(r), 0.3)$p.value)
	expect_true(all(pvals > 0.001))   # loose, non-flaky threshold: only fails if grossly non-Bernoulli(0.3)
})

test_that("draws are reproducible under an identical set.seed()", {
	d <- fx(seed = 74L)
	set.seed(81); a <- f(d$X, d$n, d$p_raw, 0.5, 50L)
	set.seed(81); b <- f(d$X, d$n, d$p_raw, 0.5, 50L)
	expect_identical(a$w_mat, b$w_mat)
})
