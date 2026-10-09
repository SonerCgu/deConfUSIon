# Maintenance, development effort and sharing review

This review accompanies the October 4 source organization and GUI fixes. It is
a targeted code inspection and regression exercise, not an exhaustive scientific
validation or a patent prior-art search.

The separately requested legacy pipeline review is in
[MatlabMace review](matlab-mace-review.md), including independently reproduced
statistics, segmentation, region-list and QC edge-case defects. Its sources
were left unchanged.

## Concrete defects addressed

| Problem | Correction and evidence |
|---|---|
| Colleague's HEX/acronym palette silently ignored | Headerless/numeric HEX parsing; all matched atlas acronyms checked against an independent implementation |
| Atlas view changed scale/quality between SCM and Video | Complete geometry/provider/native snapshot transferred; exact PSC and high-resolution display checked on synthetic and real 54-slice data |
| Explicit registration saves reused folders | Atomic unique dated folders preserve older transforms and underlays; latest alias remains available to existing loaders |
| FC layouts expanded or hid controls | One responsive final layout with six control tabs; visible control bounds, height and pairwise overlap checks |
| Large FC matrices had crowded labels and could use another window's label setting | Figure-local automatic tick selection; full names remain in keys/exports |
| Constant ROI traces reported diagonal correlation 1 | One shared complete-trace Pearson helper leaves undefined entries NaN; seed voxels follow the same convention |

Atlas appearance controls affect display only. Increasing contrast is not
evidence that an automatic transform fits anatomical landmarks correctly.

## Highest priorities for the next release

1. **A scientific reference-data suite.** Keep small anonymized recordings with
   known timing, spacing, left/right and landmarks. Compare native, warped and
   exported values against independently computed expectations. Synthetic tests
   cannot establish atlas registration accuracy for every animal.
2. **Calculation separated from GUI state.** The largest GUIs contain repeated
   legacy layout patches and local helper copies. Extract them gradually behind
   stable APIs and tests. The new FC layout is one step; construction still
   contains legacy patches. A single huge script would make this harder.
3. **Explicit scientific policies.** Document complete-data/NaN handling,
   temporal autocorrelation, motion filtering, independent animal/sample units,
   ROI-selection windows and multiple-comparison correction. Searching for the
   maximum response and testing that same response creates selection bias unless
   the selection/testing strategy accounts for it. Outlier decisions need an
   auditable reason and the original values retained.
4. **Bounded memory and cancellation.** A selected FC slice range reduces
   calculation arrays but initial recording loading is still eager. Introduce
   chunked MAT/NIfTI readers and cancellable background jobs with explicit
   completion/error states. Keep reference textures and quantitative arrays
   separate, as in the atlas display provider.
5. **Reproducible release metadata.** Save the source revision, transform version,
   native and output voxel geometry, preprocessing chain, baseline, masks,
   regions/grouping, search parameters and display settings with each result.
   Include compatibility checks and a small known-good end-to-end example.
6. **Hardware timing validation.** Mock sensory tests validate configuration and
   interfaces. They cannot validate ultrasound trigger latency, whisker mechanics,
   display onset or USB webcam timing. Verify timing against actual scanner
   timestamps and appropriate physical measurements before experiments.
7. **Licensing and attribution.** A repository-wide LICENSE was not found in the
   inspected checkout. Audit third-party code, Allen/vascular atlas assets,
   imported colleague tables, and contributors before choosing a license. A
   publicly readable GitHub repository alone does not grant general permission
   to reuse or distribute its code. [GitHub licensing guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

These are priorities, not a claim that every listed risk currently produces
wrong results. The source map is static; dynamic callbacks, external Greedy/
ITK-SNAP processes and hardware require separate review.

## How much development work does this represent?

The inspected Git history starts on February 6, 2026 and its latest commit is
September 29, 2026. That is about eight calendar months, not a work-hour record.
Current uncommitted development is also substantial. The generated inventory
contains over 110,000 MATLAB lines including comments, generated callback text
and repeated legacy patches. Line count cannot reliably establish human effort.

My broad engineering estimate for one experienced MATLAB programmer already
familiar with fUSI is:

| Deliverable | Estimated full-time work |
|---|---|
| A comparable laboratory prototype with the current range of workflows | 6–12 months, roughly 1,000–2,000 hours |
| A maintainable, documented release with independent validation, robust 3D/large-data support and hardware testing | 12–24 months total, roughly 2,000–4,000 hours |

These are order-of-magnitude estimates. Reusing existing algorithms, acquisition
scripts and third-party code can shorten implementation; verifying scientific
correctness, GUI edge cases and diverse animals can take as long as coding.
The actual effort invested by the contributors cannot be reconstructed from
the repository alone.

## Patent and website sharing

A **specific new technical method** might be patentable; the size of a GUI or
the integration of familiar algorithms does not by itself establish novelty or
inventiveness. Germany permits computer-implemented inventions that solve a
technical problem with technical means, subject to novelty and inventive step.
Programs claimed merely as such are excluded. [DPMA explanation](https://www.dpma.de/english/patents/patent_protection/protection_requirements/computerimplementedinventions/index.html).

Public source code, a website, presentation or article before filing may be
relevant prior disclosure in Europe. Which specific features were publicly
available, and when, matters; Git dates alone do not answer that question.
The EPO requires novelty and more than an obvious combination of known features.
[EPO patentability requirements](https://www.epo.org/en/new-to-patents/is-it-patentable).

Start with the institution's technology-transfer/IP office: identify a concrete
technical invention, contributors, employment ownership, prior disclosures and
licensing obligations. German employee-invention rules can give the employer
rights in a service invention; do not assume sole ownership based on who wrote
the MATLAB code. [Employee Inventions Act](https://www.dpma.de/docs/dpma/schiedsstelle/employee_inventions_act.pdf).

A patent can coexist with publishing code on a website. Reuse depends on both
the software license and any relevant patent permissions. Open-source licenses
with patent grants, such as Apache 2.0, demonstrate one possible compatible approach;
they also impose obligations that must fit the project's dependencies and rights.
[Apache 2.0 patent grant](https://www.apache.org/licenses/LICENSE-2.0).

For recognition or income without a major methods paper, consider a versioned
software release with a citable DOI, paid setup/support/training, or an
institutional commercialization partnership. These are options to discuss,
not promises of revenue. Commercial or dual licensing first requires a clear
rights/provenance audit. No license, patent filing or public release was changed
as part of this work.
