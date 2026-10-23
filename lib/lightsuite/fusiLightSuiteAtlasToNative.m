function mapper=fusiLightSuiteAtlasToNative(s)
% Compose inverse affine and the saved inverse B-spline into native queries.
% A bounded dense displacement cache is interpolated, never a 4-D movie.
guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
tr=load(fullfile(s.opts.savepath,'transform_params.mat'));
affine=tr.tform_affine_samp20um_to_atlas_10um_px;
file=fullfile(s.opts.savepath,'bspline_samp_to_atlas_20um.txt');params=elastix_parameter_read(file);
assert(strcmp(params.InitialTransformParametersFileName,'NoInitialTransform')&& ...
    norm(reshape(params.Direction,3,3)-eye(3),'fro')<1e-6, ...
    'deConfUSIon:VolumeLightSuiteInverse','This LightSuite inverse needs an independent, axis-aligned saved transform.');
coeff=double(params.TransformParameters(:));
if contains(params.Transform,'BSpline')&&mod(numel(coeff),3)==0,bound=max(abs(reshape(coeff,[],3)),[],1);
elseif strcmp(params.Transform,'TranslationTransform')&&numel(coeff)==3,bound=abs(coeff(:)');
else,error('deConfUSIon:VolumeLightSuiteInverse','Unsupported inverse transform: %s',params.Transform);end
spacing=double(params.Spacing(:)');origin=double(params.Origin(:)');shape=double(params.Size(:)');
low=origin-bound-2*spacing;high=origin+(shape-1).*spacing+bound+2*spacing;
fieldSpacing=spacing;
while prod(ceil((high-low)./fieldSpacing)+1)*12>128*1024^2,fieldSpacing=fieldSpacing*2;end
params.Origin=low;params.Spacing=fieldSpacing;params.Size=ceil((high-low)./fieldSpacing)+1;
params.Index=[0 0 0];params.ResultImagePixelType='float';
temporary=[tempname '.txt'];elastix_paramStruct2txt(temporary,params);
cleanup=onCleanup(@()delete(temporary)); %#ok<NASGU>
field=transformix([],temporary,'verbose',false);
assert(isequal(size(field,[1 2 3 4]),[3 params.Size])&&all(isfinite(field(:))), ...
    'deConfUSIon:VolumeLightSuiteInverse','The saved inverse did not produce a finite deformation field.');
F=cell(1,3);
for axis=1:3,F{axis}=griddedInterpolant(reshape(single(field(axis,:,:,:)),params.Size),'linear','none');end
clear field;
p=double(s.opts.permute_sample_to_atlas);nativeSize=double(s.inputSize(1:3));atlasSpacing=double(s.opts.atlas_res);
ratio=double(s.opts.sample_res(abs(p)))./atlasSpacing;
mapper=struct('query',@query,'deformationSamplingMm',fieldSpacing,'inverseFile',file);
    function native=query(atlasXYZ,stage)
        prepared=transformPointsInverse(affine,double(atlasXYZ));
        physical=(prepared-1).*atlasSpacing([2 1 3]);
        if strcmp(stage,'affine_bspline')
            ix=1+(physical-low)./fieldSpacing;
            moved=zeros(size(physical));
            for component=1:3,moved(:,component)=F{component}(ix(:,1),ix(:,2),ix(:,3));end
            physical=physical+moved;
        else,assert(strcmp(stage,'affine'),'Unknown LightSuite stage.');end
        prepared=physical./atlasSpacing([2 1 3])+1;prepared=prepared(:,[2 1 3]);
        prepared=.5+(prepared-.5)./ratio;
        for axis=1:3,if p(axis)<0,prepared(:,axis)=nativeSize(abs(p(axis)))+1-prepared(:,axis);end,end
        native=zeros(size(prepared));native(:,abs(p))=prepared;
    end
end
