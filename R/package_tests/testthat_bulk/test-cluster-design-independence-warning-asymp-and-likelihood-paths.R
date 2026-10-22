library(testthat)
suppressMessages(pkgload::load_all("/home/kapelner/workspace/EDI/R/EDI", compile = FALSE, quiet = TRUE))

# TODO-103 interim warning: classes whose Wald SE / likelihood-based procedures treat
# subjects as independent warn ONCE per object per procedure family on cluster designs.

cls = "edi_cluster_independence_warning"

make_cluster_des_rt = function(response_type, G = 20L, m = 10L, seed = 3L, Design = DesignFixedCluster){
	set.seed(seed)
	n = G * m
	cl = rep(seq_len(G), each = m)
	u = rnorm(G, sd = 0.5)[cl]
	X = data.frame(pretest = rnorm(n), school = factor(cl))
	des = Design$new(n = n, response_type = response_type, cluster_col = "school", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	eta = 0.3 * w + 0.3 * X$pretest + u
	if (response_type == "continuous") des$add_all_subject_responses(eta + rnorm(n))
	if (response_type == "incidence") des$add_all_subject_responses(rbinom(n, 1, plogis(eta)))
	if (response_type == "count") des$add_all_subject_responses(rpois(n, exp(eta)))
	if (response_type == "survival") des$add_all_subject_responses(rexp(n, exp(eta)) + 0.01)
	if (response_type == "ordinal") des$add_all_subject_responses(as.integer(cut(eta + rlogis(n), c(-Inf, -0.5, 0.5, 1.5, Inf))))
	if (response_type == "proportion") des$add_all_subject_responses(plogis(eta + rnorm(n, sd = 0.5)))
	des
}

count_cluster_warnings = function(expr) {
	n = 0L
	withCallingHandlers(
		suppressMessages(expr),
		warning = function(w) {
			if (inherits(w, cls)) { n <<- n + 1L; invokeRestart("muffleWarning") }
		}
	)
	n
}

test_that("Wald inference warns exactly once per object on a cluster design (logit, Poisson, Cox)", {
	for (spec in list(c("incidence", "InferenceIncidLogRegr"), c("count", "InferenceCountPoisson"), c("survival", "InferenceSurvivalCoxPHRegr"))) {
		cls_gen = tryCatch(get(spec[2]), error = function(e) NULL)
		skip_if(is.null(cls_gen), paste("class not found:", spec[2]))
		inf = cls_gen$new(make_cluster_des_rt(spec[1]))
		n1 = count_cluster_warnings({
			inf$compute_asymp_confidence_interval()
			inf$compute_asymp_two_sided_pval()
			inf$compute_asymp_confidence_interval(alpha = 0.1)
		})
		expect_equal(n1, 1L, info = spec[2])
	}
})

test_that("the cluster-independence warning names the cluster-aware routes and is suppressible by class", {
	inf = InferenceIncidLogRegr$new(make_cluster_des_rt("incidence"))
	w = tryCatch(inf$compute_asymp_two_sided_pval(), warning = function(w) w)
	expect_s3_class(w, cls)
	expect_match(conditionMessage(w), "compute_rand_two_sided_pval", fixed = TRUE)
	expect_match(conditionMessage(w), "compute_bootstrap_confidence_interval", fixed = TRUE)
	expect_match(conditionMessage(w), "unit = \"cluster\"", fixed = TRUE)
	inf2 = InferenceIncidLogRegr$new(make_cluster_des_rt("incidence"))
	expect_no_warning(suppressWarnings(inf2$compute_asymp_two_sided_pval(), classes = cls))
})

test_that("OLS and Lin Wald inference stay silent on a cluster design", {
	for (gen in list(InferenceContinOLS, InferenceContinLin)) {
		inf = gen$new(make_cluster_des_rt("continuous"))
		expect_equal(count_cluster_warnings({
			inf$compute_asymp_confidence_interval()
			inf$compute_asymp_two_sided_pval()
		}), 0L)
	}
})

test_that("a likelihood-based path warns once, including for OLS and Lin (CR2 covers Wald only)", {
	inf = InferenceIncidLogRegr$new(make_cluster_des_rt("incidence"))
	inf$set_testing_type("lik_ratio")
	expect_equal(count_cluster_warnings({
		inf$compute_asymp_two_sided_pval()
		inf$compute_asymp_two_sided_pval(delta = 0.1)
	}), 1L)
	for (gen in list(InferenceContinOLS, InferenceContinLin)) {
		inf = gen$new(make_cluster_des_rt("continuous"))
		expect_equal(count_cluster_warnings({
			try(suppressWarnings(inf$compute_lik_ratio_bootstrap_two_sided_pval(0, B = 5, show_progress = FALSE), classes = "simpleWarning"), silent = TRUE)
			try(suppressWarnings(inf$compute_lik_ratio_bootstrap_two_sided_pval(0, B = 5, show_progress = FALSE), classes = "simpleWarning"), silent = TRUE)
		}), 1L, info = class(inf)[1])
		# Wald after the likelihood-family warning: still silent (CR2 SE)
		expect_equal(count_cluster_warnings(inf$compute_asymp_two_sided_pval()), 0L, info = class(inf)[1])
	}
})

test_that("parametric bootstrap warns once on a cluster design", {
	inf = InferenceIncidLogRegr$new(make_cluster_des_rt("incidence"))
	skip_if_not(isTRUE(inf$.__enclos_env__$private$is_a_param_bootstrap()), "class has no param bootstrap")
	expect_equal(count_cluster_warnings({
		suppressWarnings(inf$compute_param_bootstrap_pval(0, B = 10, show_progress = FALSE), classes = "simpleWarning")
		suppressWarnings(inf$compute_param_bootstrap_pval(0, B = 10, show_progress = FALSE), classes = "simpleWarning")
	}), 1L)
})

test_that("no warning on a non-cluster design", {
	set.seed(4)
	n = 60
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf = InferenceIncidLogRegr$new(des)
	expect_equal(count_cluster_warnings({
		inf$compute_asymp_two_sided_pval()
		inf$set_testing_type("lik_ratio")
		inf$compute_asymp_two_sided_pval()
	}), 0L)
})

test_that("randomization and bootstrap routes do not trigger the warning", {
	inf = InferenceCountPoisson$new(make_cluster_des_rt("count"))
	expect_equal(count_cluster_warnings({
		inf$compute_rand_two_sided_pval(r = 21, show_progress = FALSE)
		inf$compute_bootstrap_two_sided_pval(B = 21, show_progress = FALSE)
		inf$compute_bootstrap_confidence_interval(B = 21, show_progress = FALSE)
	}), 0L)
})

test_that("custom-Wald classes (pooled t, Wilcox, Newcombe, Miettinen-Nurminen, G-computation) warn once on a cluster design", {
	specs = list(
		c("continuous", "InferenceAllSimpleMeanDiffPooledVar"), c("continuous", "InferenceAllSimpleWilcox"),
		c("incidence", "InferenceIncidNewcombeRiskDiff"), c("incidence", "InferenceIncidMiettinenNurminenRiskDiff"),
		c("incidence", "InferenceIncidGCompRiskDiff"), c("ordinal", "InferenceOrdinalGCompMeanDiff"),
		c("proportion", "InferencePropGCompMeanDiff")
	)
	for (spec in specs) {
		gen = tryCatch(get(spec[2]), error = function(e) NULL)
		skip_if(is.null(gen), paste("class not found:", spec[2]))
		des = make_cluster_des_rt(spec[1])
		inf = gen$new(des)
		n1 = count_cluster_warnings({
			inf$compute_asymp_confidence_interval()
			inf$compute_asymp_two_sided_pval()
			inf$compute_asymp_confidence_interval(alpha = 0.1)
		})
		expect_equal(n1, 1L, info = spec[2])
	}
})
