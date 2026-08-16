#' A Fixed, Deterministic Single-Allocation Optimal Design
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that computes
#' \strong{exactly one} allocation \eqn{w^*} -- the minimizer of a chosen
#' covariate-imbalance or information objective over all allocations with
#' \eqn{n_T = \mathrm{round}(n \cdot \mathrm{prob}_T)} treated subjects -- by
#' numerical optimization, rather than drawing from a restricted-randomization
#' distribution the way \code{\link[EDI:DesignFixedGreedy]{DesignFixedGreedy}}/
#' \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}} do.
#'
#' \strong{Objectives.} \code{objective = "D"}/\code{"A"} are the model-based
#' information criteria of \code{DesignFixedGreedyDOptimal} (identical
#' \code{interest}/\code{prior_precision} semantics, via the same shared
#' machinery); \code{"mahal_dist"}/\code{"abs_sum_diff"} are the
#' covariate-imbalance criteria of \code{DesignFixedGreedy} (identical
#' definitions, translated to exact solvable forms); \code{"custom"} is a
#' user-compiled black box under the \code{user_compiled_fns.h} calling
#' convention (\code{double f(const Eigen::MatrixXd& X, const Eigen::VectorXd& w)},
#' supplied as an \code{RcppXPtrUtils::cppXPtr()} external pointer or a C++
#' source string; a plain R function is refused -- it would be called once per
#' candidate inside a compiled hot loop).
#'
#' \strong{Solvers.} \code{solver = "auto"} (default) uses the exact
#' \code{"ompr"} MILP path (certificate \code{"global"}) wherever tractable --
#' always for \code{"abs_sum_diff"}; up to
#' \code{solver_args$linearization_max_n} (default 20, GLPK-benchmarked) for
#' the quadratic (\code{"mahal_dist"}/\code{"D"}) and Dinkelbach
#' (\code{"A"}) criteria -- and the native simulated-annealing solver
#' (certificate \code{"annealing_converged"}) beyond it, or always for
#' \code{"custom"}. \code{solver = "ompr"}/\code{"annealing"} force a path.
#' Commercial backends extend the exact range via
#' \code{solver_args$roi_solver} (\code{"glpk"} default, \code{"gurobi"},
#' \code{"cplex"}).
#'
#' \strong{Inference.} There is no usable randomization distribution
#' conditional on the observed data (given \eqn{X} there is exactly one
#' \eqn{w^*} up to the mirror coin), so permutation-style randomization
#' tests/CIs are unavailable (\code{supports_randomization_draw()} is
#' \code{FALSE}); the bootstrap randomization test IS available (the
#' mechanism -- "optimize this dataset" -- is replayed on each resampled
#' covariate matrix), as is all model-based and plain-resampling inference.
#'
#' \strong{The mirror coin.} At \code{prob_T = 0.5}, whenever the mirror
#' \eqn{1 - w^*} is a verified co-optimum (checked numerically by evaluating
#' the objective, never by a symmetry table), a fair seeded coin picks between
#' \eqn{w^*} and its mirror (\code{mirror_coin = TRUE}, the default). This
#' restores exact treated/control label symmetry -- and estimator
#' unbiasedness -- at zero cost to balance. A mirror that evaluates strictly
#' better than the solver's answer raises an error (it would be a solver bug).
#'
#' @examples
#' \dontrun{
#' des = DesignFixedOptimal$new(n = 14, response_type = 'continuous', objective = "mahal_dist")
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(14)))
#' des$assign_w_to_all_subjects()
#' des$get_optimization_diagnostics()
#' }
#' @export
DesignFixedOptimal = define_design_class(
	classname = "DesignFixedOptimal",
	inherit = DesignFixed,
	components = character(),
	public = list(
		#' @description Initialize a deterministic single-allocation optimal fixed
		#'   experimental design. The optimization itself does not run until
		#'   \code{assign_w_to_all_subjects()} (or
		#'   \code{draw_ws_according_to_design(r = 1)}) is called.
		#'
		#' @param response_type The data type of response values.
		#' @param prob_T Probability of treatment assignment, in \eqn{(0, 1)}; the
		#'   solve fixes the treated count at \eqn{\mathrm{round}(n \cdot prob_T)}.
		#' @param objective \code{"D"} (default), \code{"A"}, \code{"mahal_dist"},
		#'   \code{"abs_sum_diff"}, or \code{"custom"}; see the class documentation.
		#' @param interest For \code{objective = "D"}/\code{"A"} only:
		#'   \code{"treatment"} (default), \code{"all"}, a one-sided formula, a
		#'   formula string, or model-matrix column names -- identical semantics to
		#'   \code{DesignFixedGreedyDOptimal}.
		#' @param prior_precision For \code{objective = "D"}/\code{"A"} only:
		#'   \code{NULL} (default), a positive scalar \eqn{\tau}, or a symmetric
		#'   prior-precision matrix \eqn{R_0} -- identical semantics to
		#'   \code{DesignFixedGreedyDOptimal}.
		#' @param standardize_covariates If \code{TRUE} (default) and
		#'   \code{prior_precision} is a scalar, covariates are standardized before
		#'   the penalized criterion matrices are built. (\code{"mahal_dist"}/
		#'   \code{"abs_sum_diff"} standardize internally per their definitions
		#'   regardless.)
		#' @param custom_objective Required iff \code{objective = "custom"} (and
		#'   forbidden otherwise): an \code{RcppXPtrUtils::cppXPtr()} external
		#'   pointer or a C++ source string under the \code{user_compiled_fns.h}
		#'   calling convention.
		#' @param solver \code{"auto"} (default), \code{"ompr"}, or
		#'   \code{"annealing"}.
		#' @param solver_args A named list of solver tuning arguments. Supported:
		#'   \code{roi_solver} (\code{"glpk"}/\code{"gurobi"}/\code{"cplex"}),
		#'   \code{linearization_max_n}, \code{max_dinkelbach_iter},
		#'   \code{n_chains}, \code{max_iter}, \code{initial_temp},
		#'   \code{cooling_rate}, and (consumed by the BRT replicate path)
		#'   \code{brt_max_iter}, \code{brt_n_chains}, \code{brt_solver}.
		#' @param mirror_coin If \code{TRUE} (default), flip a fair seeded coin
		#'   between \eqn{w^*} and a \emph{verified co-optimal} mirror
		#'   \eqn{1 - w^*} after every solve (only possible at
		#'   \code{prob_T = 0.5}); see the class documentation.
		#' @param include_is_missing_as_a_new_feature Flag for missingness indicators.
		#' @param n Sample size (if fixed).
		#' @param verbose Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility (consumed by the annealing
		#'   solver and the mirror coin; MILP solves are deterministic up to the
		#'   seeded label flip).
		#'
		#' @return A new `DesignFixedOptimal` object
		initialize = function(
				response_type,
				prob_T = 0.5,
				objective = "D",
				interest = "treatment",
				prior_precision = NULL,
				standardize_covariates = TRUE,
				custom_objective = NULL,
				solver = "auto",
				solver_args = list(),
				mirror_coin = TRUE,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			# Always-on validation (never assert-gated), matching DesignFixedGreedyDOptimal.
			if (!is.numeric(prob_T) || length(prob_T) != 1L || !is.finite(prob_T) || prob_T <= 0 || prob_T >= 1) {
				stop("prob_T must be a single number strictly between 0 and 1.")
			}
			allowed_objectives = c("D", "A", "mahal_dist", "abs_sum_diff", "custom")
			if (!is.character(objective) || length(objective) != 1L || !(objective %in% allowed_objectives)) {
				stop('objective must be one of "D", "A", "mahal_dist", "abs_sum_diff", or "custom".')
			}
			interest_kind = NULL
			if (objective %in% c("D", "A")) {
				validated = validate_optimal_design_objective_args(
					objective, interest, prior_precision, standardize_covariates,
					allowed_objectives = c("D", "A")
				)
				interest = validated$interest
				interest_kind = validated$interest_kind
			} else {
				if (!identical(interest, "treatment")) {
					stop('interest is only meaningful for objective = "D"/"A".')
				}
				if (!is.null(prior_precision)) {
					stop('prior_precision is only meaningful for objective = "D"/"A".')
				}
				if (!is.logical(standardize_covariates) || length(standardize_covariates) != 1L || is.na(standardize_covariates)) {
					stop("standardize_covariates must be TRUE or FALSE.")
				}
			}
			custom_objective_normalized = NULL
			if (identical(objective, "custom")) {
				custom_objective_normalized = assert_custom_objective_xptr(custom_objective)
			} else if (!is.null(custom_objective)) {
				stop('custom_objective may only be supplied with objective = "custom".')
			}
			if (!is.character(solver) || length(solver) != 1L || !(solver %in% c("auto", "ompr", "annealing"))) {
				stop('solver must be "auto", "ompr", or "annealing".')
			}
			if (identical(solver, "ompr") && identical(objective, "custom")) {
				stop('objective = "custom" cannot be solved by the "ompr" MILP path (a black-box objective has no structure to linearize); use solver = "auto" or "annealing".')
			}
			if (!is.list(solver_args) || (length(solver_args) > 0L && (is.null(names(solver_args)) || any(!nzchar(names(solver_args)))))) {
				stop("solver_args must be a named list.")
			}
			known_solver_args = c(
				"roi_solver", "linearization_max_n", "max_dinkelbach_iter",
				"n_chains", "max_iter", "initial_temp", "cooling_rate",
				"brt_max_iter", "brt_n_chains", "brt_solver"
			)
			unknown = setdiff(names(solver_args), known_solver_args)
			if (length(unknown) > 0L) {
				stop(sprintf("Unknown solver_args: %s. Supported: %s.",
					paste(unknown, collapse = ", "), paste(known_solver_args, collapse = ", ")))
			}
			if (!is.null(solver_args$roi_solver)) {
				# Closed-set check now; package availability is checked lazily at solve time.
				if (!(is.character(solver_args$roi_solver) && length(solver_args$roi_solver) == 1L &&
						solver_args$roi_solver %in% EDI_OPTIMAL_ROI_SOLVERS)) {
					stop('solver_args$roi_solver must be one of "glpk", "gurobi", "cplex".')
				}
			}
			if (!is.logical(mirror_coin) || length(mirror_coin) != 1L || is.na(mirror_coin)) {
				stop("mirror_coin must be TRUE or FALSE.")
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$objective = objective
			private$interest = interest
			private$interest_kind = interest_kind
			private$prior_precision = prior_precision
			private$standardize_covariates = standardize_covariates
			private$custom_objective_normalized = custom_objective_normalized
			private$solver = solver
			private$solver_args = solver_args
			private$mirror_coin = mirror_coin
			private$uses_covariates = TRUE
		},
		#' @description The objective this design was constructed with.
		#' @return One of \code{"D"}, \code{"A"}, \code{"mahal_dist"},
		#'   \code{"abs_sum_diff"}, \code{"custom"}.
		get_objective = function() private$objective,
		#' @description The parameter-interest setting (\code{"D"}/\code{"A"} only).
		#' @return The \code{interest} construction argument.
		get_interest = function() private$interest,
		#' @description The Bayesian prior precision this design was constructed with.
		#' @return \code{NULL}, a positive scalar, or a symmetric matrix.
		get_prior_precision = function() private$prior_precision,
		#' @description The solver setting this design was constructed with.
		#' @return \code{"auto"}, \code{"ompr"}, or \code{"annealing"}.
		get_solver = function() private$solver,
		#' @description The mirror-coin setting this design was constructed with.
		#' @return \code{TRUE} or \code{FALSE}.
		get_mirror_coin = function() private$mirror_coin,
		#' @description Diagnostics cached by the most recent solve: the solver
		#'   used, \code{optimum_certificate} (\code{"global"} for exact
		#'   \code{"ompr"} solves, \code{"annealing_converged"} otherwise), the
		#'   achieved objective value, mirror-coin outcome
		#'   (\code{mirror_feasible}/\code{mirror_tied}/\code{mirror_flipped}),
		#'   elapsed time, and the solver's own detail fields.
		#' @return A named list, or \code{NULL} if no solve has run yet.
		get_optimization_diagnostics = function() private$optimization_diagnostics,
		#' @description Characterization: \code{FALSE} -- given the observed data
		#'   there is exactly one \eqn{w^*} (up to the vacuous 2-atom mirror pair),
		#'   so there is no randomization distribution to draw from and
		#'   permutation-style randomization tests/CIs are unavailable. The
		#'   bootstrap randomization test remains available via
		#'   \code{supports_resampling_replay()} (the deterministic mechanism is
		#'   replayed on each resample).
		#' @return Always \code{FALSE} for this class.
		supports_randomization_draw = function(){
			FALSE
		}
	),
	private = list(
		objective = NULL,
		interest = NULL,
		interest_kind = NULL,
		prior_precision = NULL,
		standardize_covariates = NULL,
		custom_objective_normalized = NULL,
		solver = NULL,
		solver_args = NULL,
		mirror_coin = NULL,
		optimization_diagnostics = NULL,
		# Resolve the constructed objective into solver inputs over the model
		# matrix X: list(kind, and the kind's matrices plus f_eval, an exact
		# evaluator used by the mirror-coin verification).
		build_solver_inputs = function(X, n_T){
			obj = private$objective
			if (obj %in% c("D", "A")) {
				need_H = identical(obj, "A") && private$interest_kind %in% c("all", "subset")
				PH = build_optimal_design_P_H(
					X = X,
					interest = if (need_H && identical(private$interest_kind, "subset")) private$interest else "all",
					prior_precision = private$prior_precision,
					standardize_covariates = private$standardize_covariates,
					need_H = need_H
				)
				if (need_H) {
					P = PH$P; H = PH$H
					return(list(kind = "ratio", P = P, H = H, f_eval = function(w){
						den = n_T - drop(t(w) %*% P %*% w)
						if (den <= 0) return(Inf)
						(drop(t(w) %*% H %*% w) + 1) / den
					}))
				}
				Q = PH$P
				return(list(kind = "quadratic", Q = Q, f_eval = function(w) drop(t(w) %*% Q %*% w)))
			}
			if (obj %in% c("mahal_dist", "abs_sum_diff")) {
				prep = prepare_optimal_objective_matrices(X, obj)
				if (identical(prep$kind, "quadratic")) {
					Q = prep$Q
					return(list(kind = "quadratic", Q = Q, mahal_fell_back = prep$mahal_fell_back,
						f_eval = function(w) drop(t(w) %*% Q %*% w)))
				}
				A = prep$A
				return(list(kind = "l1", A = A, mahal_fell_back = prep$mahal_fell_back,
					f_eval = function(w) sum(abs(A %*% w))))
			}
			# custom
			xptr = private$custom_objective_normalized$xptr
			list(kind = "custom", X = X, xptr = xptr,
				f_eval = function(w) eval_custom_design_objective_cpp(xptr, X, as.numeric(w)))
		},
		# One full solve: dispatch per the solver setting, then the mirror coin.
		# Returns the (possibly mirrored) w and caches diagnostics.
		solve_optimal_w = function(){
			n = self$get_n()
			n_T = as.integer(round(n * private$prob_T))
			if (n_T < 1L || n_T > n - 1L) {
				stop(sprintf("prob_T = %g with n = %d yields a treated count of %d; need at least one treated and one control subject.", private$prob_T, n, n_T))
			}
			X = private$X[1:n, , drop = FALSE]
			inputs = private$build_solver_inputs(X, n_T)
			sa = private$solver_args
			arg_or = function(name, default) if (is.null(sa[[name]])) default else sa[[name]]
			t0 = proc.time()[["elapsed"]]
			res = if (identical(private$solver, "auto")) {
				optimal_solve_auto(
					kind = inputs$kind, Q = inputs$Q, A = inputs$A, P = inputs$P, H = inputs$H,
					X = inputs$X, custom_objective = inputs$xptr,
					n_T = n_T,
					roi_solver = arg_or("roi_solver", "glpk"),
					linearization_max_n = arg_or("linearization_max_n", EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N),
					n_chains = arg_or("n_chains", 4L),
					max_iter = arg_or("max_iter", 20000L),
					initial_temp = arg_or("initial_temp", NULL),
					cooling_rate = arg_or("cooling_rate", 0.999),
					max_dinkelbach_iter = arg_or("max_dinkelbach_iter", 30L),
					verbose = private$verbose
				)
			} else if (identical(private$solver, "ompr")) {
				roi_solver = arg_or("roi_solver", "glpk")
				out = switch(inputs$kind,
					quadratic = milp_solve_quadratic(inputs$Q, n_T, roi_solver = roi_solver, verbose = private$verbose),
					l1        = milp_solve_l1(inputs$A, n_T, roi_solver = roi_solver, verbose = private$verbose),
					ratio     = {
						d = milp_solve_A_dinkelbach(inputs$P, inputs$H, n_T, roi_solver = roi_solver,
							max_dinkelbach_iter = arg_or("max_dinkelbach_iter", 30L), verbose = private$verbose)
						if (!d$converged) {
							stop(sprintf(paste0(
								'The forced solver = "ompr" Dinkelbach loop exhausted max_dinkelbach_iter = %d ',
								'without converging; raise solver_args$max_dinkelbach_iter or use solver = "auto" ',
								'(which falls back to annealing).'), arg_or("max_dinkelbach_iter", 30L)))
						}
						d
					}
				)
				out$solver = "ompr"; out$certificate = "global"
				out
			} else {
				out = switch(inputs$kind,
					quadratic = annealing_solve_quadratic(inputs$Q, n_T,
						n_chains = arg_or("n_chains", 4L), max_iter = arg_or("max_iter", 20000L),
						initial_temp = arg_or("initial_temp", NULL), cooling_rate = arg_or("cooling_rate", 0.999)),
					l1        = annealing_solve_l1(inputs$A, n_T,
						n_chains = arg_or("n_chains", 4L), max_iter = arg_or("max_iter", 20000L),
						initial_temp = arg_or("initial_temp", NULL), cooling_rate = arg_or("cooling_rate", 0.999)),
					ratio     = annealing_solve_A_ratio(inputs$P, inputs$H, n_T,
						n_chains = arg_or("n_chains", 4L), max_iter = arg_or("max_iter", 20000L),
						initial_temp = arg_or("initial_temp", NULL), cooling_rate = arg_or("cooling_rate", 0.999)),
					custom    = annealing_solve_custom(inputs$X, private$custom_objective_normalized$xptr, n_T,
						n_chains = arg_or("n_chains", 4L), max_iter = arg_or("max_iter", 20000L),
						initial_temp = arg_or("initial_temp", NULL), cooling_rate = arg_or("cooling_rate", 0.999))
				)
				out$solver = "annealing"
				out
			}
			elapsed_sec = proc.time()[["elapsed"]] - t0
			w = as.numeric(res$w)
			# The mirror coin: verify-then-flip, never a symmetry table. Only
			# possible when the mirror is feasible (n - n_T == n_T, i.e.
			# prob_T = 0.5) AND it numerically ties the solver's optimum.
			mirror_feasible = isTRUE(private$mirror_coin) && (n - n_T) == n_T
			mirror_tied = FALSE
			mirror_flipped = FALSE
			if (mirror_feasible) {
				f_w = inputs$f_eval(w)
				w_m = 1 - w
				f_m = inputs$f_eval(w_m)
				tol = 1e-9 * max(1, abs(f_w))
				if (is.finite(f_m) && f_m < f_w - tol) {
					stop(sprintf(paste0(
						"Solver bug: the mirror allocation evaluates strictly better than the returned ",
						"optimum (%.12g < %.12g) -- the solver failed to find its own mirror image. ",
						"Please report this."), f_m, f_w))
				}
				mirror_tied = is.finite(f_m) && abs(f_m - f_w) <= tol
				if (mirror_tied && stats::runif(1) < 0.5) {
					w = w_m
					mirror_flipped = TRUE
				}
			}
			private$optimization_diagnostics = c(
				list(
					objective = private$objective,
					kind = inputs$kind,
					mahal_fell_back = isTRUE(inputs$mahal_fell_back),
					solver = res$solver,
					optimum_certificate = res$certificate,
					objective_value = res$objective_value,
					n = n, n_T = n_T,
					mirror_coin = isTRUE(private$mirror_coin),
					mirror_feasible = mirror_feasible,
					mirror_tied = mirror_tied,
					mirror_flipped = mirror_flipped,
					elapsed_sec = elapsed_sec
				),
				res[setdiff(names(res), c("w", "solver", "certificate", "objective_value"))]
			)
			w
		},
		draw_ws_raw = function(r = 1L){
			private$maybe_set_seed()
			if (!(is.numeric(r) && length(r) == 1L && is.finite(r) && r == 1)) {
				stop(paste0(
					"DesignFixedOptimal computes exactly one optimal allocation; r > 1 draws are not ",
					"a randomization distribution and are forbidden (randomization tests/CIs are ",
					"fenced upstream via supports(\"randomization_draw\") = FALSE)."
				))
			}
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
			}
			n = self$get_n()
			if (is.null(private$X) || ncol(private$X) == 0){
				# No covariates: nothing to optimize -- degenerate to a random
				# allocation with the exact treated count (matching the sibling
				# optimal-search designs' documented fallback).
				n_T = as.integer(round(n * private$prob_T))
				return(matrix(sample(c(rep(1, n_T), rep(0, n - n_T))), ncol = 1))
			}
			private$covariate_impute_if_necessary_and_then_create_model_matrix()
			matrix(private$solve_optimal_w(), ncol = 1)
		}
	)
)
