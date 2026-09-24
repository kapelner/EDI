library(testthat)
library(EDI)

# get_poisson_glmm_score_cpp / get_poisson_glmm_hessian_cpp (fast_poisson_glmm.cpp, the
# random-intercept Poisson score/Hessian evaluators used by InferenceCountKKGLMM's likelihood-ratio
# machinery) each independently repeat the same two input guards before any computation, matching
# the identical pattern already closed this stretch for the logistic-GLMM sibling kernels
# (get_logistic_glmm_score_cpp / _hessian_cpp / _neg_loglik_cpp):
#   1. `if (par.size() != X.cols() + 1) Rcpp::stop("par must have length ncol(X_r) + 1 (got %d,
#      expected %d)", ...)` -- par must be exactly [beta, log_sigma].
#   2. `if (X.rows() != y.size() || X.rows() != group_id.size()) Rcpp::stop("Dimension mismatch:
#      X_r has %d rows, y_r has %d elements, group_id_r has %d elements", ...)`.
# The existing reference file (test-poisson-glmm-and-probit-family-score-hessian-kernels-reference.R)
# pins both kernels' numeric values against an independent reference, but only ever calls them with
# well-formed, matching-dimension inputs -- neither guard had a test reference anywhere for either
# kernel (confirmed via grep).

K <- function(x) get(x, envir = asNamespace("EDI"))
fx <- function() {
	set.seed(61)
	G <- 12L; m <- 5L; n <- G * m
	g <- rep(seq_len(G), each = m)
	X <- cbind(1, rnorm(n))
	u <- rnorm(G, 0, 0.5)[g]
	y <- as.numeric(rpois(n, exp(0.3 + 0.2 * X[, 2] + u)))
	list(X = X, y = y, g = as.integer(g), params = c(0.3, 0.2, log(0.5)))
}

for (fn in c("get_poisson_glmm_score_cpp", "get_poisson_glmm_hessian_cpp")) {
	local({
		fn <- fn
		f <- K(fn)

		test_that(paste0(fn, ": params of the wrong length (!= ncol(X) + 1) throws the length-mismatch error"), {
			d <- fx()
			expect_error(f(d$X, d$y, d$g, c(0.1, 0.2)), "par must have length ncol\\(X_r\\) \\+ 1")
			expect_error(f(d$X, d$y, d$g, c(0.1, 0.2, 0.3, 0.4)), "par must have length ncol\\(X_r\\) \\+ 1")
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
