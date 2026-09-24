library(testthat)
library(EDI)

# inference_mixin_kk_glmm_shared.R's DEFAULT compute_weighted_glmm_bootstrap_estimate() (used by
# InferenceContinKKGLMM/InferenceOrdinalKKGLMM -- distinct from InferenceCountKKGLMM's own Rcpp-fast-
# path override closed last iteration, test-kk-glmm-count-weighted-bootstrap-estimate-reference.R,
# which has no `estimate_only` branching and never reaches this glmmTMB-only implementation at all)
# had no test reference anywhere. Unlike the Count override, this shared default has NO fast Rcpp
# path -- it always cascades through glmm_predictors_df_candidates() + fit_weighted_glmm_on_data() +
# glmmTMB, and its estimate_only = FALSE branch additionally extracts a standard error from
# summary(mod), a code path the Count override doesn't have at all.
#   1. estimate_only = TRUE returns a bare numeric beta matching an independent weighted
#      glmmTMB(y ~ w + X + (1|grp), weights = ...) fit exactly.
#   2. estimate_only = FALSE returns list(beta, se), both matching the same independent glmmTMB fit's
#      fixef()/summary() exactly.
#   3. When every candidate fails .is_usable_glmm_fit(), estimate_only = TRUE returns NA_real_ and
#      estimate_only = FALSE returns list(beta = NA_real_, se = NA_real_).
#   4. When the first candidate is unusable but a later one succeeds, the cascade falls through to
#      it (verified via a call-count probe on .is_usable_glmm_fit()), landing on the same value a
#      direct call with only the usable candidate would give.

kk_glmm_contin_fixture <- function(seed, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKGLMM$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

glmm_weighted_group_id <- function(priv) {
	m_vec <- priv$m
	if (is.null(m_vec)) m_vec <- rep(NA_integer_, priv$n)
	m_vec[is.na(m_vec)] <- 0L
	group_id <- m_vec
	reservoir_idx <- which(group_id == 0L)
	if (length(reservoir_idx) > 0L) group_id[reservoir_idx] <- max(group_id) + seq_along(reservoir_idx)
	group_id
}

test_that("estimate_only = TRUE returns a bare numeric beta matching an independent weighted glmmTMB fit exactly", {
	priv <- kk_glmm_contin_fixture(1L)
	set.seed(2L); row_weights <- runif(priv$n, 0.3, 2)
	res <- priv$compute_weighted_glmm_bootstrap_estimate(row_weights, estimate_only = TRUE)

	pdf0 <- priv$glmm_predictors_df()
	dat <- data.frame(y = as.numeric(priv$y), pdf0, grp = factor(glmm_weighted_group_id(priv)), wt = row_weights)
	ref <- glmmTMB::glmmTMB(y ~ w + x1 + (1 | grp), weights = wt, data = dat)
	expect_equal(res, unname(glmmTMB::fixef(ref)$cond["w"]), tolerance = 1e-6)
})

test_that("estimate_only = FALSE returns list(beta, se), both matching the same independent glmmTMB fit exactly", {
	priv <- kk_glmm_contin_fixture(3L)
	set.seed(4L); row_weights <- runif(priv$n, 0.3, 2)
	res <- priv$compute_weighted_glmm_bootstrap_estimate(row_weights, estimate_only = FALSE)

	pdf0 <- priv$glmm_predictors_df()
	dat <- data.frame(y = as.numeric(priv$y), pdf0, grp = factor(glmm_weighted_group_id(priv)), wt = row_weights)
	ref <- glmmTMB::glmmTMB(y ~ w + x1 + (1 | grp), weights = wt, data = dat)
	ref_ct <- summary(ref)$coefficients$cond
	expect_equal(res$beta, unname(glmmTMB::fixef(ref)$cond["w"]), tolerance = 1e-6)
	expect_equal(res$se, unname(ref_ct["w", "Std. Error"]), tolerance = 1e-6)
})

test_that("when every candidate fails .is_usable_glmm_fit(), the result is NA (bare NA_real_ or list(NA, NA))", {
	priv <- kk_glmm_contin_fixture(5L)
	unlockBinding(".is_usable_glmm_fit", priv)
	priv$.is_usable_glmm_fit <- function(mod, se) FALSE

	res_e <- priv$compute_weighted_glmm_bootstrap_estimate(rep(1, priv$n), estimate_only = TRUE)
	expect_true(is.na(res_e))

	res_f <- priv$compute_weighted_glmm_bootstrap_estimate(rep(1, priv$n), estimate_only = FALSE)
	expect_true(is.na(res_f$beta))
	expect_true(is.na(res_f$se))
})

test_that("when the first candidate is unusable but a later one succeeds, the cascade falls through to it", {
	priv <- kk_glmm_contin_fixture(6L)
	direct_res <- priv$compute_weighted_glmm_bootstrap_estimate(rep(1, priv$n), estimate_only = TRUE)

	pdf0 <- priv$glmm_predictors_df()
	unlockBinding("glmm_predictors_df_candidates", priv)
	priv$glmm_predictors_df_candidates <- function() list(pdf0, pdf0)

	call_count <- 0L
	orig_usable <- priv$.is_usable_glmm_fit
	unlockBinding(".is_usable_glmm_fit", priv)
	priv$.is_usable_glmm_fit <- function(mod, se) {
		call_count <<- call_count + 1L
		if (call_count == 1L) return(FALSE)                                        # force the first candidate to be rejected
		orig_usable(mod, se)
	}
	res <- priv$compute_weighted_glmm_bootstrap_estimate(rep(1, priv$n), estimate_only = TRUE)
	expect_equal(call_count, 2L)
	expect_equal(res, direct_res, tolerance = 1e-10)
})
