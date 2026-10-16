# Installed-package diagnostics for v1.0.5 Bayesian-bootstrap TODO-57 TODO-2/3.
#
# Separate from benchmark_bayesian_bootstrap_performance.R: this times worker
# setup, fixed-draw refits, and transport of serialized task-shaped payloads.
# It never loads the checkout. Payload transfer times use EDI's actual fork or
# mirai par_lapply route to ship serialized closures for decode; these are a
# controlled transport probe, not a claim about R's exact wire framing.
#
# Usage (after TODO-56 terminates and host load is suitable):
#   Rscript R/benchmark/benchmark_bayesian_bootstrap_dispatch_payload.R [n] [B] [cores] [reps] [seed] [output.csv]
# No results file is written unless output.csv is explicitly supplied; direct
# any output to scratch, never to canonical benchmark/result paths.

args <- commandArgs(trailingOnly = TRUE)
n <- if (length(args) >= 1L) as.integer(args[[1L]]) else 500L
B <- if (length(args) >= 2L) as.integer(args[[2L]]) else 1000L
cores <- if (length(args) >= 3L) as.integer(args[[3L]]) else 3L
reps <- if (length(args) >= 4L) as.integer(args[[4L]]) else 3L
seed <- if (length(args) >= 5L) as.integer(args[[5L]]) else 20261016L
output <- if (length(args) >= 6L) args[[6L]] else NULL
if (anyNA(c(n, B, cores, reps, seed)) || n < 20L || B < 2L || cores < 2L || reps < 1L) {
  stop("Expected n >= 20, B >= 2, cores >= 2, reps >= 1, and an integer seed.")
}
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
if (length(script_arg) != 1L) stop("Run this file with Rscript so its repository root can be checked.")
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/")
if (!is.null(output)) {
  output_abs <- normalizePath(path.expand(output), winslash = "/", mustWork = FALSE)
  if (!grepl("^/", output_abs)) output_abs <- file.path(getwd(), output_abs)
  if (identical(output_abs, repo_root) || startsWith(output_abs, paste0(repo_root, "/"))) {
    stop("Refusing to write output inside the repository; use a scratch path.")
  }
}

suppressPackageStartupMessages(library(EDI))
pkg_path <- normalizePath(find.package("EDI"), winslash = "/", mustWork = TRUE)
if (grepl("/R/EDI(/|$)", pkg_path)) stop("Use an installed EDI package, not the checkout.")
cat("EDI", as.character(utils::packageVersion("EDI")), "from", pkg_path, "\n")

median_elapsed <- function(f, reps) {
  stats::median(vapply(seq_len(reps), function(i) {
    unname(system.time(f())[["elapsed"]])
  }, numeric(1L)))
}

set.seed(seed)
X <- data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n), x3 = stats::rnorm(n))
des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
des$add_all_subjects_to_experiment(X)
des$assign_w_to_all_subjects()
w <- as.numeric(des$get_w())
y <- 1 + 0.5 * w + 0.4 * X$x1 - 0.2 * X$x2 + stats::rnorm(n)
des$add_all_subject_responses(y)
inference <- InferenceContinOLS$new(des, model_formula = ~., seed = seed, verbose = FALSE)
invisible(inference$compute_estimate(estimate_only = TRUE))
private <- inference$.__enclos_env__$private
required <- c("bayesian_bootstrap_sample_weight_draws", "create_bootstrap_worker_state",
              "load_bayesian_bootstrap_draw_into_worker",
              "compute_bayesian_bootstrap_worker_estimate", "par_lapply")
missing <- required[!vapply(required, function(nm) is.function(private[[nm]]), logical(1L))]
if (length(missing)) stop("Installed EDI lacks worker hooks: ", paste(missing, collapse = ", "))

set.seed(seed + 1L)
draws <- private$bayesian_bootstrap_sample_weight_draws(B = as.integer(B))
chunk_n <- max(1L, min(as.integer(cores), as.integer(B)))
chunk_id <- ceiling(seq_len(B) / ceiling(B / chunk_n))
chunks <- split(seq_len(B), chunk_id)

# Match the current reusable-worker task shape: each task receives chunk
# indices, while its function environment captures the full draw list/private
# inference state. Serialize, but never execute, this closure here.
task_fn <- local({
  captured_draws <- draws
  captured_private <- private
  function(idxs) {
    worker_state <- captured_private$create_bootstrap_worker_state()
    for (idx in idxs) {
      draw <- captured_draws[[idx]]
      captured_private$load_bayesian_bootstrap_draw_into_worker(worker_state, draw)
      invisible(captured_private$compute_bayesian_bootstrap_worker_estimate(worker_state))
    }
    invisible(NULL)
  }
})
task_raw <- lapply(chunks, function(idxs) {
  tryCatch(serialize(list(FUN = task_fn, chunk = idxs), NULL, xdr = FALSE),
           error = function(e) structure(raw(), serialization_error = conditionMessage(e)))
})
task_bytes <- vapply(task_raw, length, integer(1L))
task_errors <- vapply(task_raw, function(x) {
  e <- attr(x, "serialization_error")
  if (is.null(e)) "" else as.character(e)[1L]
}, character(1L))

# Worker creation and a fixed-draw refit are isolated from dispatch/transfer.
worker_create_s <- median_elapsed(function() invisible(private$create_bootstrap_worker_state()),
                                 reps = max(3L, reps))
worker_state <- private$create_bootstrap_worker_state()
private$load_bayesian_bootstrap_draw_into_worker(worker_state, draws[[1L]])
invisible(private$compute_bayesian_bootstrap_worker_estimate(worker_state))
fixed_draw_refit_s <- median_elapsed(function() {
  private$load_bayesian_bootstrap_draw_into_worker(worker_state, draws[[1L]])
  invisible(private$compute_bayesian_bootstrap_worker_estimate(worker_state))
}, reps = max(5L, reps * 2L))

inspect_payload <- function(raw_payload) {
  start <- proc.time()[["elapsed"]]
  decoded <- unserialize(raw_payload)
  list(bytes = length(raw_payload), decode_s = proc.time()[["elapsed"]] - start,
       n_chunk = length(decoded$chunk))
}

results <- list()
for (backend in c("fork", "mirai")) {
  force_mirai <- identical(backend, "mirai")
  if (force_mirai && !requireNamespace("mirai", quietly = TRUE)) {
    results[[length(results) + 1L]] <- data.frame(
      backend = backend, status = "skipped: mirai not installed", cluster_setup_s = NA_real_,
      worker_create_s = worker_create_s, fixed_draw_refit_s = fixed_draw_refit_s,
      task_count = length(chunks), task_bytes_min = min(task_bytes),
      task_bytes_median = stats::median(task_bytes), task_bytes_max = max(task_bytes),
      payload_transfer_s = NA_real_, payload_decode_s_median = NA_real_,
      projected_serial_s = B * fixed_draw_refit_s, projected_parallel_s = NA_real_,
      stringsAsFactors = FALSE)
    next
  }
  setup_s <- tryCatch(median_elapsed(function() {
    on.exit(try(unset_num_cores(), silent = TRUE), add = TRUE)
    set_num_cores(cores, force_mirai = force_mirai)
  }, reps = reps), error = function(e) e)
  if (inherits(setup_s, "error")) {
    results[[length(results) + 1L]] <- data.frame(
      backend = backend, status = paste0("setup failed: ", conditionMessage(setup_s)),
      cluster_setup_s = NA_real_, worker_create_s = worker_create_s,
      fixed_draw_refit_s = fixed_draw_refit_s, task_count = length(chunks),
      task_bytes_min = min(task_bytes), task_bytes_median = stats::median(task_bytes),
      task_bytes_max = max(task_bytes), payload_transfer_s = NA_real_,
      payload_decode_s_median = NA_real_, projected_serial_s = B * fixed_draw_refit_s,
      projected_parallel_s = NA_real_, stringsAsFactors = FALSE)
    next
  }

  transfer_result <- tryCatch({
    set_num_cores(cores, force_mirai = force_mirai)
    invisible(private$par_lapply(list(1L), identity, n_cores = cores, budget = 1L))
    transfer_s <- median_elapsed(function() {
      invisible(private$par_lapply(task_raw, inspect_payload, n_cores = cores, budget = 1L))
    }, reps = reps)
    decoded <- private$par_lapply(task_raw, inspect_payload, n_cores = cores, budget = 1L)
    list(transfer_s = transfer_s,
         decode_s = vapply(decoded, function(x) as.numeric(x$decode_s)[1L], numeric(1L)))
  }, error = function(e) e)
  try(unset_num_cores(), silent = TRUE)
  if (inherits(transfer_result, "error")) {
    results[[length(results) + 1L]] <- data.frame(
      backend = backend, status = paste0("transfer failed: ", conditionMessage(transfer_result)),
      cluster_setup_s = setup_s, worker_create_s = worker_create_s,
      fixed_draw_refit_s = fixed_draw_refit_s, task_count = length(chunks),
      task_bytes_min = min(task_bytes), task_bytes_median = stats::median(task_bytes),
      task_bytes_max = max(task_bytes), payload_transfer_s = NA_real_,
      payload_decode_s_median = NA_real_, projected_serial_s = B * fixed_draw_refit_s,
      projected_parallel_s = NA_real_, stringsAsFactors = FALSE)
    next
  }
  payload_transfer_s <- transfer_result$transfer_s
  results[[length(results) + 1L]] <- data.frame(
    backend = backend, status = if (all(task_bytes > 0L)) "ok" else "task serialization failed",
    cluster_setup_s = setup_s, worker_create_s = worker_create_s,
    fixed_draw_refit_s = fixed_draw_refit_s, task_count = length(chunks),
    task_bytes_min = min(task_bytes), task_bytes_median = stats::median(task_bytes),
    task_bytes_max = max(task_bytes), payload_transfer_s = payload_transfer_s,
    payload_decode_s_median = stats::median(transfer_result$decode_s),
    projected_serial_s = B * fixed_draw_refit_s,
    projected_parallel_s = setup_s + length(chunks) * worker_create_s +
      B * fixed_draw_refit_s / cores + payload_transfer_s,
    stringsAsFactors = FALSE)
}

result <- do.call(rbind, results)
result$package_version <- as.character(utils::packageVersion("EDI"))
result$package_path <- pkg_path
result$n <- n
result$B <- B
result$cores <- cores
result$reps <- reps
result$seed <- seed
if (any(nzchar(task_errors))) {
  result$task_serialization_error <- paste(unique(task_errors[nzchar(task_errors)]), collapse = " | ")
}
print(result, row.names = FALSE, digits = 4)

if (!is.null(output)) utils::write.csv(result, output, row.names = FALSE)
