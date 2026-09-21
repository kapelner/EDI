library(testthat)
library(EDI)

# InferenceContinKKGLMM (Gaussian random-intercept model on matched pairs + reservoir singletons) equals
# lme4::lmer(REML = FALSE) for the treatment coefficient on every simulated dataset (max difference ~4e-4 over
# 14 datasets in a probe), i.e. unlike the count KK GLMM class (Newton-optimizer sigma collapse on some
# datasets) this class' L-BFGS fit is robust, and its variance components are not collapsed.

skip_if_not_installed("lme4")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed) {
	set.seed(seed)
	n <- 100L
	des <- DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.8
	y <- 1 + 0.7 * w + 0.4 * X$x + u + rnorm(n, 0, 0.5)
	des$add_all_subject_responses(y)
	d <- data.frame(y = y, w = w, x = X$x, g = ifelse(m > 0, paste0("p", m), paste0("s", seq_along(m))))
	list(des = des, d = d)
}

test_that("the class' treatment coefficient equals lmer's on every dataset, with a non-collapsed random-effect scale", {
	for (s in 801:808) {
		f <- fx(s)
		fit <- suppressMessages(lme4::lmer(y ~ w + x + (1 | g), data = f$d, REML = FALSE))
		inf <- K("InferenceContinKKGLMM")$new(f$des, verbose = FALSE)
		expect_equal(unname(inf$compute_estimate()), unname(lme4::fixef(fit)["w"]), tolerance = 2e-3, scale = 1, info = as.character(s))
		expect_identical(inf$.__enclos_env__$private$optimization_alg, "lbfgs")
		sd_b <- as.data.frame(lme4::VarCorr(fit))$sdcor[1]
		expect_gt(sd_b, 0.05)                                  # the fixtures do have a real random effect
	}
})

test_that("the fitted variance components match lmer's (log sigma_e, log sigma_b) on one dataset", {
	f <- fx(801L)
	fit <- suppressMessages(lme4::lmer(y ~ w + x + (1 | g), data = f$d, REML = FALSE))
	inf <- K("InferenceContinKKGLMM")$new(f$des, verbose = FALSE)
	inf$compute_estimate(estimate_only = FALSE)
	mod <- inf$.__enclos_env__$private$cached_mod
	p <- as.numeric(mod$params)
	vc <- as.data.frame(lme4::VarCorr(fit))
	expect_equal(exp(p[length(p) - 1L]), vc$sdcor[2], tolerance = 5e-3)     # residual sd
	expect_equal(exp(p[length(p)]), vc$sdcor[1], tolerance = 5e-3)          # between-pair sd
})
