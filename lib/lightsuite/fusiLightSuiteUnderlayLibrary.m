function [U,meta]=fusiLightSuiteUnderlayLibrary(S,file,targetSize)
% Each stage carries matching intensities, region IDs and hemisphere context.
[matched,~,inputMeta]=fusiLightSuiteRegionInput(S,targetSize);
assert(matched,'Expected a LightSuite native region bundle.');
folder=fileparts(file);finalFiles=fusiLightSuiteNativeFiles(folder);
affineFiles=fusiLightSuiteNativeFiles(folder,'affine');
complete=all(cellfun(@isfile,{finalFiles.regions,finalFiles.backgrounds,affineFiles.regions,affineFiles.backgrounds}));
complete=complete&&isfield(S.lightSuiteNativeMeta,'exportSchema')&&S.lightSuiteNativeMeta.exportSchema>=3;
if ~complete&&isfile(fullfile(folder,'deconfusion_lightsuite_session.mat'))
    progress=deConfUSIon_ui('progress','Prepare both LightSuite atlas stages',true);
    cleanup=onCleanup(@()deConfUSIon_ui('progressclose',progress)); %#ok<NASGU>
    fusiLightSuite('exportunderlays',folder, ...
        @(fraction,message)deConfUSIon_ui('progressupdate',progress,fraction,message));
    updated=fusiLightSuiteNativeFiles(folder,inputMeta.registrationStage);
    file=updated.regions;S=load(file);
end
stages={};stageIDs={'affine_bspline','affine'};selectedStage=1;
for stageIndex=1:2
    files=fusiLightSuiteNativeFiles(folder,stageIDs{stageIndex});
    if strcmp(stageIDs{stageIndex},inputMeta.registrationStage)
        T=S;files.regions=file;selectedStage=numel(stages)+1;
    elseif isfile(files.regions)
        T=load(files.regions);
        assert(isequaln(fitIdentity(T.lightSuiteNativeMeta),fitIdentity(S.lightSuiteNativeMeta)), ...
            'deConfUSIon:LightSuiteUnderlayFit','Affine and B-spline atlases belong to different exports. Export both stages again from the complete project.');
    else,continue;
    end
    [~,labels,regionMeta]=fusiLightSuiteRegionInput(T,targetSize);
    assert(strcmp(regionMeta.registrationStage,files.stage),'LightSuite stage does not match its filename.');
    entries={};names={};regionDisplay=[];
    if isfield(T,'atlasDisplayRegionLabels3D')&&isfield(T,'lightSuiteDisplayGeometry')
        regionDisplay=fusiLightSuiteAtlasDisplay(T.atlasDisplayRegionLabels3D,T.lightSuiteNativeMeta, ...
            'regions',T.lightSuiteDisplayGeometry,regionMeta.regionInfo);
    end
    if isfile(files.backgrounds)
        B=load(files.backgrounds);
        assert(isfield(B,'lightSuiteUnderlayMeta')&&isequaln(B.lightSuiteUnderlayMeta,T.lightSuiteNativeMeta), ...
            'deConfUSIon:LightSuiteUnderlayFit','LightSuite backgrounds and regions belong to different exports. Export native atlas backgrounds again.');
        for mode={'vascular','histology'}
            field=[mode{1} 'Image'];if ~isfield(B,field),continue;end
            image=B.(field);
            assert(isnumeric(image)&&isequal(size(image,[1 2 3]),double(targetSize))&&all(isfinite(image(:))), ...
                'deConfUSIon:LightSuiteNativeGrid','LightSuite background differs from the native recording grid.');
            m=rmfield(regionMeta,'regionLabels');m.isColor=false;m.atlasMode=mode{1};
            textureField=[mode{1} 'DisplayImage'];windowImage=image;
            if isfield(B,textureField)
                geometry=struct('xData',[1 targetSize(2)],'yData',[1 targetSize(1)]);
                if isfield(B,'lightSuiteDisplayGeometry'),geometry=B.lightSuiteDisplayGeometry;end
                m.displayProvider=fusiLightSuiteAtlasDisplay(B.(textureField),T.lightSuiteNativeMeta,mode{1},geometry);
                windowImage=B.(textureField);
            end
            m.displayIntensityLimits=fusiAtlasIntensityLimits(windowImage);
            entries{end+1}=struct('data',image,'meta',m,'grouping','Structure'); %#ok<AGROW>
            names{end+1}=[upper(mode{1}(1)) mode{1}(2:end)]; %#ok<AGROW>
        end
    end
    % Keep the actual acquired anatomy available alongside the reference.
    % This makes an atlas overhang distinguishable from lost signal pixels.
    if isfile(files.mask)
        M=load(files.mask,'brainImage','lightSuiteMaskMeta');
        if isfield(M,'brainImage')&&isequal(size(M.brainImage,[1 2 3]),double(targetSize))
            assert(isfield(M,'lightSuiteMaskMeta')&&isequaln(M.lightSuiteMaskMeta,T.lightSuiteNativeMeta), ...
                'deConfUSIon:LightSuiteUnderlayFit','Recorded anatomy and atlas belong to different exports. Export both atlas stages again.');
            m=rmfield(regionMeta,'regionLabels');m.isColor=false;m.atlasMode='recorded';
            geometry=struct('nativeSize',double(targetSize),'xData',[1 targetSize(2)],'yData',[1 targetSize(1)]);
            m.displayProvider=fusiLightSuiteAtlasDisplay(M.brainImage,T.lightSuiteNativeMeta,'recorded',geometry);
            entries{end+1}=struct('data',M.brainImage,'meta',m,'grouping','Structure'); %#ok<AGROW>
            names{end+1}='Recorded anatomy'; %#ok<AGROW>
        end
    end
    if ~isempty(regionDisplay),regionMeta.displayProvider=regionDisplay;end
    entries{end+1}=struct('data',fusiRegionLabelRGB(labels,regionMeta.regionInfo),'meta',regionMeta,'grouping','Structure');
    names{end+1}='Regions';
    ctx=regionMeta;ctx.labels=labels;ctx.info=regionMeta.regionInfo;
    ctx.provenance=struct('file',files.regions,'transformFile',regionMeta.transformFile, ...
        'space','native','grouping','Structure','arrayOrder',T.lightSuiteNativeMeta.arrayOrder, ...
        'registrationStage',files.stage,'registrationStageName',files.name);
    stages{end+1}=struct('id',files.stage,'name',files.name,'entries',{entries},'names',{names}, ...
        'context',ctx,'selected',numel(entries),'sourceFiles',files,'nativeMeta',T.lightSuiteNativeMeta); %#ok<AGROW>
end
% Fit all stages and backgrounds together, keeping the view stable on scroll
% and stage changes. The complete texture remains available for export.
bounds=[];
for si=1:numel(stages)
    for ei=1:numel(stages{si}.entries)
        m=stages{si}.entries{ei}.meta;
        if isfield(m,'displayProvider')&&isfield(m.displayProvider,'viewBounds')
            b=m.displayProvider.viewBounds;
            if isempty(bounds),bounds=b;else,bounds=[min(bounds(:,1),b(:,1)) max(bounds(:,2),b(:,2))];end
        end
    end
end
if ~isempty(bounds)
    for si=1:numel(stages)
        for ei=1:numel(stages{si}.entries)
            if isfield(stages{si}.entries{ei}.meta,'displayProvider')
                stages{si}.entries{ei}.meta.displayProvider.viewBounds=bounds;
            end
        end
        if isfield(stages{si}.context,'displayProvider'),stages{si}.context.displayProvider.viewBounds=bounds;end
    end
end
library=stages{selectedStage};entry=library.entries{library.selected};U=entry.data;meta=entry.meta;
library.stages=stages;library.selectedStage=selectedStage;
meta.nativeUnderlayLibrary=library;
end
function q=fitIdentity(q)
q=rmfield(q,intersect(fieldnames(q),{'registrationStage','registrationStageName','explanation'}));
end
