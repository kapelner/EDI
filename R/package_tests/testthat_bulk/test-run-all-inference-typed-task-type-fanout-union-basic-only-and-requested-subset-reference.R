library(testthat)
library(EDI)

# run_all_inference_class_typed_task_types(nm, des_obj, params, sentinel, requested_types, basic_only): for a TYPED sentinel ("bootstrap" / "bayes_boot" /
# "rand_bootstrap") it is union(class$get_supported_<sentinel>_ci_types(), class$get_supported_<sentinel>_pval_types()) -- an independent R union() of the
# class's own two accessor calls is the reference -- intersected with requested_types when given (NULL means every type), restricted to just the first
# available type when basic_only = TRUE and requested_types is NULL (requested_types, when given, always wins over basic_only). A non-typed sentinel (e.g.
# "wald") always returns character(0). An unrecognized class name raises (get_effective_capabilities() errors before the per-class tryCatch is reached).

ns <- asNamespace("EDI")
typed_types <- get("run_all_inference_class_typed_task_types", envir = ns)
set.seed(1); n <- 10L
d <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
inf <- InferenceContinOLS$new(d, verbose = FALSE)
ci_types <- inf$get_supported_bootstrap_ci_types(); pval_types <- inf$get_supported_bootstrap_pval_types()
ref_union <- union(ci_types, pval_types)

test_that("with requested_types = NULL, the result is exactly union(ci types, pval types), with independent nonempty accessor outputs", {
	expect_gt(length(ci_types), 0L); expect_gt(length(pval_types), 0L)
	expect_true("bca" %in% ci_types && "bca" %in% pval_types)                              # at least one type is on both sides
	expect_true("smoothed" %in% ci_types && !("smoothed" %in% pval_types))                 # and at least one is CI-only, one pval-only
	expect_true("symmetric" %in% pval_types && !("symmetric" %in% ci_types))
	expect_identical(typed_types("InferenceContinOLS", d, list(), "bootstrap", NULL), ref_union)
})

test_that("a requested subset is intersected with the available union; an unavailable requested type drops to character(0)", {
	expect_identical(typed_types("InferenceContinOLS", d, list(), "bootstrap", c("bca")), "bca")
	expect_identical(typed_types("InferenceContinOLS", d, list(), "bootstrap", c("bca", "smoothed")), intersect(c("bca", "smoothed"), ref_union))
	expect_identical(typed_types("InferenceContinOLS", d, list(), "bootstrap", "not_a_real_type"), character(0))
})

test_that("basic_only = TRUE restricts to the union's first element only when requested_types is NULL; an explicit request always wins over basic_only", {
	expect_identical(typed_types("InferenceContinOLS", d, list(), "bootstrap", NULL, basic_only = TRUE), ref_union[1])
	expect_identical(typed_types("InferenceContinOLS", d, list(), "bootstrap", c("bca"), basic_only = TRUE), "bca")
})

test_that("a non-typed sentinel always returns character(0), regardless of requested_types or basic_only", {
	expect_identical(typed_types("InferenceContinOLS", d, list(), "wald", NULL), character(0))
	expect_identical(typed_types("InferenceContinOLS", d, list(), "wald", c("bca")), character(0))
	expect_identical(typed_types("InferenceContinOLS", d, list(), "not_a_typed_sentinel_at_all", NULL, basic_only = TRUE), character(0))
})

test_that("an unrecognized class name raises (class metadata is consulted before the per-class error catch)", {
	expect_error(typed_types("NotARealInferenceClass", d, list(), "bootstrap", NULL), "No inference class metadata registered")
})
