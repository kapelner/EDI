# Source-level support for the inference-component dependency audit (TODO-97).
# This intentionally lives with the test tooling: production dispatch remains
# unchanged, while the graph is derived from parsed checkout sources and the
# already-created R6 generators.

inference_component_source_ast_index <- function(source_root) {
	files <- list.files(source_root, pattern = "\\.R$", full.names = TRUE)
	index <- list()
	for (path in files) {
		exprs <- tryCatch(parse(path, keep.source = TRUE), error = function(e) {
			stop("Could not parse inference source ", path, ": ", conditionMessage(e), call. = FALSE)
		})
		for (expr in exprs) {
			if (!is.call(expr) || !is.symbol(expr[[1L]])) next
			operator <- as.character(expr[[1L]])
			if (!(operator %in% c("<-", "=", "assign"))) next
			if (identical(operator, "assign")) next
			lhs <- expr[[2L]]
			if (!is.symbol(lhs)) next
			class_name <- as.character(lhs)
			rhs <- expr[[3L]]
			if (!is.call(rhs)) next
			fun <- rhs[[1L]]
			fun_name <- if (is.symbol(fun)) as.character(fun) else if (
				is.call(fun) && length(fun) >= 3L && identical(as.character(fun[[1L]]), "::")
			) as.character(fun[[3L]]) else ""
			if (fun_name %in% c("define_inference_class", "R6Class")) {
				index[[class_name]] <- list(path = normalizePath(path), call = rhs)
			}
		}
	}
	index
}

inference_component_literal_string_vector <- function(expr, context) {
	if (is.null(expr)) return(character())
	if (is.character(expr)) return(expr)
	if (is.call(expr) && identical(as.character(expr[[1L]]), "c")) {
		args <- as.list(expr)[-1L]
		if (length(args) == 0L) return(character())
		ok <- vapply(args, is.character, logical(1L))
		if (!all(ok) || any(lengths(args) != 1L)) {
			stop(context, " has a non-literal components= expression: ",
				paste(deparse(expr), collapse = ""), call. = FALSE)
		}
		return(unname(vapply(args, `[[`, character(1L), 1L)))
	}
	stop(context, " has a non-literal components= expression: ",
		paste(deparse(expr), collapse = ""), call. = FALSE)
}

inference_component_call_argument <- function(call, name) {
	args <- as.list(call)[-1L]
	arg_names <- names(args)
	if (is.null(arg_names)) return(NULL)
	hit <- which(!is.na(arg_names) & arg_names == name)
	if (length(hit) == 0L) NULL else args[[hit[[1L]]]]
}

inference_component_source_order <- function(source_ast, class_name) {
	entry <- source_ast[[class_name]]
	if (is.null(entry)) stop("No parsed class definition for ", class_name, call. = FALSE)
	components_expr <- inference_component_call_argument(entry$call, "components")
	inference_component_literal_string_vector(components_expr, class_name)
}

inference_component_method_refs <- function(fn) {
	refs <- list()
	walk <- function(node, call_head = FALSE) {
		if (!is.call(node) && !is.expression(node)) return(invisible(NULL))
		if (is.call(node) && is.call(node[[1L]]) && length(node[[1L]]) >= 3L &&
				identical(as.character(node[[1L]][[1L]]), "$") &&
				is.symbol(node[[1L]][[2L]]) && is.symbol(node[[1L]][[3L]])) {
			receiver <- as.character(node[[1L]][[2L]])
			if (receiver %in% c("self", "private", "super")) {
				refs[[length(refs) + 1L]] <<- list(receiver = receiver, method = as.character(node[[1L]][[3L]]))
			}
		}
		for (i in seq_along(node)) walk(node[[i]])
		invisible(NULL)
	}
	walk(body(fn))
	refs
}

inference_component_same_function <- function(a, b) {
	is.function(a) && is.function(b) && identical(a, b)
}

inference_component_graph_surface <- function(ns, class_names) {
	rows <- lapply(class_names, function(class_name) {
		meta <- get("get_inference_class_metadata", envir = ns)(class_name)
		if (!identical(meta$abstract, FALSE)) return(NULL)
		generator <- get(class_name, envir = ns, inherits = FALSE)
		public <- private <- character()
		current <- generator
		while (!is.null(current)) {
			owner <- current$classname
			public <- c(public, paste0(names(current$public_methods) %||% character(), "@", owner))
			private <- c(private, paste0(names(current$private_methods) %||% character(), "@", owner))
			current <- current$get_inherit()
		}
		data.frame(
			class = class_name,
			components = paste(get("get_effective_components", envir = ns)(class_name), collapse = "|"),
			public_methods = paste(sort(unique(public)), collapse = "|"),
			private_methods = paste(sort(unique(private)), collapse = "|"),
			stringsAsFactors = FALSE
		)
	})
	rows <- Filter(Negate(is.null), rows)
	out <- do.call(rbind, rows)
	rownames(out) <- NULL
	out
}

inference_component_call_graph <- function(source_root, ns = asNamespace("EDI")) {
	get_ns <- function(name) get(name, envir = ns, inherits = FALSE)
	source_ast <- inference_component_source_ast_index(source_root)
	get_ns("populate_inference_component_registry")()
	components <- get_ns("EDI_INFERENCE_COMPONENTS")
	component_names <- ls(components, all.names = TRUE)
	component_specs <- get_ns("EDI_COMPONENT_SPECS")
	component_methods <- lapply(component_names, function(name) {
		spec <- component_specs[[name]]
		source_name <- spec$source_name %||% name
		source <- get(source_name, envir = ns, inherits = TRUE)
		parts <- get_ns("inference_component_source_parts")(source)
		list(
			public = parts$public,
			private = parts$private,
			dependencies = spec$dependencies %||% character()
		)
	})
	names(component_methods) <- component_names
	component_method_index <- do.call(rbind, lapply(component_names, function(name) {
		do.call(rbind, lapply(c("public", "private"), function(slot) {
			method_names <- names(component_methods[[name]][[slot]]) %||% character()
			if (length(method_names) == 0L) return(NULL)
			data.frame(
				component = name, visibility = slot, method = method_names,
				stringsAsFactors = FALSE
			)
		}))
	}))
	if (is.null(component_method_index)) {
		component_method_index <- data.frame(
			component = character(), visibility = character(), method = character(),
			stringsAsFactors = FALSE
		)
	}
	class_names <- sort(names(get_ns("inference_class_registry_as_list")()))
	concrete <- class_names[vapply(class_names, function(name) {
		identical(get_ns("get_inference_class_metadata")(name)$abstract, FALSE)
	}, logical(1L))]
	parse_components <- function(class_name) {
		if (is.null(source_ast[[class_name]])) return(character())
		inference_component_source_order(source_ast, class_name)
	}
	component_closure_cache <- new.env(parent = emptyenv())
	component_closure <- function(direct) {
		if (length(direct) == 0L) return(character())
		key <- paste(direct, collapse = "\r")
		if (!exists(key, envir = component_closure_cache, inherits = FALSE)) {
			assign(key, get_ns("resolve_component_dependencies")(direct), envir = component_closure_cache)
		}
		get(key, envir = component_closure_cache, inherits = FALSE)
	}
	method_origin <- function(fn, candidates, owner, method_name) {
		lazy_component <- attr(fn, "inference_lazy_component_stub", exact = TRUE)
		if (!is.null(lazy_component) && lazy_component %in% candidates &&
				(method_name %in% names(component_methods[[lazy_component]]$public) ||
					method_name %in% names(component_methods[[lazy_component]]$private))) {
			return(lazy_component)
		}
		matches <- character()
		for (component_name in candidates) {
			for (slot in c("public", "private")) {
				methods <- component_methods[[component_name]][[slot]]
				if (length(methods) == 0L || !(method_name %in% names(methods))) next
				if (inference_component_same_function(fn, methods[[method_name]])) {
					matches <- c(matches, component_name)
				}
			}
		}
		if (length(matches) > 0L) return(matches[[1L]])
		if (identical(owner, "Inference")) "<root>" else paste0("<host>", owner)
	}
	method_body <- function(fn, origin, method_name, slot) {
		if (origin %in% names(component_methods) &&
				!is.null(attr(fn, "inference_lazy_component_stub", exact = TRUE))) {
			return(component_methods[[origin]][[slot]][[method_name]])
		}
		fn
	}
	methods_for <- function(generator) {
		out <- list()
		for (slot in c("public", "private")) {
			methods <- if (slot == "public") generator$public_methods else generator$private_methods
			if (length(methods) == 0L) next
			for (name in names(methods)) {
				if (is.function(methods[[name]])) out[[paste(slot, name, sep = "::")]] <- methods[[name]]
			}
		}
		out
	}
	lookup_in_chain <- function(generator, key) {
		current <- generator
		while (!is.null(current)) {
			methods <- methods_for(current)
			if (!is.null(methods[[key]])) return(list(fn = methods[[key]], owner = current$classname))
			current <- current$get_inherit()
		}
		NULL
	}
	rows <- list()
	calls <- list()
	edges <- list()
	class_component_rows <- list()
	method_ref_cache <- new.env(parent = emptyenv())
	for (class_name in concrete) {
		if (is.null(source_ast[[class_name]])) {
			stop("Concrete inference class has no parsed definition: ", class_name, call. = FALSE)
		}
		generator <- get(class_name, envir = ns, inherits = FALSE)
		chain <- list()
		current <- generator
		while (!is.null(current)) {
			chain[[length(chain) + 1L]] <- current
			current <- current$get_inherit()
		}
		# Component methods are merged in literal order inside each class; R6
		# inheritance then overlays child methods on their actual parent chain.
		dispatch <- list()
		origins <- list()
		for (layer in rev(chain)) {
			owner <- layer$classname
			direct_components <- parse_components(owner)
			class_component_rows[[owner]] <- direct_components
			layer_methods <- methods_for(layer)
			layer_candidates <- component_closure(direct_components)
			for (key in names(layer_methods)) {
				fn <- layer_methods[[key]]
				dispatch[[key]] <- list(fn = fn, owner = owner)
				method_name <- sub("^[^:]+::", "", key)
				origins[[key]] <- method_origin(fn, layer_candidates, owner, method_name)
			}
		}
		for (key in names(dispatch)) {
			parts <- strsplit(key, "::", fixed = TRUE)[[1L]]
			slot <- parts[[1L]]
			method <- parts[[2L]]
			from <- origins[[key]]
			ref_key <- paste(dispatch[[key]]$owner, key, sep = "\r")
			if (!exists(ref_key, envir = method_ref_cache, inherits = FALSE)) {
				body_fn <- method_body(dispatch[[key]]$fn, from, method, slot)
				assign(ref_key, inference_component_method_refs(body_fn), envir = method_ref_cache)
			}
			refs <- get(ref_key, envir = method_ref_cache, inherits = FALSE)
			# Host bodies do not contribute graph edges. Retain their `super$`
			# calls in the resolution table so the R6 parent-chain rule is testable
			# on raw-R6 leaves without scanning unrelated host self/private calls.
			if (grepl("^<host>", from)) {
				refs <- Filter(function(ref) identical(ref$receiver, "super"), refs)
			}
			for (ref in refs) {
				target_slot <- if (identical(ref$receiver, "private")) "private" else "public"
				target_key <- paste(target_slot, ref$method, sep = "::")
				resolved <- if (identical(ref$receiver, "super")) {
					owner_gen <- get(dispatch[[key]]$owner, envir = ns, inherits = FALSE)
					parent <- owner_gen$get_inherit()
					if (is.null(parent)) NULL else lookup_in_chain(parent, target_key)
				} else dispatch[[target_key]]
				target_origin <- if (is.null(resolved)) {
					NA_character_
				} else if (identical(ref$receiver, "super")) {
					method_origin(
						resolved$fn,
						component_closure(parse_components(resolved$owner)),
						resolved$owner,
						ref$method
					)
				} else origins[[target_key]] %||% NA_character_
				calls[[length(calls) + 1L]] <- data.frame(
					class = class_name, dispatch_owner = dispatch[[key]]$owner,
					body_origin = from, method = method,
					receiver = ref$receiver, target_method = ref$method,
					target_owner = if (is.null(resolved)) NA_character_ else resolved$owner,
					target_origin = target_origin,
					stringsAsFactors = FALSE
				)
				if (!grepl("^<", from) && !is.na(target_origin) &&
						!grepl("^<", target_origin)) {
					edges[[length(edges) + 1L]] <- data.frame(
						class = class_name, from = from, to = target_origin,
						method = method, target_method = ref$method,
						receiver = ref$receiver, stringsAsFactors = FALSE
					)
				}
			}
			rows[[length(rows) + 1L]] <- data.frame(
				class = class_name, method = method, visibility = slot,
				dispatch_owner = dispatch[[key]]$owner, body_origin = from,
				stringsAsFactors = FALSE
			)
		}
	}
	list(
		class_components = class_component_rows,
		component_sources = data.frame(
			component = component_names,
			source_name = vapply(component_names, function(name) {
				component_specs[[name]]$source_name %||% name
			}, character(1L)),
			stringsAsFactors = FALSE
		),
		component_methods = component_method_index,
		methods = if (length(rows)) do.call(rbind, rows) else data.frame(),
		calls = if (length(calls)) unique(do.call(rbind, calls)) else data.frame(),
		edges = if (length(edges)) unique(do.call(rbind, edges)) else data.frame(),
		surface = inference_component_graph_surface(ns, concrete),
		classes = concrete
	)
}
