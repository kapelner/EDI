library(testthat)
library(EDI)

# InferenceAllSimpleAverageDiff private helpers: compute_fast_bootstrap_distr(B, n, y, dead, w) (row resampling with a
# retry until both arms are present, mean difference per replicate; NULL for KK designs) and
# compute_treatment_estimate_during_randomization_inference() (cached mean difference; NA when an arm is empty).
# Reference: the same resampling loop replayed in R under an identical seed.

mk <- function(n = 30L, seed = 1L, prob_T = 0.5) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, prob_T = prob_T, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w(); y <- rnorm(n) + w; d$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(d, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, y = y, w = w, n = n)
}
f <- mk()

ref_boot <- function(n, y, w, B, max_attempts = 50L) {
	out <- numeric(B); ym <- matrix(NA_real_, n, B); wm <- matrix(NA_integer_, n, B)
	for (b in 1:B) {
		attempt <- 1
		repeat {
			i_b <- sample(n, n, replace = TRUE); w_b <- w[i_b]
			if (any(w_b == 1) && any(w_b == 0)) break
			attempt <- attempt + 1
			if (attempt > max_attempts) break
		}
		if (attempt <= max_attempts) { ym[, b] <- y[i_b]; wm[, b] <- w_b }
	}
	for (b in 1:B) out[b] <- mean(ym[wm[, b] == 1, b], na.rm = TRUE) - mean(ym[wm[, b] == 0, b], na.rm = TRUE)
	out
}

test_that("fast bootstrap distribution replays the resample-until-both-arms loop exactly under the same seed", {
	set.seed(11); got <- f$p$compute_fast_bootstrap_distr(50L, f$n, f$y, rep(1L, f$n), f$w)
	set.seed(11); ref <- ref_boot(f$n, f$y, f$w, 50L)
	expect_length(got, 50L); expect_equal(got, ref, tolerance = 1e-12)
	expect_true(all(is.finite(got)))
})

test_that("bootstrap replicates centre on the observed mean difference with a spread near the Welch standard error", {
	set.seed(12); got <- f$p$compute_fast_bootstrap_distr(2000L, f$n, f$y, rep(1L, f$n), f$w)
	obs <- mean(f$y[f$w == 1]) - mean(f$y[f$w == 0])
	se <- sqrt(var(f$y[f$w == 1]) / sum(f$w == 1) + var(f$y[f$w == 0]) / sum(f$w == 0))
	expect_lt(abs(mean(got) - obs), 0.1); expect_lt(abs(sd(got) / se - 1), 0.25)
})

test_that("a design with a single treated subject retries until a treated row is drawn; hopeless draws give NaN", {
	y <- c(5, rep(0, 9)); w <- c(1L, rep(0L, 9))
	set.seed(13); got <- f$p$compute_fast_bootstrap_distr(200L, 10L, y, rep(1L, 10), w)
	set.seed(13); ref <- ref_boot(10L, y, w, 200L)
	expect_equal(got, ref, tolerance = 1e-12)
	expect_true(all(is.na(ref) | is.finite(ref)))
	# with max_resample_attempts = 1 a draw missing an arm is left unfilled -> NaN
	unlockBinding("max_resample_attempts", f$p); f$p$max_resample_attempts <- 1L
	set.seed(14); g <- f$p$compute_fast_bootstrap_distr(300L, 10L, y, rep(1L, 10), w)
	set.seed(14); r <- ref_boot(10L, y, w, 300L, max_attempts = 1L)
	expect_equal(g, r, tolerance = 1e-12); expect_true(any(is.nan(g)))
})

test_that("randomization-time estimate is the mean difference, is cached, and is NA for an empty arm", {
	g <- mk(seed = 2L)
	expect_equal(g$p$compute_treatment_estimate_during_randomization_inference(), mean(g$y[g$w == 1]) - mean(g$y[g$w == 0]), tolerance = 1e-12)
	g$p$cached_values$beta_hat_T <- 123
	expect_identical(g$p$compute_treatment_estimate_during_randomization_inference(), 123)          # cache wins
	h <- mk(seed = 3L, n = 12L, prob_T = 0.999999)
	if (all(h$w == 1)) {
		h$p$cached_values$beta_hat_T <- NULL
		expect_true(is.na(h$p$compute_treatment_estimate_during_randomization_inference()))
	} else skip("Bernoulli draw produced both arms")
})

test_that("Welch standard error and degrees of freedom are cached by shared() with the Satterthwaite formula", {
	g <- mk(seed = 4L); g$inf$compute_estimate()
	nT <- sum(g$w == 1); nC <- sum(g$w == 0)
	s1 <- var(g$y[g$w == 1]) / nT; s2 <- var(g$y[g$w == 0]) / nC
	expect_equal(g$p$get_standard_error(), sqrt(s1 + s2), tolerance = 1e-12)
	expect_equal(g$p$get_degrees_of_freedom(), (s1 + s2)^2 / (s1^2 / (nT - 1) + s2^2 / (nC - 1)), tolerance = 1e-12)
})
