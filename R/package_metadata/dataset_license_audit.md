# Dataset catalog license audit (2026-10-04 → 2026-10-08)

Findings behind the `License`, `Version` and `Redistribution` columns of
`experimental_datasets.md` and `observational_datasets.md` (the md files are the
masters; `build_*_datasets_csv.R` copies the three columns into the CSVs unchanged).
EDI is GPL-3. Today no catalogued dataset ships with EDI (download caches are
gitignored, nothing under `R/EDI/data`), so none of this is a live obligation; it
constrains what could be bundled or committed later.

## What the columns mean

- **License** — the `License:` field of the source package's DESCRIPTION at the
  catalogued Version, verified against CRAN (`web/packages/packages.rds` for current
  releases, `src/contrib/Meta/archive.rds` + the per-version DESCRIPTION on the
  `cran/<pkg>` GitHub mirror for archived ones); Dataverse/GitHub/ICPSR rows carry the
  terms stated at the source. It is the *packager's* assertion, not a title search of
  the underlying data. 143 of 320 CRAN rows had wrong values before the audit
  (agent-written Expanded-tier metadata); all rows are now verified.
- **Version** — a release that exists on CRAN. 45 package/version pins (123 rows)
  matched no CRAN release and were replaced by the then-current release on
  2026-10-07; the same pins were fixed in `download_experimental_datasets.R`'s
  `DATASET_MANIFEST`, which must stay in step with the md (the observational
  downloader reads the md directly). Note `packageVersion()` prints `3.8-6` as
  `3.8.6`; compare with `numeric_version()`, not string equality. Ten rows are pinned
  to *old* releases on purpose (see "Ten rows deliberately pinned" below) — an old pin
  is not automatically a stale one.
- **Redistribution** — hand-maintained answer to "may EDI, as a GPL-3 package, bundle
  or share this dataset?". Vocabulary, enforced by `build_*_datasets_csv.R`:
  - `yes` — license is GPL-3-compatible: `GPL`, `GPL (>= 2)`, `GPL (>= 3)`, `GPL-3`,
    `GPL-2 | GPL-3`, LGPL, MIT, CC0, Unlimited, Part of R.
  - `yes, with attribution (CC BY 4.0)` — CC BY 4.0 is one-way compatible with GPL-3
    (`scidesignR::silkdat`).
  - `conditional: AGPL-3 (...)` — `glmmTMB::Salamanders`; a bundled copy stays AGPL-3.
  - `unclear: ...` — the package license permits it but the help page's `\source{}`
    says the packager's right to pass it on is narrower (see below).
  - `no: GPL-2 only` — `GPL-2` / `GPL-2 | file LICENSE` (s20x's LICENSE file is the
    plain GPL-2 text); GPL-2-only material cannot be included in a GPL-3 work.
  - `no: ICPSR terms of use` — restricted-terms downloads; fetch and use locally only.
  - `no: <data-level restriction>` — conditions stated in the help page that the
    package license does not convey (`surrosurv::gastadv`, `coxphw::biofeedback`).

  Any value other than plain `yes` means: fetch and use locally, do not commit or bundle
  without a decision.

## Rows that are not plain `yes`

| Redistribution | Experimental | Observational |
|---|---|---|
| `no: GPL-2 only` | 17 (glmm, gpk, hiddenf, HLMdiag, HSAUR3, isdals, moderate.mediation, PASWR2, pscl::RockTheVote, QDComparison, randomizationInference, stevedata, vegan, VGAMdata) | 12 (COUNT, catdata, insuranceData, ISLR, Lock5Data, medflex, pscl) |
| `no: ICPSR terms of use` | 2 | 1 |
| `no:` data-level restriction | `surrosurv::gastadv` (GASTRIC Group: research use only, confidentiality, results shared with the group before publication, source acknowledged — five conditions in `?gastadv`); `coxphw::biofeedback` (donor "gave permission to freely distribute the data and use them for non-commercial purposes") | — |
| `unclear:` relabelled upstream | `DigestiveDataSets::gastric_cancer_trial_df` is coin 1.4-3's data (coin is GPL-2 only) re-released as GPL-3; `NeuroDataSets::epilepsy_RCT_tbl_df` is pubh 2.0.0's data (pubh is GPL-2 only) re-released as `GPL (>= 2) \| GPL-3`. The relabelling is the repackager's, not the upstream authors'. | — |
| `unclear:` permission to packager | `stepp::aspirin` (Polyp Prevention Study Group), `stepp::bigCI` (BIG 1-98 / IBCSG) — help pages acknowledge permission granted to the stepp authors; `mediation::jobs` — a subset of the JOBS II data archived at ICPSR | — |
| `conditional: AGPL-3` | — | `glmmTMB::Salamanders` |
| `yes, with attribution` | `scidesignR::silkdat` | — |

### Ten rows deliberately pinned to old, GPL-3-compatible releases

Some packages that are GPL-2 only today were `GPL (>= 2)` or unversioned `GPL` (any
version) in earlier releases. Where the catalogued data object is `identical()` between
the old release and the current one, the row is pinned (md + `DATASET_MANIFEST`) to the
**last compatible release**, and the downloader fetches that tarball from CRAN's
`Archive/`, so the data really does arrive under a GPL-3-compatible license:

| Rows | Pinned release (license) | Current release (license) |
|---|---|---|
| `PASWR::Aggression`, `PASWR::Ratbp`, `PASWR::Swimtimes` | PASWR 1.1 (`GPL (>= 2)`) | 1.3 (`GPL-2`) |
| `s20x::teach.df`, `s20x::thyroid.df` | s20x 3.1-10 (`GPL (>= 2)`; data as `.txt.gz`) | 3.3.0 (`GPL-2 \| file LICENSE`, LICENSE = GPL-2 text) |
| `coin::rotarod` | coin 0.6-4 (`GPL`) | 1.4-6 (`GPL-2`) |
| `nlmeU::armd0`, `nlmeU::prt.subjects` | nlmeU 0.70-9 (`GPL (>= 2)`) | 0.71-7 (`GPL-2`) |
| `pscl::bioChemists` (obs) | pscl 0.92 (`GPL`) | 1.5.9 (`GPL-2`) |
| `Epi::thoro` (obs) | Epi 1.1.10 (`GPL (>= 2)`; data as `thoro.R`) | 2.63 (`GPL-2`) |

All ten objects were verified `identical()` across releases and the downloaders write
byte-identical CSVs from either. **Do not "update" these pins to the current release**
— that silently turns the rows back into `no: GPL-2 only`. (The two non-`.rda` storage
formats are why both fetchers — `cran_download_dataset_as_csv()` and
`cran_fetch_object_auto()` — match data files with compression suffixes stripped and
can `sys.source()` a `data/<obj>.R` file.)

Release-history sweep (2026-10-08): every archived DESCRIPTION of every GPL-2-only
package in the catalogs was checked (437 releases, 24 packages). The four above plus
PASWR/s20x are the only ones that ever had a compatible license; `pscl::RockTheVote`
does not exist in pscl 0.92 so it stays GPL-2 only, and the rest (glmm, gpk, hiddenf,
HLMdiag, HSAUR3, isdals, moderate.mediation, PASWR2, QDComparison,
randomizationInference, stevedata, vegan ("GPL v2 (but not later)"), VGAMdata, catdata,
COUNT, insuranceData, ISLR, Lock5Data, medflex, surrosurv) have been GPL-2 only in
every release.

## Provenance of the data behind the package licenses

For every CRAN row (339 at audit time) the help page's `\source{}` and `\references{}`
were extracted from the pinned tarball and categorised. This is the only evidence
available about whether the packager had the right to apply the license; nothing was
verified with the original data owners.

| Primary category | Experimental | Observational |
|---|---|---|
| Published study (journal cited) | 96 | 22 |
| Textbook companion data | 59 | 33 |
| Public / government source | 42 | 21 |
| Other (software docs, course material, …) | 19 | 5 |
| No `\source{}` and no `\references{}` | 20 | 2 |
| Private communication / unpublished | 7 | 6 |
| Permission granted to the packager / ICPSR-derived | 3 | 0 |
| Explicit extra use conditions | 2 | 0 |

- **No stated source (22):** `geepack::respiratory`, `qte::lalonde.exp`,
  `experiment::seguro`, `cofad::testing_effect`, `collett::tamoxifen`,
  `collett::active_hepatitis`, `coursekata::TipExperiment`,
  `heritable::lettuce_phenotypes`, `labstats::locomotor`, `isdals::cornyield`,
  `moderate.mediation::newws`, `RCT2::jd`, `Rlab::magnet`, `s20x::teach.df`,
  `s20x::thyroid.df`, `scidesignR::silkdat`, `splmm::cognitive`, `wgaim::phenoCxR`,
  `wgaim::phenoRxK`, `wgaim::phenoSxT`; observational `biostat3::melanoma`,
  `biostat3::diet`. (Several are well-known data — `respiratory`, `lalonde.exp` — whose
  help page simply omits the citation.)
- **Private communication / unpublished (13):** `hnp::fungi`, `MNM::beans`,
  `multiDimBio::Nuclei`, `SMPracticals::arithmetic`, `SMPracticals::teak`,
  `Stat2Data::Alfalfa`, `Stat2Data::Milgram`; observational `survival::nafld1`,
  `survival::mgus2`, `relsurv::colrec`, `carData::Blackmore`, `carData::Arrests`,
  `SNPassoc::SNPs`.
- **Textbook companions** are mostly maintained by the book authors themselves
  (Arnholt, Dalgaard, Faraway, Davison, Ramsey & Schafer via Turlach, Hothorn &
  Everitt) — the low-risk case. Third-party ports: `KMsurv` (11 rows; Klein &
  Moeschberger's data packaged by others) and `wooldridge` (3 rows).
- **Bulk re-packagers** (`DigestiveDataSets`, `NeuroDataSets`, `CardioDataSets`,
  `ForCausality`) copy data out of other CRAN packages and relicense it; their License
  cell is only as good as that relicensing (two rows flagged `unclear:` above).

## Not real data — dropped 2026-10-08

`rpsftm::immdef` (help page: "simulated data") and `biostat3::colon` ("based on a
simulation of a population-based cancer registry") did not meet the catalogs'
real-data criterion and were removed from the md, the CSVs and the experimental
manifest.

## Test-time covariate sources outside the catalogs

`R/package_tests/_dataset_load.R` draws covariates from 14 datasets that are not in
either catalog. Seven come from GPL-2-only packages — `mlbench` (Glass, Sonar, Soybean,
BreastCancer, Ionosphere) and `AppliedPredictiveModeling` (abalone, FuelEconomy) —
so they can be loaded from installed packages at test time but not bundled as packaged.
The rest (`MASS` Boston/Cars93/Pima.tr2, `ggplot2::diamonds`, base `iris`/`airquality`,
`PTE::continuous_example`) are compatible. The mlbench sets and abalone are UCI
originals and `FuelEconomy` is US government data, so a bundled copy could be taken
from the primary source; UCI's per-dataset terms were not checked.
