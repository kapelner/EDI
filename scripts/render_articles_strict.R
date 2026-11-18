#!/usr/bin/env Rscript
# Strict article render gate (v1.0.6-TODO-99): renders each given .Rmd (the
# package vignettes and the pkgdown-only articles under vignettes/articles/)
# and fails if any chunk prints a warning or an error, so the workflows the
# articles document keep working. Run by .github/workflows/articles-strict.yml;
# not part of scripts/pre-push (the hook stays lean).
#
# Usage (from the repo root):
#   Rscript scripts/render_articles_strict.R [options] [FILE.Rmd ...]
#
#   With no files, renders R/EDI/vignettes/*.Rmd and R/EDI/vignettes/articles/*.Rmd.
#
# Options:
#   --load-all[=PKG_DIR]  load EDI from source with
#                         pkgload::load_all(PKG_DIR, compile = FALSE) in each
#                         render process instead of using the installed EDI
#                         (PKG_DIR defaults to R/EDI). Never compiles: the
#                         source tree's EDI.so must already exist.
#   --workers=N           render up to N files at once (default 1, capped at 2).
#   --timeout=SECS        fail a file whose render takes longer (default 900).
#   --out-dir=DIR         where the HTML and intermediates go (default: a new
#                         temporary directory). Nothing is written next to the
#                         .Rmd files.
#
# What counts as a failure, per file:
#   * a chunk whose output shows a warning or an error (caught through knitr's
#     `warning`/`error` output hooks; a chunk with `warning = FALSE` hides its
#     warnings on purpose and is not counted; a chunk with
#     `strict_expect_warning = TRUE` shows one on purpose, so its warnings are
#     not counted either, but it fails if it shows none);
#   * a warning raised outside the chunk output (inline `r` code, the render
#     itself);
#   * the render stopping with an error, or running past --timeout.
# Messages are not failures.
#
# Prints one line per file (time, PASS/FAIL, and each warning/error), a
# summary table, and appends a Markdown table to $GITHUB_STEP_SUMMARY when
# that is set. Exits 1 if any file fails.

main = function(argv) {
  opts = list(load_all = NA_character_, workers = 1L, timeout = 900, out_dir = NA_character_)
  files = character()
  for (a in argv) {
    if (a == "--load-all") {
      opts$load_all = "R/EDI"
    } else if (startsWith(a, "--load-all=")) {
      opts$load_all = sub("^--load-all=", "", a)
    } else if (startsWith(a, "--workers=")) {
      opts$workers = as.integer(sub("^--workers=", "", a))
    } else if (startsWith(a, "--timeout=")) {
      opts$timeout = as.numeric(sub("^--timeout=", "", a))
    } else if (startsWith(a, "--out-dir=")) {
      opts$out_dir = sub("^--out-dir=", "", a)
    } else if (a %in% c("-h", "--help")) {
      cat(readLines(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))[2:34],
          sep = "\n")
      return(invisible(0L))
    } else if (startsWith(a, "--")) {
      stop("Unknown option: ", a)
    } else {
      files = c(files, a)
    }
  }
  if (length(files) == 0L) {
    files = c(Sys.glob("R/EDI/vignettes/*.Rmd"), Sys.glob("R/EDI/vignettes/articles/*.Rmd"))
  }
  if (length(files) == 0L) stop("No .Rmd files to render (run from the repo root or pass files).")
  missing = files[!file.exists(files)]
  if (length(missing)) stop("Not found: ", paste(missing, collapse = ", "))
  files = normalizePath(files)
  if (is.na(opts$workers) || opts$workers < 1L) opts$workers = 1L
  opts$workers = min(opts$workers, 2L)
  if (!is.na(opts$load_all)) {
    opts$load_all = normalizePath(opts$load_all, mustWork = TRUE)
  }
  if (is.na(opts$out_dir)) opts$out_dir = tempfile("articles_strict_")
  dir.create(opts$out_dir, recursive = TRUE, showWarnings = FALSE)
  opts$out_dir = normalizePath(opts$out_dir)

  for (p in c("callr", "rmarkdown", "knitr")) {
    if (!requireNamespace(p, quietly = TRUE)) stop("Package '", p, "' is required.")
  }
  cat(sprintf("Rendering %d file(s) with %d worker(s); EDI from %s; output in %s\n",
              length(files), opts$workers,
              if (is.na(opts$load_all)) "the installed package" else paste0("source (", opts$load_all, ")"),
              opts$out_dir))

  results = run_all(files, opts)
  report(results)
  if (any(results$status != "PASS")) 1L else 0L
}

# Runs in a fresh R process per file (callr), so one article's state, options
# or attached packages never reach another.
render_one = function(input, out_dir, load_all_dir) {
  problems = character()
  add = function(kind, text) {
    text = trimws(gsub("\\s+", " ", paste(text, collapse = " ")))
    problems <<- c(problems, paste0(kind, ": ", substr(text, 1L, 300L)))
  }
  if (!is.na(load_all_dir)) {
    suppressMessages(pkgload::load_all(load_all_dir, compile = FALSE, quiet = TRUE,
                                       export_all = FALSE, helpers = FALSE))
  }
  fmt = rmarkdown::resolve_output_format(input)
  base = knitr::hooks_markdown()
  prev_warning = fmt$knitr$knit_hooks$warning
  prev_error = fmt$knitr$knit_hooks$error
  if (is.null(prev_warning)) prev_warning = base$warning
  if (is.null(prev_error)) prev_error = base$error
  label = function(options) if (is.null(options$label)) "?" else options$label
  # Opt-out: a chunk with `strict_expect_warning = TRUE` shows a warning on
  # purpose (e.g. to teach what it means). Its warnings don't fail the file,
  # but the chunk must still warn: if the warning goes away, the prose around
  # it is stale, so that fails instead. Errors are never opted out.
  warned = character()
  fmt$knitr$knit_hooks$warning = function(x, options) {
    if (isTRUE(options$strict_expect_warning)) {
      warned <<- union(warned, label(options))
    } else {
      add(sprintf("warning in chunk '%s'", label(options)), x)
    }
    prev_warning(x, options)
  }
  fmt$knitr$knit_hooks$strict_expect_warning = function(before, options) {
    if (!before && isTRUE(options$strict_expect_warning) && !(label(options) %in% warned)) {
      add(sprintf("chunk '%s' has strict_expect_warning = TRUE but showed no warning", label(options)),
          "remove the option or update the text")
    }
    NULL
  }
  fmt$knitr$knit_hooks$error = function(x, options) {
    add(sprintf("error in chunk '%s'", label(options)), x)
    prev_error(x, options)
  }
  stem = tools::file_path_sans_ext(basename(input))
  inter = file.path(out_dir, paste0(stem, "_intermediates"))
  dir.create(inter, recursive = TRUE, showWarnings = FALSE)
  t0 = Sys.time()
  err = tryCatch({
    withCallingHandlers(
      rmarkdown::render(input, output_format = fmt, output_dir = out_dir,
                        intermediates_dir = inter, knit_root_dir = dirname(input),
                        envir = new.env(parent = globalenv()), quiet = TRUE),
      warning = function(w) {
        add("warning outside chunk output", conditionMessage(w))
        invokeRestart("muffleWarning")
      })
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(err)) add("render stopped with an error", err)
  list(seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")), problems = problems)
}

run_all = function(files, opts) {
  n = length(files)
  res = data.frame(file = files, seconds = NA_real_, status = NA_character_, stringsAsFactors = FALSE)
  res$problems = vector("list", n)
  # Largest files first: the slow articles are the long ones, and starting them
  # early keeps the two workers busy until the end instead of one finishing a
  # long render alone.
  queue = order(-file.size(files))
  running = list()
  start_job = function(i) {
    proc = callr::r_bg(render_one,
                       args = list(input = files[i], out_dir = opts$out_dir, load_all_dir = opts$load_all),
                       stdout = file.path(opts$out_dir, paste0(basename(files[i]), ".stdout.log")),
                       stderr = file.path(opts$out_dir, paste0(basename(files[i]), ".stderr.log")),
                       supervise = TRUE)
    list(i = i, proc = proc, t0 = Sys.time())
  }
  finish = function(job, timed_out = FALSE) {
    i = job$i
    secs = as.numeric(difftime(Sys.time(), job$t0, units = "secs"))
    if (timed_out) {
      job$proc$kill()
      out = list(seconds = secs, problems = sprintf("timed out after %.0f s", opts$timeout))
    } else {
      out = tryCatch(job$proc$get_result(), error = function(e) {
        msg = conditionMessage(e)
        if (!is.null(e$parent)) msg = paste(msg, conditionMessage(e$parent))
        list(seconds = secs, problems = paste("render process failed:", msg))
      })
    }
    res$seconds[i] <<- out$seconds
    res$problems[[i]] <<- out$problems
    res$status[i] <<- if (length(out$problems)) "FAIL" else "PASS"
    cat(sprintf("[%6.1f s] %s  %s\n", out$seconds, res$status[i], rel_path(files[i])))
    for (p in out$problems) cat("           - ", p, "\n", sep = "")
    flush(stdout())
  }
  while (length(queue) || length(running)) {
    while (length(running) < opts$workers && length(queue)) {
      running[[length(running) + 1L]] = start_job(queue[1L])
      queue = queue[-1L]
    }
    Sys.sleep(0.2)
    keep = logical(length(running))
    for (k in seq_along(running)) {
      job = running[[k]]
      elapsed = as.numeric(difftime(Sys.time(), job$t0, units = "secs"))
      if (!job$proc$is_alive()) {
        finish(job)
      } else if (elapsed > opts$timeout) {
        finish(job, timed_out = TRUE)
      } else {
        keep[k] = TRUE
      }
    }
    running = running[keep]
  }
  res
}

rel_path = function(f) {
  wd = paste0(normalizePath(getwd()), .Platform$file.sep)
  if (startsWith(f, wd)) substring(f, nchar(wd) + 1L) else f
}

report = function(res) {
  res = res[order(-res$seconds), ]
  cat("\n==== Strict article render summary ====\n")
  for (r in seq_len(nrow(res))) {
    cat(sprintf("  %-4s %7.1f s  %s\n", res$status[r], res$seconds[r], rel_path(res$file[r])))
  }
  n_fail = sum(res$status != "PASS")
  cat(sprintf("%d file(s), %d failed, %.1f s of render time in total\n",
              nrow(res), n_fail, sum(res$seconds, na.rm = TRUE)))
  summary_file = Sys.getenv("GITHUB_STEP_SUMMARY")
  if (nzchar(summary_file)) {
    esc = function(s) gsub("|", "\\|", gsub("\n", " ", s), fixed = TRUE)
    lines = c("## Strict article render", "",
              sprintf("%d file(s), %d failed.", nrow(res), n_fail), "",
              "| file | time (s) | result | problems |", "|---|---:|---|---|")
    for (r in seq_len(nrow(res))) {
      probs = res$problems[[r]]
      lines = c(lines, sprintf("| `%s` | %.1f | %s | %s |", rel_path(res$file[r]), res$seconds[r],
                               res$status[r], esc(paste(probs, collapse = "<br>"))))
    }
    cat(lines, file = summary_file, sep = "\n", append = TRUE)
  }
}

quit(status = main(commandArgs(trailingOnly = TRUE)))
