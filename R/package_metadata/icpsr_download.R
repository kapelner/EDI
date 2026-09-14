# Minimal, dependency-light ICPSR authentication + download, written to
# replace the `icpsrdata` CRAN package.
#
# STATUS: `icpsrdata::icpsr_download()` is confirmed broken (tested
# 2026-09-14, see R/package_metadata/experimental_datasets.md "Known
# issue"). It POSTs a login form to a hardcoded
# http://www.icpsr.umich.edu/cgi-bin/bob/zipcart2?... URL -- a legacy
# CGI-bin path. ICPSR has since moved to a Keycloak-based OAuth/OIDC login
# (host pattern login.*.icpsr.umich.edu/realms/icpsr/...), which is a
# structurally different flow the old package cannot perform at all, no
# matter how credentials are supplied.
#
# This script mirrors the flow used by a more recently written reference
# tool (github.com/Xarthisius/openicpsr, itself written against ICPSR's
# current login system):
#   1. GET the openICPSR base URL to establish a session cookie (JSESSIONID)
#   2. GET the login URL (following redirects) to land on the live Keycloak
#      login page and extract that page's one-time form-action URL
#      (embedded session_code/client_id/execution/tab_id query params --
#      these are generated per-session and cannot be hardcoded)
#   3. POST username + password to that extracted action URL
#   4. HEAD the file's download URL to read the real filename from the
#      Content-Disposition header
#   5. GET the same URL (streamed) to write the file to disk
#
# CONFIRMED 2026-09-14: the reference implementation this was translated
# from targets `test.openicpsr.org` / `login.uat.icpsr.umich.edu` -- those
# are staging/UAT hosts, and a plain unauthenticated GET to
# test.openicpsr.org returns HTTP 403 with no login logic involved at all.
# The real production host is `www.openicpsr.org` (verified: returns 200).
# Separately, and independent of the host: the site also 403s any request
# without realistic browser headers (User-Agent/Accept/Accept-Language) --
# both fixes were required together to get past step 1.
# `login.icpsr.umich.edu` (dropping the `uat.` prefix) is the believed
# production login host but has NOT been separately verified the way the
# data host was -- confirm this if the auth POST step fails.
#
# FURTHER FINDING, same date: the site's behavior is inconsistent across
# back-to-back runs with identical parameters -- step 1 alone returned 200
# once, then 403 on the very next attempt a few minutes later with nothing
# changed. That points to active bot-detection/rate-limiting on ICPSR's
# side (no persistent cookie jar or request pacing between separate
# httr2::request() calls, unlike a real browser session), not a remaining
# URL/header bug. This script is NOT confirmed to reliably complete a full
# download as a result -- it got further than the broken `icpsrdata`
# package (past step 1 at least once) but has not been proven end-to-end.
# A real fix would likely need a persistent cookie jar across all 5 steps
# and deliberate delays between requests; that has not been implemented
# or tested here. Manual browser download from icpsr.umich.edu remains
# the reliable path until this is solved and verified.
#
# Credentials: reads from the same ~/.Rprofile options already used
# elsewhere in this project (options("icpsr_email"=..., "icpsr_password"=...)),
# falling back to the ICPSR_EMAIL / ICPSR_PASS environment variables the
# Python reference tool uses, for parity. Never hardcode credentials here
# or anywhere else in this repository.

library(httr2)

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

#' Authenticate against ICPSR and download one file by project id.
#'
#' @param project_id ICPSR/openICPSR project or study id.
#' @param download_dir Directory to write the downloaded file into.
#'   Defaults to the persistent, gitignored `R/package_metadata/icpsr_data/`
#'   directory (see .gitignore) rather than `tempdir()`, so repeated runs
#'   during development reuse already-downloaded files instead of hitting
#'   ICPSR's rate limiting again -- but the file MUST stay untracked;
#'   never `git add` anything under it. This default assumes the script is
#'   sourced with the working directory at the EDI repo root (as shown in
#'   the usage example in experimental_datasets.md); pass an explicit
#'   `download_dir` if sourcing from elsewhere.
icpsr_download_simple <- function(project_id,
                                   download_dir = "R/package_metadata/icpsr_data") {
  creds <- get_icpsr_credentials()
  if (!dir.exists(download_dir)) dir.create(download_dir, recursive = TRUE)

  base_url <- sprintf("https://%s/openicpsr/", ICPSR_DATA_HOST)
  login_url <- sprintf("https://%s/openicpsr/login", ICPSR_DATA_HOST)

  # 1. Establish a session cookie. (Requires browser-like headers -- the
  #    site 403s anything that looks like a bare script/bot request.)
  session <- httr2::request(base_url) |>
    httr2::req_headers(!!!BROWSER_HEADERS) |>
    httr2::req_perform()

  # 2. Follow the login page to its live Keycloak form and pull out the
  #    one-time form-action URL (query params are generated per-session).
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
  action_url <- gsub("&amp;", "&", action_url) # HTML-entity-decode the querystring

  # 3. Submit credentials to that extracted action URL.
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

  # 4. HEAD the download URL to recover the real filename.
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

  # 5. Stream the actual file to disk.
  dest <- file.path(download_dir, filename)
  httr2::request(data_url) |>
    httr2::req_headers(!!!BROWSER_HEADERS) |>
    httr2::req_perform(path = dest)

  message("Downloaded: ", dest)
  invisible(dest)
}

# Example (not run automatically):
# icpsr_download_simple(project_id = 36138)
