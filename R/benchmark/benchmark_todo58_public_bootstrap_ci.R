# Focused public-path evidence for release v1.0.5 TODO-58/TODO-6.
#
# This script only loads an installed EDI package; it never sources the
# checkout or compiles code. See --help for the two independent modes:
#   benchmark <new-output.csv>
#   dump-parity <expected-EDI-version> <new-output.rds>
#   compare-parity <EDI-1.0.2.rds> <current-EDI.rds>

args <- commandArgs(trailingOnly = TRUE)
script_file <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grepl("^--file=", commandArgs(trailingOnly = FALSE))][1L])
repo_root <- normalizePath(file.path(dirname(script_file), "../.."), winslash = "/", mustWork = TRUE)

usage <- function() {
  cat(paste(
    "Usage:",
    "  Rscript R/benchmark/benchmark_todo58_public_bootstrap_ci.R benchmark <new-output.csv>",
    "  EDI_LIB=/path/to/library Rscript R/benchmark/benchmark_todo58_public_bootstrap_ci.R dump-parity <expected-version> <new-output.rds>",
    "  Rscript R/benchmark/benchmark_todo58_public_bootstrap_ci.R compare-parity <EDI-1.0.2.rds> <current-EDI.rds>",
    "",
    "benchmark runs only the three TODO-58 public percentile-CI rows, at their original B,",
    "with ten alternating EDI/boot samples. dump-parity is run separately for EDI 1.0.2",
    "and the current installed package; set EDI_LIB to select each library. Output paths",
    "must be new so existing or canonical artifacts cannot be overwritten.",
    sep = "\n"
  ))
}

if (!length(args) || args[[1L]] %in% c("-h", "--help", "help")) {
  usage()
  quit(status = if (length(args)) 0L else 2L)
}

mode <- args[[1L]]
if (identical(mode, "compare-parity")) {
  if (length(args) != 3L) stop("compare-parity requires two RDS paths.", call. = FALSE)
  old <- readRDS(args[[2L]])
  current <- readRDS(args[[3L]])
  if (!identical(old$package_version, "1.0.2")) {
    stop("The first parity artifact must come from installed EDI 1.0.2.", call. = FALSE)
  }
  if (identical(current$package_version, "1.0.2")) {
    stop("The second parity artifact must come from the current installed EDI.", call. = FALSE)
  }
  if (!identical(old$case_keys, current$case_keys)) {
    stop("Parity artifacts differ in fixtures, seeds, or B.", call. = FALSE)
  }
  comparisons <- lapply(seq_along(old$cases), function(i) {
    x <- old$cases[[i]]$distribution
    y <- current$cases[[i]]$distribution
    if (length(x) != length(y) || !identical(is.finite(x), is.finite(y))) {
      stop("Distribution length or finite-value pattern differs for ", old$case_keys[[i]], call. = FALSE)
    }
    finite <- is.finite(x)
    max_abs_diff <- if (any(finite)) max(abs(x[finite] - y[finite])) else NA_real_
    data.frame(case = old$case_keys[[i]], finite_n = sum(finite), max_abs_diff = max_abs_diff)
  })
  result <- do.call(rbind, comparisons)
  print(result, row.names = FALSE)
  if (any(!is.finite(result$max_abs_diff)) || any(result$max_abs_diff > 1e-10)) {
    stop("Fixed-seed distribution parity failed the 1e-10 TODO-3 tolerance.", call. = FALSE)
  }
  quit(status = 0L)
}

if (!mode %in% c("benchmark", "dump-parity")) {
  usage()
  stop("Unknown mode: ", mode, call. = FALSE)
}

if (identical(mode, "benchmark")) {
  if (length(args) != 2L) stop("benchmark requires one new CSV output path.", call. = FALSE)
  output_path <- args[[2L]]
  expected_version <- NULL
} else {
  if (length(args) != 3L) stop("dump-parity requires expected version and new RDS output path.", call. = FALSE)
  expected_version <- args[[2L]]
  output_path <- args[[3L]]
}

if (file.exists(output_path)) stop("Refusing to overwrite existing output: ", output_path, call. = FALSE)
output_parent <- normalizePath(dirname(output_path), winslash = "/", mustWork = TRUE)
output_path <- file.path(output_parent, basename(output_path))
if (startsWith(output_path, paste0(repo_root, "/R/package_metadata/"))) {
  stop("Benchmark evidence must not be written into canonical package metadata.", call. = FALSE)
}

edi_lib <- Sys.getenv("EDI_LIB", unset = "")
if (nzchar(edi_lib)) {
  if (!dir.exists(edi_lib)) stop("EDI_LIB is not a directory: ", edi_lib, call. = FALSE)
  .libPaths(c(normalizePath(edi_lib, winslash = "/", mustWork = TRUE), .libPaths()))
}
compiler::enableJIT(0L)
suppressPackageStartupMessages(library(EDI))
suppressPackageStartupMessages(library(boot))
suppressPackageStartupMessages(library(survival))
edi_path <- normalizePath(find.package("EDI"), winslash = "/", mustWork = TRUE)
if (startsWith(edi_path, paste0(repo_root, "/R/EDI"))) {
  stop("This evidence driver must use an installed EDI package, not the checkout.", call. = FALSE)
}
edi_version <- as.character(utils::packageVersion("EDI"))
loaded_edi_dll_path <- function() {
  dlls <- getLoadedDLLs()
  dll_paths <- vapply(dlls, function(dll) {
    tryCatch(as.character(dll[["path"]]), error = function(e) "")
  }, character(1L))
  is_edi <- grepl("(^|[/\\\\])EDI\\.(so|dylib|dll)$", dll_paths, ignore.case = TRUE)
  paths <- dll_paths[is_edi & nzchar(dll_paths)]
  if (!length(paths)) return("<unavailable>")
  tryCatch(normalizePath(paths[[1L]], winslash = "/", mustWork = TRUE),
           error = function(e) "<unavailable>")
}
sha256_file <- function(path) {
  if (length(path) != 1L || is.na(path) || !file.exists(path)) return("<unavailable>")
  commands <- list(
    list(command = Sys.which("sha256sum"), args = character()),
    list(command = Sys.which("shasum"), args = c("-a", "256")),
    list(command = Sys.which("openssl"), args = c("dgst", "-sha256")),
    list(command = Sys.which("certutil"), args = c("-hashfile", shQuote(path), "SHA256"))
  )
  for (entry in commands) {
    if (!nzchar(entry$command)) next
    args <- c(entry$args, if (!identical(entry$command, Sys.which("certutil"))) shQuote(path))
    output <- tryCatch(system2(entry$command, args = args, stdout = TRUE, stderr = FALSE),
                       error = function(e) character())
    status <- attr(output, "status")
    if (!length(output) || (!is.null(status) && !identical(as.integer(status), 0L))) next
    hashes <- regmatches(output, gregexpr("[[:xdigit:]]{64}", output, perl = TRUE))
    hashes <- tolower(unlist(hashes, use.names = FALSE))
    if (length(hashes)) return(hashes[[1L]])
  }
  "<unavailable>"
}
edi_dll_path <- loaded_edi_dll_path()
edi_dll_sha256 <- sha256_file(edi_dll_path)
if (!is.null(expected_version) && !identical(edi_version, expected_version)) {
  stop("Expected EDI ", expected_version, " but loaded ", edi_version, " from ", edi_path, call. = FALSE)
}
cat("Installed EDI", edi_version, "from", edi_path,
    "(DLL:", edi_dll_path, "; SHA-256:", edi_dll_sha256, ")\n")

seed_for_class <- function(label) {
  codes <- utf8ToInt(label)
  as.integer(sum(codes * seq_along(codes)) %% 2147483647)
}

cases <- list(
  list(key = "OLS", fixture = "continuous", response = "continuous", n = 1000L, B = 1000L,
       row = "Nonparametric bootstrap CI: OLS (B = 1000) [R6 InferenceContinOLS]",
       canonical = "boot(lm.fit)+boot.ci(perc)", class = InferenceContinOLS),
  list(key = "logistic", fixture = "incidence", response = "incidence", n = 1000L, B = 500L,
       row = "Nonparametric bootstrap CI: logistic regression (B = 500) [R6 InferenceIncidLogRegr]",
       canonical = "boot(glm.fit)+boot.ci(perc)", class = InferenceIncidLogRegr),
  list(key = "Cox", fixture = "survival", response = "survival", n = 500L, B = 500L,
       row = "Nonparametric bootstrap CI: Cox PH (B = 500, n = 500) [R6 InferenceSurvivalCoxPHRegr]",
       canonical = "boot(coxph.fit)+boot.ci(perc)", class = InferenceSurvivalCoxPHRegr)
)
for (i in seq_along(cases)) {
  cases[[i]]$fixture_seed <- seed_for_class(paste("Procedure", cases[[i]]$fixture))
  cases[[i]]$row_seed <- seed_for_class(paste(cases[[i]]$row, "boot", cases[[i]]$canonical))
}
case_keys <- vapply(cases, function(x) paste(x$key, x$n, x$B, x$fixture_seed, x$row_seed, sep = "|"), character(1L))

generate_data <- function(n, p = 5L, family) {
  X <- matrix(stats::rnorm(n * p), n, p)
  X[, 1L] <- 1
  beta <- stats::rnorm(p) * 0.5
  n_treat <- floor(n / 2)
  w <- sample(c(rep(1, n_treat), rep(0, n - n_treat)))
  eta <- drop(X %*% beta + 0.5 * w)
  out <- list(X = X, w = w)
  if (identical(family, "logistic")) {
    out$y <- stats::rbinom(n, 1L, stats::plogis(eta))
  } else if (identical(family, "cox")) {
    out$y <- stats::rexp(n, exp(eta))
    out$dead <- stats::rbinom(n, 1L, 0.8)
  } else {
    out$y <- as.numeric(eta + stats::rnorm(n, 0, 0.5))
  }
  out
}

build_case <- function(spec) {
  set.seed(spec$fixture_seed)
  d <- generate_data(spec$n, family = switch(spec$fixture,
    continuous = "continuous", incidence = "logistic", survival = "cox"
  ))
  X_cov <- as.data.frame(d$X[, -1L, drop = FALSE])
  names(X_cov) <- paste0("x", seq_len(ncol(X_cov)))
  des <- DesignFixediBCRD$new(n = spec$n, response_type = spec$response)
  des$add_all_subjects_to_experiment(X_cov)
  des$assign_w_to_all_subjects(as.numeric(d$w))
  if (identical(spec$response, "survival")) {
    des$add_all_subject_responses(
      ifelse(d$dead == 1L, d$y, NA_real_),
      y_Ls = ifelse(d$dead == 0L, d$y, NA_real_),
      y_Rs = ifelse(d$dead == 0L, Inf, NA_real_)
    )
  } else {
    des$add_all_subject_responses(as.numeric(d$y))
  }
  X_full <- cbind(`(Intercept)` = 1, treatment = as.numeric(d$w), as.matrix(X_cov))
  X_ord <- cbind(treatment = as.numeric(d$w), as.matrix(X_cov))
  df <- cbind(data.frame(y = as.numeric(d$y), treatment = as.integer(d$w),
                         Z = as.integer(d$w), dead = if (!is.null(d$dead)) d$dead else 1L), X_cov)
  list(design = des, d = d, df = df, X_full = X_full, X_ord = X_ord)
}

new_inference <- function(spec, fixture) {
  inference <- spec$class$new(fixture$design)
  inference$num_cores <- 1L
  inference
}

run_edi_ci <- function(spec, fixture, seed) {
  set.seed(seed)
  construction_ms <- system.time(inference <- new_inference(spec, fixture))[["elapsed"]] * 1000
  # This is the same public call used by benchmark_model_fits.R. The fresh
  # object is outside the procedure timer so the two columns remain separate.
  elapsed <- system.time(
    ci <- inference$compute_bootstrap_confidence_interval(
      B = spec$B, type = "percentile", show_progress = FALSE
    )
  )[["elapsed"]] * 1000
  list(ci = as.numeric(ci[1:2]), construction_ms = construction_ms, elapsed_ms = elapsed)
}

run_boot_ci <- function(spec, fixture, seed) {
  d <- fixture$d
  df <- fixture$df
  X_full <- fixture$X_full
  X_ord <- fixture$X_ord
  set.seed(seed)
  elapsed <- system.time({
    if (identical(spec$key, "OLS")) {
      bo <- boot::boot(df, function(dd, i) stats::lm.fit(X_full[i, , drop = FALSE], dd$y[i])$coefficients[2L], R = spec$B)
    } else if (identical(spec$key, "logistic")) {
      bo <- boot::boot(df, function(dd, i) stats::glm.fit(X_full[i, , drop = FALSE], dd$y[i], family = stats::binomial())$coefficients[2L], R = spec$B)
    } else {
      bo <- boot::boot(df, function(dd, i) survival::coxph.fit(
        x = X_ord[i, , drop = FALSE],
        y = survival::Surv(dd$y[i], dd$dead[i]), strata = NULL, offset = NULL, init = NULL,
        control = survival::coxph.control(), weights = NULL, method = "breslow",
        rownames = as.character(seq_along(i))
      )$coefficients[1L], R = spec$B)
    }
    ci <- boot::boot.ci(bo, type = "perc")$percent[4:5]
  })[["elapsed"]] * 1000
  list(ci = as.numeric(ci), elapsed_ms = elapsed)
}

if (identical(mode, "dump-parity")) {
  results <- lapply(cases, function(spec) {
    fixture <- build_case(spec)
    set.seed(spec$row_seed)
    inference <- new_inference(spec, fixture)
    distribution <- as.numeric(inference$approximate_bootstrap_distribution_beta_hat_T(
      B = spec$B, show_progress = FALSE
    ))
    list(key = spec$key, n = spec$n, B = spec$B, fixture_seed = spec$fixture_seed,
         row_seed = spec$row_seed, distribution = distribution)
  })
  saveRDS(list(package_version = edi_version, package_path = edi_path,
               edi_dll_path = edi_dll_path, edi_dll_sha256 = edi_dll_sha256,
               case_keys = case_keys, cases = results), output_path)
  cat("Wrote installed-package parity dump:", output_path, "\n")
  quit(status = 0L)
}

rows <- vector("list", length(cases) * 10L)
row_i <- 0L
for (i in seq_along(cases)) {
  spec <- cases[[i]]
  fixture <- build_case(spec)
  # Unrecorded warmups; measured samples below still use fresh inference objects.
  invisible(run_edi_ci(spec, fixture, spec$row_seed))
  invisible(run_boot_ci(spec, fixture, spec$row_seed))
  for (sample_id in seq_len(10L)) {
    row_i <- row_i + 1L
    # Match the exact row seed recorded in the canonical benchmark plan. Both
    # sides restart from it for each timing pair; timing parity does not assume
    # that the two implementations consume identical bootstrap indices.
    seed <- spec$row_seed
    if (sample_id %% 2L == 1L) {
      edi <- run_edi_ci(spec, fixture, seed)
      canonical <- run_boot_ci(spec, fixture, seed)
    } else {
      canonical <- run_boot_ci(spec, fixture, seed)
      edi <- run_edi_ci(spec, fixture, seed)
    }
    rows[[row_i]] <- data.frame(
      case = spec$key, sample = sample_id, n = spec$n, B = spec$B,
      EDI_package_version = edi_version, EDI_package_path = edi_path,
      EDI_dll_path = edi_dll_path, EDI_dll_sha256 = edi_dll_sha256,
      fixture_seed = spec$fixture_seed, row_seed = seed,
      EDI_CI_lower = edi$ci[1L], EDI_CI_upper = edi$ci[2L],
      EDI_construction_ms = edi$construction_ms,
      EDI_procedure_ms = edi$elapsed_ms, boot_CI_lower = canonical$ci[1L],
      boot_CI_upper = canonical$ci[2L], boot_complete_ms = canonical$elapsed_ms,
      speedup = canonical$elapsed_ms / edi$elapsed_ms
    )
    cat(sprintf("%s sample %02d/10: EDI %.1f ms, boot %.1f ms, speedup %.3fx\n",
                spec$key, sample_id, edi$elapsed_ms, canonical$elapsed_ms,
                canonical$elapsed_ms / edi$elapsed_ms))
  }
}
result <- do.call(rbind, rows)
utils::write.csv(result, output_path, row.names = FALSE)
summary <- aggregate(speedup ~ case, data = result, FUN = stats::median)
cat("Median current speed ratios (boot complete time / EDI public R6 procedure):\n")
print(summary, row.names = FALSE)
cat("Wrote isolated timing samples:", output_path, "\n")
if (any(!is.finite(summary$speedup)) || any(summary$speedup < 1)) {
  stop("TODO-6 current-speed acceptance failed: at least one row is below 1x boot.", call. = FALSE)
}
