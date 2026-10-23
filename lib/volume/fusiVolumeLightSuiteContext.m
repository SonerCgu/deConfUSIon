function context=fusiVolumeLightSuiteContext(data,selection,maxDimension,previous,progress)
% Reuse an accepted LightSuite fit for atlas-space 3D scenes and movies.
if nargin<4,previous=[];end
if nargin<5,progress=@(~,~)[];end
folder=selection.projectFolder;stage=selection.registrationStage;
progress(.05,'Reading saved LightSuite geometry; no registration is being fitted...');
files={'deconfusion_lightsuite_session.mat','transform_params.mat','bspline_atlas_to_samp_20um.txt','bspline_samp_to_atlas_20um.txt'};
stamp=[];
for k=1:numel(files)
    d=dir(fullfile(folder,files{k}));assert(numel(d)==1,'Missing LightSuite project file: %s',files{k});
    stamp=[stamp d.bytes d.datenum]; %#ok<AGROW>
end
key={folder,stamp,maxDimension};cache=[];
if isstruct(previous)&&isfield(previous,'referenceCache')&&isfield(previous.referenceCache,'key')&&isequal(previous.referenceCache.key,key)
    cache=previous.referenceCache;s=cache.session;
else,s=fusiLightSuite('load',folder);end
shape=size(data.PSC,[1 2 3]);
assert(~isfield(data,'transformed')||~data.transformed,'deConfUSIon:VolumeLightSuiteGrid','Open the native recording before loading a LightSuite fit.');
assert(isequal(double(shape),double(s.inputSize(1:3))),'deConfUSIon:VolumeLightSuiteGrid', ...
    'This fit uses native grid %s; the recording uses %s. Select the matching recording or project. No new registration is required for scans on the same grid.',mat2str(s.inputSize(1:3)),mat2str(shape));
cal=scmSpatialCalibration(data.par);known=isfinite(cal.spacingUm)&cal.spacingUm>0;
assert(~any(known&abs(cal.spacingUm-1000*s.opts.sample_res)>max(1e-5,1000*s.opts.sample_res*1e-4)), ...
    'deConfUSIon:VolumeLightSuiteGrid','The recording voxel spacing differs from the saved LightSuite geometry.');
assert(s.fitReviewed,'deConfUSIon:VolumeLightSuiteReview','Review and accept this existing fit in LightSuite before using it for 3D movies.');
if isempty(cache)
    progress(.15,'Checking the saved affine and B-spline transforms...');
    fusiLightSuite('validatefit',s,false,fullfile(folder,'bspline_samp_to_atlas_20um.txt'));
    progress(.3,'Preparing the published LightSuite atlas reference...');
    vascular=single(s.opts.atlas);histology=vascular;references={'Vascular'};
    if isfield(s.opts,'histology')
        histology=single(s.opts.histology);references={'Histology','Vascular'};
    elseif isfile(fullfile(s.config.allenAtlas,'average_template_10.nii.gz'))
        histology=fusiLightSuiteHistologyAtlas(s.config,size(vascular),s.opts.atlas_res);references={'Histology','Vascular'};
    end
    atlas=struct('Histology',histology,'Vascular',vascular,'Regions',s.opts.annotation,'VoxelSize',1000*s.opts.atlas_res);
    sz=size(vascular,[1 2 3]);step=max(1,ceil(max(sz)/maxDimension));indices={1:step:sz(1),1:step:sz(2),1:step:sz(3)};
    progress(.55,'Caching the saved inverse mapping for all movie frames...');
    mapper=fusiLightSuiteAtlasToNative(s);
    cache=struct('kind','LightSuite','key',{key},'session',s,'atlas',atlas,'maxDimension',maxDimension, ...
        'referenceNames',{references},'mapper',mapper,'stride',step,'indices',{indices}, ...
        'histology',normalize(permute(histology(indices{:}),[2 3 1])), ...
        'vascular',normalize(permute(vascular(indices{:}),[2 3 1])), ...
        'brain',permute(s.opts.annotation(indices{:})>0,[2 3 1]));
end
progress(.8,'Mapping acquired coverage onto the atlas display grid...');
atlas=cache.atlas;indices=cache.indices;brain=cache.brain;sz=size(atlas.Vascular,[1 2 3]);
[dv,lr,ap]=ndgrid(single(indices{2}),single(indices{3}),single(indices{1}));
points=cache.mapper.query([dv(:) ap(:) lr(:)],stage);q=cell(1,3);coverage=brain;
for axis=1:3,q{axis}=reshape(single(points(:,axis)),size(dv));coverage=coverage&q{axis}>=1&q{axis}<=shape(axis);end
assert(any(coverage(:)),'deConfUSIon:VolumeLightSuiteCoverage','This saved fit places no acquired voxels inside the atlas. Check the selected project, native grid and accepted alignment.');
p=s.opts.permute_sample_to_atlas;
g=struct('originalSize',shape,'originalSpacingUm',1000*s.opts.sample_res,'permutation',abs(p), ...
    'flipAxes',find(p<0),'atlasVoxelSizeUm',atlas.VoxelSize,'convention','LightSuite_CCF2020','registrationStage',stage);
provenance=struct('kind','LightSuite','transformFile',fullfile(folder,'transform_params.mat'), ...
    'projectFolder',folder,'registrationStage',stage,'scanGeometry',g,'atlasOriginalSizeAPDVLR',sz, ...
    'displayStride',cache.stride,'nativeSize',shape,'reviewRequired',false,'unsaved',false, ...
    'deformationSamplingMm',cache.mapper.deformationSamplingMm,'inverseFile',cache.mapper.inverseFile, ...
    'savedFitSignature',stamp, ...
    'referenceRole','Published LightSuite atlas context; functional samples remain limited to acquired finite coverage.');
static=[];slabCache=[];
context=struct('reference',cache.histology,'vascular',cache.vascular,'brainMask',brain,'coverageMask',coverage, ...
    'spacingYXZmm',s.opts.atlas_res([2 3 1])*cache.stride,'label',['LightSuite | ' stage], ...
    'axisOrder','row=DV, column=LR, slice=AP','provenance',provenance,'frameMapper',@mapFrame, ...
    'slabMapper',@mapSlabs,'referenceCache',cache,'referenceNames',{cache.referenceNames});
progress(1,'Saved LightSuite registration loaded.');
    function S=mapFrame(S,reuse)
        if nargin<2,reuse=false;end
        queryZ=q{3}-S.slices(1)+1;
        valid=sample(single(isfinite(S.psc)),0)>=.999&coverage;
        mapped=sample(S.psc,NaN);mapped(~valid)=NaN;
        if reuse&&~isempty(static),u=static.u;validU=static.validU;signal=static.signal;
        else
            u=sample(S.underlay,0);validU=sample(single(S.underlayValid),0)>=.999&coverage;
            signal=sample(S.signal,0);u(~validU)=0;signal(~validU)=0;
            static=struct('u',u,'validU',validU,'signal',signal);
        end
        S.nativeSlices=S.slices;S.slices=[1 size(mapped,3)];S.psc=mapped;S.underlay=u;S.underlayValid=validU;S.signal=signal;
        S.spacing=context.spacingYXZmm;S.units='mm';S.atlasReference=context.reference;S.atlasBrainMask=brain;
        S.atlasCoverageMask=validU;S.atlasAxisOrder=context.axisOrder;S.atlasProvenance=provenance;
        S.note=strtrim([S.note ' Saved LightSuite ' stage '; no functional samples outside acquisition coverage.']);
        function V=sample(X,fill),V=single(interp3(single(X),q{2},q{1},queryZ,'linear',fill));end
    end
    function slabs=mapSlabs(S,centers,thickness,reference)
        [slabs,slabCache]=fusiMapAtlasSlabs(S,atlas,g,eye(4),centers,thickness,reference,slabCache, ...
            @(xyz)cache.mapper.query(xyz,stage));
    end
end
function V=normalize(V)
values=V(isfinite(V)&V>0);if isempty(values),V(:)=0;return;end
hi=quantile(values,.995);V=min(1,max(0,single(V)/max(hi,eps('single'))));V(~isfinite(V))=0;
end
