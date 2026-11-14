library(testthat)

# read_csv_fast() (R/package_tests/read_csv_fast.R) must read a .csv.gz and a connection like read.csv does, also
# where R.utils is missing: fread decompresses only through R.utils, and the calibration study's analyze job has
# data.table but not R.utils (run 43386405728 failed reading stats/tests.csv.gz).

rcf_helper = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		f = file.path(dir, "R", "package_tests", "read_csv_fast.R")
		if (file.exists(f)) return(f)
		dir = dirname(dir)
	}
	NA_character_
}
helper = rcf_helper()
skip_if(is.na(helper), "read_csv_fast.R not found")
skip_if_not_installed("data.table")
renv = new.env()
sys.source(helper, envir = renv)

fixture = function() {
	d = data.frame(a = c(1.5, NA), formula = c("~.", "~1"), s = c("x\"y", "z"), stringsAsFactors = FALSE)
	f = tempfile(fileext = ".csv.gz")
	con = gzfile(f, "w")
	utils::write.csv(d, con, row.names = FALSE)
	close(con)
	f
}

test_that("a .csv.gz and a gzfile() connection read as read.csv reads them when R.utils is missing", {
	f = fixture()
	ref = utils::read.csv(f, stringsAsFactors = FALSE)
	rq = base::requireNamespace
	testthat::local_mocked_bindings(requireNamespace = function(package, ...) if (identical(package, "R.utils")) FALSE else
		rq(package, ...), .package = "base")
	expect_identical(renv$read_csv_fast(f, stringsAsFactors = FALSE), ref)
	expect_identical(renv$read_csv_fast(f, colClasses = list(character = "a"))$a, c("1.5", NA))
	expect_identical(renv$read_csv_fast(f, colClasses = c(formula = "character"), check.names = FALSE), ref)
	con = gzfile(f)
	expect_identical(renv$read_csv_fast(con), ref)
})

test_that("a plain .csv still goes through fread and matches read.csv", {
	p = tempfile(fileext = ".csv")
	utils::write.csv(data.frame(a = c(1.5, NA), s = c("x\"y", "z")), p, row.names = FALSE)
	expect_identical(renv$read_csv_fast(p), utils::read.csv(p, stringsAsFactors = FALSE))
})
