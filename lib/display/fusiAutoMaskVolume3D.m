function [mask,report]=fusiAutoMaskVolume3D(U,sensitivity,spacingUm,restrictMask)
% A continuous anatomical proposal from Doppler, independent of display tone.
% It is not an atlas segmentation: retain manual editing and review per slice.
if nargin<2 || isempty(sensitivity),sensitivity=.4;end
if nargin<3,spacingUm=[];end
if nargin<4,restrictMask=[];end
assert(isnumeric(U) && ndims(U)<=3,'deConfUSIon:AutoMaskInput','Supply a scalar anatomy volume.');
assert(isscalar(sensitivity) && isfinite(sensitivity) && sensitivity>0,'deConfUSIon:AutoMaskSensitivity','Sensitivity must be positive.');
shape=size(U,[1 2 3]);mask=false(shape);valid=isfinite(U);raw=double(U);raw(~valid)=0;
report=struct('method','3D Doppler envelope','validSlices',false(1,shape(3)), ...
 'threshold',NaN,'spacingUm',spacingUm,'usedPhysicalSpacing',false,'voxelCount',0, ...
 'rejectedLinePixels',0,'spatialCoherence',NaN);
values=raw(valid);if isempty(values),return;end
limits=prctile(values,[2 99.5]);span=diff(limits);
if ~isfinite(span) || span<=eps(max(1,max(abs(limits)))),return;end
% Reject narrow, nearly full-width intensity spikes before they can connect
% to the brain during closing. A vessel is not normally bright across most
% columns at a single depth; broad tissue bands remain unchanged.
artifact=false(shape);
for z=1:shape(3)
 rowMedian=median(raw(:,:,z),2);trend=movmedian(rowMedian,11);
 rows=rowMedian-trend>.15*span & rowMedian>limits(1)+.5*span;
 edges=diff([false;rows;false]);starts=find(edges==1);ends=find(edges==-1)-1;
 for k=1:numel(starts)
  run=starts(k):ends(k);if numel(run)>3,continue;end
  for y=run
   hot=raw(y,:,z)>trend(y)+.5*(rowMedian(y)-trend(y));
   if nnz(hot)>.7*shape(2),artifact(y,:,z)=hot;end
  end
 end
end
report.rejectedLinePixels=nnz(artifact);valid=valid & ~artifact;
values=raw(valid);if isempty(values),return;end
limits=prctile(values,[2 99.5]);span=diff(limits);
if ~isfinite(span) || span<=eps(max(1,max(abs(limits)))),return;end
normU=min(1,max(0,(raw-limits(1))/span));normU(~valid)=0;
for z=1:shape(3)
 plane=raw(:,:,z);ok=valid(:,:,z);v=plane(ok);
 if isempty(v),continue;end
 p=prctile(v,[5 98]);
 report.validSlices(z)=diff(p)>.02*span && p(2)>limits(1)+.05*span;
end
if ~any(report.validSlices),return;end
physical=numel(spacingUm)==3 && all(isfinite(spacingUm) & spacingUm>0);
if physical,sigma=min(3,max(.5,180./double(spacingUm(:)')));report.usedPhysicalSpacing=true;
else,sigma=[1.5 1.5 .75];end
% Moderate compression limits the influence of isolated hot vessels.
envelope=log1p(9*normU)/log(10);
sourceSupport=valid & reshape(report.validSlices,1,1,[]);
sourceContrast=diff(prctile(envelope(sourceSupport),[5 95]));
for axis=1:3
 if shape(axis)==1,continue;end
 radius=ceil(3*sigma(axis));coords=-radius:radius;
 kernel=exp(-coords.^2/(2*sigma(axis)^2));kernel=kernel/sum(kernel);
 kshape=[1 1 1];kshape(axis)=numel(kernel);
 envelope=imfilter(envelope,reshape(kernel,kshape),'replicate');
end
for z=find(report.validSlices)
 plane=envelope(:,:,z);values=plane(valid(:,:,z));
 if isempty(values) || diff(prctile(values,[5 95]))<.05,report.validSlices(z)=false;end
end
support=valid & reshape(report.validSlices,1,1,[]);
if ~any(support(:)),return;end
v=envelope(support);contrast=diff(prctile(v,[5 95]));
report.spatialCoherence=contrast/max(eps,sourceContrast);
if contrast<.05 || report.spatialCoherence<.2,return;end
level=graythresh(v);
edge=false(shape);edge([1 end],:,:)=true;edge(:,[1 end],:)=true;
edgeValues=envelope(edge & support);
if isempty(edgeValues),noiseFloor=0;
else,center=median(edgeValues);noiseFloor=center+2*median(abs(edgeValues-center));end
weak=max([.02,level*min(2.5,sensitivity),min(noiseFloor,.9*level)]);
strong=max(weak,level*max(.85,min(1.3,sensitivity)));
report.threshold=weak;
candidate=envelope>weak & support;seed=envelope>strong & support;
if physical,radii=min(4,max(1,round(180./spacingUm(1:2))));else,radii=[2 2];end
[yy,xx]=ndgrid(-radii(1):radii(1),-radii(2):radii(2));
se=strel('arbitrary',(yy/radii(1)).^2+(xx/radii(2)).^2<=1);
for z=find(report.validSlices)
 candidate(:,:,z)=imclose(candidate(:,:,z),se) & support(:,:,z);
end
if ~isempty(restrictMask)
 assert(isequal(size(restrictMask,[1 2 3]),shape),'deConfUSIon:AutoMaskRestriction','Restriction must match anatomy.');
 restriction=logical(restrictMask);
 % An existing restriction is authoritative, including holes and blank planes.
 candidate=candidate & restriction;seed=seed & restriction;
else,restriction=support;end
components=bwconncomp(candidate,18);scores=zeros(1,components.NumObjects);counts=scores;
for k=1:components.NumObjects
 ix=components.PixelIdxList{k};[y,x,z]=ind2sub(shape,ix);extent=[max(y)-min(y)+1 max(x)-min(x)+1 max(z)-min(z)+1];
 if any(extent<min(shape,[4 3 3])),continue;end
 counts(k)=numel(ix);scores(k)=nnz(seed(ix));
end
best=max(scores);largest=max(counts);if isempty(best) || best==0,return;end
keep=find(scores>=.10*best & counts>=.15*largest);
% Keep substantial disconnected lobes, rather than deleting one hemisphere.
for k=keep,mask(components.PixelIdxList{k})=true;end
for z=find(report.validSlices),mask(:,:,z)=imfill(mask(:,:,z),'holes') & restriction(:,:,z);end
mask=mask & support & restriction;report.voxelCount=nnz(mask);
end
