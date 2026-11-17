# Parser for the test-suite-health audit (.github/scripts/audits/test_suite_health.py).
#
#   Rscript test_suite_health.R OUT.json FILE...
#
# Only parses: it never loads EDI or testthat and never runs a test. For every file it writes
#   tests      each test_that() call: line, description, the functions it calls and the plain
#              symbols it uses (a function can be passed by name: lapply(x, check))
#   functions  each `name = function(...)` / `name <- function(...)`: name, calls and symbols
#   skips      each skip*() call: line, function, call text, enclosing test_that() line (NA at
#              file level), and whether every expression between the skip and that test_that()
#              (or the file) is a plain `{` block, i.e. nothing can stop it from running
#   error      the parse error, if the file does not parse
# Needs jsonlite (installed by the audit workflow's setup-r-dependencies step).

args = commandArgs(trailingOnly = TRUE)
out_path = args[[1]]
files = args[-1]

skip_fns = c("skip", "skip_if", "skip_if_not", "skip_if_not_installed", "skip_if_offline",
	"skip_on_cran", "skip_on_ci", "skip_on_covr", "skip_on_os", "skip_on_bioc", "skip_on_travis",
	"skip_on_appveyor", "skip_if_translated", "skip_unless_r", "skip_on_fork")

# Terminal tokens inside [l1:c1, l2:c2] (inclusive), in source order.
in_span = function(pd, l1, c1, l2, c2) {
	(pd$line1 > l1 | (pd$line1 == l1 & pd$col1 >= c1)) & (pd$line2 < l2 | (pd$line2 == l2 & pd$col2 <= c2))
}

# Functions called in the span, and plain symbols (a function passed by name, as in lapply(x, check)).
calls_in = function(pd, span) sort(unique(pd[span & pd$token == "SYMBOL_FUNCTION_CALL", "text"]))
symbols_in = function(pd, span) sort(unique(pd[span & pd$token == "SYMBOL", "text"]))

analyse = function(path) {
	exprs = tryCatch(parse(path, keep.source = TRUE), error = function(e) e)
	if (inherits(exprs, "error")) return(list(file = path, error = conditionMessage(exprs)))
	pd = utils::getParseData(exprs, includeText = TRUE)
	if (is.null(pd) || !nrow(pd)) return(list(file = path, tests = list(), functions = list(), skips = list()))
	pd = pd[order(pd$line1, pd$col1, -pd$line2, -pd$col2), ]
	row_of = setNames(seq_len(nrow(pd)), pd$id)
	parent_row = function(r) {
		p = pd$parent[r]
		if (p <= 0 || is.na(row_of[as.character(p)])) NA_integer_ else row_of[[as.character(p)]]
	}
	children = function(r) which(pd$parent == pd$id[r])
	# The call expression a SYMBOL_FUNCTION_CALL token names: token -> expr(name) -> expr(call).
	call_row = function(r) {
		a = parent_row(r)
		if (is.na(a)) NA_integer_ else parent_row(a)
	}

	calls = which(pd$token == "SYMBOL_FUNCTION_CALL")
	test_rows = calls[pd$text[calls] == "test_that"]
	tests = lapply(test_rows, function(r) {
		cr = call_row(r)
		if (is.na(cr)) return(NULL)
		span = in_span(pd, pd$line1[cr], pd$col1[cr], pd$line2[cr], pd$col2[cr])
		strs = pd[span & pd$token == "STR_CONST", "text"]
		list(line = pd$line1[cr], end = pd$line2[cr],
			desc = if (length(strs)) substr(strs[[1]], 1, 200) else "",
			calls = calls_in(pd, span), symbols = symbols_in(pd, span))
	})
	tests = Filter(Negate(is.null), tests)
	test_spans = do.call(rbind, lapply(test_rows, function(r) {
		cr = call_row(r)
		if (is.na(cr)) NULL else data.frame(row = cr, l1 = pd$line1[cr], c1 = pd$col1[cr], l2 = pd$line2[cr], c2 = pd$col2[cr])
	}))

	fun_rows = which(pd$token == "FUNCTION")
	functions = lapply(fun_rows, function(r) {
		fe = parent_row(r)                       # expr: function(...) body
		if (is.na(fe)) return(NULL)
		asg = parent_row(fe)                     # expr: name = function(...)
		if (is.na(asg)) return(NULL)
		kids = children(asg)
		if (!any(pd$token[kids] %in% c("EQ_ASSIGN", "LEFT_ASSIGN"))) return(NULL)
		lhs = kids[pd$token[kids] == "expr"][1]
		if (is.na(lhs)) return(NULL)
		sym = children(lhs)
		sym = sym[pd$token[sym] %in% c("SYMBOL", "STR_CONST")]
		if (!length(sym)) return(NULL)
		span = in_span(pd, pd$line1[fe], pd$col1[fe], pd$line2[fe], pd$col2[fe])
		list(name = gsub("^[\"'`]|[\"'`]$", "", pd$text[sym[1]]), line = pd$line1[fe],
			calls = calls_in(pd, span), symbols = symbols_in(pd, span))
	})
	functions = Filter(Negate(is.null), functions)

	skip_rows = calls[pd$text[calls] %in% skip_fns]
	skips = lapply(skip_rows, function(r) {
		cr = call_row(r)
		if (is.na(cr)) return(NULL)
		enclosing = NA_integer_
		if (!is.null(test_spans) && nrow(test_spans)) {
			inside = (test_spans$l1 < pd$line1[cr] | (test_spans$l1 == pd$line1[cr] & test_spans$c1 <= pd$col1[cr])) &
				(test_spans$l2 > pd$line2[cr] | (test_spans$l2 == pd$line2[cr] & test_spans$c2 >= pd$col2[cr]))
			if (any(inside)) {
				cand = test_spans[inside, ]
				enclosing = cand$row[which.max(cand$l1 * 1e6 + cand$c1)]
			}
		}
		# Walk up from the call. Unconditional: every expression between it and the enclosing
		# test_that() call (its body argument) or the top level is a `{` block.
		unconditional = TRUE
		a = parent_row(cr)
		while (!is.na(a)) {
			if (!is.na(enclosing) && a == enclosing) break
			kid_tokens = pd$token[children(a)]
			if (!identical(kid_tokens[1], "'{'")) {
				unconditional = FALSE
				break
			}
			a = parent_row(a)
		}
		list(line = pd$line1[cr], fn = pd$text[r], text = substr(gsub("\\s+", " ", pd$text[cr]), 1, 300),
			test_line = if (is.na(enclosing)) NULL else pd$line1[enclosing], unconditional = unconditional)
	})
	skips = Filter(Negate(is.null), skips)
	list(file = path, tests = tests, functions = functions, skips = skips)
}

res = lapply(files, analyse)
jsonlite::write_json(res, out_path, auto_unbox = TRUE, null = "null", pretty = FALSE)
