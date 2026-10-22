# TODO-111: a covariate frame with zero columns must give an n x 0 get_X()
# (not 0 x 0), so the KK / frailty survival classes do not crash in
# compute_zhang_match_data_cpp() with "X row count must match w size.".

.zc_surv_design = function(n = 40L, constant_col = FALSE){
	set.seed(111)
	pid = rep(seq_len(n / 2L), each = 2L)
	des = DesignFixedBinaryMatch$new(n = n, response_type = "survival", m = pid, verbose = FALSE)
	des$add_all_subjects_to_experiment(
		if (constant_col) data.frame(k = rep(1, n)) else data.frame(row.names = seq_len(n)))
	des$assign_w_to_all_subjects()
	time = rexp(n)
	dead = rbinom(n, 1, 0.8)
	des$add_all_subject_responses(ys = ifelse(dead == 1, time, NA),
		y_Ls = ifelse(dead == 1, NA, time), y_Rs = ifelse(dead == 1, NA, Inf))
	des
}

test_that("get_X() is n x 0 when the covariate frame has zero (or only constant) columns", {
	for (cc in c(FALSE, TRUE)){
		des = .zc_surv_design(constant_col = cc)
		expect_identical(dim(des$get_X()), c(40L, 0L))
	}
})

test_that("KK and frailty survival classes run with zero covariates", {
	des = .zc_surv_design()
	classes = c(
		"InferenceSurvivalKKStratCoxPHOneLik",
		"InferenceSurvivalKKLWACoxPHOneLik",
		"InferenceSurvivalGLMMWeibullFrailtyNormalOneLik",
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik",
		"InferenceSurvivalGLMMWeibullFrailtyNormalIVWC",
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC",
		"InferenceSurvivalKKLWACoxPHIVWC",
		"InferenceSurvivalKKStratCoxPHIVWC",
		"InferenceSurvivalKKRankRegrIVWC",
		"InferenceSurvivalKKWeibullMarginal",
		"InferenceSurvivalCoxPHRegr")
	for (cls in classes){
		inf = get(cls)$new(des, verbose = FALSE)
		est = tryCatch(inf$compute_estimate(), error = function(e) e)
		expect_false(inherits(est, "error"), info = paste(cls, if (inherits(est, "error")) conditionMessage(est)))
		expect_true(is.numeric(est) && length(est) == 1L && is.finite(est), info = cls)
	}
})

# ---- TODO-111 (procedure sweep): zero / constant covariate columns on several designs ----

.zc_design = function(kind, constant_col = FALSE, n = 40L){
	xdf = if (constant_col) data.frame(k = rep(1, n)) else data.frame(row.names = seq_len(n))
	set.seed(111)
	if (kind == "seq_kk14") {
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
		for (t in seq_len(n)) des$add_one_subject_to_experiment_and_assign(
			if (constant_col) data.frame(k = 1) else data.frame(row.names = 1L))
	} else {
		des = if (kind == "match") {
			DesignFixedBinaryMatch$new(n = n, response_type = "survival", m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
		} else {
			DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
		}
		des$add_all_subjects_to_experiment(xdf)
		des$assign_w_to_all_subjects()
	}
	set.seed(5)
	time = rexp(n); dead = rbinom(n, 1, 0.8)
	for (t in if (kind == "seq_kk14") seq_len(n) else integer(0)) {
		if (dead[t] == 1) des$add_one_subject_response(t, y = time[t])
		else des$add_one_subject_response(t, y_L = time[t], y_R = Inf)
	}
	if (kind != "seq_kk14") des$add_all_subject_responses(ys = ifelse(dead == 1, time, NA),
		y_Ls = ifelse(dead == 1, NA, time), y_Rs = ifelse(dead == 1, NA, Inf))
	des
}

.zc_expect_finite = function(f, info) {
	r = tryCatch(suppressWarnings(f()), error = function(e) e)
	expect_false(inherits(r, "error"), info = paste(info, if (inherits(r, "error")) conditionMessage(r)))
	if (!inherits(r, "error")) expect_true(all(is.finite(r)), info = info)
}
# bootstrap procedures may legitimately return NA at tiny n (BCa boundary / too few
# finite replicates): assert only that they do not error.
.zc_expect_no_error = function(f, info) {
	r = tryCatch(suppressWarnings(f()), error = function(e) e)
	expect_false(inherits(r, "error"), info = paste(info, if (inherits(r, "error")) conditionMessage(r)))
}

test_that("zero / constant covariate columns: Wald, randomization, bootstrap, jackknife run on the matching and non-matching designs", {
	skip_on_cran()
	kk_classes = c("InferenceSurvivalKKStratCoxPHOneLik", "InferenceSurvivalKKLWACoxPHOneLik", "InferenceSurvivalKKWeibullMarginal")
	for (cc in c(FALSE, TRUE)) {
		des = .zc_design("match", cc)
		for (cls in kk_classes) {
			inf = get(cls)$new(des, verbose = FALSE)
			tag = paste(cls, "match", cc)
			.zc_expect_finite(function() inf$compute_asymp_two_sided_pval(), paste(tag, "wald p"))
			.zc_expect_finite(function() inf$compute_asymp_confidence_interval(), paste(tag, "wald ci"))
			.zc_expect_finite(function() inf$compute_rand_two_sided_pval(r = 21, show_progress = FALSE), paste(tag, "rand p"))
			.zc_expect_finite(function() inf$compute_jackknife_wald_two_sided_pval(), paste(tag, "jackknife p"))
			.zc_expect_no_error(function() inf$compute_bootstrap_two_sided_pval(B = 101, show_progress = FALSE), paste(tag, "boot p"))
			.zc_expect_no_error(function() inf$compute_bootstrap_confidence_interval(B = 101, show_progress = FALSE), paste(tag, "boot ci"))
		}
		# KK14 sequential matching: Wald + jackknife (bootstrap/randomization are unsupported on DesignSeqOneByOne)
		des14 = .zc_design("seq_kk14", cc)
		expect_identical(dim(des14$get_X()), c(40L, 0L))
		for (cls in kk_classes) {
			inf = get(cls)$new(des14, verbose = FALSE)
			.zc_expect_finite(function() inf$compute_asymp_two_sided_pval(), paste(cls, "kk14 wald p", cc))
			.zc_expect_finite(function() inf$compute_asymp_confidence_interval(), paste(cls, "kk14 wald ci", cc))
		}
		# Bernoulli (non-matching) design with the non-KK classes
		desb = .zc_design("bern", cc)
		for (cls in c("InferenceSurvivalCoxPHRegr", "InferenceSurvivalWeibullRegr", "InferenceSurvivalLogRank")) {
			inf = get(cls)$new(desb, verbose = FALSE)
			.zc_expect_finite(function() inf$compute_asymp_two_sided_pval(), paste(cls, "bern wald p", cc))
		}
	}
})

test_that("a user model_formula on a zero-covariate design still gives an n x 0 matrix (TODO-111, formula path)", {
	des = .zc_design("match", FALSE)
	for (cls in c("InferenceSurvivalKKStratCoxPHOneLik", "InferenceSurvivalCoxPHRegr", "InferenceSurvivalKKWeibullMarginal")) {
		inf = get(cls)$new(des, model_formula = ~ 1, verbose = FALSE)
		est = tryCatch(inf$compute_estimate(), error = function(e) e)
		expect_false(inherits(est, "error"), info = paste(cls, if (inherits(est, "error")) conditionMessage(est)))
		expect_true(is.numeric(est) && is.finite(est), info = cls)
	}
})

test_that("frailty classes: Wald with zero covariates on a sequential KK14 design", {
	skip_on_cran()
	des14 = .zc_design("seq_kk14", FALSE)
	inf = InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des14, verbose = FALSE)
	.zc_expect_finite(function() inf$compute_asymp_two_sided_pval(), "frailty normal kk14 wald p")
})

# ---- TODO-111 (fifth pass): every KK / frailty survival class x matching design x {zero, constant} column ----
test_that("every KK and frailty survival class gives a finite estimate with zero / constant covariates on match and KK14 designs", {
	skip_on_cran()
	classes = c(
		"InferenceSurvivalKKStratCoxPHOneLik", "InferenceSurvivalKKLWACoxPHOneLik",
		"InferenceSurvivalKKStratCoxPHIVWC", "InferenceSurvivalKKLWACoxPHIVWC",
		"InferenceSurvivalKKRankRegrIVWC", "InferenceSurvivalKKWeibullMarginal",
		"InferenceSurvivalGLMMWeibullFrailtyNormalOneLik", "InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik",
		"InferenceSurvivalGLMMWeibullFrailtyNormalIVWC", "InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC")
	for (kind in c("match", "seq_kk14")) for (cc in c(FALSE, TRUE)) {
		des = .zc_design(kind, cc)
		expect_identical(dim(des$get_X()), c(40L, 0L), info = paste(kind, cc))
		for (cls in classes) {
			inf = get(cls)$new(des, verbose = FALSE)
			.zc_expect_finite(function() inf$compute_estimate(), paste(cls, kind, cc, "estimate"))
		}
	}
})
