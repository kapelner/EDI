library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d1f53ee72 (InferenceIncidNewcombeRiskDiff):
# the class ignores any matched-pair structure (unadjusted, independent-sample
# estimator). The "requires an incidence response" claim of the same finding is
# in test-incidence-classes-reject-non-incidence-responses.R.

test_that("Newcombe risk difference on a KK14 matched design equals the unpaired Newcombe reference from w and y", {
	set.seed(1); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	# the design really has matched pairs
	expect_true(any(as.integer(des$.__enclos_env__$private$m) > 0L))

	w <- des$get_w(); y <- des$get_y()
	x_t <- sum(y[w == 1]); n_t <- sum(w == 1); x_c <- sum(y[w == 0]); n_c <- sum(w == 0)
	# independent Wilson / Newcombe Method 10 reference
	wilson <- function(x, n, z) {
		p <- x / n
		ctr <- p + z^2 / (2 * n); adj <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))
		(c(ctr - adj, ctr + adj)) / (1 + z^2 / n)
	}
	for (alpha in c(0.05, 0.2)) {
		z <- qnorm(1 - alpha / 2)
		lt <- wilson(x_t, n_t, z); lc <- wilson(x_c, n_c, z)
		pt <- x_t / n_t; pc <- x_c / n_c
		ref <- c(pt - pc - sqrt((pt - lt[1])^2 + (lc[2] - pc)^2),
		         pt - pc + sqrt((lt[2] - pt)^2 + (pc - lc[1])^2))
		inf <- InferenceIncidNewcombeRiskDiff$new(des, verbose = FALSE)
		expect_equal(inf$compute_estimate(), pt - pc, tolerance = 1e-12)
		expect_equal(unname(inf$compute_asymp_confidence_interval(alpha = alpha)), ref, tolerance = 1e-8)
	}
})
