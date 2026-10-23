#ifdef EDI_CORE_ONLY
#include <Eigen/Dense>
#include "na_real_core.h"
#else
#include <RcppEigen.h>
#include "result_map_rcpp.h"
#endif
#include <algorithm>
#include <cmath>
#include <vector>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

namespace {

struct RiditScoreData {
    std::vector<double> scores;
    std::vector<int> levels;
    std::vector<double> ref_p;
};

RiditScoreData fast_ridit_scores_from_ref_indices(const int* y_ptr,
                                                  int n,
                                                  const std::vector<int>& ref_idx_zero_based) {
    const int n_ref = static_cast<int>(ref_idx_zero_based.size());

    // 1. Get unique levels and their counts in the reference group
    std::vector<int> levels;
    std::vector<int> counts;
    levels.reserve(static_cast<std::size_t>(std::min(n_ref, 16)));
    counts.reserve(levels.capacity());
    for (int idx : ref_idx_zero_based) {
        const int yi = y_ptr[idx];
        auto level_it = std::lower_bound(levels.begin(), levels.end(), yi);
        const std::size_t pos = static_cast<std::size_t>(level_it - levels.begin());
        if (level_it != levels.end() && *level_it == yi) {
            counts[pos]++;
        } else {
            levels.insert(level_it, yi);
            counts.insert(counts.begin() + static_cast<std::ptrdiff_t>(pos), 1);
        }
    }

    const int K = static_cast<int>(levels.size());
    std::vector<double> ref_p(static_cast<std::size_t>(K));
    std::vector<double> ridit_values(static_cast<std::size_t>(K));
    std::vector<double> cumulative_masses(static_cast<std::size_t>(K));

    // 2. Calculate Ridit scores for each category
    // R_k = sum_{j < k} p_j + 0.5 * p_k
    double cumulative_p = 0.0;
    for (int k = 0; k < K; ++k) {
        const double pk = static_cast<double>(counts[static_cast<std::size_t>(k)]) / n_ref;
        ref_p[static_cast<std::size_t>(k)] = pk;
        const double ridit = cumulative_p + 0.5 * pk;
        ridit_values[static_cast<std::size_t>(k)] = ridit;
        cumulative_p += pk;
        cumulative_masses[static_cast<std::size_t>(k)] = cumulative_p;
    }

    // 3. Assign scores to all subjects
    std::vector<double> scores(static_cast<std::size_t>(n));
    for (int i = 0; i < n; ++i) {
        const int yi = y_ptr[i];
        auto level_it = std::lower_bound(levels.begin(), levels.end(), yi);
        if (level_it != levels.end() && *level_it == yi) {
            scores[static_cast<std::size_t>(i)] = ridit_values[static_cast<std::size_t>(level_it - levels.begin())];
        } else {
            // If a level wasn't in the reference group, find its place
            if (level_it == levels.begin()) {
                scores[static_cast<std::size_t>(i)] = 0.0; // Extremely low
            } else if (level_it == levels.end()) {
                scores[static_cast<std::size_t>(i)] = 1.0; // Extremely high
            } else {
                // A missing interior category has no reference mass of its
                // own, so its ridit is exactly the reference mass below it.
                const int idx = static_cast<int>(std::distance(levels.begin(), level_it));
                scores[static_cast<std::size_t>(i)] =
                    cumulative_masses[static_cast<std::size_t>(idx - 1)];
            }
        }
    }

    return RiditScoreData{scores, levels, ref_p};
}

// TODO-106: DeLong (1988) standard error of the Mann-Whitney contrast
// theta - 1/2, a line-for-line port of ridit_delong_se() in
// R/EDI/R/inference_ordinal_ridit.R:
//   Var(V10)/n_T + Var(V01)/n_C, V10_i = control-CDF midrank (ridit) of treated
//   subject i, V01_j = 1 - treated-CDF midrank of control subject j, sample
//   variances (n - 1). A pooled reference is scaled by n_C / N.
// ridit scores under the control (resp. treatment) reference ARE the CDF
// midranks above (cumsum(p) - p/2, unseen categories scored by the mass below),
// so they are taken from fast_ridit_scores_from_ref_indices. `cur_ref` holds the
// scores already computed for `reference` (control/treatment) and is reused.
// Returns NA when either arm is empty and 0 when either arm has a single subject
// (same conventions as the R function).
double ridit_delong_se_from_scores(const int* y_ptr,
                                   const int* w_ptr,
                                   int n,
                                   const std::string& reference,
                                   const RiditScoreData& cur_ref) {
    std::vector<int> idx_t, idx_c;
    idx_t.reserve(static_cast<std::size_t>(n));
    idx_c.reserve(static_cast<std::size_t>(n));
    for (int i = 0; i < n; ++i) {
        if (w_ptr[i] == 1) idx_t.push_back(i);
        else if (w_ptr[i] == 0) idx_c.push_back(i);
    }
    const int n_t = static_cast<int>(idx_t.size());
    const int n_c = static_cast<int>(idx_c.size());
    if (n_t < 1 || n_c < 1) return NA_REAL;
    if (n_t < 2 || n_c < 2) return 0.0;

    RiditScoreData tmp_ctrl, tmp_trt;
    const RiditScoreData* ctrl_ref = &cur_ref;  // scores w.r.t. the control CDF
    const RiditScoreData* trt_ref = &cur_ref;   // scores w.r.t. the treated CDF
    if (reference != "control") {
        tmp_ctrl = fast_ridit_scores_from_ref_indices(y_ptr, n, idx_c);
        ctrl_ref = &tmp_ctrl;
    }
    if (reference != "treatment") {
        tmp_trt = fast_ridit_scores_from_ref_indices(y_ptr, n, idx_t);
        trt_ref = &tmp_trt;
    }

    // Sample variance (denominator m - 1) of v, two-pass like stats::var.
    auto sample_var = [](const std::vector<double>& v) {
        double mean = 0.0;
        for (double x : v) mean += x;
        mean /= static_cast<double>(v.size());
        double ss = 0.0;
        for (double x : v) ss += (x - mean) * (x - mean);
        return ss / static_cast<double>(v.size() - 1);
    };
    std::vector<double> v10, v01;
    v10.reserve(idx_t.size());
    v01.reserve(idx_c.size());
    for (int i : idx_t) v10.push_back(ctrl_ref->scores[static_cast<std::size_t>(i)]);
    for (int j : idx_c) v01.push_back(1.0 - trt_ref->scores[static_cast<std::size_t>(j)]);

    double se = std::sqrt(sample_var(v10) / n_t + sample_var(v01) / n_c);
    if (reference == "pooled") se *= static_cast<double>(n_c) / static_cast<double>(n_t + n_c);
    return se;
}

}  // namespace

struct RiditAnalysisResult {
    double mean_ridit_t;
    double mean_ridit_c;
    double estimate;
    double se;
    std::vector<double> scores;
    std::vector<int> levels;
    std::vector<double> ref_p;
};

// Portable (EDI_CORE_ONLY-safe) sibling of fast_ridit_analysis_cpp below:
// identical logic, on plain Eigen::Ref inputs / a plain struct return
// instead of SEXP/Rcpp::List, so a separate Python binding translation
// unit can call it. fast_ridit_scores_from_ref_indices above already used
// only std::vector/plain-int-pointer types internally -- the Rcpp coupling
// was solely in RiditScoreData's NumericVector fields (now std::vector<double>)
// and this function's own SEXP boundary. An empty scores vector on return
// is the sentinel for "no reference group" (mirrors fast_ridit_analysis_cpp's
// List::create() early return for that case).
RiditAnalysisResult fast_ridit_analysis_result(const Eigen::Ref<const Eigen::VectorXi>& w,
                                               const Eigen::Ref<const Eigen::VectorXi>& y,
                                               const std::string& reference) {
    int n = static_cast<int>(y.size());
    std::vector<int> ref_idx;
    ref_idx.reserve(static_cast<std::size_t>(n));

    if (reference == "control") {
        for (int i = 0; i < n; ++i) if (w[i] == 0) ref_idx.push_back(i);
    } else if (reference == "treatment") {
        for (int i = 0; i < n; ++i) if (w[i] == 1) ref_idx.push_back(i);
    } else { // pooled
        for (int i = 0; i < n; ++i) ref_idx.push_back(i);
    }

    if (ref_idx.empty()) {
        return RiditAnalysisResult{NA_REAL, NA_REAL, NA_REAL, NA_REAL, {}, {}, {}};
    }

    RiditScoreData ridit_data = fast_ridit_scores_from_ref_indices(y.data(), n, ref_idx);
    const std::vector<double>& scores = ridit_data.scores;

    double sum_t = 0.0, sum_c = 0.0;
    int n_t = 0, n_c = 0;

    for (int i = 0; i < n; ++i) {
        if (w[i] == 1) {
            sum_t += scores[static_cast<std::size_t>(i)];
            n_t++;
        } else {
            sum_c += scores[static_cast<std::size_t>(i)];
            n_c++;
        }
    }

    double mean_ridit_t = (n_t > 0) ? sum_t / n_t : NA_REAL;
    double mean_ridit_c = (n_c > 0) ? sum_c / n_c : NA_REAL;

    const bool treatment_reference = (reference == "treatment");
    // TODO-106: was sd(target-arm scores)/sqrt(n), which treats the reference
    // CDF as known (type-I error 14.75% vs 3.75% for DeLong at alpha = .05).
    const double se_delong = ridit_delong_se_from_scores(
        y.data(), w.data(), n, reference, ridit_data);

    return RiditAnalysisResult{
        mean_ridit_t, mean_ridit_c,
        treatment_reference ? 0.5 - mean_ridit_c : mean_ridit_t - 0.5,
        se_delong,
        ridit_data.scores, ridit_data.levels, ridit_data.ref_p
    };
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
List fast_ridit_scores_cpp(SEXP y, const Eigen::Map<Eigen::VectorXi>& ref_idx) {
	IntegerVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXi> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    
    int n = y_vec_coerced.size();
    int n_ref = ref_idx.size();

    std::vector<int> ref_idx_zero_based;
    ref_idx_zero_based.reserve(static_cast<std::size_t>(n_ref));
    for (int i = 0; i < n_ref; ++i) {
        ref_idx_zero_based.push_back(ref_idx[i] - 1);
    }

    RiditScoreData ridit_data = fast_ridit_scores_from_ref_indices(y_vec_coerced.data(), n, ref_idx_zero_based);
    // levels stays on the wrap() path (not edi::ResultMap): it's an integer
    // category-label vector, and ResultMap's ResultValue variant has no
    // integer-vector member (only Eigen::VectorXd/MatrixXd) -- routing it
    // through would silently turn it into a double vector on the R side.
    List out = edi::to_rcpp_list(edi::ResultMap()
        .set("scores", Eigen::VectorXd::Map(ridit_data.scores.data(), (Eigen::Index)ridit_data.scores.size()))
        .set("ref_p", Eigen::VectorXd::Map(ridit_data.ref_p.data(), (Eigen::Index)ridit_data.ref_p.size())));
    out["levels"] = wrap(ridit_data.levels);
    return out;
}

// [[Rcpp::export]]
List fast_ridit_analysis_cpp(SEXP w, SEXP y, const std::string& reference = "control") {
	IntegerVector w_r_coerced(w); Eigen::Map<const Eigen::VectorXi> w_vec_coerced(w_r_coerced.begin(), w_r_coerced.size());
	IntegerVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXi> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    RiditAnalysisResult res = fast_ridit_analysis_result(w_vec_coerced, y_vec_coerced, reference);
    if (res.scores.empty()) {
        return List::create();
    }

    List out = edi::to_rcpp_list(edi::ResultMap()
        .set("mean_ridit_t", res.mean_ridit_t)
        .set("mean_ridit_c", res.mean_ridit_c)
        .set("estimate", res.estimate)
        .set("se", res.se)
        .set("scores", Eigen::VectorXd::Map(res.scores.data(), (Eigen::Index)res.scores.size()))
        .set("ref_p", Eigen::VectorXd::Map(res.ref_p.data(), (Eigen::Index)res.ref_p.size())));
    out["levels"] = wrap(res.levels);
    return out;
}
#endif // EDI_CORE_ONLY
