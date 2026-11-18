# roxygen documentation stubs for Rcpp-exported functions with no R-level definition of their own.

#' Fast Mean Calculation
#'
#' Calculates the mean of a numeric vector using Rcpp for speed.
#'
#' @param  x A numeric vector.
#' @return  The mean of the vector.
#' @usage mean_cpp(x)
#' @keywords internal
#' @name mean_cpp
#' @rdname mean_cpp
NULL

#' Fast Variance Calculation
#'
#' Calculates the variance of a numeric vector using Rcpp for speed.
#'
#' @param  x A numeric vector.
#' @return  The sample variance (denominator \eqn{n - 1}) of the vector, or \code{NA}
#'   if it has length 1 or less.
#' @usage var_cpp(x)
#' @keywords internal
#' @name var_cpp
#' @rdname var_cpp
NULL

