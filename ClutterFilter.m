function varargout=ClutterFilter(action,varargin)
% ClutterFilter  Public entry point for SVD clutter filtering and QC GUI.
switch lower(char(action))
    case {'run','filter','svd'}
        [varargout{1:nargout}]=deConfUSIon_svd_clutter(varargin{:});
    case {'gui','review'}
        [varargout{1:nargout}]=deConfUSIon_svd_clutter_gui(varargin{:});
    otherwise
        error('deConfUSIon:ClutterFilterAction','Unknown action: %s',char(action));
end
end
