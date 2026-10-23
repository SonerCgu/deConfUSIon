function files=fusiLightSuiteCopyNativeAtlas(library,folder)
% Copy the exact atlas stages currently loaded in SCM into a portable package.
assert(isfield(library,'stages')&&numel(library.stages)==2, ...
    'deConfUSIon:LightSuiteStagesMissing','Load a complete LightSuite project or an export containing both registration stages first.');
assert(~isfolder(folder)||isempty(setdiff({dir(folder).name},{'.','..'})), ...
    'Choose a new empty atlas export folder. Existing exports are preserved.');
for stageIndex=1:2
    stage=library.stages{stageIndex};source=stage.sourceFiles;
    current=load(source.regions,'lightSuiteNativeMeta');
    assert(isequaln(current.lightSuiteNativeMeta,stage.nativeMeta), ...
        'deConfUSIon:LightSuiteUnderlayFit','This atlas was re-exported after loading SCM. Reload it before exporting this comparison.');
    background=load(source.backgrounds,'lightSuiteUnderlayMeta');
    assert(isequaln(background.lightSuiteUnderlayMeta,stage.nativeMeta), ...
        'deConfUSIon:LightSuiteUnderlayFit','Atlas backgrounds changed after loading SCM. Reload the atlas.');
    if isfile(source.mask)
        mask=load(source.mask,'lightSuiteMaskMeta');
        assert(isfield(mask,'lightSuiteMaskMeta')&&isequaln(mask.lightSuiteMaskMeta,stage.nativeMeta), ...
            'deConfUSIon:LightSuiteUnderlayFit','Atlas masks and regions belong to different exports. Export both stages again.');
    end
end
if ~isfolder(folder),[ok,message]=mkdir(folder);assert(ok,'%s',message);end
files={};
for stageIndex=1:2
    stage=library.stages{stageIndex};target=fusiLightSuiteNativeFiles(folder,stage.id);
    for kind={'regions','backgrounds','mask'}
        source=stage.sourceFiles.(kind{1});if ~isfile(source),continue;end
        [ok,message]=copyfile(source,target.(kind{1}));assert(ok,'%s',message);
        files{end+1}=target.(kind{1}); %#ok<AGROW>
    end
end
end
