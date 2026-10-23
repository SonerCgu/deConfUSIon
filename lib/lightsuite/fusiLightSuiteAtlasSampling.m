function sampler=fusiLightSuiteAtlasSampling(s,progress,buildDisplay,sampleGrids)
% Compose native -> saved deformation -> affine -> reference in one pull.
% The reference canvas may extend beyond the acquired grid; measurements do not.
if nargin<2,progress=[];end
if nargin<3,buildDisplay=true;end
guard=fusiLightSuitePaths(s.config); %#ok<NASGU>
opts=s.opts;p=double(opts.permute_sample_to_atlas);shape=double(s.inputSize(1:3));
if nargin<4,sampleGrids={1:shape(1),1:shape(2),1:shape(3)};end
sampleShape=cellfun(@numel,sampleGrids);
spacing=double(opts.atlas_res);
% Use the scale passed to imresize3, rather than its rounded output size.
% Ceil(size*scale)/size subtly stretches noninteger acquisition spacings.
ratio=double(opts.sample_res(abs(p)))./spacing;
tr=load(fullfile(opts.savepath,'transform_params.mat'));
affine=tr.tform_affine_samp20um_to_atlas_10um_px;
forward=fullfile(opts.savepath,'bspline_atlas_to_samp_20um.txt');params=elastix_parameter_read(forward);
% Bound the reference box after the inverse affine. B-spline basis weights
% are nonnegative and sum to <=1, so coefficient extrema bound displacement.
coefficients=double(params.TransformParameters(:));
if contains(params.Transform,'BSpline')&&mod(numel(coefficients),3)==0
    bound=max(abs(reshape(coefficients,[],3)),[],1);
elseif strcmp(params.Transform,'TranslationTransform')&&numel(coefficients)==3
    bound=abs(coefficients(:)');
else
    field=transformix([],forward,'verbose',false);
    bound=max(abs(reshape(field,3,[])),[],2)';clear field
end
assert(all(isfinite(bound)),'deConfUSIon:LightSuiteDisplayField','Invalid saved deformation.');
sz=double(size(opts.atlas,[1 2 3]));
[x,y,z]=ndgrid([.5 sz(2)+.5],[.5 sz(1)+.5],[.5 sz(3)+.5]);
corners=transformPointsInverse(affine,[x(:) y(:) z(:)]);
native=preparedToNative(corners(:,[2 1 3]));
nativeBound=zeros(1,3);nativeBound(abs(p))=bound([2 1 3])./(ratio.*spacing);
low=floor(min([ones(1,3);native],[],1)-nativeBound)-2;
high=ceil(max([shape;native],[],1)+nativeBound)+2;
xData=[low(2) high(2)];yData=[low(1) high(1)];
% Retain atlas detail with a bounded display-only volume, at native Z planes.
canvas=[diff(yData) diff(xData)]+1;
factor=min(4,max(1,opts.sample_res(1:2)/min(spacing)));
textureSize=min(1536,max(2,ceil(canvas.*factor)));
budget=64*1024^2;
if prod(textureSize)*shape(3)*4>budget
    textureSize=max(2,floor(textureSize*sqrt(budget/(prod(textureSize)*shape(3)*4))));
end
assert(prod(textureSize)*shape(3)*4<=budget,'LightSuite reference canvas exceeds the display memory budget.');
grids={linspace(yData(1),yData(2),textureSize(1)),linspace(xData(1),xData(2),textureSize(2)),1:shape(3)};
% Ask Transformix for the SAME saved transform on the expanded physical grid.
% Neither the original parameters nor the fitted coefficients are changed.
report('Sampling the saved deformation over the full reference canvas...');
displayDeformation=[];if buildDisplay,displayDeformation=readDeformation(grids);end
% Quantitative atlas lookup uses the exact native pixel centres, independent
% of display resolution or the display memory budget.
nativeDeformation=readDeformation(sampleGrids);
% Reference direction corresponding to the native image's vertical axis.
vertical=find(abs(p)==1);v=zeros(1,3);v(vertical)=sign(p(vertical));
centre=[sz(2) sz(1) sz(3)]/2;
q=transformPointsInverse(affine,[centre;centre+v([2 1 3])]);
q=preparedToNative(q(:,[2 1 3]));up=diff(q(:,[2 1]),1,1);
if norm(up)<1e-9,up=[0 1];end
if up(2)<0,up=-up;end
geometry=struct('schema',1,'nativeSize',shape,'xData',xData,'yData',yData, ...
    'textureSizeYX',textureSize,'uprightVectorXY',up, ...
    'sampling','One composed pull from the full reference; native pixel-centre coordinates');
sampler=struct('sample',@sampleVolume,'geometry',geometry);

    function [nativeImage,displayImage]=sampleVolume(atlas,stage,method,includeDisplay)
        if nargin<3,method='linear';end
        if nargin<4,includeDisplay=buildDisplay;end
        assert(~includeDisplay||buildDisplay,'The sampler was created without the display field.');
        reference=griddedInterpolant(single(atlas),method,'none');
        nativeImage=zeros(sampleShape,'single');displayImage=[];
        if includeDisplay,displayImage=zeros([textureSize shape(3)],'single');end
        [ny,nx]=ndgrid(sampleGrids{1},sampleGrids{2});
        for plane=1:sampleShape(3)
            nativeImage(:,:,plane)=samplePlane(ny,nx,sampleGrids{3}(plane),reference,stage,nativeDeformation(:,:,plane,:));
        end
        if includeDisplay
            [dy,dx]=ndgrid(grids{1},grids{2});
            for plane=1:shape(3)
                displayImage(:,:,plane)=samplePlane(dy,dx,plane,reference,stage,displayDeformation(:,:,plane,:));
            end
        end
    end
    function image=samplePlane(y,x,plane,reference,stage,deformation)
        raw=[y(:) x(:) plane*ones(numel(y),1)];prepared=nativeToPrepared(raw);
        physical=(prepared(:,[2 1 3])-1).*spacing([2 1 3]);
        if strcmp(stage,'affine_bspline')
            physical=physical+double(reshape(deformation,[],3));
        else,assert(strcmp(stage,'affine'),'Unknown LightSuite registration stage.');end
        coordinates=physical./spacing([2 1 3])+1;
        coordinates=transformPointsForward(affine,coordinates);
        referenceSize=size(reference.Values,[2 1 3]);
        inside=all(coordinates>=.5&coordinates<=referenceSize+.5,2);
        coordinates=max(1,min(referenceSize,coordinates));
        values=reference(coordinates(:,2),coordinates(:,1),coordinates(:,3));values(~inside|~isfinite(values))=0;
        image=reshape(single(values),size(y));
    end
    function prepared=nativeToPrepared(raw)
        prepared=raw(:,abs(p));
        for a=1:3,if p(a)<0,prepared(:,a)=shape(abs(p(a)))+1-prepared(:,a);end,end
        prepared=.5+(prepared-.5).*ratio;
    end
    function raw=preparedToNative(prepared)
        prepared=.5+(prepared-.5)./ratio;
        for a=1:3,if p(a)<0,prepared(:,a)=shape(abs(p(a)))+1-prepared(:,a);end,end
        raw=zeros(size(prepared));raw(:,abs(p))=prepared;
    end
    function field=readDeformation(queryGrids)
        count=cellfun(@numel,queryGrids);ends=zeros(2,3);step=zeros(1,3);
        for a=1:3
            ends(:,a)=[queryGrids{a}(1);queryGrids{a}(end)];step(a)=diff(ends(:,a))/(count(a)-1);
        end
        origin=min(nativeToPrepared(ends),[],1);fixedSpacing=step(abs(p)).*ratio.*spacing;
        fixedSize=count(abs(p));parameters=params;
        parameters.Size=fixedSize([2 1 3]);parameters.Index=[0 0 0];parameters.Spacing=fixedSpacing([2 1 3]);
        parameters.Origin=(origin([2 1 3])-1).*spacing([2 1 3]);parameters.Direction=reshape(eye(3),1,9);
        parameters.UseDirectionCosines=true;parameters.ResultImagePixelType='float';
        temporary=[tempname(opts.savepath) '_display_field.txt'];elastix_paramStruct2txt(temporary,parameters);
        cleanup=onCleanup(@()delete(temporary)); %#ok<NASGU>
        field=transformix([],temporary,'verbose',false);
        assert(isequal(size(field,[1 2 3 4]),[3 parameters.Size])&&all(isfinite(field(:))), ...
            'deConfUSIon:LightSuiteDisplayField','Transformix returned an invalid reference field.');
        field=permute(field,[3 2 4 1]);
        for a=1:3,if p(a)<0,field=flip(field,a);end,end
        field=ipermute(field,[abs(p) 4]);
    end
    function report(message)
        if ~isempty(progress),progress(NaN,message);end
    end
end
