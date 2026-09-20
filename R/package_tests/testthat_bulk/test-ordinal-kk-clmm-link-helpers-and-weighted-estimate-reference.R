library(testthat)
library(EDI)

# InferenceAbstractKKOrdinalCLMM's private helpers (clmm_link, clmm_X_for_rcpp,
# clmm_group_id, clmm_warm_start, compute_weighted_clmm_estimate) across all
# four link-function leaf classes. They were referenced only inside the legacy
# migration fixtures; the migration-golden files compare outputs, never these
# helpers against independent references. References are built from
# MASS::polr (thresholds/coefficients per link) and stats formulas.

clmm_fixture <- function(seed = 11L, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- as.integer(cut(0.5 * w + 0.4 * X$x1 + rlogis(n), c(-Inf, -0.7, 0.7, Inf), labels = FALSE))
	des$add_all_subject_responses(y)
	des
}

clmm_leaves <- list(
	InferenceOrdinalKKCLMM = c(link = "logit", method = "logistic", tol = 1e-3),
	InferenceOrdinalKKCLMMProbit = c(link = "probit", method = "probit", tol = 1e-3),
	InferenceOrdinalKKCLMMCauchit = c(link = "cauchit", method = "cauchit", tol = 2e-2),
	InferenceOrdinalKKCLMMCloglog = c(link = "cloglog", method = "cloglog", tol = 1e-3)
)

make_leaf <- function(cls, des) {
	inf <- get(cls)$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("each leaf reports its own link, treatment-first predictors, and matching-aware group ids", {
	des <- clmm_fixture()
	for (cls in names(clmm_leaves)) {
		priv <- make_leaf(cls, des)
		expect_equal(priv$clmm_link(), clmm_leaves[[cls]][["link"]], info = cls)
		Xf <- priv$clmm_X_for_rcpp()
		expect_equal(colnames(Xf), c("w", "x1"), info = cls)
		expect_equal(unname(Xf[, "w"]), as.numeric(des$get_w()), info = cls)
	}
	priv <- make_leaf("InferenceOrdinalKKCLMM", des)
	m <- priv$m
	m[is.na(m)] <- 0L
	ref <- as.integer(m)
	zero <- which(ref == 0L)
	ref[zero] <- max(ref) + seq_along(zero)
	expect_equal(as.integer(priv$clmm_group_id()), ref)
	expect_false(anyDuplicated(priv$clmm_group_id()[zero]) > 0)
})

test_that("clmm_warm_start maps the fixed-effects ordinal MLE for every link", {
	des <- clmm_fixture()
	for (cls in names(clmm_leaves)) {
		priv <- make_leaf(cls, des)
		Xf <- priv$clmm_X_for_rcpp()
		y <- as.integer(match(priv$y, sort(unique(priv$y))))
		ws <- priv$clmm_warm_start(Xf, y, 2L)
		m <- suppressWarnings(MASS::polr(factor(y) ~ Xf, method = clmm_leaves[[cls]][["method"]]))
		z <- unname(m$zeta)
		beta_ref <- unname(coef(m))                      # every link (cloglog included) uses the polr/clm sign
		ref <- c(z[1], log(z[2] - z[1]), beta_ref, -3)
		expect_length(ws, 5L)
		expect_equal(ws, ref, tolerance = as.numeric(clmm_leaves[[cls]][["tol"]]), info = cls)
		expect_equal(ws[5], -3)
	}
})

test_that("weighted estimate: logit uses the fast solver (with SE); other links use the surrogate (no SE); both track weighted polr", {
	des <- clmm_fixture()
	n <- des$get_n()
	set.seed(12)
	wts <- runif(n, 0.3, 2)
	for (cls in c("InferenceOrdinalKKCLMM", "InferenceOrdinalKKCLMMProbit")) {
		priv <- make_leaf(cls, des)
		res <- suppressWarnings(priv$compute_weighted_clmm_estimate(wts))
		Xf <- priv$clmm_X_for_rcpp()
		method <- clmm_leaves[[cls]][["method"]]
		ref <- unname(coef(suppressWarnings(MASS::polr(factor(priv$y) ~ Xf, weights = wts, method = method)))[1])
		expect_equal(res$beta_hat_T, ref, tolerance = 2e-3, info = cls)
		if (identical(method, "logistic")) {
			expect_true(is.finite(res$ssq_b_j) && res$ssq_b_j > 0)
		} else {
			expect_true(is.na(res$ssq_b_j))
		}
	}
})

test_that("weighted estimate with all-zero weights is unavailable for the surrogate links", {
	des <- clmm_fixture()
	priv <- make_leaf("InferenceOrdinalKKCLMMProbit", des)
	res <- suppressWarnings(priv$compute_weighted_clmm_estimate(rep(0, des$get_n())))
	expect_true(is.na(res$beta_hat_T))
	expect_true(is.na(res$ssq_b_j))
})

test_that("cloglog leaf's fitted estimate uses the polr/clm sign convention (warm start now agrees)", {
	des <- clmm_fixture()
	inf <- InferenceOrdinalKKCLMMCloglog$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	ref <- unname(coef(suppressWarnings(MASS::polr(factor(priv$y) ~ priv$clmm_X_for_rcpp(), method = "cloglog")))[1])
	expect_equal(inf$compute_estimate(), ref, tolerance = 0.1)
	expect_gt(inf$compute_estimate() * ref, 0)
})
