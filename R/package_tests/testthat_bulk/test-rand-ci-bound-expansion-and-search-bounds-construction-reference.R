library(testthat)
library(EDI)

# InferenceRandCI private search-range builders: expand_bound() (clip to est +/- max_radius,
# accept a bound whose p-value is already below the target, otherwise double the step until it
# rejects, conservative fallback est +/- max_radius, NA for unusable inputs, deadline stop) and
# build_randomization_ci_search_bounds() (seed CI selection by ci_search_control$seed, the
# se_guess / response-scale radius, and the l < est < u bracket). The p-value and the seed CI
# candidates are stubbed so only the range logic is exercised.

fx <- function(pfun = function(d) 2 * pnorm(-abs(d) / 1)) {
	set.seed(1)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n, sd = 2))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	rec <- new.env(); rec$deltas <- numeric(0)
	unlockBinding("compute_randomization_ci_pval_cached", p)
	p$compute_randomization_ci_pval_cached <- function(inf_obj, r, delta, transform_arg, permutations, ctrl, cache) {
		rec$deltas <- c(rec$deltas, delta); pfun(delta)
	}
	list(inf = inf, p = p, rec = rec)
}
ctrl <- function(...) modifyList(list(seed = "asymp_then_boot", max_radius_se_mult = 10, max_radius_scale_mult = 5, max_expansions = 6L), list(...))
expand <- function(f, bound, lower, est = 0, target = 0.05, max_radius = 8, max_exp = 6L, control = ctrl()) {
	f$p$expand_bound(f$inf, bound, est, 100L, "none", NULL, target, lower, max_radius, max_exp, control, new.env())
}

test_that("a bound already rejecting is kept (clipped to the radius); the p-value is evaluated once", {
	f <- fx()
	expect_equal(expand(f, 3, FALSE), 3)                    # p(3) = 0.0027 < 0.05
	expect_equal(f$rec$deltas, 3)
	expect_equal(expand(fx(), -3, TRUE), -3)
	g <- fx()
	expect_equal(expand(g, 20, FALSE), 8)                   # clipped to est + max_radius, still rejecting
	expect_equal(g$rec$deltas, 8)
	expect_equal(expand(fx(), -20, TRUE), -8)
})

test_that("an accepted bound is expanded by doubling the step from |est - bound| until the p-value rejects", {
	f <- fx()
	expect_equal(expand(f, 0.5, FALSE), 2)                  # 0.5 -> steps 1, 2 ; p(2) = 0.0455 < 0.05
	expect_equal(f$rec$deltas, c(0.5, 1, 2))
	g <- fx()
	expect_equal(expand(g, -0.5, TRUE), -2)
	expect_equal(g$rec$deltas, c(-0.5, -1, -2))
})

test_that("the step is capped at max_radius; a never-rejecting p-value falls back to est +/- max_radius", {
	f <- fx(function(d) 0.9)
	expect_equal(expand(f, 1, FALSE), 8)
	expect_equal(f$rec$deltas, c(1, 2, 4, 8))               # stops once the step reaches max_radius
	expect_equal(expand(fx(function(d) 0.9), -1, TRUE), -8)
	g <- fx(function(d) 0.9)
	expect_equal(expand(g, 1, FALSE, max_exp = 2L), 8)     # expansions exhausted first
	expect_length(g$rec$deltas, 3L)
})

test_that("a non-finite p-value at the bound does not count as rejecting", {
	f <- fx(function(d) if (abs(d) < 1.5) NA_real_ else 0.001)
	expect_equal(expand(f, 0.5, FALSE), 2)
})

test_that("a zero-width start uses min(max_radius / 4, 1) as the initial step", {
	f <- fx(function(d) if (d < 3) 0.9 else 0.001)
	got <- expand(f, 0, FALSE, est = 0, max_radius = 8)     # bound == est: step 0 -> 1, doubles: 2, 4
	expect_equal(got, 4)
	expect_equal(f$rec$deltas, c(0, 2, 4))
})

test_that("unusable inputs return NA without evaluating the p-value", {
	f <- fx()
	expect_true(is.na(expand(f, NA_real_, FALSE)))
	expect_true(is.na(expand(f, 1, FALSE, est = NA_real_)))
	expect_true(is.na(expand(f, 1, FALSE, max_radius = 0)))
	expect_true(is.na(expand(f, 1, FALSE, max_radius = Inf)))
	expect_length(f$rec$deltas, 0L)
})

test_that("an elapsed deadline stops the expansion with its label", {
	f <- fx()
	ctl <- ctrl(timeout_deadline = unname(proc.time()[["elapsed"]]) - 10)
	expect_error(expand(f, 0.5, FALSE, control = ctl), "Randomization CI bound expansion reached elapsed time limit")
})

test_that("search bounds bracket the estimate, seeded from the Wald / asymptotic CI, and expanded to reject", {
	f <- fx()
	unlockBinding("get_randomization_ci_seed_candidates", f$p)
	f$p$get_randomization_ci_seed_candidates <- function(inf_obj, alpha) list(wald_ci = c(-1, 2.5), asym_ci = c(NA_real_, NA_real_))
	est <- as.numeric(f$inf$compute_estimate())
	b <- f$p$build_randomization_ci_search_bounds(f$inf, 100L, 0.05, "none", NULL, ctrl(), new.env())
	expect_equal(b$est, est)
	expect_equal(b$fallback_ci, c(-1, 2.5))
	expect_lt(b$l, est); expect_gt(b$u, est)
	expect_lt(b$l, b$u)
	# Each end is either rejecting at alpha / 2 or the conservative outer radius.
	se_guess <- max(abs(c(-1, 2.5) - est)) / qnorm(1 - 0.05)
	max_radius <- max(10 * se_guess, 5 * sd(f$p$y), 1)
	expect_true(2 * pnorm(-abs(b$l)) < 0.025 || isTRUE(all.equal(b$l, est - max_radius)))
	expect_true(2 * pnorm(-abs(b$u)) < 0.025 || isTRUE(all.equal(b$u, est + max_radius)))
})

test_that("with no seed candidates the default seed is est +/- 2 * se_guess and the seed policy `none` ignores candidates", {
	f <- fx()
	unlockBinding("get_randomization_ci_seed_candidates", f$p)
	f$p$get_randomization_ci_seed_candidates <- function(inf_obj, alpha) list(wald_ci = c(-0.1, 0.1), asym_ci = c(NA_real_, NA_real_))
	est <- as.numeric(f$inf$compute_estimate())
	seeded <- f$p$build_randomization_ci_search_bounds(f$inf, 100L, 0.05, "none", NULL, ctrl(), new.env())
	none <- f$p$build_randomization_ci_search_bounds(f$inf, 100L, 0.05, "none", NULL, ctrl(seed = "none"), new.env())
	g <- fx(); unlockBinding("get_randomization_ci_seed_candidates", g$p)
	g$p$get_randomization_ci_seed_candidates <- function(inf_obj, alpha) list(wald_ci = c(NA_real_, NA_real_), asym_ci = c(NA_real_, NA_real_))
	bare <- g$p$build_randomization_ci_search_bounds(g$inf, 100L, 0.05, "none", NULL, ctrl(), new.env())
	expect_equal(none$fallback_ci, c(-0.1, 0.1))   # fallback still reports the candidate
	expect_true(all(is.finite(c(seeded$l, seeded$u, none$l, none$u, bare$l, bare$u))))
	expect_lt(bare$l, est); expect_gt(bare$u, est)
	expect_equal(bare$fallback_ci, c(NA_real_, NA_real_))
})
