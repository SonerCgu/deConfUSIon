function slabs=fusiAtlasReferenceSlabs(atlas,centers,thicknessUm,reference)
% Static full-resolution atlas slabs, without adapting them as animal data.
av=double(atlas.VoxelSize(:)');n=max(1,round(thicknessUm/av(1)));
fullReference=atlas.(reference);scale=max(eps('single'),single(max(fullReference(:))));
slabs=struct('psc',[],'anatomy',[],'brain',[],'indices',{{}}, ...
    'requestedThicknessUm',thicknessUm,'sampleSpacingUm',av(1), ...
    'nominalThicknessUm',n*av(1),'samplesPerSlab',n, ...
    'meanRule','Reference atlas only; anatomy averaged within full-resolution slabs. No animal PSC.');
for k=1:numel(centers)
    first=centers(k)-floor((n-1)/2);ix=max(1,first):min(size(fullReference,1),first+n-1);
    assert(~isempty(ix),'deConfUSIon:SlabRange','Atlas slab center is outside the atlas.');
    slabs.indices{k}=ix;
    brain=permute(fusiAtlasBrainMask(atlas,atlas.Regions(ix,:,:)),[2 3 1]);
    u=single(permute(fullReference(ix,:,:),[2 3 1]))/scale;u(~brain)=0;
    slabs.anatomy(:,:,k)=mean(u,3);slabs.brain(:,:,k)=any(brain,3);
    slabs.psc(:,:,k)=NaN(size(u,1),size(u,2),'single');
end
slabs.actualSampleCounts=cellfun(@numel,slabs.indices);slabs.actualThicknessUm=slabs.actualSampleCounts*av(1);
end
