library(testthat)
library(EDI)

# InferenceAbstractKKCondLogitGLMM$compute_estimate_with_bootstrap_weights()
# (inference_incidence_KK_cond_logit_glmm_abstract.R) fits a weighted glmmTMB() model and rejects
# the result as nonestimable (NA, both beta_hat_T and s_beta_hat_T) when the fitted treatment
# coefficient is non-finite OR exceeds min(max_abs_reasonable_coef, bootstrap_extreme_estimate_
# threshold) in absolute value. The existing reference test
# (test-prop-kk-glmm-weighted-refit-reference.R) only ever exercises a well-behaved fit; this
# extreme-coefficient rejection branch had no test reference anywhere.
#
# Near-perfectly-separated matched-pair responses (control near 0, treated near 1) drive glmmTMB's
# fitted treatment coefficient past the (default) threshold of 8, independently confirmed below by
# replicating the exact same weighted glmmTMB fit this method performs internally.

test_that("a weighted refit whose fitted treatment coefficient exceeds the extreme-estimate threshold is nonestimable", {
	skip_if_not_installed("glmmTMB")
	set.seed(20260918); n <- 80L
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		p <- if (w_i == 1) 0.999 else 0.001  # near-perfect separation by treatment
		des$add_one_subject_response(i, p)
	}
	inf <- EDI:::InferencePropKKGLMM$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	n_blocks <- length(unique(priv$m[priv$m != 0])) + sum(priv$m == 0)

	set.seed(1); block_w <- runif(n_blocks, 0.3, 3)

	# independent reference: replicate the internal weighted glmmTMB fit directly and confirm its
	# fitted coefficient really does exceed the threshold this call should reject against
	m_vec <- priv$m; m_vec[is.na(m_vec)] <- 0L
	group_id <- m_vec
	res_idx <- which(group_id == 0L)
	if (length(res_idx) > 0L) group_id[res_idx] <- max(group_id) + seq_along(res_idx)
	X_fit <- as.data.frame(priv$create_design_matrix()[, -1, drop = FALSE])
	colnames(X_fit)[colnames(X_fit) == "treatment"] <- "w"
	row_weights <- priv$expand_subject_or_block_weights_to_row_weights(block_w)
	ok <- is.finite(row_weights) & row_weights > 0 & is.finite(as.numeric(priv$y))
	dat <- data.frame(y = as.numeric(priv$y[ok]), X_fit[ok, , drop = FALSE], group_id = factor(group_id[ok]), wt = row_weights[ok])
	mod_ref <- suppressWarnings(glmmTMB::glmmTMB(y ~ w + x1 + x2 + (1 | group_id),
		family = stats::binomial(link = "logit"), data = dat, weights = wt, se = FALSE))
	beta_ref <- unname(glmmTMB::fixef(mod_ref)$cond[["w"]])
	threshold <- min(priv$max_abs_reasonable_coef, priv$bootstrap_extreme_estimate_threshold)
	expect_gt(abs(beta_ref), threshold)  # confirms this fixture actually exercises the extreme-coefficient branch

	res <- suppressWarnings(inf$compute_estimate_with_bootstrap_weights(block_w, estimate_only = TRUE))
	expect_true(is.na(res))
	expect_true(is.na(priv$last_weighted_refit$beta_hat_T))
	expect_true(is.na(priv$last_weighted_refit$s_beta_hat_T))
})
