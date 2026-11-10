# release_v1_0_5.md TODO-183: supports_unequal_allocation is the single source of
# truth for whether a design honours prob_T != 0.5. Design$initialize() refuses
# prob_T != 0.5 for every class without it, even with asserts disabled. Owner
# ruling 2026-11-03: Efron, Atkinson, Pocock-Simon, KK, BinaryMatch and
# PairSwitching balance 1:1, so they have no prob_T argument at all; the registry
# check is the backstop. Sequential Bernoulli, iBCRD, RandomBlockSize and SPBR
# support unequal allocation.

test_that("registry: exactly the 1:1-balancing designs refuse, the rest support", {
	reg <- EDI:::design_class_registry_as_list()
	refuse <- c("DesignSeqOneByOneEfron", "DesignSeqOneByOneAtkinson", "DesignSeqOneByOnePocockSimon",
		"DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise", "DesignSeqOneByOneUrn",
		"DesignFixedBinaryMatch", "DesignFixedMatchingGreedyPairSwitching", "DesignFixedFactorial",
		"ObservationalDesign", "ObservationalDesignBlocks", "ObservationalDesignMatching")
	support <- c("DesignSeqOneByOneBernoulli", "DesignSeqOneByOneiBCRD", "DesignSeqOneByOneRandomBlockSize",
		"DesignSeqOneByOneSPBR", "DesignCustomSequential", "DesignSeqOneByOne",
		"DesignFixedBernoulli", "DesignFixediBCRD", "DesignFixedBlocking", "DesignFixedCluster",
		"DesignFixedBlockedCluster", "DesignFixedGreedy", "DesignFixedGreedyDOptimal", "DesignFixedRerandomization",
		"DesignFixedOptimalBlocks", "DesignFixedCustom")
	for (nm in refuse) expect_false(reg[[nm]]$supports_unequal_allocation, info = nm)
	for (nm in support) expect_true(reg[[nm]]$supports_unequal_allocation, info = nm)
})

test_that("the even-only designs have no prob_T argument and fix get_prob_T() at 0.5", {
	ctors <- list(
		DesignSeqOneByOneEfron = list(), DesignSeqOneByOneAtkinson = list(),
		DesignSeqOneByOnePocockSimon = list(strata_cols = "x"),
		DesignSeqOneByOneKK14 = list(), DesignSeqOneByOneKK21 = list(), DesignSeqOneByOneKK21stepwise = list(),
		DesignFixedBinaryMatch = list(), DesignFixedMatchingGreedyPairSwitching = list()
	)
	for (nm in names(ctors)) {
		gen <- get(nm, envir = asNamespace("EDI"))
		expect_false("prob_T" %in% names(formals(gen$public_methods$initialize)), info = nm)
		args <- c(list(response_type = "continuous", n = 20L, verbose = FALSE), ctors[[nm]])
		expect_error(do.call(gen$new, c(args, list(prob_T = 0.3))), "unused argument", info = nm)
		expect_equal(do.call(gen$new, args)$get_prob_T(), 0.5, info = nm)
	}
})

test_that("Bernoulli, iBCRD, RandomBlockSize and SPBR honour prob_T != 0.5", {
	set.seed(11)
	n <- 40L
	X <- data.frame(x = rnorm(n), s = rep(c("a", "b"), n / 2))
	run_seq <- function(des) { for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE]); des$get_w() }
	expect_equal(sum(run_seq(DesignSeqOneByOneiBCRD$new(response_type = "continuous", n = n, prob_T = 0.3))), 12)
	expect_equal(sum(run_seq(DesignSeqOneByOneRandomBlockSize$new(response_type = "continuous", n = n, prob_T = 0.3, block_sizes = c(10, 20)))), 12)
	expect_equal(sum(run_seq(DesignSeqOneByOneSPBR$new(response_type = "continuous", n = n, prob_T = 0.3, block_size = 10, strata_cols = "s"))), 12)
	bern <- DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = n, prob_T = 0.3)
	run_seq(bern)
	expect_equal(bern$get_prob_T(), 0.3)
	expect_lt(abs(mean(bern$draw_ws_according_to_design(400L)) - 0.3), 0.03)
})

test_that("registry backstop: assert_even_allocation(always = TRUE) refuses even with asserts off", {
	withr::local_options(edi.run_asserts = FALSE)
	des <- DesignSeqOneByOneEfron$new(response_type = "continuous", n = 10L)
	des$.__enclos_env__$private$prob_T <- 0.3
	expect_silent(des$assert_even_allocation())
	expect_error(des$assert_even_allocation(always = TRUE), "DesignSeqOneByOneEfron currently only works with even treatment allocation")
})

test_that("a user subclass inherits its nearest registered ancestor's capability", {
	reg_lookup <- EDI:::design_supports_unequal_allocation
	SeqSub <- R6::R6Class("UserSeqEfronSub", inherit = DesignSeqOneByOneEfron)
	expect_false(reg_lookup(SeqSub$new(response_type = "continuous", n = 10L)))
	BernSub <- R6::R6Class("UserSeqBernoulliSub", inherit = DesignSeqOneByOneBernoulli)
	expect_true(reg_lookup(BernSub$new(response_type = "continuous", n = 10L)))
	expect_equal(BernSub$new(response_type = "continuous", n = 10L, prob_T = 0.3)$get_prob_T(), 0.3)
	FixSub <- R6::R6Class("UserFixedBernoulliSub", inherit = DesignFixedBernoulli)
	expect_equal(FixSub$new(response_type = "continuous", n = 10L, prob_T = 0.3)$get_prob_T(), 0.3)
})

test_that("supported fixed designs keep honouring unequal prob_T", {
	des <- DesignFixediBCRD$new(response_type = "continuous", n = 20L, prob_T = 0.3, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(20)))
	des$assign_w_to_all_subjects()
	expect_equal(sum(des$get_w()), 6)
})

test_that("validate_design_class_metadata rejects a missing or NA supports_unequal_allocation", {
	rec <- EDI:::get_design_class_metadata("DesignFixedBernoulli")
	bad <- rec; bad$supports_unequal_allocation <- NA
	expect_error(EDI:::validate_design_class_metadata(bad), "invalid `supports_unequal_allocation`")
	bad$supports_unequal_allocation <- NULL
	expect_error(EDI:::validate_design_class_metadata(bad), "supports_unequal_allocation")
})

test_that("inference registry: requires_even_allocation is set for exactly CMH and Extended Robins", {
	reg <- EDI:::inference_class_registry_as_list()
	flagged <- sort(names(reg)[vapply(reg, function(r) isTRUE(r$requires_even_allocation), logical(1))])
	expect_true(all(c("InferenceIncidCMH", "InferenceIncidExtendedRobins") %in% flagged))
	expect_true(all(grepl("^InferenceIncid(CMH|ExtendedRobins)", flagged)), info = paste(flagged, collapse = ", "))
})

test_that("even-allocation inference classes are refused at construction and dropped by discovery at prob_T != 0.5", {
	set.seed(3)
	n <- 20L
	X <- data.frame(x1 = rnorm(n), s = rep(c("a", "b"), n / 2L))
	des <- DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "s", prob_T = 0.3, equal_block_sizes = TRUE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	expect_error(InferenceIncidCMH$new(des), "InferenceIncidCMH requires even treatment allocation \\(prob_T = 0.5\\)")
	expect_error(InferenceIncidExtendedRobins$new(des), "InferenceIncidExtendedRobins requires even treatment allocation \\(prob_T = 0.5\\)")
	applicable <- des$applicable_inference_class_names()
	expect_false(any(c("InferenceIncidCMH", "InferenceIncidExtendedRobins") %in% applicable))
	expect_true("InferenceIncidWald" %in% applicable)
	withr::local_options(edi.run_asserts = FALSE)
	expect_error(InferenceIncidCMH$new(des), "requires even treatment allocation")
})

test_that("custom designs warn once when the user's draws ignore prob_T, and stay quiet when they honour it", {
	set.seed(5)
	n <- 40L
	X <- data.frame(x = rnorm(n))
	Bad <- R6::R6Class("BadFixedCustomProbT", inherit = EDI:::DesignFixedCustom,
		public = list(draw_assignments = function(r = 1) replicate(r, sample(rep(0:1, self$get_n() / 2)))))
	Good <- R6::R6Class("GoodFixedCustomProbT", inherit = EDI:::DesignFixedCustom,
		public = list(draw_assignments = function(r = 1) replicate(r, rbinom(self$get_n(), 1, self$get_prob_T()))))
	b <- Bad$new(response_type = "continuous", n = n, prob_T = 0.2)
	b$add_all_subjects_to_experiment(X)
	expect_warning(b$draw_ws_according_to_design(100L), "BadFixedCustomProbT: the custom draws treat 0.500")
	expect_no_warning(b$draw_ws_according_to_design(100L))                      # once per object
	g <- Good$new(response_type = "continuous", n = n, prob_T = 0.2)
	g$add_all_subjects_to_experiment(X)
	expect_no_warning(g$draw_ws_according_to_design(100L))

	BadSeq <- R6::R6Class("BadSeqCustomProbT", inherit = EDI:::DesignCustomSequential,
		public = list(assignment_rule = function() rbinom(1, 1, 0.5)))
	s <- BadSeq$new(response_type = "continuous", n = n, prob_T = 0.2)
	for (i in seq_len(n)) s$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	expect_warning(s$draw_ws_according_to_design(50L), "BadSeqCustomProbT: the custom draws treat")
	GoodSeq <- R6::R6Class("GoodSeqCustomProbT", inherit = EDI:::DesignCustomSequential,
		public = list(assignment_rule = function() rbinom(1, 1, self$get_prob_T())))
	s2 <- GoodSeq$new(response_type = "continuous", n = n, prob_T = 0.2)
	for (i in seq_len(n)) s2$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	expect_no_warning(s2$draw_ws_according_to_design(50L))
})

test_that("design_supports_unequal_allocation() accepts a class name and refuses anything else", {
	f <- EDI:::design_supports_unequal_allocation
	# By name: the registry's own answer (the old fall-through said TRUE for every string).
	expect_false(f("DesignSeqOneByOneEfron"))
	expect_false(f("DesignSeqOneByOneKK21"))
	expect_false(f("DesignFixedMatchingGreedyPairSwitching"))
	expect_true(f("DesignFixedBernoulli"))
	expect_true(f("DesignSeqOneByOneSPBR"))
	# Name and instance agree for every registered class.
	reg <- EDI:::design_class_registry_as_list()
	for (nm in names(reg)) expect_identical(f(nm), isTRUE(reg[[nm]]$supports_unequal_allocation), info = nm)
	expect_identical(f(DesignSeqOneByOneEfron$new(response_type = "continuous", n = 10L)), f("DesignSeqOneByOneEfron"))
	expect_identical(f(DesignFixedBernoulli$new(response_type = "continuous", n = 10L)), f("DesignFixedBernoulli"))
	# Anything else is an error, never a silent TRUE.
	expect_error(f("NotADesign"), "not a registered design class")
	expect_error(f(c("DesignFixedBernoulli", "DesignSeqOneByOneEfron")), "one design class name")
	expect_error(f(NA_character_), "one design class name")
	expect_error(f(""), "one design class name")
	expect_error(f(42), "expected a design object")
	expect_error(f(list()), "expected a design object")
	expect_error(f(NULL), "expected a design object")
})
