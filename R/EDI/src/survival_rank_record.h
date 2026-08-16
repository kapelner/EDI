#ifndef EDI_SURVIVAL_RANK_RECORD_H
#define EDI_SURVIVAL_RANK_RECORD_H

// Shared (time, dead, w) record and time/tie ordering used by the rank-based
// survival kernels (log-rank and its Peto-Prentice/Gehan-Wilcoxon
// generalization). No Eigen/Rcpp dependency -- plain data, portable as-is
// under EDI_CORE_ONLY with no #ifdef needed.
//
// Canonical shared definition: previously copy-pasted byte-for-byte into the
// anonymous namespace of both fast_logrank.cpp and fast_gehan_wilcox.cpp,
// which is harmless per-TU but a hard redefinition error if those files are
// ever merged into one translation unit (see unity_build_collision_audit.md).

namespace edi_survival {

struct SubjectRecord {
  double time;
  int dead;
  int w;
};

// Order by ascending time; at a tie, deaths (dead=1) sort before censorings
// (dead=0) so risk-set bookkeeping processes same-time events correctly;
// remaining ties broken by treatment arm.
inline bool record_less(const SubjectRecord& a, const SubjectRecord& b) {
  if (a.time < b.time) return true;
  if (a.time > b.time) return false;
  if (a.dead > b.dead) return true;
  if (a.dead < b.dead) return false;
  return a.w < b.w;
}

} // namespace edi_survival

#endif
