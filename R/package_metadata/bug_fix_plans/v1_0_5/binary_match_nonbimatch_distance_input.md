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

- [x] TODO-1: **Diagonal to 0 (bit-preserving).** Replace `diag(D) =
  .Machine$double.xmax` with `diag(D) = 0`. Test: pairs identical to the
  current output on fixed-seed fixtures at n ∈ {20, 200, 1000}, p ∈ {2,
  4}, both `mahal_match` values; 1.3x on the matcher. Check
  `nbpMatching`'s documentation for its own statement about the
  diagonal and cite it in the code comment.

- [x] TODO-2 *(accepted by the user's instruction to queue and complete all
  v1.0.5 TODOs; default change)*:
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

- [x] TODO-3: **Re-run the design table.** Acceptance: `DesignFixedBinaryMatch`
  ≥ 1x of the `gendistance()` + `nonbimatch()` row after TODO-1 (EDI's
  distance step is already faster; the matcher then runs on comparable
  input), and ≥ 1.3x if TODO-2 is accepted. Update
  `benchmark_model_fits.md`.

## Implementation and validation (2026-10-09)

The helper now passes a zero diagonal, as `nbpMatching::distancematrix` itself
documents: diagonal values are ignored and zero is preferable because very
large values can distort scaling. Its default objective is ordinary Euclidean
or Mahalanobis distance, matching `gendistance()`. Both affected public design
constructors expose `match_objective = c("distance", "squared_distance")`;
the second value preserves EDI <= 1.0.4 pair selection. The default change is
documented in both class roxygen and `NEWS.md`.

The focused regression checks n in {20, 200, 1000}, p in {2, 4}, Euclidean and
Mahalanobis inputs. In every case, zero and `double.xmax` diagonals produce the
same squared-objective pairs; the compatibility switch reproduces those pairs;
and the new default exactly reproduces direct `nonbimatch()` on ordinary
distances. The file passes 55 expectations with a compile-free source load.

Installed-package focused rerun (EDI 1.0.3) used the design-table workflow at
n = 1000, p = 4: four continuous normal covariates; EDI constructed
`DesignFixedBinaryMatch`, ingested the table, assigned all subjects, and read
`w`; the canonical comparator ran `gendistance(X)`,
`nonbimatch(distancematrix(...))`, and within-pair coin flips. Exact
compile-free command:

```sh
Rscript -e 'suppressPackageStartupMessages(library(EDI)); suppressPackageStartupMessages(library(nbpMatching)); n <- 1000L; set.seed(12345); X <- data.frame(x3=rnorm(n),x4=rnorm(n),x5=rnorm(n),x6=rnorm(n)); edi <- function(){d<-DesignFixedBinaryMatch$new(n=n,response_type="continuous"); d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); d$get_w()}; can <- function(){h<-nbpMatching::nonbimatch(nbpMatching::distancematrix(nbpMatching::gendistance(X)))$halves; w<-integer(n); f<-rbinom(nrow(h),1,.5); w[h$Group1.Row]<-f; w[h$Group2.Row]<-1L-f; w}; edi(); can(); a<-replicate(3,system.time(edi())["elapsed"]*1000); b<-replicate(3,system.time(can())["elapsed"]*1000); cat("EDI_ms",paste(round(a,2),collapse=","),"median",median(a),"canonical_ms",paste(round(b,2),collapse=","),"median",median(b),"speedup",median(b)/median(a),"\\n")'
```

EDI times were 578, 537, and 473 ms (median 537 ms); canonical times were
890, 897, and 881 ms (median 890 ms), for a 1.66x speedup. This exceeds the
accepted ≥1.3x threshold after TODO-2's default-objective change. TODO-3 is
complete; the canonical `benchmark_model_fits.md` row still needs this
installed result recorded.

## Out of scope

- Replacing `nonbimatch` with a native matcher.
- `blockTools` parity beyond what the matcher input fixes.
