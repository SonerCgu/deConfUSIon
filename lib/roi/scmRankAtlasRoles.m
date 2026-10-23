function reports=scmRankAtlasRoles(A,TR,labels,info,opt,progress)
% One whole-volume ranking per explicitly chosen IMAGE side / role.
if nargin<6,progress=@(~,~)[];end
shape=[size(labels,1) size(labels,2) size(labels,3)];nx=shape(2);
if ~isfield(opt,'bilateral'),opt.bilateral=false;end
if ~isfield(opt,'roiSelection'),opt.roiSelection='Both';end
if ~isfield(opt,'leftIsTarget'),opt.leftIsTarget=true;end
if ~isfield(opt,'splitX'),opt.splitX=floor(nx/2);end
assert(any(strcmp(opt.roiSelection,{'Both','Target','Control'})), ...
    'deConfUSIon:AtlasRankingRole','Choose Target, Control, or both.');
assert(any(numel(opt.topCount)==[1 2])&&all(isfinite(opt.topCount)&opt.topCount>=0&opt.topCount==round(opt.topCount)), ...
    'deConfUSIon:AtlasRankingCount','Top region counts must be nonnegative integers.');
if isfield(opt,'atlasRegions')&&~isempty(opt.atlasRegions)
    labels(~ismember(abs(double(labels)),[opt.atlasRegions.id]))=0;
end
roles={'Search'};sides={'Combined'};
if opt.bilateral
    [left,right]=scmSearchSideMasks(opt,shape);
    roles={'Target','Control'};if ~opt.leftIsTarget,roles=fliplr(roles);end
    sides={'Image-left','Image-right'};
elseif ~strcmp(opt.roiSelection,'Both'),roles={opt.roiSelection};end
reports={};
for side=1:numel(sides)
    role=roles{side};
    counterpartOnly=opt.bilateral&&strcmp(opt.roiSelection,'Target')&&strcmp(role,'Control');
    if ~strcmp(opt.roiSelection,'Both')&&~strcmp(opt.roiSelection,role)&&~counterpartOnly,continue;end
    L=labels;
    if strcmp(sides{side},'Image-left'),L(repmat(~left,1,1,shape(3)))=0;
    elseif strcmp(sides{side},'Image-right'),L(repmat(~right,1,1,shape(3)))=0;end
    if isempty(fusiAtlasRegionCatalog(L,info)),continue;end
    local=opt;
    unused=intersect(fieldnames(local),{'atlasLabels','paintMask','paintMasks'});
    if ~isempty(unused),local=rmfield(local,unused);end
    if numel(opt.topCount)==2
        slot=1;if strcmp(role,'Control'),slot=2;end
        local.topCount=opt.topCount(slot);
    end
    requested=local.topCount;local.topCount=0;
    r=scmRankAtlasRegions(A,TR,L,info,local,@(f,m)progress((side-1+f)/numel(sides),[role ' | ' m]));
    r.settings.topCount=requested;
    r.settings.counterpartOnly=counterpartOnly;
    r.role=role;r.imageSide=sides{side};r.settings.role=role;r.settings.imageSide=sides{side};
    r.method=strrep(r.method,'across selected slices and both hemispheres', ...
        ['across selected slices within ' sides{side} ' (' role ')']);
    reports{end+1}=r; %#ok<AGROW>
end
% Keep the contralateral Control for every retained Target even when its
% response ranks below the Control cutoff. No signal is mirrored or refitted.
keep=cell(size(reports));targetIDs=[];
for k=1:numel(reports)
    r=reports{k};count=height(r.table);if r.settings.topCount>0,count=min(count,r.settings.topCount);end
    keep{k}=1:count;
    if r.settings.counterpartOnly,keep{k}=[];end
    if strcmp(r.role,'Target'),targetIDs=[targetIDs;r.table.AtlasID(keep{k})];end %#ok<AGROW>
end
for k=1:numel(reports)
    r=reports{k};take=keep{k};
    if strcmp(r.role,'Control'),take=unique([take find(ismember(r.table.AtlasID,targetIDs))'],'sorted');end
    r.table=r.table(take,:);r.traces=r.traces(take,:);r.regionVoxelIndices=r.regionVoxelIndices(take);
    reports{k}=r;
end
reports=reports(~cellfun(@(r)r.settings.counterpartOnly&&isempty(r.table),reports));
progress(1,'Whole-region rankings by role complete');
end
