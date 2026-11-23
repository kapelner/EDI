library(testthat)
library(EDI)

# v1.0.6-TODO-294 (DECISION-v1.0.6-TODO-294, option (b), owner 2026-11-23): with
# prop_acceptable, DesignFixedRerandomization realizes its allocation as the best of
# k = round(1 / prop_acceptable) draws, but the randomization reference used to keep the
# best r of r / prop_acceptable draws, a tighter law (n = 40, two covariates,
# prop_acceptable = 0.01: KS D = 0.317 between realized and reference M(w); rand test size
# 7.25% at nominal 5%). Each reference draw is now the best of its own k draws, the same
# rule as the realized one, and realized allocations are unchanged.

rerand_294_X = function(n) {
	set.seed(294L)
	data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rbinom(n, 1, 0.4))
}

test_that("realized prop_acceptable allocations are the same as before the fix", {
	# Treated indices recorded from the pre-fix code (HEAD 307a5871) for each draw kernel:
	# forced-balanced (even n), n_T kernel at odd n, and n_T kernel at prob_T = 0.3.
	cases = list(
		list(n = 20L, prob_T = 0.5, prop = 0.1, seed = 7L, obj = "mahal_dist",
			treated = c(1L, 2L, 4L, 6L, 8L, 9L, 10L, 11L, 13L, 17L)),
		list(n = 23L, prob_T = 0.5, prop = 0.05, seed = 8L, obj = "mahal_dist",
			treated = c(1L, 2L, 5L, 8L, 10L, 15L, 17L, 18L, 19L, 20L, 21L, 23L)),
		list(n = 30L, prob_T = 0.3, prop = 0.02, seed = 9L, obj = "abs_sum_diff",
			treated = c(2L, 5L, 6L, 7L, 8L, 12L, 15L, 29L, 30L))
	)
	for (cs in cases) {
		d = DesignFixedRerandomization$new(response_type = "continuous", n = cs$n, prob_T = cs$prob_T,
			prop_acceptable = cs$prop, objective = cs$obj, seed = cs$seed, verbose = FALSE)
		d$add_all_subjects_to_experiment(rerand_294_X(cs$n))
		d$assign_w_to_all_subjects()
		expect_identical(which(d$get_w() == 1), cs$treated, info = paste("n", cs$n))
	}
})

test_that("each reference draw is the best of its own group of round(1 / prop_acceptable) draws", {
	n = 20L; r = 6L; prop = 0.2; k = 5L; seed = 13L
	X = rerand_294_X(n)
	d = DesignFixedRerandomization$new(response_type = "continuous", n = n, prop_acceptable = prop,
		seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	W = d$draw_ws_according_to_design(r)
	Xm = as.matrix(X)
	S_inv = solve(var(Xm))
	M = function(w) { dd = colMeans(Xm[w == 1, , drop = FALSE]) - colMeans(Xm[w == 0, , drop = FALSE]); drop(dd %*% S_inv %*% dd) }
	pool = EDI:::complete_randomization_forced_balanced_cpp(n, r * k, seed)
	objs = apply(pool, 1L, M)
	best_rows = vapply(seq_len(r), function(j) (j - 1L) * k + which.min(objs[(j - 1L) * k + seq_len(k)]), numeric(1))
	expect_equal(unname(W), unname(t(pool[best_rows, , drop = FALSE])))
	# The first reference draw of a seeded design is its realized allocation.
	d$assign_w_to_all_subjects()
	expect_identical(as.numeric(W[, 1L]), as.numeric(d$get_w()))
})

test_that("reference draws and realized allocations follow the same M(w) law", {
	set.seed(20261118)
	n = 40L
	X = data.frame(weight = round(rnorm(n, 25, 3), 1), age = sample(6:12, n, replace = TRUE))
	Xm = as.matrix(X)
	S_inv = solve(cov(Xm))
	M = function(w) { dd = colMeans(Xm[w == 1, ]) - colMeans(Xm[w == 0, ]); drop(dd %*% S_inv %*% dd) }
	M_realized = vapply(1:400, function(s) {
		d = DesignFixedRerandomization$new(response_type = "continuous", n = n, prop_acceptable = 0.01,
			seed = 10000L + s, verbose = FALSE)
		d$add_all_subjects_to_experiment(X)
		d$assign_w_to_all_subjects()
		M(d$get_w())
	}, numeric(1))
	d = DesignFixedRerandomization$new(response_type = "continuous", n = n, prop_acceptable = 0.01,
		seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	M_reference = apply(d$draw_ws_according_to_design(1000L), 2L, M)
	D = unname(suppressWarnings(stats::ks.test(M_realized, M_reference))$statistic)
	# Before the fix D was about 0.32 on this data (the reference never left the best 1% of
	# the base law, while about 32% of realized allocations did).
	expect_lt(D, 0.1)
})

test_that("seeded reference draws and rand p-values do not depend on the core count", {
	skip_on_cran()
	skip_if(identical(Sys.getenv("R_COVR"), "true"), "avoid spawning workers under covr")
	available = parallel::detectCores(logical = TRUE)
	skip_if(is.na(available) || available < 2L, "fewer than 2 logical cores available")
	n = 24L
	X = rerand_294_X(n)
	run = function(cores) {
		set_num_cores(cores)
		on.exit(unset_num_cores(), add = TRUE)
		d = DesignFixedRerandomization$new(response_type = "continuous", n = n, prop_acceptable = 0.05,
			seed = 21L, verbose = FALSE)
		d$add_all_subjects_to_experiment(X)
		d$assign_w_to_all_subjects()
		set.seed(5L)
		d$add_all_subject_responses(X$x1 + rnorm(n))
		W = d$draw_ws_according_to_design(50L)
		inf = InferenceAllSimpleMeanDiffPooledVar$new(d)
		inf$set_seed(3L)
		p = inf$compute_rand_two_sided_pval(r = 99L, show_progress = FALSE)
		list(W = W, p = p)
	}
	r1 = run(1L)
	r1b = run(1L)
	r2 = run(2L)
	expect_identical(r1b$W, r1$W)
	expect_identical(r1b$p, r1$p)
	expect_identical(r2$W, r1$W)
	expect_identical(r2$p, r1$p)
	expect_true(is.finite(r1$p))
})
