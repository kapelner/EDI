library(testthat)
library(EDI)

# Reference parity: the treatment estimate and its standard error from each
# EDI class are checked against an independent, established implementation
# fit to the same data (stats::lm/glm, MASS, survival, quantreg, pscl, betareg).
# The migration golden tests compare the package against ITSELF, so they cannot
# see a wrong number that has been wrong since before the snapshot was taken;
# an external oracle can. Fixed seed, n = 120, treatment + two covariates, all
# covariates entering the conditional model (EDI's default formula).
#
# Tolerances: estimates rel 1e-3 (EDI's own optimizers stop a little earlier
# than glm/polr/pscl -- observed gaps are <= 5e-4); SEs rel 5e-3.
#
# EDI_PARITY_KNOWN_SE_MISMATCH lists (class) pairs whose SE genuinely disagrees
# with the oracle today; like the other structural gates, the entry must be
# deleted as soon as the discrepancy is fixed (a stale entry fails).

parity_n = 120L
parity_est_tol = 1e-3
parity_se_tol = 5e-3

parity_data = local({
	set.seed(42)
	n = parity_n
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	w = rbinom(n, 1, 0.5)
	yc = 1 + 0.5 * w + X$x1 + rnorm(n)
	yb = rbinom(n, 1, plogis(-0.3 + 0.6 * w + 0.5 * X$x1))
	yp = rpois(n, exp(0.3 + 0.4 * w + 0.3 * X$x1))
	ys = rexp(n, exp(-0.5 + 0.3 * w))
	dead = rbinom(n, 1, 0.7)
	yprop = pmin(pmax(rbeta(n, 2 + w, 2), 0.02), 0.98)
	yo = sample(1:4, n, TRUE, prob = c(0.3, 0.3, 0.2, 0.2))
	yo = pmin(4L, yo + as.integer(w * (runif(n) < 0.3)))
	list(X = X, w = w, D = cbind(X, w = w), yc = yc, yb = yb, yp = yp, ys = ys, dead = dead, yprop = yprop, yo = yo)
})

parity_design = function(rt, y, ...) {
	d = DesignFixedBernoulli$new(n = parity_n, response_type = rt, verbose = FALSE)
	d$add_all_subjects_to_experiment(parity_data$X)
	d$overwrite_all_subject_assignments(parity_data$w)
	d$add_all_subject_responses(y, ...)
	d
}

parity_edi = function(cls, des) {
	inst = get(cls, envir = asNamespace("EDI"))$new(des)
	est = suppressWarnings(inst$compute_estimate())
	se = inst$.__enclos_env__$private$cached_values$s_beta_hat_T
	c(est = est, se = se)
}

# Each entry: package (skipped if absent), EDI class, response type, response
# vector, extra add_all_subject_responses() args, and oracle() -> c(est, se).
parity_cases = function() {
	P = parity_data
	D = cbind(P$D, yc = P$yc, yb = P$yb, yp = P$yp, ys = P$ys, dead = P$dead, yprop = P$yprop, yo = P$yo)
	coef_se = function(m, cols = c("Estimate", "Std. Error")) unname(summary(m)$coef["w", cols])
	list(
		list(cls = "InferenceContinOLS", pkg = "stats", rt = "continuous", y = P$yc,
			oracle = function() coef_se(lm(yc ~ w + x1 + x2, D))),
		list(cls = "InferenceIncidLogRegr", pkg = "stats", rt = "incidence", y = P$yb,
			oracle = function() coef_se(glm(yb ~ w + x1 + x2, binomial, D))),
		list(cls = "InferenceIncidProbitRegr", pkg = "stats", rt = "incidence", y = P$yb,
			oracle = function() coef_se(glm(yb ~ w + x1 + x2, binomial("probit"), D))),
		list(cls = "InferenceCountPoisson", pkg = "stats", rt = "count", y = P$yp,
			oracle = function() coef_se(glm(yp ~ w + x1 + x2, poisson, D))),
		list(cls = "InferenceCountNegBin", pkg = "MASS", rt = "count", y = P$yp,
			oracle = function() coef_se(MASS::glm.nb(yp ~ w + x1 + x2, D))),
		list(cls = "InferenceCountZeroInflatedPoisson", pkg = "pscl", rt = "count", y = P$yp,
			oracle = function() {
				skip_if_not_installed("sandwich")
				m = pscl::zeroinfl(yp ~ w + x1 + x2 | w + x1 + x2, data = D)
				c(unname(coef(m)["count_w"]), unname(sqrt(diag(sandwich::sandwich(m)))["count_w"]))
			}),
		list(cls = "InferenceCountHurdlePoisson", pkg = "pscl", rt = "count", y = P$yp,
			oracle = function() {
				skip_if_not_installed("sandwich")
				m = pscl::hurdle(yp ~ w + x1 + x2 | w + x1 + x2, data = D)
				c(unname(coef(m)["count_w"]), unname(sqrt(diag(sandwich::sandwich(m)))["count_w"]))
			}),
		list(cls = "InferenceContinQuantileRegr", pkg = "quantreg", rt = "continuous", y = P$yc,
			oracle = function() {
				s = suppressWarnings(summary(quantreg::rq(yc ~ w + x1 + x2, data = D, tau = 0.5), se = "nid")$coef)
				unname(s["w", 1:2])
			}),
		list(cls = "InferenceSurvivalCoxPHRegr", pkg = "survival", rt = "survival",
			y = ifelse(P$dead == 1, P$ys, NA_real_),
			extra = list(y_Ls = ifelse(P$dead == 1, NA_real_, P$ys), y_Rs = ifelse(P$dead == 1, NA_real_, Inf)),
			oracle = function() {
				m = survival::coxph(survival::Surv(ys, dead) ~ w + x1 + x2, D)
				unname(summary(m)$coef["w", c("coef", "se(coef)")])
			}),
		list(cls = "InferenceSurvivalWeibullRegr", pkg = "survival", rt = "survival",
			y = ifelse(P$dead == 1, P$ys, NA_real_),
			extra = list(y_Ls = ifelse(P$dead == 1, NA_real_, P$ys), y_Rs = ifelse(P$dead == 1, NA_real_, Inf)),
			oracle = function() {
				m = survival::survreg(survival::Surv(ys, dead) ~ w + x1 + x2, D, dist = "weibull")
				unname(summary(m)$table["w", 1:2])
			}),
		list(cls = "InferencePropFractionalLogit", pkg = "stats", rt = "proportion", y = P$yprop,
			oracle = function() coef_se(glm(yprop ~ w + x1 + x2, quasibinomial, D))),
		list(cls = "InferencePropBetaRegr", pkg = "betareg", rt = "proportion", y = P$yprop,
			oracle = function() unname(summary(betareg::betareg(yprop ~ w + x1 + x2, data = D))$coef$mean["w", 1:2])),
		list(cls = "InferenceOrdinalPropOddsRegr", pkg = "MASS", rt = "ordinal", y = P$yo,
			oracle = function() {
				m = MASS::polr(factor(yo, ordered = TRUE) ~ w + x1 + x2, D, Hess = TRUE)
				unname(summary(m)$coef["w", 1:2])
			})
	)
}

# Genuine, currently-open discrepancies. Empty today. (ZeroInflatedPoisson and
# HurdlePoisson use a deliberate sandwich SE, so their oracle is
# sandwich::sandwich() on the pscl fit, not the model-based summary SE.)
EDI_PARITY_KNOWN_SE_MISMATCH = character()

parity_rel = function(a, b) abs(a - b) / pmax(abs(b), 1e-8)

parity_cases_list = parity_cases()

for (case in parity_cases_list) {
	local({
		case = case
		test_that(sprintf("%s estimate and SE match %s", case$cls, case$pkg), {
			skip_if_not_installed(case$pkg)
			des = do.call(parity_design, c(list(case$rt, case$y), if (is.null(case$extra)) list() else case$extra))
			got = parity_edi(case$cls, des)
			ref = suppressWarnings(case$oracle())
			expect_lt(parity_rel(got[["est"]], ref[1L]), parity_est_tol)
			se_gap = parity_rel(got[["se"]], ref[2L])
			if (case$cls %in% EDI_PARITY_KNOWN_SE_MISMATCH) {
				expect_gt(se_gap, parity_se_tol, label = paste(case$cls, "SE gap (known mismatch; delete the allowlist entry once this fails)"))
			} else {
				expect_lt(se_gap, parity_se_tol)
			}
		})
	})
}

test_that("every EDI_PARITY_KNOWN_SE_MISMATCH entry names a class that is actually checked", {
	expect_true(all(EDI_PARITY_KNOWN_SE_MISMATCH %in% vapply(parity_cases_list, `[[`, "", "cls")))
})
