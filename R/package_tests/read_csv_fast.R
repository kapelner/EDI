# read_csv_fast(): a drop-in for utils::read.csv() in the package_tests tooling,
# reading with data.table::fread() (multi-threaded C) but returning exactly what
# read.csv() would: a data.frame with read.csv's column types, NA handling and
# column names. (2026-11-13: read.csv was most of the smoke analyzer's runtime.)
#
# Why every field is read as text (not fread's own column typing, which is ~3x
# faster on a 700 MB file): fread's number parser can differ from R's in the
# last bit (3.2905490658502703e-290 came back as ...697e-290), and it parses
# dates, which read.csv never does. Generated CSVs must stay byte-identical.
#
# How it matches read.csv: fread reads every field as raw text (colClasses =
# "character", no white-space stripping, no date or number guessing), then each
# column goes through utils::type.convert(), the same converter read.csv uses,
# with the same na.strings rule. Names get read.csv's make.names(unique = TRUE)
# unless check.names = FALSE.
#
# Supported arguments, the ones the call sites use: file or text, header,
# stringsAsFactors, na.strings, colClasses ("character" for all columns, a
# named vector like c(formula = "character"), or fread-style
# list(character = c("formula"))), check.names, nrows. Anything else is passed
# through to read.csv() itself rather than guessed at.
#
# data.table is in EDI's Imports, so it is present wherever EDI is installed.

# Whether this data.table's fread leaves a quoted field's escaped "" doubled
# (1.18.4 does; read.csv returns one "). Probed once, so a data.table that
# unescapes them itself is not unescaped twice.
read_csv_fast_unescape_quotes = identical(data.table::fread(text = "a\n\"x\"\"y\"\n", showProgress = FALSE)$a, "x\"\"y")

# data.table::fread() with fread's own column types, plus the one fix it needs:
# data.table 1.18.4 leaves a quoted field's doubled quotes ("") doubled, so
# could not find function "foo" (written as "could not find function ""foo""")
# reads back with "" around foo, and a read-then-fwrite cycle doubles them
# again on every pass. Only when the probe above shows that bug, turn "" back
# into " in the text columns, rewriting only the cells that contain one
# (~5% on top of fread for a 900 MB results file, 2026-11-14). For scripts
# that read results with fread and write them back (merge, prune, resume);
# read_csv_fast() stays the read.csv-identical reader.
fread_unescaped = function(...) {
	dt = data.table::fread(...)
	if (!read_csv_fast_unescape_quotes) return(dt)
	for (j in seq_along(dt)) {
		x = dt[[j]]
		if (!is.character(x)) next
		i = which(grepl("\"\"", x, fixed = TRUE))
		if (!length(i)) next
		x[i] = gsub("\"\"", "\"", x[i], fixed = TRUE)
		if (data.table::is.data.table(dt)) data.table::set(dt, j = j, value = x) else dt[[j]] = x
	}
	dt
}

read_csv_fast = function(file, header = TRUE, stringsAsFactors = FALSE, na.strings = "NA",
                         colClasses = NA, check.names = TRUE, nrows = -1L, text, ...) {
	if (length(list(...))) {
		if (missing(text)) return(utils::read.csv(file, header = header, stringsAsFactors = stringsAsFactors, na.strings = na.strings, colClasses = colClasses, check.names = check.names, nrows = nrows, ...))
		return(utils::read.csv(text = text, header = header, stringsAsFactors = stringsAsFactors, na.strings = na.strings, colClasses = colClasses, check.names = check.names, nrows = nrows, ...))
	}
	# What fread cannot read here goes to read.csv itself: a connection (gzfile(), url(), ...), and a compressed file
	# (.gz, .bz2, .xz) when R.utils is not installed, since fread decompresses only through R.utils. The calibration
	# study's analyze job has data.table but not R.utils, and its stats are tests.csv.gz / est.csv.gz (run
	# 43386405728 failed on exactly this).
	if (missing(text) && (!is.character(file) || (grepl("\\.(gz|bz2|xz)$", file[[1L]], ignore.case = TRUE) &&
		!requireNamespace("R.utils", quietly = TRUE))))
		return(utils::read.csv(file, header = header, stringsAsFactors = stringsAsFactors, na.strings = na.strings,
			colClasses = if (is.list(colClasses)) read_csv_fast_colclasses(colClasses) else colClasses, check.names = check.names, nrows = nrows))
	src = if (!missing(text)) list(text = paste(text, collapse = "\n")) else {
		if (is.character(file) && length(file) == 1L && file.exists(file) && isTRUE(file.info(file)$size == 0)) {
			stop("no lines available in input", call. = FALSE)  # read.csv's error on an empty file
		}
		list(file = file)
	}
	df = do.call(data.table::fread, c(src, list(
		sep = ",", quote = "\"", header = header, colClasses = "character", na.strings = NULL,
		strip.white = FALSE, fill = TRUE, blank.lines.skip = TRUE, check.names = FALSE, skip = 0L,
		nrows = if (is.numeric(nrows) && nrows >= 0) nrows else Inf,
		data.table = FALSE, showProgress = FALSE, logical01 = FALSE
	)))
	keep_character = character_columns_for(colClasses, names(df))
	for (j in seq_along(df)) {
		x = df[[j]]
		# fread (data.table 1.18.4) strips a quoted field's outer quotes but leaves
		# its escaped "" doubled, where read.csv returns one ". In write.csv output
		# (and any RFC 4180 file) every text field holding a quote is quoted, so
		# every "" in a field is an escaped ".
		if (read_csv_fast_unescape_quotes) {
			dq = which(grepl("\"\"", x, fixed = TRUE))
			if (length(dq)) x[dq] = gsub("\"\"", "\"", x[dq], fixed = TRUE)
		}
		x[x %in% na.strings] = NA_character_
		df[[j]] = if (names(df)[[j]] %in% keep_character) x else utils::type.convert(x, na.strings = character(), as.is = !stringsAsFactors)
	}
	if (check.names) names(df) = make.names(names(df), unique = TRUE)
	df
}

# Column names that colClasses asks to keep as character.
character_columns_for = function(colClasses, column_names) {
	if (is.null(colClasses) || all(is.na(colClasses))) return(character())
	if (is.list(colClasses)) return(intersect(as.character(colClasses$character), column_names))
	if (is.null(names(colClasses))) {
		if (length(colClasses) == 1L && identical(unname(colClasses), "character")) return(column_names)
		return(column_names[which(colClasses == "character")])
	}
	names(colClasses)[colClasses == "character"]
}

# fread-style list(character = c("a", "b")) as read.csv's named vector c(a = "character", b = "character").
read_csv_fast_colclasses = function(colClasses) {
	cols = as.character(colClasses$character)
	stats::setNames(rep("character", length(cols)), cols)
}
