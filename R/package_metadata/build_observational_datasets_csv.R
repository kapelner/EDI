# Parse the dataset table in observational_datasets.md into observational_datasets.csv.
# Usage (from the repo root): Rscript R/package_metadata/build_observational_datasets_csv.R
#
# Same "Response Variable" cell grammar as build_experimental_datasets_csv.R (see that
# file's header and observational_datasets.md's own table-header note):
#   ";" separates type groups, matched in order to the " + " groups of "Response Type";
#   "," separates distinct outcomes within a group;
#   "/" joins the columns of a single outcome (e.g. `time`/`status`, `dead`/`total`);
#   (parentheses) are comments; an outcome must contain a `backticked` column name.
#
# Differs from the experimental builder in exactly two ways, matching this table's two
# extra/renamed columns:
#   - "tx (treatment column)" -> "w (group column)" (same role, renamed since there is no
#     "treatment" in a non-randomized design).
#   - "Design" -> "Group Assignment" (free text on HOW the group arose; always
#     non-randomized by this catalog's construction -- see observational_datasets.md's
#     Methodology section -- so there is no design_status/"documented"/"unknown" split to
#     extract, only a confidence flag for the one row kept at moderate rather than high
#     confidence).
#   - New "Censoring" column (survival responses only; "n/a" for every other response
#     type). Exploded per-outcome, like primary/secondary_outcome_type, not captured as
#     one raw row-level column -- see build_experimental_datasets_csv.R's matching comment:
#     a row-level column would wrongly read as applying to a non-survival outcome too in
#     any row pairing survival with something else. No current row does that (every row
#     has at most one survival outcome group), but the per-outcome shape costs nothing and
#     stays correct if one is ever added.

RESPONSE_TYPES <- c("continuous", "incidence", "count", "proportion", "survival", "ordinal")
OUTCOME_PREFIXES <- c("primary", "secondary", "tertiary")

script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) return("R/package_metadata")
  dirname(normalizePath(sub("^--file=", "", file_arg[1])))
}

squish <- function(x) trimws(gsub("\\s+", " ", x))
strip_md <- function(x) squish(gsub("`|\\*\\*", "", x))
drop_comments <- function(x) {
  repeat {
    y <- gsub("\\([^()]*\\)", "", x)
    if (identical(y, x)) return(x)
    x <- y
  }
}

# Split a markdown table row on unescaped pipes; "\|" inside a cell is a literal pipe.
split_row <- function(line) {
  placeholder <- ""
  cells <- strsplit(gsub("\\\\\\|", placeholder, line), "|", fixed = TRUE)[[1]]
  cells <- trimws(gsub(placeholder, "|", cells, fixed = TRUE))
  cells[-1]
}

read_dataset_table <- function(md_path) {
  lines <- readLines(md_path, encoding = "UTF-8", warn = FALSE)
  header_idx <- grep("^\\| Tier \\| Category \\| Dataset \\|", lines)
  if (length(header_idx) != 1) stop("expected exactly one dataset-table header in ", md_path)
  header <- split_row(lines[header_idx])
  i <- header_idx + 2
  rows <- list()
  while (i <= length(lines) && startsWith(lines[i], "|")) {
    cells <- split_row(lines[i])
    if (length(cells) != length(header)) {
      stop(sprintf("line %d has %d cells, expected %d", i, length(cells), length(header)))
    }
    rows[[length(rows) + 1]] <- cells
    i <- i + 1
  }
  tbl <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(tbl) <- header
  tbl
}

first_number <- function(x) {
  out <- rep(NA_real_, length(x))
  has_num <- grepl("[0-9]", x)
  out[has_num] <- as.numeric(gsub(",", "", regmatches(x, regexpr("[0-9][0-9,]*(\\.[0-9]+)?", x))))
  out
}

parse_types <- function(type_cell) {
  groups <- strsplit(drop_comments(gsub("\\*\\*", "", type_cell)), "+", fixed = TRUE)[[1]]
  hits <- regmatches(groups, regexpr(paste(RESPONSE_TYPES, collapse = "|"), groups))
  hits
}

# One list entry per type group, each a character vector of outcomes ("a" or "a/b").
parse_variables <- function(var_cell) {
  groups <- strsplit(drop_comments(var_cell), ";", fixed = TRUE)[[1]]
  lapply(groups, function(g) {
    outcomes <- trimws(strsplit(g, ",", fixed = TRUE)[[1]])
    outcomes <- outcomes[grepl("`", outcomes)]
    vapply(outcomes, function(o) {
      parts <- trimws(strsplit(gsub("`", "", o), "/", fixed = TRUE)[[1]])
      paste(parts[nzchar(parts)], collapse = "/")
    }, character(1), USE.NAMES = FALSE)
  })
}

parse_outcomes <- function(dataset, var_cell, type_cell) {
  types <- parse_types(type_cell)
  if (length(types) == 0) stop(dataset, ": no response type recognized in '", type_cell, "'")
  var_groups <- parse_variables(var_cell)
  n_vars <- sum(lengths(var_groups))
  if (n_vars > 0 && length(var_groups) != length(types)) {
    stop(sprintf("%s: %d outcome group(s) separated by ';' but %d response type(s)",
      dataset, length(var_groups), length(types)))
  }
  list(
    types = types,
    vars = unlist(var_groups),
    var_types = if (n_vars > 0) rep(types, lengths(var_groups)) else character(0)
  )
}

outcome_prefix <- function(k) if (k <= length(OUTCOME_PREFIXES)) OUTCOME_PREFIXES[k] else paste0("outcome_", k)

build_csv <- function(md_path, csv_path) {
  tbl <- read_dataset_table(md_path)
  outcomes <- Map(parse_outcomes, strip_md(tbl$Dataset), tbl[["Response Variable"]], tbl[["Response Type"]])
  outcomes <- unname(outcomes)
  n_outcomes <- vapply(outcomes, function(o) length(o$vars), integer(1))

  out <- data.frame(
    tier = tbl$Tier,
    category = tbl$Category,
    dataset = strip_md(tbl$Dataset),
    source = strip_md(tbl$Source),
    version = strip_md(tbl$Version),
    license = strip_md(tbl$License),
    n = first_number(tbl$n),
    n_raw = strip_md(tbl$n),
    p = first_number(tbl[["p (covariates)"]]),
    p_approx = grepl("~", tbl[["p (covariates)"]], fixed = TRUE),
    p_raw = strip_md(tbl[["p (covariates)"]]),
    w_column = strip_md(tbl[["w (group column)"]]),
    n_outcomes = n_outcomes,
    response_types = vapply(outcomes, function(o) paste(unique(o$types), collapse = ";"), character(1)),
    binary_only = vapply(outcomes, function(o) all(o$types == "incidence"), logical(1)),
    has_survival = vapply(outcomes, function(o) any(o$types == "survival"), logical(1)),
    stringsAsFactors = FALSE
  )
  censoring_raw <- strip_md(tbl$Censoring)
  censoring_val <- tolower(trimws(sub("\\(.*$", "", censoring_raw)))
  for (k in seq_len(max(n_outcomes))) {
    prefix <- outcome_prefix(k)
    out[[paste0(prefix, "_outcome")]] <- vapply(outcomes, function(o) if (k <= length(o$vars)) o$vars[k] else NA_character_, character(1))
    out[[paste0(prefix, "_outcome_type")]] <- vapply(outcomes, function(o) if (k <= length(o$vars)) o$var_types[k] else NA_character_, character(1))
    out[[paste0(prefix, "_outcome_censoring")]] <- vapply(seq_along(outcomes), function(i) {
      o <- outcomes[[i]]
      if (k > length(o$vars)) return(NA_character_)
      if (o$var_types[k] == "survival") censoring_val[i] else "n/a"
    }, character(1))
  }
  out$censoring_raw <- censoring_raw
  out$response_variable_raw <- strip_md(tbl[["Response Variable"]])
  out$response_type_raw <- strip_md(tbl[["Response Type"]])
  out$group_assignment <- strip_md(tbl[["Group Assignment"]])
  out$group_assignment_confidence <- ifelse(
    grepl("moderate confidence", out$group_assignment, ignore.case = TRUE), "moderate", "high"
  )
  out$description <- strip_md(tbl$Description)
  # Real grouping column for designs that need clusters (reviewed by hand, not a heuristic).
  # Cell form: `column` (N groups); empty when no real cluster column has been identified.
  cluster_raw <- strip_md(tbl[["Cluster Column"]])
  out$cluster_column <- sub("\\s*\\(.*$", "", cluster_raw)
  out$cluster_groups <- suppressWarnings(as.integer(sub("^.*\\(([0-9]+) groups\\).*$", "\\1", cluster_raw)))
  out$cluster_groups[!grepl("groups", cluster_raw)] <- NA_integer_

  # Rows whose License cell records a redistribution bar (e.g. ICPSR terms of use) may be
  # fetched and used locally, but must never be committed, bundled, or shared.
  out$redistribution <- ifelse(
    grepl("ICPSR terms|no redistribution|not redistributable", out$license, ignore.case = TRUE),
    "not permitted (ICPSR terms of use)", "not flagged")
  write.csv(out, csv_path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  invisible(out)
}

if (sys.nframe() == 0L) {
  dir <- script_dir()
  csv_path <- file.path(dir, "observational_datasets.csv")
  out <- build_csv(file.path(dir, "observational_datasets.md"), csv_path)
  cat(sprintf("wrote %d datasets (%d outcome variables; %d binary-only; %d survival with censoring info; %d with no outcome column in the loaded data) to %s\n",
    nrow(out), sum(out$n_outcomes), sum(out$binary_only), sum(out$has_survival), sum(out$n_outcomes == 0), csv_path))
}
