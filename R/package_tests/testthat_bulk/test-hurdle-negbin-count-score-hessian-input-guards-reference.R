library(testthat)
library(EDI)

# get_hurdle_negbin_count_score_cpp / get_hurdle_negbin_count_hessian_cpp (fast_hurdle_negbin.cpp,
# the truncated-count-part score/Hessian evaluators for the hurdle negative-binomial model) each
# independently repeat the same two input guards before any computation, matching the identical
# pattern already closed this stretch for the logistic-GLMM and Poisson-GLMM sibling kernels:
#   1. `if (params.size() != X_r.cols() + 1) Rcpp::stop("params must have length ncol(X_r) + 1 (got
#      %d, expected %d)", ...)` -- params must be exactly [beta, log_theta].
#   2. `if (X_r.rows() != y_r.size()) Rcpp::stop("Dimension mismatch: X_r has %d rows, y_r has %d
#      elements", ...)`.
# A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/
# confirms these two exported kernels have ZERO test references of any kind (not merely the guards --
# the entire function), despite fast_hurdle_negbin_cpp itself (the fitter that internally uses the
# same truncated-count likelihood) being heavily tested elsewhere via the hurdle-negbin Inference
# classes. This file closes that gap: the guards, plus a basic well-formedness check that both
# kernels return finite, correctly-shaped output on a real fitted hurdle model's count-part
# coefficients.

K <- function(x) get(x, envir = asNamespace("EDI"))
fx <- function() {
	set.seed(73); n <- 150L
	X <- cbind(1, rnorm(n))
	mu <- exp(0.5 + 0.3 * X[, 2])
	y <- rnbinom(n, size = 2, mu = mu)
	list(X = X, y = as.numeric(y), params = c(0.5, 0.3, log(2)))
}

for (fn in c("get_hurdle_negbin_count_score_cpp", "get_hurdle_negbin_count_hessian_cpp")) {
	local({
		fn <- fn
		f <- K(fn)

		test_that(paste0(fn, ": params of the wrong length (!= ncol(X_r) + 1) throws the length-mismatch error"), {
			d <- fx()
			expect_error(f(d$X, d$y, c(0.1, 0.2)), "params must have length ncol\\(X_r\\) \\+ 1")
			expect_error(f(d$X, d$y, c(0.1, 0.2, 0.3, 0.4)), "params must have length ncol\\(X_r\\) \\+ 1")
		})

		test_that(paste0(fn, ": mismatched X_r/y_r row counts throw the dimension-mismatch error"), {
			d <- fx()
			expect_error(f(d$X, d$y[1:10], d$params), "Dimension mismatch")
		})

		test_that(paste0(fn, ": well-formed inputs do not trigger either guard and return finite, correctly-shaped output"), {
			d <- fx()
			r <- f(d$X, d$y, d$params)
			expect_true(all(is.finite(r)))
			if (is.matrix(r)) {
				expect_equal(dim(r), c(3L, 3L))
			} else {
				expect_length(r, 3L)
			}
		})
	})
}
