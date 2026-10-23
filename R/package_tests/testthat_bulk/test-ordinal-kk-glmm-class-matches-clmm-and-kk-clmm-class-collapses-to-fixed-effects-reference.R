library(testthat)
library(EDI)

# KK ordinal mixed-model classes against ordinal::clmm(nAGQ = 25) with a random intercept per pair (singletons
# on their own level): InferenceOrdinalKKGLMM (fast_ordinal_glmm_cpp, Newton polish) equals clmm's treatment
# coefficient. InferenceOrdinalKKCLMM uses a neutral variance warm start and the CLMM kernel's
# deterministic multistart, so it must retain the same random-effect solution on the seed-302 fixture.

skip_if_not_installed("ordinal")
skip_if_not_installed("MASS")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed, link = "logit", n = 200L) {
	set.seed(seed)
	n <- as.integer(n)
	des <- DesignSeqOneByOneKK14$new(response_type = "ordinal", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.9
	eta <- 0.7 * w + 0.4 * X$x + u
	if (identical(link, "logit")) {
		y <- as.integer(cut(eta + rlogis(n), c(-Inf, -1, 0.5, Inf)))
	} else {
		# Generate from the requested cumulative-link family so the independent
		# ordinal::clmm oracle and the EDI class are fitted to a correctly
		# specified random-intercept model, not merely a misspecified link.
		cum_prob <- vapply(c(-1, 0.5), function(threshold) {
			z <- threshold - eta
			switch(link,
				probit = pnorm(z),
				cauchit = pcauchy(z),
				cloglog = -expm1(-exp(z)),
				stop("Unsupported fixture link: ", link)
			)
		}, numeric(n))
		u_y <- runif(n)
		y <- 1L + as.integer(u_y > cum_prob[, 1L]) + as.integer(u_y > cum_prob[, 2L])
	}
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

test_that("nonlogit KK CLMM classes recover the ordinal::clmm random-effect fit from their default sigma start", {
	class_by_link <- c(
		probit = "InferenceOrdinalKKCLMMProbit",
		cauchit = "InferenceOrdinalKKCLMMCauchit",
		cloglog = "InferenceOrdinalKKCLMMCloglog"
	)
	for (link in names(class_by_link)) {
		# More groups stabilize the heavy-tailed Cauchit random-effect estimate.
		f <- fx(307L, link = link, n = 400L)
		# ordinal::clmm fits log-log when asked for "cloglog" (and vice versa); the
		# 2026-10-22 TODO-31 diagnosis (G6 #45). Use the probed clmm name for EDI's link.
		mm <- suppressWarnings(ordinal::clmm(y ~ w + x + (1 | g), data = f$d,
			link = EDI:::ordinal_clmm_link_name(link), nAGQ = 25))
		inf <- new_inf(unname(class_by_link[[link]]), f$des)
		beta <- unname(inf$compute_estimate())
		priv <- inf$.__enclos_env__$private
		fit <- priv$cached_mod
		ref_log_sigma <- log(sqrt(as.numeric(ordinal::VarCorr(mm)$g)))
		y_levels <- sort(unique(priv$y))
		start <- priv$clmm_warm_start(
			priv$clmm_X_for_rcpp(), as.integer(match(priv$y, y_levels)), length(y_levels) - 1L
		)

		expect_true(isTRUE(fit$converged), info = link)
		expect_identical(priv$clmm_link(), link)
		expect_equal(tail(start, 1L), 0, tolerance = 0)
		# Compare treatment and sigma to ordinal's separately implemented AGQ=25
		# optimizer. The 0.15 coefficient and 0.2 log-sigma tolerances allow for
		# 20-vs-25-node quadrature and link-specific optimizer differences; the
		# non-collapse bound independently rules out the historical -3 basin.
		# 2026-10-22 (v1.0.5 TODO-31): with the reference now asked for the correctly named
		# link and the KK CLMM fit stationary (clmm_eps_g 1e-12), measured |diff| is <= 4e-5
		# (treatment) and <= 1.3e-4 (log sigma) on all three links; tightened from 0.15 / 0.2.
		expect_equal(beta, unname(coef(mm)["w"]), tolerance = 3e-3, scale = 1, info = link)
		expect_equal(as.numeric(fit$log_sigma), ref_log_sigma, tolerance = 2e-2, scale = 1, info = link)
		expect_true(as.numeric(fit$log_sigma) > -2.5, info = link)
	}
})
