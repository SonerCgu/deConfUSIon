function guard = fusiLightSuitePaths(cfg)
% Reference-counted context: overlapping GUIs/actions cannot restore stale
% paths over one another. No recursive repository or permanent path changes.
manageContext('acquire',cfg);
guard=onCleanup(@()manageContext('release',cfg));
end

function manageContext(action,cfg)
persistent state
if strcmp(action,'release')
    if isempty(state),return;end
    state.count=state.count-1;if state.count>0,return;end
    if strcmp(path,state.activePath),path(state.oldPath);
    else
        % Preserve unrelated user addpath/rmpath operations made while a GUI
        % was open. Remove only folders that this context introduced.
        parts=strsplit(path,pathsep);parts=parts(~ismember(parts,state.added));
        path(strjoin(parts,pathsep));
    end
    current=getenv('PATH');prefix=[state.bin pathsep];
    if strcmp(current,[prefix state.oldEnv]),setenv('PATH',state.oldEnv);
    elseif startsWith(current,prefix),setenv('PATH',current(numel(prefix)+1:end));end
    setenv('DECONFUSION_LIGHTSUITE_ELASTIX',state.oldElastix);
    setenv('DECONFUSION_LIGHTSUITE_YAML',state.oldYaml);
    state=[];return;
end
key=strjoin({cfg.lightSuite,cfg.matlabElastix,cfg.yamlMatlab,cfg.elastixBin,cfg.allenAtlas},'|');
if ~isempty(state)
    assert(strcmp(state.key,key),'deConfUSIon:LightSuiteContext','Close the other LightSuite windows before choosing a different dependency installation.');
    state.count=state.count+1;return;
end
oldPath=path;oldEnv=getenv('PATH');
adapter=fusiLightSuitePrepareAdapters(cfg);
modules = {'helpers','registration','control_point_gui','fusi','slice_module', ...
    'fiber_tracing','preprocessing','atlas_counting','cell_counting','unsorted'};
folders = {fullfile(cfg.matlabElastix,'code'), cfg.yamlMatlab, cfg.bcpd, ...
    fullfile(cfg.matlabElastix,'example_parameter_files'), cfg.allenAtlas};
for k=1:numel(modules), folders{end+1}=fullfile(cfg.lightSuite,'src',modules{k}); end %#ok<AGROW>
folders = [folders {cfg.bioformats,cfg.bfmatlab}];
folders{end+1}=fullfile(fileparts(mfilename('fullpath')),'compat');
folders{end+1}=adapter;
before=strsplit(oldPath,pathsep);added=folders(~ismember(folders,before));
state=struct('key',key,'count',1,'oldPath',oldPath,'oldEnv',oldEnv, ...
    'oldElastix',getenv('DECONFUSION_LIGHTSUITE_ELASTIX'), ...
    'oldYaml',getenv('DECONFUSION_LIGHTSUITE_YAML'),'bin',cfg.elastixBin,'added',{added},'activePath','');
for k=1:numel(folders), if isfolder(folders{k}), addpath(folders{k},'-begin'); end, end
% A small adapter replaces the upstream author's hard-coded addpath helper.
setenv('DECONFUSION_LIGHTSUITE_ELASTIX',cfg.matlabElastix);
setenv('DECONFUSION_LIGHTSUITE_YAML',cfg.yamlMatlab);
setappdata(groot,'deConfUSIonLightSuiteAdapters',adapter);
setenv('PATH',[cfg.elastixBin pathsep oldEnv]);
state.activePath=path;
end
