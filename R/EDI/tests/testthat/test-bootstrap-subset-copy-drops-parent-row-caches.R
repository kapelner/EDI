# v1.0.6-TODO-131: bootstrap_subset_inference() builds the slow-path subset refit by
# duplicating the Inference object and its design, then subsetting the per-subject fields
# it knows about. Two gaps:
# (1) The design copy kept the parent's n-row y_L / y_R / y_original. get_effective_time()
#     then paired the subset's y with the parent's y_L, assert_all_responses_recorded() and
#     duplicate() failed on the copy, and the rand-bootstrap slow path copied the parent's
#     y_L / y_R into the subset Inference on interval-censored data (all-NA Weibull and
#     log-rank null distributions, wrong KM-difference draws).
# (2) Any other private cache holding the parent's rows (za_X_cov_all was the
#     v1.0.6-TODO-126 case) survived into the copy. A generic guard now clears every
#     remaining private field with the parent's NROW.

subset_copy_survival_design = function(n = 60L, interval = FALSE){
	set.seed(2)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	des = DesignFixedBernoulli$new(response_type = "survival", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	t_true = rexp(n, exp(-1 - 0.8 * w + 0.5 * X$x1))
	kind = sample(c("exact", if (interval) "interval", "right"), n, replace = TRUE)
	y = ifelse(kind == "exact", t_true, NA_real_)
	y_L = ifelse(kind == "interval", t_true * 0.7, ifelse(kind == "right", t_true * 0.8, NA_real_))
	y_R = ifelse(kind == "interval", t_true * 1.3, ifelse(kind == "right", Inf, NA_real_))
	des$add_all_subject_responses(y, y_L, y_R)
	des
}

subset_copy_glm_design = function(response_type, n = 60L){
	set.seed(11)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	des = DesignFixedBernoulli$new(response_type = response_type, n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	eta = 0.5 * des$get_w() + 0.6 * X$x1 - 0.4 * X$x2
	des$add_all_subject_responses(switch(response_type,
		incidence = rbinom(n, 1, plogis(eta)),
		count = rpois(n, exp(0.3 + 0.5 * eta))))
	des
}

test_that("a subset copy's design carries the draw's y_L / y_R / y_original", {
	des = subset_copy_survival_design()
	inf = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE, model_formula = ~ x1 + x2)
	p = inf$.__enclos_env__$private
	for (i_b in list(sort(sample.int(60L, 60L, replace = TRUE)), sort(sample.int(60L, 51L)))) {
		sub = p$bootstrap_subset_inference(list(i_b = i_b, m_vec_b = NULL))
		sub_des = sub$.__enclos_env__$private$des_obj
		expect_identical(sub_des$get_y_L(), as.numeric(des$get_y_L()[i_b]))
		expect_identical(sub_des$get_y_R(), as.numeric(des$get_y_R()[i_b]))
		expect_identical(length(sub_des$get_y_original()), length(i_b))
		expect_equal(sub_des$get_effective_time(), des$get_effective_time()[i_b])
		expect_equal(sub_des$get_effective_time(), sub$.__enclos_env__$private$y)
		expect_silent(sub_des$assert_all_responses_recorded())
		expect_s3_class(sub_des$duplicate(verbose = FALSE), "Design")
	}
})

test_that("the rand-bootstrap slow path matches the reusable worker on interval-censored data", {
	des = subset_copy_survival_design(interval = TRUE)
	skipped = character(0)
	for (cls in c("InferenceSurvivalWeibullRegr", "InferenceSurvivalKMDiff", "InferenceSurvivalLogRank")) {
		# v1.0.6-TODO-180: skip a class whose interval-censored fit needs an absent Suggests package
		missing_pkg = general_censoring_missing_package(cls, des)
		if (length(missing_pkg)) { skipped[[cls]] = missing_pkg; next }
		draws = lapply(c(TRUE, FALSE), function(worker){
			inf = suppressWarnings(get(cls)$new(des, verbose = FALSE, model_formula = ~ x1 + x2))
			inf$.__enclos_env__$private$reusable_bootstrap_worker_enabled = worker
			set.seed(4)
			suppressWarnings(inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 8, show_progress = FALSE))
		})
		expect_true(all(is.finite(draws[[2]])), info = cls)
		expect_equal(draws[[2]], draws[[1]], tolerance = 1e-6, info = cls)
	}
	skip_inference_fixtures_missing_packages(skipped)
})

test_that("no private field of a subset copy keeps the parent's rows", {
	cases = list(
		list(cls = "InferenceIncidLogRegr", des = subset_copy_glm_design("incidence")),
		list(cls = "InferenceCountPoisson", des = subset_copy_glm_design("count")),
		list(cls = "InferenceCountZeroInflatedPoisson", des = subset_copy_glm_design("count")),
		list(cls = "InferenceSurvivalCoxPHRegr", des = subset_copy_survival_design()),
		list(cls = "InferenceSurvivalStratCoxPHRegr", des = subset_copy_survival_design())
	)
	for (case in cases) {
		inf = suppressWarnings(get(case$cls)$new(case$des, verbose = FALSE, model_formula = ~ x1 + x2))
		suppressWarnings(inf$compute_estimate())
		suppressWarnings(try(inf$compute_asymp_confidence_interval(), silent = TRUE))
		p = inf$.__enclos_env__$private
		# As inside the public bootstrap: the copy then uses the resampling warm-start
		# policy instead of starting from the parent's full-data fit.
		p$active_resampling_operation = "non_param_boot"
		set.seed(5)
		for (i_b in list(sample.int(60L, 60L, replace = TRUE), sort(sample.int(60L, 51L)))) {
			sub = p$bootstrap_subset_inference(list(i_b = i_b, m_vec_b = NULL))
			sp = sub$.__enclos_env__$private
			for (field in setdiff(ls(sp, all.names = TRUE), EDI:::EDI_SUBSET_COPY_ROW_FIELDS)) {
				if (bindingIsActive(field, sp)) next
				x = get(field, envir = sp)
				if (is.function(x) || is.environment(x) || is.character(x)) next
				expect_false(
					(is.numeric(x) || is.logical(x) || is.matrix(x) || is.data.frame(x)) && NROW(x) == 60L,
					info = paste(case$cls, field, "kept the parent's rows"))
			}
			theta_slow = suppressWarnings(as.numeric(sub$compute_estimate())[1L])
			fresh = suppressWarnings(get(case$cls)$new(sp$des_obj$duplicate(verbose = FALSE), verbose = FALSE, model_formula = ~ x1 + x2))
			expect_equal(theta_slow, suppressWarnings(as.numeric(fresh$compute_estimate())[1L]), tolerance = 1e-6, info = case$cls)
		}
	}
})

test_that("clear_parent_row_private_caches clears row caches and keeps everything else", {
	env = new.env()
	env$X = matrix(0, 10, 2)
	env$stale_matrix = matrix(0, 10, 3)
	env$stale_vector = rnorm(10)
	env$stale_nested = list(mode = "unweighted", X = matrix(0, 10, 2))
	env$stale_deep = list(a = list(ids = 1:10))
	env$labels = letters[1:10]
	env$params = rnorm(3)
	env$fisher = diag(3)
	env$fn = function() 1
	cleared = EDI:::clear_parent_row_private_caches(env, n_parent = 10L)
	expect_setequal(cleared, c("stale_matrix", "stale_vector", "stale_nested", "stale_deep"))
	for (k in cleared) expect_null(env[[k]])
	expect_identical(dim(env$X), c(10L, 2L))
	expect_identical(env$labels, letters[1:10])
	expect_length(env$params, 3L)
	expect_true(is.function(env$fn))
	expect_identical(EDI:::clear_parent_row_private_caches(env, n_parent = 1L), character())
})
