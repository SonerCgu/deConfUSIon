function files=fusiLightSuiteNativeFiles(folder,stage)
% The existing filenames remain the final affine + B-spline result.
if nargin<2,stage='affine_bspline';end
switch char(stage)
    case 'affine_bspline',prefix='LightSuite';name='Affine + B-spline';
    case 'affine',prefix='LightSuite_Affine';name='Affine only';
    otherwise,error('deConfUSIon:LightSuiteStage','Unknown registration stage: %s',char(stage));
end
files=struct('stage',char(stage),'name',name, ...
    'regions',fullfile(folder,[prefix '_Native_Regions.mat']), ...
    'backgrounds',fullfile(folder,[prefix '_Native_Backgrounds.mat']), ...
    'mask',fullfile(folder,[prefix '_Native_Mask.mat']));
end
