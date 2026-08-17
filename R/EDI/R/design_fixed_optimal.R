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
#' \strong{The objective family and its argument mapping.} Write
#' \eqn{Z_0 = [1\ X]}, \eqn{P = Z_0 (Z_0^\top Z_0)^{-1} Z_0^\top}, and
#' \eqn{s(w) = n_T - w^\top P w}. The objectives map to constructor arguments
#' and solved forms as follows:
#' \describe{
#'   \item{\code{"D"} (determinant / \eqn{D_M}, \eqn{D_s}) and \code{"A"}
#'     with \code{interest = "treatment"}}{maximize \eqn{s(w)}, solved as the
#'     binary quadratic program \eqn{\min_w w^\top P w} -- identical criteria
#'     and \code{interest}/\code{prior_precision} semantics to
#'     \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}}
#'     (the same shared construction machinery is used, so the two classes
#'     optimize literally the same matrices).}
#'   \item{\code{"A"} with \code{interest = "all"} or a covariate subset
#'     (\eqn{A}, \eqn{A_s})}{minimize \eqn{(w^\top H w + 1)/s(w)} with the
#'     sibling class's \eqn{H}/\eqn{H_S}, solved exactly via Dinkelbach's
#'     algorithm (Dinkelbach 1967) over product-linearized MILP subproblems.}
#'   \item{Bayesian \eqn{D_B}/\eqn{A_B}}{\code{prior_precision =} a scalar
#'     \eqn{\tau} (covariates only; intercept and treatment unpenalized) or a
#'     full matrix \eqn{R_0}, replacing \eqn{(Z_0^\top Z_0)^{-1}} with the
#'     ridge-regularized inverse -- identical to the sibling class.}
#'   \item{\code{"mahal_dist"} / \code{"abs_sum_diff"}}{
#'     \code{\link[EDI:DesignFixedGreedy]{DesignFixedGreedy}}'s
#'     covariate-imbalance criteria, definitionally identical (column-centered
#'     \eqn{X}, the same standardization and singular-covariance fallback),
#'     translated to exactly solvable forms: the Mahalanobis criterion is the
#'     pure quadratic \eqn{w^\top Q w} with \eqn{Q = 4 X \Sigma^{-1} X^\top / n^2},
#'     and the absolute-sum criterion is an l1 objective solved by the
#'     standard linear MILP.}
#'   \item{\code{"custom"}}{a user-compiled black box under the
#'     \code{user_compiled_fns.h} calling convention
#'     (\code{double f(const Eigen::MatrixXd& X, const Eigen::VectorXd& w)},
#'     minimized), supplied via \code{custom_objective}; always solved by the
#'     annealing path (no structure to linearize).}
#' }
#'
#' \strong{Solvers and certificates.} \code{solver = "auto"} (default) uses
#' the exact \code{"ompr"} MILP path (\code{optimum_certificate = "global"},
#' a certified global optimum) wherever tractable -- always for
#' \code{"abs_sum_diff"} (pure linear MILP); up to
#' \code{solver_args$linearization_max_n} (default 20, set by a GLPK
#' benchmark: the product linearization adds \eqn{n(n-1)/2} auxiliaries and
#' branch-and-bound cost climbs steeply past \eqn{n \approx 20}) for the
#' quadratic and Dinkelbach criteria -- and the native simulated-annealing
#' solver beyond it, or always for \code{"custom"}. The annealing solver is a
#' formal method, not a heuristic: Metropolis acceptance over
#' treated/control swaps with a configurable cooling schedule, for which
#' Hajek (1988) proves convergence in probability to the global optimum
#' under a slow-enough (logarithmic) schedule; the practical geometric
#' schedule used by default is asymptotically motivated only, so its
#' certificate is always \code{"annealing_converged"}, never
#' \code{"global"}. \code{solver = "ompr"}/\code{"annealing"} force a path.
#' Commercial backends extend the exact range via
#' \code{solver_args$roi_solver}; see that parameter's wiring guides.
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
#' @references Dinkelbach, W. (1967). On nonlinear fractional programming.
#'   \emph{Management Science} 13(7):492-498, for the exact A-optimality
#'   reduction. Hajek, B. (1988). Cooling schedules for optimal annealing.
#'   \emph{Mathematics of Operations Research} 13(2):311-329, for the
#'   annealing solver's formal convergence property. Atkinson, A. C., Donev,
#'   A. N., and Tobias, R. D. (2007). \emph{Optimum Experimental Designs,
#'   with SAS}. Oxford University Press, for the D-/A-optimality criteria.
#' @examples
#' \dontrun{
#' des = DesignFixedOptimal$new(n = 14, response_type = 'continuous', objective = "mahal_dist")
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(14)))
#' des$assign_w_to_all_subjects()
#' des$get_optimization_diagnostics()
#'
#' # A custom compiled objective (the user_compiled_fns.h calling convention),
#' # built with RcppXPtrUtils::cppXPtr() -- here, squared imbalance of the
#' # centered covariate sums:
#' fobj = RcppXPtrUtils::cppXPtr(
#'   "double f(const Eigen::MatrixXd& X, const Eigen::VectorXd& w) {
#'     Eigen::RowVectorXd mu = X.colwise().mean();
#'     Eigen::MatrixXd Xc = X.rowwise() - mu;
#'     Eigen::VectorXd s = 2.0 * w - Eigen::VectorXd::Ones(X.rows());
#'     return (Xc.transpose() * s).squaredNorm();
#'   }", depends = "RcppEigen")
#' des2 = DesignFixedOptimal$new(n = 14, response_type = 'continuous',
#'   objective = "custom", custom_objective = fobj)
#' des2$add_all_subjects_to_experiment(data.frame(x1 = rnorm(14)))
#' des2$assign_w_to_all_subjects()
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
		#'   calling convention
		#'   (\code{double f(const Eigen::MatrixXd& X, const Eigen::VectorXd& w)};
		#'   \code{X} is the design's model matrix, \code{w} a candidate 0/1
		#'   allocation; the returned value is \emph{minimized}). A source string
		#'   is compiled through the same \code{cppXPtr} mechanism and retained so
		#'   parallel workers can recompile locally. \strong{A plain R function is
		#'   not accepted, and cannot be:} the annealing solver evaluates the
		#'   objective once per candidate swap -- typically thousands of times per
		#'   chain, times \code{n_chains}, and again per BRT replicate -- and an
		#'   R-call round-trip on every one of those evaluations is orders of
		#'   magnitude too slow to be usable, not merely slower. Since
		#'   \code{"custom"} is always solved by annealing (never the MILP path),
		#'   there is no lower-frequency code path where an R closure would be
		#'   merely inconvenient; the restriction is a hard performance
		#'   requirement of this objective's only execution path. See the class
		#'   examples for a worked \code{cppXPtr()} construction. \strong{Save/
		#'   reload note:} a raw \code{cppXPtr()} object does not survive
		#'   \code{saveRDS()}/\code{readRDS()} (see \code{\link{Design}}'s
		#'   "Saving and loading" section); pass a C++ source string instead
		#'   if this design needs to be reloadable.
		#' @param solver \code{"auto"} (default), \code{"ompr"}, or
		#'   \code{"annealing"}.
		#' @param solver_args A named list of solver tuning arguments. Supported:
		#'   \code{roi_solver} (\code{"glpk"}/\code{"gurobi"}/\code{"cplex"} --
		#'   a \emph{closed} set; arbitrary ROI plugin names are rejected),
		#'   \code{linearization_max_n}, \code{max_dinkelbach_iter},
		#'   \code{n_chains}, \code{max_iter}, \code{initial_temp},
		#'   \code{cooling_rate}, and (consumed by the BRT replicate path)
		#'   \code{brt_max_iter}, \code{brt_n_chains}, \code{brt_solver}.
		#'
		#'   \strong{Wiring up Gurobi} (\code{roi_solver = "gurobi"}): (1) obtain
		#'   a Gurobi license (free academic licenses are available) and install
		#'   the Gurobi Optimizer itself -- this sets up \code{GUROBI_HOME} and
		#'   the license file, entirely outside this package's control; (2)
		#'   install Gurobi's own R package, which is \emph{not on CRAN} -- it
		#'   ships inside the Gurobi installation:
		#'   \code{R CMD INSTALL "$GUROBI_HOME/R/gurobi_<version>_R_<Rmajor.minor>.tar.gz"}
		#'   (exact filename depends on your Gurobi version and platform); (3)
		#'   \code{install.packages("ROI.plugin.gurobi")} from CRAN; (4) verify
		#'   \code{"gurobi" \%in\% ROI::ROI_registered_solvers()} after loading
		#'   the plugin; (5) pass \code{solver_args = list(roi_solver = "gurobi")}.
		#'
		#'   \strong{Wiring up CPLEX} (\code{roi_solver = "cplex"}): (1) obtain
		#'   an IBM CPLEX license (free academic licenses are available) and
		#'   install IBM ILOG CPLEX Optimization Studio; (2) install
		#'   \code{Rcplex} (CRAN) -- unlike the Gurobi bridge, it \emph{compiles
		#'   from source against your local CPLEX SDK} and must be pointed at
		#'   your CPLEX version's include/lib directories at install time; follow
		#'   \code{Rcplex}'s own INSTALL instructions for your CPLEX version
		#'   rather than a fixed command, since the flags change across CPLEX
		#'   releases; (3) \code{install.packages("ROI.plugin.cplex")} from CRAN;
		#'   (4) verify \code{"cplex" \%in\% ROI::ROI_registered_solvers()}; (5)
		#'   pass \code{solver_args = list(roi_solver = "cplex")}.
		#'
		#'   \code{ROI.plugin.gurobi}/\code{ROI.plugin.cplex}/\code{Rcplex} are
		#'   deliberately \emph{never} listed in this package's \code{Suggests}:
		#'   declaring them would misrepresent the dependency as something
		#'   \code{install.packages()} could satisfy, when the vendor
		#'   installation/license underneath cannot be. Availability is checked
		#'   lazily at solve time; if the plugin loads but the solve fails, the
		#'   likely cause is a missing vendor installation or license.
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
			if (!is.character(solver) || length(solver) != 1L || !(solver %in% c("auto", "ompr", "annealing"))) {
				stop('solver must be "auto", "ompr", or "annealing".')
			}
			if (identical(solver, "ompr") && identical(objective, "custom")) {
				stop('objective = "custom" cannot be solved by the "ompr" MILP path (a black-box objective has no structure to linearize); use solver = "auto" or "annealing".')
			}
			custom_objective_normalized = NULL
			if (identical(objective, "custom")) {
				custom_objective_normalized = assert_custom_objective_xptr(custom_objective)
			} else if (!is.null(custom_objective)) {
				stop('custom_objective may only be supplied with objective = "custom".')
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
			if (!is.null(solver_args$brt_solver)) {
				if (!(is.character(solver_args$brt_solver) && length(solver_args$brt_solver) == 1L &&
						solver_args$brt_solver %in% c("annealing", "ompr"))) {
					stop('solver_args$brt_solver must be "annealing" or "ompr".')
				}
				if (identical(solver_args$brt_solver, "ompr") && identical(objective, "custom")) {
					stop('objective = "custom" cannot use solver_args$brt_solver = "ompr" (no structure to linearize).')
				}
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
		},
		#' @description BRT replicate-mode switch (called by the
		#'   bootstrap-randomization-test machinery ahead of each replayed draw;
		#'   see \code{Design$prepare_for_resampling_replay()}). Subsequent solves
		#'   use the per-replicate solver profile: \code{solver_args$brt_solver}
		#'   (default \code{"annealing"} with the reduced
		#'   \code{brt_max_iter}/\code{brt_n_chains} schedule -- replicate
		#'   assignments need to be faithful applications of the mechanism, not
		#'   individually re-verified to the observed solve's convergence
		#'   standard; \code{"ompr"} buys exact per-replicate solves at the
		#'   user's expense). Idempotent; the mirror coin still applies per
		#'   replicate (the BRT replays the coin-inclusive mechanism).
		#' @return \code{invisible(NULL)}.
		prepare_for_resampling_replay = function(){
			private$brt_replicate_mode = TRUE
			invisible(NULL)
		}
	),
	private = list(
		objective = NULL,
		interest = NULL,
		interest_kind = NULL,
		prior_precision = NULL,
		standardize_covariates = NULL,
		custom_objective_normalized = NULL,
		custom_objective_checked = FALSE,
		solver = NULL,
		solver_args = NULL,
		mirror_coin = NULL,
		optimization_diagnostics = NULL,
		brt_replicate_mode = FALSE,
		# Compiled RcppXPtrUtils::cppXPtr() pointers do not survive a
		# saveRDS()/readRDS() round trip -- reload leaves a "reconstructed"
		# externalptr object whose underlying C pointer no longer refers to
		# live compiled code, and any call into it errors with the opaque
		# "external pointer is not valid" (confirmed empirically: same-session
		# use works, a real cross-process readRDS() reload reproduces this
		# exact error; see save_load_api.md's serialization audit). Checked
		# once per (reloaded-or-not) object, not once per annealing swap
		# evaluation, via a real probe call using the actual X/n_T -- so a
		# genuine bug in the user's objective still surfaces as a normal
		# error, not a false "stale pointer" diagnosis. When the objective was
		# supplied as a C++ source string (not a raw cppXPtr()), recompiling
		# here transparently fixes reload; when it was supplied as a raw
		# pointer with no retained source, there is nothing to recompile from
		# and this raises an explicit, actionable error instead of the opaque
		# one.
		ensure_custom_objective_xptr_live = function(X, n_T){
			if (isTRUE(private$custom_objective_checked)) return(invisible(NULL))
			private$custom_objective_checked = TRUE
			normalized = private$custom_objective_normalized
			w_probe = numeric(nrow(X))
			w_probe[seq_len(n_T)] = 1
			ok = tryCatch({
				eval_custom_design_objective_cpp(normalized$xptr, X, w_probe)
				TRUE
			}, error = function(e){
				if (!grepl("external pointer", conditionMessage(e), ignore.case = TRUE)) stop(e)
				FALSE
			})
			if (!ok) {
				if (is.null(normalized$src)) {
					stop(
						"This DesignFixedOptimal's custom_objective external pointer is no longer valid, ",
						"most likely because this object was saveRDS()/readRDS()'d across R sessions -- ",
						"compiled function pointers do not survive that round trip (see the Design ",
						"'Saving and loading' section). It was constructed directly from an ",
						"RcppXPtrUtils::cppXPtr() object with no retained C++ source, so it cannot be ",
						"recompiled automatically. Reconstruct this design with a fresh cppXPtr() call, or ",
						"pass custom_objective as a C++ source string next time so it can recompile itself ",
						"automatically after a reload.",
						call. = FALSE
					)
				}
				if (!requireNamespace("RcppXPtrUtils", quietly = TRUE)) {
					stop(
						"Package 'RcppXPtrUtils' is required to recompile this design's custom_objective ",
						"after a saveRDS()/readRDS() reload; please install it.",
						call. = FALSE
					)
				}
				normalized$xptr = RcppXPtrUtils::cppXPtr(code = normalized$src, depends = "RcppEigen")
				private$custom_objective_normalized = normalized
			}
			invisible(NULL)
		},
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
			if (identical(private$objective, "custom")) {
				private$ensure_custom_objective_xptr_live(X, n_T)
			}
			inputs = private$build_solver_inputs(X, n_T)
			sa = private$solver_args
			arg_or = function(name, default) if (is.null(sa[[name]])) default else sa[[name]]
			t0 = proc.time()[["elapsed"]]
			# BRT replicate profile (TODO-8b): each replicate re-optimizes the
			# resampled covariates, so the per-solve budget is reduced by default
			# (brt_solver = "annealing", brt_n_chains = 1, brt_max_iter modest);
			# brt_solver = "ompr" opts into exact per-replicate solves.
			brt_mode = isTRUE(private$brt_replicate_mode)
			res = if (brt_mode && !identical(arg_or("brt_solver", "annealing"), "ompr")) {
				out = switch(inputs$kind,
					quadratic = annealing_solve_quadratic(inputs$Q, n_T,
						n_chains = arg_or("brt_n_chains", 1L), max_iter = arg_or("brt_max_iter", 2000L),
						initial_temp = arg_or("initial_temp", NULL), cooling_rate = arg_or("cooling_rate", 0.999)),
					l1        = annealing_solve_l1(inputs$A, n_T,
						n_chains = arg_or("brt_n_chains", 1L), max_iter = arg_or("brt_max_iter", 2000L),
						initial_temp = arg_or("initial_temp", NULL), cooling_rate = arg_or("cooling_rate", 0.999)),
					ratio     = annealing_solve_A_ratio(inputs$P, inputs$H, n_T,
						n_chains = arg_or("brt_n_chains", 1L), max_iter = arg_or("brt_max_iter", 2000L),
						initial_temp = arg_or("initial_temp", NULL), cooling_rate = arg_or("cooling_rate", 0.999)),
					custom    = annealing_solve_custom(inputs$X, private$custom_objective_normalized$xptr, n_T,
						n_chains = arg_or("brt_n_chains", 1L), max_iter = arg_or("brt_max_iter", 2000L),
						initial_temp = arg_or("initial_temp", NULL), cooling_rate = arg_or("cooling_rate", 0.999))
				)
				out$solver = "annealing"
				out
			} else if (identical(private$solver, "auto") || (brt_mode && identical(arg_or("brt_solver", "annealing"), "ompr"))) {
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
					solver_profile = if (brt_mode) "brt_replicate" else "main",
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
