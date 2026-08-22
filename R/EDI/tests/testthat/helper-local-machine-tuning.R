# Shared test utilities for local_machine_optimization.md's test files
# (test-local-machine-tuning-assembly.R, test-local-machine-tuning-correctness.R).
# In a helper-*.R file (rather than defined inside one test file) so both can use
# them regardless of testthat's per-file sourcing.

ns = asNamespace("EDI")

with_tuning_sandbox = function(code) {
	dir = file.path(tempfile("edi-tuning-"), "config")
	# Assign INTO the environment object, not via `ns$edi_env$x = v` -- that form
	# parses as a replacement on `ns$edi_env` and tries to rebind the locked symbol.
	ee = get("edi_env", envir = ns)
	old_override = ee$tuning_config_dir_override
	ee$tuning_config_dir_override = dir
	# Reset on ENTRY too: once .onLoad() imports a real saved tuning (TODO-9), a
	# developer machine with a real config file would otherwise start these tests
	# from non-shipped policies.
	set_cold_start_dispatch_policy(reset = TRUE)
	set_warm_start_dispatch_policy(reset = TRUE)
	set_optimization_dispatch_policy(reset = TRUE)
	# The TODO-7 contention guard is a real check on the real machine -- and CI /
	# dev boxes are often genuinely busy (it fired for real during development, on
	# a 12-core box at load 7). Every sandboxed test here benchmarks via stubs, so
	# contention is irrelevant to them: stub the guard to "idle" by default. The
	# TODO-7 tests override this stub explicitly to exercise the busy path.
	orig_busy = get("edi_tuning_machine_looks_busy", envir = ns)
	unlockBinding("edi_tuning_machine_looks_busy", ns)
	assign("edi_tuning_machine_looks_busy", function(...) list(busy = FALSE, load_1min = 0, cores = 1L, load_ratio = 0, calib_cv = 0, reasons = character(0)), envir = ns)
	on.exit({
		# An inner with_stub() on the same name re-locks the binding on its own exit,
		# so unlock again before restoring (lockBinding/unlockBinding are idempotent).
		unlockBinding("edi_tuning_machine_looks_busy", ns)
		assign("edi_tuning_machine_looks_busy", orig_busy, envir = ns)
		lockBinding("edi_tuning_machine_looks_busy", ns)
		ee$tuning_config_dir_override = old_override
		unlink(dirname(dir), recursive = TRUE)
		set_cold_start_dispatch_policy(reset = TRUE)
		set_warm_start_dispatch_policy(reset = TRUE)
		set_optimization_dispatch_policy(reset = TRUE)
	}, add = TRUE)
	force(code)
}

# Replace an internal function for the duration of `code`, restoring it after.
with_stub = function(name, fn, code) {
	orig = get(name, envir = ns)
	unlockBinding(name, ns)
	assign(name, fn, envir = ns)
	on.exit({ assign(name, orig, envir = ns); lockBinding(name, ns) }, add = TRUE)
	force(code)
}
