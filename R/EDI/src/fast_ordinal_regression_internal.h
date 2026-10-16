#ifndef EDI_FAST_ORDINAL_REGRESSION_INTERNAL_H
#define EDI_FAST_ORDINAL_REGRESSION_INTERNAL_H

#include "result_map.h"
#include <Eigen/Dense>
#include <optional>
#include <string>

// Shared internal declaration for native callers that need the ordinal fit
// result without crossing the Rcpp wrapper boundary.
edi::ResultMap fast_ordinal_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXd> weights = std::nullopt,
    std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
    bool smart_cold_start = true,
    int maxit = 100,
    double tol = 1e-6,
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::string optimization_alg = "lbfgs",
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
    bool estimate_only = false);

#endif
