# Package installation cache
package_cache = new.env(parent = emptyenv())

#' Check Whether a Suggested Package Is Installed (Memoized)
#'
#' Tests whether \code{package_name} is installed via
#' \code{\link[base]{requireNamespace}} and memoizes the result in a
#' package-level environment (\code{package_cache}), so that repeated checks
#' for the same package within an R session pay the namespace-lookup cost
#' only once. EDI uses this to guard optional code paths that depend on
#' Suggests-only packages (e.g. \pkg{quantreg}, \pkg{betareg},
#' \pkg{nbpMatching}, \pkg{geepack}, \pkg{icenReg}) that are not installed
#' automatically with the package, issuing an informative
#' \code{stop()}/\code{warning()} and falling back to an internal
#' implementation when the dependency is absent, rather than failing with an
#' opaque "could not find function" error.
#'
#' @details
#' \strong{Caching / mutation semantics.} This function has a side effect:
#' on the first call for a given \code{package_name} in the current R
#' session, it assigns the boolean result of \code{requireNamespace()} into
#' the package-global environment \code{package_cache}, keyed by
#' \code{package_name}. All subsequent calls for the same
#' \code{package_name} (from anywhere in the package, or from user code)
#' read the cached value directly and do not re-query the namespace
#' registry. This means the result reflects whether the package was
#' installed \emph{at the time of the first call}; installing or removing
#' \code{package_name} later in the same R session will not be picked up.
#' The cache is a plain environment (not an R6 object) shared by all
#' callers within the process and is not reset between calls; it is,
#' however, re-initialized fresh in each new R session.
#'
#' \strong{Determinism.} For a fixed installed-package state,
#' \code{check_package_installed()} is deterministic and side-effect-free
#' beyond the memoization described above; it does not consume random
#' number generator state and involves no numerical computation.
#'
#' \strong{Lifecycle.} Internal utility (exported for reuse within the
#' package's own R6 classes across files, not intended as a general-purpose
#' user-facing API); prefer \code{requireNamespace()} directly for
#' one-off checks in user code.
#'
#' @param package_name Character scalar. The name of the package to check
#'   (as passed to \code{requireNamespace()}).
#' @return Logical scalar. \code{TRUE} if the package is installed and its
#'   namespace can be loaded, \code{FALSE} otherwise.
#' @seealso \code{\link[base]{requireNamespace}}, on which this function is
#'   a thin memoizing wrapper.
#' @keywords internal
#' @export
check_package_installed = function(package_name) {
	if (!exists(package_name, envir = package_cache, inherits = FALSE)) {
		res = requireNamespace(package_name, quietly = TRUE)
		assign(package_name, res, envir = package_cache)
	}
	get(package_name, envir = package_cache)
}

# Helper for parallel progress bars
print_progress = function(pb, i, total) {
	if (!is.null(pb)) {
		utils::setTxtProgressBar(pb, i)
	}
}

assert_nbpmatching_installed = function(caller) {
	if (!requireNamespace("nbpMatching", quietly = TRUE)) {
		stop("Package 'nbpMatching' is required for ", caller, ".")
	}
}

# Compute non-bipartite pair-matching structure from a covariate matrix.
# Returns a list with $indicies_pairs (n/2 x 2 integer matrix, 1-based row indices).
# Uses squared Euclidean distance by default; Mahalanobis if mahal_match = TRUE.
# For p == 1 the subjects are simply ordered and paired consecutively.
compute_binary_match_structure = function(X, mahal_match = FALSE) {
	assert_nbpmatching_installed("compute_binary_match_structure")
	n = nrow(X)
	p = ncol(X)
	if (n %% 2L != 0L) {
		stop("Design matrix must have an even number of rows for binary matching.")
	}
	if (p == 1L) {
		indicies_pairs = matrix(order(X[, 1L]), ncol = 2L, byrow = TRUE)
	} else {
		if (mahal_match) {
			S = stats::var(X)
			S_inv = tryCatch(solve(S), error = function(e) NULL)
			if (is.null(S_inv)) {
				ridge = 1e-8
				for (i in seq_len(6L)) {
					S_inv = tryCatch(solve(S + diag(ridge, ncol(S))), error = function(e) NULL)
					if (!is.null(S_inv)) break
					ridge = ridge * 10
				}
			}
			if (is.null(S_inv)) stop("Covariance matrix is singular; cannot compute Mahalanobis distances.")
			# d_Mahal(xi,xj)^2 = ||U(xi-xj)||^2 where U = chol(S_inv) (U'U = S_inv).
			# Transform X -> X %*% t(U) so squared Euclidean == squared Mahalanobis.
			U = chol(S_inv)
			D = as.matrix(stats::dist(X %*% t(U)))^2
		} else {
			D = as.matrix(stats::dist(X))^2
		}
		diag(D) = .Machine$double.xmax
		indicies_pairs = as.matrix(
			nbpMatching::nonbimatch(nbpMatching::distancematrix(D))$matches[, c("Group1.Row", "Group2.Row")]
		)
		for (i in seq_len(n)) {
			indicies_pairs[i, ] = sort(indicies_pairs[i, ])
		}
		indicies_pairs = unique(indicies_pairs)
	}
	list(indicies_pairs = indicies_pairs, indices_pairs = indicies_pairs, n = n, p = p)
}

# Classifies which custom-DGP hooks (if any) are active for a run/cell.
# Shared by the SimulationFramework worker (tags each result row) and the
# report's reference-combo grid (must agree on the same value to join on it).
compute_simulation_mode = function(custom_dgp, custom_replication_data_generator, custom_apply_treatment_and_noise, make_estimand_fn) {
	if (!is.null(custom_dgp)) {
		return("custom_dgp")
	}
	parts = c(
		if (!is.null(custom_replication_data_generator)) "crdg",
		if (!is.null(custom_apply_treatment_and_noise))  "catn",
		if (!is.null(make_estimand_fn))                  "cte"
	)
	if (length(parts) == 0L) "standard" else paste(parts, collapse = "+")
}

assert_optimal_blocks_libraries_installed = function(caller) {
	required_pkgs = c("ompr", "ompr.roi", "ROI.plugin.glpk", "randomizr")
	missing_pkgs = required_pkgs[!vapply(required_pkgs, check_package_installed, logical(1))]
	if (length(missing_pkgs) > 0L) {
		stop("Packages ", paste(missing_pkgs, collapse = ", "), " are required for ", caller, ".")
	}
}

assert_blocktools_installed = function(caller) {
	if (!check_package_installed("blockTools"))
		stop("Package 'blockTools' is required for ", caller, ".")
}

assert_anticlust_installed = function(caller) {
	if (!check_package_installed("anticlust"))
		stop("Package 'anticlust' is required for ", caller, ".")
}

assert_icenreg_installed = function(caller) {
	if (!check_package_installed("icenReg"))
		stop("Package 'icenReg' is required for ", caller, ". Please install it with install.packages(\"icenReg\").")
}

# 'interval' depends on Bioconductor's 'Icens', which install.packages()
# cannot resolve on its own -- it must be installed via BiocManager first,
# or install.packages("interval") fails with "dependency 'Icens' is not
# available for package 'interval'".
assert_interval_installed = function(caller) {
	if (!check_package_installed("interval")) {
		stop(
			"Package 'interval' is required for ", caller, ". It depends on ",
			"Bioconductor's 'Icens' package, which install.packages() cannot ",
			"resolve directly. Please install it with:\n",
			"  if (!requireNamespace(\"BiocManager\", quietly = TRUE)) install.packages(\"BiocManager\")\n",
			"  BiocManager::install(\"Icens\")\n",
			"  install.packages(\"interval\")"
		)
	}
}

#' Logit (Log-Odds) Transform
#'
#' Computes the logit (log-odds) function \eqn{\mathrm{logit}(p) = \log\left(p /
#' (1-p)\right)}, the canonical link function for binomial/logistic-family
#' models throughout this package. \code{p} is first clamped to
#' \eqn{[\code{zero\_one\_logit\_clamp}, 1 - \code{zero\_one\_logit\_clamp}]}
#' before transforming, so exact \code{0} or \code{1} inputs (which would
#' otherwise map to \eqn{-\infty}/\eqn{\infty}) instead return a large but
#' finite value; this is what lets proportion/fractional responses with mass
#' exactly at the boundary be used as pseudo-continuous inputs to logit-scale
#' machinery elsewhere in the package (e.g. \code{\link{fast_ols_cpp}}-backed
#' logit-transform-then-OLS shortcuts) without producing non-finite values.
#'
#' @param p The value(s) to transform, nominally in \verb{(0, 1)} (values
#'   outside that range, or exactly 0/1, are clamped rather than rejected).
#' @param zero_one_logit_clamp The clamping distance from the 0/1 boundaries
#'   applied to \code{p} before transforming. Default \code{.Machine$double.eps}.
#' @return The logit-transformed value(s) as a real number (or vector), the same
#'   length as \code{p}.
#' @seealso \code{\link{inv_logit}} for the inverse transform.
#' @examples
#' logit(0.25)
#' @export
logit = function(p, zero_one_logit_clamp = .Machine$double.eps){
	p = pmax(zero_one_logit_clamp, pmin(1 - zero_one_logit_clamp, p))
	log(p / (1 - p))
}

#' Inverse Logit (Logistic) Function
#'
#' Computes the inverse logit (standard logistic sigmoid) function,
#' \eqn{\mathrm{logit}^{-1}(x) = 1/(1 + e^{-x})}, the canonical mean function
#' for binomial/logistic-family models throughout this package (mapping a
#' linear predictor on the log-odds scale back to a probability). The result is
#' clamped to \eqn{[\code{zero\_one\_logit\_clamp}, 1 -
#' \code{zero\_one\_logit\_clamp}]} before being returned, so an extreme
#' \code{x} (e.g. from a poorly identified or diverging fit) cannot produce an
#' exact \code{0} or \code{1} probability that would later cause a \code{-Inf}/
#' \code{NaN} when log-transformed downstream (e.g. in a log-likelihood).
#'
#' @param x Any real number (or vector), typically a fitted linear predictor
#'   \eqn{\eta = x_i^\top\beta} on the log-odds scale.
#' @param zero_one_logit_clamp The clamping distance from the 0/1 boundaries
#'   applied to the result. Default \code{.Machine$double.eps}.
#' @return The inverse-logit-transformed value(s), in \verb{(0, 1)}, the same
#'   length as \code{x}.
#' @seealso \code{\link{logit}} for the forward transform.
#' @examples
#' inv_logit(0)
#' @export
inv_logit = function(x, zero_one_logit_clamp = .Machine$double.eps){
	p = 1 / (1 + exp(-x))
	pmax(zero_one_logit_clamp, pmin(1 - zero_one_logit_clamp, p))
}


#' Build an Intercept-Free, Full-Rank Covariate Design Matrix from a Formula
#'
#' Expands \code{formula} against \code{data} (via \code{\link[stats]{model.matrix}}) into
#' a purely numeric covariate design matrix suitable for the package's own \code{fast_*}
#' GLM/survival/ordinal fitting routines, which manage their own intercept and treatment
#' columns separately rather than relying on the formula/model-matrix machinery for them.
#' This is the standard covariate-matrix builder used throughout EDI's inference classes
#' (e.g. \code{Inference$private$X}) whenever adjustment covariates need to go from a
#' user-facing formula/data-frame representation to a numeric matrix the C++ backends can
#' consume.
#'
#' @details
#' \strong{What it does.} (1) If \code{data} has zero columns, returns a numeric
#' \code{nrow(data) x 0} matrix immediately (no covariates to expand). (2) Otherwise calls
#' \code{\link[stats]{model.matrix}(formula, data = data)}, which performs standard
#' formula expansion: factor variables are dummy-coded against their reference level (the
#' first level of \code{\link[base]{levels}}, or the level ordering already present in
#' \code{data}), interactions (\code{a:b}, \code{a*b}) are expanded to product columns, and
#' any \code{model.matrix} contrasts option in effect at call time applies. (3) If the
#' first resulting column is named \code{"(Intercept)"} (i.e. the formula was not given
#' \code{- 1} / \code{+ 0}), that column is dropped — this function always returns a
#' covariate-only matrix with no intercept column, since EDI's design and inference classes
#' add their own intercept/treatment columns at a fixed position. (4) The result is passed
#' through \code{\link{drop_linearly_dependent_cols}}, which detects the numeric rank of
#' the matrix (via \code{matrix_rank_cpp()} at tolerance \code{1e-7}) and, if the matrix is
#' rank-deficient, greedily retains a full-rank subset of columns using the pivot order
#' from \code{\link[base]{qr}(M, tol = 1e-7)} (dropping the same tolerance's worth of
#' redundant/aliased columns, e.g. from collinear dummy expansions or an over-specified
#' interaction structure); this rank-reduction step is silent — no warning is issued when
#' columns are dropped, and the dropped columns' identity/names are not returned to the
#' caller, only the reduced matrix.
#'
#' \strong{Input conventions.} \code{data} is expected to already be free of missing
#' values at call time (imputation, when configured, happens upstream in the design/
#' inference class before this function is called); this function does not impute or warn
#' about \code{NA}s, and \code{model.matrix} will drop incomplete rows or error, per its
#' own \code{na.action} default, if \code{NA}s remain. Column order and names in the
#' returned matrix follow \code{model.matrix}'s expansion order (all factor/interaction
#' columns for a term before the next term), possibly reduced by the rank-deficiency step;
#' callers relying on stable column identity (e.g. warm-starting coefficients across calls)
#' should not assume the set or order of columns is invariant if \code{data}'s factor
#' levels or rank change between calls.
#'
#' \strong{Failure semantics.} If \code{drop_linearly_dependent_cols} detects the matrix is
#' non-numeric or contains non-finite values, it returns the matrix unchanged (rank
#' reduction is skipped rather than erroring); a downstream fitting routine operating on a
#' rank-deficient or non-finite design matrix may then fail to converge or report
#' non-finite coefficients/standard errors, which is where such problems will actually
#' surface to the user.
#'
#' @param formula A formula object giving the covariate specification to expand (e.g.
#'   \code{~ age + sex + age:sex}); should not include the response.
#' @param data A data frame or data table supplying the variables referenced in
#'   \code{formula}, with one row per subject.
#' @return A numeric matrix with \code{nrow(data)} rows and one column per retained,
#'   full-rank expanded covariate term (no intercept column). Has zero columns if
#'   \code{data} has zero columns.
#' @seealso \code{\link[stats]{model.matrix}}, which performs the formula expansion this
#'   function wraps; \code{drop_linearly_dependent_cols} (internal, same file) for the
#'   rank-deficiency cleanup step. Analogous Python API:
#'   \href{https://patsy.readthedocs.io/en/latest/}{patsy}/
#'   \href{https://www.statsmodels.org/stable/gettingstarted.html}{statsmodels formula API}
#'   for formula-based design matrix construction.
#' @keywords internal
#' @export
create_model_matrix_from_features = function(formula, data){
	# For blank data frames...
	if (ncol(data) == 0){
		return(matrix(NA, nrow = nrow(data), ncol = 0))
	}
	
	# now we need to update the numeric model matrix which may have expanded due to new factors, new missingness cols, etc
	mm = model.matrix(formula, data = data)
	
	# Packaged designs/inferences typically handle their own intercept separately (at the front),
	# so we drop the one from model.matrix if it's there.
	if (ncol(mm) > 0 && colnames(mm)[1] == "(Intercept)") {
		mm = mm[, -1, drop = FALSE]
	}
	
	# Standard cleanup: drop linearly dependent columns
	drop_linearly_dependent_cols(mm)$M
}

drop_linearly_dependent_cols = function(M){
	M = as.matrix(M)
	js = seq_len(ncol(M))
	if (nrow(M) == 0L || ncol(M) == 0L) {
		return(list(M = M, js = js))
	}
	if (!is.numeric(M) || any(!is.finite(M))) {
		return(list(M = M, js = js))
	}
	if (ncol(M) > 0){
		# Use a standard tolerance for rank detection
		tol = 1e-7
		rank = matrix_rank_cpp(M, tol = tol)
		if (rank != ncol(M)){
			# Use the same tolerance for R's qr() to be consistent
			qrX = qr(M, tol = tol)
			# QR pivot contains indices of columns in order of their 'independence'
			# but we should trust our matrix_rank_cpp's rank estimate.
			actual_rank = min(rank, qrX$rank)
			js = qrX$pivot[seq_len(actual_rank)]
			M = M[, js, drop = FALSE]
		}
	}
	list(M = M, js = js)
}

drop_highly_correlated_cols = function(M, threshold = 0.99){
	M = as.matrix(M)
	js = seq_len(ncol(M))
	if (ncol(M) <= 1) return(list(M = M, js = js))
	# Drop zero-variance (constant) columns first so they don't produce NA
	# correlations that could accidentally flag the treatment column for removal
	const_cols = which(apply(M, 2, var) == 0)
	if (length(const_cols) > 0) {
		M = M[, -const_cols, drop = FALSE]
		js = js[-const_cols]
		if (ncol(M) <= 1) return(list(M = M, js = js))
	}
	repeat {
		R = suppressWarnings(stats::cor(M))
		pairs = which(abs(R) > threshold, arr.ind = TRUE)
		pairs = pairs[pairs[, 1] < pairs[, 2], , drop = FALSE]
		if (nrow(pairs) == 0) break
		j_kill = unique(pairs[, 2])
		M = M[, -j_kill, drop = FALSE]
		js = js[-j_kill]
		if (ncol(M) <= 1) break
	}
	list(M = M, js = js)
}

assertResponseType = function(response_type, needed_response_type){
	if (!(response_type %in% needed_response_type)){
		stop("This type of inference is only available for ", paste(needed_response_type, collapse = "/"), " responses.")
	}
}

assertNoCensoring = function(any_censoring){
	if (any_censoring){
		stop("This type of inference is only available for uncensored responses.")
	}
}

#' Robust Parametric Survival Regression from Response/Censoring Vectors
#'
#' Convenience wrapper around \code{\link{robust_survreg_with_surv_object}} that
#' builds the \code{\link[survival]{Surv}} object from separate response and
#' censoring vectors first. See that function for the full description of the
#' warm-start-then-random-restart fitting strategy used to make
#' \code{\link[survival]{survreg}} converge reliably even from poor or
#' near-singular starting points.
#'
#' @param  y  					The (possibly right-censored) response vector (event/censoring time).
#' @param  dead  				The event indicator (1 if the event was observed/uncensored, 0 if
#'   right-censored at \code{y}).
#' @param  cov_matrix_or_vector  The design matrix (or a single covariate vector) of predictors,
#'   \strong{excluding} the intercept (one is added by the internal \code{~ .} formula).
#' @param  dist  				The parametric AFT distribution family passed to
#'   \code{\link[survival]{survreg}} (default \code{"weibull"}); see that function's
#'   \code{dist} argument for the full list of supported families.
#' @param  num_max_iter  		Maximum number of random-restart attempts if the direct fit fails
#'   or does not converge (default 50); see \code{\link{robust_survreg_with_surv_object}}.
#' @return  The fitted \code{\link[survival]{survreg}} model object, or \code{NULL} if no
#'   attempt converged to a fit with no \code{NA} coefficients within \code{num_max_iter} tries.
#' @examples
#' X = matrix(rnorm(500), 100, 5)
#' y = runif(100)
#' dead = rbinom(100, 1, 0.5)
#' robust_survreg(y, dead, X)
#' @export
robust_survreg = function(y, dead, cov_matrix_or_vector, dist = "weibull", num_max_iter = 50){
	robust_survreg_with_surv_object(survival::Surv(y, dead), cov_matrix_or_vector, dist = dist, num_max_iter = num_max_iter)
}

#' Robust Parametric Survival Regression (AFT) with Warm-Start and Random-Restart Fallback
#'
#' Fits a parametric accelerated-failure-time (AFT) survival regression via
#' \code{\link[survival]{survreg}} on \code{surv_object ~ .} over the columns of
#' \code{cov_matrix_or_vector}, with two layers of robustness against
#' \code{survreg}'s well-known sensitivity to starting values and
#' near-collinear design matrices:
#' \enumerate{
#'   \item \strong{Preprocessing}: near-collinear columns of the design matrix
#'     are dropped first via \code{\link{drop_highly_correlated_cols}} then
#'     \code{\link{drop_linearly_dependent_cols}}, before any fitting is attempted.
#'   \item \strong{Warm start (Weibull only)}: when \code{dist = "weibull"}, a
#'     fast closed-form-gradient Weibull fit (\code{\link{fast_weibull_regression}})
#'     is attempted first; if it succeeds and returns a finite log-likelihood, its
#'     coefficients and \eqn{\log(\hat\sigma)} are passed to \code{survreg} as the
#'     \code{init} vector, which typically converges the true MLE in a single
#'     \code{survreg} call. If this warm-started fit is unavailable, fails, or
#'     produces \code{NA} coefficients, fitting falls through to the general
#'     random-restart loop below (for all other \code{dist} values, this warm
#'     start is skipped entirely).
#'   \item \strong{Random-restart loop}: starting from an all-zero \code{init}
#'     vector, \code{survreg} is called repeatedly (perturbing \code{init} by an
#'     independent standard-normal jitter, \code{init + rnorm(length(init))},
#'     after every failed attempt) until a fit with no \code{NA} coefficients is
#'     obtained or \code{num_max_iter} attempts are exhausted, at which point
#'     \code{NULL} is returned.
#' }
#' \code{survreg.control(maxiter = 100, rel.tolerance = 1e-9, outer.max = 10)} is
#' used throughout (tighter than \code{survreg}'s own defaults) to reduce the
#' chance of a spuriously "converged" fit at a poor optimum.
#'
#' @param surv_object                     The survival object (built from the response vector
#'   and censoring vector via \code{\link[survival]{Surv}}).
#' @param  cov_matrix_or_vector  The design matrix (or a single covariate vector) of predictors,
#'   \strong{excluding} the intercept (one is added by the internal \code{~ .} formula).
#' @param  dist  				The parametric AFT distribution family passed to
#'   \code{\link[survival]{survreg}} (default \code{"weibull"}); only \code{"weibull"} triggers
#'   the closed-form warm start.
#' @param  num_max_iter  		Maximum number of random-restart attempts if the (possibly
#'   warm-started) direct fit fails or does not converge (default 50).
#' @return  The fitted \code{\link[survival]{survreg}} model object, or \code{NULL} if no
#'   attempt converged to a fit with no \code{NA} coefficients within \code{num_max_iter} tries.
#' @examples
#' X = matrix(rnorm(500), 100, 5)
#' y = runif(100)
#' dead = rbinom(100, 1, 0.5)
#' surv = survival::Surv(y, dead)
#' robust_survreg_with_surv_object(surv, X)
#' @export
robust_survreg_with_surv_object = function(surv_object, cov_matrix_or_vector, dist = "weibull", num_max_iter = 50){
	surv_reg_formula = surv_object ~ .
	X_mat = as.matrix(cov_matrix_or_vector)

	# Eliminate columns that may be causing multicollinearity before attempting model fit
	X_mat = drop_highly_correlated_cols(X_mat)$M
	X_mat = drop_linearly_dependent_cols(X_mat)$M

	cov_matrix_or_vector_data_frame = data.frame(X_mat)

	# Optimization: Use fast_weibull_regression for initialization if applicable
	if (dist == "weibull") {
		y = surv_object[, 1]
		dead = surv_object[, 2]

		# fast_weibull_regression expects X without intercept (it adds it)
		# BUT robust_survreg might already have intercept-like cols?
		# No, the formula ~ . adds intercept.

		res = tryCatch(fast_weibull_regression(y, dead, X_mat), error = function(e) NULL)

		if (!is.null(res) && is.finite(res$neg_log_lik)) {
			init_vals = c(res$coefficients, res$log_sigma)

			mod = tryCatch({
				suppressWarnings(survival::survreg(
					surv_reg_formula,
					data = cov_matrix_or_vector_data_frame,
					dist = dist,
					init = init_vals,
					control = survival::survreg.control(maxiter = 100, rel.tolerance = 1e-9, outer.max = 10)
				))
			}, error = function(e) NULL)

			if (!is.null(mod) && !any(is.na(mod$coefficients))){
				return(mod)
			}
		}
	}

	init = rep(0, ncol(cov_matrix_or_vector_data_frame) + 1)
	num_iter = 1
	repeat {
		tryCatch({
			mod = suppressWarnings(survival::survreg(
				surv_reg_formula,
				data = cov_matrix_or_vector_data_frame,
				dist = dist,
				init = init,
				control = 	survival::survreg.control(
								maxiter = 100,			#default
								rel.tolerance = 1e-9, 	#default
								outer.max = 10			#default
							)
			))
			if (!any(is.na(mod$coefficients))){
				return(mod)
			}
		}, error = function(e){})
		if (num_iter >= num_max_iter){
			break
		}
		init = init + stats::rnorm(length(init))
		num_iter = num_iter + 1
	}

	return(NULL)
}

#' Robust Negative Binomial Regression with Backward Column-Dropping Fallback
#'
#' Fits a negative-binomial GLM via \code{\link[MASS]{glm.nb}} (log link, joint
#' ML estimation of the regression coefficients and the dispersion parameter
#' \eqn{\theta}), falling back to a smaller model when the fit throws an error
#' (typically non-convergence of \eqn{\theta}, or a singular design). On each
#' failure, the \strong{last} column of \code{data_obj} is dropped and the fit is
#' retried against the same \code{form_obj} (which must resolve to \code{y ~ .}
#' or similar so that its right-hand side tracks the shrinking column set); this
#' repeats until a fit succeeds or every predictor column has been removed, at
#' which point \code{NA} is returned. Because columns are dropped strictly from
#' the right, callers should order \code{data_obj}'s columns from most to least
#' important \emph{a priori}, or accept that this is a best-effort robustness
#' measure rather than a principled model-selection procedure.
#'
#' @param  form_obj  The model formula, typically \code{y ~ .} so its right-hand side
#'   automatically tracks \code{data_obj}'s shrinking column set across retries.
#' @param  data_obj  The data frame to run negative-binomial regression on; its \strong{last}
#'   column is dropped on each retry, in order, until a fit converges or no columns remain.
#' @return  The fitted \code{\link[MASS]{glm.nb}} model object, or \code{NA} if no column subset
#'   (down to and including the response alone) produced a successful fit.
#' @examples
#' dat = data.frame(y = rpois(10, 2), x1 = rnorm(10), x2 = rnorm(10))
#' robust_negbinreg(y ~ ., dat)
#' @export
robust_negbinreg = function(form_obj, data_obj){
	repeat {
		tryCatch({
			mod = suppressWarnings(MASS::glm.nb(form_obj, data = data_obj))
			return(mod)
		}, error = function(e){})
		data_obj = data_obj[, 1 : (ncol(data_obj) - 1), drop = FALSE] #chop off one column at a time until it works
		if (ncol(data_obj) == 0){
			break
		}
	}
	NA
}

#' Sample Mode
#'
#' Thin R wrapper around \code{sample_mode_cpp()}, which returns the most
#' frequently occurring value in \code{data}. Integer, logical, double,
#' character, and factor vectors are all supported (dispatched internally on
#' \code{TYPEOF(data)}; factors preserve their \code{class}/\code{levels}
#' attributes on the returned value). \code{NA} (and, for doubles, \code{NaN}
#' as a category distinct from \code{NA}) is counted like any other value and
#' can itself be returned as "the mode" if it is the most frequent entry.
#' Ties are broken by \strong{first occurrence}: among values tied for the
#' highest count, the one that appears earliest in \code{data} is returned —
#' this is a positional, not a numeric/lexicographic, tie-break rule.
#'
#' @param  data  A vector (integer, logical, double, character, or factor) to compute the mode of.
#' @return  A length-1 vector (same type as \code{data}) holding the most frequently occurring
#'   value, with ties broken in favor of whichever tied value occurs earliest in \code{data}.
#' @examples
#' sample_mode(c(1, 2, 2, 3))
#' @export
sample_mode = function(data){
	sample_mode_cpp(data)
}

#' Lean GLM Summary (Skips Deviance Residual Quantiles)
#'
#' A drop-in replacement for \code{\link[stats]{summary.glm}} that produces the
#' identical coefficient table, dispersion estimate, and (optionally)
#' correlation matrix, but \strong{omits the five-number summary of the
#' deviance residuals} (\code{summary(object$deviance.resid)}) that
#' \code{summary.glm()} always computes and stores in its \code{deviance.resid}
#' component. That residual summary is cheap for a single fit but adds up when
#' summarizing thousands of GLM fits in a resampling loop (e.g. bootstrap or
#' randomization replicates elsewhere in this package), so this function skips
#' it entirely; the returned object's \code{deviance.resid} component is simply
#' absent rather than populated, which will matter to code that calls
#' \code{print.summary.glm()} on the result or otherwise inspects that field.
#' Every other computation — dispersion estimation (Pearson \eqn{X^2/\mathrm{df}}
#' for Gaussian/Gamma/inverse-Gaussian families, fixed at 1 for
#' Poisson/binomial, unless \code{dispersion} is supplied explicitly), the
#' coefficient table (Wald \code{z} tests when dispersion is fixed/known,
#' \code{t} tests with \code{df.residual} degrees of freedom when dispersion is
#' estimated), and the optional \code{correlation}/\code{symbolic.cor} outputs,
#' is identical to \code{\link[stats]{summary.glm}}.
#'
#' @param  object  	A fitted \code{\link[stats]{glm}} object.
#' @param  dispersion  The dispersion parameter for the fitting family; if \code{NULL}
#'   (default), estimated as in \code{\link[stats]{summary.glm}} (fixed at 1 for
#'   \code{poisson}/\code{binomial}, else the Pearson-residual-based moment estimate).
#' @param  correlation  Logical; if \code{TRUE}, the estimated correlation matrix of the
#'   coefficients is returned and printed. Default \code{FALSE}.
#' @param  symbolic.cor  Logical; if \code{TRUE} and \code{correlation = TRUE}, the correlation
#'   matrix is printed in symbolic form (see \code{\link[stats]{symnum}}) rather than as
#'   numbers. Default \code{FALSE}.
#' @param  ...  		Currently unused; present only for signature compatibility with
#'   \code{\link[stats]{summary.glm}}.
#' @return  An object of class \code{c("summary.glm")} with the same components as
#'   \code{\link[stats]{summary.glm}}'s return value \strong{except} \code{deviance.resid},
#'   which is not computed and is absent from the result.
#' @seealso \code{\link[stats]{summary.glm}}, of which this is a residual-summary-skipping variant.
#' @examples
#' fit = glm(rbinom(10, 1, 0.5) ~ rnorm(10), family = binomial)
#' summary_glm_lean(fit)
#' @export
summary_glm_lean = function (object, dispersion = NULL, correlation = FALSE, symbolic.cor = FALSE, ...){
	est.disp <- FALSE
	df.r <- object$df.residual
	if (is.null(dispersion)) {
		fam <- object$family
		dispersion <- if (!is.null(fam$dispersion) && !is.na(fam$dispersion))
					fam$dispersion
				else if (fam$family %in% c("poisson", "binomial"))
					1
				else if (df.r > 0) {
					est.disp <- TRUE
					if (any(object$weights == 0))
						warning("observations with zero weight not used for calculating dispersion")
					sum((object$weights * object$residuals^2)[object$weights >
											0])/df.r
				}
				else {
					est.disp <- TRUE
					NaN
				}
	}
	aliased <- is.na(stats::coef(object))
	p <- object$rank
	if (p > 0) {
		p1 <- 1L:p
		Qr <- object$qr
		coef.p <- object$coefficients[Qr$pivot[p1]]
		covmat.unscaled <- chol2inv(Qr$qr[p1, p1, drop = FALSE])
		dimnames(covmat.unscaled) <- list(names(coef.p), names(coef.p))
		covmat <- dispersion * covmat.unscaled
		var.cf <- diag(covmat)
		s.err <- sqrt(var.cf)
		tvalue <- coef.p/s.err
		dn <- c("Estimate", "Std. Error")
		if (!est.disp) {
			pvalue <- 2 * stats::pnorm(-abs(tvalue))
			coef.table <- cbind(coef.p, s.err, tvalue, pvalue)
			dimnames(coef.table) <- list(names(coef.p), c(dn,
							"z value", "Pr(>|z|)"))
		}
		else if (df.r > 0) {
			pvalue <- 2 * stats::pt(-abs(tvalue), df.r)
			coef.table <- cbind(coef.p, s.err, tvalue, pvalue)
			dimnames(coef.table) <- list(names(coef.p), c(dn,
							"t value", "Pr(>|t|)"))
		}
		else {
			coef.table <- cbind(coef.p, NaN, NaN, NaN)
			dimnames(coef.table) <- list(names(coef.p), c(dn,
							"t value", "Pr(>|t|)"))
		}
		df.f <- NCOL(Qr$qr)
	}
	else {
		coef.table <- matrix( 0L, 4L)
		dimnames(coef.table) <- list(NULL, c("Estimate", "Std. Error",
						"t value", "Pr(>|t|)"))
		covmat.unscaled <- covmat <- matrix( 0L, 0L)
		df.f <- length(aliased)
	}
	keep <- match(c("call", "terms", "family", "deviance", "aic",
					"contrasts", "df.residual", "null.deviance", "df.null",
					"iter", "na.action"), names(object), 0L)
	ans <- c(object[keep], list(
					coefficients = coef.table,
					aliased = aliased,
					dispersion = dispersion,
					df = c(object$rank, df.r, df.f),
					cov.unscaled = covmat.unscaled,
					cov.scaled = covmat
				)
			)
	if (correlation && p > 0) {
		dd <- sqrt(diag(covmat.unscaled))
		ans$correlation <- covmat.unscaled/outer(dd, dd)
		ans$symbolic.cor <- symbolic.cor
	}
	class(ans) <- "summary.glm"
	return(ans)
}

#' Fast Mean Calculation
#'
#' Calculates the mean of a numeric vector using Rcpp for speed.
#'
#' @param  x A numeric vector.
#' @return  The mean of the vector.
#' @name mean_cpp
#' @rdname mean_cpp
NULL

#' Fast Variance Calculation
#'
#' Calculates the variance of a numeric vector using Rcpp for speed.
#'
#' @param  x A numeric vector.
#' @return  The variance of the vector.
#' @name var_cpp
#' @rdname var_cpp
NULL

.compute_kk_basic_match_data = function(X, n, y, w, m_vec){
	if (is.null(m_vec)){
		m_vec = rep(NA_integer_, n)
	}
	m_vec[is.na(m_vec)] = 0
	compute_zhang_match_data_cpp(X, y, w, m_vec)
}

# Normalizes a raw KK matching-on-the-fly pair-id vector (possibly NULL, possibly
# containing NAs for unmatched subjects) and splits it into matched vs. reservoir
# subject indices. This is the boilerplate every IVWC-style KK inference class
# repeats before fitting a matched-pairs component and a separate reservoir
# component (interval_censored_survival_response.md TODO-25): normalize m_vec,
# then matched_idx/i_matched = which(m_vec > 0L), reservoir_idx/i_reservoir =
# which(m_vec == 0L). Deliberately does NOT also subset y/dead/w/X — call sites
# need those sliced into different shapes (some build a KKstats-style list, some
# call straight into a fit_cox_model()-style helper, some need bare X[idx, ]), so
# only the index computation itself is centralized here.
split_kk_matched_reservoir_idx = function(m_vec, n){
	if (is.null(m_vec)) m_vec = rep(NA_integer_, n)
	m_vec = as.integer(m_vec)
	m_vec[is.na(m_vec)] = 0L
	list(
		m_vec = m_vec,
		matched_idx = which(m_vec > 0L),
		reservoir_idx = which(m_vec == 0L)
	)
}

# Cached variant: the X/m structural part (X_matched_diffs, X_matched_diffs_full,
# X_reservoir, m) depends only on m_vec and X, never on y or w.
#
# Cache hierarchy:
#   1. des_priv (design object's private env) — shared across ALL inference objects
#      on the same design.  Used when the current m_vec equals the design's own m_vec,
#      i.e., for the original inference and every randomization iteration (m_vec fixed,
#      only y/w permuted).
#   2. private_env (inference object's private env) — local fallback for bootstrap
#      resamples, which have a different m_vec_b and must not corrupt the design cache.
#
# Data is NEVER written to the global environment.
.compute_kk_basic_match_data_cached = function(private_env, des_priv, X, n, y, w, m_vec){
	if (is.null(m_vec)) m_vec = rep(NA_integer_, n)
	m_vec[is.na(m_vec)] = 0L

	# --- Fast path 1: design-level structural cache ---
	if (!is.null(des_priv) &&
	    !is.null(des_priv$xm_structural) &&
	    identical(m_vec, des_priv$xm_m_vec) &&
	    ncol(X) == ncol(des_priv$xm_structural$X_reservoir)){
		wy = compute_matching_wy_stats_cpp(as.integer(w), as.numeric(y), as.integer(m_vec))
		return(c(des_priv$xm_structural, wy))
	}

	# --- Fast path 2: inference-level structural cache (bootstrap case) ---
	# --- Full computation ---
	full = compute_zhang_match_data_cpp(as.matrix(X), as.numeric(y), as.integer(w), as.integer(m_vec))
	structural = full[c("m", "X_matched_diffs", "X_matched_diffs_full", "X_reservoir")]

	# Store in the design when the current m_vec is the design's own m_vec (so all
	# inference objects on this design share it); otherwise store locally (bootstrap).
	if (!is.null(des_priv)){
		des_m = des_priv$m
		if (is.null(des_m)) des_m = rep(NA_integer_, n)
		des_m[is.na(des_m)] = 0L
		if (identical(m_vec, des_m)){
			des_priv$xm_structural = structural
			des_priv$xm_m_vec      = m_vec
		}
	}
	full
}

.compute_kk_lin_basic_match_data = function(X, n, y, w, m_vec){
	if (is.null(m_vec)){
		m_vec = rep(NA_integer_, n)
	}
	m_vec[is.na(m_vec)] = 0
	compute_matching_lin_match_data_cpp(X, y, w, m_vec)
}

# Cached variant for the lin (means + diffs) C++ path. Same hierarchy as above.
.compute_kk_lin_basic_match_data_cached = function(private_env, des_priv, X, n, y, w, m_vec){
	if (is.null(m_vec)) m_vec = rep(NA_integer_, n)
	m_vec[is.na(m_vec)] = 0L

	if (!is.null(des_priv) &&
	    !is.null(des_priv$lin_xm_structural) &&
	    identical(m_vec, des_priv$lin_xm_m_vec) &&
	    ncol(X) == ncol(des_priv$lin_xm_structural$X_reservoir)){
		wy = compute_matching_lin_wy_stats_cpp(as.integer(w), as.numeric(y), as.integer(m_vec))
		return(c(des_priv$lin_xm_structural, wy))
	}

	full = compute_matching_lin_match_data_cpp(as.matrix(X), as.numeric(y), as.integer(w), as.integer(m_vec))
	structural = full[c("m", "X_matched_diffs_full", "X_matched_means_full", "X_reservoir")]

	if (!is.null(des_priv)){
		des_m = des_priv$m
		if (is.null(des_m)) des_m = rep(NA_integer_, n)
		des_m[is.na(des_m)] = 0L
		if (identical(m_vec, des_m)){
			des_priv$lin_xm_structural = structural
			des_priv$lin_xm_m_vec      = m_vec
		}
	}
	full
}

# Computes and caches the structural bootstrap components (i_reservoir, pair_rows, n_reservoir)
# for designs with a match vector (KK14, FixedBinaryMatch). Idempotent: no-op if already cached.
.init_kk_bootstrap_structure = function(des_priv){
	if (!is.null(des_priv$boot_pair_rows)) return(invisible(NULL))
	m_vec = des_priv$m
	n = des_priv$n
	if (is.null(m_vec)){
		des_priv$boot_i_reservoir  = seq_len(n)
		des_priv$boot_n_reservoir  = n
		des_priv$boot_pair_rows    = matrix(integer(0), nrow = 0L, ncol = 2L)
		return(invisible(NULL))
	}
	m_vec_int = as.integer(m_vec)
	m_vec_int[is.na(m_vec_int)] = 0L
	i_reservoir = which(m_vec_int == 0L)
	m_max = max(m_vec_int)
	pair_rows = if (m_max > 0L) {
		pr = matrix(integer(0), nrow = m_max, ncol = 2L)
		for (pid in seq_len(m_max)) pr[pid, ] = which(m_vec_int == pid)
		pr
	} else {
		matrix(integer(0), nrow = 0L, ncol = 2L)
	}
	des_priv$boot_i_reservoir = i_reservoir
	des_priv$boot_n_reservoir = length(i_reservoir)
	des_priv$boot_pair_rows   = pair_rows
	invisible(NULL)
}

# Draws a KK-aware bootstrap sample: resamples reservoir subjects iid and matched pairs as units.
# Returns list(i_b, m_vec_b) compatible with bootstrap_subset_inference.
.draw_kk_bootstrap_indices = function(des_priv){
	.init_kk_bootstrap_structure(des_priv)
	draw_matching_bootstrap_sample_cpp(
		i_reservoir  = des_priv$boot_i_reservoir,
		pair_rows    = des_priv$boot_pair_rows,
		n_reservoir  = des_priv$boot_n_reservoir
	)
}

.extract_se_from_rq_fit = function(fit, coef_name){
	is_bad_se = function(x) !is.finite(x) || x <= 0 || x > EDI_SEPARATION_THRESHOLD

	se = tryCatch({
		s_fit = suppressWarnings(summary(fit, se = "nid"))
		ct = s_fit$coefficients
		if (coef_name %in% rownames(ct)) ct[coef_name, "Std. Error"] else NA_real_
	}, error = function(e) NA_real_)

	if (is_bad_se(se)){
		se = tryCatch({
			s_fit = suppressWarnings(summary(fit, se = "iid"))
			ct = s_fit$coefficients
			if (coef_name %in% rownames(ct)) ct[coef_name, "Std. Error"] else NA_real_
		}, error = function(e) NA_real_)
	}

	if (is_bad_se(se)) NA_real_ else se
}

.complete_pair_index_matrix = function(pair_id){
	pair_id = as.integer(pair_id)
	valid = !is.na(pair_id) & pair_id > 0L
	if (!any(valid)) return(matrix(integer(0), ncol = 2))
	pair_rows = split(which(valid), pair_id[valid])
	pair_rows = pair_rows[lengths(pair_rows) == 2L]
	if (length(pair_rows) == 0L) return(matrix(integer(0), ncol = 2))
	pair_mat = do.call(rbind, lapply(pair_rows, function(idx) sort(as.integer(idx))))
	storage.mode(pair_mat) = "integer"
	pair_mat
}

.weibull_aft_margin_terms = function(y, eta, sigma){
	y = pmax(as.numeric(y), .Machine$double.xmin)
	log_t = log(y)
	log_H = (log_t - eta) / sigma
	H = exp(pmin(log_H, 700))
	log_f = log_H - log(sigma) - log_t - H
	list(H = H, log_f = log_f)
}

.clayton_copula_logA = function(H1, H2, theta){
	h1 = theta * H1
	h2 = theta * H2
	m = pmax(h1, h2, 0)
	inner = exp(h1 - m) + exp(h2 - m) - exp(-m)
	inner = pmax(inner, .Machine$double.xmin)
	m + log(inner)
}

.extract_survreg_start = function(y, dead, X){
	full_names = c("(Intercept)", colnames(X))
	warm_start_beta = stats::setNames(rep(0, length(full_names)), full_names)
	start_log_sigma = 0

	mod_fast = tryCatch(fast_weibull_regression(y, dead, X), error = function(e) NULL)
	if (!is.null(mod_fast) && !is.null(mod_fast$coefficients)){
		common = intersect(names(warm_start_beta), names(mod_fast$coefficients))
		warm_start_beta[common] = mod_fast$coefficients[common]
		if (!is.null(mod_fast$log_sigma) && is.finite(mod_fast$log_sigma)){
			start_log_sigma = mod_fast$log_sigma
		}
		return(list(beta = warm_start_beta, log_sigma = start_log_sigma))
	}

	mod = robust_survreg_with_surv_object(survival::Surv(y, dead), X)
	if (is.null(mod)) return(list(beta = warm_start_beta, log_sigma = start_log_sigma))

	mod_coef = c(mod$coefficients, "log(scale)" = log(mod$scale))
	common = intersect(names(warm_start_beta), names(mod_coef))
	warm_start_beta[common] = mod_coef[common]
	if (is.finite(mod_coef["log(scale)"])){
		start_log_sigma = mod_coef["log(scale)"]
	}
	list(beta = warm_start_beta, log_sigma = start_log_sigma)
}

.fit_standard_weibull_aft_from_matrix = function(y, dead, X, estimate_only = FALSE, starts = NULL, warm_start_fisher_info = NULL){
	if (length(y) == 0L || sum(dead) == 0L) return(NULL)
	mod_fast = tryCatch(
		fast_weibull_regression(
			y, dead, X,
			warm_start_params = if (length(starts) > 0) starts[[1]] else NULL,
			warm_start_fisher_info = warm_start_fisher_info,
			estimate_only = estimate_only
		),
		error = function(e) NULL
	)
	if (!is.null(mod_fast) &&
	    !is.null(mod_fast$coefficients) &&
	    (isTRUE(estimate_only) || !is.null(mod_fast$vcov)) &&
	    "w" %in% names(mod_fast$coefficients) &&
	    (isTRUE(estimate_only) || "w" %in% rownames(mod_fast$vcov))){
		beta = as.numeric(mod_fast$coefficients["w"])
		ssq = if (isTRUE(estimate_only)) NA_real_ else as.numeric(mod_fast$vcov["w", "w"])
		if (is.finite(beta) && (isTRUE(estimate_only) || (is.finite(ssq) && ssq > 0))){
			return(list(beta = beta, ssq = ssq))
		}
	}

	mod = robust_survreg_with_surv_object(survival::Surv(y, dead), X)
	if (is.null(mod) || is.null(mod$coefficients) || is.null(mod$var)) return(NULL)

	mod_coef = c(mod$coefficients, "log(scale)" = log(mod$scale))
	mod_vcov = mod$var
	coef_names = c(names(mod$coefficients), "log(scale)")
	colnames(mod_vcov) = rownames(mod_vcov) = coef_names
	if (!("w" %in% names(mod_coef)) || !("w" %in% rownames(mod_vcov))) return(NULL)

	beta = as.numeric(mod_coef["w"])
	ssq = as.numeric(mod_vcov["w", "w"])
	if (!is.finite(beta) || !is.finite(ssq) || ssq <= 0) return(NULL)
	list(beta = beta, ssq = ssq)
}

.extract_lognormal_start = function(y, dead, X, event_indicator){
	full_names = c("(Intercept)", colnames(X))
	warm_start_beta = stats::setNames(rep(0, length(full_names)), full_names)
	start_log_sigma = 0

	mod = robust_survreg_with_surv_object(
		survival::Surv(y, event_indicator),
		X,
		dist = "lognormal"
	)
	if (is.null(mod)) return(list(beta = warm_start_beta, log_sigma = start_log_sigma))

	mod_coef = c(mod$coefficients, "log(scale)" = log(mod$scale))
	common = intersect(names(warm_start_beta), names(mod_coef))
	warm_start_beta[common] = mod_coef[common]
	if (is.finite(mod_coef["log(scale)"])){
		start_log_sigma = mod_coef["log(scale)"]
	}
	list(beta = warm_start_beta, log_sigma = start_log_sigma)
}

.fit_dep_cens_transform_model = function(y, dead, X, estimate_only = FALSE, optimization_alg = "lbfgs"){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	y = pmax(as.numeric(y), .Machine$double.xmin)
	dead = as.integer(dead > 0)
	X = as.matrix(X)
	if (length(y) != nrow(X) || length(dead) != nrow(X)){
		stop("Dependent censoring transformation fit inputs must have matching row counts.")
	}
	if (sum(dead) == 0L || sum(1L - dead) == 0L) return(NULL)

	if (is.null(colnames(X))){
		full_names = c("treatment", paste0("x", seq_len(max(ncol(X) - 1L, 0L))))
		colnames(X) = full_names[seq_len(ncol(X))]
	}

	X = cbind("(Intercept)" = 1, X)
	num_beta = ncol(X)
	log_y = log(y)

	start_event = .extract_lognormal_start(y, dead, X, dead)
	start_cens = .extract_lognormal_start(y, dead, X, 1L - dead)
	base_start = c(
		unname(start_event$beta),
		unname(start_cens$beta),
		start_event$log_sigma,
		start_cens$log_sigma
	)

	neg_loglik = function(par){
		beta_event = par[seq_len(num_beta)]
		beta_cens = par[num_beta + seq_len(num_beta)]
		log_sigma_event = par[2L * num_beta + 1L]
		log_sigma_cens = par[2L * num_beta + 2L]
		atanh_rho = par[2L * num_beta + 3L]

		if (!is.finite(log_sigma_event) || !is.finite(log_sigma_cens) ||
		    log_sigma_event < -8 || log_sigma_event > 8 ||
		    log_sigma_cens < -8 || log_sigma_cens > 8 ||
		    !is.finite(atanh_rho) || abs(atanh_rho) > 8){
			return(1e100)
		}

		sigma_event = exp(log_sigma_event)
		sigma_cens = exp(log_sigma_cens)
		rho = tanh(atanh_rho)
		one_minus_rho_sq = pmax(1 - rho^2, .Machine$double.eps)
		sd_cond = sqrt(one_minus_rho_sq)

		mu_event = as.vector(X %*% beta_event)
		mu_cens = as.vector(X %*% beta_cens)
		z_event = (log_y - mu_event) / sigma_event
		z_cens = (log_y - mu_cens) / sigma_cens

		log_f_event = stats::dnorm(z_event, log = TRUE) - log_sigma_event - log_y
		log_f_cens = stats::dnorm(z_cens, log = TRUE) - log_sigma_cens - log_y
		log_surv_cens_cond = stats::pnorm((rho * z_event - z_cens) / sd_cond, log.p = TRUE)
		log_surv_event_cond = stats::pnorm((rho * z_cens - z_event) / sd_cond, log.p = TRUE)

		loglik = dead * (log_f_event + log_surv_cens_cond) +
			(1 - dead) * (log_f_cens + log_surv_event_cond)
		if (any(!is.finite(loglik))) return(1e100)
		-sum(loglik)
	}

	starts = if (isTRUE(estimate_only)) {
		# For bootstrap iterations, use only one start (no correlation) for speed.
		list(c(base_start, 0))
	} else {
		list(
			c(base_start, 0),
			c(base_start, atanh(0.25)),
			c(base_start, atanh(-0.25))
		)
	}
	best = NULL
	# Attempt C++ fast path first
	for (start_par in starts) {
		fit = tryCatch(
			fast_dep_cens_transform_optim_cpp(
				y = y, dead = dead, X = X, warm_start_params = start_par,
				maxit = 2000, reltol = if (isTRUE(estimate_only)) 1e-7 else 1e-9,
				optimization_alg = optimization_alg
			),
			error = function(e) NULL
		)
		if (!is.null(fit) && isTRUE(fit$converged) && is.finite(fit$value)) {
			if (is.null(best) || fit$value < best$value) best = fit
		}
	}

	# Fallback to R optim if C++ failed to converge
	if (is.null(best)) {
		for (start_par in starts){
			fit = tryCatch(
				stats::optim(
					par = start_par,
					fn = neg_loglik,
					method = "BFGS",
					hessian = !isTRUE(estimate_only),
					control = list(
						maxit = 2000, 
						# Tight tolerance for main estimate, looser for bootstrap iterations
						reltol = if (isTRUE(estimate_only)) 1e-7 else 1e-9
					)
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !is.finite(fit$value)) next
			if (is.null(best) || fit$value < best$value) best = fit
		}
	}
	if (is.null(best)) return(NULL)

	if (isTRUE(estimate_only)) {
		coefficients = best$par
		event_names = colnames(X)
		cens_names = paste0("censoring_", event_names)
		param_names = c(event_names, cens_names, "log_scale_event", "log_scale_censoring", "atanh_rho")
		names(coefficients) = param_names
		return(list(coefficients = coefficients, vcov = NULL))
	}

	hess = best$hessian
	vcov_full = tryCatch(solve(hess), error = function(e) NULL)
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))) return(NULL)

	event_names = colnames(X)
	cens_names = paste0("censoring_", event_names)
	param_names = c(event_names, cens_names, "log_scale_event", "log_scale_censoring", "atanh_rho")
	rownames(vcov_full) = colnames(vcov_full) = param_names

	coefficients = best$par
	names(coefficients) = param_names
	list(coefficients = coefficients, vcov = vcov_full)
}



.sanitize_proportion_response = function(y, interior = FALSE){
	assertNumeric(y, any.missing = FALSE)
	y = as.numeric(y)
	if (length(y) == 0L) return(y)
	if (isTRUE(interior)) {
		eps = .Machine$double.eps
		return(pmin(1 - eps, pmax(eps, y)))
	}
	pmin(1, pmax(0, y))
}
.softmax_three_from_logits = function(alpha0, alpha1){
	m = max(0, alpha0, alpha1)
	e0 = exp(alpha0 - m)
	e1 = exp(alpha1 - m)
	e2 = exp(-m)
	den = e0 + e1 + e2
	c(pi0 = e0 / den, pi1 = e1 / den, pib = e2 / den)
}

.build_zoib_start = function(y, X){
	y = as.numeric(y)
	eps = .Machine$double.eps
	y_clip = pmin(pmax(y, eps), 1 - eps)
	beta_start = rep(0, ncol(X) + 1L)
	names(beta_start) = c("(Intercept)", colnames(X))

	glm_start = tryCatch(
		fast_logistic_regression_cpp(
			cbind(1, X),
			y_clip
		),
		error = function(e) NULL
	)
	if (!is.null(glm_start) && length(glm_start$b) == length(beta_start)){
		if (all(is.finite(glm_start$b))){
			beta_start = as.numeric(glm_start$b)
			names(beta_start) = c("(Intercept)", colnames(X))
		}
	}

	pi0 = mean(y == 0)
	pi1 = mean(y == 1)
	pib = max(1 - pi0 - pi1, 1e-4)
	pi0 = min(max(pi0, 1e-4), 1 - 2e-4)
	pi1 = min(max(pi1, 1e-4), 1 - pi0 - 1e-4)
	pib = max(1 - pi0 - pi1, 1e-4)

	c(
		unname(beta_start),
		log_phi = log(10),
		alpha0 = log(pi0 / pib),
		alpha1 = log(pi1 / pib)
	)
}

.neg_loglik_zoib = function(par, p, is_zero, is_one, y_beta, X_beta) {
	beta = par[seq_len(p)]
	phi = exp(par[p + 1L])
	a0 = par[p + 2L]
	a1 = par[p + 3L]

	denom = 1 + exp(a0) + exp(a1)
	p0 = exp(a0) / denom
	p1 = exp(a1) / denom
	pb = 1 / denom

	ll = 0
	n0 = sum(is_zero)
	n1 = sum(is_one)
	if (n0 > 0L) ll = ll + n0 * log(p0)
	if (n1 > 0L) ll = ll + n1 * log(p1)

	if (length(y_beta) > 0L) {
		mu = as.vector(stats::plogis(X_beta %*% beta))
		mu = pmin(pmax(mu, .Machine$double.eps), 1 - .Machine$double.eps)
		shape1 = mu * phi
		shape2 = (1 - mu) * phi
		ll = ll + length(y_beta) * log(pb) + sum(stats::dbeta(y_beta, shape1, shape2, log = TRUE))
	}
	-ll
}

.fit_zero_one_inflated_beta = function(y, X, X_zero_one = X, estimate_only = FALSE, starts = NULL, optimization_alg = "lbfgs"){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	y = as.numeric(y)
	X = as.matrix(X)
	X_zero_one = as.matrix(X_zero_one)
	if (length(y) != nrow(X)){
		stop("Zero/one-inflated beta fit inputs must have matching row counts.")
	}
	if (nrow(X_zero_one) != length(y)){
		stop("Zero/one-inflated beta auxiliary inputs must have matching row counts.")
	}
	if (!all(is.finite(y)) || any(y < 0 | y > 1)){
		stop("Zero/one-inflated beta requires y in [0, 1].")
	}
	if (sum(y > 0 & y < 1) == 0L) return(NULL)

	if (is.null(colnames(X))){
		full_names = c("treatment", paste0("x", seq_len(max(ncol(X) - 1L, 0L))))
		colnames(X) = full_names[seq_len(ncol(X))]
	}

	X = cbind("(Intercept)" = 1, X)
	p = ncol(X)
	is_zero = y == 0
	is_one = y == 1
	is_beta = !(is_zero | is_one)
	y_beta = y[is_beta]
	X_beta = X[is_beta, , drop = FALSE]

	if (is.null(starts)){
		start0 = .build_zoib_start(y, X)
		starts = list(start0)
	}

	best = NULL
	best_val = Inf
	for (start_par in starts){
		fit = tryCatch(
			fast_zero_one_inflated_beta_cpp(X, X_zero_one, y, warm_start_params = start_par, optimization_alg = optimization_alg),
			error = function(e) NULL
		)
		if (is.null(fit) || !is.finite(fit$neg_loglik)) next
		if (is.null(best) || fit$neg_loglik < best_val){
			best = fit
			best_val = fit$neg_loglik
		}
	}
	if (is.null(best)) return(NULL)

	best_params = as.numeric(best$coefficients)
	param_names = c(colnames(X), "log_phi", "alpha0", "alpha1")
	coef_full = best_params
	names(coef_full) = param_names

	if (estimate_only) {
		return(list(
			coefficients = coef_full,
			vcov = NULL
		))
	}

	vcov_full = best$vcov
	if (!is.matrix(vcov_full) || any(dim(vcov_full) != length(param_names))){
		vcov_full = NULL
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))){
		vcov_full = tryCatch(numDeriv::hessian(.neg_loglik_zoib, best_params, p = p, is_zero = is_zero, is_one = is_one, y_beta = y_beta, X_beta = X_beta), error = function(e) NULL)
		vcov_full = tryCatch(solve(vcov_full), error = function(e) NULL)
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))){
		hess_alt = tryCatch(numDeriv::hessian(.neg_loglik_zoib, best_params, p = p, is_zero = is_zero, is_one = is_one, y_beta = y_beta, X_beta = X_beta), error = function(e) NULL)
		if (!is.null(hess_alt)){
			vcov_full = tryCatch(MASS::ginv(hess_alt), error = function(e) NULL)
		}
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))){
		# Keep the MLE when curvature is too unstable for a usable covariance matrix.
		vcov_full = matrix(NA_real_, nrow = length(param_names), ncol = length(param_names))
	}
	rownames(vcov_full) = colnames(vcov_full) = param_names

	list(
		coefficients = coef_full,
		vcov = vcov_full
	)
}

.fit_clayton_weibull_aft = function(y, dead, X, pair_id, include_singletons = FALSE, starts = NULL, estimate_only = FALSE, optimization_alg = "lbfgs", warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	y = as.numeric(y)
	dead = as.integer(dead > 0)
	X = as.matrix(X)
	if (is.null(colnames(X))){
		full_names = c("w", paste0("x", seq_len(max(ncol(X) - 1L, 0L))))
		colnames(X) = full_names[seq_len(ncol(X))]
	}
	if (length(y) != nrow(X) || length(dead) != nrow(X) || length(pair_id) != nrow(X)){
		stop("Clayton copula fit inputs must have matching row counts.")
	}

	pair_idx = .complete_pair_index_matrix(pair_id)
	if (nrow(pair_idx) == 0L && !include_singletons) return(NULL)

	pair_rows = if (nrow(pair_idx) > 0L) sort(unique(as.vector(pair_idx))) else integer(0)
	singleton_rows = if (include_singletons) setdiff(seq_len(nrow(X)), pair_rows) else integer(0)
	rows_used = sort(unique(c(pair_rows, singleton_rows)))
	if (length(rows_used) == 0L || sum(dead[rows_used]) == 0L) return(NULL)

	X = cbind("(Intercept)" = 1, X)
	num_beta = ncol(X)

	# Pre-extract constant indices and values for the likelihood function to avoid overhead
	has_pairs = nrow(pair_idx) > 0L
	if (has_pairs){
		i1 = pair_idx[, 1]
		i2 = pair_idx[, 2]
		d1 = dead[i1]
		d2 = dead[i2]
		mask00 = d1 == 0L & d2 == 0L
		mask10 = d1 == 1L & d2 == 0L
		mask01 = d1 == 0L & d2 == 1L
		mask11 = d1 == 1L & d2 == 1L
	}
	has_singletons = length(singleton_rows) > 0L
	if (has_singletons){
		d_sg = dead[singleton_rows]
		d_sg_comp = 1 - d_sg
	}

	neg_loglik = function(par){
		log_sigma = par[num_beta + 1L]
		log_theta = par[num_beta + 2L]
		if (!is.finite(log_sigma) || !is.finite(log_theta) ||
		    log_sigma < -8 || log_sigma > 8 || log_theta < -12 || log_theta > 6){
			return(1e100)
		}
		sigma = exp(log_sigma)
		theta = exp(log_theta)
		eta = as.vector(X %*% par[seq_len(num_beta)])
		margin_terms = .weibull_aft_margin_terms(y, eta, sigma)
		H = margin_terms$H
		log_f = margin_terms$log_f

		loglik = 0
		if (has_pairs){
			H1 = H[i1]
			H2 = H[i2]
			logf1 = log_f[i1]
			logf2 = log_f[i2]
			logA = .clayton_copula_logA(H1, H2, theta)
			pair_ll = numeric(length(i1))

			pair_ll[mask00] = -(1 / theta) * logA[mask00]
			pair_ll[mask10] = logf1[mask10] + (-1 / theta - 1) * logA[mask10] + (theta + 1) * H1[mask10]
			pair_ll[mask01] = logf2[mask01] + (-1 / theta - 1) * logA[mask01] + (theta + 1) * H2[mask01]
			pair_ll[mask11] = log(theta + 1) + logf1[mask11] + logf2[mask11] +
				(-1 / theta - 2) * logA[mask11] + (theta + 1) * (H1[mask11] + H2[mask11])

			if (any(!is.finite(pair_ll))) return(1e100)
			loglik = loglik + sum(pair_ll)
		}

		if (has_singletons){
			sg_ll = d_sg * log_f[singleton_rows] - d_sg_comp * H[singleton_rows]
			if (any(!is.finite(sg_ll))) return(1e100)
			loglik = loglik + sum(sg_ll)
		}

		if (!is.finite(loglik)) return(1e100)
		-loglik
	}

	if (is.null(starts)){
		X_no_int = X[rows_used, -1L, drop = FALSE]
		start = .extract_survreg_start(y[rows_used], dead[rows_used], X_no_int)
		start_par_base = c(unname(start$beta), start$log_sigma)
		starts = list(
			c(start_par_base, log(0.10)),
			c(start_par_base, log(0.50)),
			c(start_par_base, log(1.50))
		)
	}

	best = NULL
	# Use a slightly coarser tolerance for randomization draws if nsim is high
	control_list = list(maxit = 2000, reltol = 1e-9)

	# Attempt C++ fast path first
	for (start_par in starts) {
		fit = tryCatch(
			fast_clayton_weibull_aft_optim_cpp(
				y = y, dead = dead, X = X,
				pair_idx = if (has_pairs) pair_idx - 1L else matrix(0L, 0, 2),
				singleton_rows = if (has_singletons) singleton_rows - 1L else integer(0),
				warm_start_params = start_par,
				maxit = 2000, reltol = 1e-9,
				optimization_alg = optimization_alg,
				warm_start_fisher_info = warm_start_fisher_info
			),
			error = function(e) NULL
		)
		if (!is.null(fit) && isTRUE(fit$converged) && is.finite(fit$value)) {
			if (is.null(best) || fit$value < best$value) best = fit
		}
	}

	# Fallback to R optim (BFGS) if C++ failed to converge
	if (is.null(best)) {
		for (start_par in starts){
			fit = tryCatch(
				stats::optim(
					par = start_par,
					fn = neg_loglik,
					method = "BFGS",
					hessian = !isTRUE(estimate_only),
					control = control_list
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !is.finite(fit$value)) next
			if (is.null(best) || fit$value < best$value){
				best = fit
			}
		}
	}
	# Final fallback to Nelder-Mead (derivative-free, more robust)
	if (is.null(best)) {
		for (start_par in starts){
			fit = tryCatch(
				stats::optim(
					par = start_par,
					fn = neg_loglik,
					method = "Nelder-Mead",
					hessian = FALSE,
					control = list(maxit = 10000, reltol = 1e-8)
				),
				error = function(e) NULL
			)
			if (is.null(fit) || !is.finite(fit$value)) next
			if (is.null(best) || fit$value < best$value){
				best = fit
			}
		}
	}
	if (is.null(best)) return(NULL)

	beta_hat = best$par[seq_len(num_beta)]
	names(beta_hat) = colnames(X)
	
	if (isTRUE(estimate_only)){
			return(list(
				beta = as.numeric(beta_hat["w"]),
				ssq = NA_real_,
				theta = exp(best$par[num_beta + 2L]),
				log_sigma = best$par[num_beta + 1L],
				best_par = best$par,
				best_fit = best
			))
	}

	vcov_full = NULL
	if (!is.null(best$vcov)) {
		vcov_cpp = tryCatch(as.matrix(best$vcov), error = function(e) NULL)
		if (!is.null(vcov_cpp) && nrow(vcov_cpp) == num_beta + 2L && all(is.finite(diag(vcov_cpp)))) {
			vcov_full = vcov_cpp
		}
	}
	if (is.null(vcov_full)) {
		hess = best$hessian
		vcov_full = tryCatch(solve(hess), error = function(e) NULL)
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))) {
		X_no_int = X[, -1L, drop = FALSE]
		hess_cpp = tryCatch(
			get_clayton_weibull_aft_hessian_cpp(
				X_no_int, y, dead,
				if (has_pairs) pair_idx - 1L else matrix(0L, 0, 2),
				if (has_singletons) singleton_rows - 1L else integer(0),
				best$par
			),
			error = function(e) NULL
		)
		if (!is.null(hess_cpp)) {
			vcov_full = tryCatch(solve(-hess_cpp), error = function(e) NULL)
			if (!is.null(vcov_full) && any(!is.finite(diag(vcov_full)))) vcov_full = NULL
		}
	}
	if (is.null(vcov_full) || any(!is.finite(diag(vcov_full)))){
			return(list(
				beta = as.numeric(beta_hat["w"]),
				ssq = NA_real_,
				theta = exp(best$par[num_beta + 2L]),
				log_sigma = best$par[num_beta + 1L],
				best_par = best$par,
				best_fit = best
			))
	}

	rownames(vcov_full) = colnames(vcov_full) = c(colnames(X), "log_sigma", "log_theta")
	ssq = as.numeric(vcov_full["w", "w"])
	if (!is.finite(beta_hat["w"]) || !is.finite(ssq) || ssq <= 0) {
		# If w is not finite or ssq is not valid, we still return the best_par for potential reuse
			return(list(
				beta = as.numeric(beta_hat["w"]),
				ssq = NA_real_,
				theta = exp(best$par[num_beta + 2L]),
				log_sigma = best$par[num_beta + 1L],
				best_par = best$par,
				best_fit = best
			))
	}

	list(
		beta = as.numeric(beta_hat["w"]),
		ssq = ssq,
		theta = exp(best$par[num_beta + 2L]),
		log_sigma = best$par[num_beta + 1L],
		best_par = best$par,
		best_fit = best
	)
}

.fit_weibull_frailty = function(y, dead, X, pair_id, estimate_only = FALSE, optimization_alg = "lbfgs", warm_start_params = NULL, warm_start_fisher_info = NULL){
	.fit_weibull_frailty_rcpp(
		y = y,
		dead = dead,
		X = X,
		pair_id = pair_id,
		estimate_only = estimate_only,
		optimization_alg = optimization_alg,
		warm_start_params = warm_start_params,
		warm_start_fisher_info = warm_start_fisher_info
	)
}

.fit_weibull_frailty_rcpp = function(y, dead, X, pair_id, estimate_only = FALSE, optimization_alg = "lbfgs", warm_start_params = NULL, warm_start_fisher_info = NULL){
	optimization_alg = .normalize_optimizer_algorithm(optimization_alg, allow_irls = FALSE, default = "lbfgs")
	if (length(y) == 0L || sum(dead) == 0L) return(NULL)

	X = as.matrix(X)
	if (!("w" %in% colnames(X))){
		stop("X must include a treatment column named 'w'.")
	}
	if (!identical(colnames(X)[1L], "w")){
		X = X[, c("w", setdiff(colnames(X), "w")), drop = FALSE]
	}

	group_id = as.integer(factor(pair_id))
	if (anyNA(group_id)) return(NULL)

	mod = tryCatch(
		fast_weibull_frailty_cpp(
			y = as.numeric(y),
			dead = as.numeric(dead),
			X = X,
			group_id = group_id,
			warm_start_params = warm_start_params,
			warm_start_fisher_info = warm_start_fisher_info,
			estimate_only = estimate_only,
			optimization_alg = optimization_alg
		),
		error = function(e) NULL
	)
	if (is.null(mod) || !isTRUE(mod$converged) || length(mod$b) < 1L) return(NULL)

	beta = as.numeric(mod$b[1L])
	if (!is.finite(beta)) return(NULL)

	ssq = if (estimate_only) NA_real_ else as.numeric(mod$ssq_b_T)
	if (!estimate_only && (!is.finite(ssq) || ssq <= 0)) return(NULL)

	list(
		beta = beta,
		ssq = ssq,
		log_sigma_eps = as.numeric(mod$log_sigma_eps),
		log_sigma_u = as.numeric(mod$log_sigma_u),
		neg_loglik = as.numeric(mod$neg_loglik),
		best_par = c(as.numeric(mod$b), as.numeric(mod$log_sigma_eps), as.numeric(mod$log_sigma_u)),
		mod = mod
	)
}

# Breslow non-parametric baseline hazard estimate for Cox PH simulation.
# Returns list(times, cumhaz) with the cumulative baseline hazard at each unique event time.
.breslow_hazard = function(y, dead, X, b_null){
	if (length(y) == 0L || sum(dead) == 0L) return(list(times = numeric(0), cumhaz = numeric(0)))
	eta = as.numeric(X %*% b_null)
	risk = exp(eta - max(eta))
	o = order(y, -dead)
	y_o = y[o]; dead_o = dead[o] > 0.5; risk_o = risk[o]
	event_times = unique(y_o[dead_o])
	if (length(event_times) == 0L) return(list(times = numeric(0), cumhaz = numeric(0)))
	cumhaz = numeric(length(event_times))
	h_acc = 0
	for (k in seq_along(event_times)){
		at_risk = y_o >= event_times[k]
		R_k = sum(risk_o[at_risk])
		d_k = sum(dead_o[y_o == event_times[k]])
		h_acc = h_acc + d_k / max(R_k, 1e-10)
		cumhaz[k] = h_acc
	}
	list(times = event_times, cumhaz = cumhaz)
}

# Simulate survival times under a stratified Cox model using per-stratum Breslow baselines.
.cox_simulate_stratified = function(y_obs, dead_obs, X_null, b_null, strata){
	n = nrow(X_null)
	eta = as.numeric(X_null %*% b_null)
	risk_i = exp(eta - max(eta))
	max_time = max(y_obs) * 2
	T_sim = rep(max_time, n)
	for (s in unique(strata)){
		idx = which(strata == s)
		breslow_s = .breslow_hazard(y_obs[idx], dead_obs[idx], X_null[idx, , drop = FALSE], b_null)
		if (length(breslow_s$times) == 0L) next
		for (i in idx){
			U = runif(1L)
			tgt = -log(max(U, 1e-10)) / risk_i[i]
			j_k = which(breslow_s$cumhaz >= tgt)
			T_sim[i] = if (length(j_k) == 0L) max_time else breslow_s$times[j_k[1L]]
		}
	}
	C_i = ifelse(dead_obs == 0, y_obs, Inf)
	y_sim = pmin(T_sim, C_i)
	dead_sim = as.numeric(T_sim <= C_i)
	list(y_sim = y_sim, dead_sim = dead_sim)
}

# Simulate survival times by inverting the Breslow baseline hazard.
# Returns list(y_sim, dead_sim) applying observed censoring times.
.cox_simulate_from_breslow = function(breslow, y_obs, dead_obs, X_null, b_null){
	n = nrow(X_null)
	eta = as.numeric(X_null %*% b_null)
	risk_i = exp(eta - max(eta))
	U = runif(n)
	target = -log(pmax(U, 1e-10))
	times = breslow$times
	cumhaz = breslow$cumhaz
	max_time = max(y_obs) * 2
	T_sim = vapply(seq_len(n), function(i){
		tgt = target[i] / risk_i[i]
		idx = which(cumhaz >= tgt)
		if (length(idx) == 0L) max_time else times[idx[1L]]
	}, numeric(1L))
	C_i = ifelse(dead_obs == 0, y_obs, Inf)
	y_sim = pmin(T_sim, C_i)
	dead_sim = as.numeric(T_sim <= C_i)
	list(y_sim = y_sim, dead_sim = dead_sim)
}
