function [r,note]=fusiBaselineAlignReference(r,targetShape,sourceGeometry,targetGeometry)
% Place matching physical voxels; never stretch a different-depth acquisition.
targetShape=double(targetShape(:).');shape=r.spatialSize;B=r.mean;
if isfield(r,'nativeMean'),B=r.nativeMean;shape=r.nativeSpatialSize;end
sourceGeometry=unwrap(sourceGeometry);targetGeometry=unwrap(targetGeometry);
assert(numel(shape)==numel(targetShape),'deConfUSIon:BaselineGrid','Spatial dimensions differ.');
offset=zeros(1,numel(targetShape));physical=false;
if all(isfield(sourceGeometry,{'voxelSize','origen'}))&&all(isfield(targetGeometry,{'voxelSize','origen'}))
    spacing=double(sourceGeometry.voxelSize(:).');targetSpacing=double(targetGeometry.voxelSize(:).');
    dimensions=numel(targetShape);spacing=spacing(1:dimensions);targetSpacing=targetSpacing(1:dimensions);
    assert(all(isfinite(spacing)&spacing>0)&&all(abs(spacing-targetSpacing)<1e-6), ...
        'deConfUSIon:BaselineGrid','Voxel spacing differs. Register/resample both power scans to a common grid first.');
    src=double(sourceGeometry.origen(:).');dst=double(targetGeometry.origen(:).');
    shift=(src(1:dimensions)-dst(1:dimensions))./spacing;
    assert(all(isfinite(shift))&&all(abs(shift-round(shift))<1e-4),'deConfUSIon:BaselineGrid', ...
        'Origins require a subvoxel transform. Register both power scans before sharing the baseline.');
    offset=round(shift);physical=true;
else
    assert(isequal(shape,targetShape),'deConfUSIon:BaselineGrid', ...
        'Reference grid %s differs from current grid %s and physical origins are unavailable. Select scans with geometry metadata or register them first.',mat2str(shape),mat2str(targetShape));
end
source=cell(1,numel(shape));destination=source;
for axis=1:numel(shape)
    start=max(1,1-offset(axis));stop=min(shape(axis),targetShape(axis)-offset(axis));
    assert(stop>=start,'deConfUSIon:BaselineGrid','Reference and current scan have no spatial overlap.');
    source{axis}=start:stop;destination{axis}=source{axis}+offset(axis);
end
placed=nan(targetShape,'single');placed(destination{:})=B(source{:});
r.nativeMean=B;r.nativeSpatialSize=shape;r.mean=placed;r.spatialSize=targetShape;
r.sourceGeometry=sourceGeometry;r.alignment=struct('method','Matching voxel spacing and recorded origins; overlap only', ...
    'offsetVoxels',offset,'physicalGeometryUsed',physical,'targetGeometry',targetGeometry, ...
    'coverage',prod(cellfun(@numel,destination))/prod(targetShape));
note=sprintf('Source %s -> current %s; offset %s voxels; %.1f%% spatial overlap.', ...
    mat2str(shape),mat2str(targetShape),mat2str(offset),100*r.alignment.coverage);
end
function g=unwrap(g)
if isfield(g,'meta'),g=g.meta;end
if isfield(g,'rawMetadata'),g=g.rawMetadata;end
if isfield(g,'metadata'),g=g.metadata;end
end
