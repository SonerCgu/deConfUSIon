function [matched,selection]=fusiVolumeLightSuiteSelection(input)
% Recognize a complete LightSuite project, its MAT files, or a saved link.
matched=false;selection=[];stage='affine_bspline';
if isstruct(input)
    if ~isfield(input,'kind')||~strcmp(input.kind,'LightSuite'),return;end
    folder=char(input.projectFolder);matched=true;
    if isfield(input,'registrationStage'),stage=char(input.registrationStage);end
elseif isfolder(input)
    folder=char(input);matched=true;
elseif isfile(input)
    fields=whos('-file',input);names={fields.name};
    matched=any(ismember(names,{'tform_affine_samp20um_to_atlas_10um_px','session','lightSuiteNativeMeta','lightSuiteUnderlayMeta'}));
    if ~matched,return;end
    folder=fileparts(char(input));
    [~,name]=fileparts(input);if contains(name,'LightSuite_Affine'),stage='affine';end
else,return;
end
assert(isfile(fullfile(folder,'deconfusion_lightsuite_session.mat'))&&isfile(fullfile(folder,'transform_params.mat')), ...
    'deConfUSIon:VolumeLightSuiteProject', ...
    'Choose the complete LightSuite project folder containing deconfusion_lightsuite_session.mat, transform_params.mat and the saved B-spline files. A transform MAT file alone is insufficient.');
assert(any(strcmp(stage,{'affine','affine_bspline'})),'Invalid LightSuite atlas stage.');
selection=struct('kind','LightSuite','projectFolder',folder,'registrationStage',stage);
end
