// Helpers for DesignFixedRerandomization.
//
// complete_randomization_forced_balanced_cpp : r balanced draws (n/2 treated), returns r×n
// complete_randomization_imbalanced_cpp      : r draws with nT treated, returns r×n
// compute_objective_vals_cpp                 : per-row objective value for an r×n indicTs matrix
// rerandomization_search_cpp                 : parallel rejection sampler; returns n×k (k<=r)
//   matrix of allocations whose objective value is <= cutoff, using at most max_draws total
//   random draws. Uses RcppEigen M-matrix trick for SIMD-optimized objective evaluation and
//   OpenMP for parallel draw generation.

#include <RcppEigen.h>
#include "RNG.h"
#ifdef _OPENMP
#include <omp.h>
#endif
// [[Rcpp::depends(RcppEigen)]]

#include <Rcpp.h>
#include <chrono>
#include <cmath>
#include <atomic>
#include <numeric>
#include <algorithm>

using Eigen::MatrixXd;
using Eigen::VectorXd;
using Eigen::RowVectorXd;
using Eigen::LLT;
using Eigen::Success;

// ── Helpers shared by the simple randomization functions ────────────────────

// edi_rng::RRng (RNG.h), not std::default_random_engine: the C++ standard
// leaves default_random_engine's actual algorithm implementation-defined,
// so it isn't even guaranteed to produce the same sequence for the same
// seed across different compilers/standard libraries -- RRng is a fixed,
// portable re-implementation of R's own Mersenne-Twister, giving both a
// real cross-platform guarantee and cross-language matching with any
// future binding using the same core and the same seed.
static edi_rng::RRng make_rng(int seed) {
    std::uint32_t s = (seed == NA_INTEGER)
        ? static_cast<std::uint32_t>(
              std::chrono::system_clock::now().time_since_epoch().count())
        : static_cast<std::uint32_t>(seed);
    return edi_rng::RRng(s);
}

static void shuffle_vec(std::vector<int>& v, edi_rng::RRng& rng) {
    for (int i = static_cast<int>(v.size()) - 1; i > 0; i--) {
        std::swap(v[i], v[static_cast<int>(edi_rng::bounded_rand(rng, static_cast<std::uint32_t>(i + 1)))]);
    }
}

// [[Rcpp::export]]
Rcpp::IntegerMatrix complete_randomization_forced_balanced_cpp(int n, int r, int seed) {
    edi_rng::RRng rng = make_rng(seed);
    Rcpp::IntegerMatrix out(r, n);
    std::vector<int> v(n, 0);
    int nT = n / 2;
    for (int i = 0; i < nT; i++) v[i] = 1;
    for (int row = 0; row < r; row++) {
        shuffle_vec(v, rng);
        for (int j = 0; j < n; j++) out(row, j) = v[j];
    }
    return out;
}

// [[Rcpp::export]]
Rcpp::IntegerMatrix complete_randomization_imbalanced_cpp(int n, int nT, int r, int seed) {
    edi_rng::RRng rng = make_rng(seed);
    Rcpp::IntegerMatrix out(r, n);
    std::vector<int> v(n, 0);
    for (int i = 0; i < nT; i++) v[i] = 1;
    for (int row = 0; row < r; row++) {
        shuffle_vec(v, rng);
        for (int j = 0; j < n; j++) out(row, j) = v[j];
    }
    return out;
}

// [[Rcpp::export]]
Rcpp::NumericVector compute_objective_vals_cpp(
    const Rcpp::NumericMatrix& X,
    const Rcpp::IntegerMatrix& indicTs,
    std::string         objective,
    Rcpp::Nullable<Rcpp::NumericMatrix> inv_cov_X = R_NilValue
) {
    int n = X.nrow();
    int p = X.ncol();
    int r = indicTs.nrow();
    const bool abs_mode = (objective == "abs_sum_diff");
    const bool mahal_mode = (objective == "mahal_dist");

    if (indicTs.ncol() != n) {
        Rcpp::stop("indicTs must have ncol(indicTs) == nrow(X)");
    }
    if (!abs_mode && !mahal_mode) {
        Rcpp::stop("objective must be 'abs_sum_diff' or 'mahal_dist'");
    }

    std::vector<double> sum_all(p, 0.0), sumsq_all(p, 0.0);
    for (int i = 0; i < n; i++)
        for (int j = 0; j < p; j++) {
            double x = X(i, j);
            sum_all[j]   += x;
            sumsq_all[j] += x * x;
        }

    std::vector<double> sd_all;
    if (abs_mode) {
        sd_all.resize(p);
        for (int j = 0; j < p; j++) {
            double var = (sumsq_all[j] - sum_all[j] * sum_all[j] / n) / (n - 1);
            sd_all[j] = std::sqrt(std::max(var, 0.0));
        }
    }

    Rcpp::NumericMatrix Sinv;
    if (mahal_mode) {
        if (inv_cov_X.isNull()) Rcpp::stop("inv_cov_X required for mahal_dist");
        Sinv = Rcpp::NumericMatrix(inv_cov_X);
    }

    Rcpp::NumericVector vals(r);
    std::vector<double> sum_T(static_cast<std::size_t>(r) * p, 0.0);
    std::vector<int> nT_by_row(r, 0);
    std::vector<double> x_row(p), diff(p);
    const int* indic_ptr = indicTs.begin();
    const double* x_ptr = X.begin();

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < p; j++) {
            x_row[j] = x_ptr[i + static_cast<std::size_t>(j) * n];
        }
        const int* indic_col = indic_ptr + static_cast<std::size_t>(i) * r;
        for (int row = 0; row < r; row++) {
            if (indic_col[row] == 1) {
                ++nT_by_row[row];
                double* row_sum_T = sum_T.data() + static_cast<std::size_t>(row) * p;
                for (int j = 0; j < p; j++) row_sum_T[j] += x_row[j];
            }
        }
    }

    for (int row = 0; row < r; row++) {
        const int nT = nT_by_row[row];
        int nC = n - nT;
        const double* row_sum_T = sum_T.data() + static_cast<std::size_t>(row) * p;
        for (int j = 0; j < p; j++)
            diff[j] = row_sum_T[j] / nT - (sum_all[j] - row_sum_T[j]) / nC;

        if (abs_mode) {
            double v = 0.0;
            for (int j = 0; j < p; j++) v += std::fabs(diff[j] / sd_all[j]);
            vals[row] = v;
        } else {
            double v = 0.0;
            for (int i = 0; i < p; i++)
                for (int k = 0; k < p; k++) v += diff[i] * Sinv(i, k) * diff[k];
            vals[row] = v;
        }
    }
    return vals;
}

// ── Parallel rejection-sampling rerandomization search ──────────────────────
//
// Generates balanced random allocations in parallel (OpenMP), evaluates the
// objective using the same M-matrix / Eigen SIMD path as the greedy search,
// and collects those whose objective value <= cutoff until r are found or
// max_draws is exhausted.
//
// Returns an n×k IntegerMatrix (k <= r).  The caller errors when k < r (too few
// acceptable draws found within max_draws).

// [[Rcpp::export]]
Rcpp::IntegerMatrix rerandomization_search_cpp(
    const Eigen::Map<Eigen::MatrixXd> X_raw,
    const int                         r,
    const std::string&                objective,
    const double                      cutoff,
    const int                         max_draws
) {
    const int n  = static_cast<int>(X_raw.rows());
    const int p  = static_cast<int>(X_raw.cols());
    const int nt = n / 2;

    // ── Build M (p×n): f = ‖M*(2w−1)‖₁  or  ‖M*(2w−1)‖² ───────────────────
    RowVectorXd col_means = X_raw.colwise().mean();
    MatrixXd    X         = X_raw.rowwise() - col_means;

    MatrixXd M(p, n);
    bool abs_mode = true;

    if (objective == "mahal_dist") {
        MatrixXd cov_mat = (X.transpose() * X) / std::max(1, n - 1);
        LLT<MatrixXd> llt(cov_mat);
        if (llt.info() == Success) {
            M        = llt.matrixL().solve(X.transpose()) / static_cast<double>(n);
            abs_mode = false;
        }
        // singular covariance → fall through to abs_sum_diff
    }

    if (abs_mode) {
        VectorXd inv_sd(p);
        for (int j = 0; j < p; j++) {
            double var = X.col(j).squaredNorm() / std::max(1, n - 1);
            inv_sd[j]  = (var < 1e-24) ? 1.0 : 1.0 / std::sqrt(var);
        }
        M = (X * inv_sd.asDiagonal()).transpose() / static_cast<double>(n);
    }

    // ── One master seed from R, then a deterministic stream per candidate ───
    int nthreads = 1;
#ifdef _OPENMP
    nthreads = omp_get_max_threads();
#endif
    std::uint64_t master_seed;
    GetRNGstate();
    master_seed = static_cast<std::uint64_t>(edi_rng::seed_from_unif01(::unif_rand()));
    PutRNGstate();

    // A candidate is determined by its draw index, not by the worker which
    // happens to evaluate it.  This is what makes accepted allocations and
    // their order invariant to OpenMP scheduling and thread count.
    const auto candidate_is_accepted = [&](int draw, std::vector<int>& w,
                                           std::vector<int>& order, VectorXd& dbl_w,
                                           VectorXd& d) {
        edi_rng::RRng rng(edi_rng::seed_for_index(master_seed, static_cast<std::uint64_t>(draw)));
        std::iota(order.begin(), order.end(), 0);
        edi_rng::fisher_yates_shuffle(order.begin(), order.end(), rng);
        std::fill(w.begin(), w.end(), 0);
        for (int i = 0; i < nt; i++) w[static_cast<std::size_t>(order[static_cast<std::size_t>(i)])] = 1;

        for (int i = 0; i < n; i++) dbl_w[i] = 2.0 * static_cast<double>(w[static_cast<std::size_t>(i)]) - 1.0;
        d.noalias() = M * dbl_w;
        const double f = abs_mode ? d.lpNorm<1>() : d.squaredNorm();
        return f <= cutoff;
    };

    // ── Shared result storage ────────────────────────────────────────────────
    // Pre-allocate n×r; only the first `found` columns are valid on return.
    Rcpp::IntegerMatrix result(n, r);
    const bool use_sequential = (nthreads <= 1);

    if (use_sequential) {
        std::vector<int> w(n), order(n);
        VectorXd dbl_w(n), d(p);
        int found = 0;

        for (int draw = 0; draw < max_draws && found < r; draw++) {
            if (candidate_is_accepted(draw, w, order, dbl_w, d)) {
                for (int i = 0; i < n; i++) result(i, found) = w[static_cast<std::size_t>(i)];
                ++found;
            }
        }

        if (found == r) return result;
        Rcpp::IntegerMatrix trimmed(n, found);
        for (int j = 0; j < found; j++)
            for (int i = 0; i < n; i++) trimmed(i, j) = result(i, j);
        return trimmed;
    }

    int found = 0;
    const int chunk_size = 64;

    // Complete a deterministic prefix of fixed-size blocks at a time.  A
    // wave has at most one block per worker, so it retains early stopping
    // (at most nthreads * chunk_size extra candidates) without allowing OS
    // scheduling to decide which accepted allocation claims an output slot.
    for (int first_block = 0; found < r && first_block * chunk_size < max_draws; ) {
        const int blocks_remaining = (max_draws - first_block * chunk_size + chunk_size - 1) / chunk_size;
        const int blocks_in_wave = std::min(nthreads, blocks_remaining);
        std::vector<std::vector<std::vector<int>>> accepted_by_block(
            static_cast<std::size_t>(blocks_in_wave));

#pragma omp parallel for schedule(static)
        for (int b = 0; b < blocks_in_wave; ++b) {
            const int start = (first_block + b) * chunk_size;
            const int end = std::min(max_draws, start + chunk_size);
            std::vector<int> w(n), order(n);
            VectorXd dbl_w(n), d(p);
            for (int draw = start; draw < end; ++draw) {
                if (candidate_is_accepted(draw, w, order, dbl_w, d)) {
                    accepted_by_block[static_cast<std::size_t>(b)].push_back(w);
                }
            }
        }

        for (int b = 0; b < blocks_in_wave && found < r; ++b) {
            for (const std::vector<int>& w : accepted_by_block[static_cast<std::size_t>(b)]) {
                for (int i = 0; i < n; ++i) result(i, found) = w[static_cast<std::size_t>(i)];
                if (++found == r) break;
            }
        }
        first_block += blocks_in_wave;
    }

    if (found == r) return result;
    // Return only the filled columns
    Rcpp::IntegerMatrix trimmed(n, found);
    for (int j = 0; j < found; j++)
        for (int i = 0; i < n; i++) trimmed(i, j) = result(i, j);
    return trimmed;
}
