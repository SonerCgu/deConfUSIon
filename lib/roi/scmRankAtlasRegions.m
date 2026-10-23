function result=scmRankAtlasRegions(A,TR,labels,info,opt,progress)
% Rank fixed, whole atlas regions on the acquired grid, across chosen slices.
% No intensity threshold, rectangular ROI or best-voxel selection is used.
if nargin<6,progress=@(~,~)[];end
assert(isnumeric(A)&&isreal(A)&&any(ndims(A)==[3 4]), ...
    'deConfUSIon:AtlasRankingData','PSC must be [Y X T] or [Y X Z T].');
assert(isscalar(TR)&&isfinite(TR)&&TR>0,'deConfUSIon:AtlasRankingTime','TR must be positive.');
shape=[size(A,1) size(A,2) 1];if ndims(A)==4,shape(3)=size(A,3);end
T=size(A,ndims(A));
assert(isnumeric(labels)&&isreal(labels)&&isequal([size(labels,1) size(labels,2) size(labels,3)],shape), ...
    'deConfUSIon:AtlasRankingGrid','Load registered Regions labels on the same grid as the SCM signal.');
assert(all(isfinite(labels(:)))&&all(labels(:)==round(labels(:))), ...
    'deConfUSIon:AtlasRankingGrid','Atlas labels must be finite integer region IDs.');
opt=defaults(opt,shape);
assert(any(strcmp(opt.metric,{'mean','peak'}))&&any(strcmp(opt.direction,{'increase','decrease','absolute'})), ...
    'deConfUSIon:AtlasRankingMetric','Choose mean or peak, and increase, decrease or absolute change.');
assert(isscalar(opt.topCount)&&isfinite(opt.topCount)&&opt.topCount>=0&&opt.topCount==round(opt.topCount), ...
    'deConfUSIon:AtlasRankingCount','Top count must be an integer; 0 keeps all regions.');
assert(isscalar(opt.minCoverage)&&isfinite(opt.minCoverage)&&opt.minCoverage>0&&opt.minCoverage<=1, ...
    'deConfUSIon:AtlasRankingCoverage','Minimum usable coverage must be greater than 0 and at most 100 percent.');
range=double(opt.sliceRange(:)');
assert(numel(range)==2&&all(isfinite(range))&&all(range==round(range))&&range(1)>=1&&range(2)<=shape(3)&&range(2)>=range(1), ...
    'deConfUSIon:AtlasRankingSlices','Select an inclusive slice range inside the acquisition.');
signalFrames=frames(opt.signalSec,TR,T,'Signal');
assert(numel(signalFrames)>=2,'deConfUSIon:AtlasRankingTime','Signal interval must contain at least two acquired samples.');
external=strcmp(opt.baselineMode,'external');baselineFrames=[];
if ~external,baselineFrames=frames(opt.baselineSec,TR,T,'Baseline');end
[catalog,excluded]=fusiAtlasRegionCatalog(labels,info);
assert(~isempty(catalog),'deConfUSIon:AtlasRankingAtlas','No named brain tissue regions found. Load a registered Regions atlas first.');
progress(.02,'Finding atlas regions in selected slices');
regionLabels=abs(double(labels));regionLabels(:,:,1:range(1)-1)=0;regionLabels(:,:,range(2)+1:end)=0;
[inside,group]=ismember(regionLabels(:),[catalog.id]);indices=find(inside);group=group(inside);
n=numel(catalog);total=accumarray(group,1,[n 1]);
source=reshape(A,[],T);B=zeros(numel(indices),1);valid=false(numel(indices),1);
% Read bounded voxel blocks. Membership is fixed using baseline validity and
% finite samples throughout the selected interval, never signal magnitude.
chunk=max(1,floor(16*1024^2/(8*max(1,numel(baselineFrames)+numel(signalFrames)))));
for first=1:chunk:numel(indices)
    take=first:min(numel(indices),first+chunk-1);
    if ~external,B(take)=mean(double(source(indices(take),baselineFrames)),2);end
    valid(take)=isfinite(B(take))&100+B(take)>sqrt(eps('single'))& ...
        all(isfinite(source(indices(take),signalFrames)),2);
    progress(.05+.25*take(end)/numel(indices),'Checking fixed regional voxel coverage');
end
indices=indices(valid);group=group(valid);B=B(valid);
count=accumarray(group,1,[n 1]);coverage=count./max(1,total);
keep=total>0&count>0&coverage>=opt.minCoverage-1e-12;
reason=repmat({'Insufficient finite baseline / signal coverage'},n,1);
reason(total==0)={'No voxels in selected slices'};
omitted=table([catalog.id]',{catalog.acronym}',total,count,100*coverage,reason, ...
    'VariableNames',{'AtlasID','Abbreviation','AtlasVoxels','UsableVoxels','Coverage_pct','Reason'});
omitted=omitted(~keep,:);
% Compute all regional curves together, with a constant denominator per
% region. Nonfinite frames outside the ranking interval stay nonfinite.
selected=keep(group);indices=indices(selected);group=group(selected);B=B(selected);
W=sparse(group,1:numel(group),1./max(1,count(group)),n,numel(group));
traces=nan(n,T);block=max(1,floor(16*1024^2/(8*max(1,numel(indices)))));
for first=1:block:T
    f=first:min(T,first+block-1);
    if ~isempty(indices)
        V=double(source(indices,f));V=100*bsxfun(@rdivide,bsxfun(@minus,V,B),100+B);
        traces(:,f)=W*V;
    end
    progress(.3+.65*f(end)/T,'Averaging whole atlas regions');
end
rows=find(keep);curves=traces(rows,:);window=curves(:,signalFrames);
meanPSC=mean(window,2);extreme=window;
if strcmp(opt.direction,'decrease'),extreme=-window;
elseif strcmp(opt.direction,'absolute'),extreme=abs(window);end
[~,peakIndex]=max(extreme,[],2);
peakPSC=window(sub2ind(size(window),(1:numel(rows))',peakIndex));
peakTime=reshape((signalFrames(peakIndex)-1)*TR/60,[],1);
change=meanPSC;if strcmp(opt.metric,'peak'),change=peakPSC;end
score=change;if strcmp(opt.direction,'decrease'),score=-change;
elseif strcmp(opt.direction,'absolute'),score=abs(change);end
ids=reshape([catalog(rows).id],[],1);
[~,order]=sortrows([reshape(-score,[],1) ids],[1 2]);
eligibleRegionCount=numel(rows);
if opt.topCount>0,order=order(1:min(opt.topCount,numel(order)));end
rows=rows(order);curves=curves(order,:);
firstSlice=zeros(numel(rows),1);lastSlice=firstSlice;numSlices=firstSlice;
voxelIndices=cell(numel(rows),1);
for k=1:numel(rows)
    voxelIndices{k}=uint32(indices(group==rows(k)));
    zz=unique(floor((double(voxelIndices{k})-1)/prod(shape(1:2)))+1);
    firstSlice(k)=min(zz);lastSlice(k)=max(zz);numSlices(k)=numel(zz);
end
ranking=table((1:numel(rows))',reshape({catalog(rows).acronym},[],1),reshape({catalog(rows).name},[],1),reshape([catalog(rows).id],[],1), ...
    change(order),meanPSC(order),peakPSC(order),peakTime(order),count(rows),total(rows),100*coverage(rows), ...
    firstSlice,lastSlice,numSlices,'VariableNames',{'Rank','Abbreviation','Region','AtlasID', ...
    'ChangePSC_pct','MeanPSC_pct','PeakPSC_pct','PeakTime_min','UsableVoxels','AtlasVoxels', ...
    'Coverage_pct','FirstSlice','LastSlice','NumberSlices'});
opt.signalFrames=signalFrames;opt.baselineFrames=baselineFrames;
opt.signalSampleSec=(signalFrames-1)*TR;opt.baselineSampleSec=(baselineFrames-1)*TR;
result=struct('table',ranking,'traces',curves,'timeSec',(0:T-1)*TR,'TR',TR, ...
    'regionVoxelIndices',{voxelIndices}, ...
    'settings',opt,'shapeYXZ',shape,'eligibleRegionCount',eligibleRegionCount,'omitted',omitted, ...
    'excludedAtlasIDs',excluded,'method',['Voxel-weighted regional mean across selected slices and both hemispheres, within the acquired grid. ' ...
    'Fixed finite baseline/signal support; exact per-voxel PSC rebase: 100*(PSC-B)/(100+B). ' ...
    'External-reference PSC uses B=0. No display mask, threshold, smoothing or ROI-size setting. ' ...
    'Coverage is relative to labelled voxels in the selected acquired slices, not the complete reference atlas. ' ...
    'Ranking is exploratory and does not establish statistical significance.']);
progress(1,'Atlas region ranking complete');
end

function opt=defaults(opt,shape)
d=struct('sliceRange',[1 shape(3)],'topCount',20,'minCoverage',.75,'metric','mean', ...
    'direction','increase','baselineMode','local');
names=fieldnames(d);for k=1:numel(names),if ~isfield(opt,names{k}),opt.(names{k})=d.(names{k});end,end
end

function f=frames(seconds,TR,T,label)
w=double(seconds(:)');t=(0:T-1)*TR;tol=max(1e-9,TR*1e-6);
assert(numel(w)==2&&all(isfinite(w))&&w(1)>=0&&w(2)>=w(1)&&w(2)<=t(end)+tol, ...
    'deConfUSIon:AtlasRankingTime','%s interval must lie inside the scan (last sample %.6g s).',label,t(end));
f=find(t>=w(1)-tol&t<=w(2)+tol);
assert(~isempty(f),'deConfUSIon:AtlasRankingTime','%s interval contains no acquired samples.',label);
end
