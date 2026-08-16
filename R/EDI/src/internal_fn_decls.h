#ifndef EDI_INTERNAL_FN_DECLS_H
#define EDI_INTERNAL_FN_DECLS_H

// Single shared declaration point for pure-C++ "*_internal" model-fitting
// entry points that are defined in one .cpp file but called from another
// (e.g. fast_hurdle_negbin.cpp and fast_gee.cpp both call
// fast_logistic_regression_internal, defined in
// fast_logistic_regression.cpp). Before this header existed, every calling
// .cpp file carried its own hand-copied forward declaration with its own
// default arguments -- legal per-TU (each .cpp is its own translation
// unit), but two hazards: (1) C++ forbids giving a default for the same
// parameter twice in one TU, so merging any two of these files into a unity
// build (see unity_build_collision_audit.md) was a hard compile error, and
// (2) the copies had already drifted from the real definitions'  defaults
// (e.g. smart_cold_start defaulted to true in the copies vs. false at the
// definitions) -- currently inert because every real call site passes every
// argument explicitly, but a latent trap for a future call site that relies
// on "the default" without checking which copy it's compiled against.
//
// Declare each such function exactly once, here, with defaults matching the
// real definition; every .cpp that both defines and calls one of these
// includes this header instead of hand-declaring it.
//
// ModelResult and the Eigen/optional/string types below come from
// _helper_functions_core.h; include it explicitly (its own include guard
// makes this safe regardless of what the including .cpp already pulled in).
#include "_helper_functions_core.h"

// Defined in fast_logistic_regression.cpp; called from fast_hurdle_negbin.cpp
// and fast_gee.cpp.
ModelResult fast_logistic_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& weights,
    std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
    bool smart_cold_start = false,
    int maxit = 100,
    double tol = 1e-8,
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::string optimization_alg = "irls",
    std::optional<Eigen::VectorXd> warm_start_weights = std::nullopt,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
    bool estimate_only = false);

// Defined in fast_poisson_regression.cpp; called from fast_gee.cpp.
ModelResult fast_poisson_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& weights,
    std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
    bool smart_cold_start = false,
    int maxit = 100,
    double tol = 1e-8,
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::string optimization_alg = "irls",
    std::optional<Eigen::VectorXd> warm_start_weights = std::nullopt,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
    bool estimate_only = false);

#endif
