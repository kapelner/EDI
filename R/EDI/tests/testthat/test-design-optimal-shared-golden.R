# TODO-1b golden tests (design_fixed_optimal.md): lock DesignFixedGreedyDOptimal's
# P/H criterion-matrix construction bit-for-bit before extracting it into the
# shared helper_optimal_shared.R helpers, so the refactor is provably
# behavior-preserving. Allocation-level and validation-level goldens already
# live in test-greedy-d-optimal-merged.R; this file pins the matrices
# themselves, which those tests only exercise indirectly.
#
# The reference implementations below deliberately duplicate the class's exact
# arithmetic (same QR path, same operation order) — bit-identity, not just
# numerical closeness, is the contract the extraction must satisfy.

golden_n = 14

golden_data = function(){
	set.seed(1848)
	data.frame(
		x1 = rnorm(golden_n),
		x2 = runif(golden_n),
		x3 = rnorm(golden_n, sd = 3),
		x4 = rexp(golden_n)
	)
}

# Build the design, run one draw (which caches P/H), and expose the privates.
drawn_design_privates = function(...){
	des = DesignFixedGreedyDOptimal$new(n = golden_n, response_type = "continuous", seed = 90, ...)
	des$add_all_subjects_to_experiment(golden_data())
	invisible(des$draw_ws_according_to_design(r = 3))
	des$.__enclos_env__$private
}

reference_interest_z0_columns = function(X, interest){
	wanted = if (inherits(interest, "formula")) {
		mm = stats::model.matrix(interest, data = as.data.frame(X))
		setdiff(colnames(mm), "(Intercept)")
	} else {
		interest
	}
	match(wanted, colnames(X)) + 1L
}

reference_P_H_nonbayesian = function(X, need_H, interest = NULL){
	Z0 = cbind(1, X)
	Z0_qr = qr(Z0)
	Q = qr.Q(Z0_qr)
	P = Q %*% t(Q)
	H = NULL
	if (need_H) {
		R = qr.R(Z0_qr)
		M = solve(t(R) %*% R)
		if (!is.null(interest)) {
			ZV = Z0 %*% M
			idx0 = reference_interest_z0_columns(X, interest)
			H = tcrossprod(ZV[, idx0, drop = FALSE])
		} else {
			H = Z0 %*% (M %*% M) %*% t(Z0)
		}
	}
	list(P = P, H = H)
}

reference_P_H_bayesian = function(X, prior_precision, standardize_covariates, need_H, interest = NULL){
	scalar_tau = !is.matrix(prior_precision)
	if (scalar_tau && isTRUE(standardize_covariates)) {
		X = scale(X)
		X[!is.finite(X)] = 0
	}
	Z0 = cbind(1, X)
	pz = ncol(Z0)
	R0 = if (scalar_tau) {
		diag(c(0, rep(as.numeric(prior_precision), pz - 1L)), nrow = pz)
	} else {
		prior_precision
	}
	V_B = solve(crossprod(Z0) + R0)
	P = Z0 %*% V_B %*% t(Z0)
	H = NULL
	if (need_H) {
		if (!is.null(interest)) {
			ZV = Z0 %*% V_B
			idx0 = reference_interest_z0_columns(X, interest)
			H = tcrossprod(ZV[, idx0, drop = FALSE])
		} else {
			H = Z0 %*% V_B %*% V_B %*% t(Z0)
		}
	}
	list(P = P, H = H)
}

test_that("golden P: objective D, non-Bayesian (QR path), H not built", {
	priv = drawn_design_privates(objective = "D")
	ref = reference_P_H_nonbayesian(priv$X[1:golden_n, , drop = FALSE], need_H = FALSE)
	expect_equal(priv$P, ref$P, tolerance = 0)
	expect_null(priv$H)
})

test_that("golden P/H: objective A, interest 'all', non-Bayesian", {
	priv = drawn_design_privates(objective = "A", interest = "all")
	ref = reference_P_H_nonbayesian(priv$X[1:golden_n, , drop = FALSE], need_H = TRUE)
	expect_equal(priv$P, ref$P, tolerance = 0)
	expect_equal(priv$H, ref$H, tolerance = 0)
})

test_that("golden H_S: objective A, subset interest via column names", {
	priv = drawn_design_privates(objective = "A", interest = c("x1", "x3"))
	ref = reference_P_H_nonbayesian(priv$X[1:golden_n, , drop = FALSE], need_H = TRUE, interest = c("x1", "x3"))
	expect_equal(priv$P, ref$P, tolerance = 0)
	expect_equal(priv$H, ref$H, tolerance = 0)
})

test_that("golden H_S: objective A, subset interest via one-sided formula", {
	priv = drawn_design_privates(objective = "A", interest = ~ x1 + x2)
	ref = reference_P_H_nonbayesian(priv$X[1:golden_n, , drop = FALSE], need_H = TRUE, interest = ~ x1 + x2)
	expect_equal(priv$P, ref$P, tolerance = 0)
	expect_equal(priv$H, ref$H, tolerance = 0)
})

test_that("golden P_B: Bayesian scalar tau, standardized covariates (objective D)", {
	priv = drawn_design_privates(objective = "D", prior_precision = 2.5)
	ref = reference_P_H_bayesian(priv$X[1:golden_n, , drop = FALSE], 2.5, TRUE, need_H = FALSE)
	expect_equal(priv$P, ref$P, tolerance = 0)
	expect_null(priv$H)
})

test_that("golden P_B: Bayesian scalar tau without standardization (objective D)", {
	priv = drawn_design_privates(objective = "D", prior_precision = 2.5, standardize_covariates = FALSE)
	ref = reference_P_H_bayesian(priv$X[1:golden_n, , drop = FALSE], 2.5, FALSE, need_H = FALSE)
	expect_equal(priv$P, ref$P, tolerance = 0)
})

test_that("golden P_B/H_B: Bayesian matrix R0 (objective A, interest 'all')", {
	pz = 5L  # intercept + 4 covariates
	set.seed(7)
	A0 = matrix(rnorm(pz * pz), pz, pz)
	R0 = crossprod(A0) + diag(pz)
	priv = drawn_design_privates(objective = "A", interest = "all", prior_precision = R0)
	ref = reference_P_H_bayesian(priv$X[1:golden_n, , drop = FALSE], R0, TRUE, need_H = TRUE)
	expect_equal(priv$P, ref$P, tolerance = 0)
	expect_equal(priv$H, ref$H, tolerance = 0)
})

test_that("golden H_S: Bayesian scalar tau with subset interest (objective A)", {
	priv = drawn_design_privates(objective = "A", interest = c("x2", "x4"), prior_precision = 1.7)
	ref = reference_P_H_bayesian(priv$X[1:golden_n, , drop = FALSE], 1.7, TRUE, need_H = TRUE, interest = c("x2", "x4"))
	expect_equal(priv$P, ref$P, tolerance = 0)
	expect_equal(priv$H, ref$H, tolerance = 0)
})

# ── The extracted shared helpers (helper_optimal_shared.R) ────────────────────
# Direct unit tests for the TODO-1b extraction targets. The build helper must
# reproduce the reference matrices above bit-for-bit; the validator must
# reproduce the constructor's promotion/eager-error semantics with the caller's
# own closed objective set.

test_that("validate_optimal_design_objective_args resolves interest kinds and promotes formula strings", {
	v = EDI:::validate_optimal_design_objective_args
	expect_identical(v("D", "treatment", NULL, TRUE, c("D", "A"))$interest_kind, "treatment")
	expect_identical(v("A", "all", NULL, TRUE, c("D", "A"))$interest_kind, "all")
	expect_identical(v("A", c("x1", "x3"), NULL, TRUE, c("D", "A"))$interest_kind, "subset")
	expect_identical(v("A", ~ x1 + x2, NULL, TRUE, c("D", "A"))$interest_kind, "subset")
	promoted = v("A", "x1 * x2 + x4", NULL, TRUE, c("D", "A"))
	expect_s3_class(promoted$interest, "formula")
	expect_identical(promoted$interest_kind, "subset")
})

test_that("validate_optimal_design_objective_args enforces the caller's closed objective set", {
	v = EDI:::validate_optimal_design_objective_args
	expect_error(v("Z", "treatment", NULL, TRUE, c("D", "A")), "objective")
	# A different caller's set (DesignFixedOptimal's superset) admits its own values
	expect_identical(v("mahal_dist", "treatment", NULL, TRUE, c("D", "A", "mahal_dist", "abs_sum_diff", "custom"))$interest_kind, "treatment")
	# A caller-supplied message is used verbatim
	expect_error(v("Z", "treatment", NULL, TRUE, c("D", "A"),
		objective_error_message = 'objective must be "D" (determinant) or "A" (trace).'),
		'objective must be "D" \\(determinant\\) or "A" \\(trace\\)\\.')
})

test_that("validate_optimal_design_objective_args rejects malformed interest / prior / standardize args", {
	v = EDI:::validate_optimal_design_objective_args
	expect_error(v("A", y ~ x1, NULL, TRUE, c("D", "A")), "one-sided")
	expect_error(v("A", matrix(1, 2, 2), NULL, TRUE, c("D", "A")), "Contrast-matrix")
	expect_error(v("D", "treatment", -1, TRUE, c("D", "A")), "prior_precision")
	expect_error(v("D", "treatment", matrix(1:4, 2, 2), TRUE, c("D", "A")), "symmetric")
	expect_error(v("D", "treatment", NULL, NA, c("D", "A")), "standardize_covariates")
})

test_that("build_optimal_design_P_H reproduces every golden construction bit-for-bit", {
	b = EDI:::build_optimal_design_P_H
	priv = drawn_design_privates(objective = "D")
	X = priv$X[1:golden_n, , drop = FALSE]

	res = b(X, interest = "treatment", prior_precision = NULL, standardize_covariates = TRUE, need_H = FALSE)
	expect_equal(res$P, reference_P_H_nonbayesian(X, need_H = FALSE)$P, tolerance = 0)
	expect_null(res$H)

	res = b(X, interest = "all", prior_precision = NULL, standardize_covariates = TRUE, need_H = TRUE)
	ref = reference_P_H_nonbayesian(X, need_H = TRUE)
	expect_equal(res$P, ref$P, tolerance = 0)
	expect_equal(res$H, ref$H, tolerance = 0)

	res = b(X, interest = c("x1", "x3"), prior_precision = NULL, standardize_covariates = TRUE, need_H = TRUE)
	ref = reference_P_H_nonbayesian(X, need_H = TRUE, interest = c("x1", "x3"))
	expect_equal(res$H, ref$H, tolerance = 0)

	res = b(X, interest = "treatment", prior_precision = 2.5, standardize_covariates = TRUE, need_H = FALSE)
	expect_equal(res$P, reference_P_H_bayesian(X, 2.5, TRUE, need_H = FALSE)$P, tolerance = 0)

	set.seed(7)
	A0 = matrix(rnorm(25), 5, 5)
	R0 = crossprod(A0) + diag(5)
	res = b(X, interest = "all", prior_precision = R0, standardize_covariates = TRUE, need_H = TRUE)
	ref = reference_P_H_bayesian(X, R0, TRUE, need_H = TRUE)
	expect_equal(res$P, ref$P, tolerance = 0)
	expect_equal(res$H, ref$H, tolerance = 0)
})

test_that("build_optimal_design_P_H errors informatively on unmatched interest columns and bad R0 dims", {
	b = EDI:::build_optimal_design_P_H
	priv = drawn_design_privates(objective = "D")
	X = priv$X[1:golden_n, , drop = FALSE]
	expect_error(b(X, interest = c("nope"), prior_precision = NULL, standardize_covariates = TRUE, need_H = TRUE),
		"not found in the design's model matrix")
	expect_error(b(X, interest = "all", prior_precision = diag(3), standardize_covariates = TRUE, need_H = FALSE),
		"prior_precision matrix must be")
})
