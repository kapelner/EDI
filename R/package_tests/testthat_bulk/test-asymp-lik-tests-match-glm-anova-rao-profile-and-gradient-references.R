library(testthat)
library(EDI)

# Numerical agreement of InferenceAsympLik's four likelihood-based tests for logistic
# regression (InferenceIncidLogRegr) with independent references built from glm():
#   likelihood ratio -> anova(test = "Chisq") and a fixed-offset fit at delta != 0,
#   score            -> anova(test = "Rao"),
#   gradient         -> U_T(null fit) * (beta_hat_T - delta) referred to chi-square(1),
#   Wald             -> summary(glm) z test,
# plus the inverted confidence intervals (LR interval vs profile-likelihood confint(); score and
# gradient intervals have p-value alpha at their endpoints).

fx <- function() {
	set.seed(7)
	n <- 120L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.3 + 0.5 * w + 0.4 * X$x))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, y = y, w = w, x = X$x)
}
pval <- function(f, type, delta = 0) { f$inf$set_testing_type(type); f$inf$compute_asymp_two_sided_pval(delta) }

test_that("the four testing types are advertised", {
	f <- fx()
	expect_true(all(c("wald", "score", "gradient", "lik_ratio") %in% f$inf$get_supported_testing_types()))
})

test_that("null (delta = 0) p-values match the glm Wald, Rao score and LR references", {
	f <- fx()
	g1 <- glm(f$y ~ f$w + f$x, family = binomial()); g0 <- glm(f$y ~ f$x, family = binomial())
	expect_equal(pval(f, "wald"), summary(g1)$coefficients[2, 4], tolerance = 5e-3)
	expect_equal(pval(f, "score"), anova(g0, g1, test = "Rao")[["Pr(>Chi)"]][2], tolerance = 1e-4)
	expect_equal(pval(f, "lik_ratio"), anova(g0, g1, test = "Chisq")[["Pr(>Chi)"]][2], tolerance = 1e-4)
})

test_that("the gradient test equals U_T(null fit) * (beta_hat - delta) on chi-square(1)", {
	f <- fx()
	g1 <- glm(f$y ~ f$w + f$x, family = binomial()); g0 <- glm(f$y ~ f$x, family = binomial())
	U <- sum((f$y - fitted(g0)) * f$w)
	expect_equal(unname(pval(f, "gradient")), unname(pchisq(U * coef(g1)[2], 1, lower.tail = FALSE)), tolerance = 1e-4)
})

test_that("a non-null delta uses the constrained (offset) fit for the likelihood ratio and score tests", {
	f <- fx()
	g1 <- glm(f$y ~ f$w + f$x, family = binomial())
	for (d in c(0.3, -0.4, 1)) {
		g0d <- glm(f$y ~ f$x + offset(d * f$w), family = binomial())
		lr <- pchisq(as.numeric(2 * (logLik(g1) - logLik(g0d))), 1, lower.tail = FALSE)
		expect_equal(unname(pval(f, "lik_ratio", d)), lr, tolerance = 1e-4, info = as.character(d))
		U <- sum((f$y - fitted(g0d)) * f$w)
		grad <- pchisq(U * (coef(g1)[2] - d), 1, lower.tail = FALSE)
		expect_equal(unname(pval(f, "gradient", d)), unname(grad), tolerance = 1e-4, info = as.character(d))
	}
})

test_that("the LR interval equals the profile-likelihood interval; score and gradient intervals sit where p = alpha", {
	f <- fx()
	g1 <- glm(f$y ~ f$w + f$x, family = binomial())
	prof <- suppressMessages(confint(g1))[2, ]
	f$inf$set_testing_type("lik_ratio")
	ci <- f$inf$compute_asymp_confidence_interval(0.05)
	expect_equal(unname(ci), unname(prof), tolerance = 1e-3)
	for (type in c("score", "gradient")) {
		f$inf$set_testing_type(type)
		ci <- f$inf$compute_asymp_confidence_interval(0.05)
		expect_lt(ci[1], ci[2])
		for (b in ci) expect_equal(f$inf$compute_asymp_two_sided_pval(b), 0.05, tolerance = 1e-3, info = type)
		# The interval contains the point estimate.
		est <- coef(g1)[2]
		expect_true(ci[1] < est && est < ci[2])
	}
})
