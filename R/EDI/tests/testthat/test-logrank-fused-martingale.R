library(testthat)
library(EDI)

# Verify fast_logrank_stats_cpp after fusing martingale mean/variance accumulation
# into the main sweep (TODO-47). Reference: survival::survdiff (score/var_score)
# and coxph martingale residuals (beta_hat / se_beta_hat).

skip_if_not_installed("survival")

make_surv_data <- function(n, seed) {
    set.seed(seed)
    w    <- as.integer(sample(0:1, n, replace = TRUE))
    y    <- rexp(n, rate = exp(0.3 * w))
    dead <- as.integer(rbinom(n, 1, 0.8))
    list(w = w, y = y, dead = dead)
}

test_that("logrank score and var_score match survival::survdiff", {
    d <- make_surv_data(120L, seed = 1L)
    res <- EDI:::fast_logrank_stats_cpp(d$w, d$y, d$dead)

    df  <- data.frame(time = d$y, status = d$dead, w = factor(d$w))
    sd  <- survival::survdiff(survival::Surv(time, status) ~ w, data = df)
    expect_equal(res$score,     sd$obs[2] - sd$exp[2], tolerance = 1e-10)
    expect_equal(res$var_score, sd$var[2, 2],           tolerance = 1e-10)
})

test_that("logrank beta_hat and se_beta_hat match coxph martingale residuals", {
    d <- make_surv_data(150L, seed = 2L)
    res <- EDI:::fast_logrank_stats_cpp(d$w, d$y, d$dead)

    df  <- data.frame(time = d$y, status = d$dead)
    # method = "breslow": fast_logrank_stats_cpp() accumulates cumulative hazard as
    # d_all / risk_all per tied-time group (Nelson-Aalen), which only matches coxph()'s
    # martingale residuals under method = "breslow", not the "efron" default (the two
    # agree here only because make_surv_data() uses rexp(), which essentially never ties).
    fit <- survival::coxph(survival::Surv(time, status) ~ 1, data = df, method = "breslow")
    m   <- residuals(fit, type = "martingale")

    beta_ref <- mean(m[d$w == 1]) - mean(m[d$w == 0])
    n1 <- sum(d$w == 1); n0 <- sum(d$w == 0)
    se_ref   <- sqrt(var(m[d$w == 1]) / n1 + var(m[d$w == 0]) / n0)

    expect_equal(res$beta_hat,    beta_ref, tolerance = 1e-10)
    expect_equal(res$se_beta_hat, se_ref,   tolerance = 1e-10)
})

test_that("logrank handles all-dead and no-ties data correctly", {
    d <- make_surv_data(80L, seed = 3L)
    d$dead <- rep(1L, 80L)  # all events
    res <- EDI:::fast_logrank_stats_cpp(d$w, d$y, d$dead)
    expect_true(is.finite(res$score))
    expect_true(is.finite(res$beta_hat))
    expect_true(is.finite(res$se_beta_hat))
})

test_that("logrank output matches across multiple seeds", {
    for (seed in c(10L, 20L, 30L, 40L)) {
        d   <- make_surv_data(200L, seed = seed)
        res <- EDI:::fast_logrank_stats_cpp(d$w, d$y, d$dead)

        df  <- data.frame(time = d$y, status = d$dead, w = factor(d$w))
        sd  <- survival::survdiff(survival::Surv(time, status) ~ w, data = df)

        expect_equal(res$score,     sd$obs[2] - sd$exp[2], tolerance = 1e-10,
                     label = paste("score seed", seed))
        expect_equal(res$var_score, sd$var[2, 2],           tolerance = 1e-10,
                     label = paste("var_score seed", seed))
    }
})

test_that("compute_estimate_with_bootstrap_weights(uniform weights) matches compute_estimate() under tied event times", {
    # Same tie-handling mismatch as InferenceSurvivalGehanWilcox (see
    # test-gehan-wilcox-fused-martingale.R): fast_logrank_stats_cpp() (compute_estimate()'s
    # path) accumulates cumulative hazard as d_all / risk_all per tied-time group (Breslow/
    # Nelson-Aalen), while weighted_logrank_mean_difference() (compute_estimate_with_bootstrap_weights()'s
    # path) called survival::coxph(~1, weights = ...) without pinning `method`, defaulting to
    # "efron" -- a genuinely different martingale residual under ties. Unexercised by the rest
    # of this file because make_surv_data() uses rexp(), which essentially never ties.
    n <- 10L
    des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
    for (i in seq_len(n)) {
        des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
    }
    des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
    y    <- c(1, 2, 2, 2, 3, 3, 4, 5, 5, 6)
    dead <- c(1, 1, 1, 0, 1, 1, 0, 1, 1, 1)
    y_exact <- ifelse(dead == 1, y, NA_real_)
    y_L <- ifelse(dead == 1, NA_real_, y)
    y_R <- ifelse(dead == 1, NA_real_, Inf)
    des$add_all_subject_responses(y_exact, y_L, y_R)

    # Two independent instances -- compute_shared()'s cache guard means calling
    # compute_estimate_with_bootstrap_weights() then compute_estimate() on the SAME
    # instance just returns the already-cached bootstrap value the second time,
    # silently making that comparison a tautology. Isolate each code path in its own instance.
    inf_cpp <- InferenceSurvivalLogRank$new(des)
    est_cpp <- as.numeric(inf_cpp$compute_estimate())

    inf_r <- InferenceSurvivalLogRank$new(des)
    inf_r$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
        row_to_unit = seq_len(n),
        unit_group_id = rep(1L, n),
        n_units = n
    )
    est_r <- as.numeric(inf_r$compute_estimate_with_bootstrap_weights(rep(1, n)))

    expect_equal(est_r, est_cpp, tolerance = 1e-8)
})
