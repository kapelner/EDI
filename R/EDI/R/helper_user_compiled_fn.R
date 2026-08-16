# Uniform handling for user-supplied compiled C++ functions (the R half of
# src/user_compiled_fns.h). Every feature that accepts user C++ --
# DesignFixedOptimal's custom_objective and the custom randomization
# statistic's XPtr form -- routes through normalize_user_cpp_fn(), so the
# accepted inputs, the RcppXPtrUtils plumbing, the signature verification,
# and the R-closure refusal (with its performance reason) are identical
# everywhere. Non-exported.

# The package-wide calling conventions, mirroring src/user_compiled_fns.h.
EDI_USER_CPP_SIGNATURES = list(
	design_objective = list(args = c("const Eigen::MatrixXd&", "const Eigen::VectorXd&")),
	rand_stat        = list(args = c("const Eigen::VectorXd&", "const Eigen::VectorXd&")),
	rand_stat_dead   = list(args = c("const Eigen::VectorXd&", "const Eigen::VectorXd&", "const Eigen::VectorXd&"))
)

# Whitespace- and argument-name-insensitive comparison of the arg types an
# RcppXPtrUtils::cppXPtr() recorded against a convention from
# EDI_USER_CPP_SIGNATURES. RcppXPtrUtils::checkXPtr() compares verbatim
# strings, which is brittle to "Eigen::MatrixXd& X" vs "Eigen::MatrixXd &X"
# spacing; this does its own lenient check instead.
user_cpp_xptr_args_match = function(recorded_args, expected_args){
	if (length(recorded_args) != length(expected_args)) return(FALSE)
	strip = function(a){
		a = sub("[A-Za-z_][A-Za-z0-9_]*$", "", trimws(a))  # drop the trailing arg name
		gsub("[[:space:]]+", "", a)
	}
	all(vapply(recorded_args, strip, character(1)) == vapply(expected_args, strip, character(1)))
}

# Normalize a user's compiled C++ function into list(xptr, src). Accepted:
#  - an externalptr (from RcppXPtrUtils::cppXPtr(), or any mechanism yielding
#    an Rcpp::XPtr to a function pointer of the right signature; when
#    cppXPtr's signature attributes are present they are verified, a foreign
#    bare externalptr is trusted as documented),
#  - a single C++ source string, compiled here via RcppXPtrUtils::cppXPtr()
#    with the given `depends` (the source is retained so parallel workers can
#    recompile locally instead of dereferencing a serialized -- and therefore
#    dead -- pointer).
# A plain R function is refused with the performance reason (TODO-2 of
# design_fixed_optimal.md): these functions are evaluated once per candidate
# inside compiled hot loops, and an R-call round-trip per evaluation is
# orders of magnitude too slow to be a usable option, not merely a slower one.
# `r_function_hint` names the site's R-function alternative where one exists.
normalize_user_cpp_fn = function(x, what, signature_name, depends = "RcppEigen", r_function_hint = NULL){
	sig = EDI_USER_CPP_SIGNATURES[[signature_name]]
	if (is.null(sig)) stop(sprintf("Unknown user C++ signature convention '%s'.", signature_name))
	if (is.function(x)) {
		stop(sprintf(paste0(
			"%s must be compiled C++ (an RcppXPtrUtils::cppXPtr() external pointer or a C++ ",
			"source string), not an R function: it is evaluated once per candidate inside a ",
			"compiled hot loop, and an R-call round-trip per evaluation is orders of magnitude ",
			"too slow to be usable.%s"),
			what,
			if (is.null(r_function_hint)) "" else paste0(" ", r_function_hint)
		))
	}
	if (is.character(x)) {
		if (length(x) != 1L) stop(sprintf("%s: a C++ source input must be a single string.", what))
		if (!requireNamespace("RcppXPtrUtils", quietly = TRUE)) {
			stop(sprintf("Package 'RcppXPtrUtils' is required to compile %s from source; please install it.", what))
		}
		xptr = RcppXPtrUtils::cppXPtr(code = x, depends = depends)
		recorded = attr(xptr, "args")
		if (!is.null(recorded) && !user_cpp_xptr_args_match(recorded, sig$args)) {
			stop(sprintf(
				"%s has signature (%s) but the required calling convention is (%s); see user_compiled_fns.h.",
				what, paste(recorded, collapse = ", "), paste(sig$args, collapse = ", ")
			))
		}
		return(list(xptr = xptr, src = x))
	}
	if (typeof(x) == "externalptr") {
		recorded = attr(x, "args")
		if (!is.null(recorded) && !user_cpp_xptr_args_match(recorded, sig$args)) {
			stop(sprintf(
				"%s has signature (%s) but the required calling convention is (%s); see user_compiled_fns.h.",
				what, paste(recorded, collapse = ", "), paste(sig$args, collapse = ", ")
			))
		}
		return(list(xptr = x, src = NULL))
	}
	stop(sprintf(
		"%s must be an RcppXPtrUtils::cppXPtr() external pointer or a single C++ source string (got a %s).",
		what, class(x)[1L]
	))
}

# DesignFixedOptimal's custom_objective entry point (design_fixed_optimal.md
# TODO-7): validate-only wrapper around the shared normalizer.
assert_custom_objective_xptr = function(custom_objective){
	if (is.null(custom_objective)) {
		stop('custom_objective is required when objective = "custom" (an RcppXPtrUtils::cppXPtr() external pointer or a C++ source string).')
	}
	invisible(normalize_user_cpp_fn(custom_objective, "custom_objective", "design_objective"))
}
