# Download-and-normalize pipeline for every non-CRAN, non-GitHub real
# experimental dataset in R/package_metadata/experimental_datasets.md.
#
# Usage (from the repo root):
#   Rscript R/package_metadata/download_experimental_datasets.R
# or, sourced interactively:
#   source("R/package_metadata/download_experimental_datasets.R")
#   download_all_datasets()
#
# Every dataset ends up as one or more plain CSV files, and the whole
# download directory is then packed into a single randomized_experiment_datasets.tar.bz2 (the
# loose CSVs are deleted afterward by default -- text compresses well under
# bzip2, so one archive of uniform CSVs is both smaller on disk and simpler
# to reason about than a mix of .zip/.tab/.dta/.csv). Run
# extract_experimental_datasets() to unpack the archive back to loose CSVs when you
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
# experimental_datasets.md. Keep `randomized_experiment_datasets/` and `randomized_experiment_datasets.tar.bz2`
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
icpsr_download_simple <- function(project_id, download_dir = "R/package_metadata/randomized_experiment_datasets") {
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
# Mechanism 3: CRAN packages -- source tarball only, no install.packages()
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

#' Download a CRAN package's source tarball (curl only, no install), pull
#' out one named data object, convert it to CSV, and clean up the
#' downloaded tarball/extracted directory -- nothing from the package
#' itself is left on disk afterward, only `dest_csv`.
#'
#' @param pkg CRAN package name.
#' @param version Exact version to fetch (pin, not "latest" -- matches
#'   this project's existing CRAN/GitHub pinning convention).
#' @param rda_name Base name (no extension) of the file under the
#'   package's `data/` directory, e.g. "tanf" for `data/tanf.rda`.
#' @param dest_csv Output CSV path.
#' @param work_dir Scratch directory for the tarball/extraction (cleaned
#'   up before returning).
cran_download_dataset_as_csv <- function(pkg, version, rda_name, dest_csv, work_dir) {
  # CRAN's plain src/contrib/ listing only ever holds the CURRENT version
  # of a package; anything superseded moves to src/contrib/Archive/<pkg>/.
  # The version pinned in our manifest is whatever was current when a
  # dataset was first verified -- by the time this actually runs (this
  # sweep alone took hours, spread across many parallel workers checking
  # packages at different moments) the package may well have been
  # updated, 404-ing the direct URL. Try direct first (usually still
  # right), fall back to Archive on 404 -- don't silently substitute a
  # newer version, since a later release could change the dataset itself.
  tar_path <- file.path(work_dir, paste0(".raw_", pkg, ".tar.gz"))
  direct_url <- sprintf("https://cran.r-project.org/src/contrib/%s_%s.tar.gz", pkg, version)
  archive_url <- sprintf("https://cran.r-project.org/src/contrib/Archive/%s/%s_%s.tar.gz", pkg, pkg, version)
  ok <- tryCatch({
    httr2::request(direct_url) |> httr2::req_perform(path = tar_path)
    TRUE
  }, httr2_http_404 = function(e) FALSE)
  if (!ok) {
    message("  (", pkg, " ", version, " superseded on CRAN's main listing; trying Archive/)")
    ok <- tryCatch({
      httr2::request(archive_url) |> httr2::req_perform(path = tar_path)
      TRUE
    }, httr2_http_404 = function(e) FALSE)
  }
  if (!ok) {
    # Last resort: the manifest's pinned version string doesn't exist
    # anywhere on CRAN (a handful of these were mis-transcribed during
    # the exhaustive sweep's fork-based review -- ~200 version strings
    # recorded by many parallel passes, some error rate is expected).
    # Fall back to whatever is CURRENT now rather than hard-failing --
    # for a package that exists mainly to ship one classic dataset, the
    # data itself essentially never changes across version bumps, only
    # code/docs, so this is a safe last resort, not a silent data swap.
    cur_ver <- tryCatch(tools::CRAN_package_db()$Version[tools::CRAN_package_db()$Package == pkg],
                         error = function(e) character(0))
    if (length(cur_ver) == 0L) stop("CRAN download failed for ", pkg, " ", version, " (not found on CRAN at all)", call. = FALSE)
    message("  (", pkg, " ", version, " not found in Archive/ either; falling back to current CRAN version ", cur_ver[[1L]], ")")
    current_url <- sprintf("https://cran.r-project.org/src/contrib/%s_%s.tar.gz", pkg, cur_ver[[1L]])
    httr2::request(current_url) |> httr2::req_perform(path = tar_path)
  }
  if (!file.exists(tar_path) || file.size(tar_path) == 0L) {
    stop("CRAN download failed or empty for ", pkg, " ", version, call. = FALSE)
  }

  extract_dir <- file.path(work_dir, paste0(".extract_", pkg))
  unlink(extract_dir, recursive = TRUE)
  utils::untar(tar_path, exdir = extract_dir)
  pkg_dir <- file.path(extract_dir, pkg)
  if (!dir.exists(pkg_dir) || !file.exists(file.path(pkg_dir, "DESCRIPTION"))) {
    stop("CRAN tarball for ", pkg, " did not extract as expected (partial download?)", call. = FALSE)
  }

  data_files <- list.files(file.path(pkg_dir, "data"))
  hit <- data_files[tools::file_path_sans_ext(data_files) == rda_name]
  if (length(hit) == 0L) {
    stop("Data object '", rda_name, "' not found in ", pkg, " ", version,
         "'s data/ directory (found: ", paste(data_files, collapse = ", "), ")", call. = FALSE)
  }
  src_path <- file.path(pkg_dir, "data", hit[[1L]])
  ext <- tolower(tools::file_ext(src_path))
  if (ext %in% c("rda", "rdata")) {
    e <- new.env()
    load(src_path, envir = e)
    obj_names <- ls(e)
    if (length(obj_names) == 0L) stop("No objects loaded from ", src_path, call. = FALSE)
    obj <- get(obj_names[[1L]], envir = e)
    if (!(is.data.frame(obj) || is.matrix(obj))) {
      stop("Object '", obj_names[[1L]], "' in ", pkg, "::", rda_name,
           " is not a data.frame/matrix (class: ", class(obj)[1L], ") -- needs a bespoke conversion",
           call. = FALSE)
    }
    data.table::fwrite(as.data.frame(obj), dest_csv)
  } else {
    convert_to_csv(src_path, dest_csv)
  }

  unlink(tar_path)
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
  ,
  # ---- CRAN-sourced Expanded-tier datasets from earlier rounds (3-4,
  # predating the exhaustive sweep), migrated here for consistency -- same
  # install-free mechanism, no reason for these to differ from the sweep's
  # datasets just because they were found first. Core-tier CRAN datasets
  # (the original 32) are NOT migrated -- they predate this mechanism and
  # are already relied on via the ordinary install.packages()+data()
  # pattern documented above; changing that is a separate decision.
  tanf = list(cran = list(pkg = "whatifbandit", version = "1.0.3", rda_name = "tanf", out_csv = "tanf.csv")),
  gastric_cancer_trial_df = list(cran = list(pkg = "DigestiveDataSets", version = "0.2.0", rda_name = "gastric_cancer_trial_df", out_csv = "gastric_cancer_trial_df.csv")),
  liver_cirrhosis_prednisone_df = list(cran = list(pkg = "DigestiveDataSets", version = "0.2.0", rda_name = "liver_cirrhosis_prednisone_df", out_csv = "liver_cirrhosis_prednisone_df.csv")),
  WSCdata = list(cran = list(pkg = "WSCdata", version = "0.1.2", rda_name = "WSCdata", out_csv = "WSCdata.csv")),
  immigrationconjoint = list(cran = list(pkg = "cjoint", version = "2.1.3", rda_name = "immigrationconjoint", out_csv = "immigrationconjoint.csv")),
  epilepsy_RCT_tbl_df = list(cran = list(pkg = "NeuroDataSets", version = "0.3.1", rda_name = "epilepsy_RCT_tbl_df", out_csv = "epilepsy_RCT_tbl_df.csv")),
  sulphinpyrazone_tbl_df = list(cran = list(pkg = "CardioDataSets", version = "0.2.0", rda_name = "sulphinpyrazone_tbl_df", out_csv = "sulphinpyrazone_tbl_df.csv")),
  immdef = list(cran = list(pkg = "rpsftm", version = "1.2.9", rda_name = "immdef", out_csv = "immdef.csv")),
  Gbsg_df = list(cran = list(pkg = "ForCausality", version = "0.1.0", rda_name = "Gbsg_df", out_csv = "Gbsg_df.csv")),
  seguro = list(cran = list(pkg = "experiment", version = "1.2.1", rda_name = "seguro", out_csv = "seguro.csv")),
  ajps = list(cran = list(pkg = "GK2011", version = "0.1.3", rda_name = "ajps", out_csv = "ajps.csv")),
  pakistan = list(cran = list(pkg = "endorse", version = "1.6.2", rda_name = "pakistan", out_csv = "pakistan.csv")),
  berberis_treatment = list(cran = list(pkg = "ecoteach", version = "0.1.0", rda_name = "berberis_treatment", out_csv = "berberis_treatment.csv")),
  PowderyMildew = list(cran = list(pkg = "epifitter", version = "1.0.0", rda_name = "PowderyMildew", out_csv = "PowderyMildew.csv")),
  train1 = list(cran = list(pkg = "callback", version = "0.1.3", rda_name = "train1", out_csv = "train1.csv")),
  opt = list(cran = list(pkg = "medicaldata", version = "0.2.0", rda_name = "opt", out_csv = "opt.csv")),
  supraclavicular = list(cran = list(pkg = "medicaldata", version = "0.2.0", rda_name = "supraclavicular", out_csv = "supraclavicular.csv")),

  # ---- CRAN-sourced datasets from the exhaustive sweep (round 4), no
  # install.packages() needed -- see cran_download_dataset_as_csv() ----
  clubSandwich_AchievementAwardsRCT = list(cran = list(pkg = "clubSandwich", version = "0.5.11", rda_name = "AchievementAwardsRCT", out_csv = "clubSandwich_AchievementAwardsRCT.csv")),
  asaur_pharmacoSmoking = list(cran = list(pkg = "asaur", version = "0.50", rda_name = "pharmacoSmoking", out_csv = "asaur_pharmacoSmoking.csv")),
  afex_laptop_urry = list(cran = list(pkg = "afex", version = "1.5-1", rda_name = "laptop_urry", out_csv = "afex_laptop_urry.csv")),
  cofad_testing_effect = list(cran = list(pkg = "cofad", version = "0.4.0", rda_name = "testing_effect", out_csv = "cofad_testing_effect.csv")),
  causalweight_JC = list(cran = list(pkg = "causalweight", version = "1.1.5", rda_name = "JC", out_csv = "causalweight_JC.csv")),
  causalOT_pph = list(cran = list(pkg = "causalOT", version = "1.0.4", rda_name = "pph", out_csv = "causalOT_pph.csv")),
  baggr_microcredit = list(cran = list(pkg = "baggr", version = "0.8.2", rda_name = "microcredit", out_csv = "baggr_microcredit.csv")),
  asbio_potash = list(cran = list(pkg = "asbio", version = "1.13-1", rda_name = "potash", out_csv = "asbio_potash.csv")),
  collett_prostatic = list(cran = list(pkg = "collett", version = "0.1.2", rda_name = "prostatic", out_csv = "collett_prostatic.csv")),
  collett_tamoxifen = list(cran = list(pkg = "collett", version = "0.1.2", rda_name = "tamoxifen", out_csv = "collett_tamoxifen.csv")),
  collett_active_hepatitis = list(cran = list(pkg = "collett", version = "0.1.2", rda_name = "active_hepatitis", out_csv = "collett_active_hepatitis.csv")),
  BGPhazard_gehan = list(cran = list(pkg = "BGPhazard", version = "2.1.1", rda_name = "gehan", out_csv = "BGPhazard_gehan.csv")),
  coxphw_biofeedback = list(cran = list(pkg = "coxphw", version = "4.0.3", rda_name = "biofeedback", out_csv = "coxphw_biofeedback.csv")),
  CrossCarry_Water = list(cran = list(pkg = "CrossCarry", version = "1.2.0", rda_name = "Water", out_csv = "CrossCarry_Water.csv")),
  dae_McIntyreTMV_dat = list(cran = list(pkg = "dae", version = "3.2.35", rda_name = "McIntyreTMV.dat", out_csv = "dae_McIntyreTMV.csv")),
  dae_Oats_dat = list(cran = list(pkg = "dae", version = "3.2.35", rda_name = "Oats.dat", out_csv = "dae_Oats.csv")),
  cvGEE_aids = list(cran = list(pkg = "cvGEE", version = "0.1.2", rda_name = "aids", out_csv = "cvGEE_aids.csv")),
  DeepLearningCausal_exp_data = list(cran = list(pkg = "DeepLearningCausal", version = "0.0.107", rda_name = "exp_data", out_csv = "DeepLearningCausal_exp_data.csv")),
  coursekata_TipExperiment = list(cran = list(pkg = "coursekata", version = "0.20.1", rda_name = "TipExperiment", out_csv = "coursekata_TipExperiment.csv")),
  DoseFinding_migraine = list(cran = list(pkg = "DoseFinding", version = "1.4-1", rda_name = "migraine", out_csv = "DoseFinding_migraine.csv")),
  ecotox_lamprey_tox = list(cran = list(pkg = "ecotox", version = "1.4.4", rda_name = "lamprey_tox", out_csv = "ecotox_lamprey_tox.csv")),
  emplik_smallcell = list(cran = list(pkg = "emplik", version = "1.3-3", rda_name = "smallcell", out_csv = "emplik_smallcell.csv")),
  EngrExpt_uvcoatin = list(cran = list(pkg = "EngrExpt", version = "0.1-8", rda_name = "uvcoatin", out_csv = "EngrExpt_uvcoatin.csv")),
  esci_data_rattanmotivation = list(cran = list(pkg = "esci", version = "1.0.4", rda_name = "data_rattanmotivation", out_csv = "esci_rattanmotivation.csv")),
  esci_data_selfexplain = list(cran = list(pkg = "esci", version = "1.0.4", rda_name = "data_selfexplain", out_csv = "esci_selfexplain.csv")),
  EstimationTools_head_neck_cancer = list(cran = list(pkg = "EstimationTools", version = "4.1.1", rda_name = "head_neck_cancer", out_csv = "EstimationTools_headneck.csv")),
  coin_rotarod = list(cran = list(pkg = "coin", version = "1.4-5", rda_name = "rotarod", out_csv = "coin_rotarod.csv")),
  experimentr_mcgrath = list(cran = list(pkg = "experimentr", version = "0.1.0", rda_name = "mcgrath", out_csv = "experimentr_mcgrath.csv")),
  experimentr_sherman = list(cran = list(pkg = "experimentr", version = "0.1.0", rda_name = "sherman", out_csv = "experimentr_sherman.csv")),
  faraway_coagulation = list(cran = list(pkg = "faraway", version = "1.0.9", rda_name = "coagulation", out_csv = "faraway_coagulation.csv")),
  faraway_fruitfly = list(cran = list(pkg = "faraway", version = "1.0.9", rda_name = "fruitfly", out_csv = "faraway_fruitfly.csv")),
  faraway_hips = list(cran = list(pkg = "faraway", version = "1.0.9", rda_name = "hips", out_csv = "faraway_hips.csv")),
  faraway_irrigation = list(cran = list(pkg = "faraway", version = "1.0.9", rda_name = "irrigation", out_csv = "faraway_irrigation.csv")),
  frailtyHL_bladder0 = list(cran = list(pkg = "frailtyHL", version = "2.3", rda_name = "bladder0", out_csv = "frailtyHL_bladder0.csv")),
  frailtyHL_ren = list(cran = list(pkg = "frailtyHL", version = "2.3", rda_name = "ren", out_csv = "frailtyHL_ren.csv")),
  frailtypack_bcos = list(cran = list(pkg = "frailtypack", version = "3.7.1", rda_name = "bcos", out_csv = "frailtypack_bcos.csv")),
  frailtypack_colorectal = list(cran = list(pkg = "frailtypack", version = "3.7.1", rda_name = "colorectal", out_csv = "frailtypack_colorectal.csv")),
  frailtypack_dataOvarian = list(cran = list(pkg = "frailtypack", version = "3.7.1", rda_name = "dataOvarian", out_csv = "frailtypack_dataOvarian.csv")),
  frailtypack_gastadj = list(cran = list(pkg = "frailtypack", version = "3.7.1", rda_name = "gastadj", out_csv = "frailtypack_gastadj.csv")),
  frailtypack_reduce = list(cran = list(pkg = "frailtypack", version = "3.7.1", rda_name = "reduce", out_csv = "frailtypack_reduce.csv")),
  geecure_smoking = list(cran = list(pkg = "geecure", version = "1.5", rda_name = "smoking", out_csv = "geecure_smoking.csv")),
  geecure_tonsil = list(cran = list(pkg = "geecure", version = "1.5", rda_name = "tonsil", out_csv = "geecure_tonsil.csv")),
  geer_cerebrovascular = list(cran = list(pkg = "geer", version = "0.1.0", rda_name = "cerebrovascular", out_csv = "geer_cerebrovascular.csv")),
  geer_cholecystectomy = list(cran = list(pkg = "geer", version = "0.1.0", rda_name = "cholecystectomy", out_csv = "geer_cholecystectomy.csv")),
  geer_depression = list(cran = list(pkg = "geer", version = "0.1.0", rda_name = "depression", out_csv = "geer_depression.csv")),
  geer_leprosy = list(cran = list(pkg = "geer", version = "0.1.0", rda_name = "leprosy", out_csv = "geer_leprosy.csv")),
  geer_rinse = list(cran = list(pkg = "geer", version = "0.1.0", rda_name = "rinse", out_csv = "geer_rinse.csv")),
  GJRM_data_hie = list(cran = list(pkg = "GJRM.data", version = "0.2-6.1", rda_name = "hie", out_csv = "GJRMdata_hie.csv")),
  glmm_bacteria = list(cran = list(pkg = "glmm", version = "1.4.4", rda_name = "bacteria", out_csv = "glmm_bacteria.csv")),
  glmtoolbox_amenorrhea = list(cran = list(pkg = "glmtoolbox", version = "1.1.4", rda_name = "amenorrhea", out_csv = "glmtoolbox_amenorrhea.csv")),
  glmtoolbox_ossification = list(cran = list(pkg = "glmtoolbox", version = "1.1.4", rda_name = "ossification", out_csv = "glmtoolbox_ossification.csv")),
  gosset_breadwheat = list(cran = list(pkg = "gosset", version = "1.5.5", rda_name = "breadwheat", out_csv = "gosset_breadwheat.csv")),
  gosset_nicabean = list(cran = list(pkg = "gosset", version = "1.5.5", rda_name = "nicabean", out_csv = "gosset_nicabean.csv")),
  gpk_cloudseed = list(cran = list(pkg = "gpk", version = "1.0", rda_name = "cloudseed", out_csv = "gpk_cloudseed.csv")),
  granova_arousal = list(cran = list(pkg = "granova", version = "2.0.0", rda_name = "arousal", out_csv = "granova_arousal.csv")),
  gss_bacteriuria = list(cran = list(pkg = "gss", version = "0.10-9", rda_name = "bacteriuria", out_csv = "gss_bacteriuria.csv")),
  hamlet_orxwide = list(cran = list(pkg = "hamlet", version = "0.9.8", rda_name = "orxwide", out_csv = "hamlet_orxwide.csv")),
  heplots_RatWeight = list(cran = list(pkg = "heplots", version = "1.7.4", rda_name = "RatWeight", out_csv = "heplots_RatWeight.csv")),
  heritable_lettuce_phenotypes = list(cran = list(pkg = "heritable", version = "0.1.0", rda_name = "lettuce_phenotypes", out_csv = "heritable_lettuce.csv")),
  hiddenf_Graybill_mtx = list(cran = list(pkg = "hiddenf", version = "1.2.2", rda_name = "Graybill.mtx", out_csv = "hiddenf_Graybill.csv")),
  HLMdiag_ahd = list(cran = list(pkg = "HLMdiag", version = "0.5.0", rda_name = "ahd", out_csv = "HLMdiag_ahd.csv")),
  hnp_cbb = list(cran = list(pkg = "hnp", version = "1.2-8", rda_name = "cbb", out_csv = "hnp_cbb.csv")),
  hnp_chryso = list(cran = list(pkg = "hnp", version = "1.2-8", rda_name = "chryso", out_csv = "hnp_chryso.csv")),
  hnp_corn = list(cran = list(pkg = "hnp", version = "1.2-8", rda_name = "corn", out_csv = "hnp_corn.csv")),
  hnp_fungi = list(cran = list(pkg = "hnp", version = "1.2-8", rda_name = "fungi", out_csv = "hnp_fungi.csv")),
  hnp_oil = list(cran = list(pkg = "hnp", version = "1.2-8", rda_name = "oil", out_csv = "hnp_oil.csv")),
  hnp_orange = list(cran = list(pkg = "hnp", version = "1.2-8", rda_name = "orange", out_csv = "hnp_orange.csv")),
  hnp_progeny = list(cran = list(pkg = "hnp", version = "1.2-8", rda_name = "progeny", out_csv = "hnp_progeny.csv")),
  HSAUR3_BtheB = list(cran = list(pkg = "HSAUR3", version = "1.0-13", rda_name = "BtheB", out_csv = "HSAUR3_BtheB.csv")),
  HSAUR3_Lanza = list(cran = list(pkg = "HSAUR3", version = "1.0-13", rda_name = "Lanza", out_csv = "HSAUR3_Lanza.csv")),
  HSAUR3_students = list(cran = list(pkg = "HSAUR3", version = "1.0-13", rda_name = "students", out_csv = "HSAUR3_students.csv")),
  PASWR2_WEIGHTGAIN = list(cran = list(pkg = "PASWR2", version = "1.7", rda_name = "WEIGHTGAIN", out_csv = "PASWR2_WeightGain.csv")),
  mediation_jobs = list(cran = list(pkg = "mediation", version = "4.5.0", rda_name = "jobs", out_csv = "mediation_jobs.csv")),
  Matching_GerberGreenImai = list(cran = list(pkg = "Matching", version = "4.10-15", rda_name = "GerberGreenImai", out_csv = "Matching_GerberGreenImai.csv")),
  lmPerm_Federer276 = list(cran = list(pkg = "lmPerm", version = "2.1.0", rda_name = "Federer276", out_csv = "lmPerm_Federer276.csv")),
  lmPerm_Hald17_4 = list(cran = list(pkg = "lmPerm", version = "2.1.0", rda_name = "Hald17.4", out_csv = "lmPerm_Hald.csv")),
  labstats_festing = list(cran = list(pkg = "labstats", version = "0.0.1", rda_name = "festing", out_csv = "labstats_festing.csv")),
  labstats_fluoxetine = list(cran = list(pkg = "labstats", version = "0.0.1", rda_name = "fluoxetine", out_csv = "labstats_fluoxetine.csv")),
  labstats_glycogen = list(cran = list(pkg = "labstats", version = "0.0.1", rda_name = "glycogen", out_csv = "labstats_glycogen.csv")),
  labstats_hypertension = list(cran = list(pkg = "labstats", version = "0.0.1", rda_name = "hypertension", out_csv = "labstats_hypertension.csv")),
  labstats_KH2004 = list(cran = list(pkg = "labstats", version = "0.0.1", rda_name = "KH2004", out_csv = "labstats_KH2004.csv")),
  labstats_locomotor = list(cran = list(pkg = "labstats", version = "0.0.1", rda_name = "locomotor", out_csv = "labstats_locomotor.csv")),
  labstats_VPA = list(cran = list(pkg = "labstats", version = "0.0.1", rda_name = "VPA", out_csv = "labstats_VPA.csv")),
  KONPsurv_carcinoma = list(cran = list(pkg = "KONPsurv", version = "1.1.0", rda_name = "carcinoma", out_csv = "KONPsurv_carcinoma.csv")),
  mice_toenail = list(cran = list(pkg = "mice", version = "3.18.0", rda_name = "toenail", out_csv = "mice_toenail.csv")),
  ISwR_alkfos = list(cran = list(pkg = "ISwR", version = "1.5", rda_name = "alkfos", out_csv = "ISwR_alkfos.csv")),
  invGauss_d_oropha_rec = list(cran = list(pkg = "invGauss", version = "1.6", rda_name = "d.oropha.rec", out_csv = "invGauss_dorophar.csv")),
  lava_bmd = list(cran = list(pkg = "lava", version = "1.8.1", rda_name = "bmd", out_csv = "lava_bmd.csv")),
  mhazard_anemia = list(cran = list(pkg = "mhazard", version = "0.1.1", rda_name = "anemia", out_csv = "mhazard_anemia.csv")),
  isdals_cornyield = list(cran = list(pkg = "isdals", version = "2.0-9", rda_name = "cornyield", out_csv = "isdals_cornyield.csv")),
  lqmm_labor = list(cran = list(pkg = "lqmm", version = "1.5.8", rda_name = "labor", out_csv = "lqmm_labor.csv")),
  LongCART_ACTG175 = list(cran = list(pkg = "LongCART", version = "3.2", rda_name = "ACTG175", out_csv = "LongCART_ACTG175.csv")),
  mixor_schizophrenia = list(cran = list(pkg = "mixor", version = "1.2", rda_name = "schizophrenia", out_csv = "mixor_schizophrenia.csv")),
  mixor_SmokeOnset = list(cran = list(pkg = "mixor", version = "1.2", rda_name = "SmokeOnset", out_csv = "mixor_SmokeOnset.csv")),
  mixor_SmokingPrevention = list(cran = list(pkg = "mixor", version = "1.2", rda_name = "SmokingPrevention", out_csv = "mixor_SmokingPrevention.csv")),
  MNM_beans = list(cran = list(pkg = "MNM", version = "1.0-4", rda_name = "beans", out_csv = "MNM_beans.csv")),
  moderate_mediation_newws = list(cran = list(pkg = "moderate.mediation", version = "0.0.12", rda_name = "newws", out_csv = "modmed_newws.csv")),
  mosaicData_HELPrct = list(cran = list(pkg = "mosaicData", version = "0.20.4", rda_name = "HELPrct", out_csv = "mosaicData_HELPrct.csv")),
  mosaicData_Mites = list(cran = list(pkg = "mosaicData", version = "0.20.4", rda_name = "Mites", out_csv = "mosaicData_Mites.csv")),
  multiDimBio_Nuclei = list(cran = list(pkg = "multiDimBio", version = "1.2.5", rda_name = "Nuclei", out_csv = "multiDimBio_Nuclei.csv")),
  nlme_Alfalfa = list(cran = list(pkg = "nlme", version = "3.1-171", rda_name = "Alfalfa", out_csv = "nlme_Alfalfa.csv")),
  nlme_Assay = list(cran = list(pkg = "nlme", version = "3.1-171", rda_name = "Assay", out_csv = "nlme_Assay.csv")),
  nlmeU_armd0 = list(cran = list(pkg = "nlmeU", version = "0.71.7", rda_name = "armd0", out_csv = "nlmeU_armd0.csv")),
  nlmeU_prt_subjects = list(cran = list(pkg = "nlmeU", version = "0.71.7", rda_name = "prt.subjects", out_csv = "nlmeU_prt.csv")),
  PASWR_Aggression = list(cran = list(pkg = "PASWR", version = "1.1.1", rda_name = "Aggression", out_csv = "PASWR_Aggression.csv")),
  PASWR_Ratbp = list(cran = list(pkg = "PASWR", version = "1.1.1", rda_name = "Ratbp", out_csv = "PASWR_Ratbp.csv")),
  PASWR_Swimtimes = list(cran = list(pkg = "PASWR", version = "1.1.1", rda_name = "Swimtimes", out_csv = "PASWR_Swimtimes.csv")),
  PASWR2_EPIDURALF = list(cran = list(pkg = "PASWR2", version = "1.7", rda_name = "EPIDURALF", out_csv = "PASWR2_Epidural.csv")),
  R4HCR_Acupuncture = list(cran = list(pkg = "R4HCR", version = "0.1.0", rda_name = "Acupuncture", out_csv = "R4HCR_Acupuncture.csv")),
  R4HCR_Facemasks = list(cran = list(pkg = "R4HCR", version = "0.1.0", rda_name = "Facemasks", out_csv = "R4HCR_Facemasks.csv")),
  powerSurvEpi_Oph = list(cran = list(pkg = "powerSurvEpi", version = "0.1.4", rda_name = "Oph", out_csv = "powerSurvEpi_Oph.csv")),
  pscl_RockTheVote = list(cran = list(pkg = "pscl", version = "1.5.9", rda_name = "RockTheVote", out_csv = "pscl_RockTheVote.csv")),
  QDComparison_Microfinance = list(cran = list(pkg = "QDComparison", version = "0.1.0", rda_name = "Microfinance", out_csv = "QDComparison_Microfinance.csv")),
  quantreg_uis = list(cran = list(pkg = "quantreg", version = "6.1", rda_name = "uis", out_csv = "quantreg_uis.csv")),
  RCT2_india = list(cran = list(pkg = "RCT2", version = "0.1.0", rda_name = "india", out_csv = "RCT2_india.csv")),
  RCT2_jd = list(cran = list(pkg = "RCT2", version = "0.1.0", rda_name = "jd", out_csv = "RCT2_jd.csv")),
  RESIDE_IST = list(cran = list(pkg = "RESIDE", version = "0.1.0", rda_name = "IST", out_csv = "RESIDE_IST.csv")),
  Rfit_quail = list(cran = list(pkg = "Rfit", version = "0.25.1", rda_name = "quail", out_csv = "Rfit_quail.csv")),
  Rlab_magnet = list(cran = list(pkg = "Rlab", version = "4.0", rda_name = "magnet", out_csv = "Rlab_magnet.csv")),
  randomizationInference_reading = list(cran = list(pkg = "randomizationInference", version = "1.0.5", rda_name = "reading", out_csv = "randinf_reading.csv")),
  RPEXE_RPEXT_data2 = list(cran = list(pkg = "RPEXE.RPEXT", version = "0.1.0", rda_name = "data2", out_csv = "RPEXE_data2.csv")),
  rqlm_mch = list(cran = list(pkg = "rqlm", version = "0.1.0", rda_name = "mch", out_csv = "rqlm_mch.csv")),
  s20x_teach_df = list(cran = list(pkg = "s20x", version = "3.7.9", rda_name = "teach.df", out_csv = "s20x_teach.csv")),
  s20x_thyroid_df = list(cran = list(pkg = "s20x", version = "3.7.9", rda_name = "thyroid.df", out_csv = "s20x_thyroid.csv")),
  sanon_cpain = list(cran = list(pkg = "sanon", version = "1.6", rda_name = "cpain", out_csv = "sanon_cpain.csv")),
  sanon_sebor = list(cran = list(pkg = "sanon", version = "1.6", rda_name = "sebor", out_csv = "sanon_sebor.csv")),
  sanon_skin = list(cran = list(pkg = "sanon", version = "1.6", rda_name = "skin", out_csv = "sanon_skin.csv")),
  scidesignR_silkdat = list(cran = list(pkg = "scidesignR", version = "0.1.0", rda_name = "silkdat", out_csv = "scidesignR_silkdat.csv")),
  SingleCaseES_Kelley2015 = list(cran = list(pkg = "SingleCaseES", version = "0.7.1", rda_name = "Kelley2015", out_csv = "SingleCaseES_Kelley.csv")),
  SixSigma_ss_data_doe1 = list(cran = list(pkg = "SixSigma", version = "0.9-7", rda_name = "ss.data.doe1", out_csv = "SixSigma_doe1.csv")),
  Sleuth2_case0101 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case0101", out_csv = "Sleuth2_case0101.csv")),
  Sleuth2_case0301 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case0301", out_csv = "Sleuth2_case0301.csv")),
  Sleuth2_case0402 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case0402", out_csv = "Sleuth2_case0402.csv")),
  Sleuth2_case0501 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case0501", out_csv = "Sleuth2_case0501.csv")),
  Sleuth2_case0601 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case0601", out_csv = "Sleuth2_case0601.csv")),
  Sleuth2_case1301 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case1301", out_csv = "Sleuth2_case1301.csv")),
  Sleuth2_case1302 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case1302", out_csv = "Sleuth2_case1302.csv")),
  Sleuth2_case1402 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case1402", out_csv = "Sleuth2_case1402.csv")),
  Sleuth2_case1602 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "case1602", out_csv = "Sleuth2_case1602.csv")),
  Sleuth3_ex0112 = list(cran = list(pkg = "Sleuth3", version = "1.0-5", rda_name = "ex0112", out_csv = "Sleuth3_ex0112.csv")),
  Sleuth3_ex0211 = list(cran = list(pkg = "Sleuth3", version = "1.0-5", rda_name = "ex0211", out_csv = "Sleuth3_ex0211.csv")),
  Sleuth3_ex0331 = list(cran = list(pkg = "Sleuth3", version = "1.0-5", rda_name = "ex0331", out_csv = "Sleuth3_ex0331.csv")),
  Sleuth2_ex0429 = list(cran = list(pkg = "Sleuth2", version = "2.0-9", rda_name = "ex0429", out_csv = "Sleuth2_ex0429.csv")),
  Sleuth3_ex0431 = list(cran = list(pkg = "Sleuth3", version = "1.0-5", rda_name = "ex0431", out_csv = "Sleuth3_ex0431.csv")),
  Sleuth3_ex0432 = list(cran = list(pkg = "Sleuth3", version = "1.0-5", rda_name = "ex0432", out_csv = "Sleuth3_ex0432.csv")),
  Sleuth3_ex0518 = list(cran = list(pkg = "Sleuth3", version = "1.0-5", rda_name = "ex0518", out_csv = "Sleuth3_ex0518.csv")),
  Sleuth3_ex1014 = list(cran = list(pkg = "Sleuth3", version = "1.0-5", rda_name = "ex1014", out_csv = "Sleuth3_ex1014.csv")),
  smbdata_beetles = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "beetles", out_csv = "smbdata_beetles.csv")),
  smbdata_biomassc = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "biomassc", out_csv = "smbdata_biomassc.csv")),
  smbdata_calcium = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "calcium", out_csv = "smbdata_calcium.csv")),
  smbdata_calibrate = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "calibrate", out_csv = "smbdata_calibrate.csv")),
  smbdata_cotton = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "cotton", out_csv = "smbdata_cotton.csv")),
  smbdata_cuttings = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "cuttings", out_csv = "smbdata_cuttings.csv")),
  smbdata_demethylation = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "demethylation", out_csv = "smbdata_demethylation.csv")),
  smbdata_forage = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "forage", out_csv = "smbdata_forage.csv")),
  smbdata_heights = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "heights", out_csv = "smbdata_heights.csv")),
  smbdata_herbicide = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "herbicide", out_csv = "smbdata_herbicide.csv")),
  smbdata_ladybird = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "ladybird", out_csv = "smbdata_ladybird.csv")),
  smbdata_lupintrial = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "lupintrial", out_csv = "smbdata_lupintrial.csv")),
  smbdata_potato = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "potato", out_csv = "smbdata_potato.csv")),
  smbdata_prey = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "prey", out_csv = "smbdata_prey.csv")),
  smbdata_tgw = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "tgw", out_csv = "smbdata_tgw.csv")),
  smbdata_voltage = list(cran = list(pkg = "smbdata", version = "1.0.1", rda_name = "voltage", out_csv = "smbdata_voltage.csv")),
  SMPracticals_arithmetic = list(cran = list(pkg = "SMPracticals", version = "1.4-3", rda_name = "arithmetic", out_csv = "SMPracticals_arithmetic.csv")),
  SMPracticals_cake = list(cran = list(pkg = "SMPracticals", version = "1.4-3", rda_name = "cake", out_csv = "SMPracticals_cake.csv")),
  SMPracticals_marking = list(cran = list(pkg = "SMPracticals", version = "1.4-3", rda_name = "marking", out_csv = "SMPracticals_marking.csv")),
  SMPracticals_shoe = list(cran = list(pkg = "SMPracticals", version = "1.4-3", rda_name = "shoe", out_csv = "SMPracticals_shoe.csv")),
  SMPracticals_teak = list(cran = list(pkg = "SMPracticals", version = "1.4-3", rda_name = "teak", out_csv = "SMPracticals_teak.csv")),
  SpATS_wheatdata = list(cran = list(pkg = "SpATS", version = "1.0-19", rda_name = "wheatdata", out_csv = "SpATS_wheatdata.csv")),
  splmm_cognitive = list(cran = list(pkg = "splmm", version = "1.2.0", rda_name = "cognitive", out_csv = "splmm_cognitive.csv")),
  SRMData_Jumping = list(cran = list(pkg = "SRMData", version = "0.1.0", rda_name = "Jumping", out_csv = "SRMData_Jumping.csv")),
  SRMData_SixMWT = list(cran = list(pkg = "SRMData", version = "0.1.0", rda_name = "SixMWT", out_csv = "SRMData_SixMWT.csv")),
  Stat2Data_Alfalfa = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "Alfalfa", out_csv = "Stat2Data_Alfalfa.csv")),
  Stat2Data_AutoPollution = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "AutoPollution", out_csv = "Stat2Data_AutoPollution.csv")),
  Stat2Data_CalciumBP = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "CalciumBP", out_csv = "Stat2Data_CalciumBP.csv")),
  Stat2Data_Contraceptives = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "Contraceptives", out_csv = "Stat2Data_Contraceptives.csv")),
  Stat2Data_CrackerFiber = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "CrackerFiber", out_csv = "Stat2Data_CrackerFiber.csv")),
  Stat2Data_FruitFlies2 = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "FruitFlies2", out_csv = "Stat2Data_FruitFlies2.csv")),
  Stat2Data_FruitFlies = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "FruitFlies", out_csv = "Stat2Data_FruitFlies.csv")),
  Stat2Data_Meniscus = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "Meniscus", out_csv = "Stat2Data_Meniscus.csv")),
  Stat2Data_Milgram = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "Milgram", out_csv = "Stat2Data_Milgram.csv")),
  Stat2Data_MusicTime = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "MusicTime", out_csv = "Stat2Data_MusicTime.csv")),
  Stat2Data_PigFeed = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "PigFeed", out_csv = "Stat2Data_PigFeed.csv")),
  Stat2Data_Popcorn = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "Popcorn", out_csv = "Stat2Data_Popcorn.csv")),
  Stat2Data_SandwichAnts = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "SandwichAnts", out_csv = "Stat2Data_SandwichAnts.csv")),
  Stat2Data_TipJoke = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "TipJoke", out_csv = "Stat2Data_TipJoke.csv")),
  Stat2Data_WeightLossIncentive = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "WeightLossIncentive", out_csv = "Stat2Data_WeightLossIncentive.csv")),
  Stat2Data_WordMemory = list(cran = list(pkg = "Stat2Data", version = "2.0.5", rda_name = "WordMemory", out_csv = "Stat2Data_WordMemory.csv")),
  stepp_aspirin = list(cran = list(pkg = "stepp", version = "2.0-4", rda_name = "aspirin", out_csv = "stepp_aspirin.csv")),
  stepp_bigCI = list(cran = list(pkg = "stepp", version = "2.0-4", rda_name = "bigCI", out_csv = "stepp_bigCI.csv")),
  surrosurv_gastadv = list(cran = list(pkg = "surrosurv", version = "1.1.1", rda_name = "gastadv", out_csv = "surrosurv_gastadv.csv")),
  survSAKK_esophagus = list(cran = list(pkg = "survSAKK", version = "1.0", rda_name = "esophagus", out_csv = "survSAKK_esophagus.csv")),
  texmex_liver = list(cran = list(pkg = "texmex", version = "2.4.8", rda_name = "liver", out_csv = "texmex_liver.csv")),
  TukeyC_SPET = list(cran = list(pkg = "TukeyC", version = "1.1-6", rda_name = "SPET", out_csv = "TukeyC_SPET.csv")),
  vegan_pyrifos = list(cran = list(pkg = "vegan", version = "2.7-1", rda_name = "pyrifos", out_csv = "vegan_pyrifos.csv")),
  VGAMdata_belcap = list(cran = list(pkg = "VGAMdata", version = "1.1-13", rda_name = "belcap", out_csv = "VGAMdata_belcap.csv")),
  WA_hfaction_cpx12 = list(cran = list(pkg = "WA", version = "0.1.0", rda_name = "hfaction_cpx12", out_csv = "WA_hfaction.csv")),
  wgaim_phenoCxR = list(cran = list(pkg = "wgaim", version = "2.0.3", rda_name = "phenoCxR", out_csv = "wgaim_phenoCxR.csv")),
  wgaim_phenoRxK = list(cran = list(pkg = "wgaim", version = "2.0.3", rda_name = "phenoRxK", out_csv = "wgaim_phenoRxK.csv")),
  wgaim_phenoSxT = list(cran = list(pkg = "wgaim", version = "2.0.3", rda_name = "phenoSxT", out_csv = "wgaim_phenoSxT.csv")),
  wooldridge_apple = list(cran = list(pkg = "wooldridge", version = "1.4-2", rda_name = "apple", out_csv = "wooldridge_apple.csv")),
  WRS2_electric = list(cran = list(pkg = "WRS2", version = "1.1-6", rda_name = "electric", out_csv = "WRS2_electric.csv")),
  WWGbook_ratpup = list(cran = list(pkg = "WWGbook", version = "1.0.4", rda_name = "ratpup", out_csv = "WWGbook_ratpup.csv"))
)

# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

#' Download and normalize every dataset in DATASET_MANIFEST, packing each
#' one's CSV(s) into its own `<name>.tar.bz2` -- one archive per manifest
#' entry (a "dataset" in our table's sense, which can span several
#' constituent CSVs, e.g. monitoring_works' 7 files), not one combined
#' archive for the whole collection. This matches how `_dataset_load.R`
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
download_all_datasets <- function(download_dir = "R/package_metadata/randomized_experiment_datasets",
                                   keep_loose_csvs = FALSE,
                                   datasets = names(DATASET_MANIFEST)) {
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)

  for (name in datasets) {
    spec <- DATASET_MANIFEST[[name]]
    if (is.null(spec)) stop("No manifest entry named '", name, "'", call. = FALSE)
    archive_path <- file.path(download_dir, paste0(name, ".tar.bz2"))
    if (file.exists(archive_path)) {
      message("== ", name, " == already have ", archive_path)
      next
    }
    message("== ", name, " ==")
    out_csvs <- character(0)

    if (!is.null(spec$files)) {
      for (remote_name in names(spec$files)) {
        out_csv <- file.path(download_dir, spec$files[[remote_name]])
        out_csvs <- c(out_csvs, out_csv)
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
        out_csvs <- c(out_csvs, out_csv)
        if (file.exists(out_csv)) { message("  already have ", out_csv); next }
        message("  downloading ", zm$zip_filename, " (large; extracting ", zm$member_basename, ") ...")
        download_zip_member_as_csv(spec$doi, zm$zip_filename, zm$member_basename, out_csv, download_dir)
        message("  -> ", out_csv)
      }
    }

    if (!is.null(spec$cran)) {
      out_csv <- file.path(download_dir, spec$cran$out_csv)
      out_csvs <- c(out_csvs, out_csv)
      if (!file.exists(out_csv)) {
        message("  downloading CRAN ", spec$cran$pkg, " ", spec$cran$version,
                " (", spec$cran$rda_name, ", no install.packages()) ...")
        cran_download_dataset_as_csv(spec$cran$pkg, spec$cran$version, spec$cran$rda_name,
                                      out_csv, download_dir)
        message("  -> ", out_csv)
      }
    }

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
extract_experimental_datasets <- function(name,
                                download_dir = "R/package_metadata/randomized_experiment_datasets") {
  archive_path <- file.path(download_dir, paste0(name, ".tar.bz2"))
  if (!file.exists(archive_path)) {
    stop("Archive not found: ", archive_path, ". Run download_all_datasets(datasets = \"", name,
         "\") first.", call. = FALSE)
  }
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
