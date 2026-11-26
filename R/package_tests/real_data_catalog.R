# Shared loader for the real-data CI jobs: the crash corpus
# (R/package_tests/real_data_crash_corpus.R, v1.0.7-TODO-102) and the design-balance
# benchmark (R/benchmark/design_balance_real_data.R, v1.0.7-TODO-103).
#
# It turns one row of R/package_metadata/experimental_datasets.csv into the pieces an
# EDI design needs: a covariate data.frame, a 0/1 treatment vector, the real outcomes
# (already in EDI's ys / y_Ls / y_Rs form) and a design recipe. Only CRAN-hosted rows
# whose Redistribution cell is exactly "yes" are used (223 rows on 2026-11-25). The data
# come from the catalog's pinned CRAN release, fetched as a source tarball and read from
# its data/ directory without installing the package (the fetchers of
# R/package_metadata/download_experimental_datasets.R). Nothing fetched is ever committed
# or uploaded: the cache lives in a gitignored folder locally and in an Actions cache on CI.
#
# The catalog describes each trial in prose, so the resolution below is a set of rules,
# plus RDC_OVERRIDES for trials the rules cannot read. A row the rules cannot turn into a
# two-arm comparison is returned with a skip reason, never guessed at. The rules:
#   - Treatment: the treatment cell's leading column name. Cells naming several columns,
#     a factorial, a crossover or "N/A" are skipped. Two values: the control is the value
#     matching RDC_CONTROL_PATTERN (else the smaller number, else the first factor level).
#     More than two arms: control as above against the first other arm in level order;
#     subjects in the other arms are dropped (recorded in `arms`).
#   - Outcomes: every outcome slot of the row. Survival "time/indicator" pairs become
#     ys / y_Ls / y_Rs with right censoring; the indicator's event value is 1 (of 0/1),
#     2 (of 1/2 or 0/1/2, the survival-package convention) or, for a column named
#     "cens...", 0. Three-part (counting-process) survival cells and two time columns
#     are skipped. Proportions "a/b" are a/b when b is a total (name `total`, `m`, `n...`,
#     `size`, `litter`) and a/(a + b) otherwise; a single column in [0, 100] is divided by
#     100. Other "/"-joined outcome cells are wide (one column per arm) and are skipped.
#   - Covariates: every other column, minus the cluster column, id-like columns and
#     constant or all-NA ones; characters become factors (dropped above 30 levels).
#     Missing covariate values are kept: the designs impute them, and real missingness is
#     one of the things these jobs exist to exercise.
#   - Design: a blocked trial whose catalog Design cell says "block" or "stratif" and whose
#     cluster column varies treatment within groups -> DesignFixedBlocking on that column;
#     a cluster column with treatment constant within groups -> DesignFixedCluster; else
#     DesignFixedBernoulli at the trial's treated share. The trial's real assignment is
#     always passed as `w_precomputed` (the crash corpus) or discarded (design balance).
#   - Size: a trial above `subsample_above` rows (default 5000) is subsampled to `n_max`
#     rows (default 2000), per arm with a fixed seed (owner ruling 2026-11-26,
#     DECISION-v1.0.7-TODO-102); trials up to 5000 rows stay whole.

`%||%` <- function(a, b) if (is.null(a)) b else a

# The checkout root, from this file's own path (it lives in R/package_tests/), so the jobs
# run from any working directory. Falls back to git, then the working directory.
RDC_ROOT <- local({
	sourced <- Filter(is.character, lapply(rev(sys.frames()), function(f) f$ofile))
	here <- if (length(sourced)) dirname(normalizePath(sourced[[1L]])) else NA_character_
	if (!is.na(here) && file.exists(file.path(here, "..", "..", "R", "package_metadata"))) {
		normalizePath(file.path(here, "..", ".."))
	} else {
		top <- tryCatch(suppressWarnings(system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)),
			error = function(e) character())
		if (length(top) && nzchar(top[1L])) top[1L] else getwd()
	}
})
RDC_CATALOG_CSV <- file.path(RDC_ROOT, "R", "package_metadata", "experimental_datasets.csv")
RDC_OUTCOME_SLOTS <- c("primary", "secondary", "tertiary", paste0("outcome_", 4:14))
RDC_CONTROL_PATTERN <- "^(0|no|none|control|ctrl|placebo|plac|standard|std|usual|untreated|sham|false|c|n|regular|baseline|vehicle|water|soc)$|control|placebo"
RDC_RESPONSE_TYPES <- c("continuous", "incidence", "proportion", "count", "survival", "ordinal")

# Cache of fetched data frames (one .rds per dataset key). EDI_REAL_DATA_CACHE overrides;
# the default is inside the gitignored randomized_experiment_datasets/ folder.
rdc_cache_dir <- function() {
	d <- Sys.getenv("EDI_REAL_DATA_CACHE",
		file.path(RDC_ROOT, "R", "package_metadata", "randomized_experiment_datasets", "real_data_rds"))
	dir.create(d, showWarnings = FALSE, recursive = TRUE)
	d
}

rdc_key <- function(dataset) gsub("[^A-Za-z0-9_]", "_", gsub("::", "_", dataset, fixed = TRUE))

# The CRAN-hosted, redistributable catalog rows.
rdc_catalog <- function(path = RDC_CATALOG_CSV) {
	cat_df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = character())
	cat_df <- cat_df[startsWith(cat_df$source, "CRAN: ") & cat_df$redistribution == "yes", , drop = FALSE]
	cat_df$key <- rdc_key(cat_df$dataset)
	cat_df$pkg <- sub("^CRAN: ", "", cat_df$source)
	rownames(cat_df) <- NULL
	cat_df
}

# The manifest of download_experimental_datasets.R (which data/ file and object hold each
# dataset), loaded once without running its downloads.
rdc_manifest <- local({
	m <- NULL
	function() {
		if (is.null(m)) {
			e <- new.env()
			suppressPackageStartupMessages(sys.source(
				file.path(RDC_ROOT, "R", "package_metadata", "download_experimental_datasets.R"), envir = e, chdir = TRUE))
			m <<- e
		}
		m
	}
})

# The data frame of one catalog row, at the catalog's pinned CRAN release.
rdc_fetch <- function(row, cache_dir = rdc_cache_dir()) {
	rds <- file.path(cache_dir, paste0(row$key, "_", row$version, ".rds"))
	if (file.exists(rds)) return(readRDS(rds))
	e <- rdc_manifest()
	spec <- e$DATASET_MANIFEST[[row$key]] %||% e$DATASET_MANIFEST[[row$dataset]]
	if (is.null(spec$cran)) stop("no CRAN manifest entry for ", row$dataset, call. = FALSE)
	work <- file.path(cache_dir, "work")
	dir.create(work, showWarnings = FALSE)
	pkg_dir <- e$cran_extract_package(spec$cran$pkg, row$version, work)
	df <- e$load_data_object(pkg_dir, obj_name = spec$cran$obj_name, file_name = spec$cran$rda_name,
		list_element = spec$cran$list_element, label = paste(spec$cran$pkg, row$version))
	saveRDS(df, rds)
	df
}

# Per-dataset fixes the rules cannot infer. Each entry may set: `prep` (a function of the
# data frame, run first), `treatment` (column), `control` / `treated` (arm values),
# `outcomes` (a list of list(cell, type) replacing the catalog's), `design`
# ("blocking" / "cluster" / "bernoulli"), `group_col` (the blocking or cluster column),
# `order_col` (enrollment order, for sequential designs), `drop` (extra columns to drop),
# `event_value` (the survival indicator's event value, when the column name misleads),
# `skip` (a reason).
RDC_OVERRIDES <- list(
	# README "Real data": one row per patient (first infection), permuted blocks within center.
	cgd = list(prep = function(d) d[d$enum == 1, , drop = FALSE], outcomes = list(list(cell = "tstop/status", type = "survival")),
		design = "blocking", group_col = "center", order_col = "random", drop = c("id", "enum", "tstart")),
	# Two rows per patient (etype 1 = recurrence, 2 = death): keep death.
	colon = list(prep = function(d) d[d$etype == 2, , drop = FALSE], drop = c("id", "study", "etype"), design = "bernoulli",
		control = "Obs", treated = "Lev+5FU"),
	# Kindergarten class type: small vs regular (the regular+aide arm is dropped).
	STAR = list(treatment = "stark", control = "regular", treated = "small", design = "bernoulli"),
	# trt: 1 = D-penicillamine, 2 = placebo, NA = the 106 non-randomized patients.
	pbc = list(control = "2", treated = "1"),
	# Catalog cells that name a description, not the column.
	`lqmm::labor` = list(treatment = "treatment"),
	`dae::McIntyreTMV.dat` = list(treatment = "Treat"),
	`RPEXE.RPEXT::data2` = list(treatment = "V3"),
	# `cens` is 1 = relapse (every control patient relapsed), not 1 = censored as the name suggests.
	`BGPhazard::gehan` = list(event_value = 1),
	# Post-randomization columns: the 6-month radiologic outcome (`radiologic_6m` is `rad_num` as a factor), the doses
	# (set by the arm) and the streptomycin resistance that developed during treatment.
	strep_tb = list(drop = c("radiologic_6m", "dose_strep_g", "dose_PAS_g", "strep_resistance"))
)

rdc_first_column_token <- function(cell) {
	cell <- trimws(gsub("`", "", cell))
	if (!nzchar(cell)) return(NA_character_)
	if (grepl("^N/A|factorial|crossover|cross-over|derived:", cell, ignore.case = TRUE)) return(NA_character_)
	head <- trimws(sub("[ (,].*$", "", cell))
	rest <- trimws(substring(cell, nchar(head) + 1L))
	# "a / b", "a x b" or a second column outside the parenthetical: more than one factor.
	if (grepl("/", head) || grepl("^(/|x |vs\\b|\\*)", rest)) return(NA_character_)
	if (grepl("\\)\\s*(/|x)\\s*\\w", rest)) return(NA_character_)
	head
}

rdc_match_col <- function(name, df) {
	if (is.na(name) || !nzchar(name)) return(NA_character_)
	if (name %in% names(df)) return(name)
	hit <- names(df)[tolower(names(df)) == tolower(name)]
	if (length(hit) == 1L) hit else NA_character_
}

rdc_arm_values <- function(x) {
	if (is.factor(x)) return(levels(droplevels(x)))
	v <- unique(x[!is.na(x)])
	if (is.numeric(v) || is.logical(v)) as.character(sort(v)) else sort(as.character(v))
}

# 0/1 treatment from the treatment column, or a skip reason.
rdc_code_treatment <- function(x, control = NULL, treated = NULL) {
	vals <- rdc_arm_values(x)
	if (length(vals) < 2L) return(list(skip = "treatment column has fewer than two arms"))
	xs <- as.character(x)
	ctrl <- control %||% {
		hit <- vals[grepl(RDC_CONTROL_PATTERN, vals, ignore.case = TRUE)]
		if (length(hit) == 1L) hit else vals[1L]
	}
	if (!ctrl %in% vals) return(list(skip = paste0("control value '", ctrl, "' not in the treatment column")))
	trt <- treated %||% setdiff(vals, ctrl)[1L]
	if (!trt %in% vals) return(list(skip = paste0("treated value '", trt, "' not in the treatment column")))
	keep <- !is.na(xs) & xs %in% c(ctrl, trt)
	w <- as.integer(xs == trt)
	list(w = w, keep = keep, arms = sprintf("%s (control) vs %s%s", ctrl, trt,
		if (length(vals) > 2L) sprintf("; %d other arm(s) dropped", length(vals) - 2L) else ""))
}

rdc_split_cell <- function(cell) {
	parts <- trimws(strsplit(gsub("`", "", cell), "/", fixed = TRUE)[[1L]])
	parts[nzchar(parts)]
}

rdc_event_indicator <- function(ind, name, event_value = NULL) {
	if (!is.null(event_value)) return(ind == event_value)
	if (is.logical(ind)) return(ind)
	if (is.factor(ind) || is.character(ind)) {
		s <- tolower(as.character(ind))
		ev <- grepl("dead|death|died|event|relapse|yes|^1$|true|fail|recur", s)
		return(ifelse(is.na(ind), NA, ev))
	}
	v <- sort(unique(ind[!is.na(ind)]))
	if (grepl("cens", name, ignore.case = TRUE)) return(ind == min(v))
	if (length(v) > 3L) return(NULL)
	ind == max(v)
}

# One outcome cell -> list(ys, y_Ls, y_Rs, cols) or list(skip = reason).
rdc_outcome <- function(df, cell, type, event_value = NULL) {
	parts <- rdc_split_cell(cell)
	if (!length(parts)) return(list(skip = "empty outcome cell"))
	cols <- vapply(parts, rdc_match_col, character(1), df = df)
	if (anyNA(cols)) return(list(skip = paste0("outcome column(s) not in data: ", paste(parts[is.na(cols)], collapse = ", "))))
	if (type == "survival") {
		if (length(cols) == 1L) {
			t <- suppressWarnings(as.numeric(df[[cols]]))
			return(list(ys = t, y_Ls = rep(NA_real_, length(t)), y_Rs = rep(NA_real_, length(t)), cols = cols))
		}
		if (length(cols) != 2L) return(list(skip = "counting-process survival outcome (start/stop/status)"))
		t <- suppressWarnings(as.numeric(df[[cols[1L]]]))
		ev <- rdc_event_indicator(df[[cols[2L]]], cols[2L], event_value)
		if (is.null(ev)) return(list(skip = "survival outcome's second column is not an event indicator (two time columns)"))
		ev <- as.logical(ev)
		return(list(ys = ifelse(ev, t, NA_real_), y_Ls = ifelse(ev, NA_real_, t), y_Rs = ifelse(ev, NA_real_, Inf),
			cols = cols, missing = is.na(t) | is.na(ev)))
	}
	if (type == "proportion" && length(cols) == 2L) {
		a <- suppressWarnings(as.numeric(df[[cols[1L]]]))
		b <- suppressWarnings(as.numeric(df[[cols[2L]]]))
		denom <- if (grepl("^(total|m|n.*|size|litter.*|ntrt)$", cols[2L], ignore.case = TRUE)) b else a + b
		return(list(ys = ifelse(denom > 0, a / denom, NA_real_), cols = cols))
	}
	if (length(cols) != 1L) return(list(skip = "wide outcome (one column per arm or per period)"))
	y <- rdc_numeric_if_numeric_text(df[[cols]])
	ys <- switch(type,
		continuous = if (is.numeric(y) || is.logical(y)) as.numeric(y) else NULL,
		count = if (is.numeric(y) && all(y[!is.na(y)] >= 0 & y[!is.na(y)] == round(y[!is.na(y)]))) as.numeric(y) else NULL,
		proportion = if (is.numeric(y)) {
			r <- range(y, na.rm = TRUE)
			if (r[1L] >= 0 && r[2L] <= 1) as.numeric(y) else if (r[1L] >= 0 && r[2L] <= 100) as.numeric(y) / 100 else NULL
		},
		incidence = {
			if (is.logical(y)) as.numeric(y)
			else {
				vals <- rdc_arm_values(y)
				if (length(vals) != 2L) NULL
				else {
					hit <- vals[grepl("^(1|yes|y|true|success|s|event|dead|died|positive|pos)$", vals, ignore.case = TRUE)]
					succ <- if (length(hit) == 1L) hit else vals[2L]
					ifelse(is.na(y), NA_real_, as.numeric(as.character(y) == succ))
				}
			}
		},
		ordinal = {
			if (is.ordered(y)) droplevels(y)
			else if (is.factor(y)) factor(y, levels = levels(droplevels(y)), ordered = TRUE)
			else if (is.numeric(y) && length(unique(y[!is.na(y)])) <= 15L) factor(y, levels = sort(unique(y[!is.na(y)])), ordered = TRUE)
			else NULL
		},
		NULL)
	if (is.null(ys)) return(list(skip = sprintf("outcome '%s' does not read as %s", cols, type)))
	list(ys = ys, cols = cols)
}

# Character columns that hold only numbers (some packages store them as text).
rdc_numeric_if_numeric_text <- function(x) {
	if (!is.character(x)) return(x)
	v <- trimws(x[!is.na(x) & nzchar(trimws(x))])
	if (length(v) && !anyNA(suppressWarnings(as.numeric(v)))) suppressWarnings(as.numeric(x)) else x
}

rdc_catalog_outcomes <- function(row) {
	out <- list()
	for (s in RDC_OUTCOME_SLOTS) {
		cell <- row[[paste0(s, "_outcome")]]
		type <- row[[paste0(s, "_outcome_type")]]
		if (is.null(cell) || is.na(cell) || !nzchar(cell) || !type %in% RDC_RESPONSE_TYPES) next
		out[[length(out) + 1L]] <- list(cell = cell, type = type)
	}
	out
}

rdc_clean_covariates <- function(df, exclude) {
	X <- df[, setdiff(names(df), exclude), drop = FALSE]
	X[] <- lapply(X, rdc_numeric_if_numeric_text)
	keep <- vapply(names(X), function(nm) {
		x <- X[[nm]]
		if (grepl("^(id|.*_id|subject|subj|patient|record|obs|row)$", nm, ignore.case = TRUE)) return(FALSE)
		if (all(is.na(x))) return(FALSE)
		if (length(unique(x[!is.na(x)])) < 2L) return(FALSE)
		if (is.character(x) || is.factor(x)) {
			nl <- length(unique(x[!is.na(x)]))
			if (nl > 30L) return(FALSE)
		}
		is.numeric(x) || is.logical(x) || is.factor(x) || is.character(x) || inherits(x, c("Date", "POSIXt"))
	}, logical(1))
	X <- X[, keep, drop = FALSE]
	for (nm in names(X)) {
		x <- X[[nm]]
		if (inherits(x, c("Date", "POSIXt"))) X[[nm]] <- as.numeric(x)
		else if (is.character(x)) X[[nm]] <- factor(x)
		else if (is.logical(x)) X[[nm]] <- as.numeric(x)
		else if (is.factor(x)) X[[nm]] <- droplevels(factor(x, ordered = FALSE))
		else X[[nm]] <- x
	}
	X
}

# One catalog row -> a resolved trial, or a list with `skip`.
#   dataset, n, arms, design (bernoulli / blocking / cluster), group_col, prob_T, X, w,
#   order (enrollment order or NULL), subsampled, outcomes: list of list(name, type, ys,
#   y_Ls, y_Rs, keep) where keep marks the rows with an observed outcome.
rdc_resolve <- function(row, df = rdc_fetch(row), n_max = 2000L, subsample_above = 5000L, seed = 1L) {
	ov <- RDC_OVERRIDES[[row$dataset]] %||% RDC_OVERRIDES[[row$key]] %||% list()
	base <- list(dataset = row$dataset)
	if (!is.null(ov$skip)) return(c(base, skip = ov$skip))
	df <- as.data.frame(df)
	if (!is.null(ov$prep)) df <- ov$prep(df)
	tr_col <- ov$treatment %||% rdc_match_col(rdc_first_column_token(row$treatment), df)
	if (is.na(tr_col)) return(c(base, skip = paste0("treatment cell does not name one column: ", row$treatment)))
	tc <- rdc_code_treatment(df[[tr_col]], control = ov$control, treated = ov$treated)
	if (!is.null(tc$skip)) return(c(base, skip = tc$skip))
	specs <- ov$outcomes %||% rdc_catalog_outcomes(row)
	if (!length(specs)) return(c(base, skip = "no outcome of a supported response type"))
	df <- df[tc$keep, , drop = FALSE]
	w <- tc$w[tc$keep]
	if (min(sum(w), sum(1L - w)) < 2L) return(c(base, skip = "an arm has fewer than two subjects"))
	subsampled <- FALSE
	if (nrow(df) > subsample_above && nrow(df) > n_max) {
		set.seed(seed)
		share <- n_max / nrow(df)
		idx <- sort(c(sample(which(w == 1L), max(2L, round(sum(w) * share))), sample(which(w == 0L), max(2L, round(sum(1L - w) * share)))))
		df <- df[idx, , drop = FALSE]
		w <- w[idx]
		subsampled <- TRUE
	}
	outcomes <- list()
	outcome_cols <- character()
	skipped <- character()
	for (sp in specs) {
		o <- rdc_outcome(df, sp$cell, sp$type, event_value = ov$event_value)
		if (!is.null(o$skip)) { skipped <- c(skipped, sprintf("%s (%s): %s", sp$cell, sp$type, o$skip)); next }
		outcome_cols <- c(outcome_cols, o$cols)
		n <- nrow(df)
		ys <- o$ys
		y_Ls <- o$y_Ls %||% rep(NA_real_, n)
		y_Rs <- o$y_Rs %||% rep(NA_real_, n)
		has <- if (is.factor(ys)) !is.na(ys) else !is.na(ys) | (!is.na(y_Ls) & !is.na(y_Rs))
		if (!is.null(o$missing)) has <- has & !o$missing
		if (sp$type == "survival") has <- has & (is.na(ys) | ys > 0) & (is.na(y_Ls) | y_Ls > 0)
		outcomes[[length(outcomes) + 1L]] <- list(name = paste(o$cols, collapse = "/"), type = sp$type,
			ys = ys, y_Ls = y_Ls, y_Rs = y_Rs, keep = has)
	}
	# Every catalogued outcome column is excluded from the covariates, read or not.
	all_outcome_cols <- unlist(lapply(specs, function(sp) {
		p <- rdc_split_cell(sp$cell); m <- vapply(p, rdc_match_col, character(1), df = df); m[!is.na(m)]
	}))
	if (!length(outcomes)) return(c(base, skip = paste("no outcome could be read:", paste(skipped, collapse = "; "))))
	group_col <- ov$group_col %||% rdc_match_col(if (nzchar(row$cluster_column)) row$cluster_column else NA_character_, df)
	design <- ov$design
	if (is.null(design)) {
		design <- "bernoulli"
		if (!is.na(group_col %||% NA)) {
			g <- df[[group_col]]
			within <- tapply(w, g, function(v) length(unique(v)))
			if (all(within == 1L) && length(within) >= 4L && max(table(g)) > 1L) design <- "cluster"
			else if (grepl("block|stratif", row$design, ignore.case = TRUE) && length(within) <= max(2L, nrow(df) / 4)) design <- "blocking"
		}
	}
	if (design == "bernoulli") group_col <- NA_character_
	order_col <- if ("order_col" %in% names(ov)) ov$order_col else NULL
	order <- if (!is.null(order_col) && order_col %in% names(df)) order(df[[order_col]]) else NULL
	exclude <- unique(c(tr_col, all_outcome_cols, ov$drop, if (!is.na(group_col) && design == "cluster") character() else NULL))
	if (!is.na(row$cluster_column) && nzchar(row$cluster_column) && design == "bernoulli") {
		cc <- rdc_match_col(row$cluster_column, df)
		if (!is.na(cc)) exclude <- c(exclude, cc)
	}
	X <- rdc_clean_covariates(df, exclude)
	if (!is.na(group_col)) {
		X[[group_col]] <- factor(df[[group_col]])
	}
	cat_group <- ov$group_col %||% rdc_match_col(if (nzchar(row$cluster_column)) row$cluster_column else NA_character_, df)
	c(base, list(n = nrow(df), arms = tc$arms, catalog_group_col = cat_group,
		groups = if (is.na(cat_group)) NULL else df[[cat_group]], treatment_col = tr_col, design = design, group_col = group_col,
		prob_T = mean(w), X = X, w = w, order = order, subsampled = subsampled, outcomes = outcomes,
		unread_outcomes = skipped))
}

# Restrict a resolved trial to one outcome's observed rows (designs need every response).
rdc_outcome_subset <- function(trial, k) {
	o <- trial$outcomes[[k]]
	keep <- o$keep
	sub <- function(v) if (is.factor(v)) droplevels(v[keep]) else v[keep]
	list(X = trial$X[keep, , drop = FALSE], w = trial$w[keep], ys = sub(o$ys), y_Ls = o$y_Ls[keep], y_Rs = o$y_Rs[keep],
		type = o$type, name = o$name, groups = if (is.null(trial$groups)) NULL else trial$groups[keep],
		order = if (is.null(trial$order)) NULL else order(match(seq_along(keep), trial$order)[keep]))
}

# An EDI fixed design for a resolved trial (or its outcome subset `s`), with the subjects added.
# `w`: the assignment to precompute, or NULL to let the design draw.
rdc_new_design <- function(trial, s, response_type, w = s$w) {
	n <- nrow(s$X)
	X <- s$X
	if (trial$design == "cluster") {
		des <- EDI::DesignFixedCluster$new(cluster_col = trial$group_col, response_type = response_type,
			prob_T = mean(s$w), n = n)
	} else if (trial$design == "blocking") {
		des <- EDI::DesignFixedBlocking$new(n = n, response_type = response_type, strata_cols = trial$group_col,
			equal_block_sizes = FALSE)
	} else {
		des <- EDI::DesignFixedBernoulli$new(n = n, response_type = response_type, prob_T = mean(s$w))
	}
	des$add_all_subjects_to_experiment(X)
	if (is.null(w)) des$assign_w_to_all_subjects() else des$assign_w_to_all_subjects(w_precomputed = as.numeric(w))
	des
}

rdc_add_responses <- function(des, s) {
	if (s$type == "survival") des$add_all_subject_responses(ys = s$ys, y_Ls = s$y_Ls, y_Rs = s$y_Rs)
	else des$add_all_subject_responses(ys = s$ys)
	invisible(des)
}
