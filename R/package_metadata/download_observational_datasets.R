# Download and cache every dataset in observational_datasets.md, one
# <name>.tar.bz2 archive per dataset, same scheme as
# download_experimental_datasets.R's download_all_datasets() /
# extract_experimental_datasets() for the experimental catalog.
#
# Usage (from the repo root):
#   source("R/package_metadata/download_observational_datasets.R")
#   download_all_observational_datasets()                 # fetch everything not yet cached
#   extract_observational_datasets("nafld1")               # unpack one archive's CSV
#
# Unlike the experimental catalog, there is no hand-written
# rda_name/obj_name manifest here: this auto-discovers which data/ file
# inside each CRAN package actually contains the named object (verified by
# spot-checking CRAN's survival package: a single cancer.rda file holds
# veteran/ovarian/colon/bladder1/gbsg/lung/mgus2/rotterdam, so
# "rda_name == obj_name" would be wrong most of the time). See
# compute_covariate_missingness.R's cran_fetch_object_auto(), which this
# reuses, for the discovery mechanism and the curl-CLI-not-httr2 fetch
# rationale (R's curl/httr2 package fails through this sandbox's proxy).
# The one `datasets`-package (base R) row, `esoph`, needs no download at all.

THIS_DIR <- {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) "R/package_metadata" else dirname(normalizePath(sub("^--file=", "", file_arg[1])))
}
source(file.path(THIS_DIR, "build_experimental_datasets_csv.R"))  # read_dataset_table(), strip_md()
source(file.path(THIS_DIR, "compute_covariate_missingness.R"))    # curl_fetch(), cran_fetch_object_auto(), extract_backtick_columns()

OBS_ARCHIVE_DIR <- file.path(THIS_DIR, "observational_datasets_cache")

observational_manifest <- function(md_path = file.path(THIS_DIR, "observational_datasets.md")) {
  md_tbl <- read_dataset_table(md_path)
  data.frame(
    name = strip_md(md_tbl$Dataset),
    obj_name = sapply(md_tbl$Dataset, function(x) extract_backtick_columns(x)[1]),
    pkg = sub("^(CRAN|base R): ", "", md_tbl$Source),
    is_base_r = grepl("^base R:", md_tbl$Source),
    version = md_tbl$Version,
    stringsAsFactors = FALSE
  )
}

#' Download + cache every observational dataset not already archived.
#' Skips (with a message) anything whose archive already exists -- same
#' "already have" resume semantics as download_all_datasets().
download_all_observational_datasets <- function(download_dir = OBS_ARCHIVE_DIR,
                                                  datasets = NULL) {
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)
  manifest <- observational_manifest()
  if (!is.null(datasets)) manifest <- manifest[manifest$name %in% datasets, ]

  results <- data.frame(name = character(0), status = character(0), detail = character(0))
  for (i in seq_len(nrow(manifest))) {
    row <- manifest[i, ]
    archive_path <- file.path(download_dir, paste0(row$name, ".tar.bz2"))
    if (file.exists(archive_path)) {
      message("== ", row$name, " == already have ", archive_path)
      results <- rbind(results, data.frame(name = row$name, status = "cached", detail = NA_character_))
      next
    }
    message("== ", row$name, " (", row$pkg, (if (!row$is_base_r) paste0(" ", row$version) else ""), ") ==")
    out_csv <- file.path(download_dir, paste0(row$name, ".csv"))
    ok <- tryCatch({
      if (row$is_base_r) {
        df <- as.data.frame(get(row$obj_name, envir = asNamespace("datasets")))
        data.table::fwrite(df, out_csv)
      } else {
        cran_fetch_object_auto(row$pkg, row$version, row$obj_name, out_csv, download_dir)
      }
      TRUE
    }, error = function(e) { message("  FAILED: ", conditionMessage(e)); FALSE })
    if (!ok) {
      results <- rbind(results, data.frame(name = row$name, status = "failed", detail = "see message above"))
      next
    }
    old_wd <- setwd(download_dir)
    utils::tar(paste0(row$name, ".tar.bz2"), files = basename(out_csv), compression = "bzip2")
    setwd(old_wd)
    unlink(out_csv)
    message("  -> ", archive_path)
    results <- rbind(results, data.frame(name = row$name, status = "downloaded", detail = NA_character_))
  }
  message("Done. ", sum(results$status != "failed"), "/", nrow(results), " cached. ",
          "Run extract_observational_datasets(<name>) to unpack any one dataset when you need it.")
  invisible(results)
}

#' Unpack one dataset's cached archive into its loose CSV, same as
#' extract_experimental_datasets().
extract_observational_datasets <- function(name, download_dir = OBS_ARCHIVE_DIR) {
  archive_path <- file.path(download_dir, paste0(name, ".tar.bz2"))
  if (!file.exists(archive_path)) {
    stop("Archive not found: ", archive_path, ". Run download_all_observational_datasets(datasets = \"", name,
         "\") first.", call. = FALSE)
  }
  utils::untar(archive_path, exdir = download_dir)
  invisible(download_dir)
}

if (sys.nframe() == 0L) {
  download_all_observational_datasets()
}
