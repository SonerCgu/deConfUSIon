function [matched,U,meta]=fusiReadAtlasUnderlay3D(S)
% Explicit bundle marker avoids guessing whether a three-slice image is RGB.
matched=isfield(S,'atlasUnderlayMeta') && isstruct(S.atlasUnderlayMeta) && ...
 isfield(S.atlasUnderlayMeta,'kind') && strcmp(S.atlasUnderlayMeta.kind,'deConfUSIon_3D_registration_underlay');
U=[];meta=struct();if ~matched,return;end
assert(isfield(S,'Transf') && isequal(S.Transf.displayPermutation,[2 3 1]),'Invalid 3D underlay transform.');
meta=struct('isColor',strcmp(S.atlasMode,'regions'),'regionLabels',[],'regionInfo',struct(), ...
 'atlasMode',S.atlasMode,'registrationBundle3D',true,'transform',S.Transf, ...
 'voxelSizeUm',S.atlasUnderlayMeta.voxelSizeUm,'arrayOrder',S.atlasUnderlayMeta.arrayOrder, ...
 'transformFile',S.atlasUnderlayMeta.transformFile);
if isfield(S.atlasUnderlayMeta,'regionGrouping'),meta.regionGrouping=S.atlasUnderlayMeta.regionGrouping;end
geometry=[];if isfield(S.Transf,'scanGeometry'),geometry=S.Transf.scanGeometry;end
meta.registrationKey=struct('M',S.Transf.M,'scanGeometry',geometry, ...
 'atlasCanonicalSize',S.Transf.atlasCanonicalSize,'displayPermutation',S.Transf.displayPermutation);
if meta.isColor,U=S.atlasUnderlayRGB;meta.regionLabels=S.atlasRegionLabels3D;meta.regionInfo=S.atlasInfoRegions;
else,U=S.atlasUnderlay;end
sz=[size(U,1) size(U,2) size(U,3)];if meta.isColor,sz(3)=size(U,4);end
assert(isequal(double(sz),double(S.Transf.outputSize)),'deConfUSIon:AtlasUnderlayGrid','Saved underlay and output grid differ.');
end
