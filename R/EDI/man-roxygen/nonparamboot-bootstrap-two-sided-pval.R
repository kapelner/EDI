#' @description Computes a bootstrap-based two-sided p-value for the treatment effect.
#'   Validity is asymptotic and design-dependent; for most covariate-adaptive designs the
#'   p-value errs conservative. See the class-level section \emph{Design-specific validity
#'   caveats for the nonparametric bootstrap}.
#'
#' @param delta  				Null hypothesis value. Default 0.
#' @param B  					Number of bootstrap samples. Default 501.
#' @param min_number_usable_samples Minimum number of finite bootstrap samples
#'   required after filtering. Default 5. Must be less than or equal to \code{B}.
#' @param type  				Bootstrap p-value type. Supported values are
#'   \code{"percentile"} (default), \code{"symmetric"}, \code{"studentized"},
#'   \code{"bootstrap-t"}, and \code{"bca"}.
#'   \code{"percentile"}: shifts the bootstrap distribution to be centred at
#'   \code{delta} and counts the two-tail proportion (Hall 1992).
#'   \code{"symmetric"}: uses \eqn{|T^* - \bar{T}^*| \ge |t_{\rm obs} - \delta|}
#'   for a symmetric one-sample test; recommended by Hall & Wilson (1991) when the
#'   null distribution may be skewed. This pooled-tail test is offered only as a
#'   p-value here, not as a confidence-interval \code{type} in
#'   \code{compute_bootstrap_confidence_interval}: pooling both tails via
#'   \eqn{|\cdot|} improves testing power (Hall & Wilson's original use case), but
#'   inverting it unstudentized would add no value as an interval. The unstudentized
#'   pivot is not asymptotically pivotal, so the resulting interval would have the
#'   same first-order \eqn{O(n^\{-1/2\})} coverage error as \code{"percentile"}/
#'   \code{"basic"}, while forcing symmetric bounds around a possibly skewed
#'   bootstrap distribution --- strictly worse than \code{"percentile"}/\code{"basic"}
#'   for shape-adaptivity, and strictly worse than \code{"symmetric-percentile-t"} for
#'   accuracy, since studentizing (not the absolute-value pooling) is what buys the
#'   \eqn{O(n^\{-1\})} improvement. The CI-worthy symmetric variant is therefore
#'   \code{"symmetric-percentile-t"} (studentized pivot), not a plain \code{"symmetric"}
#'   CI type.
#'   \code{"studentized"} / \code{"bootstrap-t"}: pivots by the per-replicate
#'   standard error, giving O(n^\{-1\}) error versus O(n^\{-1/2\}) for the percentile
#'   method (Hall 1992; Davidson & MacKinnon 1999).
#'   \code{"bca"}: bias-corrected and accelerated p-value via closed-form CI
#'   inversion using the jackknife acceleration and bias-correction constants;
#'   second-order accurate (Efron 1987; Efron & Tibshirani 1993).
#' @param na.rm  				Remove non-finite bootstrap replicates. Default FALSE.
#' @param show_progress  		A flag indicating whether a progress bar should be displayed.
#'
#' @return 	A bootstrap two-sided p-value.
