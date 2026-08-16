# R wrappers for the native simulated-annealing solver (design_fixed_optimal.md
# TODO-6; kernel in src/design_optimal_annealing_search.cpp) and the "auto"
# solver dispatch that enforces EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N: exact
# "ompr" MILP within the cutoff (certificate "global"), annealing beyond it
# (certificate "annealing_converged"). Non-exported; DesignFixedOptimal's
# solver dispatch (TODO-9) is a thin consumer of optimal_solve_auto().

assert_annealing_args = function(n_chains, max_iter, initial_temp, cooling_rate){
	if (!(is.numeric(n_chains) && length(n_chains) == 1L && is.finite(n_chains) && n_chains >= 1 && n_chains == floor(n_chains))) {
		stop("n_chains must be a positive integer.")
	}
	if (!(is.numeric(max_iter) && length(max_iter) == 1L && is.finite(max_iter) && max_iter >= 1 && max_iter == floor(max_iter))) {
		stop("max_iter must be a positive integer.")
	}
	if (!is.null(initial_temp) && !(is.numeric(initial_temp) && length(initial_temp) == 1L && is.finite(initial_temp) && initial_temp > 0)) {
		stop("initial_temp must be NULL (auto-calibrated) or a single positive number.")
	}
	if (!(is.numeric(cooling_rate) && length(cooling_rate) == 1L && is.finite(cooling_rate) && cooling_rate > 0 && cooling_rate < 1)) {
		stop("cooling_rate must be a single number strictly between 0 and 1.")
	}
	invisible(TRUE)
}

# Auto-calibrate the starting temperature: probe random BCRD allocations and
# one random treated/control swap from each, and scale to the typical
# |objective delta| so early Metropolis acceptance of uphill moves is likely.
# Consumes R's RNG, so it is reproducible under the caller's set.seed().
estimate_annealing_initial_temp = function(f, n, n_T, n_probe = 16L){
	deltas = numeric(0)
	for (k in seq_len(n_probe)) {
		w = numeric(n)
		w[sample.int(n, n_T)] = 1
		f0 = f(w)
		a = sample(which(w == 1), 1L); b = sample(which(w == 0), 1L)
		w[a] = 0; w[b] = 1
		f1 = f(w)
		if (is.finite(f0) && is.finite(f1)) deltas = c(deltas, abs(f1 - f0))
	}
	max(10 * mean(deltas), 1e-8)
}

annealing_solve_kernel = function(objective_kind, M1, M2, n, n_T, n_chains, max_iter, initial_temp, cooling_rate, f_exact, custom_objective_xptr = NULL){
	assert_annealing_args(n_chains, max_iter, initial_temp, cooling_rate)
	n_T = assert_optimal_milp_n_T(n_T, n)
	if (is.null(initial_temp)) {
		initial_temp = estimate_annealing_initial_temp(f_exact, n, n_T)
	}
	res = annealing_design_search_cpp(
		objective_kind, M1, M2,
		as.integer(n_T), as.integer(n_chains), as.integer(max_iter),
		as.numeric(initial_temp), as.numeric(cooling_rate),
		custom_objective_xptr
	)
	list(
		w               = as.numeric(res$w),
		objective_value = res$objective_value,
		chain_values    = res$chain_values,
		certificate     = "annealing_converged",
		status          = "annealing_converged",
		n_chains        = as.integer(n_chains),
		max_iter        = as.integer(max_iter),
		initial_temp    = as.numeric(initial_temp),
		cooling_rate    = as.numeric(cooling_rate),
		final_temp      = res$final_temp
	)
}

annealing_solve_quadratic = function(Q, n_T, n_chains = 4L, max_iter = 20000L, initial_temp = NULL, cooling_rate = 0.999){
	Qs = (Q + t(Q)) / 2
	annealing_solve_kernel("quadratic", Qs, matrix(0, 0, 0), nrow(Qs), n_T,
		n_chains, max_iter, initial_temp, cooling_rate,
		f_exact = function(w) drop(t(w) %*% Qs %*% w))
}

annealing_solve_l1 = function(A, n_T, n_chains = 4L, max_iter = 20000L, initial_temp = NULL, cooling_rate = 0.999){
	annealing_solve_kernel("l1", A, matrix(0, 0, 0), ncol(A), n_T,
		n_chains, max_iter, initial_temp, cooling_rate,
		f_exact = function(w) sum(abs(A %*% w)))
}

annealing_solve_A_ratio = function(P, H, n_T, n_chains = 4L, max_iter = 20000L, initial_temp = NULL, cooling_rate = 0.999){
	Ps = (P + t(P)) / 2
	Hs = (H + t(H)) / 2
	annealing_solve_kernel("ratio", Ps, Hs, nrow(Ps), n_T,
		n_chains, max_iter, initial_temp, cooling_rate,
		f_exact = function(w){
			den = n_T - drop(t(w) %*% Ps %*% w)
			if (den <= 0) return(Inf)
			(drop(t(w) %*% Hs %*% w) + 1) / den
		})
}

# The "custom" objective (design_fixed_optimal.md TODO-7): a user-compiled
# black box f(X, w) under the src/user_compiled_fns.h convention, entering as
# an RcppXPtrUtils::cppXPtr() external pointer or a C++ source string (the
# shared normalize_user_cpp_fn() handles both; R closures are refused with
# the performance reason). Always annealing -- no structure to linearize --
# and always serial chains (user code carries no thread-safety guarantee).
annealing_solve_custom = function(X, custom_objective, n_T, n_chains = 4L, max_iter = 20000L, initial_temp = NULL, cooling_rate = 0.999){
	normalized = assert_custom_objective_xptr(custom_objective)
	X = as.matrix(X)
	storage.mode(X) = "double"
	annealing_solve_kernel("custom", X, matrix(0, 0, 0), nrow(X), n_T,
		n_chains, max_iter, initial_temp, cooling_rate,
		f_exact = function(w) eval_custom_design_objective_cpp(normalized$xptr, X, as.numeric(w)),
		custom_objective_xptr = normalized$xptr)
}

# The "auto" solver-resolution policy (design rule in design_fixed_optimal.md):
# the exact "ompr" path strictly dominates annealing wherever tractable, so
# annealing is chosen only in the complementary region -- a quadratic/ratio
# instance past linearization_max_n, or a Dinkelbach run that exhausted
# max_dinkelbach_iter (where the better of the exhausted run and a fresh
# annealing run is returned). l1 is a pure linear MILP with no linearization
# blowup, so it is always solved exactly. Adds solver/certificate fields on
# top of the underlying solver's return.
optimal_solve_auto = function(kind, Q = NULL, A = NULL, P = NULL, H = NULL, n_T,
		X = NULL, custom_objective = NULL,
		roi_solver = "glpk",
		linearization_max_n = EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N,
		n_chains = 4L, max_iter = 20000L, initial_temp = NULL, cooling_rate = 0.999,
		max_dinkelbach_iter = 30L, verbose = FALSE){
	if (!(is.character(kind) && length(kind) == 1L && kind %in% c("quadratic", "l1", "ratio", "custom"))) {
		stop('kind must be "quadratic", "l1", "ratio", or "custom".')
	}
	if (kind == "custom") {
		# Never expressible as a MILP: always the annealing solver, at any n.
		res = annealing_solve_custom(X, custom_objective, n_T, n_chains = n_chains,
			max_iter = max_iter, initial_temp = initial_temp, cooling_rate = cooling_rate)
		res$solver = "annealing"
		return(res)
	}
	if (kind == "l1") {
		res = milp_solve_l1(A, n_T, roi_solver = roi_solver, verbose = verbose)
		res$solver = "ompr"; res$certificate = "global"
		return(res)
	}
	n = if (kind == "quadratic") nrow(Q) else nrow(P)
	if (n <= linearization_max_n) {
		if (kind == "quadratic") {
			res = milp_solve_quadratic(Q, n_T, roi_solver = roi_solver, verbose = verbose)
			res$solver = "ompr"; res$certificate = "global"
			return(res)
		}
		res = milp_solve_A_dinkelbach(P, H, n_T, roi_solver = roi_solver,
			max_dinkelbach_iter = max_dinkelbach_iter, verbose = verbose)
		if (res$converged) {
			res$solver = "ompr"; res$certificate = "global"
			return(res)
		}
		# Dinkelbach exhausted max_dinkelbach_iter: fall back to annealing and
		# keep the better allocation; the certificate downgrades either way.
		message(sprintf(
			"Dinkelbach exhausted max_dinkelbach_iter = %d without converging; falling back to the annealing solver (certificate downgraded to \"annealing_converged\").",
			max_dinkelbach_iter))
		ann = annealing_solve_A_ratio(P, H, n_T, n_chains = n_chains, max_iter = max_iter,
			initial_temp = initial_temp, cooling_rate = cooling_rate)
		if (res$objective_value < ann$objective_value) {
			ann$w = res$w; ann$objective_value = res$objective_value
		}
		ann$solver = "annealing"
		return(ann)
	}
	message(sprintf(
		"n = %d exceeds linearization_max_n = %d: solving with the annealing solver (certificate \"annealing_converged\", not a certified global optimum). A commercial roi_solver (\"gurobi\"/\"cplex\") or a larger linearization_max_n extends the exact range.",
		n, linearization_max_n))
	res = if (kind == "quadratic") {
		annealing_solve_quadratic(Q, n_T, n_chains = n_chains, max_iter = max_iter,
			initial_temp = initial_temp, cooling_rate = cooling_rate)
	} else {
		annealing_solve_A_ratio(P, H, n_T, n_chains = n_chains, max_iter = max_iter,
			initial_temp = initial_temp, cooling_rate = cooling_rate)
	}
	res$solver = "annealing"
	res
}
