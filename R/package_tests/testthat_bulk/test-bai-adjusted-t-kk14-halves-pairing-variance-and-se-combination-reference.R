library(testthat)
library(EDI)
skip_if_not_installed("nbpMatching")

# InferenceBaiAdjustedTKK14 private helpers: compute_halves() (optimal non-bipartite pairing of the matched pairs:
# every pair used at most once, cached, empty for < 2 pairs), compute_bai_variance_for_pairs() (tau^2 - (lambda^2 +
# delta^2)/2 floored at 1e-8) and shared()'s standard-error combination (reservoir / matched / convex / fallbacks).
# References: the same formulas evaluated in R from the cached match statistics.

mk <- function(seed = 108L, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		x <- data.frame(x1 = rnorm(1), x2 = rnorm(1))
		w <- des$add_one_subject_to_experiment_and_assign(x)
		des$add_one_subject_response(i, 0.4 * w + 0.2 * x$x1 + rnorm(1))
	}
	inf <- InferenceBaiAdjustedTKK14$new(des, verbose = FALSE)
	inf$compute_estimate()
	list(inf = inf, p = inf$.__enclos_env__$private)
}
f <- mk()
KK <- f$p$cached_values$KKstats
d <- KK$y_matched_diffs

test_that("halves pair up the matched pairs: ids are within 1..m, no pair is used twice, ghost rows removed", {
	h <- f$p$compute_halves()
	expect_gte(KK$m, 2L)
	ids <- c(as.integer(h[, 1]), as.integer(h[, 3]))
	expect_true(all(ids >= 1L & ids <= KK$m))
	expect_false(anyDuplicated(ids) > 0)
	expect_lte(nrow(h), KK$m %/% 2L)
	expect_false(any(h[, 3] == "ghost")); expect_false(any(h[, 1] == "ghost"))
	# the pairing uses only the pair ids it was given, and is cached
	expect_identical(f$p$cached_values$halves, h)
	expect_identical(f$p$compute_halves(), h)
})

test_that("halves are a minimum-distance pairing: total distance <= that of random pairings of the same pairs", {
	h <- f$p$compute_halves()
	X <- f$p$get_X(); pa <- get("compute_pair_averages_cpp", asNamespace("EDI"))(X, f$p$des_obj_priv_int$m, KK$m)
	dist <- as.matrix(dist(pa))
	total <- function(a, b) sum(dist[cbind(a, b)])
	best <- total(as.integer(h[, 1]), as.integer(h[, 3]))
	set.seed(3)
	rnd <- replicate(200, { s <- sample(KK$m); k <- (length(s) %/% 2) * 2; total(s[seq(1, k, 2)], s[seq(2, k, 2)]) })
	expect_lte(best, min(rnd[is.finite(rnd)]) * (1 + 1e-6) + 1e-9)
})

test_that("Bai pair-variance equals max(mean(d^2) - (lambda^2 + mean(d)^2)/2, 1e-8) with lambda from the halves", {
	h <- f$p$compute_halves(); hi <- matrix(as.integer(as.matrix(h[, c(1, 3)])), ncol = 2)
	lambda <- mean(d[hi[, 1]] * d[hi[, 2]])
	expect_equal(f$p$compute_bai_variance_for_pairs(), max(mean(d^2) - (lambda + mean(d)^2) / 2, 1e-8), tolerance = 1e-12)
})

test_that("SE (non-convex): sqrt(bai_var_d_bar) with bai_var_d_bar = variance / m", {
	f$p$cached_values$s_beta_hat_T <- NULL
	f$p$shared(estimate_only = FALSE)
	expect_equal(f$p$cached_values$bai_var_d_bar, f$p$compute_bai_variance_for_pairs() / KK$m, tolerance = 1e-12)
	expect_equal(f$p$cached_values$s_beta_hat_T, sqrt(f$p$cached_values$bai_var_d_bar), tolerance = 1e-12)
})

test_that("SE (convex): sqrt(ssqR * ssqD / (ssqR + ssqD)) when both variances are usable", {
	g <- mk(); g$p$convex_flag <- TRUE
	g$p$cached_values$s_beta_hat_T <- NULL; g$p$shared(estimate_only = FALSE)
	ssqD <- g$p$cached_values$bai_var_d_bar; ssqR <- g$p$cached_values$KKstats$ssqR
	expect_true(is.finite(ssqR) && ssqR > 0 && ssqD > 0)
	expect_equal(g$p$cached_values$s_beta_hat_T, sqrt(ssqR * ssqD / (ssqR + ssqD)), tolerance = 1e-12)
	expect_lt(g$p$cached_values$s_beta_hat_T, min(sqrt(ssqR), sqrt(ssqD)) + 1e-12)      # harmonic-type combination is below both
})

test_that("SE falls back to the reservoir SE when the matched variance is unusable, and to the matched SE when the reservoir is", {
	g <- mk()
	g$p$cached_values$KKstats$m <- 1L                      # no_matches branch
	g$p$cached_values$s_beta_hat_T <- NULL; g$p$shared(estimate_only = FALSE)
	expect_equal(g$p$cached_values$s_beta_hat_T, sqrt(g$p$cached_values$KKstats$ssqR), tolerance = 1e-12)
	g2 <- mk()
	g2$p$cached_values$KKstats$nRT <- 1L                   # reservoir_unusable branch: matched SE preferred
	g2$p$cached_values$s_beta_hat_T <- NULL; g2$p$shared(estimate_only = FALSE)
	expect_equal(g2$p$cached_values$s_beta_hat_T, sqrt(g2$p$cached_values$bai_var_d_bar), tolerance = 1e-12)
	g3 <- mk()
	g3$p$cached_values$KKstats$nRT <- 1L; g3$p$cached_values$KKstats$m <- 0L; g3$p$cached_values$KKstats$ssqR <- NA_real_
	g3$p$cached_values$s_beta_hat_T <- NULL; g3$p$shared(estimate_only = FALSE)
	expect_true(is.na(g3$p$cached_values$s_beta_hat_T))
})

test_that("fewer than two pairs give an empty halves frame", {
	g <- mk(); g$p$cached_values$halves <- NULL; g$p$cached_values$KKstats$m <- 1L
	h <- g$p$compute_halves(); expect_s3_class(h, "data.frame"); expect_identical(nrow(h), 0L)
})

test_that("the asymptotic p-value is 2 * pnorm(-|estimate / SE|)", {
	g <- mk()
	expect_equal(g$inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(g$inf$compute_estimate() / g$p$cached_values$s_beta_hat_T)), tolerance = 1e-12)
})
