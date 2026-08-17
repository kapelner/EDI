// [[Rcpp::depends(RcppEigen)]]
#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#endif
#include <cmath>
#include <limits>
#include <stdexcept>
#include <optional>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

constexpr double kEps = 1e-8;
constexpr double kMinMu = kEps;
constexpr double kMaxMu = 1.0 - kEps;
constexpr double kMaxEtaLog = -kEps;

enum class BinomialConstrainedLink {
  kLog = 0,
  kIdentity = 1
};

namespace {

inline double clamp_prob(double mu) {
  if (mu <= kMinMu) return kMinMu;
  if (mu >= kMaxMu) return kMaxMu;
  return mu;
}

inline double safe_mu_from_eta(double eta, BinomialConstrainedLink link_type) {
  if (link_type == BinomialConstrainedLink::kLog) {
    if (eta >= kMaxEtaLog) return std::exp(kMaxEtaLog);
    return std::exp(eta);
  }
  return clamp_prob(eta);
}

double loglik_constrained_binomial(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                   const Eigen::Ref<const Eigen::VectorXd>& y,
                                   const Eigen::Ref<const Eigen::VectorXd>& beta,
                                   BinomialConstrainedLink link_type) {
  const int n = (int)X.rows();
  Eigen::VectorXd eta = X * beta;
  double ll = 0.0;
  for (int i = 0; i < n; ++i) {
    double ei = eta[i];
    if (link_type == BinomialConstrainedLink::kLog) {
      if (ei >= kMaxEtaLog) return (-std::numeric_limits<double>::infinity());
      const double mu = std::exp(ei);
      ll += y[i] * ei + (1.0 - y[i]) * std::log1p(-mu);
    } else {
      if (ei <= kMinMu || ei >= kMaxMu) return (-std::numeric_limits<double>::infinity());
      ll += y[i] * std::log(ei) + (1.0 - y[i]) * std::log1p(-ei);
    }
  }
  return ll;
}

double weighted_loglik_constrained_binomial(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                            const Eigen::Ref<const Eigen::VectorXd>& y,
                                            const Eigen::Ref<const Eigen::VectorXd>& obs_weights,
                                            const Eigen::Ref<const Eigen::VectorXd>& beta,
                                            BinomialConstrainedLink link_type) {
  const int n = (int)X.rows();
  Eigen::VectorXd eta = X * beta;
  double ll = 0.0;
  for (int i = 0; i < n; ++i) {
    const double wi = obs_weights[i];
    if (!std::isfinite(wi) || wi < 0.0) return (-std::numeric_limits<double>::infinity());
    double ei = eta[i];
    if (link_type == BinomialConstrainedLink::kLog) {
      if (ei >= kMaxEtaLog) return (-std::numeric_limits<double>::infinity());
      const double mu = std::exp(ei);
      ll += wi * (y[i] * ei + (1.0 - y[i]) * std::log1p(-mu));
    } else {
      if (ei <= kMinMu || ei >= kMaxMu) return (-std::numeric_limits<double>::infinity());
      ll += wi * (y[i] * std::log(ei) + (1.0 - y[i]) * std::log1p(-ei));
    }
  }
  return ll;
}

// all_finite_vec/all_finite_mat are now the canonical versions in
// _helper_functions_core.h (already in this file's include chain) -- see
// their comment for why.

// Evaluate log-likelihood directly from precomputed eta (avoids X*beta GEMV).
inline double loglik_from_eta(const Eigen::VectorXd& eta,
                               const Eigen::Ref<const Eigen::VectorXd>& y,
                               BinomialConstrainedLink link_type) {
  const int n = (int)eta.size();
  double ll = 0.0;
  for (int i = 0; i < n; ++i) {
    const double ei = eta[i];
    if (link_type == BinomialConstrainedLink::kLog) {
      if (ei >= kMaxEtaLog) return (-std::numeric_limits<double>::infinity());
      ll += y[i] * ei + (1.0 - y[i]) * std::log1p(-std::exp(ei));
    } else {
      if (ei <= kMinMu || ei >= kMaxMu) return (-std::numeric_limits<double>::infinity());
      ll += y[i] * std::log(ei) + (1.0 - y[i]) * std::log1p(-ei);
    }
  }
  return ll;
}

// Weighted version of loglik_from_eta for bootstrap/IPW paths.
inline double weighted_loglik_from_eta(const Eigen::VectorXd& eta,
                                       const Eigen::Ref<const Eigen::VectorXd>& y,
                                       const Eigen::Ref<const Eigen::VectorXd>& obs_weights,
                                       BinomialConstrainedLink link_type) {
  const int n = (int)eta.size();
  double ll = 0.0;
  for (int i = 0; i < n; ++i) {
    const double wi = obs_weights[i];
    if (!std::isfinite(wi) || wi < 0.0) return (-std::numeric_limits<double>::infinity());

    const double ei = eta[i];
    if (link_type == BinomialConstrainedLink::kLog) {
      if (ei >= kMaxEtaLog) return (-std::numeric_limits<double>::infinity());
      ll += wi * (y[i] * ei + (1.0 - y[i]) * std::log1p(-std::exp(ei)));
    } else {
      if (ei <= kMinMu || ei >= kMaxMu) return (-std::numeric_limits<double>::infinity());
      ll += wi * (y[i] * std::log(ei) + (1.0 - y[i]) * std::log1p(-ei));
    }
  }
  return ll;
}

} // namespace

// fit_constrained_binomial_cpp_impl / _weighted_cpp_impl / _with_var_cpp_impl
// moved to global (non-anonymous-namespace) scope: they need external
// linkage to be callable from a separate Python binding translation unit
// (an anonymous-namespace function has internal linkage and silently fails
// to link/dlopen from another TU -- see this session's history for the
// recurring bug this fixes). The low-level helpers above stay anonymous
// since they're only ever called from within this same file.
edi::ResultMap fit_constrained_binomial_cpp_impl(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                       const Eigen::Ref<const Eigen::VectorXd>& y,
                                       BinomialConstrainedLink link_type,
                                       int maxit,
                                       double tol,
                                       std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
                                       std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
                                       std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
                                       bool smart_cold_start = true,
                                       std::optional<Eigen::VectorXd> warm_start_weights = std::nullopt,
                                       std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
                                       bool estimate_only = false) {
  const int n = (int)X.rows();
  const int p = (int)X.cols();
  if (y.size() != n) throw std::invalid_argument("dimension mismatch in constrained binomial regression");
  FixedParamSpec fixed_spec = make_fixed_param_spec(p, fixed_idx, fixed_values);
  const int p_free = (int)fixed_spec.free_idx.size();
  Eigen::MatrixXd X_free(n, p_free);
  for (int j = 0; j < p_free; ++j) X_free.col(j) = X.col(fixed_spec.free_idx[j]);
  Eigen::VectorXd eta_fixed = Eigen::VectorXd::Zero(n);
  for (int j = 0; j < (int)fixed_spec.fixed_idx.size(); ++j) {
    eta_fixed.noalias() += X.col(fixed_spec.fixed_idx[j]) * fixed_spec.fixed_values[j];
  }

  Eigen::VectorXd beta = Eigen::VectorXd::Zero(p);
  if (warm_start_beta.has_value()) {
    beta = *warm_start_beta;
    if (beta.size() != p) throw std::invalid_argument("warm_start_beta must have length equal to ncol(X)");
  } else if (smart_cold_start) {
    if (link_type == BinomialConstrainedLink::kLog) {
      beta = ols_smart_cold_start_beta_on_log1p_or_legacy(X, y, Eigen::VectorXd::Zero(p), fixed_spec);
    } else {
      beta = ols_smart_cold_start_beta_or_legacy(X, y, Eigen::VectorXd::Zero(p), fixed_spec);
    }
  } else {
    const double y_mean = std::min(std::max(y.mean(), kMinMu), kMaxMu);
    beta[0] = (link_type == BinomialConstrainedLink::kLog) ? std::log(y_mean) : y_mean;
  }
  beta = apply_fixed_values(beta, fixed_spec);
  Eigen::VectorXd beta_free = subset_vector(beta, fixed_spec.free_idx);

  bool converged = false;
  Eigen::VectorXd mu = Eigen::VectorXd::Constant(n, y.mean());
  Eigen::VectorXd w = Eigen::VectorXd::Constant(n, 1.0);
  Eigen::VectorXd z_adj(n);

  // Cache ll at current beta — carried forward across iterations to avoid one
  // loglik_constrained_binomial call per accepted step.
  double ll_curr = loglik_constrained_binomial(X, y, beta, link_type);

  int iterations = 0;
  for (int iter = 0; iter < maxit; ++iter) {
    edi_check_R_user_interrupt_every(iter);
    iterations = iter + 1;
    const Eigen::VectorXd eta = eta_fixed + X_free * beta_free;

    // In-place update of mu and w to avoid temporary arrays
    for (int i = 0; i < n; ++i) {
        double ei = eta[i];
        if (link_type == BinomialConstrainedLink::kLog) {
            if (ei > kMaxEtaLog) ei = kMaxEtaLog;
            double mui = std::exp(ei);
            if (mui < kEps) mui = kEps;
            mu[i] = mui;
            w[i] = std::max(mui / std::max(1.0 - mui, kEps), kEps);
            z_adj[i] = ei + (y[i] - mui) / mui - eta_fixed[i];
        } else {
            if (ei < kMinMu) ei = kMinMu;
            if (ei > kMaxMu) ei = kMaxMu;
            mu[i] = ei;
            w[i] = 1.0 / std::max(ei * (1.0 - ei), kEps);
            z_adj[i] = y[i] - eta_fixed[i];
        }
    }

    Eigen::MatrixXd XtWX;
    bool used_warm_fisher = false;
    if (iter == 0 && warm_start_fisher_info.has_value()) {
      const Eigen::MatrixXd& info_full = *warm_start_fisher_info;
      if (info_full.rows() == p && info_full.cols() == p) {
        XtWX = subset_matrix(info_full, fixed_spec.free_idx, fixed_spec.free_idx);
        used_warm_fisher = true;
      } else {
        XtWX = weighted_crossprod(X_free, w);
      }
    } else {
      XtWX = weighted_crossprod(X_free, w);
    }
    Eigen::VectorXd XtWz = weighted_crossprod_rhs(X_free, w, z_adj);

    Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
    if (ldlt.info() != Eigen::Success) {
      if (used_warm_fisher) {
        XtWX = weighted_crossprod(X_free, w);
        ldlt.compute(XtWX);
        if (ldlt.info() != Eigen::Success) {
          return edi::ResultMap().set("b", beta).set("mu_hat", mu).set("working_weights", w).set("converged", false).set("hit_iteration_cap", false).set("num_iter", iterations);
        }
      } else {
        return edi::ResultMap().set("b", beta).set("mu_hat", mu).set("working_weights", w).set("converged", false).set("hit_iteration_cap", false).set("num_iter", iterations);
      }
    }

    Eigen::VectorXd beta_free_target = ldlt.solve(XtWz);
    if (ldlt.info() != Eigen::Success || !all_finite_vec(beta_free_target)) {
      return edi::ResultMap().set("b", beta).set("mu_hat", mu).set("working_weights", w).set("converged", false).set("hit_iteration_cap", false).set("num_iter", iterations);
    }

    // Precompute the step direction in eta-space once per IRLS iteration so
    // each backtracking probe is a cheap O(n) vector-add + scalar scan rather
    // than a full O(n*p) GEMV inside loglik_constrained_binomial.
    const Eigen::VectorXd delta_eta = X_free * (beta_free_target - beta_free);

    double step = 1.0;

    Eigen::VectorXd beta_new = beta;
    Eigen::VectorXd beta_free_new = beta_free;
    Eigen::VectorXd eta_try(n);
    bool accepted = false;
    int step_iter = 0;
    while (step >= 1e-8) {
      edi_check_R_user_interrupt_every(step_iter++);
      eta_try.noalias() = eta + step * delta_eta;
      const double ll_new = loglik_from_eta(eta_try, y, link_type);
      if (std::isfinite(ll_new) && ll_new >= ll_curr - 1e-10) {
        beta_free_new = beta_free + step * (beta_free_target - beta_free);
        beta_new = expand_free_params(beta_free_new, beta, fixed_spec);
        ll_curr = ll_new;  // carry forward — avoids recomputing at next iter start
        accepted = true;
        break;
      }
      step *= 0.5;
    }
    if (!accepted) break;
    if ((beta_free_new - beta_free).norm() / (beta_free_new.norm() + 1e-10) < tol) {
      beta = beta_new;
      beta_free = beta_free_new;
      converged = true;
      break;
    }
    beta = beta_new;
    beta_free = beta_free_new;
  }

  // NOT redefined to gradient-norm-based (optimizer_diagnostics_report.md
  // TODO-4): this IRLS loop's stopping criterion is coefficient-relative-
  // change, not gradient-based, and there is no already-computed score/
  // gradient here to reuse "for free" -- see fast_robust_regression.cpp for
  // the same reasoning. hit_iteration_cap is still meaningful without
  // touching `converged`'s definition.
  if (estimate_only) {
    const bool converged_out = converged && all_finite_vec(beta);
    return edi::ResultMap()
      .set("b", beta)
      .set("converged", converged_out)
      .set("hit_iteration_cap", (iterations >= maxit) && !converged_out)
      .set("num_iter", iterations);
  }

  Eigen::VectorXd eta = X * beta;
  if (link_type == BinomialConstrainedLink::kLog) {
    eta = eta.array().min(kMaxEtaLog).matrix();
    mu = eta.array().exp().matrix();
    w = (mu.array() / (1.0 - mu.array()).max(kEps)).max(kEps).matrix();
  } else {
    eta = eta.array().max(kMinMu).min(kMaxMu).matrix();
    mu = eta;
    w = (1.0 / (mu.array() * (1.0 - mu.array())).max(kEps)).max(kEps).matrix();
  }

  const bool converged_out = converged && all_finite_vec(beta) && all_finite_vec(mu) && all_finite_vec(w);
  return edi::ResultMap()
    .set("b", beta)
    .set("mu_hat", mu)
    .set("working_weights", w)
    .set("num_iter", iterations)
    .set("hit_iteration_cap", (iterations >= maxit) && !converged_out)
    .set("converged", converged_out)
    .set("fisher_information", weighted_crossprod(X, w));
}

edi::ResultMap fit_constrained_binomial_weighted_cpp_impl(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                const Eigen::Ref<const Eigen::VectorXd>& y,
                                                const Eigen::VectorXd& obs_weights,
                                                BinomialConstrainedLink link_type,
                                                int maxit,
                                                double tol,
                                                std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
                                                std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
                                                std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
                                                bool smart_cold_start = true,
                                                std::optional<Eigen::VectorXd> warm_start_weights = std::nullopt,
                                                std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
                                                bool estimate_only = false) {
  const int n = (int)X.rows();
  const int p = (int)X.cols();
  if (y.size() != n) throw std::invalid_argument("dimension mismatch in constrained binomial regression");
  if (obs_weights.size() != n) throw std::invalid_argument("weights length mismatch in constrained binomial regression");
  FixedParamSpec fixed_spec = make_fixed_param_spec(p, fixed_idx, fixed_values);
  const int p_free = (int)fixed_spec.free_idx.size();
  Eigen::MatrixXd X_free(n, p_free);
  for (int j = 0; j < p_free; ++j) X_free.col(j) = X.col(fixed_spec.free_idx[j]);
  Eigen::VectorXd eta_fixed = Eigen::VectorXd::Zero(n);
  for (int j = 0; j < (int)fixed_spec.fixed_idx.size(); ++j) {
    eta_fixed.noalias() += X.col(fixed_spec.fixed_idx[j]) * fixed_spec.fixed_values[j];
  }

  Eigen::VectorXd beta = Eigen::VectorXd::Zero(p);
  if (warm_start_beta.has_value()) {
    beta = *warm_start_beta;
    if (beta.size() != p) throw std::invalid_argument("warm_start_beta must have length equal to ncol(X)");
  } else if (smart_cold_start) {
    if (link_type == BinomialConstrainedLink::kLog) {
      beta = ols_smart_cold_start_beta_on_log1p_or_legacy(X, y, Eigen::VectorXd::Zero(p), fixed_spec);
    } else {
      beta = ols_smart_cold_start_beta_or_legacy(X, y, Eigen::VectorXd::Zero(p), fixed_spec);
    }
  } else {
    const double y_mean = std::min(std::max(y.mean(), kMinMu), kMaxMu);
    beta[0] = (link_type == BinomialConstrainedLink::kLog) ? std::log(y_mean) : y_mean;
  }
  beta = apply_fixed_values(beta, fixed_spec);
  Eigen::VectorXd beta_free = subset_vector(beta, fixed_spec.free_idx);

  bool converged = false;
  Eigen::VectorXd mu = Eigen::VectorXd::Constant(n, y.mean());
  Eigen::VectorXd w = Eigen::VectorXd::Constant(n, 1.0);
  Eigen::VectorXd z_adj(n);
  Eigen::VectorXd w_eff(n);
  Eigen::VectorXd eta_try(n);
  Eigen::VectorXd warm_weights_vec;
  const bool has_warm_start_weights = warm_start_weights.has_value();
  if (has_warm_start_weights) {
    warm_weights_vec = *warm_start_weights;
    if (warm_weights_vec.size() != n) throw std::invalid_argument("warm_start_weights must have length equal to nrow(X)");
  }

  double ll_curr = weighted_loglik_constrained_binomial(X, y, obs_weights, beta, link_type);

  int iterations = 0;
  for (int iter = 0; iter < maxit; ++iter) {
    edi_check_R_user_interrupt_every(iter);
    iterations = iter + 1;
    const Eigen::VectorXd eta = eta_fixed + X_free * beta_free;
    const bool use_warm_weights = (iter == 0 && has_warm_start_weights);
    for (int i = 0; i < n; ++i) {
      double ei = eta[i];
      if (link_type == BinomialConstrainedLink::kLog) {
        if (ei > kMaxEtaLog) ei = kMaxEtaLog;
        double mui = std::exp(ei);
        if (mui < kEps) mui = kEps;
        mu[i] = mui;
        w[i] = use_warm_weights ? warm_weights_vec[i] : std::max(mui / std::max(1.0 - mui, kEps), kEps);
        z_adj[i] = ei + (y[i] - mui) / mui - eta_fixed[i];
      } else {
        if (ei < kMinMu) ei = kMinMu;
        if (ei > kMaxMu) ei = kMaxMu;
        mu[i] = ei;
        w[i] = use_warm_weights ? warm_weights_vec[i] : 1.0 / std::max(ei * (1.0 - ei), kEps);
        z_adj[i] = y[i] - eta_fixed[i];
      }
      w_eff[i] = obs_weights[i] * w[i];
    }

    Eigen::MatrixXd XtWX;
    bool used_warm_fisher_w = false;
    if (iter == 0 && warm_start_fisher_info.has_value()) {
      const Eigen::MatrixXd& info_full = *warm_start_fisher_info;
      if (info_full.rows() == p && info_full.cols() == p) {
        XtWX = subset_matrix(info_full, fixed_spec.free_idx, fixed_spec.free_idx);
        used_warm_fisher_w = true;
      } else {
        XtWX = weighted_crossprod(X_free, w_eff);
      }
    } else {
      XtWX = weighted_crossprod(X_free, w_eff);
    }
    Eigen::VectorXd XtWz = weighted_crossprod_rhs(X_free, w_eff, z_adj);

    Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
    if (ldlt.info() != Eigen::Success) {
      if (used_warm_fisher_w) {
        XtWX = weighted_crossprod(X_free, w_eff);
        ldlt.compute(XtWX);
        if (ldlt.info() != Eigen::Success) {
          return edi::ResultMap().set("b", beta).set("mu_hat", mu).set("working_weights", w).set("converged", false).set("hit_iteration_cap", false).set("num_iter", iterations);
        }
      } else {
        return edi::ResultMap().set("b", beta).set("mu_hat", mu).set("working_weights", w).set("converged", false).set("hit_iteration_cap", false).set("num_iter", iterations);
      }
    }

    Eigen::VectorXd beta_free_target = ldlt.solve(XtWz);
    if (ldlt.info() != Eigen::Success || !all_finite_vec(beta_free_target)) {
      return edi::ResultMap().set("b", beta).set("mu_hat", mu).set("working_weights", w).set("converged", false).set("hit_iteration_cap", false).set("num_iter", iterations);
    }

    const Eigen::VectorXd delta_beta = beta_free_target - beta_free;
    const Eigen::VectorXd delta_eta = X_free * delta_beta;
    double step = 1.0;
    Eigen::VectorXd beta_new = beta;
    Eigen::VectorXd beta_free_new = beta_free;
    bool accepted = false;
    int step_iter = 0;
    while (step >= 1e-8) {
      edi_check_R_user_interrupt_every(step_iter++);
      eta_try.noalias() = eta + step * delta_eta;
      const double ll_new = weighted_loglik_from_eta(eta_try, y, obs_weights, link_type);
      if (std::isfinite(ll_new) && ll_new >= ll_curr - 1e-10) {
        beta_free_new = beta_free + step * delta_beta;
        beta_new = expand_free_params(beta_free_new, beta, fixed_spec);
        ll_curr = ll_new;
        accepted = true;
        break;
      }
      step *= 0.5;
    }
    if (!accepted) break;
    if ((beta_free_new - beta_free).norm() / (beta_free_new.norm() + 1e-10) < tol) {
      beta = beta_new;
      beta_free = beta_free_new;
      converged = true;
      break;
    }
    beta = beta_new;
    beta_free = beta_free_new;
  }

  // NOT redefined to gradient-norm-based -- see the unweighted variant above
  // for the same reasoning (optimizer_diagnostics_report.md TODO-4).
  if (estimate_only) {
    const bool converged_out = converged && all_finite_vec(beta);
    return edi::ResultMap()
      .set("b", beta)
      .set("converged", converged_out)
      .set("hit_iteration_cap", (iterations >= maxit) && !converged_out)
      .set("num_iter", iterations);
  }

  Eigen::VectorXd eta = X * beta;
  if (link_type == BinomialConstrainedLink::kLog) {
    eta = eta.array().min(kMaxEtaLog).matrix();
    mu = eta.array().exp().matrix();
    w = (mu.array() / (1.0 - mu.array()).max(kEps)).max(kEps).matrix();
  } else {
    eta = eta.array().max(kMinMu).min(kMaxMu).matrix();
    mu = eta;
    w = (1.0 / (mu.array() * (1.0 - mu.array())).max(kEps)).max(kEps).matrix();
  }
  w_eff = obs_weights.cwiseProduct(w);

  const bool converged_out = converged && all_finite_vec(beta) && all_finite_vec(mu) && all_finite_vec(w);
  return edi::ResultMap()
    .set("b", beta)
    .set("mu_hat", mu)
    .set("working_weights", w)
    .set("num_iter", iterations)
    .set("hit_iteration_cap", (iterations >= maxit) && !converged_out)
    .set("converged", converged_out)
    .set("fisher_information", weighted_crossprod(X, w_eff));
}

edi::ResultMap fit_constrained_binomial_with_var_cpp_impl(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                 const Eigen::Ref<const Eigen::VectorXd>& y,
                                                 BinomialConstrainedLink link_type,
                                                 int j,
                                                 int maxit,
                                                 double tol,
                                                 std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
                                                 std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
                                                 std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
                                                 bool smart_cold_start = true,
                                                 std::optional<Eigen::VectorXd> warm_start_weights = std::nullopt,
                                                 std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt) {
  edi::ResultMap fit = fit_constrained_binomial_cpp_impl(X, y, link_type, maxit, tol, fixed_idx, fixed_values, warm_start_beta, smart_cold_start, warm_start_weights, warm_start_fisher_info);
  const bool converged = *fit.get_if<bool>("converged");
  const bool hit_iteration_cap = *fit.get_if<bool>("hit_iteration_cap");
  const int num_iter = *fit.get_if<int>("num_iter");
  Eigen::VectorXd beta = *fit.get_if<Eigen::VectorXd>("b");
  Eigen::VectorXd w = *fit.get_if<Eigen::VectorXd>("working_weights");

  if (!converged || !all_finite_vec(beta) || !all_finite_vec(w)) {
    return edi::ResultMap()
      .set("b", beta)
      .set("vcov", Eigen::MatrixXd(0, 0))
      .set("std_err", Eigen::VectorXd(0))
      .set("z_vals", Eigen::VectorXd(0))
      .set("ssq_b_j", std::numeric_limits<double>::quiet_NaN())
      .set("converged", false)
      .set("hit_iteration_cap", hit_iteration_cap)
      .set("num_iter", num_iter);
  }

  FixedParamSpec fixed_spec = make_fixed_param_spec((int)X.cols(), fixed_idx, fixed_values);
  Eigen::MatrixXd fisher_information;
  if (const auto* fi = fit.get_if<Eigen::MatrixXd>("fisher_information")) {
    fisher_information = *fi;
  }
  if (fisher_information.rows() != X.cols() || fisher_information.cols() != X.cols() || !all_finite_mat(fisher_information)) {
    fisher_information = weighted_crossprod(X, w);
  }
  Eigen::MatrixXd XtWX_free = subset_matrix(fisher_information, fixed_spec.free_idx, fixed_spec.free_idx);
  Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX_free);
  if (ldlt.info() != Eigen::Success) {
    return edi::ResultMap()
      .set("b", beta)
      .set("vcov", Eigen::MatrixXd(0, 0))
      .set("std_err", Eigen::VectorXd(0))
      .set("z_vals", Eigen::VectorXd(0))
      .set("ssq_b_j", std::numeric_limits<double>::quiet_NaN())
      .set("converged", false)
      .set("hit_iteration_cap", hit_iteration_cap)
      .set("num_iter", num_iter);
  }

  int free_j = -1;
  for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
    if (fixed_spec.free_idx[jj] == j - 1) { free_j = jj + 1; break; }
  const double ssq_b_j = (free_j > 0) ? compute_diagonal_inverse_entry(XtWX_free, free_j) : std::numeric_limits<double>::quiet_NaN();

  return edi::ResultMap()
    .set("b", beta)
    .set("ssq_b_j", ssq_b_j)
    .set("converged", true)
    .set("hit_iteration_cap", hit_iteration_cap)
    .set("num_iter", num_iter)
    .set("fisher_information", fisher_information)
    .set("neg_ll", -loglik_constrained_binomial(X, y, beta, link_type))
    .set("logLik", loglik_constrained_binomial(X, y, beta, link_type));
}

namespace {

Eigen::VectorXd constrained_binomial_score_cpp_impl(const Eigen::Ref<const Eigen::MatrixXd>& X,
													const Eigen::Ref<const Eigen::VectorXd>& y,
													const Eigen::Ref<const Eigen::VectorXd>& beta,
													BinomialConstrainedLink link_type) {
	const int p = (int)beta.size();
	Eigen::VectorXd score(p);
	const double h = 1e-6;
	for (int j = 0; j < p; ++j) {
		Eigen::VectorXd bp = beta;
		Eigen::VectorXd bm = beta;
		bp[j] += h;
		bm[j] -= h;
		score[j] = (loglik_constrained_binomial(X, y, bp, link_type) -
					loglik_constrained_binomial(X, y, bm, link_type)) / (2.0 * h);
	}
	return score;
}

Eigen::MatrixXd constrained_binomial_hessian_cpp_impl(const Eigen::Ref<const Eigen::MatrixXd>& X,
													  const Eigen::Ref<const Eigen::VectorXd>& y,
													  const Eigen::Ref<const Eigen::VectorXd>& beta,
													  BinomialConstrainedLink link_type) {
	const int p = (int)beta.size();
	Eigen::MatrixXd H(p, p);
	const double h = 1e-4;
	for (int i = 0; i < p; ++i) {
		for (int j = i; j < p; ++j) {
			Eigen::VectorXd bpp = beta; bpp[i] += h; bpp[j] += h;
			Eigen::VectorXd bpm = beta; bpm[i] += h; bpm[j] -= h;
			Eigen::VectorXd bmp = beta; bmp[i] -= h; bmp[j] += h;
			Eigen::VectorXd bmm = beta; bmm[i] -= h; bmm[j] -= h;
			H(i, j) = (loglik_constrained_binomial(X, y, bpp, link_type) -
					   loglik_constrained_binomial(X, y, bpm, link_type) -
					   loglik_constrained_binomial(X, y, bmp, link_type) +
					   loglik_constrained_binomial(X, y, bmm, link_type)) / (4.0 * h * h);
			H(j, i) = H(i, j);
		}
	}
	return H;
}

Eigen::VectorXd constrained_binomial_weighted_score_cpp_impl(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                             const Eigen::Ref<const Eigen::VectorXd>& y,
                                                             const Eigen::Ref<const Eigen::VectorXd>& weights,
                                                             const Eigen::Ref<const Eigen::VectorXd>& beta,
                                                             BinomialConstrainedLink link_type) {
  const int p = (int)beta.size();
  Eigen::VectorXd score(p);
  const double h = 1e-6;
  for (int j = 0; j < p; ++j) {
    Eigen::VectorXd bp = beta;
    Eigen::VectorXd bm = beta;
    bp[j] += h;
    bm[j] -= h;
    score[j] = (weighted_loglik_constrained_binomial(X, y, weights, bp, link_type) -
                weighted_loglik_constrained_binomial(X, y, weights, bm, link_type)) / (2.0 * h);
  }
  return score;
}

Eigen::MatrixXd constrained_binomial_weighted_hessian_cpp_impl(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                               const Eigen::Ref<const Eigen::VectorXd>& y,
                                                               const Eigen::Ref<const Eigen::VectorXd>& weights,
                                                               const Eigen::Ref<const Eigen::VectorXd>& beta,
                                                               BinomialConstrainedLink link_type) {
  const int p = (int)beta.size();
  Eigen::MatrixXd H(p, p);
  const double h = 1e-4;
  for (int i = 0; i < p; ++i) {
    for (int j = i; j < p; ++j) {
      Eigen::VectorXd bpp = beta; bpp[i] += h; bpp[j] += h;
      Eigen::VectorXd bpm = beta; bpm[i] += h; bpm[j] -= h;
      Eigen::VectorXd bmp = beta; bmp[i] -= h; bmp[j] += h;
      Eigen::VectorXd bmm = beta; bmm[i] -= h; bmm[j] -= h;
      H(i, j) = (weighted_loglik_constrained_binomial(X, y, weights, bpp, link_type) -
                 weighted_loglik_constrained_binomial(X, y, weights, bpm, link_type) -
                 weighted_loglik_constrained_binomial(X, y, weights, bmp, link_type) +
                 weighted_loglik_constrained_binomial(X, y, weights, bmm, link_type)) / (4.0 * h * h);
      H(j, i) = H(i, j);
    }
  }
  return H;
}

}  // namespace

#ifndef EDI_CORE_ONLY
//' Log-Link (Relative-Risk) Binomial Regression Score, Standalone (C++)
//'
//' Computes a \strong{numerical} (central finite-difference, step \eqn{h =
//' 10^{-6}}) approximation of the score vector (gradient of the log-likelihood)
//' of the constrained log-link binomial regression model documented in full at
//' \code{\link{fast_log_binomial_regression_cpp}}, at arbitrary caller-supplied
//' \code{beta} (not necessarily the MLE) — not an analytic derivative. Exported
//' standalone — independent of any optimizer run — for direct numerical
//' diagnostics (e.g. verifying convergence) at a specific parameter value.
//'
//' @param X_r A numeric matrix of predictors.
//' @param y_r A binary (0/1) numeric vector of responses.
//' @param beta A numeric vector of coefficients \eqn{\beta} at which to evaluate the score.
//' @return The finite-difference-approximated score vector at \code{beta}.
//' @seealso \code{\link{get_log_binomial_regression_hessian_cpp}} for the
//'   corresponding (also finite-difference) Hessian at the same point;
//'   \code{\link{fast_log_binomial_regression_cpp}} for the full model
//'   documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_log_binomial_regression_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
													  SEXP y_r,
													  const Eigen::Map<Eigen::VectorXd>& beta) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
	return constrained_binomial_score_cpp_impl(X, y, beta, BinomialConstrainedLink::kLog);
}

//' Log-Link (Relative-Risk) Binomial Regression Hessian, Standalone (C++)
//'
//' Computes a \strong{numerical} (central finite-difference 4-point stencil, step
//' \eqn{h = 10^{-4}}) approximation of the Hessian matrix of the log-likelihood of
//' the constrained log-link binomial regression model documented in full at
//' \code{\link{fast_log_binomial_regression_cpp}}, at arbitrary caller-supplied
//' \code{beta} (not necessarily the MLE) — not an analytic second derivative.
//' Exported standalone — independent of any optimizer run — for direct numerical
//' diagnostics at a specific parameter value.
//'
//' @param X_r A numeric matrix of predictors.
//' @param y_r A binary (0/1) numeric vector of responses.
//' @param beta A numeric vector of coefficients \eqn{\beta} at which to evaluate the Hessian.
//' @return The finite-difference-approximated Hessian matrix of the log-likelihood at \code{beta}.
//' @seealso \code{\link{get_log_binomial_regression_score_cpp}} for the
//'   corresponding (also finite-difference) gradient at the same point;
//'   \code{\link{fast_log_binomial_regression_cpp}} for the full model
//'   documentation, including the probability-boundary constraint this Hessian is
//'   evaluated without enforcing.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_log_binomial_regression_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
														SEXP y_r,
														const Eigen::Map<Eigen::VectorXd>& beta) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
	return constrained_binomial_hessian_cpp_impl(X, y, beta, BinomialConstrainedLink::kLog);
}

//' Weighted Log-Link (Relative-Risk) Binomial Regression Score, Standalone (C++)
//'
//' Computes the observation-weighted score vector (gradient of the weighted
//' log-likelihood) of the constrained log-link binomial regression model
//' documented in full at \code{\link{fast_log_binomial_regression_cpp}}, at
//' arbitrary caller-supplied \code{beta} (not necessarily the MLE), with each
//' observation's contribution multiplied by \code{weights_r[i]}, via a
//' \strong{numerical} (central finite-difference, step \eqn{h = 10^{-6}})
//' approximation — not an analytic derivative. Exported standalone — independent
//' of any optimizer run — for direct numerical diagnostics at a specific
//' parameter value.
//'
//' @param X_r A numeric matrix of predictors.
//' @param y_r A binary (0/1) numeric vector of responses.
//' @param weights_r A nonnegative numeric vector of observation weights.
//' @param beta A numeric vector of coefficients \eqn{\beta} at which to evaluate the score.
//' @return The finite-difference-approximated weighted score vector at \code{beta}.
//' @seealso \code{\link{get_log_binomial_regression_weighted_hessian_cpp}} for
//'   the corresponding weighted Hessian at the same point;
//'   \code{\link{get_log_binomial_regression_score_cpp}} for the unweighted
//'   version; \code{\link{fast_log_binomial_regression_cpp}} for the full model
//'   documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_log_binomial_regression_weighted_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                                               SEXP y_r,
                                                               SEXP weights_r,
                                                               const Eigen::Map<Eigen::VectorXd>& beta) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
    NumericVector weights_vec(weights_r);
    Eigen::Map<const Eigen::VectorXd> weights(weights_vec.begin(), weights_vec.size());
  return constrained_binomial_weighted_score_cpp_impl(X, y, weights, beta, BinomialConstrainedLink::kLog);
}

//' Weighted Log-Link (Relative-Risk) Binomial Regression Hessian, Standalone (C++)
//'
//' Computes the observation-weighted Hessian matrix of the weighted log-likelihood
//' of the constrained log-link binomial regression model documented in full at
//' \code{\link{fast_log_binomial_regression_cpp}}, at arbitrary caller-supplied
//' \code{beta} (not necessarily the MLE), with each observation's contribution
//' multiplied by \code{weights_r[i]}, via a \strong{numerical} (central
//' finite-difference 4-point stencil, step \eqn{h = 10^{-4}}) approximation —
//' not an analytic second derivative. Exported standalone — independent of any
//' optimizer run — for direct numerical diagnostics at a specific parameter value.
//'
//' @param X_r A numeric matrix of predictors.
//' @param y_r A binary (0/1) numeric vector of responses.
//' @param weights_r A nonnegative numeric vector of observation weights.
//' @param beta A numeric vector of coefficients \eqn{\beta} at which to evaluate the Hessian.
//' @return The finite-difference-approximated weighted Hessian matrix at \code{beta}.
//' @seealso \code{\link{get_log_binomial_regression_weighted_score_cpp}} for
//'   the corresponding weighted gradient at the same point;
//'   \code{\link{get_log_binomial_regression_hessian_cpp}} for the unweighted
//'   version; \code{\link{fast_log_binomial_regression_cpp}} for the full model
//'   documentation.
//' @return A numeric matrix representing the weighted Hessian.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_log_binomial_regression_weighted_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                                                 SEXP y_r,
                                                                 SEXP weights_r,
                                                                 const Eigen::Map<Eigen::VectorXd>& beta) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
    NumericVector weights_vec(weights_r);
    Eigen::Map<const Eigen::VectorXd> weights(weights_vec.begin(), weights_vec.size());
  return constrained_binomial_weighted_hessian_cpp_impl(X, y, weights, beta, BinomialConstrainedLink::kLog);
}

//' Identity-Link (Risk-Difference) Binomial Regression Score, Standalone (C++)
//'
//' Computes a \strong{numerical} (central finite-difference, step \eqn{h =
//' 10^{-6}}) approximation of the score vector (gradient of the log-likelihood)
//' of the constrained identity-link binomial regression model documented in full
//' at \code{\link{fast_identity_binomial_regression_cpp}}, at arbitrary
//' caller-supplied \code{beta} (not necessarily the MLE) — not an analytic
//' derivative. Exported standalone — independent of any optimizer run — for
//' direct numerical diagnostics (e.g. verifying convergence, or cross-checking an
//' analytic gradient elsewhere) at a specific parameter value.
//'
//' @param X_r A numeric matrix of predictors.
//' @param y_r A binary (0/1) numeric vector of responses.
//' @param beta A numeric vector of coefficients \eqn{\beta} at which to evaluate the score.
//' @return The finite-difference-approximated score vector at \code{beta}.
//' @seealso \code{\link{get_identity_binomial_regression_hessian_cpp}} for the
//'   corresponding (also finite-difference) Hessian at the same point;
//'   \code{\link{fast_identity_binomial_regression_cpp}} for the full model
//'   documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_identity_binomial_regression_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
														   SEXP y_r,
														   const Eigen::Map<Eigen::VectorXd>& beta) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
	return constrained_binomial_score_cpp_impl(X, y, beta, BinomialConstrainedLink::kIdentity);
}

//' Identity-Link (Risk-Difference) Binomial Regression Hessian, Standalone (C++)
//'
//' Computes a \strong{numerical} (central finite-difference 4-point stencil, step
//' \eqn{h = 10^{-4}}) approximation of the Hessian matrix of the log-likelihood of
//' the constrained identity-link binomial regression model documented in full at
//' \code{\link{fast_identity_binomial_regression_cpp}}, at arbitrary
//' caller-supplied \code{beta} (not necessarily the MLE) — not an analytic
//' second derivative. Exported standalone — independent of any optimizer run —
//' for direct numerical diagnostics at a specific parameter value.
//'
//' @param X_r A numeric matrix of predictors.
//' @param y_r A binary (0/1) numeric vector of responses.
//' @param beta A numeric vector of coefficients \eqn{\beta} at which to evaluate the Hessian.
//' @return The finite-difference-approximated Hessian matrix of the log-likelihood at \code{beta}.
//' @seealso \code{\link{get_identity_binomial_regression_score_cpp}} for the
//'   corresponding (also finite-difference) gradient at the same point;
//'   \code{\link{fast_identity_binomial_regression_cpp}} for the full model
//'   documentation, including the probability-boundary constraint this Hessian is
//'   evaluated without enforcing.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_identity_binomial_regression_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
															 SEXP y_r,
															 const Eigen::Map<Eigen::VectorXd>& beta) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
	return constrained_binomial_hessian_cpp_impl(X, y, beta, BinomialConstrainedLink::kIdentity);
}

//' Weighted Identity-Link (Risk-Difference) Binomial Regression Score, Standalone (C++)
//'
//' Computes the observation-weighted score vector (gradient of the weighted
//' log-likelihood) of the constrained identity-link binomial regression model
//' documented in full at \code{\link{fast_identity_binomial_regression_cpp}}, at
//' arbitrary caller-supplied \code{beta} (not necessarily the MLE), with each
//' observation's contribution multiplied by \code{weights_r[i]}, via a
//' \strong{numerical} (central finite-difference, step \eqn{h = 10^{-6}})
//' approximation — not an analytic derivative. Exported standalone — independent
//' of any optimizer run — for direct numerical diagnostics at a specific
//' parameter value.
//'
//' @param X_r A numeric matrix of predictors.
//' @param y_r A binary (0/1) numeric vector of responses.
//' @param weights_r A nonnegative numeric vector of observation weights.
//' @param beta A numeric vector of coefficients \eqn{\beta} at which to evaluate the score.
//' @return The finite-difference-approximated weighted score vector at \code{beta}.
//' @seealso \code{\link{get_identity_binomial_regression_weighted_hessian_cpp}} for
//'   the corresponding weighted Hessian at the same point;
//'   \code{\link{get_identity_binomial_regression_score_cpp}} for the unweighted
//'   version; \code{\link{fast_identity_binomial_regression_cpp}} for the full model
//'   documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_identity_binomial_regression_weighted_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                                                    SEXP y_r,
                                                                    SEXP weights_r,
                                                                    const Eigen::Map<Eigen::VectorXd>& beta) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
    NumericVector weights_vec(weights_r);
    Eigen::Map<const Eigen::VectorXd> weights(weights_vec.begin(), weights_vec.size());
  return constrained_binomial_weighted_score_cpp_impl(X, y, weights, beta, BinomialConstrainedLink::kIdentity);
}

//' Weighted Identity-Link (Risk-Difference) Binomial Regression Hessian, Standalone (C++)
//'
//' Computes the observation-weighted Hessian matrix of the weighted log-likelihood
//' of the constrained identity-link binomial regression model documented in full
//' at \code{\link{fast_identity_binomial_regression_cpp}}, at arbitrary
//' caller-supplied \code{beta} (not necessarily the MLE), with each observation's
//' contribution multiplied by \code{weights_r[i]}, via a \strong{numerical}
//' (central finite-difference 4-point stencil, step \eqn{h = 10^{-4}})
//' approximation — not an analytic second derivative. Exported standalone —
//' independent of any optimizer run — for direct numerical diagnostics at a
//' specific parameter value.
//'
//' @param X_r A numeric matrix of predictors.
//' @param y_r A binary (0/1) numeric vector of responses.
//' @param weights_r A nonnegative numeric vector of observation weights.
//' @param beta A numeric vector of coefficients \eqn{\beta} at which to evaluate the Hessian.
//' @return The finite-difference-approximated weighted Hessian matrix at \code{beta}.
//' @seealso \code{\link{get_identity_binomial_regression_weighted_score_cpp}} for
//'   the corresponding weighted gradient at the same point;
//'   \code{\link{get_identity_binomial_regression_hessian_cpp}} for the unweighted
//'   version; \code{\link{fast_identity_binomial_regression_cpp}} for the full model
//'   documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_identity_binomial_regression_weighted_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                                                      SEXP y_r,
                                                                      SEXP weights_r,
                                                                      const Eigen::Map<Eigen::VectorXd>& beta) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
    NumericVector weights_vec(weights_r);
    Eigen::Map<const Eigen::VectorXd> weights(weights_vec.begin(), weights_vec.size());
  return constrained_binomial_weighted_hessian_cpp_impl(X, y, weights, beta, BinomialConstrainedLink::kIdentity);
}

//' Fast Log-Link Binomial Regression, Estimate Only (C++ Backend)
//'
//' Fits a binary-response GLM with the \strong{log} link (a relative-risk
//' model), \eqn{\log \mu_i = \log \Pr(Y_i = 1) = x_i^\top \beta} (equivalently
//' \eqn{\mu_i = e^{x_i^\top \beta}}, constrained to stay below
//' \eqn{1 - 10^{-8}} so it remains a valid probability), via Fisher scoring
//' (IRLS) with a step-halving line search that rejects any Newton step whose
//' resulting \eqn{\eta_i = x_i^\top \beta} would push \eqn{\mu_i} out of range
//' or decrease the log-likelihood — the same boundary-constrained-line-search
//' mechanism documented in full at
//' \code{\link{fast_identity_binomial_regression_cpp}} (see that page for the
//' IRLS/line-search mechanics, which are shared verbatim between the log and
//' identity links here; only the link function itself, and hence the
//' coefficient scale, differs). Regression coefficients are directly
//' interpretable as \strong{log relative risks}: \eqn{e^{\beta_j}} is the
//' multiplicative change in \eqn{\Pr(Y = 1)} per unit change in covariate
//' \eqn{j} — in contrast to
//' \code{\link{fast_identity_binomial_regression_cpp}}'s risk-difference scale,
//' or a logit-link model's odds-ratio scale.
//'
//' @param X_r A numeric matrix of predictors, \eqn{n \times p}; include an
//'   explicit intercept column if desired (no implicit intercept).
//' @param y_r A binary (0/1) numeric vector of responses, length \eqn{n}.
//' @param maxit Maximum number of Fisher-scoring iterations.
//' @param tol Convergence tolerance, on the relative norm of the coefficient
//'   update step.
//' @param fixed_idx Optional integer indices of coefficients to hold fixed
//'   rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
//' @param warm_start_weights Optional initial working weights for the first IRLS iteration.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix for the first IRLS iteration.
//' @return A list with components \code{b} (estimated coefficients
//'   \eqn{\hat\beta}, on the log-relative-risk scale), \code{mu_hat} (fitted
//'   probabilities, length \eqn{n}), \code{working_weights} (final IRLS
//'   weights), \code{iterations}, \code{converged} (logical), and
//'   \code{fisher_information} (the working-weights curvature matrix
//'   \eqn{X^\top W X}).
//' @seealso \code{\link{fast_identity_binomial_regression_cpp}} for the
//'   identity-link (risk-difference) analog and the full IRLS/line-search
//'   mechanics; \code{\link{fast_log_binomial_regression_with_var_cpp}} for the
//'   variance-augmented variant; \code{\link{fast_log_binomial_regression_weighted_cpp}}
//'   for the row-weighted variant.
//'   \href{https://en.wikipedia.org/wiki/Poisson_regression}{Poisson
//'   regression}'s log link is the closest common orientation point for a
//'   log-link GLM. Analogous Python API:
//'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM}
//'   (\code{families.Binomial(link=log())}).
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_log_binomial_regression_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                      SEXP y_r,
                                      int maxit = 100,
                                      double tol = 1e-6,
                                      Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                      Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                      Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
                                      bool smart_cold_start = true,
                                      Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
                                      Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
                                      bool estimate_only = false) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
  return edi::to_rcpp_list(fit_constrained_binomial_cpp_impl(X, y, BinomialConstrainedLink::kLog, maxit, tol, nullable_to_optional<Eigen::VectorXi>(fixed_idx), nullable_to_optional<Eigen::VectorXd>(fixed_values), nullable_to_optional<Eigen::VectorXd>(warm_start_beta), smart_cold_start, nullable_to_optional<Eigen::VectorXd>(warm_start_weights), nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info), estimate_only));
}

//' Fast Log-Link Binomial Regression with Targeted Variance (C++ Backend)
//'
//' Fits the same log-link (relative-risk) binomial regression as
//' \code{\link{fast_log_binomial_regression_cpp}} (see that page for the full
//' model) and additionally computes the variance of a single caller-selected
//' coefficient — the log-link analog of
//' \code{\link{fast_identity_binomial_regression_with_var_cpp}}, sharing
//' exactly the same targeted-diagonal-entry variance mechanism and the same
//' caveat: this entry point does \strong{not} compute or return a full
//' variance-covariance matrix or per-coefficient standard errors, despite its
//' name; only the coefficient named by \code{j} gets a variance
//' (\code{ssq_b_j}), and the returned \code{vcov}/\code{std_err}/\code{z_vals}
//' fields are always empty placeholders (see
//' \code{\link{fast_identity_binomial_regression_with_var_cpp}}'s Details for
//' the exact mechanics, identical here up to the link function).
//'
//' @param X_r A numeric matrix of predictors, \eqn{n \times p}.
//' @param y_r A binary (0/1) numeric vector of responses, length \eqn{n}.
//' @param j 1-based index (into \code{X}'s columns) of the coefficient to
//'   compute \code{ssq_b_j} for.
//' @param maxit Maximum number of Fisher-scoring iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional integer indices of coefficients to hold fixed
//'   rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
//' @param warm_start_weights Optional initial working weights for the first IRLS iteration.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix for the first IRLS iteration.
//' @return A list with components \code{b}, \code{ssq_b_j}, \code{converged},
//'   \code{fisher_information}, \code{neg_ll}/\code{logLik} (present only on
//'   the success path), and the always-empty \code{vcov}/\code{std_err}/
//'   \code{z_vals} placeholders; see
//'   \code{\link{fast_identity_binomial_regression_with_var_cpp}} for the exact
//'   field semantics (shared verbatim here).
//' @seealso \code{\link{fast_log_binomial_regression_cpp}} for the
//'   estimate-only variant; \code{\link{fast_identity_binomial_regression_with_var_cpp}}
//'   for the identity-link analog with the same targeted-variance mechanism.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_log_binomial_regression_with_var_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                               SEXP y_r,
                                               int j = 2,
                                               int maxit = 100,
                                               double tol = 1e-6,
                                               Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                               Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                               Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
                                               bool smart_cold_start = true,
                                               Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
                                               Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
  return edi::to_rcpp_list(fit_constrained_binomial_with_var_cpp_impl(X, y, BinomialConstrainedLink::kLog, j, maxit, tol, nullable_to_optional<Eigen::VectorXi>(fixed_idx), nullable_to_optional<Eigen::VectorXd>(fixed_values), nullable_to_optional<Eigen::VectorXd>(warm_start_beta), smart_cold_start, nullable_to_optional<Eigen::VectorXd>(warm_start_weights), nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info)));
}

//' Fast Weighted Log-Link Binomial Regression, Estimate Only (C++ Backend)
//'
//' Fits the same log-link (relative-risk) binomial regression as
//' \code{\link{fast_log_binomial_regression_cpp}} (see that page for the full
//' model and boundary-constrained IRLS line search), with each observation's
//' contribution to the log-likelihood and IRLS working weights multiplied by a
//' nonnegative row weight \code{weights_r[i]}. Setting all weights to 1
//' recovers \code{\link{fast_log_binomial_regression_cpp}} exactly.
//'
//' @param X_r A numeric matrix of predictors, \eqn{n \times p}.
//' @param y_r A binary (0/1) numeric vector of responses, length \eqn{n}.
//' @param weights_r A nonnegative numeric vector of length \eqn{n} giving each
//'   row's weight.
//' @param maxit Maximum number of Fisher-scoring iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional integer indices of coefficients to hold fixed
//'   rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
//' @param warm_start_weights Optional initial working weights for the first IRLS iteration.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix for the first IRLS iteration.
//' @return A list with the same components as
//'   \code{\link{fast_log_binomial_regression_cpp}}: \code{b}, \code{mu_hat},
//'   \code{working_weights}, \code{iterations}, \code{converged}, and
//'   \code{fisher_information} (all reflecting the weighted log-likelihood).
//' @seealso \code{\link{fast_log_binomial_regression_cpp}} for the unweighted
//'   model and full documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_log_binomial_regression_weighted_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                               SEXP y_r,
                                               SEXP weights_r,
                                               int maxit = 100,
                                               double tol = 1e-6,
                                               Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                               Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                               Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
                                               bool smart_cold_start = true,
                                               Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
                                               Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
                                               bool estimate_only = false) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
    NumericVector weights_vec(weights_r);
    Eigen::Map<const Eigen::VectorXd> weights(weights_vec.begin(), weights_vec.size());
  return edi::to_rcpp_list(fit_constrained_binomial_weighted_cpp_impl(X, y, weights, BinomialConstrainedLink::kLog, maxit, tol, nullable_to_optional<Eigen::VectorXi>(fixed_idx), nullable_to_optional<Eigen::VectorXd>(fixed_values), nullable_to_optional<Eigen::VectorXd>(warm_start_beta), smart_cold_start, nullable_to_optional<Eigen::VectorXd>(warm_start_weights), nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info), estimate_only));
}

//' Fast Identity-Link Binomial Regression, Estimate Only (C++ Backend)
//'
//' Fits a binary-response GLM with the \strong{identity} link (a linear
//' probability / risk-difference model), \eqn{\mu_i = \Pr(Y_i = 1) = x_i^\top \beta}
//' (constrained to \eqn{(10^{-8}, 1 - 10^{-8})}; no other link transformation is
//' applied), via Fisher scoring (IRLS) with a step-halving line search that
//' rejects any Newton step whose resulting \eqn{\eta_i = x_i^\top \beta} would
//' leave the valid probability range or decrease the log-likelihood — this
//' boundary-constrained line search, not a link-function transform, is what
//' keeps fitted probabilities in \eqn{(0, 1)} for this otherwise-unconstrained
//' linear-in-\eqn{\beta} model. Regression coefficients on the identity-link
//' scale are directly interpretable as \strong{risk differences}: \eqn{\beta_j}
//' is the change in \eqn{\Pr(Y = 1)} per unit change in covariate \eqn{j}, in
//' contrast to \code{fast_log_binomial_regression_cpp}'s log-link coefficients
//' (interpretable as log relative risks) or a standard logit-link model's
//' log-odds-ratio coefficients.
//'
//' @details
//' \strong{Optimization.} Each Fisher-scoring iteration solves a weighted
//' least-squares step using working weights
//' \eqn{w_i = 1 / \max(\mu_i(1-\mu_i), 10^{-8})} (the inverse Bernoulli variance,
//' clamped away from 0 for stability near the boundary), then backtracks
//' (halving the step size, down to a minimum step of \eqn{10^{-8}}) until the
//' resulting \eqn{\eta} stays within \eqn{(10^{-8}, 1-10^{-8})} for every
//' observation \emph{and} the log-likelihood does not decrease; a step that
//' cannot be accepted at any halving depth terminates iteration without
//' \code{converged = TRUE}. \code{fixed_idx}/\code{fixed_values} hold specific
//' coefficients fixed rather than estimated; \code{warm_start_beta} (or, when
//' absent, an OLS-based guess if \code{smart_cold_start = TRUE}) seeds the
//' first iteration, and \code{warm_start_weights}/\code{warm_start_fisher_info}
//' warm-start the first IRLS working-weights/curvature computation.
//'
//' \strong{No guarantee of a feasible solution.} Because the identity link has
//' no inherent boundary protection, some \eqn{(X, y)} configurations (e.g.
//' extreme covariate values, near-perfect separation, or an ill-conditioned
//' \code{X}) may have no interior maximum-likelihood solution reachable by this
//' constrained line search; such cases surface as \code{converged = FALSE}
//' rather than a silently invalid (out-of-range) fitted probability.
//'
//' @param X_r A numeric matrix of predictors, \eqn{n \times p}; include an
//'   explicit intercept column if desired (no implicit intercept).
//' @param y_r A binary (0/1) numeric vector of responses, length \eqn{n}.
//' @param maxit Maximum number of Fisher-scoring iterations.
//' @param tol Convergence tolerance, on the relative norm of the coefficient
//'   update step.
//' @param fixed_idx Optional integer indices of coefficients to hold fixed
//'   rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE} (default) and no
//'   \code{warm_start_beta} is supplied, use an OLS-based initial guess.
//' @param warm_start_weights Optional initial working weights for the first IRLS iteration.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix for the first IRLS iteration.
//' @return A list with components \code{b} (estimated coefficients
//'   \eqn{\hat\beta}, on the risk-difference/identity scale), \code{mu_hat}
//'   (fitted probabilities \eqn{\hat\mu_i}, length \eqn{n}), \code{working_weights}
//'   (the final IRLS weights \eqn{w_i}), \code{iterations} (number of Fisher-
//'   scoring iterations performed), \code{converged} (logical; also requires all
//'   of \code{b}, \code{mu_hat}, \code{working_weights} to be finite), and
//'   \code{fisher_information} (the working-weights curvature matrix
//'   \eqn{X^\top W X}).
//' @seealso \code{\link{fast_identity_binomial_regression_with_var_cpp}} for the
//'   variance-augmented variant; \code{\link{fast_identity_binomial_regression_weighted_cpp}}
//'   for the row-weighted variant; \code{fast_log_binomial_regression_cpp} for
//'   the log-link (relative-risk) analog of this model.
//'   \href{https://en.wikipedia.org/wiki/Generalized_linear_model}{Generalized
//'   linear model} for orientation. Analogous Python API:
//'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM}
//'   (\code{families.Binomial(link=identity())}).
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_identity_binomial_regression_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                           SEXP y_r,
                                           int maxit = 100,
                                           double tol = 1e-6,
                                           Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                           Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                           Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
                                           bool smart_cold_start = true,
                                           Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
                                           Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
  return edi::to_rcpp_list(fit_constrained_binomial_cpp_impl(X, y, BinomialConstrainedLink::kIdentity, maxit, tol, nullable_to_optional<Eigen::VectorXi>(fixed_idx), nullable_to_optional<Eigen::VectorXd>(fixed_values), nullable_to_optional<Eigen::VectorXd>(warm_start_beta), smart_cold_start, nullable_to_optional<Eigen::VectorXd>(warm_start_weights), nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info)));
}

//' Fast Identity-Link Binomial Regression with Targeted Variance (C++ Backend)
//'
//' Fits the same identity-link (risk-difference) binomial regression as
//' \code{\link{fast_identity_binomial_regression_cpp}} (see that page for the
//' full model and boundary-constrained IRLS line search) and additionally
//' computes the variance of a single caller-selected coefficient, via a targeted
//' diagonal-entry inversion of the working-weights Fisher information — this
//' entry point does \strong{not} compute or return a full variance-covariance
//' matrix or a vector of standard errors for every coefficient, despite its
//' name; only the one coefficient named by \code{j} gets a variance
//' (\code{ssq_b_j}).
//'
//' @details
//' \strong{Variance computation.} The IRLS working-weights Fisher information
//' \eqn{X^\top W X} (reused from the underlying fit if finite and correctly
//' sized, else recomputed from the final working weights) is restricted to the
//' free (non-\code{fixed_idx}) parameters and factorized via LDLT; \code{ssq_b_j}
//' is then obtained from a single targeted diagonal-entry inversion
//' (\code{compute_diagonal_inverse_entry()}) at the free-parameter position
//' corresponding to \code{j}, not a full matrix inverse. If the underlying fit
//' did not converge, or the LDLT factorization fails (e.g. a rank-deficient
//' free-parameter information matrix), the function returns early with
//' \code{converged = FALSE}, \code{ssq_b_j = NA}, and empty
//' (zero-length/zero-dimension) \code{vcov}/\code{std_err}/\code{z_vals}
//' placeholders — these three fields are \strong{only ever populated as empty
//' placeholders}, on both the success and failure paths; no caller should rely
//' on them containing actual values.
//'
//' @param X_r A numeric matrix of predictors, \eqn{n \times p}.
//' @param y_r A binary (0/1) numeric vector of responses, length \eqn{n}.
//' @param j 1-based index (into \code{X}'s columns) of the coefficient to
//'   compute \code{ssq_b_j} for.
//' @param maxit Maximum number of Fisher-scoring iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional integer indices of coefficients to hold fixed
//'   rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
//' @param warm_start_weights Optional initial working weights for the first IRLS iteration.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix for the first IRLS iteration.
//' @return A list with components \code{b} (estimated coefficients
//'   \eqn{\hat\beta}), \code{ssq_b_j} (the variance of \eqn{\hat\beta_j}, or
//'   \code{NA} on failure), \code{converged} (logical), \code{fisher_information}
//'   (the working-weights curvature matrix used for \code{ssq_b_j}, present only
//'   on the success path), \code{neg_ll}/\code{logLik} (the negative/positive
//'   log-likelihood at \eqn{\hat\beta}, present only on the success path), and
//'   the always-empty \code{vcov}/\code{std_err}/\code{z_vals} placeholders
//'   described in Details.
//' @seealso \code{\link{fast_identity_binomial_regression_cpp}} for the
//'   estimate-only variant and the full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_identity_binomial_regression_with_var_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                                    SEXP y_r,
                                                    int j = 2,
                                                    int maxit = 100,
                                                    double tol = 1e-6,
                                                    Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                                    Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                                    Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
                                                    bool smart_cold_start = true,
                                                    Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
                                                    Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
  return edi::to_rcpp_list(fit_constrained_binomial_with_var_cpp_impl(X, y, BinomialConstrainedLink::kIdentity, j, maxit, tol, nullable_to_optional<Eigen::VectorXi>(fixed_idx), nullable_to_optional<Eigen::VectorXd>(fixed_values), nullable_to_optional<Eigen::VectorXd>(warm_start_beta), smart_cold_start, nullable_to_optional<Eigen::VectorXd>(warm_start_weights), nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info)));
}

//' Fast Weighted Identity-Link Binomial Regression, Estimate Only (C++ Backend)
//'
//' Fits the same identity-link (risk-difference) binomial regression as
//' \code{\link{fast_identity_binomial_regression_cpp}} (see that page for the
//' full model, boundary-constrained IRLS line search, and interpretation), with
//' each observation's contribution to the log-likelihood and IRLS working
//' weights multiplied by a nonnegative row weight \code{weights_r[i]}. Setting
//' all weights to 1 recovers \code{\link{fast_identity_binomial_regression_cpp}}
//' exactly; this is the backend used when the identity-link model must be fit on
//' bootstrap-reweighted or otherwise weighted data.
//'
//' @param X_r A numeric matrix of predictors, \eqn{n \times p}.
//' @param y_r A binary (0/1) numeric vector of responses, length \eqn{n}.
//' @param weights_r A nonnegative numeric vector of length \eqn{n} giving each
//'   row's weight.
//' @param maxit Maximum number of Fisher-scoring iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional integer indices of coefficients to hold fixed
//'   rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
//' @param warm_start_weights Optional initial working weights for the first IRLS iteration.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix for the first IRLS iteration.
//' @return A list with the same components as
//'   \code{\link{fast_identity_binomial_regression_cpp}}: \code{b},
//'   \code{mu_hat}, \code{working_weights}, \code{iterations}, \code{converged},
//'   and \code{fisher_information} (all reflecting the weighted log-likelihood).
//' @seealso \code{\link{fast_identity_binomial_regression_cpp}} for the
//'   unweighted model and full documentation;
//'   \code{\link{fast_identity_binomial_regression_with_var_cpp}} for the
//'   (unweighted) variance-augmented variant.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_identity_binomial_regression_weighted_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                                    SEXP y_r,
                                                    SEXP weights_r,
                                                    int maxit = 100,
                                                    double tol = 1e-6,
                                                    Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                                    Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                                    Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
                                                    bool smart_cold_start = true,
                                                    Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
                                                    Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
                                                    bool estimate_only = false) {
    NumericVector y_vec(y_r);
    Eigen::Map<const Eigen::VectorXd> y(y_vec.begin(), y_vec.size());
    NumericVector weights_vec(weights_r);
    Eigen::Map<const Eigen::VectorXd> weights(weights_vec.begin(), weights_vec.size());
  return edi::to_rcpp_list(fit_constrained_binomial_weighted_cpp_impl(X, y, weights, BinomialConstrainedLink::kIdentity, maxit, tol, nullable_to_optional<Eigen::VectorXi>(fixed_idx), nullable_to_optional<Eigen::VectorXd>(fixed_values), nullable_to_optional<Eigen::VectorXd>(warm_start_beta), smart_cold_start, nullable_to_optional<Eigen::VectorXd>(warm_start_weights), nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info), estimate_only));
}
#endif // EDI_CORE_ONLY
