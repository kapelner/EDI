#' Robust sandwich variance helpers
#'
#' @keywords internal
#' @noRd
robust_sandwich_meat_from_residuals = function(X, residuals) {
	X = as.matrix(X)
	residuals = as.numeric(residuals)
	if (nrow(X) == 0L || ncol(X) == 0L || length(residuals) != nrow(X)) {
		return(NULL)
	}
	if (any(!is.finite(X)) || any(!is.finite(residuals))) {
		return(NULL)
	}
	crossprod(X, X * (residuals^2))
}

#' @keywords internal
#' @noRd
robust_sandwich_vcov = function(bread, meat) {
	bread = as.matrix(bread)
	meat = as.matrix(meat)
	if (nrow(bread) == 0L || ncol(bread) == 0L || !identical(dim(bread), dim(meat))) {
		return(NULL)
	}
	if (nrow(bread) != ncol(bread) || any(!is.finite(bread)) || any(!is.finite(meat))) {
		return(NULL)
	}
	vcov = bread %*% meat %*% bread
	if (any(!is.finite(vcov))) {
		return(NULL)
	}
	vcov
}

#' @keywords internal
#' @noRd
robust_sandwich_variance = function(vcov, j) {
	j = as.integer(j)
	if (length(j) != 1L || !is.finite(j) || j < 1L) {
		return(NA_real_)
	}
	vcov = as.matrix(vcov)
	if (j > nrow(vcov) || j > ncol(vcov)) {
		return(NA_real_)
	}
	ssq = as.numeric(vcov[j, j])
	if (!is.finite(ssq) || ssq < 0) {
		return(NA_real_)
	}
	ssq
}

#' @keywords internal
#' @noRd
robust_sandwich_variance_from_xtwx = function(X, residuals, XtWX, j) {
	meat = robust_sandwich_meat_from_residuals(X, residuals)
	if (is.null(meat)) {
		return(NA_real_)
	}
	bread = tryCatch(
		solve(XtWX),
		error = function(e) {
			if (is_edi_control_condition(e)) stop(e)
			NULL
		}
	)
	if (is.null(bread)) {
		return(NA_real_)
	}
	vcov = robust_sandwich_vcov(bread, meat)
	if (is.null(vcov)) {
		return(NA_real_)
	}
	robust_sandwich_variance(vcov, j)
}

RobustSandwichSource = list(
	public = list(),
	private = list(
		robust_sandwich_meat_from_residuals = function(X, residuals) {
			robust_sandwich_meat_from_residuals(X, residuals)
		},
		robust_sandwich_vcov = function(bread, meat) {
			robust_sandwich_vcov(bread, meat)
		},
		robust_sandwich_variance = function(vcov, j) {
			robust_sandwich_variance(vcov, j)
		},
		robust_sandwich_variance_from_xtwx = function(X, residuals, XtWX, j) {
			robust_sandwich_variance_from_xtwx(X, residuals, XtWX, j)
		}
	)
)
