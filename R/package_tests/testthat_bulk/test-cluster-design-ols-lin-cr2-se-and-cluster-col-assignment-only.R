library(testthat)
library(EDI)

# TODO-103: on cluster-randomized designs InferenceContinOLS / InferenceContinLin use a
# CR2 (Bell-McCaffrey) cluster-robust SE with G - 1 df, and cluster_col is kept out of `~ .`.

make_cluster_des = function(seed = 1L, G = 20L, m = 10L, add_cluster_col_to_X = TRUE){
	set.seed(seed)
	n = G * m
	cl = rep(seq_len(G), each = m)
	u = rnorm(G, sd = 2)[cl]
	X = data.frame(pretest = rnorm(n) + u / 2, school = factor(cl))
	des = DesignFixedCluster$new(n = n, response_type = "continuous", cluster_col = "school", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(0.5 * X$pretest + u + 1 * w + rnorm(n))
	list(des = des, X = X, w = w, y = des$get_y(), cl = cl)
}

cr2_ref = function(Xm, y, cl, j){
	b = solve(crossprod(Xm), crossprod(Xm, y)); e = y - Xm %*% b
	bread = solve(crossprod(Xm)); meat = 0
	for (g in unique(cl)) {
		i = which(cl == g); Xg = Xm[i, , drop = FALSE]
		M = diag(length(i)) - Xg %*% bread %*% t(Xg)
		ev = eigen(M, symmetric = TRUE); A = ev$vectors %*% diag(1 / sqrt(pmax(ev$values, 1e-12))) %*% t(ev$vectors)
		s = crossprod(Xg, A %*% e[i]); meat = meat + s %*% t(s)
	}
	sqrt((bread %*% meat %*% bread)[j, j])
}

# Independent Bell-McCaffrey Satterthwaite df via full n x n matrices.
satt_df_ref = function(Xm, cl, j){
	n = nrow(Xm); bread = solve(crossprod(Xm)); H = Xm %*% bread %*% t(Xm); IH = diag(n) - H
	ej = diag(ncol(Xm))[, j]; U = NULL
	for (g in unique(cl)) {
		E = diag(n)[cl == g, , drop = FALSE]                  # n_g x n selector
		M = E %*% IH %*% t(E); ev = eigen((M + t(M)) / 2, symmetric = TRUE)
		A = ev$vectors %*% diag(1 / sqrt(pmax(ev$values, 1e-12))) %*% t(ev$vectors)
		U = cbind(U, t(IH) %*% t(E) %*% A %*% E %*% Xm %*% bread %*% ej)
	}
	Q = U %*% t(U); sum(diag(Q))^2 / sum(Q * Q)
}

test_that("cluster_col is not a covariate under the default formula", {
	d = make_cluster_des()
	inf = InferenceContinOLS$new(d$des)
	expect_false(any(grepl("school", colnames(inf$.__enclos_env__$private$X))))
	expect_true("pretest" %in% colnames(inf$.__enclos_env__$private$X))
})

test_that("OLS SE on a cluster design equals the CR2 reference with G-1 df", {
	d = make_cluster_des()
	inf = InferenceContinOLS$new(d$des)
	est = inf$compute_estimate()
	se = inf$.__enclos_env__$private$get_standard_error()
	Xm = cbind(1, d$w, d$X$pretest)
	expect_equal(unname(est), unname(solve(crossprod(Xm), crossprod(Xm, d$y))[2]), tolerance = 1e-8)
	expect_equal(se, as.numeric(cr2_ref(Xm, d$y, d$cl, 2L)), tolerance = 1e-8)
	df = inf$.__enclos_env__$private$get_degrees_of_freedom()
	expect_equal(df, satt_df_ref(Xm, d$cl, 2L), tolerance = 1e-6)
	expect_lt(df, 19); expect_gt(df, 1)
	naive = summary(lm(d$y ~ d$w + d$X$pretest))$coefficients[2, 2]
	expect_gt(se, 1.5 * naive)
})

test_that("Lin SE on a cluster design is the CR2 SE (wider than subject-level HC2)", {
	d = make_cluster_des(seed = 2L)
	inf = InferenceContinLin$new(d$des)
	inf$compute_estimate()
	se = inf$.__enclos_env__$private$get_standard_error()
	xc = d$X$pretest - mean(d$X$pretest)
	Xm = cbind(1, d$w, xc, d$w * xc)
	expect_equal(se, as.numeric(cr2_ref(Xm, d$y, d$cl, 2L)), tolerance = 1e-8)
	expect_equal(inf$.__enclos_env__$private$get_degrees_of_freedom(), satt_df_ref(Xm, d$cl, 2L), tolerance = 1e-6)
})

test_that("Satterthwaite df matches clubSandwich on cluster_trial-like data", {
	skip_if_not_installed("clubSandwich")
	d = make_cluster_des(seed = 5L)
	Xm = cbind(1, d$w, d$X$pretest)
	b = solve(crossprod(Xm), crossprod(Xm, d$y))
	cr = EDI:::cluster_robust_cr2_variance(Xm, d$y, as.numeric(b), d$cl, 2L)
	m = lm(d$y ~ d$w + d$X$pretest)
	ct = clubSandwich::coef_test(m, vcov = "CR2", cluster = d$cl, test = "Satterthwaite")
	expect_equal(sqrt(cr$ssq), ct$SE[2], tolerance = 1e-6)
	expect_equal(cr$df, ct$df_Satt[2], tolerance = 1e-5)
})

test_that("G-1 fallback when fewer than 3 clusters (NULL) and user formula with cluster col warns", {
	Xm = cbind(1, rnorm(6), rnorm(6))
	expect_null(EDI:::cluster_robust_cr2_variance(Xm, rnorm(6), c(0, 1, 1), rep(1:2, each = 3), 2L))
	d = make_cluster_des(seed = 6L, G = 8L, m = 6L)
	expect_warning(InferenceContinOLS$new(d$des, model_formula = ~ pretest + school),
		class = "edi_cluster_col_in_model_formula_warning")
	expect_no_warning(InferenceContinOLS$new(d$des, model_formula = ~ pretest))
})

test_that("non-cluster designs keep the classical OLS SE", {
	set.seed(3); n = 40
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	X = data.frame(x = rnorm(n)); des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(X$x + des$get_w() + rnorm(n))
	inf = InferenceContinOLS$new(des); inf$compute_estimate()
	ref = summary(lm(des$get_y() ~ des$get_w() + X$x))$coefficients[2, 2]
	expect_equal(inf$.__enclos_env__$private$get_standard_error(), ref, tolerance = 1e-8)
})
