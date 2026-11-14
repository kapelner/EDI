# The test files scripts/run_structural_checks.R runs as pre-push's fast
# structural gate. scripts/run_prepush_r_tests.R reads the same list to skip
# them in the full suite once that gate has passed in the same hook run
# (EDI_PREPUSH_STRUCTURAL_PASSED=1), so they do not run twice (~75 s). Paths are
# relative to R/EDI/tests. CI's own suite still runs every file.
structural_check_files <- c(
	"testthat/test-inference-class-wiring-completeness.R",
	"testthat/test-registry-component-drift.R",
	"testthat/test-adversarial-and-fault-injection.R",
	"testthat/test-reference-parity.R",
	"testthat/test-reused-worker-resampling-nondegenerate.R"
)
