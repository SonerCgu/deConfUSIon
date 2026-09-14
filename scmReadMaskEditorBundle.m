function B = scmReadMaskEditorBundle(S)
% Decode Mask Editor exports without confusing display pixels with raw data.
% Accept old exports, nested-only bundles and compact-save top-level fields.
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
