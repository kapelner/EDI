# Measures whether BLAS thread controls actually constrain the BLAS R is
# linked to (arm_hardware.md TODO-21: report observed behaviour instead of
# assuming VECLIB_MAXIMUM_THREADS is enough). Written for macOS/Accelerate,
# runs anywhere:
#
#   Rscript R/package_tests/ci/accelerate_thread_probe.R [report.md]
#
# Each control runs in a fresh R process that times crossprod() of a large
# matrix. (user + sys CPU) / elapsed above ~1.5 means the BLAS ran more than
# one thread; near 1 means it ran one. Always exits 0: this is a
# measurement, not a gate.

args = commandArgs(trailingOnly = TRUE)
report = if (length(args) >= 1L) args[[1L]] else ""

child_code = '
mode = commandArgs(trailingOnly = TRUE)[[1L]]
set.seed(1)
X = matrix(rnorm(4000 * 1500), 4000, 1500)
invisible(crossprod(X))                      # first BLAS call: library initialised
if (mode == "setenv_after_start") Sys.setenv(VECLIB_MAXIMUM_THREADS = "1")
if (mode == "rhpcblasctl_after_start") RhpcBLASctl::blas_set_num_threads(1L)
t = system.time(for (r in 1:4) invisible(crossprod(X)))
cat(sprintf("%.4f %.4f %.4f\\n", t[["user.self"]], t[["sys.self"]], t[["elapsed"]]))
'
child_file = tempfile(fileext = ".R")
writeLines(child_code, child_file)

has_rhpc = requireNamespace("RhpcBLASctl", quietly = TRUE)
Sys.unsetenv("VECLIB_MAXIMUM_THREADS")

controls = list(
	list(mode = "default", env = character(),
		label = "none (default)"),
	list(mode = "default", env = "VECLIB_MAXIMUM_THREADS=1",
		label = "`VECLIB_MAXIMUM_THREADS=1` set before R starts"),
	list(mode = "setenv_after_start", env = character(),
		label = "`Sys.setenv(VECLIB_MAXIMUM_THREADS = \"1\")` after the first BLAS call"),
	list(mode = "rhpcblasctl_after_start", env = character(),
		label = "`RhpcBLASctl::blas_set_num_threads(1)` after the first BLAS call")
)

rscript = file.path(R.home("bin"), "Rscript")
rows = vapply(controls, function(ctl) {
	if (ctl$mode == "rhpcblasctl_after_start" && !has_rhpc) {
		return(sprintf("| %s | | | | skipped: RhpcBLASctl not installed |", ctl$label))
	}
	out = suppressWarnings(system2(rscript, c(shQuote(child_file), ctl$mode),
		env = ctl$env, stdout = TRUE, stderr = TRUE))
	nums = suppressWarnings(as.numeric(strsplit(trimws(utils::tail(out, 1L)), " +")[[1L]]))
	if (length(nums) != 3L || anyNA(nums)) {
		return(sprintf("| %s | | | | error: %s |", ctl$label, paste(out, collapse = " ")))
	}
	ratio = (nums[[1L]] + nums[[2L]]) / nums[[3L]]
	verdict = if (ratio >= 1.5) "multi-threaded" else if (ratio <= 1.2) "single-threaded" else "unclear"
	sprintf("| %s | %.2f | %.2f | %.2f | %s |", ctl$label, nums[[3L]],
		nums[[1L]] + nums[[2L]], ratio, verdict)
}, character(1L))

sys_info = function(cmd, args) {
	out = tryCatch(suppressWarnings(system2(cmd, args, stdout = TRUE, stderr = FALSE)),
		error = function(e) character())
	if (length(out)) paste(out, collapse = " ") else "n/a"
}
blas = extSoftVersion()[["BLAS"]]

lines = c(
	"### BLAS thread-control probe",
	"",
	sprintf("- OS: %s; machine: %s; R %s", utils::sessionInfo()$running,
		Sys.info()[["machine"]], getRversion()),
	sprintf("- BLAS: `%s`", if (nzchar(blas)) blas else "n/a"),
	sprintf("- LAPACK: `%s`", La_library()),
	sprintf("- Cores (performance/efficiency): %s / %s",
		sys_info("sysctl", c("-n", "hw.perflevel0.physicalcpu")),
		sys_info("sysctl", c("-n", "hw.perflevel1.physicalcpu"))),
	sprintf("- RhpcBLASctl: %s", if (has_rhpc) {
		sprintf("%s, blas_get_num_procs() = %s", utils::packageVersion("RhpcBLASctl"),
			RhpcBLASctl::blas_get_num_procs())
	} else "not installed"),
	"",
	"4 x `crossprod()` of a 4000 x 1500 matrix in a fresh R process per row.",
	"CPU / elapsed above 1.5 means more than one BLAS thread ran.",
	"",
	"| Thread control | Elapsed (s) | CPU (s) | CPU / elapsed | Observed |",
	"|---|---|---|---|---|",
	rows
)

if (nzchar(report)) cat(lines, file = report, sep = "\n", append = TRUE)
cat(lines, sep = "\n")
