function info=fusiVolumeGeometry(par,shape,sequencePath)
% Sampling comes from metadata; reference sequence constants are not a PSF.
par.scmSizeYXZ=shape;c=scmSpatialCalibration(par);
info=struct('spacingUm',c.spacingUm,'source',c.source,'shapeYXZ',shape, ...
    'fieldOfViewMm',shape.*c.spacingUm/1000, ...
    'resolutionStatement','Acoustic resolution is not measured by voxel spacing. It requires pulse/bandwidth and aperture information or a measured point-spread function.');
if nargin<3,sequencePath='Z:/fUS/Scripts_fUSI_Soner/paramMatrix15M_1024_V1.m';end
% A matrix reference is not evidence for an fMRI or another probe's geometry.
if shape(2)~=64 || shape(3)~=54,return;end
if ~isfile(sequencePath),return;end
src=fileread(sequencePath);cmm=constant('cp.acq.c');f=constant('cp.acq.freqTX');
if ~isempty(cmm) && ~isempty(f) && cmm>0 && f>0
    info.referenceSequence=sequencePath;info.referenceTransmitMHz=f;
    info.referenceSoundSpeedMps=cmm*1000;info.referenceWavelengthUm=cmm/f*1000;
    info.nominal15MHzWavelengthUm=cmm/15*1000;
    info.referenceNote='Sequence-file settings, not a frequency saved in this recording. Wavelength is not measured acoustic resolution.';
end
    function v=constant(key)
        tok=regexp(src,[regexptranslate('escape',key) '\s*=\s*([0-9.]+)\s*;'],'tokens','once');
        v=[];if ~isempty(tok),v=str2double(tok{1});end
    end
end
