#' A Fixed, Model-Based Optimal Design via Greedy Pairwise-Exchange Search
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that searches, among
#' allocations with exactly \eqn{n_T = \mathrm{round}(n \cdot \mathrm{prob}_T)} treated
#' subjects, for allocations optimizing a \emph{model-based information-matrix}
#' criterion implied by the linear model \eqn{y = \beta_T w + Z_0 \gamma + \epsilon}
#' with \eqn{Z_0 = [1\ X]}, via a native C++ greedy pairwise-exchange (Fedorov/
#' DETMAX-style) local search. This class is the merger of the former
#' \code{DesignFixedDOptimal} and \code{DesignFixedAOptimal} classes; the criterion is
#' selected by the \code{objective} and \code{interest} constructor arguments.
#'
#' \strong{The optimality-criterion family and its argument mapping.} Write
#' \eqn{M(w) = [w\ Z_0]^\top [w\ Z_0]} for the information (moment) matrix,
#' \eqn{P = Z_0 (Z_0^\top Z_0)^{-1} Z_0^\top}, and
#' \eqn{s(w) = n_T - w^\top P w} (the treatment-coefficient information given the
#' covariate block). The classical criteria map to constructor arguments as
#' follows:
#' \describe{
#'   \item{\eqn{D_M} -- full-matrix determinant optimality (maximize
#'     \eqn{\det M(w)}, i.e. \eqn{|M|})}{\code{objective = "D", interest = "all"}.
#'     By the Schur-complement identity
#'     \eqn{\det M(w) = \det(Z_0^\top Z_0) \cdot s(w)} (with
#'     \eqn{w^\top w = n_T} fixed and \eqn{Z_0} not depending on \eqn{w}), the
#'     covariate block factors out, so \eqn{D_M} reduces to maximizing
#'     \eqn{s(w)}.}
#'   \item{\eqn{D_s} -- subset determinant optimality (minimize
#'     \eqn{\det(K^\top M(w)^{-1} K)} for a coordinate-selection \eqn{K}: the
#'     treatment coefficient plus a chosen covariate subset)}{the default
#'     \code{objective = "D", interest = "treatment"} is \eqn{D_s} with the
#'     interest set = \{treatment\}; \code{interest = ~ x1 + x2} (a one-sided
#'     formula) or \code{interest = c("x1", "x2")} (model-matrix column names)
#'     selects treatment + those covariates. Because \eqn{w} enters only the
#'     treatment row/column of \eqn{M(w)}, every such \eqn{D_s} criterion
#'     factorizes as \eqn{\det(V_{SS})/s(w)} with \eqn{\det(V_{SS})} constant in
#'     \eqn{w} -- so \emph{all} determinant-type settings (\eqn{D_M} and every
#'     \eqn{D_s}) select identical allocations and share the same search kernel.
#'     For the single treatment contrast, \eqn{D_s}-, c-, and per-parameter
#'     A-optimality coincide as well, which is why
#'     \code{objective = "A", interest = "treatment"} is silently equivalent to
#'     the default (allowed by design; no message is emitted).}
#'   \item{\eqn{D_A} -- general contrast optimality (minimize
#'     \eqn{\det(A^\top M(w)^{-1} A)} for an arbitrary contrast matrix
#'     \eqn{A})}{\code{interest = <contrast matrix>} -- arrives with Stage 2 of
#'     the merge plan (the generalized-criterion kernel) and currently raises an
#'     informative error, as do interest sets excluding the treatment
#'     coefficient.}
#'   \item{\eqn{D_B} (and \eqn{A_B}) -- Bayesian optimality (criteria computed on
#'     the posterior information \eqn{M(w) + R})}{\code{prior_precision = } a
#'     scalar \eqn{\tau} or a matrix \eqn{R_0}, combined with either
#'     \code{objective}; see the Bayesian section below for exactly which
#'     coefficients a scalar \eqn{\tau} penalizes.}
#'   \item{A -- trace optimality (minimize \eqn{\mathrm{tr}(K^\top M(w)^{-1} K)})}{
#'     \code{objective = "A"} with \code{interest = "all"} (all parameters:
#'     objective \eqn{(w^\top H w + 1)/s(w)},
#'     \eqn{H = Z_0 (Z_0^\top Z_0)^{-2} Z_0^\top}), or with
#'     \code{interest = } formula/names (\eqn{A_s}: same kernel with the
#'     subset-restricted \eqn{H_S}; see below). Unlike the determinant family,
#'     trace criteria over different interest sets generally select
#'     \emph{different} allocations.}
#' }
#'
#' \strong{Bayesian variants.} Supplying \code{prior_precision} replaces
#' \eqn{(Z_0^\top Z_0)^{-1}} with the ridge-regularized \eqn{(Z_0^\top Z_0 + R_0)^{-1}}
#' in the construction of \eqn{P} (and \eqn{H}), yielding Bayesian
#' D\eqn{_B}/A\eqn{_B}-optimality. A scalar \eqn{\tau} penalizes the
#' \emph{covariate coefficients only} -- the treatment coefficient and the intercept
#' are unpenalized (\eqn{R_0 = \tau \cdot \mathrm{diag}(0, 1, \ldots, 1)} over
#' \eqn{Z_0}'s columns) -- and, when \code{standardize_covariates = TRUE} (the
#' default), the covariates are centered and scaled to unit variance first so
#' \eqn{\tau} is interpretable per standardized coefficient. A full matrix
#' \code{prior_precision} is used as \eqn{R_0} verbatim (dimensions
#' \eqn{(1+p) \times (1+p)} over \eqn{[\mathrm{intercept}, \mathrm{covariates}]} of
#' the design's model matrix; \code{standardize_covariates} is ignored).
#'
#' \strong{Search algorithm.} For each of the \code{r} requested allocations
#' independently: start from a uniformly random balanced-count allocation (a BCRD
#' draw with exactly \eqn{n_T} treated), then repeatedly apply the single best
#' improving treated/control pairwise exchange until no exchange improves the
#' criterion (a strict local optimum). The returned allocations therefore form a
#' restricted-randomization distribution over locally optimal allocations, which is
#' what makes randomization inference possible for this design. \strong{The search is
#' reproducible via the constructor's \code{seed} argument}: the C++ kernels seed a
#' local generator from R's own RNG stream, so a fixed \code{seed} yields identical
#' draws (this corrects the former classes' documentation, which predated the RNG
#' migration).
#'
#' \strong{Covariate-subset criteria (D_s/A_s) via \code{interest = } a formula or
#' names.} \code{interest} also accepts a one-sided formula (e.g.
#' \code{~ x1 + x2}) or a character vector of model-matrix column names, meaning
#' \emph{the treatment coefficient plus the named covariate coefficients} (the
#' treatment is always in the interest set; the intercept never is). Both reduce to
#' the existing kernels with no new machinery: under \code{objective = "D"},
#' because \eqn{w} only enters the treatment row/column of \eqn{M(w)}, the
#' subset determinant factorizes as
#' \eqn{\det(K^\top M(w)^{-1} K) = \det(V_{SS}) / s(w)} with
#' \eqn{\det(V_{SS})} constant in \eqn{w} -- so subset-D selects allocations
#' \emph{identical} to the default treatment-focused criterion (allowed silently,
#' like \code{objective = "A", interest = "treatment"}); under
#' \code{objective = "A"}, the subset trace criterion is
#' \eqn{(w^\top H_S w + 1) / s(w)} with
#' \eqn{H_S = (Z_0 V S)(Z_0 V S)^\top} built from the selected columns -- the
#' same trace kernel with a subset-restricted \eqn{H}. Formula terms are
#' expanded against the design's model matrix, so factor covariates must be
#' referred to by their expanded model-matrix column names. Note that restricting
#' the design's model matrix itself via \code{design_formula} also changes the
#' default covariate set downstream inference adjusts for
#' (\code{Inference$initialize()} inherits the design's formula), whereas
#' \code{interest} affects the allocation criterion only. General \emph{contrast
#' matrices} (D_A), and interest sets excluding the treatment coefficient, arrive
#' with Stage 2 of the merge plan (the generalized-criterion kernel; see
#' \code{package_metadata/new_feature_plans/fix_design_hierarchy.md}).
#'
#' \strong{Constraints and fallbacks.} \code{prob_T} may be any value in \eqn{(0, 1)}
#' for which \eqn{1 \le \mathrm{round}(n \cdot \mathrm{prob}_T) \le n - 1}. If no
#' covariates are available, the search degenerates to pure random allocation with
#' \eqn{n_T} treated (there is no criterion to optimize).
#'
#' @references Atkinson, A. C., Donev, A. N., and Tobias, R. D. (2007).
#'   \emph{Optimum Experimental Designs, with SAS}. Oxford University Press, for the
#'   D-/A-optimality criteria and exchange algorithms for constrained design search.
#'   See also \href{https://en.wikipedia.org/wiki/Optimal_design}{optimal design}
#'   for orientation.
#' @examples
#' des = DesignFixedGreedyDOptimal$new(n = 10, response_type = 'continuous')
#' des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10)))
#' des$assign_w_to_all_subjects()
#' @export
DesignFixedGreedyDOptimal = define_design_class(
	classname = "DesignFixedGreedyDOptimal",
	inherit = DesignFixed,
	components = character(),
	public = list(
		#' @description Initialize a model-based optimal-search fixed experimental
		#'   design. Covariates, if any, are supplied later via
		#'   \code{add_all_subjects_to_experiment()}; the optimality search itself does
		#'   not run until \code{assign_w_to_all_subjects()} (or
		#'   \code{draw_ws_according_to_design()}) is called.
		#'
		#' @param response_type "continuous", "incidence", "proportion", "count",
		#'   "survival", or "ordinal". Determines only which downstream
		#'   inference/response machinery this design is paired with; it does not
		#'   affect the optimality search itself.
		#' @param prob_T Probability of treatment assignment, in \eqn{(0, 1)}. The
		#'   search fixes the treated count at \eqn{\mathrm{round}(n \cdot prob_T)}.
		#' @param objective The optimality criterion: \code{"D"} (default,
		#'   determinant) or \code{"A"} (trace). See the class documentation for the
		#'   exact criteria and for why \code{objective = "A"} with
		#'   \code{interest = "treatment"} is equivalent to the default.
		#' @param interest Which parameters the criterion targets:
		#'   \code{"treatment"} (default), \code{"all"}, a one-sided formula
		#'   (e.g. \code{~ x1 + x2}), a single formula \emph{string} (e.g.
		#'   \code{"x1 * x2 + x7"}, promoted to \code{~ x1 * x2 + x7}), or a
		#'   character vector of model-matrix column names -- all but
		#'   \code{"all"} meaning the treatment coefficient plus the named
		#'   covariate coefficients (D_s/A_s; see class documentation, including
		#'   why subset-D selects the same allocations as the default). Formula
		#'   terms (including interactions like \code{x1:x2}) must correspond to
		#'   columns of the design's model matrix: to target an interaction
		#'   coefficient, the interaction must be in \code{design_formula} too --
		#'   you cannot be "interested in" a coefficient the working model does
		#'   not contain.
		#'   Contrast matrices (general D_A) arrive with Stage 2 of the merge plan
		#'   and currently raise an error.
		#' @param prior_precision \code{NULL} (default, non-Bayesian), a single
		#'   positive scalar \eqn{\tau} (ridge prior precision on the covariate
		#'   coefficients only; treatment and intercept unpenalized), or a full
		#'   \eqn{(1+p) \times (1+p)} symmetric prior-precision matrix \eqn{R_0} over
		#'   \eqn{[\mathrm{intercept}, \mathrm{covariates}]}.
		#' @param standardize_covariates If \code{TRUE} (default) and
		#'   \code{prior_precision} is a scalar, covariates are centered and scaled
		#'   to unit variance before the penalized criterion matrices are built.
		#'   Ignored otherwise.
		#' @param n_iter Number of exchange iterations. \code{Inf} (default) runs the
		#'   exhaustive best-improvement search to a strict local optimum. Finite
		#'   values (the stochastic swap mode shared with
		#'   \code{\link[EDI:DesignFixedGreedy]{DesignFixedGreedy}}) arrive with the
		#'   Stage-2 shared search engine and currently raise an error.
		#' @param include_is_missing_as_a_new_feature Flag for missingness indicators.
		#' @param n Sample size (if fixed).
		#' @param verbose Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility. Unlike the former
		#'   \code{DesignFixedDOptimal}/\code{DesignFixedAOptimal} documentation
		#'   claimed, the optimality search \emph{is} reproducible via \code{seed}
		#'   (see class documentation).
		#'
		#' @return A new `DesignFixedGreedyDOptimal` object
		#'
		initialize = function(
				response_type,
				prob_T = 0.5,
				objective = "D",
				interest = "treatment",
				prior_precision = NULL,
				standardize_covariates = TRUE,
				n_iter = Inf,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			# Always-on validation (deliberately NOT gated behind should_run_asserts():
			# see fix_design_hierarchy.md's DesignFixedGreedy prob_T-bypass follow-up).
			if (!is.numeric(prob_T) || length(prob_T) != 1L || !is.finite(prob_T) || prob_T <= 0 || prob_T >= 1) {
				stop("prob_T must be a single number strictly between 0 and 1.")
			}
			validated = validate_optimal_design_objective_args(
				objective, interest, prior_precision, standardize_covariates,
				allowed_objectives = c("D", "A"),
				objective_error_message = 'objective must be "D" (determinant) or "A" (trace).'
			)
			interest = validated$interest
			interest_kind = validated$interest_kind
			if (!(is.numeric(n_iter) && length(n_iter) == 1L)) {
				stop("n_iter must be Inf or a positive integer.")
			}
			if (!is.infinite(n_iter)) {
				stop(paste0(
					"Finite n_iter (the stochastic swap mode) arrives with the Stage-2 shared ",
					"search engine of the DesignFixedGreedyDOptimal plan; use n_iter = Inf."
				))
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$objective = objective
			private$interest = interest
			private$interest_kind = interest_kind
			private$prior_precision = prior_precision
			private$standardize_covariates = standardize_covariates
			private$n_iter = n_iter
			# Single-parameter A- and D-optimality coincide, and subset-D reduces to
			# the treatment-focused criterion (see class docs), so only the trace
			# criteria over more than the treatment need the A kernel.
			private$use_A_kernel = (objective == "A" && interest_kind %in% c("all", "subset"))
			private$uses_covariates = TRUE
		},
		#' @description The optimality criterion this design was constructed with.
		#' @return \code{"D"} or \code{"A"}.
		get_objective = function() private$objective,
		#' @description The parameter-interest setting this design was constructed with.
		#' @return \code{"treatment"} or \code{"all"}.
		get_interest = function() private$interest,
		#' @description The Bayesian prior precision this design was constructed with.
		#' @return \code{NULL}, a positive scalar, or a symmetric matrix.
		get_prior_precision = function() private$prior_precision
	),
	private = list(
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				assertCount(r, positive = TRUE)
				self$assert_all_subjects_arrived()
			}
			n = self$get_n()
			n_T = as.integer(round(n * private$prob_T))
			if (n_T < 1L || n_T > n - 1L) {
				stop(sprintf("prob_T = %g with n = %d yields a treated count of %d; need at least one treated and one control subject.", private$prob_T, n, n_T))
			}
			if (is.null(private$X) || ncol(private$X) == 0){
				# No covariates: nothing to optimize -- pure random allocation with
				# exactly n_T treated (consistent with the kernel path's treated count).
				return(replicate(r, sample(c(rep(1, n_T), rep(0, n - n_T)))))
			}
			if (is.null(private$P)){
				# Shared with DesignFixedOptimal (helper_optimal_shared.R); the
				# construction is golden-locked to remain bit-identical to the
				# pre-extraction (and pre-merge) classes.
				PH = build_optimal_design_P_H(
					X = private$X[1:n, , drop = FALSE],
					interest = if (private$use_A_kernel && identical(private$interest_kind, "subset")) private$interest else "all",
					prior_precision = private$prior_precision,
					standardize_covariates = private$standardize_covariates,
					need_H = private$use_A_kernel
				)
				private$P = PH$P
				private$H = PH$H
			}
			res = if (private$use_A_kernel) {
				a_optimal_search_cpp(private$P, private$H, as.integer(r), n_T)
			} else {
				d_optimal_search_cpp(private$P, as.integer(r), n_T)
			}
			w_mat = res
			storage.mode(w_mat) = "numeric"
			w_mat
		}
	)
)
