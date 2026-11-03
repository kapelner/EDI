#' A Fixed, Covariate-Balanced Design via Greedy Pairwise-Swap Search
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that searches, among
#' allocations with exactly \eqn{n_T = \mathrm{round}(n \cdot \mathrm{prob}_T)} treated
#' subjects, for one that directly minimizes a covariate
#' imbalance criterion \eqn{f(d)}, \eqn{d = M(2w - 1)}, via a native C++ (RcppEigen +
#' OpenMP) greedy pairwise-swap search (\code{greedy_design_search_cpp()}). Unlike
#' \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}}, which optimizes a
#' model-based information-matrix criterion (D-/A-optimality) implied by an assumed
#' linear model, this design optimizes a direct covariate-distance criterion between the
#' treated and control group means/covariance, with no linear-model assumption: the two
#' supported \code{objective}s are
#' \itemize{
#'   \item \code{"mahal_dist"} (default): \eqn{d = L^{-1} X^\top (2w-1) / n} where
#'     \eqn{\Sigma = LL^\top} is the Cholesky factor of the covariate covariance matrix,
#'     and \eqn{f(d) = \lVert d \rVert_2^2} — the squared Mahalanobis distance between
#'     the treated and control covariate means, accounting for covariate
#'     correlation/scale. Falls back to \code{"abs_sum_diff"} if the covariate
#'     covariance matrix is (numerically) singular, since the Cholesky factorization
#'     then fails.
#'   \item \code{"abs_sum_diff"}: \eqn{d = X_{\mathrm{std}}^\top (2w-1) / n} (covariates
#'     standardized to unit variance, no correlation adjustment) and
#'     \eqn{f(d) = \lVert d \rVert_1} — the sum of absolute standardized mean
#'     differences across covariates.
#' }
#'
#' @details
#' \strong{Search algorithm.} Starting from a random (Fisher-Yates) allocation with \eqn{n_T} treated,
#' the search runs in one of two modes selected by \code{n_iter}: \code{Inf} (default)
#' runs \strong{exhaustive best-improvement} search — each round scans every
#' (treated, control) pair, applies the single globally best improving swap, and repeats
#' until no swap improves \eqn{f(d)}, guaranteeing convergence to a strict local optimum;
#' a positive integer instead runs exactly that many \strong{stochastic} steps, each
#' picking a uniformly random (treated, control) pair and accepting the swap only if it
#' improves \eqn{f(d)}, with no early stopping. \code{r} independent design
#' searches (one per requested replicate) run in parallel via OpenMP, each with its own
#' random-number stream. \strong{This search's
#' randomization is reproducible via the constructor's \code{seed} argument}: one master
#' seed is drawn from R's own RNG state (\code{GetRNGstate()}/\code{unif_rand()})
#' before the parallel region begins, and each replicate's stream is derived from that
#' seed and the replicate's index, so \code{private$maybe_set_seed()} does govern the
#' resulting allocation, independent of the number of OpenMP threads used.
#'
#' \strong{Same draws as \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}}
#' at the defaults.} With \code{objective = "mahal_dist"} and \code{n_iter = Inf} (the
#' defaults), this class returns exactly the same allocations as
#' \code{DesignFixedGreedyDOptimal} with its defaults (\code{objective = "D"}, no
#' \code{prior_precision}) for the same seed. Despite the "no linear-model assumption"
#' framing above, the default criterion coincides with D-optimality: with the number of
#' treated subjects fixed, the information about the treatment effect in the linear model
#' \eqn{y = \beta_T w + \beta_0 + X \gamma + \epsilon} equals a constant minus a positive
#' multiple of the squared Mahalanobis distance between the treated and control
#' covariate means. Both criteria therefore rank every allocation the same way, and the
#' same swap search from the same starting allocation reaches the same allocation (the
#' derivation is in \code{DesignFixedGreedyDOptimal}'s documentation). The draws differ
#' when this class uses \code{objective = "abs_sum_diff"}, a finite \code{n_iter}, or the
#' \code{"abs_sum_diff"} fallback after a failed Cholesky factorization, and when
#' \code{DesignFixedGreedyDOptimal} uses \code{objective = "A"} with \code{interest = "all"} or a covariate
#' subset, or a \code{prior_precision}.
#'
#' \strong{Unequal arms.} Any \code{prob_T} in \eqn{(0, 1)} is supported; the search
#' keeps the treated count fixed at \eqn{n_T = \mathrm{round}(n \cdot \mathrm{prob}_T)},
#' and drawing errors if that leaves no treated or no control subject. The kernel centres
#' \eqn{X}, so \eqn{M(2w - 1) = 2Mw}, a fixed positive multiple of the half
#' treated-minus-control mean difference at every \eqn{n_T}: both objectives keep their
#' balance meaning without any change to the swap update.
#'
#' \strong{Constraints and fallbacks.} If
#' no covariates are available, the search degenerates to pure Fisher-Yates
#' randomization with \eqn{n_T} treated (no swap search, since there is nothing to
#' balance on).
#' \code{greedy_design_search_cpp()}'s output is trusted unvalidated -- it guarantees
#' exactly \code{n x r} valid \eqn{\{0,1\}} columns with \eqn{n_T} treated subjects per
#' column by construction (see fix_design_hierarchy.md, "AllocationMatrixValidation").
#'
#' @references Krieger, A. M., Azriel, D., and Kapelner, A. (2019). "Nearly random
#'   designs with greatly improved balance." \emph{Biometrika}, 106(3), 695-701,
#'   \doi{10.1093/biomet/asz026}, for the greedy-swap balance-optimization approach this
#'   class implements. See also
#'   \href{https://en.wikipedia.org/wiki/Mahalanobis_distance}{Mahalanobis distance} for
#'   orientation on the default objective.
#' @examples
#' des = DesignFixedGreedy$new(n = 10, response_type = 'continuous')
#' @export
DesignFixedGreedy = define_design_class(
	classname = "DesignFixedGreedy",
	inherit = DesignFixed,
	components = "BatchWPregeneration",
	overrides = list(public = "supports_batch_w_pregeneration"),
	public = list(
		#' @description Initialize a greedy pairwise-swap search fixed experimental
		#'   design. Any \code{prob_T} in \eqn{(0, 1)} is supported (see class documentation).
		#'
		#' @param response_type 	The data type of response values.
		#' @param prob_T  The probability of the treatment assignment; the search fixes the
		#'   treated count at \code{round(n * prob_T)}.
		#' @param objective 	The covariate-imbalance objective to minimize: either
		#'   \code{"mahal_dist"} (default, squared Mahalanobis distance between treated
		#'   and control covariate means) or \code{"abs_sum_diff"} (sum of absolute
		#'   standardized mean differences); see class documentation for the exact
		#'   criteria.
		#' @param n_iter Number of swap iterations. \code{Inf} (default) uses exhaustive
		#'   best-improvement search guaranteed to reach a strict local optimum. A positive
		#'   integer runs exactly that many stochastic random-pair iterations (no early
		#'   stopping), each accepting the swap only if it improves the objective.
		#' @param include_is_missing_as_a_new_feature  Flag for missingness indicators.
		#' @param n  		The sample size.
		#' @param verbose  Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility. This design's
		#'   search \emph{is} reproducible via \code{seed} (see class documentation).
		#'
		#' @return 			A new `DesignFixedGreedy` object
		#'
		initialize = function(
				response_type,
				prob_T = 0.5,
				objective = "mahal_dist",
				n_iter = Inf,
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			# Always-on validation (fix_design_hierarchy.md, TODO-33; same check as
			# DesignFixedGreedyDOptimal). The treated count round(n * prob_T) is
			# checked against n in draw_ws_raw(), once n is known.
			if (!is.numeric(prob_T) || length(prob_T) != 1L || !is.finite(prob_T) || prob_T <= 0 || prob_T >= 1) {
				stop("prob_T must be a single number strictly between 0 and 1.")
			}
			# GED availability is checked lazily in draw_ws_according_to_design so
			# that workers using pre-computed w vectors never trigger a JVM load.
			if (should_run_asserts()) {
				if (!is.infinite(n_iter) && (!is.numeric(n_iter) || length(n_iter) != 1L || n_iter <= 0 || n_iter != floor(n_iter)))
					stop("n_iter must be Inf or a positive integer")
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$objective = objective
			private$n_iter    = n_iter
			private$uses_covariates = TRUE
		},
		#' @description Returns \code{TRUE} so the calling framework pre-generates all
		#'   replicate \code{w} vectors for a simulation cell in a single batched call
		#'   to \code{greedy_design_search_cpp()} (which parallelizes the \code{r}
		#'   independent searches over OpenMP threads internally), rather than issuing
		#'   \code{r} separate single-replicate C++ calls.
		#'
		#' @return Always \code{TRUE} for this class.
		supports_batch_w_pregeneration = function() TRUE
	),
	private = list(
		objective = NULL,
		n_iter    = NULL,
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				assertCount(r, positive = TRUE)
			}
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
			}
			n = self$get_n()
			private$ensure_model_matrix_current()
			# Always-on validation (fix_design_hierarchy.md, TODO-33): the kernel
			# draws exactly n_T treated, the same count DesignFixedGreedyDOptimal uses.
			n_T = as.integer(round(n * private$prob_T))
			if (n_T < 1L || n_T > n - 1L) {
				stop(sprintf("prob_T = %g with n = %d yields a treated count of %d; need at least one treated and one control subject.", private$prob_T, n, n_T))
			}
			if (is.null(private$X) || ncol(private$X) == 0){
				return(replicate(r, sample(c(rep(1, n_T), rep(0, n - n_T)))))
			}
			X          = private$X[1:n, , drop = FALSE]
			cpp_n_iter = if (is.infinite(private$n_iter)) -1L else as.integer(private$n_iter)
			# Trusted unvalidated (fix_design_hierarchy.md, "AllocationMatrixValidation"):
			# greedy_design_search_cpp always returns exactly n x r valid {0,1} columns
			# by construction, so the post-search shape/finite/balance checks this class
			# used to run were dead code that never fired.
			greedy_design_search_cpp(
				X_raw     = X,
				r         = as.integer(r),
				objective = private$objective,
				n_iter    = cpp_n_iter,
				n_T       = n_T
			)
		}
	)
)
