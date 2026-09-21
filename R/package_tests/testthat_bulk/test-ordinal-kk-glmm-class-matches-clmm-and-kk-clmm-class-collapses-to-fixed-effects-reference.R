library(testthat)
library(EDI)

# KK ordinal mixed-model classes against ordinal::clmm(nAGQ = 25) with a random intercept per pair (singletons
# on their own level): InferenceOrdinalKKGLMM (fast_ordinal_glmm_cpp, Newton polish) equals clmm's treatment
# coefficient. SUSPECTED SOURCE BUG (pinned at class level, not fixed): InferenceOrdinalKKCLMM (fast_ordinal_clmm_cpp
# started at log sigma = -3) collapses the random effect and returns essentially the FIXED-EFFECTS polr estimate
# instead of the mixed-model one -- on the seed-302 fixture 0.4101 (= polr 0.4100) vs clmm / KKGLMM 0.4228.

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

test_that("SUSPECTED SOURCE BUG (pinned): the KK CLMM class returns ~ the fixed-effects (polr) estimate, not the mixed-model one, on the seed-302 fixture", {
	f <- fx(302L)
	mm <- suppressWarnings(ordinal::clmm(y ~ w + x + (1 | g), data = f$d, link = "logit", nAGQ = 25))
	po <- unname(coef(MASS::polr(y ~ w + x, data = f$d))["w"])
	est <- unname(new_inf("InferenceOrdinalKKCLMM", f$des)$compute_estimate())
	expect_gt(sqrt(as.numeric(ordinal::VarCorr(mm)$g)), 0.3)                   # a genuine random effect exists
	expect_lt(abs(est - po), 5e-3)                                              # KK CLMM ~ polr (random effect lost)
	expect_gt(abs(est - unname(coef(mm)["w"])), 0.01)                           # ... and differs from the mixed-model estimate
	# The GLMM class, by contrast, keeps the random effect.
	expect_gt(abs(unname(new_inf("InferenceOrdinalKKGLMM", f$des)$compute_estimate()) - po), 0.01)
})
