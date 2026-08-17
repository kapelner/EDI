# Robust (heavy-tailed-safe) survreg/negbin refitting wrappers and a lean summary.glm() replacement.

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
#'     are dropped first via \code{drop_highly_correlated_cols} then
#'     \code{drop_linearly_dependent_cols}, before any fitting is attempted.
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

