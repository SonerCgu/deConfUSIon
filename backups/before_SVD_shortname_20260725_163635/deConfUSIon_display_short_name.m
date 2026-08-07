function label = deConfUSIon_display_short_name(nameIn, dataStruct, matFile)
% Central user-facing name used by Studio dropdowns.
% Short means cleaned/canonical; the chain is not hard-truncated.
if nargin < 1 || isempty(nameIn), nameIn = 'dataset'; end
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end
try
    label = deConfUSIon_display_name_from_sources(nameIn,dataStruct,matFile);
catch
    try, label = char(nameIn); catch, label = 'dataset'; end
end
label = strrep(label,'...','_');
label = regexprep(label,'\.mat$','','ignorecase');
label = regexprep(label,'_+','_');
label = regexprep(label,'^_+|_+$','');
% Preserve the SVD processing tag in Studio and Load fUSI Data dropdowns.
try
    svdTag = '';

    % Prefer the actual SVD metadata stored with the dataset.
    if isstruct(dataStruct) && isfield(dataStruct,'svdClutter') && ...
            ~isempty(dataStruct.svdClutter)

        st = dataStruct.svdClutter;

        pct = [];
        nRejected = [];
        scopeTag = 'joint';

        if isfield(st,'cutoffPercent') && ~isempty(st.cutoffPercent)
            pct = double(st.cutoffPercent);
        end

        if isfield(st,'nRejected') && ~isempty(st.nRejected)
            nRejected = round(double(st.nRejected));
        end

        if isfield(st,'scope') && ~isempty(st.scope)
            sc = lower(char(st.scope));
            if contains(sc,'slice')
                scopeTag = 'perSlice';
            else
                scopeTag = 'joint';
            end
        end

        if ~isempty(pct) && isfinite(pct)
            pctTag = strrep(sprintf('%.1f',pct),'.','p');
        else
            pctTag = 'unknown';
        end

        if ~isempty(nRejected) && isfinite(nRejected)
            svdTag = sprintf('SVD_p%s_k%d_%s', ...
                pctTag,nRejected,scopeTag);
        else
            svdTag = sprintf('SVD_p%s_%s',pctTag,scopeTag);
        end
    end

    % Fallback: recover an SVD tag already present in the supplied name.
    if isempty(svdTag)
        sourceText = char(nameIn);
        tok = regexp(sourceText, ...
            'SVD_p[0-9pP\.]+_k[0-9]+_(?:per[-_]?slice|perSlice|joint)', ...
            'match','once','ignorecase');

        if isempty(tok)
            tok = regexp(sourceText, ...
                'svd_p[0-9pP\.]+_k[0-9]+_[A-Za-z-]+', ...
                'match','once','ignorecase');
        end

        if ~isempty(tok)
            tok = regexprep(tok,'^svd_','SVD_','ignorecase');
            tok = regexprep(tok,'per[-_]?slice','perSlice','ignorecase');
            svdTag = tok;
        end
    end

    % Append only when the canonical name builder dropped the SVD tag.
    if ~isempty(svdTag) && isempty(regexpi(label,'(^|_)SVD(_|$)'))
        label = [label '_' svdTag];
    end
catch
    % Naming errors must never prevent loading a dataset.
end

if isempty(label), label = 'dataset'; end
end
