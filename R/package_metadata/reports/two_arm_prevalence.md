# Prevalence of Two-Arm Randomized Experiments Across Fields

Research date: September 16, 2026.

## Executive summary

A working estimate is that **roughly two-thirds to three-quarters of randomized human experiments have exactly two arms**. Clinical trials appear closer to **80–85%**, and commercial online experiments around **70–80%**. Economics and experimental psychology are less clearly dominated by two-arm designs.

For **all randomized experiments worldwide**, including agriculture, animal research, laboratory biology, and industrial experimentation, **about 65% is only a provisional planning assumption**, with a broad **40–85% sensitivity range**. This is a judgment based on incomplete evidence, not a measured global prevalence or a statistical confidence interval. The evidence does not establish worldwide field weights or a globally representative arm-count distribution.

The findings support EDI's two-arm focus as addressing a very large setting. They do **not** support claiming that EDI covers “80–90% of all experiments.”

## Scope and approach

This report summarizes a targeted web-based review of published methodological audits, trial reviews, primary research papers, and commercial experimentation benchmarks. It is not a systematic review with a preregistered search strategy or an exhaustive worldwide census. No new registry extraction or experiment-level dataset analysis was performed. Arithmetic derived from reported counts is identified below, and planning assumptions are separated from observed findings.

The intended denominator is the number of randomized experiments, rather than the number of papers, participants, outcomes, or hypothesis tests. The evidence spans different historical periods and sampling frames; it should not be read as a direct measurement of prevalence in 2026 or across all historical experiments.

## 1. Definition of a two-arm experiment

An experiment is two-arm when it randomly assigns units to exactly two intervention conditions, counting the control as an arm.

This includes unequal allocation, cluster randomization, blocking, and matched pairs. It excludes a control plus two treatments and a 2 × 2 factorial experiment with four treatment combinations.

Three distinctions are essential:

- **Two levels per factor does not mean two arms per experiment.**
- **A two-group comparison extracted from a multi-arm study does not make the original experiment two-arm.**
- **The counting unit matters:** one paper may contain several experiments, and one experiment may generate many comparisons.

Crossover and repeated-measures studies need separate flags: two treatment conditions alone do not establish compatibility with EDI's inference procedures. Published sources also vary in whether they count treatment conditions, randomized sequences, or groups.

## 2. Direct empirical evidence

| Field and source | Sample | Finding | Interpretation |
|---|---|---|---|
| Clinical medicine: Baron et al., 2013 | 1,690 RCT reports in core clinical journals, published in 2009 | 17.6% had more than two arms → **82.4% two-arm** | Broad clinical evidence, but older and restricted to selected English-language journals. [Study](https://pmc.ncbi.nlm.nih.gov/articles/PMC3621416/) |
| Publicly funded clinical effectiveness trials: Pike et al., 2022 | 138 trials published January–June 2018 in seven major outlets | 23 had more than two treatment groups → **83.3% two-group** | Supports the earlier estimate in a different clinical sample. [Study](https://pmc.ncbi.nlm.nih.gov/articles/PMC8818238/) |
| Phase III oncology: 2021 review | ClinicalTrials.gov trials from 2010–2019 | Authors report **90% two-arm** | A narrower clinical subgroup, not a general medical estimate. [Study](https://pmc.ncbi.nlm.nih.gov/articles/PMC8332855/) |
| Commercial online experimentation: Optimizely benchmark | 173,000 qualifying experiments across 1,200+ companies, 2018–2026 | Approximately **75% simple A/B tests** | Large and recent, but vendor-reported and limited to its customers and eligibility criteria. [Benchmark](https://www.optimizely.com/field-notes/guides/173000-experiments) |
| Commercial online experimentation: Berman and Van den Bulte | 2,766 experiments from 1,349 accounts, initiated April 2014 | 36% had multiple nonbaseline variants → **64% two-arm** | Peer-reviewed evidence showing variation across samples and periods. [Paper, §4.2](https://gwern.net/doc/statistics/decision/2021-berman.pdf) |
| Economics field experiments: Muralidharan, Romero, and Wüthrich | 124 field-experiment articles in the top five economics journals, 2007–2017 | **22% used factorial designs** | Does not establish the two-arm percentage: nonfactorial studies can also have three or more arms. The sampling unit is an article. [Study](https://direct.mit.edu/rest/article/107/3/589/115272/Factorial-Designs-Model-Selection-and-Incorrect) |
| Social psychology: manipulation audit | 244 experimental studies containing 348 manipulations in selected sections of JPSP | **66.8%** used one manipulation; **82.18% of manipulations** had two conditions | These are different denominators; neither number is the percentage of two-arm studies. [Study](https://pmc.ncbi.nlm.nih.gov/articles/PMC7954782/) |
| School-based public health: Parker et al., 2022 | 24 UK school-based feasibility cluster trials | 21 were two-arm → **87.5%** | Useful corroboration for this niche, not representative of education generally. [Study](https://repository.essex.ac.uk/33118/1/b687bcd1-6534-47dd-b35a-a4f52a119153.pdf) |

### Clinical trials

The two broad clinical reviews give closely aligned estimates of 82.4% and 83.3%. These provide a reasonable basis for an approximate 80–85% clinical planning value, while their publication restrictions and historical sampling periods limit worldwide generalization. The 90% figure in phase III oncology illustrates subgroup variation rather than providing a replacement for the broader estimates. Sources and sample definitions appear in the table above.

### Technology and commercial online experiments

The recent Optimizely benchmark provides a direct three-in-four estimate, while the older peer-reviewed sample gives 64%.

An independent web audit found 1,214 two-variant configurations and 247 configurations with more variants. Excluding 897 single-variant configurations gives **83.1% two-variant among configurations with at least two variants**, calculated as 1,214 / (1,214 + 247). This was a snapshot of website configurations, not a clean cohort of completed randomized experiments. [Jiang et al., Figure 14](https://cbw.sh/static/pdf/jiang-2019-fat.pdf)

There are substantial exceptions. Upworthy's archive contains **32,487 experiments and 150,817 arms**, giving a calculated average of **4.64 arms per experiment**. That average cannot identify its two-arm proportion, but it shows why “A/B testing” should not automatically be interpreted as exactly two-arm testing. [Archive paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC8329003/)

**Planning synthesis:** around **75%** is a reasonable commercial online value, with **60–85%** as a judgment-based sensitivity range across platforms and use cases. This is not a pooled estimate or confidence interval.

### Economics field experiments

The finding that 22% of field-experiment articles used factorial designs makes a near-universal two-arm claim implausible in that publication sample. Nonfactorial experiments can also compare multiple intervention versions or intensities, so subtracting 22% from 100% does not yield the two-arm share. A representative worldwide arm-count distribution was not found in this research. [Factorial-design audit](https://direct.mit.edu/rest/article/107/3/589/115272/Factorial-Designs-Model-Selection-and-Incorrect)

For planning, **40–70%** can be explored as a judgment range. Its endpoints are not estimated by the cited audit and should not be presented as measured field-wide prevalence.

### Psychology

The social psychology audit separates the number of manipulations per study from the number of conditions per manipulation. A rough calculation illustrates the difference:

```text
Share with one manipulation × share of manipulations with two conditions
= 0.668 × 0.8218
≈ 0.55
```

This suggests **about 55%** under the assumption that single-manipulation studies have the same two-level frequency as manipulations overall. **It is an extrapolation, not the review's reported result.** It does not resolve within-participant designs or generalize automatically to cognitive, developmental, and clinical psychology. [Manipulation audit](https://pmc.ncbi.nlm.nih.gov/articles/PMC7954782/)

For planning, **40–65%** can be explored for social psychology, explicitly as a judgment range rather than a measured prevalence interval.

### Other fields

Agriculture is heterogeneous. Some on-farm research typically compares a new practice with a standard practice using two treatments. That observation does not establish prevalence across agriculture as a whole. [On-farm trial methods paper](https://www.sciencedirect.com/science/article/abs/pii/S1161030120301349)

Industrial experimentation includes factorial, fractional factorial, screening, and response-surface designs. A two-level design can contain four, eight, sixteen, or more treatment combinations. [NIST experimental-design handbook](https://www.itl.nist.gov/div898/handbook/pri/section3/pri3.htm)

This research did not establish representative arm-count rates for agriculture overall, animal research, laboratory biology, industrial experiments, or political science. The school-based public-health result above also cannot stand in for all education experiments. These gaps materially limit the literal “all fields worldwide” estimate.

## 3. Worldwide estimation and sensitivity

The required quantity is a weighted average:

```text
P(two-arm) = sum over fields f of:
    P(field = f) × P(two-arm | field = f)
```

There is some evidence for the within-field prevalence term. The other term—the share of all experiments conducted in each field—is largely unknown. Fields must also be defined without overlap; for example, an online psychology experiment should not be counted twice.

Online experimentation could receive a very large weight. A 2020 paper reported annual experimentation rates exceeding 20,000 at Google, LinkedIn, and Microsoft, while explicitly warning that companies count experiments differently: a control plus two treatments may count as one experiment or two. [Kohavi et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC7007661/)

### Illustrative scenarios

Assume two-arm rates of **75% online**, **82% clinical**, and **50% in all remaining fields combined**. The final rate is deliberately illustrative, not empirically established.

| Assumed worldwide mix: online / clinical / other | Implied two-arm prevalence |
|---|---:|
| 30% / 10% / 60% | 60.7% |
| 70% / 10% / 20% | 70.7% |
| 90% / 5% / 5% | 74.1% |

These are **scenarios, not estimated worldwide field weights**. They explain why a figure around two-thirds is plausible under some assumptions, while showing why the available evidence cannot identify a precise global percentage. Giving greater weight to nonhuman experiments, or changing their assumed two-arm rate, can move the result substantially.

### Recommended internal planning assumptions

| Scope | Working value | Interpretation |
|---|---:|---|
| Randomized human experiments | **70%** | Judgment-based synthesis; roughly two-thirds to three-quarters is a working central range, not a confidence interval. |
| All randomized experiments, including nonhuman and industrial settings | **65%** | Provisional judgment with particularly weak information about field weights and several within-field rates. Explore **40–85%** in sensitivity analyses. |

The all-fields working value is not a computed estimate from a representative sample, and the 40–85% range does not have calibrated probability coverage. Neither should be presented as an established global statistic.

## 4. Implications for EDI

A defensible public statement is:

> EDI focuses on two-arm randomized experiments, a prevalent design accounting for approximately four-fifths of trials in broad clinical reviews and three-quarters of experiments in a large commercial online benchmark.

Use the [clinical review](https://pmc.ncbi.nlm.nih.gov/articles/PMC3621416/) and [Optimizely benchmark](https://www.optimizely.com/field-notes/guides/173000-experiments) to support that statement, retaining their sample qualifications when discussing the evidence in detail.

For internal planning, use the working values above and check whether decisions change across wider assumptions. Avoid describing the two-arm share as EDI's software-coverage percentage: matching the assignment mechanism, dependence structure, outcome, and estimand still matters.

**Conclusion:** two-arm prevalence provides a strong justification for EDI's focus. A precise worldwide prevalence claim would require additional representative data and a consistent experiment-counting convention.
