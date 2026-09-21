library(testthat)
library(EDI)

# OrdinalStereotypeLikelihoodSource$private$stereotype_fit_is_usable(fit, require_standard_error, check_treatment, fixed_idx,
# require_information_pd): convergence, treatment-coefficient bound (|b| <= 10), Fisher-information finiteness / squareness /
# positive definiteness / conditioning, cascading exclusion of unidentified parameters under fixed_idx, and the flags that relax
# each gate. Pure predicate evaluated on hand-built fit lists.

priv <- getFromNamespace("OrdinalStereotypeLikelihoodSource", "EDI")$private
usable <- priv$stereotype_fit_is_usable; est_ok <- priv$stereotype_treatment_estimate_is_usable
good <- list(b = 0.5, converged = TRUE, fisher_information = diag(3), ssq_b_j = 0.25)

test_that("treatment estimate bound: finite and |beta| <= 10; non-numeric input is coerced quietly", {
	expect_true(est_ok(0)); expect_true(est_ok(-10)); expect_true(est_ok(c(3, 99)))              # only the first element matters
	expect_false(est_ok(10.001)); expect_false(est_ok(-10.001)); expect_false(est_ok(NA)); expect_false(est_ok(Inf)); expect_false(est_ok("abc"))
	expect_false(est_ok(NULL))
})

test_that("baseline: a converged, bounded, positive-definite fit is usable; NULL / non-converged / missing flag are not", {
	expect_true(usable(good))
	expect_false(usable(NULL)); expect_false(usable(modifyList(good, list(converged = FALSE)))); expect_false(usable(modifyList(good, list(converged = NULL))))
	expect_false(usable(modifyList(good, list(converged = NA))))
})

test_that("treatment coefficient gate can be switched off with check_treatment = FALSE", {
	bad <- modifyList(good, list(b = 25))
	expect_false(usable(bad)); expect_true(usable(bad, check_treatment = FALSE))
	expect_false(usable(modifyList(good, list(b = NA_real_)))); expect_true(usable(modifyList(good, list(b = NA_real_)), check_treatment = FALSE))
})

test_that("information matrix gates: non-finite or non-square is rejected even without the PD check; symmetrisation is applied", {
	for (bad in list(matrix(c(1, NA, NA, 1), 2), matrix(1, 2, 3), matrix(Inf, 1, 1))) {
		expect_false(usable(modifyList(good, list(fisher_information = bad))))
		expect_false(usable(modifyList(good, list(fisher_information = bad)), require_information_pd = FALSE))
	}
	asym <- matrix(c(2, 0.5, 0.3, 2), 2)                                                    # asymmetric but its symmetric part is PD
	expect_true(usable(modifyList(good, list(fisher_information = asym))))
	expect_true(usable(modifyList(good, list(fisher_information = NULL))))                  # no information at all: nothing to reject
})

test_that("positive-definiteness and conditioning: singular / indefinite / ill-conditioned fail unless the PD gate is off", {
	sing <- matrix(1, 3, 3); indef <- diag(c(1, 1, -1)); ill <- diag(c(1, 1, 1e-9))
	for (m in list(sing, indef, ill)) {
		fit <- modifyList(good, list(fisher_information = m))
		expect_false(usable(fit)); expect_true(usable(fit, require_information_pd = FALSE))
	}
	borderline <- diag(c(1, 1, 1e-6)); expect_true(usable(modifyList(good, list(fisher_information = borderline))))         # rcond 1e-6 > sqrt(eps)
})

test_that("fixed_idx removes the held-fixed parameters, then cascades away rows left all-zero before the PD check", {
	info <- matrix(c(1, 0, 0.5, 0, 0, 0, 0.5, 0, 1), 3)                                    # parameter 2 is fully unidentified (zero row/col)
	fit <- modifyList(good, list(fisher_information = info))
	expect_false(usable(fit))                                                               # singular as a whole
	expect_true(usable(fit, fixed_idx = 2L))                                                # dropping the dead parameter leaves a PD block
	f2 <- modifyList(good, list(fisher_information = matrix(c(2, 0, 0.7, 0, 1, 0, 0.7, 0, 0), 3)))
	expect_false(usable(f2)); expect_true(usable(f2, fixed_idx = 1L))                       # cascade: with 1 fixed, row 3 becomes all-zero and is dropped
	expect_false(usable(fit, fixed_idx = c(1L, 2L, 3L)))                                    # nothing left to check
	expect_true(usable(fit, fixed_idx = c(0L, 99L, NA), require_information_pd = FALSE))    # out-of-range indices are ignored
})
