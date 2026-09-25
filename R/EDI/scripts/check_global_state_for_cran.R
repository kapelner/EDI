#!/usr/bin/env Rscript
# Pre-submission check that EDI never modifies the user's global state, per the
# CRAN policy a 2026-09-25 review cited ("Please do not modify the .GlobalEnv";
# "do not change the user's options, par or working directory"; ".Random.seed
# ... should not be changed at all"):
# https://contributor.r-project.org/cran-cookbook/code_issues.html
#
# Usage:
#   Rscript check_global_state_for_cran.R <pkg_dir> --static-only
#   Rscript check_global_state_for_cran.R <pkg_dir> [--lib <library containing the EDI build to test>]
#   Rscript check_global_state_for_cran.R <pkg_dir> --load-all   (dev: test the source tree via
#     pkgload::load_all(compile = FALSE) -- never compiles; needs an already-built src/*.so)
#
# Static checks (parse the package's R/ sources, no package needed):
#   - a `<<-` whose target is not a variable of an enclosing function: only
#     then can it create or overwrite a variable in .GlobalEnv (a `<<-` into an
#     enclosing function's own variable is the pattern CRAN recommends);
#   - any assign()/rm()/remove()/`$<-`/`[[<-` into .GlobalEnv / globalenv(),
#     except of .Random.seed (saving the user's RNG state and putting it back
#     unchanged on exit, the withr::with_seed pattern, is how set.seed() inside
#     a function is made side-effect free);
#   - any attach() call.
# Runtime checks (unless --static-only): loading EDI and running its parallel,
# simulation and inference-suite entry points must leave options(), the working
# directory, the objects in .GlobalEnv and (for seeded runs) .Random.seed
# exactly as they were. Thread environment variables are not checked: EDI
# deliberately manages OMP/BLAS thread counts.
# Exits non-zero, listing every problem, if anything fails.

args = commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("usage: check_global_state_for_cran.R <pkg_dir> [--static-only] [--lib <path>]")
pkg_dir = args[1]
static_only = "--static-only" %in% args
lib = if ("--lib" %in% args) args[which(args == "--lib") + 1L] else NULL
load_all = "--load-all" %in% args
problems = character()

## ---- static checks ----------------------------------------------------------
src_files = sort(list.files(file.path(pkg_dir, "R"), pattern = "\\.[Rr]$", full.names = TRUE))
cat("Static checks of", length(src_files), "R source files: no .GlobalEnv writes, no unsafe `<<-`, no attach()\n")
global_env_expr = "^(\\.GlobalEnv|globalenv\\(\\)|base::globalenv\\(\\)|as\\.environment\\(1L?\\))$"
n_safe_superassign = 0L
for (f in src_files) {
	src_lines = readLines(f, warn = FALSE)
	has_superassign = any(grepl("<<-", src_lines, fixed = TRUE))
	has_global = any(grepl("\\.GlobalEnv|globalenv\\(|as\\.environment\\(1|attach\\(", src_lines))
	if (!has_superassign && !has_global) next
	pd = utils::getParseData(parse(f, keep.source = TRUE))
	row_of = function(id) match(id, pd$id)
	parent_of = function(id) pd$parent[row_of(id)]
	children = split(pd$id, pd$parent)
	kids = function(id) { k = children[[as.character(id)]]; if (is.null(k)) integer() else k }
	txt = function(id) utils::getParseText(pd, id)
	where = function(id) sprintf("R/%s:%d", basename(f), pd$line1[row_of(id)])
	fun_exprs = pd$parent[pd$token == "FUNCTION"]          # expr ids of every `function(...) ...`
	enclosing_functions = function(id) {                     # innermost first
		out = integer()
		while (length(id) && !is.na(id) && id != 0L) {
			if (id %in% fun_exprs) out = c(out, id)
			id = parent_of(id)
		}
		out
	}
	# 1. `<<-` must target a variable of an enclosing function
	for (op in pd$id[pd$token == "LEFT_ASSIGN" & pd$text == "<<-"]) {
		lhs = kids(parent_of(op))[1L]                        # first child of the assignment = the target expression
		lhs_syms = pd[pd$token == "SYMBOL" & pd$line1 >= pd$line1[row_of(lhs)] & pd$line2 <= pd$line2[row_of(lhs)] &
			pd$col1 >= pd$col1[row_of(lhs)] & (pd$line1 > pd$line1[row_of(lhs)] | pd$col1 <= pd$col2[row_of(lhs)]), ]
		target = lhs_syms$text[order(lhs_syms$line1, lhs_syms$col1)][1L]
		rx = gsub(".", "\\.", target, fixed = TRUE)
		found = FALSE
		for (fn in enclosing_functions(op)[-1L]) {           # skip the function doing the `<<-`
			fn_src = txt(fn)
			if (grepl(paste0("(^|[^A-Za-z0-9_.$@])", rx, "\\s*(=|<-)[^=]"), fn_src) ||
					grepl(paste0("^function\\s*\\(([^)]*[,[:space:]])?", rx, "\\s*(=|,|\\))"), fn_src)) {
				found = TRUE
				break
			}
		}
		if (found) {
			n_safe_superassign = n_safe_superassign + 1L
		} else {
			problems = c(problems, sprintf("%s: `%s <<- ...` -- `%s` is not a variable of any enclosing function, so this can write to .GlobalEnv; use a local environment instead",
				where(op), target, target))
		}
	}
	if (!has_global) next
	# 2. attach(), and assign()/rm()/... into the global environment
	calls = pd[pd$token == "SYMBOL_FUNCTION_CALL" &
		pd$text %in% c("attach", "assign", "rm", "remove", "delayedAssign", "makeActiveBinding"), ]
	for (k in seq_len(nrow(calls))) {
		call_id = parent_of(parent_of(calls$id[k]))
		call_src = gsub("\\s+", " ", txt(call_id))
		if (calls$text[k] == "attach") {
			problems = c(problems, sprintf("%s: attach() modifies the user's search path", where(calls$id[k])))
			next
		}
		arg_ids = kids(call_id)
		arg_ids = arg_ids[pd$token[row_of(arg_ids)] == "expr"][-1L]
		arg_srcs = vapply(arg_ids, function(a) gsub("\\s+", "", txt(a)), "")
		if (any(grepl(global_env_expr, arg_srcs)) && !grepl("\\.Random\\.seed", call_src)) {
			problems = c(problems, sprintf("%s: writes to the global environment: %s", where(calls$id[k]), substr(call_src, 1, 160)))
		}
	}
	# 3. `.GlobalEnv$x <- ...` / `globalenv()[["x"]] <- ...`
	for (ln in grep("(\\.GlobalEnv|globalenv\\(\\))\\s*(\\$|\\[\\[)[^=]*[^=<>!]=[^=]|(\\.GlobalEnv|globalenv\\(\\))\\s*(\\$|\\[\\[).*<-", src_lines)) {
		if (grepl("^\\s*#", src_lines[ln]) || grepl("\\.Random\\.seed", src_lines[ln])) next
		problems = c(problems, sprintf("R/%s:%d: assignment into the global environment: %s", basename(f), ln, trimws(src_lines[ln])))
	}
}
cat(sprintf("  (%d `<<-` uses all target a variable of an enclosing function -- OK)\n", n_safe_superassign))

## ---- runtime checks -------------------------------------------------------------
if (!static_only && !length(problems)) {
	if (!is.null(lib)) .libPaths(c(lib, .libPaths()))
	state = function() list(
		options = options(),
		wd = getwd(),
		globals = sort(ls(globalenv(), all.names = TRUE)),
		seed = if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) get(".Random.seed", envir = globalenv()) else NULL
	)
	# An option that did not exist before, set by ANOTHER package whose namespace
	# got loaded during the call (named after it, e.g. datatable.* / fixest_*, or
	# set in its .onLoad, e.g. cli's setting callr.*), is that package's own
	# load-time default, not EDI writing to the user's options. EDI itself is
	# never excused.
	squash = function(x) gsub("[^a-z0-9]", "", tolower(x))
	is_new_dependency_default = function(opt, new_namespaces) {
		new_namespaces = setdiff(new_namespaces, "EDI")
		if (any(startsWith(squash(opt), squash(new_namespaces)) & nchar(squash(new_namespaces)) >= 3L)) return(TRUE)
		for (ns in new_namespaces) {
			on_load = get0(".onLoad", envir = asNamespace(ns), inherits = FALSE)
			if (is.function(on_load) && any(grepl(opt, deparse(on_load), fixed = TRUE))) return(TRUE)
		}
		FALSE
	}
	check = function(label, expr, check_seed = TRUE) {
		cat(sprintf("  %-62s", label)); flush(stdout())
		before = state()
		ns_before = loadedNamespaces()
		# progress bars and messages go to stderr; keep them off the report
		msg_sink = file(nullfile(), open = "wt")
		sink(msg_sink, type = "message")
		err = tryCatch({
			utils::capture.output(suppressMessages(suppressWarnings(force(expr))), type = "output")
			NULL
		}, error = conditionMessage, finally = {sink(type = "message"); close(msg_sink)})
		after = state()
		new_namespaces = setdiff(loadedNamespaces(), ns_before)
		found = character()
		if (!is.null(err)) found = c(found, paste("errored:", err))
		new_opts = setdiff(names(after$options), names(before$options))
		new_opts = new_opts[!vapply(new_opts, is_new_dependency_default, logical(1L), new_namespaces = new_namespaces)]
		changed_opts = union(new_opts,
			names(before$options)[!mapply(identical, before$options, after$options[names(before$options)])])
		if (length(changed_opts)) found = c(found, paste("changed options():", paste(changed_opts, collapse = ", ")))
		if (!identical(before$wd, after$wd)) found = c(found, sprintf("changed the working directory to %s", after$wd))
		new_globals = setdiff(after$globals, before$globals)
		gone_globals = setdiff(before$globals, after$globals)
		if (length(new_globals)) found = c(found, paste("created in .GlobalEnv:", paste(new_globals, collapse = ", ")))
		if (length(gone_globals)) found = c(found, paste("removed from .GlobalEnv:", paste(gone_globals, collapse = ", ")))
		if (check_seed && !identical(before$seed, after$seed)) found = c(found, "changed .Random.seed")
		cat(if (length(found)) "PROBLEM\n" else "ok\n")
		if (length(found)) problems <<- c(problems, paste0(label, ": ", found))
	}
	set.seed(20260925)
	# Load EDI's hard dependencies first, so their own load-time option defaults
	# are part of the baseline rather than attributed to EDI.
	deps = if (load_all) {
		desc = read.dcf(file.path(pkg_dir, "DESCRIPTION"), fields = c("Depends", "Imports"))
		trimws(sub("\\(.*", "", unlist(strsplit(paste(desc[!is.na(desc)], collapse = ","), ","))))
	} else {
		tools::package_dependencies("EDI", db = installed.packages(lib.loc = .libPaths()),
			which = c("Depends", "Imports"), recursive = TRUE)[["EDI"]]
	}
	if (load_all) deps = unique(c(deps, "pkgload", unlist(tools::package_dependencies(c(deps, "pkgload"),
		db = installed.packages(), which = c("Depends", "Imports"), recursive = TRUE))))
	deps = setdiff(deps[nzchar(deps)], c("R", "EDI"))
	for (d in c("methods", deps)) try(suppressPackageStartupMessages(loadNamespace(d)), silent = TRUE)
	if (load_all) {
		check("pkgload::load_all(compile = FALSE)", pkgload::load_all(pkg_dir, compile = FALSE, quiet = TRUE))
	} else {
		check("library(EDI)", suppressPackageStartupMessages(library(EDI)))
	}
	cat("  (EDI", format(packageVersion("EDI")), "from", dirname(find.package("EDI")), ")\n")
	check("toggle_asserts(FALSE); toggle_asserts(TRUE)", {toggle_asserts(FALSE); toggle_asserts(TRUE)})
	check("set_num_cores(2); unset_num_cores()", {set_num_cores(2); unset_num_cores()})
	sim = function(num_cores) SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff), n = 10, Nrep_W = 2, Nrep_Y_w = 1L,
		num_cores = num_cores, verbose = FALSE, seed = 1, continue_from_last_result_row = FALSE)
	check("SimulationFramework$new(seed = 1, num_cores = 1)$run()", sim(1L)$run())
	check("SimulationFramework$new(seed = 1, num_cores = 2)$run()", sim(2L)$run())
	# Random draws legitimately advance .Random.seed; only a seeded API must leave it alone.
	seq_des = DesignSeqOneByOneBernoulli$new(n = 20, response_type = "continuous")
	for (i in 1:20) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	seq_des$add_all_subject_responses(rnorm(20))
	output_dir = tempfile("edi_suite_")
	dir.create(output_dir)
	check("InferenceSuite$run_all_inference(num_cores = 2)",
		InferenceSuite$new(seq_des)$run_all_inference(screen = TRUE, plots = FALSE,
			classes = c("InferenceAllSimpleAverageDiff", "InferenceAllSimpleWilcox"),
			num_cores = 2L, output_dir = output_dir),
		check_seed = FALSE)
	unlink(output_dir, recursive = TRUE)
}

if (length(problems)) {
	cat("\nERROR: ", length(problems), " global-state problem(s) that CRAN will flag:\n", sep = "", file = stderr())
	cat(paste0("  - ", problems, "\n"), sep = "", file = stderr())
	quit(status = 1L)
}
cat("\nOK: no .GlobalEnv writes or unsafe `<<-` in R/",
	if (!static_only) ", and EDI's entry points leave options(), the working directory, .GlobalEnv and .Random.seed unchanged",
	"\n", sep = "")
