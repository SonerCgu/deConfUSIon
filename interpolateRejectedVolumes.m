function Iout = interpolateRejectedVolumes(I, outliers)
% interpolateRejectedVolumes
% ------------------------------------------------------------
% Interpolate rejected volumes along time (Urban/Montaldo style)
%
% INPUT
%   I        : [nz x nx x nVols]
%   outliers : logical [nVols x 1]
%
% OUTPUT
%   Iout     : same size as I
%
% LOGIC:
%   IDENTICAL to fusi_video_soner10
%
% Author: Soner Caner Cagun
% Refactor: Naman Jain
% ------------------------------------------------------------

Iout = deConfUSIon_signal('interpolate',I,outliers);

end
