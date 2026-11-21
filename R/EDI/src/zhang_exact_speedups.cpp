#include <Rcpp.h>
#include <algorithm>
#include <cfloat>
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

namespace {

// Adding a term t >= 0 to a long double running sum s > 0 leaves s unchanged when
// t < ulp(s) / 2, which holds whenever t < s * 2^-(LDBL_MANT_DIG + 1). The log weights
// of both Zhang components are concave in the outcome (binomial and
// hypergeometric coefficients are log-concave; the delta term is linear), so past
// the mode each term is at most the previous one. So once a term past the mode is
// below this factor times every running sum it would join, it and all later terms
// are no-ops, and stopping there gives the same sums bit for bit. The factor
// below has 2^-5 to spare, for rounding of the log weights (about 1e-13
// absolute), which can make them non-increasing only up to a factor of 1 + 1e-12.
inline long double ldbl_sum_noop_factor() {
  return std::ldexp(1.0L, -(LDBL_MANT_DIG + 6));
}

// A product that R rounds on its own before adding it to something. On a target
// with fused multiply-add instructions (e.g. -march=native) the compiler may fuse
// "a + b * c" into one rounding (GCC does by default), which would no longer give
// R's doubles bit for bit; a volatile round trip prevents that there. Without FMA
// instructions nothing can be fused and the value passes through unchanged.
#if defined(__FP_FAST_FMA)
inline double unfused(double x) {
  volatile double v = x;
  return v;
}
#else
inline double unfused(double x) {
  return x;
}
#endif

}  // namespace

// One exact component of the Zhang test as an outcome distribution in delta:
// unnormalised log weights cj[i] + i * delta over outcomes i = 0..K-1, observed
// outcome at 1-based index x (zhang_exact_pval_components() in R). Returns the
// two-sided minimum-likelihood p-value at every delta: the probability of the
// outcomes with P(i) <= P(x) (1 + 1e-7), the same rule as
// zhang_exact_binom_pval_cpp() / zhang_exact_fisher_pval_cpp(). The normalising
// constant cancels in that comparison, so it uses the log weights directly. Per
// delta: one pass for the maximum, one for the exp sums. Sums are long double, as
// in R's colSums(), so the result equals the R matrix version it replaced
// (zhang_pval_exact_combined_vec(), v1.0.6-TODO-285) bit for bit. Two kinds of
// term are skipped, both exactly: one with exp() below the smallest subnormal (0
// there too), and, past the mode, the rest of the outcomes once a term is below
// 2^-(LDBL_MANT_DIG + 6) times both running sums (see ldbl_sum_noop_factor()).
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
  const long double noop = ldbl_sum_noop_factor();
  std::vector<double> lw(static_cast<std::size_t>(K));
  for (R_xlen_t d = 0; d < nd; ++d) {
    const double delta = deltas[d];
    if (!R_finite(delta)) {
      continue;
    }
    double mx = R_NegInf;
    R_xlen_t mode = 0;
    for (R_xlen_t i = 0; i < K; ++i) {
      // The product rounded on its own, as in R's cj + outer(j, delta).
      const double step = unfused(static_cast<double>(i) * delta);
      const double v = cj[i] + step;
      lw[static_cast<std::size_t>(i)] = v;
      if (v > mx) {
        mx = v;
        mode = i;
      }
    }
    const double cut = lw[static_cast<std::size_t>(x - 1)] + rel_tol_log;
    long double num = 0.0L;
    long double den = 0.0L;
    for (R_xlen_t i = 0; i < K; ++i) {
      const double v = lw[static_cast<std::size_t>(i)];
      const double z = v - mx;
      if (z < exp_zero_below) {
        if (i > mode) {
          break;  // exp() is 0 here and, past the mode, for every later term
        }
        continue;
      }
      const double e = std::exp(z);
      if (i > mode && num > 0.0L && e < den * noop && e < num * noop) {
        break;  // this and every later term leave both sums unchanged
      }
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
namespace {

double minlike_tail_bound(const NumericVector& cj, int x, double delta, int direction) {
  const R_xlen_t K = cj.size();
  if (K == 0 || x < 1 || x > K || !R_finite(delta) || direction == 0) {
    return 1.0;
  }
  std::vector<double> lw(static_cast<std::size_t>(K));
  R_xlen_t mode = 0;
  for (R_xlen_t i = 0; i < K; ++i) {
    const double step = unfused(static_cast<double>(i) * delta);
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
  const long double noop = ldbl_sum_noop_factor();
  long double total = 0.0L;
  long double side = 0.0L;
  for (R_xlen_t i = 0; i < K; ++i) {
    const double z = lw[static_cast<std::size_t>(i)] - top;
    if (z < -746.0) {
      if (i > mode) {
        break;  // exp() is 0 here and for every later term
      }
      continue;
    }
    const double e = std::exp(z);
    const bool on_side = direction > 0 ? i <= x0 : i >= x0;
    // Past the mode, stop once this and every later term leave both sums
    // unchanged (ldbl_sum_noop_factor()). Going right those terms are off x's
    // side (mode >= x0); going left they are on it once i >= x0.
    if (i > mode && e < total * noop &&
        (direction > 0 || (side > 0.0L && e < side * noop))) {
      break;
    }
    total += e;
    if (on_side) {
      side += e;
    }
  }
  const double n_other = static_cast<double>(direction > 0 ? K - x : x - 1);
  const double other_mass = unfused(n_other * (1.0 + 1e-7));
  const double b = static_cast<double>(side) / static_cast<double>(total) *
    (1.0 + other_mass) * (1.0 + 1e-6);
  return std::min(1.0, b);
}

// zhang_combine_exact_pvals() in R, for the bounds below; same arithmetic (R's
// pchisq/qnorm/pnorm, x^2 as x * x). A component is used when present, finite and
// positive. method: 0 Fisher, 1 Stouffer, 2 min_p.
double combine_zhang_pvals(double p_M, bool present_M, double p_R, bool present_R, int method) {
  const bool has_M = present_M && R_finite(p_M) && p_M > 0.0;
  const bool has_R = present_R && R_finite(p_R) && p_R > 0.0;
  if (has_M && has_R) {
    switch (method) {
      case 0:
        return R::pchisq(-2.0 * (std::log(p_M) + std::log(p_R)), 4.0, 0, 0);
      case 1: {
        const double z_M = R::qnorm(1.0 - p_M / 2.0, 0.0, 1.0, 1, 0);
        const double z_R = R::qnorm(1.0 - p_R / 2.0, 0.0, 1.0, 1, 0);
        const double z_combined = (z_M + z_R) / std::sqrt(2.0);
        return 2.0 * R::pnorm(-std::fabs(z_combined), 0.0, 1.0, 1, 0);
      }
      case 2: {
        const double q = 1.0 - std::min(p_M, p_R);
        const double q2 = unfused(q * q);
        return 1.0 - q2;
      }
      default:
        return NA_REAL;
    }
  }
  if (has_M) {
    return p_M;
  }
  if (has_R) {
    return p_R;
  }
  return NA_REAL;
}

// zhang_pval_exact_tail_bound() in R: the combined bound, and the max with each
// single component's (the fallback when one component underflows). An absent
// component is passed as an empty cj. NA when both are absent.
double combined_tail_bound(const NumericVector& cjM, int xM, const NumericVector& cjR, int xR,
                           double delta, int direction, int method) {
  const bool present_M = cjM.size() > 0;
  const bool present_R = cjR.size() > 0;
  const double bM = present_M ? minlike_tail_bound(cjM, xM, delta, direction) : NA_REAL;
  const double bR = present_R ? minlike_tail_bound(cjR, xR, delta, direction) : NA_REAL;
  const double g = combine_zhang_pvals(bM, present_M, bR, present_R, method);
  double out = R_NegInf;
  bool any = false;
  for (double v : {g, bM, bR}) {
    if (!ISNAN(v)) {
      out = any ? std::max(out, v) : v;
      any = true;
    }
  }
  return any ? out : NA_REAL;
}

}  // namespace

// One component's tail bound (above), for tests against the R formula.
// [[Rcpp::export]]
double zhang_minlike_tail_bound_cpp(const NumericVector& cj, int x, double delta, int direction) {
  return minlike_tail_bound(cj, x, delta, direction);
}

// The combined tail bound of zhang_pval_exact_tail_bound() at one delta
// (v1.0.6-TODO-285). method: 0 Fisher, 1 Stouffer, 2 min_p.
// [[Rcpp::export]]
double zhang_pval_exact_tail_bound_cpp(const NumericVector& cjM, int xM, const NumericVector& cjR, int xR,
                                       double delta, int direction, int method) {
  return combined_tail_bound(cjM, xM, cjR, xR, delta, direction, method);
}

// zhang_hull_scan_cut() in R with the bound above, in one call (v1.0.6-TODO-285):
// t_far when the bound there (b_far, or computed when NA) reaches pval_th, else
// n_iter bisection steps between r and t_far on the nonincreasing bound, returning
// the outer end, whose bound is below pval_th.
// [[Rcpp::export]]
double zhang_hull_scan_cut_cpp(const NumericVector& cjM, int xM, const NumericVector& cjR, int xR,
                               double r, double t_far, int direction, double pval_th, int method,
                               int n_iter, double b_far) {
  if (ISNAN(b_far)) {
    b_far = combined_tail_bound(cjM, xM, cjR, xR, t_far, direction, method);
  }
  if (b_far >= pval_th) {
    return t_far;
  }
  double lo = r;
  double hi = t_far;
  for (int iter = 0; iter < n_iter; ++iter) {
    const double mid = (lo + hi) / 2.0;
    if (combined_tail_bound(cjM, xM, cjR, xR, mid, direction, method) >= pval_th) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
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
