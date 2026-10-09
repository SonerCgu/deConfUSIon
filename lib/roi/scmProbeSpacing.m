function c=scmProbeSpacing(which)
% Verified beamformer grids from the two user-supplied sequence files.
% cp.bf is in mm in this scanner; element pitch cp.probe.dx is NOT voxel pitch.
switch lower(which)
 case 'matrix'
  c=struct('spacingUm',[100 150 150],'rawSpacing',[.1 .15 .15], ...
   'source','Matrix sequence paramMatrix15M_1024_V1.m: bf.dz/dx/dy in mm. Native grid only.', ...
   'expectedColumns',64,'expectedSlices',54);
 case 'linear'
  c=struct('spacingUm',[45 45 NaN],'rawSpacing',[.045 .045], ...
   'source','Linear sequence paramLinear15M_128_D.m: bf.dz=bf.dx=probe.dx/2=0.045 mm. Motor step is not specified.', ...
   'expectedColumns',256,'expectedSlices',NaN);
 otherwise
  error('deConfUSIon:ProbeSpacing','Unknown sequence profile.');
end
end
