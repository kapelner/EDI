# Parse ICPSR card-image (fixed-width, multi-record-per-subject) data using the
# SPSS DATA LIST setup file that ships with the study.
#
# A DATA LIST block declares RECORDS=k, then one "/" separated spec per record.
# Each spec lists NAME start-end columns; a subject is k consecutive physical
# lines (one per record). Missing values are coded -1 in these files.
#
# Usage:
#   source("R/package_metadata/icpsr_card_parser.R")
#   spec <- parse_spss_card_setup("path/to/setup.sps")
#   df   <- read_spss_card_file("path/to/card.txt", spec)

parse_spss_card_setup <- function(setup_path) {
  lines <- readLines(setup_path, warn = FALSE)
  start <- grep("^\\s*DATA LIST", lines)
  if (length(start) != 1L) stop("expected exactly one DATA LIST in ", setup_path, call. = FALSE)
  n_records <- as.integer(sub(".*RECORDS=([0-9]+).*", "\\1", lines[start]))
  if (is.na(n_records)) stop("could not read RECORDS= from DATA LIST", call. = FALSE)

  body <- lines[(start + 1L):length(lines)]
  end <- which(grepl("\\.\\s*$", body))[1L]
  body <- body[seq_len(end)]
  body <- sub("!.*$", "", body)  # drop SPSS comment markers, if any

  # Split on lines that are just "/" (record separators)
  is_sep <- trimws(body) == "/"
  rec_id <- cumsum(c(0L, head(is_sep, -1L))) + 1L

  specs <- list()
  for (r in seq_len(max(rec_id))) {
    chunk <- paste(body[rec_id == r], collapse = " ")
    m <- gregexpr("([A-Za-z][A-Za-z0-9_]*)\\s+([0-9]+)\\s*-\\s*([0-9]+)", chunk)
    hits <- regmatches(chunk, m)[[1L]]
    if (length(hits) == 0L) next
    parts <- regmatches(hits, regexec("([A-Za-z][A-Za-z0-9_]*)\\s+([0-9]+)\\s*-\\s*([0-9]+)", hits))
    specs[[length(specs) + 1L]] <- data.frame(
      record = r,
      name = vapply(parts, `[`, character(1), 2L),
      from = as.integer(vapply(parts, `[`, character(1), 3L)),
      to = as.integer(vapply(parts, `[`, character(1), 4L)),
      stringsAsFactors = FALSE
    )
  }
  spec <- do.call(rbind, specs)
  if (max(spec$record) != n_records) {
    stop(sprintf("parsed %d record specs, RECORDS=%d declared", max(spec$record), n_records), call. = FALSE)
  }
  attr(spec, "n_records") <- n_records
  spec
}

read_spss_card_file <- function(card_path, spec) {
  k <- attr(spec, "n_records")
  raw <- readLines(card_path, warn = FALSE)
  if (length(raw) %% k != 0L) {
    stop(sprintf("%d lines is not a multiple of %d records/subject", length(raw), k), call. = FALSE)
  }
  n_subj <- length(raw) %/% k
  out <- vector("list", nrow(spec))
  for (i in seq_len(nrow(spec))) {
    r <- spec$record[i]
    lines_r <- raw[seq(r, by = k, length.out = n_subj)]
    vals <- trimws(substr(lines_r, spec$from[i], spec$to[i]))
    num <- suppressWarnings(as.numeric(vals))
    num[!is.na(num) & num == -1] <- NA_real_
    out[[i]] <- if (all(is.na(num) | vals == "")) vals else num
    out[[i]][vals == ""] <- NA
  }
  names(out) <- spec$name
  as.data.frame(out, stringsAsFactors = FALSE, optional = TRUE)
}
