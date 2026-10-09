function [tissue,selected,description]=scmAtlasSearchMask(opt,z,shape)
tissue=true(shape);selected=[];description=[];
if ~isfield(opt,'atlasLabels')||isempty(opt.atlasLabels),return;end
L=opt.atlasLabels;
assert(size(L,3)>=z&&isequal(size(L,[1 2]),shape),'deConfUSIon:AtlasSearchGrid','Atlas labels must match the functional search grid.');
L=abs(double(L(:,:,z)));tissue=isfinite(L)&L>0;
if isfield(opt,'excludedAtlasIDs'),tissue=tissue&~ismember(L,opt.excludedAtlasIDs);end
if isfield(opt,'atlasRegion')&&~isempty(opt.atlasRegion)
 description=opt.atlasRegion;selected=L==description.id;
end
end
