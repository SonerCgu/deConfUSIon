function s=fusiFCReferenceImages(s,metadata)
% Prepare static reference volumes once, rather than reducing I4 on scrolling.
if nargin<2,metadata=struct();end
s.referenceMean=mean(s.I4,4,'omitnan');
s.referenceValid=isfinite(s.referenceMean)&max(s.I4,[],4)>min(s.I4,[],4);
s.referenceVersion=now;
n=size(s.I4,4);idx=unique(round(linspace(1,n,min(n,600))));
s.referenceMedian=median(s.I4(:,:,:,idx),4,'omitnan');
% PSC is a signal, not an anatomical intensity reference.
power=[];
if isfield(metadata,'fcPowerReference'),power=metadata.fcPowerReference;
elseif isfield(metadata,'functionalSource')&&strcmpi(metadata.functionalSource,'PSC')&&isfield(metadata,'bg'),power=metadata.bg;end
if ~isempty(power)&&isequal(size(power,[1 2 3]),size(s.I4,[1 2 3]))
 s.referenceMean=single(power);s.referenceMedian=single(power);
end
c=scmSpatialCalibration(metadata);s.spacingUm=c.spacingUm;s.spacingSource=c.source;
end
