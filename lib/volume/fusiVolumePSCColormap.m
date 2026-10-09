function map=fusiVolumePSCColormap(map,clearOverlay)
% Preserve the quantitative Video LUT exactly. Strengthening opacity must
% never recolor a low PSC or change the meaning of the selected color range.
% Retain the second argument for existing renderer callers.
if nargin<2,clearOverlay=false;end %#ok<NASGU>
end
