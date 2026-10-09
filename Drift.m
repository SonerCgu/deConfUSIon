function varargout=Drift(action,varargin)
% Drift  Single public entry point for drift and artifact workflows.
% Compatibility wrappers remain available for older scripts, while new code
% can call Drift('core'|'pacap'|'stats'|'artifact'|'compcor'|'cca',...).
deConfUSIon_setup();
switch lower(char(action))
    case 'core'
        [varargout{1:nargout}]=DriftCompensation('run',varargin{:});
    case 'pacap'
        [varargout{1:nargout}]=deConfUSIon_pacap_response_estimator(varargin{:});
    case 'stats'
        [varargout{1:nargout}]=deConfUSIon_pacap_common_drift_stats(varargin{:});
    case 'artifact'
        [varargout{1:nargout}]=deConfUSIon_build_artifact_regressors(varargin{:});
    case 'compcor'
        [varargout{1:nargout}]=deConfUSIon_build_compcor_regressors(varargin{:});
    case 'cca'
        [varargout{1:nargout}]=deConfUSIon_spatial_cca_simple(varargin{:});
    otherwise
        error('deConfUSIon:DriftAction','Unknown Drift action: %s',char(action));
end
end
