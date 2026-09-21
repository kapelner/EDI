library(testthat)
library(EDI)

# InferenceContinLin private helpers: get_centered_covariates() (column-centred X, cached on the design's private env,
# list() sentinel for zero covariates) and build_lin_design_matrix() ([1, w, Xc, w * Xc] with named columns).
# References: base scale(center = TRUE), hand-built interaction columns, and stats::lm(y ~ w * Xc) (Lin's estimator).

mk <- function(X, seed = 1L) {
	n <- if (is.null(X)) 40L else nrow(X)
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(if (is.null(X)) data.frame(row.names = seq_len(n)) else X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	set.seed(seed + 10L); y <- rnorm(n) + 2 * w + (if (is.null(X)) 0 else X[[1]])
	des$add_all_subject_responses(y)
	inf <- InferenceContinLin$new(des, verbose = FALSE)
	list(des = des, inf = inf, p = inf$.__enclos_env__$private, w = w, y = y, X = X)
}
set.seed(1); n <- 40L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))

test_that("centered covariates equal scale(X, scale = FALSE), keep names, and have zero column means", {
	f <- mk(X)
	xc <- f$p$get_centered_covariates()
	expect_named(xc, "Xc")
	expect_equal(unname(xc$Xc), unname(as.matrix(scale(as.matrix(X), center = TRUE, scale = FALSE))), tolerance = 1e-12)
	expect_identical(colnames(xc$Xc), c("x1", "x2"))
	expect_lt(max(abs(colMeans(xc$Xc))), 1e-12)
})

test_that("the result is cached on the design's private env and reused on later calls", {
	f <- mk(X)
	expect_null(f$p$des_obj_priv_int$lin_centered_covariates)
	a <- f$p$get_centered_covariates()
	expect_identical(f$p$des_obj_priv_int$lin_centered_covariates, a)
	f$p$des_obj_priv_int$lin_centered_covariates <- list(Xc = matrix(1, n, 1, dimnames = list(NULL, "sentinel")))
	expect_identical(colnames(f$p$get_centered_covariates()$Xc), "sentinel")        # cache wins over recomputation
	expect_identical(colnames(f$p$build_lin_design_matrix()), c("(Intercept)", "treatment", "sentinel", "treatment:sentinel"))
})

test_that("with no covariates the helper returns NULL and caches an empty-list sentinel", {
	f <- mk(NULL)
	expect_null(f$p$get_centered_covariates())
	expect_identical(f$p$des_obj_priv_int$lin_centered_covariates, list())
	expect_null(f$p$get_centered_covariates())                                          # sentinel round-trips to NULL
})

test_that("design matrix is [1, w, Xc, w * Xc] with the documented column names", {
	f <- mk(X)
	M <- f$p$build_lin_design_matrix()
	xc <- scale(as.matrix(X), scale = FALSE)
	expect_identical(colnames(M), c("(Intercept)", "treatment", "x1", "x2", "treatment:x1", "treatment:x2"))
	expect_identical(dim(M), c(n, 6L))
	expect_equal(unname(M[, 1]), rep(1, n)); expect_equal(unname(M[, 2]), as.numeric(f$w))
	expect_equal(unname(M[, 3:4]), unname(xc[, 1:2]))
	expect_equal(unname(M[, 5]), unname(xc[, 1] * f$w)); expect_equal(unname(M[, 6]), unname(xc[, 2] * f$w))
})

test_that("with no covariates the design matrix is just intercept and treatment", {
	f <- mk(NULL); M <- f$p$build_lin_design_matrix()
	expect_identical(colnames(M), c("(Intercept)", "treatment"))
	expect_equal(unname(M[, 2]), as.numeric(f$w))
})

test_that("Lin's estimate from the class equals the treatment coefficient of lm(y ~ w * centred X)", {
	f <- mk(X, seed = 2L)
	xc <- scale(as.matrix(X), scale = FALSE)
	expect_equal(f$inf$compute_estimate(), coef(lm(f$y ~ f$w * xc))[["f$w"]], tolerance = 1e-8)
	g <- mk(NULL, seed = 3L)
	expect_equal(g$inf$compute_estimate(), mean(g$y[g$w == 1]) - mean(g$y[g$w == 0]), tolerance = 1e-10)
})
