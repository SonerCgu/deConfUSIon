function [slabs,cache]=fusiMapAtlasSlabs(S,atlas,g,M,centers,thicknessUm,reference,cache)
% Sample only the requested full-resolution atlas slabs from a native frame.
% Never allocate a full atlas-sized movie or invent PSC outside acquisition.
av=double(atlas.VoxelSize(:)');n=max(1,round(thicknessUm/av(1)));
if nargin<8,cache=[];end
key={S.slices,size(S.psc),atlas,g,M,centers,thicknessUm,reference};
indices=cell(1,numel(centers));allAP=[];
for k=1:numel(centers)
    first=centers(k)-floor((n-1)/2);
    indices{k}=max(1,first):min(size(atlas.Histology,1),first+n-1);
    assert(~isempty(indices{k}),'deConfUSIon:SlabRange','Atlas slab center is outside the atlas.');
    allAP=[allAP indices{k}]; %#ok<AGROW>
end
if isempty(cache)||~isequal(cache.key,key)
[dv,lr,ap]=ndgrid(single(1:size(atlas.Histology,2)),single(1:size(atlas.Histology,3)),single(allAP));
points=[dv(:) ap(:) lr(:) ones(numel(ap),1,'single')]/single(M);
prepared={reshape(points(:,2),size(ap)),reshape(points(:,1),size(ap)),reshape(points(:,3),size(ap))};
shape=double(g.originalSize);q=cell(1,3);
for axis=1:3
    value=1+(prepared{axis}-1)*av(axis)/double(g.originalSpacingUm(g.permutation(axis)));
    if isfield(g,'flipAxes')&&ismember(axis,g.flipAxes),value=shape(g.permutation(axis))+1-value;end
    q{g.permutation(axis)}=value;
end
q{3}=q{3}-S.slices(1)+1;
brain=permute(fusiAtlasBrainMask(atlas,atlas.Regions(allAP,:,:)),[2 3 1]);
inside=brain;sourceSize=[size(S.psc,1) size(S.psc,2) size(S.psc,3)];
for axis=1:3,inside=inside & q{axis}>=1 & q{axis}<=sourceSize(axis);end
locations=find(inside);for axis=1:3,q{axis}=q{axis}(locations);end
fullReference=atlas.(reference);
u=single(permute(fullReference(allAP,:,:),[2 3 1]));
% Stable reference-wide limits, independent of frame/slab selection.
u=min(1,max(0,u/max(eps('single'),single(max(fullReference(:))))));
u(~brain)=0;
cache=struct('key',{key},'query',{q},'locations',locations,'brain',brain,'u',u);
end
q=cache.query;brain=cache.brain;u=cache.u;
p=NaN(size(brain),'single');
if ~isempty(cache.locations)
    finite=interp3(single(isfinite(S.psc)),q{2},q{1},q{3},'linear',0)>=.999;
    values=single(interp3(S.psc,q{2},q{1},q{3},'linear',NaN));values(~finite)=NaN;
    p(cache.locations)=values;
end
slabs=struct('psc',[],'anatomy',[],'brain',[],'indices',{indices}, ...
    'requestedThicknessUm',thicknessUm,'sampleSpacingUm',av(1), ...
    'nominalThicknessUm',n*av(1),'samplesPerSlab',n, ...
    'meanRule','Arithmetic mean of finite aligned PSC within full-resolution atlas slabs; excluded/out-of-coverage samples omitted. Atlas resampling does not increase acoustic resolution.');
offset=0;
for k=1:numel(indices)
    ix=offset+(1:numel(indices{k}));offset=offset+numel(ix);
    slabs.psc(:,:,k)=mean(p(:,:,ix),3,'omitnan');
    slabs.anatomy(:,:,k)=mean(u(:,:,ix),3);
    slabs.brain(:,:,k)=any(brain(:,:,ix),3);
end
slabs.actualSampleCounts=cellfun(@numel,indices);slabs.actualThicknessUm=slabs.actualSampleCounts*av(1);
end
