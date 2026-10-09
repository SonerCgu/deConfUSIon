function seed=fusiBregmaAnchors(sourceSlices,apEndpointsMm,bregmaIndex,spacingUm,atlasCount)
% AP positive anterior to bregma; atlas AP indices increase posteriorly.
validateattributes(sourceSlices,{'numeric'},{'vector','numel',3,'finite','increasing'});
validateattributes(apEndpointsMm,{'numeric'},{'vector','numel',2,'finite'});
validateattributes(bregmaIndex,{'numeric'},{'scalar','finite','>=',1,'<=',atlasCount});
validateattributes(spacingUm,{'numeric'},{'scalar','finite','positive'});
ap=interp1(sourceSlices([1 end]),apEndpointsMm,sourceSlices,'linear');
indices=bregmaIndex-ap*1000/spacingUm;
assert(all(indices>=1 & indices<=atlasCount),'deConfUSIon:BregmaRange','Bregma/AP coordinates map outside this atlas. Check the atlas bregma slice and signs.');
seed=struct('sourceSlices',sourceSlices,'apMm',ap,'atlasIndices',indices, ...
    'bregmaAtlasIndex',bregmaIndex,'atlasAPSpacingUm',spacingUm, ...
    'reference','User-specified bregma slice on this atlas; AP positive anterior. Coordinates seed editable anchors, not anatomical validation.');
end
