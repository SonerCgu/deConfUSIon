function fig=fusiAtlasVolumeGUI(atlas,maxDimension)
% Inspect the complete Allen reference without a scan or a registration.
deConfUSIon_setup();
if nargin<1 || isempty(atlas)
    path=which('allen_brain_atlas.mat');
    if isempty(path),path=fullfile(fileparts(mfilename('fullpath')),'allen_brain_atlas.mat');end
    loaded=load(path,'atlas');atlas=loaded.atlas;
else,path='Supplied atlas';end
if nargin<2,maxDimension=160;end
validateattributes(maxDimension,{'numeric'},{'scalar','finite','>=',16});
sz=size(atlas.Histology);stride=max(1,ceil(max(sz)/maxDimension));
indices={1:stride:sz(1),1:stride:sz(2),1:stride:sz(3)};
histology=normalize(single(permute(atlas.Histology(indices{:}),[2 3 1])));
vascular=normalize(single(permute(atlas.Vascular(indices{:}),[2 3 1])));
brain=permute(fusiAtlasBrainMask(atlas,atlas.Regions(indices{:})),[2 3 1]);
% The companion viewer uses a time-series adapter, but atlasOnly explicitly
% disables functional playback and labels all exports as reference anatomy.
empty=zeros([size(histology) 2],'single');
data=struct('PSC',empty,'I',empty,'underlay',histology,'mask',[], ...
    'maskIsInclude',true,'applyMask',false,'TR',1,'interpol',1,'frame',1, ...
    'par',struct('voxelSizeUm',double(atlas.VoxelSize([2 3 1]))*stride), ...
    'label','Complete Allen brain atlas','underlayLabel','Allen atlas reference','caxis',[0 100], ...
    'baseline',struct('start',0,'end',1,'mode','sec'),'inputIsPSC',true, ...
    'transformed',false,'atlasOnly',true,'atlasFull',atlas,'atlasReference',histology, ...
    'atlasVascular',vascular,'atlasBrainMask',brain, ...
    'atlasProvenance',struct('atlasFile',path,'displayStride',stride, ...
    'atlasOriginalSizeAPDVLR',sz,'referenceRole','Complete reference anatomy; no animal data.'));
fig=fusiVolumeGUI(data);
end
function V=normalize(V)
values=sort(V(isfinite(V) & V>0));
if isempty(values),V(:)=0;return;end
hi=values(max(1,round(.995*numel(values))));
V=min(1,max(0,V/max(hi,eps('single'))));V(~isfinite(V))=0;
end
