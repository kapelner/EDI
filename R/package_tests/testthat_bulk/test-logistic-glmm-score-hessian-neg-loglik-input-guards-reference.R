library(testthat)
library(EDI)

# get_logistic_glmm_score_cpp / get_logistic_glmm_hessian_cpp / get_logistic_glmm_neg_loglik_cpp
# (fast_logistic_glmm.cpp, the random-intercept logistic score/Hessian/neg-loglik evaluators used by
# InferenceIncidKKGLMM's likelihood-ratio machinery) each independently repeat the same two input
# guards before any computation:
#   1. `if (params.size() != X.cols() + 1) Rcpp::stop("params must have length ncol(X) + 1 (got %d,
#      expected %d)", ...)` -- params must be exactly [beta, log_sigma].
#   2. `if (X.rows() != y.size() || X.rows() != group_id.size()) Rcpp::stop("Dimension mismatch: X
#      has %d rows, y has %d elements, group_id has %d elements", ...)`.
# The existing reference file (test-logistic-glmm-neg-loglik-score-hessian-kernels-reference.R) pins
# all three kernels' numeric values against an independent integrate()/numDeriv reference, but only
# ever calls them with well-formed, matching-dimension inputs -- neither guard had a test reference
# anywhere for any of the three kernels (confirmed via grep).

K <- function(x) get(x, envir = asNamespace("EDI"))
fx <- function() {
	set.seed(53)
	G <- 12L; m <- 5L; n <- G * m
	g <- rep(seq_len(G), each = m)
	X <- cbind(1, rnorm(n))
	u <- rnorm(G, 0, 0.8)[g]
	y <- as.numeric(rbinom(n, 1, plogis(X %*% c(-0.2, 0.7) + u)))
	list(X = X, y = y, g = as.integer(g), params = c(-0.2, 0.7, log(0.8)))
}

for (fn in c("get_logistic_glmm_score_cpp", "get_logistic_glmm_hessian_cpp", "get_logistic_glmm_neg_loglik_cpp")) {
	local({
		fn <- fn
		f <- K(fn)

		test_that(paste0(fn, ": params of the wrong length (!= ncol(X) + 1) throws the length-mismatch error"), {
			d <- fx()
			expect_error(f(d$X, d$y, d$g, c(0.1, 0.2)), "params must have length ncol\\(X\\) \\+ 1")
			expect_error(f(d$X, d$y, d$g, c(0.1, 0.2, 0.3, 0.4)), "params must have length ncol\\(X\\) \\+ 1")
		})

		test_that(paste0(fn, ": mismatched X/y/group_id row counts throw the dimension-mismatch error"), {
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
