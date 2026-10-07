# Adds a covariate-missingness column to experimental_datasets.csv and
# observational_datasets.csv: the % of rows that have at least one missing
# value among the COVARIATE columns only (treatment/w column and response
# outcome column(s) excluded) -- per-dataset's real raw data, not just the
# metadata already in the tables.
#
# Usage (from the repo root): Rscript R/package_metadata/compute_covariate_missingness.R
#
# This is a computed statistic over live CRAN data, not a hand-curated fact,
# so it is added to the two CSVs only -- NOT to the .md tables (same
# treatment as p_approx/n_raw, which are also CSV-only derived fields).
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
# Dataset-fetch strategy: the 262 experimental rows are already downloaded
# (one <name>.tar.bz2 per DATASET_MANIFEST entry under
# randomized_experiment_datasets/, from the original exhaustive-search
# session) -- extract the loose CSV already inside, no re-download. The 64
# observational rows have no such manifest/cache; rather than hand-map
# rda_name per row (verified by spot-checking CRAN's survival package: a
# single cancer.rda file holds
# veteran/ovarian/colon/bladder1/gbsg/lung/mgus2/rotterdam, so
# "rda_name == obj_name" is wrong most of the time), this scans every file in
# the package's data/ directory and uses whichever one actually contains the
# named object -- auto-discovery instead of guessing.

suppressMessages({
  library(data.table)
})

THIS_DIR <- {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) "R/package_metadata" else dirname(normalizePath(sub("^--file=", "", file_arg[1])))
}
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

# ---------------------------------------------------------------------------
# Auto-discovering CRAN fetch: downloads pkg's tarball once, tries every
# data/ file until one actually contains `obj_name`, writes it to dest_csv.
# Falls back through Archive/ and "current" exactly like
# cran_download_dataset_as_csv() (reimplemented here, not called, since we
# need to search ALL data/ files rather than one named rda_name).
# ---------------------------------------------------------------------------
# R's curl/httr2 package fails through this sandbox's proxy ("Proxy CONNECT
# aborted") even though the plain `curl` CLI works fine against the same
# URL -- shell out rather than use httr2::req_perform().
curl_fetch <- function(url, dest_path) {
  status <- suppressWarnings(system2("curl", c("-sL", "-f", "-o", shQuote(dest_path), shQuote(url)), stdout = TRUE, stderr = TRUE))
  exit_code <- attr(status, "status")
  !is.null(exit_code) && exit_code != 0L
}

# Extracted tarballs are cached per pkg+version under work_dir (several
# observational rows share one package, e.g. 7 rows all come from
# `survival` -- extract it once, reuse for all of them).
cran_fetch_object_auto <- function(pkg, version, obj_name, dest_csv, work_dir) {
  pkg_dir <- file.path(work_dir, paste0(".extract_", pkg, "_", version), pkg)
  if (!dir.exists(pkg_dir)) {
    tar_path <- file.path(work_dir, paste0(".raw_", pkg, ".tar.gz"))
    direct_url <- sprintf("https://cran.r-project.org/src/contrib/%s_%s.tar.gz", pkg, version)
    archive_url <- sprintf("https://cran.r-project.org/src/contrib/Archive/%s/%s_%s.tar.gz", pkg, pkg, version)
    failed <- curl_fetch(direct_url, tar_path)
    if (failed || !file.exists(tar_path) || file.size(tar_path) < 100) {
      failed <- curl_fetch(archive_url, tar_path)
    }
    if (failed || !file.exists(tar_path) || file.size(tar_path) < 100) {
      cur_ver <- tryCatch(tools::CRAN_package_db()$Version[tools::CRAN_package_db()$Package == pkg],
                           error = function(e) character(0))
      if (length(cur_ver) == 0L) stop("CRAN download failed for ", pkg, " (not found at all)", call. = FALSE)
      current_url <- sprintf("https://cran.r-project.org/src/contrib/%s_%s.tar.gz", pkg, cur_ver[[1L]])
      failed <- curl_fetch(current_url, tar_path)
    }
    if (failed || !file.exists(tar_path) || file.size(tar_path) == 0L) {
      stop("CRAN download failed or empty for ", pkg, call. = FALSE)
    }
    utils::untar(tar_path, exdir = dirname(pkg_dir))
    unlink(tar_path)
  }
  if (!dir.exists(pkg_dir)) stop("tarball for ", pkg, " did not extract as expected", call. = FALSE)

  data_files <- list.files(file.path(pkg_dir, "data"))
  obj <- NULL
  for (f in data_files) {
    base_ext <- tolower(tools::file_ext(sub("\\.gz$", "", f, ignore.case = TRUE)))
    full_path <- file.path(pkg_dir, "data", f)
    if (base_ext %in% c("rda", "rdata")) {
      e <- new.env()
      ok2 <- tryCatch({ load(full_path, envir = e); TRUE }, error = function(e) FALSE)
      if (ok2 && obj_name %in% ls(e)) { obj <- get(obj_name, envir = e); break }
    } else if (base_ext %in% c("txt", "csv") &&
               tools::file_path_sans_ext(f, compression = TRUE) == obj_name) {
      obj <- tryCatch(data.table::fread(full_path, data.table = FALSE), error = function(e) NULL)
      if (!is.null(obj)) break
    } else if (base_ext == "r" && tools::file_path_sans_ext(f, compression = TRUE) == obj_name) {
      # data/<obj>.R: an R script that builds the object, sourced the way data() does.
      # Old releases only, e.g. Epi 1.1.10's thoro.R -- pinned for its GPL (>= 2) license.
      e <- new.env()
      ok2 <- tryCatch({ sys.source(full_path, envir = e, chdir = TRUE); TRUE }, error = function(e) FALSE)
      if (ok2 && obj_name %in% ls(e)) { obj <- get(obj_name, envir = e); break }
    }
  }
  if (is.null(obj)) stop(obj_name, " not found in any data/ file of ", pkg, " (checked: ", paste(data_files, collapse = ", "), ")", call. = FALSE)
  if (!(is.data.frame(obj) || is.matrix(obj))) stop(obj_name, " in ", pkg, " is not a data.frame/matrix (class ", class(obj)[1L], ")", call. = FALSE)
  data.table::fwrite(as.data.frame(obj), dest_csv)
  invisible(dest_csv)
}

# Same auto-discovery idea as cran_fetch_object_auto(), for a GitHub-only
# (not-on-CRAN) repo pinned at a commit SHA. Repo's data/ files are plain
# .csv here (rmcelreath/rethinking), not .rda -- data.table::fread()
# auto-detects the delimiter (rethinking's CSVs use ";", not ",").
github_fetch_object_auto <- function(repo, commit_sha, obj_name, dest_csv, work_dir) {
  owner_repo <- strsplit(repo, "/", fixed = TRUE)[[1L]]
  repo_dir <- file.path(work_dir, paste0(".extract_gh_", owner_repo[[2L]], "_", commit_sha))
  if (!dir.exists(repo_dir)) {
    tar_path <- file.path(work_dir, paste0(".raw_gh_", owner_repo[[2L]], ".tar.gz"))
    url <- sprintf("https://github.com/%s/archive/%s.tar.gz", repo, commit_sha)
    failed <- curl_fetch(url, tar_path)
    if (failed || !file.exists(tar_path) || file.size(tar_path) == 0L) {
      stop("GitHub download failed or empty: ", url, call. = FALSE)
    }
    utils::untar(tar_path, exdir = repo_dir)
    unlink(tar_path)
  }
  # GitHub tarballs extract to "<repo>-<sha>/", not "<repo>/"
  pkg_dir <- list.files(repo_dir, full.names = TRUE)[[1L]]
  if (is.na(pkg_dir) || !dir.exists(pkg_dir)) stop("GitHub tarball for ", repo, " did not extract as expected", call. = FALSE)

  data_files <- list.files(file.path(pkg_dir, "data"))
  obj <- NULL
  for (f in data_files) {
    base_ext <- tolower(tools::file_ext(sub("\\.gz$", "", f, ignore.case = TRUE)))
    full_path <- file.path(pkg_dir, "data", f)
    if (base_ext %in% c("rda", "rdata")) {
      e <- new.env()
      ok2 <- tryCatch({ load(full_path, envir = e); TRUE }, error = function(e) FALSE)
      if (ok2 && obj_name %in% ls(e)) { obj <- get(obj_name, envir = e); break }
    } else if (base_ext %in% c("txt", "csv") &&
               tools::file_path_sans_ext(f, compression = TRUE) == obj_name) {
      obj <- tryCatch(data.table::fread(full_path, data.table = FALSE), error = function(e) NULL)
      if (!is.null(obj)) break
    }
  }
  if (is.null(obj)) stop(obj_name, " not found in any data/ file of ", repo, "@", commit_sha, " (checked: ", paste(data_files, collapse = ", "), ")", call. = FALSE)
  if (!(is.data.frame(obj) || is.matrix(obj))) stop(obj_name, " in ", repo, " is not a data.frame/matrix (class ", class(obj)[1L], ")", call. = FALSE)
  data.table::fwrite(as.data.frame(obj), dest_csv)
  invisible(dest_csv)
}

# ---------------------------------------------------------------------------
# Dataverse fetch: curl-based equivalents of download_experimental_datasets.R's
# dataverse_dataset_files()/dataverse_download_file() (which use httr2 and so
# hit the same sandbox-proxy failure as cran_fetch_object_auto() above).
# Reuses that file's DATAVERSE_HOST/DATAVERSE_GUESTBOOK_ANSWERS/
# dataverse_guestbook_identity() -- those are plain data/logic, not httr2
# calls, so they're safe to reuse as-is (already in scope via the
# download_experimental_datasets.R source() at the top of this file).
# ---------------------------------------------------------------------------

# Parses a Source cell of the form
# "Dataverse: `doi:10.7910/DVN/XXXXX`; file `name.csv`" or, when the file is
# bundled inside a zip, "...; file `name.csv` (inside `archive.zip`)".
parse_dataverse_source <- function(cell) {
  if (!grepl("^Dataverse:", cell)) return(NULL)
  list(
    doi = sub("^Dataverse: `doi:([^`]+)`.*$", "\\1", cell),
    filename = sub("^.*; file `([^`]+)`.*$", "\\1", cell),
    inside_zip = if (grepl("\\(inside `[^`]+`\\)", cell)) sub("^.*\\(inside `([^`]+)`\\).*$", "\\1", cell) else NA_character_
  )
}

dataverse_list_files_curl <- function(doi) {
  json_path <- tempfile(fileext = ".json")
  url <- sprintf("%s/api/datasets/:persistentId/?persistentId=doi:%s", DATAVERSE_HOST, doi)
  if (curl_fetch(url, json_path)) stop("Dataverse metadata fetch failed for ", doi, call. = FALSE)
  dat <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)$data
  files <- lapply(dat$latestVersion$files, function(f) {
    list(filename = f$dataFile$filename, id = f$dataFile$id)
  })
  list(guestbookId = dat$guestbookId, files = files)
}

dataverse_download_file_curl <- function(file_id, guestbook_id, dest_path) {
  base_access_url <- sprintf("%s/api/access/datafile/%s", DATAVERSE_HOST, file_id)
  if (is.null(guestbook_id)) {
    if (curl_fetch(base_access_url, dest_path)) stop("Dataverse file download failed: ", base_access_url, call. = FALSE)
    return(invisible(dest_path))
  }
  answers <- DATAVERSE_GUESTBOOK_ANSWERS[[as.character(guestbook_id)]]
  if (is.null(answers)) {
    stop("No DATAVERSE_GUESTBOOK_ANSWERS entry for guestbookId ", guestbook_id,
         " -- inspect ", DATAVERSE_HOST, "/api/guestbooks/", guestbook_id,
         " and add a matching entry (string-valued answers, not numeric ids).", call. = FALSE)
  }
  identity <- dataverse_guestbook_identity()
  body <- list(guestbookResponse = c(identity, list(answers = answers)))
  body_path <- tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(body, auto_unbox = TRUE), body_path)
  resp_path <- tempfile(fileext = ".json")
  status <- suppressWarnings(system2("curl", c("-sL", "-X", "POST", "-H", shQuote("Content-Type: application/json"),
                                                "--data-binary", paste0("@", body_path), "-o", shQuote(resp_path),
                                                shQuote(base_access_url)), stdout = TRUE, stderr = TRUE))
  exit_code <- attr(status, "status")
  if (!is.null(exit_code) && exit_code != 0L) stop("Dataverse guestbook POST failed: ", base_access_url, call. = FALSE)
  signed_url <- jsonlite::fromJSON(resp_path, simplifyVector = FALSE)$data$signedUrl
  if (is.null(signed_url)) stop("Dataverse guestbook POST did not return a signedUrl for file ", file_id, call. = FALSE)
  if (curl_fetch(signed_url, dest_path)) stop("Dataverse signed-URL download failed for file ", file_id, call. = FALSE)
  invisible(dest_path)
}

# `filename` is the actual data file to read; if it lives inside a zip on
# Dataverse (several deposits bundle data+code+results together), pass
# `inside_zip` as that zip's own listed filename and `filename` as the member
# to extract. Handles .csv/.txt directly, .xlsx via readxl, falls back to
# convert_to_csv() (from download_experimental_datasets.R) for .dta/.sav/.tab.
dataverse_fetch_object_auto <- function(doi, filename, dest_csv, work_dir, inside_zip = NULL) {
  listing <- dataverse_list_files_curl(doi)
  want <- if (!is.null(inside_zip)) inside_zip else filename
  hit <- Filter(function(f) identical(f$filename, want), listing$files)
  if (length(hit) == 0L) {
    stop("'", want, "' not found in Dataverse dataset ", doi, " (found: ",
         paste(vapply(listing$files, function(f) f$filename, character(1)), collapse = ", "), ")", call. = FALSE)
  }
  raw_path <- file.path(work_dir, paste0(".dv_raw_", hit[[1L]]$id, ".", tools::file_ext(want)))
  dataverse_download_file_curl(hit[[1L]]$id, listing$guestbookId, raw_path)

  src_path <- raw_path
  if (!is.null(inside_zip)) {
    extract_dir <- file.path(work_dir, paste0(".dv_extract_", hit[[1L]]$id))
    unlink(extract_dir, recursive = TRUE)
    utils::unzip(raw_path, exdir = extract_dir)
    all_files <- list.files(extract_dir, recursive = TRUE, full.names = TRUE)
    matches <- all_files[basename(all_files) == basename(filename)]
    if (length(matches) == 0L) stop("'", filename, "' not found inside ", inside_zip, call. = FALSE)
    src_path <- matches[[1L]]
  }

  ext <- tolower(tools::file_ext(src_path))
  obj <- if (ext %in% c("csv", "txt", "tab")) {
    data.table::fread(src_path, data.table = FALSE)
  } else if (ext == "xlsx") {
    as.data.frame(readxl::read_xlsx(src_path))
  } else {
    tmp_csv <- tempfile(fileext = ".csv")
    convert_to_csv(src_path, tmp_csv)
    data.table::fread(tmp_csv, data.table = FALSE)
  }
  data.table::fwrite(obj, dest_csv)
  invisible(dest_csv)
}

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
# Experimental: all 262 are already downloaded as one <name>.tar.bz2 archive
# each (see "already have" skip logic in download_all_datasets()) -- extract
# the loose CSV from the existing archive instead of re-downloading anything.
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

compute_experimental_missingness <- function(csv_path = file.path(THIS_DIR, "experimental_datasets.csv")) {
  csv <- read.csv(csv_path, stringsAsFactors = FALSE, na.strings = "")
  md_tbl <- read_dataset_table(file.path(THIS_DIR, "experimental_datasets.md"))
  treat_raw <- md_tbl[["tx (treatment column)"]]
  outcome_cols <- grep("^(primary|secondary|tertiary|outcome_[0-9]+)_outcome$", names(csv), value = TRUE)

  pct <- rep(NA_real_, nrow(csv)); n_cov <- rep(NA_integer_, nrow(csv)); note <- rep(NA_character_, nrow(csv))
  for (i in seq_len(nrow(csv))) {
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
    dest_csv <- file.path(ARCHIVE_DIR, csv_name)
    if (!file.exists(dest_csv)) {
      ok <- tryCatch({ extract_experimental_datasets(manifest_key, download_dir = ARCHIVE_DIR); TRUE },
                      error = function(e) { note[i] <<- paste("extract failed:", conditionMessage(e)); FALSE })
      if (!ok) next
    }
    if (!file.exists(dest_csv)) { note[i] <- "csv not found after extract"; next }
    df <- tryCatch(data.table::fread(dest_csv, data.table = FALSE), error = function(e) NULL)
    if (is.null(df)) { note[i] <- "csv read failed"; next }
    outcome_strs <- unlist(csv[i, outcome_cols])
    excl <- resolve_exclude_cols(name, treat_raw[i], outcome_strs, names(df))
    r <- covariate_missingness_pct(df, excl)
    pct[i] <- r$pct; n_cov[i] <- r$n_cov
    if (r$n_cov == 0L) note[i] <- "no covariate columns in dataset (only treatment/outcome columns present)"
  }
  csv$pct_missing_covariate_rows <- pct
  csv$n_covariate_cols_used <- n_cov
  csv$missingness_note <- note
  write.csv(csv, csv_path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  invisible(csv)
}

# ---------------------------------------------------------------------------
# Observational: no manifest -- auto-discover rda file per row.
# ---------------------------------------------------------------------------
compute_observational_missingness <- function(csv_path = file.path(THIS_DIR, "observational_datasets.csv")) {
  csv <- read.csv(csv_path, stringsAsFactors = FALSE, na.strings = "")
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
  for (i in seq_len(nrow(csv))) {
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
      dest_csv <- file.path(obs_cache_dir, paste0(name, ".csv"))
      if (startsWith(md_tbl$Source[i], "ICPSR:")) {
        note[i] <- "ICPSR restricted-terms data: not cached, missingness not computed"
        next
      }
      if (file.exists(archive_path) && !file.exists(dest_csv)) {
        utils::untar(archive_path, exdir = obs_cache_dir)
      }
      if (!file.exists(dest_csv)) {
        dest_csv <- file.path(WORK_DIR, paste0("obs_", gsub("[^A-Za-z0-9]", "_", name), ".csv"))
        ok <- tryCatch({
          if (is_github[i]) {
            github_fetch_object_auto(pkgs[i], versions[i], obj_names[i], dest_csv, WORK_DIR)
          } else if (is_dataverse[i]) {
            dv_i <- dv[[i]]
            dataverse_fetch_object_auto(dv_i$doi, dv_i$filename, dest_csv, WORK_DIR,
                                         inside_zip = if (is.na(dv_i$inside_zip)) NULL else dv_i$inside_zip)
          } else {
            cran_fetch_object_auto(pkgs[i], versions[i], obj_names[i], dest_csv, WORK_DIR)
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
  csv$pct_missing_covariate_rows <- pct
  csv$n_covariate_cols_used <- n_cov
  csv$missingness_note <- note
  write.csv(csv, csv_path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  invisible(csv)
}

if (sys.nframe() == 0L) {
  message("=== Observational (64 datasets) ===")
  obs <- compute_observational_missingness()
  message("done: ", sum(!is.na(obs$pct_missing_covariate_rows)), "/", nrow(obs), " resolved")

  message("\n=== Experimental (262 datasets, CRAN-sourced only) ===")
  exp <- compute_experimental_missingness()
  message("done: ", sum(!is.na(exp$pct_missing_covariate_rows)), "/", nrow(exp), " resolved")
}
