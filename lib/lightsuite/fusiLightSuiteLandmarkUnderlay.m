function [image,meta]=fusiLightSuiteLandmarkUnderlay(s,file)
% Display-only native pixels: never replace opts.sample or fit intensities.
image=[];meta=struct();
if nargin<2||isempty(file)
    saved=fullfile(s.opts.savepath,'landmark_underlay.mat');
    if ~isfile(saved),return;end
    S=load(saved,'displayImage','displayMeta');image=S.displayImage;meta=S.displayMeta;
else
    S=load(file);B=scmReadMaskEditorBundle(S);
    assert(~isempty(B),'deConfUSIon:LightSuiteLandmarkUnderlay','Select a saved Mask Editor underlay bundle.');
    image=single(B.image);image(~isfinite(image))=0;
    if ~isempty(B.brainMask)
        assert(isequal(size(B.brainMask),size(image)),'Mask Editor brain mask and underlay differ.');
        image(~B.brainMask)=0;
    end
    meta=struct('sourceFile',char(file),'processed',B.isProcessed,'nativeSize',size(image,[1 2 3]), ...
        'purpose','Display only; original anatomy, transforms and landmark coordinates unchanged');
end
assert(ndims(image)<=3&&isequal(size(image,[1 2 3]),double(s.inputSize(1:3))), ...
    'deConfUSIon:LightSuiteLandmarkUnderlayGrid', ...
    'Choose the Mask Editor underlay on this recording''s native grid %s. Cropped or atlas-space images cannot be used for native landmarks.',mat2str(s.inputSize(1:3)));
end
