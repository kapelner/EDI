#ifndef EDI_NA_REAL_CORE_H
#define EDI_NA_REAL_CORE_H

// Portable (Rcpp/R-free) stand-in for R's NA_REAL, for the small "leaf"
// EDI_CORE_ONLY branches that don't otherwise pull in _helper_functions_
// core.h. R_finite/NA_REAL and std::isfinite/quiet_NaN() are behaviorally
// identical for every consumer in this codebase (same substitution already
// used throughout _helper_functions_core.h -- see that header's comment).
//
// `inline constexpr` (not plain `constexpr`, which implies internal
// linkage at namespace scope): this is the C++17 mechanism specifically
// designed to let the identical definition appear in every translation
// unit that includes this header without violating the ODR -- previously,
// several EDI_CORE_ONLY branches each declared their own plain
// `constexpr double NA_REAL`, which is harmless when every file is its own
// translation unit, but is a hard redefinition error the moment any two of
// them are merged into one translation unit (as CMake's UNITY_BUILD does
// for the Python extension -- see python/CMakeLists.txt and
// package_metadata/new_feature_plans/unity_build_collision_audit.md, whose
// R-side mega-TU check never caught this because it only compiles the
// non-EDI_CORE_ONLY branch).
#include <limits>

inline constexpr double NA_REAL = std::numeric_limits<double>::quiet_NaN();

#endif
