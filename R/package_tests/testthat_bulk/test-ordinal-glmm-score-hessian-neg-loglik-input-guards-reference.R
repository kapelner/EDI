library(testthat)
library(EDI)

# get_ordinal_glmm_score_cpp / get_ordinal_glmm_hessian_cpp / get_ordinal_glmm_neg_loglik_cpp
# (fast_ordinal_glmm.cpp, the random-intercept ordinal-GLMM score/Hessian/neg-loglik evaluators used
# by InferenceOrdinalKKGLMM's likelihood machinery) share a single combined evaluation-input guard:
# `if (n <= 0 || y.size() != n || group_id.size() != n || K < 2 || params.size() != total ||
# !params.allFinite() || n_gh <= 0 || !isfinite(max_abs_log_sigma) || max_abs_log_sigma <= 0) throw
# std::invalid_argument("invalid ordinal GLMM evaluation inputs")` -- unlike the sibling
# logistic/Poisson-GLMM kernels already closed this stretch, this guard is one combined check
# (dimension mismatch and wrong-length params both produce the identical message), plus a SEPARATE
# per-row guard: `if (y[i] < 1 || y[i] > K || group_id[i] == INT_MIN) throw std::invalid_argument(
# "ordinal GLMM evaluation y/group_id contains an invalid value")`. A codebase-wide grep across
# testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms the existing reference
# file (test-ordinal-glmm-kernel-clmm-agreement-score-hessian-and-polish-reference.R) pins all three
# kernels' numeric values against clmm()/numDeriv, but only ever calls them with well-formed inputs --
# neither guard had a test reference anywhere for any of the three kernels.

K_ <- function(x) get(x, envir = asNamespace("EDI"))
fx <- function() {
	set.seed(97)
	G <- 12L; m <- 6L; n <- G * m
	g <- rep(seq_len(G), each = m)
	X <- cbind(rnorm(n))
	y <- as.integer(cut(X[, 1] + rnorm(n), c(-Inf, -0.5, 0.5, Inf)))   # K = 3 categories
	list(X = X, y = y, g = as.integer(g), K = 3L, params = c(-0.5, 0.5, 0.3, log(0.4)))   # n_alpha = 2, p = 1, + log_sigma = 4
}

for (fn in c("get_ordinal_glmm_score_cpp", "get_ordinal_glmm_hessian_cpp", "get_ordinal_glmm_neg_loglik_cpp")) {
	local({
		fn <- fn
		f <- K_(fn)

		test_that(paste0(fn, ": params of the wrong length throws the combined evaluation-input error"), {
			d <- fx()
			expect_error(f(d$X, d$y, d$g, c(0.1, 0.2), d$K), "invalid ordinal GLMM evaluation inputs")
			expect_error(f(d$X, d$y, d$g, c(d$params, 0.1), d$K), "invalid ordinal GLMM evaluation inputs")
		})

		test_that(paste0(fn, ": mismatched X/y/group_id row counts throw the same combined error"), {
			d <- fx()
			expect_error(f(d$X, d$y[1:10], d$g, d$params, d$K), "invalid ordinal GLMM evaluation inputs")
			expect_error(f(d$X, d$y, d$g[1:10], d$params, d$K), "invalid ordinal GLMM evaluation inputs")
		})

		test_that(paste0(fn, ": K < 2 throws the same combined error"), {
			d <- fx()
			expect_error(f(d$X, d$y, d$g, d$params, 1L), "invalid ordinal GLMM evaluation inputs")
		})

		test_that(paste0(fn, ": an out-of-range y value throws the separate y/group_id validity error"), {
			d <- fx()
			y_bad <- d$y
			y_bad[1] <- d$K + 2L
			expect_error(f(d$X, y_bad, d$g, d$params, d$K), "ordinal GLMM evaluation y/group_id contains an invalid value")
		})

		test_that(paste0(fn, ": well-formed inputs do not trigger either guard"), {
			d <- fx()
			r <- f(d$X, d$y, d$g, d$params, d$K)
			expect_true(all(is.finite(r)))
		})
	})
}
