library(testthat)
library(EDI)

# v1.0.6-TODO-167: the combined exact p-value of InferenceIncidExactZhang is not monotone in the log
# odds ratio (each component is a two-sided "minimum likelihood" exact p-value that jumps where
# another outcome ties the observed one), so the set of accepted values can have gaps. The bisection
# used to return only the piece around its starting point (8 of 323 random KK CIs). The CI is now the
# convex hull of the accepted set (Blaker 2000; Fay 2010), and an endpoint on a jump is reported at
# the jump itself (at p0 = 0.5 the binomial's tie with its mirror outcome put endpoints at about
# -1e-7 where the test accepts delta = 0). The fixtures rebuild exact tables of gapped cases found
# by a random sweep (the CI depends on nothing else).

zhang_table_fx <- function(m, d_plus, d_minus, n11, n10, n01, n00) {
	# Pairs: d_plus (treated 1, control 0), d_minus (0, 1), the rest concordant (1, 1);
	# then the reservoir 2x2 table.
	conc <- m - d_plus - d_minus
	yT <- c(rep(1L, d_plus), rep(0L, d_minus), rep(1L, conc))
	yC <- c(rep(0L, d_plus), rep(1L, d_minus), rep(1L, conc))
	w <- c(rep(c(1L, 0L), m), rep(1L, n11 + n10), rep(0L, n01 + n00))
	y <- c(as.vector(rbind(yT, yC)), rep(1L, n11), rep(0L, n10), rep(1L, n01), rep(0L, n00))
	m_vec <- c(rep(seq_len(m), each = 2L), rep(0L, n11 + n10 + n01 + n00))
	n <- length(w)
	set.seed(1)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$w <- w
	des$.__enclos_env__$private$m <- m_vec
	des$add_all_subject_responses(y)
	InferenceIncidExactZhang$new(des, verbose = FALSE)
}

# Gapped cases: table (m, d_plus, d_minus, n11, n10, n01, n00), combination method, and the old
# connected-piece CI at alpha = 0.05.
gapped <- list(
	list(tab = c(15L, 0L, 4L, 9L, 6L, 7L, 17L),   cm = "Fisher",   old = c(-0.0703551, -1.273865e-07)),
	list(tab = c(31L, 6L, 5L, 16L, 0L, 9L, 7L),   cm = "Stouffer", old = c(-1.077512e-07, 0.5148099)),
	list(tab = c(9L, 0L, 2L, 13L, 4L, 9L, 12L),   cm = "Stouffer", old = c(0.2792895, 1.894771)),
	list(tab = c(28L, 0L, 3L, 6L, 5L, 3L, 10L),   cm = "Stouffer", old = c(-0.1856638, 1.534667)),
	list(tab = c(20L, 3L, 1L, 1L, 9L, 5L, 3L),    cm = "Fisher",   old = c(-1.672885, 0.4918907))
)
fx_of <- function(g) do.call(zhang_table_fx, as.list(g$tab))
pval <- function(inf, cm) function(d) EDI:::zhang_pval_exact_combined(inf, d, cm)

test_that("the CI is the convex hull of every log odds ratio the combined test accepts", {
	for (g in gapped) {
		inf <- fx_of(g)
		p <- pval(inf, g$cm)
		ci <- inf$compute_exact_confidence_interval(0.05, args_for_type = list(Zhang = list(combination_method = g$cm)))
		expect_length(ci, 2L)
		expect_true(all(is.finite(ci)))
		# Wider than the old connected piece on at least one side.
		expect_true(ci[[1]] < g$old[1] - 0.01 || ci[[2]] > g$old[2] + 0.01)
		# Every accepted grid point lies inside the CI.
		grid <- seq(ci[[1]] - 1.5, ci[[2]] + 1.5, by = 2e-3)
		acc <- grid[vapply(grid, p, numeric(1)) >= 0.05]
		expect_gte(min(acc), ci[[1]] - 1e-9)
		expect_lte(max(acc), ci[[2]] + 1e-9)
		# Both endpoints are accepted (closed endpoints) or at the alpha crossing, and the test rejects
		# just outside them.
		expect_gte(p(ci[[1]]), 0.05 - 1e-6); expect_gte(p(ci[[2]]), 0.05 - 1e-6)
		expect_lt(p(ci[[1]] - 1e-5), 0.05); expect_lt(p(ci[[2]] + 1e-5), 0.05)
		# The accepted set really has a gap: some value inside the CI is rejected.
		expect_true(any(vapply(grid[grid > ci[[1]] & grid < ci[[2]]], p, numeric(1)) < 0.05))
	}
})

test_that("an endpoint on a p0 = 0.5 tie is exactly 0, where the test accepts", {
	inf <- fx_of(gapped[[2]])                                                  # Stouffer, lower end on the tie
	ci <- inf$compute_exact_confidence_interval(0.05, args_for_type = list(Zhang = list(combination_method = "Stouffer")))
	expect_identical(ci[[1]], 0)
	p <- pval(inf, "Stouffer")
	expect_gt(p(0), 0.05)
	expect_lt(p(-1e-6), 0.05)
	# The CI agrees with the test of delta = 0: it is accepted and inside the CI.
	expect_gt(inf$compute_exact_two_sided_pval_for_treatment_effect(args_for_type = list(Zhang = list(combination_method = "Stouffer"))), 0.05)
	inf <- fx_of(gapped[[1]])                                                  # Fisher: the old upper end was -1.27e-7
	ci <- inf$compute_exact_confidence_interval(0.05)
	expect_gt(inf$compute_exact_two_sided_pval_for_treatment_effect(), 0.05)
	expect_true(ci[[1]] < 0 && ci[[2]] > 0)
})

test_that("breakpoints are the ties of each component's outcomes with the observed one", {
	st <- list(m = 5L, d_plus = 1L, d_minus = 3L, nRT = 0L, nRC = 0L, n11 = 0L, n10 = 0L, n01 = 0L, n00 = 0L)
	bp <- EDI:::zhang_exact_pval_breakpoints(st)
	k <- 4L; x <- 1L; j <- setdiff(0:k, x)
	expect_equal(bp, sort((lchoose(k, x) - lchoose(k, j)) / (j - x)), tolerance = 1e-12)
	expect_true(0 %in% bp)                                                     # mirror outcome 3 ties at p0 = 0.5
	# The binomial p-value jumps at each breakpoint and counts the tie there.
	pb <- function(d) EDI:::zhang_exact_binom_pval_cpp(1L, 3L, d)
	for (b in bp) {
		expect_gte(pb(b), max(pb(b - 1e-6), pb(b + 1e-6)) - 1e-6)
		expect_gt(abs(pb(b - 1e-6) - pb(b + 1e-6)), 1e-3)
	}
	expect_equal(pb(0), binom.test(1, 4)$p.value, tolerance = 1e-10)
})

test_that("with no gap the CI is the bisection result around the start point", {
	set.seed(6L)
	np <- 15L; ns <- 14L; n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	w <- des$get_w(); des$add_all_subject_responses(rbinom(n, 1, plogis(0.8 * w)))
	inf <- InferenceIncidExactZhang$new(des, verbose = FALSE)
	ci <- inf$compute_exact_confidence_interval(0.1)
	p <- pval(inf, "Fisher")
	grid <- seq(ci[[1]] - 1.5, ci[[2]] + 1.5, by = 2e-3)
	acc <- grid[vapply(grid, p, numeric(1)) >= 0.1]
	expect_true(all(diff(acc) < 2.5e-3))                                       # one connected piece
	st <- EDI:::zhang_get_exact_stats(inf)
	inside <- EDI:::zhang_ci_inside_point(p, st, -3, 3, 0.1)
	old <- c(EDI:::zhang_bisect_ci_boundary(p, inside, ci[[1]] - 1, 0.1, 1e-6),
		EDI:::zhang_bisect_ci_boundary(p, inside, ci[[2]] + 1, 0.1, 1e-6))
	expect_equal(as.numeric(ci), old, tolerance = 2e-6)
})

test_that("the vectorised scan p-value equals the scalar kernels, ties at breakpoints included", {
	for (g in gapped) {
		inf <- fx_of(g)
		st <- EDI:::zhang_get_exact_stats(inf)
		d <- c(seq(-4, 4, length.out = 201), EDI:::zhang_exact_pval_breakpoints(st))
		for (cm in c("Fisher", "Stouffer", "min_p")) {
			expect_equal(as.vector(EDI:::zhang_pval_exact_combined_vec(st, d, cm)),
				vapply(d, function(x) EDI:::zhang_pval_exact_combined(inf, x, cm), numeric(1)), tolerance = 1e-12)
		}
	}
})
