library(testthat)
library(EDI)

# InferenceCustomRand and InferenceCustomBoot each have their own compute_estimate()
# with the same result-list validation and nonestimable_reason propagation logic
# as InferenceCustomAsymp (covered separately in
# test-custom-extension-fit-contract-validation-and-caching.R), but as distinct
# code (not shared via a common private helper -- each class's compute_estimate
# reimplements the check). Confirmed via repo-wide grep these two classes' own
# validation branches had zero test references anywhere.

make_custom_fixture = function(base_class_name, fit_fn) {
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	base_class = getFromNamespace(base_class_name, "EDI")
	assign(base_class_name, base_class, envir = ext_env)
	ext_env$fit_fn = fit_fn
	eval(
		bquote({
			Cls = R6Class("Cls", inherit = .(as.name(base_class_name)), lock_objects = FALSE,
				public = list(fit = function(estimate_only = FALSE) fit_fn(estimate_only)))
		}),
		envir = ext_env
	)

	des = DesignFixedBernoulli$new(n = 20, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
	des$add_all_subject_responses(c(1:10, 12:21))
	ext_env$Cls$new(des, verbose = FALSE)
}

for (cls in c("InferenceCustomRand", "InferenceCustomBoot")) {
	local({
		cls_name = cls

		test_that(paste0(cls_name, "$compute_estimate() errors when fit() returns something other than a list"), {
			inf = make_custom_fixture(cls_name, function(estimate_only) 5)
			expect_error(inf$compute_estimate(), "must include numeric scalar 'estimate'")
		})

		test_that(paste0(cls_name, "$compute_estimate() errors when fit()'s list is missing a scalar 'estimate'"), {
			inf_missing = make_custom_fixture(cls_name, function(estimate_only) list(se = 1))
			expect_error(inf_missing$compute_estimate(), "must include numeric scalar 'estimate'")

			inf_vector = make_custom_fixture(cls_name, function(estimate_only) list(estimate = c(1, 2)))
			expect_error(inf_vector$compute_estimate(), "must include numeric scalar 'estimate'")
		})

		test_that(paste0(cls_name, ": a non-finite estimate is recorded nonestimable with the default reason when none supplied"), {
			inf = make_custom_fixture(cls_name, function(estimate_only) list(estimate = NA_real_))
			expect_true(is.na(suppressWarnings(inf$compute_estimate())))
			expect_true(inf$is_nonestimable())
			expect_equal(inf$get_nonestimable_reason(), "custom_estimate_unavailable")
		})

		test_that(paste0(cls_name, ": a non-finite estimate propagates a caller-supplied nonestimable_reason"), {
			inf = make_custom_fixture(cls_name, function(estimate_only) {
				list(estimate = NaN, nonestimable_reason = "my_custom_reason")
			})
			suppressWarnings(inf$compute_estimate())
			expect_true(inf$is_nonestimable())
			expect_equal(inf$get_nonestimable_reason(), "my_custom_reason")
		})

		test_that(paste0(cls_name, ": compute_estimate(estimate_only=TRUE) caches and short-circuits a second call"), {
			call_count = 0
			inf = make_custom_fixture(cls_name, function(estimate_only) {
				call_count <<- call_count + 1
				list(estimate = 9)
			})
			expect_equal(inf$compute_estimate(estimate_only = TRUE), 9)
			expect_equal(call_count, 1L)
			expect_equal(inf$compute_estimate(estimate_only = TRUE), 9)
			expect_equal(call_count, 1L)
		})
	})
}
