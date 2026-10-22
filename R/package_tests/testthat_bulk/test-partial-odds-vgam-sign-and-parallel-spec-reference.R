library(testthat)
library(EDI)

# TODO-107: InferenceOrdinalPartialProportionalOddsRegr's VGAM backend
# (1) returned VGAM's alpha + beta x coefficient with the opposite sign to the
# fast solver / ordinal::clm / MASS::polr (alpha - beta x), and (2) used
# `parallel = ~ treatment + ...`, which also made the intercepts parallel and
# degenerated the fit whenever `nonparallel` was non-empty. Also: the fast
# solver is inaccurate on uncentred covariates while reporting converged = TRUE.

skip_if_not_installed("VGAM")
skip_if_not_installed("ordinal")
skip_if_not_installed("MASS")

ppo107_fixture <- function(seed = 1L, n = 200L, shift = 3, np = character(0)) {
	set.seed(seed)
	x1 <- rnorm(n) + shift
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	lin <- 0.5 * w + 0.4 * (x1 - shift)
	y <- 1L + rowSums(matrix(runif(n * 3), n, 3) > plogis(outer(lin, c(-1, 0.5, 1.6), "-")))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPartialProportionalOddsRegr$new(des, model_formula = ~x1, nonparallel = np, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private,
		dat = data.frame(y = ordered(y), treatment = w, x1 = x1))
}

test_that("fit_vgam reports the clm/polr sign with a genuinely nonparallel covariate", {
	f <- ppo107_fixture(np = "x1")
	ref <- ordinal::clm(y ~ treatment, nominal = ~x1, data = f$dat, link = "logit")
	got <- f$priv$fit_vgam(f$dat, character(0), "x1")
	expect_equal(got$beta, unname(coef(ref)["treatment"]), tolerance = 1e-4)
	expect_equal(got$se, unname(sqrt(vcov(ref)["treatment", "treatment"])), tolerance = 1e-3)
	# the user-facing estimate follows the same convention
	expect_equal(suppressWarnings(f$inf$compute_estimate()), unname(coef(ref)["treatment"]), tolerance = 1e-4)
})

test_that("fit_vgam with no nonparallel covariate matches polr's sign", {
	f <- ppo107_fixture()
	ref <- suppressWarnings(MASS::polr(y ~ treatment + x1, data = f$dat, Hess = TRUE))
	got <- f$priv$fit_vgam(f$dat, "x1", character(0))
	expect_equal(got$beta, unname(coef(ref)["treatment"]), tolerance = 1e-3)
})

test_that("the parallel spec frees only the nonparallel covariates (non-degenerate CI)", {
	f <- ppo107_fixture(np = "x1")
	ci <- suppressWarnings(f$inf$compute_asymp_confidence_interval())
	expect_gt(diff(ci), 0.1)
	spec <- f$priv$vgam_parallel_spec("x1")
	expect_true(inherits(spec, "formula"))
	expect_identical(spec[[2]], FALSE)
	expect_identical(f$priv$vgam_parallel_spec(character(0)), TRUE)
})

test_that("a VGAM fit with non-finite logLik or a ~0 SE is rejected", {
	f <- ppo107_fixture()
	fin <- f$priv$finalize_vgam_fit
	expect_null(fin(NULL, NULL))
	# tiny SE (valid logLik via a real model)
	real <- VGAM::vglm(y ~ treatment, VGAM::cumulative(link = "logitlink", parallel = TRUE), data = f$dat)
	expect_null(fin(list(beta = 1, se = 2e-7), real))
	ok <- fin(list(beta = 1, se = 0.3), real)
	expect_equal(ok$beta, -1)
})

test_that("the fast proportional-odds path is accurate on uncentred covariates", {
	f <- ppo107_fixture(shift = 100)
	ref <- suppressWarnings(MASS::polr(y ~ treatment + x1, data = f$dat, Hess = TRUE))
	est <- f$inf$compute_estimate()
	expect_equal(est, unname(coef(ref)["treatment"]), tolerance = 2e-3)
	expect_lt(abs(est - coef(ref)[["treatment"]]), 2e-3)
})

test_that("nonparallel = 'treatment' warns and is ignored", {
	set.seed(2); n <- 60
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, TRUE))
	expect_warning(
		inf <- InferenceOrdinalPartialProportionalOddsRegr$new(des, nonparallel = "treatment", verbose = FALSE),
		"treatment")
	expect_false("treatment" %in% inf$.__enclos_env__$private$nonparallel)
})

test_that("the centered/scaled proportional-odds refit maps back to the original parameterization", {
	f <- ppo107_fixture(shift = 100)
	X <- cbind(treatment = f$dat$treatment, x1 = f$dat$x1)
	refit <- get("ordinal_po_refit_centered_scaled", envir = asNamespace("EDI"))
	res <- refit(X, as.numeric(f$dat$y), TRUE)
	ref <- suppressWarnings(MASS::polr(y ~ treatment + x1, data = f$dat, Hess = TRUE))
	expect_equal(res$b[1], unname(coef(ref)["treatment"]), tolerance = 2e-3)
	expect_equal(res$b[2], unname(coef(ref)["x1"]), tolerance = 2e-3)
	expect_equal(sqrt(res$ssq_b_j), unname(sqrt(vcov(ref)["treatment", "treatment"])), tolerance = 2e-3)
})
