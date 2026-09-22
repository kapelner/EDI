library(testthat)
library(EDI)

# inference_custom_extensions.R's InferenceCustomAsymp/Rand/Boot each declare a private
# type-marker predicate (is_a_custom_asymp/is_a_custom_rand/is_a_custom_boot, always
# returning TRUE) but none has any caller anywhere in the source (confirmed via
# repo-wide grep) and none had any test reference anywhere -- unlike other classes'
# analogous is_a_* markers (e.g. is_a_exact, is_a_kk_modified_poisson), which existing
# callers/tests exercise indirectly. These three are declarative-only, so the only
# thing worth pinning is the contract itself: each concrete class's own predicate
# exists, is callable, and returns TRUE -- plus that a class does NOT also answer TRUE
# for a sibling custom-extension base it doesn't inherit from.

make_custom_fixture = function(base_class_name) {
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	base_class = getFromNamespace(base_class_name, "EDI")
	assign(base_class_name, base_class, envir = ext_env)
	eval(
		bquote({
			Cls = R6Class("Cls", inherit = .(as.name(base_class_name)), lock_objects = FALSE,
				public = list(fit = function(estimate_only = FALSE) list(estimate = 1)))
		}),
		envir = ext_env
	)

	des = DesignFixedBernoulli$new(n = 10, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(10)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 5))
	des$add_all_subject_responses(1:10)
	ext_env$Cls$new(des, verbose = FALSE)
}

test_that("InferenceCustomAsymp's is_a_custom_asymp() exists, is callable, and returns TRUE", {
	inf = make_custom_fixture("InferenceCustomAsymp")
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_custom_asymp))
	expect_identical(priv$is_a_custom_asymp(), TRUE)
	expect_null(priv$is_a_custom_rand)
	expect_null(priv$is_a_custom_boot)
})

test_that("InferenceCustomRand's is_a_custom_rand() exists, is callable, and returns TRUE", {
	inf = make_custom_fixture("InferenceCustomRand")
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_custom_rand))
	expect_identical(priv$is_a_custom_rand(), TRUE)
	expect_null(priv$is_a_custom_asymp)
	expect_null(priv$is_a_custom_boot)
})

test_that("InferenceCustomBoot's is_a_custom_boot() exists, is callable, and returns TRUE", {
	inf = make_custom_fixture("InferenceCustomBoot")
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_custom_boot))
	expect_identical(priv$is_a_custom_boot(), TRUE)
	expect_null(priv$is_a_custom_asymp)
	expect_null(priv$is_a_custom_rand)
})
