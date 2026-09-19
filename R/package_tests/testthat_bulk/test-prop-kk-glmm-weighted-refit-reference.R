library(testthat)
library(EDI)

# InferenceAbstractKKCondLogitGLMM$compute_estimate_with_bootstrap_weights()
# (inference_incidence_KK_cond_logit_glmm_abstract.R) is shared by three
# concrete leaves -- InferencePropKKGLMM, InferenceIncidKKCondLogitGLMMIVWC,
# InferenceIncidKKCondLogitGLMMOneLik -- and was previously only exercised by
# migration-golden tests (legacy-vs-migrated equivalence, not an independent
# reference) or name-existence checks on a sibling class. Exercised here via
# InferencePropKKGLMM against an independently-assembled weighted
# glmmTMB::glmmTMB() fit with the same random-intercept-per-block formula.

make_prop_kk_glmm_fixture <- function(n = 80L, seed = 20260918L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, plogis(0.3 * ((w_i + 1) / 2) + 0.2 * X$x1[i] + rnorm(1L, sd = 0.3)))
	}
	inf <- EDI:::InferencePropKKGLMM$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	n_blocks <- length(unique(priv$m[priv$m != 0])) + sum(priv$m == 0)
	list(inf = inf, priv = priv, n_blocks = n_blocks)
}

independent_weighted_glmm_ref <- function(priv, row_weights) {
	skip_if_not_installed("glmmTMB")
	m <- priv$m
	y <- as.numeric(priv$y)
	group_id <- m
	group_id[is.na(group_id)] <- 0L
	res_idx <- which(group_id == 0L)
	group_id[res_idx] <- max(group_id) + seq_along(res_idx)
	Xmat <- priv$create_design_matrix()
	Xdf <- as.data.frame(Xmat[, -1, drop = FALSE])
	colnames(Xdf)[colnames(Xdf) == "treatment"] <- "w"
	ok <- is.finite(row_weights) & row_weights > 0 & is.finite(y)
	dat <- data.frame(y = y[ok], Xdf[ok, , drop = FALSE], group_id = factor(group_id[ok]), wt = row_weights[ok])
	mod <- suppressWarnings(glmmTMB::glmmTMB(y ~ w + x1 + x2 + (1 | group_id),
		family = stats::binomial(link = "logit"), data = dat, weights = wt, se = FALSE))
	unname(glmmTMB::fixef(mod)$cond[["w"]])
}

test_that("InferencePropKKGLMM weighted-bootstrap refit matches an independent weighted glmmTMB fit", {
	skip_if_not_installed("glmmTMB")
	fx <- make_prop_kk_glmm_fixture()

	set.seed(1)
	block_w <- runif(fx$n_blocks, 0.3, 3)
	row_w <- fx$priv$expand_subject_or_block_weights_to_row_weights(block_w)

	actual <- suppressWarnings(fx$inf$compute_estimate_with_bootstrap_weights(block_w, estimate_only = TRUE))
	expected <- independent_weighted_glmm_ref(fx$priv, row_w)
	expect_equal(actual, expected, tolerance = 1e-6)

	# estimate_only = FALSE reports the same point estimate but never a real SE.
	full <- suppressWarnings(fx$inf$compute_estimate_with_bootstrap_weights(block_w, estimate_only = FALSE))
	expect_equal(full, actual, tolerance = 1e-8)
	expect_true(is.na(fx$priv$cached_values$s_beta_hat_T))
})

test_that("unit block weights reproduce compute_estimate() via the effectively-constant shortcut", {
	fx <- make_prop_kk_glmm_fixture()
	unit_est <- fx$inf$compute_estimate_with_bootstrap_weights(rep(1, fx$n_blocks), estimate_only = TRUE)
	plain_est <- fx$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(unit_est, plain_est, tolerance = 1e-10)
})

test_that("genuinely varying block weights diverge from the unit-weight estimate", {
	fx <- make_prop_kk_glmm_fixture()
	unit_est <- fx$inf$compute_estimate_with_bootstrap_weights(rep(1, fx$n_blocks), estimate_only = TRUE)
	set.seed(1)
	w <- runif(fx$n_blocks, 0.3, 3)
	w_est <- suppressWarnings(fx$inf$compute_estimate_with_bootstrap_weights(w, estimate_only = TRUE))
	expect_true(abs(w_est - unit_est) > 1e-4)
})
