function varargout = driftcompensation(varargin)
% PACAP_RESPONSE_ESTIMATOR_WRAPPER
% Dispatches PACAP response estimation to deConfUSIon_pacap_response_estimator.

opts = struct();
if nargin >= 4 && isstruct(varargin{4})
    opts = varargin{4};
end
method = '';
try
    if isfield(opts,'method') && ~isempty(opts.method)
        method = lower(strtrim(char(opts.method)));
    end
catch
    method = '';
end

if any(strcmp(method,{'pacap','pacap_response','pacap_response_estimator','response_estimator'}))
    if nargout == 0
        deConfUSIon_pacap_response_estimator(varargin{:});
    else
        [varargout{1:nargout}] = deConfUSIon_pacap_response_estimator(varargin{:});
    end
    return;
end

if nargout == 0
    deConfUSIon_driftcompensation_core(varargin{:});
else
    [varargout{1:nargout}] = deConfUSIon_driftcompensation_core(varargin{:});
end
end
