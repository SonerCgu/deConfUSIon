function [backgrounds,affineBackgrounds]=fusiLightSuiteNativeBackgrounds(s,nativeMeta,progress,affineMeta,sampler)
% Native measurements and an uncropped reference display share one pull map.
if nargin<3,progress=[];end
if nargin<4,affineMeta=nativeMeta;affineMeta.registrationStage='affine';affineMeta.registrationStageName='Affine only';end
if nargin<5,sampler=fusiLightSuiteAtlasSampling(s,progress);end
backgrounds=struct('lightSuiteUnderlayMeta',nativeMeta,'lightSuiteDisplayGeometry',sampler.geometry);
affineBackgrounds=struct('lightSuiteUnderlayMeta',affineMeta,'lightSuiteDisplayGeometry',sampler.geometry);
report('Mapping full vascular reference: affine and affine + B-spline...');
[backgrounds.vascularImage,backgrounds.vascularDisplayImage]=sampler.sample(s.opts.atlas,'affine_bspline','linear');
[affineBackgrounds.vascularImage,affineBackgrounds.vascularDisplayImage]=sampler.sample(s.opts.atlas,'affine','linear');
if isfile(fullfile(s.config.allenAtlas,'average_template_10.nii.gz'))
    report('Reading and downsampling the Allen CCF2020 histology template...');
    histology=fusiLightSuiteHistologyAtlas(s.config,size(s.opts.atlas,[1 2 3]),s.opts.atlas_res);
    report('Mapping full histology reference: affine and affine + B-spline...');
    [backgrounds.histologyImage,backgrounds.histologyDisplayImage]=sampler.sample(histology,'affine_bspline','linear');
    [affineBackgrounds.histologyImage,affineBackgrounds.histologyDisplayImage]=sampler.sample(histology,'affine','linear');
else
    warning('deConfUSIon:LightSuiteHistologyMissing', ...
        'Vascular background saved. Install the Allen template with install_lightsuite_dependencies.ps1 -IncludeHistology and export again to add histology.');
end
    function report(message)
        if ~isempty(progress),progress(NaN,message);end
    end
end