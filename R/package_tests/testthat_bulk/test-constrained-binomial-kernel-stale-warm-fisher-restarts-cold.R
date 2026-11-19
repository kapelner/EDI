library(testthat)
library(EDI)

# v1.0.6-TODO-209 (2): the constrained binomial kernels (fast_log_binomial_regression.cpp) used a
# supplied warm Fisher information (and, in the weighted kernels, warm working weights) for the first
# Newton step. When that curvature came from a fit on other data (another randomization draw's
# assignment), the line search rejected every step and the kernel returned the warm start unchanged
# with converged = FALSE (~30% of identity-link draws in v1.0.6-TODO-205). The kernel now redoes such a
# fit from the cold start, so it returns exactly what a cold call returns; fits whose warm first step is
# accepted are unchanged. (The R-side cold retry from v1.0.6-TODO-205 stays.) Needs the owner's build.

stale_fisher_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	list(x1 = rnorm(n), w = rbinom(n, 1, 0.5), y = rbinom(n, 1, 0.5))
}

for (link in c("identity", "log")) for (weighted in c(FALSE, TRUE)) local({
	fname <- paste0("fast_", link, "_binomial_regression", if (weighted) "_weighted" else "", "_cpp")
	test_that(paste(fname, "never returns a warm start unchanged after a rejected warm-Fisher step"), {
		kernel <- get(fname, envir = asNamespace("EDI"))
		d <- stale_fisher_fixture()
		n <- length(d$y)
		set.seed(2L)
		wts <- if (weighted) rexp(n) else NULL
		call <- function(X, ...) if (weighted) kernel(X = X, y = d$y, weights = wts, ...) else kernel(X = X, y = d$y, ...)
		obs <- call(cbind(1, d$w, d$x1))
		expect_true(isTRUE(obs$converged))
		set.seed(3L)
		n_restarted <- 0L
		for (b in 1:60) {
			wb <- rbinom(n, 1, 0.5)
			if (sum(wb) %in% c(0L, n)) next
			Xb <- cbind(1, wb, d$x1)
			warm <- call(Xb, warm_start_beta = obs$b, warm_start_fisher_info = obs$fisher_information)
			stalled_at_start <- !isTRUE(warm$converged) && isTRUE(all(as.numeric(warm$b) == as.numeric(obs$b)))
			expect_false(stalled_at_start, info = paste("draw", b))
			if (identical(warm, call(Xb))) n_restarted <- n_restarted + 1L
		}
		expect_gt(n_restarted, 0L)
	})
})
