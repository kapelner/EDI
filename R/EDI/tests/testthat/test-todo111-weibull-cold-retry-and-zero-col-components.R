# TODO-111 follow-ups: (1) a warm-started Weibull refit at an already-optimal point
# can return converged = FALSE (NaN gradient norm) on a covariate-free fit; the
# randomization-statistic / estimate paths must retry cold. (2) zero-column
# designs (with and without a user ~1 formula) must work for the hurdle / ZI /
# ZOIB component-matrix builders (they get 0 x 0 from create_model_matrix_from_features
# and rely on the ncol == 0 intercept-only branch).

.t111c_design = function(response_type, n = 40L, constant_col = FALSE){
	set.seed(111)
	des = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(
		if (constant_col) data.frame(k = rep(1, n)) else data.frame(row.names = seq_len(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	if (response_type == "survival") {
		set.seed(5)
		time = rexp(n); dead = rbinom(n, 1, 0.8)
		des$add_all_subject_responses(ys = ifelse(dead == 1, time, NA),
			y_Ls = ifelse(dead == 1, NA, time), y_Rs = ifelse(dead == 1, NA, Inf))
	} else if (response_type == "count") {
		set.seed(3)
		des$add_all_subject_responses(ifelse(runif(n) < 0.3, 0, rpois(n, 2 + 0.5 * w)))
	} else {
		set.seed(3)
		v = rbeta(n, 2, 3); v[runif(n) < 0.1] = 0; v[runif(n) < 0.1] = 1
		des$add_all_subject_responses(v)
	}
	des
}

test_that("InferenceSurvivalWeibullRegr: covariate-free randomization p-value is finite and does not poison the estimate", {
	skip_on_cran()
	for (cc in c(FALSE, TRUE)) {
		des = .t111c_design("survival", constant_col = cc)
		ref = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)$compute_estimate()
		expect_true(is.finite(ref))
		inf = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
		p = suppressWarnings(inf$compute_rand_two_sided_pval(r = 21, show_progress = FALSE))
		expect_true(is.finite(p) && p > 0 && p <= 1, info = paste("constant_col", cc))
		# the warm start left by the randomization refits sits at the optimum; the
		# estimate afterwards must still converge and equal the fresh-object estimate
		expect_equal(inf$compute_estimate(), ref, tolerance = 1e-6)
	}
})

test_that("zero-column designs (default and ~1 formula) work for hurdle / zero-inflated / ZOIB classes", {
	skip_on_cran()
	specs = list(
		list("count", "InferenceCountHurdlePoisson"), list("count", "InferenceCountHurdleNegBin"),
		list("count", "InferenceCountZeroInflatedPoisson"), list("count", "InferenceCountZeroInflatedNegBin"),
		list("proportion", "InferencePropZeroOneInflatedBetaRegr"))
	for (cc in c(FALSE, TRUE)) {
		for (sp in specs) {
			des = .t111c_design(sp[[1]], constant_col = cc)
			expect_identical(dim(des$get_X()), c(40L, 0L))
			for (fm in list(NULL, ~ 1)) {
				inf = if (is.null(fm)) get(sp[[2]])$new(des, verbose = FALSE) else get(sp[[2]])$new(des, model_formula = fm, verbose = FALSE)
				est = tryCatch(inf$compute_estimate(), error = function(e) e)
				expect_false(inherits(est, "error"), info = paste(sp[[2]], cc, deparse(fm)))
				expect_true(is.numeric(est) && is.finite(est), info = paste(sp[[2]], cc, deparse(fm)))
				p = suppressWarnings(inf$compute_rand_two_sided_pval(r = 11, show_progress = FALSE))
				expect_true(is.finite(p), info = paste(sp[[2]], "rand", cc, deparse(fm)))
			}
		}
	}
})
