function regions=scmSearchRegions(opt,z,include)
% Image coordinates: X = column, Y = row. Never infer anatomical laterality.
if isfield(opt,'atlasRegions')&&~isempty(opt.atlasRegions)
    chosen=opt.atlasRegions;opt=rmfield(opt,'atlasRegions');regions=[];
    for k=1:numel(chosen)
        opt.atlasRegion=chosen(k);part=scmSearchRegions(opt,z,include);
        regions=[regions part]; %#ok<AGROW>
    end
    return;
end
[ny,nx]=size(include); b=double(opt.boundsXY(:)');
assert(numel(b)==4 && all(isfinite(b)&b==round(b)) && b(1)>=1 && b(2)<=nx && b(3)>=1 && b(4)<=ny && b(1)<=b(2) && b(3)<=b(4), ...
    'deConfUSIon:SearchBounds','Bounds must be integer X start/end, Y start/end inside the image.');
[X,Y]=meshgrid(1:nx,1:ny);
% Atlas labels define search membership independently of the uploaded SCM
% display mask. Acquired sample validity is still checked by AutomaticSCM.
if isfield(opt,'atlasLabels') && ~isempty(opt.atlasLabels)
    include=true(ny,nx);
end
base=logical(include)&X>=b(1)&X<=b(2)&Y>=b(3)&Y<=b(4);
[tissue,selected,atlasRegion]=scmAtlasSearchMask(opt,z,[ny nx]);base=base&tissue;
if isfield(opt,'paintMasks') && numel(opt.paintMasks)>=z && ~isempty(opt.paintMasks{z})
    painted=opt.paintMasks{z};
    assert(isequal(size(painted),[ny nx]),'deConfUSIon:PaintMask','Painted mask must match the image size.');
    base=base&logical(painted);
end
regions=struct('name','Search','role','Search','mask',base,'polygonXY',[], ...
    'atlasRegionMask',selected,'atlasRegion',atlasRegion);
selection='Both';
if isfield(opt,'roiSelection'), selection=char(opt.roiSelection); end
assert(any(strcmp(selection,{'Both','Target','Control'})), ...
    'deConfUSIon:SearchRole','ROI selection must be Both, Target or Control.');
if ~opt.bilateral
    if ~isempty(atlasRegion),regions.name=atlasRegion.acronym;end
    if ~strcmp(selection,'Both'), regions.role=selection; end
    return;
end
assert(isscalar(opt.splitX)&&isfinite(opt.splitX)&&opt.splitX>=1&&opt.splitX<nx, ...
    'deConfUSIon:SearchBounds','Split X must lie between the first and last image columns.');
names={'Image-left','Image-right'}; roles={'Target','Control'};
if ~opt.leftIsTarget, roles=fliplr(roles); end
for k=1:2
    p=opt.polygons{z,k};
    if isempty(p)
        if k==1, m=X<=opt.splitX; else, m=X>opt.splitX; end
    else
        assert(size(p,2)==2&&size(p,1)>=3&&all(isfinite(p(:))), ...
            'deConfUSIon:SearchBounds','A region needs at least three finite polygon vertices.');
        m=inpolygon(X,Y,p(:,1),p(:,2));
    end
    name=names{k};if ~isempty(atlasRegion),name=[atlasRegion.acronym ' / ' name];end
    selectedSide=selected;if ~isempty(selected),selectedSide=selected&m;end
    regions(k)=struct('name',name,'role',roles{k},'mask',base&m,'polygonXY',p, ...
        'atlasRegionMask',selectedSide,'atlasRegion',atlasRegion);
end
assert(~any(any(regions(1).mask&regions(2).mask)), ...
    'deConfUSIon:SearchOverlap','Left/right search regions overlap. Redraw them or reset to the split.');
if ~strcmp(selection,'Both'), regions=regions(strcmp({regions.role},selection)); end
end
