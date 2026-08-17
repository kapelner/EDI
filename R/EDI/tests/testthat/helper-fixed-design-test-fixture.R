# Minimal concrete stand-in for the now-abstract (non-instantiable) DesignFixed,
# used throughout the test suite wherever a test only needs *some* generic
# fixed design (manual overwrite_all_subject_assignments(), no randomization
# draw) to exercise unrelated machinery (inference, likelihood-test
# memoization, smart-start warm paths, etc.). No components composed, same as
# every other non-blocking/non-matching concrete DesignFixed subclass
# (DesignFixedBernoulli, DesignFixedFactorial, ...) -- structural methods like
# add_all_subject_matched_pair_ids() are supplied only by BlockingStructure/
# MatchingStructure, not by DesignFixed itself.
DesignFixedTestFixture = EDI:::define_design_class(
	classname = "DesignFixedTestFixture",
	inherit = DesignFixed,
	components = character(),
	public = list()
)
