library(testthat)
library(EDI)

# InferenceIncidExactZhang's design_compatibility_reason(): requires the design to be either Bernoulli-capable
# (is_a_bernoulli_capable() = TRUE) or KK-matching-capable (is_a_kk_matching_capable() = TRUE); a design that is
# neither is rejected at construction with "Zhang incidence inference requires Bernoulli or matching designs."
# The package-wide generic design_compatibility_reason sweep (test-design-inference-introspection-audit.R) reuses
# one shared incompatible fixture (a Bernoulli incidence design) for every class it checks -- which is itself
# Bernoulli-capable, so it never actually trips THIS class's specific incompatibility branch (its reason comes
# back NA for that fixture, so the sweep's own guard skips asserting exclusion for it). No test anywhere used a
# design that is genuinely neither Bernoulli- nor matching-capable to trigger this class's real rejection path.

test_that("a design that is neither Bernoulli- nor matching-capable is flagged incompatible and rejected at construction", {
	set.seed(1); n <- 20L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	expect_false(des$is_a_bernoulli_capable())
	expect_false(des$is_a_kk_matching_capable())
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))

	reason_fn <- get("infer_inference_design_compatibility_reason_fn", envir = asNamespace("EDI"))(InferenceIncidExactZhang)
	expect_identical(reason_fn(des), "exact_zhang_requires_bernoulli_or_matching_design")
	expect_error(InferenceIncidExactZhang$new(des, verbose = FALSE), "Zhang incidence inference requires Bernoulli or matching designs\\.")
	expect_false("InferenceIncidExactZhang" %in% des$applicable_inference_class_names())
})

test_that("a Bernoulli-capable design is compatible (reason NA) even though it is not matching-capable", {
	set.seed(321); n <- 24L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	for (i in seq_len(n)) des$add_one_subject_response(i, rbinom(1, 1, 0.5))
	expect_true(des$is_a_bernoulli_capable())
	expect_false(des$is_a_kk_matching_capable())

	reason_fn <- get("infer_inference_design_compatibility_reason_fn", envir = asNamespace("EDI"))(InferenceIncidExactZhang)
	expect_true(is.na(reason_fn(des)))
	expect_no_error(InferenceIncidExactZhang$new(des, verbose = FALSE))
	expect_true("InferenceIncidExactZhang" %in% des$applicable_inference_class_names())
})

test_that("a KK matching-capable design is compatible (reason NA) even though it is not Bernoulli-capable", {
	set.seed(6); n <- 22L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_false(des$is_a_bernoulli_capable())
	expect_true(des$is_a_kk_matching_capable())

	reason_fn <- get("infer_inference_design_compatibility_reason_fn", envir = asNamespace("EDI"))(InferenceIncidExactZhang)
	expect_true(is.na(reason_fn(des)))
})
