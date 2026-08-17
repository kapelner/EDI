# Model-matrix construction helpers: building a model matrix from a formula/feature spec and dropping (near-)collinear columns.

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
#' through \code{drop_linearly_dependent_cols}, which detects the numeric rank of
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

