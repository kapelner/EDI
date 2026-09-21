library(testthat)
library(EDI)
library(data.table)

# InferenceIncidExactBinomial private helpers: get_exact_binomial_stats() (m, d_plus, d_minus from the matching structure),
# get_exact_binomial_log_or_estimate() (Haldane-Anscombe log((d+ + .5)/(d- + .5))), ci_exact_binomial(alpha) (Clopper-Pearson via
# binom.test on the logit scale, named bounds, NA when no discordant pairs), pval_exact_binomial(delta) and
# design_supports_exact_binomial(). References: discordant pairs counted by hand from (m, w, y); stats::binom.test.

mk <- function(n_treat_wins, n_control_wins, n_concordant = 0L) {
	n_pairs <- n_treat_wins + n_control_wins + n_concordant
	x_dat <- data.table(x1 = seq_len(2L * n_pairs) * ifelse(rep(c(TRUE, FALSE), n_pairs), -1, 1), x2 = rep(0:1, length.out = 2L * n_pairs))
	des <- DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat); des$assign_w_to_all_subjects()
	des$.__enclos_env__$private$ensure_matching_structure_computed()
	m <- as.integer(des$.__enclos_env__$private$m); w <- des$get_w(); y <- integer(length(w))
	ids <- sort(unique(m[m > 0L]))
	for (k in seq_along(ids)) {
		idx <- which(m == ids[k]); tr <- idx[w[idx] == 1L]; ct <- idx[w[idx] == 0L]
		if (k <= n_treat_wins) y[tr] <- 1L
		else if (k <= n_treat_wins + n_control_wins) y[ct] <- 1L
		else { y[tr] <- 1L; y[ct] <- 1L }
	}
	des$add_all_subject_responses(y)
	inf <- InferenceIncidExactBinomial$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, m = m, w = w, y = y, des = des)
}
f <- mk(7L, 2L, 3L)

test_that("stats equal the discordant counts computed by hand from (m, w, y)", {
	s <- f$p$get_exact_binomial_stats()
	ids <- sort(unique(f$m[f$m > 0L]))
	pair_y <- t(vapply(ids, function(k) { i <- which(f$m == k); c(f$y[i[f$w[i] == 1]], f$y[i[f$w[i] == 0]]) }, c(0, 0)))
	expect_identical(s$m, length(ids))
	expect_identical(s$d_plus, sum(pair_y[, 1] == 1 & pair_y[, 2] == 0))
	expect_identical(s$d_minus, sum(pair_y[, 1] == 0 & pair_y[, 2] == 1))
	expect_identical(c(s$d_plus, s$d_minus), c(7L, 2L))
	expect_identical(f$p$cached_values$incidence_exact_binomial_stats, s)                 # cached
})

test_that("log-OR estimate is the Haldane-Anscombe corrected discordant ratio", {
	expect_equal(f$p$get_exact_binomial_log_or_estimate(), log((7 + 0.5) / (2 + 0.5)), tolerance = 1e-12)
	g <- mk(2L, 7L, 0L); expect_equal(g$p$get_exact_binomial_log_or_estimate(), log(2.5 / 7.5), tolerance = 1e-12)
	z <- mk(0L, 0L, 4L); expect_equal(z$p$get_exact_binomial_log_or_estimate(), 0)
})

test_that("CI is the Clopper-Pearson interval for d+/(d+ + d-) mapped through the logit, with percent-named bounds", {
	for (a in c(0.1, 0.05, 0.01)) {
		ci <- f$p$ci_exact_binomial(a)
		expect_equal(unname(ci), qlogis(binom.test(7, 9, conf.level = 1 - a)$conf.int), tolerance = 1e-10)
		expect_identical(names(ci), paste0(c(a / 2, 1 - a / 2) * 100, "%"))
		expect_lt(ci[[1]], ci[[2]])
	}
	expect_gt(diff(f$p$ci_exact_binomial(0.01)), diff(f$p$ci_exact_binomial(0.1)))          # wider at higher confidence
})

test_that("no discordant pairs: CI is NA-named and the estimate path is marked nonestimable rather than erroring", {
	z <- mk(0L, 0L, 4L)
	ci <- z$p$ci_exact_binomial(0.05)
	expect_true(all(is.na(ci))); expect_identical(names(ci), c("2.5%", "97.5%"))
	expect_true(isTRUE(z$inf$is_nonestimable("estimate")))
})

test_that("p-value: exact binomial of d+ vs d- under the null log-OR; 1 when no discordant pairs", {
	for (d0 in c(0, 0.5, -1)) expect_equal(f$p$pval_exact_binomial(d0), binom.test(7, 9, plogis(d0))$p.value, tolerance = 1e-9)
	expect_equal(mk(0L, 0L, 4L)$p$pval_exact_binomial(0), 1)
})

test_that("the design-support predicates agree: matching designs support exact binomial, non-matching designs do not", {
	expect_true(f$p$design_supports_exact_binomial())
	expect_true(is.na(f$p$design_compatibility_reason(f$des)))
	bern <- DesignFixedBernoulli$new(response_type = "incidence", n = 6L, seed = 1L, verbose = FALSE)
	expect_identical(f$p$design_compatibility_reason(bern), "exact_binomial_requires_matching_design")
})
