library(testthat)
library(EDI)

# Five otherwise-unrelated C++ likelihood kernels share the identical warm_start_params guard shape:
# if a caller-supplied warm_start_params vector doesn't match the model's own parameter count, stop
# with "warm_start_params size mismatch" -- fast_clogit_plus_glmm_cpp() (fast_clogit_plus_glmm.cpp),
# fast_cpoisson_combined_with_var_cpp() (fast_cpoisson_combined.cpp),
# fast_adjacent_category_logit_cpp() (fast_adjacent_category_logit.cpp), fast_stereotype_logit_cpp()
# and fast_stereotype_profile_loglik_cpp() (fast_stereotype_logit.cpp). A codebase-wide grep confirmed
# this exact message had zero test references anywhere, despite all 5 functions being otherwise
# well-tested elsewhere (2-9 references each) -- every existing reference either omits
# warm_start_params entirely or supplies one of the correct length. Reached by calling each kernel
# directly with a deliberately wrong-length warm_start_params vector against a real, minimal fixture.

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("fast_clogit_plus_glmm_cpp() rejects a wrong-length warm_start_params", {
	set.seed(1)
	G <- 20L; m <- 4L; n <- G * m
	g <- rep(seq_len(G), each = m); w <- rbinom(n, 1, 0.5); x <- rnorm(n)
	X <- cbind(1, w, x)
	y <- rbinom(n, 1, plogis(X %*% c(-0.2, 0.7, 0.3)))
	expect_error(
		K("fast_clogit_plus_glmm_cpp")(matrix(0, 0, 3), numeric(0), X, as.numeric(y), as.integer(g), FALSE, TRUE, warm_start_params = c(1, 2)),
		"warm_start_params size mismatch",
		fixed = TRUE
	)
})

test_that("fast_cpoisson_combined_with_var_cpp() rejects a wrong-length warm_start_params", {
	set.seed(8)
	Kp <- 25L; nr <- 40L
	Xd <- matrix(rnorm(Kp * 2), Kp, 2); nk <- rpois(Kp, 4) + 1L
	yT <- rbinom(Kp, nk, plogis(0.3 + Xd %*% c(0.2, -0.1)))
	Xr <- matrix(rnorm(nr * 2), nr, 2); wr <- rbinom(nr, 1, 0.5)
	yr <- rpois(nr, exp(0.5 + 0.3 * wr + Xr %*% c(0.2, -0.1)))
	expect_error(
		K("fast_cpoisson_combined_with_var_cpp")(as.numeric(yT), as.numeric(nk), Xd, as.numeric(yr), as.numeric(wr), Xr, warm_start_params = c(1, 2)),
		"warm_start_params size mismatch",
		fixed = TRUE
	)
})

test_that("fast_adjacent_category_logit_cpp() and fast_stereotype_logit_cpp() both reject a wrong-length warm_start_params", {
	X <- cbind(1, rnorm(20))
	y <- as.numeric(factor(sample(1:3, 20, replace = TRUE), levels = 1:3, ordered = TRUE))
	expect_error(
		EDI:::fast_adjacent_category_logit_cpp(X, y, warm_start_params = c(1, 2)),
		"warm_start_params size mismatch",
		fixed = TRUE
	)
	expect_error(
		EDI:::fast_stereotype_logit_cpp(X, y, warm_start_params = c(1, 2)),
		"warm_start_params size mismatch",
		fixed = TRUE
	)
})

test_that("fast_stereotype_profile_loglik_cpp() rejects a wrong-length warm_start_params", {
	X <- cbind(1, rnorm(20))
	y <- as.numeric(factor(sample(1:3, 20, replace = TRUE), levels = 1:3, ordered = TRUE))
	expect_error(
		EDI:::fast_stereotype_profile_loglik_cpp(X, y, beta_fixed = 0.5, warm_start_params = c(1, 2)),
		"warm_start_params size mismatch",
		fixed = TRUE
	)
})
