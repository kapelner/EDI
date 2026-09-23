library(testthat)
library(EDI)

# contracts_mixins.R's define_inference_class() rejects any lock_objects value other than FALSE
# ("define_inference_class() must keep `lock_objects = FALSE` until the R6 tree is stable."). The
# identically-shaped design-side sibling (define_design_class()'s own lock_objects guard) is already
# covered by test-design-class-factory.R's "define_design_class() rejects lock_objects other than
# FALSE" test, but the inference-side guard had zero test references anywhere.

test_that("define_inference_class() rejects lock_objects other than FALSE", {
	expect_error(
		EDI:::define_inference_class(classname = "InferenceTemporaryLockedHostProbe", lock_objects = TRUE),
		"define_inference_class\\(\\) must keep `lock_objects = FALSE` until the R6 tree is stable\\."
	)
})
