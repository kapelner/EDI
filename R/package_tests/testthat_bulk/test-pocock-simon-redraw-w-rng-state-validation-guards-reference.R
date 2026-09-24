library(testthat)
library(EDI)

# pocock_simon_redraw_w_cpp's rrng_from_live_r_state() (pocock_simon_assign.cpp) reads R's live
# .Random.seed and validates it before continuing the RNG stream from it, with two guards: (1) an
# unexpected .Random.seed length ("pocock_simon_redraw_w_cpp: unexpected .Random.seed length
# (RNGkind changed?)"), fired when kind/normal.kind is changed to something with a differently-sized
# state vector (e.g. "Knuth-TAOCP"); (2) a same-length .Random.seed whose encoded kind isn't
# Mersenne-Twister + Inversion ("pocock_simon_redraw_w_cpp: requires RNGkind (\"Mersenne-Twister\",
# \"Inversion\")"), fired when only normal.kind is swapped (e.g. to "Box-Muller"), which keeps the
# state vector's length at 626 but changes the kind code embedded in its first element. The existing
# reference file for this kernel (test-pocock-simon-redraw-w-kernel-input-guards-and-output-contract-
# reference.R) explicitly notes it covers only the 3 plain-argument guards, not these two RNG-state
# guards, since reaching them requires temporarily changing the process's global RNGkind -- reached
# here with RNGkind() carefully saved and restored (via on.exit, so a test failure mid-assertion still
# restores it) around each probe, never left mutated for other tests in the suite.

f <- get("pocock_simon_redraw_w_cpp", envir = asNamespace("EDI"))
lv <- matrix(c(1L, 2L, 1L, 2L), ncol = 1)
wts <- 1

test_that("an RNGkind whose .Random.seed has an unexpected length raises the documented length-mismatch error", {
	old_kind <- RNGkind()
	on.exit(do.call(RNGkind, as.list(old_kind)), add = TRUE)
	set.seed(1)
	RNGkind(kind = "Knuth-TAOCP")

	expect_error(
		f(lv, 2L, wts, 1, 0.5),
		"pocock_simon_redraw_w_cpp: unexpected .Random.seed length (RNGkind changed?)",
		fixed = TRUE
	)
})

test_that("a non-Mersenne-Twister-plus-Inversion RNGkind (same seed length) raises the documented RNGkind-requirement error", {
	old_kind <- RNGkind()
	on.exit(do.call(RNGkind, as.list(old_kind)), add = TRUE)
	set.seed(1)
	RNGkind(normal.kind = "Box-Muller")
	expect_length(.Random.seed, 626L)

	expect_error(
		f(lv, 2L, wts, 1, 0.5),
		"pocock_simon_redraw_w_cpp: requires RNGkind (\"Mersenne-Twister\", \"Inversion\")",
		fixed = TRUE
	)
})

test_that("the default RNGkind never triggers either guard, and RNGkind is unchanged after each probe above", {
	expect_identical(RNGkind()[1:2], c("Mersenne-Twister", "Inversion"))
	set.seed(1)
	expect_no_error(f(lv, 2L, wts, 1, 0.5))
})
