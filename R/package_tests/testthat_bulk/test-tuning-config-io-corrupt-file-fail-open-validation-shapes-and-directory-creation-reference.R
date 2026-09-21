library(testthat)
library(EDI)

# Machine-tuning config persistence edge cases: edi_tuning_config_dir (override vs R_user_dir), edi_tuning_config_path,
# edi_tuning_write_config (creates nested directories, returns the path invisibly, overwrites), edi_tuning_read_config
# (never errors: absent / corrupt / warning-raising files give NULL) and edi_tuning_validate_config (schema version,
# list-ness, policy_diffs). All I/O happens in a temporary directory injected through the package's override hook.

Z <- function(x) get(x, envir = asNamespace("EDI"))
env <- Z("edi_env")
old <- env$tuning_config_dir_override
withr::defer(env$tuning_config_dir_override <- old, teardown_env())
new_dir <- function() { d <- file.path(withr::local_tempdir(.local_envir = parent.frame()), "nested", "cfg"); env$tuning_config_dir_override <- d; d }
SCHEMA <- Z("EDI_TUNING_SCHEMA_VERSION")

test_that("directory resolution: override wins, otherwise the R user config directory for EDI", {
	env$tuning_config_dir_override <- NULL
	expect_identical(Z("edi_tuning_config_dir")(), tools::R_user_dir("EDI", which = "config"))
	d <- new_dir()
	expect_identical(Z("edi_tuning_config_dir")(), d)
	expect_identical(Z("edi_tuning_config_path")(), file.path(d, "machine_policies.rds"))
	expect_identical(Z("EDI_TUNING_CONFIG_FILENAME"), "machine_policies.rds")
	expect_identical(SCHEMA, 1L)
})

test_that("write creates missing nested directories, returns the path invisibly, and overwrites an existing file", {
	d <- new_dir(); expect_false(dir.exists(d))
	cfg <- list(schema_version = SCHEMA, policy_diffs = list(), effort = "quick")
	r <- withVisible(Z("edi_tuning_write_config")(cfg))
	expect_false(r$visible); expect_identical(r$value, file.path(d, "machine_policies.rds"))
	expect_true(dir.exists(d)); expect_true(file.exists(r$value))
	expect_identical(readRDS(r$value), cfg)
	cfg2 <- modifyList(cfg, list(effort = "thorough")); Z("edi_tuning_write_config")(cfg2)
	expect_identical(Z("edi_tuning_read_config")()$effort, "thorough")
})

test_that("read never errors: absent file, corrupt bytes, and a non-RDS text file all give NULL", {
	d <- new_dir()
	expect_null(Z("edi_tuning_read_config")())                                       # directory does not even exist
	dir.create(d, recursive = TRUE)
	p <- Z("edi_tuning_config_path")()
	writeBin(as.raw(c(0x00, 0x01, 0x02, 0xff, 0xfe)), p)
	expect_no_error(x <- Z("edi_tuning_read_config")()); expect_null(x)
	writeLines("this is not an RDS file", p)
	expect_null(Z("edi_tuning_read_config")())
	file.create(p)                                                                   # zero-byte file
	expect_null(Z("edi_tuning_read_config")())
})

test_that("read round-trips arbitrary configs, including nested policy diffs", {
	d <- new_dir()
	cfg <- list(schema_version = SCHEMA, effort = "standard",
		policy_diffs = list(cold_start = list(inference_class_overrides = c("^A$" = TRUE)), optimizer = NULL),
		hardware_fingerprint = list(logical_cores = 4L))
	Z("edi_tuning_write_config")(cfg)
	expect_identical(Z("edi_tuning_read_config")(), cfg)
})

test_that("validate: requires a list with the current schema_version and a list policy_diffs", {
	v <- Z("edi_tuning_validate_config")
	expect_true(v(list(schema_version = SCHEMA, policy_diffs = list())))
	expect_true(v(list(schema_version = 1, policy_diffs = list(a = 1))))               # numeric 1 coerces to integer 1
	expect_false(v(list(schema_version = 2L, policy_diffs = list())))
	expect_false(v(list(schema_version = SCHEMA)))                                     # missing policy_diffs
	expect_false(v(list(policy_diffs = list())))                                       # missing schema_version
	expect_false(v(list(schema_version = SCHEMA, policy_diffs = "x")))
	expect_false(v(NULL)); expect_false(v("config")); expect_false(v(1L)); expect_false(v(NA))
	expect_false(v(list(schema_version = NA_integer_, policy_diffs = list())))
})
