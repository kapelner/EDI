# v1.0.6-TODO-76: two separation gaps left by v1.0.6-TODO-72.
# (1) InferenceOrdinalKKGEE has its own ordLORgee dispatch, so the TODO-118 check
#     never ran: with every treated subject in the top category its asymptotic CI
#     was (21.33, 25.80) and p ~ 1e-95, silently. Now it warns once
#     (edi_logistic_separation_warning) and the asymptotic p-value / CI are NA.
# (2) The KK GEE jackknife on a separated design returned finite nonsense
#     (incidence: jackknife estimate -384, SE 434, p 0.38) with no warning. The
#     jackknife driver now returns NA (reason "jackknife_full_data_separation")
#     with a warning when the full-data fit is separated.
# Point estimates (compute_estimate()) are unchanged throughout.

make_kk14_design_122 = function(response_type, y_fun, n = 40, seed = 1) {
	set.seed(seed)
	des = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	des$add_all_subject_responses(y_fun(des$get_w()))
	des
}

collect_warnings_122 = function(expr) {
	classes = character()
	messages = character()
	value = withCallingHandlers(expr, warning = function(w) {
		classes <<- c(classes, class(w)[1L])
		messages <<- c(messages, conditionMessage(w))
		invokeRestart("muffleWarning")
	})
	list(value = value, classes = classes, messages = messages)
}

separated_ordinal_y = function(w) ifelse(w == 1, 4, sample(1:4, length(w), replace = TRUE))

test_that("InferenceOrdinalKKGEE warns once and returns NA Wald results under separation", {
	skip_if_not_installed("multgee")
	des = make_kk14_design_122("ordinal", separated_ordinal_y)
	expect_true(all(des$get_y()[des$get_w() == 1] == 4))
	inf = InferenceOrdinalKKGEE$new(des)
	res = collect_warnings_122(list(
		est = inf$compute_estimate(),
		p = inf$compute_asymp_two_sided_pval(),
		ci = inf$compute_asymp_confidence_interval(),
		est2 = inf$compute_estimate()
	))
	expect_identical(sum(res$classes == "edi_logistic_separation_warning"), 1L)
	expect_true(is.na(res$value$p))
	expect_true(all(is.na(res$value$ci)))
	expect_true(is.finite(res$value$est))
	expect_gt(abs(res$value$est), 10)
	expect_identical(res$value$est, res$value$est2)
	expect_true(inf$is_nonestimable("se"))
})

test_that("InferenceOrdinalKKGEE gives no separation warning and finite Wald results on ordinary data", {
	skip_if_not_installed("multgee")
	des = make_kk14_design_122("ordinal", function(w) sample(1:4, length(w), replace = TRUE), seed = 2)
	inf = InferenceOrdinalKKGEE$new(des)
	res = collect_warnings_122(list(p = inf$compute_asymp_two_sided_pval(), ci = inf$compute_asymp_confidence_interval()))
	expect_false("edi_logistic_separation_warning" %in% res$classes)
	expect_true(is.finite(res$value$p))
	expect_true(all(is.finite(res$value$ci)))
})

test_that("KK GEE jackknife returns NA with a reason when the full-data fit is separated", {
	skip_if_not_installed("geepack")
	des = make_kk14_design_122("incidence", function(w) ifelse(w == 1, 1, rbinom(length(w), 1, 0.4)))
	inf = InferenceIncidKKGEE$new(des)
	res = collect_warnings_122(list(
		p = inf$compute_jackknife_wald_two_sided_pval(),
		ci = inf$compute_jackknife_wald_confidence_interval(),
		jest = inf$compute_jackknife_estimate(),
		est = inf$compute_estimate()
	))
	expect_true(is.na(res$value$p))
	expect_true(all(is.na(res$value$ci)))
	expect_true(is.na(res$value$jest))
	expect_true(is.finite(res$value$est))
	expect_gt(abs(res$value$est), 10)
	# one separation warning for the object, plus one NA warning per jackknife call
	expect_identical(sum(res$classes == "edi_logistic_separation_warning"), 1L)
	na_msgs = res$messages[res$classes == "edi_procedure_na_warning"]
	expect_length(na_msgs, 3L)
	expect_true(all(grepl("jackknife_full_data_separation", na_msgs, fixed = TRUE)))

	# a fresh object asked only for the jackknife still sees the separation
	inf2 = InferenceIncidKKGEE$new(des)
	res2 = collect_warnings_122(inf2$compute_jackknife_wald_two_sided_pval())
	expect_true(is.na(res2$value))
	expect_identical(sum(res2$classes == "edi_logistic_separation_warning"), 1L)
	expect_true(any(grepl("jackknife_full_data_separation", res2$messages, fixed = TRUE)))
})

test_that("InferenceOrdinalKKGEE SE path still fits after an estimate-only fit on separated data", {
	# The estimate-only fit leaves a warm start at the diverged solution, from
	# which ordLORgee can fail; the SE path used to return a silent NA fit.
	skip_if_not_installed("multgee")
	des = make_kk14_design_122("ordinal", separated_ordinal_y)
	inf = InferenceOrdinalKKGEE$new(des)
	est = inf$compute_estimate(estimate_only = TRUE)
	res = collect_warnings_122(inf$compute_asymp_two_sided_pval())
	expect_true(is.na(res$value))
	expect_identical(sum(res$classes == "edi_logistic_separation_warning"), 1L)
	expect_identical(inf$.__enclos_env__$private$cached_values$nonestimable_reason, "ordinal_kk_gee_separation")
	expect_equal(inf$compute_estimate(), est, tolerance = 1e-6)
})

test_that("InferenceOrdinalKKGEE jackknife returns NA with the separation reason", {
	skip_if_not_installed("multgee")
	des = make_kk14_design_122("ordinal", separated_ordinal_y)
	inf = InferenceOrdinalKKGEE$new(des)
	res = collect_warnings_122(inf$compute_jackknife_wald_two_sided_pval())
	expect_true(is.na(res$value))
	expect_true(any(grepl("jackknife_full_data_separation", res$messages, fixed = TRUE)))
})

test_that("KK GEE jackknife is unaffected on ordinary data, and the Poisson KK GEE never reports separation", {
	skip_if_not_installed("geepack")
	des = make_kk14_design_122("incidence", function(w) rbinom(length(w), 1, ifelse(w == 1, 0.6, 0.4)))
	inf = InferenceIncidKKGEE$new(des)
	res = collect_warnings_122(inf$compute_jackknife_wald_two_sided_pval())
	expect_false("edi_logistic_separation_warning" %in% res$classes)
	expect_false(any(grepl("jackknife_full_data_separation", res$messages, fixed = TRUE)))
	expect_false(isTRUE(inf$.__enclos_env__$private$jackknife_full_fit_is_separated()))

	des_c = make_kk14_design_122("count", function(w) rpois(length(w), ifelse(w == 1, 4, 2)))
	inf_c = InferenceCountPoissonKKGEE$new(des_c)
	expect_false(isTRUE(inf_c$.__enclos_env__$private$jackknife_full_fit_is_separated()))
})
