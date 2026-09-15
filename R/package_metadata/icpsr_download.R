# Download-and-normalize pipeline for every non-CRAN, non-GitHub real
# experimental dataset in R/package_metadata/experimental_datasets.md.
#
# Usage (from the repo root):
#   Rscript R/package_metadata/icpsr_download.R
# or, sourced interactively:
#   source("R/package_metadata/icpsr_download.R")
#   download_all_datasets()
#
# Every dataset ends up as one or more plain CSV files, and the whole
# download directory is then packed into a single icpsr_data.tar.bz2 (the
# loose CSVs are deleted afterward by default -- text compresses well under
# bzip2, so one archive of uniform CSVs is both smaller on disk and simpler
# to reason about than a mix of .zip/.tab/.dta/.csv). Run
# icpsr_data_extract() to unpack the archive back to loose CSVs when you
# actually need to read one (e.g. from `_dataset_load.R`-style consumers).
#
# Two distinct download mechanisms are used, per dataset:
#
# 1. Harvard Dataverse (the source for every dataset currently in the
#    manifest below -- J-PAL/IPA/openICPSR studies mirrored there).
#    CONFIRMED WORKING end-to-end 2026-09-14/15. No ICPSR account or login
#    of any kind is needed -- Dataverse's own "Guestbook" mechanism (a
#    usage-tracking questionnaire some depositors require, unrelated to the
#    file's license) is satisfied with plain identity fields, not
#    credentials:
#      a. GET the dataset's metadata to find the target file's numeric id
#         and the dataset's guestbookId (NULL if no guestbook is required).
#      b. If a guestbook is required: POST
#         https://dataverse.harvard.edu/api/access/datafile/{fileId} with a
#         JSON body {"guestbookResponse": {...}} -> {"data":{"signedUrl":
#         "..."}}. The custom-question "answers" MUST use the option's
#         STRING text as `value`, not its numeric id -- the numeric-id form
#         looks plausible (it's what the "id" field elsewhere in the
#         payload takes) but 500s server-side with an opaque
#         ClassCastException; found by trial 2026-09-15.
#      c. GET the file's own access URL (guestbook-gated) or the signed URL
#         (guestbook-gated case) -- both return an HTTP 303 redirect to a
#         short-lived, pre-signed S3 URL, which must be followed
#         (`httr2::req_perform()` follows redirects by default; a bare
#         `curl` needs `-L`) and consumed promptly.
#
# 2. Classic ICPSR archive proper (`icpsr_download_simple()`, kept below
#    for any future dataset that is on ICPSR but NOT mirrored on Dataverse
#    -- none of the datasets currently in the manifest need it). STATUS:
#    confirmed broken as a replacement for the CRAN `icpsrdata` package
#    (which POSTs to a dead legacy `cgi-bin/bob/zipcart2` URL) and NOT YET
#    proven reliable end-to-end even in this rewritten form -- ICPSR's
#    Keycloak-based OAuth login appears to be bot-detected/rate-limited
#    inconsistently across back-to-back attempts (see the function's own
#    comment). Prefer a Dataverse mirror when one exists.
#
# Credentials: only the classic-ICPSR path (mechanism 2) needs any. Read
# from your personal `~/.Rprofile` (never from this repo):
#   options("icpsr_email" = "you@example.com", "icpsr_password" = "...")
# The Dataverse guestbook path (mechanism 1 -- everything in the manifest
# below) needs no account and no secret; it just records who's asking, the
# same as a physical library guestbook. Your own name/email/institution for
# that guestbook come from these options (all optional -- generic defaults
# are used if unset, so this script runs for anyone who clones the repo):
#   options("dataverse_guestbook_name" = "Your Name",
#           "dataverse_guestbook_email" = "you@example.com",
#           "dataverse_guestbook_institution" = "Your Institution")
#
# Licensing: do not vendor any of this repo's downloaded output into a git
# commit or the shipped package -- see the "Licensing note" section of
# experimental_datasets.md. Keep `icpsr_data/` and `icpsr_data.tar.bz2`
# gitignored (already true) and fetch live instead.

library(httr2)

# ---------------------------------------------------------------------------
# Mechanism 2: classic ICPSR archive (OAuth/Keycloak login)
# ---------------------------------------------------------------------------

ICPSR_LOGIN_HOST <- "login.icpsr.umich.edu"  # believed correct; not yet independently verified
ICPSR_DATA_HOST  <- "www.openicpsr.org"      # verified 2026-09-14: returns HTTP 200

BROWSER_HEADERS <- c(
  "User-Agent" = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
  "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Language" = "en-US,en;q=0.9"
)

get_icpsr_credentials <- function() {
  email <- getOption("icpsr_email", Sys.getenv("ICPSR_EMAIL", unset = NA))
  password <- getOption("icpsr_password", Sys.getenv("ICPSR_PASS", unset = NA))
  if (is.na(email) || is.na(password) || !nchar(email) || !nchar(password)) {
    stop(
      "ICPSR credentials not found. Set them in your personal ~/.Rprofile ",
      "(never in this repository):\n",
      '  options("icpsr_email" = "you@example.com", "icpsr_password" = "...")',
      call. = FALSE
    )
  }
  list(email = email, password = password)
}

#' Authenticate against classic ICPSR and download one file by project id.
#' Only needed for a dataset that is on ICPSR but has no Dataverse mirror --
#' none of the datasets in DATASET_MANIFEST below need this.
#'
#' @param project_id ICPSR/openICPSR project or study id.
#' @param download_dir Directory to write the downloaded file into.
icpsr_download_simple <- function(project_id, download_dir = "R/package_metadata/icpsr_data") {
  creds <- get_icpsr_credentials()
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)

  base_url <- sprintf("https://%s/openicpsr/", ICPSR_DATA_HOST)
  login_url <- sprintf("https://%s/openicpsr/login", ICPSR_DATA_HOST)

  session <- httr2::request(base_url) |>
    httr2::req_headers(!!!BROWSER_HEADERS) |>
    httr2::req_perform()

  login_page <- httr2::request(login_url) |>
    httr2::req_headers(!!!BROWSER_HEADERS, Referer = base_url) |>
    httr2::req_perform()

  html <- httr2::resp_body_string(login_page)
  action_match <- regmatches(html, regexpr('action="([^"]*)"', html))
  if (length(action_match) == 0L) {
    stop(
      "Could not find the login form's action URL in the response. ",
      "This usually means ICPSR_LOGIN_HOST/ICPSR_DATA_HOST are wrong, or ",
      "the site has changed its login page again since this was written.",
      call. = FALSE
    )
  }
  action_url <- sub('^action="', "", sub('"$', "", action_match))
  action_url <- gsub("&amp;", "&", action_url)

  auth_resp <- httr2::request(action_url) |>
    httr2::req_headers(!!!BROWSER_HEADERS) |>
    httr2::req_body_form(username = creds$email, password = creds$password) |>
    httr2::req_perform()

  if (httr2::resp_status(auth_resp) >= 400L) {
    stop(
      "ICPSR authentication failed (HTTP ", httr2::resp_status(auth_resp), "). ",
      "Check credentials, or the login flow may have changed again.",
      call. = FALSE
    )
  }

  data_url <- sprintf(
    "https://%s/openicpsr/project/%s/version/V1/download",
    ICPSR_DATA_HOST, project_id
  )
  head_resp <- httr2::request(data_url) |>
    httr2::req_headers(!!!BROWSER_HEADERS) |>
    httr2::req_method("HEAD") |>
    httr2::req_perform()
  disposition <- httr2::resp_header(head_resp, "content-disposition")
  filename <- if (!is.null(disposition)) {
    sub('.*filename="?([^"]+)"?.*', "\\1", disposition)
  } else {
    paste0("ICPSR_", project_id, ".zip")
  }

  dest <- file.path(download_dir, filename)
  httr2::request(data_url) |>
    httr2::req_headers(!!!BROWSER_HEADERS) |>
    httr2::req_perform(path = dest)

  message("Downloaded: ", dest)
  invisible(dest)
}

# ---------------------------------------------------------------------------
# Mechanism 1: Harvard Dataverse (guestbook where required, direct GET otherwise)
# ---------------------------------------------------------------------------

DATAVERSE_HOST <- "https://dataverse.harvard.edu"

# Defaults match the identity already used (with the user's explicit
# go-ahead) for every Dataverse guestbook download fetched so far this
# project -- override via options() if you're a different user running
# this script; some guestbooks (e.g. IPA's, id 80) reject an empty email
# or institution outright, so these must be non-empty, not just placeholders.
dataverse_guestbook_identity <- function() {
  list(
    name = getOption("dataverse_guestbook_name", "Adam Kapelner"),
    email = getOption("dataverse_guestbook_email", Sys.getenv("EDI_DATAVERSE_EMAIL", unset = "kapelner@gmail.com")),
    institution = getOption("dataverse_guestbook_institution", Sys.getenv("EDI_DATAVERSE_INSTITUTION", unset = "Hebrew University of Jerusalem"))
  )
}

# Per-guestbook required custom-question answers, keyed by the numeric
# guestbookId returned in a dataset's own metadata. Every "options"-type
# question here MUST be answered with the option's string text (not its
# numeric id) -- see the mechanism-1 header comment above. Add a new named
# entry here if a future dataset uses a guestbook other than these two.
DATAVERSE_GUESTBOOK_ANSWERS <- list(
  `269` = list( # "J-PAL Guestbook (v2)"
    list(id = 207, value = "Exploring or replicating methods/code used in a study"),
    list(id = 206, value = "Faculty or academic researcher"),
    list(id = 317, value = "Israel")
  ),
  `80` = list( # "IPA Dataverse"
    list(id = 6, value = "Using the data for secondary analysis"),
    list(id = 308, value = "Dataverse search"),
    list(id = 9, value = "Faculty member at college or university"),
    list(id = 5, value = "No"),
    list(id = 50, value = "No, I will pass.")
  )
)

#' List a dataset's files (name/id/size) and its guestbookId, from its DOI.
dataverse_dataset_files <- function(doi) {
  resp <- httr2::request(sprintf("%s/api/datasets/:persistentId/", DATAVERSE_HOST)) |>
    httr2::req_url_query(persistentId = doi) |>
    httr2::req_perform()
  dat <- httr2::resp_body_json(resp)$data
  files <- lapply(dat$latestVersion$files, function(f) {
    list(filename = f$dataFile$filename, id = f$dataFile$id, size = f$dataFile$filesize)
  })
  list(guestbookId = dat$guestbookId, files = files)
}

#' Download one Dataverse file by its numeric file id to `dest_path`,
#' satisfying the guestbook if the dataset requires one.
dataverse_download_file <- function(file_id, guestbook_id, dest_path) {
  base_access_url <- sprintf("%s/api/access/datafile/%s", DATAVERSE_HOST, file_id)
  if (!is.null(guestbook_id)) {
    answers <- DATAVERSE_GUESTBOOK_ANSWERS[[as.character(guestbook_id)]]
    if (is.null(answers)) {
      stop(
        "No DATAVERSE_GUESTBOOK_ANSWERS entry for guestbookId ", guestbook_id,
        " -- inspect https://dataverse.harvard.edu/api/guestbooks/", guestbook_id,
        " and add a matching entry (string-valued answers, not numeric ids).",
        call. = FALSE
      )
    }
    identity <- dataverse_guestbook_identity()
    body <- list(guestbookResponse = c(identity, list(answers = answers)))
    resp <- httr2::request(base_access_url) |>
      httr2::req_body_json(body) |>
      httr2::req_perform()
    signed_url <- httr2::resp_body_json(resp)$data$signedUrl
    httr2::request(signed_url) |> httr2::req_perform(path = dest_path)
  } else {
    httr2::request(base_access_url) |> httr2::req_perform(path = dest_path)
  }
  invisible(dest_path)
}

#' Look up a file's id by filename within a dataset and download it.
dataverse_download_by_filename <- function(doi, filename, dest_path) {
  listing <- dataverse_dataset_files(doi)
  hit <- Filter(function(f) identical(f$filename, filename), listing$files)
  if (length(hit) == 0L) {
    stop("File '", filename, "' not found in dataset ", doi, call. = FALSE)
  }
  dataverse_download_file(hit[[1L]]$id, listing$guestbookId, dest_path)
}

# ---------------------------------------------------------------------------
# Normalization: every downloaded file becomes plain CSV
# ---------------------------------------------------------------------------

#' Convert a downloaded .tab/.tsv/.dta/.csv file in place to CSV at
#' `dest_csv`. Stata (.dta) columns are stripped of haven's value/variable
#' labels (`zap_labels()`) so the CSV holds plain values, not labelled
#' vectors -- consumers reading the CSV shouldn't need `haven` at all.
convert_to_csv <- function(src_path, dest_csv) {
  ext <- tolower(tools::file_ext(src_path))
  df <- switch(
    ext,
    dta = haven::zap_labels(haven::read_dta(src_path)),
    tab = data.table::fread(src_path, sep = "\t", quote = "", data.table = FALSE),
    tsv = data.table::fread(src_path, sep = "\t", quote = "", data.table = FALSE),
    csv = data.table::fread(src_path, data.table = FALSE),
    stop("convert_to_csv: unsupported extension '", ext, "' for ", src_path, call. = FALSE)
  )
  data.table::fwrite(df, dest_csv)
  invisible(dest_csv)
}

#' Download one zip-bundled file, locate a member by filename anywhere in
#' the archive (Dataverse zips nest arbitrarily, e.g.
#' `PUBLISH_0/Data/Analysis/analysis.dta`), convert it to CSV, then discard
#' the zip and the extraction scratch directory.
download_zip_member_as_csv <- function(doi, zip_filename, member_basename, dest_csv, work_dir) {
  zip_path <- file.path(work_dir, zip_filename)
  listing <- dataverse_dataset_files(doi)
  hit <- Filter(function(f) identical(f$filename, zip_filename), listing$files)
  if (length(hit) == 0L) stop("Zip '", zip_filename, "' not found in dataset ", doi, call. = FALSE)
  dataverse_download_file(hit[[1L]]$id, listing$guestbookId, zip_path)

  extract_dir <- file.path(work_dir, paste0(".extract_", tools::file_path_sans_ext(zip_filename)))
  utils::unzip(zip_path, exdir = extract_dir)
  member_path <- list.files(extract_dir, pattern = paste0("^", member_basename, "$"),
                             recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (length(member_path) == 0L) {
    stop("Member '", member_basename, "' not found inside ", zip_filename, call. = FALSE)
  }
  convert_to_csv(member_path[[1L]], dest_csv)

  unlink(zip_path)
  unlink(extract_dir, recursive = TRUE)
  invisible(dest_csv)
}

# ---------------------------------------------------------------------------
# Dataset manifest -- every Dataverse-sourced row in experimental_datasets.md
# ---------------------------------------------------------------------------

DATASET_MANIFEST <- list(
  monitoring_works = list(
    doi = "doi:10.7910/DVN/LRDXHX",
    files = list(
      TreatmentSchools.tab = "monitoring_works_TreatmentSchools.csv",
      Posttest.tab         = "monitoring_works_Posttest.csv",
      Pretest.tab          = "monitoring_works_Pretest.csv",
      Closed.tab           = "monitoring_works_Closed.csv",
      RandomCheck.tab      = "monitoring_works_RandomCheck.csv",
      ValidDay.tab         = "monitoring_works_ValidDay.csv",
      Roster.csv           = "monitoring_works_Roster.csv"
    )
  ),
  savings = list(
    doi = "doi:10.7910/DVN/UJD5OP",
    files = list(
      analysis_dataallcountries.tab = "savings_analysis_allcountries.csv"
    )
  ),
  sanitation = list(
    doi = "doi:10.7910/DVN/GJDUTV",
    files = list(
      `BD-SAN-FINAL.dta` = "sanitation_BD-SAN-FINAL.csv"
    )
  ),
  student_test_data = list(
    doi = "doi:10.7910/DVN/LWFH9U",
    files = list(
      student_test_data.tab = "student_test_data.csv"
    )
  ),
  PES_analysis_science = list(
    doi = "doi:10.7910/DVN/MGMDYN",
    files = list(
      PES_analysis_science.tab = "PES_analysis_science.csv"
    )
  ),
  # Hayes & Moulton "Cluster Randomised Trials" textbook companion dataverse
  # -- one Dataverse dataset (DOI) bundling 10 files, no guestbook required.
  # `simpairs.tab` is deliberately excluded: it's simulated data, not a real
  # trial. `mwanza_stdtrial_community.tab` (n=12, baseline-only, no outcome
  # field) was evaluated and excluded too -- see its note in
  # experimental_datasets.md.
  ghana_bednet = list(
    doi = "doi:10.7910/DVN/YXMQZM",
    files = list(ghana_bednet.tab = "ghana_bednet.csv")
  ),
  laviiswa = list(
    doi = "doi:10.7910/DVN/YXMQZM",
    files = list(laviiswa.tab = "laviiswa.csv")
  ),
  mkvtrial = list(
    doi = "doi:10.7910/DVN/YXMQZM",
    files = list(mkvtrial.tab = "mkvtrial.csv")
  ),
  mwanza_stdtrial = list(
    doi = "doi:10.7910/DVN/YXMQZM",
    files = list(mwanza_stdtrial.tab = "mwanza_stdtrial.csv")
  ),
  pneumovac = list(
    doi = "doi:10.7910/DVN/YXMQZM",
    files = list(pneumovac.tab = "pneumovac.csv")
  ),
  share = list(
    doi = "doi:10.7910/DVN/YXMQZM",
    files = list(share.tab = "share.csv")
  ),
  thrio = list(
    doi = "doi:10.7910/DVN/YXMQZM",
    files = list(thrio.tab = "thrio.csv")
  ),
  zamstar = list(
    doi = "doi:10.7910/DVN/YXMQZM",
    files = list(zamstar.tab = "zamstar.csv")
  ),
  immig = list(
    doi = "doi:10.7910/DVN/DDCNEW",
    zip_members = list(
      list(zip_filename = "PUBLISH.zip", member_basename = "analysis\\.dta", dest_csv = "immig_analysis.csv")
    )
  ),
  hiv = list(
    doi = "doi:10.7910/DVN/CVOPZL",
    zip_members = list(
      list(zip_filename = "data.zip", member_basename = "Phase2_sample_list\\.dta", dest_csv = "hiv_Phase2_sample_list.csv")
    )
  )
)

# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

#' Download and normalize every dataset in DATASET_MANIFEST, then pack the
#' result into one tar.bz2 archive.
#'
#' @param download_dir Working/output directory for CSVs (gitignored).
#' @param archive_path Final tar.bz2 path.
#' @param keep_loose_csvs If FALSE (default), the loose CSVs are deleted
#'   after archiving -- only icpsr_data.tar.bz2 remains on disk. Set TRUE to
#'   keep both (e.g. while developing this script).
#' @param datasets Names of DATASET_MANIFEST entries to fetch; default all.
download_all_datasets <- function(download_dir = "R/package_metadata/icpsr_data",
                                   archive_path = "R/package_metadata/icpsr_data.tar.bz2",
                                   keep_loose_csvs = FALSE,
                                   datasets = names(DATASET_MANIFEST)) {
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)

  for (name in datasets) {
    spec <- DATASET_MANIFEST[[name]]
    if (is.null(spec)) stop("No manifest entry named '", name, "'", call. = FALSE)
    message("== ", name, " ==")

    if (!is.null(spec$files)) {
      for (remote_name in names(spec$files)) {
        out_csv <- file.path(download_dir, spec$files[[remote_name]])
        if (file.exists(out_csv)) { message("  already have ", out_csv); next }
        raw_path <- file.path(download_dir, paste0(".raw_", remote_name))
        message("  downloading ", remote_name, " ...")
        dataverse_download_by_filename(spec$doi, remote_name, raw_path)
        convert_to_csv(raw_path, out_csv)
        unlink(raw_path)
        message("  -> ", out_csv)
      }
    }

    if (!is.null(spec$zip_members)) {
      for (zm in spec$zip_members) {
        out_csv <- file.path(download_dir, zm$dest_csv)
        if (file.exists(out_csv)) { message("  already have ", out_csv); next }
        message("  downloading ", zm$zip_filename, " (large; extracting ", zm$member_basename, ") ...")
        download_zip_member_as_csv(spec$doi, zm$zip_filename, zm$member_basename, out_csv, download_dir)
        message("  -> ", out_csv)
      }
    }
  }

  message("Packing ", download_dir, " -> ", archive_path)
  csvs <- list.files(download_dir, pattern = "\\.csv$", full.names = FALSE)
  old_wd <- setwd(download_dir); on.exit(setwd(old_wd), add = TRUE)
  utils::tar(file.path("..", basename(archive_path)), files = csvs, compression = "bzip2")
  setwd(old_wd)

  if (!keep_loose_csvs) {
    unlink(file.path(download_dir, csvs))
    message("Removed loose CSVs (kept only ", archive_path, "); run icpsr_data_extract() to unpack them again.")
  }
  invisible(archive_path)
}

#' Unpack icpsr_data.tar.bz2 back into loose CSVs for actual use.
icpsr_data_extract <- function(archive_path = "R/package_metadata/icpsr_data.tar.bz2",
                                download_dir = "R/package_metadata/icpsr_data") {
  if (!file.exists(archive_path)) {
    stop("Archive not found: ", archive_path, ". Run download_all_datasets() first.", call. = FALSE)
  }
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)
  utils::untar(archive_path, exdir = download_dir)
  invisible(download_dir)
}

# Run end-to-end only when this file is executed directly (Rscript), never
# when it's source()'d -- matches the documented `source(...); call a
# function` usage pattern above.
if (sys.nframe() == 0L) {
  .args <- commandArgs(trailingOnly = FALSE)
  .file_arg <- grep("^--file=", .args, value = TRUE)
  if (length(.file_arg) > 0L && grepl("icpsr_download\\.R$", .file_arg[[1L]])) {
    download_all_datasets()
  }
}
