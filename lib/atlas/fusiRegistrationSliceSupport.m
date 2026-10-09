function [mask,report]=fusiRegistrationSliceSupport(V,cfg)
% Keep the prepared volume's origin intact; ignore bad AP planes in fitting.
n=size(V,1);range=[1 n];
if isfield(cfg,'preparedSliceRange') && ~isempty(cfg.preparedSliceRange)
    range=double(cfg.preparedSliceRange(:)');
    if numel(range)~=2 || any(~isfinite(range)) || range(1)<1 || range(2)>n || range(2)<=range(1)
        error('deConfUSIon:AtlasSliceRange','Select at least two AP planes inside 1 to %d.',n);
    end
end
samples=reshape(max(0,single(V)),n,[]);samples(~isfinite(samples))=0;
energy=mean(samples,2);fraction=mean(samples>0,2);
automatic=isfield(cfg,'trimEmptySlices') && cfg.trimEmptySlices;
keep=false(n,1);keep(ceil(range(1)):floor(range(2)))=true;
if automatic
    candidates=find(keep & energy>max(energy)*.02 & fraction>.02);
    if numel(candidates)<4,error('deConfUSIon:AtlasSliceRange','Too few usable AP planes. Choose the slice range manually.');end
    keep=keep & (1:n)'>=candidates(1) & (1:n)'<=candidates(end);
end
mask=repmat(keep,1,size(V,2),size(V,3));
chosen=find(keep);report=struct('preparedSliceRange',[chosen(1) chosen(end)], ...
    'trimEmptySlices',automatic,'sliceEnergy',energy,'nonzeroFraction',fraction, ...
    'sourceSliceRange',[],'rule','AP support is masked without cropping or shifting the native origin.');
if isfield(cfg,'sourceSliceRange'),report.sourceSliceRange=cfg.sourceSliceRange;end
end
