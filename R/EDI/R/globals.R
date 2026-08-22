# Internal environment for the EDI package to store global state
edi_env = new.env(parent = emptyenv())

# .wgt__ is a data.table/formula column name used via non-standard evaluation
# (e.g. `weights = .wgt__` inside a formula-fitting call), not a real object;
# R CMD check's static analysis can't see that, so it must be declared here.
utils::globalVariables(".wgt__")

`%||%` <- function(a, b) if (!is.null(a)) a else b

# Coefficient/statistic magnitude beyond which a fit is treated as
# complete/quasi-complete separation or otherwise extreme: the MLE does not
# exist (or a bootstrap/LR replicate has diverged) and the optimizer has
# stopped at a large-but-finite value that would otherwise silently corrupt
# CIs/SEs. Centralized here because this exact 1e6 heuristic was previously
# copy-pasted independently in helper_glm_fit.R,
# inference_all_abstract_param_boot.R, inference_all_abstract_non_param_boot.R,
# and the helper_*.R files split out of the former other_helpers.R, with no
# guarantee the copies stayed in sync.
#
# Note: inference_mixin_kk_gee_shared.R's private$max_abs_reasonable_coef
# (default 1e4) is a deliberately different, tighter threshold for that
# family and is intentionally left as its own separately-configured value
# rather than folded into this constant.
#' @keywords internal
#' @noRd
EDI_SEPARATION_THRESHOLD = 1e6

#' Whether a coefficient vector's magnitude indicates complete/quasi-complete
#' separation (the MLE does not exist and the optimizer diverged to a
#' large-but-finite value). Returns FALSE if no finite entries are present
#' (that is a different failure mode -- a non-finite estimate -- not this one).
#' @keywords internal
#' @noRd
is_separated_coefficient_magnitude = function(x, threshold = EDI_SEPARATION_THRESHOLD) {
  x = as.numeric(x)
  if (!any(is.finite(x))) return(FALSE)
  max(abs(x), na.rm = TRUE) > threshold
}

#' Whether an error is a timeout/interrupt control condition that must not be
#' converted into an ordinary failed fit or failed resampling replicate.
#' @keywords internal
#' @noRd
is_edi_control_condition = function(e){
  msg = conditionMessage(e)
  inherits(e, "TimeoutException") ||
    inherits(e, "interrupt") ||
    grepl("reached elapsed time limit", msg, fixed = TRUE) ||
    grepl("reached CPU time limit", msg, fixed = TRUE)
}

# Closure to encapsulate the internal assertion override flag (used by SimulationFramework)
.assert_manager = (function() {
  internal_run_asserts = TRUE
  list(
    toggle = function(on = TRUE) {
      internal_run_asserts <<- isTRUE(on)
      invisible(internal_run_asserts)
    },
    should_run = function() {
      internal_run_asserts && isTRUE(getOption("edi.run_asserts", TRUE))
    }
  )
})()
#' Toggle the execution of assertions throughout the package
#' 
#' @description This function enables or disables the internal input validation checks (assertions)
#' by setting the \code{options(edi.run_asserts = ...)} value.
#' Disabling assertions can provide a significant performance boost in heavy
#' simulations (often 10x-20x speedup), but it removes the safety rails that
#' prevent invalid data from reaching the internal algorithms.
#' 
#' \strong{Warning:} If assertions are disabled, passing malformed or invalid
#' data to package functions may result in cryptic R errors, incorrect
#' statistical results, or even hard system crashes (SEGFAULTs) at the C++ layer.
#' Only disable assertions if you are certain your data is pre-validated and
#' follows the package requirements exactly.
#' 
#' @param on Logical scalar. If TRUE (default), assertions are executed. If FALSE, they are skipped.
#' @keywords internal
#' @export
toggle_asserts = function(on = TRUE) {
  options(edi.run_asserts = isTRUE(on))
  invisible(isTRUE(on))
}
# private method
should_run_asserts = .assert_manager$should_run

stop_bayesian_bootstrap_for_ivwc = function(self_obj = NULL) {
  # Relaxing this to allow Jackknife if implemented.
  # For now, if we reach here, it means it is not yet implemented for this specific IVWC operation.
  cls = if (is.null(self_obj)) "This IVWC class" else class(self_obj)[1]
  stop(
    cls,
    " does not support this Bayesian bootstrap operation. Implementation is missing for this IVWC path."
  )
}

stop_bayesian_bootstrap_for_bai = function(self_obj = NULL) {
  cls = if (is.null(self_obj)) "This Bai-adjusted KK class" else class(self_obj)[1]
  stop(
    cls,
    " does not support this Bayesian bootstrap operation. Implementation is missing for this Bai path."
  )
}

#' Calls a class's own `design_compatibility_reason(des_obj)` predicate and,
#' if it returns a non-`NA` reason, `stop()`s with that class's message text
#' for the reason -- centralizing the "call the predicate, look up the
#' message, stop()" boilerplate that would otherwise be duplicated verbatim
#' in every `initialize()` that consults its own `design_compatibility_reason`
#' (single source of truth with the discovery-time predicate; see
#' `inference_class_design_compatibility_reason()` in inference_suite.R and
#' fix_inference_hierarchy.md). Does nothing if compatible.
#'
#' @param design_compatibility_reason_fn The class's own `design_compatibility_reason`
#'   function (e.g. `private$design_compatibility_reason`), called unbound with `des_obj`.
#' @param des_obj The design object under construction.
#' @param reason_messages A named list/character vector mapping every reason code the
#'   class's `design_compatibility_reason` can return to the exact `stop()` message text.
#'
#' @keywords internal
#' @noRd
stop_if_design_incompatible = function(design_compatibility_reason_fn, des_obj, reason_messages) {
  reason = design_compatibility_reason_fn(des_obj)
  if (!is.na(reason)) {
    stop(reason_messages[[reason]])
  }
  invisible(NULL)
}

# Bayesian bootstrap helpers were removed to allow Jackknife support across all paths.

weighted_ordinal_bootstrap_surrogate_fit = function(X, y, row_weights, method = c("logistic", "probit", "cauchit", "cloglog"), warm_start_params = NULL) {
  method = match.arg(method)
  X = as.matrix(X)
  y_num = as.integer(y)
  row_weights = as.numeric(row_weights)
  ok = is.finite(row_weights) & row_weights > 0 & is.finite(y_num)
  if (!any(ok)) return(NULL)
  X_fit = X[ok, , drop = FALSE]
  y_fit = y_num[ok]
  w_fit = row_weights[ok]
  if (is.null(colnames(X_fit))) {
    colnames(X_fit) = paste0("x", seq_len(ncol(X_fit)))
  }
  if (!("treatment" %in% colnames(X_fit)) && ncol(X_fit) >= 1L) {
    colnames(X_fit)[1L] = "treatment"
  }
  dat = as.data.frame(X_fit, check.names = FALSE)
  y_levels = sort(unique(y_fit))
  dat$y_ord = ordered(y_fit, levels = y_levels)
  fit_polr = function(start = NULL) {
    tryCatch(
      suppressWarnings(
        MASS::polr(
          y_ord ~ .,
          data = dat,
          weights = w_fit,
          method = method,
          Hess = FALSE,
          start = start
        )
      ),
      error = function(e) NULL
    )
  }
  polr_start = NULL
  warm_start_params = as.numeric(warm_start_params)
  n_coef = ncol(X_fit)
  n_zeta = length(y_levels) - 1L
  if (length(warm_start_params) == n_coef + n_zeta && all(is.finite(warm_start_params))) {
    beta_start = utils::tail(warm_start_params, n_coef)
    zeta_start = utils::head(warm_start_params, n_zeta)
    if (n_zeta == 0L || all(diff(zeta_start) > 0)) {
      polr_start = c(beta_start, zeta_start)
      names(polr_start) = c(colnames(X_fit), paste0("zeta", seq_len(n_zeta)))
    }
  }
  fit = fit_polr(polr_start)
  if (is.null(fit) && !is.null(polr_start)) {
    fit = fit_polr(NULL)
  }
  coef_vec = tryCatch(stats::coef(fit), error = function(e) NULL)
  beta_hat = if (!is.null(coef_vec) && ("treatment" %in% names(coef_vec))) as.numeric(coef_vec[["treatment"]]) else NA_real_
  if (is.finite(beta_hat)) {
    return(list(beta_hat = beta_hat, coefficients = coef_vec, fit_type = paste0("polr_", method)))
  }
  X_lm = cbind(`(Intercept)` = 1, X_fit)
  lm_fit = tryCatch(
    stats::lm.wfit(x = X_lm, y = as.numeric(y_fit), w = w_fit),
    error = function(e) NULL
  )
  coef_lm = if (is.null(lm_fit)) NULL else as.numeric(lm_fit$coefficients)
  names(coef_lm) = if (is.null(coef_lm)) NULL else colnames(X_lm)
  beta_hat_lm = if (!is.null(coef_lm) && ("treatment" %in% names(coef_lm))) as.numeric(coef_lm[["treatment"]]) else NA_real_
  if (!is.finite(beta_hat_lm)) return(NULL)
  list(beta_hat = beta_hat_lm, coefficients = coef_lm, fit_type = "weighted_lm_surrogate")
}

weights_are_effectively_constant = function(weights, tol = sqrt(.Machine$double.eps)) {
  weights = as.numeric(weights)
  ok = is.finite(weights)
  if (!any(ok)) return(FALSE)
  weights = weights[ok]
  (max(weights) - min(weights)) <= tol
}

kk_pair_and_reservoir_bootstrap_weights = function(private_env, row_weights) {
  row_weights = as.numeric(row_weights)
  m_vec = private_env$m
  n = length(row_weights)
  if (is.null(m_vec)) {
    m_vec = rep(NA_integer_, n)
  } else {
    m_vec = as.integer(m_vec)
    if (length(m_vec) != n) {
      m_vec = rep_len(m_vec, n)
    }
  }
  pair_ids = sort(unique(m_vec[is.finite(m_vec) & m_vec > 0L]))
  pair_weights = if (length(pair_ids) > 0L) {
    vapply(pair_ids, function(pid) {
      idx = which(m_vec == pid)
      mean(row_weights[idx], na.rm = TRUE)
    }, numeric(1))
  } else {
    numeric(0)
  }
  reservoir_idx = which(is.na(m_vec) | m_vec <= 0L)
  list(
    pair_ids = pair_ids,
    pair_weights = as.numeric(pair_weights),
    reservoir_idx = reservoir_idx,
    reservoir_weights = as.numeric(row_weights[reservoir_idx])
  )
}

weighted_cox_bootstrap_surrogate_fit = function(time, dead, X, row_weights, strata = NULL, cluster = NULL, warm_start_beta = NULL) {
  X = as.matrix(X)
  row_weights = as.numeric(row_weights)
  ok = is.finite(time) & is.finite(dead) & is.finite(row_weights) & row_weights > 0
  if (!is.null(strata)) ok = ok & !is.na(strata)
  if (!is.null(cluster)) ok = ok & !is.na(cluster)
  if (!any(ok)) return(NULL)
  X_fit = X[ok, , drop = FALSE]
  if (is.null(colnames(X_fit))) colnames(X_fit) = paste0("x", seq_len(ncol(X_fit)))
  if (!("treatment" %in% colnames(X_fit)) && ncol(X_fit) >= 1L) colnames(X_fit)[1L] = "treatment"
  dat = as.data.frame(X_fit, check.names = FALSE)
  dat$.time__ = as.numeric(time[ok])
  dat$.dead__ = as.numeric(dead[ok])
  dat$.wgt__ = as.numeric(row_weights[ok])
  rhs_terms = colnames(X_fit)
  if (!is.null(strata)) {
    dat$.strata__ = factor(as.integer(strata[ok]))
    rhs_terms = c(rhs_terms, "strata(.strata__)")
  }
  if (!is.null(cluster)) {
    dat$.cluster__ = factor(as.integer(cluster[ok]))
    rhs_terms = c(rhs_terms, "cluster(.cluster__)")
  }
  warm_start_beta = as.numeric(warm_start_beta)
  cox_init = if (length(warm_start_beta) == ncol(X_fit) && all(is.finite(warm_start_beta))) {
    warm_start_beta
  } else {
    NULL
  }
  fit_cox = function(init = NULL) {
    # survival::coxph() rejects an explicit init = NULL ("wrong length for
    # init argument") -- the argument must be omitted entirely to use its
    # default start, not passed as NULL.
    args = list(
      formula = stats::as.formula(paste0("survival::Surv(.time__, .dead__) ~ ", paste(rhs_terms, collapse = " + "))),
      data = dat,
      weights = dat$.wgt__
    )
    if (!is.null(init)) args$init = init
    tryCatch(
      suppressWarnings(do.call(survival::coxph, args)),
      error = function(e) NULL
    )
  }
  fit = tryCatch(
    fit_cox(cox_init),
    error = function(e) NULL
  )
  if (is.null(fit) && !is.null(cox_init)) {
    fit = fit_cox(NULL)
  }
  coef_vec = tryCatch(stats::coef(fit), error = function(e) NULL)
  beta_hat = if (!is.null(coef_vec) && ("treatment" %in% names(coef_vec))) as.numeric(coef_vec[["treatment"]]) else NA_real_
  if (!is.finite(beta_hat)) return(NULL)
  list(beta_hat = beta_hat, coefficients = coef_vec, fit = fit)
}

weighted_weibull_bootstrap_surrogate_fit = function(time, dead, X, row_weights, cluster = NULL, warm_start_params = NULL) {
  X = as.matrix(X)
  row_weights = as.numeric(row_weights)
  ok = is.finite(time) & is.finite(dead) & is.finite(row_weights) & row_weights > 0
  if (!is.null(cluster)) ok = ok & !is.na(cluster)
  if (!any(ok)) return(NULL)
  X_fit = X[ok, , drop = FALSE]
  if (is.null(colnames(X_fit))) colnames(X_fit) = paste0("x", seq_len(ncol(X_fit)))
  if (!("treatment" %in% colnames(X_fit)) && ncol(X_fit) >= 1L) colnames(X_fit)[1L] = "treatment"
  dat = as.data.frame(X_fit, check.names = FALSE)
  dat$.time__ = as.numeric(time[ok])
  dat$.dead__ = as.numeric(dead[ok])
  dat$.wgt__ = as.numeric(row_weights[ok])
  rhs_terms = colnames(X_fit)
  if (!is.null(cluster)) {
    dat$.cluster__ = factor(as.integer(cluster[ok]))
  }
  warm_start_params = as.numeric(warm_start_params)
  survreg_init = NULL
  if (length(warm_start_params) >= ncol(X_fit) + 1L && all(is.finite(warm_start_params))) {
    survreg_init = utils::head(warm_start_params, ncol(X_fit) + 1L)
    names(survreg_init) = c("(Intercept)", colnames(X_fit))
  }
  fit_survreg = function(init = NULL) {
    tryCatch(
      suppressWarnings(
        survival::survreg(
          stats::as.formula(paste0("survival::Surv(.time__, .dead__) ~ ", paste(rhs_terms, collapse = " + "))),
          data = dat,
          weights = .wgt__,
          dist = "weibull",
          init = init
        )
      ),
      error = function(e) NULL
    )
  }
  fit = fit_survreg(survreg_init)
  if (is.null(fit) && !is.null(survreg_init)) {
    fit = fit_survreg(NULL)
  }
  coef_vec = tryCatch(stats::coef(fit), error = function(e) NULL)
  beta_hat = if (!is.null(coef_vec) && ("treatment" %in% names(coef_vec))) as.numeric(coef_vec[["treatment"]]) else NA_real_
  if (!is.finite(beta_hat)) return(NULL)
  list(beta_hat = beta_hat, coefficients = coef_vec, fit = fit)
}

# Creates a fork cluster and caps OMP/BLAS threads on each worker to 1.
# Returns the cluster without storing it — callers decide where it lives.
make_configured_fork_cluster = function(n_cores) {
  if (isTRUE(edi_env$mirai_has_been_used)) {
    stop(
      "Cannot create a fork cluster after mirai-backed parallelism has been used in the same R session. ",
      "Restart R or keep using force_mirai = TRUE. This avoids the nng is not fork-reentrant safe panic.",
      call. = FALSE
    )
  }
  cl = tryCatch(
    parallel::makeForkCluster(n_cores),
    error = function(e) NULL
  )
  if (!is.null(cl)) {
    return(cl)
  }
  candidate_ports = unique(as.integer(sample.int(20000L, 20L) + 10000L))
  candidate_ports = candidate_ports[is.finite(candidate_ports) & candidate_ports > 0L & candidate_ports <= 65535L]
  last_error = NULL
  cl = NULL
  for (port in candidate_ports) {
    cl = tryCatch(
      parallel::makeForkCluster(n_cores, port = port),
      error = function(e) {
        last_error <<- e
        NULL
      }
    )
    if (!is.null(cl)) break
  }
  if (is.null(cl)) {
    cl = tryCatch(
      parallel::makeCluster(n_cores),
      error = function(e) {
        last_error <<- e
        NULL
      }
    )
  }
  if (is.null(cl)) {
    stop(
      "Could not create fork cluster after trying ",
      length(candidate_ports),
      " ports",
      if (!is.null(last_error)) paste0(": ", conditionMessage(last_error)) else ".",
      call. = FALSE
    )
  }
  tryCatch(
    parallel::clusterCall(cl, function() {
      Sys.setenv(
        OMP_NUM_THREADS        = 1L,
        MKL_NUM_THREADS        = 1L,
        OPENBLAS_NUM_THREADS   = 1L,
        GOTO_NUM_THREADS       = 1L,
        VECLIB_MAXIMUM_THREADS = 1L,
        NUMEXPR_NUM_THREADS    = 1L
      )
      options(mc.cores = 1L)
      if (requireNamespace("data.table", quietly = TRUE)) data.table::setDTthreads(1L)
      if (requireNamespace("fixest", quietly = TRUE)) suppressWarnings(try(fixest::setFixest_nthreads(1L), silent = TRUE))
      invisible(NULL)
    }),
    error = function(e) invisible(NULL)
  )
  cl
}
#' Set the number of cores for parallelization
#'
#' This function initializes a persistent parallel cluster (either a fork cluster
#' on Unix-like systems or a mirai cluster on others) to be used by all Design
#' and Inference objects. This avoids the overhead of creating clusters
#' repeatedly.
#'
#' @details
#' \code{set_num_cores()} sets a global upper bound for parallel work. It does
#' not guarantee that every inference routine will use all requested workers.
#' EDI's inference dispatcher applies a blocklist-first heuristic informed by
#' package benchmarks: workloads that have shown consistent multicore slowdowns
#' are forced to run serially, while the remaining workloads are allowed to use
#' their method-specific warmup heuristics and native thread caps.
#'
#' The default forced-serial blocklist covers incidence randomization confidence
#' intervals, bootstrap for non-regression KK Wilcoxon inference, bootstrap for
#' non-KK survival procedures, and bootstrap for incidence procedures. Do not
#' expect a universal "more cores is faster" rule.
#'
#' If you want to change the default policy, use
#' \code{set_parallel_dispatch_policy()}.
#' 
#' @param num_cores Integer number of worker processes to make available.
#' @param force_mirai If \code{TRUE}, forces the use of the \code{mirai} package
#'   even on systems where forking is available.
#' 
#' @return Invisible \code{NULL}.
#' 
#' @examples
#' set_num_cores(2)
#' unset_num_cores()
#' @export
set_num_cores = function(num_cores, force_mirai = FALSE) {
  checkmate::assertCount(num_cores, positive = TRUE)
  checkmate::assertFlag(force_mirai)
  
  # Clear any existing clusters first
  unset_num_cores()
  # Set package/native thread budgets before workers are created so forked
  # children inherit the intended global thread settings.
  set_package_threads(num_cores)
  if (as.integer(num_cores) <= 1L) {
    return(invisible(NULL))
  }
  
  if (force_mirai || .Platform$OS.type != "unix") {
    if (!check_package_installed("mirai")) {
      stop("The 'mirai' package is required for parallelization on this system or when force_mirai = TRUE. Please install it.")
    }
    edi_env$mirai_has_been_used = TRUE
    # Initialize mirai daemons
    mirai::daemons(num_cores)
    edi_env$global_mirai_num_cores = num_cores
    # Each daemon inherited OMP_NUM_THREADS=N from the parent; cap them at 1 so
    # N daemons don't each spawn N OMP threads.  Main-process Rcpp OMP functions
    # use omp_set_num_threads() explicitly and are unaffected by this reset.
    tryCatch(
      mirai::everywhere({
        Sys.setenv(
          OMP_NUM_THREADS        = 1L,
          MKL_NUM_THREADS        = 1L,
          OPENBLAS_NUM_THREADS   = 1L,
          GOTO_NUM_THREADS       = 1L,
          VECLIB_MAXIMUM_THREADS = 1L,
          NUMEXPR_NUM_THREADS    = 1L
        )
        options(mc.cores = 1L)
        if (requireNamespace("data.table", quietly = TRUE)) data.table::setDTthreads(1L)
        if (requireNamespace("fixest", quietly = TRUE)) suppressWarnings(try(fixest::setFixest_nthreads(1L), silent = TRUE))
      }),
      error = function(e) invisible(NULL)
    )
  } else {
    if (isTRUE(edi_env$mirai_has_been_used)) {
      stop(
        "Cannot switch from mirai-backed parallelism to fork-based parallelism in the same R session. ",
        "Restart R or keep using force_mirai = TRUE. This avoids the nng is not fork-reentrant safe panic."
      )
    }
    # Unix-like system, use forking
    cl = make_configured_fork_cluster(num_cores)
    edi_env$global_fork_cluster = cl
  }
  
  invisible(NULL)
}
#' Unset the number of cores and stop parallel clusters
#' 
#' This function stops any global fork or mirai clusters stored in the package
#' environment and resets the core count to serial execution.
#' @return Invisible \code{NULL}.
#' 
#' @examples
#' set_num_cores(2)
#' unset_num_cores()
#' @export
unset_num_cores = function() {
  # Handle fork cluster
  if (!is.null(edi_env$global_fork_cluster)) {
    cl = edi_env$global_fork_cluster
    edi_env$global_fork_cluster = NULL
    tryCatch(parallel::stopCluster(cl), error = function(e) invisible(NULL))
  }
  
  # Handle mirai cluster
  if (!is.null(edi_env$global_mirai_num_cores)) {
    if (check_package_installed("mirai")) {
      tryCatch(mirai::daemons(0), error = function(e) invisible(NULL)) # Stop daemons
    }
    edi_env$global_mirai_num_cores = NULL
  }
  
  # Reset package threads to 1
  set_package_threads(1L)
  
  invisible(NULL)
}
#' Get the default parallel dispatch policy
#'
#' Returns EDI's built-in \strong{blocklist-first} policy table, consulted by an
#' internal (non-exported) dispatcher, for deciding whether a given
#' \code{"bootstrap"} or \code{"rand_ci"} (randomization confidence interval)
#' operation is forced to run \strong{serially} rather than in parallel, for a
#' given inference class and response type. "Blocklist-first" means every
#' operation is parallel-eligible by default; only combinations explicitly
#' matched below are forced serial.
#'
#' @details For a given \code{operation} (\code{"bootstrap"} or
#'   \code{"rand_ci"}), the dispatcher looks up that operation's sub-list (e.g.
#'   \code{bootstrap}) and forces serial execution if either the inference class
#'   name matches any of \code{serial_inference_class_patterns} (regular
#'   expressions, PCRE-flavored — \code{serial_inference_class_patterns} supports
#'   lookahead, e.g. the built-in
#'   \verb{"^InferenceSurvival(?!.*KK)"} pattern matches non-KK survival inference
#'   classes but excludes matched-design (KK) survival variants) or the response
#'   type matches any of \code{serial_response_types} exactly. In the built-in
#'   policy, incidence-response inference generally runs serially for both
#'   operations (its bootstrap/randomization resampling is not currently
#'   parallel-safe or not worth parallelizing at typical trial sizes), and
#'   non-KK survival inference and \code{InferenceAllKKWilcoxIVWC} are
#'   additionally forced serial for bootstrapping specifically.
#'
#' @return A named list with two components, \code{bootstrap} and \code{rand_ci},
#'   each itself a list with \code{serial_inference_class_patterns} (a character
#'   vector of PCRE-flavored regular expressions matched against the inference
#'   class name) and \code{serial_response_types} (a character vector of exact
#'   response-type strings) — any match in either forces that operation to run
#'   serially rather than in parallel.
#' @seealso \code{\link{get_bootstrap_dispatch_policy}},
#'   \code{\link{get_cold_start_dispatch_policy}}, and
#'   \code{\link{get_optimization_dispatch_policy}} for the analogous policies
#'   controlling bootstrap CI type, cold-start behavior, and default optimizer
#'   algorithm (none of which control parallel-vs-serial dispatch).
#' @examples
#' get_parallel_dispatch_policy()
#' @export
get_parallel_dispatch_policy = function() {
  list(
    bootstrap = list(
      serial_inference_class_patterns = c(
        "^InferenceIncid",
        "^InferenceSurvival(?!.*KK)",
        "^InferenceAllKKWilcoxIVWC$"
      ),
      serial_response_types = c("incidence")
    ),
    rand_ci = list(
      serial_inference_class_patterns = c("^InferenceIncid"),
      serial_response_types = c("incidence")
    )
  )
}
edi_env$parallel_dispatch_policy_config = get_parallel_dispatch_policy()
#' Get the default bootstrap dispatch policy
#'
#' Returns EDI's built-in policy table, consulted by the internal (non-exported)
#' dispatcher \code{edi_bootstrap_dispatch_policy()}, for choosing which bootstrap
#' confidence-interval type — \code{"bca"} (bias-corrected and accelerated) or
#' \code{"percentile"} — an inference class uses by default.
#'
#' @details
#' The dispatcher resolves a type for a given inference-class name (and, if
#' available, the fitted inference object) in this precedence order, returning the
#' first match:
#' \enumerate{
#' \item If the object's experimental design class matches a key of
#'   \code{design_class_overrides} (via \code{\link[methods]{is}}), and the
#'   inference class name matches one of that design's named regular-expression
#'   patterns, use the associated type.
#' \item Otherwise, if the inference class name matches one of
#'   \code{inference_class_overrides}'s named regular-expression patterns (checked
#'   in list order, first match wins), use the associated type.
#' \item Otherwise, fall back to \code{default_type} (\code{"bca"}).
#' }
#' Whichever type is resolved by that process, a final safety check applies: if the
#' resolved type is \code{"bca"} and the fitted object reports (via its private
#' \code{jackknife_block_size_gt_one_unsupported()} method) that BCa's required
#' jackknife computation is unsupported for its current data (e.g. a block size
#' greater than 1), the type is silently downgraded to \code{"percentile"} instead.
#' This override table exists because BCa is the generally preferred default (it
#' corrects for both bias and skewness in the bootstrap distribution), but is
#' empirically unreliable or computationally unsupported for specific inference/
#' design class combinations — the \code{"percentile"} overrides listed here were
#' added as those cases were identified, not derived from a general rule.
#'
#' @return A named list describing the default bootstrap type configuration, with
#'   components \code{default_type} (the fallback type, \code{"bca"}),
#'   \code{inference_class_overrides} (a named character vector: regular-expression
#'   pattern names to bootstrap-type values, matched against the inference class
#'   name), and \code{design_class_overrides} (a named list keyed by experimental
#'   design class name, each value itself a named character vector of
#'   pattern-to-type overrides scoped to that design).
#' @seealso \code{\link{get_parallel_dispatch_policy}} for the analogous policy
#'   controlling forced-serial dispatch; \code{\link{get_optimization_dispatch_policy}}
#'   for the analogous policy controlling default optimizer algorithm choice.
#' @examples
#' get_bootstrap_dispatch_policy()
#' @export
get_bootstrap_dispatch_policy = function() {
  list(
    default_type = "bca",
    inference_class_overrides = c(
      "^InferenceContinLin$" = "percentile",
      "^InferenceIncidGCompRisk(Diff|Ratio)$" = "percentile",
      "^InferenceIncidKKGCompRisk(Diff|Ratio)$" = "percentile",
      "^InferenceIncidBinomialIdentityRiskDiff$" = "percentile",
      "^InferencePropGCompMeanDiff$" = "percentile",
      "^InferenceSurvivalDepCensTransformRegr$" = "percentile",
      "^InferenceSurvivalKKRankRegrIVWC$" = "percentile",
      "^InferenceOrdinalAdjCatLogitRegr$" = "percentile",
      "^InferenceAllSimpleWilcox$" = "percentile",
      "^InferenceSurvivalKKStratCoxPHOneLik$" = "percentile",
	      "^InferenceCountPoisson$" = "percentile",
	      "^InferenceCountRobustPoisson$" = "percentile",
	      "^InferenceCountQuasiPoisson$" = "percentile",
	      "^InferenceCountNegBin$" = "percentile",
	      "^InferenceCountZeroInflatedPoisson$" = "percentile",
	      "^InferenceCountZeroInflatedNegBin$" = "percentile",
	      "^InferenceCountHurdlePoisson$" = "percentile",
	      "^InferenceCountKKHurdlePoissonOneLik$" = "percentile",
	      "^InferenceCountKKCondPoissonOneLik$" = "percentile",
	      "^InferencePropZeroOneInflatedBetaRegr$" = "percentile",
      "^InferencePropFractionalLogit$" = "percentile",
	      "^InferenceCountHurdleNegBin$" = "percentile",
      "^InferenceContinRobustRegr$" = "percentile",
      "^InferenceCustom(Asymp|Rand|Boot)$" = "percentile"
    ),
    design_class_overrides = list(
      DesignFixedBlockedCluster = c(
        "^InferenceContinRobustRegr$" = "percentile",
        "^InferenceContinLin$" = "percentile",
        "^InferenceContinOLS$" = "percentile",
        "^InferenceContinKKOLSIVWC$" = "percentile",
        "^InferenceContinKKOLSOneLik$" = "percentile"
      )
    )
  )
}
edi_env$bootstrap_dispatch_policy_config = get_bootstrap_dispatch_policy()
#' Get the default optimization dispatch policy
#'
#' Returns EDI's built-in policy table, consulted by the internal (non-exported)
#' dispatcher \code{edi_optimization_dispatch_policy()}, for choosing which
#' optimization algorithm (\code{"newton_raphson"}, \code{"lbfgs"}, or
#' \code{"irls"}) an inference class's C++ model-fitting backend uses by default.
#'
#' @details The dispatcher checks the inference class name against
#'   \code{inference_class_overrides}'s named regular-expression patterns in list
#'   order, returning the associated algorithm string at the first match; if none
#'   match, it falls back to \code{default_alg} (\code{"newton_raphson"}). Unlike
#'   \code{\link{get_bootstrap_dispatch_policy}}, there is no separate
#'   design-class-scoped override table here — only a single flat pattern list.
#'   The built-in overrides are empirical, chosen per model family based on which
#'   algorithm converges fastest/most reliably for that likelihood surface in
#'   practice — e.g. plain-vanilla generalized linear models with a canonical or
#'   near-canonical link (Poisson, quasi-Poisson, robust Poisson, various incidence
#'   models) default to \code{"irls"}, most non-canonical-link and ordinal/survival
#'   models default to \code{"lbfgs"}, and stratified Cox PH and most matched
#'   (\code{KK*GLMM}-adjacent) models default to \code{"newton_raphson"}.
#' @return A named list with components \code{default_alg} (the fallback
#'   algorithm, \code{"newton_raphson"} in the built-in policy) and
#'   \code{inference_class_overrides} (a named character vector: regular-expression
#'   pattern names to algorithm-name values, matched against the inference class
#'   name).
#' @seealso \code{\link{get_bootstrap_dispatch_policy}} and
#'   \code{\link{get_cold_start_dispatch_policy}} for the analogous policies
#'   controlling bootstrap CI type and cold-start behavior;
#'   \code{\link{.normalize_optimizer_algorithm}} for how a resolved algorithm
#'   string is validated/normalized before being passed to a C++ backend.
#' @examples
#' get_optimization_dispatch_policy()
#' @export
get_optimization_dispatch_policy = function() {
  list(
    default_alg = "newton_raphson",
    inference_class_overrides = c(
      "^InferenceCountKKGLMM$"  = "newton_raphson",
      "KKGLMM$"                 = "lbfgs",
      "KKWeibullFrailtyIVWC$"   = "lbfgs",
      "KKWeibullFrailtyOneLik$" = "lbfgs",
      "KKHurdlePoissonIVWC$"    = "lbfgs",
      "KKHurdlePoissonOneLik$"  = "lbfgs",
      "KKCondPoissonOneLik$"       = "lbfgs",
      "InferenceCountPoisson$"  = "irls",
      "InferenceCountQuasiPoisson$" = "irls",
      "InferenceCountRobustPoisson$" = "irls",
      "InferenceCountNegBin$" = "lbfgs",
      "InferenceIncidModifiedPoisson$" = "irls",
      "InferenceIncidLogRegr$" = "irls",
      "InferenceIncidProbitRegr$" = "irls",
      "InferencePropFractionalLogit$" = "irls",
      "InferencePropGCompMeanDiff$" = "irls",
      "InferencePropBetaRegr$" = "lbfgs",
      "InferenceOrdinalAdjCatLogitRegr$" = "lbfgs",
      "InferenceOrdinalContRatioRegr$" = "lbfgs",
      "InferenceOrdinalPropOddsRegr$" = "lbfgs",
      "InferenceOrdinalOrderedProbitRegr$" = "lbfgs",
      "InferenceOrdinalCauchitRegr$" = "lbfgs",
      "InferenceOrdinalCloglogRegr$" = "lbfgs",
      "InferenceSurvivalWeibullRegr$" = "lbfgs",
      "InferenceSurvivalStratCoxPHRegr$" = "newton_raphson",
      "InferenceSurvivalKKClaytonCopulaOneLik$" = "lbfgs",
      "InferenceIncidKKCondLogitGLMMOneLik$"   = "lbfgs"
    )
  )
}
edi_env$optimization_dispatch_policy_config = get_optimization_dispatch_policy()
#' Get the default cold-start dispatch policy
#'
#' Returns EDI's built-in policy table, consulted by the internal (non-exported)
#' dispatcher \code{edi_cold_start_dispatch_policy()}, for the \code{smart_cold_start}
#' default used by each inference class's C++ model-fitting backend. A \code{TRUE}
#' entry means the solver initializes via an OLS (or otherwise model-appropriate
#' heuristic) warm-up before iterating; \code{FALSE} means a plain zero-vector cold
#' start. Benchmarks show the OLS warm-up is net-negative for logistic and Poisson
#' IRLS at typical trial sizes (the one extra OLS solve costs more than the IRLS
#' iterations it saves), so those families — along with several G-computation-based
#' incidence/proportion inference classes — default to \code{FALSE} here.
#'
#' @details The dispatcher checks the inference class name against
#'   \code{inference_class_overrides}'s named regular-expression patterns in list
#'   order, returning the associated logical value at the first match; if none
#'   match, it falls back to \code{default} (\code{TRUE}). Unlike
#'   \code{\link{get_bootstrap_dispatch_policy}}, there is no separate
#'   design-class-scoped override table here — only a single flat pattern list.
#'
#' @return A named list with \code{default} (logical, the fallback when no
#'   override pattern matches; \code{TRUE} in the built-in policy) and
#'   \code{inference_class_overrides} (a named logical vector: regular-expression
#'   pattern names to \code{TRUE}/\code{FALSE} values, matched against the
#'   inference class name).
#' These \code{TRUE}/\code{FALSE} defaults are empirical performance
#' judgments computed on the maintainer's machine, not correctness facts —
#' the same heuristic can be net-positive or net-negative depending on
#' your hardware's core count, cache sizes, and BLAS backend. Run
#' \code{\link{tune_EDI_for_this_machine}} to re-measure this axis on your
#' own machine and persist any better setting it finds.
#'
#' @seealso \code{\link{get_bootstrap_dispatch_policy}} and
#'   \code{\link{get_optimization_dispatch_policy}} for the analogous policies
#'   controlling bootstrap CI type and default optimizer algorithm;
#'   \code{\link{set_cold_start_dispatch_policy}} to override this policy at
#'   runtime; \code{\link{tune_EDI_for_this_machine}} to re-benchmark it on
#'   your own hardware.
#' @examples
#' get_cold_start_dispatch_policy()
#' @export
get_cold_start_dispatch_policy = function() {
  list(
    default = TRUE,
    inference_class_overrides = c(
      "^InferenceIncidLogRegr$"          = FALSE,
      "^InferencePropFractionalLogit$"   = FALSE,
      "^InferencePropGComp"              = FALSE,
      "^InferenceIncidGComp"             = FALSE,
      "^InferenceIncidKKGComp"           = FALSE,
      "^InferenceCountPoisson$"          = FALSE,
      "^InferenceCountQuasiPoisson$"     = FALSE,
      "^InferenceCountRobustPoisson$"    = FALSE,
      "^InferenceIncidModifiedPoisson$"  = FALSE
    )
  )
}
edi_env$cold_start_dispatch_policy_config = get_cold_start_dispatch_policy()
#' Update the cold-start dispatch policy
#'
#' Overrides, queries, or resets the runtime policy consulted by
#' \code{edi_cold_start_dispatch_policy()} for whether an inference class's C++
#' fitting backend defaults to an OLS-based \code{smart_cold_start} or a plain
#' zero-vector start; see \code{\link{get_cold_start_dispatch_policy}} for the
#' built-in default table and the rationale behind it.
#'
#' @details Call with no arguments (\code{policy = NULL}, \code{reset = FALSE})
#'   to retrieve the current configuration without changing it. Pass a named
#'   list to \code{policy} to merge new/overriding entries into the current
#'   configuration via \code{\link[utils]{modifyList}} (so \code{default} and/or
#'   \code{inference_class_overrides} can each be supplied independently, and
#'   entries not mentioned are left untouched — this cannot \emph{remove} an
#'   existing override pattern, only add or replace one). Pass \code{reset =
#'   TRUE} to discard any accumulated overrides and restore the package's
#'   built-in default policy exactly as returned by
#'   \code{\link{get_cold_start_dispatch_policy}}.
#'
#' @param policy Either \code{NULL} (no change) or a named list of policy
#'   overrides merged into the current configuration (see Details).
#' @param reset If \code{TRUE}, discard all overrides and restore the built-in
#'   default policy.
#' @return Invisible \code{NULL} when \code{policy} is supplied (a mutation), or
#'   invisibly the current policy configuration list when called for its
#'   side-effect-free query/reset value.
#' @seealso \code{\link{get_cold_start_dispatch_policy}} for the policy schema
#'   and built-in defaults; \code{\link{set_warm_start_dispatch_policy}} and
#'   \code{\link{set_optimization_dispatch_policy}} for the analogous setters
#'   governing warm-starting and optimizer-algorithm choice;
#'   \code{\link{tune_EDI_for_this_machine}}, which calls this setter with
#'   machine-measured overrides rather than hand-picked ones.
#' @examples
#' set_cold_start_dispatch_policy(reset = TRUE)
#' @export
set_cold_start_dispatch_policy = function(policy = NULL, reset = FALSE) {
  checkmate::assertFlag(reset)
  if (isTRUE(reset)) {
    edi_env$cold_start_dispatch_policy_config = get_cold_start_dispatch_policy()
    return(invisible(edi_env$cold_start_dispatch_policy_config))
  }
  if (is.null(policy)) {
    return(invisible(edi_env$cold_start_dispatch_policy_config))
  }
  checkmate::assertList(policy, names = "named")
  edi_env$cold_start_dispatch_policy_config = utils::modifyList(edi_env$cold_start_dispatch_policy_config, policy)
  invisible(NULL)
}
edi_cold_start_dispatch_policy = function(inference_class) {
  config = edi_env$cold_start_dispatch_policy_config
  inference_class = as.character(inference_class[[1]])
  overrides = config$inference_class_overrides
  default_val = if (isTRUE(config$default)) TRUE else FALSE
  if (!is.null(overrides) && length(overrides) > 0L) {
    for (pattern in names(overrides)) {
      if (is.na(pattern) || pattern == "") next
      if (grepl(pattern, inference_class, perl = TRUE)) {
        return(isTRUE(overrides[[pattern]]))
      }
    }
  }
  default_val
}
#' Get the default warm-start dispatch policy
#'
#' Returns EDI's built-in policy table for choosing whether \strong{warm starts}
#' (reusing a previous fit's parameters/curvature to seed the next fit, e.g.
#' across bootstrap or randomization replicates) are enabled for a given
#' inference class during a given resampling or simulation \code{operation}
#' (one of \code{"jackknife"}, \code{"non_param_boot"}, \code{"bayesian_boot"},
#' \code{"param_boot"}, or \code{"rand"}).
#'
#' @details The internal (non-exported) dispatcher,
#'   \code{edi_warm_start_dispatch_policy(inference_class, operation, n)},
#'   consults this table's \code{default} plus, per operation, two override
#'   layers: \code{inference_class_overrides} (a sample-size-independent
#'   pattern table, as before) and \code{n_conditioned_overrides} (a list of
#'   \code{list(pattern, value, n_min, n_max)} rules — each pattern only
#'   applies when the current sample size \code{n} falls in
#'   \code{[n_min, n_max)} — encoding empirical findings like "the extra
#'   bookkeeping only pays off once resampling is expensive enough per
#'   replicate, so disable below n=200/500/1000 for these families"). Both
#'   layers are returned by this function and are both reachable via
#'   \code{\link{set_warm_start_dispatch_policy}}.
#'
#' @return A named list with \code{default} (logical, \code{TRUE} in the
#'   built-in policy) and one component per operation (\code{jackknife},
#'   \code{non_param_boot}, \code{bayesian_boot}, \code{param_boot},
#'   \code{rand}), each itself a list containing \code{inference_class_overrides}
#'   (a named logical vector: regular-expression pattern names to
#'   \code{TRUE}/\code{FALSE} values, matched against the inference class name,
#'   applied regardless of sample size) and \code{n_conditioned_overrides} (a
#'   list of \code{list(pattern, value, n_min, n_max)} rules, applied only when
#'   \code{n} is supplied and falls in \code{[n_min, n_max)}); see Details.
#' Like the cold-start table, every \code{TRUE}/\code{FALSE} entry here
#' (including the n-thresholds) is an empirical performance judgment
#' computed on the maintainer's machine, not a correctness fact. Run
#' \code{\link{tune_EDI_for_this_machine}} to re-measure this axis,
#' per resampling operation and sample size, on your own machine.
#'
#' @seealso \code{\link{get_cold_start_dispatch_policy}} for the analogous
#'   (simpler, single-layer) policy governing the initial cold-start heuristic
#'   rather than cross-replicate warm-starting; \code{\link{set_warm_start_dispatch_policy}}
#'   to override this table at runtime; \code{\link{tune_EDI_for_this_machine}}
#'   to re-benchmark it on your own hardware.
#' @examples
#' get_warm_start_dispatch_policy()
#' @export
get_warm_start_dispatch_policy = function() {
  wn = function(pattern, value = FALSE, n_min = -Inf, n_max = Inf) {
    list(pattern = pattern, value = value, n_min = n_min, n_max = n_max)
  }
  list(
    default = TRUE,
    jackknife = list(
      inference_class_overrides = c(
        "^InferenceSurvivalKKLWACoxPHIVWC$" = FALSE,
        "^InferenceSurvivalCoxPHRegr$" = FALSE,
        "^InferenceSurvivalStratCoxPHRegr$" = FALSE,
        "^InferenceOrdinalContRatioRegr$" = FALSE,
        "^InferenceOrdinalAdjCatLogitRegr$" = FALSE,
        "^InferenceSurvivalRestrictedMeanDiff$" = FALSE
      ),
      n_conditioned_overrides = list(
        wn("^InferenceSurvivalGehanWilcox$", n_max = 200L),
        wn("^InferenceSurvivalLogRank$", n_max = 500L),
        wn("^InferenceContinKKGLMM$", n_max = 500L),
        wn("^InferenceOrdinalCauchitRegr$", n_max = 500L),
        wn("^InferencePropBetaRegr$", n_max = 500L),
        wn("^InferenceIncidKKCondLogitGLMMIVWC$", n_min = 200L, n_max = 500L),
        wn("^InferenceCountNegBin$", n_max = 1000L),
        wn("^InferenceContinQuantileRegr$", n_min = 500L),
        wn("^InferenceOrdinalGCompMeanDiff$", n_min = 500L),
        wn("^InferenceSurvivalKKClaytonCopulaIVWC$", n_min = 1000L),
        wn("^InferenceOrdinalOrderedProbitRegr$", n_min = 1000L),
        wn("^InferenceSurvivalDepCensTransformRegr$", n_min = 1000L),
        wn("^InferenceSurvivalGehanWilcox$", n_min = 1000L),
        wn("^InferenceSurvivalWeibullRegr$", n_min = 1000L)
      )
    ),
    non_param_boot = list(
      inference_class_overrides = c(
        "^InferenceCountNegBin$" = FALSE,
        "^InferenceSurvivalCoxPHRegr$" = FALSE,
        "^InferenceSurvivalStratCoxPHRegr$" = FALSE,
        "^InferencePropZeroOneInflatedBetaRegr$" = FALSE
      ),
      n_conditioned_overrides = list(
        wn("^InferenceOrdinalContRatioRegr$", n_max = 200L),
        wn("^InferenceOrdinalKKCLMMCauchit$", n_max = 200L),
        wn("^InferencePropKKGEE$", n_max = 200L),
        wn("^InferenceOrdinalKKCondAdjCatLogitRegr$", n_max = 200L),
        wn("^InferenceCountQuasiPoisson$", n_max = 200L),
        wn("^InferencePropKKQuantileRegrOneLik$", n_max = 200L),
        wn("^InferenceCountHurdlePoisson$", n_max = 200L),
        wn("^InferenceCountZeroInflatedPoisson$", n_max = 200L),
        wn("^InferenceIncidBinomialIdentityRiskDiff$", n_max = 200L),
        wn("^InferenceIncidGCompRiskRatio$", n_max = 200L),
        wn("^InferenceIncidKKGEE$", n_max = 200L),
        wn("^InferencePropBetaRegr$", n_max = 200L),
        wn("^InferenceCountZeroInflatedNegBin$", n_max = 500L),
        wn("^InferenceIncidLogBinomial$", n_max = 500L),
        wn("^InferenceAllSimpleWilcox$", n_max = 500L),
        wn("^InferenceContinKKGLMM$", n_max = 500L),
        wn("^InferenceCountPoisson$", n_max = 500L),
        wn("^InferenceOrdinalContRatioRegr$", n_max = 500L),
        wn("^InferenceSurvivalDepCensTransformRegr$", n_max = 500L),
        wn("^InferenceCountHurdleNegBin$", n_max = 1000L),
        wn("^InferenceAllKKWilcoxIVWC$", n_min = 500L),
        wn("^InferenceOrdinalCloglogRegr$", n_min = 500L),
        wn("^InferenceOrdinalKKGLMM$", n_min = 500L),
        wn("^InferencePropFractionalLogit$", n_min = 500L),
        wn("^InferencePropKKQuantileRegrIVWC$", n_min = 500L),
        wn("^InferenceSurvivalKMDiff$", n_min = 500L),
        wn("^InferenceIncidKKCondLogitGLMMOneLik$", n_min = 1000L),
        wn("^InferenceIncidKKGCompRiskDiff$", n_min = 1000L),
        wn("^InferenceIncidRiskDiff$", n_min = 1000L),
        wn("^InferenceOrdinalKKCLMM$", n_min = 1000L),
        wn("^InferenceSurvivalRestrictedMeanDiff$", n_min = 1000L)
      )
    ),
    bayesian_boot = list(
      inference_class_overrides = c(
        "^InferenceCountNegBin$" = FALSE,
        "^InferenceSurvivalCoxPHRegr$" = FALSE,
        "^InferenceSurvivalStratCoxPHRegr$" = FALSE,
        "^InferenceContinKKGLMM$" = FALSE,
        "^InferenceSurvivalDepCensTransformRegr$" = FALSE,
        "^InferenceOrdinalCloglogRegr$" = FALSE,
        "^InferenceCountPoisson$" = FALSE,
        "^InferenceOrdinalPropOddsRegr$" = FALSE,
        "^InferenceIncidKKNewcombeRiskDiff$" = FALSE,
        "^InferenceOrdinalJonckheereTerpstraTest$" = FALSE,
        "^InferenceOrdinalKKCLMMProbit$" = FALSE,
        "^InferencePropFractionalLogit$" = FALSE,
        "^InferencePropGCompMeanDiff$" = FALSE,
        "^InferenceSurvivalWeibullRegr$" = FALSE,
        "^InferenceIncidBinomialIdentityRiskDiff$" = FALSE
      ),
      n_conditioned_overrides = list(
        wn("^InferenceContinQuantileRegr$", n_max = 200L),
        wn("^InferenceOrdinalKKCondAdjCatLogitRegr$", n_max = 500L),
        wn("^InferenceSurvivalGehanWilcox$", n_max = 500L),
        wn("^InferenceCountKKGLMM$", n_max = 500L),
        wn("^InferenceCountHurdleNegBin$", n_max = 500L),
        wn("^InferenceOrdinalContRatioRegr$", n_max = 500L),
        wn("^InferenceSurvivalKKStratCoxPHOneLik$", n_max = 500L),
        wn("^InferenceOrdinalKKCLMMCauchit$", n_max = 1000L),
        wn("^InferenceSurvivalKKClaytonCopulaOneLik$", n_min = 500L),
        wn("^InferenceIncidKKCondLogitGLMMOneLik$", n_min = 500L),
        wn("^InferenceIncidModifiedPoisson$", n_min = 500L),
        wn("^InferenceOrdinalKKCLMM$", n_min = 500L),
        wn("^InferencePropZeroOneInflatedBetaRegr$", n_min = 500L),
        wn("^InferenceIncidGCompRiskRatio$", n_min = 1000L),
        wn("^InferenceContinQuantileRegr$", n_min = 1000L),
        wn("^InferenceIncidRiskDiff$", n_min = 1000L),
        wn("^InferenceCountQuasiPoisson$", n_min = 1000L),
        wn("^InferenceIncidKKGCompRiskRatio$", n_min = 1000L),
        wn("^InferenceCountKKCondPoissonOneLik$", n_min = 1000L),
        wn("^InferenceCountKKGLMM$", n_min = 1000L),
        wn("^InferenceCountKKHurdlePoissonOneLik$", n_min = 1000L),
        wn("^InferenceIncidExactBinomial$", n_min = 1000L),
        wn("^InferenceIncidProbitRegr$", n_min = 1000L),
        wn("^InferenceIncidExactZhang$", n_min = 1000L),
        wn("^InferenceOrdinalKKGLMM$", n_min = 1000L),
        wn("^InferenceOrdinalOrderedProbitRegr$", n_min = 1000L)
      )
    ),
    param_boot = list(
      inference_class_overrides = character(0),
      n_conditioned_overrides = list()
    ),
    rand = list(
      inference_class_overrides = c(
        "^InferenceIncidKKCondLogitOneLik$" = FALSE,
        "^InferenceAllSimpleWilcox$" = FALSE,
        "^InferenceSurvivalKKLWACoxPHIVWC$" = FALSE
      ),
      n_conditioned_overrides = list(
        wn("^InferencePropBetaRegr$", n_max = 200L),
        wn("^InferenceOrdinalKKCondAdjCatLogitRegr$", n_max = 200L),
        wn("^InferenceSurvivalKKClaytonCopulaOneLik$", n_max = 200L),
        wn("^InferenceSurvivalKKStratCoxPHOneLik$", n_max = 200L),
        wn("^InferenceSurvivalKKWeibullFrailtyIVWC$", n_max = 200L),
        wn("^InferenceContinKKOLSIVWC$", n_max = 500L),
        wn("^InferenceContinKKRobustRegrIVWC$", n_max = 500L),
        wn("^InferencePropKKQuantileRegrIVWC$", n_max = 500L),
        wn("^InferenceOrdinalContRatioRegr$", n_max = 500L),
        wn("^InferenceSurvivalCoxPHRegr$", n_max = 500L),
        wn("^InferenceIncidKKGEE$", n_max = 500L),
        wn("^InferenceIncidLogBinomial$", n_max = 500L),
        wn("^InferenceContinKKQuantileRegrOneLik$", n_min = 200L, n_max = 500L),
        wn("^InferenceContinKKGLMM$", n_max = 1000L),
        wn("^InferenceContinQuantileRegr$", n_max = 1000L),
        wn("^InferenceIncidKKModifiedPoisson$", n_max = 1000L),
        wn("^InferencePropGCompMeanDiff$", n_max = 1000L),
        wn("^InferenceCountKKHurdlePoissonOneLik$", n_min = 200L),
        wn("^InferenceContinRobustRegr$", n_min = 500L),
        wn("^InferenceIncidBinomialIdentityRiskDiff$", n_min = 500L),
        wn("^InferenceIncidKKCondLogitGLMMOneLik$", n_min = 500L),
        wn("^InferenceIncidKKCondLogitGLMMIVWC$", n_min = 500L),
        wn("^InferenceIncidGCompRiskRatio$", n_min = 500L),
        wn("^InferenceOrdinalKKCLMM$", n_min = 500L),
        wn("^InferenceCountPoisson$", n_min = 1000L)
      )
    )
  )
}
edi_env$warm_start_dispatch_policy_config = get_warm_start_dispatch_policy()

#' Update the warm-start dispatch policy
#'
#' Overrides, queries, or resets the runtime policy consulted by
#' \code{edi_warm_start_dispatch_policy()} for whether an inference class
#' reuses a previous fit's parameters/curvature to seed the next fit during
#' resampling; see \code{\link{get_warm_start_dispatch_policy}} for the
#' built-in default table and its \code{jackknife}/\code{non_param_boot}/
#' \code{bayesian_boot}/\code{param_boot}/\code{rand} operation schema
#' (each with an \code{inference_class_overrides} layer and an
#' \code{n_conditioned_overrides} layer).
#'
#' @details Call with no arguments (\code{policy = NULL}, \code{reset = FALSE})
#'   to retrieve the current configuration without changing it. Pass a named
#'   list to \code{policy} to merge new/overriding entries into the current
#'   configuration via \code{\link[utils]{modifyList}} (per-operation
#'   sub-lists, e.g. \code{list(rand = list(inference_class_overrides = ...))}
#'   or \code{list(rand = list(n_conditioned_overrides = ...))}, are merged
#'   rather than replaced wholesale — note \code{n_conditioned_overrides} is a
#'   plain list of rules, so overriding it replaces the whole list for that
#'   operation, not a per-rule merge). Pass \code{reset = TRUE} to discard any
#'   accumulated overrides and restore the package's built-in default policy
#'   exactly as returned by \code{\link{get_warm_start_dispatch_policy}}.
#'   \strong{This function controls the full dispatch policy}, including the
#'   sample-size-conditioned \code{n_conditioned_overrides} layer.
#'
#' @param policy Either \code{NULL} (no change) or a named list of per-operation
#'   policy overrides merged into the current configuration (see Details).
#' @param reset If \code{TRUE}, discard all overrides and restore the built-in
#'   default policy.
#' @return Invisible \code{NULL} when \code{policy} is supplied (a mutation), or
#'   invisibly the current policy configuration list when called for its
#'   side-effect-free query/reset value.
#' @seealso \code{\link{get_warm_start_dispatch_policy}} for the policy schema
#'   and built-in defaults; \code{\link{set_cold_start_dispatch_policy}} for
#'   the analogous, simpler single-layer setter governing the initial
#'   cold-start heuristic.
#' @examples
#' set_warm_start_dispatch_policy(reset = TRUE)
#' @export
set_warm_start_dispatch_policy = function(policy = NULL, reset = FALSE) {
  checkmate::assertFlag(reset)
  if (isTRUE(reset)) {
    edi_env$warm_start_dispatch_policy_config = get_warm_start_dispatch_policy()
    return(invisible(edi_env$warm_start_dispatch_policy_config))
  }
  if (is.null(policy)) {
    return(invisible(edi_env$warm_start_dispatch_policy_config))
  }
  checkmate::assertList(policy, names = "named")
  current = edi_env$warm_start_dispatch_policy_config
  for (op in names(policy)) {
    op_policy = policy[[op]]
    if (!is.list(op_policy)) {
      current[[op]] = op_policy
      next
    }
    # n_conditioned_overrides is a plain (unnamed) list of rules -- modifyList()'s
    # recursive merge is a silent no-op on unnamed lists, so replace it wholesale
    # here rather than routing it through modifyList() below.
    n_replacement = op_policy$n_conditioned_overrides
    op_policy$n_conditioned_overrides = NULL
    current[[op]] = utils::modifyList(current[[op]] %||% list(), op_policy)
    if (!is.null(n_replacement)) {
      current[[op]]$n_conditioned_overrides = n_replacement
    }
  }
  edi_env$warm_start_dispatch_policy_config = current
  invisible(NULL)
}

edi_warm_start_dispatch_policy = function(inference_class, operation, n = NULL) {
  config = edi_env$warm_start_dispatch_policy_config
  inference_class = as.character(inference_class[[1]])
  operation = as.character(operation[[1]])
  n_val = suppressWarnings(as.integer(n))

  default_val = if (isTRUE(config$default)) TRUE else FALSE

  op_cfg = config[[operation]]
  if (!is.list(op_cfg)) return(default_val)

  overrides = op_cfg$inference_class_overrides
  if (!is.null(overrides) && length(overrides) > 0L) {
    for (pattern in names(overrides)) {
      if (is.na(pattern) || pattern == "") next
      if (grepl(pattern, inference_class, perl = TRUE)) {
        return(isTRUE(overrides[[pattern]]))
      }
    }
  }

  n_overrides = op_cfg$n_conditioned_overrides
  if (!is.na(n_val) && !is.null(n_overrides) && length(n_overrides) > 0L) {
    for (rule in n_overrides) {
      if (n_val >= rule$n_min && n_val < rule$n_max &&
          grepl(rule$pattern, inference_class, perl = TRUE)) {
        return(isTRUE(rule$value))
      }
    }
  }

  default_val
}
#' Update the parallel dispatch policy
#'
#' EDI uses an empirical, blocklist-first dispatch policy to decide when an
#' inference routine's \code{"bootstrap"} or \code{"rand_ci"} resampling should
#' be forced serial even if multiple cores are available (see
#' \code{\link{get_parallel_dispatch_policy}} for the built-in table and the
#' PCRE pattern/response-type matching rules it encodes). This function lets
#' the user update that policy at runtime without editing package internals.
#'
#' @details
#' The policy can be updated in two mutually exclusive ways:
#' \itemize{
#'   \item Pass a named list to \code{policy} to merge with the current policy
#'   configuration via \code{\link[utils]{modifyList}}, one section at a time.
#'   Supported top-level keys are \code{bootstrap} and \code{rand_ci}, and each
#'   key's value is itself a list that may contain
#'   \code{serial_inference_class_patterns} (character vector of PCRE regular
#'   expressions) and/or \code{serial_response_types} (character vector of
#'   exact response-type strings); an unrecognized top-level key raises an
#'   error rather than being silently ignored.
#'   \item Pass a custom function with signature
#'   \code{function(inference_class, response_type, operation)} to \code{policy}
#'   to \strong{replace} the entire pattern-table dispatch logic with your own
#'   rule; it must return a list with at least \code{force_serial} (logical)
#'   and \code{reason} (character). Supplying a function clears any
#'   list-based overrides accumulated so far and is stored separately from the
#'   pattern-table configuration.
#' }
#' Use \code{reset = TRUE} to discard both the list-based overrides and any
#' custom function, restoring the package's built-in default policy exactly as
#' returned by \code{\link{get_parallel_dispatch_policy}}. Do not expect a
#' universal "more cores is faster" rule — this policy exists because several
#' resampling workloads have shown consistent multicore \emph{slowdowns} in
#' package benchmarks.
#'
#' @param policy Either \code{NULL} (no change), a named list of policy-section
#'   overrides, or a custom dispatch function (see Details).
#' @param reset If \code{TRUE}, restore the built-in default policy and remove
#'   any custom function override.
#' @return Invisible \code{NULL} when \code{policy} is supplied (a mutation), or
#'   invisibly the current policy configuration list when called for its
#'   side-effect-free query/reset value.
#' @seealso \code{\link{get_parallel_dispatch_policy}} for the policy schema and
#'   built-in defaults; \code{\link{set_num_cores}} for setting the actual
#'   worker-count upper bound this policy operates within.
#' @examples
#' set_parallel_dispatch_policy(reset = TRUE)
#'
#' @export
set_parallel_dispatch_policy = function(policy = NULL, reset = FALSE) {
  checkmate::assertFlag(reset)
  if (isTRUE(reset)) {
    edi_env$parallel_dispatch_policy_config = get_parallel_dispatch_policy()
    edi_env$parallel_dispatch_policy_override = NULL
    return(invisible(edi_env$parallel_dispatch_policy_config))
  }
  if (is.null(policy)) {
    return(invisible(edi_env$parallel_dispatch_policy_config))
  }
  if (is.function(policy)) {
    edi_env$parallel_dispatch_policy_override = policy
    return(invisible(NULL))
  }
  checkmate::assertList(policy, names = "named")
  current_config = edi_env$parallel_dispatch_policy_config
  for (nm in names(policy)) {
    if (!nm %in% names(current_config)) {
      stop("Unknown policy section: ", nm, call. = FALSE)
    }
    if (!is.list(policy[[nm]])) {
      stop("Policy section '", nm, "' must be a list.", call. = FALSE)
    }
    current_config[[nm]] = utils::modifyList(current_config[[nm]], policy[[nm]])
  }
  edi_env$parallel_dispatch_policy_config = current_config
  edi_env$parallel_dispatch_policy_override = NULL
  invisible(NULL)
}
#' Update the optimization dispatch policy
#'
#' Overrides, queries, or resets the runtime policy consulted by
#' \code{edi_optimization_dispatch_policy()} for which optimization algorithm
#' (\code{"newton_raphson"}, \code{"lbfgs"}, or \code{"irls"}) an inference
#' class's C++ model-fitting backend uses by default; see
#' \code{\link{get_optimization_dispatch_policy}} for the built-in default
#' table and the empirical rationale behind its per-family choices.
#'
#' @details Call with no arguments (\code{policy = NULL}, \code{reset = FALSE})
#'   to retrieve the current configuration without changing it. Pass a named
#'   list to \code{policy} to merge new/overriding entries into the current
#'   configuration via \code{\link[utils]{modifyList}} (\code{default_alg}
#'   and/or \code{inference_class_overrides} can each be supplied
#'   independently). Pass \code{reset = TRUE} to discard any accumulated
#'   overrides and restore the package's built-in default policy exactly as
#'   returned by \code{\link{get_optimization_dispatch_policy}}. Note that this
#'   only changes the \emph{default} algorithm consulted when a fitting call
#'   does not itself specify \code{optimization_alg} explicitly; an explicit
#'   per-call argument still takes precedence.
#'
#' @param policy Either \code{NULL} (no change) or a named list of policy
#'   overrides merged into the current configuration (see Details).
#' @param reset If \code{TRUE}, discard all overrides and restore the built-in
#'   default policy.
#' @return Invisible \code{NULL} when \code{policy} is supplied (a mutation), or
#'   invisibly the current policy configuration list when called for its
#'   side-effect-free query/reset value.
#' @seealso \code{\link{get_optimization_dispatch_policy}} for the policy
#'   schema and built-in defaults; \code{\link{set_cold_start_dispatch_policy}}
#'   and \code{\link{set_warm_start_dispatch_policy}} for the analogous setters
#'   governing cold-start and warm-start behavior.
#' @examples
#' set_optimization_dispatch_policy(reset = TRUE)
#' @export
set_optimization_dispatch_policy = function(policy = NULL, reset = FALSE) {
  checkmate::assertFlag(reset)
  if (isTRUE(reset)) {
    edi_env$optimization_dispatch_policy_config = get_optimization_dispatch_policy()
    return(invisible(edi_env$optimization_dispatch_policy_config))
  }
  if (is.null(policy)) {
    return(invisible(edi_env$optimization_dispatch_policy_config))
  }
  checkmate::assertList(policy, names = "named")
  edi_env$optimization_dispatch_policy_config = utils::modifyList(edi_env$optimization_dispatch_policy_config, policy)
  invisible(NULL)
}
# Internal helper to get the global fork cluster
get_global_fork_cluster = function() {
  edi_env$global_fork_cluster
}
# Internal helper to get the global mirai core count
get_global_mirai_cores = function() {
  edi_env$global_mirai_num_cores
}
get_num_cores = function() {
  if (!is.null(edi_env$num_cores_override)) return(edi_env$num_cores_override)
  cl = get_global_fork_cluster()
  if (!is.null(cl)) return(length(cl))
  mirai_cores = get_global_mirai_cores()
  if (!is.null(mirai_cores)) return(mirai_cores)
  1L
}
# Internal helper for empirical parallel dispatch policy.
# This is intentionally conservative and only forces serial execution for
# inference families that have shown repeat multicore regressions in the package
# benchmark suite. Everything else remains eligible for the usual warmup-based
# parallel heuristics. Do not expect a universal "more cores is faster" rule.
edi_parallel_dispatch_policy = function(inference_class, response_type, operation) {
  if (is.function(edi_env$parallel_dispatch_policy_override)) {
    return(edi_env$parallel_dispatch_policy_override(inference_class, response_type, operation))
  }
  inference_class = as.character(inference_class[[1]])
  response_type = as.character(response_type[[1]])
  operation = as.character(operation[[1]])
  config = edi_env$parallel_dispatch_policy_config
  matches_any = function(value, patterns) {
    if (is.null(patterns) || length(patterns) == 0L) return(FALSE)
    any(vapply(patterns, function(pattern) grepl(pattern, value, perl = TRUE), logical(1)))
  }
  reason = NULL
  if (identical(operation, "bootstrap")) {
    op_cfg = config$bootstrap
    if (matches_any(inference_class, op_cfg$serial_inference_class_patterns) ||
        matches_any(response_type, op_cfg$serial_response_types)) {
      reason = "bootstrap is forced serial by benchmark policy"
    }
  } else if (identical(operation, "rand_ci")) {
    op_cfg = config$rand_ci
    if (matches_any(inference_class, op_cfg$serial_inference_class_patterns) ||
        matches_any(response_type, op_cfg$serial_response_types)) {
      reason = "randomization confidence intervals are forced serial by benchmark policy"
    }
  }
  list(
    force_serial = !is.null(reason),
    reason = reason,
    inference_class = inference_class,
    response_type = response_type,
    operation = operation
  )
}
edi_bootstrap_dispatch_policy = function(inference_class, object = NULL) {
  config = edi_env$bootstrap_dispatch_policy_config
  inference_classes = as.character(inference_class)
  inference_class = inference_classes[[1]]
  overrides = config$inference_class_overrides
  design_overrides = config$design_class_overrides
  default_type = config$default_type
  if (is.null(default_type)) default_type = "bca"
  finalize_type = function(type) {
    type = tolower(type)
    if (identical(type, "bca") && !is.null(object)) {
      bca_unavailable = isTRUE(tryCatch(
        object$.__enclos_env__$private$jackknife_block_size_gt_one_unsupported(unit = "auto"),
        error = function(e) FALSE
      ))
      if (bca_unavailable) return("percentile")
    }
    type
  }
  if (!is.null(object) && !is.null(design_overrides) && length(design_overrides) > 0L) {
    des_obj = tryCatch(object$.__enclos_env__$private$des_obj, error = function(e) NULL)
    if (!is.null(des_obj)) {
      for (design_class in names(design_overrides)) {
        if (is(des_obj, design_class)) {
          design_map = design_overrides[[design_class]]
          for (pattern in names(design_map)) {
            if (is.na(pattern) || pattern == "") next
            if (any(grepl(pattern, inference_classes, perl = TRUE))) {
              return(finalize_type(design_map[[pattern]]))
            }
          }
        }
      }
    }
  }
  if (!is.null(overrides) && length(overrides) > 0L) {
    for (pattern in names(overrides)) {
      if (is.na(pattern) || pattern == "") next
      if (any(grepl(pattern, inference_classes, perl = TRUE))) {
        return(finalize_type(overrides[[pattern]]))
      }
    }
  }
  finalize_type(default_type)
}
edi_optimization_dispatch_policy = function(inference_class) {
  config = edi_env$optimization_dispatch_policy_config
  inference_class = as.character(inference_class[[1]])
  overrides = config$inference_class_overrides
  default_alg = config$default_alg
  if (is.null(default_alg)) default_alg = "newton_raphson"
  
  if (!is.null(overrides) && length(overrides) > 0L) {
    for (pattern in names(overrides)) {
      if (is.na(pattern) || pattern == "") next
      if (grepl(pattern, inference_class, perl = TRUE)) {
        return(tolower(overrides[[pattern]]))
      }
    }
  }
  tolower(default_alg)
}
# Internal helper
set_package_threads = function(num_cores) {
  # Ensure it's an integer
  num_cores = as.integer(num_cores)
  # Skip all expensive syscalls if threads are already set to this value.
  # Sys.setenv and the BLAS/OMP setters are relatively slow; calling them on
  # every serial replication causes a visible pause between reps.
  last = getOption(".edi_last_set_threads")
  if (identical(last, num_cores)) return(invisible(NULL))
  # R packages with global thread setters
	  if (check_package_installed("data.table")) {
	    data.table::setDTthreads(num_cores)
	  }
	  if (check_package_installed("fixest")) {
	    suppressWarnings(try(fixest::setFixest_nthreads(num_cores), silent = TRUE))
	  }
  # Environment variables for OpenMP and BLAS/LAPACK
  # This helps prevent thread explosion in child processes
  # that call multi-threaded native libraries.
  # Sys.setenv is relatively slow, so we only do it if needed.
  # We include as many as possible to catch various libraries.
  Sys.setenv(
    OMP_NUM_THREADS        = num_cores,
    MKL_NUM_THREADS        = num_cores,
    OPENBLAS_NUM_THREADS   = num_cores,
    GOTO_NUM_THREADS       = num_cores,
    BLAS_NUM_THREADS       = num_cores,
    LAPACK_NUM_THREADS     = num_cores,
    TAO_NUM_THREADS        = num_cores,
    VECLIB_MAXIMUM_THREADS = num_cores,
    NUMEXPR_NUM_THREADS    = num_cores,
    OMP_THREAD_LIMIT       = num_cores,
    OMP_DYNAMIC            = "FALSE",
    OMP_NESTED             = "FALSE"
  )
  
  # Direct C++ control for OpenMP and Eigen (more robust than env vars after startup)
  try(set_omp_num_threads_cpp(num_cores), silent = TRUE)
  # BLAS and OpenMP control via RhpcBLASctl (now a required dependency)
  try({
    RhpcBLASctl::blas_set_num_threads(num_cores)
    RhpcBLASctl::omp_set_num_threads(num_cores)
  }, silent = TRUE)
  
  # Also set R options for parallel/pbmcapply
  options(mc.cores = num_cores)
  
  options(".edi_last_set_threads" =   num_cores)
  invisible(NULL)
}

.create_match_dummies = function(m_vec) {
  m_vec = as.integer(m_vec)
  m_vec[is.na(m_vec)] = 0L
  max_m = max(m_vec, 0L)
  if (max_m == 0L) return(NULL)
  mm = stats::model.matrix(~ factor(m_vec) + 0)
  colnames(mm) = paste0("match_", 0:max_m)
  mm
}
