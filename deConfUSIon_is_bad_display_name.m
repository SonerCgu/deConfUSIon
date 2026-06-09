function tf = deConfUSIon_is_bad_display_name(s)
% True if visible name looks like an internal temporary/preproc key.
tf = false;
if nargin < 1 || isempty(s), tf = true; return; end
try, s = char(s); catch, tf = true; return; end
low = lower(s);
bad = {'preproc_preproc','filter_filter','pca_pca','ica_ica','imreg_imreg','motor_motor'};
for i = 1:numel(bad)
    if ~isempty(strfind(low,bad{i})), tf = true; return; end
end
if ~isempty(strfind(s,'...')), tf = true; return; end
if ~isempty(regexp(low,'^preproc_[0-9a-f]{6,}','once')), tf = true; return; end
end
