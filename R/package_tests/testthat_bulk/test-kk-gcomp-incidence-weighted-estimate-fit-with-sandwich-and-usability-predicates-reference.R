library(testthat)
library(EDI)

# InferenceIncidKKGCompRiskDiff / RiskRatio private helpers on a KK14 matched incidence design:
# compute_weighted_gcomp_estimate(row_weights) (weighted logistic fit + weighted g-computation; NA on unusable weights),
# fit_logistic_with_sandwich(X, estimate_only) (coefficients equal glm, pair-clustered HC0 vcov; NULL when the fit is impossible),
# effects_are_usable(effects, estimate_only) and coefficients_are_usable(coef). References: stats::glm (weights via
# quasibinomial to avoid non-integer warnings), sandwich::vcovCL / vcovHC, weighted.mean.

set.seed(9); n <- 80L
des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
for (i in seq_len(n)) {
	x <- data.frame(x1 = rnorm(1), x2 = runif(1)); w <- des$add_one_subject_to_experiment_and_assign(x)
	des$add_one_subject_response(i, rbinom(1, 1, plogis(-0.2 + 0.8 * w + 0.4 * x$x1)))
}
mk <- function(cls) { inf <- cls$new(des, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }
rd <- mk(InferenceIncidKKGCompRiskDiff); rr <- mk(InferenceIncidKKGCompRiskRatio)
Xd <- rd$p$build_design_matrix(); yv <- as.numeric(rd$p$y)

test_that("design matrix is [1, treatment, covariates]", {
	expect_identical(colnames(Xd), c("(Intercept)", "treatment", "x1", "x2"))
	expect_identical(nrow(Xd), n)
})

test_that("logistic fit with sandwich returns glm coefficients, the pair-clustered HC0 covariance, and fitted probabilities", {
	skip_if_not_installed("sandwich")
	fit <- rd$p$fit_logistic_with_sandwich(Xd)
	ref <- glm(yv ~ Xd - 1, family = binomial)
	expect_equal(unname(fit$coefficients), unname(coef(ref)), tolerance = 1e-6)
	expect_identical(fit$j_treat, 2L); expect_false(isTRUE(fit$estimate_only))
	m <- as.integer(des$.__enclos_env__$private$m); m[is.na(m)] <- 0L
	cl <- ifelse(m > 0L, m, max(m) + seq_along(m))                                   # matched pairs are clusters, reservoir subjects singletons
	expect_equal(unname(fit$vcov), unname(sandwich::vcovCL(ref, cluster = cl, type = "HC0", cadjust = FALSE)), tolerance = 1e-4)
	expect_gt(max(abs(unname(fit$vcov) - unname(sandwich::vcovHC(ref, type = "HC0")))), 1e-3)     # NOT the independent-observations HC0
	expect_equal(as.numeric(fit$mu_hat), as.numeric(fitted(ref)), tolerance = 1e-6)
	est_only <- rd$p$fit_logistic_with_sandwich(Xd, estimate_only = TRUE)
	expect_true(est_only$estimate_only); expect_null(est_only$vcov)
	expect_equal(unname(est_only$coefficients), unname(coef(ref)), tolerance = 1e-6)
})

test_that("fit returns NULL when the design cannot be fit (fewer rows than columns); a fresh object is used because the reduction caches the kept columns", {
	fresh <- mk(InferenceIncidKKGCompRiskDiff)
	expect_null(fresh$p$fit_logistic_with_sandwich(Xd[1:3, ]))
})

test_that("weighted g-computation estimate equals the weighted logistic fit's weighted standardized risks (RD and RR)", {
	set.seed(1); rw <- runif(n, 0.3, 2)
	fw <- suppressWarnings(glm(yv ~ Xd - 1, family = quasibinomial, weights = rw))
	X1 <- Xd; X1[, 2] <- 1; X0 <- Xd; X0[, 2] <- 0
	r1 <- weighted.mean(plogis(X1 %*% coef(fw)), rw); r0 <- weighted.mean(plogis(X0 %*% coef(fw)), rw)
	expect_equal(rd$p$compute_weighted_gcomp_estimate(rw), r1 - r0, tolerance = 1e-5)
	expect_equal(rr$p$compute_weighted_gcomp_estimate(rw), r1 / r0, tolerance = 1e-5)
	expect_equal(mk(InferenceIncidKKGCompRiskDiff)$p$compute_weighted_gcomp_estimate(rep(1, n)), mk(InferenceIncidKKGCompRiskDiff)$inf$compute_estimate(), tolerance = 1e-6)      # unit weights = unweighted
})

test_that("weights that are zero, non-finite or all unusable: zero rows dropped; nothing usable gives NA", {
	set.seed(2); rw <- runif(n, 0.3, 2); rz <- rw; rz[1:10] <- 0; rn <- rw; rn[5] <- NA
	keep <- rz > 0
	fw <- suppressWarnings(glm(yv[keep] ~ Xd[keep, ] - 1, family = quasibinomial, weights = rz[keep]))
	X1 <- Xd[keep, ]; X1[, 2] <- 1; X0 <- Xd[keep, ]; X0[, 2] <- 0
	ref <- weighted.mean(plogis(X1 %*% coef(fw)), rz[keep]) - weighted.mean(plogis(X0 %*% coef(fw)), rz[keep])
	expect_equal(rd$p$compute_weighted_gcomp_estimate(rz), ref, tolerance = 1e-5)
	expect_true(is.finite(rd$p$compute_weighted_gcomp_estimate(rn)))
	expect_true(is.na(rd$p$compute_weighted_gcomp_estimate(rep(0, n)))); expect_true(is.na(rd$p$compute_weighted_gcomp_estimate(rep(NA_real_, n))))
})

test_that("effects_are_usable: RD needs a finite estimate (and a positive finite SE for full inference); RR needs positive finite RR, log RR and SE", {
	e <- list(rd = 0.1, se_rd = 0.05, rr = 1.2, log_rr = log(1.2), se_log_rr = 0.1)
	expect_true(rd$p$effects_are_usable(e)); expect_true(rd$p$effects_are_usable(e, estimate_only = TRUE))
	expect_false(rd$p$effects_are_usable(modifyList(e, list(se_rd = 0)))); expect_true(rd$p$effects_are_usable(modifyList(e, list(se_rd = 0)), estimate_only = TRUE))
	expect_false(rd$p$effects_are_usable(modifyList(e, list(rd = NA_real_)), estimate_only = TRUE))
	expect_true(rr$p$effects_are_usable(e)); expect_true(rr$p$effects_are_usable(e, estimate_only = TRUE))
	expect_false(rr$p$effects_are_usable(modifyList(e, list(rr = 0)), estimate_only = TRUE))
	expect_false(rr$p$effects_are_usable(modifyList(e, list(rr = -1))))
	expect_false(rr$p$effects_are_usable(modifyList(e, list(se_log_rr = 0)))); expect_true(rr$p$effects_are_usable(modifyList(e, list(se_log_rr = 0)), estimate_only = TRUE))
	expect_false(rr$p$effects_are_usable(modifyList(e, list(log_rr = Inf))))
})

test_that("coefficients_are_usable: non-empty, finite, and within the maximum reasonable magnitude", {
	m <- rd$p$max_abs_reasonable_coef
	expect_true(rd$p$coefficients_are_usable(c(0.5, -2, m)))
	expect_false(rd$p$coefficients_are_usable(c(0.5, m * 1.01))); expect_false(rd$p$coefficients_are_usable(numeric(0)))
	expect_false(rd$p$coefficients_are_usable(c(1, NA))); expect_false(rd$p$coefficients_are_usable(c(1, Inf)))
})
