# Download-and-normalize pipeline for every experimental dataset in
# R/package_metadata/experimental_datasets.md: 248 CRAN, 15 Dataverse and 6 GitHub
# rows (the 2 ICPSR restricted-terms rows are fetched by hand). DATASET_MANIFEST
# below says how to fetch each one; the md's Version column says which release.
#
# Usage (from the repo root):
#   Rscript R/package_metadata/download_experimental_datasets.R
# or, sourced interactively:
#   source("R/package_metadata/download_experimental_datasets.R")
#   download_all_datasets()
#
# Every dataset ends up as one plain CSV packed into its own <name>.tar.bz2 under
# randomized_experiment_datasets/ (the loose CSVs are deleted afterward by
# default -- text compresses well under bzip2). Run
# extract_experimental_datasets(<name>) to unpack one back to a loose CSV when you
# actually need to read it (e.g. from `_dataset_load.R`-style consumers). A row
# whose Redistribution cell is not "yes" warns on download and on unpacking.
#
# Download mechanisms, per dataset:
#
# 1. Harvard Dataverse (J-PAL/IPA/openICPSR studies mirrored there).
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
#      c. GET the file's own access URL (no guestbook) or the signed URL
#         (guestbook-gated case) -- both return an HTTP 303 redirect to a
#         short-lived, pre-signed S3 URL, which must be followed (`curl -L`)
#         and consumed promptly.
#    The files are those of the dataset version in the md's Version cell
#    (e.g. v3.3), never the latest one instead. All calls use the curl CLI
#    (dataverse_file_as_csv(), shared with the observational downloader).
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
# 3./4. CRAN packages and GitHub-only R packages: the pinned source tarball is
#    fetched with the curl CLI and the data object read from its data/
#    directory, no install (cran_extract_package(), github_extract_repo(),
#    load_data_object(); shared with download_observational_datasets.R).
#
# Credentials: only the classic-ICPSR path (mechanism 2) needs any. Read
# from your personal `~/.Rprofile` (never from this repo):
#   options("icpsr_email" = "you@example.com", "icpsr_password" = "...")
# The Dataverse guestbook path (mechanism 1) needs no account and no secret;
# it just records who's asking, the same as a physical library guestbook. There
# are no defaults: the first guestbook-gated download asks for your name, email
# and institution at the prompt and saves them to
# <download dir>/dataverse_guestbook_credentials.dcf (inside the gitignored
# download folder, readable only by you), which later runs reuse. Edit or delete
# that file to change them; never commit it.
#
# Licensing: do not vendor any of this repo's downloaded output into a git
# commit or the shipped package -- see dataset_license_audit.md. Keep
# `randomized_experiment_datasets/` gitignored (already true) and fetch live instead.

library(httr2)

# This file's folder as an absolute path, so it runs from any working directory, whether
# run with Rscript or source()d (also from inside another script): the innermost source()
# call's file wins, then Rscript's --file=, then R/package_metadata/ under the working directory.
EXPERIMENTAL_DIR <- local({
  sourced <- Filter(is.character, lapply(rev(sys.frames()), function(f) f$ofile))
  file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
  dirname(normalizePath(c(unlist(sourced), file_arg, "R/package_metadata/download_experimental_datasets.R")[[1L]], mustWork = TRUE))
})

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
icpsr_download_simple <- function(project_id, download_dir = file.path(EXPERIMENTAL_DIR, "randomized_experiment_datasets")) {
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

DATAVERSE_CREDENTIALS_FILE <- "dataverse_guestbook_credentials.dcf"

# Reads one answer per prompt: readline() in an interactive session, the terminal (stdin)
# under Rscript. All prompts share one stdin connection so piped answers are not lost.
prompt_lines <- function(prompts) {
  if (interactive()) return(vapply(prompts, readline, character(1)))
  con <- file("stdin")
  on.exit(close(con))
  open(con)
  vapply(prompts, function(p) {
    cat(p)
    line <- readLines(con, n = 1L)
    if (length(line) == 0L) {
      stop("No input for the Dataverse guestbook prompt. Run the download from a terminal or an ",
           "interactive R session so you can answer it", call. = FALSE)
    }
    line
  }, character(1))
}

# The name, email and institution sent with a Dataverse guestbook form, from
# <dir>/dataverse_guestbook_credentials.dcf. When that file is missing or incomplete, asks
# for them at the prompt (the guestbooks reject empty fields) and saves them there.
dataverse_guestbook_identity <- function(dir) {
  path <- file.path(dir, DATAVERSE_CREDENTIALS_FILE)
  fields <- c("name", "email", "institution")
  if (file.exists(path)) {
    saved <- read.dcf(path, fields = fields)[1L, ]
    if (all(!is.na(saved) & nzchar(trimws(saved)))) return(as.list(saved))
    message("Ignoring incomplete ", path)
  }
  message("This Dataverse deposit requires a guestbook form: the name, email and institution of the person ",
          "downloading. Your answers are saved to ", path, " for later runs.")
  answers <- trimws(prompt_lines(c("Your name: ", "Your email: ", "Your institution: ")))
  names(answers) <- fields
  if (any(!nzchar(answers))) {
    stop("Dataverse guestbook ", paste(fields[!nzchar(answers)], collapse = ", "),
         " is required; nothing was saved", call. = FALSE)
  }
  write.dcf(as.data.frame(as.list(answers)), path)
  Sys.chmod(path, "600")
  as.list(answers)
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

# Every Dataverse call goes through the curl CLI (curl_status(), with the CRAN helpers
# below), not httr2, for the same proxy reason as the CRAN tarballs. Shared with
# download_observational_datasets.R and compute_covariate_missingness.R.

# Parses an md Source cell of the form "Dataverse: `doi:10.7910/DVN/XXXXX`; file
# `name.csv`" or, for a file bundled in a zip, "...; file `name.csv` (inside
# `archive.zip`)". NULL for a non-Dataverse cell.
parse_dataverse_source <- function(cell) {
  if (!grepl("^Dataverse:", cell)) return(NULL)
  list(
    doi = sub("^Dataverse: `doi:([^`]+)`.*$", "\\1", cell),
    filename = sub("^.*; file `([^`]+)`.*$", "\\1", cell),
    inside_zip = if (grepl("\\(inside `[^`]+`\\)", cell)) sub("^.*\\(inside `([^`]+)`\\).*$", "\\1", cell) else NA_character_
  )
}

# The `data` field of a Dataverse API response, or NULL with the curl exit status as the
# "status" attribute when the request failed (22 = HTTP error such as 404).
dataverse_api_data <- function(url) {
  json_path <- tempfile(fileext = ".json")
  on.exit(unlink(json_path))
  status <- curl_status(url, json_path)
  if (status != 0L) return(structure(list(), status = status))
  jsonlite::fromJSON(json_path, simplifyVector = FALSE)$data
}

#' A dataset's guestbookId and the files (name/id/size) of exactly `version` (the md
#' Version cell, "v3.3" or "3.3"). A version Dataverse does not have is an error; no
#' other version is substituted.
dataverse_dataset_files <- function(doi, version) {
  pid <- paste0("doi:", sub("^doi:", "", doi))
  dat <- dataverse_api_data(sprintf("%s/api/datasets/:persistentId/?persistentId=%s", DATAVERSE_HOST, pid))
  if (length(dat) == 0L) stop("Dataverse metadata fetch failed for ", pid, " (curl exit status ", attr(dat, "status"), ")", call. = FALSE)
  ver <- sub("^v", "", version)
  ver_dat <- dataverse_api_data(sprintf("%s/api/datasets/:persistentId/versions/%s?persistentId=%s", DATAVERSE_HOST, ver, pid))
  if (length(ver_dat) == 0L) {
    if (identical(attr(ver_dat, "status"), 22L)) {
      stop("Dataverse has no version ", version, " of ", pid, " (latest is ", dat$latestVersion$versionNumber, ".",
           dat$latestVersion$versionMinorNumber, "); correct the Version cell in the catalog md", call. = FALSE)
    }
    stop("Dataverse version fetch failed for ", pid, " ", version, " (curl exit status ", attr(ver_dat, "status"), ")", call. = FALSE)
  }
  files <- lapply(ver_dat$files, function(f) {
    list(filename = f$dataFile$filename, id = f$dataFile$id, size = f$dataFile$filesize)
  })
  list(guestbookId = dat$guestbookId, files = files)
}

#' Download one Dataverse file by its numeric file id to `dest_path`,
#' satisfying the guestbook if the dataset requires one (identity from
#' `credentials_dir`; see dataverse_guestbook_identity()).
dataverse_download_file <- function(file_id, guestbook_id, dest_path, credentials_dir) {
  base_access_url <- sprintf("%s/api/access/datafile/%s", DATAVERSE_HOST, file_id)
  if (is.null(guestbook_id)) {
    status <- curl_status(base_access_url, dest_path)
    if (status != 0L) stop("Dataverse file download failed (curl exit status ", status, "): ", base_access_url, call. = FALSE)
    return(invisible(dest_path))
  }
  answers <- DATAVERSE_GUESTBOOK_ANSWERS[[as.character(guestbook_id)]]
  if (is.null(answers)) {
    stop(
      "No DATAVERSE_GUESTBOOK_ANSWERS entry for guestbookId ", guestbook_id,
      " -- inspect ", DATAVERSE_HOST, "/api/guestbooks/", guestbook_id,
      " and add a matching entry (string-valued answers, not numeric ids).",
      call. = FALSE
    )
  }
  body <- list(guestbookResponse = c(dataverse_guestbook_identity(credentials_dir), list(answers = answers)))
  body_path <- tempfile(fileext = ".json")
  resp_path <- tempfile(fileext = ".json")
  on.exit(unlink(c(body_path, resp_path)))
  writeLines(jsonlite::toJSON(body, auto_unbox = TRUE), body_path)
  out <- suppressWarnings(system2("curl", c("-sSL", "-f", "-X", "POST", "-H", shQuote("Content-Type: application/json"),
                                            "--data-binary", paste0("@", body_path), "-o", shQuote(resp_path),
                                            shQuote(base_access_url)), stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status"))) {
    stop("Dataverse guestbook POST failed (curl exit status ", attr(out, "status"), "): ", base_access_url, call. = FALSE)
  }
  signed_url <- jsonlite::fromJSON(resp_path, simplifyVector = FALSE)$data$signedUrl
  if (is.null(signed_url)) stop("Dataverse guestbook POST did not return a signedUrl for file ", file_id, call. = FALSE)
  status <- curl_status(signed_url, dest_path)
  if (status != 0L) stop("Dataverse signed-URL download failed for file ", file_id, " (curl exit status ", status, ")", call. = FALSE)
  invisible(dest_path)
}

#' Download file `filename` of Dataverse dataset `doi` at `version` and write it to
#' `dest_csv` as plain CSV. When the deposit bundles the file in a zip, `inside_zip` is
#' the zip's listed filename and `filename` the member's name, matched case-insensitively
#' at any depth (Dataverse zips nest arbitrarily, e.g.
#' `PUBLISH_0/Data/Analysis/analysis.dta`). Scratch files go in `work_dir` and are removed;
#' the guestbook credentials file is read from (or saved to) `credentials_dir`.
dataverse_file_as_csv <- function(doi, version, filename, dest_csv, work_dir, inside_zip = NULL,
                                  credentials_dir = work_dir) {
  listing <- dataverse_dataset_files(doi, version)
  want <- if (is.null(inside_zip)) filename else inside_zip
  hit <- Filter(function(f) identical(f$filename, want), listing$files)
  if (length(hit) == 0L) {
    stop("'", want, "' not found in Dataverse dataset ", doi, " ", version, " (found: ",
         paste(vapply(listing$files, function(f) f$filename, character(1)), collapse = ", "), ")", call. = FALSE)
  }
  file_id <- hit[[1L]]$id
  raw_path <- file.path(work_dir, paste0(".raw_dv_", file_id, ".", tools::file_ext(want)))
  on.exit(unlink(raw_path), add = TRUE)
  dataverse_download_file(file_id, listing$guestbookId, raw_path, credentials_dir)

  src_path <- raw_path
  if (!is.null(inside_zip)) {
    extract_dir <- file.path(work_dir, paste0(".extract_dv_", file_id))
    on.exit(unlink(extract_dir, recursive = TRUE), add = TRUE)
    unlink(extract_dir, recursive = TRUE)
    utils::unzip(raw_path, exdir = extract_dir)
    members <- list.files(extract_dir, recursive = TRUE, full.names = TRUE)
    members <- members[tolower(basename(members)) == tolower(basename(filename))]
    if (length(members) == 0L) stop("'", filename, "' not found inside ", inside_zip, call. = FALSE)
    src_path <- members[[1L]]
  }
  convert_to_csv(src_path, dest_csv)
}

# ---------------------------------------------------------------------------
# Normalization: every downloaded file becomes plain CSV
# ---------------------------------------------------------------------------

#' Convert a downloaded .tab/.tsv/.dta/.csv/.txt/.xlsx file to CSV at
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
    txt = data.table::fread(src_path, data.table = FALSE),
    xlsx = as.data.frame(readxl::read_xlsx(src_path)),
    stop("convert_to_csv: unsupported extension '", ext, "' for ", src_path, call. = FALSE)
  )
  data.table::fwrite(df, dest_csv)
  invisible(dest_csv)
}

# ---------------------------------------------------------------------------
# Mechanisms 3 and 4: CRAN packages, and GitHub-only R packages (e.g.
# `experimentdatar`, no CRAN listing -- see "Required R packages" in
# experimental_datasets.md) -- source tarball only, no install. Shared with
# download_observational_datasets.R and compute_covariate_missingness.R, which
# source this file.
# ---------------------------------------------------------------------------
#
# Confirmed working 2026-09-15/16 as the harvesting method for the
# exhaustive CRAN dataset sweep (see experimental_datasets.md's "Two
# tiers" section, round 4): a package's exported data objects (.rda/
# .RData under data/) load directly via base R `load()`, with no need to
# `install.packages()` the surrounding package at all -- R's data-loading
# machinery doesn't care whether the package is installed, only that the
# .rda file itself is a valid serialized R object. This is dramatically
# faster than installing (no dependency resolution, no compilation) and
# is exactly what's needed here: we only want one dataset's bytes, not a
# working copy of the package's R/C++ code.

# Tarballs are fetched with the curl CLI, not httr2: R's curl/httr2 package fails through
# some proxies ("Proxy CONNECT aborted", e.g. the Claude Code sandbox's) where the CLI works
# against the same URL. Returns curl's exit status: 0 on success, 22 on an HTTP error such
# as 404.
curl_status <- function(url, dest_path) {
  out <- suppressWarnings(system2("curl", c("-sSL", "-f", "-o", shQuote(dest_path), shQuote(url)),
                                  stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (is.null(status)) 0L else as.integer(status)
}


#' Download a CRAN package's source tarball at exactly `version` and extract it
#' under `work_dir`; returns the package directory. An earlier extraction of the
#' same package and version is reused, since many catalog rows share a package
#' (seven observational rows come from `survival` alone).
#'
#' CRAN's src/contrib/ holds only the current release; superseded ones move to
#' src/contrib/Archive/<pkg>/. Another version is never substituted: the catalogs'
#' License and Redistribution cells describe the pinned release, and some pins are
#' deliberately old because the current release is GPL-2 only
#' (dataset_license_audit.md).
cran_extract_package <- function(pkg, version, work_dir) {
  pkg_dir <- file.path(work_dir, paste0(".extract_", pkg, "_", version), pkg)
  if (file.exists(file.path(pkg_dir, "DESCRIPTION"))) return(pkg_dir)
  tar_path <- file.path(work_dir, paste0(".raw_", pkg, "_", version, ".tar.gz"))
  on.exit(unlink(tar_path))
  status <- curl_status(sprintf("https://cran.r-project.org/src/contrib/%s_%s.tar.gz", pkg, version), tar_path)
  if (status == 22L) {
    message("  (", pkg, " ", version, " superseded on CRAN's main listing; trying Archive/)")
    status <- curl_status(sprintf("https://cran.r-project.org/src/contrib/Archive/%s/%s_%s.tar.gz",
                                  pkg, pkg, version), tar_path)
  }
  if (status == 22L) {
    stop("CRAN has no ", pkg, " ", version, " (neither src/contrib/ nor Archive/); ",
         "correct the Version cell in the catalog md", call. = FALSE)
  }
  if (status != 0L || !file.exists(tar_path) || file.size(tar_path) == 0L) {
    stop("CRAN download of ", pkg, " ", version, " failed (curl exit status ", status, ")", call. = FALSE)
  }
  utils::untar(tar_path, exdir = dirname(pkg_dir))
  if (!file.exists(file.path(pkg_dir, "DESCRIPTION"))) {
    stop("CRAN tarball for ", pkg, " ", version, " did not extract as expected (partial download?)", call. = FALSE)
  }
  pkg_dir
}

#' Download a GitHub repo at a pinned commit (source tarball, no
#' `devtools::install_github()`) and extract it under `work_dir`; returns the
#' package directory. An earlier extraction of the same commit is reused.
#'
#' @param repo "owner/name" GitHub repo spec.
#' @param commit_sha Pinned commit SHA (full or abbreviated).
github_extract_repo <- function(repo, commit_sha, work_dir) {
  repo_dir <- file.path(work_dir, paste0(".extract_gh_", basename(repo), "_", commit_sha))
  # GitHub tarballs extract to "<repo>-<sha>/", not "<repo>/"
  pkg_dir <- list.files(repo_dir, full.names = TRUE)
  if (length(pkg_dir) == 1L) return(pkg_dir)
  url <- sprintf("https://github.com/%s/archive/%s.tar.gz", repo, commit_sha)
  tar_path <- file.path(work_dir, paste0(".raw_gh_", basename(repo), "_", commit_sha, ".tar.gz"))
  on.exit(unlink(tar_path))
  status <- curl_status(url, tar_path)
  if (status != 0L || !file.exists(tar_path) || file.size(tar_path) == 0L) {
    stop("GitHub download failed (curl exit status ", status, "): ", url, call. = FALSE)
  }
  unlink(repo_dir, recursive = TRUE)
  utils::untar(tar_path, exdir = repo_dir)
  pkg_dir <- list.files(repo_dir, full.names = TRUE)
  if (length(pkg_dir) != 1L) stop("GitHub tarball for ", repo, " did not extract as expected", call. = FALSE)
  pkg_dir
}

#' Load one data object from an extracted package's data/ directory the way
#' `data()` would: .rda/.RData are `load()`ed, a data/<obj>.R script is
#' `sys.source()`d (old releases only, e.g. Epi 1.1.10's thoro.R), and
#' .txt/.csv/.tab/.tsv tables are read with `fread()`. Compression suffixes are
#' ignored (s20x 3.1-10 ships teach.df.txt.gz; fread reads .gz directly). Returns a
#' data.frame.
#'
#' @param obj_name The object to return. For a file that bundles several objects
#'   (e.g. `survival`'s data/cancer.rda, which holds veteran/ovarian/colon/bladder1
#'   and more), this picks one; NULL takes the first object the file defines.
#' @param file_name The data/ file holding the object, without extension. NULL
#'   (default) tries every .rda/.RData file, then a table or .R file named
#'   `obj_name`, until one yields `obj_name` -- the file name often differs from the
#'   object's (cancer.rda again).
#' @param list_element For an object that is a named list of tables (e.g.
#'   `stevedata::mm_randhie`'s "RAND Baseline" and "RAND Outcomes"), the one to use.
#' @param label How to name the package in error messages.
load_data_object <- function(pkg_dir, obj_name = NULL, file_name = NULL, list_element = NULL,
                             label = basename(pkg_dir)) {
  if (is.null(obj_name) && is.null(file_name)) stop("load_data_object() needs obj_name or file_name", call. = FALSE)
  searching <- is.null(file_name)
  stem_wanted <- if (searching) obj_name else file_name
  data_files <- list.files(file.path(pkg_dir, "data"))
  stems <- tools::file_path_sans_ext(data_files, compression = TRUE)
  exts <- tolower(tools::file_ext(sub("\\.(gz|bz2|xz)$", "", data_files, ignore.case = TRUE)))
  candidates <- which(stems == stem_wanted | (searching & exts %in% c("rda", "rdata")))
  if (length(candidates) == 0L) {
    stop("No data/ file for '", stem_wanted, "' in ", label, " (found: ", paste(data_files, collapse = ", "), ")", call. = FALSE)
  }
  # While searching, a file that fails to load or lacks the object is skipped, not fatal.
  give_up <- function(...) if (searching) NULL else stop(..., call. = FALSE)
  obj <- NULL
  for (i in candidates) {
    path <- file.path(pkg_dir, "data", data_files[[i]])
    if (exts[[i]] %in% c("rda", "rdata", "r")) {
      e <- new.env()
      loaded <- tryCatch({
        if (exts[[i]] == "r") sys.source(path, envir = e, chdir = TRUE) else load(path, envir = e)
        TRUE
      }, error = function(err) { give_up("Could not load ", path, ": ", conditionMessage(err)); FALSE })
      if (!loaded) next
      want <- if (!is.null(obj_name)) obj_name else ls(e)[1L]
      if (is.na(want) || !want %in% ls(e)) {
        give_up("Object '", if (is.null(obj_name)) "<any>" else obj_name, "' not in data/", data_files[[i]], " of ", label,
                " (available: ", paste(ls(e), collapse = ", "), ")")
        next
      }
      obj <- get(want, envir = e)
    } else if (exts[[i]] %in% c("txt", "csv", "tab", "tsv")) {
      obj <- tryCatch(
        if (exts[[i]] %in% c("tab", "tsv")) data.table::fread(path, sep = "\t", quote = "", data.table = FALSE)
        else data.table::fread(path, data.table = FALSE),
        error = function(err) give_up("Could not read ", path, ": ", conditionMessage(err)))
      if (is.null(obj)) next
    } else {
      give_up("Unsupported data/ file type: ", data_files[[i]], " in ", label)
      next
    }
    break
  }
  if (is.null(obj)) {
    stop(obj_name, " not found in any data/ file of ", label, " (checked: ", paste(data_files[candidates], collapse = ", "), ")",
         call. = FALSE)
  }
  if (is.list(obj) && !is.data.frame(obj) && !is.null(list_element)) {
    if (!list_element %in% names(obj)) {
      stop("list_element '", list_element, "' not found in ", label, " (available: ", paste(names(obj), collapse = ", "), ")",
           call. = FALSE)
    }
    obj <- obj[[list_element]]
  }
  if (!(is.data.frame(obj) || is.matrix(obj))) {
    stop("Data object in ", label, " is not a data.frame/matrix (class: ", class(obj)[1L], ") -- needs a bespoke conversion",
         call. = FALSE)
  }
  as.data.frame(obj)
}

#' Fetch one data object from a pinned CRAN release and write it to `dest_csv`.
#' Arguments as for cran_extract_package() and load_data_object().
cran_dataset_as_csv <- function(pkg, version, dest_csv, work_dir, obj_name = NULL, file_name = NULL,
                                list_element = NULL) {
  pkg_dir <- cran_extract_package(pkg, version, work_dir)
  data.table::fwrite(load_data_object(pkg_dir, obj_name, file_name, list_element, label = paste(pkg, version)), dest_csv)
  invisible(dest_csv)
}

#' Same as cran_dataset_as_csv() for a GitHub repo at a pinned commit.
github_dataset_as_csv <- function(repo, commit_sha, dest_csv, work_dir, obj_name = NULL, file_name = NULL) {
  pkg_dir <- github_extract_repo(repo, commit_sha, work_dir)
  data.table::fwrite(load_data_object(pkg_dir, obj_name, file_name, label = paste0(repo, "@", commit_sha)), dest_csv)
  invisible(dest_csv)
}

# Remove the .extract_* / .raw_* scratch the fetchers above leave under work_dir.
clean_fetch_scratch <- function(work_dir) {
  unlink(list.files(work_dir, pattern = "^\\.(extract|raw)_", all.files = TRUE, full.names = TRUE), recursive = TRUE)
}

# ---------------------------------------------------------------------------
# Post-download joins -- datasets published as several tables. A manifest
# entry with `combine` (a function of the named list of its downloaded
# tables) and `combined_csv` is packed as that single joined CSV instead of
# its constituent files.
# ---------------------------------------------------------------------------

school_means <- function(df, cols) {
  out <- stats::aggregate(df[cols], by = list(schid = df$schid), FUN = mean, na.rm = TRUE)
  out[cols] <- lapply(out[cols], function(x) replace(x, is.nan(x), NA))
  out
}

school_counts <- function(df, name) {
  out <- as.data.frame(table(df$schid), stringsAsFactors = FALSE)
  names(out) <- c("schid", name)
  out$schid <- as.numeric(out$schid)
  out
}

# Per-school counts over unannounced random checks, coded per the visit
# checklist NFE_Random_Check.pdf (1 = yes, 2 = no; -999/-777 = missing). A
# closed school (a1_1 != 1) skips the teacher questions, so it counts as no
# teacher present. "Teaching" is first-teacher activity a2_3 codes 1-5:
# reading to children, writing on the blackboard, writing in a book, talking
# to a child, talking to the whole class (6-8 and 996 are playing, talking
# to an adult, walking outside, other).
random_check_summaries <- function(checks, suffix) {
  open <- checks$a1_1 %in% 1
  present <- open & checks$a2_0 %in% 1
  per_visit <- data.frame(
    n_checks = 1L,
    n_open = as.integer(open),
    n_teacher_present = as.integer(present),
    n_teacher_teaching = as.integer(present & checks$a2_3 %in% 1:5),
    n_second_teacher = as.integer(present & checks$a3_0 %in% 1),
    n_blackboard_written = as.integer(open & checks$a6_2 %in% 1)
  )
  counts <- stats::aggregate(per_visit, by = list(schid = checks$schid), FUN = sum)
  children <- replace(checks$a4_1, !open | checks$a4_1 < 0, NA)
  kids <- school_means(data.frame(schid = checks$schid, children_present_mean = children), "children_present_mean")
  out <- merge(counts, kids, by = "schid")
  names(out)[-1] <- paste0(names(out)[-1], "_", suffix)
  out
}

#' monitoring_works (Duflo, Hanna & Ryan): one row per post-tested child,
#' with that child's scores and their school's data repeated on every row.
#' Treatment is school membership in TreatmentSchools (the 60 schools
#' originally assigned; randomization is by school). School-level columns:
#' pretest means (child pretest and posttest records cannot be linked --
#' `childno` repeats within schools and same-key pre/post scores correlate
#' only ~0.1, so the numbering was reassigned between tests); random-check
#' summaries before (`_baseline`) and from (`_program`) the September 2003
#' start; camera valid-day counts, which exist for treated schools only and
#' are NA for comparison schools; and months closed.
combine_monitoring_works <- function(tables) {
  treated <- tables$monitoring_works_TreatmentSchools$schid
  pre <- tables$monitoring_works_Pretest
  post <- tables$monitoring_works_Posttest
  checks <- tables$monitoring_works_RandomCheck
  closed <- tables$monitoring_works_Closed
  camera <- tables$monitoring_works_ValidDay
  is_baseline <- checks$year * 100 + checks$month < 200309

  pre_cols <- c("pre_math_v", "pre_lang_v", "pre_total_v", "pre_math_w", "pre_lang_w", "pre_total_w", "pre_writ")
  school_pre <- merge(school_counts(pre, "pre_n_children"), school_means(pre, pre_cols), by = "schid")
  names(school_pre)[-1] <- paste0("school_", sub("pre_writ", "pre_share_written", names(school_pre)[-1]))
  camera_days <- stats::aggregate(
    data.frame(n_camera_days = 1L, n_camera_valid_days = as.integer(camera$validday == "Yes")),
    by = list(schid = camera$schid), FUN = sum)

  schools <- data.frame(schid = sort(unique(c(pre$schid, post$schid, checks$schid))))
  pieces <- list(
    school_pre,
    random_check_summaries(checks[is_baseline, ], "baseline"),
    random_check_summaries(checks[!is_baseline, ], "program"),
    camera_days,
    school_counts(closed, "n_months_closed")
  )
  for (p in pieces) schools <- merge(schools, p, by = "schid", all.x = TRUE)
  count_cols <- grep("^(n_|school_pre_n_)", names(schools), value = TRUE)
  count_cols <- setdiff(count_cols, c("n_camera_days", "n_camera_valid_days"))
  schools[count_cols] <- lapply(schools[count_cols], function(x) replace(x, is.na(x), 0L))

  children <- post
  names(children)[names(children) == "post_writ"] <- "took_written_test"
  children$treatment <- as.integer(children$schid %in% treated)
  out <- merge(children, schools, by = "schid", all.x = TRUE)
  out <- out[order(out$schid, out$childno), c("schid", "childno", "treatment", setdiff(names(out), c("schid", "childno", "treatment")))]
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------------------
# Dataset manifest -- every Dataverse-sourced row in experimental_datasets.md
# ---------------------------------------------------------------------------

# The manifest says how to fetch and normalize each dataset, never which release: every
# CRAN version and GitHub commit comes from the Version column of experimental_datasets.md
# (catalog_row() below), so the catalog's License/Redistribution cells always describe the
# release actually downloaded. Ten rows are pinned to old GPL-3-compatible releases on
# purpose (PASWR 1.1, s20x 3.1-10, coin 0.6-4, nlmeU 0.70-9; see dataset_license_audit.md).
DATASET_MANIFEST <- list(
  # ---- Core tier, CRAN-sourced -- migrated from install.packages()+data()
  # to the install-free mechanism for consistency with every Expanded-tier
  # CRAN dataset.
  veteran = list(cran = list(pkg = "survival", rda_name = "cancer", obj_name = "veteran", out_csv = "core_veteran.csv")),
  ovarian = list(cran = list(pkg = "survival", rda_name = "cancer", obj_name = "ovarian", out_csv = "core_ovarian.csv")),
  colon = list(cran = list(pkg = "survival", rda_name = "cancer", obj_name = "colon", out_csv = "core_colon.csv")),
  pbc = list(cran = list(pkg = "survival", rda_name = "pbc", out_csv = "core_pbc.csv")),
  respdis = list(cran = list(pkg = "geepack", rda_name = "respdis", out_csv = "core_respdis.csv")),
  respiratory = list(cran = list(pkg = "geepack", rda_name = "respiratory", out_csv = "core_respiratory.csv")),
  strep_tb = list(cran = list(pkg = "medicaldata", rda_name = "strep_tb", out_csv = "core_strep_tb.csv")),
  licorice_gargle = list(cran = list(pkg = "medicaldata", rda_name = "licorice_gargle", out_csv = "core_licorice_gargle.csv")),
  polyps = list(cran = list(pkg = "medicaldata", rda_name = "polyps", out_csv = "core_polyps.csv")),
  indo_rct = list(cran = list(pkg = "medicaldata", rda_name = "indo_rct", out_csv = "core_indo_rct.csv")),
  laryngoscope = list(cran = list(pkg = "medicaldata", rda_name = "laryngoscope", out_csv = "core_laryngoscope.csv")),
  lalonde.exp = list(cran = list(pkg = "qte", rda_name = "lalonde", out_csv = "core_lalonde_exp.csv")),
  STAR = list(cran = list(pkg = "AER", rda_name = "STAR", out_csv = "core_STAR.csv")),
  ResumeNames = list(cran = list(pkg = "AER", rda_name = "ResumeNames", out_csv = "core_ResumeNames.csv")),
  mm_randhie = list(cran = list(pkg = "stevedata", rda_name = "mm_randhie", out_csv = "core_mm_randhie.csv", list_element = "RAND Outcomes")),
  diabetic = list(cran = list(pkg = "survival", rda_name = "diabetic", out_csv = "core_diabetic.csv")),
  bladder1 = list(cran = list(pkg = "survival", rda_name = "cancer", obj_name = "bladder1", out_csv = "core_bladder1.csv")),
  rhDNase = list(cran = list(pkg = "survival", rda_name = "rhDNase", out_csv = "core_rhDNase.csv")),
  cgd = list(cran = list(pkg = "survival", rda_name = "cgd", out_csv = "core_cgd.csv")),
  udca = list(cran = list(pkg = "survival", rda_name = "udca", out_csv = "core_udca.csv")),
  solder = list(cran = list(pkg = "survival", rda_name = "solder", out_csv = "core_solder.csv")),

  # ---- Core tier, GitHub-sourced (experimentdatar, no CRAN listing) ----
  charitable = list(github = list(repo = "itamarcaspi/experimentdatar", rda_name = "charitable", out_csv = "core_charitable.csv")),
  mobilization = list(github = list(repo = "itamarcaspi/experimentdatar", rda_name = "mobilization", out_csv = "core_mobilization.csv")),
  social = list(github = list(repo = "itamarcaspi/experimentdatar", rda_name = "social", out_csv = "core_social.csv")),
  secrecy = list(github = list(repo = "itamarcaspi/experimentdatar", rda_name = "secrecy", out_csv = "core_secrecy.csv")),
  vouchers = list(github = list(repo = "itamarcaspi/experimentdatar", rda_name = "vouchers", out_csv = "core_vouchers.csv")),
  welfare = list(github = list(repo = "itamarcaspi/experimentdatar", rda_name = "welfare", out_csv = "core_welfare.csv")),

  # Roster.csv is not fetched: it is a variable-description sheet for a
  # roster data file the deposit does not include.
  monitoring_works = list(
    doi = "doi:10.7910/DVN/LRDXHX",
    files = list(
      TreatmentSchools.tab = "monitoring_works_TreatmentSchools.csv",
      Posttest.tab         = "monitoring_works_Posttest.csv",
      Pretest.tab          = "monitoring_works_Pretest.csv",
      Closed.tab           = "monitoring_works_Closed.csv",
      RandomCheck.tab      = "monitoring_works_RandomCheck.csv",
      ValidDay.tab         = "monitoring_works_ValidDay.csv"
    ),
    combine = combine_monitoring_works,
    combined_csv = "monitoring_works.csv"
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
      list(zip_filename = "PUBLISH.zip", member_basename = "analysis.dta", dest_csv = "immig_analysis.csv")
    )
  ),
  hiv = list(
    doi = "doi:10.7910/DVN/CVOPZL",
    zip_members = list(
      list(zip_filename = "data.zip", member_basename = "Phase2_sample_list.dta", dest_csv = "hiv_Phase2_sample_list.csv")
    )
  )
  ,
  # ---- CRAN-sourced Expanded-tier datasets from earlier rounds (3-4,
  # predating the exhaustive sweep), migrated here for consistency -- same
  # install-free mechanism, no reason for these to differ from the sweep's
  # datasets just because they were found first. Core-tier CRAN datasets
  # (the original 32) are NOT migrated -- they predate this mechanism and
  # are already relied on via the ordinary install.packages()+data()
  # pattern documented above; changing that is a separate decision.
  tanf = list(cran = list(pkg = "whatifbandit", rda_name = "tanf", out_csv = "tanf.csv")),
  gastric_cancer_trial_df = list(cran = list(pkg = "DigestiveDataSets", rda_name = "gastric_cancer_trial_df", out_csv = "gastric_cancer_trial_df.csv")),
  liver_cirrhosis_prednisone_df = list(cran = list(pkg = "DigestiveDataSets", rda_name = "liver_cirrhosis_prednisone_df", out_csv = "liver_cirrhosis_prednisone_df.csv")),
  WSCdata = list(cran = list(pkg = "WSCdata", rda_name = "WSCdata", out_csv = "WSCdata.csv")),
  immigrationconjoint = list(cran = list(pkg = "cjoint", rda_name = "immigrationconjoint", out_csv = "immigrationconjoint.csv")),
  epilepsy_RCT_tbl_df = list(cran = list(pkg = "NeuroDataSets", rda_name = "epilepsy_RCT_tbl_df", out_csv = "epilepsy_RCT_tbl_df.csv")),
  sulphinpyrazone_tbl_df = list(cran = list(pkg = "CardioDataSets", rda_name = "sulphinpyrazone_tbl_df", out_csv = "sulphinpyrazone_tbl_df.csv")),
  Gbsg_df = list(cran = list(pkg = "ForCausality", rda_name = "Gbsg_df", out_csv = "Gbsg_df.csv")),
  seguro = list(cran = list(pkg = "experiment", rda_name = "seguro", out_csv = "seguro.csv")),
  ajps = list(cran = list(pkg = "GK2011", rda_name = "ajps", out_csv = "ajps.csv")),
  pakistan = list(cran = list(pkg = "endorse", rda_name = "pakistan", out_csv = "pakistan.csv")),
  berberis_treatment = list(cran = list(pkg = "ecoteach", rda_name = "berberis_treatment", out_csv = "berberis_treatment.csv")),
  PowderyMildew = list(cran = list(pkg = "epifitter", rda_name = "PowderyMildew", out_csv = "PowderyMildew.csv")),
  train1 = list(cran = list(pkg = "callback", rda_name = "train1", out_csv = "train1.csv")),
  opt = list(cran = list(pkg = "medicaldata", rda_name = "opt", out_csv = "opt.csv")),
  supraclavicular = list(cran = list(pkg = "medicaldata", rda_name = "supraclavicular", out_csv = "supraclavicular.csv")),

  # ---- CRAN-sourced datasets from the exhaustive sweep (round 4), no
  # install.packages() needed -- see cran_dataset_as_csv() ----
  clubSandwich_AchievementAwardsRCT = list(cran = list(pkg = "clubSandwich", rda_name = "AchievementAwardsRCT", out_csv = "clubSandwich_AchievementAwardsRCT.csv")),
  asaur_pharmacoSmoking = list(cran = list(pkg = "asaur", rda_name = "pharmacoSmoking", out_csv = "asaur_pharmacoSmoking.csv")),
  afex_laptop_urry = list(cran = list(pkg = "afex", rda_name = "laptop_urry", out_csv = "afex_laptop_urry.csv")),
  cofad_testing_effect = list(cran = list(pkg = "cofad", rda_name = "testing_effect", out_csv = "cofad_testing_effect.csv")),
  causalweight_JC = list(cran = list(pkg = "causalweight", rda_name = "JC", out_csv = "causalweight_JC.csv")),
  causalweight_india = list(cran = list(pkg = "causalweight", rda_name = "india", out_csv = "causalweight_india.csv")),
  causalweight_wexpect = list(cran = list(pkg = "causalweight", rda_name = "wexpect", out_csv = "causalweight_wexpect.csv")),
  causalweight_coffeeleaflet = list(cran = list(pkg = "causalweight", rda_name = "coffeeleaflet", out_csv = "causalweight_coffeeleaflet.csv")),
  causalweight_swissexper = list(cran = list(pkg = "causalweight", rda_name = "swissexper", out_csv = "causalweight_swissexper.csv")),
  causalOT_pph = list(cran = list(pkg = "causalOT", rda_name = "pph", out_csv = "causalOT_pph.csv")),
  causalSLSE_nsw = list(cran = list(pkg = "causalSLSE", rda_name = "nsw", out_csv = "causalSLSE_nsw.csv")),
  causaldata_black_politicians = list(cran = list(pkg = "causaldata", rda_name = "black_politicians", out_csv = "causaldata_black_politicians.csv")),
  ClinicalTrialSummary_ggas = list(cran = list(pkg = "ClinicalTrialSummary", rda_name = "ggas", out_csv = "ClinicalTrialSummary_ggas.csv")),
  baggr_microcredit = list(cran = list(pkg = "baggr", rda_name = "microcredit", out_csv = "baggr_microcredit.csv")),
  asbio_potash = list(cran = list(pkg = "asbio", rda_name = "potash", out_csv = "asbio_potash.csv")),
  collett_prostatic = list(cran = list(pkg = "collett", rda_name = "prostatic", out_csv = "collett_prostatic.csv")),
  collett_tamoxifen = list(cran = list(pkg = "collett", rda_name = "tamoxifen", out_csv = "collett_tamoxifen.csv")),
  collett_active_hepatitis = list(cran = list(pkg = "collett", rda_name = "active_hepatitis", out_csv = "collett_active_hepatitis.csv")),
  BGPhazard_gehan = list(cran = list(pkg = "BGPhazard", rda_name = "gehan", out_csv = "BGPhazard_gehan.csv")),
  coxphw_biofeedback = list(cran = list(pkg = "coxphw", rda_name = "biofeedback", out_csv = "coxphw_biofeedback.csv")),
  CrossCarry_Water = list(cran = list(pkg = "CrossCarry", rda_name = "Water", out_csv = "CrossCarry_Water.csv")),
  dae_McIntyreTMV_dat = list(cran = list(pkg = "dae", rda_name = "McIntyreTMV.dat", out_csv = "dae_McIntyreTMV.csv")),
  dae_Oats_dat = list(cran = list(pkg = "dae", rda_name = "Oats.dat", out_csv = "dae_Oats.csv")),
  cvGEE_aids = list(cran = list(pkg = "cvGEE", rda_name = "aids", out_csv = "cvGEE_aids.csv")),
  DeepLearningCausal_exp_data = list(cran = list(pkg = "DeepLearningCausal", rda_name = "exp_data", out_csv = "DeepLearningCausal_exp_data.csv")),
  DeepLearningCausal_exp_data_full = list(cran = list(pkg = "DeepLearningCausal", rda_name = "exp_data_full", out_csv = "DeepLearningCausal_exp_data_full.csv")),
  coursekata_TipExperiment = list(cran = list(pkg = "coursekata", rda_name = "TipExperiment", out_csv = "coursekata_TipExperiment.csv")),
  DoseFinding_migraine = list(cran = list(pkg = "DoseFinding", rda_name = "migraine", out_csv = "DoseFinding_migraine.csv")),
  ecotox_lamprey_tox = list(cran = list(pkg = "ecotox", rda_name = "lamprey_tox", out_csv = "ecotox_lamprey_tox.csv")),
  emplik_smallcell = list(cran = list(pkg = "emplik", rda_name = "smallcell", out_csv = "emplik_smallcell.csv")),
  EngrExpt_uvcoatin = list(cran = list(pkg = "EngrExpt", rda_name = "uvcoatin", out_csv = "EngrExpt_uvcoatin.csv")),
  esci_data_rattanmotivation = list(cran = list(pkg = "esci", rda_name = "data_rattanmotivation", out_csv = "esci_rattanmotivation.csv")),
  esci_data_selfexplain = list(cran = list(pkg = "esci", rda_name = "data_selfexplain", out_csv = "esci_selfexplain.csv")),
  EstimationTools_head_neck_cancer = list(cran = list(pkg = "EstimationTools", rda_name = "head_neck_cancer", out_csv = "EstimationTools_headneck.csv")),
  coin_rotarod = list(cran = list(pkg = "coin", rda_name = "rotarod", out_csv = "coin_rotarod.csv")),
  experimentr_mcgrath = list(cran = list(pkg = "experimentr", rda_name = "mcgrath", out_csv = "experimentr_mcgrath.csv")),
  experimentr_sherman = list(cran = list(pkg = "experimentr", rda_name = "sherman", out_csv = "experimentr_sherman.csv")),
  faraway_coagulation = list(cran = list(pkg = "faraway", rda_name = "coagulation", out_csv = "faraway_coagulation.csv")),
  faraway_fruitfly = list(cran = list(pkg = "faraway", rda_name = "fruitfly", out_csv = "faraway_fruitfly.csv")),
  faraway_hips = list(cran = list(pkg = "faraway", rda_name = "hips", out_csv = "faraway_hips.csv")),
  faraway_irrigation = list(cran = list(pkg = "faraway", rda_name = "irrigation", out_csv = "faraway_irrigation.csv")),
  frailtyHL_bladder0 = list(cran = list(pkg = "frailtyHL", rda_name = "bladder0", out_csv = "frailtyHL_bladder0.csv")),
  frailtyHL_ren = list(cran = list(pkg = "frailtyHL", rda_name = "ren", out_csv = "frailtyHL_ren.csv")),
  frailtypack_bcos = list(cran = list(pkg = "frailtypack", rda_name = "bcos", out_csv = "frailtypack_bcos.csv")),
  frailtypack_colorectal = list(cran = list(pkg = "frailtypack", rda_name = "colorectal", out_csv = "frailtypack_colorectal.csv")),
  frailtypack_dataOvarian = list(cran = list(pkg = "frailtypack", rda_name = "dataOvarian", out_csv = "frailtypack_dataOvarian.csv")),
  frailtypack_gastadj = list(cran = list(pkg = "frailtypack", rda_name = "gastadj", out_csv = "frailtypack_gastadj.csv")),
  frailtypack_reduce = list(cran = list(pkg = "frailtypack", rda_name = "reduce", out_csv = "frailtypack_reduce.csv")),
  geecure_smoking = list(cran = list(pkg = "geecure", rda_name = "smoking", out_csv = "geecure_smoking.csv")),
  geecure_tonsil = list(cran = list(pkg = "geecure", rda_name = "tonsil", out_csv = "geecure_tonsil.csv")),
  geer_cerebrovascular = list(cran = list(pkg = "geer", rda_name = "cerebrovascular", out_csv = "geer_cerebrovascular.csv")),
  geer_cholecystectomy = list(cran = list(pkg = "geer", rda_name = "cholecystectomy", out_csv = "geer_cholecystectomy.csv")),
  geer_depression = list(cran = list(pkg = "geer", rda_name = "depression", out_csv = "geer_depression.csv")),
  geer_leprosy = list(cran = list(pkg = "geer", rda_name = "leprosy", out_csv = "geer_leprosy.csv")),
  geer_rinse = list(cran = list(pkg = "geer", rda_name = "rinse", out_csv = "geer_rinse.csv")),
  GJRM_data_hie = list(cran = list(pkg = "GJRM.data", rda_name = "hie", out_csv = "GJRMdata_hie.csv")),
  glmm_bacteria = list(cran = list(pkg = "glmm", rda_name = "bacteria", out_csv = "glmm_bacteria.csv")),
  glmtoolbox_amenorrhea = list(cran = list(pkg = "glmtoolbox", rda_name = "amenorrhea", out_csv = "glmtoolbox_amenorrhea.csv")),
  glmtoolbox_ossification = list(cran = list(pkg = "glmtoolbox", rda_name = "ossification", out_csv = "glmtoolbox_ossification.csv")),
  gosset_breadwheat = list(cran = list(pkg = "gosset", rda_name = "breadwheat", out_csv = "gosset_breadwheat.csv")),
  gosset_nicabean = list(cran = list(pkg = "gosset", rda_name = "nicabean", out_csv = "gosset_nicabean.csv", list_element = "trial")),
  gpk_cloudseed = list(cran = list(pkg = "gpk", rda_name = "cloudseed", out_csv = "gpk_cloudseed.csv")),
  granova_arousal = list(cran = list(pkg = "granova", rda_name = "arousal", out_csv = "granova_arousal.csv")),
  gss_bacteriuria = list(cran = list(pkg = "gss", rda_name = "bacteriuria", out_csv = "gss_bacteriuria.csv")),
  hamlet_orxwide = list(cran = list(pkg = "hamlet", rda_name = "orxwide", out_csv = "hamlet_orxwide.csv")),
  heplots_RatWeight = list(cran = list(pkg = "heplots", rda_name = "RatWeight", out_csv = "heplots_RatWeight.csv")),
  heritable_lettuce_phenotypes = list(cran = list(pkg = "heritable", rda_name = "lettuce_phenotypes", out_csv = "heritable_lettuce.csv")),
  hiddenf_Graybill_mtx = list(cran = list(pkg = "hiddenf", rda_name = "Graybill.mtx", out_csv = "hiddenf_Graybill.csv")),
  HLMdiag_ahd = list(cran = list(pkg = "HLMdiag", rda_name = "ahd", out_csv = "HLMdiag_ahd.csv")),
  hnp_cbb = list(cran = list(pkg = "hnp", rda_name = "cbb", out_csv = "hnp_cbb.csv")),
  hnp_chryso = list(cran = list(pkg = "hnp", rda_name = "chryso", out_csv = "hnp_chryso.csv")),
  hnp_corn = list(cran = list(pkg = "hnp", rda_name = "corn", out_csv = "hnp_corn.csv")),
  hnp_fungi = list(cran = list(pkg = "hnp", rda_name = "fungi", out_csv = "hnp_fungi.csv")),
  hnp_oil = list(cran = list(pkg = "hnp", rda_name = "oil", out_csv = "hnp_oil.csv")),
  hnp_orange = list(cran = list(pkg = "hnp", rda_name = "orange", out_csv = "hnp_orange.csv")),
  hnp_progeny = list(cran = list(pkg = "hnp", rda_name = "progeny", out_csv = "hnp_progeny.csv")),
  HSAUR3_BtheB = list(cran = list(pkg = "HSAUR3", rda_name = "BtheB", out_csv = "HSAUR3_BtheB.csv")),
  HSAUR3_Lanza = list(cran = list(pkg = "HSAUR3", rda_name = "Lanza", out_csv = "HSAUR3_Lanza.csv")),
  HSAUR3_students = list(cran = list(pkg = "HSAUR3", rda_name = "students", out_csv = "HSAUR3_students.csv")),
  PASWR2_WEIGHTGAIN = list(cran = list(pkg = "PASWR2", rda_name = "WEIGHTGAIN", out_csv = "PASWR2_WeightGain.csv")),
  mediation_jobs = list(cran = list(pkg = "mediation", rda_name = "jobs", out_csv = "mediation_jobs.csv")),
  Matching_GerberGreenImai = list(cran = list(pkg = "Matching", rda_name = "GerberGreenImai", out_csv = "Matching_GerberGreenImai.csv")),
  lmPerm_Federer276 = list(cran = list(pkg = "lmPerm", rda_name = "Federer276", out_csv = "lmPerm_Federer276.csv")),
  lmPerm_Hald17_4 = list(cran = list(pkg = "lmPerm", rda_name = "Hald17.4", out_csv = "lmPerm_Hald.csv")),
  labstats_festing = list(cran = list(pkg = "labstats", rda_name = "festing", out_csv = "labstats_festing.csv")),
  labstats_fluoxetine = list(cran = list(pkg = "labstats", rda_name = "fluoxetine", out_csv = "labstats_fluoxetine.csv")),
  labstats_glycogen = list(cran = list(pkg = "labstats", rda_name = "glycogen", out_csv = "labstats_glycogen.csv")),
  labstats_hypertension = list(cran = list(pkg = "labstats", rda_name = "hypertension", out_csv = "labstats_hypertension.csv")),
  labstats_KH2004 = list(cran = list(pkg = "labstats", rda_name = "KH2004", out_csv = "labstats_KH2004.csv")),
  labstats_locomotor = list(cran = list(pkg = "labstats", rda_name = "locomotor", out_csv = "labstats_locomotor.csv")),
  labstats_VPA = list(cran = list(pkg = "labstats", rda_name = "VPA", out_csv = "labstats_VPA.csv")),
  KONPsurv_carcinoma = list(cran = list(pkg = "KONPsurv", rda_name = "carcinoma", out_csv = "KONPsurv_carcinoma.csv")),
  mice_toenail = list(cran = list(pkg = "mice", rda_name = "toenail", out_csv = "mice_toenail.csv")),
  ISwR_alkfos = list(cran = list(pkg = "ISwR", rda_name = "alkfos", out_csv = "ISwR_alkfos.csv")),
  invGauss_d_oropha_rec = list(cran = list(pkg = "invGauss", rda_name = "d.oropha.rec", out_csv = "invGauss_dorophar.csv")),
  lava_bmd = list(cran = list(pkg = "lava", rda_name = "bmd", out_csv = "lava_bmd.csv")),
  mhazard_anemia = list(cran = list(pkg = "mhazard", rda_name = "anemia", out_csv = "mhazard_anemia.csv")),
  isdals_cornyield = list(cran = list(pkg = "isdals", rda_name = "cornyield", out_csv = "isdals_cornyield.csv")),
  lqmm_labor = list(cran = list(pkg = "lqmm", rda_name = "labor", out_csv = "lqmm_labor.csv")),
  LongCART_ACTG175 = list(cran = list(pkg = "LongCART", rda_name = "ACTG175", out_csv = "LongCART_ACTG175.csv")),
  mixor_schizophrenia = list(cran = list(pkg = "mixor", rda_name = "schizophrenia", out_csv = "mixor_schizophrenia.csv")),
  mixor_SmokeOnset = list(cran = list(pkg = "mixor", rda_name = "SmokeOnset", out_csv = "mixor_SmokeOnset.csv")),
  mixor_SmokingPrevention = list(cran = list(pkg = "mixor", rda_name = "SmokingPrevention", out_csv = "mixor_SmokingPrevention.csv")),
  MNM_beans = list(cran = list(pkg = "MNM", rda_name = "beans", out_csv = "MNM_beans.csv")),
  moderate_mediation_newws = list(cran = list(pkg = "moderate.mediation", rda_name = "newws", out_csv = "modmed_newws.csv")),
  mosaicData_HELPrct = list(cran = list(pkg = "mosaicData", rda_name = "HELPrct", out_csv = "mosaicData_HELPrct.csv")),
  mosaicData_Mites = list(cran = list(pkg = "mosaicData", rda_name = "Mites", out_csv = "mosaicData_Mites.csv")),
  multiDimBio_Nuclei = list(cran = list(pkg = "multiDimBio", rda_name = "Nuclei", out_csv = "multiDimBio_Nuclei.csv")),
  nlme_Alfalfa = list(cran = list(pkg = "nlme", rda_name = "Alfalfa", out_csv = "nlme_Alfalfa.csv")),
  nlme_Assay = list(cran = list(pkg = "nlme", rda_name = "Assay", out_csv = "nlme_Assay.csv")),
  nlmeU_armd0 = list(cran = list(pkg = "nlmeU", rda_name = "armd0", out_csv = "nlmeU_armd0.csv")),
  nlmeU_prt_subjects = list(cran = list(pkg = "nlmeU", rda_name = "prt.subjects", out_csv = "nlmeU_prt.csv")),
  PASWR_Aggression = list(cran = list(pkg = "PASWR", rda_name = "Aggression", out_csv = "PASWR_Aggression.csv")),
  PASWR_Ratbp = list(cran = list(pkg = "PASWR", rda_name = "Ratbp", out_csv = "PASWR_Ratbp.csv")),
  PASWR_Swimtimes = list(cran = list(pkg = "PASWR", rda_name = "Swimtimes", out_csv = "PASWR_Swimtimes.csv")),
  PASWR2_EPIDURALF = list(cran = list(pkg = "PASWR2", rda_name = "EPIDURALF", out_csv = "PASWR2_Epidural.csv")),
  R4HCR_Acupuncture = list(cran = list(pkg = "R4HCR", rda_name = "Acupuncture", out_csv = "R4HCR_Acupuncture.csv")),
  R4HCR_Facemasks = list(cran = list(pkg = "R4HCR", rda_name = "Facemasks", out_csv = "R4HCR_Facemasks.csv")),
  powerSurvEpi_Oph = list(cran = list(pkg = "powerSurvEpi", rda_name = "Oph", out_csv = "powerSurvEpi_Oph.csv")),
  pscl_RockTheVote = list(cran = list(pkg = "pscl", rda_name = "RockTheVote", out_csv = "pscl_RockTheVote.csv")),
  QDComparison_Microfinance = list(cran = list(pkg = "QDComparison", rda_name = "Microfinance", out_csv = "QDComparison_Microfinance.csv")),
  quantreg_uis = list(cran = list(pkg = "quantreg", rda_name = "uis", out_csv = "quantreg_uis.csv")),
  RCT2_india = list(cran = list(pkg = "RCT2", rda_name = "india", out_csv = "RCT2_india.csv")),
  RCT2_jd = list(cran = list(pkg = "RCT2", rda_name = "jd", out_csv = "RCT2_jd.csv")),
  RESIDE_IST = list(cran = list(pkg = "RESIDE", rda_name = "IST", out_csv = "RESIDE_IST.csv")),
  Rfit_quail = list(cran = list(pkg = "Rfit", rda_name = "quail", out_csv = "Rfit_quail.csv")),
  Rlab_magnet = list(cran = list(pkg = "Rlab", rda_name = "magnet", out_csv = "Rlab_magnet.csv")),
  randomizationInference_reading = list(cran = list(pkg = "randomizationInference", rda_name = "reading", out_csv = "randinf_reading.csv")),
  RPEXE_RPEXT_data2 = list(cran = list(pkg = "RPEXE.RPEXT", rda_name = "data2", out_csv = "RPEXE_data2.csv")),
  rqlm_mch = list(cran = list(pkg = "rqlm", rda_name = "mch", out_csv = "rqlm_mch.csv")),
  s20x_teach_df = list(cran = list(pkg = "s20x", rda_name = "teach.df", out_csv = "s20x_teach.csv")),
  s20x_thyroid_df = list(cran = list(pkg = "s20x", rda_name = "thyroid.df", out_csv = "s20x_thyroid.csv")),
  sanon_cpain = list(cran = list(pkg = "sanon", rda_name = "cpain", out_csv = "sanon_cpain.csv")),
  sanon_sebor = list(cran = list(pkg = "sanon", rda_name = "sebor", out_csv = "sanon_sebor.csv")),
  sanon_skin = list(cran = list(pkg = "sanon", rda_name = "skin", out_csv = "sanon_skin.csv")),
  scidesignR_silkdat = list(cran = list(pkg = "scidesignR", rda_name = "silkdat", out_csv = "scidesignR_silkdat.csv")),
  SingleCaseES_Kelley2015 = list(cran = list(pkg = "SingleCaseES", rda_name = "Kelley2015", out_csv = "SingleCaseES_Kelley.csv")),
  SixSigma_ss_data_doe1 = list(cran = list(pkg = "SixSigma", rda_name = "ss.data.doe1", out_csv = "SixSigma_doe1.csv")),
  Sleuth2_case0101 = list(cran = list(pkg = "Sleuth2", rda_name = "case0101", out_csv = "Sleuth2_case0101.csv")),
  Sleuth2_case0301 = list(cran = list(pkg = "Sleuth2", rda_name = "case0301", out_csv = "Sleuth2_case0301.csv")),
  Sleuth2_case0402 = list(cran = list(pkg = "Sleuth2", rda_name = "case0402", out_csv = "Sleuth2_case0402.csv")),
  Sleuth2_case0501 = list(cran = list(pkg = "Sleuth2", rda_name = "case0501", out_csv = "Sleuth2_case0501.csv")),
  Sleuth2_case0601 = list(cran = list(pkg = "Sleuth2", rda_name = "case0601", out_csv = "Sleuth2_case0601.csv")),
  Sleuth2_case1301 = list(cran = list(pkg = "Sleuth2", rda_name = "case1301", out_csv = "Sleuth2_case1301.csv")),
  Sleuth2_case1302 = list(cran = list(pkg = "Sleuth2", rda_name = "case1302", out_csv = "Sleuth2_case1302.csv")),
  Sleuth2_case1402 = list(cran = list(pkg = "Sleuth2", rda_name = "case1402", out_csv = "Sleuth2_case1402.csv")),
  Sleuth2_case1602 = list(cran = list(pkg = "Sleuth2", rda_name = "case1602", out_csv = "Sleuth2_case1602.csv")),
  Sleuth3_ex0112 = list(cran = list(pkg = "Sleuth3", rda_name = "ex0112", out_csv = "Sleuth3_ex0112.csv")),
  Sleuth3_ex0211 = list(cran = list(pkg = "Sleuth3", rda_name = "ex0211", out_csv = "Sleuth3_ex0211.csv")),
  Sleuth3_ex0331 = list(cran = list(pkg = "Sleuth3", rda_name = "ex0331", out_csv = "Sleuth3_ex0331.csv")),
  Sleuth2_ex0429 = list(cran = list(pkg = "Sleuth2", rda_name = "ex0429", out_csv = "Sleuth2_ex0429.csv")),
  Sleuth3_ex0431 = list(cran = list(pkg = "Sleuth3", rda_name = "ex0431", out_csv = "Sleuth3_ex0431.csv")),
  Sleuth3_ex0432 = list(cran = list(pkg = "Sleuth3", rda_name = "ex0432", out_csv = "Sleuth3_ex0432.csv")),
  Sleuth3_ex0518 = list(cran = list(pkg = "Sleuth3", rda_name = "ex0518", out_csv = "Sleuth3_ex0518.csv")),
  Sleuth3_ex1014 = list(cran = list(pkg = "Sleuth3", rda_name = "ex1014", out_csv = "Sleuth3_ex1014.csv")),
  smbdata_beetles = list(cran = list(pkg = "smbdata", rda_name = "beetles", out_csv = "smbdata_beetles.csv")),
  smbdata_biomassc = list(cran = list(pkg = "smbdata", rda_name = "biomassc", out_csv = "smbdata_biomassc.csv")),
  smbdata_calcium = list(cran = list(pkg = "smbdata", rda_name = "calcium", out_csv = "smbdata_calcium.csv")),
  smbdata_calibrate = list(cran = list(pkg = "smbdata", rda_name = "calibrate", out_csv = "smbdata_calibrate.csv")),
  smbdata_cotton = list(cran = list(pkg = "smbdata", rda_name = "cotton", out_csv = "smbdata_cotton.csv")),
  smbdata_cuttings = list(cran = list(pkg = "smbdata", rda_name = "cuttings", out_csv = "smbdata_cuttings.csv")),
  smbdata_demethylation = list(cran = list(pkg = "smbdata", rda_name = "demethylation", out_csv = "smbdata_demethylation.csv")),
  smbdata_forage = list(cran = list(pkg = "smbdata", rda_name = "forage", out_csv = "smbdata_forage.csv")),
  smbdata_heights = list(cran = list(pkg = "smbdata", rda_name = "heights", out_csv = "smbdata_heights.csv")),
  smbdata_herbicide = list(cran = list(pkg = "smbdata", rda_name = "herbicide", out_csv = "smbdata_herbicide.csv")),
  smbdata_ladybird = list(cran = list(pkg = "smbdata", rda_name = "ladybird", out_csv = "smbdata_ladybird.csv")),
  smbdata_lupintrial = list(cran = list(pkg = "smbdata", rda_name = "lupintrial", out_csv = "smbdata_lupintrial.csv")),
  smbdata_potato = list(cran = list(pkg = "smbdata", rda_name = "potato", out_csv = "smbdata_potato.csv")),
  smbdata_prey = list(cran = list(pkg = "smbdata", rda_name = "prey", out_csv = "smbdata_prey.csv")),
  smbdata_tgw = list(cran = list(pkg = "smbdata", rda_name = "tgw", out_csv = "smbdata_tgw.csv")),
  smbdata_voltage = list(cran = list(pkg = "smbdata", rda_name = "voltage", out_csv = "smbdata_voltage.csv")),
  SMPracticals_arithmetic = list(cran = list(pkg = "SMPracticals", rda_name = "arithmetic", out_csv = "SMPracticals_arithmetic.csv")),
  SMPracticals_cake = list(cran = list(pkg = "SMPracticals", rda_name = "cake", out_csv = "SMPracticals_cake.csv")),
  SMPracticals_marking = list(cran = list(pkg = "SMPracticals", rda_name = "marking", out_csv = "SMPracticals_marking.csv")),
  SMPracticals_shoe = list(cran = list(pkg = "SMPracticals", rda_name = "shoe", out_csv = "SMPracticals_shoe.csv")),
  SMPracticals_teak = list(cran = list(pkg = "SMPracticals", rda_name = "teak", out_csv = "SMPracticals_teak.csv")),
  SpATS_wheatdata = list(cran = list(pkg = "SpATS", rda_name = "wheatdata", out_csv = "SpATS_wheatdata.csv")),
  splmm_cognitive = list(cran = list(pkg = "splmm", rda_name = "cognitive", out_csv = "splmm_cognitive.csv")),
  SRMData_Jumping = list(cran = list(pkg = "SRMData", rda_name = "Jumping", out_csv = "SRMData_Jumping.csv")),
  SRMData_SixMWT = list(cran = list(pkg = "SRMData", rda_name = "SixMWT", out_csv = "SRMData_SixMWT.csv")),
  Stat2Data_Alfalfa = list(cran = list(pkg = "Stat2Data", rda_name = "Alfalfa", out_csv = "Stat2Data_Alfalfa.csv")),
  Stat2Data_AutoPollution = list(cran = list(pkg = "Stat2Data", rda_name = "AutoPollution", out_csv = "Stat2Data_AutoPollution.csv")),
  Stat2Data_CalciumBP = list(cran = list(pkg = "Stat2Data", rda_name = "CalciumBP", out_csv = "Stat2Data_CalciumBP.csv")),
  Stat2Data_Contraceptives = list(cran = list(pkg = "Stat2Data", rda_name = "Contraceptives", out_csv = "Stat2Data_Contraceptives.csv")),
  Stat2Data_CrackerFiber = list(cran = list(pkg = "Stat2Data", rda_name = "CrackerFiber", out_csv = "Stat2Data_CrackerFiber.csv")),
  Stat2Data_FruitFlies2 = list(cran = list(pkg = "Stat2Data", rda_name = "FruitFlies2", out_csv = "Stat2Data_FruitFlies2.csv")),
  Stat2Data_FruitFlies = list(cran = list(pkg = "Stat2Data", rda_name = "FruitFlies", out_csv = "Stat2Data_FruitFlies.csv")),
  Stat2Data_Meniscus = list(cran = list(pkg = "Stat2Data", rda_name = "Meniscus", out_csv = "Stat2Data_Meniscus.csv")),
  Stat2Data_Milgram = list(cran = list(pkg = "Stat2Data", rda_name = "Milgram", out_csv = "Stat2Data_Milgram.csv")),
  Stat2Data_MusicTime = list(cran = list(pkg = "Stat2Data", rda_name = "MusicTime", out_csv = "Stat2Data_MusicTime.csv")),
  Stat2Data_PigFeed = list(cran = list(pkg = "Stat2Data", rda_name = "PigFeed", out_csv = "Stat2Data_PigFeed.csv")),
  Stat2Data_Popcorn = list(cran = list(pkg = "Stat2Data", rda_name = "Popcorn", out_csv = "Stat2Data_Popcorn.csv")),
  Stat2Data_SandwichAnts = list(cran = list(pkg = "Stat2Data", rda_name = "SandwichAnts", out_csv = "Stat2Data_SandwichAnts.csv")),
  Stat2Data_TipJoke = list(cran = list(pkg = "Stat2Data", rda_name = "TipJoke", out_csv = "Stat2Data_TipJoke.csv")),
  Stat2Data_WeightLossIncentive = list(cran = list(pkg = "Stat2Data", rda_name = "WeightLossIncentive", out_csv = "Stat2Data_WeightLossIncentive.csv")),
  Stat2Data_WordMemory = list(cran = list(pkg = "Stat2Data", rda_name = "WordMemory", out_csv = "Stat2Data_WordMemory.csv")),
  stepp_aspirin = list(cran = list(pkg = "stepp", rda_name = "aspirin", out_csv = "stepp_aspirin.csv")),
  stepp_bigCI = list(cran = list(pkg = "stepp", rda_name = "bigCI", out_csv = "stepp_bigCI.csv")),
  surrosurv_gastadv = list(cran = list(pkg = "surrosurv", rda_name = "gastadv", out_csv = "surrosurv_gastadv.csv")),
  survSAKK_esophagus = list(cran = list(pkg = "survSAKK", rda_name = "esophagus", out_csv = "survSAKK_esophagus.csv")),
  texmex_liver = list(cran = list(pkg = "texmex", rda_name = "liver", out_csv = "texmex_liver.csv")),
  TukeyC_SPET = list(cran = list(pkg = "TukeyC", rda_name = "SPET", out_csv = "TukeyC_SPET.csv", list_element = "dfm")),
  vegan_pyrifos = list(cran = list(pkg = "vegan", rda_name = "pyrifos", out_csv = "vegan_pyrifos.csv")),
  VGAMdata_belcap = list(cran = list(pkg = "VGAMdata", rda_name = "belcap", out_csv = "VGAMdata_belcap.csv")),
  WA_hfaction_cpx12 = list(cran = list(pkg = "WA", rda_name = "hfaction_cpx12", out_csv = "WA_hfaction.csv")),
  wgaim_phenoCxR = list(cran = list(pkg = "wgaim", rda_name = "phenoCxR", out_csv = "wgaim_phenoCxR.csv")),
  wgaim_phenoRxK = list(cran = list(pkg = "wgaim", rda_name = "phenoRxK", out_csv = "wgaim_phenoRxK.csv")),
  wgaim_phenoSxT = list(cran = list(pkg = "wgaim", rda_name = "phenoSxT", out_csv = "wgaim_phenoSxT.csv")),
  wooldridge_apple = list(cran = list(pkg = "wooldridge", rda_name = "apple", out_csv = "wooldridge_apple.csv")),
  WRS2_electric = list(cran = list(pkg = "WRS2", rda_name = "electric", out_csv = "WRS2_electric.csv")),
  WWGbook_ratpup = list(cran = list(pkg = "WWGbook", rda_name = "ratpup", out_csv = "WWGbook_ratpup.csv"))
)

# Every archive must hold exactly one CSV: an entry with several sources
# must also define `combine` and `combined_csv` to join them.
validate_manifest <- function(manifest) {
  for (name in names(manifest)) {
    spec <- manifest[[name]]
    n_sources <- length(spec$files) + length(spec$zip_members) + (!is.null(spec$cran)) + (!is.null(spec$github))
    if (n_sources == 0L) stop("Manifest entry '", name, "' has no source", call. = FALSE)
    has_combine <- !is.null(spec$combine) && !is.null(spec$combined_csv)
    if (n_sources > 1L && !has_combine) {
      stop("Manifest entry '", name, "' has ", n_sources, " source files but no `combine` + ",
           "`combined_csv` to join them; each archive must hold exactly one CSV", call. = FALSE)
    }
    if (xor(is.null(spec$combine), is.null(spec$combined_csv))) {
      stop("Manifest entry '", name, "' must set both `combine` and `combined_csv`, or neither", call. = FALSE)
    }
    if (!is.null(spec$cran$version) || !is.null(spec$github$commit_sha)) {
      stop("Manifest entry '", name, "' pins a version; pins live only in experimental_datasets.md", call. = FALSE)
    }
  }
  invisible(manifest)
}
validate_manifest(DATASET_MANIFEST)

# The md's dataset table reduced to what the fetchers need: one row per dataset with its
# manifest key (the Dataset name with "::" and other punctuation turned into "_"), Source
# ("CRAN: <pkg>", "GitHub: <owner/repo>", ...), Version (a CRAN release, or the commit of a
# "commit <sha>" cell), License and Redistribution.
catalog_rows <- function(md_path) {
  e <- new.env()
  sys.source(file.path(dirname(md_path), "build_experimental_datasets_csv.R"), envir = e)
  tbl <- e$read_dataset_table(md_path)
  dataset <- e$strip_md(tbl$Dataset)
  data.frame(dataset = dataset,
             key = gsub("[^A-Za-z0-9_]", "_", gsub("::", "_", dataset, fixed = TRUE)),
             source = e$strip_md(tbl$Source),
             version = sub("^commit ", "", e$strip_md(tbl$Version)),
             license = e$strip_md(tbl$License),
             redistribution = e$strip_md(tbl$Redistribution),
             stringsAsFactors = FALSE)
}

# The md row of manifest entry `name`, checked against the source the manifest fetches
# from (`expected_source`, e.g. "CRAN: coin"; NULL for Dataverse entries, whose DOI is not
# a pin). One key (`lalonde.exp`) keeps its literal dot, hence the match on either the key
# or the Dataset name.
catalog_row <- function(rows, name, expected_source = NULL) {
  hit <- rows[rows$key == name | rows$dataset == name, , drop = FALSE]
  if (nrow(hit) != 1L) {
    stop("Manifest entry '", name, "' matches ", nrow(hit), " rows of experimental_datasets.md; expected 1", call. = FALSE)
  }
  if (!is.null(expected_source) && !identical(hit$source, expected_source)) {
    stop("Manifest entry '", name, "' fetches from ", expected_source, " but experimental_datasets.md says ",
         hit$source, call. = FALSE)
  }
  hit
}

# Every row may be fetched and used locally, but a row whose Redistribution cell is not
# "yes..." says why each time it is downloaded or unpacked (user decision 2026-10-15; the
# cell vocabulary is in dataset_license_audit.md). Shared with download_observational_datasets.R.
warn_if_not_gpl3_compatible <- function(dataset, license, redistribution) {
  if (startsWith(redistribution, "yes")) return(invisible(FALSE))
  msg <- if (startsWith(redistribution, "no: GPL-2 only")) {
    sprintf("Dataset %s has license %s, which does not comply with GPL-3. Only use it if your use case complies with the license %s.",
            dataset, license, license)
  } else {
    sprintf("Dataset %s has license %s but is not cleared for use with GPL-3 (%s). Only use it if your use case complies with the license %s and those terms.",
            dataset, license, redistribution, license)
  }
  warning(msg, call. = FALSE, immediate. = TRUE)
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

#' Download and normalize every dataset in DATASET_MANIFEST, packing each
#' one's CSV into its own `<name>.tar.bz2` -- one archive per manifest
#' entry, not one combined archive for the whole collection. A dataset
#' published as several tables is joined into one CSV first (see the
#' `combine` field and "Post-download joins" above). This matches how `_dataset_load.R`
#' already loads the 14 existing ML-benchmark datasets one at a time: a
#' consumer extracts only the dataset it needs, and "already downloaded"
#' is a plain file-existence check on `<name>.tar.bz2` -- no extraction
#' needed to resume a partial run.
#'
#' @param download_dir Working/output directory (gitignored). Holds loose
#'   CSVs transiently during conversion, then one `<name>.tar.bz2` per
#'   dataset once packed.
#' @param keep_loose_csvs If FALSE (default), each dataset's loose CSV(s)
#'   are deleted right after that dataset's archive is written. Set TRUE
#'   to keep both (e.g. while developing this script).
#' @param datasets Names of DATASET_MANIFEST entries to fetch; default all.
#' @param catalog_md The catalog whose Version column pins every CRAN release and
#'   GitHub commit fetched. All requested pins are resolved before anything is
#'   downloaded, so a manifest entry with no matching md row fails up front.
download_all_datasets <- function(download_dir = file.path(EXPERIMENTAL_DIR, "randomized_experiment_datasets"),
                                   keep_loose_csvs = FALSE,
                                   datasets = names(DATASET_MANIFEST),
                                   catalog_md = file.path(EXPERIMENTAL_DIR, "experimental_datasets.md")) {
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)

  unknown <- setdiff(datasets, names(DATASET_MANIFEST))
  if (length(unknown) > 0L) stop("No manifest entry named '", unknown[[1L]], "'", call. = FALSE)
  md_rows <- catalog_rows(catalog_md)
  rows <- lapply(datasets, function(name) {
    spec <- DATASET_MANIFEST[[name]]
    expected_source <- if (!is.null(spec$cran)) paste0("CRAN: ", spec$cran$pkg)
                       else if (!is.null(spec$github)) paste0("GitHub: ", spec$github$repo)
    catalog_row(md_rows, name, expected_source)
  })
  names(rows) <- datasets
  pins <- vapply(rows, function(r) r$version, character(1))
  on.exit(clean_fetch_scratch(download_dir), add = TRUE)

  for (name in datasets) {
    spec <- DATASET_MANIFEST[[name]]
    archive_path <- file.path(download_dir, paste0(name, ".tar.bz2"))
    if (file.exists(archive_path)) {
      message("== ", name, " == already have ", archive_path)
      next
    }
    message("== ", name, " ==")
    warn_if_not_gpl3_compatible(rows[[name]]$dataset, rows[[name]]$license, rows[[name]]$redistribution)
    out_csvs <- character(0)

    if (!is.null(spec$files)) {
      for (remote_name in names(spec$files)) {
        out_csv <- file.path(download_dir, spec$files[[remote_name]])
        out_csvs <- c(out_csvs, out_csv)
        if (file.exists(out_csv)) { message("  already have ", out_csv); next }
        message("  downloading ", remote_name, " (Dataverse ", pins[[name]], ") ...")
        dataverse_file_as_csv(spec$doi, pins[[name]], remote_name, out_csv, download_dir)
        message("  -> ", out_csv)
      }
    }

    if (!is.null(spec$zip_members)) {
      for (zm in spec$zip_members) {
        out_csv <- file.path(download_dir, zm$dest_csv)
        out_csvs <- c(out_csvs, out_csv)
        if (file.exists(out_csv)) { message("  already have ", out_csv); next }
        message("  downloading ", zm$zip_filename, " (large; extracting ", zm$member_basename, ") ...")
        dataverse_file_as_csv(spec$doi, pins[[name]], zm$member_basename, out_csv, download_dir,
                              inside_zip = zm$zip_filename)
        message("  -> ", out_csv)
      }
    }

    if (!is.null(spec$cran)) {
      out_csv <- file.path(download_dir, spec$cran$out_csv)
      out_csvs <- c(out_csvs, out_csv)
      if (!file.exists(out_csv)) {
        message("  downloading CRAN ", spec$cran$pkg, " ", pins[[name]],
                " (", spec$cran$rda_name, ", no install.packages()) ...")
        cran_dataset_as_csv(spec$cran$pkg, pins[[name]], out_csv, download_dir,
                            obj_name = spec$cran$obj_name, file_name = spec$cran$rda_name,
                            list_element = spec$cran$list_element)
        message("  -> ", out_csv)
      }
    }

    if (!is.null(spec$github)) {
      out_csv <- file.path(download_dir, spec$github$out_csv)
      out_csvs <- c(out_csvs, out_csv)
      if (!file.exists(out_csv)) {
        message("  downloading GitHub ", spec$github$repo, "@", pins[[name]],
                " (", spec$github$rda_name, ", no install_github()) ...")
        github_dataset_as_csv(spec$github$repo, pins[[name]], out_csv, download_dir,
                              file_name = spec$github$rda_name)
        message("  -> ", out_csv)
      }
    }

    if (!is.null(spec$combine)) {
      tables <- lapply(out_csvs, data.table::fread, data.table = FALSE)
      names(tables) <- tools::file_path_sans_ext(basename(out_csvs))
      combined_csv <- file.path(download_dir, spec$combined_csv)
      data.table::fwrite(spec$combine(tables), combined_csv)
      message("  joined ", length(out_csvs), " tables -> ", combined_csv)
      if (!keep_loose_csvs) unlink(out_csvs)
      out_csvs <- combined_csv
    }

    stopifnot(length(out_csvs) == 1L)
    message("  packing -> ", archive_path)
    rel_csvs <- basename(out_csvs)
    old_wd <- setwd(download_dir)
    utils::tar(basename(archive_path), files = rel_csvs, compression = "bzip2")
    setwd(old_wd)

    if (!keep_loose_csvs) unlink(out_csvs)
  }
  message("Done. Run extract_experimental_datasets(<name>) to unpack any one dataset when you need it.")
  invisible(download_dir)
}

#' Unpack one dataset's `<name>.tar.bz2` back into loose CSV(s) for actual use.
#'
#' @param name Dataset name (a DATASET_MANIFEST key); its archive must
#'   already exist (run `download_all_datasets(datasets = name)` first if not).
#' @param catalog_md The catalog whose License/Redistribution cells decide whether
#'   unpacking warns (see warn_if_not_gpl3_compatible()).
extract_experimental_datasets <- function(name,
                                download_dir = file.path(EXPERIMENTAL_DIR, "randomized_experiment_datasets"),
                                catalog_md = file.path(EXPERIMENTAL_DIR, "experimental_datasets.md")) {
  archive_path <- file.path(download_dir, paste0(name, ".tar.bz2"))
  if (!file.exists(archive_path)) {
    stop("Archive not found: ", archive_path, ". Run download_all_datasets(datasets = \"", name,
         "\") first.", call. = FALSE)
  }
  row <- catalog_row(catalog_rows(catalog_md), name)
  warn_if_not_gpl3_compatible(row$dataset, row$license, row$redistribution)
  utils::untar(archive_path, exdir = download_dir)
  invisible(download_dir)
}

# Run end-to-end only when this file is executed directly (Rscript), never
# when it's source()'d -- matches the documented `source(...); call a
# function` usage pattern above.
if (sys.nframe() == 0L) {
  .args <- commandArgs(trailingOnly = FALSE)
  .file_arg <- grep("^--file=", .args, value = TRUE)
  if (length(.file_arg) > 0L && grepl("download_experimental_datasets\\.R$", .file_arg[[1L]])) {
    download_all_datasets()
  }
}
