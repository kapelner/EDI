#ifndef EDI_GEE_GROUPED_FIT_H
#define EDI_GEE_GROUPED_FIT_H

#include <Eigen/Core>
#include <optional>
#include <string>

struct GEEResult {
    Eigen::VectorXd beta;
    double alpha;
    Eigen::MatrixXd vcov;
    double quasi_loglik;
    Eigen::VectorXd score;
    Eigen::MatrixXd bread;
    bool converged;
    int niter;
    bool hit_iteration_cap;
    double gradient_norm;
};

GEEResult fit_gee_pairs_singletons_grouped(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    const std::string& family_str, const double* weights,
    std::optional<Eigen::VectorXd> warm_start_beta,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info, int maxit, double tol);

#endif
