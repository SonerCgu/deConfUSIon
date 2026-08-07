function varargout = driftcompensation(varargin)
% PACAP_RESPONSE_ESTIMATOR_WRAPPER
% Dispatches PACAP response estimator or original drift compensation core.
% Also adds common stats fields expected by fusi_studio_GUI.

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

isPacap = any(strcmp(method,{'pacap','pacap_response','pacap_response_estimator','early_pacap_delayed_drift'}));

if isPacap
    I = varargin{1};
    TR = varargin{2};
    exportPath = '';
    if nargin >= 3, exportPath = varargin{3}; end

    [outI, stats] = deConfUSIon_pacap_response_estimator(I,TR,exportPath,opts);
    stats = deConfUSIon_pacap_common_drift_stats(stats,I,outI,TR,opts);

    if nargout <= 1
        varargout{1} = outI;
    else
        varargout{1} = outI;
        varargout{2} = stats;
        for k = 3:nargout
            varargout{k} = [];
        end
    end
    return;
end

if nargout == 0
    deConfUSIon_driftcompensation_core(varargin{:});
else
    [varargout{1:nargout}] = deConfUSIon_driftcompensation_core(varargin{:});
end
end
