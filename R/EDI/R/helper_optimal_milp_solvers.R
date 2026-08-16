# Exact "ompr" MILP solvers for DesignFixedOptimal (design_fixed_optimal.md
# TODO-5/TODO-5b). Non-exported. Three entry points, all constrained to
# sum(w) == n_T over binary w:
#
#   milp_solve_l1(A, n_T)            min sum_j |(A w)_j|          (abs_sum_diff)
#   milp_solve_quadratic(Q, n_T)     min w'Qw                     (mahal_dist / D,
#                                    via exact product linearization y_ij = w_i w_j)
#   milp_solve_A_dinkelbach(P, H, n_T)  min (w'Hw + 1)/(n_T - w'Pw)  (A, via
#                                    Dinkelbach's algorithm over quadratic subproblems)
#
# GLPK certifies the global optimum for each (linearized) MILP; the product
# linearization is exact for binary w regardless of Q's definiteness, and
# Dinkelbach terminates in finitely many outer iterations on a finite feasible
# set. Exactness is locked by brute-force enumeration tests in
# tests/testthat/test-design-optimal-milp-solvers.R.

EDI_OPTIMAL_ROI_SOLVERS = c("glpk", "gurobi", "cplex")

# Default n cutoff above which "auto" abandons the product-linearized
# quadratic MILP (and each Dinkelbach subproblem) for the annealing fallback.
# GLPK benchmark (mahal_dist quadratic, p = 5, 2026-08-16): n = 15 -> 0.4s,
# n = 20 -> 3.5s, n = 25 -> 311s -- a sharp branch-and-bound cliff between 20
# and 25, hence 20. Commercial backends (gurobi/cplex) push this out; users
# override via solver_args$linearization_max_n.
EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N = 20L

# Closed-set validation (fail fast on typos, never pass unchecked names into
# ROI) plus a lazy requireNamespace() check for the packages the chosen
# backend needs -- at solve time only, mirroring DesignFixedOptimalBlocks.
assert_optimal_roi_solver = function(roi_solver){
	if (!is.character(roi_solver) || length(roi_solver) != 1L || !(roi_solver %in% EDI_OPTIMAL_ROI_SOLVERS)) {
		stop(sprintf(
			'roi_solver must be one of "glpk", "gurobi", "cplex" (got: %s).',
			paste(deparse(roi_solver), collapse = "")
		))
	}
	for (pkg in c("ompr", "ompr.roi")) {
		if (!requireNamespace(pkg, quietly = TRUE)) {
			stop(sprintf("Package '%s' is required for the \"ompr\" solver path; please install it.", pkg))
		}
	}
	plugin = switch(roi_solver,
		glpk   = "ROI.plugin.glpk",
		gurobi = "ROI.plugin.gurobi",
		cplex  = "ROI.plugin.cplex"
	)
	if (!requireNamespace(plugin, quietly = TRUE)) {
		stop(sprintf(paste0(
			"Package '%s' is required for roi_solver = \"%s\"; please install it. ",
			"%s"), plugin, roi_solver,
			if (roi_solver == "glpk") "" else paste0(
				"Note this backend also requires the vendor's own solver installation ",
				"and license (see the class documentation's wiring guide); if '", plugin,
				"' is installed but the solve still fails, the likely cause is a missing ",
				"vendor installation/license, not this package."
			)
		))
	}
	invisible(TRUE)
}

assert_optimal_milp_n_T = function(n_T, n){
	if (!(is.numeric(n_T) && length(n_T) == 1L && is.finite(n_T) && n_T == floor(n_T)) ||
			n_T < 1L || n_T > n - 1L) {
		stop(sprintf("n_T must be an integer with 1 <= n_T <= n - 1 (got n_T = %s, n = %d).",
			paste(deparse(n_T), collapse = ""), n))
	}
	as.integer(n_T)
}

optimal_milp_check_status = function(result, what){
	status = ompr::solver_status(result)
	if (!(status %in% c("optimal", "success"))) {
		stop(sprintf("The %s MILP solve did not reach optimality (solver status: '%s').", what, status))
	}
	status
}

optimal_milp_extract_w = function(result, n){
	sol = ompr::get_solution(result, w[i])
	w = numeric(n)
	w[sol$i] = round(sol$value)
	w
}

# Prepare DesignFixedGreedy's covariate-imbalance objectives as matrices over
# w, replicating the greedy kernel's (design_fixed_greedy.cpp) definitions
# exactly -- column-centered X throughout, so the (2w - 1) criterion reduces
# to a pure form in w with no linear/constant remainder:
#   mahal_dist  : f(w) = ||L^-1 X'(2w-1)/n||^2 = w'Qw,  Q = 4 X S^-1 X'/n^2
#                 (S = X'X/(n-1); singular S falls back to abs_sum_diff,
#                 matching the kernel)
#   abs_sum_diff: f(w) = ||X_std'(2w-1)/n||_1 = sum_j |(A w)_j|, A = (2/n) X_std'
#                 (per-column sd uses divisor n-1; near-zero variance -> 1,
#                 matching the kernel's 1e-24 guard)
# Returns list(kind = "quadratic"|"l1", Q = or A =, mahal_fell_back = flag).
prepare_optimal_objective_matrices = function(X_raw, objective){
	n = nrow(X_raw)
	Xc = scale(X_raw, center = TRUE, scale = FALSE)
	mahal_fell_back = FALSE
	if (objective == "mahal_dist") {
		Sigma = crossprod(Xc) / max(1, n - 1)
		# R's chol() can return a rounding-level positive pivot on an exactly
		# singular Sigma where the greedy kernel's Eigen LLT fails, so guard
		# with an explicit conditioning check rather than chol() success alone.
		ch = if (rcond(Sigma) < 1e-12) NULL else tryCatch(chol(Sigma), error = function(e) NULL)
		if (!is.null(ch)) {
			M = forwardsolve(t(ch), t(Xc)) / n
			return(list(kind = "quadratic", Q = 4 * crossprod(M), mahal_fell_back = FALSE))
		}
		mahal_fell_back = TRUE
	}
	col_var = colSums(Xc^2) / max(1, n - 1)
	inv_sd = ifelse(col_var < 1e-24, 1, 1 / sqrt(col_var))
	X_std = sweep(Xc, 2, inv_sd, `*`)
	list(kind = "l1", A = (2 / n) * t(X_std), mahal_fell_back = mahal_fell_back)
}

# min_w sum_j t_j  s.t.  -t_j <= (A w)_j <= t_j, sum(w) = n_T, w binary --
# the standard absolute-value linearization; pure MILP, GLPK-native.
milp_solve_l1 = function(A, n_T, roi_solver = "glpk", verbose = FALSE){
	assert_optimal_roi_solver(roi_solver)
	p = nrow(A); n = ncol(A)
	n_T = assert_optimal_milp_n_T(n_T, n)
	model = ompr::MIPModel()
	model = ompr::add_variable(model, w[i], i = 1:n, type = "binary")
	model = ompr::add_variable(model, tvar[j], j = 1:p, type = "continuous", lb = 0)
	model = ompr::set_objective(model, ompr::sum_expr(tvar[j], j = 1:p), "min")
	model = ompr::add_constraint(model, ompr::sum_expr(w[i], i = 1:n) == n_T)
	model = ompr::add_constraint(model, ompr::sum_expr(A[j, i] * w[i], i = 1:n) - tvar[j] <= 0, j = 1:p)
	model = ompr::add_constraint(model, ompr::sum_expr(A[j, i] * w[i], i = 1:n) + tvar[j] >= 0, j = 1:p)
	result = ompr::solve_model(model, ompr.roi::with_ROI(solver = roi_solver, verbose = verbose))
	status = optimal_milp_check_status(result, "abs_sum_diff (l1)")
	w = optimal_milp_extract_w(result, n)
	list(w = w, objective_value = sum(abs(A %*% w)), status = status)
}

# min_w w'Qw via exact product linearization: y_ij (i < j) with
# y_ij >= w_i + w_j - 1, y_ij <= w_i, y_ij <= w_j; objective
# sum_i Q_ii w_i + sum_{i<j} 2 Q_ij y_ij. Exact for binary w regardless of
# Q's definiteness (the minimizer pins each y_ij to w_i w_j from whichever
# side its coefficient pushes). n(n-1)/2 auxiliaries -- practical only up to
# the benchmarked linearization_max_n cutoff (TODO-5).
milp_solve_quadratic = function(Q, n_T, roi_solver = "glpk", verbose = FALSE){
	assert_optimal_roi_solver(roi_solver)
	n = nrow(Q)
	n_T = assert_optimal_milp_n_T(n_T, n)
	Qs = (Q + t(Q)) / 2
	diag_Q = diag(Qs)
	off_Q = 2 * Qs
	model = ompr::MIPModel()
	model = ompr::add_variable(model, w[i], i = 1:n, type = "binary")
	model = ompr::add_variable(model, y[i, j], i = 1:n, j = 1:n, type = "continuous", lb = 0, ub = 1, i < j)
	model = ompr::set_objective(model,
		ompr::sum_expr(diag_Q[i] * w[i], i = 1:n) +
		ompr::sum_expr(off_Q[i, j] * y[i, j], i = 1:n, j = 1:n, i < j),
		"min")
	model = ompr::add_constraint(model, ompr::sum_expr(w[i], i = 1:n) == n_T)
	model = ompr::add_constraint(model, y[i, j] <= w[i], i = 1:n, j = 1:n, i < j)
	model = ompr::add_constraint(model, y[i, j] <= w[j], i = 1:n, j = 1:n, i < j)
	model = ompr::add_constraint(model, y[i, j] >= w[i] + w[j] - 1, i = 1:n, j = 1:n, i < j)
	result = ompr::solve_model(model, ompr.roi::with_ROI(solver = roi_solver, verbose = verbose))
	status = optimal_milp_check_status(result, "quadratic (product-linearized)")
	w = optimal_milp_extract_w(result, n)
	list(w = w, objective_value = drop(t(w) %*% Qs %*% w), status = status)
}

# min_w (w'Hw + 1)/(n_T - w'Pw) via Dinkelbach's algorithm (Dinkelbach 1967):
# iterate the parametric subproblem min_w w'(H + t P)w (an ordinary
# product-linearized MILP), update t = (w'Hw + 1)/(n_T - w'Pw), stop when
# F(t) = min[g - t s] ~= 0. Finitely many distinct ratio values on the finite
# feasible set => provable finite termination; max_dinkelbach_iter bounds the
# worst case (callers implement the fallback-to-annealing policy on
# converged = FALSE; this layer only reports).
milp_solve_A_dinkelbach = function(P, H, n_T, roi_solver = "glpk", max_dinkelbach_iter = 30L, tol = 1e-9, verbose = FALSE){
	assert_optimal_roi_solver(roi_solver)
	n = nrow(P)
	n_T = assert_optimal_milp_n_T(n_T, n)
	g_of = function(w) drop(t(w) %*% H %*% w) + 1
	s_of = function(w) n_T - drop(t(w) %*% P %*% w)
	ratio_of = function(w){
		s = s_of(w)
		if (s <= 0) {
			stop("Degenerate allocation in the A-optimality ratio: n_T - w'Pw <= 0 (the treatment indicator is in the covariate span).")
		}
		g_of(w) / s
	}
	w = c(rep(1, n_T), rep(0, n - n_T))
	t_k = ratio_of(w)
	converged = FALSE
	iterations = 0L
	status = NA_character_
	while (iterations < max_dinkelbach_iter) {
		iterations = iterations + 1L
		sub = milp_solve_quadratic(H + t_k * P, n_T, roi_solver = roi_solver, verbose = verbose)
		status = sub$status
		# F(t_k) = min_w [g(w) - t_k s(w)] = (w'(H + t_k P)w) + (1 - t_k n_T)
		F_val = sub$objective_value + (1 - t_k * n_T)
		if (F_val >= -tol) {
			converged = TRUE
			break
		}
		w = sub$w
		t_k = ratio_of(w)
	}
	list(w = w, objective_value = ratio_of(w), iterations = iterations, converged = converged, status = status)
}
