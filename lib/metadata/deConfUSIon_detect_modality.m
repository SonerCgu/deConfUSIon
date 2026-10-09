function info = deConfUSIon_detect_modality(anatomic, studio)
% deConfUSIon_detect_modality
% -------------------------------------------------------------
% Classify a deConfUSIon anatomy/scan volume as one of:
%
%   '2d_single'  : single imaging plane (nZ == 1)
%   '2d_motor'   : step-motor stack, few slices, coarse z spacing
%   '3d_probe'   : matrix-probe volume, many slices, near-isotropic z
%
% INPUT
%   anatomic : struct with .Data [Y X Z] and optional .VoxelSize [z x y]
%   studio   : optional studio struct (used only for extra hints)
%
% OUTPUT
%   info.modality      : one of the strings above
%   info.nZ            : number of slices
%   info.zRatio        : z spacing / mean in-plane spacing (NaN if unknown)
%   info.voxelKnown    : true if a real VoxelSize was supplied
%   info.confidence    : 'high' | 'medium' | 'low'
%   info.reason        : human-readable explanation
%   info.dofMask       : logical 1x9 mask of parameters worth optimising
%                        [tx ty tz rx ry rz sx sy sz]
%
% ASCII only. MATLAB 2017b compatible.
% -------------------------------------------------------------

if nargin < 2
    studio = [];
end

info = struct();
info.modality   = '2d_single';
info.nZ         = 1;
info.zRatio     = NaN;
info.voxelKnown = false;
info.confidence = 'low';
info.reason     = '';
info.dofMask    = true(1,9);

if ~isstruct(anatomic) || ~isfield(anatomic,'Data') || isempty(anatomic.Data)
    info.reason = 'No data supplied.';
    return;
end

D = anatomic.Data;
if ndims(D) == 2
    nZ = 1;
else
    nZ = size(D,3);
end
info.nZ = nZ;

% ---- voxel geometry -------------------------------------------------
vox = [];
if isfield(anatomic,'VoxelSize') && ~isempty(anatomic.VoxelSize)
    vox = double(anatomic.VoxelSize(:)');
end
if numel(vox) >= 3 && all(isfinite(vox(1:3))) && all(vox(1:3) > 0)
    % deConfUSIon convention for VoxelSize is [z x y]
    dz = vox(1);
    dInPlane = mean(vox(2:3));
    if dInPlane > 0
        info.zRatio = dz / dInPlane;
        % [1 1 1] is the library default, not a measurement
        info.voxelKnown = ~(abs(dz-1) < 1e-9 && abs(dInPlane-1) < 1e-9);
    end
end

% ---- studio hints ---------------------------------------------------
motorHint = false;
if isstruct(studio)
    fn = {'motorInfo','isMotor','motorReconstructed','nSlices'};
    for k = 1:numel(fn)
        if isfield(studio, fn{k}) && ~isempty(studio.(fn{k}))
            motorHint = true;
        end
    end
    if isfield(studio,'preprocessing') && ischar(studio.preprocessing)
        if ~isempty(strfind(lower(studio.preprocessing),'motor')) %#ok<STREMP>
            motorHint = true;
        end
    end
end

% ---- classify -------------------------------------------------------
if nZ <= 1
    info.modality   = '2d_single';
    info.confidence = 'high';
    info.reason     = 'Single imaging plane (nZ = 1).';

elseif nZ >= 50
    info.modality   = '3d_probe';
    info.confidence = 'high';
    info.reason     = sprintf('%d slices - matrix-probe volume.', nZ);

elseif nZ >= 30
    if isfinite(info.zRatio) && info.zRatio > 2.5
        info.modality   = '2d_motor';
        info.confidence = 'medium';
        info.reason     = sprintf(['%d slices but z spacing is %.1fx in-plane ' ...
                          '- treated as a step-motor stack.'], nZ, info.zRatio);
    else
        info.modality   = '3d_probe';
        info.confidence = 'medium';
        info.reason     = sprintf('%d slices, z spacing not coarse - treated as a probe volume.', nZ);
    end

else
    info.modality   = '2d_motor';
    if motorHint
        info.confidence = 'high';
        info.reason     = sprintf('%d slices and motor reconstruction in history.', nZ);
    else
        info.confidence = 'medium';
        info.reason     = sprintf('%d slices - too few for a matrix probe, treated as a motor stack.', nZ);
    end
end

% ---- which parameters are worth optimising --------------------------
% order: [tx ty tz rx ry rz sx sy sz]
switch info.modality
    case '2d_single'
        % One plane cannot constrain out-of-plane rotation or z scale.
        % Solve for AP position (tz), in-plane pose, in-plane scale only.
        info.dofMask = [true true true, false false true, true true false];

    case '2d_motor'
        % Sparse z: allow z translation and scale, but out-of-plane
        % rotations are weakly determined and left to the manual stage.
        info.dofMask = [true true true, false false true, true true true];

    otherwise
        info.dofMask = true(1,9);
end

if ~info.voxelKnown
    info.reason = [info.reason ' NOTE: no real VoxelSize found, assuming isotropic.'];
    if strcmp(info.confidence,'high')
        info.confidence = 'medium';
    end
end

end
