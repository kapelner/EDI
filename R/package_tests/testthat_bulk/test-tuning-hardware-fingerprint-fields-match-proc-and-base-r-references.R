library(testthat)
library(EDI)

# edi_tuning_hardware_fingerprint(): each field is cross-checked against an independent source
# (/proc, base R, .Machine); the privacy contract (no login/user fields) and the NA-on-failure wrapper are pinned.

fp_fn <- get("edi_tuning_hardware_fingerprint", envir = asNamespace("EDI"))
fp <- fp_fn()

test_that("fingerprint is a flat named list with the documented hardware, OS, and build fields", {
	expect_type(fp, "list")
	expect_false(is.null(names(fp)) || any(names(fp) == ""))
	expect_false(anyDuplicated(names(fp)) > 0)
	required <- c("logical_cores", "physical_cores", "cpu_model", "cpu_vendor_id", "cpu_architecture",
		"total_ram_bytes", "blas", "lapack", "platform", "r_version", "os_description", "os_sysname",
		"os_release", "os_version", "hostname", "sizeof_long", "sizeof_longdouble", "sizeof_pointer",
		"edi_native_tuned_build", "edi_lto_build", "edi_build_host", "edi_build_compiler")
	expect_true(all(required %in% names(fp)))
})

test_that("privacy contract: no account-name fields are recorded", {
	expect_false(any(c("login", "user", "effective_user", "username") %in% names(fp)))
	sys <- Sys.info()
})

test_that("core counts, architecture, OS and R identity equal base-R references", {
	expect_identical(fp$logical_cores, as.integer(parallel::detectCores(logical = TRUE)))
	expect_identical(fp$physical_cores, as.integer(parallel::detectCores(logical = FALSE)))
	expect_gte(fp$logical_cores, fp$physical_cores)
	sys <- Sys.info()
	expect_identical(fp$cpu_architecture, sys[["machine"]])
	expect_identical(fp$os_sysname, sys[["sysname"]])
	expect_identical(fp$os_release, sys[["release"]])
	expect_identical(fp$os_version, sys[["version"]])
	expect_identical(fp$hostname, sys[["nodename"]])
	expect_identical(fp$platform, R.version$platform)
	expect_identical(fp$r_version, R.version.string)
	expect_identical(fp$lapack, unname(La_library()))
	expect_identical(fp$blas, unname(extSoftVersion()[["BLAS"]]))
})

test_that(".Machine size fields match", {
	expect_identical(fp$sizeof_long, .Machine$sizeof.long)
	expect_identical(fp$sizeof_longdouble, .Machine$sizeof.longdouble)
	expect_identical(fp$sizeof_pointer, .Machine$sizeof.pointer)
})

test_that("CPU and RAM fields match /proc on Linux", {
	skip_if_not(file.exists("/proc/cpuinfo") && file.exists("/proc/meminfo"))
	ci <- readLines("/proc/cpuinfo", n = 200L, warn = FALSE)
	model <- sub("^model name\\s*:\\s*", "", grep("^model name", ci, value = TRUE)[1])
	expect_identical(fp$cpu_model, trimws(model))
	vend <- grep("^vendor_id", ci, value = TRUE)
	if (length(vend)) expect_identical(fp$cpu_vendor_id, trimws(sub("^vendor_id\\s*:\\s*", "", vend[1])))
	kb <- as.numeric(strsplit(grep("^MemTotal", readLines("/proc/meminfo", n = 5L), value = TRUE), "\\s+")[[1]][2])
	expect_equal(fp$total_ram_bytes, kb * 1024)
})

test_that("build flags are logical/NA consistent with the build-info record", {
	bi <- if (exists("edi_build_info_cpp", envir = asNamespace("EDI"), mode = "function"))
		get("edi_build_info_cpp", envir = asNamespace("EDI"))() else NULL
	if (is.null(bi)) {
		expect_true(is.na(fp$edi_native_tuned_build)); expect_true(is.na(fp$edi_lto_build))
	} else {
		expect_identical(fp$edi_native_tuned_build, identical(bi[["env_edi_portable"]], "0"))
		expect_identical(fp$edi_lto_build, identical(bi[["env_edi_native_lto"]], "1"))
		expect_identical(fp$edi_build_host, bi[["build_host"]])
		expect_identical(fp$edi_build_compiler, bi[["compiler"]])
	}
})

test_that("fingerprint is deterministic across calls and JSON-serialisable", {
	expect_identical(fp_fn(), fp)
	js <- jsonlite::toJSON(fp, auto_unbox = TRUE, null = "null", na = "null")
	expect_gt(nchar(js), 50L)
})
