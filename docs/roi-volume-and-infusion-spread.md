# Injection-site ROI size and infusion spread

For animal 1287, the raw scanner header and matrix-probe sequence agree on
native sampling of **0.10 x 0.15 x 0.15 mm** in depth/row, left-right/column,
and slice order. These are sample spacings, not a measured ultrasound
point-spread function or an independently measured slice thickness.

## What the 7- and 9-slice numbers mean

The earlier suggestion is an **equivalent-volume geometric model**, not a
measurement or prediction of PACAP distribution. Assume a sphere with volume
equal to the injected liquid, with no correction for tissue, diffusion,
convection, binding, clearance or reflux. Since 1 microlitre = 1 cubic mm:

```text
V = (4/3) pi r^3
r = (3V/(4 pi))^(1/3)
d = 2r = (6V/pi)^(1/3)
N_slice approximately ceil(d / 0.15 mm)
voxel-cell volume = 0.10 x 0.15 x 0.15 = 0.00225 cubic mm
```

| Injected volume | Sphere radius | Sphere diameter | Approximate slice span | Continuous sphere volume / voxel-cell volume |
| --- | --- | --- | --- | --- |
| 0.5 microlitre | 0.492 mm | 0.985 mm | 7 slices | 222 voxel equivalents |
| 1.0 microlitre | 0.620 mm | 1.241 mm | 9 slices | 444 voxel equivalents |

Seven contiguous slice cells span 1.05 mm; nine span 1.35 mm. Their first-to-last
sample-center distances are 0.90 and 1.20 mm. Centering on a slice gives
indices z0-3 through z0+3, or z0-4 through z0+4. Alignment with the voxel grid
and partial-volume treatment can change the count. A sampled spherical mask
will also differ slightly from the continuous voxel-equivalent counts above.

A sphere is not the same square on every slice. At physical distance z from
its center, its cross-section radius is sqrt(r^2-z^2). Use physical spacing
in an anisotropic mask:

```text
((row-row0)*0.10)^2 + ((column-column0)*0.15)^2
  + ((slice-slice0)*0.15)^2 <= r^2
```

The ROI should be centered on an anatomically verified cannula tip/target,
with the same prespecified physical size on target and control sides. A
roughly 1-mm diameter ROI over seven slices is a provisional injection-site
ROI; it does not establish complete drug coverage. An ROI spanning multiple
slices contributes one animal-level value, not several independent animals.

## What is missing for a spread estimate

Actual distribution volume Vd need not equal infusion volume Vi. If an
experiment establishes k = Vd/Vi, the equivalent distribution diameter is:

```text
d_distribution = (6 k Vi / pi)^(1/3)
N_slice approximately ceil(d_distribution / 0.15 mm)
```

For illustration only, assuming k=5 gives 1.684 mm (12 slice cells) for
0.5 microlitre and 2.122 mm (15 slice cells) for 1 microlitre. **k=5 is not
validated for this PACAP protocol and these are not recommended coverage
ROIs.** Neither a 33-gauge cannula nor voxel spacing determines k.

Diffusion additionally depends on elapsed time and an effective diffusion
coefficient: in an ideal isotropic, unbounded diffusion-only model, the
root-mean-square displacement is sqrt(6 D_eff t). This is not a sharp
drug boundary. Infusion adds convection, and tissue binding and clearance
change the concentration distribution. A diffusion coefficient, infusion
rate, target anatomy and relevant time/concentration threshold are missing.

To report drug coverage, measure a suitable tracer/distribution marker under
the actual infusion conditions, verify its relationship to PACAP, measure
the anterior-posterior extent L, and choose approximately ceil(L/0.15 mm)
slice cells with a predefined edge/partial-volume rule. Histology of the
cannula track verifies placement; it alone does not measure PACAP spread.
Voxel sampling controls how that measured extent is represented, not how far
the compound travels. Functional PSC spread is not a direct concentration map.

## Relevant papers and what they support

1. [Oh et al. (2007), Improved distribution of small molecules and viral vectors in the murine brain using a hollow fiber catheter, J Neurosurg 107:568-577](https://pmc.ncbi.nlm.nih.gov/articles/PMC2615393/).
   Mouse experiments show that catheter design and infusion method change
   distribution. The paper uses measured ellipsoidal geometry in agarose and
   serial-section area measurements in brain. Its 28-gauge, 2-microlitre
   protocol is different from the user's 33-gauge PACAP protocol.
2. [Bobo et al. (1994), Convection-enhanced delivery of macromolecules in the brain, PNAS 91:2076-2080](https://doi.org/10.1073/pnas.91.6.2076).
   Demonstrates that pressure-driven convection changes intracerebral
   distribution; injected liquid volume alone does not specify the region.
3. [Sykova and Nicholson (2008), Diffusion in Brain Extracellular Space, Physiol Rev 88:1277-1340](https://pmc.ncbi.nlm.nih.gov/articles/PMC2785730/).
   Reviews diffusion coefficients, extracellular volume fraction, tortuosity,
   binding and clearance. These explain why geometric liquid volume is not
   sufficient for predicting a drug's spatial reach.

These papers support the transport limitations and geometric measurement
approach. **None validates a 7- or 9-slice PACAP spread boundary for this
recording.** The numerical table is derived from the stated sphere assumption.
