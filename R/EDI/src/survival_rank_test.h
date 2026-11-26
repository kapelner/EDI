#ifndef EDI_SURVIVAL_RANK_TEST_H
#define EDI_SURVIVAL_RANK_TEST_H

#include "_helper_functions_core.h"
#ifdef EDI_CORE_ONLY
#include "na_real_core.h"
#endif
#include "survival_rank_record.h"
#include <algorithm>
#include <cmath>
#include <vector>

namespace edi_survival {

// Peto-Prentice uses the pooled KM survival before each event time to weight
// the score and martingale residuals. The log-rank calculation is unweighted.
template <bool peto_prentice>
inline ModelResult rank_test(const Eigen::Ref<const Eigen::VectorXd>& time,
                             const std::vector<int>& dead,
                             const std::vector<int>& w) {
  const int n = time.size();
  ModelResult res;
  if (n == 0) return res;

  std::vector<SubjectRecord> recs;
  recs.reserve(n);
  int n_treat = 0;
  int n_control = 0;
  for (int i = 0; i < n; ++i) {
    recs.push_back(SubjectRecord{time[i], dead[i], w[i]});
    if (w[i] == 1) ++n_treat;
    else ++n_control;
  }
  std::sort(recs.begin(), recs.end(), record_less);

  // Precompute group boundaries: eliminates FP equality check inside the hot loop
  std::vector<int> gstart;
  gstart.reserve(n);
  {
    int i = 0;
    while (i < n) {
      gstart.push_back(i);
      const double t = recs[i].time;
      while (++i < n && recs[i].time == t);
    }
  }
  gstart.push_back(n);
  const int n_groups = static_cast<int>(gstart.size()) - 1;

  double score = 0.0;
  double var_score = 0.0;
  double cum_hazard = 0.0;
  double s_km = 1.0; // pooled KM survival, carried as S(t_g^-) into group g
  int risk_all = n;
  int risk_treat = n_treat;
  // Fused martingale accumulators
  double sum_m_treat = 0.0, sum_m_control = 0.0;
  double sum_sq_m_treat = 0.0, sum_sq_m_control = 0.0;

  for (int g = 0; g < n_groups; ++g) {
    const int start = gstart[g];
    const int end   = gstart[g + 1];
    int d_all = 0, d_treat = 0, remove_treat = 0;
    const double weight = s_km; // S_hat(t_g^-), fixed for every member of this tied-time group

    for (int i = start; i < end; ++i) {
      const SubjectRecord& rec = recs[i];
      if (rec.dead == 1) { ++d_all; if (rec.w == 1) ++d_treat; }
      if (rec.w == 1) ++remove_treat;
    }

    if (d_all > 0 && risk_all > 0) {
      const double expected_treat = static_cast<double>(d_all) * static_cast<double>(risk_treat) / static_cast<double>(risk_all);
      if constexpr (peto_prentice) {
        score += weight * (static_cast<double>(d_treat) - expected_treat);
      } else {
        score += static_cast<double>(d_treat) - expected_treat;
      }
      if (risk_all > 1) {
        const double frac_treat = static_cast<double>(risk_treat) / static_cast<double>(risk_all);
        const double v_j = static_cast<double>(d_all) * frac_treat * (1.0 - frac_treat) * (static_cast<double>(risk_all - d_all) / static_cast<double>(risk_all - 1));
        if constexpr (peto_prentice) var_score += weight * weight * v_j;
        else var_score += v_j;
      }
      cum_hazard += static_cast<double>(d_all) / static_cast<double>(risk_all);
      if constexpr (peto_prentice) s_km *= (1.0 - static_cast<double>(d_all) / static_cast<double>(risk_all));
    }

    // The cumulative hazard is now final for this time group.
    for (int i = start; i < end; ++i) {
      double m = static_cast<double>(recs[i].dead) - cum_hazard;
      if constexpr (peto_prentice) m = weight * m;
      if (recs[i].w == 1) { sum_m_treat += m; sum_sq_m_treat += m * m; }
      else { sum_m_control += m; sum_sq_m_control += m * m; }
    }

    risk_all -= (end - start);
    risk_treat -= remove_treat;
  }

  const double mean_treat   = (n_treat   > 0) ? sum_m_treat   / static_cast<double>(n_treat)   : 0.0;
  const double mean_control = (n_control > 0) ? sum_m_control / static_cast<double>(n_control) : 0.0;
  res.b = Eigen::VectorXd(1);
  res.b[0] = (n_treat > 0 && n_control > 0) ? (mean_treat - mean_control) : NA_REAL;

  double var_treat = 0.0, var_control = 0.0;
  if (n_treat > 1)
    var_treat = (sum_sq_m_treat - static_cast<double>(n_treat) * mean_treat * mean_treat) / static_cast<double>(n_treat - 1);
  if (n_control > 1)
    var_control = (sum_sq_m_control - static_cast<double>(n_control) * mean_control * mean_control) / static_cast<double>(n_control - 1);

  if (std::isfinite(var_treat) && std::isfinite(var_control)) {
    const double se_sq = var_treat / static_cast<double>(n_treat) + var_control / static_cast<double>(n_control);
    if (std::isfinite(se_sq) && se_sq > 0.0) res.ssq_b_2 = std::sqrt(se_sq); // repurposing ssq_b_2 for SE
  }
  res.dispersion = score; // repurposing dispersion for score
  res.sigma2_hat = var_score; // repurposing sigma2_hat for var_score
  return res;
}

} // namespace edi_survival

#endif
