library(testthat)
library(EDI)

# sample_mode_cpp: most frequent value, ties broken by earliest first occurrence, NA / NaN counted as values,
# type and factor attributes preserved. Reference: brute-force R tabulation over first-occurrence order.

sm <- get("sample_mode_cpp", envir = asNamespace("EDI"))
ref_mode <- function(x) {
	key <- ifelse(is.na(x) & !is.nan(x), "<NA>", ifelse(is.nan(x), "<NaN>", as.character(x)))
	if (is.logical(x) || is.character(x) || is.integer(x)) key <- ifelse(is.na(x), "<NA>", as.character(x))
	u <- unique(key)                      # first-occurrence order
	cnt <- vapply(u, function(k) sum(key == k), 0L)
	first_u <- u[which.max(cnt)]          # which.max picks the first maximum
	x[match(first_u, key)]
}

test_that("ties resolve to the value that appears first, for every atomic type", {
	expect_identical(sm(c(2, 1, 1, 2)), 2)
	expect_identical(sm(c(1, 2, 2, 1)), 1)
	expect_identical(sm(c(5L, 7L, 7L, 5L)), 5L)
	expect_identical(sm(c("b", "a", "a", "b")), "b")
	expect_identical(sm(c(TRUE, FALSE, FALSE, TRUE)), TRUE)
	expect_identical(sm(c(FALSE, TRUE, TRUE, FALSE)), FALSE)
})

test_that("agrees with the brute-force reference on random vectors of each type", {
	set.seed(11)
	for (rep in 1:60) {
		n <- sample(1:40, 1)
		xs <- list(
			sample(c(-1.5, 0, 2, 9), n, TRUE),
			sample(1:5, n, TRUE),
			sample(letters[1:4], n, TRUE),
			sample(c(TRUE, FALSE), n, TRUE))
		for (x in xs) expect_identical(sm(x), ref_mode(x))
	}
})

test_that("NA is an ordinary countable value: it wins when most frequent and loses ties to an earlier value", {
	expect_true(is.na(sm(c(1, NA, NA, 1, NA))))
	expect_identical(sm(c(1, NA, NA, 1)), 1)
	expect_true(is.na(sm(c(NA, 1, 1, NA))))
	expect_identical(sm(c(NA_integer_, 3L, 3L)), 3L)
	expect_true(is.na(sm(c(NA_integer_, NA_integer_, 3L))))
	expect_true(is.na(sm(c(NA_character_, NA_character_, "a"))))
	expect_identical(sm(c("a", NA, NA, "a")), "a")
	expect_true(is.na(sm(c(NA, TRUE, NA))))
	expect_identical(sm(c(TRUE, NA, NA, TRUE)), TRUE)
})

test_that("NaN is distinct from NA and follows the same count / first-occurrence rule", {
	r <- sm(c(NaN, NA, NaN))
	expect_true(is.nan(r))
	r2 <- sm(c(NA, NaN, NaN, NA))
	expect_true(is.na(r2) && !is.nan(r2))          # tie -> NA appears first
	r3 <- sm(c(NaN, NA, NA, NaN))
	expect_true(is.nan(r3))
	expect_identical(sm(c(NaN, 4, 4)), 4)
})

test_that("factors keep class and levels, returning the modal level code", {
	f <- factor(c("lo", "hi", "hi", "mid", "lo", "hi"), levels = c("lo", "mid", "hi"))
	r <- sm(f)
	expect_s3_class(r, "factor")
	expect_identical(levels(r), levels(f))
	expect_identical(as.character(r), "hi")
	ft <- factor(c("b", "a", "a", "b"))
	expect_identical(as.character(sm(ft)), "b")
	fna <- factor(c("a", NA, NA, "a"))
	expect_identical(as.character(sm(fna)), "a")
})

test_that("empty input is returned unchanged, singletons return themselves, and unsupported types error", {
	expect_identical(sm(numeric(0)), numeric(0))
	expect_identical(sm(character(0)), character(0))
	expect_identical(sm(integer(0)), integer(0))
	expect_identical(sm(logical(0)), logical(0))
	expect_identical(sm(3.5), 3.5)
	expect_error(sm(list(1, 2)), "unsupported type")
	expect_error(sm(as.complex(1)), "unsupported type")
})

test_that("negative zero and zero are one value", {
	expect_equal(sm(c(0, -0, 1)), 0)
	expect_equal(sm(c(1, 0, -0, 1, 0)), 0)
})
