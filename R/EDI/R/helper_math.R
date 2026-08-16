# Small numeric utilities: logit/inverse-logit transforms and mode calculation.

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

