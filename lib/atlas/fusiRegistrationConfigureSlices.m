function [cfg,initial]=fusiRegistrationConfigureSlices(cfg,g,preparedSize,initial,atlasSize)
% Convert ORIGINAL source slice numbers into the prepared AP coordinate grid.
if ~isfield(cfg,'sourceSliceRange') || isempty(cfg.sourceSliceRange),return;end
r=double(cfg.sourceSliceRange(:)');count=preparedSize(1);ratio=1;
if isstruct(g) && all(isfield(g,{'originalSize','permutation','originalSpacingUm','atlasVoxelSizeUm'}))
    axis=g.permutation(1);count=g.originalSize(axis);
    ratio=g.originalSpacingUm(axis)/g.atlasVoxelSizeUm(1);
end
if numel(r)~=2 || any(~isfinite(r)) || any(r~=round(r)) || r(1)<1 || r(2)>count || diff(r)<=0
    error('deConfUSIon:AtlasSliceRange','Enter two increasing original slices inside 1 to %d.',count);
end
q=1+(r-1)*ratio;
if isstruct(g) && isfield(g,'flipAxes') && ismember(1,g.flipAxes)
    q=1+(count-r)*ratio;
end
cfg.preparedSliceRange=[max(1,ceil(min(q))) min(preparedSize(1),floor(max(q)))];
if isfield(cfg,'atlasAPAnchors') && ~isempty(cfg.atlasAPAnchors)
    anchors=double(cfg.atlasAPAnchors(:)');
    if numel(anchors)~=2 || any(~isfinite(anchors)) || any(anchors<1 | anchors>atlasSize(1))
        error('deConfUSIon:AtlasAnchors','Atlas AP endpoints must lie inside 1 to %d.',atlasSize(1));
    end
    scale=diff(anchors)/diff(q);
    if scale<.7 || scale>1.4
        error('deConfUSIon:AtlasAnchors','Endpoints imply a reflection or an AP scale outside 0.7-1.4. Check slice direction and spacing.');
    end
    % Endpoint initialization is one coherent 3D affine, not separate slice fits.
    initial(1:3,2)=0;initial(2,2)=scale;initial(4,2)=anchors(1)-q(1)*scale;
    cfg.useCurrent=true;
end
end
