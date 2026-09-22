#' @description Returns the Hodges-Lehmann confidence interval directly from
#'   \code{stats::wilcox.test(yT, yC, conf.int = TRUE, exact = FALSE,
#'   conf.level = 1 - alpha)} — the standard nonparametric interval
#'   associated with the Wilcoxon rank-sum test, based on inverting the
#'   rank-sum test statistic rather than a Wald normal-approximation
#'   interval around \code{$compute_estimate()}'s point estimate (though the
#'   two coincide asymptotically).
#' @param alpha Significance level. Default 0.05.
