library(testthat)
library(EDI)

# The "jackknife is never estimable" declaration: the per-class constant
# jackknife_always_nonestimable() (FALSE in the base, TRUE for the Wilcox
# Hodges-Lehmann classes), the registry helper that walks the class hierarchy to find it,
# the suite's method planner that drops the jackknife task for such classes, and the
# Wilcox class's five public jackknife methods (NA plus a cached reason and stage).

Z <- function(x) get(x, envir = asNamespace("EDI"))

wilcox_fx <- function(n = 30L) {
	set.seed(1)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	inf <- InferenceAllSimpleWilcox$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, des = des)
}

test_that("the constant is FALSE by default and TRUE for the Wilcox classes", {
	f <- wilcox_fx()
	expect_true(f$p$jackknife_always_nonestimable())
	ols <- InferenceContinOLS$new(f$des, verbose = FALSE)
	expect_false(ols$.__enclos_env__$private$jackknife_always_nonestimable())
})

test_that("the registry helper resolves the constant through the class hierarchy without constructing objects", {
	h <- Z("inference_class_jackknife_always_nonestimable")
	expect_true(h("InferenceAllSimpleWilcox"))
	expect_true(h("InferenceAllKKWilcoxIVWC"))
	expect_false(h("InferenceContinOLS"))
	expect_false(h("InferenceCountPoisson"))
	expect_false(h("NoSuchClassAnywhere"))                                          # unknown name -> not flagged
})

test_that("the suite drops the jackknife method for always-nonestimable classes and keeps it elsewhere", {
	f <- wilcox_fx()
	plan <- Z("run_all_inference_class_applicable_methods")
	m_all <- c("asymptotic", "jackknife")
	got_w <- plan("InferenceAllSimpleWilcox", m_all, des_obj = f$des)
	expect_false("jackknife" %in% got_w)
	got_o <- plan("InferenceContinOLS", m_all, des_obj = f$des)
	expect_true("jackknife" %in% got_o)
})

test_that("Wilcox jackknife methods return NA and cache the documented reason at the right stage", {
	reason <- "wilcox_hl_jackknife_not_supported"
	f <- wilcox_fx()
	expect_true(is.na(f$inf$compute_jackknife_estimate()))
	expect_true(f$inf$is_nonestimable("estimate")); expect_identical(f$inf$get_nonestimable_reason(), reason)
	g <- wilcox_fx()
	expect_true(is.na(g$inf$compute_jackknife_bias_estimate()))
	expect_true(g$inf$is_nonestimable("estimate")); expect_identical(g$inf$get_nonestimable_reason(), reason)
	for (m in list(function(i) i$compute_jackknife_std_error(), function(i) i$compute_jackknife_wald_two_sided_pval(0.1))) {
		h <- wilcox_fx()
		expect_true(is.na(m(h$inf)))
		expect_true(h$inf$is_nonestimable("se")); expect_false(h$inf$is_nonestimable("estimate"))
		expect_identical(h$inf$get_nonestimable_reason(), reason)
	}
	k <- wilcox_fx()
	ci <- k$inf$compute_jackknife_wald_confidence_interval(0.1)
	expect_length(ci, 2L); expect_true(all(is.na(ci)))
	expect_true(k$inf$is_nonestimable("se"))
	# The unit argument is accepted and ignored.
	expect_true(is.na(wilcox_fx()$inf$compute_jackknife_estimate(unit = "observation")))
})
