function context=fusiVolumeAtlasContext(data,transformFile,atlas,maxDimension,previous)
% Lazy native -> atlas display mapper. Never materialize an atlas-sized 4D.
if nargin<5,previous=[];end
if nargin<4,maxDimension=160;end
cache=[];
if (nargin<3 || isempty(atlas)) && isstruct(previous) && isfield(previous,'referenceCache') && ...
        previous.referenceCache.maxDimension==maxDimension
    cache=previous.referenceCache;atlas=cache.atlas;path=cache.path;
elseif nargin<3 || isempty(atlas)
    path=which('allen_brain_atlas.mat');
    if isempty(path),path=fullfile(deConfUSIon_root(),'allen_brain_atlas.mat');end
    loaded=load(path,'atlas');atlas=loaded.atlas;
else,path='Supplied atlas';end
unsaved=isstruct(transformFile);
if unsaved,T=transformFile;transformFile='';
else
    loaded=load(transformFile,'Transf');
    assert(isfield(loaded,'Transf'),'deConfUSIon:VolumeAtlas','Select a saved 3D Transformation.mat.');
    T=loaded.Transf;
end
assert(all(isfield(T,{'M','size','scanGeometry'})) && ~isempty(T.scanGeometry), ...
    'deConfUSIon:VolumeAtlas','Re-save this transform with confirmed 3D scan geometry before loading it here.');
g=T.scanGeometry;shape=[size(data.PSC,1) size(data.PSC,2) size(data.PSC,3)];
assert(~isfield(data,'transformed') || ~data.transformed,'deConfUSIon:VolumeAtlas','Open the native recording for this transform; it is already spatially transformed.');
assert(isequal(shape,double(g.originalSize)),'deConfUSIon:VolumeAtlas','The transform was made for a different native grid.');
assert(strcmp(g.convention,'coronal_stack_v2') && all(isfield(g,{'permutation','originalSpacingUm','atlasVoxelSizeUm'})), ...
    'deConfUSIon:VolumeAtlas','This viewer needs a transform saved with the confirmed coronal-stack geometry.');
assert(isequal(sort(g.permutation),1:3) && numel(g.originalSpacingUm)==3 && all(isfinite(g.originalSpacingUm)) && all(g.originalSpacingUm>0), ...
    'deConfUSIon:VolumeAtlas','Invalid native spacing or permutation in the transform.');
av=double(atlas.VoxelSize(:)');sz=[size(atlas.Histology,1) size(atlas.Histology,2) size(atlas.Histology,3)];
assert(isequal(double(T.size),sz) && all(abs(av-double(g.atlasVoxelSizeUm))<1e-6), ...
    'deConfUSIon:VolumeAtlas','Saved transform and atlas geometry do not match.');
M=double(T.M);
assert(isequal(size(M),[4 4]) && all(isfinite(M(:))) && rcond(M)>1e-10 && norm(M(:,4)-[0;0;0;1])<1e-8, ...
    'deConfUSIon:VolumeAtlas','Invalid saved affine transform.');
assert(det(M(1:3,1:3))>0,'deConfUSIon:VolumeAtlas','Unexpected reflection in the saved transform.');
step=max(1,ceil(max(sz)/maxDimension));indices={1:step:sz(1),1:step:sz(2),1:step:sz(3)};
% Atlas arrays are [AP DV LR]; Video arrays are [DV LR AP].
if isempty(cache)
    histology=normalize(single(permute(atlas.Histology(indices{:}),[2 3 1])));
    vascular=normalize(single(permute(atlas.Vascular(indices{:}),[2 3 1])));
    brain=permute(fusiAtlasBrainMask(atlas,atlas.Regions(indices{:})),[2 3 1]);
    [dv,lr,ap]=ndgrid(single(indices{2}),single(indices{3}),single(indices{1}));
    grid=[dv(:) ap(:) lr(:) ones(numel(dv),1,'single')];
    cache=struct('atlas',atlas,'path',path,'maxDimension',maxDimension, ...
        'histology',histology,'vascular',vascular,'brain',brain,'grid',grid,'shape',size(dv));
else
    histology=cache.histology;vascular=cache.vascular;brain=cache.brain;grid=cache.grid;
end
points=grid/single(M);
prepared={reshape(points(:,2),cache.shape),reshape(points(:,1),cache.shape),reshape(points(:,3),cache.shape)};clear points grid;
q=cell(1,3);nativePermSize=shape(g.permutation);sv=double(g.originalSpacingUm(g.permutation));
for axis=1:3
    value=1+(prepared{axis}-1)*av(axis)/sv(axis);
    if isfield(g,'flipAxes') && ismember(axis,g.flipAxes),value=nativePermSize(axis)+1-value;end
    q{g.permutation(axis)}=value;
end
coverage=brain;
for axis=1:3,coverage=coverage & q{axis}>=1 & q{axis}<=shape(axis);end
provenance=struct('transformFile',transformFile,'matrix',M,'scanGeometry',g,'atlasFile',path, ...
    'atlasOriginalSizeAPDVLR',sz,'displayStride',step,'nativeSize',shape, ...
    'referenceRole','Atlas anatomy is context; PSC is only shown within acquired finite coverage.', ...
    'reviewRequired',false,'unsaved',unsaved);
if isfield(T,'autoRegistration') && isstruct(T.autoRegistration) && isfield(T.autoRegistration,'reviewRequired')
    provenance.reviewRequired=T.autoRegistration.reviewRequired;
end
static=[];slabCache=[];
context=struct('reference',histology,'vascular',vascular,'brainMask',brain,'coverageMask',coverage, ...
    'spacingYXZmm',av([2 3 1])*step/1000,'label','Allen atlas context', ...
    'axisOrder','row=DV, column=LR, slice=AP','provenance',provenance,'frameMapper',@mapFrame, ...
    'slabMapper',@mapSlabs,'referenceCache',cache);

    function slabs=mapSlabs(S,centers,thickness,reference)
        [slabs,slabCache]=fusiMapAtlasSlabs(S,atlas,g,M,centers,thickness,reference,slabCache);
    end

    function S=mapFrame(S,reuse)
        if nargin<2,reuse=false;end
        nativeSlices=S.slices;queryZ=q{3}-nativeSlices(1)+1;
        valid=sample(single(isfinite(S.psc)),0)>=.999 & coverage;
        p=sample(S.psc,NaN);p(~valid)=NaN;
        if reuse && ~isempty(static)
            u=static.u;validU=static.validU;signal=static.signal;
        else
            u=sample(S.underlay,0);validU=sample(single(S.underlayValid),0)>=.999 & coverage;
            signal=sample(S.signal,0);u(~validU)=0;signal(~validU)=0;
            static=struct('u',u,'validU',validU,'signal',signal);
        end
        S.psc=p;S.underlay=u;S.underlayValid=validU;S.signal=signal;
        S.nativeSlices=nativeSlices;S.slices=[1 size(p,3)];S.spacing=context.spacingYXZmm;S.units='mm';
        S.atlasReference=histology;S.atlasBrainMask=brain;S.atlasCoverageMask=validU;
        S.atlasAxisOrder=context.axisOrder;S.atlasProvenance=provenance;
        S.note=strtrim([S.note ' Atlas tissue is reference context; PSC remains limited to acquired coverage.']);
        function V=sample(X,fill)
            V=single(interp3(single(X),q{2},q{1},queryZ,'linear',fill));
        end
    end
end

function V=normalize(V)
values=sort(V(isfinite(V) & V>0));
if isempty(values),V(:)=0;return;end
hi=values(max(1,round(.995*numel(values))));V=min(1,max(0,V/max(hi,eps('single'))));V(~isfinite(V))=0;
end
