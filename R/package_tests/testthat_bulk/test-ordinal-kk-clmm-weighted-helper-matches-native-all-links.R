library(testthat)
library(EDI)

# v1.0.5 TODO-31 (bug_fix_plans/clmm_sigma_collapse_false_convergence.md TODO-2, E3; G6 #45
# (ii)(a), 2026-10-22). The Bayesian-bootstrap weighted refit (weighted_ordinal_random_intercept_fit
# via compute_weighted_clmm_estimate) and the use_rcpp = FALSE path call ordinal::clmm, whose
# cloglog/loglog names are swapped upstream. Before the fix the cloglog BB refit fitted log-log
# (golden design: 0.2076 vs native 0.0869). With unit weights the refit must reproduce the native
# point estimate on all four links (20-node adaptive vs non-adaptive GH: within 2e-3), and the
# use_rcpp = FALSE cloglog fit must be clmm's correctly named model.

skip_if_not_installed("ordinal")

cls <- c(logit = "InferenceOrdinalKKCLMM", probit = "InferenceOrdinalKKCLMMProbit",
	cauchit = "InferenceOrdinalKKCLMMCauchit", cloglog = "InferenceOrdinalKKCLMMCloglog")

golden_design <- function(n = 60L, seed = 20260819L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		eta <- 0.4 * ((w_i + 1) / 2) + 0.2 * X$x1[i]
		u <- runif(1L)
		cuts <- plogis(c(-0.8, 0.2, 1.2) - eta)
		y <- if (u <= cuts[1L]) 1L else if (u <= cuts[2L]) 2L else if (u <= cuts[3L]) 3L else 4L
		des$add_one_subject_response(i, y)
	}
	des
}

# Same fixture as test-ordinal-kk-clmm-gradient-tolerance-matches-clmm.R (seed 302).
design_302 <- function(seed = 302L, n = 200L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "ordinal", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.9
	y <- as.integer(cut(0.7 * w + 0.4 * X$x + u + rlogis(n), c(-Inf, -1, 0.5, Inf)))
	des$add_all_subject_responses(y)
	des
}

test_that("unit-weight Bayesian-bootstrap CLMM refit equals the native estimate on all four links", {
	designs <- list(golden = list(des = golden_design(), formula = ~ x1 + x2),
		seed302 = list(des = design_302(), formula = NULL))
	for (dn in names(designs)) for (link in names(cls)) {
		info <- paste(dn, link)
		inf <- get(cls[[link]])$new(designs[[dn]]$des, model_formula = designs[[dn]]$formula, verbose = FALSE)
		native <- unname(inf$compute_estimate(estimate_only = TRUE))
		p <- inf$.__enclos_env__$private
		bb <- p$compute_weighted_clmm_estimate(rep(1, p$n), estimate_only = TRUE)$beta_hat_T
		expect_true(is.finite(bb), info = info)
		expect_equal(bb, native, tolerance = 2e-3, scale = 1, info = info)
	}
})

test_that("use_rcpp = FALSE cloglog fits clmm's correctly named model (not log-log)", {
	des <- golden_design()
	infR <- InferenceOrdinalKKCLMMCloglog$new(des, model_formula = ~ x1 + x2, use_rcpp = FALSE, verbose = FALSE)
	est_R <- unname(infR$compute_estimate())
	p <- infR$.__enclos_env__$private
	d <- data.frame(y = factor(p$y, ordered = TRUE), p$clmm_predictors_df(), group_id = factor(p$clmm_group_id()))
	right <- suppressWarnings(ordinal::clmm(y ~ w + x1 + x2 + (1 | group_id), data = d,
		link = EDI:::ordinal_clmm_link_name("cloglog")))
	wrong <- suppressWarnings(ordinal::clmm(y ~ w + x1 + x2 + (1 | group_id), data = d,
		link = setdiff(c("cloglog", "loglog"), EDI:::ordinal_clmm_link_name("cloglog"))))
	expect_equal(est_R, unname(coef(right)["w"]), tolerance = 1e-8, scale = 1)
	expect_gt(abs(est_R - unname(coef(wrong)["w"])), 0.02)         # was the mislabelled 0.1940
	# On the golden design the Laplace fit (clmm's default nAGQ = 1) is itself 0.06 from the
	# 20-node optimum (0.146 vs 0.0869); on the larger seed-302 design it agrees within 1e-2.
	des2 <- design_302()
	nat2 <- unname(InferenceOrdinalKKCLMMCloglog$new(des2, verbose = FALSE)$compute_estimate(estimate_only = TRUE))
	r2 <- unname(InferenceOrdinalKKCLMMCloglog$new(des2, use_rcpp = FALSE, verbose = FALSE)$compute_estimate())
	expect_equal(r2, nat2, tolerance = 1e-2, scale = 1)
})
