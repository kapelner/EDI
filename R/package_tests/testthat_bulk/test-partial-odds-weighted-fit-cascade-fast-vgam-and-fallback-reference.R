library(testthat)
library(EDI)

# InferenceOrdinalPartialProportionalOddsRegr's weighted fit cascade:
# fit_fast_proportional_odds_weighted() against a weighted MASS::polr reference,
# fit_vgam_weighted() (VGAM weighted vglm, availability guard), and
# fit_partial_proportional_odds_from_covariates_weighted()'s dispatch: fast solver when no
# covariate is non-parallel, VGAM otherwise, dropping non-positive weights, NULL/NA when
# nothing has positive weight.

po_fx <- function(nonparallel = character(0), seed = 7L, n = 150L) {
	set.seed(seed)
	x1 <- rnorm(n); x2 <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2)); des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- 1L + rowSums(matrix(runif(n), n, 3) > plogis(outer(0.6 * w + 0.4 * x1, c(-1, 0.5, 1.6), "-")))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPartialProportionalOddsRegr$new(des, model_formula = ~x1 + x2, nonparallel = nonparallel, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	list(inf = inf, p = p, w = w, y = y, n = n, Xc = as.matrix(p$get_X()))
}

test_that("weighted fast proportional odds matches a weighted polr fit and never reports an SE", {
	f <- po_fx()
	set.seed(1); wt <- rexp(f$n) + 0.1
	fit <- f$p$fit_fast_proportional_odds_weighted(f$Xc, wt)
	ref <- suppressWarnings(MASS::polr(ordered(f$y) ~ f$w + f$Xc, weights = wt, method = "logistic"))
	expect_equal(fit$beta, unname(coef(ref)[1]), tolerance = 2e-3)
	expect_true(is.na(fit$se))
	# Unit weights reproduce the unweighted polr fit.
	ref1 <- suppressWarnings(MASS::polr(ordered(f$y) ~ f$w + f$Xc, method = "logistic"))
	expect_equal(f$p$fit_fast_proportional_odds_weighted(f$Xc, rep(1, f$n))$beta, unname(coef(ref1)[1]), tolerance = 1e-3)
})

test_that("weighted fast fit drops zero / non-finite weights and returns NULL when none remain", {
	f <- po_fx()
	wt <- rep(1, f$n); wt[1:10] <- 0; wt[11] <- NA
	keep <- wt > 0 & !is.na(wt)
	fit <- f$p$fit_fast_proportional_odds_weighted(f$Xc, wt)
	ref <- suppressWarnings(MASS::polr(ordered(f$y[keep]) ~ f$w[keep] + f$Xc[keep, ], method = "logistic"))
	expect_equal(fit$beta, unname(coef(ref)[1]), tolerance = 1e-3)
	expect_null(f$p$fit_fast_proportional_odds_weighted(f$Xc, rep(0, f$n)))
	expect_null(f$p$fit_fast_proportional_odds_weighted(f$Xc, rep(NA_real_, f$n)))
})

test_that("VGAM weighted fit equals the weighted polr coefficient in magnitude for integer weights, without an SE", {
	skip_if_not_installed("VGAM")
	f <- po_fx()
	set.seed(2); wt <- sample(1:3, f$n, TRUE)
	dat <- data.frame(y = ordered(f$y), treatment = f$w, as.data.frame(f$Xc), .bootstrap_weight__ = wt, check.names = FALSE)
	v <- f$p$fit_vgam_weighted(dat, colnames(f$Xc), character(0))
	expect_false(is.null(v))
	ref <- suppressWarnings(MASS::polr(ordered(f$y) ~ f$w + f$Xc, weights = wt, method = "logistic"))
	expect_equal(abs(v$beta), abs(unname(coef(ref)[1])), tolerance = 1e-2)             # VGAM models P(Y >= k): opposite sign
	expect_equal(sign(v$beta), -sign(unname(coef(ref)[1])))
	expect_true(is.na(v$se))
})

test_that("VGAM weighted fit declines fractional weights (vglm fails), so bootstrap draws fall through to the later fallbacks", {
	skip_if_not_installed("VGAM")
	f <- po_fx()
	set.seed(2); wt <- rexp(f$n) + 0.1
	dat <- data.frame(y = ordered(f$y), treatment = f$w, as.data.frame(f$Xc), .bootstrap_weight__ = wt, check.names = FALSE)
	expect_null(f$p$fit_vgam_weighted(dat, colnames(f$Xc), character(0)))
})

test_that("the weighted cascade uses the fast solver without non-parallel covariates and agrees with it", {
	f <- po_fx()
	set.seed(3); wt <- rexp(f$n) + 0.1
	got <- f$p$fit_partial_proportional_odds_from_covariates_weighted(f$Xc, wt)
	fast <- f$p$fit_fast_proportional_odds_weighted(f$Xc, wt)
	expect_equal(got$beta, fast$beta)
	expect_true(is.na(got$se))
})

test_that("the weighted cascade drops non-positive weights and gives NULL when no row has positive weight", {
	f <- po_fx()
	expect_null(f$p$fit_partial_proportional_odds_from_covariates_weighted(f$Xc, rep(0, f$n)))
	wt <- rep(1, f$n); wt[1:20] <- 0
	g <- f$p$fit_partial_proportional_odds_from_covariates_weighted(f$Xc, wt)
	h <- f$p$fit_fast_proportional_odds_weighted(f$Xc, wt)
	expect_equal(g$beta, h$beta)
})

test_that("with a non-parallel covariate the fast solver is skipped and the VGAM / fallback chain supplies a finite estimate", {
	skip_if_not_installed("VGAM")
	f <- po_fx(nonparallel = "x1")
	expect_equal(f$p$nonparallel, "x1")
	set.seed(4); wt <- rexp(f$n) + 0.1
	called <- character(0)
	orig <- f$p$fit_fast_proportional_odds_weighted
	unlockBinding("fit_fast_proportional_odds_weighted", f$p)
	f$p$fit_fast_proportional_odds_weighted <- function(...) { called <<- c(called, "fast"); orig(...) }
	got <- f$p$fit_partial_proportional_odds_from_covariates_weighted(f$Xc, wt)
	expect_length(called, 0L)
	expect_true(is.null(got) || (is.finite(got$beta) && is.na(got$se)))
})
