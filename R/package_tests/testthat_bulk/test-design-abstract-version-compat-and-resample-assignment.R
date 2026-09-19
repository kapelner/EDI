library(testthat)
library(EDI)

# Design's private check_version_compat()/resample_assignment() (design_abstract.R)
# have zero test references anywhere in the suite -- confirmed via repo-wide grep.
# check_version_compat() is a once-only warning guard comparing the object's
# stamped construction version against the currently loaded package version;
# resample_assignment() is the private with-replacement resample used by the
# design-side resampling machinery (distinct kernel call from the already-covered
# draw_bootstrap_indices(), which only returns index vectors rather than
# mutating w/y/y_original/y_L/y_R in place).

make_bernoulli_design <- function(seed, n = 8L) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	des
}

test_that("check_version_compat() is a silent no-op once the object's stamped version already matches", {
	des <- make_bernoulli_design(1)
	priv <- des$.__enclos_env__$private

	# A freshly-completed design already stamps + checks its own version during
	# construction, so version_mismatch_checked is already TRUE and this call
	# is a genuine no-op re-check, not the first check.
	expect_true(priv$version_mismatch_checked)
	expect_equal(priv$check_version_compat(), invisible(NULL))
	expect_no_warning(priv$check_version_compat())
})

test_that("check_version_compat() warns exactly once on a genuine major-version mismatch, then goes silent", {
	des <- make_bernoulli_design(2)
	priv <- des$.__enclos_env__$private

	# Force an unchecked state with a stamped version from a different major release.
	priv$version_mismatch_checked <- FALSE
	priv$edi_version_created <- "0.1.0"

	expect_warning(
		priv$check_version_compat(),
		"created under EDI version 0.1.0.*Major-version differences",
		perl = TRUE
	)
	expect_true(priv$version_mismatch_checked)
	# The flag latched TRUE by the first call suppresses any further warning,
	# even though the stamped/loaded version mismatch is still present.
	expect_no_warning(priv$check_version_compat())
})

test_that("check_version_compat() does not warn when only the minor/patch version differs", {
	des <- make_bernoulli_design(3)
	priv <- des$.__enclos_env__$private
	priv$version_mismatch_checked <- FALSE
	current_major <- as.integer(unlist(strsplit(as.character(utils::packageVersion("EDI")), "\\."))[1])
	priv$edi_version_created <- paste0(current_major, ".999.999")

	expect_no_warning(priv$check_version_compat())
	expect_true(priv$version_mismatch_checked)
})

test_that("resample_assignment() reproduces the same with-replacement resample under a fixed seed", {
	des_a <- make_bernoulli_design(4)
	des_b <- des_a$duplicate()
	orig_w <- des_a$get_w()
	orig_y <- des_a$get_y()

	set.seed(123)
	res <- des_a$.__enclos_env__$private$resample_assignment()
	set.seed(123)
	des_b$.__enclos_env__$private$resample_assignment()

	# Returns self invisibly, matching the documented builder-pattern contract.
	expect_identical(res, des_a)
	expect_identical(des_a$get_w(), des_b$get_w())
	expect_identical(des_a$get_y(), des_b$get_y())

	# Every resampled (w, y) pair must be one of the original observed pairs,
	# reindexed together (not independently permuted), and length-preserved --
	# the defining contract of a paired with-replacement bootstrap resample.
	n <- length(orig_y)
	expect_length(des_a$get_y(), n)
	expect_true(all(des_a$get_y() %in% orig_y))
	expect_true(all(des_a$get_w() %in% orig_w))
	idx <- match(des_a$get_y(), orig_y)
	expect_true(all(des_a$get_w() == orig_w[idx]))
	expect_identical(des_a$get_y_original(), des_a$get_y())
})

test_that("resample_assignment() differs across resamples with different seeds on the same design (not a no-op)", {
	des_a <- make_bernoulli_design(5, n = 30L)
	des_b <- des_a$duplicate()

	set.seed(1)
	des_a$.__enclos_env__$private$resample_assignment()
	set.seed(2)
	des_b$.__enclos_env__$private$resample_assignment()

	expect_false(identical(des_a$get_y(), des_b$get_y()))
})
