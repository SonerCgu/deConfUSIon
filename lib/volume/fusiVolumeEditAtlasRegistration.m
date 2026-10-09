function R=fusiVolumeEditAtlasRegistration(data,transformFile,onSaved,onPreview)
% Reuse the existing three-plane manual/automatic editor for this native scan.
loaded=load(fullfile(deConfUSIon_root(),'allen_brain_atlas.mat'),'atlas');atlas=loaded.atlas;
if nargin<3,onSaved=[];end
if nargin<4,onPreview=[];end
if isempty(data.baselineUnderlay),error('deConfUSIon:AtlasAnatomy','Use a raw native 3D intensity recording to register its baseline anatomy.');end
T=[];
if ~isempty(transformFile)
    if isstruct(transformFile),T=transformFile;
    else,loaded=load(transformFile,'Transf');T=loaded.Transf;end
    assert(isequal(T.scanGeometry.originalSize,[size(data.PSC,1) size(data.PSC,2) size(data.PSC,3)]), ...
        'deConfUSIon:AtlasGeometryMismatch','Saved transform does not match this native recording.');
    g=T.scanGeometry;scan=struct('Data',permute(data.baselineUnderlay,g.permutation), ...
        'VoxelSize',g.originalSpacingUm(g.permutation),'Geometry',g);
    if isfield(g,'flipAxes'),for axis=g.flipAxes,scan.Data=flip(scan.Data,axis);end,end
    if isstruct(transformFile),folder=fusiAtlasTransformFolder(data.par,'',[],true);
    else,folder=fusiAtlasTransformFolder(data.par,transformFile,[],true);end
else
    par=data.par;par.scmSizeYXZ=[size(data.PSC,1) size(data.PSC,2) size(data.PSC,3)];cal=scmSpatialCalibration(par);
    scan=struct('Data',data.baselineUnderlay,'arrayOrder','DV-LR-AP');
    if isfield(par,'nativeColumnOneSide'),scan.nativeColumnOneSide=par.nativeColumnOneSide;end
    if all(isfinite(cal.spacingUm)),scan.VoxelSize=cal.spacingUm;end
    scan=AtlasRegistration('geometry',scan,atlas);if isempty(scan),R=[];return;end
    folder=fusiAtlasTransformFolder(par,'',[],true);
    if ~isfolder(folder),mkdir(folder);end
end
if isfield(data,'underlayProcessed') && data.underlayProcessed && ...
        isequal(size(data.underlay),size(data.baselineUnderlay))
    g=scan.Geometry;scan.DisplayData=permute(single(data.underlay),g.permutation);
    if isfield(g,'flipAxes'),for axis=g.flipAxes,scan.DisplayData=flip(scan.DisplayData,axis);end,end
end
R=registration_ccf(atlas,scan,T,[],folder,struct());
setappdata(R.H.figure1,'AtlasSavedCallback',@(file)saved(file,data.par,onSaved));
setappdata(R.H.figure1,'AtlasPreviewCallback',onPreview);
set(R.H.figure1,'Name',['3D atlas alignment | ' data.label]);
end
function saved(file,par,onSaved)
fusiAtlasTransformFolder(par,file,fileparts(file));
if isa(onSaved,'function_handle'),onSaved(file);end
end
