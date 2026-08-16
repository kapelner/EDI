#ifndef EDI_RNG_H
#define EDI_RNG_H

// A standalone, Rcpp/R-free re-implementation of R's default random-number
// generator, extracted and adapted from R's own C sources:
//   - src/main/RNG.c        (Mersenne-Twister core + integer-seed scrambling)
//   - src/nmath/snorm.c     (the "Inversion" normal-deviate method)
//   - src/nmath/qnorm.c     (qnorm5 / AS 241, needed by Inversion)
// all (C) The R Core Team / Robert Gentleman & Ross Ihaka / Ross Ihaka, and
// all licensed GPL (>= 2) -- see https://www.R-project.org/Licenses/. This
// file is likewise distributed under the terms of the GNU General Public
// License version 2 or (at your option) any later version, consistent with
// this package's own GPL-3 license (R's "GPL-2 or later" is compatible with
// and absorbable into GPL-3).
//
// PURPOSE: a standalone, independently-testable building block for a
// portable RNG (see package_metadata/new_feature_plans/
// sexp_removal_rcppeigen_conversion_spec.md's TODO-12), used two ways
// elsewhere in this package:
//   1. Seed-once-per-call: draw one value from R::unif_rand(), construct
//      RRng(seed), run independently from there. Decouples the call from
//      R's global (thread-unsafe) RNG state -- safe inside OpenMP, and,
//      unlike a std::mt19937_64 seeded the same way, still gives genuine
//      cross-language reproducibility for a given seed, since RRng is a
//      fixed, portable re-implementation of R's actual algorithm rather
//      than an unrelated one.
//   2. Live-stream continuation: read R's actual current `.Random.seed`
//      directly as an R object, build RRng(mti, mt) from it, draw, then
//      write the advanced state back to `.Random.seed`. Produces output
//      bit-identical to calling R's own unif_rand()/norm_rand() directly
//      -- used where an existing test requires exact parity with a
//      hand-written R reference implementation.
//
// GOTCHA (hit and fixed during development, don't reintroduce it): Rcpp
// wraps every `// [[Rcpp::export]]` function in an implicit RNGScope, whose
// destructor calls PutRNGstate() on return -- which re-derives
// `.Random.seed` from R's own internal C statics and will silently
// overwrite a manual `.Random.seed` write (like continuation path #2 does)
// with stale data, since those internal statics were never touched (no
// R::unif_rand()/R::norm_rand() call happened). Any code that writes
// `.Random.seed` directly (via Rcpp::Environment::global_env().assign(...))
// MUST call GetRNGstate() again immediately after, to re-sync R's internal
// statics from the just-written value -- making the implicit
// PutRNGstate()-on-return a no-op instead of a silent revert. Confirmed via
// a failing/passing round-trip test before and after adding this.
//
// SCOPE: only the two generator kinds this package actually uses --
// Mersenne-Twister (RNGkind's default uniform generator) and Inversion
// (R's default normal-deviate method) -- are ported. R's other RNGkind
// options (Wichmann-Hill, Marsaglia-Multicarry, Super-Duper, Knuth-TAOCP,
// L'Ecuyer-CMRG, Kinderman-Ramage, Box-Muller, Ahrens-Dieter) are not
// implemented, since this package never selects them.
//
// VERIFICATION: see r_rng_bitexact_check.R in this same directory's test
// support (or wherever it's wired up) -- draws must be validated against
// real R output across many seeds before this class is trusted for
// anything beyond its own unit tests. Porting a PRNG from source without
// numerical verification is exactly the kind of change that can be subtly,
// silently wrong; do not skip that step.

#include <cstdint>
#include <cmath>
#include <array>
#include <limits>

namespace edi_rng {

// 32-bit unsigned integer type matching R's `Int32` (RNG.c uses `unsigned
// int`, assumed 32-bit -- true on every platform this package targets).
using Int32 = std::uint32_t;

// Re-implementation of R's Mersenne-Twister + "Inversion" normal generator.
// One instance == one independent RNG stream (safe to give each OpenMP
// thread, or each Monte Carlo replicate, its own instance).
class RRng {
private:
	static constexpr int N = 624;
	static constexpr int M = 397;
	static constexpr Int32 MATRIX_A   = 0x9908b0dfu;
	static constexpr Int32 UPPER_MASK = 0x80000000u;
	static constexpr Int32 LOWER_MASK = 0x7fffffffu;
	static constexpr Int32 TEMPERING_MASK_B = 0x9d2c5680u;
	static constexpr Int32 TEMPERING_MASK_C = 0xefc60000u;

public:
	// Seeds exactly as R's RNG_Init(MERSENNE_TWISTER, seed) does: a 50-round
	// scrambling pass, then 625 more rounds filling i_seed[0..624]
	// (i_seed[0] is a legacy `mti` slot always overwritten to 624 by
	// FixupSeeds on initial seeding; i_seed[1..624] become the MT state
	// array). seed is truncated to 32 bits the same way R's Int32 does via
	// unsigned-integer wraparound.
	explicit RRng(std::uint32_t seed) {
		Int32 s = static_cast<Int32>(seed);
		for (int j = 0; j < 50; ++j) {
			s = static_cast<Int32>(69069u * s + 1u);
		}
		// i_seed[0] (=mti) is scrambled too for historical consistency, but
		// immediately overwritten below to match FixupSeeds(kind, initial=1).
		s = static_cast<Int32>(69069u * s + 1u); // i_seed[0], discarded
		for (int j = 0; j < N; ++j) {
			s = static_cast<Int32>(69069u * s + 1u);
			mt_[static_cast<std::size_t>(j)] = s;
		}
		mti_ = N; // FixupSeeds(MERSENNE_TWISTER, initial=1) always sets this
	}

	// Constructs directly from a raw (mti, mt[0..623]) state pair -- e.g. one
	// read straight out of R's live `.Random.seed` -- rather than from an
	// integer seed run through the scrambling loop. Used to continue R's
	// actual live stream bit-for-bit from wherever it currently is, instead
	// of starting a fresh independent stream. mti is clamped into [0, N] the
	// same way R's FixupSeeds(kind, initial=0) does for a non-initial load
	// (accepts a corrupted/out-of-range mti no more charitably than R does).
	RRng(std::int32_t mti, const std::array<Int32, N>& mt) : mt_(mt) {
		mti_ = (mti <= 0) ? N : mti;
	}

	// Equivalent to R's unif_rand() under RNGkind("Mersenne-Twister"): one
	// draw in (0, 1), endpoints excluded via the same fixup() R uses.
	double unif_rand() {
		return fixup(static_cast<double>(next_word()) * 2.3283064365386963e-10);
	}

	// Equivalent to R's norm_rand() under the default N01_kind
	// ("Inversion"): combines two unif_rand() draws into one high-precision
	// uniform, then applies qnorm(., 0, 1, lower_tail=TRUE, log_p=FALSE) via
	// AS 241 (Wichura 1988), exactly as R's snorm.c does.
	double norm_rand() {
		constexpr double BIG = 134217728.0; // 2^27
		double u1 = unif_rand();
		u1 = static_cast<double>(static_cast<long>(BIG * u1)) + unif_rand();
		return qnorm_std(u1 / BIG);
	}

	// Raw tempered 32-bit MT output (the word unif_rand() scales into a
	// double) -- exposes R's actual generator output directly, so callers
	// that need unbiased bounded-integer sampling (Lemire-style rejection
	// sampling) can use it instead of rescaling a [0,1) double, matching the
	// bounded_rand() helper pattern already used across this codebase (just
	// at 32 bits instead of the arbitrary-generator 64-bit form).
	Int32 next_word() { return mt_genrand(); }

	// std::shuffle / <random>'s UniformRandomBitGenerator interface, so RRng
	// can be passed directly to std::shuffle(...) the same way
	// std::mt19937/std::mt19937_64 instances were.
	using result_type = Int32;
	Int32 operator()() { return next_word(); }
	static constexpr Int32 min() { return 0u; }
	static constexpr Int32 max() { return 0xffffffffu; }

	// Exports the current (mti, mt[]) state -- e.g. to write back into R's
	// `.Random.seed` after this instance has advanced, so R's own stream
	// continues correctly for whatever runs after this call.
	std::int32_t mti() const { return mti_; }
	const std::array<Int32, N>& state() const { return mt_; }

private:
	std::array<Int32, N> mt_{};
	int mti_ = N + 1;

	static double fixup(double x) {
		constexpr double i2_32m1 = 2.328306437080797e-10; // 1/(2^32 - 1)
		if (x <= 0.0) return 0.5 * i2_32m1;
		if ((1.0 - x) <= 0.0) return 1.0 - 0.5 * i2_32m1;
		return x;
	}

	// Verbatim port of R's MT_genrand() (src/main/RNG.c), operating on this
	// instance's own state instead of R's process-global `dummy`/`mt`/`mti`,
	// and returning the raw tempered word instead of R's own version's
	// already-scaled-to-double return (the scaling now lives in unif_rand()).
	Int32 mt_genrand() {
		static const Int32 mag01[2] = {0x0u, MATRIX_A};
		Int32 y;

		if (mti_ >= N) {
			int kk;
			for (kk = 0; kk < N - M; ++kk) {
				y = (mt_[static_cast<std::size_t>(kk)] & UPPER_MASK) |
				    (mt_[static_cast<std::size_t>(kk + 1)] & LOWER_MASK);
				mt_[static_cast<std::size_t>(kk)] =
					mt_[static_cast<std::size_t>(kk + M)] ^ (y >> 1) ^ mag01[y & 0x1u];
			}
			for (; kk < N - 1; ++kk) {
				y = (mt_[static_cast<std::size_t>(kk)] & UPPER_MASK) |
				    (mt_[static_cast<std::size_t>(kk + 1)] & LOWER_MASK);
				mt_[static_cast<std::size_t>(kk)] =
					mt_[static_cast<std::size_t>(kk + (M - N))] ^ (y >> 1) ^ mag01[y & 0x1u];
			}
			y = (mt_[N - 1] & UPPER_MASK) | (mt_[0] & LOWER_MASK);
			mt_[N - 1] = mt_[M - 1] ^ (y >> 1) ^ mag01[y & 0x1u];

			mti_ = 0;
		}

		y = mt_[static_cast<std::size_t>(mti_++)];
		y ^= (y >> 11);
		y ^= (y << 7) & TEMPERING_MASK_B;
		y ^= (y << 15) & TEMPERING_MASK_C;
		y ^= (y >> 18);

		return y;
	}

	// Specialization of R's qnorm5(p, mu=0, sigma=1, lower_tail=TRUE,
	// log_p=FALSE) (src/nmath/qnorm.c, AS 241 / Wichura 1988) -- the only
	// call shape norm_rand()'s Inversion branch ever uses. Boundary/NaN
	// handling collapses accordingly (R_DT_qIv(p) == p and R_DT_CIv(p) ==
	// 1-p when log_p=FALSE, lower_tail=TRUE).
	static double qnorm_std(double p) {
		if (p <= 0.0) return -std::numeric_limits<double>::infinity();
		if (p >= 1.0) return std::numeric_limits<double>::infinity();

		const double q = p - 0.5;
		double r, val;

		if (std::fabs(q) <= .425) {
			r = .180625 - q * q;
			val =
				q * (((((((r * 2509.0809287301226727 +
				           33430.575583588128105) * r + 67265.770927008700853) * r +
				          45921.953931549871457) * r + 13731.693765509461125) * r +
				        1971.5909503065514427) * r + 133.14166789178437745) * r +
				     3.387132872796366608)
				/ (((((((r * 5226.495278852854561 +
				         28729.085735721942674) * r + 39307.89580009271061) * r +
				        21213.794301586595867) * r + 5394.1960214247511077) * r +
				      687.1870074920579083) * r + 42.313330701600911252) * r + 1.);
		} else {
			const double lp = std::log(q > 0 ? (1.0 - p) : p);
			r = std::sqrt(-lp);
			if (r <= 5.) {
				r += -1.6;
				val = (((((((r * 7.7454501427834140764e-4 +
				           .0227238449892691845833) * r + .24178072517745061177) *
				         r + 1.27045825245236838258) * r +
				        3.64784832476320460504) * r + 5.7694972214606914055) *
				      r + 4.6303378461565452959) * r +
				     1.42343711074968357734)
				    / (((((((r *
				             1.05075007164441684324e-9 + 5.475938084995344946e-4) *
				            r + .0151986665636164571966) * r +
				           .14810397642748007459) * r + .68976733498510000455) *
				         r + 1.6763848301838038494) * r +
				        2.05319162663775882187) * r + 1.);
			} else if (r <= 27) {
				r += -5.;
				val = (((((((r * 2.01033439929228813265e-7 +
				           2.71155556874348757815e-5) * r +
				          .0012426609473880784386) * r + .026532189526576123093) *
				        r + .29656057182850489123) * r +
				       1.7848265399172913358) * r + 5.4637849111641143699) *
				     r + 6.6579046435011037772)
				    / (((((((r *
				             2.04426310338993978564e-15 + 1.4215117583164458887e-7) *
				            r + 1.8463183175100546818e-5) * r +
				           7.868691311456132591e-4) * r + .0148753612908506148525)
				         * r + .13692988092273580531) * r +
				        .59983220655588793769) * r + 1.);
			} else if (r >= 6.4e8) {
				val = r * 1.4142135623730951; // M_SQRT2
			} else {
				const double s2 = -2.0 * lp;
				double x2 = s2 - std::log(6.283185307179586 * s2); // 2*pi
				if (r < 36000.) {
					x2 = s2 - std::log(6.283185307179586 * x2) - 2. / (2. + x2);
					if (r < 840.) {
						x2 = s2 - std::log(6.283185307179586 * x2) +
						     2 * std::log1p(-(1 - 1 / (4 + x2)) / (2. + x2));
						if (r < 109.) {
							x2 = s2 - std::log(6.283185307179586 * x2) +
							     2 * std::log1p(-(1 - (1 - 5 / (6 + x2)) / (4. + x2)) / (2. + x2));
							if (r < 55.) {
								x2 = s2 - std::log(6.283185307179586 * x2) +
								     2 * std::log1p(-(1 - (1 - (5 - 9 / (8. + x2)) / (6. + x2)) / (4. + x2)) / (2. + x2));
							}
						}
					}
				}
				val = std::sqrt(x2);
			}
			if (q < 0.0) val = -val;
		}
		return val;
	}
};

// Converts one R::unif_rand() draw (a double in [0,1)) into a 32-bit seed
// for RRng's constructor -- scaled by RRng::max() (2^32 - 1) rather than a
// bare repeated literal, so the derivation is self-documenting at every
// call site: "the full range of the 32-bit word this generator produces."
inline std::uint32_t seed_from_unif01(double u) {
	return static_cast<std::uint32_t>(u * static_cast<double>(RRng::max()));
}

// Lemire-style unbiased bounded integer sampling, 32-bit width to match
// RRng's native word size (R's actual Mersenne-Twister generates 32-bit
// words -- this is R's own generator, not an arbitrary wider one).
//
// Canonical shared definition: previously copy-pasted byte-for-byte into
// the anonymous namespace of 5 separate .cpp files (bootstrap_indices.cpp,
// bootstrap_match_indices.cpp, exchangeable_resampling_draws.cpp,
// fast_sample_int.cpp, sample_bootstrap_distr_weighted_distances.cpp),
// which is harmless per-TU but a hard redefinition error if any two of
// those files are ever merged into one translation unit (see
// unity_build_collision_audit.md). Declared here, in edi_rng (RRng's own
// namespace) rather than an anonymous one, so every existing unqualified
// call site (`bounded_rand(rng, s)`, with `rng` typed `edi_rng::RRng&`)
// still resolves via ADL with zero call-site changes.
inline std::uint32_t bounded_rand(RRng& rng, std::uint32_t s) {
	std::uint32_t x = rng.next_word();
	std::uint64_t m = static_cast<std::uint64_t>(x) * static_cast<std::uint64_t>(s);
	std::uint32_t l = static_cast<std::uint32_t>(m);
	if (l < s) {
		std::uint32_t t = (-s) % s;
		while (l < t) {
			x = rng.next_word();
			m = static_cast<std::uint64_t>(x) * static_cast<std::uint64_t>(s);
			l = static_cast<std::uint32_t>(m);
		}
	}
	return static_cast<std::uint32_t>(m >> 32);
}

} // namespace edi_rng

#endif // EDI_RNG_H
