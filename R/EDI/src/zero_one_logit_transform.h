#ifndef EDI_ZERO_ONE_LOGIT_TRANSFORM_H
#define EDI_ZERO_ONE_LOGIT_TRANSFORM_H

// Clamped logit / inverse-logit for shifting a response bounded in [0, 1]
// (or a value derived from one) by a treatment-effect delta on the logit
// scale. No Eigen/Rcpp dependency -- plain doubles, portable as-is.
//
// Canonical shared definitions: previously copy-pasted byte-for-byte into
// the anonymous namespace of both fast_kk_wilcox_parallel.cpp and
// fast_wilcox_hl.cpp, which is harmless per-TU but a hard redefinition
// error if those files are ever merged into one translation unit (see
// unity_build_collision_audit.md).
//
// NOTE: apply_shift(), which both files build on top of these two
// functions, is deliberately NOT hoisted here -- the two files' copies have
// diverged (fast_wilcox_hl.cpp's supports an additional transform_code == 4
// count-response branch that fast_kk_wilcox_parallel.cpp's copy lacks, so
// merging them would silently change one file's behavior). See each file's
// own apply_shift for that unresolved drift.

namespace edi_transform {

inline double logit_cpp(double x, double clamp) {
    if (x < clamp) x = clamp;
    if (x > 1.0 - clamp) x = 1.0 - clamp;
    return std::log(x / (1.0 - x));
}

inline double inv_logit_cpp(double x, double clamp) {
    double p;
    if (x >= 0.0) {
        const double z = std::exp(-x);
        p = 1.0 / (1.0 + z);
    } else {
        const double z = std::exp(x);
        p = z / (1.0 + z);
    }
    if (p < clamp) p = clamp;
    if (p > 1.0 - clamp) p = 1.0 - clamp;
    return p;
}

} // namespace edi_transform

#endif
