# v1.0.6-TODO-119: InferenceOrdinalGCompMeanDiff called the raw proportional-odds kernels and
# InferenceOrdinalStereotypeLogitRegr called fast_stereotype_logit_cpp on the raw covariates,
# bypassing the column scaling the other ordinal classes use (ordinal_fit_scaled()). The C++
# convergence tests are not scale-aware, so the estimate moved with the units of a covariate
# (g-comp 0.259 raw vs 0.193 scaled on the colon data; stereotype NA at age x 1000). Both
# models are closed under centring/scaling a covariate, so the treatment estimate and its SE
# must not depend on covariate location or scale.

ordinal_scale_invariance_variants = function(n = 240L, seed = 11L){
	set.seed(seed)
	age = rnorm(n, 60, 12)
	nodes = rpois(n, 3)
	sex = rbinom(n, 1, 0.5)
	w = rep(c(0L, 1L), length.out = n)[sample.int(n)]
	eta = 0.6 * w + 0.04 * (age - 60) + 0.25 * nodes - 0.3 * sex
	u = eta + stats::rlogis(n)
	y = as.integer(cut(u, stats::quantile(u, 0:4 / 4), include.lowest = TRUE))
	X0 = data.frame(age = age, nodes = nodes, sex = sex)
	list(
		w = w, y = y,
		X = list(
			raw = X0,
			scaled = as.data.frame(scale(X0)),
			age_x1000 = transform(X0, age = age * 1000),
			age_plus_1e5 = transform(X0, age = age + 1e5)
		)
	)
}

ordinal_scale_invariance_fit = function(cls, X, w, y){
	des = DesignFixedBernoulli$new(response_type = "ordinal", n = nrow(X), verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(w_precomputed = w)
	des$add_all_subject_responses(y)
	inf = get(cls)$new(des, verbose = FALSE)
	est = inf$compute_estimate()
	se = inf$.__enclos_env__$private$get_standard_error()
	c(est = est, se = se)
}

test_that("the ordinal g-computation and stereotype estimates do not depend on covariate location or scale", {
	dat = ordinal_scale_invariance_variants()
	for (cls in c("InferenceOrdinalGCompMeanDiff", "InferenceOrdinalStereotypeLogitRegr")) {
		res = lapply(dat$X, function(X) ordinal_scale_invariance_fit(cls, X, dat$w, dat$y))
		ref = res$scaled
		expect_true(all(is.finite(ref)) && ref[["se"]] > 0, info = cls)
		for (v in names(res)) {
			expect_equal(res[[v]][["est"]], ref[["est"]], tolerance = 1e-5, info = paste(cls, v))
			expect_equal(res[[v]][["se"]], ref[["se"]], tolerance = 1e-3, info = paste(cls, v))
		}
	}
})

test_that("the ordinal g-computation estimate matches a proportional-odds g-computation from the same fit on uncentred covariates", {
	dat = ordinal_scale_invariance_variants()
	X = dat$X$age_plus_1e5
	est = ordinal_scale_invariance_fit("InferenceOrdinalGCompMeanDiff", X, dat$w, dat$y)[["est"]]
	X_fit = cbind(treatment = dat$w, as.matrix(X))
	fit = ordinal_fit_scaled(fast_ordinal_regression_cpp, X = X_fit, y = as.numeric(dat$y), force = TRUE)
	ref = gcomp_ordinal_proportional_odds_post_fit_cpp(X_fit = X_fit, coef_hat = as.numeric(fit$b),
		alpha_hat = as.numeric(fit$alpha), j_treat = 1L)$md
	expect_equal(est, as.numeric(ref), tolerance = 1e-6)
})

test_that("the stereotype design scaling leaves well-scaled designs untouched and the treatment column alone", {
	X = cbind(treatment = rep(0:1, 20), x1 = seq(-1, 1, length.out = 40))
	expect_identical(EDI:::.stereotype_center_scale_design(X), X)
	X[, "x1"] = X[, "x1"] * 1000 + 5e4
	Xs = EDI:::.stereotype_center_scale_design(X)
	expect_identical(Xs[, "treatment"], X[, "treatment"])
	expect_equal(mean(Xs[, "x1"]), 0, tolerance = 1e-10)
	expect_equal(stats::sd(Xs[, "x1"]), 1, tolerance = 1e-10)
})
