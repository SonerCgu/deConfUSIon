function [V, note] = deConfUSIon_collapse_time(D, method)
% deConfUSIon_collapse_time
% -------------------------------------------------------------
% Collapse a 4D matrix-probe dataset [Y X Z T] into a 3D anatomical
% volume [Y X Z] suitable for atlas registration.
%
% ONLY acts on 4D input. 3D input is returned untouched, because
% [Y X Z] (a small volume) and [Y X T] (a 2D time series) cannot be
% told apart reliably and guessing would silently destroy data.
%
% USAGE
%   V = deConfUSIon_collapse_time(D)
%   V = deConfUSIon_collapse_time(D, 'p90')    % default
%   V = deConfUSIon_collapse_time(D, 'mean')
%   V = deConfUSIon_collapse_time(D, 'max')
%   V = deConfUSIon_collapse_time(D, 'median')
%
% METHOD NOTES
%   'p90'    90th percentile over time per voxel. Gives a crisp
%            angiographic vascular map without single-frame noise.
%            Best default for power-Doppler anatomy.
%   'mean'   Lowest variance, softest vessels. Safe fallback.
%   'max'    Sharpest vessels but keeps every motion spike.
%   'median' Robust but washes out small vessels.
%
% Memory: processes one z-slice at a time and returns single
% precision, so peak usage stays near one slice rather than a full
% double copy of the movie.
%
% ASCII only. MATLAB 2017b compatible.
% -------------------------------------------------------------

if nargin < 2 || isempty(method)
    method = 'p90';
end
note = '';

if isempty(D)
    V = D;
    note = 'empty input';
    return;
end

if ndims(D) ~= 4
    V = D;
    note = sprintf('not 4D (ndims = %d), returned unchanged', ndims(D));
    return;
end

sz = size(D);
nY = sz(1); nX = sz(2); nZ = sz(3); nT = sz(4);

if nT < 2
    V = reshape(D, nY, nX, nZ);
    note = 'single time point, reshaped';
    return;
end

V = zeros(nY, nX, nZ, 'single');

for z = 1:nZ
    % [Y X T] for this slice only
    slab = double(reshape(D(:,:,z,:), nY*nX, nT));
    slab(~isfinite(slab)) = 0;

    switch lower(method)
        case 'mean'
            col = mean(slab, 2);

        case 'max'
            col = max(slab, [], 2);

        case 'median'
            col = median(slab, 2);

        otherwise   % 'p90'
            % sort-based percentile: no Statistics Toolbox needed
            s = sort(slab, 2);
            r = 0.90 * (nT - 1) + 1;
            lo = floor(r);
            hi = min(nT, lo + 1);
            w  = r - lo;
            col = (1-w) * s(:,lo) + w * s(:,hi);
    end

    V(:,:,z) = single(reshape(col, nY, nX));
end

note = sprintf('collapsed [%d %d %d %d] -> [%d %d %d] using %s over time', ...
    nY, nX, nZ, nT, nY, nX, nZ, lower(method));

end
