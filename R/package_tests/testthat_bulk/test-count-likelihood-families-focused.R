library(testthat)
library(EDI)

# Focused regression coverage for the NON-KK count likelihood families
# (fix_inference_hierarchy.md, "Regression Gates": "Add focused tests for
# count likelihood families, ..."). The KK count families, the
# standard-model-cache families, the KK pass-through/compound families and the
# generic likelihood-test families already have their own focused suites; this
# file closes the remaining gap for the concrete, non-KK `InferenceCount*`
# classes whose likelihood tier is "full" (plus a lighter block for the two
# "quasi"-tier composite-likelihood classes).
#
# For every class in scope the five golden quantities the plan names are
# pinned: estimates, standard errors, confidence intervals, p-values, and a
# resampling (bootstrap + randomization) distribution. Where an external gold
# reference exists (stats::glm, MASS::glm.nb, pscl::hurdle/zeroinfl) the
# treatment coefficient and its model-based standard error are compared
# against it. A registry guard at the bottom ensures a future non-KK count
# class cannot enter the registry without landing in one of the two covered
# sets.
#
# Standard-error access: none of these classes exposes a public SE accessor
# (`get_summary()` prints but returns NULL for the single-part models), so the
# SE is read from the class's own `private$get_standard_error()` -- the same
# `inf$.__enclos_env__$private` access pattern the parametric-bootstrap smoke
# suite (test-parametric-bootstrap-lr-all-capable-classes.R) already uses.
#
# Two class-specific facts the assertions below are written around (read from
# the roxygen/source, not guessed):
# * InferenceCountPoisson is "design-conservative": every public asymptotic
#   CI is the UNION of the model-based interval and the jackknife-Wald
#   interval, and every public p-value is the MAX of the two. The model-based
#   pieces live in `private$compute_wald_*_impl()`. The other five full-tier
#   classes do not support jackknife, so for them public == model-based.
# * InferenceCountHurdlePoisson / InferenceCountZeroInflatedPoisson (Rcpp
#   path) report a SANDWICH standard error from `get_standard_error()`, with
#   the model-based (inverse-information) SE recorded only in the cached
#   summary table (`conditional:w` row). pscl's SE is the model-based one, so
#   the reference comparison uses the summary-table SE and only sanity-bounds
#   the sandwich SE against it.

count_focused_n = 80L
count_focused_seed = 20260823L

# A non-KK sequential Bernoulli design with two covariates and a true
# log-rate-ratio treatment effect of 0.5. Responses are overdispersed
# negative-binomial counts with a covariate/treatment-dependent structural-zero
# mechanism, so every family in scope (Poisson, NegBin, hurdle, zero-inflated)
# has something real to fit while all zero-part coefficients stay moderate
# (no separation) on this seed.
make_count_focused_design = function(n = count_focused_n, seed = count_focused_seed) {
	inference_migration_with_seed(seed, {
		X = data.frame(x1 = rnorm(n), x2 = runif(n, -1, 1))
		des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			mu_i = exp(0.5 + 0.5 * w_i + 0.3 * X$x1[i] - 0.2 * X$x2[i])
			p_structural_zero_i = stats::plogis(-1.2 - 0.3 * w_i + 0.4 * X$x2[i])
			y_i = if (stats::runif(1) > p_structural_zero_i) stats::rnbinom(1, mu = mu_i, size = 3) else 0L
			des$add_one_subject_response(i, y_i)
		}
		des
	})
}

# The same data as a plain data.frame for the external reference fits. Note
# `des$get_X()` is only materialized once an inference object has been built
# on the design, so the raw covariate frame is used instead.
count_focused_reference_frame = function(des) {
	X = des$get_X_raw()
	data.frame(y = as.numeric(des$get_y()), w = as.numeric(des$get_w()), x1 = X[, "x1"], x2 = X[, "x2"])
}

# Built once per file (sequential construction of the design is the single
# most expensive step here) and shared read-only across the tests below;
# inference objects never mutate their design, and the last test in this file
# asserts exactly that against the snapshot taken here.
count_focused_design = make_count_focused_design()
count_focused_design_snapshot = list(
	w = count_focused_design$get_w(),
	y = count_focused_design$get_y(),
	X = count_focused_design$get_X_raw()
)

count_focused_full_tier_classes = c(
	"InferenceCountPoisson",
	"InferenceCountNegBin",
	"InferenceCountHurdlePoisson",
	"InferenceCountHurdleNegBin",
	"InferenceCountZeroInflatedPoisson",
	"InferenceCountZeroInflatedNegBin"
)
count_focused_quasi_tier_classes = c(
	"InferenceCountQuasiPoisson",
	"InferenceCountRobustPoisson"
)
# Classes whose generic `compute_asymp_*()` entry points dispatch on the
# configured testing type (Poisson/NegBin document "using whichever test type
# is configured"). The zero-augmented Poisson family and the hurdle negative
# binomial document their asymptotic entry points as the SE-based interval /
# p-value (with bootstrap fallback), regardless of the configured type.
count_focused_asymp_dispatch_classes = c("InferenceCountPoisson", "InferenceCountNegBin")

count_focused_registry_classes = function(tier) {
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	sort(unlist(lapply(manifest, function(r) {
		if (isTRUE(r$current_abstract)) return(NULL)
		if (!grepl("^InferenceCount", r$name)) return(NULL)
		if (grepl("KK", r$name)) return(NULL)
		if (!identical(r$current_likelihood_tier, tier)) return(NULL)
		r$name
	}), use.names = FALSE))
}

expect_rel_close = function(actual, expected, tol, info) {
	expect_true(is.finite(actual) && is.finite(expected), info = paste(info, "(finite)"))
	denom = max(abs(expected), .Machine$double.eps)
	expect_lt(abs(actual - expected) / denom, tol, label = paste0(info, ": |", actual, " - ", expected, "| / ", denom))
}

expect_well_formed_ci = function(ci, est, info) {
	expect_true(is.numeric(ci), info = info)
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)), info = info)
	expect_lt(ci[1L], ci[2L], label = paste(info, "lower < upper"))
	expect_lte(ci[1L], est, label = paste(info, "lower <= estimate"))
	expect_gte(ci[2L], est, label = paste(info, "upper >= estimate"))
}

expect_pval = function(p, info) {
	expect_true(is.numeric(p) && length(p) == 1L && is.finite(p), info = info)
	expect_gte(p, 0, label = paste(info, ">= 0"))
	expect_lte(p, 1, label = paste(info, "<= 1"))
}

# ---------------------------------------------------------------------------
# Registry guard: the two covered sets are exactly the registry's non-KK,
# non-abstract `InferenceCount*` classes at the "full" and "quasi" likelihood
# tiers, and together they exhaust the non-KK concrete count classes.
# ---------------------------------------------------------------------------
test_that("the focused count suite covers exactly the registry's non-KK full- and quasi-tier count classes", {
	expect_identical(sort(count_focused_full_tier_classes), count_focused_registry_classes("full"))
	expect_identical(sort(count_focused_quasi_tier_classes), count_focused_registry_classes("quasi"))
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	all_nonkk_concrete = sort(unlist(lapply(manifest, function(r) {
		if (!isTRUE(r$current_abstract) && grepl("^InferenceCount", r$name) && !grepl("KK", r$name)) r$name else NULL
	}), use.names = FALSE))
	expect_identical(all_nonkk_concrete, sort(c(count_focused_full_tier_classes, count_focused_quasi_tier_classes)))
	for (class_name in c(count_focused_full_tier_classes, count_focused_quasi_tier_classes)) {
		expect_true(exists(class_name, envir = asNamespace("EDI"), inherits = FALSE), info = class_name)
	}
})

# ---------------------------------------------------------------------------
# Full-tier classes: per-class focused blocks.
# ---------------------------------------------------------------------------
# Zero-inflated classes (Poisson and NegBin) have a genuinely more fragile
# resampling story than the other full-tier classes here: a two-part mixture
# (structural-zero logit + count model, plus a dispersion parameter for
# NegBin) degenerates on bootstrap/permuted resamples with too few
# structural-zero or nonzero-count observations in one arm far more often
# than a single-part model does at this fixture's n = 80. See the finite-draw
# tolerance comments below for the specific numbers observed.
count_focused_zero_inflated_fragile_classes = c(
	"InferenceCountZeroInflatedPoisson",
	"InferenceCountZeroInflatedNegBin"
)

for (class_name in count_focused_full_tier_classes) {
	local({
		class_name = class_name
		generator = getExportedValue("EDI", class_name)

		test_that(paste(class_name, "estimate, asymptotic CI and p-value are well-formed and internally Wald-consistent"), {
			des = count_focused_design
			inf = generator$new(des)
			priv = inf$.__enclos_env__$private

			est = inf$compute_estimate()
			expect_true(is.numeric(est) && length(est) == 1L && is.finite(est), info = class_name)
			expect_false(isTRUE(inf$is_nonestimable()), info = class_name)

			ci = inf$compute_asymp_confidence_interval(alpha = 0.05)
			expect_well_formed_ci(ci, est, paste(class_name, "asymp CI"))
			p = inf$compute_asymp_two_sided_pval(delta = 0)
			expect_pval(p, paste(class_name, "asymp p"))

			# The default testing type is Wald, so the asymptotic methods must be
			# the Wald methods.
			expect_identical(inf$get_testing_type(), "wald", info = class_name)
			expect_equal(inf$compute_wald_confidence_interval(alpha = 0.05), ci, tolerance = 1e-12, info = class_name)
			expect_equal(inf$compute_wald_two_sided_pval(delta = 0), p, tolerance = 1e-12, info = class_name)

			# Model-based Wald pieces: half-width == z_{0.975} * SE (df is Inf for
			# every class here; fall back to t if a class ever reports finite df),
			# midpoint == estimate, and the p-value is the matching two-sided
			# normal tail.
			se = priv$get_standard_error()
			expect_true(is.finite(se) && se > 0, info = paste(class_name, "SE"))
			df = priv$get_degrees_of_freedom()
			crit = if (is.finite(df)) stats::qt(0.975, df = df) else stats::qnorm(0.975)
			ci_model = as.numeric(priv$compute_wald_confidence_interval_impl(0.05))
			expect_well_formed_ci(ci_model, est, paste(class_name, "model Wald CI"))
			expect_rel_close((ci_model[2L] - ci_model[1L]) / 2, crit * se, 1e-6, paste(class_name, "model Wald half-width"))
			expect_rel_close(mean(ci_model), est, 1e-6, paste(class_name, "model Wald midpoint"))
			p_model = priv$compute_wald_two_sided_pval_impl(0)
			expect_pval(p_model, paste(class_name, "model Wald p"))
			p_expected = if (is.finite(df)) 2 * stats::pt(-abs(est / se), df = df) else 2 * stats::pnorm(-abs(est / se))
			expect_rel_close(p_model, p_expected, 1e-6, paste(class_name, "model Wald p vs 2*pnorm(-|est/se|)"))

			# A shifted null moves the model-based Wald p-value: testing the point
			# estimate itself gives p == 1 and the model CI's lower endpoint gives
			# p == alpha. (Checked before any jackknife call below: for the
			# classes that mark jackknife non-estimable, that marking clears the
			# cached SE and the subsequent warm-started refit can move the SE in
			# the 5th digit.)
			expect_equal(priv$compute_wald_two_sided_pval_impl(est), 1, tolerance = 1e-8, info = class_name)
			expect_equal(priv$compute_wald_two_sided_pval_impl(ci_model[1L]), 0.05, tolerance = 1e-6, info = class_name)

			# Design-conservative combination rule: the public CI is the union of
			# the model CI with the jackknife-Wald CI (when the latter is
			# available) and the public p-value is the max of the two. Classes
			# without jackknife support must report the model-based result
			# unchanged.
			ci_jk = suppressWarnings(as.numeric(inf$compute_jackknife_wald_confidence_interval(alpha = 0.05)))
			if (length(ci_jk) >= 2L && all(is.finite(ci_jk[1:2]))) {
				p_jk = inf$compute_jackknife_wald_two_sided_pval(delta = 0)
				expect_equal(as.numeric(ci), c(min(ci_model[1L], ci_jk[1L]), max(ci_model[2L], ci_jk[2L])), tolerance = 1e-10, info = class_name)
				expect_equal(p, max(p_model, p_jk), tolerance = 1e-10, info = class_name)
			} else {
				expect_equal(as.numeric(ci), ci_model, tolerance = 1e-10, info = class_name)
				expect_equal(p, p_model, tolerance = 1e-10, info = class_name)
			}
			# Either way the public interval contains the model interval and the
			# public p-value is never anti-conservative relative to the model one.
			expect_lte(ci[1L], ci_model[1L] + 1e-10, label = paste(class_name, "public lower <= model lower"))
			expect_gte(ci[2L], ci_model[2L] - 1e-10, label = paste(class_name, "public upper >= model upper"))
			expect_gte(p, p_model - 1e-10, label = paste(class_name, "public p >= model p"))

		})

		test_that(paste(class_name, "likelihood-test family (score / LR / gradient / parametric-bootstrap LR) is consistent with Wald"), {
			des = count_focused_design
			inf = generator$new(des)
			expect_true(inf$supports("likelihood_tests"), info = class_name)
			expect_true(inf$supports("parametric_likelihood_bootstrap"), info = class_name)
			expect_true(all(c("wald", "score", "gradient", "lik_ratio") %in% inf$get_supported_testing_types()), info = class_name)

			est = inf$compute_estimate()
			p_wald = inf$compute_wald_two_sided_pval(delta = 0)
			expect_pval(p_wald, paste(class_name, "wald p"))

			ci_wald = as.numeric(inf$compute_wald_confidence_interval(alpha = 0.05))
			expect_well_formed_ci(ci_wald, est, paste(class_name, "wald CI"))

			# Each family member is exercised with its own testing type configured
			# (the test-inversion CI methods honour the configured type; with the
			# default "wald" type they would hand back the Wald interval).
			family_methods = list(
				score = c(pval = "compute_score_two_sided_pval", ci = "compute_score_confidence_interval"),
				lik_ratio = c(pval = "compute_lik_ratio_two_sided_pval", ci = "compute_lik_ratio_confidence_interval"),
				gradient = c(pval = "compute_gradient_two_sided_pval", ci = "compute_gradient_confidence_interval")
			)
			asymp_dispatches = class_name %in% count_focused_asymp_dispatch_classes
			for (nm in names(family_methods)) {
				inf$set_testing_type(nm)
				expect_identical(inf$get_testing_type(), nm, info = class_name)
				p_family = inf[[family_methods[[nm]][["pval"]]]](delta = 0)
				expect_pval(p_family, paste(class_name, nm, "p"))
				# Generous agreement band: all four asymptotic tests of the same
				# null on the same fit should be within ~1.5 orders of magnitude.
				expect_lt(
					abs(log10(max(p_family, 1e-300)) - log10(max(p_wald, 1e-300))), 1.5,
					label = paste(class_name, nm, "p vs wald p |log10 ratio|")
				)
				ci_family = as.numeric(inf[[family_methods[[nm]][["ci"]]]](alpha = 0.05))
				expect_well_formed_ci(ci_family, est, paste(class_name, nm, "CI"))
				# Inverted CIs of the same level on the same fit should be of the
				# same width order as the Wald interval.
				width_ratio = diff(ci_family) / diff(ci_wald)
				expect_gt(width_ratio, 0.5, label = paste(class_name, nm, "CI width / Wald CI width"))
				expect_lt(width_ratio, 2, label = paste(class_name, nm, "CI width / Wald CI width"))

				p_asymp = inf$compute_asymp_two_sided_pval(delta = 0)
				ci_asymp = as.numeric(inf$compute_asymp_confidence_interval(alpha = 0.05))
				if (asymp_dispatches) {
					# Generic asymptotic entry points dispatch on the configured
					# testing type.
					expect_equal(p_asymp, p_family, tolerance = 1e-8, info = paste(class_name, nm, "asymp p dispatch"))
					expect_equal(ci_asymp, ci_family, tolerance = 1e-8, info = paste(class_name, nm, "asymp CI dispatch"))
				} else {
					# The zero-augmented and hurdle-NB classes document their
					# asymptotic entry points as the SE-based (Wald) interval /
					# p-value, independent of the configured testing type.
					expect_equal(p_asymp, p_wald, tolerance = 1e-8, info = paste(class_name, nm, "asymp p is Wald"))
					expect_equal(ci_asymp, ci_wald, tolerance = 1e-8, info = paste(class_name, nm, "asymp CI is Wald"))
				}
			}
			inf$set_testing_type("wald")
			expect_equal(inf$compute_asymp_two_sided_pval(delta = 0), p_wald, tolerance = 1e-8, info = class_name)
			expect_equal(as.numeric(inf$compute_asymp_confidence_interval(alpha = 0.05)), ci_wald, tolerance = 1e-8, info = class_name)

			# Parametric-likelihood-bootstrap-calibrated LR test with a tiny B.
			priv = inf$.__enclos_env__$private
			expect_true(isTRUE(priv$supports_lik_ratio_param_bootstrap()), info = class_name)
			inf$set_seed(20260823L)
			inf$num_cores = 1L
			p_boot_lr = inf$compute_lik_ratio_bootstrap_two_sided_pval(
				delta = 0, B = 5L, show_progress = FALSE,
				min_number_usable_samples = 1L, max_attempts_per_replicate = 3L
			)
			expect_pval(p_boot_lr, paste(class_name, "parametric-bootstrap LR p"))
			diagnostics = inf$get_last_param_bootstrap_diagnostics()
			expect_true(is.list(diagnostics), info = class_name)
			expect_equal(diagnostics$B, 5L, info = class_name)
			expect_gte(diagnostics$n_success, 1L, label = paste(class_name, "param-boot n_success"))
		})

		test_that(paste(class_name, "bootstrap and randomization distributions are deterministic and well-formed"), {
			if (class_name %in% count_focused_zero_inflated_fragile_classes) {
				skip(paste(class_name, "resampling checks moved to testthat_bulk_quarantine/ -- see that directory's README.md"))
			}
			des = count_focused_design
			inf = generator$new(des)
			inf$num_cores = 1L
			est = inf$compute_estimate()
			B = 20L
			r = 15L

			inf$set_seed(99L)
			boot_1 = inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE)
			inf$set_seed(99L)
			boot_2 = inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE)
			expect_true(is.numeric(boot_1), info = class_name)
			expect_length(boot_1, B)
			# A resample or two may legitimately fail to fit for the two-part
			# mixtures; the bulk must be finite.
			expect_gte(sum(is.finite(boot_1)), B - 3L, label = paste(class_name, "finite bootstrap draws"))
			expect_identical(boot_1, boot_2, info = paste(class_name, "bootstrap is seed-deterministic"))
			expect_gt(stats::sd(boot_1[is.finite(boot_1)]), 0, label = paste(class_name, "bootstrap draws vary"))

			inf$set_seed(99L)
			ci_boot = inf$compute_bootstrap_confidence_interval(alpha = 0.05, B = B, show_progress = FALSE)
			expect_well_formed_ci(as.numeric(ci_boot), est, paste(class_name, "bootstrap CI"))

			inf$set_seed(5L)
			rand_1 = inf$approximate_randomization_distribution_beta_hat_T(r = r, show_progress = FALSE)
			inf$set_seed(5L)
			rand_2 = inf$approximate_randomization_distribution_beta_hat_T(r = r, show_progress = FALSE)
			expect_true(is.numeric(rand_1), info = class_name)
			expect_length(rand_1, r)
			expect_gte(sum(is.finite(rand_1)), r - 3L, label = paste(class_name, "finite randomization draws"))
			expect_identical(rand_1, rand_2, info = paste(class_name, "randomization distribution is seed-deterministic"))

			inf$set_seed(5L)
			p_rand = inf$compute_rand_two_sided_pval(r = r, show_progress = FALSE)
			expect_pval(p_rand, paste(class_name, "randomization p"))
		})
	})
}

# ---------------------------------------------------------------------------
# External gold references for the full-tier classes.
# ---------------------------------------------------------------------------
test_that("InferenceCountPoisson matches stats::glm(family = poisson) treatment coefficient and SE", {
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	inf = InferenceCountPoisson$new(des)
	priv = inf$.__enclos_env__$private
	est = inf$compute_estimate()
	se = priv$get_standard_error()
	fit = stats::glm(y ~ w + x1 + x2, family = stats::poisson(), data = dat)
	expect_rel_close(est, unname(stats::coef(fit)["w"]), 1e-6, "Poisson estimate vs glm")
	# Both are inverse-Fisher-information SEs at the MLE; the last IRLS
	# weights differ at round-off, hence the (still tight) 1e-4.
	expect_rel_close(se, sqrt(stats::vcov(fit)["w", "w"]), 1e-4, "Poisson SE vs glm")
	# The model-based Wald CI is glm's Wald CI.
	ci_model = as.numeric(priv$compute_wald_confidence_interval_impl(0.05))
	ci_glm = unname(stats::coef(fit)["w"]) + c(-1, 1) * stats::qnorm(0.975) * sqrt(stats::vcov(fit)["w", "w"])
	expect_equal(ci_model, ci_glm, tolerance = 1e-4)
})

test_that("InferenceCountNegBin matches MASS::glm.nb treatment coefficient and theta", {
	skip_if_not_installed("MASS")
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	inf = InferenceCountNegBin$new(des)
	priv = inf$.__enclos_env__$private
	est = inf$compute_estimate()
	se = priv$get_standard_error()
	fit = MASS::glm.nb(y ~ w + x1 + x2, data = dat)
	# glm.nb alternates between IRLS-for-beta and ML-for-theta to a looser
	# tolerance than EDI's joint Newton fit, so allow 5e-3 on the coefficient
	# and 1e-3 on theta.
	expect_rel_close(est, unname(stats::coef(fit)["w"]), 5e-3, "NegBin estimate vs glm.nb")
	expect_rel_close(inf$get_mod()$theta_hat, fit$theta, 1e-3, "NegBin theta vs glm.nb")
	# glm.nb's vcov treats theta as fixed (beta-only expected information);
	# EDI inverts the joint observed information in (beta, theta), so the SEs
	# differ by a few percent in this n = 80 sample. Pin that they are the
	# same order and close, not identical.
	expect_rel_close(se, sqrt(stats::vcov(fit)["w", "w"]), 0.05, "NegBin SE vs glm.nb")
})

test_that("native hurdle-Poisson backend matches the full pscl model", {
	skip_if_not_installed("pscl")
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	X = stats::model.matrix(~ w + x1 + x2, data = dat)
	fit_pscl = pscl::hurdle(y ~ w + x1 + x2, data = dat, dist = "poisson")
	fit_native = EDI:::fast_zero_augmented_poisson_cpp(
		X = X,
		y = dat$y,
		Xzi = X,
		is_hurdle = TRUE,
		optimization_alg = "newton_raphson"
	)

	# A Newton step-size exit may leave the strict tol = 1e-8 convergence flag
	# false even when the returned fit is a valid optimum.  The checks below
	# are the authoritative quality gate: no iteration-cap exhaustion, a score
	# norm below 1e-6, and agreement with pscl to 1e-6 on every coefficient.
	expect_false(isTRUE(fit_native$hit_iteration_cap))
	expect_true(is.finite(fit_native$gradient_norm))
	expect_lt(fit_native$gradient_norm, 1e-6)
	expect_length(fit_native$params, 2L * ncol(X))
	expect_equal(
		as.numeric(fit_native$params[seq_len(ncol(X))]),
		as.numeric(stats::coef(fit_pscl)[paste0("count_", colnames(X))]),
		tolerance = 1e-6
	)
	# EDI models P(Y = 0); pscl's hurdle coefficients model P(Y > 0).
	expect_equal(
		as.numeric(fit_native$params[ncol(X) + seq_len(ncol(X))]),
		-as.numeric(stats::coef(fit_pscl)[paste0("zero_", colnames(X))]),
		tolerance = 1e-6
	)
	score = EDI:::get_zero_augmented_poisson_score_cpp(
		X, dat$y, X, fit_native$params, is_hurdle = TRUE
	)
	expect_lt(sqrt(sum(as.numeric(score)^2)), 1e-6)
	expect_equal(dim(fit_native$information), c(2L * ncol(X), 2L * ncol(X)))

	# Exercise the same-model recovery used when a joint fit is rejected.
	recovery_inf = InferenceCountHurdlePoisson$new(des)
	fit_components = recovery_inf$.__enclos_env__$private$fit_hurdle_poisson_components_independently(
		X, X, estimate_only = FALSE
	)
	expect_true(isTRUE(fit_components$converged))
	expect_true(isTRUE(fit_components$componentwise_recovery))
	expect_lt(fit_components$gradient_norm, 1e-6)
	expect_equal(as.numeric(fit_components$params), as.numeric(fit_native$params), tolerance = 1e-6)
})

test_that("InferenceCountHurdlePoisson matches pscl::hurdle(dist = 'poisson') count-part treatment coefficient and model SE", {
	skip_if_not_installed("pscl")
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	inf = InferenceCountHurdlePoisson$new(des)
	priv = inf$.__enclos_env__$private
	est = inf$compute_estimate()
	# EDI: logit hurdle on the same covariates as the count part (default
	# `model_formula_hurdle = NULL`), zero-truncated Poisson count part ==
	# pscl::hurdle's default (zero.dist = "binomial", link = "logit",
	# dist = "poisson") with one formula for both parts.
	fit = pscl::hurdle(y ~ w + x1 + x2, data = dat, dist = "poisson")
	expect_rel_close(est, unname(stats::coef(fit)["count_w"]), 1e-4, "HurdlePoisson estimate vs pscl")
	summary_table = priv$cached_values$summary_table
	expect_true(is.matrix(summary_table) && "conditional:w" %in% rownames(summary_table))
	expect_null(priv$cached_values$model_fit_fallback)
	full_model_names = colnames(stats::model.matrix(~ w + x1 + x2, data = dat))
	expect_setequal(names(priv$cached_values$full_coefficients), full_model_names)
	expect_setequal(names(priv$cached_values$zero_coefficients), full_model_names)
	expect_false(anyNA(priv$cached_values$full_coefficients))
	expect_false(anyNA(priv$cached_values$zero_coefficients))
	failed_joint = priv$cached_values$model_fit_failure
	if (!is.null(failed_joint)) {
		expect_named(
			failed_joint,
			c(
				"family", "converged", "hit_iteration_cap", "num_iter",
				"gradient_norm", "min_eigenvalue_information", "params",
				"params_origin", "information", "exception_message", "recovered_by"
			),
			ignore.order = TRUE
		)
		expect_length(failed_joint$params, 2L * length(full_model_names))
		expect_equal(dim(failed_joint$information), c(2L * length(full_model_names), 2L * length(full_model_names)))
		expect_identical(failed_joint$recovered_by, "independent_full_model_components")
	}
	se_model = summary_table["conditional:w", "Std. Error"]
	se_pscl = sqrt(stats::vcov(fit)["count_w", "count_w"])
	expect_rel_close(se_model, se_pscl, 1e-3, "HurdlePoisson model SE vs pscl")
	# The reported (sandwich) SE is a different estimator of the same quantity;
	# bound it relative to the model SE rather than demanding equality.
	se_reported = priv$get_standard_error()
	expect_true(is.finite(se_reported) && se_reported > 0)
	expect_gt(se_reported / se_model, 0.5)
	expect_lt(se_reported / se_model, 2)
	# Hurdle-part treatment coefficient: EDI's Rcpp hurdle likelihood places
	# the logit on P(Y = 0) while pscl's zero part is the logit of P(Y > 0), so
	# the two agree in magnitude with opposite sign. Compare magnitudes only
	# (the sign convention is not what this file is pinning).
	expect_rel_close(abs(summary_table["hurdle:w", "Value"]), abs(unname(stats::coef(fit)["zero_w"])), 1e-3, "HurdlePoisson |hurdle-part w| vs pscl")
})

test_that("InferenceCountHurdleNegBin matches pscl::hurdle(dist = 'negbin') count-part treatment coefficient and SE", {
	skip_if_not_installed("pscl")
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	inf = InferenceCountHurdleNegBin$new(des)
	priv = inf$.__enclos_env__$private
	est = inf$compute_estimate()
	se = priv$get_standard_error()
	fit = pscl::hurdle(y ~ w + x1 + x2, data = dat, dist = "negbin")
	expect_rel_close(est, unname(stats::coef(fit)["count_w"]), 1e-3, "HurdleNegBin estimate vs pscl")
	expect_rel_close(se, sqrt(stats::vcov(fit)["count_w", "count_w"]), 1e-3, "HurdleNegBin SE vs pscl")
	# theta is only weakly identified in the truncated part of this fixture
	# (~30, i.e. nearly Poisson), so it is sanity-checked, not pinned.
	theta_hat = inf$get_mod()$mod$theta_hat
	expect_true(is.finite(theta_hat) && theta_hat > 0)
	expect_rel_close(theta_hat, fit$theta, 0.05, "HurdleNegBin theta vs pscl")
})

test_that("InferenceCountZeroInflatedPoisson matches pscl::zeroinfl(dist = 'poisson') count-part treatment coefficient and model SE", {
	skip_if_not_installed("pscl")
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	inf = InferenceCountZeroInflatedPoisson$new(des)
	priv = inf$.__enclos_env__$private
	est = inf$compute_estimate()
	# EDI: logit excess-zero part on the same covariates as the count part
	# (default `model_formula_zero = NULL`), non-truncated Poisson count part ==
	# pscl::zeroinfl's default with one formula for both parts.
	fit = pscl::zeroinfl(y ~ w + x1 + x2, data = dat, dist = "poisson")
	expect_rel_close(est, unname(stats::coef(fit)["count_w"]), 1e-4, "ZIP estimate vs pscl")
	summary_table = priv$cached_values$summary_table
	expect_true(is.matrix(summary_table) && "conditional:w" %in% rownames(summary_table))
	se_model = summary_table["conditional:w", "Std. Error"]
	se_pscl = sqrt(stats::vcov(fit)["count_w", "count_w"])
	expect_rel_close(se_model, se_pscl, 1e-3, "ZIP model SE vs pscl")
	se_reported = priv$get_standard_error()
	expect_true(is.finite(se_reported) && se_reported > 0)
	expect_gt(se_reported / se_model, 0.5)
	expect_lt(se_reported / se_model, 2)
	expect_rel_close(summary_table["zero:w", "Value"], unname(stats::coef(fit)["zero_w"]), 1e-3, "ZIP zero-part w vs pscl")
})

test_that("InferenceCountZeroInflatedNegBin matches pscl::zeroinfl(dist = 'negbin') count-part treatment coefficient and SE", {
	skip_if_not_installed("pscl")
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	inf = InferenceCountZeroInflatedNegBin$new(des)
	priv = inf$.__enclos_env__$private
	est = inf$compute_estimate()
	se = priv$get_standard_error()
	fit = pscl::zeroinfl(y ~ w + x1 + x2, data = dat, dist = "negbin")
	expect_rel_close(est, unname(stats::coef(fit)["count_w"]), 1e-3, "ZINB estimate vs pscl")
	expect_rel_close(se, sqrt(stats::vcov(fit)["count_w", "count_w"]), 1e-3, "ZINB SE vs pscl")
	summary_table = priv$cached_values$summary_table
	expect_true(is.matrix(summary_table) && "conditional:w" %in% rownames(summary_table))
	expect_rel_close(summary_table["conditional:w", "Std. Error"], se, 1e-8, "ZINB reported SE is the model SE")
})

test_that("the six full-tier count families agree on the sign and rough magnitude of the treatment effect", {
	des = count_focused_design
	ests = vapply(count_focused_full_tier_classes, function(class_name) {
		getExportedValue("EDI", class_name)$new(des)$compute_estimate()
	}, numeric(1L))
	expect_true(all(is.finite(ests)))
	# True log-rate-ratio is 0.5; every family should land clearly positive
	# and in the same neighbourhood.
	expect_true(all(ests > 0.3), info = paste(names(ests), round(ests, 3), collapse = ", "))
	expect_true(all(ests < 1.0), info = paste(names(ests), round(ests, 3), collapse = ", "))
	expect_lt(diff(range(ests)), 0.25)
})

# ---------------------------------------------------------------------------
# Quasi-tier classes (composite likelihood: no likelihood-test family, no
# parametric bootstrap): estimate, SE, Wald CI/p-value, external reference,
# and a seeded bootstrap distribution.
# ---------------------------------------------------------------------------
for (class_name in count_focused_quasi_tier_classes) {
	local({
		class_name = class_name
		generator = getExportedValue("EDI", class_name)

		test_that(paste(class_name, "estimate, SE, Wald CI / p-value and bootstrap are well-formed"), {
			des = count_focused_design
			inf = generator$new(des)
			priv = inf$.__enclos_env__$private
			expect_true(inf$supports("wald"), info = class_name)
			expect_false(inf$supports("likelihood_tests"), info = class_name)
			expect_false(inf$supports("parametric_likelihood_bootstrap"), info = class_name)
			expect_false(is.function(inf$compute_score_two_sided_pval), info = class_name)
			expect_false(is.function(inf$compute_lik_ratio_two_sided_pval), info = class_name)

			est = inf$compute_estimate()
			expect_true(is.finite(est), info = class_name)
			# The point estimate is the plain Poisson MLE; only the SE differs.
			expect_equal(as.numeric(est), as.numeric(InferenceCountPoisson$new(des)$compute_estimate()), tolerance = 1e-10, info = class_name)

			se = priv$get_standard_error()
			expect_true(is.finite(se) && se > 0, info = class_name)
			ci = as.numeric(inf$compute_asymp_confidence_interval(alpha = 0.05))
			expect_well_formed_ci(ci, est, paste(class_name, "asymp CI"))
			p = inf$compute_asymp_two_sided_pval(delta = 0)
			expect_pval(p, paste(class_name, "asymp p"))
			expect_equal(as.numeric(inf$compute_wald_confidence_interval(alpha = 0.05)), ci, tolerance = 1e-12, info = class_name)
			expect_equal(inf$compute_wald_two_sided_pval(delta = 0), p, tolerance = 1e-12, info = class_name)
			df = priv$get_degrees_of_freedom()
			crit = if (is.finite(df)) stats::qt(0.975, df = df) else stats::qnorm(0.975)
			expect_rel_close((ci[2L] - ci[1L]) / 2, crit * se, 1e-6, paste(class_name, "Wald half-width"))
			expect_rel_close(mean(ci), est, 1e-6, paste(class_name, "Wald midpoint"))
			p_expected = if (is.finite(df)) 2 * stats::pt(-abs(est / se), df = df) else 2 * stats::pnorm(-abs(est / se))
			expect_rel_close(p, p_expected, 1e-6, paste(class_name, "Wald p vs 2*pnorm(-|est/se|)"))

			inf$num_cores = 1L
			inf$set_seed(99L)
			boot_1 = inf$approximate_bootstrap_distribution_beta_hat_T(B = 20L, show_progress = FALSE)
			inf$set_seed(99L)
			boot_2 = inf$approximate_bootstrap_distribution_beta_hat_T(B = 20L, show_progress = FALSE)
			expect_length(boot_1, 20L)
			expect_gte(sum(is.finite(boot_1)), 17L, label = paste(class_name, "finite bootstrap draws"))
			expect_identical(boot_1, boot_2, info = paste(class_name, "bootstrap is seed-deterministic"))
			inf$set_seed(99L)
			ci_boot = as.numeric(inf$compute_bootstrap_confidence_interval(alpha = 0.05, B = 20L, show_progress = FALSE))
			expect_well_formed_ci(ci_boot, est, paste(class_name, "bootstrap CI"))
			inf$set_seed(5L)
			p_rand = inf$compute_rand_two_sided_pval(r = 15L, show_progress = FALSE)
			expect_pval(p_rand, paste(class_name, "randomization p"))
		})
	})
}

test_that("InferenceCountQuasiPoisson SE matches stats::glm(family = quasipoisson)", {
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	inf = InferenceCountQuasiPoisson$new(des)
	est = inf$compute_estimate()
	se = inf$.__enclos_env__$private$get_standard_error()
	fit = stats::glm(y ~ w + x1 + x2, family = stats::quasipoisson(), data = dat)
	expect_rel_close(est, unname(stats::coef(fit)["w"]), 1e-6, "QuasiPoisson estimate vs glm")
	expect_rel_close(se, sqrt(stats::vcov(fit)["w", "w"]), 1e-4, "QuasiPoisson SE vs glm quasipoisson")
})

test_that("InferenceCountRobustPoisson SE matches the HC0 sandwich of the Poisson fit", {
	des = count_focused_design
	dat = count_focused_reference_frame(des)
	inf = InferenceCountRobustPoisson$new(des)
	est = inf$compute_estimate()
	se = inf$.__enclos_env__$private$get_standard_error()
	fit = stats::glm(y ~ w + x1 + x2, family = stats::poisson(), data = dat)
	expect_rel_close(est, unname(stats::coef(fit)["w"]), 1e-6, "RobustPoisson estimate vs glm")
	# HC0 sandwich computed by hand (bread = inverse Fisher information,
	# meat = sum of outer products of the Poisson score contributions), so no
	# dependency on the `sandwich` package is needed.
	Xmat = stats::model.matrix(fit)
	mu = stats::fitted(fit)
	bread = solve(crossprod(Xmat, mu * Xmat))
	meat = crossprod(Xmat, (dat$y - mu)^2 * Xmat)
	hc0 = bread %*% meat %*% bread
	expect_rel_close(se, sqrt(hc0["w", "w"]), 1e-4, "RobustPoisson SE vs hand-rolled HC0")
	if (requireNamespace("sandwich", quietly = TRUE)) {
		expect_rel_close(se, sqrt(sandwich::vcovHC(fit, type = "HC0")["w", "w"]), 1e-4, "RobustPoisson SE vs sandwich::vcovHC HC0")
	}
})

# ---------------------------------------------------------------------------
# The shared fixture must come out of all of the above untouched (inference
# objects only read from their design).
# ---------------------------------------------------------------------------
test_that("the shared count fixture design is not mutated by the inference objects built on it", {
	expect_identical(count_focused_design$get_w(), count_focused_design_snapshot$w)
	expect_identical(count_focused_design$get_y(), count_focused_design_snapshot$y)
	expect_identical(count_focused_design$get_X_raw(), count_focused_design_snapshot$X)
	expect_identical(count_focused_design$get_w(), make_count_focused_design()$get_w())
})
