function addElastixRepoPaths()
% Adapter for LightSuite's machine-specific helper. No recursive path adds.
e=getenv('DECONFUSION_LIGHTSUITE_ELASTIX');y=getenv('DECONFUSION_LIGHTSUITE_YAML');
assert(isfolder(fullfile(e,'code')) && isfolder(y), ...
    'deConfUSIon:LightSuiteSetup','Open the deConfUSIon LightSuite workspace first.');
addpath(fullfile(e,'code'),'-begin');addpath(y,'-begin');
adapter=getappdata(groot,'deConfUSIonLightSuiteAdapters');
if ischar(adapter)&&isfolder(adapter),addpath(adapter,'-begin');end
end
