#ifndef EDI_SIMD_H
#define EDI_SIMD_H

// Loop-vectorization hints for the hot loops that used bare `#pragma omp
// simd`. With OpenMP (GCC/Linux, Windows, the macOS libomp build) they are
// exactly `#pragma omp simd`. CRAN's macOS R has no OpenMP, so Apple clang
// silently dropped those pragmas; the flag that would keep them
// (-fopenmp-simd) is a -f* flag that R CMD check reports as non-portable in
// PKG_CXXFLAGS. Under clang without OpenMP the same promise is spelled as
// `#pragma clang loop vectorize(assume_safety)`: no loop-carried memory
// dependence, reductions may be reordered -- what `omp simd` asserts.
// Elsewhere (GCC without OpenMP) the hint is dropped, as before.
// arm_hardware.md TODO-7 / more_simd_optimization.md TODO-7.
#define EDI_PRAGMA(x) _Pragma(#x)

#if defined(_OPENMP)
#define EDI_SIMD EDI_PRAGMA(omp simd)
#define EDI_SIMD_REDUCTION(...) EDI_PRAGMA(omp simd reduction(__VA_ARGS__))
#elif defined(__clang__)
#define EDI_SIMD EDI_PRAGMA(clang loop vectorize(assume_safety))
#define EDI_SIMD_REDUCTION(...) EDI_PRAGMA(clang loop vectorize(assume_safety))
#else
#define EDI_SIMD
#define EDI_SIMD_REDUCTION(...)
#endif

#endif
