library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d55fb24f7 (InferencePropGCompMeanDiff):
# - max_resample_attempts must be a positive integer; exhausted redraws record the replicate as NA; per-call
#   override in approximate_bootstrap_distribution_beta_hat_T (inference_proportion_gcomp.R:114);
# - compute_bootstrap_two_sided_pval(na.rm = FALSE): a non-finite replicate gives NA with one
#   edi_bootstrap_nonfinite_na_warning per object, through this class's screening wrapper (:258);
# - des_obj must have a proportion response (:71);
# - model_based covariance caps the binomial weight mu(1 - mu) at 0.25 (:93);
# - _fd strategies use a central-difference gradient (h_j = eps^(1/3)(|beta_j| + 1)); strong_clip
#   strategies use prob_clip_strong_eps (:99).

prop_gcomp_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- plogis(-0.2 + 0.6 * w + 0.4 * x + rnorm(n, sd = 0.3))
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	list(des = des, X = cbind("(Intercept)" = 1, treatment = w, x = x), y = y, x = x, w = w, n = n)
}

test_that("max_resample_attempts must be a positive integer; exhausted redraws give NA replicates", {
	f <- prop_gcomp_fixture()
	expect_error(InferencePropGCompMeanDiff$new(f$des, max_resample_attempts = 0L), "max_resample_attempts")
	expect_error(InferencePropGCompMeanDiff$new(f$des, max_resample_attempts = 1.5), "max_resample_attempts")
	inf <- InferencePropGCompMeanDiff$new(f$des, model_formula = ~ x)
	expect_error(inf$approximate_bootstrap_distribution_beta_hat_T(B = 3, show_progress = FALSE, max_resample_attempts = 0), "max_resample_attempts")
	# min_group_n = n fails every draw's screening; one attempt per replicate, so every replicate is NA.
	b <- inf$approximate_bootstrap_distribution_beta_hat_T(B = 9, show_progress = FALSE, max_resample_attempts = 1, min_group_n = f$n)
	expect_length(b, 9L)
	expect_true(all(is.na(b)))
	# With the ordinary screen the same call gives finite replicates.
	b_ok <- inf$approximate_bootstrap_distribution_beta_hat_T(B = 9, show_progress = FALSE, max_resample_attempts = 1)
	expect_true(any(is.finite(b_ok)))
})

test_that("compute_bootstrap_two_sided_pval with a non-finite replicate returns NA with one nonfinite warning per object", {
	f <- prop_gcomp_fixture()
	inf <- InferencePropGCompMeanDiff$new(f$des, model_formula = ~ x)
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", inf)
	inf$approximate_bootstrap_distribution_beta_hat_T <- function(...) c(seq(-0.1, 0.1, length.out = 20), NaN)
	classes <- character()
	vals <- withCallingHandlers(
		list(inf$compute_bootstrap_two_sided_pval(B = 21, show_progress = FALSE),
			inf$compute_bootstrap_two_sided_pval(B = 21, show_progress = FALSE)),
		warning = function(w) { classes <<- c(classes, class(w)[1L]); invokeRestart("muffleWarning") }
	)
	expect_true(is.na(vals[[1]]))
	expect_true(is.na(vals[[2]]))
	expect_identical(sum(classes == "edi_bootstrap_nonfinite_na_warning"), 1L)
	# na.rm = TRUE drops the NaN instead.
	expect_true(is.finite(suppressWarnings(inf$compute_bootstrap_two_sided_pval(B = 21, na.rm = TRUE, show_progress = FALSE, min_fraction_usable_samples = 0.9))))
})

test_that("des_obj must have a proportion response", {
	f <- prop_gcomp_fixture()
	d <- DesignFixedBernoulli$new(n = f$n, response_type = "incidence", verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = f$x))
	d$overwrite_all_subject_assignments(f$w)
	d$add_all_subject_responses(rbinom(f$n, 1, 0.5))
	expect_error(InferencePropGCompMeanDiff$new(d), "proportion")
})

test_that("model_based covariance is (X' W X)^-1 with W = mu(1 - mu), and W is capped at 0.25", {
	f <- prop_gcomp_fixture()
	p <- InferencePropGCompMeanDiff$new(f$des, model_formula = ~ x)$.__enclos_env__$private
	b <- glm.fit(f$X, f$y, family = quasibinomial())$coefficients
	names(b) <- colnames(f$X)
	mu <- plogis(as.numeric(f$X %*% b))
	V <- p$model_based_covariance_matrix(f$X, b)
	expect_equal(unname(solve(V)), unname(crossprod(f$X, f$X * mu * (1 - mu))), tolerance = 1e-8)
	# mu(1 - mu) itself never exceeds 0.25, so the cap is reached through the clip floor
	# clip_lower * (1 - clip_upper) = 0.36 here: every weight is then capped to exactly 0.25.
	V_cap <- p$model_based_covariance_matrix(f$X, b, clip_lower = 0.6, clip_upper = 0.4)
	expect_equal(unname(solve(V_cap)), unname(0.25 * crossprod(f$X)), tolerance = 1e-8)
})

test_that("_fd strategies use a central-difference gradient; strong_clip strategies use prob_clip_strong_eps", {
	f <- prop_gcomp_fixture(seed = 99, n = 60L)
	se_for <- function(methods, ...) {
		inf <- InferencePropGCompMeanDiff$new(f$des, model_formula = ~ x, variance_fallback_methods = methods, ...)
		inf$compute_estimate()
		inf$get_standard_error()
	}
	se_mb <- se_for("model_based")
	expect_equal(se_for("model_based_fd"), se_mb, tolerance = 1e-6)
	expect_equal(se_for("stabilized_robust_fd"), se_for("stabilized_robust"), tolerance = 1e-6)

	# The finite-difference gradient itself, against an independent central difference with the documented step.
	p <- InferencePropGCompMeanDiff$new(f$des, model_formula = ~ x)$.__enclos_env__$private
	b <- glm.fit(f$X, f$y, family = quasibinomial())$coefficients
	names(b) <- colnames(f$X)
	md <- function(beta) { X1 <- f$X; X1[, 2] <- 1; X0 <- f$X; X0[, 2] <- 0; mean(plogis(X1 %*% beta)) - mean(plogis(X0 %*% beta)) }
	ref <- vapply(seq_along(b), function(j) {
		h <- .Machine$double.eps^(1 / 3) * (abs(b[j]) + 1)
		e <- replace(numeric(length(b)), j, h)
		(md(b + e) - md(b - e)) / (2 * h)
	}, numeric(1))
	expect_equal(unname(p$finite_difference_md_gradient(f$X, b, 2L)), ref, tolerance = 1e-10)

	# A non-binding strong clip (default 1e-4) leaves the model-based SE as is; a binding one (0.45) changes it.
	expect_equal(se_for("model_based_strong_clip"), se_mb, tolerance = 1e-6)
	expect_gt(abs(se_for("model_based_strong_clip", prob_clip_strong_eps = 0.45) - se_mb), 1e-4)
})
