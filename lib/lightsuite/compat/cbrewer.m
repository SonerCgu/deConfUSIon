function colors=cbrewer(kind,name,n,varargin) %#ok<INUSD>
% Minimal display compatibility for LightSuite's optional implant figure.
% Uses MATLAB's own categorical palette, not the external ColorBrewer data.
% Palette choice affects plotted categories only, never annotation IDs,
% registration coordinates, fitted trajectories or measurements.
assert(strcmpi(kind,'qual')&&any(strcmpi(name,{'Dark2','Set1'}))&&isscalar(n)&&isfinite(n)&&n>=1&&n==round(n), ...
    'deConfUSIon:LightSuitePalette','Only the implant plot categorical palette request is supported by this adapter.');
colors=lines(n);
end
