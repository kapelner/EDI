library(testthat)
library(EDI)

# v1.0.6-TODO-106: overwrite_all_subject_assignments() had two copies (Design and
# DesignFixed). There is now one body in Design: w must be a 0/1 vector over every
# subject, and every subject must be in -- t = n for a fixed design, all n arrived
# for a sequential design with n, any t >= 1 for an open-ended sequential design.
# These checks run with asserts on and off.

oasfs_with_asserts = function(on, code) {
	old = EDI:::edi_env$asserts_user
	toggle_asserts(on)
	on.exit(toggle_asserts(if (is.null(old)) TRUE else old), add = TRUE)
	force(code)
}

oasfs_seq = function(cls, n, t_arrived) {
	d = cls$new(response_type = "continuous", n = n, verbose = FALSE)
	for (i in seq_len(t_arrived)) d$add_one_subject_to_experiment_and_assign(data.frame(x = i / 10))
	d
}

test_that("DesignFixed inherits overwrite_all_subject_assignments from Design (one body)", {
	expect_identical(DesignFixed$public_methods$overwrite_all_subject_assignments, NULL)
	d = DesignFixedBernoulli$new(response_type = "continuous", n = 4, verbose = FALSE)
	expect_identical(body(d$overwrite_all_subject_assignments), body(Design$public_methods$overwrite_all_subject_assignments))
})

for (asserts_on in c(TRUE, FALSE)) {
	test_that(sprintf("fixed designs: valid w is stored, invalid w and no-subjects are rejected (asserts %s)", asserts_on), {
		oasfs_with_asserts(asserts_on, {
			for (cls in list(DesignFixedBernoulli, DesignFixediBCRD, ObservationalDesign)) {
				d = cls$new(response_type = "continuous", n = 6, verbose = FALSE)
				expect_error(d$overwrite_all_subject_assignments(c(0, 1, 0, 1, 0, 1)), "no subjects")
				d$add_all_subjects_to_experiment(data.frame(x = 1:6))
				d$overwrite_all_subject_assignments(c(1L, 0L, 1L, 0L, 0L, 1L))
				expect_identical(d$get_w(), c(1, 0, 1, 0, 0, 1))
				expect_error(d$overwrite_all_subject_assignments(c(1, 0, 1, 0, 0, 2)), "0 \\(control\\) or 1 \\(treated\\)|<= 1")
				expect_error(d$overwrite_all_subject_assignments(c(1, 0, 1, 0, 0, 0.5)), "0 \\(control\\) or 1 \\(treated\\)|integerish")
				expect_error(d$overwrite_all_subject_assignments(c(1, 0, 1, 0, 0, NA)), "0 \\(control\\) or 1 \\(treated\\)|missing values")
				expect_error(d$overwrite_all_subject_assignments(c(1, 0, 1)), "length|subjects")
				expect_error(d$overwrite_all_subject_assignments(c("1", "0", "1", "0", "0", "1")), "numeric|integerish")
				expect_identical(d$get_w(), c(1, 0, 1, 0, 0, 1))  # failed overwrites leave w as it was
			}
		})
	})

	test_that(sprintf("sequential designs: valid w after all arrive is stored, invalid w and mid-trial are rejected (asserts %s)", asserts_on), {
		oasfs_with_asserts(asserts_on, {
			set.seed(154)
			for (cls in list(DesignSeqOneByOneBernoulli, DesignSeqOneByOneEfron, DesignSeqOneByOneKK14)) {
				d = oasfs_seq(cls, n = 6, t_arrived = 3)
				w_drawn = d$get_w()
				expect_error(d$overwrite_all_subject_assignments(c(1, 0, 1)), "only 3 of the n = 6 subjects")
				expect_identical(d$get_w(), w_drawn)
				for (i in 4:6) d$add_one_subject_to_experiment_and_assign(data.frame(x = i / 10))
				d$overwrite_all_subject_assignments(c(0, 1, 1, 0, 1, 0))
				expect_identical(d$get_w(), c(0, 1, 1, 0, 1, 0))
				expect_error(d$overwrite_all_subject_assignments(c(0, 1, 1, 0, 1, 3)), "0 \\(control\\) or 1 \\(treated\\)|<= 1")
				expect_error(d$overwrite_all_subject_assignments(c(0, 1, 1, 0, 1, NA)), "0 \\(control\\) or 1 \\(treated\\)|missing values")
				expect_error(d$overwrite_all_subject_assignments(c(0, 1, 1, 0, 1, 0, 1)), "length|subjects")
				expect_identical(d$get_w(), c(0, 1, 1, 0, 1, 0))
			}

			# open-ended sequential design (no n): complete at whatever t has arrived
			s = DesignSeqOneByOneBernoulli$new(response_type = "continuous", verbose = FALSE)
			expect_error(s$overwrite_all_subject_assignments(numeric(0)), "no subjects")
			for (i in 1:3) s$add_one_subject_to_experiment_and_assign(data.frame(x = i / 10))
			s$overwrite_all_subject_assignments(c(0, 1, 1))
			expect_identical(s$get_w(), c(0, 1, 1))
			expect_error(s$overwrite_all_subject_assignments(c(0, 1, 2)), "0 \\(control\\) or 1 \\(treated\\)|<= 1")
			expect_error(s$overwrite_all_subject_assignments(c(0, 1)), "length|subjects")
		})
	})
}
