# Fits every "full"/"partial" likelihood class on simulated data and checks the
# declared parameter_layout (EDI_INFERENCE_LIKELIHOOD_PROPERTIES in
# R/inference_class_registry.R) against the live likelihood test spec. The vector
# from spec$extract_start(spec$full_fit) (or full_fit$params / full_fit$b when the
# spec has no extract_start) must have the declared length, spec$j must
# equal the declared treatment index, and a class declares a layout exactly when it
# exposes a spec.

skip_on_cran()

lik_layout_gen_y = function(rt, w, x1, x2) {
	eta = 0.3 * w + 0.3 * x1 - 0.2 * x2
	switch(rt,
		continuous = 1 + eta + rnorm(1),
		incidence = rbinom(1, 1, plogis(-0.2 + eta)),
		count = rnbinom(1, mu = exp(0.5 + eta), size = 3) * rbinom(1, 1, 0.85),
		proportion = { r = runif(1); if (r < 0.05) 0 else if (r < 0.10) 1 else plogis(eta + rnorm(1, sd = 0.7)) },
		ordinal = { u = runif(1); cs = plogis(c(-1, 0.2, 1.1) - eta); 1L + sum(u > cs) },
		survival = rweibull(1, shape = 1.3, scale = exp(0.2 + eta))
	)
}

lik_layout_make_design = function(rt, kk, n = 120L) {
	x1 = rnorm(n); x2 = rnorm(n)
	if (kk) {
		des = DesignSeqOneByOneKK14$new(n = n, response_type = rt, verbose = FALSE)
		for (i in seq_len(n)) {
			w = des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
			des$add_one_subject_response(i, lik_layout_gen_y(rt, w, x1[i], x2[i]))
		}
	} else {
		des = DesignFixedBernoulli$new(n = n, response_type = rt, verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
		des$assign_w_to_all_subjects()
		w = des$get_w()
		des$add_all_subject_responses(vapply(seq_len(n), function(i) as.numeric(lik_layout_gen_y(rt, w[i], x1[i], x2[i])), numeric(1)))
	}
	des
}

test_that("declared parameter layouts match live likelihood specs", {
	props = EDI:::EDI_INFERENCE_LIKELIHOOD_PROPERTIES
	reg = Filter(function(r) !isTRUE(r$abstract) && r$likelihood_tier %in% c("full", "partial"),
		EDI:::inference_class_registry_as_list())
	for (r in reg) {
		nm = r$name
		set.seed(1)
		des = lik_layout_make_design(r$response_types[1], grepl("KK|Frailty", nm))
		inf = get(nm, envir = asNamespace("EDI"))$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
		inf$compute_estimate()
		pv = inf$.__enclos_env__$private
		spec = if (is.function(pv$get_likelihood_test_spec)) pv$get_likelihood_test_spec() else NULL
		layout = props[[nm]]$parameter_layout
		has_spec = !is.null(spec)
		expect_identical(!is.null(layout), has_spec,
			info = sprintf("%s: layout declared = %s, likelihood spec = %s", nm, !is.null(layout), has_spec))
		if (!has_spec || is.null(layout)) next
		# KK count OneLik specs carry no X; their regression columns are
		# intercept + treatment + x1 + x2.
		p = if (is.matrix(spec$X) && ncol(spec$X) > 0L) ncol(spec$X) else 4L
		K = length(unique(stats::na.omit(as.numeric(pv$y))))
		ev = EDI:::evaluate_likelihood_parameter_layout(layout, p = p, K = K)
		params = if (is.function(spec$extract_start)) spec$extract_start(spec$full_fit) else spec$full_fit$params %||% spec$full_fit$b
		expect_identical(ev$length, length(params), info = paste(nm, "length"))
		expect_identical(ev$treatment_index, as.integer(spec$j), info = paste(nm, "treatment index"))
	}
})
