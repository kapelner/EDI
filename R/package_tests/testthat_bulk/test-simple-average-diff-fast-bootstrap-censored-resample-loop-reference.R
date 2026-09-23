library(testthat)
library(EDI)

# InferenceAllSimpleAverageDiff$compute_fast_bootstrap_distr()'s resample-until-valid loop
# (inference_all_average_diff.R) has an extra acceptance condition that only applies when
# private$any_censoring is TRUE: beyond "both arms present" it also requires an observed event
# (dead == 1) in BOTH the resampled treated and control rows, and a strictly positive minimum
# response (min(y[i_b]) > 0, e.g. a survival time). The existing reference test
# (test-simple-average-diff-fast-bootstrap-resample-loop-and-randomization-estimate-cache-reference.R)
# only exercises the any_censoring == FALSE path (it always passes dead = rep(1L, n)), so this
# branch had no test reference anywhere. any_censoring is normally set from the design's censoring
# state at construction (inference_all_abstract.R); it is set directly here via unlockBinding, the
# same direct-private-state-injection pattern this suite already uses elsewhere to reach guards not
# naturally wired up through the public constructor path.

mk <- function(n = 30L, seed = 1L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w(); y <- abs(rnorm(n)) + 0.1 + w; d$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(d, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("any_censoring", p)
	p$any_censoring <- TRUE
	list(inf = inf, p = p, y = y, w = w, n = n)
}
f <- mk()

ref_boot_censored <- function(n, y, w, dead, B, max_attempts = 50L) {
	out <- numeric(B); ym <- matrix(NA_real_, n, B); wm <- matrix(NA_integer_, n, B)
	for (b in 1:B) {
		attempt <- 1
		repeat {
			i_b <- sample(n, n, replace = TRUE); w_b <- w[i_b]
			if (any(w_b == 1) && any(w_b == 0)) {
				dead_b <- dead[i_b]
				if (any(dead_b[w_b == 1] == 1) && any(dead_b[w_b == 0] == 1) && min(y[i_b]) > 0) break
			}
			attempt <- attempt + 1
			if (attempt > max_attempts) break
		}
		if (attempt <= max_attempts) { ym[, b] <- y[i_b]; wm[, b] <- w_b }
	}
	for (b in 1:B) out[b] <- mean(ym[wm[, b] == 1, b], na.rm = TRUE) - mean(ym[wm[, b] == 0, b], na.rm = TRUE)
	out
}

test_that("with any_censoring TRUE, the resample loop additionally requires an observed event in both arms and a positive minimum response", {
	dead <- rep(1L, f$n); dead[c(3, 7, 11, 19)] <- 0L
	set.seed(21); got <- f$p$compute_fast_bootstrap_distr(60L, f$n, f$y, dead, f$w)
	set.seed(21); ref <- ref_boot_censored(f$n, f$y, f$w, dead, 60L)
	expect_equal(got, ref, tolerance = 1e-12)
	expect_true(all(is.finite(got)))
})

test_that("a design where the event is rare (one dead subject per arm) still resamples until a valid draw is found", {
	y <- c(5, 3, rep(0.5, 8)); w <- c(1L, 0L, rep(0:1, 4)); dead <- c(1L, 1L, rep(0L, 8))
	set.seed(22); got <- f$p$compute_fast_bootstrap_distr(80L, 10L, y, dead, w)
	set.seed(22); ref <- ref_boot_censored(10L, y, w, dead, 80L)
	expect_equal(got, ref, tolerance = 1e-12)
})

test_that("with any_censoring TRUE, a nonpositive response makes every draw fail min(y[i_b]) > 0 and max_resample_attempts exhausts to NaN", {
	unlockBinding("max_resample_attempts", f$p); on.exit(f$p$max_resample_attempts <- 50L, add = TRUE)
	f$p$max_resample_attempts <- 3L
	y_bad <- f$y; y_bad[5] <- -1  # negative response forces min(y[i_b]) > 0 to fail on any draw touching row 5
	dead <- rep(1L, f$n)
	set.seed(23); got <- f$p$compute_fast_bootstrap_distr(40L, f$n, y_bad, dead, f$w)
	set.seed(23); ref <- ref_boot_censored(f$n, y_bad, f$w, dead, 40L, max_attempts = 3L)
	expect_equal(got, ref, tolerance = 1e-12)
	expect_true(any(is.nan(got)))
})
