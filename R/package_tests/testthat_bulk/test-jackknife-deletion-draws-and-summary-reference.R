library(testthat)
library(EDI)

# The jackknife machinery's private pieces, none with a direct test reference:
# build_jackknife_deletion_draws() (observation and KK matched-set units),
# assert_jackknife_supported(), and compute_jackknife_summary() (bias-corrected
# estimate, bias, standard error, caching, and every unavailable-result branch).
# References: independent leave-one-out mean differences and the textbook
# delete-1 jackknife formulas.

smd_boot_fixture <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n, sd = 0.5)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, y = y, n = n)
}

mean_diff <- function(y, w) mean(y[w == 1]) - mean(y[w == 0])

kk_boot_fixture <- function(n = 30L, seed = 9L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	list(inf = inf, priv = inf$.__enclos_env__$private, des_priv = des$.__enclos_env__$private, n = n)
}

test_that("observation-unit deletion draws are the leave-one-out index sets", {
	f <- smd_boot_fixture()
	ref <- lapply(seq_len(f$n), function(i) setdiff(seq_len(f$n), i))
	expect_equal(f$priv$build_jackknife_deletion_draws("observation"), ref)
	expect_equal(f$priv$build_jackknife_deletion_draws("auto"), ref)
})

test_that("KK matched-set deletion draws remove reservoir subjects singly and matched pairs together, with renumbered match ids", {
	f <- kk_boot_fixture()
	draws <- f$priv$build_jackknife_deletion_draws("auto")
	m <- f$des_priv$m
	m[is.na(m)] <- 0L
	pair_ids <- sort(unique(m[m > 0]))
	reservoir <- which(m == 0L)
	expect_length(draws, length(pair_ids) + length(reservoir))

	deleted <- lapply(draws, function(d) setdiff(seq_len(f$n), d$i_b))
	ref_deleted <- c(lapply(reservoir, function(i) i), lapply(pair_ids, function(p) which(m == p)))
	key <- function(x) paste(sort(x), collapse = ",")
	expect_setequal(vapply(deleted, key, character(1)), vapply(ref_deleted, key, character(1)))

	renum <- function(v) { pos <- sort(unique(v[v > 0])); out <- integer(length(v)); out[v > 0] <- match(v[v > 0], pos); out }
	for (d in draws) {
		expect_equal(as.integer(d$m_vec_b), renum(m[d$i_b]))
	}
})

test_that("assert_jackknife_supported rejects units the design cannot provide", {
	f <- smd_boot_fixture()
	expect_null(f$priv$assert_jackknife_supported("observation"))
	expect_null(f$priv$assert_jackknife_supported("auto"))
	expect_error(f$priv$assert_jackknife_supported("block"), "requires a blocking design")
	expect_error(f$priv$assert_jackknife_supported("pair"), "requires a matching design")
	expect_error(f$priv$assert_jackknife_supported("matched_set"), "requires a matching design")
	expect_error(f$priv$assert_jackknife_supported("cluster"), "requires a clustered design")
	expect_error(f$priv$assert_jackknife_supported("bogus"))
})

test_that("compute_jackknife_summary matches the delete-1 jackknife formulas and is cached", {
	f <- smd_boot_fixture()
	theta <- mean_diff(f$y, f$w)
	jack <- vapply(seq_len(f$n), function(i) mean_diff(f$y[-i], f$w[-i]), numeric(1))
	n <- f$n
	bias <- (n - 1) * (mean(jack) - theta)

	s <- f$priv$compute_jackknife_summary("observation")
	expect_equal(s$distribution, jack, tolerance = 1e-10)
	expect_equal(s$bias, bias, tolerance = 1e-10)
	expect_equal(s$estimate, theta - bias, tolerance = 1e-10)
	expect_equal(s$std_error, sqrt(((n - 1) / n) * sum((jack - mean(jack))^2)), tolerance = 1e-10)

	expect_equal(f$inf$compute_jackknife_estimate(), s$estimate, tolerance = 1e-10)
	expect_equal(f$inf$compute_jackknife_bias_estimate(), s$bias, tolerance = 1e-10)
	expect_equal(f$inf$compute_jackknife_std_error(), s$std_error, tolerance = 1e-10)
	z <- (theta - 0.1) / s$std_error
	expect_equal(f$inf$compute_jackknife_wald_two_sided_pval(delta = 0.1), 2 * pnorm(-abs(z)), tolerance = 1e-10)

	f$priv$cached_values$jackknife_summary[["observation"]]$estimate <- 999
	expect_equal(f$priv$compute_jackknife_summary("observation")$estimate, 999)
})

test_that("summary is unavailable when the original estimate, replicates or summary are unusable", {
	stub_jack <- function(f, values) {
		unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", f$priv)
		f$priv$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") values
	}
	all_na <- function(s) all(is.na(c(s$estimate, s$bias, s$std_error)))

	f1 <- smd_boot_fixture()
	stub_jack(f1, 1)                                   # a single unit cannot support a jackknife
	expect_true(all_na(f1$priv$compute_jackknife_summary("observation")))
	expect_equal(length(f1$priv$compute_jackknife_summary("observation")$distribution), 0L)

	f2 <- smd_boot_fixture()
	stub_jack(f2, c(0.1, NA, 0.2, 0.3))
	expect_true(all_na(f2$priv$compute_jackknife_summary("observation")))
	expect_true(f2$inf$is_nonestimable("se"))

	f3 <- smd_boot_fixture()
	stub_jack(f3, c(0.1, 0.2, 5e6))                    # extreme finite replicate
	expect_true(all_na(f3$priv$compute_jackknife_summary("observation")))
	expect_true(f3$inf$is_nonestimable("se"))

	f4 <- smd_boot_fixture()
	stub_jack(f4, c(-40, 40, -30, 30))                 # |bias| > 2 * se or extreme summary
	s4 <- f4$priv$compute_jackknife_summary("observation")
	expect_true(all_na(s4) || is.finite(s4$std_error))

	f5 <- smd_boot_fixture()
	unlockBinding("compute_estimate", f5$inf)
	f5$inf$compute_estimate <- function(estimate_only = FALSE) NA_real_
	expect_true(all_na(f5$priv$compute_jackknife_summary("observation")))
	expect_true(f5$inf$is_nonestimable("estimate"))
})
