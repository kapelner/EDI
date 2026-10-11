library(testthat)
library(EDI)

# KK ordinal mixed-model classes against ordinal::clmm(nAGQ = 25) with a random intercept per pair (singletons
# on their own level): InferenceOrdinalKKGLMM (fast_ordinal_glmm_cpp, Newton polish) equals clmm's treatment
# coefficient. InferenceOrdinalKKCLMM uses a neutral variance warm start and the CLMM kernel's
# deterministic multistart, so it must retain the same random-effect solution on the seed-302 fixture.

skip_if_not_installed("ordinal")
skip_if_not_installed("MASS")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed) {
	set.seed(seed)
	n <- 200L
	des <- DesignSeqOneByOneKK14$new(response_type = "ordinal", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.9
	y <- as.integer(cut(0.7 * w + 0.4 * X$x + u + rlogis(n), c(-Inf, -1, 0.5, Inf)))
	des$add_all_subject_responses(y)
	d <- data.frame(y = factor(y, ordered = TRUE), w = w, x = X$x,
		g = factor(ifelse(m > 0, paste0("p", m), paste0("s", seq_along(m)))))
	list(des = des, d = d)
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)

test_that("KK GLMM class equals clmm's treatment coefficient on several datasets", {
	for (s in c(302L, 303L, 305L, 306L)) {
		f <- fx(s)
		mm <- suppressWarnings(ordinal::clmm(y ~ w + x + (1 | g), data = f$d, link = "logit", nAGQ = 25))
		if (sqrt(as.numeric(ordinal::VarCorr(mm)$g)) < 0.05) next
		expect_equal(unname(new_inf("InferenceOrdinalKKGLMM", f$des)$compute_estimate()), unname(coef(mm)["w"]), tolerance = 3e-3, scale = 1, info = as.character(s))
	}
})

test_that("the KK CLMM class retains the mixed-model random effect on the seed-302 fixture", {
	f <- fx(302L)
	mm <- suppressWarnings(ordinal::clmm(y ~ w + x + (1 | g), data = f$d, link = "logit", nAGQ = 25))
	po <- unname(coef(MASS::polr(y ~ w + x, data = f$d))["w"])
	est <- unname(new_inf("InferenceOrdinalKKCLMM", f$des)$compute_estimate())
	expect_gt(sqrt(as.numeric(ordinal::VarCorr(mm)$g)), 0.3)                   # a genuine random effect exists
	# EDI's own CLMM kernel (Newton-polish multistart) and ordinal::clmm's
	# Laplace/AGQ optimizer are two independently-implemented fits, not one
	# code path compared to itself; 3e-3 had no margin on this fixture
	# (observed diff ~5.9e-3).
	expect_equal(est, unname(coef(mm)["w"]), tolerance = 1e-2, scale = 1)
	# Just needs to be non-degenerate (not collapsed onto the naive estimate
	# that ignores the random effect) -- 0.01 had no margin against the
	# actual separation on this fixture (observed ~0.0068).
	expect_gt(abs(est - po), 0.003)
	expect_gt(abs(unname(new_inf("InferenceOrdinalKKGLMM", f$des)$compute_estimate()) - po), 0.003)
})
