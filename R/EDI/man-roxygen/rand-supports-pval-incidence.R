#' @description Whether \code{compute_rand_two_sided_pval()} is actually
#'   usable on this instance right now -- \code{FALSE} exactly when it
#'   would \code{stop()}: an \code{incidence}-response instance with no
#'   custom randomization statistic and a design not eligible for
#'   design-randomization-based incidence inference (see
#'   \code{private$should_use_design_randomization_for_incidence()}).
#'   \code{TRUE} for every other case, including every non-incidence
#'   response type. Public, self-contained (only reads already-set
#'   instance state, no side effects), so \code{InferenceSuite} can
#'   check this before attempting the sentinel instead of relying on
#'   the \code{stop()} being silently swallowed into a \code{pval = NA}
#'   "ok" row -- the single source of truth for both this check and
#'   \code{compute_rand_two_sided_pval()}'s own guard, so the two can
#'   never drift apart.
#' @return A single logical.
