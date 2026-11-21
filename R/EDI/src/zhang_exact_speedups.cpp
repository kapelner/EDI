#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <vector>

using namespace Rcpp;

namespace {

double log_sum_exp(const std::vector<double>& log_weights) {
  if (log_weights.empty()) {
    return R_NegInf;
  }
  double max_log_weight = *std::max_element(log_weights.begin(), log_weights.end());
  double total = 0.0;
  for (double log_weight : log_weights) {
    total += std::exp(log_weight - max_log_weight);
  }
  return max_log_weight + std::log(total);
}

double binom_two_sided_pval(int x_obs, int n, double p) {
  if (n <= 0 || !R_finite(p) || p < 0.0 || p > 1.0 || x_obs < 0 || x_obs > n) {
    return NA_REAL;
  }

  const double rel_tol_log = std::log1p(1e-7);
  const double log_p_obs = R::dbinom(x_obs, n, p, true);
  double pval = 0.0;

  for (int x = 0; x <= n; ++x) {
    const double log_p_x = R::dbinom(x, n, p, true);
    if (log_p_x <= log_p_obs + rel_tol_log) {
      pval += std::exp(log_p_x);
    }
  }

  return std::min(1.0, pval);
}

double fisher_noncentral_two_sided_pval(int n11, int n10, int n01, int n00, double log_or) {
  if (!R_finite(log_or) || n11 < 0 || n10 < 0 || n01 < 0 || n00 < 0) {
    return NA_REAL;
  }

  const int row1 = n11 + n01;
  const int row2 = n10 + n00;
  const int col1 = n11 + n10;
  const int col2 = n01 + n00;
  const int min_x = std::max(0, row1 - col2);
  const int max_x = std::min(row1, col1);
  if (min_x > max_x || n11 < min_x || n11 > max_x) {
    return NA_REAL;
  }

  std::vector<double> log_weights;
  log_weights.reserve(static_cast<std::size_t>(max_x - min_x + 1));
  const double log_row1_factorial = std::lgamma(static_cast<double>(row1) + 1.0);
  const double log_row2_factorial = std::lgamma(static_cast<double>(row2) + 1.0);
  for (int x = min_x; x <= max_x; ++x) {
    const int row2_successes = col1 - x;
    const double log_choose_row1 =
      log_row1_factorial -
      std::lgamma(static_cast<double>(x) + 1.0) -
      std::lgamma(static_cast<double>(row1 - x) + 1.0);
    const double log_choose_row2 =
      log_row2_factorial -
      std::lgamma(static_cast<double>(row2_successes) + 1.0) -
      std::lgamma(static_cast<double>(row2 - row2_successes) + 1.0);
    log_weights.push_back(log_choose_row1 + log_choose_row2 + x * log_or);
  }

  const double log_norm = log_sum_exp(log_weights);
  const double rel_tol_log = std::log1p(1e-7);
  const double log_p_obs = log_weights[static_cast<std::size_t>(n11 - min_x)] - log_norm;
  double pval = 0.0;

  for (std::size_t i = 0; i < log_weights.size(); ++i) {
    const double log_p_x = log_weights[i] - log_norm;
    if (log_p_x <= log_p_obs + rel_tol_log) {
      pval += std::exp(log_p_x);
    }
  }

  return std::min(1.0, pval);
}

bool is_success(double y_i) {
  return R_finite(y_i) && y_i != 0.0;
}

}  // namespace

// [[Rcpp::export]]
double zhang_exact_binom_pval_cpp(int d_plus, int d_minus, double delta_0) {
  const int k = d_plus + d_minus;
  if (d_plus < 0 || d_minus < 0 || k <= 0 || !R_finite(delta_0)) {
    return NA_REAL;
  }

  const double p0 = 1.0 / (1.0 + std::exp(-delta_0));
  return binom_two_sided_pval(d_plus, k, p0);
}

// [[Rcpp::export]]
double zhang_exact_fisher_pval_cpp(int n11, int n10, int n01, int n00, double delta_0) {
  return fisher_noncentral_two_sided_pval(n11, n10, n01, n00, delta_0);
}

// One exact component of the Zhang test as an outcome distribution in delta:
// unnormalised log weights cj[i] + i * delta over outcomes i = 0..K-1, observed
// outcome at 1-based index x (zhang_exact_pval_components() in R). Returns the
// two-sided minimum-likelihood p-value at every delta: the probability of the
// outcomes with P(i) <= P(x) (1 + 1e-7), the same rule as
// zhang_exact_binom_pval_cpp() / zhang_exact_fisher_pval_cpp(). The normalising
// constant cancels in that comparison, so it uses the log weights directly. Per
// delta: one pass for the maximum, one for the exp sums. Sums are long double, as
// in R's colSums(), so the result equals the R matrix version it replaced
// (zhang_pval_exact_combined_vec(), v1.0.6-TODO-285) bit for bit; a term with
// exp() below the smallest subnormal is exactly 0 there and is skipped here.
// Non-finite delta gives NA (rejected by the caller).
// [[Rcpp::export]]
NumericVector zhang_minlike_pval_vec_cpp(const NumericVector& cj, int x, const NumericVector& deltas) {
  const R_xlen_t K = cj.size();
  const R_xlen_t nd = deltas.size();
  NumericVector out(nd, NA_REAL);
  if (K == 0 || x < 1 || x > K) {
    return out;
  }
  const double rel_tol_log = std::log1p(1e-7);
  const double exp_zero_below = -746.0;  // exp(z) == 0 in double for z < -745.14
  std::vector<double> lw(static_cast<std::size_t>(K));
  for (R_xlen_t d = 0; d < nd; ++d) {
    const double delta = deltas[d];
    if (!R_finite(delta)) {
      continue;
    }
    double mx = R_NegInf;
    for (R_xlen_t i = 0; i < K; ++i) {
      // volatile: no fused multiply-add (-march=native builds), so the sum is
      // rounded as R's cj + outer(j, delta) is.
      volatile double step = static_cast<double>(i) * delta;
      const double v = cj[i] + step;
      lw[static_cast<std::size_t>(i)] = v;
      if (v > mx) {
        mx = v;
      }
    }
    const double cut = lw[static_cast<std::size_t>(x - 1)] + rel_tol_log;
    long double num = 0.0L;
    long double den = 0.0L;
    for (R_xlen_t i = 0; i < K; ++i) {
      const double v = lw[static_cast<std::size_t>(i)];
      const double z = v - mx;
      if (z < exp_zero_below) {
        continue;
      }
      const double e = std::exp(z);
      den += e;
      if (v <= cut) {
        num += e;
      }
    }
    out[d] = std::min(1.0, static_cast<double>(num) / static_cast<double>(den));
  }
  return out;
}

// Upper bound on one component's minimum-likelihood p-value at delta, valid going
// outward in `direction` (+1 right, -1 left); see zhang_pval_exact_tail_bound() in
// R for the argument. Same arithmetic as the R version it replaced
// (v1.0.6-TODO-285): 1 while the mode of the weights is on x's own side, else
// P(tail on x's side) * (1 + n_other (1 + 1e-7)) * (1 + 1e-6), capped at 1.
// [[Rcpp::export]]
double zhang_minlike_tail_bound_cpp(const NumericVector& cj, int x, double delta, int direction) {
  const R_xlen_t K = cj.size();
  if (K == 0 || x < 1 || x > K || !R_finite(delta) || direction == 0) {
    return 1.0;
  }
  std::vector<double> lw(static_cast<std::size_t>(K));
  R_xlen_t mode = 0;
  for (R_xlen_t i = 0; i < K; ++i) {
    volatile double step = static_cast<double>(i) * delta;  // no FMA, as above
    lw[static_cast<std::size_t>(i)] = cj[i] + step;
    if (lw[static_cast<std::size_t>(i)] > lw[static_cast<std::size_t>(mode)]) {
      mode = i;  // first maximum, as which.max()
    }
  }
  const R_xlen_t x0 = static_cast<R_xlen_t>(x) - 1;
  if ((direction > 0 && mode < x0) || (direction < 0 && mode > x0)) {
    return 1.0;
  }
  const double top = lw[static_cast<std::size_t>(mode)];
  long double total = 0.0L;
  long double side = 0.0L;
  for (R_xlen_t i = 0; i < K; ++i) {
    const double z = lw[static_cast<std::size_t>(i)] - top;
    if (z < -746.0) {
      continue;
    }
    const double e = std::exp(z);
    total += e;
    if (direction > 0 ? i <= x0 : i >= x0) {
      side += e;
    }
  }
  const double n_other = static_cast<double>(direction > 0 ? K - x : x - 1);
  volatile double other_mass = n_other * (1.0 + 1e-7);  // no FMA, as above
  const double b = static_cast<double>(side) / static_cast<double>(total) *
    (1.0 + other_mass) * (1.0 + 1e-6);
  return std::min(1.0, b);
}

// [[Rcpp::export]]
List compute_zhang_match_data_cpp(const NumericMatrix& X,
                                  const NumericVector& y,
                                  const IntegerVector& w,
                                  const IntegerVector& m_vec) {
  if (w.size() != m_vec.size()) {
    stop("m_vec size must match w size.");
  }
  if (w.size() != y.size()) {
    stop("y size must match w size.");
  }
  if (X.nrow() != w.size()) {
    stop("X row count must match w size.");
  }
  const int n = w.size();
  const int p = X.ncol();
  int m = 0;
  int n_reservoir = 0;

  for (int i = 0; i < n; ++i) {
    int match_id = m_vec[i];
    if (match_id == NA_INTEGER) {
      match_id = 0;
    }
    if (match_id <= 0) {
      ++n_reservoir;
    } else if (match_id > m) {
      m = match_id;
    }
  }

  NumericVector yTs_matched(m, NA_REAL);
  NumericVector yCs_matched(m, NA_REAL);
  NumericVector y_matched_diffs(m, NA_REAL);
  NumericMatrix X_matched_diffs_full(m, p);
  std::vector<int> found_t(static_cast<std::size_t>(m), 0);
  std::vector<int> found_c(static_cast<std::size_t>(m), 0);

  for (int i = 0; i < n; ++i) {
    int match_id = m_vec[i];
    if (match_id == NA_INTEGER || match_id <= 0) {
      continue;
    }

    const int pair_index = match_id - 1;
    if (w[i] == 1) {
      yTs_matched[pair_index] = y[i];
      found_t[static_cast<std::size_t>(pair_index)] = 1;
      for (int j = 0; j < p; ++j) {
        X_matched_diffs_full(pair_index, j) += X(i, j);
      }
    } else {
      yCs_matched[pair_index] = y[i];
      found_c[static_cast<std::size_t>(pair_index)] = 1;
      for (int j = 0; j < p; ++j) {
        X_matched_diffs_full(pair_index, j) -= X(i, j);
      }
    }
  }

  IntegerVector keep_col_idx;
  if (m > 0) {
    std::vector<int> keep_cols;
    keep_cols.reserve(static_cast<std::size_t>(p));
    for (int pair_index = 0; pair_index < m; ++pair_index) {
      if (found_t[static_cast<std::size_t>(pair_index)] && found_c[static_cast<std::size_t>(pair_index)]) {
        y_matched_diffs[pair_index] = yTs_matched[pair_index] - yCs_matched[pair_index];
      }
    }
    for (int j = 0; j < p; ++j) {
      bool nonzero = false;
      for (int pair_index = 0; pair_index < m; ++pair_index) {
        if (X_matched_diffs_full(pair_index, j) != 0.0) {
          nonzero = true;
          break;
        }
      }
      if (nonzero) {
        keep_cols.push_back(j);
      }
    }
    keep_col_idx = wrap(keep_cols);
  } else {
    keep_col_idx = IntegerVector(0);
  }

  NumericMatrix X_matched_diffs(
    m,
    m > 0 ? keep_col_idx.size() : p
  );
  if (m > 0) {
    for (int pair_index = 0; pair_index < m; ++pair_index) {
      for (int j = 0; j < keep_col_idx.size(); ++j) {
        X_matched_diffs(pair_index, j) = X_matched_diffs_full(pair_index, keep_col_idx[j]);
      }
    }
  }

  NumericMatrix X_reservoir(n_reservoir, p);
  NumericVector y_reservoir(n_reservoir);
  IntegerVector w_reservoir(n_reservoir);
  int nRT = 0;
  int nRC = 0;
  int n11 = 0;
  int n10 = 0;
  int n01 = 0;
  int n00 = 0;

  for (int i = 0, reservoir_index = 0; i < n; ++i) {
    int match_id = m_vec[i];
    if (match_id == NA_INTEGER) {
      match_id = 0;
    }
    if (match_id > 0) {
      continue;
    }

    const int w_i = w[i];
    const bool success = is_success(y[i]);
    y_reservoir[reservoir_index] = y[i];
    w_reservoir[reservoir_index] = w_i;
    for (int j = 0; j < p; ++j) {
      X_reservoir(reservoir_index, j) = X(i, j);
    }

    if (w_i == 1) {
      ++nRT;
      if (success) {
        ++n11;
      } else {
        ++n10;
      }
    } else {
      ++nRC;
      if (success) {
        ++n01;
      } else {
        ++n00;
      }
    }
    ++reservoir_index;
  }

  int d_plus = 0;
  int d_minus = 0;
  for (int pair_index = 0; pair_index < m; ++pair_index) {
    if (!(found_t[static_cast<std::size_t>(pair_index)] && found_c[static_cast<std::size_t>(pair_index)])) {
      continue;
    }
    const bool y_t_success = is_success(yTs_matched[pair_index]);
    const bool y_c_success = is_success(yCs_matched[pair_index]);
    if (y_t_success && !y_c_success) {
      ++d_plus;
    } else if (!y_t_success && y_c_success) {
      ++d_minus;
    }
  }

  return List::create(
    _["X_matched_diffs"] = X_matched_diffs,
    _["X_matched_diffs_full"] = X_matched_diffs_full,
    _["yTs_matched"] = yTs_matched,
    _["yCs_matched"] = yCs_matched,
    _["y_matched_diffs"] = y_matched_diffs,
    _["X_reservoir"] = X_reservoir,
    _["y_reservoir"] = y_reservoir,
    _["w_reservoir"] = w_reservoir,
    _["nRT"] = nRT,
    _["nRC"] = nRC,
    _["m"] = m,
    _["d_plus"] = d_plus,
    _["d_minus"] = d_minus,
    _["n11"] = n11,
    _["n10"] = n10,
    _["n01"] = n01,
    _["n00"] = n00
  );
}

// [[Rcpp::export]]
List compute_matching_wy_stats_cpp(const IntegerVector& w,
                              const NumericVector& y,
                              const IntegerVector& m_vec) {
  const int n = w.size();
  int m = 0;
  int n_reservoir = 0;

  for (int i = 0; i < n; ++i) {
    int match_id = m_vec[i];
    if (match_id == NA_INTEGER) match_id = 0;
    if (match_id <= 0) {
      ++n_reservoir;
    } else if (match_id > m) {
      m = match_id;
    }
  }

  NumericVector yTs_matched(m, NA_REAL);
  NumericVector yCs_matched(m, NA_REAL);
  NumericVector y_matched_diffs(m, NA_REAL);
  std::vector<int> found_t(static_cast<std::size_t>(m), 0);
  std::vector<int> found_c(static_cast<std::size_t>(m), 0);

  NumericVector y_reservoir(n_reservoir);
  IntegerVector w_reservoir(n_reservoir);
  int nRT = 0, nRC = 0;
  int n11 = 0, n10 = 0, n01 = 0, n00 = 0;
  int reservoir_index = 0;

  for (int i = 0; i < n; ++i) {
    int match_id = m_vec[i];
    if (match_id == NA_INTEGER) match_id = 0;
    const int w_i = w[i];
    const bool success = is_success(y[i]);

    if (match_id <= 0) {
      y_reservoir[reservoir_index] = y[i];
      w_reservoir[reservoir_index] = w_i;
      if (w_i == 1) {
        ++nRT;
        if (success) ++n11; else ++n10;
      } else {
        ++nRC;
        if (success) ++n01; else ++n00;
      }
      ++reservoir_index;
    } else {
      const int pair_index = match_id - 1;
      if (w_i == 1) {
        yTs_matched[pair_index] = y[i];
        found_t[static_cast<std::size_t>(pair_index)] = 1;
      } else {
        yCs_matched[pair_index] = y[i];
        found_c[static_cast<std::size_t>(pair_index)] = 1;
      }
    }
  }

  int d_plus = 0, d_minus = 0;
  for (int pair_index = 0; pair_index < m; ++pair_index) {
    if (found_t[static_cast<std::size_t>(pair_index)] && found_c[static_cast<std::size_t>(pair_index)]) {
      y_matched_diffs[pair_index] = yTs_matched[pair_index] - yCs_matched[pair_index];
      const bool y_t_success = is_success(yTs_matched[pair_index]);
      const bool y_c_success = is_success(yCs_matched[pair_index]);
      if (y_t_success && !y_c_success) ++d_plus;
      else if (!y_t_success && y_c_success) ++d_minus;
    }
  }

  return List::create(
    _["yTs_matched"]     = yTs_matched,
    _["yCs_matched"]     = yCs_matched,
    _["y_matched_diffs"] = y_matched_diffs,
    _["y_reservoir"]     = y_reservoir,
    _["w_reservoir"]     = w_reservoir,
    _["nRT"]             = nRT,
    _["nRC"]             = nRC,
    _["d_plus"]          = d_plus,
    _["d_minus"]         = d_minus,
    _["n11"]             = n11,
    _["n10"]             = n10,
    _["n01"]             = n01,
    _["n00"]             = n00
  );
}
