#' @description Returns the estimated treatment effect: an inverse-variance-weighted
#'   compound (IVWC) of two Hodges-Lehmann median-shift estimates.
#'
#' @details For matched pairs, \eqn{\hat\beta_m} is the Hodges-Lehmann
#'   estimate from a Wilcoxon \strong{signed-rank} test on the within-pair
#'   differences (\code{stats::wilcox.test(diffs, conf.int = TRUE)}'s
#'   \code{estimate}, the median of the Walsh averages
#'   \eqn{(d_i + d_j)/2}), with normal-model calibrated variance
#'   \eqn{(2\pi/3)\operatorname{Var}(\text{Walsh})/m}. For
#'   reservoir (unmatched) subjects, \eqn{\hat\beta_r} is the
#'   Hodges-Lehmann estimate from a Wilcoxon \strong{rank-sum} test between
#'   treated and control reservoir responses (median of all pairwise
#'   differences \eqn{y_{T,i} - y_{C,j}}), with normal-model calibrated
#'   variance \eqn{\pi\operatorname{Var}(Y_T-Y_C)(n_T+n_C)/(6n_Tn_C)}.
#'   When both sub-estimates
#'   are usable, the compound estimate is the inverse-variance-weighted
#'   combination
#'   \deqn{\hat\beta_T = w^* \hat\beta_m + (1-w^*)\, \hat\beta_r, \qquad
#'   w^* = \frac{\widehat{\mathrm{Var}}(\hat\beta_r)}{\widehat{\mathrm{Var}}(\hat\beta_r)
#'   + \widehat{\mathrm{Var}}(\hat\beta_m)},}
#'   with combined variance \eqn{\widehat{\mathrm{Var}}(\hat\beta_r)\,
#'   \widehat{\mathrm{Var}}(\hat\beta_m) / (\widehat{\mathrm{Var}}(\hat\beta_r) +
#'   \widehat{\mathrm{Var}}(\hat\beta_m))} — the same combination scheme as
#'   \code{\link[EDI:InferenceAllKKMeanDiffIVWC]{InferenceAllKKMeanDiffIVWC}},
#'   but applied to rank-based rather than mean-based sub-estimates. If
#'   only one sub-estimate is usable (e.g. no matched pairs, or a degenerate
#'   reservoir), \eqn{\hat\beta_T} falls back to that sub-estimate alone.
#' @param estimate_only If TRUE, omit only the final combined standard error;
#'   component variances are still fitted because they determine IVWC weights.
