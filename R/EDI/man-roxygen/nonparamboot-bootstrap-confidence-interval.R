#' @description Computes a bootstrap-based confidence interval.
#'   Coverage is asymptotic and design-dependent; for most covariate-adaptive designs the
#'   interval errs conservative (over-coverage). See the class-level section
#'   \emph{Design-specific validity caveats for the nonparametric bootstrap}.
#'
#' @param alpha  				The confidence level 1 - \code{alpha}. Default 0.05.
#' @param B  					Number of bootstrap samples. Default 501.
#' @param min_number_usable_samples Minimum number of finite bootstrap samples
#'   required after filtering. Default 5. Must be less than or equal to \code{B}.
#' @param type  				Bootstrap CI type. Supported values are
#'   \code{"percentile"}, \code{"basic"}, \code{"studentized"},
#'   \code{"bootstrap-t"}, \code{"symmetric-percentile-t"},
#'   \code{"bca"}, \code{"prepivoted"}, \code{"double-bootstrap"},
#'   \code{"calibrated"}, and \code{"smoothed"}.
#'   There is no plain \code{"symmetric"} CI type (contrast with the \code{"symmetric"}
#'   p-value type in \code{compute_bootstrap_two_sided_pval}): inverting the unstudentized
#'   Hall & Wilson pooled-tail statistic would add no value as an interval, since it is not
#'   asymptotically pivotal and so has the same first-order \eqn{O(n^\{-1/2\})} coverage
#'   error as \code{"percentile"}/\code{"basic"}, while forcing symmetric bounds around a
#'   possibly skewed bootstrap distribution --- strictly worse than \code{"percentile"}/
#'   \code{"basic"} for shape-adaptivity, and strictly worse than
#'   \code{"symmetric-percentile-t"} for accuracy, since studentizing (not the
#'   absolute-value pooling) is what buys the \eqn{O(n^\{-1\})} improvement.
#'   \code{"symmetric-percentile-t"} is the CI-worthy symmetric variant.
#' @param na.rm                                   Remove non-finite bootstrap replicates.
#'   Default TRUE. Non-finite replicates are always removed internally.
#' @param show_progress  		Show progress bar.
#'
#' @return 	A bootstrap confidence interval.
