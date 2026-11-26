library(testthat)
library(EDI)

# v1.0.5 TODO-31 (bug_fix_plans/v1_0_5/clmm_sigma_collapse_false_convergence.md, tests-to-add item 4;
# G6 #45, 2026-10-22). Reference test for all four KK CLMM links against an independently
# implemented fit: ordinal::clmm(nAGQ = 20) asked for the link name that really fits EDI's model
# (ordinal_clmm_link_name(): clmm's cloglog/loglog names are swapped upstream). EDI uses a fixed
# 20-node non-adaptive Gauss-Hermite rule while clmm's nAGQ = 20 is adaptive, so the tolerances
# absorb that quadrature gap (plan E5; adaptive quadrature is TODO-153). Cauchit is skipped where
# clmm itself errors or stops at a clearly worse likelihood.

skip_if_not_installed("ordinal")

cls <- c(logit = "InferenceOrdinalKKCLMM", probit = "InferenceOrdinalKKCLMMProbit",
	cauchit = "InferenceOrdinalKKCLMMCauchit", cloglog = "InferenceOrdinalKKCLMMCloglog")
Fc <- list(logit = plogis, probit = pnorm, cauchit = pcauchy, cloglog = function(z) -expm1(-exp(z)))
# Treatment tolerances by sigma_b. Measured 2026-10-22 (max |EDI - clmm|): sigma_b = 0.6: logit
# 8e-6, probit 6e-6, cloglog 3.6e-4, cauchit 2.5e-4 (one cauchit cell excluded below); sigma_b = 1.2:
# logit 3.2e-4, probit 1.0e-3, cloglog 1.7e-2 (n = 60, reference sigma 2.0: quadrature gap),
# cauchit 1.7e-2.
# 2026-11-17, after the v1.0.6-TODO-10 KK14 matching fix changed the matches: cloglog n = 60,
# sigma_b = 1.2 seeds 2 and 3 gave |EDI - clmm| = 0.039 and 0.021 at fitted sigma 2.1 to 2.6, and the
# tolerance was loosened to 5e-2.
# v1.0.6-TODO-13 (owner ruling 2026-11-24): that was EDI's error. Under the exact marginal likelihood
# (integrate(), rel.tol 1e-12) clmm's parameters were better in both cells (nll 72.0694 vs EDI 72.1193;
# 61.7877 vs 61.8786): EDI maximized a 20-node non-adaptive Gauss-Hermite approximation. The KK CLMM
# classes now use 60 nodes (KK_CLMM_N_GH) and land on clmm's optimum (0.7752 vs 0.7755; 0.2799 vs
# 0.2797). Measured 2026-11-24 at 60 nodes (max |EDI - clmm| over the cells below): logit 1.0e-5 / 1.5e-5,
# probit 8.9e-6 / 5.7e-6, cloglog 3.3e-6 / 2.6e-4 (sigma_b = 0.6 / 1.2), so 1e-3 for these. Cauchit:
# 6.3e-5 / 4.1e-3; the 4.1e-3 cell (n = 200, sigma_b = 1.2, seed 1) is clmm's error, not EDI's: clmm's
# adaptive 20-node nll there is 263.1695 but its exact nll is 263.3381, worse than EDI's exact 263.3136.
tol_w <- list(`0.6` = c(logit = 1e-3, probit = 1e-3, cloglog = 1e-3, cauchit = 5e-3),
	`1.2` = c(logit = 1e-3, probit = 1e-3, cloglog = 1e-3, cauchit = 5e-3))

gen <- function(seed, link, n, sb) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "ordinal", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w(); m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(c(m, 1)))[pmax(m, 1)], 0) * sb
	eta <- 0.5 * w + 0.4 * X$x + u
	cp <- sapply(c(-1, 0, 1), function(t) Fc[[link]](t - eta)); uu <- runif(n)
	y <- 1L + rowSums(uu > cp)
	des$add_all_subject_responses(y)
	list(des = des, d = data.frame(y = factor(y, ordered = TRUE), w = w, x = X$x,
		g = factor(ifelse(m > 0, paste0("p", m), paste0("s", seq_along(m))))))
}

test_that("KK CLMM classes match ordinal::clmm (correctly named link) on all four links", {
	for (link in names(cls)) for (n in c(60L, 200L)) for (sb in c(0.6, 1.2)) for (s in 1:3) {
		info <- sprintf("%s n=%d sb=%.1f seed=%d", link, n, sb, s)
		f <- gen(1000L * s + n, link, n, sb)
		mm <- tryCatch(suppressWarnings(ordinal::clmm(y ~ w + x + (1 | g), data = f$d,
			link = EDI:::ordinal_clmm_link_name(link), nAGQ = 20)), error = function(e) NULL)
		if (is.null(mm)) {
			if (identical(link, "cauchit")) next
			fail(paste("ordinal::clmm errored:", info))
		}
		inf <- get(cls[[link]])$new(f$des, verbose = FALSE)
		est <- unname(inf$compute_estimate(estimate_only = TRUE))
		fit <- inf$.__enclos_env__$private$cached_mod
		# Cauchit cells are skipped only where clmm itself fails: it errors (above; 4 of 12 cells on this
		# machine, 2026-11-24) or does not reach a stationary point. (An older skip for cells where EDI's
		# nll beat clmm's by > 1e-2 -- cauchit n = 60, sigma_b = 0.6, seed 1, EDI better by 0.18 at
		# 20 nodes -- no longer fires at 60 nodes and was removed for v1.0.6-TODO-13.)
		# Cells where clmm did not reach a stationary point. Cauchit n = 200, sigma_b = 1.2,
		# seed 2 (2026-11-17): nlminb errors on one machine and on another (CI) returns treatment 0.31,
		# sigma 1.46; refitting with ucminf reaches the same point with an Inf gradient, while EDI's
		# fit converges (0.36, sigma 1.72).
		if (identical(link, "cauchit") && !isTRUE(max(abs(mm$gradient)) < 1e-3)) next
		expect_true(isTRUE(fit$converged), info = info)
		expect_lte(fit$gradient_norm, 1e-4)
		expect_equal(est, unname(coef(mm)["w"]), tolerance = tol_w[[format(sb)]][[link]], scale = 1, info = info)
		ref_sigma <- mm$ST[[1L]][1L]
		if (ref_sigma < 0.05) {
			expect_lt(fit$log_sigma, -2, label = paste("both at the variance boundary:", info))
		} else {
			expect_equal(fit$log_sigma, log(ref_sigma), tolerance = 0.1, scale = 1, info = info)
		}
	}
})
