function [B, report] = scmReadMaskEditorBundle(S,varargin)
% Decode Mask Editor exports without confusing display pixels with raw data.
% Accept old exports, nested-only bundles and compact-save top-level fields.
report=[];
if ischar(S)&&strcmp(S,'align')
    [B,report]=alignBundle(varargin{:});return;
end
B = [];
R = S;
if isfield(S,'maskBundle') && isstruct(S.maskBundle) && isscalar(S.maskBundle)
    R = S.maskBundle;
end

info = pick({'maskEditorInfo'});
if isempty(info) || ~isstruct(info), return; end
B = struct('isMaskEditor',true,'image',[],'isProcessed',false, ...
    'brainMask',[],'overlayMask',[],'includeMask',[]);
processed = {'sliceUnderlayProcessed','anatomical_reference','brainImage'};
B.image = pick(processed);
B.isProcessed = ~isempty(B.image);
if isempty(B.image)
    B.image = pick({'sliceUnderlayRaw','anatomical_reference_raw'});
end
if isempty(B.image) || ~(isnumeric(B.image) || islogical(B.image))
    error('SCM:MaskEditorUnderlay','Mask Editor bundle has no usable underlay.');
end
B.image = double(B.image);
B.brainMask = readInclude({'brainMask','underlayMask'}, ...
    {'brainMaskIsInclude'}, 'hasBrainMask');
B.overlayMask = readInclude({'overlayMask','signalMask'}, ...
    {'overlayMaskIsInclude'}, 'hasOverlayMask');
B.includeMask = B.brainMask;
if ~isempty(B.overlayMask)
    if isempty(B.includeMask)
        B.includeMask = B.overlayMask;
    else
        if ~isequal(size(B.includeMask),size(B.overlayMask))
            error('SCM:MaskEditorMaskSize','Saved brain and overlay mask sizes differ.');
        end
        B.includeMask = B.includeMask & B.overlayMask;
    end
end

    function v = pick(names)
        v = [];
        for k = 1:numel(names)
            name = names{k};
            if isfield(R,name) && ~isempty(R.(name)), v = R.(name); return; end
            if isfield(S,name) && ~isempty(S.(name)), v = S.(name); return; end
        end
    end

    function M = readInclude(names, flags, presenceField)
        M = pick(names);
        if isempty(M), return; end
        M = isfinite(M) & M ~= 0;
        flag = pick(flags);
        if ~isempty(flag) && ~logical(flag), M = ~M; end
        % Older exports saved an all-false array for a mask never drawn.
        % Preserve empty slices within a drawn multi-slice mask.
        if isfield(info,presenceField)
            present = logical(info.(presenceField));
        else
            present = any(M(:));
        end
        if ~present, M = []; end
    end
end

function [B,report]=alignBundle(B,ctx)
% A native mask can be loaded after the functional series was atlas-warped.
% Use the applied mapping, never resize/reorder unrelated masks by shape.
expected=double(ctx.sizeYXZ(:)');source=size(B.image,[1 2 3]);
report=struct('warpedFromNative',false,'sourceSize',source,'outputSize',expected);
assert(ndims(B.image)<=3,'SCM:MaskEditorDimensions','Mask Editor underlay must be a grayscale slice or slice stack.');
for field={'brainMask','overlayMask','includeMask'}
    M=B.(field{1});
    assert(isempty(M)||(ndims(M)<=3&&isequal(size(M,[1 2 3]),source)), ...
        'SCM:MaskEditorDimensions','Saved %s does not match the Mask Editor underlay slices.',field{1});
end
if isequal(source,expected),return;end
native=double(ctx.nativeSizeYXZ(:)');mapping=ctx.mapping;
assert(ctx.isAtlasWarped&&isequal(source,native)&&~isempty(mapping), ...
    'SCM:MaskEditorDimensions', ...
    'Mask Editor bundle [Y X Z] = %s matches neither the current SCM grid %s nor a native grid with an applied atlas transform (%s). Select the mask for this recording.', ...
    mat2str(source),mat2str(expected),mat2str(native));
image=single(B.image);finite=isfinite(image);image(~finite)=0;
if ~isempty(B.brainMask),image(~B.brainMask)=0;end
if any(strcmp(mapping.kind,{'3D','3DDirect'}))
    image=fusiWarpAtlasForDisplay(image,mapping.transform,true);
elseif strcmp(mapping.kind,'2D')
    assert(numel(mapping.sourceSlices)==expected(3)&&numel(mapping.matrices)==expected(3), ...
        'SCM:MaskEditorDimensions','The applied 2D atlas transforms do not match the displayed slices.');
    output=nan(expected,'single');reference=imref2d(expected(1:2));
    for z=1:expected(3)
        plane=image(:,:,mapping.sourceSlices(z));
        if mapping.transpose(z),plane=plane.';end
        output(:,:,z)=imwarp(plane,affine2d(mapping.matrices{z}),'linear', ...
            'OutputView',reference,'FillValues',NaN);
    end
    image=output;
else
    error('SCM:MaskEditorDimensions','The applied atlas transform cannot map this Mask Editor bundle.');
end
assert(isequal(size(image,[1 2 3]),expected),'SCM:MaskEditorDimensions', ...
    'The applied atlas transform produced a different mask grid from the displayed functional data.');
fields={'brainMask','overlayMask','includeMask'};definitions={};present=[];
for k=1:numel(fields)
    M=B.(fields{k});if isempty(M),continue;end
    definitions{end+1}=struct('roiMaskVolumeIndices',find(M),'slice',1); %#ok<AGROW>
    present(end+1)=k; %#ok<AGROW>
end
definitions{end+1}=struct('roiMaskVolumeIndices',find(finite),'slice',1);
% One inverse-coordinate calculation for all masks; discrete membership uses
% nearest neighbours, preserving slice order and acquisition handedness.
mapped=scmROI('map',definitions,source,expected,mapping,false,[NaN NaN NaN]);
for k=1:numel(present)
    M=false(expected);M(mapped{k}.roiMaskVolumeIndices)=true;B.(fields{present(k)})=M;
end
valid=false(expected);valid(mapped{end}.roiMaskVolumeIndices)=true;image(~valid)=NaN;
B.image=double(image);report.warpedFromNative=true;
end
