function s=fusiFCReferenceImages(s,metadata)
% Prepare static reference volumes once, rather than reducing I4 on scrolling.
if nargin<2,metadata=struct();end
s.referenceMean=mean(s.I4,4,'omitnan');
n=size(s.I4,4);idx=unique(round(linspace(1,n,min(n,600))));
s.referenceMedian=median(s.I4(:,:,:,idx),4,'omitnan');
c=scmSpatialCalibration(metadata);s.spacingUm=c.spacingUm;s.spacingSource=c.source;
end
