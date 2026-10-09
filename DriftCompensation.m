function varargout = DriftCompensation(action,varargin)
% DriftCompensation  Public entry point for drift compensation workflows.
%
%   [Icorr,stats] = DriftCompensation('run',I,TR,exportPath,opts)
%   cfg          = DriftCompensation('dialog',defaults)
%   stats        = DriftCompensation('stats',stats,Icorr,I,TR,opts)
%
% The legacy deConfUSIon_* files remain compatibility backends for existing
% projects; new code should use this short, discoverable module entry point.
% Preserve the historical numeric-first call signature while exposing the
% shorter named actions for new code.
deConfUSIon_setup();
if nargin==0
    action='run';
elseif ~(ischar(action) || isstring(action))
    args=[{action},varargin]; opts=struct();
    if numel(args)>=4 && isstruct(args{4}), opts=args{4}; end
    [outI,stats]=DriftCompensation('run',args{:});
    if nargout<=1, varargout{1}=outI; else, varargout{1}=outI; varargout{2}=stats; end
    return;
end
if nargin<1 || isempty(action), action='run'; end
switch lower(char(action))
    case {'run','core'}
        opts=struct();
        if numel(varargin)>=4 && isstruct(varargin{4}), opts=varargin{4}; end
        method=''; if isfield(opts,'method'), method=lower(strtrim(char(opts.method))); end
        if any(strcmp(method,{'pacap','pacap_response','pacap_response_estimator','early_pacap_delayed_drift'}))
            [outI,stats]=deConfUSIon_pacap_response_estimator(varargin{:});
            stats=deConfUSIon_pacap_common_drift_stats(stats,varargin{1},outI,varargin{2},opts);
            varargout={outI,stats};
        else
            [varargout{1:nargout}] = deConfUSIon_driftcompensation_core(varargin{:});
        end
    case {'dialog','setup'}
        [varargout{1:nargout}] = deConfUSIon_drift_dialog(varargin{:});
    case 'stats'
        [varargout{1:nargout}] = deConfUSIon_pacap_common_drift_stats(varargin{:});
    case 'pacap'
        [varargout{1:nargout}] = deConfUSIon_pacap_response_estimator(varargin{:});
    otherwise
        error('deConfUSIon:DriftCompensationAction','Unknown action: %s',char(action));
end
end
