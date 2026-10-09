function mask=fusiAtlasBrainMask(atlas,regions)
% Atlas labels are table indices in the bundled atlas: index 1 is background.
% Other atlases may use zero background. Consult names rather than assuming
% every nonzero index represents brain, which creates a rectangular surface.
if nargin<2,regions=atlas.Regions;end
mask=isfinite(regions) & regions~=0;
if isfield(atlas,'infoRegions') && isfield(atlas.infoRegions,'name')
    names=string(atlas.infoRegions.name);
    background=find(ismember(lower(strtrim(names)),["background","outside","outside brain","clear label"]));
    mask=mask & ~ismember(abs(double(regions)),background);
end
end
