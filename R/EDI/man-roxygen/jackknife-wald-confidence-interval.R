#' @description Computes a normal-approximation confidence interval using the
#'   jackknife estimate and jackknife standard error.
#'
#' For blocking designs, this uses leave-one-block-out deletion units. For
#' matching designs, it uses leave-match-out deletion units. For KK designs,
#' it uses leave-match-out for matched pairs and leave-one-out for reservoir
#' subjects.
#'
#' @param alpha Significance level. Default 0.05.
#' @param unit Deletion unit. Default `\"auto\"`, which chooses a design-aware
#'   unit automatically.
#'
#' @return A jackknife-Wald confidence interval.
