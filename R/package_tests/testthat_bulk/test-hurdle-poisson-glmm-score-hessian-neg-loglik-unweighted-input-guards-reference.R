library(testthat)
library(EDI)

# get_hurdle_poisson_glmm_score_cpp / get_hurdle_poisson_glmm_hessian_cpp /
# get_hurdle_poisson_glmm_neg_loglik_cpp (fast_hurdle_poisson_glmm.cpp, the UNWEIGHTED
# random-intercept positive-count-part evaluators for the hurdle-Poisson GLMM) each independently
# repeat the same two input guards before any computation:
#   1. `if (params.size() != X_r.cols() + 1) Rcpp::stop("params must have length ncol(X_r) + 1 (got
#      %d, expected %d)", ...)` -- params must be exactly [beta, log_sigma].
#   2. `if (X_r.rows() != y_r.size() || X_r.rows() != group_id_r.size()) Rcpp::stop("Dimension
#      mismatch: X_r has %d rows, y_r has %d elements, group_id_r has %d elements", ...)`.
# A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/
# confirms these three UNWEIGHTED kernels have ZERO test references of any kind. Their WEIGHTED
# siblings (get_hurdle_poisson_glmm_weighted_score_cpp/_hessian_cpp/_neg_loglik_cpp) are partially
# covered by test-hurdle-poisson-glmm-weighted-reference.R (which tests the weighted score/hessian
# dimension guard, but not their params-length guard, nor either guard on weighted_neg_loglik) --
# left for a future iteration; this file closes the larger, completely-untested unweighted trio.

K <- function(x) get(x, envir = asNamespace("EDI"))
fx <- function() {
	set.seed(83)
	G <- 12L; m <- 5L; n <- G * m
	g <- rep(seq_len(G), each = m)
	X <- cbind(1, rnorm(n))
	u <- rnorm(G, 0, 0.3)[g]
	y <- as.numeric(rpois(n, exp(0.5 + 0.2 * X[, 2] + u)))
	list(X = X, y = y, g = as.integer(g), params = c(0.5, 0.2, log(0.3)))
}

for (fn in c("get_hurdle_poisson_glmm_score_cpp", "get_hurdle_poisson_glmm_hessian_cpp", "get_hurdle_poisson_glmm_neg_loglik_cpp")) {
	local({
		fn <- fn
		f <- K(fn)

		test_that(paste0(fn, ": params of the wrong length (!= ncol(X_r) + 1) throws the length-mismatch error"), {
			d <- fx()
			expect_error(f(d$X, d$y, d$g, c(0.1, 0.2)), "params must have length ncol\\(X_r\\) \\+ 1")
			expect_error(f(d$X, d$y, d$g, c(0.1, 0.2, 0.3, 0.4)), "params must have length ncol\\(X_r\\) \\+ 1")
		})

		test_that(paste0(fn, ": mismatched X_r/y_r/group_id_r row counts throw the dimension-mismatch error"), {
			d <- fx()
			expect_error(f(d$X, d$y[1:10], d$g, d$params), "Dimension mismatch")
			expect_error(f(d$X, d$y, d$g[1:10], d$params), "Dimension mismatch")
		})

		test_that(paste0(fn, ": well-formed inputs do not trigger either guard"), {
			d <- fx()
			r <- f(d$X, d$y, d$g, d$params)
			expect_true(all(is.finite(r)))
		})
	})
}
