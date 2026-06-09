function tf = HUMOR_is_bad_display_name(s)
% True if name looks like an internal short physical filename/key.

tf = false;
if nargin < 1 || isempty(s), tf = true; return; end
try, s = char(s); catch, tf = true; return; end
low = lower(s);

patterns = {
    'preproc_preproc', ...
    '^preproc_[0-9]', ...
    '^preproc_.*_[0-9a-f]{8}$', ...
    '_[0-9a-f]{8}$', ...
    'filter_filter', ...
    'pca_pca', ...
    'ica_ica', ...
    'imreg_imreg', ...
    'motor_motor' ...
};

for i = 1:numel(patterns)
    if ~isempty(regexp(low,patterns{i},'once'))
        tf = true;
        return;
    end
end

% Generic op name without animal/session/slice context.
startsGeneric = ~isempty(regexp(low,'^(preproc|filter|pca|ica|imreg|tsmooth|subsample)_','once'));
hasContext = ~isempty(regexp(low,'\d{3,6}.*(sess|sl|slice|scan)','once'));
if startsGeneric && ~hasContext
    tf = true;
end
end
