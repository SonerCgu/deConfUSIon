function a = deConfUSIon_view_aspect(par)
%DECONFUSION_VIEW_ASPECT  In-plane display aspect ratio for fUSI images.
%   Used as set(ax,'DataAspectRatio',[1 a 1]).  a > 1 makes a tall probe
%   image wider/shorter.  a == 1 is the legacy pixel-square behaviour.
%
%   Resolution order:
%     1) par.probeViewAspect                    explicit override
%     2) par.voxelSize / par.meta.voxelSize     physical size from the dataset
%     3) getpref deConfUSIon voxelSizeYX        [dY dX], any consistent unit
%     4) getpref deConfUSIon probeViewAspect    plain scalar
%     5) 1                                      unchanged legacy behaviour
%
%   Set once per rig, e.g.:
%     setpref('deConfUSIon','voxelSizeYX',[0.100 0.055])
%     setpref('deConfUSIon','probeViewAspect',1.6)

a = 1;
if nargin < 1 || ~isstruct(par), par = struct(); end

try
    if isfield(par,'probeViewAspect')
        v = double(par.probeViewAspect);
        if isscalar(v) && isfinite(v) && v > 0, a = v; return; end
    end
catch
end

try
    vs = [];
    if isfield(par,'voxelSize'), vs = double(par.voxelSize); end
    if isempty(vs) && isfield(par,'meta') && isstruct(par.meta)
        m = par.meta;
        if isfield(m,'voxelSize')
            vs = double(m.voxelSize);
        elseif isfield(m,'rawMetadata') && isstruct(m.rawMetadata) && isfield(m.rawMetadata,'voxelSize')
            vs = double(m.rawMetadata.voxelSize);
        end
    end
    vs = vs(:).';
    vs = vs(isfinite(vs) & vs > 0);
    if numel(vs) >= 2
        v = vs(1)/vs(2);
        if isfinite(v) && v > 0, a = v; return; end
    end
catch
end

try
    vs = double(getpref('deConfUSIon','voxelSizeYX',[]));
    vs = vs(:).';
    if numel(vs) >= 2 && all(isfinite(vs(1:2))) && all(vs(1:2) > 0)
        a = vs(1)/vs(2); return;
    end
catch
end

try
    v = double(getpref('deConfUSIon','probeViewAspect',1));
    if isscalar(v) && isfinite(v) && v > 0, a = v; return; end
catch
end

a = 1;
end
