function tf = HUMOR_is_preproc_mat_path(p)
% True for saved processed/lazy preprocessing MAT files.

tf = false;
if nargin < 1 || isempty(p), return; end
try, p = char(p); catch, return; end
pp = lower(strrep(p,'/','\'));

if ~isempty(strfind(pp,'\preprocessing\')) || ~isempty(strfind(pp,'\analyseddata\'))
    tf = true;
end

% Short folder P used when Windows path is too long.
if ~isempty(regexp(pp,'\\p\\[^\\]+\.mat$','once'))
    tf = true;
end
end
