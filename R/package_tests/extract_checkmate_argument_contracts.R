#!/usr/bin/env Rscript

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/extract_checkmate_argument_contracts.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

supported_assertions = c(
	"assertChoice",
	"assertSubset",
	"assertNumeric",
	"assertIntegerish",
	"assertCount",
	"assertFlag",
	"assertLogical",
	"assertString",
	"assertFormula",
	"assertList",
	"assertClass",
	"assertDataFrame",
	"assertMatrix",
	"assertResponseType",
	"assertNoCensoring"
)

load_edi_namespace = function() {
	if (requireNamespace("pkgload", quietly = TRUE)) {
		# Already loaded from source by an earlier generator in run_drift_generators.R's
		# single process: reuse it instead of a second ~5.5 s load_all.
		if (!(isNamespaceLoaded("EDI") && pkgload::is_dev_package("EDI"))) pkgload::load_all(file.path(repo_root, "EDI"), quiet = TRUE, export_all = FALSE, compile = FALSE)
	} else {
		stop("Package 'pkgload' is required for checkmate contract extraction.", call. = FALSE)
	}
	asNamespace("EDI")
}

safe_deparse = function(x) {
	if (missing(x) || is.null(x)) return("")
	paste(deparse(x, width.cutoff = 500L), collapse = "\n")
}

collapse_chr = function(x) {
	x = unique(as.character(x))
	x = x[nzchar(x)]
	if (length(x) == 0L) "" else paste(x, collapse = ";")
}

is_r6_generator = function(x) {
	inherits(x, "R6ClassGenerator")
}

call_name = function(expr) {
	if (!is.call(expr)) return("")
	head = expr[[1L]]
	if (is.symbol(head)) return(as.character(head))
	if (is.call(head) && identical(as.character(head[[1L]]), "::")) {
		return(as.character(head[[3L]]))
	}
	if (is.call(head) && identical(as.character(head[[1L]]), ":::")) {
		return(as.character(head[[3L]]))
	}
	""
}

is_should_run_asserts_call = function(expr) {
	is.call(expr) && identical(call_name(expr), "should_run_asserts")
}

condition_uses_should_run_asserts = function(expr) {
	if (is_should_run_asserts_call(expr)) return(TRUE)
	if (!is.call(expr)) return(FALSE)
	any(vapply(as.list(expr), condition_uses_should_run_asserts, logical(1)))
}

literal_value = function(expr) {
	if (missing(expr) || is.null(expr)) return(NULL)
	out = tryCatch(
		eval(expr, envir = baseenv()),
		error = function(e) NULL
	)
	if (is.atomic(out) || is.null(out)) out else NULL
}

literal_string = function(expr) {
	val = literal_value(expr)
	if (is.null(val)) return("")
	if (length(val) == 0L) return("")
	paste(as.character(val), collapse = ";")
}

literal_scalar = function(expr) {
	val = literal_value(expr)
	if (is.null(val) || length(val) != 1L || is.na(val)) return("")
	as.character(val)
}

source_location = function(expr, fn) {
	sr = attr(expr, "srcref", exact = TRUE)
	if (is.null(sr)) sr = attr(fn, "srcref", exact = TRUE)
	if (is.null(sr)) {
		return(list(file = "", line = NA_integer_))
	}
	srcfile = attr(sr, "srcfile", exact = TRUE)
	file = if (!is.null(srcfile) && !is.null(srcfile$filename)) srcfile$filename else ""
	file = sub(paste0("^", repo_root, "/?"), "", file)
	line = suppressWarnings(as.integer(sr[1L]))
	list(file = file, line = line)
}

formal_default = function(fn, arg) {
	if (!is.function(fn) || !nzchar(arg)) return("")
	fmls = formals(fn)
	if (!(arg %in% names(fmls))) return("")
	if (identical(fmls[[arg]], quote(expr = ))) return("<missing>")
	value = fmls[[arg]]
	safe_deparse(value)
}

simple_arg_name = function(expr) {
	if (missing(expr) || is.null(expr)) return("")
	if (is.symbol(expr)) return(as.character(expr))
	safe_deparse(expr)
}

get_call_arg = function(args, arg_names, name, position = NULL) {
	if (!is.null(name) && name %in% arg_names) return(args[[which(arg_names == name)[1L]]])
	if (!is.null(position) && length(args) >= position) return(args[[position]])
	NULL
}

extract_contract_from_call = function(expr, fn, api_meta, inside_assert_block) {
	assertion = call_name(expr)
	args = as.list(expr)[-1L]
	if (length(args)) {
		args = Filter(function(x) !identical(x, quote(expr = )), args)
	}
	arg_names = names(args) %||% rep("", length(args))
	arg_names[is.na(arg_names)] = ""
	target_expr = get_call_arg(args, arg_names, NULL, 1L)
	target_arg = simple_arg_name(target_expr)
	# An assertion on an expression (e.g. assertCount(as.integer(max_expansions))) constrains
	# the one formal it reads; record that formal, or nothing when it reads none or several.
	if (!is.symbol(target_expr) && is.function(fn)) {
		used = intersect(all.names(target_expr), names(formals(fn)))
		if (length(used) != 1L) return(NULL)
		target_arg = used
	}
	
	choices_expr = switch(
		assertion,
		assertChoice = get_call_arg(args, arg_names, "choices", 2L),
		assertSubset = get_call_arg(args, arg_names, "choices", NULL),
		assertClass = get_call_arg(args, arg_names, "classes", 2L),
		assertResponseType = get_call_arg(args, arg_names, NULL, 2L),
		NULL
	)
	loc = source_location(expr, fn)
	data.frame(
		api_name = api_meta$api_name,
		api_kind = api_meta$api_kind,
		class_name = api_meta$class_name,
		method_name = api_meta$method_name,
		arg = target_arg,
		default_expr = formal_default(fn, target_arg),
		assertion = assertion,
		choices = literal_string(choices_expr),
		lower = literal_scalar(get_call_arg(args, arg_names, "lower", NULL)),
		upper = literal_scalar(get_call_arg(args, arg_names, "upper", NULL)),
		len = literal_scalar(get_call_arg(args, arg_names, "len", NULL)),
		min_len = literal_scalar(get_call_arg(args, arg_names, "min.len", NULL)),
		max_len = literal_scalar(get_call_arg(args, arg_names, "max.len", NULL)),
		positive = literal_scalar(get_call_arg(args, arg_names, "positive", NULL)),
		null_ok = literal_scalar(get_call_arg(args, arg_names, "null.ok", NULL)),
		any_missing = literal_scalar(get_call_arg(args, arg_names, "any.missing", NULL)),
		source_file = loc$file,
		source_line = loc$line,
		coverage_scope = api_meta$coverage_scope,
		inside_should_run_asserts = isTRUE(inside_assert_block),
		stringsAsFactors = FALSE
	)
}

walk_assertion_calls = function(expr, fn, api_meta, inside_assert_block = FALSE) {
	rows = list()
	if (!is.call(expr)) return(rows)
	nm = call_name(expr)
	if (identical(nm, "if") && length(expr) >= 3L) {
		condition = expr[[2L]]
		then_inside = inside_assert_block || condition_uses_should_run_asserts(condition)
		rows = c(rows, walk_assertion_calls(expr[[3L]], fn, api_meta, then_inside))
		if (length(expr) >= 4L) {
			rows = c(rows, walk_assertion_calls(expr[[4L]], fn, api_meta, inside_assert_block))
		}
		return(rows)
	}
	if (nm %in% supported_assertions) {
		row = extract_contract_from_call(expr, fn, api_meta, inside_assert_block)
		if (!is.null(row)) rows[[length(rows) + 1L]] = row
	}
	# EDI's assertBootstrapArgs() (EDI/R/helper_additional_asserts.R) wraps checkmate:
	# assertCount(B), assertCount(min_number_usable_samples) and, given allowed_types,
	# assertChoice(type, allowed_types). Record those contracts at the call site.
	if (identical(nm, "assertBootstrapArgs")) {
		a = as.list(expr)[-1L]
		an = names(a) %||% rep("", length(a))
		pick = function(name, pos) get_call_arg(a, an, name, if (all(an[seq_len(min(pos, length(an)))] == "")) pos else NULL)
		emit = function(call) {
			attr(call, "srcref") = attr(expr, "srcref", exact = TRUE)
			row = extract_contract_from_call(call, fn, api_meta, TRUE)
			if (!is.null(row)) rows[[length(rows) + 1L]] <<- row
		}
		b = pick("B", 1L)
		if (!is.null(b)) emit(as.call(list(as.name("assertCount"), b, positive = TRUE)))
		m = pick("min_number_usable_samples", 2L)
		if (!is.null(m)) emit(as.call(list(as.name("assertCount"), m, positive = TRUE)))
		ty = pick("type", 3L); at = pick("allowed_types", 4L)
		if (!is.null(ty) && !is.null(at)) emit(as.call(list(as.name("assertChoice"), ty, choices = at)))
	}
	# EDI's assert_min_fraction_usable_samples(x) (EDI/R/inference_all_abstract_non_param_boot.R,
	# v1.0.6-TODO-12) is checkmate::assertNumber(x, lower = 0, upper = 1, finite = TRUE): a
	# finite scalar in [0, 1], recorded as the equivalent assertNumeric contract.
	if (identical(nm, "assert_min_fraction_usable_samples") && length(expr) >= 2L) {
		call = as.call(list(as.name("assertNumeric"), expr[[2L]], len = 1L, lower = 0, upper = 1, any.missing = FALSE))
		attr(call, "srcref") = attr(expr, "srcref", exact = TRUE)
		row = extract_contract_from_call(call, fn, api_meta, inside_assert_block)
		if (!is.null(row)) rows[[length(rows) + 1L]] = row
	}
	children = as.list(expr)
	if (length(children) > 1L) {
		for (idx in 2L:length(children)) {
			if (identical(children[[idx]], quote(expr = ))) next
			child = tryCatch(children[[idx]], error = function(e) NULL)
			if (is.null(child)) next
			rows = c(rows, walk_assertion_calls(child, fn, api_meta, inside_assert_block))
		}
	}
	rows
}

parse_source_files = function() {
	files = list.files(file.path(repo_root, "EDI", "R"), pattern = "[.]R$", full.names = TRUE)
	ok = vapply(files, function(path) {
		!inherits(try(parse(path, keep.source = TRUE), silent = TRUE), "try-error")
	}, logical(1))
	message("Parsed ", sum(ok), " of ", length(files), " R source files with keep.source=TRUE.")
	invisible(files[ok])
}

find_r6_method = function(generator, method_name, origin_class = "") {
	current = generator
	while (!is.null(current)) {
		methods = current$public_methods %||% list()
		if (method_name %in% names(methods) &&
			(!nzchar(origin_class) || identical(current$classname, origin_class))) {
			return(methods[[method_name]])
		}
		current = current$get_inherit()
	}
	current = generator
	while (!is.null(current)) {
		methods = current$public_methods %||% list()
		if (method_name %in% names(methods)) return(methods[[method_name]])
		current = current$get_inherit()
	}
	NULL
}

function_for_inventory_row = function(row, ns) {
	if (identical(row$api_kind, "function")) {
		obj = get(row$export_name, envir = ns)
		if (is.function(obj) && !is_r6_generator(obj)) return(obj)
		return(NULL)
	}
	if (identical(row$api_kind, "r6_public_method")) {
		gen = get(row$export_name, envir = ns)
		if (!is_r6_generator(gen)) return(NULL)
		fn = find_r6_method(gen, row$method_name, row$method_origin_class)
		# Lazy-component stubs (`function(...)`, install_lazy_inference_component in
		# EDI/R/contracts_mixins.R) hold no assertions: read the real component method.
		component = if (is.function(fn)) attr(fn, "inference_lazy_component_stub", exact = TRUE) else NULL
		if (!is.null(component)) {
			dispatch = tryCatch(get("get_lazy_component_dispatch", envir = ns)(component, gen$classname), error = function(e) NULL)
			if (is.function(dispatch$public[[row$method_name]])) fn = dispatch$public[[row$method_name]]
		}
		return(fn)
	}
	NULL
}

api_meta_for_row = function(row) {
	list(
		api_name = row$export_name,
		api_kind = row$api_kind,
		class_name = row$class_name,
		method_name = row$method_name,
		coverage_scope = "public_contract"
	)
}

main = function() {
	parse_source_files()
	ns = load_edi_namespace()
	inventory_path = file.path(repo_root, "package_tests", "public_api_inventory.csv")
	if (!file.exists(inventory_path)) {
		stop("Missing package_tests/public_api_inventory.csv. Run Phase 0 first.", call. = FALSE)
	}
	inventory = read_csv_fast(inventory_path, stringsAsFactors = FALSE)
	inventory = inventory[inventory$api_kind %in% c("function", "r6_public_method"), , drop = FALSE]
	message("Scanning ", nrow(inventory), " public function/method inventory rows.")
	
	rows = list()
	for (i in seq_len(nrow(inventory))) {
		row = inventory[i, , drop = FALSE]
		fn = function_for_inventory_row(row, ns)
		if (!is.function(fn)) next
		found = walk_assertion_calls(body(fn), fn, api_meta_for_row(row))
		if (length(found)) rows = c(rows, found)
	}
	
	if (length(rows)) {
		contracts = do.call(rbind, rows)
		contracts = unique(contracts)
		contracts = contracts[order(
			contracts$api_name,
			contracts$api_kind,
			contracts$method_name,
			contracts$source_file,
			contracts$source_line,
			contracts$assertion,
			contracts$arg
		), ]
		row.names(contracts) = NULL
	} else {
		contracts = data.frame(
			api_name = character(),
			api_kind = character(),
			class_name = character(),
			method_name = character(),
			arg = character(),
			default_expr = character(),
			assertion = character(),
			choices = character(),
			lower = character(),
			upper = character(),
			len = character(),
			min_len = character(),
			max_len = character(),
			positive = character(),
			null_ok = character(),
			any_missing = character(),
			source_file = character(),
			source_line = integer(),
			coverage_scope = character(),
			inside_should_run_asserts = logical(),
			stringsAsFactors = FALSE
		)
	}
	
	write.csv(contracts, file.path(repo_root, "package_tests", "checkmate_argument_contracts.csv"), row.names = FALSE)
	message("Wrote ", nrow(contracts), " checkmate/custom assertion contract rows.")
}

main()
