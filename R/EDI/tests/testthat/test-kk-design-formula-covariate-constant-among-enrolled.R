# v1.0.6-TODO-107: KK14/KK21/KK21stepwise crashed ("object 'g' not found") when
# design_formula named a covariate that was still constant among the subjects
# enrolled so far, because constant columns were dropped before the formula was
# applied. A formula whose only covariate first varies at the current subject
# also crashed in KK14's matching step (solve() on a 0 x 0 covariance).

kk_formula_classes = c("DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")

run_kk_formula_design = function(cls, X, design_formula, seed = 1L){
	n = nrow(X)
	d = get(cls, envir = asNamespace("EDI"))$new(response_type = "continuous", n = n,
		design_formula = design_formula, seed = seed)
	set.seed(seed)
	y = rnorm(n)
	for (i in seq_len(n)){
		d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		d$add_one_subject_response(i, y[i])
	}
	d
}

test_that("KK designs assign when a formula-named factor is constant among the first subjects", {
	set.seed(1)
	X = data.frame(x1 = rnorm(20), x2 = rnorm(20), g = factor(rep(c("a", "b"), each = 10)))
	# Two varying covariates besides g: with a single one, KK21stepwise hits a separate
	# all-zero-weights NaN crash (reported with v1.0.6-TODO-107, not fixed here).
	for (cls in kk_formula_classes){
		for (fml in list(~ x1 + x2 + g, ~ x1 * g + x2, ~ g)){
			d = run_kk_formula_design(cls, X, fml)
			w = d$get_w()
			expect_length(w, 20L)
			expect_true(all(w %in% c(0, 1)), info = paste(cls, deparse(fml)))
			# once g varies it enters the model matrix
			expect_true("gb" %in% colnames(d$.__enclos_env__$private$X), info = paste(cls, deparse(fml)))
		}
	}
})

test_that("KK designs assign when a formula-named numeric or character column starts constant", {
	set.seed(2)
	X = data.frame(x1 = rnorm(24), x2 = rnorm(24), h = rep(c("u", "v"), each = 12), z = c(rep(2, 15), rnorm(9)))
	for (cls in kk_formula_classes){
		d = run_kk_formula_design(cls, X, ~ x1 + x2 + h + I(z^2))
		w = d$get_w()
		expect_length(w, 24L)
		expect_true(all(w %in% c(0, 1)), info = cls)
		expect_setequal(colnames(d$.__enclos_env__$private$X), c("x1", "x2", "hv", "I(z^2)"))
	}
})

test_that("DesignFixedOptimalBlocks resolves covariates when a formula-named column is constant", {
	required = c("ompr", "ompr.roi", "ROI.plugin.glpk", "randomizr")
	skip_if_not(all(vapply(required, requireNamespace, logical(1), quietly = TRUE)))
	skip_on_os("windows")
	X = data.frame(x1 = c(-3, -2.9, -2.8, -2.7, 2.7, 2.8, 2.9, 3), g = factor(rep("a", 8), levels = c("a", "b")))
	des = DesignFixedOptimalBlocks$new(response_type = "continuous", method = "ompr", B = 2, n = 8,
		verbose = FALSE, design_formula = ~ x1 + g)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	expect_equal(sum(des$get_w()), 4)
	Xr = des$.__enclos_env__$private$optimal_block_resolve_covariates(8L)
	expect_equal(colnames(Xr), "x1")
})
