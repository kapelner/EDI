#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <Rcpp.h>
#include <RcppEigen.h>
#endif
#include <algorithm>
#include <cmath>
#include <vector>
#include <stdexcept>

// [[Rcpp::depends(RcppEigen)]]

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

class StereotypeLogitRegression {
private:
    const Eigen::Ref<const Eigen::MatrixXd> m_X;
    std::vector<int> m_y;
    int m_n;
    int m_p;
    int m_K;
    mutable VectorXd m_eta;
    mutable VectorXd m_beta_score_weight;
    mutable VectorXd m_logits;
    mutable VectorXd m_probs;
    mutable std::vector<double> m_hess_score_vals;
    mutable MatrixXd m_hess_dscore_dgamma;
    mutable std::vector<MatrixXd> m_hess_d2score_dgamma2;
    mutable std::vector<VectorXd> m_hess_logit_grad;
    mutable std::vector<MatrixXd> m_hess_logit_hess;
    mutable VectorXd m_hess_mean_grad;
    mutable MatrixXd m_hess_mean_hess;
    mutable MatrixXd m_hess_mean_outer;
    mutable MatrixXd m_hess_delta;
    mutable VectorXd m_score_v;
    mutable VectorXd m_score_cum_v;
    mutable MatrixXd m_hess_H;
    mutable std::vector<double> m_exp_z;
    mutable std::vector<double> m_exp_mean_grad;
    mutable std::vector<double> m_exp_logits;
    mutable std::vector<double> m_exp_probs;

public:
    StereotypeLogitRegression(const Eigen::Ref<const Eigen::MatrixXd>& X, const Eigen::Ref<const Eigen::VectorXd>& y) :
        m_X(X), m_n(X.rows()), m_p(X.cols()), m_K(0) {
        std::vector<double> levels = init_levels(y);
        m_K = static_cast<int>(levels.size());
        m_y.resize(m_n);
        for (int i = 0; i < m_n; ++i) {
            double yi = y[i];
            int idx = 0;
            while (idx < m_K && levels[idx] != yi) {
                ++idx;
            }
            m_y[i] = idx + 1;
        }
        m_eta.resize(m_n);
        m_beta_score_weight.resize(m_n);
        m_logits.resize(m_K);
        m_probs.resize(m_K);
        const int d = num_params();
        const int n_gamma = num_gamma();
        m_hess_score_vals.resize(m_K);
        m_hess_dscore_dgamma.resize(m_K, n_gamma);
        m_hess_d2score_dgamma2.resize(m_K);
        m_hess_logit_grad.resize(m_K);
        m_hess_logit_hess.resize(m_K);
        for (int k = 0; k < m_K; ++k) {
            m_hess_d2score_dgamma2[k].resize(n_gamma, n_gamma);
            m_hess_logit_grad[k].resize(d);
            m_hess_logit_hess[k].resize(d, d);
        }
        m_hess_mean_grad.resize(d);
        m_hess_mean_hess.resize(d, d);
        m_hess_mean_outer.resize(d, d);
        m_hess_delta.resize(d, d);
        m_score_v.resize(n_gamma);
        m_score_cum_v.resize(n_gamma);
        m_hess_H.resize(d, d);
        m_exp_z.resize(d);
        m_exp_mean_grad.resize(d);
        m_exp_logits.resize(m_K);
        m_exp_probs.resize(m_K);
    }

    static std::vector<double> init_levels(const Eigen::Ref<const Eigen::VectorXd>& y) {
        std::vector<double> levels(y.data(), y.data() + y.size());
        std::sort(levels.begin(), levels.end());
        levels.erase(std::unique(levels.begin(), levels.end()), levels.end());
        return levels;
    }

    int num_categories() const { return m_K; }
    int num_alpha() const { return m_K - 1; }
    int num_gamma() const { return std::max(0, m_K - 2); }
    int num_params() const { return num_alpha() + m_p + num_gamma(); }

    VectorXd initialize_params() const {
        VectorXd params(num_params());
        params.setZero();

        std::vector<double> counts(m_K, 0.5);
        for (int i = 0; i < m_n; ++i) {
            counts[m_y[i] - 1] += 1.0;
        }
        for (int j = 1; j < m_K; ++j) {
            params[j - 1] = std::log(counts[j] / counts[0]);
        }
        return params;
    }

    void compute_scores(
        const Eigen::Ref<const VectorXd>& gamma,
        std::vector<double>& score_vals,
        Eigen::Ref<MatrixXd> dscore_dgamma
    ) const {
        score_vals.assign(m_K, 0.0);
        dscore_dgamma.setZero();

        if (num_gamma() == 0) {
            if (m_K >= 2) {
                score_vals[m_K - 1] = 1.0;
            }
            return;
        }

        m_score_v = gamma.array().exp();
        const double denom = 1.0 + m_score_v.sum();
        double running = 0.0;
        for (int r = 0; r < num_gamma(); ++r) {
            running += m_score_v[r];
            m_score_cum_v[r] = running;
        }

        for (int j = 2; j <= m_K - 1; ++j) {
            int interior_idx = j - 2;
            double c_j = m_score_cum_v[interior_idx];
            score_vals[j - 1] = c_j / denom;

            for (int r = 0; r < num_gamma(); ++r) {
                double dc = (r <= interior_idx) ? m_score_v[r] : 0.0;
                dscore_dgamma(j - 1, r) = (dc * denom - c_j * m_score_v[r]) / (denom * denom);
            }
        }
        score_vals[m_K - 1] = 1.0;
    }

    void compute_scores_with_second_derivatives(
        const Eigen::Ref<const VectorXd>& gamma,
        std::vector<double>& score_vals,
        Eigen::Ref<MatrixXd> dscore_dgamma,
        std::vector<MatrixXd>& d2score_dgamma2
    ) const {
        const int n_gamma = num_gamma();
        compute_scores(gamma, score_vals, dscore_dgamma);
        if ((int)d2score_dgamma2.size() != m_K) {
            d2score_dgamma2.resize(m_K);
        }
        for (int k = 0; k < m_K; ++k) {
            if (d2score_dgamma2[k].rows() != n_gamma || d2score_dgamma2[k].cols() != n_gamma) {
                d2score_dgamma2[k].resize(n_gamma, n_gamma);
            }
            d2score_dgamma2[k].setZero();
        }

        if (n_gamma == 0) {
            return;
        }

        // m_score_v and m_score_cum_v already filled by compute_scores() above
        const double denom = 1.0 + m_score_v.sum();

        for (int j = 2; j <= m_K - 1; ++j) {
            const int interior_idx = j - 2;
            const double c_j = m_score_cum_v[interior_idx];
            MatrixXd& Hs = d2score_dgamma2[j - 1];

            for (int r = 0; r < n_gamma; ++r) {
                const double A_r = (r <= interior_idx) ? 1.0 : 0.0;
                const double numerator_r = A_r * denom - c_j;
                const double first_r = m_score_v[r] * numerator_r / (denom * denom);

                for (int t = 0; t < n_gamma; ++t) {
                    const double A_t = (t <= interior_idx) ? 1.0 : 0.0;
                    const double delta_rt = (r == t) ? 1.0 : 0.0;
                    Hs(r, t) =
                        delta_rt * first_r +
                        m_score_v[r] * m_score_v[t] * (
                            (A_r - A_t) / (denom * denom) -
                            2.0 * numerator_r / (denom * denom * denom)
                        );
                }
            }
        }
    }

    double loglik_grad(
        const Eigen::Ref<const VectorXd>& params,
        VectorXd* grad = NULL
    ) const {
        const int n_alpha = num_alpha();
        const int n_gamma = num_gamma();

        const auto alpha = params.head(n_alpha);
        const auto beta = params.segment(n_alpha, m_p);
        VectorXd gamma = (n_gamma > 0) ? params.tail(n_gamma) : VectorXd(0);

        if (grad != NULL) {
            grad->setZero();
        }
        if (m_p > 0) {
            m_eta.noalias() = m_X * beta;
        }

        compute_scores(gamma, m_hess_score_vals, m_hess_dscore_dgamma);
        const std::vector<double>& score_vals = m_hess_score_vals;
        const MatrixXd& dscore_dgamma = m_hess_dscore_dgamma;
        const Map<const VectorXd> score_vec(score_vals.data(), m_K);

        VectorXd& logits = m_logits;
        VectorXd& probs = m_probs;
        double ll = 0.0;

        for (int i = 0; i < m_n; ++i) {
            const double eta = (m_p > 0) ? m_eta[i] : 0.0;
            logits.setZero();
            for (int j = 2; j <= m_K; ++j) {
                logits[j - 1] = alpha[j - 2] + score_vec[j - 1] * eta;
            }

            const double max_logit = logits.maxCoeff();
            probs = (logits.array() - max_logit).exp().matrix();
            const double denom = probs.sum();
            probs /= denom;

            const int yi = m_y[i] - 1;
            ll += logits[yi] - max_logit - std::log(denom);

            if (grad != NULL) {
                for (int j = 2; j <= m_K; ++j) {
                    (*grad)[j - 2] += ((yi == (j - 1)) ? 1.0 : 0.0) - probs[j - 1];
                }

                if (m_p > 0) {
                    const double observed_score = score_vec[yi];
                    const double expected_score = probs.dot(score_vec);
                    m_beta_score_weight[i] = observed_score - expected_score;
                }

                if (n_gamma > 0) {
                    for (int r = 0; r < n_gamma; ++r) {
                        double expected_dscore = 0.0;
                        for (int j = 0; j < m_K; ++j) {
                            expected_dscore += probs[j] * dscore_dgamma(j, r);
                        }
                        (*grad)[n_alpha + m_p + r] += eta * (dscore_dgamma(yi, r) - expected_dscore);
                    }
                }
            }
        }
        if (grad != NULL && m_p > 0) {
            grad->segment(n_alpha, m_p).noalias() += m_X.transpose() * m_beta_score_weight;
        }

        return ll;
    }

    MatrixXd loglik_hessian(const Eigen::Ref<const VectorXd>& params) const {
        const int n_alpha = num_alpha();
        const int n_gamma = num_gamma();
        const int d = num_params();

        VectorXd beta = params.segment(n_alpha, m_p);
        VectorXd gamma = (n_gamma > 0) ? params.tail(n_gamma) : VectorXd(0);
        if (m_p > 0) {
            m_eta.noalias() = m_X * beta;
        }

        std::vector<double>& score_vals = m_hess_score_vals;
        MatrixXd& dscore_dgamma = m_hess_dscore_dgamma;
        std::vector<MatrixXd>& d2score_dgamma2 = m_hess_d2score_dgamma2;
        compute_scores_with_second_derivatives(gamma, score_vals, dscore_dgamma, d2score_dgamma2);
        const Map<const VectorXd> score_vec(score_vals.data(), m_K);

        MatrixXd& H = m_hess_H;
        H.setZero();
        VectorXd& logits = m_logits;
        VectorXd& probs = m_probs;
        std::vector<VectorXd>& logit_grad = m_hess_logit_grad;
        std::vector<MatrixXd>& logit_hess = m_hess_logit_hess;
        VectorXd& mean_grad = m_hess_mean_grad;
        MatrixXd& mean_hess = m_hess_mean_hess;
        MatrixXd& mean_outer = m_hess_mean_outer;
        MatrixXd& delta = m_hess_delta;

        for (int i = 0; i < m_n; ++i) {
            const double eta = (m_p > 0) ? m_eta[i] : 0.0;
            logits.setZero();
            logit_grad[0].setZero();
            logit_hess[0].setZero();

            for (int j = 2; j <= m_K; ++j) {
                const int cat = j - 1;
                logits[cat] = params[j - 2] + score_vec[cat] * eta;

                VectorXd& zj = logit_grad[cat];
                MatrixXd& Bj = logit_hess[cat];
                zj.setZero();
                Bj.setZero();

                zj[j - 2] = 1.0;
                if (m_p > 0) {
                    zj.segment(n_alpha, m_p).noalias() = score_vec[cat] * m_X.row(i).transpose();
                }
                if (n_gamma > 0) {
                    zj.tail(n_gamma).noalias() = eta * dscore_dgamma.row(cat).transpose();
                    for (int r = 0; r < n_gamma; ++r) {
                        const double ds = dscore_dgamma(cat, r);
                        for (int b = 0; b < m_p; ++b) {
                            const int beta_idx = n_alpha + b;
                            const int gamma_idx = n_alpha + m_p + r;
                            const double cross = m_X(i, b) * ds;
                            Bj(beta_idx, gamma_idx) = cross;
                            Bj(gamma_idx, beta_idx) = cross;
                        }
                    }
                    Bj.bottomRightCorner(n_gamma, n_gamma).noalias() =
                        eta * d2score_dgamma2[cat];
                }
            }

            const double max_logit = logits.maxCoeff();
            probs = (logits.array() - max_logit).exp().matrix();
            probs /= probs.sum();

            mean_grad.setZero();
            mean_hess.setZero();
            mean_outer.setZero();
            double* mo = mean_outer.data();
            for (int j = 0; j < m_K; ++j) {
                mean_grad.noalias() += probs[j] * logit_grad[j];
                mean_hess.noalias() += probs[j] * logit_hess[j];
                // Raw pointer accumulation for mean_outer (upper triangle only)
                const double* gj = logit_grad[j].data();
                const double pj = probs[j];
                for (int c = 0; c < d; ++c) {
                    const double s = pj * gj[c];
                    for (int r = 0; r <= c; ++r)
                        mo[r + c * d] += s * gj[r];
                }
            }
            // Reflect mean_outer upper triangle to lower
            for (int c = 0; c < d; ++c)
                for (int r = 0; r < c; ++r)
                    mo[c + r * d] = mo[r + c * d];

            const int yi = m_y[i] - 1;
            // Build delta = logit_hess[yi] - mean_hess - mean_outer, then add mean_grad outer product
            delta.noalias() = logit_hess[yi];
            delta.noalias() -= mean_hess;
            delta.noalias() -= mean_outer;
            double* d_data = delta.data();
            const double* mg = mean_grad.data();
            // Add mean_grad * mean_grad.T (upper triangle only)
            for (int c = 0; c < d; ++c) {
                const double mg_c = mg[c];
                for (int r = 0; r <= c; ++r)
                    d_data[r + c * d] += mg_c * mg[r];
            }
            // Reflect delta upper triangle to lower
            for (int c = 0; c < d; ++c)
                for (int r = 0; r < c; ++r)
                    d_data[c + r * d] = d_data[r + c * d];
            H.noalias() += delta;
        }

        return 0.5 * (H + H.transpose());
    }

    // Fisher information: E[-d2LL/dθ2] = Σ_i [Σ_j p_j z_j z_j^T - mean_z mean_z^T]
    // No d2score/dgamma2 needed — cheap and always PSD.
    MatrixXd expected_hessian(const Eigen::Ref<const VectorXd>& params) const {
        const int n_alpha = num_alpha();
        const int n_gamma = num_gamma();
        const int d = num_params();

        const VectorXd beta  = params.segment(n_alpha, m_p);
        const VectorXd gamma = (n_gamma > 0) ? params.tail(n_gamma) : VectorXd(0);
        if (m_p > 0) {
            m_eta.noalias() = m_X * beta;
        }

        compute_scores(gamma, m_hess_score_vals, m_hess_dscore_dgamma);
        const std::vector<double>& score_vals = m_hess_score_vals;
        const MatrixXd& dscore_dgamma = m_hess_dscore_dgamma;

        MatrixXd I = MatrixXd::Zero(d, d);
        double* I_data = I.data();
        std::vector<double>& z = m_exp_z;
        std::vector<double>& mean_grad = m_exp_mean_grad;
        std::vector<double>& logits = m_exp_logits;
        std::vector<double>& probs = m_exp_probs;

        for (int i = 0; i < m_n; ++i) {
            const double eta = (m_p > 0) ? m_eta[i] : 0.0;
            const double* xi = m_X.data() + i; // column-major: xi[j*m_n] = X(i,j)

            // Compute logits and softmax probabilities
            logits[0] = 0.0;
            for (int cat = 1; cat < m_K; ++cat)
                logits[cat] = params[cat - 1] + score_vals[cat] * eta;
            double max_l = *std::max_element(logits.begin(), logits.end());
            double sp = 0.0;
            for (int cat = 0; cat < m_K; ++cat) { probs[cat] = std::exp(logits[cat] - max_l); sp += probs[cat]; }
            for (int cat = 0; cat < m_K; ++cat) probs[cat] /= sp;

            // Accumulate mean_grad = Σ_j p_j * z_j
            for (int jj = 0; jj < d; ++jj) mean_grad[jj] = 0.0;
            for (int cat = 1; cat < m_K; ++cat) {
                const double pj = probs[cat];
                const double sv = score_vals[cat];
                mean_grad[cat - 1] += pj;
                for (int b = 0; b < m_p; ++b)
                    mean_grad[n_alpha + b] += pj * sv * xi[b * m_n];
                for (int r = 0; r < n_gamma; ++r)
                    mean_grad[n_alpha + m_p + r] += pj * eta * dscore_dgamma(cat, r);
            }

            // Accumulate Σ_j p_j * z_j * z_j^T (upper triangle)
            for (int cat = 1; cat < m_K; ++cat) {
                const double pj = probs[cat];
                const double sv = score_vals[cat];
                for (int jj = 0; jj < d; ++jj) z[jj] = 0.0;
                z[cat - 1] = 1.0;
                for (int b = 0; b < m_p; ++b) z[n_alpha + b] = sv * xi[b * m_n];
                for (int r = 0; r < n_gamma; ++r) z[n_alpha + m_p + r] = eta * dscore_dgamma(cat, r);
                for (int c = 0; c < d; ++c) {
                    if (z[c] == 0.0) continue;
                    const double pz = pj * z[c];
                    for (int r = 0; r <= c; ++r)
                        I_data[r + c * d] += pz * z[r];
                }
            }

            // Subtract mean_grad * mean_grad^T (upper triangle)
            for (int c = 0; c < d; ++c) {
                if (mean_grad[c] == 0.0) continue;
                const double mg = mean_grad[c];
                for (int r = 0; r <= c; ++r)
                    I_data[r + c * d] -= mg * mean_grad[r];
            }
        }

        // Reflect upper triangle to lower
        for (int c = 0; c < d; ++c)
            for (int r = 0; r < c; ++r)
                I_data[c + r * d] = I_data[r + c * d];
        return I;
    }
};

static MatrixXd numeric_hessian_from_gradient(
    const StereotypeLogitRegression& model,
    const Eigen::Ref<const VectorXd>& params,
    double h = 1e-5
) {
    (void)h;
    return model.loglik_hessian(params);
}

static MatrixXd pseudo_inverse_symmetric(const Eigen::Ref<const MatrixXd>& A, double tol = 1e-8) {
    JacobiSVD<MatrixXd> svd(A, ComputeThinU | ComputeThinV);
    VectorXd sing = svd.singularValues();
    MatrixXd Dinv = MatrixXd::Zero(sing.size(), sing.size());
    for (int i = 0; i < sing.size(); ++i) {
        if (sing[i] > tol) {
            Dinv(i, i) = 1.0 / sing[i];
        }
    }
    return svd.matrixV() * Dinv * svd.matrixU().transpose();
}

static VectorXd set_beta_and_pack_nuisance(
    const Eigen::Ref<const VectorXd>& nuisance,
    double beta_fixed,
    int n_alpha,
    int p,
    int n_gamma,
    int beta_index = 0
) {
    const int d = n_alpha + p + n_gamma;
    VectorXd params(d);
    int cursor = 0;

    if (n_alpha > 0) {
        params.head(n_alpha) = nuisance.segment(cursor, n_alpha);
        cursor += n_alpha;
    }

    for (int j = 0; j < p; ++j) {
        if (j == beta_index) {
            params[n_alpha + j] = beta_fixed;
        } else {
            params[n_alpha + j] = nuisance[cursor];
            ++cursor;
        }
    }

    if (n_gamma > 0) {
        params.tail(n_gamma) = nuisance.tail(n_gamma);
    }

    return params;
}

static VectorXd extract_nuisance_params(
    const Eigen::Ref<const VectorXd>& params,
    int n_alpha,
    int p,
    int n_gamma,
    int beta_index = 0
) {
    VectorXd nuisance(params.size() - 1);
    int cursor = 0;

    if (n_alpha > 0) {
        nuisance.segment(cursor, n_alpha) = params.head(n_alpha);
        cursor += n_alpha;
    }

    for (int j = 0; j < p; ++j) {
        if (j == beta_index) {
            continue;
        }
        nuisance[cursor] = params[n_alpha + j];
        ++cursor;
    }

    if (n_gamma > 0) {
        nuisance.tail(n_gamma) = params.tail(n_gamma);
    }

    return nuisance;
}

static double nuisance_loglik_grad(
    const StereotypeLogitRegression& model,
    const Eigen::Ref<const VectorXd>& nuisance,
    double beta_fixed,
    int n_alpha,
    int p,
    int n_gamma,
    VectorXd* grad = NULL,
    int beta_index = 0
) {
    VectorXd params = set_beta_and_pack_nuisance(nuisance, beta_fixed, n_alpha, p, n_gamma, beta_index);
    VectorXd full_grad(params.size());
    double ll = model.loglik_grad(params, grad == NULL ? NULL : &full_grad);
    if (grad != NULL) {
        *grad = extract_nuisance_params(full_grad, n_alpha, p, n_gamma, beta_index);
    }
    return ll;
}

static MatrixXd nuisance_numeric_hessian_from_gradient(
    const StereotypeLogitRegression& model,
    const Eigen::Ref<const VectorXd>& nuisance,
    double beta_fixed,
    int n_alpha,
    int p,
    int n_gamma,
    double h = 1e-5,
    int beta_index = 0
) {
    (void)h;
    VectorXd params = set_beta_and_pack_nuisance(nuisance, beta_fixed, n_alpha, p, n_gamma, beta_index);
    MatrixXd H_full = model.loglik_hessian(params);
    const int d = nuisance.size();
    MatrixXd H(d, d);
    std::vector<int> keep;
    keep.reserve(d);
    for (int j = 0; j < params.size(); ++j) {
        if (j != n_alpha + beta_index) {
            keep.push_back(j);
        }
    }
    for (int r = 0; r < d; ++r) {
        for (int c = 0; c < d; ++c) {
            H(r, c) = H_full(keep[r], keep[c]);
        }
    }
    return H;
}

static VectorXd optimize_nuisance_given_beta(
    const StereotypeLogitRegression& model,
    const Eigen::Ref<const VectorXd>& full_params_start,
    double beta_fixed,
    int n_alpha,
    int p,
    int n_gamma,
    int maxit = 50,
    double tol = 1e-8,
    int beta_index = 0
) {
    VectorXd nuisance = extract_nuisance_params(full_params_start, n_alpha, p, n_gamma, beta_index);
    const int d = nuisance.size();
    if (d == 0) {
        return nuisance;
    }

    VectorXd grad(d);
    for (int iter = 0; iter < maxit; ++iter) {
        edi_check_R_user_interrupt_every(iter);
        double current_ll = nuisance_loglik_grad(model, nuisance, beta_fixed, n_alpha, p, n_gamma, &grad, beta_index);
        if (grad.norm() < tol) {
            break;
        }

        MatrixXd H = nuisance_numeric_hessian_from_gradient(
            model, nuisance, beta_fixed, n_alpha, p, n_gamma, 1e-5, beta_index
        );
        FullPivLU<MatrixXd> lu(H);
        if (!lu.isInvertible()) {
            break;
        }

        VectorXd step = lu.solve(grad);
        double scale = 1.0;
        bool accepted = false;
        int step_iter = 0;
        while (scale > 1e-8) {
            edi_check_R_user_interrupt_every(step_iter++);
            VectorXd next_nuisance = nuisance - scale * step;
            double next_ll = nuisance_loglik_grad(
                model, next_nuisance, beta_fixed, n_alpha, p, n_gamma, NULL, beta_index
            );
            if (std::isfinite(next_ll) && next_ll > current_ll) {
                nuisance = next_nuisance;
                accepted = true;
                break;
            }
            scale *= 0.5;
        }

        if (!accepted || (scale * step).norm() < tol) {
            break;
        }
    }

    return nuisance;
}

static double profile_loglik_for_beta(
    const StereotypeLogitRegression& model,
    const Eigen::Ref<const VectorXd>& full_params_start,
    double beta_fixed,
    int n_alpha,
    int p,
    int n_gamma,
    int beta_index = 0
) {
    VectorXd nuisance = optimize_nuisance_given_beta(
        model, full_params_start, beta_fixed, n_alpha, p, n_gamma, 50, 1e-8, beta_index
    );
    VectorXd params = set_beta_and_pack_nuisance(nuisance, beta_fixed, n_alpha, p, n_gamma, beta_index);
    return model.loglik_grad(params, NULL);
}

static VectorXd stereotype_newton_fit(
    const StereotypeLogitRegression& model,
    int maxit,
    double tol,
    bool* converged = NULL
) {
    VectorXd params = model.initialize_params();
    const int d = params.size();
    VectorXd grad(d);
    bool did_converge = false;
    const double score_tol = std::max(tol, std::sqrt(std::max(tol, 0.0)));

    auto score_is_small = [&](const VectorXd& g) {
        return g.allFinite() && (g.norm() / std::sqrt((double)std::max(1, d))) <= score_tol;
    };

    if (converged != NULL) {
        *converged = false;
    }

    for (int iter = 0; iter < maxit; ++iter) {
        edi_check_R_user_interrupt_every(iter);
        double current_ll = model.loglik_grad(params, &grad);
        if (!std::isfinite(current_ll) || !grad.allFinite()) {
            break;
        }
        if (score_is_small(grad)) {
            did_converge = true;
            break;
        }

        MatrixXd H = numeric_hessian_from_gradient(model, params);
        FullPivLU<MatrixXd> lu(H);
        if (!lu.isInvertible()) {
            break;
        }

        VectorXd step = lu.solve(grad);
        double scale = 1.0;
        bool accepted = false;
        int step_iter = 0;

        while (scale > 1e-8) {
            edi_check_R_user_interrupt_every(step_iter++);
            VectorXd next_params = params - scale * step;
            double next_ll = model.loglik_grad(next_params, NULL);
            if (std::isfinite(next_ll) && next_ll > current_ll) {
                params = next_params;
                accepted = true;
                break;
            }
            scale *= 0.5;
        }

        if (!accepted) {
            model.loglik_grad(params, &grad);
            did_converge = score_is_small(grad);
            break;
        }

        model.loglik_grad(params, &grad);
        if (score_is_small(grad)) {
            did_converge = true;
            break;
        }

        if ((scale * step).norm() < tol) {
            break;
        }
    }

    if (!did_converge) {
        model.loglik_grad(params, &grad);
        did_converge = score_is_small(grad);
    }
    if (converged != NULL) {
        *converged = did_converge;
    }

    return params;
}

struct StereotypeObjective {
    const StereotypeLogitRegression& model;
    StereotypeObjective(const StereotypeLogitRegression& m) : model(m) {}

    double operator()(const Eigen::Ref<const VectorXd>& params, Eigen::Ref<VectorXd> grad) const {
        VectorXd g = VectorXd::Zero(params.size());
        double val = -model.loglik_grad(params, &g);
        grad = -g;
        return val;
    }

    MatrixXd hessian(const Eigen::Ref<const VectorXd>& params) const {
        return -model.loglik_hessian(params);
    }

    MatrixXd expected_hessian(const Eigen::Ref<const VectorXd>& params) const {
        return model.expected_hessian(params);
    }
};

LikelihoodFitResult fast_stereotype_logit_internal(
		const StereotypeLogitRegression& model,
		int maxit = 100,
		double tol = 1e-8,
		std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
		std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
		std::string optimization_alg = "newton_raphson",
		std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
		std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
		std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt) {
	VectorXd params = model.initialize_params();
	int n_par = params.size();
	int n_alpha = model.num_alpha();
	int p = model.num_params() - n_alpha - model.num_gamma();

	if (warm_start_params.has_value()) {
		params = *warm_start_params;
		if (params.size() != n_par) throw std::invalid_argument("warm_start_params size mismatch");
	} else if (warm_start_beta.has_value()) {
		const Eigen::VectorXd& sb = *warm_start_beta;
		if (sb.size() == p) {
			params.segment(n_alpha, p) = sb;
		}
	}
	// smart_cold_start: alpha from initialize_params() empirical log-ratios; beta/gamma = 0

	FixedParamSpec fixed_spec = make_fixed_param_spec(n_par, fixed_idx, fixed_values);
	StereotypeObjective obj(model);

	Eigen::MatrixXd info_start;
	const Eigen::MatrixXd* info_start_ptr = nullptr;
	if (warm_start_fisher_info.has_value()) {
		info_start = *warm_start_fisher_info;
		info_start_ptr = &info_start;
	}

	return optimize_fixed_likelihood(obj, params, fixed_spec, maxit, tol, optimization_alg, "newton_raphson", 0, info_start_ptr);
}

// Portable core taking raw X/y (constructs the model internally), unifying
// fast_stereotype_logit_cpp (fit only) and fast_stereotype_logit_with_var_cpp
// (fit + ssq_b_1 diagonal variance, via the same profile-likelihood fallback)
// below so a Python caller gets everything from one call.
edi::ResultMap fast_stereotype_logit_full_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    int maxit = 100,
    double tol = 1e-8,
    bool smart_cold_start = true,
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::string optimization_alg = "newton_raphson",
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
    std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
    std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
    bool estimate_only = false
) {
    (void)smart_cold_start; // matches original: only warm starts alter initialize_params()'s default

    StereotypeLogitRegression model(X, y);
    if (model.num_categories() < 2) {
        throw std::invalid_argument("Stereotype logistic regression requires at least two observed outcome categories.");
    }

    int n_alpha = model.num_alpha();
    int p = (int)X.cols();
    int n_par = model.num_params();

    LikelihoodFitResult fit = fast_stereotype_logit_internal(
        model, maxit, tol, fixed_idx, fixed_values, optimization_alg,
        warm_start_fisher_info, warm_start_params, warm_start_beta);
    VectorXd params = fit.params;

    if (estimate_only) {
        return edi::ResultMap()
            .set("b", params.segment(n_alpha, p))
            .set("alpha", params.head(n_alpha))
            .set("scores_raw", (model.num_gamma() > 0) ? params.tail(model.num_gamma()) : VectorXd(0))
            .set("params", params)
            .set("neg_loglik", fit.value)
            .set("converged", fit.converged);
    }

    MatrixXd neg_hess = -model.loglik_hessian(params);

    FixedParamSpec fixed_spec = make_fixed_param_spec(n_par, fixed_idx, fixed_values);
    MatrixXd info_free = subset_matrix(neg_hess, fixed_spec.free_idx, fixed_spec.free_idx);
    int free_j = -1;
    for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
        if (fixed_spec.free_idx[jj] == n_alpha) { free_j = jj + 1; break; }
    double ssq_b_1 = (p >= 1 && free_j > 0) ? compute_diagonal_inverse_entry(info_free, free_j) : std::numeric_limits<double>::quiet_NaN();

    // Fallback profiling logic for variance if still not finite
    if (!std::isfinite(ssq_b_1) && p >= 1 && !fixed_spec.has_fixed) {
        double beta_hat = params[n_alpha];
        double h = std::max(1e-4, 1e-3 * (std::abs(beta_hat) + 1.0));
        double ll_0 = profile_loglik_for_beta(model, params, beta_hat, n_alpha, p, model.num_gamma(), 0);
        double ll_p = profile_loglik_for_beta(model, params, beta_hat + h, n_alpha, p, model.num_gamma(), 0);
        double ll_m = profile_loglik_for_beta(model, params, beta_hat - h, n_alpha, p, model.num_gamma(), 0);
        double info_beta = -(ll_p - 2.0 * ll_0 + ll_m) / (h * h);
        if (std::isfinite(info_beta) && info_beta > 0) {
            ssq_b_1 = 1.0 / info_beta;
        }
    }

    return edi::ResultMap()
        .set("b", params.segment(n_alpha, p))
        .set("alpha", params.head(n_alpha))
        .set("scores_raw", (model.num_gamma() > 0) ? params.tail(model.num_gamma()) : VectorXd(0))
        .set("params", params)
        .set("neg_loglik", fit.value)
        .set("ssq_b_1", ssq_b_1)
        .set("ssq_b_j", ssq_b_1)
        .set("vcov", std::monostate{})
        .set("converged", fit.converged)
        .set("fisher_information", neg_hess);
}

#ifndef EDI_CORE_ONLY
//' @title Compute Stereotype Logit Score
//' @description Calculates the score vector (gradient of the log-likelihood) for a stereotype logit model.
//' @param X A numeric matrix of predictors.
//' @param y A numeric vector of responses.
//' @param params A numeric vector of parameters.
//' @return A numeric vector representing the score.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_stereotype_logit_score_cpp(const Rcpp::NumericMatrix& X,
											   const Rcpp::NumericVector& y,
											   const Rcpp::NumericVector& params) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());

	StereotypeLogitRegression model(map_X, map_y);
	Eigen::VectorXd grad(map_params.size());
	model.loglik_grad(map_params, &grad);
	return grad;
}

//' Stereotype Logit Regression Hessian, Standalone (C++)
//'
//' Computes the (analytic) Hessian matrix of the log-likelihood of the
//' stereotype (reduced-rank multinomial) logistic regression model documented
//' in full at \code{\link{fast_stereotype_logit_cpp}}, at arbitrary
//' caller-supplied \code{params} (not necessarily the MLE). Exported standalone
//' — independent of any optimizer run — for direct numerical diagnostics at a
//' specific parameter value.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_stereotype_logit_cpp}}).
//' @param y A numeric vector of categorical (nominal or ordinal) responses; only
//'   the set of distinct values matters, not their numeric coding or order.
//' @param params A numeric vector of the full joint parameter vector \eqn{[\alpha,
//'   \beta, \gamma]}, at which to evaluate the Hessian.
//' @return The Hessian matrix of the log-likelihood at \code{params}.
//' @seealso \code{\link{get_stereotype_logit_score_cpp}} for the corresponding
//'   gradient at the same point; \code{\link{fast_stereotype_logit_cpp}} for the
//'   full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_stereotype_logit_hessian_cpp(const Rcpp::NumericMatrix& X,
												 const Rcpp::NumericVector& y,
												 const Rcpp::NumericVector& params) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());

	StereotypeLogitRegression model(map_X, map_y);
	return model.loglik_hessian(map_params);
}

//' Fast Stereotype (Reduced-Rank Multinomial) Logistic Regression (C++)
//'
//' Fits Anderson's \strong{stereotype logit} model — a reduced-rank multinomial
//' logit for a categorical (nominal or ordinal) response with \eqn{K} distinct
//' observed levels, using a \strong{single} linear predictor \eqn{\eta_i =
//' x_i^\top\beta} scaled by a category-specific "score" \eqn{\phi_k \in [0, 1]}:
//' \deqn{\Pr(Y_i = k \mid x_i) = \frac{\exp(\alpha_k + \phi_k \eta_i)}
//'   {\sum_{l=1}^K \exp(\alpha_l + \phi_l \eta_i)}, \qquad \alpha_1 := 0,\ \phi_1 := 0,\ \phi_K := 1,}
//' with free intercepts \eqn{\alpha_2, \ldots, \alpha_K} and free interior scores
//' \eqn{\phi_2, \ldots, \phi_{K-1}} reparameterized via unconstrained
//' \eqn{\gamma_1, \ldots, \gamma_{K-2}} as cumulative softmax-style partial sums,
//' \eqn{\phi_{j} = \left(\sum_{r \le j-2} e^{\gamma_r}\right) \big/ \left(1 +
//' \sum_r e^{\gamma_r}\right)} for \eqn{j = 2, \ldots, K-1}, which guarantees
//' \eqn{0 = \phi_1 \le \phi_2 \le \cdots \le \phi_{K-1} \le \phi_K = 1} without an
//' explicit constraint. A single \eqn{\hat\beta} therefore governs the covariate
//' effect for every category, with the fitted \eqn{\hat\phi_k} determining how much
//' of that effect applies to category \eqn{k} — collapsing categories with similar
//' fitted scores are "stereotyped" together, which is the model's namesake use case
//' (a parsimony-inducing alternative to full multinomial or ordinal cumulative-link
//' models when categories are not clearly ordered but the covariate effect is
//' plausibly one-dimensional). \code{K = 2} reduces exactly to ordinary binary
//' logistic regression (\eqn{\phi_2 = 1} by construction, no \eqn{\gamma}
//' parameters). At least 2 distinct observed outcome categories are required; fewer
//' throws an error. Fitting optimizes the joint parameter vector \eqn{[\alpha_2,
//' \ldots, \alpha_K, \beta, \gamma_1, \ldots, \gamma_{K-2}]} via
//' \code{optimization_alg} (default \code{"newton_raphson"}), using this model's
//' analytic gradient and Hessian.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; the
//'   category intercepts \code{alpha} serve that role).
//' @param y A numeric vector of categorical (nominal or ordinal) responses; only
//'   the set of distinct values matters (mapped to \eqn{1, \ldots, K} by sorted
//'   rank), not their numeric coding or order.
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance.
//' @param smart_cold_start Present for interface parity with sibling functions but
//'   currently has \strong{no effect}: starting values always come from
//'   \code{initialize_params()} (log empirical category-count ratios for
//'   \code{alpha}, zero for \code{beta}/\code{gamma}) unless overridden by
//'   \code{warm_start_params}/\code{warm_start_beta}.
//' @param fixed_idx Optional 1-indexed positions (into the joint parameter vector,
//'   \code{alpha} first) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param optimization_alg Optimization algorithm (default \code{"newton_raphson"}).
//' @param warm_start_fisher_info Optional initial curvature matrix for the first optimizer iteration.
//' @param warm_start_params Optional starting values for the full joint parameter vector.
//'   Takes precedence over \code{warm_start_beta}.
//' @param warm_start_beta Optional starting values for \eqn{\beta} alone (ignored if
//'   \code{warm_start_params} is supplied).
//' @param estimate_only If \code{TRUE}, skip computing the observed-information matrix
//'   and return only point estimates.
//'
//' @return A list with components \code{b} (\eqn{\hat\beta}), \code{alpha} (the \eqn{K-1}
//'   free intercepts), \code{scores_raw} (the raw \eqn{\hat\gamma} reparameterization
//'   parameters, length \eqn{\max(0, K-2)}; recover \eqn{\hat\phi} from these via the
//'   cumulative-softmax formula above), \code{params} (the full fitted joint parameter
//'   vector), \code{neg_loglik}, \code{converged}, and, unless \code{estimate_only = TRUE},
//'   \code{fisher_information} (the negative Hessian of the log-likelihood at the fitted
//'   parameters — despite the name, this is the \strong{observed}, not expected,
//'   information).
//' @seealso \code{\link{fast_stereotype_logit_with_var_cpp}} for the variance-computing
//'   variant.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_stereotype_logit_cpp(const Rcpp::NumericMatrix& X, const Rcpp::NumericVector& y, int maxit = 100, double tol = 1e-8,
                                bool smart_cold_start = true,
                                Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                std::string optimization_alg = "newton_raphson",
                                Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
                                Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue,
                                Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
                                bool estimate_only = false) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

    StereotypeLogitRegression model(map_X, map_y);
    if (model.num_categories() < 2) {
        stop("Stereotype logistic regression requires at least two observed outcome categories.");
    }

    int n_alpha = model.num_alpha();
    int p = map_X.cols();

    LikelihoodFitResult fit = fast_stereotype_logit_internal(
        model, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta));
    VectorXd params = fit.params;

    if (estimate_only) {
        return edi::to_rcpp_list(edi::ResultMap()
            .set("b", params.segment(n_alpha, p))
            .set("alpha", params.head(n_alpha))
            .set("scores_raw", (model.num_gamma() > 0) ? params.tail(model.num_gamma()) : VectorXd(0))
            .set("params", params)
            .set("neg_loglik", fit.value)
            .set("converged", fit.converged));
    }
    Eigen::MatrixXd neg_hess = -model.loglik_hessian(params);
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", params.segment(n_alpha, p))
        .set("alpha", params.head(n_alpha))
        .set("scores_raw", (model.num_gamma() > 0) ? params.tail(model.num_gamma()) : VectorXd(0))
        .set("params", params)
        .set("neg_loglik", fit.value)
        .set("converged", fit.converged)
        .set("fisher_information", neg_hess));
}

//' Fast Stereotype (Reduced-Rank Multinomial) Logistic Regression with Variance (C++)
//'
//' As \code{\link{fast_stereotype_logit_cpp}} (see that page for the full stereotype
//' logit model), but always computes the observed information and the variance of
//' \eqn{\hat\beta_1} (the first, and typically only meaningfully identified,
//' regression coefficient — conventionally the treatment effect). The primary
//' variance estimate is \eqn{[(-H)^{-1}]_{\beta_1\beta_1}} from the observed
//' information (negative Hessian) at the fitted parameters. If \eqn{\beta_1} is not
//' held fixed (via \code{fixed_idx}) and that entry comes out non-finite (e.g. the
//' information matrix is singular), this function falls back to a
//' \strong{profile-likelihood} variance: it re-optimizes all nuisance parameters
//' (everything except \eqn{\beta_1}) at \eqn{\hat\beta_1}, \eqn{\hat\beta_1 \pm h}
//' (\eqn{h = \max(10^{-4}, 10^{-3}(|\hat\beta_1| + 1))}), takes the central
//' second-difference of the resulting profile log-likelihood to approximate the
//' profile information \eqn{I(\hat\beta_1)}, and reports \eqn{1/I(\hat\beta_1)} if
//' that comes out finite and positive (otherwise the variance remains \code{NA}).
//' \code{vcov} is never populated (always \code{NULL}/missing) — only the single
//' \eqn{\beta_1} variance is available from this function.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_stereotype_logit_cpp}}).
//' @param y A numeric vector of categorical (nominal or ordinal) responses; only
//'   the set of distinct values matters, not their numeric coding or order.
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance.
//' @param smart_cold_start Present for interface parity but currently has no effect;
//'   see \code{\link{fast_stereotype_logit_cpp}} Details.
//' @param fixed_idx Optional 1-indexed positions (into the joint parameter vector,
//'   \code{alpha} first) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param optimization_alg Optimization algorithm (default \code{"newton_raphson"}).
//' @param warm_start_fisher_info Optional initial curvature matrix for the first optimizer iteration.
//' @param warm_start_params Optional starting values for the full joint parameter vector.
//'   Takes precedence over \code{warm_start_beta}.
//' @param warm_start_beta Optional starting values for \eqn{\beta} alone (ignored if
//'   \code{warm_start_params} is supplied).
//' @param estimate_only Accepted for interface parity but \strong{ignored}: this function
//'   always computes the observed information and \code{ssq_b_1}/\code{ssq_b_j} regardless
//'   of its value.
//'
//' @return A list with components \code{b} (\eqn{\hat\beta}), \code{alpha} (the \eqn{K-1}
//'   free intercepts), \code{params} (the full fitted joint parameter vector),
//'   \code{ssq_b_1} and \code{ssq_b_j} (identical aliases for the variance of
//'   \eqn{\hat\beta_1}, computed as described above; \code{NA} if unavailable),
//'   \code{vcov} (always missing/\code{NULL}), \code{converged}, and
//'   \code{fisher_information} (the observed information, i.e. negative Hessian, at the
//'   fitted parameters).
//' @seealso \code{\link{fast_stereotype_logit_cpp}} for the estimate-only-capable variant
//'   and the full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_stereotype_logit_with_var_cpp(const Rcpp::NumericMatrix& X, const Rcpp::NumericVector& y, int maxit = 100, double tol = 1e-8,
                                         bool smart_cold_start = true,
                                         Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                         Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                         std::string optimization_alg = "newton_raphson",
                                         Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
                                         Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue,
                                         Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
                                         bool estimate_only = false) {

    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

    StereotypeLogitRegression model(map_X, map_y);
    if (model.num_categories() < 2) {
        stop("Stereotype logistic regression requires at least two observed outcome categories.");
    }

    int n_par = model.num_params();

    LikelihoodFitResult fit = fast_stereotype_logit_internal(
        model, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta));
    VectorXd params = fit.params;
    MatrixXd H = model.loglik_hessian(params);
    MatrixXd info = -H;

    int n_alpha = model.num_alpha();
    int p = map_X.cols();

    FixedParamSpec fixed_spec = make_fixed_param_spec(
        n_par,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));
    MatrixXd info_free = subset_matrix(info, fixed_spec.free_idx, fixed_spec.free_idx);
    int free_j = -1;
    for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
        if (fixed_spec.free_idx[jj] == n_alpha) { free_j = jj + 1; break; }
    double ssq_b_1 = (p >= 1 && free_j > 0) ? compute_diagonal_inverse_entry(info_free, free_j) : NA_REAL;
    
    // Fallback profiling logic for variance if still not finite
    if (!R_finite(ssq_b_1) && p >= 1 && !fixed_spec.has_fixed) {
        double beta_hat = params[n_alpha];
        double h = std::max(1e-4, 1e-3 * (std::abs(beta_hat) + 1.0));
        double ll_0 = profile_loglik_for_beta(model, params, beta_hat, n_alpha, p, model.num_gamma(), 0);
        double ll_p = profile_loglik_for_beta(model, params, beta_hat + h, n_alpha, p, model.num_gamma(), 0);
        double ll_m = profile_loglik_for_beta(model, params, beta_hat - h, n_alpha, p, model.num_gamma(), 0);
        double info_beta = -(ll_p - 2.0 * ll_0 + ll_m) / (h * h);
        if (R_finite(info_beta) && info_beta > 0) {
            ssq_b_1 = 1.0 / info_beta;
        }
    }

    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", params.segment(n_alpha, p))
        .set("alpha", params.head(n_alpha))
        .set("params", params)
        .set("ssq_b_1", ssq_b_1)
        .set("ssq_b_j", ssq_b_1)
        .set("vcov", std::monostate{})
        .set("converged", fit.converged)
        .set("fisher_information", info));
}

//' Stereotype Logit Profile Log-Likelihood for a Fixed Treatment Coefficient (C++)
//'
//' Computes the \strong{profile} log-likelihood of the
//' \code{\link{fast_stereotype_logit_cpp}} stereotype logit model (see that page for
//' the full model) at a caller-fixed value of \eqn{\beta_1} (the first regression
//' coefficient, conventionally the treatment effect): all other parameters
//' (intercepts \eqn{\alpha}, the remaining \eqn{\beta} columns if \eqn{p > 1}, and
//' the score reparameterization \eqn{\gamma}) are re-optimized by damped Newton's
//' method (up to 50 iterations, gradient-norm tolerance \eqn{10^{-8}}, backtracking
//' step-halving line search — both hardcoded and \strong{not} controlled by the
//' \code{maxit}/\code{tol} arguments below, which are accepted but currently
//' unused) to maximize the log-likelihood conditional on \eqn{\beta_1}, and the
//' resulting maximized log-likelihood is returned. This is the building block used
//' by \code{\link{fast_stereotype_logit_with_var_cpp}}'s profile-likelihood
//' variance fallback (finite-differencing this function's output in
//' \eqn{\beta_1}), and is exported standalone for constructing profile-likelihood
//' confidence intervals or diagnostic profile plots directly.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_stereotype_logit_cpp}}).
//' @param y A numeric vector of categorical (nominal or ordinal) responses; only
//'   the set of distinct values matters, not their numeric coding or order.
//' @param beta_fixed The fixed value at which to profile \eqn{\beta_1}.
//' @param maxit Accepted but currently unused; see Details.
//' @param tol Accepted but currently unused; see Details.
//' @param warm_start_params Optional starting values for the full joint parameter vector
//'   (used to initialize the nuisance-parameter optimization). Takes precedence over
//'   \code{warm_start_beta}.
//' @param warm_start_beta Optional starting values for \eqn{\beta} alone (ignored if
//'   \code{warm_start_params} is supplied).
//' @return The maximized profile log-likelihood at \code{beta_fixed}, a single number.
//' @seealso \code{\link{fast_stereotype_logit_with_var_cpp}}, whose profile-likelihood
//'   variance fallback calls this function three times per fallback invocation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
double fast_stereotype_profile_loglik_cpp(
    const Rcpp::NumericMatrix& X,
    const Rcpp::NumericVector& y,
    double beta_fixed,
    int maxit = 100,
    double tol = 1e-8,
    Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue,
    Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue
) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

    StereotypeLogitRegression model(map_X, map_y);
    if (model.num_categories() < 2) {
        stop("Stereotype logistic regression requires at least two observed outcome categories.");
    }

    int n_alpha = model.num_alpha();
    int p = map_X.cols();
    int n_gamma = model.num_gamma();
    int total = n_alpha + p + n_gamma;

    VectorXd params = model.initialize_params();
    std::optional<Eigen::VectorXd> warm_start_params_opt = nullable_to_optional<Eigen::VectorXd>(warm_start_params);
    std::optional<Eigen::VectorXd> warm_start_beta_opt = nullable_to_optional<Eigen::VectorXd>(warm_start_beta);
    if (warm_start_params_opt.has_value()) {
        params = *warm_start_params_opt;
        if (params.size() != total) stop("warm_start_params size mismatch");
    } else if (warm_start_beta_opt.has_value()) {
        const Eigen::VectorXd& sb = *warm_start_beta_opt;
        if (sb.size() == total) {
            params = sb;
        } else if (sb.size() == p) {
            params.segment(n_alpha, p) = sb;
        }
    }

    return profile_loglik_for_beta(model, params, beta_fixed, n_alpha, p, n_gamma, 0);
}

#ifdef _OPENMP
#include <omp.h>
#endif

// [[Rcpp::plugins(openmp)]]

//' Parallel Stereotype Logit Randomization Distribution
//'
//' @param X Matrix of covariates (without intercept or treatment).
//' @param y Numeric vector of response values (pre-null-shifted for treated).
//' @param w_mat Integer matrix of permuted treatment assignments (n x nsim).
//' @param delta Null treatment effect (additive shift).
//' @param num_cores Number of OpenMP threads.
//' @return Numeric vector of length nsim with treatment coefficients.
// [[Rcpp::export]]
NumericVector compute_stereotype_logit_distr_parallel_cpp(
	const Rcpp::NumericMatrix& X,
	const Rcpp::NumericVector& y,
	const Rcpp::IntegerMatrix& w_mat,
	double delta,
	int num_cores
) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

	int nsim = w_mat.cols();
	int n = map_y.size();
	int p_covars = map_X.cols();
	int p_full = p_covars + 1; // treatment + covars (no intercept — thresholds handle location)

	std::vector<double> results(nsim, NA_REAL);
	const int* w_ptr = w_mat.begin();

#ifdef _OPENMP
	omp_set_num_threads(num_cores);
#endif

#pragma omp parallel for schedule(static)
	for (int b = 0; b < nsim; ++b) {
		const int* w_col = w_ptr + (size_t)b * n;

		Eigen::MatrixXd X_full(n, p_full);
		Eigen::VectorXd y_shifted(n);

		for (int i = 0; i < n; ++i) {
			X_full(i, 0) = (double)w_col[i];
			for (int k = 0; k < p_covars; ++k) {
				X_full(i, 1 + k) = map_X(i, k);
			}
			y_shifted[i] = (w_col[i] == 1) ? map_y[i] + delta : map_y[i];
		}


		StereotypeLogitRegression model(X_full, y_shifted);
		if (model.num_categories() < 2) continue;

		bool converged = false;
		Eigen::VectorXd params = stereotype_newton_fit(model, 100, 1e-8, &converged);

		int n_alpha = model.num_alpha();
		// accept result even if not formally converged, matching R generate_mod behaviour
		if ((int)params.size() >= n_alpha + 1 && std::isfinite(params[n_alpha])) {
			results[b] = params[n_alpha];
		}
	}

	return wrap(results);
}
#endif // EDI_CORE_ONLY
