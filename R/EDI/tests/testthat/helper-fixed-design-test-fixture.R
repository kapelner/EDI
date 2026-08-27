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
	inherit = EDI:::DesignFixed,
	components = character(),
	public = list(
		# Overridden directly (same pattern as ObservationalDesign, see
		# design_abstract.R's supports_resampling()/supports_randomization_draw()/
		# supports_resampling_replay() docs): this fixture is defined outside the
		# EDI namespace, so it is never scanned by populate_design_class_registry()
		# and fails open (registry-unknown classes default to "supports resampling").
		# But it genuinely never overrides draw_ws_raw(), so it must report FALSE to
		# match reality instead of the registry-unknown fail-open default.
		supports_resampling = function() FALSE,
		supports_randomization_draw = function() FALSE,
		supports_resampling_replay = function() FALSE
	)
)
