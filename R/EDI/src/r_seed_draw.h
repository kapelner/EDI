#ifndef EDI_R_SEED_DRAW_H
#define EDI_R_SEED_DRAW_H

// Thin Rcpp-glue counterpart to RNG.h (which is deliberately kept
// Rcpp/R-free -- see its own header comment): draw_seed_from_r() below is
// the one place several .cpp files convert R's live unif_rand() stream into
// a seed for edi_rng::RRng, and it inherently needs R::unif_rand(), so it
// cannot live in RNG.h itself. Not compiled under EDI_CORE_ONLY (no R
// runtime available there -- callers under that build seed RRng some other
// way, matching this function's original per-file guard).
#ifndef EDI_CORE_ONLY
#include "RNG.h"
#include <RcppEigen.h>
#include <Rmath.h>
#include <cstdint>

namespace edi_rng {

// Canonical shared definition: previously copy-pasted byte-for-byte into
// the anonymous namespace of both generate_permutations.cpp and
// pocock_simon_assign.cpp, which is harmless per-TU but a hard redefinition
// error if those files are ever merged into one translation unit (see
// unity_build_collision_audit.md). Declared here, in edi_rng, rather than
// an anonymous namespace, so it has one definition shared across TUs;
// callers use it as `edi_rng::draw_seed_from_r()` (it takes no arguments,
// so unlike bounded_rand() there is no ADL to rely on for an unqualified
// call).
inline std::uint32_t draw_seed_from_r() {
	return edi_rng::seed_from_unif01(R::unif_rand());
}

} // namespace edi_rng
#endif // EDI_CORE_ONLY

#endif
