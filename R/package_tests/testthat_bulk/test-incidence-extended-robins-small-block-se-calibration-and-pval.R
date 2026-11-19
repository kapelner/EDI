library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-dc16c3b9a (InferenceIncidExtendedRobins):
#   - with matched pairs the SE is anti-conservative (about 0.68 of the true SD,
#     5% Wald size about 0.14-0.18), while with blocks of about 10 it is conservative;
#   - compute_asymp_two_sided_pval() is the z-test 2 * pnorm(-|(est - delta) / se|)
#     with default delta = 0.

robins_blocked_design <- function(n, block_size, seed, p = 0.4) {
	set.seed(seed)
	des <- DesignFixedBlocking$new(n = n, response_type = "incidence",
		m = rep(seq_len(n / block_size), each = block_size), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, p))
	des
}

test_that("Extended Robins p-value is the normal z-test at delta = 0 (default) and at a nonzero delta", {
	des <- robins_blocked_design(40L, 4L, 1L)
	inf <- InferenceIncidExtendedRobins$new(des, verbose = FALSE)
	est <- inf$compute_estimate()
	se <- inf$.__enclos_env__$private$get_standard_error()
	expect_true(is.finite(se) && se > 0)
	expect_equal(inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(est / se)), tolerance = 1e-12)
	expect_identical(inf$compute_asymp_two_sided_pval(), inf$compute_asymp_two_sided_pval(delta = 0))
	for (d in c(0.1, -0.25)) {
		expect_equal(inf$compute_asymp_two_sided_pval(delta = d), 2 * pnorm(-abs((est - d) / se)), tolerance = 1e-12, info = format(d))
	}
})

test_that("Extended Robins SE is anti-conservative on matched pairs and conservative with blocks of 10 (null Monte Carlo)", {
	# The class SE is the C++ kernel compute_extended_robins_block_se_cpp(); check
	# that once on a real object, then run the Monte Carlo on the kernel directly.
	des <- robins_blocked_design(20L, 2L, 3L)
	inf <- InferenceIncidExtendedRobins$new(des, verbose = FALSE)
	expect_equal(inf$.__enclos_env__$private$get_standard_error(),
		compute_extended_robins_block_se_cpp(des$get_y(), 2 * des$get_w() - 1, des$get_block_ids(), 20L),
		tolerance = 1e-12)

	sim <- function(block_size, R = 200L, n = 200L, p = 0.4, seed = 1L) {
		set.seed(seed)
		blk <- rep(seq_len(n / block_size), each = block_size)
		est <- se <- numeric(R)
		for (r in seq_len(R)) {
			w <- as.vector(vapply(seq_len(n / block_size), function(b) sample(rep(0:1, block_size / 2)), numeric(block_size)))
			y <- rbinom(n, 1, p)
			est[r] <- mean(y[w == 1]) - mean(y[w == 0])
			se[r] <- compute_extended_robins_block_se_cpp(y, 2 * w - 1, blk, n)
		}
		c(ratio = mean(se) / sd(est), size = mean(abs(est / se) > qnorm(0.975)))
	}
	pairs <- sim(2L)
	tens <- sim(10L)
	# pairs: SE about 0.7 of the SD and an inflated 5% Wald size
	expect_lt(pairs[["ratio"]], 0.8)
	expect_gt(pairs[["ratio"]], 0.6)
	expect_gt(pairs[["size"]], 0.09)
	# blocks of 10: conservative
	expect_gte(tens[["ratio"]], 0.95)
	expect_lte(tens[["size"]], 0.06)
})
