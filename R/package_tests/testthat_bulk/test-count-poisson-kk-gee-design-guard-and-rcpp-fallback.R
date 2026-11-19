library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-dc2095879 (InferenceCountPoissonKKGEE, R/EDI/R/inference_count_KK_gee.R):
#   - initialize validates the matched/reservoir (KK matching) design;
#   - use_rcpp = TRUE (default) uses the internal Rcpp solver with automatic fallback to geepack::geeglm on failure.

kk_count_design <- function(seed = 20260423L, n_pairs = 30L, n_single = 10L) {
	set.seed(seed)
	n <- 2L * n_pairs + n_single
	X <- data.frame(x1 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(n_pairs), each = 2L), rep(0L, n_single))
	w <- des$get_w()
	gid <- c(rep(seq_len(n_pairs), each = 2L), n_pairs + seq_len(n_single))
	b <- rnorm(max(gid), sd = 0.4)
	des$add_all_subject_responses(rpois(n, exp(0.3 + 0.3 * w + 0.2 * X$x1 + b[gid])))
	list(des = des, y = des$get_y(), w = w, x1 = X$x1, gid = gid)
}

test_that("a completed non-KK count design is rejected at construction", {
	set.seed(1); n <- 30L
	d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rpois(n, 2))
	expect_error(InferenceCountPoissonKKGEE$new(d), "requires a KK matching")
})

test_that("use_rcpp defaults to TRUE and falls back to geepack::geeglm when the Rcpp solver fails", {
	skip_if_not_installed("geepack")
	f <- kk_count_design()
	inf <- InferenceCountPoissonKKGEE$new(f$des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$use_rcpp)
	rcpp_calls <- 0L
	local_mocked_bindings(
		gee_pairs_singletons_cpp = function(...) { rcpp_calls <<- rcpp_calls + 1L; stop("mocked Rcpp GEE failure") },
		.package = "EDI"
	)
	est <- inf$compute_estimate()
	expect_gt(rcpp_calls, 0L)
	ord <- order(f$gid)
	dat <- data.frame(y = f$y, w = f$w, x1 = f$x1)[ord, ]
	ref <- geepack::geeglm(y ~ w + x1, family = poisson("log"), data = dat, id = f$gid[ord],
		corstr = "exchangeable", std.err = "san.se")
	expect_equal(est, unname(coef(ref)["w"]), tolerance = 1e-6)
	expect_equal(inf$.__enclos_env__$private$cached_values$s_beta_hat_T,
		unname(summary(ref)$coefficients["w", "Std.err"]), tolerance = 1e-6)
})
