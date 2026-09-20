library(testthat)
library(EDI)

# DesignFixedOptimal's private build_solver_inputs() (objective -> solver-input
# kind, with the exact objective evaluator f_eval) and solve_optimal_w() with the
# exact "ompr" MILP solver plus the mirror coin. References: the Mahalanobis and
# standardized-L1 imbalance definitions written out from the raw covariates, and
# brute-force enumeration of every balanced allocation for n = 10. None of these
# private layers had a direct reference (the sibling MILP-solver tests exercise
# milp_solve_* on hand-built matrices).

optimal_fixture <- function(objective, seed_x = 5L, n = 10L, ..., seed = 1L) {
	set.seed(seed_x)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignFixedOptimal$new(response_type = "continuous", n = n, objective = objective,
		solver = "ompr", seed = seed, verbose = FALSE, ...)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	list(des = des, priv = des$.__enclos_env__$private, n = n)
}

ref_mahal <- function(Xm, w) {
	n <- nrow(Xm)
	Xc <- scale(Xm, center = TRUE, scale = FALSE)
	S <- crossprod(Xc) / (n - 1)
	d <- crossprod(Xc, 2 * w - 1) / n
	as.numeric(crossprod(d, solve(S) %*% d))
}

ref_l1 <- function(Xm, w) {
	n <- nrow(Xm)
	Xc <- scale(Xm, center = TRUE, scale = FALSE)
	sd_j <- sqrt(colSums(Xc^2) / (n - 1))
	sum(abs(crossprod(sweep(Xc, 2, sd_j, "/"), 2 * w - 1) / n))
}

all_allocations <- function(n, n_T) {
	cols <- utils::combn(n, n_T)
	lapply(seq_len(ncol(cols)), function(j) { w <- numeric(n); w[cols[, j]] <- 1; w })
}

test_that("objectives map to the documented solver-input kinds", {
	for (spec in list(c("mahal_dist", "quadratic"), c("abs_sum_diff", "l1"), c("D", "quadratic"))) {
		f <- optimal_fixture(spec[1])
		inp <- f$priv$build_solver_inputs(f$priv$X[1:10, , drop = FALSE], 5L)
		expect_equal(inp$kind, spec[2], info = spec[1])
		expect_true(is.function(inp$f_eval))
	}
	a_all <- optimal_fixture("A", interest = "all")
	expect_equal(a_all$priv$build_solver_inputs(a_all$priv$X[1:10, , drop = FALSE], 5L)$kind, "ratio")
	a_trt <- optimal_fixture("A")
	expect_equal(a_trt$priv$build_solver_inputs(a_trt$priv$X[1:10, , drop = FALSE], 5L)$kind, "quadratic")
})

test_that("f_eval reproduces the Mahalanobis and standardized-L1 imbalance definitions for arbitrary allocations", {
	set.seed(8)
	m <- optimal_fixture("mahal_dist")
	Xm <- m$priv$X[1:10, , drop = FALSE]
	inp <- m$priv$build_solver_inputs(Xm, 5L)
	l <- optimal_fixture("abs_sum_diff")
	inp_l1 <- l$priv$build_solver_inputs(l$priv$X[1:10, , drop = FALSE], 5L)
	for (i in 1:6) {
		w <- sample(rep(0:1, 5))
		expect_equal(inp$f_eval(w), ref_mahal(Xm, w), tolerance = 1e-8)
		expect_equal(inp_l1$f_eval(w), ref_l1(l$priv$X[1:10, , drop = FALSE], w), tolerance = 1e-8)
	}
	# The quadratic form is symmetric under the mirror allocation.
	w <- sample(rep(0:1, 5))
	expect_equal(inp$f_eval(w), inp$f_eval(1 - w), tolerance = 1e-10)
})

test_that("the exact MILP allocation attains the brute-force optimum, balanced, and records diagnostics", {
	for (obj in c("mahal_dist", "abs_sum_diff", "D")) {
		f <- optimal_fixture(obj)
		Xm <- f$priv$X[1:10, , drop = FALSE]
		inp <- f$priv$build_solver_inputs(Xm, 5L)
		w <- f$des$get_w()
		expect_equal(sum(w), 5, info = obj)
		expect_true(all(w %in% c(0, 1)), info = obj)
		brute <- vapply(all_allocations(10, 5), inp$f_eval, numeric(1))
		expect_equal(inp$f_eval(w), min(brute), tolerance = 1e-7, info = obj)

		diag <- f$priv$optimization_diagnostics
		expect_equal(diag$objective, obj)
		expect_equal(diag$kind, inp$kind)
		expect_equal(diag$solver, "ompr")
		expect_equal(diag$objective_value, min(brute), tolerance = 1e-7, info = obj)
		expect_equal(c(diag$n, diag$n_T), c(10L, 5L))
		expect_true(diag$mirror_feasible)
		expect_false(diag$mahal_fell_back)
	}
	# Independent of the package's own evaluator, for the two explicitly defined objectives.
	m <- optimal_fixture("mahal_dist")
	Xm <- m$priv$X[1:10, , drop = FALSE]
	best <- min(vapply(all_allocations(10, 5), function(w) ref_mahal(Xm, w), numeric(1)))
	expect_equal(ref_mahal(Xm, m$des$get_w()), best, tolerance = 1e-7)
	l <- optimal_fixture("abs_sum_diff")
	Xl <- l$priv$X[1:10, , drop = FALSE]
	best_l <- min(vapply(all_allocations(10, 5), function(w) ref_l1(Xl, w), numeric(1)))
	expect_equal(ref_l1(Xl, l$des$get_w()), best_l, tolerance = 1e-7)
})

test_that("the mirror coin only ever returns the optimum or its exact mirror image", {
	f <- optimal_fixture("mahal_dist")
	inp <- f$priv$build_solver_inputs(f$priv$X[1:10, , drop = FALSE], 5L)
	brute <- vapply(all_allocations(10, 5), inp$f_eval, numeric(1))
	seen <- list()
	for (s in 1:12) {
		g <- optimal_fixture("mahal_dist", seed = s)
		w <- g$des$get_w()
		expect_equal(inp$f_eval(w), min(brute), tolerance = 1e-7)
		seen[[s]] <- paste(w, collapse = "")
		dg <- g$priv$optimization_diagnostics
		expect_true(dg$mirror_tied)
		expect_identical(dg$mirror_flipped, isTRUE(dg$mirror_flipped))
	}
	distinct <- unique(unlist(seen))
	expect_lte(length(distinct), 2L)
	if (length(distinct) == 2L) {
		a <- as.numeric(strsplit(distinct[1], "")[[1]]); b <- as.numeric(strsplit(distinct[2], "")[[1]])
		expect_equal(a, 1 - b)
	}

	off <- optimal_fixture("mahal_dist", mirror_coin = FALSE)
	expect_false(off$priv$optimization_diagnostics$mirror_coin)
	expect_false(off$priv$optimization_diagnostics$mirror_flipped)
})

test_that("the A-optimality ratio evaluator is (w'Hw + 1) / (n_T - w'Pw)", {
	f <- optimal_fixture("A", interest = "all")
	inp <- f$priv$build_solver_inputs(f$priv$X[1:10, , drop = FALSE], 5L)
	set.seed(9)
	w <- sample(rep(0:1, 5))
	val <- inp$f_eval(w)
	expect_true(is.finite(val) && val > 0)
	den <- 5 - drop(t(w) %*% inp$P %*% w)
	expect_equal(val, (drop(t(w) %*% inp$H %*% w) + 1) / den, tolerance = 1e-10)
})
