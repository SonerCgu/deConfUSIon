function varargout = deConfUSIon_LightSuite(varargin)
%DECONFUSION_LIGHTSUITE Optional landmark-guided LightSuite workspace.
%   deConfUSIon_LightSuite opens an independent, resumable registration GUI.
%   deConfUSIon_LightSuite('gui', data, meta) uses a loaded data.I volume.
%   R = deConfUSIon_LightSuite('dependencies') reports optional requirements.
%   S = deConfUSIon_LightSuite('prepare', data, meta, cfg) prepares a project.
%   See lib/lightsuite/README.md for the script API and coordinate contract.
%   The established deConfUSIon affine registration workflow is unchanged.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'lib', 'lightsuite'), '-end');
if nargin == 0, varargin = {'gui'}; end
[varargout{1:nargout}] = fusiLightSuite(varargin{:});
end
