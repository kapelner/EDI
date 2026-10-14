# Per-draw reusable nonparametric-bootstrap worker benchmark (release v1.0.5 TODO-58).
# Run with Rscript R/benchmark/benchmark_bootstrap_worker_draws.R [n] [draws] [seed] [output.csv]
# This intentionally exercises the installed EDI package's private worker API;
# it does not source or compile the checkout.

args <- commandArgs(trailingOnly = TRUE)
n <- if (length(args) >= 1L) as.integer(args[[1L]]) else 1000L
n_draws <- if (length(args) >= 2L) as.integer(args[[2L]]) else 100L
seed <- if (length(args) >= 3L) as.integer(args[[3L]]) else 20261014L
output_path <- if (length(args) >= 4L) args[[4L]] else NULL

if (is.na(n) || n < 20L || is.na(n_draws) || n_draws < 1L || is.na(seed)) {
  stop("Expected n >= 20, draws >= 1, and an integer seed.")
}

suppressPackageStartupMessages(library(EDI))
pkg_path <- normalizePath(find.package("EDI"), winslash = "/", mustWork = TRUE)
if (grepl("/R/EDI(/|$)", pkg_path)) {
  stop("This benchmark must run against an installed EDI package, not the checkout.")
}
cat("EDI", as.character(utils::packageVersion("EDI")), "from", pkg_path, "\n")

make_fixture <- function(kind, n, seed) {
  set.seed(seed)
  x1 <- stats::rnorm(n)
  x2 <- stats::rnorm(n)
  response_type <- switch(kind,
    OLS = "continuous",
    logistic = "incidence",
    Cox = "survival"
  )
  design_class <- if (identical(response_type, "survival")) {
    DesignFixediBCRD
  } else {
    DesignFixedBernoulli
  }
  des <- design_class$new(
    n = n,
    response_type = response_type,
    seed = seed,
    verbose = FALSE
  )
  des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
  des$assign_w_to_all_subjects()
  w <- as.numeric(des$get_w())
  if (identical(kind, "OLS")) {
    y <- 0.5 + 0.7 * w + 0.4 * x1 - 0.2 * x2 + stats::rnorm(n)
    des$add_all_subject_responses(y)
    inf <- InferenceContinOLS$new(des, model_formula = ~., verbose = FALSE)
  } else if (identical(kind, "logistic")) {
    p <- stats::plogis(-0.4 + 0.7 * w + 0.3 * x1 - 0.2 * x2)
    y <- stats::rbinom(n, size = 1L, prob = p)
    des$add_all_subject_responses(y)
    inf <- InferenceIncidLogRegr$new(des, model_formula = ~., verbose = FALSE)
  } else {
    event_time <- stats::rexp(n, rate = exp(0.25 * w + 0.2 * x1 - 0.15 * x2))
    # Exact event times use `ys` alone; censoring bounds must be supplied as
    # a paired (y_Ls, y_Rs) observation for every censored subject.
    des$add_all_subject_responses(event_time)
    inf <- InferenceSurvivalCoxPHRegr$new(des, model_formula = ~., verbose = FALSE)
  }
  inf$num_cores <- 1L
  invisible(inf$compute_estimate(estimate_only = TRUE))
  list(inference = inf, n = n)
}

benchmark_one <- function(kind, n, n_draws, seed) {
  fixture <- make_fixture(kind, n, seed)
  inference <- fixture$inference
  private <- inference$.__enclos_env__$private
  worker <- private$create_design_backed_bootstrap_worker_state()
  set.seed(seed + 1000L)
  draws <- replicate(n_draws, sample.int(n, n, replace = TRUE), simplify = FALSE)
  run_draw <- function(indices) {
    private$load_bootstrap_sample_into_design_backed_worker(worker, indices)
    private$compute_bootstrap_worker_estimate(worker)
  }

  warmup_n <- min(5L, n_draws)
  for (i in seq_len(warmup_n)) invisible(run_draw(draws[[i]]))
  batch_size <- 25L
  batch_starts <- seq.int(1L, n_draws, by = batch_size)
  elapsed_ms_per_draw <- numeric(length(batch_starts))
  for (batch in seq_along(batch_starts)) {
    first <- batch_starts[[batch]]
    last <- min(n_draws, first + batch_size - 1L)
    before <- proc.time()[["elapsed"]]
    for (i in first:last) invisible(run_draw(draws[[i]]))
    elapsed_ms_per_draw[[batch]] <-
      (proc.time()[["elapsed"]] - before) * 1000 / (last - first + 1L)
  }

  profile_n <- min(100L, n_draws)
  profile_file <- tempfile(pattern = paste0("edi-bootstrap-worker-", kind, "-"), fileext = ".out")
  utils::Rprof(profile_file, interval = 0.01)
  for (i in seq_len(profile_n)) invisible(run_draw(draws[[i]]))
  utils::Rprof(NULL)
  profile <- summaryRprof(profile_file, memory = "none")$by.total
  unlink(profile_file)

  cat("\n", kind, ": median ", format(stats::median(elapsed_ms_per_draw), digits = 4),
      " ms/draw; IQR ", format(stats::IQR(elapsed_ms_per_draw), digits = 4),
      " ms; n=", n, ", draws=", n_draws, "\n", sep = "")
  if (nrow(profile)) {
    cat("Top Rprof entries (", profile_n, " profiled draws):\n", sep = "")
    print(utils::head(profile, 15L))
  }
  data.frame(
    class = kind,
    n = n,
    draws = n_draws,
    seed = seed,
    median_ms_per_draw = stats::median(elapsed_ms_per_draw),
    iqr_ms_per_draw = stats::IQR(elapsed_ms_per_draw),
    stringsAsFactors = FALSE
  )
}

results <- do.call(rbind, lapply(seq_along(c("OLS", "logistic", "Cox")), function(i) {
  kind <- c("OLS", "logistic", "Cox")[[i]]
  benchmark_one(kind, n, n_draws, seed + i - 1L)
}))
if (!is.null(output_path)) {
  utils::write.csv(results, output_path, row.names = FALSE)
  cat("\nWrote", normalizePath(output_path, mustWork = FALSE), "\n")
}
