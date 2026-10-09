function slabs=fusiVolumeSlabMean(S,centers,thicknessUm)
% Physical coronal slabs. Missing/excluded voxels never become zero PSC.
validateattributes(thicknessUm,{'numeric'},{'scalar','finite','positive'});
validateattributes(centers,{'numeric'},{'vector','finite','integer','positive'});
assert(strcmp(S.units,'mm'),'deConfUSIon:SlabCalibration','Enter calibrated millimetre spacing to select a slab thickness.');
n=max(1,round(thicknessUm/(S.spacing(3)*1000)));
slabs=struct('psc',[],'anatomy',[],'brain',[],'indices',{{}}, ...
    'requestedThicknessUm',thicknessUm,'sampleSpacingUm',S.spacing(3)*1000, ...
    'nominalThicknessUm',n*S.spacing(3)*1000,'samplesPerSlab',n, ...
    'meanRule','Arithmetic mean of finite PSC within each slab; excluded/out-of-coverage samples are omitted. Sampling is not acoustic resolution.');
if isfield(S,'atlasReference'),u=S.atlasReference;brain=S.atlasBrainMask;
else,u=S.underlay;brain=S.underlayValid;end
for k=1:numel(centers)
    first=centers(k)-floor((n-1)/2);ix=max(1,first):min(size(S.psc,3),first+n-1);
    assert(~isempty(ix),'deConfUSIon:SlabRange','Slab center is outside the volume.');
    slabs.indices{k}=ix+S.slices(1)-1;
    slabs.psc(:,:,k)=mean(S.psc(:,:,ix),3,'omitnan');
    slabs.anatomy(:,:,k)=mean(u(:,:,ix),3);
    slabs.brain(:,:,k)=any(brain(:,:,ix),3);
end
slabs.actualSampleCounts=cellfun(@numel,slabs.indices);
slabs.actualThicknessUm=slabs.actualSampleCounts*slabs.sampleSpacingUm;
end
