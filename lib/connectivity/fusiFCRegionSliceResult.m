function res=fusiFCRegionSliceResult(subj,selections,timeIdx,minVox)
% One simultaneous trace per signed anatomical region and explicitly chosen Z.
% Composite IDs are exact doubles, stable across order/subjects, and distinguish
% the same anatomical label on different slices. They are NOT atlas IDs.
if nargin<4,minVox=1;end
A=subj.roiAtlas;I=subj.I4;Z=size(I,3);
assert(~isempty(selections),'deConfUSIon:FCRegionSlices','Choose at least two region/slice entries.');
labs=double([selections.label]');zs=double([selections.slice]');
assert(all(isfinite(labs)&labs~=0&labs==round(labs)&abs(labs)<2^32), ...
 'deConfUSIon:FCRegionSlices','Region labels must be nonzero signed integer atlas IDs.');
assert(all(isfinite(zs)&zs==round(zs)&zs>=1&zs<=Z&zs<2^20), ...
 'deConfUSIon:FCRegionSlices','Every selected slice must exist in this scan.');
ids=sign(labs).*(2^52+abs(labs)*2^20+zs);
assert(numel(unique(ids))==numel(ids),'deConfUSIon:FCRegionSlices','Remove duplicate region/slice entries.');
assert(numel(timeIdx)>=3,'deConfUSIon:FCSamples','At least three simultaneous time samples are required.');
N=numel(ids);TS=nan(numel(timeIdx),N);counts=zeros(N,1);names=cell(N,1);
map=zeros(size(A)); % Do not cast composite IDs to int32: that destroys identity.
T=subj.roiNameTable;
for k=1:N
 z=zs(k);mask=A(:,:,z)==labs(k);
 if ~isempty(subj.mask),mask=mask&subj.mask(:,:,z);end
 counts(k)=nnz(mask);
 assert(counts(k)>=minVox,'deConfUSIon:FCEmptyRegionSlice', ...
  'Region %g on slice %d has %d included voxels (minimum %d). Choose another slice or check the atlas/mask.',labs(k),z,counts(k),minVox);
 D=reshape(I(:,:,z,timeIdx),[],numel(timeIdx));TS(:,k)=mean(double(D(mask(:),:)),1)';
 hit=find(double(T.labels)==labs(k),1);nm=sprintf('ROI_%g',labs(k));
 if ~isempty(hit),nm=char(T.names{hit});end
 nm=regexprep(nm,'\s*\[-?\d+\]\s*$','');
 names{k}=sprintf('%s (slice %d)',nm,z);
 layer=map(:,:,z);layer(mask)=ids(k);map(:,:,z)=layer;
end
res=struct('labels',ids,'atlasLabels',labs,'roiSlices',zs,'names',{names}, ...
 'fullNames',{fusiFCFullRegionNames(names,T)},'counts',counts,'meanTS',TS, ...
 'M',fusiFCCorrelationMatrix(TS),'TR',subj.TR,'timeIdx',timeIdx, ...
 'roiScope','region-slice','regionSliceSelections',selections,'labelMap',map, ...
 'sourceNote','Each ROI uses one named anatomical region on its specified native Z slice. All traces use the same local scan samples.');
end
