# Binary Matching: Squared Distances and a `double.xmax` Diagonal Handed to `nbpMatching::nonbimatch`

> **Depends on:** nothing. Touches `helper_matching.R →
> compute_binary_match_structure()` (L7–46: squared distances at L33 and
> L35, `diag(D) = .Machine$double.xmax` at L36, the `nonbimatch` call at
> L38). Independent of every item in `release_v1_0_5.md` and
> `release_v1_1_0.md`.
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-61`).

Written 2026-10-07, user decision. Found by the 2026-10-07 extension of
`R/benchmark/benchmark_model_fits.R` (new "Design Generation Performance"
table: `DesignFixedBinaryMatch` vs. `nbpMatching::gendistance` +
`nonbimatch` and vs. `blockTools`), measured the same day against the
installed CRAN EDI 1.0.2 (no rebuild). Under the 2026-09-23 split rule
TODO-1 is a misfiring performance path that already shipped; TODO-2 is a
decision-gated default change and is listed as such in the release file's
standing constraint.

## Why

`DesignFixedBinaryMatch` times at 0.6–0.7x of `nbpMatching`'s own
pipeline although EDI's distance step is faster than `gendistance()`
(about 120 ms vs. 235 ms at n = 1000, p = 4). The matcher,
`nonbimatch()`, which both sides call, takes 1.6x longer on EDI's input
than on `gendistance()`'s. The difference is the matrix EDI hands it.

## Findings (n = 1000, p = 4, Mahalanobis, installed nbpMatching, 2026-10-07)

| Input to `nonbimatch(distancematrix(D))` | Time | Pairs vs. EDI today |
|---|---|---|
| squared distances, `diag = .Machine$double.xmax` (EDI today) | 926 ms | — |
| squared distances, `diag = 0` | 716 ms | **identical** |
| unsquared distances, `diag = .Machine$double.xmax` | 450 ms | 111 of 500 pairs differ |
| unsquared distances, `diag = 0` (what `gendistance()` produces) | 429 ms | 111 of 500 pairs differ |

- The diagonal does not affect the result (`nonbimatch` never pairs a row
  with itself) but costs 1.3x. `gendistance()` leaves it at 0.
- Squaring changes the objective: EDI minimizes the sum of **squared**
  Mahalanobis distances within pairs; `nbpMatching`, `gendistance()` and
  the matching literature it implements (Lu, Greevy, Xu & Beck 2011)
  minimize the sum of distances. On this fixture the squared objective
  gives total pair distance 270.4 vs. 269.2, and total squared distance
  183.6 vs. 186.1, so each is optimal for its own criterion. The unsquared
  input is also 1.7x faster to match, presumably because
  `distancematrix()`'s integer scaling of the weights behaves better on
  the smaller dynamic range.
- The Euclidean branch (`mahal_match = FALSE`, L35) squares and sets the
  diagonal the same way.

## TODOs

- [ ] TODO-1: **Diagonal to 0 (bit-preserving).** Replace `diag(D) =
  .Machine$double.xmax` with `diag(D) = 0`. Test: pairs identical to the
  current output on fixed-seed fixtures at n ∈ {20, 200, 1000}, p ∈ {2,
  4}, both `mahal_match` values; 1.3x on the matcher. Check
  `nbpMatching`'s documentation for its own statement about the
  diagonal and cite it in the code comment.

- [ ] TODO-2 *(decision-gated, user decision required; default change)*:
  **Unsquared distances.** Pass `sqrt` of the squared Mahalanobis (or
  Euclidean) distances, matching `gendistance()`'s objective. 2.2x on the
  matcher in total with TODO-1, and the objective then agrees with the
  canonical package and the cited literature. It changes which pairs are
  formed (22% of pairs on the fixture above), hence every downstream
  matched-pair estimate, CI and p-value on `DesignFixedBinaryMatch` and
  the KK designs that call this helper. If accepted:
  1. document the default change in the roxygen for the design classes
     and in `NEWS.md`;
  2. offer the old objective behind an argument (`match_objective =
     c("distance", "squared_distance")`) so 1.0.x pairs stay reproducible;
  3. regenerate the affected `comprehensive_tests` baseline rows and
     `package_tests` golden files, and re-run the results audit on them.
  If declined, record the decision here and close the item.

- [ ] TODO-3: **Re-run the design table.** Acceptance: `DesignFixedBinaryMatch`
  ≥ 1x of the `gendistance()` + `nonbimatch()` row after TODO-1 (EDI's
  distance step is already faster; the matcher then runs on comparable
  input), and ≥ 1.3x if TODO-2 is accepted. Update
  `benchmark_model_fits.md`.

## Out of scope

- Replacing `nonbimatch` with a native matcher.
- `blockTools` parity beyond what the matcher input fixes.
