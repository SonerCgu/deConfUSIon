# Automatic masks for a matrix recording

Mask Editor **AUTO MASK** now proposes a mask using the full 3D temporal mean
Doppler volume. It uses neighboring slices and the recorded row/column/slice
spacing, so sparse vessels do not have to form the largest connected area on
every individual plane. An explicitly selected external anatomy is used instead
of Doppler when External mode is active. Brightness, gamma, sharpening and
vessel display controls do not change this proposal.

The proposal rejects empty, nonfinite and spatially unstructured planes, removes
narrow nearly full-width intensity spikes, and retains substantial disconnected
brain components. It fills enclosed low-Doppler cavities for a brain mask. An
existing brain restriction, including its holes and empty planes, is respected
when proposing an overlay mask.

**Current slice** changes only that slice; neighboring slices still inform the
proposal. **All slices** applies the volume proposal. Lower sensitivity produces
a larger mask, higher sensitivity produces a tighter mask, and the existing
inward edge shrink remains available. Painting and manual corrections remain
unchanged. This is a Doppler-based proposal to review, not a registered atlas
segmentation or a measured anatomical boundary.

Saved Mask Editor metadata includes the latest automatic proposal method,
sensitivity, edge shrink, source, selected slices and spacing. Saved raw Doppler
and functional data are unchanged. The existing 2D automatic mask stays in use
for single-plane recordings and for the toolbox-free fallback.
