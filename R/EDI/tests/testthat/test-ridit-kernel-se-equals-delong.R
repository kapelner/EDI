library(testthat)
library(EDI)

# PROPOSED companion to cpp patch 06 (ridit DeLong SE, TODO-106). Copy to R/EDI/tests/testthat/
# after the patched kernel is built. Asserts the C++ kernel `se` equals the R reference
# ridit_delong_se() (which InferenceOrdinalRidit keeps using). Pre-patch the kernel returns
# sd(arm scores)/sqrt(n) (0.04305201 on the probe fixture vs DeLong 0.0597673440656908), so the
# probe below skips; EDI_REQUIRE_CPP_PATCHES=true turns that skip into a failure.

skip_unless_patched = function(applied, msg) {
	if (isTRUE(applied)) return(invisible(TRUE))
	if (identical(Sys.getenv("EDI_REQUIRE_CPP_PATCHES"), "true")) testthat::fail(msg) else testthat::skip(msg)
}

ridit_fx = function() {
	set.seed(4)
	n = 80L
	w = rep(0:1, each = 40L)
	y = as.numeric(pmin(4, pmax(1, round(2.2 + 0.7 * w + rnorm(n)))))
	list(w = as.integer(w), y = as.integer(y))
}

probe_patched = function() {
	f = ridit_fx()
	k = EDI:::fast_ridit_analysis_cpp(f$w, f$y, "control")
	isTRUE(abs(k$se - EDI:::ridit_delong_se(f$y, f$w, "control")) < 1e-10)
}

test_that("fast_ridit_analysis_cpp()$se equals ridit_delong_se() for control / treatment / pooled", {
	skip_unless_patched(probe_patched(), "ridit DeLong SE patch (06) not applied: kernel se still sd/sqrt(n)")
	f = ridit_fx()
	for (ref in c("control", "treatment", "pooled")) {
		k = EDI:::fast_ridit_analysis_cpp(f$w, f$y, ref)
		expect_equal(k$se, EDI:::ridit_delong_se(f$y, f$w, ref), tolerance = 1e-12, info = ref)
	}
	# pinned numbers (computed from ridit_delong_se on this fixture)
	expect_equal(EDI:::fast_ridit_analysis_cpp(f$w, f$y, "control")$se, 0.0597673440656908, tolerance = 1e-10)
	expect_equal(EDI:::fast_ridit_analysis_cpp(f$w, f$y, "pooled")$se, 0.0298836720328454, tolerance = 1e-10)
})

test_that("kernel se equals ridit_delong_se() with a missing interior level, ties and tiny arms", {
	skip_unless_patched(probe_patched(), "ridit DeLong SE patch (06) not applied")
	w = c(rep(0L, 4), rep(1L, 4)); y = c(1L, 3L, 3L, 3L, 2L, 2L, 3L, 4L)
	for (ref in c("control", "treatment", "pooled")) {
		expect_equal(EDI:::fast_ridit_analysis_cpp(w, y, ref)$se, EDI:::ridit_delong_se(y, w, ref), tolerance = 1e-12, info = ref)
	}
	expect_equal(EDI:::fast_ridit_analysis_cpp(w, y, "control")$se, 0.237992909558247, tolerance = 1e-10)
	# single-subject arm: R convention is 0; empty arm: kernel returns an empty list (see the bulk test), so not asserted
	w1 = c(0L, 1L, 1L, 1L); y1 = c(1L, 2L, 3L, 3L)
	expect_equal(EDI:::fast_ridit_analysis_cpp(w1, y1, "control")$se, EDI:::ridit_delong_se(y1, w1, "control"), tolerance = 1e-12)
	set.seed(11)
	for (rep in 1:20) {
		n = sample(10:60, 1); ww = rbinom(n, 1, 0.5); yy = sample(1:5, n, TRUE)
		if (sum(ww) < 2 || sum(1 - ww) < 2) next
		for (ref in c("control", "treatment", "pooled")) {
			expect_equal(EDI:::fast_ridit_analysis_cpp(as.integer(ww), as.integer(yy), ref)$se,
				EDI:::ridit_delong_se(as.integer(yy), as.integer(ww), ref), tolerance = 1e-10, info = paste(rep, ref))
		}
	}
})
