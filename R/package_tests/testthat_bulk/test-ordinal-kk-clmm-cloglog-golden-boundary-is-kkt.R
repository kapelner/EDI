library(testthat)
library(EDI)

# v1.0.5 TODO-31 root-cause pin (bug_fix_plans/clmm_sigma_collapse_false_convergence.md E1/E4,
# G6 #45 (i), 2026-10-22). On the migration-golden design, InferenceOrdinalKKCLMMCloglog's fit
# sits at the lower variance boundary (sigma -> 0). That is the correct cloglog MLE, not a
# collapse: the fit equals ordinal::clm(link = "cloglog") and the likelihood rises as sigma^2
# leaves 0 (positive one-sided tau-score, observed 0.91), i.e. the boundary is a KKT point. The
# "better" ordinal::clmm(link = "cloglog") fit (0.2076) is the log-log model.

skip_if_not_installed("ordinal")

golden_design <- function(n = 60L, seed = 20260819L) {
	old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old)) assign(".Random.seed", old, envir = globalenv()))
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

test_that("golden cloglog KK CLMM fit is the boundary MLE (equals clm) with a positive tau-score", {
	des <- golden_design()
	inf <- InferenceOrdinalKKCLMMCloglog$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	est <- unname(inf$compute_estimate(estimate_only = TRUE))
	p <- inf$.__enclos_env__$private
	fit <- p$cached_mod
	expect_lte(fit$log_sigma, -4.5)
	expect_true(isTRUE(p$cached_values$clmm_variance_boundary))
	expect_lte(fit$gradient_norm, 1e-4)
	pdf <- p$clmm_predictors_df()
	d <- data.frame(y = factor(p$y, ordered = TRUE), pdf)
	clm_w <- unname(coef(ordinal::clm(y ~ w + x1 + x2, data = d, link = "cloglog"))["w"])
	expect_equal(est, clm_w, tolerance = 1e-4, scale = 1)
	# Fixed-log-sigma Newton profile: nll at sigma = 0.1 vs at the boundary, per unit tau = sigma^2.
	X <- p$clmm_X_for_rcpp(); gid <- as.integer(p$clmm_group_id())
	yl <- sort(unique(p$y)); y <- as.integer(match(p$y, yl)); K <- length(yl)
	par <- c(fit$alpha, fit$b, fit$log_sigma)
	prof <- function(ls) EDI:::fast_ordinal_clmm_cpp(X = X, y = y, group_id = gid, K = K, j_T = 0L,
		link = "cloglog", estimate_only = TRUE, warm_start_params = replace(par, length(par), ls),
		optimization_alg = "newton_raphson", eps_g = 1e-10,
		fixed_idx = length(par), fixed_values = ls)$neg_loglik
	tau_score <- (prof(log(0.1)) - prof(-5)) / 0.01
	expect_gt(tau_score, 0.5)
	# clmm under the probed (correct) name lands on the same boundary fit.
	mm <- suppressWarnings(ordinal::clmm(y ~ w + x1 + x2 + (1 | g), data = cbind(d, g = factor(gid)),
		link = EDI:::ordinal_clmm_link_name("cloglog"), nAGQ = 20))
	expect_equal(est, unname(coef(mm)["w"]), tolerance = 1e-3, scale = 1)
	expect_lt(mm$ST[[1L]][1L], 0.05)
})
