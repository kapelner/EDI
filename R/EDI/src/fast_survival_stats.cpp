#ifdef EDI_CORE_ONLY
#include <Eigen/Dense>
#include "na_real_core.h"
inline bool R_IsNA(double x) { return std::isnan(x); }
#else
#include <RcppEigen.h>
#ifdef _OPENMP
#include <omp.h>
#endif
#endif
#include <algorithm> // for std::sort
#include <cmath>
#include <limits>
#include <stdexcept> // for std::invalid_argument (NA/NaN event-time guard)
#include <vector>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

// File-local struct and helper for the parallel BRT kernel.
// Avoids all Rcpp wrap/unwrap in the per-draw inner loop so OpenMP can be used safely.
namespace {

struct SurvEntry { double time; int status; };

// NA/NaN guard for event-time inputs. Every KM group-walk in this file scans
// sorted times with `while (time[j] == current_time)`; a NaN time makes that
// comparison false even for j == i, so the outer loop's `i = j` never
// advances -- an infinite, uninterruptible (no R checkpoints) hang. NaN also
// breaks std::sort's strict-weak-ordering precondition (UB). Callers must
// therefore reject NaN input up front: the Rcpp entry points stop() with a
// clear message, and the OpenMP-safe inline kernel returns NA_REAL (throwing
// inside a parallel region is not an option). First hit in the wild: the
// slow-path bootstrap machinery fed the design's raw NA-for-censored `y`
// into the KM median kernel (fix_inference_hierarchy.md, Follow-Ups,
// "NA-y subset-clone bootstrap hang", 2026-08-17).
inline bool any_nan_time(const double* x, int n) {
    for (int i = 0; i < n; ++i) if (std::isnan(x[i])) return true;
    return false;
}

// Compute KM median or RMST for one sorted group; utimes/sprobs are reused across calls.
inline double km_stat_inline(SurvEntry* grp, int ng, bool do_rmst,
                              std::vector<double>& utimes, std::vector<double>& sprobs) {
    if (ng == 0) return NA_REAL;
    for (int i = 0; i < ng; ++i) if (std::isnan(grp[i].time)) return NA_REAL;
    std::sort(grp, grp + ng, [](const SurvEntry& a, const SurvEntry& b){ return a.time < b.time; });
    utimes.clear(); sprobs.clear();
    utimes.push_back(0.0); sprobs.push_back(1.0);
    double sp = 1.0;
    for (int i = 0; i < ng; ) {
        double ct = grp[i].time;
        int ar = ng - i, ev = 0, j = i;
        while (j < ng && grp[j].time == ct) { if (grp[j].status == 1) ev++; j++; }
        if (ev > 0) { sp *= 1.0 - (double)ev / ar; utimes.push_back(ct); sprobs.push_back(sp); }
        i = j;
    }
    if (!do_rmst) {
        // Match survival::quantile.survfit median semantics: the KM curve is a
        // step function. If it lands exactly on 0.5, average this event time
        // with the next event time; otherwise use the first time S(t) < 0.5.
        const int sz = (int)sprobs.size();
        const double tol = std::sqrt(std::numeric_limits<double>::epsilon());
        for (int i = 0; i < sz; ++i) {
            if (sprobs[i] <= 0.5) {
                if (std::abs(sprobs[i] - 0.5) < tol && i + 1 < sz) return 0.5 * (utimes[i] + utimes[i + 1]);
                return utimes[i];
            }
        }
        return NA_REAL;
    } else {
        // RMST: area under the KM curve (trapezoidal integration)
        double rmst = 0.0;
        const int sz = (int)utimes.size();
        for (int i = 0; i + 1 < sz; ++i)
            rmst += sprobs[i] * (utimes[i+1] - utimes[i]);
        if (sz > 1)
            rmst += sprobs.back() * (grp[ng-1].time - utimes.back());
        return rmst;
    }
}

} // namespace

// Portable (EDI_CORE_ONLY-safe) sibling of get_survival_stat_for_group
// below: identical KM-median/RMST algorithm, just Eigen::Ref inputs instead
// of SEXP, so a separate Python binding translation unit can call it
// (and get_survival_stat_diff_result below, in the same TU, avoiding that
// function's wrap()/SEXP round-trip through get_survival_stat_for_group).
double get_survival_stat_for_group_result(const Eigen::Ref<const Eigen::VectorXd>& y,
                                          const Eigen::Ref<const Eigen::VectorXi>& dead,
                                          const std::string& requested_stat) {
    int n = static_cast<int>(y.size());
    if (n == 0) return NA_REAL;
    // See any_nan_time() above: NaN times hang the group walk and break the
    // sort. Portable (EDI_CORE_ONLY-safe) function, so throw a std::exception
    // rather than Rcpp::stop; Rcpp converts it to an R error at the .Call
    // boundary and pybind11 translates it for the Python TU.
    if (any_nan_time(y.data(), n)) {
        throw std::invalid_argument(
            "get_survival_stat_for_group_result: y contains NA/NaN event times; "
            "survival kernels require finite (effective) times -- resolve censored "
            "subjects to their censoring time (Design$get_effective_time()) first.");
    }

    struct Subject { double time; int status; };
    std::vector<Subject> subjects(n);
    for (int i = 0; i < n; ++i) subjects[i] = {y[i], dead[i]};
    std::sort(subjects.begin(), subjects.end(), [](const Subject& a, const Subject& b) {
        return a.time < b.time;
    });

    double survival_prob = 1.0;
    std::vector<double> unique_times;
    std::vector<double> survival_probs;
    unique_times.push_back(0.0);
    survival_probs.push_back(1.0);

    for (int i = 0; i < n; ) {
        double current_time = subjects[i].time;
        int at_risk_at_time = n - i;
        int event_count_at_time = 0;

        int j = i;
        while (j < n && subjects[j].time == current_time) {
            if (subjects[j].status == 1) event_count_at_time++;
            j++;
        }

        if (event_count_at_time > 0) {
            survival_prob *= (1.0 - (double)event_count_at_time / at_risk_at_time);
            unique_times.push_back(current_time);
            survival_probs.push_back(survival_prob);
        }

        i = j;
    }

    if (requested_stat == "median") {
        const double tol = std::sqrt(std::numeric_limits<double>::epsilon());
        for (size_t i = 0; i < survival_probs.size(); ++i) {
            if (survival_probs[i] <= 0.5) {
                if (std::abs(survival_probs[i] - 0.5) < tol && i + 1 < survival_probs.size()) {
                    return 0.5 * (unique_times[i] + unique_times[i + 1]);
                }
                return unique_times[i];
            }
        }
        return NA_REAL;
    } else if (requested_stat == "restricted_mean") {
        double restricted_mean = 0.0;
        for (size_t i = 0; i < unique_times.size() - 1; ++i) {
            restricted_mean += survival_probs[i] * (unique_times[i + 1] - unique_times[i]);
        }
        if (unique_times.size() > 1) {
            restricted_mean += survival_probs.back() * (subjects.back().time - unique_times.back());
        }
        return restricted_mean;
    }

    return NA_REAL;
}

// Portable (EDI_CORE_ONLY-safe) sibling of get_survival_stat_diff below.
double get_survival_stat_diff_result(const Eigen::Ref<const Eigen::VectorXd>& y,
                                     const Eigen::Ref<const Eigen::VectorXi>& dead,
                                     const Eigen::Ref<const Eigen::VectorXi>& w,
                                     const std::string& requested_stat) {
    std::vector<double> y_control_std, y_treatment_std;
    std::vector<int> dead_control_std, dead_treatment_std;
    for (int i = 0; i < w.size(); ++i) {
        if (w[i] == 0) {
            y_control_std.push_back(y[i]);
            dead_control_std.push_back(dead[i]);
        } else {
            y_treatment_std.push_back(y[i]);
            dead_treatment_std.push_back(dead[i]);
        }
    }

    Eigen::Map<const Eigen::VectorXd> y_control(y_control_std.data(), y_control_std.size());
    Eigen::Map<const Eigen::VectorXi> dead_control(dead_control_std.data(), dead_control_std.size());
    Eigen::Map<const Eigen::VectorXd> y_treatment(y_treatment_std.data(), y_treatment_std.size());
    Eigen::Map<const Eigen::VectorXi> dead_treatment(dead_treatment_std.data(), dead_treatment_std.size());

    double stat_control = get_survival_stat_for_group_result(y_control, dead_control, requested_stat);
    double stat_treatment = get_survival_stat_for_group_result(y_treatment, dead_treatment, requested_stat);

    if (R_IsNA(stat_treatment) || R_IsNA(stat_control)) return NA_REAL;
    return stat_treatment - stat_control;
}

#ifndef EDI_CORE_ONLY
//' Calculates the median or restricted mean survival time for a single group
//'
//' @param y Numeric vector of survival times.
//' @param dead Integer vector of event indicators (1=event, 0=censored).
//' @param requested_stat A string, either "median" or "restricted_mean".
//' @return The calculated statistic.
//' @keywords internal
// [[Rcpp::export]]
double get_survival_stat_for_group(SEXP y, SEXP dead, std::string requested_stat) {
	IntegerVector dead_r_coerced(dead); Eigen::Map<const Eigen::VectorXi> dead_vec_coerced(dead_r_coerced.begin(), dead_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    
    // Combine y_vec_coerced and dead_vec_coerced into a data frame-like structure for sorting
    int n = y_vec_coerced.size();
    if (n == 0) {
        return NA_REAL;
    }
    if (any_nan_time(y_vec_coerced.data(), n)) {
        Rcpp::stop("get_survival_stat_for_group: y contains NA/NaN event times; "
                   "survival kernels require finite (effective) times.");
    }

    struct Subject {
        double time;
        int status;
    };

    std::vector<Subject> subjects(n);
    for (int i = 0; i < n; ++i) {
        subjects[i] = {y_vec_coerced[i], dead_vec_coerced[i]};
    }

    // Sort subjects by time
    std::sort(subjects.begin(), subjects.end(), [](const Subject& a, const Subject& b) {
        return a.time < b.time;
    });

    // Calculate Kaplan-Meier survival probability
    double survival_prob = 1.0;
    std::vector<double> unique_times;
    std::vector<double> survival_probs;

    unique_times.push_back(0.0);
    survival_probs.push_back(1.0);

    double last_unique_time = -1.0;
    int at_risk = n;
    int event_count_at_time = 0;
    int at_risk_at_time = n;

    for (int i = 0; i < n; ) {
        double current_time = subjects[i].time;
        at_risk_at_time = n - i;
        event_count_at_time = 0;

        int j = i;
        while (j < n && subjects[j].time == current_time) {
            if (subjects[j].status == 1) {
                event_count_at_time++;
            }
            j++;
        }

        if (event_count_at_time > 0) {
            survival_prob *= (1.0 - (double)event_count_at_time / at_risk_at_time);
            unique_times.push_back(current_time);
            survival_probs.push_back(survival_prob);
        }

        i = j;
    }

    if (requested_stat == "median") {
        const double tol = std::sqrt(std::numeric_limits<double>::epsilon());
        for (size_t i = 0; i < survival_probs.size(); ++i) {
            if (survival_probs[i] <= 0.5) {
                if (std::abs(survival_probs[i] - 0.5) < tol && i + 1 < survival_probs.size()) {
                    return 0.5 * (unique_times[i] + unique_times[i + 1]);
                }
                return unique_times[i];
            }
        }
        return NA_REAL; // Median is not estimable before the last observation time
    } else if (requested_stat == "restricted_mean") {
        double restricted_mean = 0.0;
        for (size_t i = 0; i < unique_times.size() - 1; ++i) {
            restricted_mean += survival_probs[i] * (unique_times[i+1] - unique_times[i]);
        }
        // Add the last interval
        if (unique_times.size() > 1){
             restricted_mean += survival_probs.back() * (subjects.back().time - unique_times.back());
        }

        return restricted_mean;
    }

    return NA_REAL; // Should not be reached
}


//' Calculates the difference in a survival statistic (median or restricted mean)
//' between two groups (treatment vs control)
//'
//' @param y Numeric vector of survival times.
//' @param dead Integer vector of event indicators (1=event, 0=censored).
//' @param w Integer vector of treatment assignments (1=treatment, 0=control).
//' @param requested_stat A string, either "median" or "restricted_mean".
//' @return The difference in the statistic (treatment - control).
//' @keywords internal
// [[Rcpp::export]]
double get_survival_stat_diff(SEXP y, SEXP dead, SEXP w, std::string requested_stat) {
	IntegerVector dead_r_coerced(dead); Eigen::Map<const Eigen::VectorXi> dead_vec_coerced(dead_r_coerced.begin(), dead_r_coerced.size());
	IntegerVector w_r_coerced(w); Eigen::Map<const Eigen::VectorXi> w_vec_coerced(w_r_coerced.begin(), w_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    
    if (any_nan_time(y_vec_coerced.data(), (int)y_vec_coerced.size())) {
        Rcpp::stop("get_survival_stat_diff: y contains NA/NaN event times; "
                   "survival kernels require finite (effective) times.");
    }
    std::vector<int> control_indices_std, treatment_indices_std;
    for (int i = 0; i < w_vec_coerced.size(); ++i) {
        if (w_vec_coerced[i] == 0) {
            control_indices_std.push_back(i);
        } else {
            treatment_indices_std.push_back(i);
        }
    }

    std::vector<double> y_control_std, y_treatment_std;
    std::vector<int> dead_control_std, dead_treatment_std;

    for (int idx : control_indices_std) {
        y_control_std.push_back(y_vec_coerced[idx]);
        dead_control_std.push_back(dead_vec_coerced[idx]);
    }
    for (int idx : treatment_indices_std) {
        y_treatment_std.push_back(y_vec_coerced[idx]);
        dead_treatment_std.push_back(dead_vec_coerced[idx]);
    }

    double stat_control = get_survival_stat_for_group_result(
        Eigen::Map<const Eigen::VectorXd>(y_control_std.data(), y_control_std.size()),
        Eigen::Map<const Eigen::VectorXi>(dead_control_std.data(), dead_control_std.size()),
        requested_stat);
    double stat_treatment = get_survival_stat_for_group_result(
        Eigen::Map<const Eigen::VectorXd>(y_treatment_std.data(), y_treatment_std.size()),
        Eigen::Map<const Eigen::VectorXi>(dead_treatment_std.data(), dead_treatment_std.size()),
        requested_stat);

    if (R_IsNA(stat_treatment) || R_IsNA(stat_control)) {
        return NA_REAL;
    }

    return stat_treatment - stat_control;
}


//' Calculates standard variance using the formula from Uno et al
//'
//' \eqn{Var(RMST) = \sum_j A(t_j)^2 d_j / (n_j (n_j - d_j))}
//' where \eqn{A(t_j) = \int_{t_j}^{\tau} S(u) du} is the remaining area under the KM
//' curve from event time \eqn{t_j} to the last observation \eqn{\tau}.
//' Here \eqn{d_j} is the number of events at \eqn{t_j}, and \eqn{n_j}
//' is the number at risk just before \eqn{t_j}.
//' Terms where n_j == d_j are omitted: S drops to 0 there, so A(t_j) = 0 and the
//' contribution is 0 in the limit regardless of the undefined Greenwood denominator.
//'
//' @param y Numeric vector of survival times.
//' @param dead Integer vector of event indicators (1=event, 0=censored).
//' @return The standard error of the restricted mean.
//' @keywords internal
// [[Rcpp::export]]
double get_restricted_mean_se_for_group(SEXP y, SEXP dead) {
	IntegerVector dead_r_coerced(dead); Eigen::Map<const Eigen::VectorXi> dead_vec_coerced(dead_r_coerced.begin(), dead_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    
    int n = y_vec_coerced.size();
    if (n == 0) return NA_REAL;
    if (any_nan_time(y_vec_coerced.data(), n)) {
        Rcpp::stop("get_restricted_mean_se_for_group: y contains NA/NaN event times; "
                   "survival kernels require finite (effective) times.");
    }

    struct Subject { double time; int status; };
    std::vector<Subject> subjects(n);
    for (int i = 0; i < n; ++i) subjects[i] = {y_vec_coerced[i], dead_vec_coerced[i]};
    std::sort(subjects.begin(), subjects.end(), [](const Subject& a, const Subject& b) {
        return a.time < b.time;
    });

    double tau = subjects.back().time;

    // Build KM event table: one entry per unique event time
    struct EventInfo { double time; double S_after; int n_j; int d_j; };
    std::vector<EventInfo> events;
    double S = 1.0;
    for (int i = 0; i < n; ) {
        double t = subjects[i].time;
        int n_at_risk = n - i;
        int d = 0;
        int j = i;
        while (j < n && subjects[j].time == t) {
            if (subjects[j].status == 1) d++;
            j++;
        }
        if (d > 0) {
            S *= (1.0 - (double)d / n_at_risk);
            events.push_back({t, S, n_at_risk, d});
        }
        i = j;
    }

    int K = (int)events.size();
    if (K == 0) return 0.0;  // no events: RMST equals tau with zero variance

    // Compute A(t_j) = integral_{t_j}^{tau} S(u) du via suffix sums.
    // S(u) = events[k].S_after for u in [events[k].time, events[k+1].time);
    // the final interval extends to tau.
    std::vector<double> A(K);
    A[K - 1] = events[K - 1].S_after * (tau - events[K - 1].time);
    for (int k = K - 2; k >= 0; --k) {
        A[k] = A[k + 1] + events[k].S_after * (events[k + 1].time - events[k].time);
    }

    // Var(RMST) = sum_j A(t_j)^2 * d_j / (n_j * (n_j - d_j)), skipping n_j == d_j
    double rmst_var = 0.0;
    for (int k = 0; k < K; ++k) {
        int nj = events[k].n_j;
        int dj = events[k].d_j;
        if (nj > dj) {
            rmst_var += A[k] * A[k] * (double)dj / ((double)nj * (nj - dj));
        }
    }

    return sqrt(rmst_var);
}

//' Calculates the standard error of the difference in restricted mean survival times
//'
//' @param y Numeric vector of survival times.
//' @param dead Integer vector of event indicators (1=event, 0=censored).
//' @param w Integer vector of treatment assignments (1=treatment, 0=control).
//' @return The standard error of the difference.
//' @keywords internal
// [[Rcpp::export]]
double get_restricted_mean_se_diff(SEXP y, SEXP dead, SEXP w) {
	IntegerVector dead_r_coerced(dead); Eigen::Map<const Eigen::VectorXi> dead_vec_coerced(dead_r_coerced.begin(), dead_r_coerced.size());
	IntegerVector w_r_coerced(w); Eigen::Map<const Eigen::VectorXi> w_vec_coerced(w_r_coerced.begin(), w_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    
    std::vector<int> control_indices_std, treatment_indices_std;
    for (int i = 0; i < w_vec_coerced.size(); ++i) {
        if (w_vec_coerced[i] == 0) {
            control_indices_std.push_back(i);
        } else {
            treatment_indices_std.push_back(i);
        }
    }

    std::vector<double> y_control_std, y_treatment_std;
    std::vector<int> dead_control_std, dead_treatment_std;

    for (int idx : control_indices_std) {
        y_control_std.push_back(y_vec_coerced[idx]);
        dead_control_std.push_back(dead_vec_coerced[idx]);
    }
    for (int idx : treatment_indices_std) {
        y_treatment_std.push_back(y_vec_coerced[idx]);
        dead_treatment_std.push_back(dead_vec_coerced[idx]);
    }

    double se_control = get_restricted_mean_se_for_group(
        wrap(y_control_std), wrap(dead_control_std));
    double se_treatment = get_restricted_mean_se_for_group(
        wrap(y_treatment_std), wrap(dead_treatment_std));

    if (R_IsNA(se_treatment) || R_IsNA(se_control)) {
        return NA_REAL;
    }

    return sqrt(pow(se_treatment, 2.0) + pow(se_control, 2.0));
}


//' Parallel BRT kernel for KM-diff (median) and RMST-diff.
//' Each replicate resamples rows i_mat(.,b) and pairs them with assignment w_mat(.,b).
//' Sharp-null shift is multiplicative on treated times (exp(delta)). Uses an inline
//' pure-C++ KM calculator — no R objects inside the loop, so OpenMP is safe.
//' @param do_rmst TRUE for RMST-diff, FALSE for median (KM-diff).
//' @keywords internal
// [[Rcpp::export]]
NumericVector compute_survival_stat_diff_rand_bootstrap_parallel_cpp(
    const NumericVector& y0,
    const IntegerVector& dead,
    const IntegerMatrix& i_mat,
    const IntegerMatrix& w_mat,
    double delta,
    bool do_rmst,
    Rcpp::Nullable<Rcpp::NumericMatrix> noise_mat,
    int num_cores) {

  const int n = i_mat.nrow();
  const int nsim = i_mat.ncol();
  // Guard before the parallel region (throwing inside OpenMP is not allowed);
  // km_stat_inline's own NaN check is the per-replicate backstop for
  // NaN introduced via noise_mat.
  if (any_nan_time(y0.begin(), (int)y0.size())) {
    Rcpp::stop("compute_survival_stat_diff_rand_bootstrap_parallel_cpp: y0 contains "
               "NA/NaN event times; survival kernels require finite (effective) times.");
  }
  std::vector<double> results_vec(nsim, NA_REAL);
  const double* y0_ptr = y0.begin();
  const int* dead_ptr = dead.begin();
  const int* i_ptr = i_mat.begin();
  const int* w_ptr = w_mat.begin();
  double* res_ptr = results_vec.data();
  const double mult = std::exp(delta);

  const bool has_noise = noise_mat.isNotNull();
  NumericMatrix noise_m;
  const double* noise_ptr = nullptr;
  if (has_noise) {
    noise_m = NumericMatrix(noise_mat);
    noise_ptr = noise_m.begin();
  }

#ifdef _OPENMP
  omp_set_num_threads(num_cores);
#endif

#pragma omp parallel if(num_cores > 1)
  {
    // Per-thread reusable buffers: avoids heap allocation in the hot loop
    std::vector<SurvEntry> y_t(n), y_c(n);
    std::vector<double> utimes_t, utimes_c, sprobs_t, sprobs_c;
    utimes_t.reserve(n); sprobs_t.reserve(n);
    utimes_c.reserve(n); sprobs_c.reserve(n);

#pragma omp for schedule(dynamic)
    for (int b = 0; b < nsim; ++b) {
      const int* i_col = i_ptr + (size_t)b * n;
      const int* w_col = w_ptr + (size_t)b * n;
      int nt = 0, nc = 0;
      for (int i = 0; i < n; ++i) {
        const int row0 = i_col[i] - 1;  // i_mat is 1-based
        double yv = y0_ptr[row0];
        if (has_noise) yv += noise_ptr[(size_t)b * n + i];
        SurvEntry e;
        e.status = dead_ptr[row0];
        if (w_col[i] == 1) {
          e.time = (delta != 0.0) ? yv * mult : yv;
          y_t[nt++] = e;
        } else {
          e.time = yv;
          y_c[nc++] = e;
        }
      }
      if (nt == 0 || nc == 0) continue;
      double stat_t = km_stat_inline(y_t.data(), nt, do_rmst, utimes_t, sprobs_t);
      double stat_c = km_stat_inline(y_c.data(), nc, do_rmst, utimes_c, sprobs_c);
      if (std::isfinite(stat_t) && std::isfinite(stat_c))
        res_ptr[b] = stat_t - stat_c;
    }
  }
  return wrap(results_vec);
}


// BRT variant of the KM survival-statistic difference (median or restricted mean):
// each replicate b resamples rows i_mat(., b) and pairs them with the fresh assignment
// w_mat(., b); the sharp-null shift is multiplicative on the treated times (delta on the
// log scale). Serial: get_survival_stat_for_group allocates R objects, which is not
// thread-safe; the win over the R paths is eliminating per-replicate object duplication.
// [[Rcpp::export]]
NumericVector compute_survival_stat_diff_rand_bootstrap_serial_cpp(
    const NumericVector& y0,
    const IntegerVector& dead,
    const IntegerMatrix& i_mat,
    const IntegerMatrix& w_mat,
    double delta,
    std::string requested_stat) {

  const int n = i_mat.nrow();
  const int nsim = i_mat.ncol();
  if (any_nan_time(y0.begin(), (int)y0.size())) {
    Rcpp::stop("compute_survival_stat_diff_rand_bootstrap_serial_cpp: y0 contains "
               "NA/NaN event times; survival kernels require finite (effective) times.");
  }
  NumericVector results(nsim, NA_REAL);
  const double* y0_ptr = y0.begin();
  const int* dead_ptr = dead.begin();
  const int* i_ptr = i_mat.begin();
  const int* w_ptr = w_mat.begin();
  const double mult = std::exp(delta);

  std::vector<double> y_t, y_c;
  std::vector<int> d_t, d_c;

  for (int b = 0; b < nsim; ++b) {
    const int* i_col = i_ptr + (size_t)b * n;
    const int* w_col = w_ptr + (size_t)b * n;
    y_t.clear(); y_c.clear(); d_t.clear(); d_c.clear();
    for (int i = 0; i < n; ++i) {
      const int row0 = i_col[i] - 1; // i_mat is 1-based
      if (w_col[i] == 1) {
        y_t.push_back(delta != 0.0 ? y0_ptr[row0] * mult : y0_ptr[row0]);
        d_t.push_back(dead_ptr[row0]);
      } else {
        y_c.push_back(y0_ptr[row0]);
        d_c.push_back(dead_ptr[row0]);
      }
    }
    if (y_t.empty() || y_c.empty()) continue;
    const double stat_t = get_survival_stat_for_group_result(
      Eigen::Map<const Eigen::VectorXd>(y_t.data(), y_t.size()),
      Eigen::Map<const Eigen::VectorXi>(d_t.data(), d_t.size()),
      requested_stat);
    const double stat_c = get_survival_stat_for_group_result(
      Eigen::Map<const Eigen::VectorXd>(y_c.data(), y_c.size()),
      Eigen::Map<const Eigen::VectorXi>(d_c.data(), d_c.size()),
      requested_stat);
    if (std::isfinite(stat_t) && std::isfinite(stat_c)) results[b] = stat_t - stat_c;
  }

  return results;
}
#endif // EDI_CORE_ONLY
