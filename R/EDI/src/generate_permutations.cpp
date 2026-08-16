#ifdef EDI_CORE_ONLY
#include <Eigen/Dense>
#include <stdexcept>
#else
#include <RcppEigen.h>
#endif
#include "RNG.h"
#include "r_seed_draw.h"
#include <algorithm>
#include <vector>
#include <string>
#include <cmath>
#include <unordered_map>
#include <cstdint>
#include <limits>

// [[Rcpp::depends(RcppEigen)]]

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

namespace {

// Helper: which_cols_vary_subset
std::vector<int> which_cols_vary_subset_int(const MatrixXd& X, int n_rows) {
	int p = X.cols();
	std::vector<int> var_cols;
	for (int j = 0; j < p; ++j) {
		if (n_rows <= 1) continue;
		double first_val = X(0, j);
		bool varies = false;
		for (int i = 1; i < n_rows; ++i) {
			if (X(i, j) != first_val) {
				varies = true;
				break;
			}
		}
		if (varies) var_cols.push_back(j);
	}
	return var_cols;
}

// Helper: extract_submatrix
MatrixXd extract_submatrix_int(const MatrixXd& X, int n_rows, const std::vector<int>& cols) {
	MatrixXd res(n_rows, cols.size());
	for (int i = 0; i < n_rows; ++i) {
		for (size_t j = 0; j < cols.size(); ++j) {
			res(i, j) = X(i, cols[j]);
		}
	}
	return res;
}

// Helper: find_independent_cols
std::vector<int> find_independent_cols_int(
	const MatrixXd& X,
	FullPivHouseholderQR<MatrixXd>& qr
) {
	int p = X.cols();
	if (p == 0) return std::vector<int>();
	qr.compute(X);
	int rank = qr.rank();
	std::vector<int> indep_cols;
	if (rank == 0) return indep_cols;
	MatrixXi P = qr.colsPermutation().indices();
	for (int i = 0; i < rank; ++i) indep_cols.push_back(P(i));
	std::sort(indep_cols.begin(), indep_cols.end());
	return indep_cols;
}

struct AtkinsonStepData {
	bool usable = false;
	MatrixXd X_prev;
	VectorXd xt_prev;
};

// Helper: compute_atkinson_weight_internal
double compute_atkinson_weight_internal(
	const int* w_prev,
	const MatrixXd& X_prev,
	const VectorXd& xt_prev,
	int t,
	FullPivLU<MatrixXd>& lu,
	MatrixXd& design_workspace,
	MatrixXd& crossprod_workspace,
	MatrixXd& inverse_workspace,
	VectorXd& xt_workspace
) {
	int rows = t - 1;
	int p = X_prev.cols();
	int cols = p + 2;
	if (rows == 0 || cols < 2) return 0.5;

	auto XprevWT = design_workspace.topLeftCorner(rows, cols);
	for (int i = 0; i < rows; ++i) XprevWT(i, 0) = static_cast<double>(w_prev[i]);
	XprevWT.col(1).setOnes();
	XprevWT.rightCols(p) = X_prev;

	auto XwtXw = crossprod_workspace.topLeftCorner(cols, cols);
	XwtXw.noalias() = XprevWT.transpose() * XprevWT;
	lu.compute(XwtXw);
	if (!lu.isInvertible()) return 0.5;

	auto M = inverse_workspace.topLeftCorner(cols, cols);
	M.noalias() = static_cast<double>(t - 1) * lu.inverse();
	auto xt = xt_workspace.head(p + 1);
	xt(0) = 1.0;
	xt.tail(p) = xt_prev;

	double A = M.row(0).segment(1, p + 1).dot(xt);
	if (A == 0 || !std::isfinite(A)) return 0.5;

	double val = M(0, 0) / A + 1.0;
	double s_over_A_plus_one_sq = val * val;
	double prob = s_over_A_plus_one_sq / (s_over_A_plus_one_sq + 1.0);
	return std::max(0.0, std::min(1.0, prob));
}

} // namespace

// ─────────────────────────────────────────────────────────────────────────
// Portable cores (EDI_CORE_ONLY-safe): identical logic to the 9 exported
// generate_permutations_*_cpp functions below, but each takes the seed as
// an explicit parameter instead of drawing it from R's RNG internally (the
// Rcpp wrapper draws one R::unif_rand() value; a Python binding would pass
// its own seed) -- so every *_internal core below has zero R/Rcpp
// dependency. Each seeds an edi_rng::RRng (RNG.h), a portable
// re-implementation of R's own Mersenne-Twister generator, so a given seed
// produces identical draws in R and in any future binding using the same
// core and the same seed.
// ─────────────────────────────────────────────────────────────────────────

Eigen::MatrixXi generate_permutations_matching_internal(
	const Eigen::Ref<const Eigen::VectorXi>& m_vec, int nsim, double prob_T, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	int n = static_cast<int>(m_vec.size());
	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();

	int max_m = 0;
	for (int i = 0; i < n; ++i) if (m_vec[i] > max_m) max_m = m_vec[i];

	std::vector<std::vector<int>> pairs(static_cast<std::size_t>(max_m));
	std::vector<int> reservoir;
	for (int i = 0; i < n; ++i) {
		int m = m_vec[i];
		if (m > 0) pairs[static_cast<std::size_t>(m - 1)].push_back(i);
		else reservoir.push_back(i);
	}

	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		for (int i : reservoir) w_col[i] = (rng.unif_rand() < prob_T) ? 1 : 0;
		for (int m = 0; m < max_m; ++m) {
			const auto& pair = pairs[static_cast<std::size_t>(m)];
			if (pair.size() == 2) {
				int first_is_T = (rng.unif_rand() < prob_T) ? 1 : 0;
				w_col[pair[0]] = first_is_T;
				w_col[pair[1]] = 1 - first_is_T;
			} else if (pair.size() == 1) {
				w_col[pair[0]] = (rng.unif_rand() < prob_T) ? 1 : 0;
			}
		}
	}
	return w_mat;
}

Eigen::MatrixXi generate_permutations_bernoulli_internal(int n, int nsim, double prob_T, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();
	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		for (int i = 0; i < n; ++i) w_col[i] = (rng.unif_rand() < prob_T) ? 1 : 0;
	}
	return w_mat;
}

Eigen::MatrixXi generate_permutations_ibcrd_internal(int n, int nsim, double prob_T, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();
	int n_T = static_cast<int>(std::round(n * prob_T));
	std::vector<int> w_base(static_cast<std::size_t>(n));
	for (int i = 0; i < n; ++i) w_base[static_cast<std::size_t>(i)] = (i < n_T) ? 1 : 0;
	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		std::vector<int> w_shuffled = w_base;
		std::shuffle(w_shuffled.begin(), w_shuffled.end(), rng);
		for (int i = 0; i < n; ++i) w_col[i] = w_shuffled[static_cast<std::size_t>(i)];
	}
	return w_mat;
}

Eigen::MatrixXi generate_permutations_blocking_internal(
	int n, int nsim, double prob_T, const std::vector<std::vector<int>>& strata_indices, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();
	int num_strata = static_cast<int>(strata_indices.size());
	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		for (int s = 0; s < num_strata; ++s) {
			const std::vector<int>& idxs = strata_indices[static_cast<std::size_t>(s)];
			int m = static_cast<int>(idxs.size());
			int n_T = static_cast<int>(std::round(m * prob_T));
			std::vector<int> w_stratum(static_cast<std::size_t>(m));
			for (int i = 0; i < m; ++i) w_stratum[static_cast<std::size_t>(i)] = (i < n_T) ? 1 : 0;
			std::shuffle(w_stratum.begin(), w_stratum.end(), rng);
			for (int i = 0; i < m; ++i) w_col[idxs[static_cast<std::size_t>(i)] - 1] = w_stratum[static_cast<std::size_t>(i)];
		}
	}
	return w_mat;
}

Eigen::MatrixXi generate_permutations_efron_internal(
	int n, int nsim, double prob_T, double weighted_coin_prob, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();
	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		int n_T = 0, n_C = 0;
		for (int i = 0; i < n; ++i) {
			double p;
			double sT = n_T * prob_T, sC = n_C * (1.0 - prob_T);
			if (sT > sC) p = 1.0 - weighted_coin_prob;
			else if (sT < sC) p = weighted_coin_prob;
			else p = prob_T;
			if (rng.unif_rand() < p) { w_col[i] = 1; n_T++; }
			else { w_col[i] = 0; n_C++; }
		}
	}
	return w_mat;
}

Eigen::MatrixXi generate_permutations_atkinson_internal(
	const Eigen::Ref<const Eigen::MatrixXd>& X, int n, int p_raw, double prob_T, int nsim, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();
	int bernoulli_threshold = p_raw + 2 + 1;

	// The varying/independent covariate columns depend only on X and t, not on
	// the simulated assignments. Compute each QR and processed design once.
	std::vector<AtkinsonStepData> step_data(static_cast<std::size_t>(n));
	FullPivHouseholderQR<MatrixXd> qr_workspace;
	for (int t = bernoulli_threshold + 1; t <= n; ++t) {
		std::vector<int> var_cols = which_cols_vary_subset_int(X, t);
		if (var_cols.empty()) continue;
		MatrixXd X_var = extract_submatrix_int(X, t - 1, var_cols);
		std::vector<int> indep_cols = find_independent_cols_int(X_var, qr_workspace);
		if (indep_cols.empty()) continue;

		AtkinsonStepData& step = step_data[static_cast<std::size_t>(t - 1)];
		step.X_prev.resize(t - 1, static_cast<int>(indep_cols.size()));
		step.xt_prev.resize(static_cast<int>(indep_cols.size()));
		for (int i = 0; i < t - 1; ++i) {
			for (std::size_t j = 0; j < indep_cols.size(); ++j) {
				step.X_prev(i, static_cast<int>(j)) = X_var(i, indep_cols[j]);
			}
		}
		for (std::size_t j = 0; j < indep_cols.size(); ++j) {
			step.xt_prev(static_cast<int>(j)) = X(t - 1, var_cols[indep_cols[j]]);
		}
		step.usable = true;
	}

	const int max_cols = static_cast<int>(X.cols()) + 2;
	FullPivLU<MatrixXd> lu_workspace;
	MatrixXd design_workspace(n, max_cols);
	MatrixXd crossprod_workspace(max_cols, max_cols);
	MatrixXd inverse_workspace(max_cols, max_cols);
	VectorXd xt_workspace(max_cols - 1);

	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		for (int t = 1; t <= n; ++t) {
			if (t <= bernoulli_threshold) {
				w_col[t - 1] = (rng.unif_rand() < prob_T) ? 1 : 0;
				continue;
			}
			const AtkinsonStepData& step = step_data[static_cast<std::size_t>(t - 1)];
			if (!step.usable) { w_col[t - 1] = (rng.unif_rand() < prob_T) ? 1 : 0; continue; }
			double p = compute_atkinson_weight_internal(
				w_col, step.X_prev, step.xt_prev, t, lu_workspace,
				design_workspace, crossprod_workspace, inverse_workspace, xt_workspace);
			w_col[t - 1] = (rng.unif_rand() < p) ? 1 : 0;
		}
	}
	return w_mat;
}

Eigen::MatrixXi generate_permutations_pocock_simon_internal(
	const Eigen::Ref<const Eigen::MatrixXi>& x_levels_matrix, int num_levels_total,
	const Eigen::Ref<const Eigen::VectorXd>& weights, double p_best, double prob_T, int nsim, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	int n = static_cast<int>(x_levels_matrix.rows());
	int num_covs = static_cast<int>(x_levels_matrix.cols());
	if (num_levels_total <= 0) throw std::invalid_argument("num_levels_total must be positive");
	if (weights.size() != num_covs) throw std::invalid_argument("weights length must match the number of covariates");

	// Convert the input matrix's one-based global level rows to a cache-friendly,
	// zero-based row-major buffer once, validating before any pointer indexing.
	std::vector<int> level_rows(static_cast<std::size_t>(n) * static_cast<std::size_t>(num_covs));
	for (int i = 0; i < n; ++i) {
		for (int j = 0; j < num_covs; ++j) {
			const int row_idx = x_levels_matrix(i, j) - 1;
			if (row_idx < 0 || row_idx >= num_levels_total) {
				throw std::invalid_argument("x_levels_matrix contains a level index outside 1..num_levels_total");
			}
			level_rows[static_cast<std::size_t>(i) * static_cast<std::size_t>(num_covs) + static_cast<std::size_t>(j)] = row_idx;
		}
	}

	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();
	const double* weights_ptr = weights.data();
	std::vector<int> counts(static_cast<std::size_t>(num_levels_total) * 2);

	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		std::fill(counts.begin(), counts.end(), 0);

		for (int i = 0; i < n; ++i) {
			const int* subject_levels = level_rows.data() + static_cast<std::size_t>(i) * static_cast<std::size_t>(num_covs);

			double G[2] = {0.0, 0.0};
			for (int k = 0; k < 2; ++k) {
				double G_k = 0.0;
				for (int j = 0; j < num_covs; ++j) {
					const int row_idx = subject_levels[j];
					double c0 = counts[static_cast<std::size_t>(row_idx) * 2] + (k == 0 ? 1 : 0);
					double c1 = counts[static_cast<std::size_t>(row_idx) * 2 + 1] + (k == 1 ? 1 : 0);
					double m = (c0 + c1) / 2.0;
					double var = (c0-m)*(c0-m) + (c1-m)*(c1-m); // Variance proportional
					G_k += weights_ptr[j] * var;
				}
				G[k] = G_k;
			}

			int best_trt = (G[1] < G[0]) ? 1 : (G[0] < G[1] ? 0 : ((rng.unif_rand() < prob_T) ? 1 : 0));
			int assigned_w = (rng.unif_rand() < p_best) ? best_trt : (1 - best_trt);

			w_col[i] = assigned_w;
			for (int j = 0; j < num_covs; ++j) {
				counts[static_cast<std::size_t>(subject_levels[j]) * 2 + static_cast<std::size_t>(assigned_w)]++;
			}
		}
	}
	return w_mat;
}

Eigen::MatrixXi generate_permutations_cluster_internal(
	int n, int nsim, double prob_T, const std::vector<std::vector<int>>& cluster_indices, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();
	int num_clusters = static_cast<int>(cluster_indices.size());

	// Flatten the input once. Offsets retain cluster order and allow overlapping
	// clusters to preserve the original last-write-wins behavior.
	std::vector<std::size_t> cluster_offsets(static_cast<std::size_t>(num_clusters) + 1);
	std::vector<int> subject_indices;
	subject_indices.reserve(static_cast<std::size_t>(n));
	for (int c = 0; c < num_clusters; ++c) {
		cluster_offsets[static_cast<std::size_t>(c)] = subject_indices.size();
		const std::vector<int>& idxs = cluster_indices[static_cast<std::size_t>(c)];
		for (std::size_t i = 0; i < idxs.size(); ++i) {
			const int subject = idxs[i] - 1;
			if (subject < 0 || subject >= n) throw std::invalid_argument("cluster_indices contains an index outside 1..n");
			subject_indices.push_back(subject);
		}
	}
	cluster_offsets[static_cast<std::size_t>(num_clusters)] = subject_indices.size();

	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		for (int c = 0; c < num_clusters; ++c) {
			int w_cluster = (rng.unif_rand() < prob_T) ? 1 : 0;
			const std::size_t begin = cluster_offsets[static_cast<std::size_t>(c)];
			const std::size_t end = cluster_offsets[static_cast<std::size_t>(c + 1)];
			for (std::size_t i = begin; i < end; ++i) w_col[subject_indices[i]] = w_cluster;
		}
	}
	return w_mat;
}

Eigen::MatrixXi generate_permutations_spbr_internal(
	const std::vector<std::string>& strata_keys, int block_size, double prob_T, int nsim, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	int n = static_cast<int>(strata_keys.size());
	Eigen::MatrixXi w_mat(n, nsim);
	int* w_ptr = w_mat.data();

	int n_T_block = static_cast<int>(std::round(block_size * prob_T));

	// Pre-convert string keys to dense integer IDs once — eliminates per-sim string map lookups
	std::unordered_map<std::string, int> key_to_id;
	key_to_id.reserve(64);
	std::vector<int> strata_ids(static_cast<std::size_t>(n));
	int num_strata = 0;
	for (int i = 0; i < n; ++i) {
		auto result = key_to_id.emplace(strata_keys[static_cast<std::size_t>(i)], num_strata);
		if (result.second) ++num_strata;
		strata_ids[static_cast<std::size_t>(i)] = result.first->second;
	}

	// Base block shuffled per new block; reuse allocation across simulations
	std::vector<int> base_block(static_cast<std::size_t>(block_size));
	for (int k = 0; k < block_size; ++k) base_block[static_cast<std::size_t>(k)] = (k < n_T_block) ? 1 : 0;

	// Persistent strata state — clear() at top of each simulation keeps capacity
	std::vector<std::vector<int>> strata_states(static_cast<std::size_t>(num_strata));

	for (int b = 0; b < nsim; ++b) {
		int* w_col = w_ptr + (size_t)b * n;
		for (auto& v : strata_states) v.clear();

		for (int i = 0; i < n; ++i) {
			int sid = strata_ids[static_cast<std::size_t>(i)];
			if (strata_states[static_cast<std::size_t>(sid)].empty()) {
				strata_states[static_cast<std::size_t>(sid)] = base_block;
				std::shuffle(strata_states[static_cast<std::size_t>(sid)].begin(), strata_states[static_cast<std::size_t>(sid)].end(), rng);
			}
			w_col[i] = strata_states[static_cast<std::size_t>(sid)].back();
			strata_states[static_cast<std::size_t>(sid)].pop_back();
		}
	}
	return w_mat;
}

#ifndef EDI_CORE_ONLY
//' @description Every generate_permutations_*_cpp function below is seeded
//'   from one R::unif_rand() draw into edi_rng::RRng (RNG.h), a portable
//'   re-implementation of R's own Mersenne-Twister generator -- a given
//'   seed therefore produces identical draws in R and in any future binding
//'   (e.g. Python) using the same core and the same seed.
// [[Rcpp::export]]
List generate_permutations_matching_cpp(const IntegerVector& m_vec, int nsim, double prob_T) {
	Eigen::Map<const Eigen::VectorXi> m_vec_map(m_vec.begin(), m_vec.size());
	Eigen::MatrixXi w_mat = generate_permutations_matching_internal(m_vec_map, nsim, prob_T, edi_rng::draw_seed_from_r());
	return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue); // Assume m_vec is fixed for KK randomization test
}

//' @description See generate_permutations_matching_cpp for the reproducibility
//'   note that applies to every function in this file.
// [[Rcpp::export]]
List generate_permutations_bernoulli_cpp(int n, int nsim, double prob_T) {
	Eigen::MatrixXi w_mat = generate_permutations_bernoulli_internal(n, nsim, prob_T, edi_rng::draw_seed_from_r());
	return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue);
}

//' @description See generate_permutations_matching_cpp for the reproducibility
//'   note that applies to every function in this file.
// [[Rcpp::export]]
List generate_permutations_ibcrd_cpp(int n, int nsim, double prob_T) {
	Eigen::MatrixXi w_mat = generate_permutations_ibcrd_internal(n, nsim, prob_T, edi_rng::draw_seed_from_r());
	return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue);
}

//' @description See generate_permutations_matching_cpp for the reproducibility
//'   note that applies to every function in this file.
// [[Rcpp::export]]
List generate_permutations_blocking_cpp(int n, int nsim, double prob_T, List strata_indices) {
	std::vector<std::vector<int>> strata(strata_indices.size());
	for (int s = 0; s < strata_indices.size(); ++s) {
		IntegerVector idxs = strata_indices[s];
		strata[static_cast<std::size_t>(s)].assign(idxs.begin(), idxs.end());
	}
	Eigen::MatrixXi w_mat = generate_permutations_blocking_internal(n, nsim, prob_T, strata, edi_rng::draw_seed_from_r());
	return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue);
}

//' @description See generate_permutations_matching_cpp for the reproducibility
//'   note that applies to every function in this file.
// [[Rcpp::export]]
List generate_permutations_efron_cpp(int n, int nsim, double prob_T, double weighted_coin_prob) {
	Eigen::MatrixXi w_mat = generate_permutations_efron_internal(n, nsim, prob_T, weighted_coin_prob, edi_rng::draw_seed_from_r());
	return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue);
}

//' @description See generate_permutations_matching_cpp for the reproducibility
//'   note that applies to every function in this file.
// [[Rcpp::export]]
List generate_permutations_atkinson_cpp(SEXP X_sexp, int n, int p_raw, double prob_T, int nsim) {
	Rcpp::NumericMatrix X_r(X_sexp);
	Eigen::Map<const Eigen::MatrixXd> X(X_r.begin(), X_r.nrow(), X_r.ncol());
	Eigen::MatrixXi w_mat = generate_permutations_atkinson_internal(X, n, p_raw, prob_T, nsim, edi_rng::draw_seed_from_r());
	return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue);
}

//' @description See generate_permutations_matching_cpp for the reproducibility
//'   note that applies to every function in this file.
// [[Rcpp::export]]
List generate_permutations_pocock_simon_cpp(const IntegerMatrix& x_levels_matrix, int num_levels_total, const NumericVector& weights, double p_best, double prob_T, int nsim) {
	Eigen::Map<const Eigen::MatrixXi> x_levels_map(x_levels_matrix.begin(), x_levels_matrix.nrow(), x_levels_matrix.ncol());
	Eigen::Map<const Eigen::VectorXd> weights_map(weights.begin(), weights.size());
	try {
		Eigen::MatrixXi w_mat = generate_permutations_pocock_simon_internal(
			x_levels_map, num_levels_total, weights_map, p_best, prob_T, nsim, edi_rng::draw_seed_from_r());
		return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue);
	} catch (const std::invalid_argument& e) {
		stop(e.what());
	}
}

//' @description See generate_permutations_matching_cpp for the reproducibility
//'   note that applies to every function in this file.
// [[Rcpp::export]]
List generate_permutations_cluster_cpp(int n, int nsim, double prob_T, List cluster_indices) {
	std::vector<std::vector<int>> clusters(cluster_indices.size());
	for (int c = 0; c < cluster_indices.size(); ++c) {
		IntegerVector idxs = cluster_indices[c];
		clusters[static_cast<std::size_t>(c)].assign(idxs.begin(), idxs.end());
	}
	try {
		Eigen::MatrixXi w_mat = generate_permutations_cluster_internal(n, nsim, prob_T, clusters, edi_rng::draw_seed_from_r());
		return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue);
	} catch (const std::invalid_argument& e) {
		stop(e.what());
	}
}

//' @description See generate_permutations_matching_cpp for the reproducibility
//'   note that applies to every function in this file.
// [[Rcpp::export]]
List generate_permutations_spbr_cpp(const CharacterVector& strata_keys, int block_size, double prob_T, int nsim) {
	std::vector<std::string> keys(strata_keys.size());
	for (int i = 0; i < strata_keys.size(); ++i) {
		keys[static_cast<std::size_t>(i)] = as<std::string>(strata_keys[i]);
	}
	Eigen::MatrixXi w_mat = generate_permutations_spbr_internal(keys, block_size, prob_T, nsim, edi_rng::draw_seed_from_r());
	return List::create(_["w_mat"] = w_mat, _["m_mat"] = R_NilValue);
}
#endif // EDI_CORE_ONLY
