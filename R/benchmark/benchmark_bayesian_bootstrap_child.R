# Bayesian bootstrap: EDI (installed) vs bayesboot across 11 estimators.
# Child of benchmark_bayesian_bootstrap_performance.R (release v1.0.5 TODO-57).
# Protocol: same data, same B, fresh EDI object per timed run (no cached
# distribution), single-threaded, median of `reps` runs. For each case
# the R statistic is fit with and without covariates; whichever matches EDI's
# point estimate is the one bayesboot uses. Cases where neither matches are
# reported as "no match" and not timed. Loads the installed EDI only.
suppressPackageStartupMessages({
  library(EDI); library(bayesboot); library(survival); library(MASS)
  library(betareg); library(quantreg); library(doParallel)
})
args = commandArgs(trailingOnly = TRUE)  # optional output CSV path (written at the end)
CORES = as.integer(Sys.getenv("EDI_BB_BENCH_CORES", "3"))
if (!is.finite(CORES) || CORES < 1L) stop("EDI_BB_BENCH_CORES must be a positive integer")
cl = parallel::makeCluster(CORES); registerDoParallel(cl)
invisible(parallel::clusterEvalQ(cl, { suppressPackageStartupMessages({ library(survival); library(MASS); library(betareg); library(quantreg) }) }))
set.seed(2)
n = as.integer(Sys.getenv("EDI_BB_BENCH_N", "500"))
B = as.integer(Sys.getenv("EDI_BB_BENCH_B", "1000"))
reps = as.integer(Sys.getenv("EDI_BB_BENCH_REPS", "3"))
if (!is.finite(n) || n < 2L || !is.finite(B) || B < 1L || !is.finite(reps) || reps < 1L) {
  stop("EDI_BB_BENCH_N, EDI_BB_BENCH_B, and EDI_BB_BENCH_REPS must be positive integers")
}
override_blocklist = identical(Sys.getenv("EDI_BB_BENCH_OVERRIDE_BLOCKLIST", "0"), "1")
if (override_blocklist) {
  getFromNamespace("set_parallel_dispatch_policy", "EDI")(function(inference_class, response_type, operation) {
    list(force_serial = FALSE, reason = NULL, inference_class = inference_class,
         response_type = response_type, operation = operation)
  })
}
X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
lin = 0.5 * X$x1 - 0.3 * X$x2 + 0.2 * X$x3
time_med = function(f) median(replicate(reps, system.time(f())[["elapsed"]]))

design_with = function(response_type, y_fun) {
  des = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
  des$add_all_subjects_to_experiment(X)
  des$assign_w_to_all_subjects()
  w = des$get_w()
  list(des = des, w = w, y = y_fun(w))
}

cases = list()
add_case = function(label, cls, response_type, y_fun, fit_adj, fit_unadj, add_resp = NULL, d_extra = NULL) {
  dw = design_with(response_type, y_fun)
  if (is.null(add_resp)) dw$des$add_all_subject_responses(dw$y) else add_resp(dw$des, dw$y)
  d = data.frame(y = if (is.list(dw$y) && !is.factor(dw$y)) NA else dw$y, w = dw$w, X)
  if (!is.null(d_extra)) d = d_extra(d, dw$y)
  cases[[length(cases) + 1]] <<- list(label = label, des = dw$des, cls = cls, d = d,
                                      fit_adj = fit_adj, fit_unadj = fit_unadj)
}

# round-1 estimators, re-run here so every row shares one protocol
add_case("OLS, covariate-adjusted (lm)", "InferenceContinOLS", "continuous",
  function(w) 1 + 0.5 * w + lin + rnorm(n),
  fit_adj = function(d, wt) coef(lm(y ~ w + x1 + x2 + x3, data = d, weights = wt))[["w"]],
  fit_unadj = function(d, wt) coef(lm(y ~ w, data = d, weights = wt))[["w"]])
add_case("Logistic regression (glm)", "InferenceIncidLogRegr", "incidence",
  function(w) rbinom(n, 1, plogis(-0.2 + 0.6 * w + lin)),
  fit_adj = function(d, wt) coef(suppressWarnings(glm(y ~ w + x1 + x2 + x3, data = d, weights = wt, family = binomial)))[["w"]],
  fit_unadj = function(d, wt) coef(suppressWarnings(glm(y ~ w, data = d, weights = wt, family = binomial)))[["w"]])
add_case("Cox proportional hazards (coxph)", "InferenceSurvivalCoxPHRegr", "survival",
  function(w) { t_ev = rexp(n, rate = exp(-0.5 * w + lin)); t_c = rexp(n, rate = 0.25)
                list(time = pmin(t_ev, t_c), status = as.integer(t_ev <= t_c)) },
  fit_adj = function(d, wt) coef(survival::coxph(survival::Surv(time, status) ~ w + x1 + x2 + x3, data = d, weights = wt))[["w"]],
  fit_unadj = function(d, wt) coef(survival::coxph(survival::Surv(time, status) ~ w, data = d, weights = wt))[["w"]],
  add_resp = function(des, y) des$add_all_subject_responses(ys = ifelse(y$status == 1, y$time, NA),
    y_Ls = ifelse(y$status == 1, NA, y$time), y_Rs = ifelse(y$status == 1, NA, Inf)),
  d_extra = function(d, y) { d$y = NULL; d$time = y$time; d$status = y$status; d })
# continuous
add_case("Difference in means", "InferenceAllSimpleMeanDiffPooledVar", "continuous",
  function(w) 1 + 0.5 * w + lin + rnorm(n),
  fit_adj = function(d, wt) { m = lm(y ~ w + x1 + x2 + x3, data = d, weights = wt); coef(m)[["w"]] },
  fit_unadj = function(d, wt) weighted.mean(d$y[d$w == 1], wt[d$w == 1]) - weighted.mean(d$y[d$w == 0], wt[d$w == 0]))
add_case("MM robust regression (MASS::rlm, method = MM)", "InferenceContinRobustRegr", "continuous",
  function(w) 1 + 0.5 * w + lin + rt(n, df = 3),
  fit_adj = function(d, wt) coef(MASS::rlm(y ~ w + x1 + x2 + x3, data = d, weights = wt, method = "MM", maxit = 50))[["w"]],
  fit_unadj = function(d, wt) coef(MASS::rlm(y ~ w, data = d, weights = wt, method = "MM", maxit = 50))[["w"]])
add_case("Median (quantile) regression (quantreg::rq)", "InferenceContinQuantileRegr", "continuous",
  function(w) 1 + 0.5 * w + lin + rnorm(n),
  fit_adj = function(d, wt) coef(quantreg::rq(y ~ w + x1 + x2 + x3, data = d, weights = wt, tau = 0.5))[["w"]],
  fit_unadj = function(d, wt) coef(quantreg::rq(y ~ w, data = d, weights = wt, tau = 0.5))[["w"]])
# binary
add_case("Probit regression (glm)", "InferenceIncidProbitRegr", "incidence",
  function(w) rbinom(n, 1, pnorm(-0.1 + 0.4 * w + 0.6 * lin)),
  fit_adj = function(d, wt) coef(suppressWarnings(glm(y ~ w + x1 + x2 + x3, data = d, weights = wt, family = binomial("probit"))))[["w"]],
  fit_unadj = function(d, wt) coef(suppressWarnings(glm(y ~ w, data = d, weights = wt, family = binomial("probit"))))[["w"]])
# count
add_case("Poisson regression (glm)", "InferenceCountPoisson", "count",
  function(w) rpois(n, exp(0.5 + 0.3 * w + 0.5 * lin)),
  fit_adj = function(d, wt) coef(suppressWarnings(glm(y ~ w + x1 + x2 + x3, data = d, weights = wt, family = poisson)))[["w"]],
  fit_unadj = function(d, wt) coef(suppressWarnings(glm(y ~ w, data = d, weights = wt, family = poisson)))[["w"]])
add_case("Negative binomial (MASS::glm.nb)", "InferenceCountNegBin", "count",
  function(w) rnbinom(n, mu = exp(0.5 + 0.3 * w + 0.5 * lin), size = 2),
  fit_adj = function(d, wt) coef(suppressWarnings(MASS::glm.nb(y ~ w + x1 + x2 + x3, data = d, weights = wt)))[["w"]],
  fit_unadj = function(d, wt) coef(suppressWarnings(MASS::glm.nb(y ~ w, data = d, weights = wt)))[["w"]])
# proportion
add_case("Beta regression (betareg)", "InferencePropBetaRegr", "proportion",
  function(w) { mu = plogis(-0.2 + 0.4 * w + 0.5 * lin); rbeta(n, mu * 10, (1 - mu) * 10) },
  fit_adj = function(d, wt) coef(betareg::betareg(y ~ w + x1 + x2 + x3, data = d, weights = wt))[["w"]],
  fit_unadj = function(d, wt) coef(betareg::betareg(y ~ w, data = d, weights = wt))[["w"]])
# ordinal
add_case("Proportional odds (MASS::polr)", "InferenceOrdinalPropOddsRegr", "ordinal",
  function(w) { z = 0.6 * w + lin + rlogis(n); factor(cut(z, c(-Inf, -1, 0, 1, Inf), labels = FALSE), levels = 1:4, ordered = TRUE) },
  fit_adj = function(d, wt) coef(suppressWarnings(MASS::polr(y ~ w + x1 + x2 + x3, data = d, weights = wt)))[["w"]],
  fit_unadj = function(d, wt) coef(suppressWarnings(MASS::polr(y ~ w, data = d, weights = wt)))[["w"]])
# survival
# survreg's default (cold) Newton start occasionally diverges on a Dirichlet
# weight draw (~1 in 15,000 here: log-scale step runs away, scale -> 1e-127,
# every coefficient NA), which made bayesboot's draws mean/sd print NA / NA.
# On such a draw, refit warm-started at the unweighted MLE; that converges to
# the same weighted MLE (checked against optim). Normal draws are unchanged.
# A factory (not a global helper) so the statistic closure carries everything
# it needs to the bayesboot .parallel = TRUE PSOCK workers.
survreg_weibull_w_stat = function(fm) { force(fm); function(d, wt) {
  environment(fm) = environment()  # survreg/model.frame look up `weights = wt` here
  fit = survival::survreg(fm, data = d, weights = wt, dist = "weibull")
  if (anyNA(coef(fit))) {
    fit0 = survival::survreg(fm, data = d, dist = "weibull")
    fit = survival::survreg(fm, data = d, weights = wt, dist = "weibull",
                            init = c(coef(fit0), log(fit0$scale)))
  }
  coef(fit)[["w"]]
} }
add_case("Weibull AFT (survreg)", "InferenceSurvivalWeibullRegr", "survival",
  function(w) { t_ev = rweibull(n, shape = 1.5, scale = exp(1 + 0.4 * w + 0.5 * lin)); t_c = rexp(n, 0.15)
                list(time = pmin(t_ev, t_c), status = as.integer(t_ev <= t_c)) },
  fit_adj = survreg_weibull_w_stat(survival::Surv(time, status) ~ w + x1 + x2 + x3),
  fit_unadj = survreg_weibull_w_stat(survival::Surv(time, status) ~ w),
  add_resp = function(des, y) des$add_all_subject_responses(ys = ifelse(y$status == 1, y$time, NA),
    y_Ls = ifelse(y$status == 1, NA, y$time), y_Rs = ifelse(y$status == 1, NA, Inf)),
  d_extra = function(d, y) { d$y = NULL; d$time = y$time; d$status = y$status; d })

cat(sprintf("n = %d, B = %d draws, median of %d timed runs; 1 core and %d cores for both packages (bayesboot via .parallel = TRUE + doParallel); EDI %s, bayesboot %s, %d cores detected\n\n",
    n, B, reps, CORES, packageVersion("EDI"), packageVersion("bayesboot"), parallel::detectCores()))
rows = list()
for (cs in cases) {
  res = tryCatch({
    inf = get(cs$cls)$new(cs$des); edi_est = inf$compute_estimate()
    one = rep(1, n)
    r_adj = cs$fit_adj(cs$d, one); r_unadj = cs$fit_unadj(cs$d, one)
    tol = 1e-3 * max(1, abs(edi_est))
    stat = if (abs(edi_est - r_adj) < tol) cs$fit_adj else if (abs(edi_est - r_unadj) < tol) cs$fit_unadj else NULL
    which_fit = if (identical(stat, cs$fit_adj)) "covariate-adjusted" else if (!is.null(stat)) "unadjusted" else "NO MATCH"
    if (is.null(stat)) {
      sprintf("%s\n  EDI %.4f | R adjusted %.4f | R unadjusted %.4f -> NO MATCH, not timed\n", cs$label, edi_est, r_adj, r_unadj)
    } else {
      edi_draws = inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE)
      bb_draws = bayesboot(cs$d, stat, R = B, use.weights = TRUE)[[1]]
      edi_run = function() { i = get(cs$cls)$new(cs$des); i$compute_estimate()
                             i$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE) }
      set_num_cores(1);     t_edi = time_med(edi_run)
      set_num_cores(CORES); t_edi3 = time_med(edi_run); set_num_cores(1)
      t_bb  = time_med(function() bayesboot(cs$d, stat, R = B, use.weights = TRUE))
      t_bb3 = time_med(function() bayesboot(cs$d, stat, R = B, use.weights = TRUE, .parallel = TRUE))
      rows = c(rows, list(data.frame(estimator = cs$label, model = which_fit,
        n = n, B = B, reps = reps, EDI_cores = paste0("1_vs_", CORES),
        dispatch_policy = if (override_blocklist) "blocklist_override" else "default",
        edi_1core_s = t_edi, bayesboot_1core_s = t_bb, speedup_1core = t_bb / t_edi,
        edi_3core_s = t_edi3, bayesboot_3core_s = t_bb3, speedup_3core = t_bb3 / t_edi3)))
      assign("rows", rows, envir = globalenv())
      sprintf("%s [%s]\n  point estimate: EDI %.4f | R %.4f\n  draws mean/sd:  EDI %.4f / %.4f | bayesboot %.4f / %.4f\n  1 core: EDI %.3f s | bayesboot %.3f s | speedup %.2fx;  %d cores: EDI %.3f s | bayesboot %.3f s | speedup %.2fx\n",
        cs$label, which_fit, edi_est, if (which_fit == "covariate-adjusted") r_adj else r_unadj,
        mean(edi_draws, na.rm = TRUE), sd(edi_draws, na.rm = TRUE), mean(bb_draws), sd(bb_draws), t_edi, t_bb, t_bb / t_edi, CORES, t_edi3, t_bb3, t_bb3 / t_edi3)
    }
  }, error = function(e) sprintf("%s\n  ERROR: %s\n", cs$label, conditionMessage(e)))
  cat(res, "\n")
}
if (length(rows)) { cat("Summary:\n"); print(do.call(rbind, rows), row.names = FALSE, digits = 3) }
if (length(args) >= 1L) utils::write.csv(do.call(rbind, rows), args[[1L]], row.names = FALSE)

parallel::stopCluster(cl)
