# Computes each catalogued dataset's covariate missingness: the % of rows that
# have at least one missing value among the COVARIATE columns only
# (treatment/w column and response outcome column(s) excluded), measured on
# the dataset's real data, not on the catalog metadata.
#
# Usage (from the repo root):
#   Rscript R/package_metadata/compute_covariate_missingness.R               # every row
#   Rscript R/package_metadata/compute_covariate_missingness.R --stale-only  # new, changed-pin and never-computed rows only
#
# Output: one sidecar per catalog, experimental_datasets_missingness.csv and
# observational_datasets_missingness.csv, with columns dataset, version,
# pct_missing_covariate_rows, n_covariate_cols_used, missingness_note. The
# catalog CSVs are never written here: build_*_datasets_csv.R regenerates them
# from the md and would drop any extra column. Join on `dataset` when needed.
# `version` is the catalog Version the value was computed from; --stale-only
# recomputes rows missing from the sidecar, whose catalog version differs, or
# that have no value yet (n_covariate_cols_used empty), and keeps the rest. Values come from the cached archives (unpacked to a temp dir;
# loose CSVs beside them are ignored), so after a pin change delete that
# dataset's cached <key>.tar.bz2 and download it again before recomputing, or
# the old release's data is measured again.
#
# Column-name resolution: the "tx (treatment column)"/"w (group column)" and
# outcome cells in the .md tables name real data.frame columns via backticks
# (one backtick span can hold several "/"-joined column names, e.g.
# "`dose / tank`"). Covariates = every other column actually present in the
# downloaded data. Any treatment/outcome name that does NOT match an actual
# column (typo, or the markdown cell described a derived/renamed quantity
# rather than a literal column) is logged as a resolution warning and simply
# left out of the exclusion set -- a conservative bias that would, if
# anything, UNDER-count missingness slightly by treating a stray
# treatment/outcome column as a covariate, never the other way round.
#
# Dataset-fetch strategy: experimental rows are read from the cached archives
# download_experimental_datasets.R writes (one <name>.tar.bz2 per
# DATASET_MANIFEST entry under randomized_experiment_datasets/); a row without
# one is reported, not downloaded. Observational rows use
# download_observational_datasets.R's cache (observational_datasets_cache/)
# and otherwise fetch the pinned release into a temp dir; the CRAN/GitHub
# fetchers find the named object in whichever data/ file holds it (a single
# survival cancer.rda holds veteran/ovarian/colon/..., so "file name ==
# object name" is often wrong).

suppressMessages({
  library(data.table)
})

# This file's folder as an absolute path, so it runs from any working directory, whether
# run with Rscript or source()d (also from inside another script): the innermost source()
# call's file wins, then Rscript's --file=, then R/package_metadata/ under the working directory.
THIS_DIR <- local({
  sourced <- Filter(is.character, lapply(rev(sys.frames()), function(f) f$ofile))
  file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
  dirname(normalizePath(c(unlist(sourced), file_arg, "R/package_metadata/compute_covariate_missingness.R")[[1L]], mustWork = TRUE))
})
source(file.path(THIS_DIR, "download_experimental_datasets.R"))
source(file.path(THIS_DIR, "build_experimental_datasets_csv.R"))  # for read_dataset_table()/strip_md()

WORK_DIR <- file.path(tempdir(), "covariate_missingness_work")
dir.create(WORK_DIR, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# Column-name extraction from a raw markdown cell (keeps backtick spans only;
# drops parenthetical comments automatically since they're outside backticks).
# ---------------------------------------------------------------------------
extract_backtick_columns <- function(cell) {
  spans <- regmatches(cell, gregexpr("`[^`]*`", cell))[[1]]
  spans <- gsub("`", "", spans)
  parts <- unlist(lapply(spans, function(s) trimws(strsplit(s, "/", fixed = TRUE)[[1]])))
  unique(parts[nzchar(parts)])
}

# All fetches use download_experimental_datasets.R's shared helpers (sourced above):
# cran_dataset_as_csv(), github_dataset_as_csv() and dataverse_file_as_csv(), with
# parse_dataverse_source() for the md's Dataverse Source cells.

# ---------------------------------------------------------------------------
# Covariate-missingness core: given the data.frame and the raw column names
# that are treatment/outcome, compute % of rows with >=1 NA among the rest.
# ---------------------------------------------------------------------------
covariate_missingness_pct <- function(df, exclude_cols) {
  covariate_cols <- setdiff(names(df), exclude_cols)
  if (length(covariate_cols) == 0L) return(list(pct = NA_real_, n_cov = 0L))
  sub <- df[, covariate_cols, drop = FALSE]
  # Per-column, not vectorized across columns: "col == ''" must never be
  # evaluated on a Date/POSIXct column (as.POSIXct("") errors outright
  # rather than returning NA, which previously crashed the whole run).
  na_mask <- sapply(sub, function(col) if (is.character(col)) is.na(col) | col == "" else is.na(col))
  if (is.null(dim(na_mask))) na_mask <- matrix(na_mask, ncol = length(covariate_cols))
  row_has_na <- apply(na_mask, 1, any)
  list(pct = round(100 * mean(row_has_na), 2), n_cov = length(covariate_cols))
}

resolve_exclude_cols <- function(dataset, treat_raw_cell, outcome_strs, data_cols) {
  wanted <- unique(c(extract_backtick_columns(treat_raw_cell), unlist(strsplit(outcome_strs[!is.na(outcome_strs)], "/", fixed = TRUE))))
  wanted <- trimws(wanted)
  missing <- setdiff(wanted, data_cols)
  if (length(missing) > 0L) {
    message("  [warn] ", dataset, ": treatment/outcome name(s) not found as literal columns, left as covariates: ",
            paste(missing, collapse = ", "))
  }
  intersect(wanted, data_cols)
}

# ---------------------------------------------------------------------------
# Sidecar files: <catalog>_missingness.csv next to each catalog CSV.
# ---------------------------------------------------------------------------
missingness_sidecar_path <- function(csv_path) sub("\\.csv$", "_missingness.csv", csv_path)

read_catalog_csv <- function(path) {
  read.csv(path, stringsAsFactors = FALSE, na.strings = "", colClasses = c(version = "character"))
}

# Which catalog rows to compute: all of them, or with stale_only only rows that
# are missing from the sidecar, whose catalog version differs from the version
# the sidecar value was computed from, or that were never computed (no cached
# archive, failed download, ...: n_covariate_cols_used is empty).
missingness_rows_to_compute <- function(csv, sidecar_path, stale_only) {
  if (!stale_only || !file.exists(sidecar_path)) return(rep(TRUE, nrow(csv)))
  old <- read_catalog_csv(sidecar_path)
  m <- match(csv$dataset, old$dataset)
  is.na(m) | !mapply(identical, old$version[m], csv$version) | is.na(old$n_covariate_cols_used[m])
}

# Writes the sidecar in catalog row order: computed rows take the new values,
# the others keep their sidecar values; datasets no longer in the catalog drop out.
write_missingness_sidecar <- function(csv, todo, pct, n_cov, note, sidecar_path) {
  out <- data.frame(dataset = csv$dataset, version = csv$version,
                    pct_missing_covariate_rows = pct, n_covariate_cols_used = n_cov,
                    missingness_note = note, stringsAsFactors = FALSE)
  if (any(!todo)) {
    old <- read_catalog_csv(sidecar_path)
    m <- match(csv$dataset[!todo], old$dataset)
    for (col in names(out)[-(1:2)]) out[[col]][!todo] <- old[[col]][m]
  }
  write.csv(out, sidecar_path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  message("wrote ", sidecar_path, " (", sum(todo), " of ", nrow(out), " rows computed)")
  invisible(out)
}

# Unpacks one CSV from a cached archive into a fresh scratch dir under WORK_DIR and
# returns its path. Never reads a loose CSV left beside the archive: that copy may
# predate a pin change.
untar_cached_csv <- function(archive_path, csv_name) {
  exdir <- tempfile("unpack_", tmpdir = WORK_DIR)
  utils::untar(archive_path, files = csv_name, exdir = exdir)
  file.path(exdir, csv_name)
}

# ---------------------------------------------------------------------------
# Experimental: read from the cached archives (one <name>.tar.bz2 per manifest
# entry, written by download_all_datasets()); nothing is downloaded here.
# ---------------------------------------------------------------------------
ARCHIVE_DIR <- file.path(THIS_DIR, "randomized_experiment_datasets")

# Mirrors the out_csv/combined_csv priority order download_all_datasets()
# itself uses when writing an entry's archive.
manifest_final_csv_name <- function(spec) {
  if (!is.null(spec$combine) && !is.null(spec$combined_csv)) return(spec$combined_csv)
  if (!is.null(spec$cran)) return(spec$cran$out_csv)
  if (!is.null(spec$github)) return(spec$github$out_csv)
  if (!is.null(spec$files) && length(spec$files) == 1L) return(spec$files[[1L]])
  if (!is.null(spec$zip_members) && length(spec$zip_members) == 1L) return(spec$zip_members[[1L]]$dest_csv)
  NA_character_
}

compute_experimental_missingness <- function(csv_path = file.path(THIS_DIR, "experimental_datasets.csv"),
                                             stale_only = FALSE) {
  csv <- read_catalog_csv(csv_path)
  sidecar_path <- missingness_sidecar_path(csv_path)
  todo <- missingness_rows_to_compute(csv, sidecar_path, stale_only)
  md_tbl <- read_dataset_table(file.path(THIS_DIR, "experimental_datasets.md"))
  treat_raw <- md_tbl[["tx (treatment column)"]]
  outcome_cols <- grep("^(primary|secondary|tertiary|outcome_[0-9]+)_outcome$", names(csv), value = TRUE)

  pct <- rep(NA_real_, nrow(csv)); n_cov <- rep(NA_integer_, nrow(csv)); note <- rep(NA_character_, nrow(csv))
  for (i in which(todo)) {
    name <- csv$dataset[i]
    manifest_key <- gsub("[^A-Za-z0-9_]", "_", gsub("::", "_", name, fixed = TRUE))
    spec <- DATASET_MANIFEST[[manifest_key]]
    if (is.null(spec) && !is.null(DATASET_MANIFEST[[name]])) { spec <- DATASET_MANIFEST[[name]]; manifest_key <- name }  # one manifest key (lalonde.exp) keeps its literal dot
    if (is.null(spec)) { note[i] <- "no manifest entry"; next }
    message("[", i, "/", nrow(csv), "] ", name)
    archive_path <- file.path(ARCHIVE_DIR, paste0(manifest_key, ".tar.bz2"))
    if (!file.exists(archive_path)) { note[i] <- "no cached archive"; next }
    csv_name <- manifest_final_csv_name(spec)
    if (is.na(csv_name)) { note[i] <- "ambiguous source, skipped"; next }
    dest_csv <- tryCatch(untar_cached_csv(archive_path, csv_name),
                         error = function(e) { note[i] <<- paste("extract failed:", conditionMessage(e)); NULL })
    if (is.null(dest_csv)) next
    if (!file.exists(dest_csv)) { note[i] <- "csv not found after extract"; next }
    df <- tryCatch(data.table::fread(dest_csv, data.table = FALSE), error = function(e) NULL)
    if (is.null(df)) { note[i] <- "csv read failed"; next }
    outcome_strs <- unlist(csv[i, outcome_cols])
    excl <- resolve_exclude_cols(name, treat_raw[i], outcome_strs, names(df))
    r <- covariate_missingness_pct(df, excl)
    pct[i] <- r$pct; n_cov[i] <- r$n_cov
    if (r$n_cov == 0L) note[i] <- "no covariate columns in dataset (only treatment/outcome columns present)"
  }
  write_missingness_sidecar(csv, todo, pct, n_cov, note, sidecar_path)
}

# ---------------------------------------------------------------------------
# Observational: no manifest -- each row's md Source/Version/Dataset cells say
# what to fetch; the fetchers find the object's data/ file.
# ---------------------------------------------------------------------------
compute_observational_missingness <- function(csv_path = file.path(THIS_DIR, "observational_datasets.csv"),
                                              stale_only = FALSE) {
  csv <- read_catalog_csv(csv_path)
  sidecar_path <- missingness_sidecar_path(csv_path)
  todo <- missingness_rows_to_compute(csv, sidecar_path, stale_only)
  md_tbl <- read_dataset_table(file.path(THIS_DIR, "observational_datasets.md"))
  treat_raw <- md_tbl[["w (group column)"]]
  obj_names <- sub("^.*::", "", sapply(md_tbl$Dataset, function(x) extract_backtick_columns(x)[1]))
  pkgs <- sub("^(CRAN|base R|GitHub): ", "", md_tbl$Source)
  is_base_r <- grepl("^base R:", md_tbl$Source)
  is_github <- grepl("^GitHub:", md_tbl$Source)
  is_dataverse <- grepl("^Dataverse:", md_tbl$Source)
  dv <- lapply(md_tbl$Source, parse_dataverse_source)
  versions <- sub("^commit `(.*)`$", "\\1", md_tbl$Version)
  outcome_cols <- grep("^(primary|secondary|tertiary|outcome_[0-9]+)_outcome$", names(csv), value = TRUE)

  obs_cache_dir <- file.path(THIS_DIR, "observational_datasets_cache")

  pct <- rep(NA_real_, nrow(csv)); n_cov <- rep(NA_integer_, nrow(csv)); note <- rep(NA_character_, nrow(csv))
  for (i in which(todo)) {
    name <- csv$dataset[i]
    message("[", i, "/", nrow(csv), "] ", name)
    df <- NULL
    if (is_base_r[i]) {
      df <- tryCatch(as.data.frame(get(obj_names[i], envir = asNamespace("datasets"))), error = function(e) NULL)
      if (is.null(df)) note[i] <- "base-R object lookup failed"
    } else {
      # Prefer the persistent cache (download_observational_datasets.R) over
      # a throwaway tempdir() fetch, so a second run of this script is free.
      archive_path <- file.path(obs_cache_dir, paste0(name, ".tar.bz2"))
      if (startsWith(md_tbl$Source[i], "ICPSR:")) {
        note[i] <- "ICPSR restricted-terms data: not cached, missingness not computed"
        next
      }
      dest_csv <- if (file.exists(archive_path)) untar_cached_csv(archive_path, paste0(name, ".csv")) else ""
      if (!file.exists(dest_csv)) {
        dest_csv <- file.path(WORK_DIR, paste0("obs_", gsub("[^A-Za-z0-9]", "_", name), ".csv"))
        ok <- tryCatch({
          if (is_github[i]) {
            github_dataset_as_csv(pkgs[i], versions[i], dest_csv, WORK_DIR, obj_name = obj_names[i])
          } else if (is_dataverse[i]) {
            dv_i <- dv[[i]]
            dataverse_file_as_csv(dv_i$doi, md_tbl$Version[i], dv_i$filename, dest_csv, WORK_DIR,
                                  inside_zip = if (is.na(dv_i$inside_zip)) NULL else dv_i$inside_zip,
                                  credentials_dir = obs_cache_dir)
          } else {
            cran_dataset_as_csv(pkgs[i], versions[i], dest_csv, WORK_DIR, obj_name = obj_names[i])
          }
          TRUE
        }, error = function(e) { note[i] <<- paste("download failed:", conditionMessage(e)); FALSE })
        if (!ok) next
      }
      df <- tryCatch(data.table::fread(dest_csv, data.table = FALSE), error = function(e) NULL)
      if (is.null(df)) { note[i] <- "csv read failed"; next }
    }
    if (is.null(df)) next
    outcome_strs <- unlist(csv[i, outcome_cols])
    excl <- resolve_exclude_cols(name, treat_raw[i], outcome_strs, names(df))
    r <- covariate_missingness_pct(df, excl)
    pct[i] <- r$pct; n_cov[i] <- r$n_cov
    if (r$n_cov == 0L) note[i] <- "no covariate columns in dataset (only treatment/outcome columns present)"
  }
  write_missingness_sidecar(csv, todo, pct, n_cov, note, sidecar_path)
}

if (sys.nframe() == 0L) {
  stale_only <- "--stale-only" %in% commandArgs(trailingOnly = TRUE)
  message("=== Observational ===")
  obs <- compute_observational_missingness(stale_only = stale_only)
  message("done: ", sum(!is.na(obs$pct_missing_covariate_rows)), "/", nrow(obs), " resolved")

  message("\n=== Experimental ===")
  exp <- compute_experimental_missingness(stale_only = stale_only)
  message("done: ", sum(!is.na(exp$pct_missing_covariate_rows)), "/", nrow(exp), " resolved")
}
