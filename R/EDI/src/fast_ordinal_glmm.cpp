// Ordinal Cumulative-Logit GLMM for KK designs via Gauss-Hermite quadrature.
//
// Model:  logit P(Y_ij <= k | u_i) = alpha_k - X_ij' beta - u_i
//   u_i ~ N(0, sigma^2)    (random intercept per matched pair / singleton)
//   y_ij \in {1, ..., K}

#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#endif
#include "_glmm_engine.h"
#include <cmath>
#include <vector>
#include <algorithm>
#include <optional>
#include <string>
#include <limits>
#include <stdexcept>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

namespace {

// Maps ordinal y (1..K) to indicators I(y <= k) for k=1..K-1
struct OrdinalGLMMData {
	Eigen::MatrixXd X;
	std::vector<int> y;
	std::vector<int> group_id;
	int K;
	int n_gh;
	double max_abs_log_sigma;

	int n;
	int p;
	int m_n_groups;
	std::vector<int> m_group_start;
	std::vector<int> m_group_end;
	glmm::GHRule m_gh;

	OrdinalGLMMData(const Eigen::Ref<const Eigen::MatrixXd>& X_in, const std::vector<int>& y_in, 
	                const std::vector<int>& gid_in, int K_in, int n_gh_in, double max_als)
		: K(K_in), n_gh(n_gh_in), max_abs_log_sigma(max_als), m_gh(glmm::gauss_hermite_rule(n_gh_in)) {
		n = (int)y_in.size();
		p = (int)X_in.cols();

		// Matched-pair IDs are not generally contiguous in subject order.  Sort
		// all row-aligned inputs together before constructing the contiguous
		// group layout.  The previous implementation only split the input into
		// runs of equal IDs, silently treating non-adjacent members of one pair
		// as unrelated singleton groups.
		std::vector<int> ord(n);
		std::iota(ord.begin(), ord.end(), 0);
		std::stable_sort(ord.begin(), ord.end(),
			[&](int a, int b){ return gid_in[a] < gid_in[b]; });
		X.resize(n, p);
		y.resize(n);
		group_id.resize(n);
		for (int i = 0; i < n; ++i) {
			X.row(i) = X_in.row(ord[i]);
			y[i] = y_in[ord[i]];
			group_id[i] = gid_in[ord[i]];
		}
		
		// Map the sorted group IDs to contiguous blocks.
		m_n_groups = 0;
		if (n > 0) {
			m_n_groups = 1;
			m_group_start.push_back(0);
			for (int i = 1; i < n; ++i) {
				if (group_id[i] != group_id[i - 1]) {
					m_group_end.push_back(i);
					m_group_start.push_back(i);
					m_n_groups++;
				}
			}
			m_group_end.push_back(n);
		}
	}
};

class OrdinalGLMMObjective {
	const OrdinalGLMMData& m_dat;
	VectorXd m_alpha;
	VectorXd m_eta_fixed;
	VectorXd m_log_lik_k;
	MatrixXd m_grad_k;
	VectorXd m_p_plus;
	VectorXd m_p_minus;
	VectorXd m_g_plus;
	VectorXd m_g_minus;
public:
	OrdinalGLMMObjective(const OrdinalGLMMData& dat)
		: m_dat(dat),
		  m_alpha(dat.K - 1),
		  m_eta_fixed(dat.n),
		  m_log_lik_k(dat.n_gh),
		  m_grad_k(dat.K - 1 + dat.p + 1, dat.n_gh),
		  m_p_plus(dat.K - 1 + dat.p + 1),
		  m_p_minus(dat.K - 1 + dat.p + 1),
		  m_g_plus(dat.K - 1 + dat.p + 1),
		  m_g_minus(dat.K - 1 + dat.p + 1) {}

	// par = [alpha_1, log_diff_alpha_2, ..., log_diff_alpha_{K-1}, beta_1, ..., beta_p, log_sigma]
	double operator()(const Eigen::Ref<const VectorXd>& par, Eigen::Ref<VectorXd> grad) {
		const int n_alpha = m_dat.K - 1;
		const int p = m_dat.p;
		const int total = n_alpha + p + 1;

		// Recover actual cutpoints alpha
		m_alpha[0] = par[0];
		for (int k = 1; k < n_alpha; ++k) m_alpha[k] = m_alpha[k - 1] + std::exp(par[k]);

		const auto beta = par.segment(n_alpha, p);
		const double raw_log_sigma = par[total - 1];
		if (!std::isfinite(raw_log_sigma)) {
			grad.setZero();
			return 1e100;
		}
		const double log_sigma = std::clamp(raw_log_sigma, -m_dat.max_abs_log_sigma, m_dat.max_abs_log_sigma);
		const double boundary_delta = raw_log_sigma - log_sigma;
		const double boundary_penalty_scale = 1e4;
		const bool sigma_inside_boundary = (boundary_delta == 0.0);
		const double sigma = std::exp(log_sigma);

		m_eta_fixed.noalias() = m_dat.X * beta;
		const VectorXd& nodes = m_dat.m_gh.nodes;
		const VectorXd& log_weights = m_dat.m_gh.log_norm_weights;

		double total_neg_ll = boundary_penalty_scale * boundary_delta * boundary_delta;
		grad.setZero();
		grad[total - 1] = 2.0 * boundary_penalty_scale * boundary_delta;

		for (int gi = 0; gi < m_dat.m_n_groups; ++gi) {
			const int start = m_dat.m_group_start[gi];
			const int end   = m_dat.m_group_end[gi];
			
			m_grad_k.setZero();

			for (int k = 0; k < m_dat.n_gh; ++k) {
				const double u = std::sqrt(2.0) * sigma * nodes[k];
				double ll_k = 0.0;
				for (int i = start; i < end; ++i) {
					const double eta_ij = m_eta_fixed[i] + u;
					const int y_ij = m_dat.y[i];
					
					double prob_ij;
					if (y_ij == 1) {
						prob_ij = plogis_safe(m_alpha[0] - eta_ij);
					} else if (y_ij == m_dat.K) {
						prob_ij = 1.0 - plogis_safe(m_alpha[n_alpha - 1] - eta_ij);
					} else {
						prob_ij = plogis_safe(m_alpha[y_ij - 1] - eta_ij) - plogis_safe(m_alpha[y_ij - 2] - eta_ij);
					}
					prob_ij = std::max(prob_ij, 1e-15);
					ll_k += std::log(prob_ij);

					// Gradient w.r.t. beta
					double dprob_deta = 0.0;
					if (y_ij == 1) {
						dprob_deta = -dplogis_safe(m_alpha[0] - eta_ij);
					} else if (y_ij == m_dat.K) {
						dprob_deta = dplogis_safe(m_alpha[n_alpha - 1] - eta_ij);
					} else {
						dprob_deta = dplogis_safe(m_alpha[y_ij - 2] - eta_ij) - dplogis_safe(m_alpha[y_ij - 1] - eta_ij);
					}
					m_grad_k.col(k).segment(n_alpha, p) -= (dprob_deta / prob_ij) * m_dat.X.row(i).transpose();
					
					// Gradient w.r.t. raw log_sigma (via u).  Outside the
					// numerical boundary the likelihood is evaluated at the
					// clamped value, whose derivative with respect to the raw
					// parameter is zero; only the quadratic boundary penalty
					// above contributes there.
					if (sigma_inside_boundary)
						m_grad_k(total - 1, k) -= (dprob_deta / prob_ij) * u;

					// Gradient w.r.t. alpha params
					if (y_ij == 1) {
						m_grad_k(0, k) -= dplogis_safe(m_alpha[0] - eta_ij) / prob_ij;
					} else if (y_ij == m_dat.K) {
						double d_alpha_Km1 = dplogis_safe(m_alpha[n_alpha - 1] - eta_ij);
						for (int j = 0; j < n_alpha; ++j) {
							double d_cut = (j == 0) ? 1.0 : std::exp(par[j]);
							m_grad_k(j, k) += (d_alpha_Km1 / prob_ij) * d_cut;
						}
					} else {
						// d(plogis(alpha_{y-1} - eta) - plogis(alpha_{y-2} - eta))
						double d1 = dplogis_safe(m_alpha[y_ij - 1] - eta_ij);
						double d2 = dplogis_safe(m_alpha[y_ij - 2] - eta_ij);
						for (int j = 0; j < n_alpha; ++j) {
							double d_cut = (j == 0) ? 1.0 : std::exp(par[j]);
							if (j <= y_ij - 1) m_grad_k(j, k) -= (d1 / prob_ij) * d_cut;
							if (j <= y_ij - 2) m_grad_k(j, k) += (d2 / prob_ij) * d_cut;
						}
					}
				}
				m_log_lik_k[k] = ll_k + log_weights[k];
			}
			
			double max_ll = m_log_lik_k.maxCoeff();
			double sum_exp = 0.0;
			for (int k = 0; k < m_dat.n_gh; ++k) sum_exp += std::exp(m_log_lik_k[k] - max_ll);
			double ll_gi = max_ll + std::log(sum_exp);
			total_neg_ll -= ll_gi;

			for (int k = 0; k < m_dat.n_gh; ++k) {
				double pk = std::exp(m_log_lik_k[k] - ll_gi);
				grad += pk * m_grad_k.col(k);
			}
		}
		return total_neg_ll;
	}

	MatrixXd hessian(const Eigen::Ref<const VectorXd>& par) {
		const int total = (int)par.size();
		MatrixXd H = MatrixXd::Zero(total, total);
		double h = 1e-4;
		for (int j = 0; j < total; ++j) {
			m_p_plus = par; m_p_plus[j] += h;
			(*this)(m_p_plus, m_g_plus);
			m_p_minus = par; m_p_minus[j] -= h;
			(*this)(m_p_minus, m_g_minus);
			H.col(j) = (m_g_plus - m_g_minus) / (2.0 * h);
		}
		return (H + H.transpose()) / 2.0;
	}
};

VectorXd ols_start_beta(const Eigen::Ref<const MatrixXd>& X, const Eigen::Ref<const VectorXd>& y) {
	return (X.transpose() * X).ldlt().solve(X.transpose() * y);
}

} // namespace

// Portable core. variance_boundary_hit is a bool everywhere except the
// catch(...) fallback path, where the original R export returned NA_LOGICAL
// (no boundary diagnostic is meaningful if the fit itself threw) -- that one
// branch uses std::monostate{} instead; the (still-guarded) R wrapper below
// detects it and patches in NA_LOGICAL to preserve the exact original
// contract.
edi::ResultMap fast_ordinal_glmm_internal(
	const Eigen::Ref<const Eigen::MatrixXd>& X,     // n x p, NO intercept column; treatment at column j_T (0-based)
	const Eigen::Ref<const Eigen::VectorXi>& y,     // 1-indexed ordinal outcomes, length n
	const Eigen::Ref<const Eigen::VectorXi>& group_id, // group IDs, length n (sorted internally)
	int K,                        // number of ordinal levels
	int j_T,                      // 0-based treatment column index in X
	bool smart_cold_start = true,
	bool estimate_only = false,
	int n_gh = 20,
	double max_abs_log_sigma = 8.0,
	int maxit = 300,
	double eps_g = 1e-6,
	std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
	std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
	std::string optimization_alg = "lbfgs",
	std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
	std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
	std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt
) {
	const int n = (int)X.rows();
	const int p = (int)X.cols();
	if (n <= 0 || p <= 0 || y.size() != n || group_id.size() != n)
		throw std::invalid_argument("ordinal GLMM requires non-empty, row-aligned X, y, and group_id");
	if (K < 2 || j_T < 0 || j_T >= p)
		throw std::invalid_argument("ordinal GLMM requires K >= 2 and a valid zero-based j_T");
	if (!std::isfinite(max_abs_log_sigma) || max_abs_log_sigma <= 0 ||
		!std::isfinite(eps_g) || eps_g <= 0 || maxit <= 0 || n_gh <= 0)
		throw std::invalid_argument("ordinal GLMM numerical controls must be finite and positive");
	const int n_alpha = K - 1;
	const int total = n_alpha + p + 1; // cutpoint params + betas + log_sigma
	FixedParamSpec fixed_spec = make_fixed_param_spec(total, fixed_idx, fixed_values);

	// Convert Eigen/R vectors to std::vector for OrdinalGLMMData
	std::vector<int> y_v(n), gid_v(n);
	for (int i = 0; i < n; ++i) {
		if (y[i] < 1 || y[i] > K || group_id[i] == std::numeric_limits<int>::min())
			throw std::invalid_argument("ordinal GLMM y/group_id contains an invalid value");
		y_v[i] = y[i];
		gid_v[i] = group_id[i];
	}

	OrdinalGLMMData dat(X, y_v, gid_v, K, n_gh, max_abs_log_sigma);

	// Initialize parameters
	Eigen::VectorXd par(total);
	if (warm_start_params.has_value()) {
		const Eigen::VectorXd& sv = *warm_start_params;
		if (sv.size() == total) {
			for (int i = 0; i < total; ++i) par[i] = sv[i];
		} else {
			// Fallback: zero-initialize
			par.head(n_alpha).setZero();
			par.segment(n_alpha, p).setZero();
			par[total - 1] = -3.0;
		}
	} else if (warm_start_beta.has_value()) {
		const VectorXd& sb = *warm_start_beta;
		if (sb.size() == total) {
			par = sb;
		} else if (sb.size() == p) {
			par.head(n_alpha).setZero();
			par.segment(n_alpha, p) = sb;
			par[total - 1] = -3.0;
		} else {
            par.head(n_alpha).setZero();
			par.segment(n_alpha, p).setZero();
			par[total - 1] = -3.0;
        }
	} else if (smart_cold_start) {
		// Cutpoints: alpha_1 = 0, log_diffs = 0 (evenly spaced by 1)
		par.head(n_alpha).setZero();
		// Betas: OLS on y (rough)
		Eigen::VectorXd y_double = y.cast<double>();
		par.segment(n_alpha, p) = ols_start_beta(X, y_double);
		par[total - 1] = -3.0;
	} else {
		par.head(n_alpha).setZero();
		par.segment(n_alpha, p).setZero();
		par[total - 1] = -3.0;
	}

	OrdinalGLMMObjective obj(dat);

	Eigen::MatrixXd info_start;
	const Eigen::MatrixXd* info_start_ptr = nullptr;
	if (warm_start_fisher_info.has_value()) {
		info_start = *warm_start_fisher_info;
		info_start_ptr = &info_start;
	}

	// A log-sigma start near zero variance has an almost-flat derivative and
	// can trap a single L-BFGS run.  Include the supplied/cold start, a
	// moderate-variance start, and an explicit near-zero boundary candidate;
	// retain the finite fit with the smallest objective.  When log_sigma is a
	// fixed parameter (rare, but supported by the public kernel), do not alter
	// it across starts.
	bool log_sigma_is_fixed = false;
	for (int ii = 0; ii < fixed_spec.fixed_idx.size(); ++ii)
		if (fixed_spec.fixed_idx[ii] == total - 1) log_sigma_is_fixed = true;
	std::vector<Eigen::VectorXd> starts;
	starts.push_back(par);
	if (!log_sigma_is_fixed) {
		for (double z : std::vector<double>{-1.0, 0.0, 1.0, -max_abs_log_sigma}) {
			bool duplicate = false;
			for (const auto& existing : starts)
				if (std::abs(existing[total - 1] - z) < 1e-12) duplicate = true;
			if (!duplicate) {
				Eigen::VectorXd candidate = par;
				candidate[total - 1] = z;
				starts.push_back(candidate);
			}
		}
	}

	LikelihoodFitResult best_fit;
	bool have_finite_fit = false;
	bool multistart_used_lbfgs = false;
	bool newton_polish_attempted = false;
	bool newton_polish_accepted = false;
	int newton_polish_iterations = 0;
	try {
		multistart_used_lbfgs = normalize_optimizer_algorithm(
			optimization_alg, "lbfgs", false) == "lbfgs";
		for (const auto& start_candidate : starts) {
			LikelihoodFitResult fit = optimize_fixed_likelihood(
				obj, start_candidate, fixed_spec, maxit, eps_g,
				optimization_alg, "lbfgs", 0, info_start_ptr);
			if (!std::isfinite(fit.value) || !fit.params.allFinite()) continue;
			if (!have_finite_fit || fit.value < best_fit.value) {
				best_fit = fit;
				have_finite_fit = true;
			}
		}
		if (!have_finite_fit) throw std::runtime_error("ordinal GLMM produced no finite multistart fit");

		// Polish the selected basin with a function-decrease tolerance tight
		// enough that LBFGSpp cannot call a visibly nonstationary fit converged.
		const double polish_tol = std::min(eps_g, 1e-10);
		LikelihoodFitResult polished = optimize_fixed_likelihood(
			obj, best_fit.params, fixed_spec, maxit, polish_tol,
			optimization_alg, "lbfgs", 0, nullptr);
		if (std::isfinite(polished.value) && polished.params.allFinite() &&
			polished.value <= best_fit.value + 1e-10) {
			polished.niter += best_fit.niter;
			best_fit = polished;
		}
		par = best_fit.params;
	} catch (...) {
		return edi::ResultMap()
			.set("b", par.segment(n_alpha, p))
			.set("alpha", par.head(n_alpha))
			.set("params", par)
			.set("log_sigma", par[total - 1])
			.set("ssq_b_T", std::numeric_limits<double>::quiet_NaN())
			.set("converged", false)
			.set("num_iter", maxit)
			.set("hit_iteration_cap", false)
			.set("neg_loglik", std::numeric_limits<double>::quiet_NaN())
			.set("gradient_norm", std::numeric_limits<double>::quiet_NaN())
			.set("newton_polish_attempted", newton_polish_attempted)
			.set("newton_polish_accepted", newton_polish_accepted)
			.set("newton_polish_iterations", newton_polish_iterations)
			.set("variance_boundary_hit", std::monostate{});
	}

	Eigen::VectorXd nll_gradient(total);
	double neg_ll = obj(par, nll_gradient);
	// Project the gradient at a valid near-zero variance boundary: if moving
	// into the feasible interval would increase the objective, the KKT
	// condition is satisfied even though the unconstrained derivative is not
	// exactly zero.
	const double variance_boundary_tol = 1e-4;
	const double convergence_gradient_tol = std::max(1e-5, eps_g);
	auto active_indices_and_gradient = [&](const Eigen::VectorXd& params,
			const Eigen::VectorXd& gradient) {
		std::vector<int> active_vec;
		const bool lower_variance_kkt =
			params[total - 1] <= -dat.max_abs_log_sigma + variance_boundary_tol &&
			gradient[total - 1] > 0;
		for (int ii = 0; ii < fixed_spec.free_idx.size(); ++ii) {
			const int idx = fixed_spec.free_idx[ii];
			if (!(lower_variance_kkt && idx == total - 1)) active_vec.push_back(idx);
		}
		Eigen::VectorXi active_idx(active_vec.size());
		for (int ii = 0; ii < (int)active_vec.size(); ++ii) active_idx[ii] = active_vec[ii];
		return std::make_pair(active_idx, subset_vector(gradient, active_idx));
	};

	auto active_state = active_indices_and_gradient(par, nll_gradient);
	// L-BFGS can stop normally on relative function decrease while leaving a
	// small but visible score.  Preserve it as the global/multistart search,
	// then use the objective's already-available numerical Hessian for a local
	// damped-Newton polish only when the projected score still fails the public
	// convergence threshold.  At a valid lower log-sigma boundary, omit that
	// KKT-satisfied coordinate from the Newton system.
	if (multistart_used_lbfgs && std::isfinite(neg_ll) && par.allFinite() &&
		nll_gradient.allFinite() && active_state.second.norm() > convergence_gradient_tol) {
		newton_polish_attempted = true;
		Eigen::VectorXd candidate_params = par;
		Eigen::VectorXd candidate_gradient = nll_gradient;
		double candidate_value = neg_ll;
		const int polish_maxit = std::min(maxit, 50);
		for (int iter = 0; iter < polish_maxit; ++iter) {
			edi_check_R_user_interrupt_every(iter);
			active_state = active_indices_and_gradient(candidate_params, candidate_gradient);
			const Eigen::VectorXi& active_idx = active_state.first;
			const Eigen::VectorXd& active_gradient = active_state.second;
			if (active_gradient.norm() <= convergence_gradient_tol || active_idx.size() == 0) break;

			Eigen::MatrixXd information_full = obj.hessian(candidate_params);
			if (!information_full.allFinite()) break;
			Eigen::MatrixXd information_active = subset_matrix(information_full, active_idx, active_idx);
			Eigen::LDLT<Eigen::MatrixXd> ldlt(information_active);
			if (ldlt.info() != Eigen::Success || !ldlt.isPositive()) break;
			Eigen::VectorXd step = ldlt.solve(active_gradient);
			const double predicted_decrease = active_gradient.dot(step);
			if (!step.allFinite() || !std::isfinite(predicted_decrease) || predicted_decrease <= 0) break;

			bool step_accepted = false;
			double step_scale = 1.0;
			for (int line_iter = 0; line_iter < 30; ++line_iter) {
				edi_check_R_user_interrupt_every(line_iter);
				Eigen::VectorXd trial = candidate_params;
				for (int jj = 0; jj < active_idx.size(); ++jj)
					trial[active_idx[jj]] -= step_scale * step[jj];
				trial = apply_fixed_values(trial, fixed_spec);
				Eigen::VectorXd trial_gradient(total);
				const double trial_value = obj(trial, trial_gradient);
				if (std::isfinite(trial_value) && trial.allFinite() && trial_gradient.allFinite() &&
					trial_value <= candidate_value - 1e-4 * step_scale * predicted_decrease) {
					candidate_params = trial;
					candidate_gradient = trial_gradient;
					candidate_value = trial_value;
					step_accepted = true;
					++newton_polish_iterations;
					break;
				}
				step_scale *= 0.5;
			}
			if (!step_accepted) break;
		}

		if (candidate_params.allFinite() && candidate_gradient.allFinite() &&
			std::isfinite(candidate_value) && candidate_value <= neg_ll + 1e-10 &&
			newton_polish_iterations > 0) {
			par = candidate_params;
			nll_gradient = candidate_gradient;
			neg_ll = candidate_value;
			best_fit.params = par;
			best_fit.value = neg_ll;
			best_fit.niter += newton_polish_iterations;
			newton_polish_accepted = true;
		}
	}

	active_state = active_indices_and_gradient(par, nll_gradient);
	const double gradient_norm = active_state.second.norm();
	const bool converged = std::isfinite(neg_ll) && par.allFinite() &&
		nll_gradient.allFinite() && gradient_norm <= convergence_gradient_tol;
	const bool hit_iteration_cap = !converged && best_fit.hit_iteration_cap;
	const int niter = best_fit.niter;
	// This file's boundary is the caller-configurable max_abs_log_sigma (hard
	// clamp, no separate soft-barrier zone), not the fixed 5.0 threshold used
	// by the soft-barrier GLMM families -- so the diagnostic must use dat's
	// own value rather than the shared engine's constant.
	const bool variance_boundary_hit = std::isfinite(par[total - 1]) &&
		std::abs(par[total - 1]) >= dat.max_abs_log_sigma - variance_boundary_tol;

	const int j_T_full = n_alpha + j_T;
	Eigen::MatrixXd information = obj.hessian(par);
	double ssq_b_T = std::numeric_limits<double>::quiet_NaN();
	if (!estimate_only && converged) {
		// At the near-zero variance boundary, infer beta conditional on that
		// valid boundary solution rather than trying to invert a variance-
		// parameter row/column that is necessarily nonregular.
		std::vector<int> inference_idx_vec;
		for (int ii = 0; ii < fixed_spec.free_idx.size(); ++ii) {
			const int idx = fixed_spec.free_idx[ii];
			if (!(variance_boundary_hit && par[total - 1] < 0 && idx == total - 1))
				inference_idx_vec.push_back(idx);
		}
		Eigen::VectorXi inference_idx(inference_idx_vec.size());
		int treatment_in_free = -1;
		for (int ii = 0; ii < (int)inference_idx_vec.size(); ++ii) {
			inference_idx[ii] = inference_idx_vec[ii];
			if (inference_idx_vec[ii] == j_T_full) treatment_in_free = ii;
		}
		Eigen::MatrixXd H_free = subset_matrix(information, inference_idx, inference_idx);
		Eigen::LDLT<Eigen::MatrixXd> ldlt(H_free);
		if (ldlt.info() == Eigen::Success) {
			Eigen::MatrixXd inv_free = ldlt.solve(Eigen::MatrixXd::Identity(H_free.rows(), H_free.cols()));
			if (inv_free.allFinite() && treatment_in_free >= 0 &&
				inv_free(treatment_in_free, treatment_in_free) > 0)
				ssq_b_T = inv_free(treatment_in_free, treatment_in_free);
		}
	}

	return edi::ResultMap()
		.set("b", par.segment(n_alpha, p))
		.set("alpha", par.head(n_alpha))
		.set("params", par)
		.set("log_sigma", par[total - 1])
		.set("ssq_b_T", ssq_b_T)
		.set("converged", converged)
		.set("num_iter", niter)
		.set("hit_iteration_cap", hit_iteration_cap)
		.set("neg_loglik", neg_ll)
		.set("fisher_information", information)
		.set("score", -nll_gradient)
		.set("gradient_norm", gradient_norm)
		.set("newton_polish_attempted", newton_polish_attempted)
		.set("newton_polish_accepted", newton_polish_accepted)
		.set("newton_polish_iterations", newton_polish_iterations)
		.set("variance_boundary_hit", variance_boundary_hit);
}

namespace {

struct OrdinalGLMMEvaluation {
	double neg_loglik;
	Eigen::VectorXd score;
	Eigen::MatrixXd information;
};

OrdinalGLMMEvaluation evaluate_ordinal_glmm_at_params(
	const Eigen::Ref<const Eigen::MatrixXd>& X,
	const Eigen::Ref<const Eigen::VectorXi>& y,
	const Eigen::Ref<const Eigen::VectorXi>& group_id,
	const Eigen::Ref<const Eigen::VectorXd>& params,
	int K,
	int n_gh,
	double max_abs_log_sigma,
	bool compute_information
) {
	const int n = (int)X.rows();
	const int total = (K - 1) + (int)X.cols() + 1;
	if (n <= 0 || y.size() != n || group_id.size() != n || K < 2 ||
		params.size() != total || !params.allFinite() || n_gh <= 0 ||
		!std::isfinite(max_abs_log_sigma) || max_abs_log_sigma <= 0)
		throw std::invalid_argument("invalid ordinal GLMM evaluation inputs");
	std::vector<int> y_v(n), gid_v(n);
	for (int i = 0; i < n; ++i) {
		if (y[i] < 1 || y[i] > K || group_id[i] == std::numeric_limits<int>::min())
			throw std::invalid_argument("ordinal GLMM evaluation y/group_id contains an invalid value");
		y_v[i] = y[i];
		gid_v[i] = group_id[i];
	}
	OrdinalGLMMData dat(X, y_v, gid_v, K, n_gh, max_abs_log_sigma);
	OrdinalGLMMObjective obj(dat);
	Eigen::VectorXd nll_gradient(total);
	const double neg_loglik = obj(params, nll_gradient);
	Eigen::MatrixXd information = compute_information ? obj.hessian(params) : Eigen::MatrixXd();
	return OrdinalGLMMEvaluation{neg_loglik, -nll_gradient, information};
}

} // namespace

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
NumericVector get_ordinal_glmm_score_cpp(
	const Rcpp::NumericMatrix& X,
	const Rcpp::IntegerVector& y,
	const Rcpp::IntegerVector& group_id,
	const Rcpp::NumericVector& params,
	int K,
	int n_gh = 20,
	double max_abs_log_sigma = 8.0
) {
	Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
	Eigen::Map<const Eigen::VectorXi> map_y(y.begin(), y.size());
	Eigen::Map<const Eigen::VectorXi> map_group_id(group_id.begin(), group_id.size());
	Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());
	return Rcpp::wrap(evaluate_ordinal_glmm_at_params(
		map_X, map_y, map_group_id, map_params, K, n_gh, max_abs_log_sigma, false).score);
}

// [[Rcpp::export]]
NumericMatrix get_ordinal_glmm_hessian_cpp(
	const Rcpp::NumericMatrix& X,
	const Rcpp::IntegerVector& y,
	const Rcpp::IntegerVector& group_id,
	const Rcpp::NumericVector& params,
	int K,
	int n_gh = 20,
	double max_abs_log_sigma = 8.0
) {
	Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
	Eigen::Map<const Eigen::VectorXi> map_y(y.begin(), y.size());
	Eigen::Map<const Eigen::VectorXi> map_group_id(group_id.begin(), group_id.size());
	Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());
	return Rcpp::wrap(evaluate_ordinal_glmm_at_params(
		map_X, map_y, map_group_id, map_params, K, n_gh, max_abs_log_sigma, true).information);
}

// [[Rcpp::export]]
double get_ordinal_glmm_neg_loglik_cpp(
	const Rcpp::NumericMatrix& X,
	const Rcpp::IntegerVector& y,
	const Rcpp::IntegerVector& group_id,
	const Rcpp::NumericVector& params,
	int K,
	int n_gh = 20,
	double max_abs_log_sigma = 8.0
) {
	Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
	Eigen::Map<const Eigen::VectorXi> map_y(y.begin(), y.size());
	Eigen::Map<const Eigen::VectorXi> map_group_id(group_id.begin(), group_id.size());
	Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());
	return evaluate_ordinal_glmm_at_params(
		map_X, map_y, map_group_id, map_params, K, n_gh, max_abs_log_sigma, false).neg_loglik;
}

//' Fast Ordinal Cumulative-Logit Random-Intercept GLMM via Gauss-Hermite Quadrature (C++)
//'
//' Fits a cumulative-logit ordinal mixed model with a single Gaussian random intercept
//' per group (e.g. a matched pair or singleton from a KK-style matched design):
//' \deqn{\mathrm{logit}\,\Pr(Y_{ij} \le k \mid u_i) = \alpha_k - x_{ij}^\top\beta - u_i,
//'   \qquad u_i \sim N(0, \sigma^2),}
//' for group \eqn{i}, member \eqn{j}, ordinal outcome \eqn{y_{ij} \in \{1, \ldots, K\}}, and
//' increasing cutpoints \eqn{\alpha_1 < \cdots < \alpha_{K-1}} (\code{X} carries no separate
//' intercept column — the cutpoints serve that role). The marginal likelihood for group
//' \eqn{i} integrates the random intercept out,
//' \deqn{L_i(\theta) = \int \prod_{j \in i} \Pr(Y_{ij} = y_{ij} \mid u_i) \, \phi(u_i / \sigma) \, du_i,}
//' approximated by \code{n_gh}-point Gauss-Hermite quadrature (substituting
//' \eqn{u = \sqrt{2}\,\sigma\, z} for quadrature node \eqn{z}), and optimized on the
//' log scale by directly maximizing \eqn{\sum_i \log L_i(\theta)} (via
//' \code{optimize_fixed_likelihood}, default \code{optimization_alg = "lbfgs"}) over the
//' reparameterized vector \eqn{[\alpha_1, \log(\alpha_2-\alpha_1), \ldots,
//' \log(\alpha_{K-1}-\alpha_{K-2}), \beta, \log\sigma]} — cutpoints are recovered as
//' successive partial sums of \eqn{\alpha_1} and the exponentiated log-differences, which
//' enforces \eqn{\alpha_1 < \cdots < \alpha_{K-1}} by construction rather than as a fitting
//' constraint. Rows are stably sorted by \code{group_id} inside the kernel, so
//' matched-group membership is invariant to input row order. Optimization uses
//' supplied/cold, moderate-variance, and near-zero-variance starts, retains the
//' smallest finite negative log-likelihood, and polishes that solution before
//' applying a projected-gradient convergence check. If finite multistart
//' L-BFGS stops on function decrease while its projected score remains above
//' \code{max(1e-5, eps_g)}, the kernel performs a local damped-Newton polish
//' using its numerical Hessian. A Newton trial is retained only when its
//' parameters, objective, and gradient are finite and its objective does not
//' exceed the L-BFGS objective. At a valid lower \code{log_sigma} boundary, the
//' KKT-satisfied variance coordinate is excluded from the Newton system, so
//' fixed-effect convergence can be established without rejecting a
//' near-zero random-effect variance. \code{log_sigma} is evaluated
//' within \eqn{[-\code{max\_abs\_log\_sigma},
//' \code{max\_abs\_log\_sigma}]} with a quadratic penalty on excursions beyond
//' that interval whose analytic gradient matches the bounded objective;
//' \code{variance_boundary_hit} in the
//' return value flags whether the fitted \code{log_sigma} landed at that boundary (a sign
//' the random-intercept variance is being driven to (near-)zero or is unbounded, and that
//' \code{ssq_b_T}/\code{fisher_information} should be treated with caution). The Hessian
//' used for inference is a numerical (central finite-difference, step \eqn{10^{-4}},
//' symmetrized) second derivative of the analytic gradient, not a closed-form expression.
//' At the valid near-zero variance boundary, treatment variance is computed
//' conditional on that boundary by excluding the nonregular variance-parameter
//' row and column.
//'
//' @references Pinheiro, J. C., and Bates, D. M. (1995). "Approximations to
//'   the Log-Likelihood Function in the Nonlinear Mixed-Effects Model."
//'   \emph{Journal of Computational and Graphical Statistics}, 4(1), 12-35,
//'   \doi{10.1080/10618600.1995.10474663}, for Gauss-Hermite quadrature as
//'   an approximation to the random-effect marginal likelihood integral used
//'   throughout this package's GLMM backends (\code{fast_poisson_glmm_cpp},
//'   \code{fast_logistic_glmm_cpp}, \code{fast_weibull_frailty_cpp}, and this
//'   function).
//' @param X A numeric matrix of predictors, one row per observation (member-level, not
//'   group-level); no intercept column (see Details).
//' @param y Integer vector of 1-indexed ordinal outcomes (\eqn{1, \ldots, K}), one per row of \code{X}.
//' @param group_id Integer vector of group (e.g. matched-pair) identifiers, one per row of \code{X};
//'   assumed contiguous per group after internal sorting-by-value into blocks.
//' @param K The number of ordinal levels.
//' @param j_T 0-based column index of \code{X} whose coefficient's variance (\code{ssq_b_T})
//'   should be computed — typically the treatment indicator.
//' @param smart_cold_start Logical. If \code{TRUE} and no warm start is given, initialize
//'   cutpoints evenly at 0 (all log-differences zero) and \eqn{\beta} via a naive OLS fit
//'   of \code{y} (treated as numeric) on \code{X}; \code{log_sigma} starts at \eqn{-3}.
//'   If \code{FALSE}, \eqn{\beta} instead starts at zero.
//' @param estimate_only If \code{TRUE}, skip the (converged-fit-only) covariance calculation
//'   for \code{ssq_b_T} — point estimates and the Hessian are still returned regardless.
//' @param n_gh Number of Gauss-Hermite quadrature nodes used to integrate out the random intercept.
//' @param max_abs_log_sigma Symmetric clamp bound for \code{log_sigma} during optimization (default 8).
//' @param maxit Maximum number of optimizer iterations.
//' @param eps_g Gradient-norm convergence tolerance.
//' @param warm_start_params Optional starting values for the full reparameterized vector
//'   \eqn{[\alpha_1, \log\text{-diffs}, \beta, \log\sigma]}; if its length doesn't match, falls
//'   back to zero cutpoints/\eqn{\beta} and \code{log_sigma = -3}. Takes precedence over
//'   \code{warm_start_beta} and \code{smart_cold_start}.
//' @param warm_start_beta Optional starting values either for the full parameter vector (same
//'   length as \code{warm_start_params} above) or for \eqn{\beta} alone (length \code{p}, with
//'   cutpoints zeroed and \code{log_sigma = -3}); ignored if \code{warm_start_params} is supplied.
//' @param optimization_alg Optimization algorithm (default \code{"lbfgs"}).
//' @param fixed_idx Optional 1-indexed positions (into the reparameterized parameter vector) to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param warm_start_fisher_info Optional initial curvature matrix for the first optimizer iteration.
//'
//' @return A list with components \code{b} (\eqn{\hat\beta}), \code{alpha} (the \eqn{K-1}
//'   cutpoints, recovered from the reparameterization), \code{params} (the full fitted
//'   reparameterized vector), \code{log_sigma}, \code{ssq_b_T} (variance of \code{b[j_T]},
//'   \code{NA} unless \code{estimate_only = FALSE} and the fit converged and the resulting
//'   information matrix inverts successfully), \code{converged}, \code{neg_loglik},
//'   \code{fisher_information} (the numerical Hessian, always returned), \code{score}
//'   (the log-likelihood score at the returned parameters), \code{gradient_norm},
//'   \code{newton_polish_attempted}, \code{newton_polish_accepted}, and
//'   \code{newton_polish_iterations} (diagnostics for the conditional
//'   damped-Newton fallback), and \code{variance_boundary_hit} (\code{TRUE}/\code{FALSE}, or \code{NA} if the optimizer
//'   itself threw an exception, in which case \code{converged = FALSE} and all other quantities
//'   besides \code{b}/\code{alpha}/\code{log_sigma} are \code{NA}).
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_ordinal_glmm_cpp(
	const Rcpp::NumericMatrix& X,     // n x p, NO intercept column; treatment at column j_T (0-based)
	const Rcpp::IntegerVector& y,     // 1-indexed ordinal outcomes, length n
	const Rcpp::IntegerVector& group_id, // group IDs, length n (sorted internally)
	int K,                        // number of ordinal levels
	int j_T,                      // 0-based treatment column index in X
	bool smart_cold_start = true,
	bool estimate_only = false,
	int n_gh = 20,
	double max_abs_log_sigma = 8.0,
	int maxit = 300,
	double eps_g = 1e-6,
	Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue,
	Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
	std::string optimization_alg = "lbfgs",
	Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
	Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
	Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue
) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXi> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXi> map_group_id(group_id.begin(), group_id.size());

	edi::ResultMap res = fast_ordinal_glmm_internal(
		map_X, map_y, map_group_id, K, j_T, smart_cold_start, estimate_only, n_gh,
		max_abs_log_sigma, maxit, eps_g,
		nullable_to_optional<Eigen::VectorXd>(warm_start_params),
		nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
		optimization_alg,
		nullable_to_optional<Eigen::VectorXi>(fixed_idx),
		nullable_to_optional<Eigen::VectorXd>(fixed_values),
		nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info));

	List out = edi::to_rcpp_list(res);
	if (res.get_if<std::monostate>("variance_boundary_hit")) {
		out["variance_boundary_hit"] = NA_LOGICAL;
	}
	return out;
}
#endif // EDI_CORE_ONLY
