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

progress=deConfUSIon_ui('progress','Motion correction - frame interpolation');
guard=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
Iout = deConfUSIon_signal('interpolate',I,outliers,@(fraction)deConfUSIon_ui('progressupdate',progress,fraction,'Interpolating rejected frames'));

end
