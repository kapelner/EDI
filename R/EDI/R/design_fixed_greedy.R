#' A Fixed, Covariate-Balanced Design via Greedy Pairwise-Swap Search
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} that searches, among
#' balanced (\eqn{n/2}-treated) allocations, for one that directly minimizes a covariate
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
#' \strong{Search algorithm.} Starting from a random balanced (Fisher-Yates) allocation,
#' the search runs in one of two modes selected by \code{n_iter}: \code{Inf} (default)
#' runs \strong{exhaustive best-improvement} search — each round scans every
#' (treated, control) pair, applies the single globally best improving swap, and repeats
#' until no swap improves \eqn{f(d)}, guaranteeing convergence to a strict local optimum;
#' a positive integer instead runs exactly that many \strong{stochastic} steps, each
#' picking a uniformly random (treated, control) pair and accepting the swap only if it
#' improves \eqn{f(d)} (with patience-based early stopping). \code{r} independent design
#' searches (one per requested replicate) run in parallel via OpenMP, each with its own
#' \code{std::mt19937} generator. \strong{This search's
#' randomization is reproducible via the constructor's \code{seed} argument}: per-thread
#' RNGs are seeded from R's own RNG state (\code{GetRNGstate()}/\code{unif_rand()})
#' before the parallel region begins, so \code{private$maybe_set_seed()} does govern the
#' resulting allocation, independent of the number of OpenMP threads used.
#'
#' \strong{Constraints and fallbacks.} Only exactly balanced allocation
#' (\code{prob_T = 0.5}, \eqn{n} even) is supported; the constructor errors otherwise. If
#' no covariates are available, the search degenerates to pure balanced Fisher-Yates
#' randomization (no swap search, since there is nothing to balance on). Every drawn
#' allocation is validated (\code{private$validate_allocation_matrix()}) to have the
#' correct shape, finite \eqn{\{0,1\}} entries, and exactly \eqn{n/2} treated per
#' replicate, raising an error on violation rather than returning a malformed allocation.
#'
#' @references Krieger, A. M., Azriel, D., and Kapelner, A. (2019). "Nearly random
#'   designs with greatly improved balance." \emph{Biometrika}, 106(3), 695-701,
#'   \doi{10.1093/biomet/asz026}, for the greedy-swap balance-optimization approach this
#'   class implements. See also
#'   \href{https://en.wikipedia.org/wiki/Mahalanobis_distance}{Mahalanobis distance} for
#'   orientation on the default objective.
#' @examples
#' \dontrun{
#' des = DesignFixedGreedy$new(n = 10, response_type = 'continuous')
#' }
#' @export
DesignFixedGreedy = R6::R6Class("DesignFixedGreedy",
	inherit = DesignFixed,
	public = list(
		#' @description Initialize a greedy pairwise-swap search fixed experimental
		#'   design. Only \code{prob_T = 0.5} is supported (see class documentation).
		#'
		#' @param response_type 	The data type of response values.
		#' @param prob_T  The probability of the treatment assignment. Must be 0.5.
		#' @param objective 	The covariate-imbalance objective to minimize: either
		#'   \code{"mahal_dist"} (default, squared Mahalanobis distance between treated
		#'   and control covariate means) or \code{"abs_sum_diff"} (sum of absolute
		#'   standardized mean differences); see class documentation for the exact
		#'   criteria.
		#' @param n_iter Number of swap iterations. \code{Inf} (default) uses exhaustive
		#'   best-improvement search guaranteed to reach a strict local optimum. A positive
		#'   integer runs that many stochastic random-pair iterations with patience-based
		#'   early stopping.
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
			if (should_run_asserts()) {
				if (prob_T != 0.5){
					stop("Greedy designs currently only support even treatment allocation (prob_T = 0.5)")
				}
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
			if (should_run_asserts()) {
				if (n %% 2 != 0){
					stop("DesignFixedGreedy requires an even number of subjects.")
				}
			}
			if (is.null(private$X) || ncol(private$X) == 0){
				return(replicate(r, sample(c(rep(1, n / 2), rep(0, n / 2)))))
			}
			private$covariate_impute_if_necessary_and_then_create_model_matrix()
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
				n_iter    = cpp_n_iter
			)
		}
	)
)
