# Numerical-robustness review audit, 2026-11-18: InferenceOrdinalGCompMeanDiff passes the raw,
# uncentred covariates to fast_ordinal_regression_with_var_cpp / fast_ordinal_regression_cpp and
# never reads fit$converged. With a covariate of mean 1e4, the solver stops early (the kernel's scale
# guard sets converged = FALSE but leaves the params as they are), and the class still builds md and
# its delta-method SE from those params. The g-computation mean difference should not change when a
# covariate is shifted, but here it comes out wrong (or NA). The sibling classes avoid this: PropOdds
# and OrderedProbit go through ordinal_fit_scaled(), and PartialProportionalOdds calls
# center_scale_covariates() and checks converged.
# Where: R/EDI/R/inference_ordinal_gcomp.R:281 (kind: converged_unchecked).
# On commit 4ce2b7126d36 this test failed with: Expected `md_shifted` to equal `md0`. Differences:
# 1/1 mismatches [1] 0.112 - 0.507 == -0.395
# v1.0.6-TODO-393: verified fixed on HEAD 2026-11-22 (this test passes); skip removed.

test_that("ordinal G-comp mean difference is invariant to shifting a covariate's location", {
		gcomp_md_at_shift = function(shift){
			set.seed(1)
			n = 200L
			x1 = rnorm(n) + shift
			des = DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
			des$add_all_subjects_to_experiment(data.frame(x1 = x1))
			des$assign_w_to_all_subjects()
			w = des$get_w()
			lin = -1.2 * w + 0.4 * (x1 - shift)
			y = 1L + rowSums(matrix(runif(n * 3), n, 3) > plogis(outer(lin, c(-1, 0.5, 1.6), "-")))
			des$add_all_subject_responses(y)
			inf = InferenceOrdinalGCompMeanDiff$new(des, model_formula = ~x1, verbose = FALSE)
			suppressWarnings(inf$compute_estimate())
		}
		md0 = gcomp_md_at_shift(0)
		md_shifted = gcomp_md_at_shift(1e4)
		expect_true(is.finite(md0))
		expect_true(is.finite(md_shifted))
		# shifting x1 by a constant is absorbed by the thresholds, so the
		# standardized mean difference must be unchanged
		expect_equal(md_shifted, md0, tolerance = 5e-3)
})
