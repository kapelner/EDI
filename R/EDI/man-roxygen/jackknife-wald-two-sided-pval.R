#' @description Computes a two-sided Wald p-value using the jackknife estimate
#'   and jackknife standard error.
#'
#' For blocking designs, this uses leave-one-block-out deletion units. For
#' matching designs, it uses leave-match-out deletion units. For KK designs,
#' it uses leave-match-out for matched pairs and leave-one-out for reservoir
#' subjects.
#'
#' @param delta Null treatment-effect value. Default 0.
#' @param unit Deletion unit. Default `\"auto\"`, which chooses a design-aware
#'   unit automatically.
#'
#' @return A two-sided jackknife-Wald p-value.
