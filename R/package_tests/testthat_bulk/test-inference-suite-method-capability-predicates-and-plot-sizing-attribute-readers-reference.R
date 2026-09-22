library(testthat)
library(EDI)

# Two small discovery predicates behind run_all_inference()'s applicable-method filtering, plus four pure attribute-reading / formula helpers behind its CI
# forest plot sizing:
#  * inference_class_has_method(nm, m, des_obj): TRUE iff m is a known CI or p-value sentinel label AND its capability is among the class's effective
#    capabilities; FALSE for an unknown sentinel label even if the class has every capability.
#  * inference_class_supports_bartlett_exact(nm, des_obj): constructs the class on des_obj and reads its private supports_bartlett_likelihood_ratio_exact()
#    predicate, catching any construction error as FALSE (e.g. an unknown class name, or a class/design combination that cannot be built).
#  * run_all_inference_plot_n_rows / _plot_max_label_chars: read an integer attribute off a plot object, defaulting to 0 when absent.
#  * run_all_inference_plot_height_in: the edi_height_in attribute (default 6), capped at 48.
#  * run_all_inference_plot_width_for_label_chars: 3 + 0.09 * chars, floored at 6, capped at 40.

ns <- asNamespace("EDI")
has_method <- get("inference_class_has_method", envir = ns)
supports_bartlett_exact <- get("inference_class_supports_bartlett_exact", envir = ns)
plot_n_rows <- get("run_all_inference_plot_n_rows", envir = ns)
plot_max_label_chars <- get("run_all_inference_plot_max_label_chars", envir = ns)
plot_height_in <- get("run_all_inference_plot_height_in", envir = ns)
plot_width_for_label_chars <- get("run_all_inference_plot_width_for_label_chars", envir = ns)

test_that("inference_class_has_method is TRUE only for a known sentinel whose capability the class has, FALSE for an unknown sentinel", {
	expect_true(has_method("InferenceContinOLS", "wald"))
	expect_false(has_method("InferenceContinOLS", "exact"))                 # a real sentinel this class does not support
	expect_false(has_method("InferenceContinOLS", "not_a_real_sentinel"))   # unknown sentinel label entirely
	ci_spec <- get("EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY", envir = ns)[[1]]
	expect_identical(ci_spec$label, "wald")
})

test_that("inference_class_supports_bartlett_exact reads the class's own private predicate on a real instance and is FALSE by default", {
	set.seed(1); n <- 16L
	d <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	d$add_all_subject_responses(rnorm(n))
	expect_true(supports_bartlett_exact("InferenceContinKKOLSOneLik", d))   # this class overrides the predicate to TRUE
	expect_false(supports_bartlett_exact("InferenceContinOLS", d))         # the default (unset) predicate
})

test_that("inference_class_supports_bartlett_exact catches a construction error and returns FALSE instead of raising", {
	set.seed(2); n <- 10L
	d <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	expect_false(supports_bartlett_exact("NotARealInferenceClass", d))
	expect_false(supports_bartlett_exact("InferenceContinKKOLSOneLik", d))  # wrong design family for this class -> construction fails
})

test_that("plot_n_rows / plot_max_label_chars read their integer attribute and default to 0 when absent", {
	expect_identical(plot_n_rows(structure(list(), edi_n_rows = 5L)), 5L)
	expect_identical(plot_n_rows(list()), 0L)
	expect_identical(plot_n_rows(structure(list(), edi_n_rows = 7)), 7L)     # coerces a double attribute to integer
	expect_identical(plot_max_label_chars(structure(list(), edi_max_label_chars = 12L)), 12L)
	expect_identical(plot_max_label_chars(list()), 0L)
})

test_that("plot_height_in reads edi_height_in, defaults to 6, and is capped at 48", {
	expect_equal(plot_height_in(structure(list(), edi_height_in = 10)), 10)
	expect_equal(plot_height_in(list()), 6)
	expect_equal(plot_height_in(structure(list(), edi_height_in = 100)), 48)
	expect_equal(plot_height_in(structure(list(), edi_height_in = 48)), 48)
})

test_that("plot_width_for_label_chars is 3 + 0.09 * chars, floored at 6 and capped at 40", {
	expect_equal(plot_width_for_label_chars(0), 6)                          # 3 + 0 = 3, floored to 6
	expect_equal(plot_width_for_label_chars(50), 3 + 0.09 * 50)
	expect_equal(plot_width_for_label_chars(1000), 40)                      # 3 + 90 = 93, capped to 40
	expect_equal(plot_width_for_label_chars((40 - 3) / 0.09), 40, tolerance = 1e-8)
})
